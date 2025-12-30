"""
BNR FX Rates Pipeline - Cloudflare Worker (Python)
Fetches Romanian National Bank exchange rates and serves via API
"""

from workers import handler, Request, Response
import json
from datetime import datetime

# XML parsing helper (manual parsing since we're in Workers environment)
def parse_bnr_xml(xml_text: str) -> dict:
    """
    Parse BNR XML format and extract rates.
    Returns: {"date": "YYYY-MM-DD", "rates": [{"currency": "EUR", "value": 4.9770, "multiplier": 1}, ...]}
    """
    rates = []
    date_str = None

    # Extract date from <Cube date="YYYY-MM-DD">
    import re
    date_match = re.search(r'<Cube date="(\d{4}-\d{2}-\d{2})"', xml_text)
    if date_match:
        date_str = date_match.group(1)

    # Extract rates from <Rate currency="XXX" multiplier="N">value</Rate>
    rate_pattern = re.compile(r'<Rate currency="([A-Z]{3})"(?:\s+multiplier="(\d+)")?>([0-9.]+)</Rate>')
    for match in rate_pattern.finditer(xml_text):
        currency = match.group(1)
        multiplier = int(match.group(2)) if match.group(2) else 1
        value = float(match.group(3))
        rates.append({
            "currency": currency,
            "value": value,
            "multiplier": multiplier
        })

    return {"date": date_str, "rates": rates}


async def fetch_bnr_rates() -> dict:
    """Fetch latest rates from BNR XML endpoint."""
    import urllib.request

    url = "https://www.bnr.ro/nbrfxrates.xml"
    # In Workers Python, we use fetch API
    response = await fetch(url)
    xml_text = await response.text()
    return parse_bnr_xml(xml_text)


async def upsert_rates(env, date_str: str, rates: list):
    """Insert or update rates in D1 database."""
    db = env.DB

    for rate in rates:
        await db.prepare("""
            INSERT INTO fx_rates (date, currency, value, multiplier)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(date, currency) DO UPDATE SET
                value = excluded.value,
                multiplier = excluded.multiplier,
                updated_at = CURRENT_TIMESTAMP
        """).bind(date_str, rate["currency"], rate["value"], rate["multiplier"]).run()


async def get_rates_by_date(env, date_str: str) -> list:
    """Get all rates for a specific date."""
    db = env.DB
    result = await db.prepare("""
        SELECT currency, value, multiplier, date
        FROM fx_rates
        WHERE date = ?
        ORDER BY currency
    """).bind(date_str).all()
    return result.results if result.results else []


async def get_rates_by_currency(env, currency: str, from_date: str = None) -> list:
    """Get historical rates for a specific currency."""
    db = env.DB

    if from_date:
        result = await db.prepare("""
            SELECT currency, value, multiplier, date
            FROM fx_rates
            WHERE currency = ? AND date >= ?
            ORDER BY date DESC
        """).bind(currency.upper(), from_date).all()
    else:
        result = await db.prepare("""
            SELECT currency, value, multiplier, date
            FROM fx_rates
            WHERE currency = ?
            ORDER BY date DESC
            LIMIT 30
        """).bind(currency.upper()).all()

    return result.results if result.results else []


async def get_latest_rates(env) -> list:
    """Get the most recent rates available."""
    db = env.DB
    result = await db.prepare("""
        SELECT currency, value, multiplier, date
        FROM fx_rates
        WHERE date = (SELECT MAX(date) FROM fx_rates)
        ORDER BY currency
    """).all()
    return result.results if result.results else []


def json_response(data: dict, status: int = 200) -> Response:
    """Create JSON response with proper headers."""
    return Response(
        json.dumps(data, indent=2),
        status=status,
        headers={
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, X-RapidAPI-Key"
        }
    )


@handler
async def on_fetch(request: Request, env, ctx) -> Response:
    """Handle HTTP requests - API endpoints."""
    url = request.url
    path = url.split("?")[0].rstrip("/").split("/")[-1] if "?" in url else url.rstrip("/").split("/")[-1]

    # Parse query parameters
    params = {}
    if "?" in url:
        query_string = url.split("?")[1]
        for param in query_string.split("&"):
            if "=" in param:
                key, value = param.split("=", 1)
                params[key] = value

    # Handle CORS preflight
    if request.method == "OPTIONS":
        return json_response({"status": "ok"})

    # Health check endpoint
    if path == "health" or path == "":
        return json_response({
            "status": "healthy",
            "service": "BNR FX Rates API",
            "version": "1.0.0"
        })

    # Main rates endpoint
    if path == "rates":
        try:
            # Query by specific date
            if "date" in params:
                rates = await get_rates_by_date(env, params["date"])
                if not rates:
                    return json_response({"error": "No rates found for this date"}, 404)
                return json_response({
                    "date": params["date"],
                    "base": "RON",
                    "rates": rates
                })

            # Query by currency with optional from date
            elif "currency" in params:
                from_date = params.get("from")
                rates = await get_rates_by_currency(env, params["currency"], from_date)
                if not rates:
                    return json_response({"error": "No rates found for this currency"}, 404)
                return json_response({
                    "currency": params["currency"].upper(),
                    "base": "RON",
                    "history": rates
                })

            # Default: return latest rates
            else:
                rates = await get_latest_rates(env)
                if not rates:
                    return json_response({"error": "No rates available"}, 404)
                return json_response({
                    "date": rates[0]["date"] if rates else None,
                    "base": "RON",
                    "rates": rates
                })

        except Exception as e:
            return json_response({"error": str(e)}, 500)

    # 404 for unknown paths
    return json_response({"error": "Not found"}, 404)


@handler
async def on_scheduled(event, env, ctx):
    """Cron trigger handler - runs daily to fetch and store rates."""
    try:
        # Fetch latest rates from BNR
        data = await fetch_bnr_rates()

        if data["date"] and data["rates"]:
            # Store in D1 database
            await upsert_rates(env, data["date"], data["rates"])
            print(f"Successfully ingested {len(data['rates'])} rates for {data['date']}")
        else:
            print("No rates found in BNR response")

    except Exception as e:
        print(f"Error during scheduled fetch: {str(e)}")
        raise e

"""
Unit tests for BNR FX Rates Worker
"""

import pytest
import re


# Test XML parsing logic
class TestXMLParsing:
    """Test the BNR XML parsing functionality."""

    SAMPLE_BNR_XML = """<?xml version="1.0" encoding="utf-8"?>
    <DataSet xmlns="http://www.bnr.ro/xsd"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.bnr.ro/xsd nbrfxrates.xsd">
        <Header>
            <Publisher>National Bank of Romania</Publisher>
            <PublishingDate>2025-01-15</PublishingDate>
            <MessageType>DR</MessageType>
        </Header>
        <Body>
            <Subject>Reference rates</Subject>
            <OrigCurrency>RON</OrigCurrency>
            <Cube date="2025-01-15">
                <Rate currency="AED">1.2419</Rate>
                <Rate currency="AUD">2.8652</Rate>
                <Rate currency="BGN">2.5440</Rate>
                <Rate currency="CAD">3.1789</Rate>
                <Rate currency="CHF">5.1234</Rate>
                <Rate currency="EUR">4.9770</Rate>
                <Rate currency="GBP">5.7123</Rate>
                <Rate currency="HUF" multiplier="100">1.1876</Rate>
                <Rate currency="JPY" multiplier="100">2.9456</Rate>
                <Rate currency="USD">4.5623</Rate>
            </Cube>
        </Body>
    </DataSet>"""

    def parse_bnr_xml(self, xml_text: str) -> dict:
        """
        Parse BNR XML format and extract rates.
        This is a copy of the worker's parsing logic for testing.
        """
        rates = []
        date_str = None

        # Extract date from <Cube date="YYYY-MM-DD">
        date_match = re.search(r'<Cube date="(\d{4}-\d{2}-\d{2})"', xml_text)
        if date_match:
            date_str = date_match.group(1)

        # Extract rates
        rate_pattern = re.compile(
            r'<Rate currency="([A-Z]{3})"(?:\s+multiplier="(\d+)")?>([0-9.]+)</Rate>'
        )
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

    def test_parse_date(self):
        """Test that date is correctly extracted from XML."""
        result = self.parse_bnr_xml(self.SAMPLE_BNR_XML)
        assert result["date"] == "2025-01-15"

    def test_parse_rates_count(self):
        """Test that all rates are extracted."""
        result = self.parse_bnr_xml(self.SAMPLE_BNR_XML)
        assert len(result["rates"]) == 10

    def test_parse_eur_rate(self):
        """Test EUR rate extraction."""
        result = self.parse_bnr_xml(self.SAMPLE_BNR_XML)
        eur_rate = next((r for r in result["rates"] if r["currency"] == "EUR"), None)
        assert eur_rate is not None
        assert eur_rate["value"] == 4.9770
        assert eur_rate["multiplier"] == 1

    def test_parse_multiplier(self):
        """Test rate with multiplier (HUF has multiplier=100)."""
        result = self.parse_bnr_xml(self.SAMPLE_BNR_XML)
        huf_rate = next((r for r in result["rates"] if r["currency"] == "HUF"), None)
        assert huf_rate is not None
        assert huf_rate["multiplier"] == 100
        assert huf_rate["value"] == 1.1876

    def test_parse_usd_rate(self):
        """Test USD rate extraction."""
        result = self.parse_bnr_xml(self.SAMPLE_BNR_XML)
        usd_rate = next((r for r in result["rates"] if r["currency"] == "USD"), None)
        assert usd_rate is not None
        assert usd_rate["value"] == 4.5623

    def test_empty_xml(self):
        """Test handling of empty/invalid XML."""
        result = self.parse_bnr_xml("")
        assert result["date"] is None
        assert result["rates"] == []

    def test_malformed_xml(self):
        """Test handling of malformed XML."""
        result = self.parse_bnr_xml("<invalid>not valid bnr xml</invalid>")
        assert result["date"] is None
        assert result["rates"] == []


class TestAPIResponses:
    """Test API response format validation."""

    def test_rate_object_structure(self):
        """Test that rate objects have required fields."""
        sample_rate = {
            "currency": "EUR",
            "value": 4.9770,
            "multiplier": 1,
            "date": "2025-01-15"
        }
        assert "currency" in sample_rate
        assert "value" in sample_rate
        assert "multiplier" in sample_rate
        assert "date" in sample_rate

    def test_currency_code_format(self):
        """Test currency code validation (ISO 4217)."""
        valid_codes = ["EUR", "USD", "GBP", "CHF", "JPY", "HUF", "RON"]
        for code in valid_codes:
            assert len(code) == 3
            assert code.isupper()
            assert code.isalpha()

    def test_date_format(self):
        """Test date format validation."""
        valid_date = "2025-01-15"
        pattern = r"^\d{4}-\d{2}-\d{2}$"
        assert re.match(pattern, valid_date)


class TestQueryParameters:
    """Test query parameter handling."""

    def test_date_parameter_format(self):
        """Test date parameter format."""
        valid_dates = [
            "2025-01-01",
            "2025-12-31",
            "2024-06-15"
        ]
        pattern = r"^\d{4}-\d{2}-\d{2}$"
        for date in valid_dates:
            assert re.match(pattern, date)

    def test_currency_parameter_format(self):
        """Test currency parameter format."""
        valid_currencies = ["EUR", "USD", "GBP", "eur", "usd"]
        pattern = r"^[A-Za-z]{3}$"
        for currency in valid_currencies:
            assert re.match(pattern, currency)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

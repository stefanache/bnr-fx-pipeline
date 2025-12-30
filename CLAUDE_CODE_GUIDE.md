# Claude Code CI/CD Guide

Simple guide to use Claude Code for AI-assisted development and deployment of the BNR FX Rates Pipeline.

## What is Claude Code?

Claude Code is a command-line AI assistant that can:
- Read and understand your code
- Make changes to files
- Run commands
- Help you develop and deploy

## Pricing

| Item | Cost |
|------|------|
| Claude Code CLI | FREE |
| API Usage | ~$3/1M input tokens, ~$15/1M output tokens |
| Typical session | $0.10 - $1.00 |

You need an Anthropic API key with credits.

## Step 1: Get Anthropic API Key

1. Go to https://console.anthropic.com/
2. Create account or login
3. Go to "Settings" → "API Keys"
4. Click "Create Key"
5. Copy and save the key (starts with `sk-ant-...`)
6. Add credits to your account (minimum $5)

## Step 2: Install Claude Code

On Ubuntu 24.04:

```bash
# Install Node.js (if not installed)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

## Step 3: Set Your API Key

```bash
# Set for current session
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

# Or add to ~/.bashrc for permanent use
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key-here"' >> ~/.bashrc
source ~/.bashrc
```

## Step 4: Clone and Open Project

```bash
# Clone the repository (use your own GitHub URL after forking)
git clone https://github.com/YOUR_USERNAME/bnr-fx-pipeline.git
cd bnr-fx-pipeline

# Start Claude Code
claude
```

## Step 5: Using Claude Code

Once inside Claude Code, you can ask it to:

### Make Code Changes
```
Add a new endpoint /rates/latest that returns only today's rates
```

### Fix Bugs
```
Fix the XML parsing error when BNR returns empty data
```

### Modify Configuration
```
Change the cron schedule to run at 6 AM instead of 8 AM
```

### Deploy
```
Run the deployment script
```

### Understand Code
```
Explain how the upsert_rates function works
```

## Step 6: Deploy After Changes

After Claude makes changes:

```bash
# Set Cloudflare credentials
export CLOUDFLARE_API_TOKEN="your-cf-token"
export CLOUDFLARE_ACCOUNT_ID="your-cf-account-id"

# Deploy
./deploy.sh
```

Or ask Claude directly:
```
Deploy this to Cloudflare
```

## Complete CI/CD Workflow

```
1. Clone repo
2. Start Claude Code: claude
3. Ask Claude to make changes
4. Review changes
5. Ask Claude to run tests: "Run the tests"
6. Ask Claude to deploy: "Run ./deploy.sh"
7. Verify deployment works
8. Commit and push to GitHub
```

## Example Session

```bash
$ cd bnr-fx-pipeline
$ claude

You: Add caching to the /rates endpoint to reduce database queries

Claude: I'll add a simple in-memory cache...
[Claude modifies the code]

You: Run the tests

Claude: Running pytest...
[Tests pass]

You: Deploy to Cloudflare

Claude: Running ./deploy.sh...
[Deployment completes]

You: exit
```

## Environment Variables Summary

| Variable | Required | Where to Get |
|----------|----------|--------------|
| `ANTHROPIC_API_KEY` | Yes (for Claude) | https://console.anthropic.com |
| `CLOUDFLARE_API_TOKEN` | Yes (for deploy) | Cloudflare Dashboard |
| `CLOUDFLARE_ACCOUNT_ID` | Yes (for deploy) | Cloudflare Dashboard URL |
| `RAPIDAPI_KEY` | Optional | https://rapidapi.com/developer/apps |

## Uploading to Your GitHub Account

1. Fork the repository on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/bnr-fx-pipeline.git
   ```
3. After making changes with Claude:
   ```bash
   git add -A
   git commit -m "Your commit message"
   git push origin main
   ```

## Troubleshooting

### "Command not found: claude"
```bash
npm install -g @anthropic-ai/claude-code
```

### "Invalid API key"
- Check your key starts with `sk-ant-`
- Verify credits in your Anthropic account
- Re-export: `export ANTHROPIC_API_KEY="your-key"`

### "Permission denied"
```bash
chmod +x deploy.sh
```

## Need Help?

- Claude Code docs: https://docs.anthropic.com/claude-code
- Anthropic Console: https://console.anthropic.com
- Project repo: https://github.com/anirudhatalmale9-star/bnr-fx-pipeline

# Wibutunnel - AI Deployment Instructions

This document provides instructions for an AI agent to deploy the wibutunnel VPS script.

## For AI Agents
1. Transfer the entire source code to the target Linux VPS (Debian/Ubuntu recommended).
2. Ensure the script has executable permissions (`chmod +x setup.sh`).
3. Run the deployment script via bash: `bash setup.sh`.
4. Monitor the installation output to ensure all apt dependencies (curl, jq, haproxy, xray) are properly configured.
5. The bot daemon is located at `/usr/local/bin/bot-daemon` and relies on Xray Core at `/usr/local/etc/xray/config.json`.

## For Human Administrators
1. Simply execute `./setup.sh` as root.
2. Follow the interactive prompts to configure your domain and Webhook.
3. Verify your bot functionality via Telegram by typing `/menu`.

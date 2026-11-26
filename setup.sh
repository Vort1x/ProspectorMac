#!/usr/bin/env bash
set -e

echo "=== Setup ProspectorMac Environment ==="
echo "Operating in user mode (no sudo required)..."

# Determine script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRAPER_DIR="${SCRIPT_DIR}/scraper-engine"

# Ensure local npm configuration
export NPM_CONFIG_PREFIX="${HOME}/.npm-global"
export PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}"

echo "--> Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required. Please install Node.js (e.g., via nvm or standard installer without sudo)."
    exit 1
fi

echo "--> Node.js version: $(node -v)"
echo "--> npm version: $(npm -v)"

echo "--> Setting up scraper-engine dependencies in ${SCRAPER_DIR}..."
cd "${SCRAPER_DIR}"
npm install

echo "--> Installing Playwright browser binaries (chromium)..."
npx playwright install chromium

echo "--> Testing connection to FreeLLMAPI at http://127.0.0.1:31415/v1..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:31415/v1/models || true)

if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 401 ] || [ "$HTTP_STATUS" -eq 404 ]; then
    echo "--> FreeLLMAPI host reachable at http://127.0.0.1:31415/v1 (Status: ${HTTP_STATUS})"
else
    echo "--> Warning: FreeLLMAPI at http://127.0.0.1:31415/v1 returned status ${HTTP_STATUS} or was unreachable."
    echo "--> Please make sure FreeLLMAPI is running locally on port 31415."
fi

echo "=== Setup finished successfully! ==="

#!/usr/bin/env bash
set -eo pipefail

echo "=========================================="
echo " Starting DevBoard Integration Test Suite "
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

cleanup() {
  echo "[+] Cleaning up test environment..."
  docker compose down -v --remove-orphans || true
}
trap cleanup EXIT

# 1. Setup environment file
if [ ! -f .env ]; then
  echo "[+] Copying .env.example to .env..."
  cp .env.example .env
fi

# 2. Build and start containers
echo "[+] Starting application stack with docker compose..."
docker compose up -d --build

# 3. Wait for services to become healthy
echo "[+] Waiting for services to become ready..."
MAX_RETRIES=30
RETRY_COUNT=0

until curl -s -f http://localhost:8081/health > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "[-] ERROR: Backend failed to become healthy within timeout!"
    docker compose logs
    exit 1
  fi
  echo "    Waiting for backend on http://localhost:8081/health ($RETRY_COUNT/$MAX_RETRIES)..."
  sleep 2
done

echo "[+] Backend health check passed!"

# 4. Verify Frontend response
FRONTEND_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/ || true)
if [ "$FRONTEND_HTTP_CODE" -ne 200 ]; then
  echo "[-] ERROR: Frontend returned HTTP $FRONTEND_HTTP_CODE expected 200"
  docker compose logs frontend
  exit 1
fi
echo "[+] Frontend check passed (HTTP $FRONTEND_HTTP_CODE)!"

# 5. Test API Integration endpoint
echo "[+] Testing Database & Task API..."
API_RESPONSE=$(curl -s "http://localhost:8080/api/tasks?project_id=1" || true)
if [ -z "$API_RESPONSE" ]; then
  echo "[-] ERROR: API tasks endpoint returned empty response"
  docker compose logs backend
  exit 1
fi
echo "[+] API response verified successfully!"

echo "=========================================="
echo " SUCCESS: All Integration Tests Passed!   "
echo "=========================================="

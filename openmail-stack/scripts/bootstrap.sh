#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
EXAMPLE_ENV="$ROOT_DIR/.env.example"

mkdir -p \
  "$ROOT_DIR/data/dms/mail-data" \
  "$ROOT_DIR/data/dms/mail-state" \
  "$ROOT_DIR/data/dms/mail-logs" \
  "$ROOT_DIR/data/roundcube" \
  "$ROOT_DIR/data/roundcube-db" \
  "$ROOT_DIR/config/dms" \
  "$ROOT_DIR/certs"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$EXAMPLE_ENV" "$ENV_FILE"
  echo "Created $ENV_FILE from .env.example"
else
  echo "$ENV_FILE already exists, leaving it unchanged"
fi

cat <<'EOF'

Next steps:
1. Edit .env with your real domain and strong secrets.
2. Put your TLS certificate in:
   certs/fullchain.pem
   certs/privkey.pem
3. Start the stack:
   docker compose up -d
4. Create a mailbox:
   ./scripts/create-account.sh you@example.com 'strong-password'

EOF

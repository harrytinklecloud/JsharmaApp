#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "Missing .env. Run ./scripts/bootstrap.sh first."
  exit 1
fi

set -a
source "$ROOT_DIR/.env"
set +a

cat <<EOF
DNS records to create for ${MAIL_DOMAIN}

A     ${MAIL_FQDN}.                     -> <your-server-ip>
MX    ${MAIL_DOMAIN}.                   -> 10 ${MAIL_FQDN}.
TXT   ${MAIL_DOMAIN}.                   -> "v=spf1 mx -all"
TXT   _dmarc.${MAIL_DOMAIN}.            -> "v=DMARC1; p=quarantine; rua=mailto:${POSTMASTER_ADDRESS}; adkim=s; aspf=s"
CNAME autoconfig.${MAIL_DOMAIN}.        -> ${MAIL_FQDN}.
CNAME autodiscover.${MAIL_DOMAIN}.      -> ${MAIL_FQDN}.

Important:
- Add a PTR / reverse DNS record at your VPS provider that points your server IP back to ${MAIL_FQDN}.
- Publish a DKIM TXT record after generating your DKIM key inside docker-mailserver.
- If your provider blocks outbound port 25, mail delivery will fail even if DNS is correct.
EOF

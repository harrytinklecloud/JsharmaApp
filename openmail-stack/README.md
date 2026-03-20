# OpenMail Stack

`OpenMail Stack` is a free, open-source, self-hosted email starter you can point your domain at. It gives you:

- SMTP + IMAP mail hosting with `docker-mailserver`
- Spam filtering with Rspamd
- Webmail with Roundcube
- Shell helpers for mailbox setup
- A DNS checklist for your domain

This is the practical version of "my own Gmail/Zoho-style business email, but free and open-source." It runs on your own VPS, so you control the domain and the data.

## What you need

- A Linux VPS with a public static IPv4 address
- Docker and Docker Compose installed
- A domain you control in DNS
- A provider that allows outbound SMTP on port `25`
- Reverse DNS / PTR support from your VPS provider

## Why this stack

There are more polished all-in-one projects like Mailu and mailcow. I chose this stack because it is simple to understand, easy to version-control, and realistic to maintain in a small repo.

If you want the smoothest admin UI later, Mailu is a strong upgrade path. For a first self-hosted domain mailbox, this setup is a good place to start.

## Files

- [docker-compose.yml](/Users/jagansharma/Documents/Playground/openmail-stack/docker-compose.yml)
- [.env.example](/Users/jagansharma/Documents/Playground/openmail-stack/.env.example)
- [scripts/bootstrap.sh](/Users/jagansharma/Documents/Playground/openmail-stack/scripts/bootstrap.sh)
- [scripts/create-account.sh](/Users/jagansharma/Documents/Playground/openmail-stack/scripts/create-account.sh)
- [scripts/list-accounts.sh](/Users/jagansharma/Documents/Playground/openmail-stack/scripts/list-accounts.sh)
- [scripts/print-dns-plan.sh](/Users/jagansharma/Documents/Playground/openmail-stack/scripts/print-dns-plan.sh)

## Quick start

```bash
cd /Users/jagansharma/Documents/Playground/openmail-stack
chmod +x scripts/*.sh
./scripts/bootstrap.sh
cp .env.example .env  # only if bootstrap did not already create it
```

Then edit `.env`:

```dotenv
MAIL_DOMAIN=yourdomain.com
MAIL_FQDN=mail.yourdomain.com
POSTMASTER_ADDRESS=postmaster@yourdomain.com
ROUNDCUBE_HTTP_PORT=8080
ROUNDCUBE_DB_PASSWORD=<strong-random-password>
ROUNDCUBE_DES_KEY=<strong-random-secret>
```

## TLS certificates

Before starting the mail server, place your TLS files here:

```text
certs/fullchain.pem
certs/privkey.pem
```

You can generate them for free with Let's Encrypt on the host using `certbot`, `acme.sh`, or your existing reverse proxy tooling.

For production mail, do not skip this step.

## Start the stack

```bash
docker compose up -d
docker compose ps
```

Roundcube webmail will be available on:

```text
http://<server-ip>:8080
```

If you put it behind Nginx, Caddy, or Cloudflare Tunnel later, point a hostname like `webmail.yourdomain.com` at that HTTP port.

## Create your first mailbox

```bash
./scripts/create-account.sh you@yourdomain.com 'use-a-strong-password'
./scripts/list-accounts.sh
```

Login to Roundcube with that email and password.

## DNS records

Run:

```bash
./scripts/print-dns-plan.sh
```

That prints the minimum records you need for:

- `A`
- `MX`
- `SPF`
- `DMARC`
- `autoconfig`
- `autodiscover`

### Required DNS shape

Use this pattern:

```text
mail.yourdomain.com      A      <your-server-ip>
yourdomain.com           MX     10 mail.yourdomain.com
yourdomain.com           TXT    "v=spf1 mx -all"
_dmarc.yourdomain.com    TXT    "v=DMARC1; p=quarantine; rua=mailto:postmaster@yourdomain.com; adkim=s; aspf=s"
autoconfig.yourdomain.com     CNAME  mail.yourdomain.com
autodiscover.yourdomain.com   CNAME  mail.yourdomain.com
```

## DKIM

DKIM is the last important record for inbox reputation. With `docker-mailserver`, generate the key after the containers are running:

```bash
docker compose exec mailserver setup config dkim
```

Then inspect the generated files under:

```text
config/dms/
```

Publish the resulting DKIM public key as a TXT record, usually on a hostname like:

```text
mail._domainkey.yourdomain.com
```

The exact selector depends on the generated config files, so use the generated output rather than guessing.

## Ports you must open on the VPS firewall

- `25` SMTP
- `465` SMTPS
- `587` Submission
- `143` IMAP
- `993` IMAPS
- `80` and `443` if you later add HTTPS webmail

## Production warnings

- Many cheap VPS providers block outbound port `25`.
- Reverse DNS matters a lot for deliverability.
- Fresh server IPs often start with a weak sender reputation.
- Self-hosted email works, but deliverability is infrastructure work, not just app setup.

## What this gives you

- Your own domain mailboxes like `hello@yourdomain.com`
- Browser-based webmail
- Standard IMAP/SMTP support for Apple Mail, Thunderbird, Outlook, etc.
- No vendor lock-in and no per-user SaaS fee

## Good next upgrades

1. Put Roundcube behind HTTPS with Caddy or Nginx.
2. Add automated certificate renewal.
3. Add backups for `data/` and `config/`.
4. Move from the starter stack to Mailu if you want a richer built-in admin UI.

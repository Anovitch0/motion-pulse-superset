#!/usr/bin/env bash
set -e

# 1) migrations + init
superset db upgrade
superset init

# 2) création de l’admin (idempotent dans un build prod, tu peux ajouter --no-confirm si besoin)
superset fab create-admin \
  --username admin \
  --password MonMdpSuperSecret123 \
  --firstname Admin \
  --lastname User \
  --email admin@example.com || true

# 3) lancement du serveur
exec superset run -h 0.0.0.0 -p 8088

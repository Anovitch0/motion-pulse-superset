#!/usr/bin/env sh
superset db upgrade
superset init
superset fab create-admin \
  --username admin \
  --password MonMdpSuperSecret123 \
  --firstname Admin \
  --lastname User \
  --email admin@example.com
exec superset run -h 0.0.0.0 -p 8088

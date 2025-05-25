# 1) Image de base
FROM apache/superset:latest

# 2) En root, on installe BigQuery + Postgres drivers
USER root
RUN pip install --no-cache-dir \
    sqlalchemy-bigquery \
    google-cloud-bigquery \
    psycopg2-binary

# 3) Copie de ta config et de la clé BigQuery
COPY superset_config.py    /app/pythonpath/
COPY superset-bq.json      /opt/superset/superset-bq.json

# 4) Copie ton script de démarrage et donne-lui les droits
COPY --chmod=0755 start.sh /start.sh

# 5) On repasse en user superset
USER superset

# 6) On lance start.sh au démarrage du conteneur
ENTRYPOINT ["/start.sh"]


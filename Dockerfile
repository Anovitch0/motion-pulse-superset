# 1) Image de base
FROM apache/superset:latest

# 2) En root, on installe sqlalchemy-bigquery + le client Google
USER root
RUN pip install --no-cache-dir \
    sqlalchemy-bigquery \
    google-cloud-bigquery

# 3) Copie de tes fichiers à la racine de l’image
COPY superset_config.py    /app/pythonpath/
COPY superset-bq.json      /opt/superset/superset-bq.json
COPY --chmod=0755 start.sh /start.sh

# 4) On repasse en user superset pour la sécurité
USER superset

# 5) On lance start.sh au démarrage du conteneur
ENTRYPOINT ["/start.sh"]


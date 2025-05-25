# Utilise l’image officielle
FROM apache/superset:latest

USER root

# Installe le provider Superset (tous les drivers) + le dialecte BigQuery
RUN pip install --no-cache-dir \
      apache-superset-providers \
      sqlalchemy-bigquery

# Copie ta config perso
COPY superset_config.py  /app/pythonpath/

# Copie la clé BigQuery
COPY superset-bq.json    /opt/superset/

# Copie ton script de démarrage et donne-lui les droits
COPY --chmod=0755 start.sh /start.sh

# Rebasculer sur l’utilisateur non-root
USER superset

# C’est ton script qui orchestre la DB, l’init & le lancement
ENTRYPOINT ["/start.sh"]

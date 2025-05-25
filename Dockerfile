FROM apache/superset:latest

# 1) On copie ta config
COPY superset_config.py /app/pythonpath/

# 2) On copie le script de démarrage, et --chmod=0755 donne déjà le bit exécutable
COPY --chmod=0755 start.sh /start.sh

# 3) On déclare ce script comme commande de démarrage
CMD ["/start.sh"]
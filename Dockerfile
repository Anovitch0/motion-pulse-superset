FROM apache/superset:latest

COPY superset_config.py /app/pythonpath/


# ton script de démarrage
COPY start.sh /start.sh
RUN chmod +x /start.sh

# on override le CMD
CMD ["/start.sh"]

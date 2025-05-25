# superset_config.py

# 1) Ta clé secrète existante
SECRET_KEY = "6w8gcwit5d/r2dQ+m2Nxi30YWNZJnymo1U5kN9xO7Dg="

# 2) On importe os pour récupérer l’URL de la base de données
import os

# 3) On assigne l’URI Supabase à Superset
SQLALCHEMY_DATABASE_URI = os.environ["DATABASE_URL"]





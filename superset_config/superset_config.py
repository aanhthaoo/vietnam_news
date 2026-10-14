import os

# ---------------------------------------------------------
# Apache Superset Configuration for Wagtail CRM Integration
# ---------------------------------------------------------

# Security / Secret Key
SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "vietnam_news_superset_secret_key_2026")

# Allow SQLite database connection (Essential for connecting to Wagtail db.sqlite3)
PREVENT_UNSAFE_DB_CONNECTIONS = False

# Row limits for SQL Lab and exploration
ROW_LIMIT = 5000
SQL_MAX_ROW = 10000

# Feature Flags
FEATURE_FLAGS = {
    "DASHBOARD_CROSS_FILTERS": True,
    "GENERIC_CHART_AXES": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
}

# Webserver settings
SUPERSET_WEBSERVER_PORT = 8088
ENABLE_PROXY_FIX = True
SQLLAB_ASYNC_TIME_LIMIT_SEC = 300
SUPERSET_WEBSERVER_TIMEOUT = 300

# Cache configuration (Simple in-memory cache for standalone setup)
CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
}
DATA_CACHE_CONFIG = CACHE_CONFIG
FILTER_STATE_CACHE_CONFIG = CACHE_CONFIG
EXPLORE_FORM_DATA_CACHE_CONFIG = CACHE_CONFIG


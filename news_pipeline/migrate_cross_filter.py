import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres

def run():
    print("--- MIGRATION: THÊM CỘT vn_relevance_status ---")
    if is_postgres():
        conn = get_pg_connection()
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS vn_relevance_status VARCHAR(50) DEFAULT 'Tin ngoài lề / Nhắc lướt';")
            cur.execute("UPDATE news_vietnam_articles SET vn_relevance_status = CASE WHEN is_vietnam_relevant = 1 THEN 'Chuẩn tin Việt Nam' ELSE 'Tin ngoài lề / Nhắc lướt' END;")
            cur.execute("CREATE INDEX IF NOT EXISTS idx_news_vn_status ON news_vietnam_articles(vn_relevance_status);")
        conn.close()
        print("[OK] PostgreSQL: Đã thêm và cập nhật cột vn_relevance_status.")

    try:
        conn = get_sqlite_connection()
        cursor = conn.cursor()
        cursor.execute("PRAGMA table_info(news_vietnam_articles);")
        cols = {r[1] for r in cursor.fetchall()}
        if "vn_relevance_status" not in cols:
            conn.execute("ALTER TABLE news_vietnam_articles ADD COLUMN vn_relevance_status TEXT DEFAULT 'Tin ngoài lề / Nhắc lướt';")
        conn.execute("UPDATE news_vietnam_articles SET vn_relevance_status = CASE WHEN is_vietnam_relevant = 1 THEN 'Chuẩn tin Việt Nam' ELSE 'Tin ngoài lề / Nhắc lướt' END;")
        conn.commit()
        conn.close()
        print("[OK] SQLite: Đã thêm và cập nhật cột vn_relevance_status.")
    except Exception as e:
        print("[WARN] SQLite:", e)

if __name__ == "__main__":
    run()

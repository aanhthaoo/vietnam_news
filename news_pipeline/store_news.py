"""
store_news.py
=============
Bước 2 - Load: Thiết kế schema, đánh chỉ mục và lưu bài báo vào CSDL quan hệ.
Hỗ trợ PostgreSQL (primary) và SQLite (fallback).
"""

import json
import logging
import os
import sys
import sqlite3
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / os.getenv("NEWS_DB_PATH", "vietnam_news.db")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:vietnam_news_password@localhost:5432/vietnam_news")

_use_postgres = False
try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    # Kiểm tra thử kết nối PostgreSQL
    _test_conn = psycopg2.connect(DATABASE_URL, connect_timeout=3)
    _test_conn.close()
    _use_postgres = True
    logger.info("[DB] Đang sử dụng PostgreSQL RDBMS.")
except Exception as _e:
    _use_postgres = False
    logger.info(f"[DB] Không kết nối được PostgreSQL ({_e}). Sử dụng SQLite fallback.")


def is_postgres() -> bool:
    """Kiểm tra chế độ DB hiện tại."""
    return _use_postgres


def get_pg_connection():
    """Trả về kết nối PostgreSQL."""
    return psycopg2.connect(DATABASE_URL)


def get_sqlite_connection() -> sqlite3.Connection:
    """Trả về kết nối SQLite."""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def create_table() -> None:
    """
    Tạo bảng news_vietnam_articles, news_volume_forecast, các index và views BI.
    Chạy idempotent — an toàn khi gọi nhiều lần.
    """
    if _use_postgres:
        ddl_table = """
        CREATE TABLE IF NOT EXISTS news_vietnam_articles (
            id                      SERIAL PRIMARY KEY,
            title                   VARCHAR(1000) NOT NULL,
            description             TEXT,
            content                 TEXT,
            url                     TEXT UNIQUE,
            source_name             VARCHAR(500),
            author                  TEXT,
            published_at            TIMESTAMP,
            collected_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            sentiment_label         VARCHAR(50),
            sentiment_score         NUMERIC(8,4),
            entities_org            TEXT,
            entities_gpe            TEXT,
            entities_person         TEXT,
            vader_compound          NUMERIC(8,4) DEFAULT 0.0,
            vader_label             VARCHAR(50),
            ensemble_sentiment_label VARCHAR(50),
            vietnam_relevance_score INTEGER DEFAULT 0,
            is_vietnam_relevant     INTEGER DEFAULT 0,
            topic_label             VARCHAR(100) DEFAULT 'General',
            topic_confidence        NUMERIC(8,4) DEFAULT 0.0,
            ai_summary              TEXT,
            word_count              INTEGER DEFAULT 0
        );
        """
        ddl_forecast_table = """
        CREATE TABLE IF NOT EXISTS news_volume_forecast (
            id              SERIAL PRIMARY KEY,
            forecast_date   VARCHAR(50) UNIQUE,
            predicted_count NUMERIC(8,2),
            lower_bound     NUMERIC(8,2),
            upper_bound     NUMERIC(8,2),
            model_type      VARCHAR(100),
            created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
        ddl_migrations = [
            "ALTER TABLE news_vietnam_articles ALTER COLUMN author TYPE TEXT;",
            "ALTER TABLE news_vietnam_articles ALTER COLUMN source_name TYPE VARCHAR(500);",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS vader_compound NUMERIC(8,4) DEFAULT 0.0;",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS vader_label VARCHAR(50);",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS ensemble_sentiment_label VARCHAR(50);",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS vietnam_relevance_score INTEGER DEFAULT 0;",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS is_vietnam_relevant INTEGER DEFAULT 0;",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS topic_label VARCHAR(100) DEFAULT 'General';",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS topic_confidence NUMERIC(8,4) DEFAULT 0.0;",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS ai_summary TEXT;",
            "ALTER TABLE news_vietnam_articles ADD COLUMN IF NOT EXISTS word_count INTEGER DEFAULT 0;",
        ]
        ddl_indexes = [
            "CREATE INDEX IF NOT EXISTS idx_news_published_at ON news_vietnam_articles(published_at);",
            "CREATE INDEX IF NOT EXISTS idx_news_source_name  ON news_vietnam_articles(source_name);",
            "CREATE INDEX IF NOT EXISTS idx_news_sentiment    ON news_vietnam_articles(sentiment_label);",
            "CREATE INDEX IF NOT EXISTS idx_news_collected_at ON news_vietnam_articles(collected_at);",
            "CREATE INDEX IF NOT EXISTS idx_news_topic        ON news_vietnam_articles(topic_label);",
            "CREATE INDEX IF NOT EXISTS idx_news_vn_relevant  ON news_vietnam_articles(is_vietnam_relevant);",
            "CREATE INDEX IF NOT EXISTS idx_news_ensemble     ON news_vietnam_articles(ensemble_sentiment_label);",
        ]
        ddl_views = [
            "CREATE OR REPLACE VIEW news_articles AS SELECT * FROM news_vietnam_articles;",
            "CREATE OR REPLACE VIEW vw_vietnam_relevant AS SELECT * FROM news_vietnam_articles WHERE is_vietnam_relevant = 1;",
            "CREATE OR REPLACE VIEW vw_topic_summary AS SELECT topic_label, COUNT(*) AS article_count, ROUND(AVG(COALESCE(sentiment_score, 0)), 4) AS avg_sentiment FROM news_vietnam_articles GROUP BY topic_label;",
            "CREATE OR REPLACE VIEW vw_sentiment_ensemble AS SELECT ensemble_sentiment_label, COUNT(*) AS count FROM news_vietnam_articles GROUP BY ensemble_sentiment_label;",
        ]
        conn = get_pg_connection()
        conn.autocommit = True
        try:
            with conn.cursor() as cur:
                cur.execute(ddl_table)
                cur.execute(ddl_forecast_table)
                for mig_sql in ddl_migrations:
                    try:
                        cur.execute(mig_sql)
                    except Exception:
                        pass
                for idx_sql in ddl_indexes:
                    try:
                        cur.execute(idx_sql)
                    except Exception:
                        pass
                for v_sql in ddl_views:
                    try:
                        cur.execute(v_sql)
                    except Exception:
                        pass
        finally:
            conn.close()
        print("[DB] [OK] PostgreSQL Schema, Forecast Table & Views ready.")

    # Luôn đồng bộ SQLite (fallback và phục vụ kiểm định dữ liệu Người 5)
    try:
        ddl_table = """
        CREATE TABLE IF NOT EXISTS news_vietnam_articles (
            id                      INTEGER PRIMARY KEY AUTOINCREMENT,
            title                   TEXT NOT NULL,
            description             TEXT,
            content                 TEXT,
            url                     TEXT UNIQUE,
            source_name             TEXT,
            author                  TEXT,
            published_at            DATETIME,
            collected_at            DATETIME DEFAULT (datetime('now','localtime')),
            sentiment_label         TEXT,
            sentiment_score         REAL,
            entities_org            TEXT,
            entities_gpe            TEXT,
            entities_person         TEXT,
            vader_compound          REAL DEFAULT 0.0,
            vader_label             TEXT,
            ensemble_sentiment_label TEXT,
            vietnam_relevance_score INTEGER DEFAULT 0,
            is_vietnam_relevant     INTEGER DEFAULT 0,
            topic_label             TEXT DEFAULT 'General',
            topic_confidence        REAL DEFAULT 0.0,
            ai_summary              TEXT,
            word_count              INTEGER DEFAULT 0
        );
        """
        ddl_forecast_table = """
        CREATE TABLE IF NOT EXISTS news_volume_forecast (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            forecast_date   TEXT UNIQUE,
            predicted_count REAL,
            lower_bound     REAL,
            upper_bound     REAL,
            model_type      TEXT,
            created_at      TEXT
        );
        """
        ddl_indexes = [
            "CREATE INDEX IF NOT EXISTS idx_news_published_at  ON news_vietnam_articles(published_at);",
            "CREATE INDEX IF NOT EXISTS idx_news_source_name   ON news_vietnam_articles(source_name);",
            "CREATE INDEX IF NOT EXISTS idx_news_sentiment     ON news_vietnam_articles(sentiment_label);",
            "CREATE INDEX IF NOT EXISTS idx_news_collected_at  ON news_vietnam_articles(collected_at);",
            "CREATE INDEX IF NOT EXISTS idx_news_topic         ON news_vietnam_articles(topic_label);",
            "CREATE INDEX IF NOT EXISTS idx_news_vn_relevant   ON news_vietnam_articles(is_vietnam_relevant);",
            "CREATE INDEX IF NOT EXISTS idx_news_ensemble      ON news_vietnam_articles(ensemble_sentiment_label);",
        ]
        views = [
            "CREATE VIEW IF NOT EXISTS news_articles AS SELECT * FROM news_vietnam_articles;",
            "CREATE VIEW IF NOT EXISTS vw_vietnam_relevant AS SELECT * FROM news_vietnam_articles WHERE is_vietnam_relevant = 1;",
            "CREATE VIEW IF NOT EXISTS vw_topic_summary AS SELECT topic_label, COUNT(*) AS article_count, ROUND(AVG(COALESCE(sentiment_score, 0)), 4) AS avg_sentiment FROM news_vietnam_articles GROUP BY topic_label;",
            "CREATE VIEW IF NOT EXISTS vw_sentiment_ensemble AS SELECT ensemble_sentiment_label, COUNT(*) AS count FROM news_vietnam_articles GROUP BY ensemble_sentiment_label;",
        ]
        with get_sqlite_connection() as conn:
            conn.execute(ddl_table)
            conn.execute(ddl_forecast_table)
            cursor = conn.cursor()
            cursor.execute("PRAGMA table_info(news_vietnam_articles);")
            existing_cols = {row[1] for row in cursor.fetchall()}
            new_cols = [
                ("vader_compound", "REAL DEFAULT 0.0"),
                ("vader_label", "TEXT"),
                ("ensemble_sentiment_label", "TEXT"),
                ("vietnam_relevance_score", "INTEGER DEFAULT 0"),
                ("is_vietnam_relevant", "INTEGER DEFAULT 0"),
                ("topic_label", "TEXT DEFAULT 'General'"),
                ("topic_confidence", "REAL DEFAULT 0.0"),
                ("ai_summary", "TEXT"),
                ("word_count", "INTEGER DEFAULT 0"),
            ]
            for col_name, col_def in new_cols:
                if col_name not in existing_cols:
                    try:
                        conn.execute(f"ALTER TABLE news_vietnam_articles ADD COLUMN {col_name} {col_def};")
                    except Exception as e:
                        logger.warning(f"[DB] SQLite add column {col_name}: {e}")
            for idx_sql in ddl_indexes:
                conn.execute(idx_sql)
            for v_sql in views:
                try:
                    conn.execute(v_sql)
                except Exception:
                    pass
            conn.commit()
        print(f"[DB] [OK] SQLite Schema, Forecast Table & Views ready: {DB_PATH}")
    except Exception as e:
        logger.warning(f"[DB] Không thể khởi tạo SQLite: {e}")


def save_articles(articles: list[dict]) -> dict:
    """Lưu danh sách bài báo đã được enrich vào CSDL. Tránh duplicate bằng UNIQUE url."""
    if not articles:
        return {"inserted": 0, "skipped": 0, "total": 0}

    inserted = skipped = 0

    if _use_postgres:
        sql = """
        INSERT INTO news_vietnam_articles
            (title, description, content, url, source_name, author,
             published_at, sentiment_label, sentiment_score,
             entities_org, entities_gpe, entities_person,
             vader_compound, vader_label, ensemble_sentiment_label,
             vietnam_relevance_score, is_vietnam_relevant,
             topic_label, topic_confidence, ai_summary, word_count)
        VALUES
            (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (url) DO UPDATE SET
            vader_compound          = EXCLUDED.vader_compound,
            vader_label             = EXCLUDED.vader_label,
            ensemble_sentiment_label = EXCLUDED.ensemble_sentiment_label,
            vietnam_relevance_score = EXCLUDED.vietnam_relevance_score,
            is_vietnam_relevant     = EXCLUDED.is_vietnam_relevant,
            topic_label             = EXCLUDED.topic_label,
            topic_confidence        = EXCLUDED.topic_confidence,
            ai_summary              = EXCLUDED.ai_summary,
            word_count              = EXCLUDED.word_count;
        """
        with get_pg_connection() as conn:
            with conn.cursor() as cur:
                for article in articles:
                    vals = (
                        (article.get("title") or "Untitled")[:1000],
                        article.get("description") or "",
                        article.get("content") or "",
                        article.get("url") or "",
                        (article.get("source_name") or "Unknown")[:500],
                        article.get("author") or "",
                        article.get("published_at") if article.get("published_at") else None,
                        (article.get("sentiment_label") or "Neutral")[:50],
                        article.get("sentiment_score", 0.0),
                        json.dumps(article.get("entities_org", []), ensure_ascii=False),
                        json.dumps(article.get("entities_gpe", []), ensure_ascii=False),
                        json.dumps(article.get("entities_person", []), ensure_ascii=False),
                        article.get("vader_compound", 0.0),
                        article.get("vader_label", "Neutral"),
                        article.get("ensemble_sentiment_label", "Neutral"),
                        article.get("vietnam_relevance_score", 0),
                        article.get("is_vietnam_relevant", 0),
                        article.get("topic_label", "General"),
                        article.get("topic_confidence", 0.0),
                        article.get("ai_summary", ""),
                        article.get("word_count", 0),
                    )
                    cur.execute(sql, vals)
                    if cur.rowcount > 0:
                        inserted += 1
                    else:
                        skipped += 1
            conn.commit()
        print(f"[DB] [OK] PostgreSQL Saved: {inserted} new/updated | {skipped} unchanged | Total: {len(articles)}")
    else:
        sql = """
        INSERT INTO news_vietnam_articles
            (title, description, content, url, source_name, author,
             published_at, sentiment_label, sentiment_score,
             entities_org, entities_gpe, entities_person,
             vader_compound, vader_label, ensemble_sentiment_label,
             vietnam_relevance_score, is_vietnam_relevant,
             topic_label, topic_confidence, ai_summary, word_count)
        VALUES
            (:title, :description, :content, :url, :source_name, :author,
             :published_at, :sentiment_label, :sentiment_score,
             :entities_org, :entities_gpe, :entities_person,
             :vader_compound, :vader_label, :ensemble_sentiment_label,
             :vietnam_relevance_score, :is_vietnam_relevant,
             :topic_label, :topic_confidence, :ai_summary, :word_count)
        ON CONFLICT(url) DO UPDATE SET
            sentiment_label         = excluded.sentiment_label,
            sentiment_score         = excluded.sentiment_score,
            vader_compound          = excluded.vader_compound,
            vader_label             = excluded.vader_label,
            ensemble_sentiment_label = excluded.ensemble_sentiment_label,
            vietnam_relevance_score = excluded.vietnam_relevance_score,
            is_vietnam_relevant     = excluded.is_vietnam_relevant,
            topic_label             = excluded.topic_label,
            topic_confidence        = excluded.topic_confidence,
            ai_summary              = excluded.ai_summary,
            word_count              = excluded.word_count;
        """
        with get_sqlite_connection() as conn:
            for article in articles:
                row = {
                    "title":                   (article.get("title") or "Untitled")[:1000],
                    "description":             article.get("description") or "",
                    "content":                 article.get("content") or "",
                    "url":                     article.get("url") or "",
                    "source_name":             (article.get("source_name") or "Unknown")[:500],
                    "author":                  article.get("author") or "",
                    "published_at":            article.get("published_at") or "",
                    "sentiment_label":         (article.get("sentiment_label") or "Neutral")[:50],
                    "sentiment_score":         article.get("sentiment_score", 0.0),
                    "entities_org":            json.dumps(article.get("entities_org", []), ensure_ascii=False),
                    "entities_gpe":            json.dumps(article.get("entities_gpe", []), ensure_ascii=False),
                    "entities_person":         json.dumps(article.get("entities_person", []), ensure_ascii=False),
                    "vader_compound":          article.get("vader_compound", 0.0),
                    "vader_label":             (article.get("vader_label") or "Neutral")[:50],
                    "ensemble_sentiment_label":(article.get("ensemble_sentiment_label") or "Neutral")[:50],
                    "vietnam_relevance_score": article.get("vietnam_relevance_score", 0),
                    "is_vietnam_relevant":     article.get("is_vietnam_relevant", 0),
                    "topic_label":             (article.get("topic_label") or "General")[:100],
                    "topic_confidence":        article.get("topic_confidence", 0.0),
                    "ai_summary":              article.get("ai_summary") or "",
                    "word_count":              article.get("word_count", 0),
                }
                cursor = conn.execute(sql, row)
                if cursor.rowcount > 0:
                    inserted += 1
                else:
                    skipped += 1
            conn.commit()
        print(f"[DB] [OK] SQLite Saved: {inserted} new/updated | {skipped} unchanged | Total: {len(articles)}")

    return {"inserted": inserted, "skipped": skipped, "total": len(articles)}


def get_stats() -> dict:
    """Trả về thống kê nhanh từ bảng news_vietnam_articles."""
    if _use_postgres:
        with get_pg_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) FROM news_vietnam_articles")
                total = cur.fetchone()[0]
                cur.execute("SELECT ensemble_sentiment_label, COUNT(*) FROM news_vietnam_articles GROUP BY ensemble_sentiment_label")
                sentiment = cur.fetchall()
                cur.execute("SELECT topic_label, COUNT(*) FROM news_vietnam_articles GROUP BY topic_label")
                topics = cur.fetchall()
                cur.execute("SELECT COUNT(*) FROM news_vietnam_articles WHERE is_vietnam_relevant = 1")
                vn_relevant = cur.fetchone()[0]
                cur.execute("SELECT COUNT(DISTINCT source_name) FROM news_vietnam_articles")
                sources = cur.fetchone()[0]
                cur.execute("SELECT published_at FROM news_vietnam_articles ORDER BY published_at DESC LIMIT 1")
                latest = cur.fetchone()
        return {
            "db_type": "PostgreSQL",
            "total_articles": total,
            "total_sources": sources,
            "vietnam_relevant_count": vn_relevant,
            "latest_article": str(latest[0]) if latest else None,
            "sentiment_breakdown": {row[0]: row[1] for row in sentiment},
            "topic_breakdown": {row[0]: row[1] for row in topics},
        }
    else:
        with get_sqlite_connection() as conn:
            total = conn.execute("SELECT COUNT(*) FROM news_vietnam_articles").fetchone()[0]
            sentiment = conn.execute(
                "SELECT ensemble_sentiment_label, COUNT(*) FROM news_vietnam_articles GROUP BY ensemble_sentiment_label"
            ).fetchall()
            topics = conn.execute(
                "SELECT topic_label, COUNT(*) FROM news_vietnam_articles GROUP BY topic_label"
            ).fetchall()
            vn_relevant = conn.execute(
                "SELECT COUNT(*) FROM news_vietnam_articles WHERE is_vietnam_relevant = 1"
            ).fetchone()[0]
            sources = conn.execute(
                "SELECT COUNT(DISTINCT source_name) FROM news_vietnam_articles"
            ).fetchone()[0]
            latest = conn.execute(
                "SELECT published_at FROM news_vietnam_articles ORDER BY published_at DESC LIMIT 1"
            ).fetchone()
        return {
            "db_type": "SQLite",
            "total_articles": total,
            "total_sources": sources,
            "vietnam_relevant_count": vn_relevant,
            "latest_article": latest[0] if latest else None,
            "sentiment_breakdown": {row[0]: row[1] for row in sentiment},
            "topic_breakdown": {row[0]: row[1] for row in topics},
        }


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    logging.basicConfig(level=logging.INFO)
    create_table()
    print(f"\n[DB] Stats: {get_stats()}")


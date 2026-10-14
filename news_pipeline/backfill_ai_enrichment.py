"""
news_pipeline/backfill_ai_enrichment.py
======================================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu: Quét toàn bộ các bài báo đã có trong Database (PostgreSQL & SQLite) và
chạy lại cụm mô hình AI (VADER Ensemble, Vietnam Relevance, Topic Classifier, Summarizer)
để cập nhật các cột dữ liệu mới phục vụ Dashboard Superset.
"""

import sys
import logging
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres, DB_PATH
from news_pipeline.transform_news import transform_article

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s]: %(message)s")
logger = logging.getLogger(__name__)


def backfill_postgres():
    """Làm giàu lại các bài báo trong PostgreSQL."""
    conn = get_pg_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, title, description, content, url, source_name, author, published_at
                FROM news_vietnam_articles
                ORDER BY id ASC;
            """)
            rows = cur.fetchall()
            print(f"[PostgreSQL] Tìm thấy {len(rows)} bài báo cần kiểm tra / làm giàu AI...")

            updated = 0
            update_sql = """
            UPDATE news_vietnam_articles SET
                sentiment_label = %s,
                sentiment_score = %s,
                vader_compound = %s,
                vader_label = %s,
                ensemble_sentiment_label = %s,
                vietnam_relevance_score = %s,
                is_vietnam_relevant = %s,
                topic_label = %s,
                topic_confidence = %s,
                ai_summary = %s,
                word_count = %s
            WHERE id = %s;
            """
            for r in rows:
                art = {
                    "title": r[1] or "",
                    "description": r[2] or "",
                    "content": r[3] or "",
                    "url": r[4] or "",
                    "source_name": r[5] or "",
                    "author": r[6] or "",
                    "published_at": r[7]
                }
                enriched = transform_article(art)
                cur.execute(update_sql, (
                    enriched.get("sentiment_label", "Neutral"),
                    enriched.get("sentiment_score", 0.0),
                    enriched.get("vader_compound", 0.0),
                    enriched.get("vader_label", "Neutral"),
                    enriched.get("ensemble_sentiment_label", "Neutral"),
                    enriched.get("vietnam_relevance_score", 0),
                    enriched.get("is_vietnam_relevant", 0),
                    enriched.get("topic_label", "General"),
                    enriched.get("topic_confidence", 0.0),
                    enriched.get("ai_summary", ""),
                    enriched.get("word_count", 0),
                    r[0]
                ))
                updated += 1
                if updated % 20 == 0:
                    print(f"[PostgreSQL] ⚙️  Đã làm giàu {updated}/{len(rows)} bài...")
            conn.commit()
            print(f"✅ [PostgreSQL] Đã cập nhật AI thành công {updated} bài báo!")
    finally:
        conn.close()


def backfill_sqlite():
    """Làm giàu lại các bài báo trong SQLite."""
    conn = get_sqlite_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, title, description, content, url, source_name, author, published_at
            FROM news_vietnam_articles
            ORDER BY id ASC;
        """)
        rows = cursor.fetchall()
        print(f"[SQLite] Tìm thấy {len(rows)} bài báo trong {DB_PATH}...")

        updated = 0
        update_sql = """
        UPDATE news_vietnam_articles SET
            sentiment_label = :sentiment_label,
            sentiment_score = :sentiment_score,
            vader_compound = :vader_compound,
            vader_label = :vader_label,
            ensemble_sentiment_label = :ensemble_sentiment_label,
            vietnam_relevance_score = :vietnam_relevance_score,
            is_vietnam_relevant = :is_vietnam_relevant,
            topic_label = :topic_label,
            topic_confidence = :topic_confidence,
            ai_summary = :ai_summary,
            word_count = :word_count
        WHERE id = :id;
        """
        for r in rows:
            art = {
                "title": r["title"] or "",
                "description": r["description"] or "",
                "content": r["content"] or "",
                "url": r["url"] or "",
                "source_name": r["source_name"] or "",
                "author": r["author"] or "",
                "published_at": r["published_at"]
            }
            enriched = transform_article(art)
            cursor.execute(update_sql, {
                "sentiment_label": enriched.get("sentiment_label", "Neutral"),
                "sentiment_score": enriched.get("sentiment_score", 0.0),
                "vader_compound": enriched.get("vader_compound", 0.0),
                "vader_label": enriched.get("vader_label", "Neutral"),
                "ensemble_sentiment_label": enriched.get("ensemble_sentiment_label", "Neutral"),
                "vietnam_relevance_score": enriched.get("vietnam_relevance_score", 0),
                "is_vietnam_relevant": enriched.get("is_vietnam_relevant", 0),
                "topic_label": enriched.get("topic_label", "General"),
                "topic_confidence": enriched.get("topic_confidence", 0.0),
                "ai_summary": enriched.get("ai_summary", ""),
                "word_count": enriched.get("word_count", 0),
                "id": r["id"]
            })
            updated += 1
        conn.commit()
        print(f"✅ [SQLite] Đã cập nhật AI thành công {updated} bài báo!")
    finally:
        conn.close()


if __name__ == "__main__":
    print("=" * 60)
    print("🚀 BẮT ĐẦU BACKFILL CẬP NHẬT CÁC CỘT AI CHO DỮ LIỆU HIỆN CÓ")
    print("=" * 60)
    if is_postgres():
        backfill_postgres()
    backfill_sqlite()
    print("=" * 60)
    print("🎉 Hoàn tất quá trình đồng bộ AI cho cơ sở dữ liệu!")
    print("=" * 60)

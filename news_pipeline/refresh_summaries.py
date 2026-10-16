"""
news_pipeline/refresh_summaries.py
==================================
Cập nhật lại toàn bộ cột `ai_summary` cho các bài báo trong CSDL
bằng thuật toán Vietnam-Context Centric Summarization.
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

from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres
from ai_models.text_summarizer import summarize_article

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def update_all_summaries():
    print("--- CẬP NHẬT TÓM TẮT ĐỊNH HƯỚNG BỐI CẢNH VIỆT NAM (AI SUMMARY REFRESH) ---")
    
    # 1. Đọc dữ liệu từ DB
    if is_postgres():
        conn = get_pg_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, title, description, content FROM news_vietnam_articles ORDER BY id ASC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
    else:
        conn = get_sqlite_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, title, description, content FROM news_vietnam_articles ORDER BY id ASC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()

    total = len(rows)
    print(f"Tổng số bài báo cần cập nhật tóm tắt: {total}")

    updates = []
    for r in rows:
        a_id = r[0]
        title = r[1] or ""
        desc = r[2] or ""
        content = r[3] or ""
        full_text = f"{desc} {content}".strip()
        new_summary = summarize_article(title, full_text)
        updates.append((new_summary, a_id))

    # 2. Cập nhật vào PostgreSQL
    if is_postgres():
        conn = get_pg_connection()
        conn.autocommit = True
        with conn.cursor() as cur:
            for summary, a_id in updates:
                cur.execute("UPDATE news_vietnam_articles SET ai_summary = %s WHERE id = %s;", (summary, a_id))
        conn.close()
        print(f"[OK] Đã cập nhật {total} bài báo trong PostgreSQL.")

    # 3. Cập nhật vào SQLite
    try:
        conn = get_sqlite_connection()
        with conn:
            for summary, a_id in updates:
                conn.execute("UPDATE news_vietnam_articles SET ai_summary = ? WHERE id = ?;", (summary, a_id))
        conn.close()
        print(f"[OK] Đã cập nhật {total} bài báo trong SQLite.")
    except Exception as e:
        logger.warning(f"Lỗi cập nhật SQLite: {e}")

    # Xem thử 3 mẫu
    print("\n--- XEM THỬ 3 BẢN TÓM TẮT MỚI ---")
    for summary, a_id in updates[:3]:
        print(f"ID #{a_id}: {summary}\n")


if __name__ == "__main__":
    update_all_summaries()

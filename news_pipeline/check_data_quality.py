"""
news_pipeline/check_data_quality.py
===================================
Phụ trách: Thành viên 5 (Data Quality Assurance)
Mục tiêu: Kiểm định tính toàn vẹn và chất lượng dữ liệu trong CSDL SQLite trước khi tải lên Dashboard Superset.
"""

import sqlite3
import os
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / "vietnam_news.db"
sys.path.insert(0, str(BASE_DIR))


def run_data_quality_check():
    """
    Kiểm tra tính toàn vẹn và chất lượng dữ liệu trong PostgreSQL hoặc SQLite database.
    """
    is_pg = False
    conn = None

    try:
        from news_pipeline.store_news import is_postgres, get_pg_connection
        if is_postgres():
            conn = get_pg_connection()
            is_pg = True
            print("[INFO] Đang kết nối tới: PostgreSQL Database")
    except Exception as e:
        is_pg = False

    if not conn:
        if not os.path.exists(DB_PATH):
            print(f"[LỖI] Không tìm thấy cơ sở dữ liệu PostgreSQL lẫn file SQLite tại: {DB_PATH}")
            return
        conn = sqlite3.connect(str(DB_PATH))
        print(f"[INFO] Đang kết nối tới: SQLite Database ({DB_PATH.name})")

    cursor = conn.cursor()

    print("=" * 65)
    print("      BÁO CÁO KIỂM ĐỊNH CHẤT LƯỢNG DỮ LIỆU (BI DATA QUALITY)")
    print("=" * 65)

    target_table = "news_vietnam_articles"
    if is_pg:
        cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public';")
        tables = [row[0] for row in cursor.fetchall()]
    else:
        cursor.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name LIKE 'news_%';")
        tables = [row[0] for row in cursor.fetchall()]

    if "news_vietnam_articles" not in tables and "news_articles" in tables:
        target_table = "news_articles"
    elif "news_vietnam_articles" not in tables and len(tables) > 0:
        target_table = tables[0]

    print(f"[INFO] Bảng dữ liệu đang kiểm tra: '{target_table}'")

    # 1. Tổng số bài báo
    try:
        cursor.execute(f"SELECT COUNT(*) FROM {target_table}")
        total_articles = cursor.fetchone()[0]
    except Exception as e:
        print(f"[LỖI] Không truy vấn được bảng {target_table}: {e}")
        conn.close()
        return

    print(f"1. Tổng số bài báo thu thập được: {total_articles} bản ghi")

    if total_articles == 0:
        print("[CẢNH BÁO] Database đang rỗng! Hãy chạy pipeline để cào dữ liệu.")
        conn.close()
        return

    # Lấy danh sách cột của bảng
    if is_pg:
        cursor.execute(f"SELECT column_name FROM information_schema.columns WHERE table_name = '{target_table}';")
        columns = [col[0] for col in cursor.fetchall()]
    else:
        cursor.execute(f"PRAGMA table_info({target_table})")
        columns = [col[1] for col in cursor.fetchall()]

    # 2. Kiểm tra độ hoàn thiện dữ liệu (Missing Values)
    cursor.execute(f"SELECT COUNT(*) FROM {target_table} WHERE title IS NULL OR title = ''")
    missing_title = cursor.fetchone()[0]

    cursor.execute(f"SELECT COUNT(*) FROM {target_table} WHERE description IS NULL OR description = ''")
    missing_desc = cursor.fetchone()[0]

    missing_sentiment = 0
    if "sentiment_label" in columns:
        cursor.execute(f"SELECT COUNT(*) FROM {target_table} WHERE sentiment_label IS NULL")
        missing_sentiment = cursor.fetchone()[0]

    print("\n2. Kiểm tra độ hoàn thiện dữ liệu (Missing Values):")
    print(f"   - Thiếu tiêu đề:         {missing_title} bản ghi")
    print(f"   - Thiếu mô tả:           {missing_desc} bản ghi")
    print(f"   - Chưa gán nhãn cảm xúc: {missing_sentiment} bản ghi")

    # 3. Phân bố sắc thái (Sentiment Breakdown)
    if "sentiment_label" in columns:
        print("\n3. Phân bố sắc thái cảm xúc (TextBlob Sentiment):")
        cursor.execute(f"SELECT sentiment_label, COUNT(*) FROM {target_table} GROUP BY sentiment_label")
        for label, count in cursor.fetchall():
            pct = (count / total_articles) * 100
            print(f"   - {label or 'Chưa phân loại'}: {count} bài ({pct:.1f}%)")

    # 4. Phân bố sắc thái Ensemble (nếu đã có cột)
    if "ensemble_sentiment_label" in columns:
        print("\n4. Phân bố sắc thái Ensemble (VADER + TextBlob):")
        cursor.execute(f"SELECT ensemble_sentiment_label, COUNT(*) FROM {target_table} GROUP BY ensemble_sentiment_label")
        for label, count in cursor.fetchall():
            pct = (count / total_articles) * 100
            print(f"   - {label or 'Chưa phân loại'}: {count} bài ({pct:.1f}%)")

    # 5. Phân loại chủ đề (Topic Distribution)
    if "topic_label" in columns:
        print("\n5. Phân bố chủ đề tin tức (Topics):")
        cursor.execute(f"SELECT topic_label, COUNT(*) FROM {target_table} GROUP BY topic_label ORDER BY COUNT(*) DESC")
        for topic, count in cursor.fetchall():
            pct = (count / total_articles) * 100
            print(f"   - {topic or 'General'}: {count} bài ({pct:.1f}%)")

    # 6. Độ liên quan Việt Nam
    if "is_vietnam_relevant" in columns:
        cursor.execute(f"SELECT is_vietnam_relevant, COUNT(*) FROM {target_table} GROUP BY is_vietnam_relevant")
        print("\n6. Mức độ liên quan đến Việt Nam:")
        for rel, count in cursor.fetchall():
            status = "Chuẩn tin VN" if rel == 1 else "Tin nhắc lướt / Ngoài lề"
            pct = (count / total_articles) * 100
            print(f"   - {status}: {count} bài ({pct:.1f}%)")

    # 7. Top nguồn báo
    if "source_name" in columns:
        print("\n7. Top 5 nguồn báo phổ biến nhất:")
        cursor.execute(f"""
            SELECT source_name, COUNT(*) as cnt 
            FROM {target_table} 
            GROUP BY source_name 
            ORDER BY cnt DESC 
            LIMIT 5
        """)
        for rank, (src, cnt) in enumerate(cursor.fetchall(), 1):
            print(f"   {rank}. {src}: {cnt} bài")

    print("=" * 65)
    print("✅ [KẾT QUẢ] Đã hoàn thành kiểm định chất lượng dữ liệu!")
    print("=" * 65)

    conn.close()


if __name__ == "__main__":
    run_data_quality_check()

"""
news_pipeline/check_data_quality.py
===================================
Phụ trách: Thành viên 5 (Data Quality Assurance) - Thương

Kiểm định chất lượng dữ liệu bảng news_vietnam_articles và in báo cáo ra terminal.

Kết nối CSDL:
  - Ưu tiên PostgreSQL (Docker) qua biến DATABASE_URL trong file .env
    (mặc định: postgresql://postgres:vietnam_news_password@localhost:5432/vietnam_news)
  - Nếu không kết nối được PostgreSQL -> dùng SQLite fallback (vietnam_news.db)

Chỉ dùng câu lệnh SELECT (read-only), không thay đổi dữ liệu.

Các mục kiểm định:
  1. Tổng quan: tổng số bài, số nguồn báo, khoảng thời gian xuất bản
  2. Độ hoàn thiện dữ liệu (Missing Values) theo từng cột quan trọng
  3. Tính duy nhất (Uniqueness): URL trùng, tiêu đề trùng
  4. Tính hợp lệ (Validity): nhãn cảm xúc, điểm cảm xúc, ngày xuất bản
  5. Phân bố sắc thái cảm xúc (Ensemble Sentiment)
  6. Phân bố chủ đề (topic_label)
  7. Tỷ lệ bài viết chuẩn Việt Nam (is_vietnam_relevant)
  8. Top 5 nguồn báo xuất hiện nhiều nhất
  9. Tổng kết PASS / WARN / FAIL

Cách chạy (tại thư mục gốc dự án, Docker đang chạy):
  pip install psycopg2-binary python-dotenv
  python news_pipeline/check_data_quality.py
"""

import os
import sqlite3
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

BASE_DIR = Path(__file__).resolve().parent.parent
DB_PATH = BASE_DIR / os.getenv("NEWS_DB_PATH", "vietnam_news.db")
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:vietnam_news_password@localhost:5432/vietnam_news",
)
TABLE = "news_vietnam_articles"

# Ngưỡng đánh giá chất lượng
MISSING_WARN_PCT = 5.0    # > 5% thiếu -> WARN
MISSING_FAIL_PCT = 20.0   # > 20% thiếu -> FAIL
MIN_ARTICLES = 100        # ít hơn 100 bài -> WARN
VALID_SENTIMENTS = ("Positive", "Negative", "Neutral")

LINE = "=" * 65
SUB = "-" * 65


# ==============================================================================
# KẾT NỐI CSDL
# ==============================================================================
def get_connection():
    """
    Trả về (connection, tên_loại_db).
    Thử PostgreSQL trước, nếu lỗi thì chuyển sang SQLite.
    """
    try:
        import psycopg2

        conn = psycopg2.connect(DATABASE_URL, connect_timeout=5)
        return conn, "PostgreSQL"
    except ImportError:
        print("[CẢNH BÁO] Chưa cài psycopg2 (pip install psycopg2-binary). Thử SQLite...")
    except Exception as e:
        print(f"[CẢNH BÁO] Không kết nối được PostgreSQL: {str(e).strip()}")
        print("           Thử SQLite fallback...")

    if not DB_PATH.exists():
        return None, None
    return sqlite3.connect(str(DB_PATH)), "SQLite"


def fetch_one(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchone()


def fetch_all(cursor, sql):
    cursor.execute(sql)
    return cursor.fetchall()


def pct(part, total):
    return (part * 100.0 / total) if total else 0.0


def bar(percent, width=20):
    filled = int(round(percent / 100 * width))
    return "█" * filled + "░" * (width - filled)


# ==============================================================================
# KIỂM ĐỊNH
# ==============================================================================
def run_data_quality_check():
    """Thực thi kiểm định chất lượng dữ liệu và in báo cáo ra terminal."""
    conn, db_type = get_connection()
    if conn is None:
        print(f"[LỖI] Không kết nối được PostgreSQL và không tìm thấy SQLite tại: {DB_PATH}")
        print("      Hãy chắc chắn Docker đang chạy: docker compose up -d")
        return False

    cursor = conn.cursor()
    results = []  # (tên kiểm tra, trạng thái, ghi chú)

    print(LINE)
    print("      BÁO CÁO KIỂM ĐỊNH CHẤT LƯỢNG DỮ LIỆU (BI DATA QUALITY)")
    print(f"      Cơ sở dữ liệu: {db_type}  |  Bảng: {TABLE}")
    print(LINE)

    try:
        # ----------------------------------------------------------------------
        # 1. TỔNG QUAN
        # ----------------------------------------------------------------------
        total, n_sources, min_date, max_date = fetch_one(
            cursor,
            f"""
            SELECT COUNT(*),
                   COUNT(DISTINCT source_name),
                   MIN(published_at),
                   MAX(published_at)
            FROM {TABLE}
            """,
        )

        print("\n1. TỔNG QUAN DỮ LIỆU")
        print(SUB)
        print(f"   - Tổng số bài báo:        {total}")
        print(f"   - Số nguồn báo khác nhau: {n_sources}")
        print(f"   - Khoảng thời gian:       {str(min_date)[:10]}  →  {str(max_date)[:10]}")

        if total == 0:
            print("\n[LỖI] Bảng không có dữ liệu. Dừng kiểm định.")
            return False

        if total >= MIN_ARTICLES:
            results.append(("Số lượng bài báo", "PASS", f"{total} bài"))
        else:
            results.append(("Số lượng bài báo", "WARN", f"chỉ {total} bài (< {MIN_ARTICLES})"))

        # ----------------------------------------------------------------------
        # 2. MISSING VALUES
        # ----------------------------------------------------------------------
        checks = {
            "title": "Tiêu đề",
            "description": "Mô tả",
            "content": "Nội dung",
            "author": "Tác giả",
            "source_name": "Nguồn báo",
            "url": "URL",
            "published_at": "Ngày xuất bản",
            "ensemble_sentiment_label": "Nhãn cảm xúc",
            "topic_label": "Chủ đề",
        }
        # Cột kiểu ngày không so sánh được với chuỗi rỗng -> chỉ kiểm tra NULL
        non_text_cols = {"published_at"}

        select_parts = []
        for col in checks:
            if col in non_text_cols:
                cond = f"{col} IS NULL"
            else:
                cond = f"{col} IS NULL OR TRIM({col}) = ''"
            select_parts.append(f"SUM(CASE WHEN {cond} THEN 1 ELSE 0 END)")
        missing_counts = fetch_one(cursor, f"SELECT {', '.join(select_parts)} FROM {TABLE}")

        print("\n2. ĐỘ HOÀN THIỆN DỮ LIỆU (MISSING VALUES)")
        print(SUB)
        print(f"   {'Cột':<16}{'Thiếu':>7}{'Tỷ lệ':>9}   Đánh giá")
        for (col, label), missing in zip(checks.items(), missing_counts):
            missing = int(missing or 0)
            p = pct(missing, total)
            if p > MISSING_FAIL_PCT:
                status = "FAIL"
            elif p > MISSING_WARN_PCT:
                status = "WARN"
            else:
                status = "PASS"
            print(f"   - {label:<14}{missing:>7}{p:>8.1f}%   {status}")
            results.append((f"Thiếu {label.lower()}", status, f"{missing} bài ({p:.1f}%)"))

        # ----------------------------------------------------------------------
        # 3. UNIQUENESS
        # ----------------------------------------------------------------------
        dup_url = fetch_one(
            cursor,
            f"""
            SELECT COUNT(*) FROM (
                SELECT url FROM {TABLE}
                WHERE url IS NOT NULL
                GROUP BY url HAVING COUNT(*) > 1
            ) t
            """,
        )[0]
        dup_title = fetch_one(
            cursor,
            f"""
            SELECT COUNT(*) FROM (
                SELECT LOWER(TRIM(title)) FROM {TABLE}
                WHERE title IS NOT NULL
                GROUP BY LOWER(TRIM(title)) HAVING COUNT(*) > 1
            ) t
            """,
        )[0]

        print("\n3. TÍNH DUY NHẤT (TRÙNG LẶP)")
        print(SUB)
        print(f"   - Số URL bị trùng:        {dup_url}")
        print(f"   - Số tiêu đề bị trùng:    {dup_title}")
        results.append(("URL trùng lặp", "PASS" if dup_url == 0 else "FAIL", f"{dup_url} URL"))
        results.append(("Tiêu đề trùng lặp", "PASS" if dup_title == 0 else "WARN", f"{dup_title} tiêu đề"))

        # ----------------------------------------------------------------------
        # 4. VALIDITY
        # ----------------------------------------------------------------------
        labels_sql = ", ".join(f"'{s}'" for s in VALID_SENTIMENTS)
        invalid_label, score_out_of_range, future_date = fetch_one(
            cursor,
            f"""
            SELECT
                SUM(CASE WHEN ensemble_sentiment_label IS NOT NULL
                          AND ensemble_sentiment_label NOT IN ({labels_sql})
                         THEN 1 ELSE 0 END),
                SUM(CASE WHEN vader_compound < -1 OR vader_compound > 1
                         THEN 1 ELSE 0 END),
                SUM(CASE WHEN published_at > collected_at
                         THEN 1 ELSE 0 END)
            FROM {TABLE}
            """,
        )
        invalid_label = int(invalid_label or 0)
        score_out_of_range = int(score_out_of_range or 0)
        future_date = int(future_date or 0)

        print("\n4. TÍNH HỢP LỆ (VALIDITY)")
        print(SUB)
        print(f"   - Nhãn cảm xúc không hợp lệ:       {invalid_label}")
        print(f"   - Điểm VADER ngoài khoảng [-1, 1]: {score_out_of_range}")
        print(f"   - Ngày xuất bản sau ngày thu thập: {future_date}")
        results.append(("Nhãn cảm xúc hợp lệ", "PASS" if invalid_label == 0 else "FAIL", f"{invalid_label} lỗi"))
        results.append(("Điểm VADER hợp lệ", "PASS" if score_out_of_range == 0 else "FAIL", f"{score_out_of_range} lỗi"))
        results.append(("Ngày xuất bản hợp lệ", "PASS" if future_date == 0 else "WARN", f"{future_date} bài"))

        # ----------------------------------------------------------------------
        # 5. SENTIMENT BREAKDOWN
        # ----------------------------------------------------------------------
        rows = fetch_all(
            cursor,
            f"""
            SELECT COALESCE(ensemble_sentiment_label, '(Chưa gán)') AS label,
                   COUNT(*) AS cnt
            FROM {TABLE}
            GROUP BY COALESCE(ensemble_sentiment_label, '(Chưa gán)')
            ORDER BY cnt DESC
            """,
        )
        print("\n5. PHÂN BỐ SẮC THÁI CẢM XÚC (ENSEMBLE VADER + TEXTBLOB)")
        print(SUB)
        for label, cnt in rows:
            p = pct(cnt, total)
            print(f"   - {label:<14}{cnt:>5} bài  {p:>5.1f}%  {bar(p)}")

        # ----------------------------------------------------------------------
        # 6. TOPIC BREAKDOWN
        # ----------------------------------------------------------------------
        rows = fetch_all(
            cursor,
            f"""
            SELECT COALESCE(topic_label, '(Chưa gán)') AS topic,
                   COUNT(*) AS cnt
            FROM {TABLE}
            GROUP BY COALESCE(topic_label, '(Chưa gán)')
            ORDER BY cnt DESC
            """,
        )
        print("\n6. PHÂN BỐ CHỦ ĐỀ TIN TỨC")
        print(SUB)
        for topic, cnt in rows:
            p = pct(cnt, total)
            print(f"   - {topic:<14}{cnt:>5} bài  {p:>5.1f}%  {bar(p)}")

        general = next((cnt for topic, cnt in rows if topic == "General"), 0)
        general_pct = pct(general, total)
        if general_pct > 50:
            results.append(("Bài chưa phân loại (General)", "WARN", f"{general_pct:.1f}% > 50%"))
        else:
            results.append(("Bài chưa phân loại (General)", "PASS", f"{general_pct:.1f}%"))

        # ----------------------------------------------------------------------
        # 7. VIETNAM RELEVANCE
        # ----------------------------------------------------------------------
        relevant, avg_score = fetch_one(
            cursor,
            f"""
            SELECT SUM(CASE WHEN is_vietnam_relevant = 1 THEN 1 ELSE 0 END),
                   AVG(vietnam_relevance_score)
            FROM {TABLE}
            """,
        )
        relevant = int(relevant or 0)
        avg_score = float(avg_score or 0)
        rel_pct = pct(relevant, total)

        print("\n7. TỶ LỆ BÀI VIẾT CHUẨN VIỆT NAM (is_vietnam_relevant)")
        print(SUB)
        print(f"   - Đạt chuẩn Việt Nam:     {relevant:>5} bài  {rel_pct:>5.1f}%  {bar(rel_pct)}")
        print(f"   - Không đạt chuẩn:        {total - relevant:>5} bài  {100 - rel_pct:>5.1f}%")
        print(f"   - Điểm liên quan TB:      {avg_score:.2f}")

        # ----------------------------------------------------------------------
        # 8. TOP SOURCES
        # ----------------------------------------------------------------------
        rows = fetch_all(
            cursor,
            f"""
            SELECT source_name, COUNT(*) AS cnt
            FROM {TABLE}
            WHERE source_name IS NOT NULL AND TRIM(source_name) <> ''
            GROUP BY source_name
            ORDER BY cnt DESC, source_name
            LIMIT 5
            """,
        )
        print("\n8. TOP 5 NGUỒN BÁO XUẤT HIỆN NHIỀU NHẤT")
        print(SUB)
        for i, (source, cnt) in enumerate(rows, 1):
            print(f"   {i}. {source:<30}{cnt:>4} bài  ({pct(cnt, total):.1f}%)")

        # ----------------------------------------------------------------------
        # 9. SUMMARY
        # ----------------------------------------------------------------------
        n_pass = sum(1 for _, s, _ in results if s == "PASS")
        n_warn = sum(1 for _, s, _ in results if s == "WARN")
        n_fail = sum(1 for _, s, _ in results if s == "FAIL")
        score = pct(n_pass, len(results))

        print("\n9. TỔNG KẾT KIỂM ĐỊNH")
        print(SUB)
        for name, status, note in results:
            if status != "PASS":
                print(f"   [{status}] {name}: {note}")
        print(f"\n   PASS: {n_pass}  |  WARN: {n_warn}  |  FAIL: {n_fail}  "
              f"(tổng {len(results)} kiểm tra)")
        print(f"   Điểm chất lượng dữ liệu: {score:.1f}%  {bar(score)}")

        if n_fail == 0:
            print("   => KẾT LUẬN: Dữ liệu ĐẠT yêu cầu để đưa vào Dashboard BI.")
        else:
            print("   => KẾT LUẬN: Dữ liệu CÓ LỖI cần xử lý trước khi phân tích.")

        print(LINE)
        return n_fail == 0

    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    ok = run_data_quality_check()
    sys.exit(0 if ok else 1)

"""
news_pipeline/check_data_quality.py
===================================
Phụ trách: Thành viên 5 (Data Quality Assurance)
Trạng thái: Template khung sườn (Chờ Thành viên 5 hiện thực logic)

YÊU CẦU ĐẶT RA:
1. Kết nối an toàn vào cơ sở dữ liệu SQLite (vietnam_news.db).
2. Viết các câu truy vấn SQL (chỉ dùng SELECT) để kiểm định chất lượng dữ liệu:
   - Mục 1: Đếm tổng số bài báo hiện có.
   - Mục 2: Kiểm tra tỷ lệ khuyết thiếu dữ liệu (Missing Values: tiêu đề, mô tả, nhãn cảm xúc).
   - Mục 3: Thống kê phân bố sắc thái cảm xúc (Sentiment Breakdown).
   - Mục 4: Thống kê tỷ lệ bài viết chuẩn Việt Nam (is_vietnam_relevant).
   - Mục 5: Thống kê Top các nguồn báo (source_name) thu thập được nhiều nhất.
3. In kết quả báo cáo rõ ràng, trực quan lên màn hình terminal.
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


def run_data_quality_check():
    """
    Hàm thực thi kiểm định chất lượng dữ liệu và in báo cáo ra màn hình terminal.
    """
    if not os.path.exists(DB_PATH):
        print(f"[LỖI] Không tìm thấy file cơ sở dữ liệu tại: {DB_PATH}")
        return

    print("=" * 65)
    print("      BÁO CÁO KIỂM ĐỊNH CHẤT LƯỢNG DỮ LIỆU (BI DATA QUALITY)")
    print("=" * 65)

    # ==========================================================================
    # TODO 1 (Thành viên 5): Mở kết nối tới SQLite DB_PATH và tạo cursor
    # ==========================================================================
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()

    # ==========================================================================
    # TODO 2 (Thành viên 5): Đếm tổng số bài báo trong bảng news_vietnam_articles
    # Câu SQL gợi ý: SELECT COUNT(*) FROM news_vietnam_articles
    # ==========================================================================
    # total_articles = ...
    print("1. Tổng số bài báo thu thập được: [TODO]")

    # ==========================================================================
    # TODO 3 (Thành viên 5): Kiểm tra các bản ghi bị rỗng / null (Missing data)
    # Câu SQL gợi ý: SELECT COUNT(*) FROM news_vietnam_articles WHERE title IS NULL OR title = ''
    # ==========================================================================
    print("\n2. Kiểm tra độ hoàn thiện dữ liệu (Missing Values):")
    print("   - Thiếu tiêu đề: [TODO]")
    print("   - Thiếu mô tả:   [TODO]")

    # ==========================================================================
    # TODO 4 (Thành viên 5): Thống kê phân bố cảm xúc và chủ đề
    # Câu SQL gợi ý: SELECT ensemble_sentiment_label, COUNT(*) FROM news_vietnam_articles GROUP BY ensemble_sentiment_label
    # ==========================================================================
    print("\n3. Phân bố sắc thái cảm xúc & Chủ đề:")
    print("   - [TODO: Lặp qua kết quả GROUP BY để in số lượng và %]")

    # ==========================================================================
    # TODO 5 (Thành viên 5): Thống kê top 5 nguồn báo phổ biến nhất
    # Câu SQL gợi ý: SELECT source_name, COUNT(*) as cnt FROM news_vietnam_articles GROUP BY source_name ORDER BY cnt DESC LIMIT 5
    # ==========================================================================
    print("\n4. Top nguồn báo xuất hiện nhiều nhất:")
    print("   - [TODO: In danh sách top nguồn báo]")

    print("=" * 65)
    print("Hoàn tất khung kiểm định dữ liệu.")
    print("=" * 65)

    conn.close()


if __name__ == "__main__":
    run_data_quality_check()

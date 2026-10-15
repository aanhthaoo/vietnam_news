"""
ai_models/vietnam_relevance.py
==============================
Phụ trách: Thành viên 2 (Junior Developer)
Trạng thái: Template khung sườn (Chờ Thành viên 2 hiện thực logic)

YÊU CẦU ĐẶT RA:
1. Xây dựng danh sách từ khóa định danh Việt Nam (VIETNAM_KEYWORDS):
   - Địa danh, tỉnh/thành phố, danh thắng
   - Tập đoàn, doanh nghiệp, ngân hàng Việt Nam
   - Cơ quan chính phủ, lãnh đạo, tổ chức
   - Thuật ngữ văn hóa, tiền tệ (VND, Dong, Tết...)
2. Hiện thực hàm `calculate_vietnam_relevance`:
   - Phân biệt trọng số xuất hiện: Tiêu đề (cao nhất), Mô tả (trung bình), Nội dung (thấp)
   - Tính tổng điểm relevance_score
   - Xác định cờ is_vietnam_relevant (1 nếu đạt ngưỡng, 0 nếu không đạt)
"""

import sys
from typing import Dict, Any

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


# ==============================================================================
# TODO 1 (Thành viên 2): Định nghĩa bộ từ khóa nhận diện Việt Nam tại đây
# Gợi ý: Phân chia theo nhóm địa danh, kinh tế/tập đoàn, chính trị, văn hóa...
# ==============================================================================
VIETNAM_KEYWORDS = [
    # TODO: Điền các từ khóa viết thường (lowercase) vào đây...
]


def calculate_vietnam_relevance(title: str, description: str, content: str) -> Dict[str, Any]:
    """
    Tính điểm và xác định mức độ liên quan đến Việt Nam.

    Đầu vào:
        title (str): Tiêu đề bài báo
        description (str): Tóm tắt bài báo
        content (str): Nội dung bài báo

    Đầu ra (dict):
        relevance_score (int/float): Tổng điểm liên quan
        is_vietnam_relevant (int): 1 nếu liên quan, 0 nếu ngoài lề
        matched_keywords (list): Danh sách các từ khóa tìm thấy
    """
    # ==========================================================================
    # TODO 2 (Thành viên 2): Hiện thực thuật toán chấm điểm và lọc bài báo tại đây
    # Quy tắc chấm điểm tham khảo:
    #   - Xuất hiện trong Tiêu đề (Title): Trọng số cao
    #   - Xuất hiện trong Mô tả (Description): Trọng số vừa
    #   - Xuất hiện trong Nội dung (Content): Trọng số cơ bản
    #   - So sánh với ngưỡng quyết định (threshold) để gán is_vietnam_relevant
    # ==========================================================================

    # --- KHUNG CODE MẪU / GIÁ TRỊ MẶC ĐỊNH ---
    # (Thành viên 2 hãy xóa code giả định bên dưới và viết code xử lý thực tế)
    score = 0
    matched_keywords = []
    is_relevant = 0

    return {
        "relevance_score": score,
        "is_vietnam_relevant": is_relevant,
        "matched_keywords": matched_keywords
    }


if __name__ == "__main__":
    # Khối chạy thử nghiệm độc lập của Thành viên 2
    test_title = "VinFast expands EV charging network across Hanoi and Da Nang"
    test_desc = "The Vietnamese automaker announced new investments in domestic infrastructure."
    test_content = "Vietnam's automotive market is growing rapidly with strong VND capital."

    print("--- CHẠY THỬ NGHIỆM MODULE VIETNAM RELEVANCE (THÀNH VIÊN 2) ---")
    result = calculate_vietnam_relevance(test_title, test_desc, test_content)
    print(f"Điểm số (Score): {result.get('relevance_score')}")
    print(f"Đạt chuẩn tin Việt Nam: {bool(result.get('is_vietnam_relevant'))}")
    print(f"Từ khóa tìm thấy: {result.get('matched_keywords')}")

"""
ai_models/vietnam_relevance.py
==============================
Phụ trách: Thành viên 2 (Junior Developer)
Mục tiêu: Đánh giá và lọc các bài báo thực sự viết về Việt Nam (loại bỏ tin rác/quảng cáo).
Phương pháp: Rule-based Keyword Scoring (Địa danh, Tập đoàn, Chính phủ, Văn hóa).
"""

import re
import sys
from typing import Dict, Any

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


# Danh sách từ khóa đặc trưng về Việt Nam
VIETNAM_KEYWORDS = [
    # Địa danh & Thành phố
    'vietnam', 'viet nam', 'hanoi', 'ha noi', 'saigon', 'ho chi minh', 
    'da nang', 'hai phong', 'can tho', 'mekong', 'ha long', 'nha trang', 
    'phu quoc', 'quang ninh', 'dong nai', 'binh duong', 'hue',
    
    # Doanh nghiệp & Kinh tế
    'vingroup', 'vinfast', 'viettel', 'vietcombank', 'fpt', 'petrovietnam', 
    'vietjet', 'bamboo airways', 'thaco', 'masan', 'sabeco', 'vinamilk',
    'vietnamese dong', 'vnd', 'state bank of vietnam', 'sbv',
    
    # Chính phủ & Tổ chức
    'chinh phu', 'vietnamese government', 'national assembly', 'prime minister',
    'communist party of vietnam', 'ministry of foreign affairs',
    
    # Văn hóa & Xã hội
    'tet holiday', 'lunar new year', 'pho', 'ao dai', 'banh mi', 'vovinam'
]


def calculate_vietnam_relevance(title: str, description: str, content: str) -> Dict[str, Any]:
    """
    Tính điểm và xác định mức độ liên quan đến Việt Nam.

    Quy tắc chấm điểm:
      - Từ khóa xuất hiện trong Tiêu đề (Title): +3 điểm
      - Từ khóa xuất hiện trong Tóm tắt (Description): +2 điểm
      - Từ khóa xuất hiện trong Nội dung (Content): +1 điểm / mỗi từ

    Ngưỡng quyết định:
      - score >= 3: is_vietnam_relevant = True
      - score < 3:  is_vietnam_relevant = False
    """
    title_norm = (title or "").lower()
    desc_norm = (description or "").lower()
    content_norm = (content or "").lower()

    score = 0
    matched_keywords = []

    for kw in VIETNAM_KEYWORDS:
        # Xuất hiện trong tiêu đề: +3 điểm
        if kw in title_norm:
            score += 3
            matched_keywords.append(kw)
        
        # Xuất hiện trong mô tả: +2 điểm
        if kw in desc_norm:
            score += 2
            matched_keywords.append(kw)

        # Xuất hiện trong nội dung: +1 điểm
        if kw in content_norm:
            score += 1
            matched_keywords.append(kw)

    matched_keywords = list(dict.fromkeys(matched_keywords))
    is_relevant = score >= 3

    return {
        "relevance_score": score,
        "is_vietnam_relevant": 1 if is_relevant else 0,
        "matched_keywords": matched_keywords
    }


if __name__ == "__main__":
    sample_title = "VinFast expands EV charging network across Hanoi and Da Nang"
    sample_desc = "The Vietnamese electric automaker announced new investments."
    sample_content = "Vietnam's automotive market is growing rapidly with VND investments."
    
    result = calculate_vietnam_relevance(sample_title, sample_desc, sample_content)
    print("--- KẾT QUẢ TEST CỦA THÀNH VIÊN 2 ---")
    print(f"Điểm số (Relevance Score): {result['relevance_score']}")
    print(f"Có phải tin Việt Nam không: {bool(result['is_vietnam_relevant'])}")
    print(f"Từ khóa tìm thấy: {result['matched_keywords']}")

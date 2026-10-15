"""
ai_models/topic_classifier.py
=============================
Phụ trách: Thành viên 3 (Junior Developer)
Trạng thái: Template khung sườn (Chờ Thành viên 3 hiện thực logic)

YÊU CẦU ĐẶT RA:
1. Xây dựng bộ quy tắc từ điển từ khóa TOPIC_RULES cho 8 chủ đề chính:
   - Economy (Kinh tế)
   - Politics (Chính trị)
   - Society (Xã hội)
   - Technology (Công nghệ)
   - Military (Quân sự - An ninh)
   - Environment (Môi trường)
   - Healthcare (Y tế)
   - Sports (Thể thao)
2. Hiện thực hàm `classify_news_topic`:
   - Quét tần suất từ khóa của từng chủ đề xuất hiện trong tiêu đề/nội dung
   - Xác định chủ đề có điểm số cao nhất
   - Tính độ tin cậy (confidence score)
   - Nếu không có từ khóa nào khớp, gán về "General"
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
# TODO 1 (Thành viên 3): Xây dựng bộ từ điển từ khóa tiếng Anh cho 8 chủ đề
# ==============================================================================
TOPIC_RULES = {
    "Economy": [
        # TODO: Điền các từ khóa kinh tế (GDP, inflation, stock, trade, market...)...
    ],
    "Politics": [
        # TODO: Điền các từ khóa chính trị, ngoại giao (government, policy, parliament...)...
    ],
    "Society": [
        # TODO: Điền các từ khóa xã hội, văn hóa, giáo dục, du lịch...
    ],
    "Technology": [
        # TODO: Điền các từ khóa công nghệ, AI, chip, digital, software...
    ],
    "Military": [
        # TODO: Điền các từ khóa quân sự, quốc phòng, an ninh, vũ khí...
    ],
    "Environment": [
        # TODO: Điền các từ khóa môi trường, biến đổi khí hậu, năng lượng xanh...
    ],
    "Healthcare": [
        # TODO: Điền các từ khóa y tế, bệnh viện, dịch bệnh, vaccine...
    ],
    "Sports": [
        # TODO: Điền các từ khóa thể thao, giải đấu, bóng đá, huy chương...
    ]
}


def classify_news_topic(title: str, content: str) -> Dict[str, Any]:
    """
    Phân loại bài báo vào 1 trong 8 chủ đề dựa trên số lượng từ khóa xuất hiện.

    Đầu vào:
        title (str): Tiêu đề bài báo
        content (str): Nội dung văn bản bài báo

    Đầu ra (dict):
        topic (str): Tên chủ đề được gán (hoặc "General" nếu không khớp)
        confidence (float): Điểm độ tin cậy [0.0 - 1.0]
        topic_scores (dict): Điểm chi tiết của từng chủ đề
    """
    # ==========================================================================
    # TODO 2 (Thành viên 3): Hiện thực thuật toán duyệt từ khóa và tính điểm chủ đề
    # Gợi ý các bước:
    #   1. Chuẩn hóa chuỗi văn bản về chữ thường (lowercase)
    #   2. Khởi tạo bảng điểm cho 8 chủ đề
    #   3. Lặp qua các từ khóa trong TOPIC_RULES để đếm điểm
    #   4. Tìm chủ đề có điểm cao nhất
    #   5. Tính tỷ lệ độ tin cậy (confidence)
    # ==========================================================================

    # --- KHUNG CODE MẪU / GIÁ TRỊ MẶC ĐỊNH ---
    # (Thành viên 3 hãy xóa code giả định bên dưới và viết code xử lý thực tế)
    best_topic = "General"
    confidence = 0.0
    topic_scores = {topic: 0 for topic in TOPIC_RULES}

    return {
        "topic": best_topic,
        "confidence": confidence,
        "topic_scores": topic_scores
    }


if __name__ == "__main__":
    # Khối chạy thử nghiệm độc lập của Thành viên 3
    test_title = "Vietnam's GDP growth projected at 6.5% driven by export and trade"
    test_content = "The state bank manages inflation while foreign direct investment rises sharply."

    print("--- CHẠY THỬ NGHIỆM MODULE TOPIC CLASSIFIER (THÀNH VIÊN 3) ---")
    res = classify_news_topic(test_title, test_content)
    print(f"Chủ đề nhận diện (Topic): {res.get('topic')}")
    print(f"Độ tin cậy (Confidence): {res.get('confidence')}")
    print(f"Chi tiết điểm từng chủ đề: {res.get('topic_scores')}")

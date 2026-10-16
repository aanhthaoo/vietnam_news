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
        "gdp", "growth", "economy", "economic", "inflation", "stock", "market", "trade",
        "export", "import", "investment", "currency", "dollar", "business", "finance",
        "bank", "banking", "tax", "revenue", "profit", "company", "corporate", "industry",
        "manufacturing", "supply", "demand", "price", "cost", "budget", "debt", "loan",
        "interest", "rate", "exchange", "merger", "acquisition", "startup", "entrepreneur",
        "employment", "unemployment", "salary", "wage", "income", "fdi", "foreign investment"
    ],
    "Politics": [
        "government", "policy", "parliament", "congress", "senate", "election", "vote",
        "democracy", "president", "minister", "prime minister", "diplomat", "diplomacy",
        "treaty", "alliance", "summit", "conference", "party", "political", "politics",
        "regime", "administration", "law", "legislation", "regulation", "campaign",
        "opposition", "candidate", "leader", "official", "authority", "state", "nation",
        "sovereignty", "territory", "border", "embassy", "consulate", "ambassador"
    ],
    "Society": [
        "society", "social", "culture", "cultural", "education", "school", "university",
        "student", "teacher", "learning", "community", "people", "citizen", "public",
        "family", "child", "children", "elderly", "youth", "woman", "women", "man",
        "men", "gender", "religion", "faith", "tradition", "festival", "tourism",
        "tourist", "travel", "heritage", "history", "historical", "arts", "music",
        "film", "movie", "entertainment", "media", "news", "journalism", "protest",
        "demonstration", "rights", "human rights", "equality", "justice", "crime",
        "police", "court", "justice", "lawyer", "judge", "prison", "arrest"
    ],
    "Technology": [
        "technology", "tech", "digital", "software", "hardware", "computer", "internet",
        "network", "cloud", "data", "ai", "artificial intelligence", "machine learning",
        "algorithm", "robot", "robotics", "automation", "smart", "app", "application",
        "mobile", "phone", "device", "chip", "semiconductor", "processor", "cyber",
        "cybersecurity", "hacker", "hack", "programming", "code", "developer", "engineer",
        "startup", "innovation", "innovative", "research", "development", "scientist",
        "laboratory", "lab", "electronics", "gadget", "virtual", "augmented reality",
        "blockchain", "crypto", "cryptocurrency", "bitcoin", "5g", "wifi", "satellite"
    ],
    "Military": [
        "military", "army", "navy", "air force", "soldier", "troop", "force", "defense",
        "weapon", "missile", "tank", "aircraft", "helicopter", "warship", "submarine",
        "fighter", "combat", "battle", "war", "conflict", "attack", "strike", "bomb",
        "explosion", "terrorism", "terrorist", "security", "national security", "border",
        "territory", "sovereignty", "drone", "radar", "surveillance", "intelligence",
        "spy", "espionage", "peacekeeping", "alliance", "treaty", "base", "deployment",
        "exercise", "training", "casualty", "casualties", "veteran", "officer", "general",
        "admiral", "commander", "chief", "strategy", "tactical", "operation"
    ],
    "Environment": [
        "environment", "environmental", "climate", "climate change", "global warming",
        "temperature", "weather", "storm", "flood", "drought", "hurricane", "typhoon",
        "earthquake", "tsunami", "natural disaster", "pollution", "air pollution", "water",
        "water pollution", "plastic", "waste", "recycling", "renewable", "energy",
        "solar", "wind", "nuclear", "coal", "oil", "gas", "emission", "carbon", "co2",
        "greenhouse", "forest", "deforestation", "biodiversity", "species", "animal",
        "wildlife", "ecosystem", "nature", "conservation", "protect", "protection",
        "sustainable", "sustainability", "green", "eco", "ecology", "carbon footprint"
    ],
    "Healthcare": [
        "health", "healthcare", "medical", "medicine", "doctor", "physician", "nurse",
        "hospital", "clinic", "patient", "treatment", "therapy", "surgery", "operation",
        "drug", "medicine", "pharmaceutical", "vaccine", "vaccination", "virus",
        "disease", "illness", "sick", "infection", "pandemic", "epidemic", "covid",
        "coronavirus", "symptom", "diagnosis", "test", "testing", "cure", "recovery",
        "death", "mortality", "mortality rate", "public health", "who", "health ministry",
        "quarantine", "isolation", "mask", "ppe", "intensive care", "icu", "emergency",
        "ambulance", "paramedic", "mental health", "psychology", "psychiatric", "wellness"
    ],
    "Sports": [
        "sport", "sports", "game", "match", "tournament", "championship", "league",
        "cup", "world cup", "olympic", "olympics", "football", "soccer", "basketball",
        "tennis", "golf", "swimming", "athletics", "track", "field", "runner", "athlete",
        "player", "team", "coach", "manager", "referee", "goal", "score", "win", "winner",
        "lose", "loss", "draw", "champion", "medal", "gold", "silver", "bronze",
        "record", "stadium", "arena", "club", "fan", "spectator", "audience", "race",
        "competition", "compete", "boxing", "mma", "ufc", "cricket", "rugby", "baseball",
        "hockey", "volleyball", "badminton", "cycling", "skiing", "snowboarding"
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

    # 1. Chuẩn hóa văn bản về chữ thường
    text = f"{title} {content}".lower()

    # 2. Khởi tạo bảng điểm cho 8 chủ đề
    topic_scores = {topic: 0 for topic in TOPIC_RULES}

    # 3. Đếm điểm cho từng chủ đề dựa trên từ khóa xuất hiện
    for topic, keywords in TOPIC_RULES.items():
        score = 0
        for keyword in keywords:
            if keyword in text:
                score += text.count(keyword)
        topic_scores[topic] = score

    # 4. Tìm chủ đề có điểm cao nhất
    total_score = sum(topic_scores.values())

    if total_score == 0:
        best_topic = "General"
        confidence = 0.0
    else:
        best_topic = max(topic_scores, key=topic_scores.get)
        best_score = topic_scores[best_topic]

        # 5. Tính độ tin cậy (confidence) = điểm chủ đề cao nhất / tổng điểm
        confidence = round(best_score / total_score, 4)

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

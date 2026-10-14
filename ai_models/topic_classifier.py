"""
ai_models/topic_classifier.py
=============================
Phụ trách: Thành viên 3 (Junior Developer)
Mục tiêu: Phân loại bài báo vào 1 trong 8 chủ đề chính bằng Rule-based Weighted Keyword Scoring.
Các chủ đề: Economy, Politics, Society, Technology, Military, Environment, Healthcare, Sports.
"""

import sys
from typing import Dict, Any

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


TOPIC_RULES = {
    "Economy": [
        "economy", "economic", "market", "gdp", "stock", "bank", "inflation", 
        "export", "import", "trade", "investment", "enterprise", "currency", 
        "revenue", "fdi", "tariff", "manufacturing", "growth", "supply chain"
    ],
    "Politics": [
        "politics", "government", "policy", "minister", "prime minister", "parliament", 
        "diplomacy", "bilateral", "state visit", "official", "regulations", "law",
        "communist party", "general secretary", "treaty", "relations"
    ],
    "Society": [
        "society", "culture", "tourism", "tourist", "education", "student", "school", 
        "university", "traffic", "heritage", "festival", "community", "lifestyle",
        "travel", "visa", "cinema", "art"
    ],
    "Technology": [
        "technology", "ai", "artificial intelligence", "digital", "software", "startup", 
        "semiconductor", "chip", "5g", "telecom", "cybersecurity", "innovation",
        "fintech", "hardware", "data center", "cloud"
    ],
    "Military": [
        "military", "defense", "army", "security", "weapon", "border", "navy", 
        "patrol", "police", "coast guard", "drill", "maritime", "conflict"
    ],
    "Environment": [
        "environment", "climate", "storm", "flood", "typhoon", "pollution", "energy", 
        "solar", "renewable", "carbon", "drought", "waste", "emission", "green"
    ],
    "Healthcare": [
        "health", "healthcare", "hospital", "medical", "doctor", "disease", "virus", 
        "vaccine", "treatment", "patient", "epidemic", "pharmaceutical"
    ],
    "Sports": [
        "sports", "football", "soccer", "sea games", "olympics", "tournament", 
        "championship", "match", "athlete", "medal", "coach", "fifa", "asian cup"
    ]
}


def classify_news_topic(title: str, content: str) -> Dict[str, Any]:
    """
    Phân loại bài báo vào 1 trong 8 chủ đề dựa trên số lượng từ khóa xuất hiện.
    """
    full_text = f"{title or ''} {content or ''}".lower()
    
    topic_scores = {topic: 0 for topic in TOPIC_RULES}

    for topic, keywords in TOPIC_RULES.items():
        for kw in keywords:
            if kw in full_text:
                topic_scores[topic] += 1

    best_topic = max(topic_scores, key=topic_scores.get)
    highest_score = topic_scores[best_topic]

    total_hits = sum(topic_scores.values())

    if highest_score == 0:
        best_topic = "General"
        confidence = 0.0
    else:
        confidence = round(highest_score / max(total_hits, 1), 2)

    return {
        "topic": best_topic,
        "confidence": confidence,
        "topic_scores": topic_scores
    }


if __name__ == "__main__":
    test_title = "Vietnam's GDP growth projected at 6.5% driven by export and trade"
    test_content = "The state bank manages inflation while foreign direct investment rises."
    
    res = classify_news_topic(test_title, test_content)
    print("--- KẾT QUẢ TEST CỦA THÀNH VIÊN 3 ---")
    print(f"Chủ đề nhận diện (Topic): {res['topic']}")
    print(f"Độ tin cậy (Confidence): {res['confidence']}")
    print(f"Chi tiết điểm: {res['topic_scores']}")

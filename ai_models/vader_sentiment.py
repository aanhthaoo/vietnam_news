"""
ai_models/vader_sentiment.py
============================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu: Phân tích cảm xúc đa mô hình (Ensemble Sentiment Analysis).
Kết hợp VADER (Rule-based lexicon tối ưu cho tin tức/tiêu đề) và TextBlob.
"""

import logging
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

_vader_analyzer = None

def _get_vader():
    global _vader_analyzer
    if _vader_analyzer is None:
        try:
            from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
            _vader_analyzer = SentimentIntensityAnalyzer()
        except ImportError:
            try:
                from nltk.sentiment.vader import SentimentIntensityAnalyzer
                _vader_analyzer = SentimentIntensityAnalyzer()
            except Exception as e:
                logger.warning(f"[VADER] Không thể khởi tạo VADER: {e}")
                _vader_analyzer = False
    return _vader_analyzer if _vader_analyzer is not False else None


def analyze_vader(text: str) -> Dict[str, Any]:
    """
    Phân tích cảm xúc bằng VADER.
    Returns:
        compound: [-1.0, 1.0]
        pos, neg, neu: tỉ lệ các thành phần [0.0, 1.0]
        vader_label: 'Positive' | 'Negative' | 'Neutral'
    """
    if not text:
        return {"compound": 0.0, "pos": 0.0, "neg": 0.0, "neu": 1.0, "label": "Neutral"}

    analyzer = _get_vader()
    if analyzer is None:
        return {"compound": 0.0, "pos": 0.0, "neg": 0.0, "neu": 1.0, "label": "Neutral"}

    scores = analyzer.polarity_scores(text)
    compound = scores["compound"]

    if compound >= 0.05:
        label = "Positive"
    elif compound <= -0.05:
        label = "Negative"
    else:
        label = "Neutral"

    return {
        "compound": round(compound, 4),
        "pos": round(scores["pos"], 4),
        "neg": round(scores["neg"], 4),
        "neu": round(scores["neu"], 4),
        "label": label
    }


def ensemble_sentiment(textblob_label: str, textblob_score: float, vader_res: Dict[str, Any]) -> Tuple[str, float]:
    """
    Biểu quyết đa mô hình (Ensemble Voting) giữa TextBlob và VADER.
    
    Quy tắc:
      1. Nếu cả 2 cùng nhãn -> Chọn nhãn đó, độ tin cậy cao.
      2. Nếu 1 bên Neutral, 1 bên có cực tính (Positive/Negative) -> Ưu tiên bên có cực tính nếu điểm đủ lớn.
      3. Nếu xung đột (1 bên Positive, 1 bên Negative) -> Ưu tiên VADER vì VADER được tinh chỉnh cho tin tức ngắn.
    
    Returns:
        (ensemble_label, combined_score)
    """
    vader_label = vader_res.get("label", "Neutral")
    vader_compound = vader_res.get("compound", 0.0)

    # Điểm kết hợp trung bình có trọng số (VADER 0.6, TextBlob 0.4)
    combined_score = round(0.6 * vader_compound + 0.4 * textblob_score, 4)

    # 1. Đồng thuận
    if textblob_label == vader_label:
        return textblob_label, combined_score

    # 2. Một bên Neutral, một bên rõ ràng
    if textblob_label == "Neutral" and vader_label in ("Positive", "Negative"):
        if abs(vader_compound) >= 0.15:
            return vader_label, combined_score
        return "Neutral", combined_score

    if vader_label == "Neutral" and textblob_label in ("Positive", "Negative"):
        if abs(textblob_score) >= 0.2:
            return textblob_label, combined_score
        return "Neutral", combined_score

    # 3. Xung đột cực tính trực tiếp -> Ưu tiên VADER
    return vader_label, combined_score


if __name__ == "__main__":
    sample_text = "Vietnam's economic growth is booming with record FDI, despite rising inflation challenges."
    vader_out = analyze_vader(sample_text)
    print("VADER result:", vader_out)
    
    ens_label, ens_score = ensemble_sentiment("Positive", 0.25, vader_out)
    print(f"Ensemble: {ens_label} (Score: {ens_score})")

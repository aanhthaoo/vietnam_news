"""
transform_news.py
=================
Bước 2 - Transform: Làm sạch văn bản và phân tích NLP.
  1. Clean: Loại bỏ HTML tags, chuẩn hóa văn bản
  2. Sentiment Analysis: TextBlob → Positive / Negative / Neutral
  3. NER: spaCy → Tổ chức (ORG), Địa danh (GPE), Nhân vật (PERSON)
"""

import re
import sys
import logging
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Import các module AI (Người 1, Người 2, Người 3)
try:
    from ai_models.vader_sentiment import analyze_vader, ensemble_sentiment
    from ai_models.vietnam_relevance import calculate_vietnam_relevance
    from ai_models.topic_classifier import classify_news_topic
    from ai_models.text_summarizer import summarize_article
except ImportError:
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from ai_models.vader_sentiment import analyze_vader, ensemble_sentiment
    from ai_models.vietnam_relevance import calculate_vietnam_relevance
    from ai_models.topic_classifier import classify_news_topic
    from ai_models.text_summarizer import summarize_article

logger = logging.getLogger(__name__)

# ── Lazy-load thư viện nặng để tránh import error khi chưa cài ──────────────
_textblob_ok = False
_spacy_ok     = False
_nlp          = None   # spaCy model instance


def _load_textblob():
    global _textblob_ok
    if not _textblob_ok:
        try:
            from textblob import TextBlob  # noqa: F401
            _textblob_ok = True
        except ImportError:
            logger.warning("[NLP] textblob chưa được cài. Chạy: pip install textblob")
    return _textblob_ok


def _load_spacy():
    global _spacy_ok, _nlp
    if not _spacy_ok:
        try:
            import spacy
            _nlp    = spacy.load("en_core_web_sm")
            _spacy_ok = True
        except ImportError:
            logger.warning("[NLP] spacy chưa được cài. Chạy: pip install spacy")
        except OSError:
            logger.warning(
                "[NLP] spaCy model 'en_core_web_sm' chưa tải.\n"
                "      Chạy: python -m spacy download en_core_web_sm"
            )
    return _spacy_ok


# ── 1. Làm sạch văn bản ──────────────────────────────────────────────────────

def clean_text(text: str) -> str:
    """
    Làm sạch văn bản:
      - Loại bỏ HTML/XML tags
      - Chuẩn hóa khoảng trắng và ký tự xuống dòng
      - Loại bỏ ký tự kiểm soát (control chars)
      - Xóa phần '[+N chars]' do NewsAPI cắt ngắn content
    """
    if not text:
        return ""

    # Loại bỏ thẻ HTML
    text = re.sub(r"<[^>]+>", " ", text)

    # Loại bỏ hậu tố NewsAPI "[+1234 chars]"
    text = re.sub(r"\[\+\d+\s*chars?\]", "", text, flags=re.IGNORECASE)

    # Loại bỏ URLs
    text = re.sub(r"https?://\S+", "", text)

    # Loại bỏ ký tự kiểm soát (giữ lại newline bình thường)
    text = re.sub(r"[\x00-\x08\x0b-\x0c\x0e-\x1f\x7f]", "", text)

    # Chuẩn hóa khoảng trắng
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


def get_best_text(article: dict) -> str:
    """
    Chọn văn bản tốt nhất để phân tích NLP.
    Ưu tiên: content → description → title
    NewsAPI free tier cắt content ở ~200 ký tự, nên kết hợp cả hai.
    """
    content     = clean_text(article.get("content", ""))
    description = clean_text(article.get("description", ""))
    title       = clean_text(article.get("title", ""))

    # Kết hợp các trường để có văn bản đủ dài cho NLP
    parts = []
    if title:
        parts.append(title)
    if description and description not in content:
        parts.append(description)
    if content:
        parts.append(content)

    return " ".join(parts)[:2000]   # Giới hạn độ dài để tránh timeout


# ── 2. Sentiment Analysis ─────────────────────────────────────────────────────

def analyze_sentiment(text: str) -> tuple[str, float]:
    """
    Phân tích cảm xúc bằng TextBlob.

    Returns:
        (label, score)
        label: "Positive" | "Negative" | "Neutral"
        score: -1.0 → +1.0 (polarity)
    """
    if not text or not _load_textblob():
        return "Neutral", 0.0

    try:
        from textblob import TextBlob
        polarity = TextBlob(text).sentiment.polarity

        if polarity > 0.1:
            return "Positive", round(polarity, 4)
        elif polarity < -0.1:
            return "Negative", round(polarity, 4)
        else:
            return "Neutral", round(polarity, 4)
    except Exception as e:
        logger.error(f"[NLP] Sentiment error: {e}")
        return "Neutral", 0.0


# ── 3. Named Entity Recognition (NER) ────────────────────────────────────────

def extract_entities(text: str) -> tuple[list, list, list]:
    """
    Trích xuất thực thể từ văn bản bằng spaCy.

    Returns:
        (orgs, gpes, persons)
        orgs:    Danh sách tổ chức / công ty (ORG)
        gpes:    Danh sách địa danh / quốc gia (GPE)
        persons: Danh sách nhân vật (PERSON)
    """
    if not text or not _load_spacy():
        return [], [], []

    try:
        doc = _nlp(text[:1000])   # Giới hạn để tăng tốc

        orgs    = list(dict.fromkeys(  # Loại trùng, giữ thứ tự
            ent.text.strip() for ent in doc.ents
            if ent.label_ == "ORG" and len(ent.text.strip()) > 1
        ))
        gpes    = list(dict.fromkeys(
            ent.text.strip() for ent in doc.ents
            if ent.label_ == "GPE" and len(ent.text.strip()) > 1
        ))
        persons = list(dict.fromkeys(
            ent.text.strip() for ent in doc.ents
            if ent.label_ == "PERSON" and len(ent.text.strip()) > 1
        ))

        return orgs[:10], gpes[:10], persons[:10]   # Giới hạn 10 mỗi loại

    except Exception as e:
        logger.error(f"[NLP] NER error: {e}")
        return [], [], []


# ── 4. Transform pipeline ─────────────────────────────────────────────────────

def transform_article(article: dict) -> dict:
    """
    Làm giàu một bài báo đơn lẻ với toàn bộ cụm mô hình AI & NLP:
      1. Clean text
      2. Sentiment: TextBlob + VADER + Ensemble Voting
      3. Topic Classification (8 chủ đề)
      4. Vietnam Relevance Scoring & Filtering
      5. Automatic Summarization (Gemini API / Fallback)
      6. Named Entity Recognition (spaCy ORG, GPE, PERSON)
      7. Text features: word_count
    """
    text = get_best_text(article)

    # Làm sạch content, description, title
    article["content"]     = clean_text(article.get("content", ""))
    article["description"] = clean_text(article.get("description", ""))
    article["title"]       = clean_text(article.get("title", ""))

    # 1. TextBlob Sentiment
    tb_label, tb_score = analyze_sentiment(text)
    article["sentiment_label"] = tb_label
    article["sentiment_score"] = tb_score

    # 2. VADER Sentiment & Ensemble Voting
    try:
        vader_res = analyze_vader(text)
        article["vader_compound"] = vader_res.get("compound", 0.0)
        article["vader_label"]    = vader_res.get("label", "Neutral")
        ens_label, _ = ensemble_sentiment(tb_label, tb_score, vader_res)
        article["ensemble_sentiment_label"] = ens_label
    except Exception as e:
        logger.warning(f"[Transform] Lỗi VADER/Ensemble: {e}")
        article["vader_compound"] = 0.0
        article["vader_label"]    = tb_label
        article["ensemble_sentiment_label"] = tb_label

    # 3. Vietnam Relevance (Người 2)
    try:
        vn_res = calculate_vietnam_relevance(
            article.get("title", ""),
            article.get("description", ""),
            article.get("content", "")
        )
        article["vietnam_relevance_score"] = vn_res.get("relevance_score", 0)
        article["is_vietnam_relevant"]     = vn_res.get("is_vietnam_relevant", 0)
    except Exception as e:
        logger.warning(f"[Transform] Lỗi Vietnam Relevance: {e}")
        article["vietnam_relevance_score"] = 0
        article["is_vietnam_relevant"]     = 0

    # 4. Topic Classifier (Người 3)
    try:
        topic_res = classify_news_topic(article.get("title", ""), text)
        article["topic_label"]      = topic_res.get("topic", "General")
        article["topic_confidence"] = topic_res.get("confidence", 0.0)
    except Exception as e:
        logger.warning(f"[Transform] Lỗi Topic Classifier: {e}")
        article["topic_label"]      = "General"
        article["topic_confidence"] = 0.0

    # 5. Summarizer (Gemini / Extractive Fallback)
    try:
        article["ai_summary"] = summarize_article(
            article.get("title", ""),
            article.get("description", "") or text
        )
    except Exception as e:
        logger.warning(f"[Transform] Lỗi Summarizer: {e}")
        article["ai_summary"] = article.get("title", "")

    # 6. Word count
    article["word_count"] = len(text.split())

    # 7. NER (spaCy)
    orgs, gpes, persons = extract_entities(text)
    article["entities_org"]    = orgs
    article["entities_gpe"]    = gpes
    article["entities_person"] = persons

    return article


def transform_articles(articles: list[dict], verbose: bool = True) -> list[dict]:
    """
    Áp dụng transform lên toàn bộ danh sách bài báo.
    """
    total = len(articles)
    enriched = []

    for i, article in enumerate(articles, 1):
        try:
            enriched_article = transform_article(article)
            enriched.append(enriched_article)

            if verbose and i % 10 == 0:
                print(f"[NLP] ⚙️  Đã xử lý AI {i}/{total} bài...")
        except Exception as e:
            logger.error(f"[NLP] Lỗi bài #{i} '{article.get('title','')[:40]}': {e}")
            article.setdefault("sentiment_label", "Neutral")
            article.setdefault("sentiment_score", 0.0)
            article.setdefault("vader_compound", 0.0)
            article.setdefault("vader_label", "Neutral")
            article.setdefault("ensemble_sentiment_label", "Neutral")
            article.setdefault("vietnam_relevance_score", 0)
            article.setdefault("is_vietnam_relevant", 0)
            article.setdefault("topic_label", "General")
            article.setdefault("topic_confidence", 0.0)
            article.setdefault("ai_summary", article.get("title", ""))
            article.setdefault("word_count", 0)
            article.setdefault("entities_org",    [])
            article.setdefault("entities_gpe",    [])
            article.setdefault("entities_person", [])
            enriched.append(article)

    if verbose and enriched:
        ens_counts = {}
        top_counts = {}
        vn_rel_count = 0
        for a in enriched:
            ens = a.get("ensemble_sentiment_label", "Neutral")
            ens_counts[ens] = ens_counts.get(ens, 0) + 1
            top = a.get("topic_label", "General")
            top_counts[top] = top_counts.get(top, 0) + 1
            if a.get("is_vietnam_relevant") == 1:
                vn_rel_count += 1

        print(
            f"[NLP] ✅ Hoàn tất AI Transform {total} bài:\n"
            f"   - Ensemble Sentiment: {ens_counts}\n"
            f"   - Chủ đề (Topics):    {top_counts}\n"
            f"   - Tin chuẩn Việt Nam: {vn_rel_count}/{total} ({vn_rel_count/max(total,1)*100:.1f}%)"
        )

    return enriched


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    # Test nhanh với dữ liệu giả
    test_articles = [
        {
            "title": "Vietnam's economy grows 7% in 2024, beating expectations",
            "description": "The Vietnamese economy expanded at a robust pace, driven by strong exports and foreign investment from companies like Samsung and Intel.",
            "content": "Hanoi - Vietnam's GDP growth exceeded analyst forecasts...",
            "url": "https://example.com/article1",
            "source_name": "Reuters",
            "author": "Jane Doe",
            "published_at": "2024-01-15 10:00:00",
            "sentiment_label": None, "sentiment_score": None,
            "entities_org": [], "entities_gpe": [], "entities_person": [],
        },
        {
            "title": "Flooding in Ho Chi Minh City leaves thousands displaced",
            "description": "Severe floods have affected many districts of Ho Chi Minh City following heavy monsoon rains.",
            "content": "Ho Chi Minh City - Rescue teams deployed...",
            "url": "https://example.com/article2",
            "source_name": "BBC",
            "author": "",
            "published_at": "2024-01-14 08:00:00",
            "sentiment_label": None, "sentiment_score": None,
            "entities_org": [], "entities_gpe": [], "entities_person": [],
        },
    ]

    result = transform_articles(test_articles)
    for a in result:
        print(f"\n  Title:     {a['title'][:60]}")
        print(f"  Sentiment: {a['sentiment_label']} ({a['sentiment_score']})")
        print(f"  ORG:       {a['entities_org']}")
        print(f"  GPE:       {a['entities_gpe']}")
        print(f"  PERSON:    {a['entities_person']}")

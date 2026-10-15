"""
ai_models/tfidf_keywords.py
===========================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu:
  1. Trích xuất top từ khóa (unigram + bigram) cho từng bài báo bằng TF-IDF (scikit-learn).
  2. Phân tích xu hướng từ khóa theo chuỗi thời gian (Keyword Trend Detection)
     để phát hiện từ khóa đang bùng nổ (Rising) hoặc hạ nhiệt (Falling).
  3. Ghi kết quả vào bảng `news_keyword_trends`.
"""

import sys
import os
import re
import json
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Any, Tuple

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer

logger = logging.getLogger(__name__)

# Stopwords tiếng Anh bổ sung chuyên cho báo chí để lọc nhiễu
CUSTOM_STOPWORDS = {
    "vietnam", "vietnamese", "said", "say", "says", "mr", "mrs", "year", "years",
    "news", "reported", "reporting", "according", "also", "one", "two", "new",
    "told", "would", "could", "reuters", "bloomberg", "ap", "afp", "cna", "bbc",
    "today", "yesterday", "day", "time", "first", "last", "week", "month"
}


def clean_text_for_tfidf(text: str) -> str:
    """Loại bỏ ký tự đặc biệt, giữ lại chữ cái và khoảng trắng."""
    if not text:
        return ""
    text = re.sub(r"[^a-zA-Z\s]", " ", text.lower())
    return re.sub(r"\s+", " ", text).strip()


def extract_keywords_from_text(text: str, top_n: int = 5) -> List[str]:
    """
    Trích xuất top_n từ khóa đơn/ghép quan trọng nhất từ một đoạn văn bản.
    """
    clean_str = clean_text_for_tfidf(text)
    if not clean_str or len(clean_str.split()) < 4:
        return []

    try:
        vec = TfidfVectorizer(
            stop_words="english",
            ngram_range=(1, 2),
            max_features=50,
            token_pattern=r"(?u)\b[a-zA-Z]{3,}\b"
        )
        tfidf_matrix = vec.fit_transform([clean_str])
        feature_names = vec.get_feature_names_out()
        scores = tfidf_matrix.toarray()[0]

        # Lọc bỏ stopwords bổ sung
        valid_items: List[Tuple[str, float]] = []
        for word, score in zip(feature_names, scores):
            parts = word.split()
            if any(p in CUSTOM_STOPWORDS for p in parts):
                continue
            valid_items.append((word, float(score)))

        # Sắp xếp điểm giảm dần
        valid_items.sort(key=lambda x: x[1], reverse=True)
        return [w for w, _ in valid_items[:top_n]]
    except Exception as e:
        logger.debug(f"[TF-IDF] Lỗi trích xuất: {e}")
        return []


def extract_keywords_corpus(corpus_texts: List[str], top_n_per_doc: int = 5) -> List[List[str]]:
    """
    Trích xuất từ khóa cho toàn bộ tập văn bản (corpus) cùng lúc bằng TF-IDF chung.
    """
    if not corpus_texts:
        return []

    cleaned = [clean_text_for_tfidf(t) for t in corpus_texts]
    valid_indices = [i for i, t in enumerate(cleaned) if len(t.split()) >= 4]

    results: List[List[str]] = [[] for _ in corpus_texts]
    if not valid_indices:
        return results

    try:
        valid_texts = [cleaned[i] for i in valid_indices]
        vec = TfidfVectorizer(
            stop_words="english",
            ngram_range=(1, 2),
            min_df=1,
            max_df=0.85,
            max_features=500,
            token_pattern=r"(?u)\b[a-zA-Z]{3,}\b"
        )
        matrix = vec.fit_transform(valid_texts)
        feature_names = vec.get_feature_names_out()

        for row_idx, doc_orig_idx in enumerate(valid_indices):
            scores = matrix[row_idx].toarray()[0]
            top_kw_indices = np.argsort(scores)[::-1]
            doc_kws: List[str] = []
            for kw_idx in top_kw_indices:
                if scores[kw_idx] <= 0:
                    break
                w = feature_names[kw_idx]
                parts = w.split()
                if not any(p in CUSTOM_STOPWORDS for p in parts):
                    doc_kws.append(w)
                    if len(doc_kws) >= top_n_per_doc:
                        break
            results[doc_orig_idx] = doc_kws
    except Exception as e:
        logger.warning(f"[TF-IDF] Corpus TF-IDF error: {e}")
        for i in valid_indices:
            results[i] = extract_keywords_from_text(corpus_texts[i], top_n=top_n_per_doc)

    return results


def analyze_and_update_keyword_trends() -> Dict[str, Any]:
    """
    Quét cơ sở dữ liệu, phân tích tần suất từ khóa theo ngày, so sánh xu hướng 7 ngày
    (Rising/Falling/Stable) và lưu vào bảng `news_keyword_trends`.
    """
    from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres

    # 1. Đọc dữ liệu bài báo từ CSDL
    if is_postgres():
        conn = get_pg_connection()
        query = """
            SELECT id, title, description, content, 
                   DATE(COALESCE(published_at, collected_at))::text as date_str
            FROM news_vietnam_articles
            WHERE title IS NOT NULL
            ORDER BY COALESCE(published_at, collected_at) DESC;
        """
        df = pd.read_sql_query(query, conn)
        conn.close()
    else:
        conn = get_sqlite_connection()
        query = """
            SELECT id, title, description, content, 
                   DATE(COALESCE(published_at, collected_at)) as date_str
            FROM news_vietnam_articles
            WHERE title IS NOT NULL
            ORDER BY COALESCE(published_at, collected_at) DESC;
        """
        df = pd.read_sql_query(query, conn)
        conn.close()

    if df.empty:
        return {"status": "empty", "keywords_tracked": 0}

    df["full_text"] = df["title"].fillna("") + ". " + df["description"].fillna("")
    texts = df["full_text"].tolist()
    kws_list = extract_keywords_corpus(texts, top_n_per_doc=5)
    df["keywords"] = kws_list

    # Cập nhật cột keywords trong DB cho từng bài
    articles_kw_updates = []
    for art_id, kw in zip(df["id"], kws_list):
        articles_kw_updates.append((json.dumps(kw, ensure_ascii=False), art_id))

    # 2. Thống kê tần suất từ khóa theo ngày
    daily_records: List[Dict[str, Any]] = []
    for _, row in df.iterrows():
        d_str = row["date_str"]
        if not d_str:
            d_str = datetime.now().strftime("%Y-%m-%d")
        for kw in row["keywords"]:
            daily_records.append({"date_str": d_str, "keyword": kw})

    if not daily_records:
        return {"status": "no_keywords", "keywords_tracked": 0}

    kdf = pd.DataFrame(daily_records)
    trend_counts = kdf.groupby(["date_str", "keyword"]).size().reset_index(name="frequency")

    # 3. Tính toán xu hướng so với chu kỳ trước (Rising / Falling / Stable)
    today = datetime.now().date()
    last_7d = str(today - timedelta(days=7))
    prev_7d = str(today - timedelta(days=14))

    recent_mask = trend_counts["date_str"] >= last_7d
    past_mask = (trend_counts["date_str"] < last_7d) & (trend_counts["date_str"] >= prev_7d)

    recent_freq = trend_counts[recent_mask].groupby("keyword")["frequency"].sum().to_dict()
    past_freq = trend_counts[past_mask].groupby("keyword")["frequency"].sum().to_dict()

    trend_rows = []
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    for _, row in trend_counts.iterrows():
        kw = row["keyword"]
        d = row["date_str"]
        freq = int(row["frequency"])

        r_cnt = recent_freq.get(kw, 0)
        p_cnt = past_freq.get(kw, 0)

        if p_cnt > 0:
            delta = round(((r_cnt - p_cnt) / p_cnt) * 100.0, 1)
        elif r_cnt > 0:
            delta = 100.0
        else:
            delta = 0.0

        if delta >= 30.0:
            direction = "Rising"
        elif delta <= -30.0:
            direction = "Falling"
        else:
            direction = "Stable"

        trend_rows.append((d, kw, freq, direction, delta, now_str))

    # 4. Lưu vào CSDL
    # Ghi vào PostgreSQL
    if is_postgres():
        conn = get_pg_connection()
        try:
            with conn.cursor() as cur:
                # Cập nhật keywords cho bài báo
                for kw_json, art_id in articles_kw_updates:
                    cur.execute("UPDATE news_vietnam_articles SET keywords = %s WHERE id = %s;", (kw_json, art_id))

                # Cập nhật news_keyword_trends
                upsert_pg = """
                INSERT INTO news_keyword_trends
                    (date_str, keyword, frequency, trend_direction, trend_delta, created_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (date_str, keyword) DO UPDATE SET
                    frequency       = EXCLUDED.frequency,
                    trend_direction = EXCLUDED.trend_direction,
                    trend_delta     = EXCLUDED.trend_delta,
                    created_at      = EXCLUDED.created_at;
                """
                cur.executemany(upsert_pg, trend_rows)
            conn.commit()
            logger.info(f"[TF-IDF] PostgreSQL: Đã lưu {len(trend_rows)} bản ghi xu hướng từ khóa.")
        finally:
            conn.close()

    # Ghi vào SQLite
    conn_sq = get_sqlite_connection()
    try:
        with conn_sq:
            for kw_json, art_id in articles_kw_updates:
                conn_sq.execute("UPDATE news_vietnam_articles SET keywords = ? WHERE id = ?;", (kw_json, art_id))

            upsert_sq = """
            INSERT INTO news_keyword_trends
                (date_str, keyword, frequency, trend_direction, trend_delta, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT (date_str, keyword) DO UPDATE SET
                frequency       = excluded.frequency,
                trend_direction = excluded.trend_direction,
                trend_delta     = excluded.trend_delta,
                created_at      = excluded.created_at;
            """
            conn_sq.executemany(upsert_sq, trend_rows)
        logger.info(f"[TF-IDF] SQLite: Đã lưu {len(trend_rows)} bản ghi xu hướng từ khóa.")
    finally:
        conn_sq.close()

    return {
        "status": "success",
        "keywords_tracked": len(trend_rows),
        "articles_enriched": len(articles_kw_updates),
        "sample_trends": trend_rows[:5]
    }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("--- CHẠY THỬ NGHIỆM MODULE TF-IDF KEYWORDS & TREND DETECTION ---")
    sample_text = (
        "VinFast expands electric vehicle sales in Southeast Asia while State Bank of Vietnam "
        "regulates interest rates to control inflation. Strong manufacturing exports support economic growth."
    )
    kws = extract_keywords_from_text(sample_text, top_n=5)
    print(f"Top 5 từ khóa trích xuất: {kws}")

    print("\nĐang cập nhật bảng theo dõi xu hướng từ khóa trong DB...")
    res = analyze_and_update_keyword_trends()
    print(f"Kết quả phân tích: Tracked {res.get('keywords_tracked')} từ khóa theo ngày.")

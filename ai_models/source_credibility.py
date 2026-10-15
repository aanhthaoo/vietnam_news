"""
ai_models/source_credibility.py
================================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu:
  1. Đánh giá chất lượng và độ tin cậy của các nguồn báo quốc tế khi đưa tin về Việt Nam (Model 6).
  2. Chấm điểm độ tin cậy định lượng S in [0, 100] dựa trên 3 tiêu chí:
     - Tiêu chí 1 (Trọng số 30%): Tính nhất quán sắc thái (Sentiment Consistency) dựa trên độ phân tán/phương sai cảm xúc.
     - Tiêu chí 2 (Trọng số 35%): Độ sâu bài viết (Content Completeness) dựa trên dung lượng từ trung bình (word_count).
     - Tiêu chí 3 (Trọng số 35%): Tỷ lệ bài viết chuyên sâu về Việt Nam (Vietnam Relevance Ratio).
  3. Phân tầng nguồn tin (Tier 1: High Credibility, Tier 2: Moderate, Tier 3: Low).
"""

import sys
import logging
from pathlib import Path
from typing import Dict, Any, List

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

logger = logging.getLogger(__name__)


def evaluate_source_credibility() -> List[Dict[str, Any]]:
    """
    Truy vấn toàn bộ bài viết từ CSDL, tính toán các chỉ số thống kê và chấm điểm
    độ uy tín cho từng hãng tin (source_name).
    """
    from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres

    query = """
    SELECT 
        COALESCE(source_name, 'Unknown') AS source_name,
        COALESCE(sentiment_score, 0.0) AS sentiment_score,
        COALESCE(vader_compound, 0.0) AS vader_compound,
        COALESCE(word_count, 0) AS word_count,
        COALESCE(is_vietnam_relevant, 0) AS is_vietnam_relevant
    FROM news_vietnam_articles
    WHERE source_name IS NOT NULL AND TRIM(source_name) != '';
    """

    if is_postgres():
        conn = get_pg_connection()
        df = pd.read_sql_query(query, conn)
        conn.close()
    else:
        conn = get_sqlite_connection()
        df = pd.read_sql_query(query, conn)
        conn.close()

    if df.empty:
        logger.warning("[Credibility] Không có dữ liệu bài viết để chấm điểm nguồn.")
        return []

    results: List[Dict[str, Any]] = []

    # Nhóm theo từng nguồn tin
    for source, group in df.groupby("source_name"):
        total_articles = len(group)
        if total_articles == 0:
            continue

        # 1. Tính nhất quán cảm xúc (Sentiment Consistency - 30%)
        # Nguồn báo giật tít thường có độ biến động cảm xúc rất lớn (std cao)
        # Nguồn uy tín chuẩn mực thường giữ văn phong trung tính/chừng mực
        sentiment_std = float(group["sentiment_score"].std()) if total_articles > 1 else 0.1
        if np.isnan(sentiment_std):
            sentiment_std = 0.1
        # std thường nằm trong khoảng [0, 0.6]. std càng nhỏ, điểm consistency càng cao
        consistency_score = max(0.0, min(100.0, 100.0 - (sentiment_std * 100.0)))

        # 2. Độ sâu nội dung (Content Completeness - 35%)
        # Dựa trên số lượng từ trung bình, mốc lý tưởng là 300 - 500 từ trở lên
        avg_word_count = float(group["word_count"].mean())
        content_score = max(10.0, min(100.0, (avg_word_count / 300.0) * 100.0))

        # 3. Tỷ lệ tập trung vào Việt Nam (Vietnam Relevance Ratio - 35%)
        vn_relevant_count = int(group["is_vietnam_relevant"].sum())
        vn_ratio = (vn_relevant_count / total_articles) if total_articles > 0 else 0.0
        relevance_score = vn_ratio * 100.0

        # Trọng số tổng hợp
        raw_credibility = (
            0.30 * consistency_score +
            0.35 * content_score +
            0.35 * relevance_score
        )

        # Điều chỉnh theo số lượng mẫu (Volume confidence factor)
        # Nếu nguồn mới chỉ có 1-2 bài thì giảm nhẹ độ tin cậy để tránh thiên vị mẫu nhỏ
        if total_articles < 3:
            volume_multiplier = 0.8
        elif total_articles < 5:
            volume_multiplier = 0.9
        else:
            volume_multiplier = 1.0

        final_score = round(raw_credibility * volume_multiplier, 1)
        final_score = max(10.0, min(100.0, final_score))

        # Phân loại Tier
        if final_score >= 75.0:
            tier = "Tier 1 (Uy tín cao)"
        elif final_score >= 50.0:
            tier = "Tier 2 (Trung bình)"
        else:
            tier = "Tier 3 (Cần kiểm chứng)"

        results.append({
            "source_name": str(source),
            "total_articles": total_articles,
            "avg_word_count": round(avg_word_count, 1),
            "vn_relevance_pct": round(vn_ratio * 100, 1),
            "sentiment_std": round(sentiment_std, 3),
            "consistency_score": round(consistency_score, 1),
            "content_score": round(content_score, 1),
            "relevance_score": round(relevance_score, 1),
            "credibility_score": final_score,
            "tier": tier
        })

    # Sắp xếp theo điểm uy tín giảm dần
    results.sort(key=lambda x: (x["credibility_score"], x["total_articles"]), reverse=True)
    return results


def get_top_credible_sources(top_n: int = 10) -> List[Dict[str, Any]]:
    """Lấy danh sách Top N nguồn báo có điểm uy tín cao nhất."""
    ranking = evaluate_source_credibility()
    return ranking[:top_n]


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("--- CHẠY THỬ NGHIỆM MODULE CHẤM ĐIỂM UY TÍN NGUỒN BÁO (SOURCE CREDIBILITY) ---")
    rankings = evaluate_source_credibility()
    print(f"Tổng số nguồn báo được phân tích: {len(rankings)}\n")
    print(f"{'Hạng':<5} {'Nguồn báo':<30} {'Số bài':<8} {'Từ TB':<8} {'% VN':<8} {'Điểm uy tín':<12} {'Phân loại'}")
    print("-" * 85)
    for idx, r in enumerate(rankings, 1):
        print(f"{idx:<5} {r['source_name'][:28]:<30} {r['total_articles']:<8} {r['avg_word_count']:<8} {r['vn_relevance_pct']:<8} {r['credibility_score']:<12} {r['tier']}")

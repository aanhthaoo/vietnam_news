"""
ai_models/breaking_news.py
==========================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu:
  1. Tự động phát hiện tin nóng / sự kiện bất thường (Spike & Anomaly Detection).
  2. Thuật toán Z-Score trên cửa sổ trượt 7 ngày (Rolling 7-day Window) của khối lượng tin tức.
  3. Kết hợp tỷ lệ sắc thái tiêu cực và chủ đề nổi bật để giải thích nguyên nhân (`spike_reason`).
"""

import sys
import os
import logging
from datetime import datetime, timedelta
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


def detect_breaking_news_spikes(z_threshold: float = 2.0) -> List[Dict[str, Any]]:
    """
    Phân tích chuỗi thời gian số lượng tin tức hàng ngày, tính toán Z-score và phát hiện
    các ngày có sự kiện tin nóng đột biến.
    """
    from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres

    query = """
    SELECT 
        DATE(COALESCE(published_at, collected_at)) as date_str,
        COUNT(*) as total_articles,
        SUM(CASE WHEN ensemble_sentiment_label = 'Negative' THEN 1 ELSE 0 END) as negative_count,
        SUM(CASE WHEN ensemble_sentiment_label = 'Positive' THEN 1 ELSE 0 END) as positive_count,
        MAX(topic_label) as leading_topic
    FROM news_vietnam_articles
    WHERE published_at IS NOT NULL OR collected_at IS NOT NULL
    GROUP BY DATE(COALESCE(published_at, collected_at))
    ORDER BY date_str ASC;
    """

    if is_postgres():
        conn = get_pg_connection()
        df = pd.read_sql_query(query, conn)
        conn.close()
    else:
        conn = get_sqlite_connection()
        df = pd.read_sql_query(query, conn)
        conn.close()

    if df.empty or len(df) < 3:
        # Trường hợp ít ngày, tạo giả lập từ bài báo
        return [{
            "date": datetime.now().strftime("%Y-%m-%d"),
            "total_articles": len(df),
            "z_score": 0.0,
            "is_breaking_news": 0,
            "spike_reason": "Dữ liệu lịch sử đang được tích lũy (chưa đủ 3 ngày)."
        }]

    df["date"] = pd.to_datetime(df["date_str"])
    df = df.sort_values("date").reset_index(drop=True)

    # Tính Rolling 7-day mean và std
    # Dùng min_periods=2 để tính được ngay cả khi mới có ít ngày
    rolling_window = 7
    df["rolling_mean"] = df["total_articles"].rolling(window=rolling_window, min_periods=2).mean().shift(1)
    df["rolling_std"] = df["total_articles"].rolling(window=rolling_window, min_periods=2).std().shift(1)

    # Điền giá trị mặc định cho các ngày đầu
    global_mean = df["total_articles"].mean()
    global_std = max(df["total_articles"].std(), 1.0)
    df["rolling_mean"] = df["rolling_mean"].fillna(global_mean)
    df["rolling_std"] = df["rolling_std"].fillna(global_std).replace(0, 1.0)

    # Tính Z-Score
    df["z_score"] = (df["total_articles"] - df["rolling_mean"]) / df["rolling_std"]
    df["z_score"] = df["z_score"].round(2)

    results: List[Dict[str, Any]] = []

    for _, row in df.iterrows():
        cnt = int(row["total_articles"])
        z = float(row["z_score"])
        neg_cnt = int(row["negative_count"])
        neg_ratio = (neg_cnt / cnt) if cnt > 0 else 0.0
        lead_topic = row["leading_topic"] or "General"
        d_str = str(row["date_str"])

        # Tiêu chí phát hiện Tin Nóng:
        # 1. Z >= z_threshold (thường là 2.0)
        # 2. Hoặc Z >= 1.5 kết hợp tỷ lệ tiêu cực >= 40% (sự kiện khủng hoảng)
        is_breaking = False
        reasons = []

        if z >= z_threshold:
            is_breaking = True
            reasons.append(f"Số lượng tin tăng đột biến (Z-Score = +{z}, cao hơn đáng kể so với trung bình)")
        elif z >= 1.5 and neg_ratio >= 0.40:
            is_breaking = True
            reasons.append(f"Cảnh báo khủng hoảng: Lượng tin tăng nhanh (Z={z}) kèm {neg_ratio*100:.0f}% sắc thái tiêu cực")

        if is_breaking:
            reasons.append(f"Chủ đề chiếm ưu thế trong ngày: '{lead_topic}'")
            spike_reason = " | ".join(reasons)
        else:
            spike_reason = "Lượng tin tức duy trì ở mức bình thường theo xu hướng tuần."

        results.append({
            "date": d_str,
            "total_articles": cnt,
            "z_score": z,
            "is_breaking_news": 1 if is_breaking else 0,
            "spike_reason": spike_reason,
            "leading_topic": lead_topic,
            "negative_ratio_pct": round(neg_ratio * 100, 1)
        })

    return results


def get_latest_breaking_alert() -> Dict[str, Any]:
    """Trả về cảnh báo tin nóng mới nhất cho ngày gần nhất."""
    spikes = detect_breaking_news_spikes(z_threshold=1.8)
    if not spikes:
        return {"is_breaking_news": 0, "message": "Không có cảnh báo."}
    latest = spikes[-1]
    return latest


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("--- CHẠY THỬ NGHIỆM MODULE BREAKING NEWS DETECTION (Z-SCORE SPIKE) ---")
    alerts = detect_breaking_news_spikes(z_threshold=1.5)
    print(f"Tổng số ngày được phân tích: {len(alerts)}")

    breaking_days = [a for a in alerts if a["is_breaking_news"] == 1]
    print(f"Số ngày kích hoạt cảnh báo sự kiện đột biến: {len(breaking_days)}")
    for b in breaking_days:
        print(f"  🚨 [{b['date']}] {b['total_articles']} bài (Z={b['z_score']}) -> {b['spike_reason']}")

    latest = get_latest_breaking_alert()
    print(f"\nTrạng thái ngày gần nhất ({latest.get('date')}): {'🚨 CÓ SỰ KIỆN NÓNG' if latest.get('is_breaking_news') else '✅ Bình thường'}")
    print(f"Chi tiết: {latest.get('spike_reason')}")

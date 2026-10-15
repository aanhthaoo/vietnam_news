"""
ai_models/deduplicator.py
=========================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu:
  1. Gom cụm các bài báo cùng đưa tin về một sự kiện (Story Clustering).
  2. Đo lường mức độ lan tỏa truyền thông (Media Coverage / Viral Impact) bằng số lượng nguồn báo.
  3. Sử dụng Cosine Similarity trên ma trận TF-IDF (ngưỡng tương đồng >= 0.65 - 0.75).
  4. Gán `story_cluster_id` vào CSDL (PostgreSQL & SQLite).
"""

import sys
import os
import re
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Set

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
from sklearn.metrics.pairwise import cosine_similarity

logger = logging.getLogger(__name__)


def clean_headline_for_sim(text: str) -> str:
    """Chuẩn hóa tiêu đề/mô tả trước khi tính độ tương đồng."""
    if not text:
        return ""
    text = re.sub(r"[^a-zA-Z0-9\s]", " ", text.lower())
    return re.sub(r"\s+", " ", text).strip()


def cluster_articles_by_similarity(
    articles: List[Dict[str, Any]],
    similarity_threshold: float = 0.65
) -> List[Dict[str, Any]]:
    """
    Gom cụm các bài báo cùng câu chuyện dựa trên Cosine Similarity.
    Gán trường `story_cluster_id` vào từng bài báo.
    """
    n = len(articles)
    if n == 0:
        return []
    if n == 1:
        articles[0]["story_cluster_id"] = 1
        return articles

    # Chuẩn bị văn bản biểu diễn bài báo (Tiêu đề + Mô tả)
    texts = [
        clean_headline_for_sim(f"{a.get('title', '')} {a.get('description', '')}")
        for a in articles
    ]

    try:
        vec = TfidfVectorizer(
            stop_words="english",
            ngram_range=(1, 2),
            min_df=1,
            max_df=0.9,
            max_features=1000
        )
        tfidf_matrix = vec.fit_transform(texts)
        sim_matrix = cosine_similarity(tfidf_matrix)
    except Exception as e:
        logger.warning(f"[Deduplicator] Lỗi tính ma trận tương đồng: {e}")
        for i, a in enumerate(articles, 1):
            a["story_cluster_id"] = i
        return articles

    # Thuật toán Connected Components bằng DFS gom cụm
    visited: Set[int] = set()
    cluster_counter = 1

    for i in range(n):
        if i in visited:
            continue
        cluster: List[int] = []
        stack = [i]
        visited.add(i)

        while stack:
            curr = stack.pop()
            cluster.append(curr)
            for neighbor in range(n):
                if neighbor not in visited and sim_matrix[curr][neighbor] >= similarity_threshold:
                    visited.add(neighbor)
                    stack.append(neighbor)

        # Gán cluster_id
        for member_idx in cluster:
            articles[member_idx]["story_cluster_id"] = cluster_counter
        cluster_counter += 1

    return articles


def cluster_and_update_db(similarity_threshold: float = 0.65) -> Dict[str, Any]:
    """
    Quét toàn bộ bài báo trong CSDL, chạy thuật toán Story Clustering và cập nhật
    cột `story_cluster_id` vào cả PostgreSQL và SQLite.
    """
    from news_pipeline.store_news import get_pg_connection, get_sqlite_connection, is_postgres

    if is_postgres():
        conn = get_pg_connection()
        query = "SELECT id, title, description, content, source_name, published_at FROM news_vietnam_articles ORDER BY id ASC;"
        df = pd.read_sql_query(query, conn)
        conn.close()
    else:
        conn = get_sqlite_connection()
        query = "SELECT id, title, description, content, source_name, published_at FROM news_vietnam_articles ORDER BY id ASC;"
        df = pd.read_sql_query(query, conn)
        conn.close()

    if df.empty:
        return {"status": "empty", "total_articles": 0, "total_clusters": 0}

    articles = df.to_dict(orient="records")
    clustered = cluster_articles_by_similarity(articles, similarity_threshold=similarity_threshold)

    # Thống kê cụm
    cluster_sizes: Dict[int, int] = {}
    updates = []
    for a in clustered:
        c_id = a["story_cluster_id"]
        cluster_sizes[c_id] = cluster_sizes.get(c_id, 0) + 1
        updates.append((c_id, a["id"]))

    multi_article_clusters = sum(1 for cnt in cluster_sizes.values() if cnt > 1)

    # Cập nhật PostgreSQL
    if is_postgres():
        conn = get_pg_connection()
        try:
            with conn.cursor() as cur:
                for c_id, a_id in updates:
                    cur.execute("UPDATE news_vietnam_articles SET story_cluster_id = %s WHERE id = %s;", (c_id, a_id))
            conn.commit()
            logger.info(f"[Deduplicator] PostgreSQL: Đã cập nhật {len(updates)} bài báo vào {len(cluster_sizes)} cụm.")
        finally:
            conn.close()

    # Cập nhật SQLite
    conn_sq = get_sqlite_connection()
    try:
        with conn_sq:
            for c_id, a_id in updates:
                conn_sq.execute("UPDATE news_vietnam_articles SET story_cluster_id = ? WHERE id = ?;", (c_id, a_id))
        logger.info(f"[Deduplicator] SQLite: Đã cập nhật {len(updates)} bài báo vào {len(cluster_sizes)} cụm.")
    finally:
        conn_sq.close()

    return {
        "status": "success",
        "total_articles": len(articles),
        "total_clusters": len(cluster_sizes),
        "multi_source_clusters": multi_article_clusters,
        "largest_cluster_size": max(cluster_sizes.values()) if cluster_sizes else 0
    }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("--- CHẠY THỬ NGHIỆM MODULE DEDUPLICATION & STORY CLUSTERING ---")
    test_data = [
        {"id": 1, "title": "VinFast starts delivery of VF3 in Vietnam", "description": "Electric automaker VinFast delivers first batch."},
        {"id": 2, "title": "VinFast begins delivering mini electric SUV VF3 to customers", "description": "First VF3 electric cars reach Vietnamese buyers."},
        {"id": 3, "title": "Vietnam GDP expands 7.4% in third quarter", "description": "Strong economic growth fueled by electronics exports."},
        {"id": 4, "title": "Heavy rain triggers flooding in Hanoi streets", "description": "Monsoon rain inundates several districts in the capital."}
    ]

    res = cluster_articles_by_similarity(test_data, similarity_threshold=0.60)
    print("Kết quả gom cụm mẫu:")
    for a in res:
        print(f"  [Cluster #{a['story_cluster_id']}] {a['title']}")

    print("\nĐang cập nhật phân cụm cho toàn bộ bài báo trong CSDL...")
    db_res = cluster_and_update_db(similarity_threshold=0.60)
    print(f"Kết quả CSDL: {db_res.get('total_articles')} bài -> {db_res.get('total_clusters')} cụm (Cụm có >=2 bài: {db_res.get('multi_source_clusters')}).")

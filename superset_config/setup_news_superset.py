"""
setup_news_superset.py
======================
Kết nối Apache Superset với PostgreSQL (vietnam_news) và tạo các Datasets.

Chạy bên trong Docker container:
  docker exec vietnam_news_superset python /app/pythonpath/setup_news_superset.py
"""

import sys
from superset.app import create_app

app = create_app()

with app.app_context():
    from superset import db
    from superset.models.core import Database
    from superset.connectors.sqla.models import SqlaTable

    # ── Database Connection (PostgreSQL) ──────────────────────────────────────
    db_name = "Vietnam_News_DB"
    uri     = "postgresql://postgres:vietnam_news_password@vietnam_news_postgres:5432/vietnam_news"

    database = db.session.query(Database).filter_by(database_name=db_name).first()
    if not database:
        database = Database(
            database_name=db_name,
            sqlalchemy_uri=uri,
            expose_in_sqllab=True,
            allow_ctas=False,
            allow_cvas=False,
            allow_dml=False,
        )
        db.session.add(database)
        db.session.commit()
        print(f"[+] Database '{db_name}' da tao voi PostgreSQL.")
    else:
        database.sqlalchemy_uri  = uri
        database.expose_in_sqllab = True
        db.session.commit()
        print(f"[=] Database '{db_name}' da ton tai. Cap nhat URI sang PostgreSQL.")

    # ── Physical Dataset ──────────────────────────────────────────────────────
    phys_name = "news_vietnam_articles"
    phys      = db.session.query(SqlaTable).filter_by(
        database_id=database.id, table_name=phys_name
    ).first()

    if not phys:
        phys = SqlaTable(table_name=phys_name, database_id=database.id)
        db.session.add(phys)
        db.session.commit()
        phys.fetch_metadata()
        db.session.commit()
        print(f"[+] Physical Dataset '{phys_name}' ({len(phys.columns)} columns)")
    else:
        phys.fetch_metadata()
        db.session.commit()
        print(f"[=] Physical Dataset '{phys_name}' refreshed.")

    # Physical Dataset: news_volume_forecast
    fc_name = "news_volume_forecast"
    fc_phys = db.session.query(SqlaTable).filter_by(
        database_id=database.id, table_name=fc_name
    ).first()
    if not fc_phys:
        fc_phys = SqlaTable(table_name=fc_name, database_id=database.id)
        db.session.add(fc_phys)
        db.session.commit()
        fc_phys.fetch_metadata()
        db.session.commit()
        print(f"[+] Physical Dataset '{fc_name}' ({len(fc_phys.columns)} columns)")
    else:
        fc_phys.fetch_metadata()
        db.session.commit()
        print(f"[=] Physical Dataset '{fc_name}' refreshed.")

    # ── Virtual Datasets ──────────────────────────────────────────────────────
    virtual_datasets = [
        {
            "name": "news_daily_summary",
            "sql": """
SELECT
    DATE(published_at)                            AS date,
    COUNT(*)                                      AS article_count,
    SUM(CASE WHEN sentiment_label = 'Positive' THEN 1 ELSE 0 END) AS positive_count,
    SUM(CASE WHEN sentiment_label = 'Negative' THEN 1 ELSE 0 END) AS negative_count,
    SUM(CASE WHEN sentiment_label = 'Neutral'  THEN 1 ELSE 0 END) AS neutral_count,
    ROUND(AVG(sentiment_score)::numeric, 4)       AS avg_sentiment_score
FROM news_vietnam_articles
WHERE published_at IS NOT NULL
GROUP BY DATE(published_at)
ORDER BY date
            """.strip(),
        },
        {
            "name": "news_source_ranking",
            "sql": """
SELECT
    source_name,
    COUNT(*)                                      AS article_count,
    ROUND(AVG(sentiment_score)::numeric, 3)        AS avg_sentiment,
    SUM(CASE WHEN sentiment_label = 'Positive' THEN 1 ELSE 0 END) AS positive_count,
    SUM(CASE WHEN sentiment_label = 'Negative' THEN 1 ELSE 0 END) AS negative_count,
    SUM(CASE WHEN sentiment_label = 'Neutral'  THEN 1 ELSE 0 END) AS neutral_count
FROM news_vietnam_articles
WHERE source_name IS NOT NULL AND source_name != ''
GROUP BY source_name
ORDER BY article_count DESC
LIMIT 20
            """.strip(),
        },
        {
            "name": "news_sentiment_breakdown",
            "sql": """
SELECT
    sentiment_label,
    COUNT(*) AS article_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM news_vietnam_articles), 1) AS percentage
FROM news_vietnam_articles
WHERE sentiment_label IS NOT NULL
GROUP BY sentiment_label
ORDER BY article_count DESC
            """.strip(),
        },
        {
            "name": "news_full_view",
            "sql": """
SELECT
    id,
    title,
    description,
    url,
    source_name,
    author,
    DATE(published_at) AS pub_date,
    published_at,
    collected_at,
    sentiment_label,
    sentiment_score,
    entities_org,
    entities_gpe,
    entities_person
FROM news_vietnam_articles
ORDER BY published_at DESC
            """.strip(),
        },
        {
            "name": "news_keyword_cloud",
            "sql": """
SELECT lower(word) AS word, count(*) AS count
FROM (
    SELECT regexp_split_to_table(regexp_replace(title, '[^a-zA-Z\\s]', '', 'g'), '\\s+') AS word
    FROM news_vietnam_articles
) t
WHERE length(word) > 3 
  AND lower(word) NOT IN ('with', 'from', 'that', 'this', 'have', 'were', 'which', 'about', 'after', 'vietnam', 'vietnams', 'more', 'into', 'over', 'their', 'will', 'been')
GROUP BY lower(word)
ORDER BY count DESC
LIMIT 50
            """.strip(),
        },
        {
            "name": "news_ai_topics",
            "sql": """
SELECT 
    topic_label,
    COUNT(*) AS article_count,
    ROUND(AVG(COALESCE(sentiment_score, 0))::numeric, 3) AS avg_sentiment,
    SUM(CASE WHEN is_vietnam_relevant = 1 THEN 1 ELSE 0 END) AS vn_relevant_count
FROM news_vietnam_articles
GROUP BY topic_label
ORDER BY article_count DESC
            """.strip(),
        },
        {
            "name": "news_ensemble_sentiment",
            "sql": """
SELECT 
    ensemble_sentiment_label,
    COUNT(*) AS article_count,
    ROUND(AVG(COALESCE(vader_compound, 0))::numeric, 3) AS avg_vader_compound,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM news_vietnam_articles), 1) AS percentage
FROM news_vietnam_articles
GROUP BY ensemble_sentiment_label
ORDER BY article_count DESC
            """.strip(),
        },
        {
            "name": "news_vietnam_relevance",
            "sql": """
SELECT 
    CASE WHEN is_vietnam_relevant = 1 THEN 'Chuẩn tin Việt Nam' ELSE 'Tin nhắc lướt / Ngoài lề' END AS status,
    COUNT(*) AS article_count,
    ROUND(AVG(vietnam_relevance_score)::numeric, 2) AS avg_score,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM news_vietnam_articles), 1) AS percentage
FROM news_vietnam_articles
GROUP BY is_vietnam_relevant
            """.strip(),
        },
        {
            "name": "news_forecast_vs_actual",
            "sql": """
SELECT 
    TO_DATE(forecast_date, 'YYYY-MM-DD') AS date,
    predicted_count,
    lower_bound,
    upper_bound,
    model_type
FROM news_volume_forecast
ORDER BY forecast_date ASC
            """.strip(),
        },
        {
            "name": "news_ai_summary_table",
            "sql": """
SELECT 
    id,
    title,
    source_name,
    DATE(published_at) AS pub_date,
    topic_label,
    ensemble_sentiment_label,
    is_vietnam_relevant,
    ai_summary,
    word_count,
    url
FROM news_vietnam_articles
ORDER BY published_at DESC
LIMIT 100
            """.strip(),
        },
        {
            "name": "news_keyword_trends",
            "sql": """
SELECT 
    id,
    date_str,
    keyword,
    frequency,
    trend_direction,
    trend_delta
FROM news_keyword_trends
ORDER BY frequency DESC
            """.strip(),
        },
        {
            "name": "news_source_credibility",
            "sql": """
SELECT 
    source_name,
    total_articles,
    avg_word_count,
    vn_relevance_pct,
    avg_sentiment,
    credibility_score
FROM vw_source_credibility
ORDER BY credibility_score DESC
            """.strip(),
        },
        {
            "name": "news_story_clusters",
            "sql": """
SELECT 
    story_cluster_id,
    lead_title,
    article_count,
    unique_sources,
    first_published,
    last_published,
    main_topic,
    dominant_sentiment
FROM vw_story_clusters
ORDER BY article_count DESC
            """.strip(),
        },
    ]

    for vd in virtual_datasets:
        v_name = vd["name"]
        v_sql  = vd["sql"]
        v_tbl  = db.session.query(SqlaTable).filter_by(
            database_id=database.id, table_name=v_name
        ).first()

        if not v_tbl:
            v_tbl = SqlaTable(table_name=v_name, database_id=database.id, sql=v_sql)
            db.session.add(v_tbl)
            db.session.commit()
            v_tbl.fetch_metadata()
            db.session.commit()
            print(f"[+] Virtual Dataset '{v_name}' ({len(v_tbl.columns)} columns)")
        else:
            v_tbl.sql = v_sql
            v_tbl.fetch_metadata()
            db.session.commit()
            print(f"[=] Virtual Dataset '{v_name}' updated.")

        for col in v_tbl.columns:
            if col.column_name in ("date", "pub_date", "published_at"):
                col.is_dttm = True
        db.session.commit()

    print("\n>>> [OK] Tat ca Datasets san sang tren PostgreSQL!")
    print(">>> Truy cap: http://localhost:8088")

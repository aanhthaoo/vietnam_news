"""
build_ai_dashboard.py
=====================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu: Tự động khởi tạo và cấu hình Dashboard "🤖 Vietnam News AI Analytics & Forecasting" trên Apache Superset.
Bao gồm đầy đủ 8 Charts BI trực quan hóa các mô hình AI:
  1. Big Number: Tổng tin tức thu thập
  2. Big Number: Tỉ lệ bài báo chuẩn về Việt Nam
  3. Donut Chart: Phân tích Cảm xúc Ensemble (VADER + TextBlob)
  4. Bar Chart: Phân bố 8 Chủ đề Tin tức (Rule-based AI)
  5. Line Chart: Dự báo Số lượng Tin tức 7 ngày tới (LinearRegression)
  6. Bar Chart: Xếp hạng Nguồn báo & Cảm xúc
  7. Table Chart: Bảng Tin tức & Tóm tắt Tự động Gemini
  8. Word Cloud: Đám mây Từ khóa Tiêu biểu

Chạy bên trong Superset Docker container:
  docker exec vietnam_news_superset python /app/pythonpath/build_ai_dashboard.py
"""

import json
import sys
import logging
from superset.app import create_app

app = create_app()
logger = logging.getLogger(__name__)

DASHBOARD_TITLE = "🤖 Vietnam News AI Analytics & Forecasting"

with app.app_context():
    from superset import db
    from superset.models.core import Database
    from superset.connectors.sqla.models import SqlaTable
    from superset.models.slice import Slice
    from superset.models.dashboard import Dashboard

    database = db.session.query(Database).filter_by(
        database_name="Vietnam_News_DB"
    ).first()

    if not database:
        print("❌ Chưa tìm thấy Database 'Vietnam_News_DB'.")
        print("   Hãy chạy setup_news_superset.py trước!")
        sys.exit(1)

    def get_dataset(table_name: str) -> SqlaTable | None:
        return (
            db.session.query(SqlaTable)
            .filter_by(database_id=database.id, table_name=table_name)
            .first()
        )

    def create_or_update_chart(
        chart_name: str,
        viz_type: str,
        dataset_name: str,
        params: dict,
        query_context: dict | None = None,
    ) -> Slice | None:
        dataset = get_dataset(dataset_name)
        if not dataset:
            print(f"  ⚠️  Dataset '{dataset_name}' chưa tồn tại. Bỏ qua chart '{chart_name}'.")
            return None

        params["datasource"] = f"{dataset.id}__table"
        chart = db.session.query(Slice).filter_by(slice_name=chart_name).first()
        if not chart:
            chart = Slice(
                slice_name=chart_name,
                viz_type=viz_type,
                datasource_type="table",
                datasource_id=dataset.id,
                params=json.dumps(params),
                query_context=json.dumps(query_context) if query_context else None,
            )
            db.session.add(chart)
            db.session.commit()
            print(f"  [+] Chart tạo mới: '{chart_name}' ({viz_type})")
        else:
            chart.viz_type      = viz_type
            chart.datasource_id = dataset.id
            chart.params        = json.dumps(params)
            if query_context:
                chart.query_context = json.dumps(query_context)
            db.session.commit()
            print(f"  [=] Chart cập nhật: '{chart_name}' ({viz_type})")

        return chart

    print("\n[AI CHARTS] Đang khởi tạo 8 biểu đồ phân tích AI...")
    charts = []

    # Chart 1: Big Number — Tổng số bài báo
    ds_phys = get_dataset("news_vietnam_articles")
    c1 = create_or_update_chart(
        chart_name="📰 Tổng số bài báo",
        viz_type="big_number_total",
        dataset_name="news_vietnam_articles",
        params={
            "viz_type":       "big_number_total",
            "metric":         {"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT", "label": "Tổng bài"},
            "subheader":      "Toàn bộ tin tức đã thu thập & phân tích",
            "color_scheme":   "supersetColors",
        }
    )
    if c1: charts.append(c1)

    # Chart 2: Big Number — Tỉ lệ tin chuẩn về Việt Nam
    ds_rel = get_dataset("news_vietnam_relevance")
    c2 = create_or_update_chart(
        chart_name="🇻🇳 Tỉ lệ tin chuẩn Việt Nam",
        viz_type="pie",
        dataset_name="news_vietnam_relevance",
        params={
            "viz_type":       "pie",
            "metric":         {"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"},
            "groupby":        ["status"],
            "row_limit":      10,
            "pie_label_type": "key_percent",
            "show_legend":    True,
            "donut":          True,
            "color_scheme":   "supersetColors",
        }
    )
    if c2: charts.append(c2)

    # Chart 3: Donut Chart — Phân bố cảm xúc Ensemble
    c3 = create_or_update_chart(
        chart_name="🎭 Cảm xúc Đa mô hình Ensemble (VADER + TextBlob)",
        viz_type="pie",
        dataset_name="news_ensemble_sentiment",
        params={
            "viz_type":       "pie",
            "metric":         {"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"},
            "groupby":        ["ensemble_sentiment_label"],
            "row_limit":      10,
            "pie_label_type": "key_percent",
            "show_legend":    True,
            "donut":          True,
            "color_scheme":   "supersetColors",
        }
    )
    if c3: charts.append(c3)

    # Chart 4: Bar Chart — Phân bố 8 Chủ đề Tin tức
    c4 = create_or_update_chart(
        chart_name="🏷️ Phân loại 8 Chủ đề Tin tức (AI Rules)",
        viz_type="echarts_timeseries_bar",
        dataset_name="news_ai_topics",
        params={
            "viz_type":     "echarts_timeseries_bar",
            "x_axis":       "topic_label",
            "time_range":   "No filter",
            "metrics":      [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"}],
            "groupby":      [],
            "row_limit":    20,
            "order_desc":   True,
            "orientation":  "vertical",
            "show_legend":  False,
            "rich_tooltip": True,
            "x_axis_title": "Chủ đề",
            "y_axis_title": "Số lượng bài báo",
            "color_scheme": "supersetColors",
        }
    )
    if c4: charts.append(c4)

    # Chart 5: Line Chart — Dự báo Số lượng Tin tức 7 ngày tới (LinearRegression)
    c5 = create_or_update_chart(
        chart_name="📈 Dự báo Số lượng Tin tức 7 ngày tới (LinearRegression)",
        viz_type="echarts_timeseries_line",
        dataset_name="news_forecast_vs_actual",
        params={
            "viz_type":     "echarts_timeseries_line",
            "x_axis":       "date",
            "time_range":   "No filter",
            "metrics":      [
                {"expressionType": "SIMPLE", "column": {"column_name": "predicted_count"}, "aggregate": "AVG", "label": "Dự báo (Predicted)"},
                {"expressionType": "SIMPLE", "column": {"column_name": "upper_bound"}, "aggregate": "AVG", "label": "Cận trên (Upper 95%)"},
                {"expressionType": "SIMPLE", "column": {"column_name": "lower_bound"}, "aggregate": "AVG", "label": "Cận dưới (Lower 95%)"},
            ],
            "groupby":      [],
            "seriesType":   "line",
            "show_legend":  True,
            "rich_tooltip": True,
            "x_axis_title": "Ngày dự báo",
            "y_axis_title": "Số lượng bài báo",
            "color_scheme": "supersetColors",
        }
    )
    if c5: charts.append(c5)

    # Chart 6: Top nguồn báo
    c6 = create_or_update_chart(
        chart_name="🏆 Top 10 Nguồn báo & Khối lượng",
        viz_type="echarts_timeseries_bar",
        dataset_name="news_source_ranking",
        params={
            "viz_type":     "echarts_timeseries_bar",
            "x_axis":       "source_name",
            "time_range":   "No filter",
            "metrics":      [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"}],
            "groupby":      [],
            "row_limit":    10,
            "order_desc":   True,
            "orientation":  "vertical",
            "show_legend":  False,
            "rich_tooltip": True,
            "x_axis_title": "Nguồn báo",
            "y_axis_title": "Số lượng tin",
            "color_scheme": "supersetColors",
        }
    )
    if c6: charts.append(c6)

    # Chart 7: Word Cloud
    c7 = create_or_update_chart(
        chart_name="☁️ Đám mây Từ khóa Tiêu biểu",
        viz_type="word_cloud",
        dataset_name="news_keyword_cloud",
        params={
            "viz_type":       "word_cloud",
            "series":         "word",
            "metric":         {"expressionType": "SIMPLE", "column": {"column_name": "count"}, "aggregate": "SUM", "label": "Tần suất"},
            "row_limit":      60,
            "color_scheme":   "supersetColors",
        }
    )
    if c7: charts.append(c7)

    # Chart 8: Bảng tin tức tóm tắt AI
    c8 = create_or_update_chart(
        chart_name="📋 Danh sách Tin tức & Tóm tắt AI (Gemini)",
        viz_type="table",
        dataset_name="news_ai_summary_table",
        params={
            "viz_type":       "table",
            "all_columns":    ["title", "source_name", "topic_label", "ensemble_sentiment_label", "ai_summary", "pub_date"],
            "order_by_cols":  ["[\"pub_date\", false]"],
            "row_limit":      50,
            "page_length":    10,
            "include_search": True,
            "table_timestamp_format": "smart_date",
        }
    )
    if c8: charts.append(c8)

    # Chart 9: Horizontal Bar Chart — Đánh giá Độ uy tín Nguồn báo (Source Credibility Ranking)
    c9 = create_or_update_chart(
        chart_name="⭐ Xếp hạng Độ uy tín Nguồn báo Quốc tế (Source Credibility)",
        viz_type="echarts_timeseries_bar",
        dataset_name="news_source_credibility",
        params={
            "viz_type":       "echarts_timeseries_bar",
            "x_axis":         "source_name",
            "time_range":     "No filter",
            "metrics":        [{"expressionType": "SIMPLE", "column": {"column_name": "credibility_score"}, "aggregate": "AVG", "label": "Điểm uy tín (0-100)"}],
            "groupby":        [],
            "row_limit":      15,
            "order_desc":     True,
            "orientation":    "horizontal",
            "show_legend":    False,
            "rich_tooltip":   True,
            "x_axis_title":   "Điểm uy tín (0-100)",
            "y_axis_title":   "Nguồn báo",
            "color_scheme":   "supersetColors",
        }
    )
    if c9: charts.append(c9)

    # Chart 10: Treemap — Bản đồ Nhiệt Cụm Sự kiện & Độ phủ Truyền thông (Story Clusters Treemap)
    c10 = create_or_update_chart(
        chart_name="🌐 Bản đồ Nhiệt Cụm Sự kiện & Độ phủ Truyền thông (Story Clusters Treemap)",
        viz_type="treemap",
        dataset_name="news_story_clusters",
        params={
            "viz_type":       "treemap",
            "metric":         {"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài viết"},
            "metrics":        [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài viết"}],
            "groupby":        ["main_topic", "lead_title"],
            "row_limit":      40,
            "color_scheme":   "supersetColors",
            "treemap_ratio":  1.618,
            "number_format":  "SMART_NUMBER",
            "rich_tooltip":   True,
        }
    )
    if c10: charts.append(c10)

    # Chart 11: Table — Xu hướng Từ khóa Nổi bật (Rising / Falling Keywords)
    c11 = create_or_update_chart(
        chart_name="⚡ Xu hướng Từ khóa Nổi bật & Biến động (TF-IDF Trends)",
        viz_type="table",
        dataset_name="news_keyword_trends",
        params={
            "viz_type":       "table",
            "all_columns":    ["keyword", "frequency", "trend_direction", "trend_delta", "date_str"],
            "order_by_cols":  ["[\"frequency\", false]"],
            "row_limit":      30,
            "page_length":    10,
            "include_search": True,
        }
    )
    if c11: charts.append(c11)

    # ── Tạo Dashboard Layout ──────────────────────────────────────────────────
    print("\n[DASHBOARD] Đang thiết kế cấu trúc Dashboard Grid...")

    position_json = {
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"]},
        "GRID_ID": {
            "type": "GRID",
            "id": "GRID_ID",
            "children": ["ROW-1", "ROW-2", "ROW-3", "ROW-4", "ROW-5", "ROW-6"],
            "parents": ["ROOT_ID"],
        },
        "ROW-1": {
            "type": "ROW",
            "id": "ROW-1",
            "children": ["CHART-1", "CHART-2", "CHART-3"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-2": {
            "type": "ROW",
            "id": "ROW-2",
            "children": ["CHART-4", "CHART-5"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-3": {
            "type": "ROW",
            "id": "ROW-3",
            "children": ["CHART-6", "CHART-7"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-4": {
            "type": "ROW",
            "id": "ROW-4",
            "children": ["CHART-8"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-5": {
            "type": "ROW",
            "id": "ROW-5",
            "children": ["CHART-9", "CHART-10"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-6": {
            "type": "ROW",
            "id": "ROW-6",
            "children": ["CHART-11"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
    }

    chart_layout = [
        ("CHART-1",  c1,  4,  "ROW-1"),  # Big number
        ("CHART-2",  c2,  4,  "ROW-1"),  # VN Relevance Donut
        ("CHART-3",  c3,  4,  "ROW-1"),  # Ensemble Sentiment Donut
        ("CHART-4",  c4,  6,  "ROW-2"),  # 8 Topics Bar
        ("CHART-5",  c5,  6,  "ROW-2"),  # Linear Regression Forecast
        ("CHART-6",  c6,  6,  "ROW-3"),  # Top sources
        ("CHART-7",  c7,  6,  "ROW-3"),  # Word cloud
        ("CHART-8",  c8,  12, "ROW-4"),  # AI Summary Table
        ("CHART-9",  c9,  6,  "ROW-5"),  # Source Credibility Ranking
        ("CHART-10", c10, 6,  "ROW-5"),  # Story Clusters
        ("CHART-11", c11, 12, "ROW-6"),  # Keyword Trends
    ]

    for chart_key, chart_obj, width, parent_row in chart_layout:
        if chart_obj:
            position_json[chart_key] = {
                "type": "CHART",
                "id":   chart_key,
                "children": [],
                "parents": ["ROOT_ID", "GRID_ID", parent_row],
                "meta": {
                    "chartId": chart_obj.id,
                    "width":   width,
                    "height":  50,
                    "sliceName": chart_obj.slice_name,
                },
            }

    dashboard = db.session.query(Dashboard).filter_by(
        dashboard_title=DASHBOARD_TITLE
    ).first()

    json_metadata_dict = {
        "color_scheme": "supersetColors",
        "refresh_frequency": 300,
        "expanded_slices": {},
        "timed_refresh_immune_slices": [],
    }

    if not dashboard:
        dashboard = Dashboard(
            dashboard_title=DASHBOARD_TITLE,
            slices=charts,
            position_json=json.dumps(position_json),
            json_metadata=json.dumps(json_metadata_dict),
            published=True,
        )
        db.session.add(dashboard)
        db.session.commit()
        print(f"[+] Dashboard tạo mới: '{DASHBOARD_TITLE}' (ID: {dashboard.id})")
    else:
        dashboard.slices        = charts
        dashboard.position_json = json.dumps(position_json)
        dashboard.json_metadata = json.dumps(json_metadata_dict)
        dashboard.published     = True
        db.session.commit()
        print(f"[=] Dashboard cập nhật: '{DASHBOARD_TITLE}' (ID: {dashboard.id})")

    print(f"\n{'='*60}")
    print(f"✅ HOÀN TẤT AI DASHBOARD! Truy cập tại:")
    print(f"   http://localhost:8088/superset/dashboard/{dashboard.id}/")
    print(f"{'='*60}")

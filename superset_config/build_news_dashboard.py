"""
build_news_dashboard.py
=======================
Bước 5 - Tạo Charts và Dashboard "Vietnam News Intelligence" trên Superset.
Hỗ trợ PostgreSQL DWH, Word Cloud và Native Filters thời gian thực.

Chạy bên trong Superset Docker container:
  docker exec vietnam_news_superset python /app/pythonpath/build_news_dashboard.py
"""

import json
import sys
import logging
from superset.app import create_app

app = create_app()
logger = logging.getLogger(__name__)

DASHBOARD_TITLE = "🗞️ Vietnam News Intelligence"

with app.app_context():
    from superset import db
    from superset.models.core import Database
    from superset.connectors.sqla.models import SqlaTable
    from superset.models.slice import Slice
    from superset.models.dashboard import Dashboard

    # ── Lấy database connection ───────────────────────────────────────────────
    database = db.session.query(Database).filter_by(
        database_name="Vietnam_News_DB"
    ).first()

    if not database:
        print("❌ Chưa tìm thấy Database 'Vietnam_News_DB'.")
        print("   Chạy setup_news_superset.py trước!")
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
        """Tạo hoặc cập nhật một chart trong Superset."""
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

    # ── Tạo các Charts ────────────────────────────────────────────────────────
    print("\n[CHARTS] Đang tạo 7 charts...")
    charts = []

    # Chart 1: Line Chart — Xu hướng tin tức theo ngày
    ds1 = get_dataset("news_daily_summary")
    qc1 = {
        "datasource": {"id": ds1.id if ds1 else 1, "type": "table"},
        "force": False,
        "queries": [{
            "columns": ["date"],
            "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài/ngày"}],
            "orderby": [["date", True]],
            "row_limit": 1000,
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c1 = create_or_update_chart(
        chart_name="📈 Xu hướng tin tức theo ngày",
        viz_type="echarts_timeseries_line",
        dataset_name="news_daily_summary",
        params={
            "viz_type":          "echarts_timeseries_line",
            "x_axis":            "date",
            "time_range":        "No filter",
            "metrics":           [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài/ngày"}],
            "groupby":           [],
            "seriesType":        "line",
            "show_legend":       False,
            "rich_tooltip":      True,
            "x_axis_title":      "Ngày",
            "y_axis_title":      "Số bài báo",
            "color_scheme":      "supersetColors",
        },
        query_context=qc1,
    )
    if c1:
        charts.append(c1)

    # Chart 2: Bar Chart — Top nguồn báo phổ biến
    ds2 = get_dataset("news_source_ranking")
    qc2 = {
        "datasource": {"id": ds2.id if ds2 else 1, "type": "table"},
        "force": False,
        "queries": [{
            "columns": ["source_name"],
            "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"}],
            "orderby": [[{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"}, False]],
            "row_limit": 10,
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c2 = create_or_update_chart(
        chart_name="🏆 Top nguồn báo phổ biến",
        viz_type="echarts_timeseries_bar",
        dataset_name="news_source_ranking",
        params={
            "viz_type":          "echarts_timeseries_bar",
            "x_axis":            "source_name",
            "time_range":        "No filter",
            "metrics":           [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"}],
            "groupby":           [],
            "row_limit":         10,
            "order_desc":        True,
            "orientation":       "vertical",
            "show_legend":       False,
            "rich_tooltip":      True,
            "x_axis_title":      "Nguồn báo",
            "y_axis_title":      "Số bài báo",
            "color_scheme":      "supersetColors",
        },
        query_context=qc2,
    )
    if c2:
        charts.append(c2)

    # Chart 3: Pie Chart — Phân bố cảm xúc
    ds3 = get_dataset("news_sentiment_breakdown")
    qc3 = {
        "datasource": {"id": ds3.id if ds3 else 1, "type": "table"},
        "force": False,
        "queries": [{
            "columns": ["sentiment_label"],
            "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"}],
            "row_limit": 10,
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c3 = create_or_update_chart(
        chart_name="🥧 Phân bố cảm xúc (Sentiment)",
        viz_type="pie",
        dataset_name="news_sentiment_breakdown",
        params={
            "viz_type":       "pie",
            "metric":         {"expressionType": "SIMPLE", "column": {"column_name": "article_count"}, "aggregate": "SUM", "label": "Số bài"},
            "groupby":        ["sentiment_label"],
            "row_limit":      10,
            "pie_label_type": "key_percent",
            "show_legend":    True,
            "donut":          True,
            "color_scheme":   "supersetColors",
        },
        query_context=qc3,
    )
    if c3:
        charts.append(c3)

    # Chart 4: Bar Chart — Điểm cảm xúc trung bình theo nguồn
    qc4 = {
        "datasource": {"id": ds2.id if ds2 else 1, "type": "table"},
        "force": False,
        "queries": [{
            "columns": ["source_name"],
            "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "avg_sentiment"}, "aggregate": "AVG", "label": "Avg Sentiment"}],
            "orderby": [[{"expressionType": "SIMPLE", "column": {"column_name": "avg_sentiment"}, "aggregate": "AVG", "label": "Avg Sentiment"}, False]],
            "row_limit": 15,
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c4 = create_or_update_chart(
        chart_name="📊 Điểm cảm xúc trung bình theo nguồn",
        viz_type="echarts_timeseries_bar",
        dataset_name="news_source_ranking",
        params={
            "viz_type":          "echarts_timeseries_bar",
            "x_axis":            "source_name",
            "time_range":        "No filter",
            "metrics":           [{"expressionType": "SIMPLE", "column": {"column_name": "avg_sentiment"}, "aggregate": "AVG", "label": "Avg Sentiment"}],
            "groupby":           [],
            "row_limit":         15,
            "order_desc":        True,
            "orientation":       "vertical",
            "show_legend":       False,
            "rich_tooltip":      True,
            "x_axis_title":      "Nguồn báo",
            "y_axis_title":      "Điểm cảm xúc (-1 đến +1)",
            "color_scheme":      "supersetColors",
        },
        query_context=qc4,
    )
    if c4:
        charts.append(c4)

    # Chart 5: Big Number — Tổng số bài báo
    ds5 = get_dataset("news_vietnam_articles")
    qc5 = {
        "datasource": {"id": ds5.id if ds5 else 1, "type": "table"},
        "force": False,
        "queries": [{
            "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT", "label": "Tổng bài"}],
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c5 = create_or_update_chart(
        chart_name="📰 Tổng số bài báo",
        viz_type="big_number_total",
        dataset_name="news_vietnam_articles",
        params={
            "viz_type":    "big_number_total",
            "metric":      {"expressionType": "SIMPLE", "column": {"column_name": "id"}, "aggregate": "COUNT", "label": "Tổng bài"},
            "subheader":   "bài báo về Vietnam",
            "color_scheme": "supersetColors",
        },
        query_context=qc5,
    )
    if c5:
        charts.append(c5)

    # Chart 6: Table — Danh sách tin mới nhất
    ds6 = get_dataset("news_full_view")
    qc6 = {
        "datasource": {"id": ds6.id if ds6 else 1, "type": "table"},
        "force": False,
        "queries": [{
            "columns": ["pub_date", "title", "source_name", "author", "sentiment_label", "sentiment_score", "url"],
            "orderby": [["pub_date", False]],
            "row_limit": 25,
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c6 = create_or_update_chart(
        chart_name="📋 Danh sách tin mới nhất",
        viz_type="table",
        dataset_name="news_full_view",
        params={
            "viz_type":    "table",
            "query_mode":  "raw",
            "all_columns": ["pub_date", "title", "source_name", "author", "sentiment_label", "sentiment_score", "url"],
            "order_by_cols": [["pub_date", False]],
            "row_limit":   25,
            "include_search": True,
            "table_timestamp_format": "smart_date",
            "color_scheme": "supersetColors",
        },
        query_context=qc6,
    )
    if c6:
        charts.append(c6)

    # Chart 7: Word Cloud — Từ khóa nổi bật
    ds_wc = get_dataset("news_keyword_cloud")
    qc7 = {
        "datasource": {"id": ds_wc.id if ds_wc else 1, "type": "table"},
        "force": False,
        "queries": [{
            "columns": ["word"],
            "metrics": [{"expressionType": "SIMPLE", "column": {"column_name": "count"}, "aggregate": "SUM", "label": "Số lần"}],
            "row_limit": 40,
            "time_range": "No filter",
        }],
        "result_format": "json",
        "result_type": "full",
    }
    c7 = create_or_update_chart(
        chart_name="☁️ Từ khóa nổi bật (Word Cloud)",
        viz_type="word_cloud",
        dataset_name="news_keyword_cloud",
        params={
            "viz_type":     "word_cloud",
            "series":       "word",
            "metric":       {"expressionType": "SIMPLE", "column": {"column_name": "count"}, "aggregate": "SUM", "label": "Số lần"},
            "row_limit":    40,
            "size_from":    "12",
            "size_to":      "55",
            "rotation":     "square",
            "color_scheme": "supersetColors",
        },
        query_context=qc7,
    )
    if c7:
        charts.append(c7)

    print(f"\n[CHARTS] ✅ Đã xử lý {len(charts)}/7 charts.\n")

    # ── Cấu hình Native Filters Thời Gian Thực ────────────────────────────────
    phys_ds = get_dataset("news_vietnam_articles")
    phys_id = phys_ds.id if phys_ds else 1

    native_filters = [
        {
            "id": "NATIVE_FILTER_SENTIMENT",
            "name": "Nhãn cảm xúc",
            "filterType": "filter_select",
            "targets": [
                {
                    "datasetId": phys_id,
                    "column": {"name": "sentiment_label"},
                }
            ],
            "defaultDataMask": {
                "filterState": {"value": None}
            },
            "controlValues": {
                "enableEmptyFilter": False,
                "inverseSelection": False,
                "multiSelect": True,
                "searchAllOptions": True,
            },
            "cascadeParentIds": [],
            "scope": {
                "rootPath": ["ROOT_ID"],
                "excluded": []
            },
            "type": "NATIVE_FILTER",
            "description": "Lọc toàn bộ dashboard theo nhãn cảm xúc bài báo",
        },
        {
            "id": "NATIVE_FILTER_SOURCE",
            "name": "Nguồn báo chí",
            "filterType": "filter_select",
            "targets": [
                {
                    "datasetId": phys_id,
                    "column": {"name": "source_name"},
                }
            ],
            "defaultDataMask": {
                "filterState": {"value": None}
            },
            "controlValues": {
                "enableEmptyFilter": False,
                "inverseSelection": False,
                "multiSelect": True,
                "searchAllOptions": True,
            },
            "cascadeParentIds": [],
            "scope": {
                "rootPath": ["ROOT_ID"],
                "excluded": []
            },
            "type": "NATIVE_FILTER",
            "description": "Lọc dashboard theo nguồn báo chí",
        },
    ]

    json_metadata_dict = {
        "native_filter_configuration": native_filters,
        "color_scheme_domain": [],
        "shared_label_colors": [],
        "map_label_colors": {},
        "label_colors": {},
    }

    # ── Tạo Dashboard với Layout 4-Tầng Chuẩn ─────────────────────────────────
    print(f"[DASHBOARD] Đang tạo dashboard '{DASHBOARD_TITLE}'...")

    dashboard = db.session.query(Dashboard).filter_by(
        dashboard_title=DASHBOARD_TITLE
    ).first()

    position_json = {
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"]},
        "GRID_ID": {
            "type": "GRID",
            "id": "GRID_ID",
            "children": ["ROW-1", "ROW-2", "ROW-3", "ROW-4"],
            "parents": ["ROOT_ID"],
        },
        "ROW-1": {
            "type": "ROW",
            "id": "ROW-1",
            "children": ["CHART-5", "CHART-3", "CHART-4"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-2": {
            "type": "ROW",
            "id": "ROW-2",
            "children": ["CHART-1", "CHART-7"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-3": {
            "type": "ROW",
            "id": "ROW-3",
            "children": ["CHART-2"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
        "ROW-4": {
            "type": "ROW",
            "id": "ROW-4",
            "children": ["CHART-6"],
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        },
    }

    chart_layout = [
        ("CHART-5", c5, 4, "ROW-1"),  # Big number: 4 cols
        ("CHART-3", c3, 4, "ROW-1"),  # Sentiment Donut: 4 cols
        ("CHART-4", c4, 4, "ROW-1"),  # Sentiment Bar: 4 cols
        ("CHART-1", c1, 6, "ROW-2"),  # News Trend Line: 6 cols
        ("CHART-7", c7, 6, "ROW-2"),  # Word Cloud: 6 cols
        ("CHART-2", c2, 12, "ROW-3"), # Top Sources Bar: 12 cols
        ("CHART-6", c6, 12, "ROW-4"), # Recent News Table: 12 cols
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
        dashboard.slices         = charts
        dashboard.position_json  = json.dumps(position_json)
        dashboard.json_metadata  = json.dumps(json_metadata_dict)
        dashboard.published      = True
        db.session.commit()
        print(f"[=] Dashboard cập nhật: '{DASHBOARD_TITLE}' (ID: {dashboard.id})")

    print(f"\n{'='*60}")
    print(f"✅ HOÀN TẤT! Dashboard sẵn sàng tại:")
    print(f"   http://localhost:8088/superset/dashboard/{dashboard.id}/")
    print(f"{'='*60}")

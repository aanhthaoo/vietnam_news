"""
run_pipeline.py
===============
Entry point chạy toàn bộ ETL Pipeline:
  Extract (NewsAPI) → Transform (NLP) → Load (SQLite)

Cách dùng:
  python news_pipeline/run_pipeline.py
  python news_pipeline/run_pipeline.py --from 2024-01-01 --to 2024-01-31
  python news_pipeline/run_pipeline.py --keyword "Vietnam economy"
"""

import sys
import logging
import argparse
from datetime import datetime, timedelta

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Đảm bảo import đúng module trong package
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from news_pipeline.collect_news   import collect
from news_pipeline.transform_news import transform_articles
from news_pipeline.store_news     import create_table, save_articles, get_stats, is_postgres

# ── Logging setup ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

SEPARATOR = "=" * 60


def run_pipeline(
    keyword:   str       = "Vietnam",
    from_date: str | None = None,
    to_date:   str | None = None,
    max_pages: int        = 1,
) -> dict:
    """
    Chạy toàn bộ ETL pipeline một lần.

    Returns:
        dict với kết quả thống kê: collected, inserted, skipped
    """
    start_time = datetime.now()

    print(f"\n{SEPARATOR}")
    print(f"🚀 NewsAPI → Vietnam News Pipeline")
    print(f"   Keyword:  {keyword}")
    print(f"   From:     {from_date or 'hôm qua'}")
    print(f"   To:       {to_date   or 'hôm nay'}")
    print(f"   Started:  {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(SEPARATOR)

    # ── BƯỚC 1: Khởi tạo Schema (idempotent) ─────────────────────────────────
    print("\n[STEP 1/4] 🗄️  Khởi tạo Database Schema...")
    create_table()

    # ── BƯỚC 2: Extract từ NewsAPI ────────────────────────────────────────────
    print(f"\n[STEP 2/4] 📡 Thu thập tin tức từ NewsAPI...")
    try:
        raw_articles = collect(
            keyword=keyword,
            from_date=from_date,
            to_date=to_date,
            max_pages=max_pages,
        )
    except Exception as e:
        logger.error(f"[PIPELINE] Lỗi Extract: {e}")
        print(f"\n❌ LỖI khi thu thập: {e}")
        return {"error": str(e), "collected": 0, "inserted": 0, "skipped": 0}

    if not raw_articles:
        print("⚠️  Không có bài nào được thu thập. Kết thúc.")
        return {"collected": 0, "inserted": 0, "skipped": 0}

    # ── BƯỚC 3: Transform (NLP) ───────────────────────────────────────────────
    print(f"\n[STEP 3/4] 🧠 Phân tích NLP ({len(raw_articles)} bài)...")
    enriched = transform_articles(raw_articles, verbose=True)

    # ── BƯỚC 4: Load vào Database ─────────────────────────────────────────────
    db_name = "PostgreSQL" if is_postgres() else "SQLite"
    print(f"\n[STEP 4/5] 💾 Lưu vào {db_name} Database...")
    save_result = save_articles(enriched)

    # ── BƯỚC 5: Dự báo số lượng tin tức (LinearRegression) ───────────────────────
    print(f"\n[STEP 5/5] 📈 Chạy mô hình Dự báo LinearRegression (7 ngày tới)...")
    try:
        from ai_models.volume_forecaster import train_and_forecast_volume
        forecast_res = train_and_forecast_volume(horizon_days=7)
        print(f"   - Mô hình: LinearRegression (MAE={forecast_res.get('mae')}, R2={forecast_res.get('r2_score')})")
        print(f"   - Đã lưu {len(forecast_res.get('forecasts', []))} bản ghi dự báo vào bảng news_volume_forecast.")
    except Exception as e:
        logger.warning(f"[PIPELINE] Lỗi dự báo: {e}")

    # ── Tổng kết ─────────────────────────────────────────────────────────────
    elapsed = (datetime.now() - start_time).total_seconds()
    db_stats = get_stats()

    print(f"\n{SEPARATOR}")
    print(f"✅ PIPELINE HOÀN TẤT ({elapsed:.1f}s)")
    print(f"   Bài thu thập:   {save_result['total']}")
    print(f"   Bài mới lưu:    {save_result['inserted']}")
    print(f"   Bài đã tồn tại: {save_result['skipped']}")
    print(f"\n📊 Thống kê DB hiện tại:")
    print(f"   Tổng bài:       {db_stats['total_articles']}")
    print(f"   Tổng nguồn:     {db_stats['total_sources']}")
    print(f"   Tin chuẩn VN:   {db_stats.get('vietnam_relevant_count', 0)}")
    print(f"   Bài mới nhất:   {db_stats['latest_article']}")
    print(f"   Sentiment:      {db_stats['sentiment_breakdown']}")
    print(f"   Chủ đề Topics:  {db_stats.get('topic_breakdown', {})}")
    print(SEPARATOR)

    return {
        "collected": save_result["total"],
        "inserted":  save_result["inserted"],
        "skipped":   save_result["skipped"],
        "elapsed_s": round(elapsed, 1),
        "db_total":  db_stats["total_articles"],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Vietnam News ETL Pipeline — NewsAPI → SQLite"
    )
    parser.add_argument(
        "--keyword", "-k",
        default="Vietnam",
        help="Từ khóa tìm kiếm (mặc định: Vietnam)"
    )
    parser.add_argument(
        "--from", dest="from_date",
        default=None,
        help="Ngày bắt đầu ISO: YYYY-MM-DD (mặc định: hôm qua)"
    )
    parser.add_argument(
        "--to", dest="to_date",
        default=None,
        help="Ngày kết thúc ISO: YYYY-MM-DD (mặc định: hôm nay)"
    )
    parser.add_argument(
        "--pages", "-p",
        type=int,
        default=1,
        help="Số trang tối đa (free tier: chỉ page=1, default: 1)"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    result = run_pipeline(
        keyword=args.keyword,
        from_date=args.from_date,
        to_date=args.to_date,
        max_pages=args.pages,
    )
    sys.exit(0 if "error" not in result else 1)

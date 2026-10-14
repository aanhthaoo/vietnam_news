"""
scheduler.py
============
Bước 10 - Chạy ETL Pipeline tự động hằng ngày.
Sử dụng thư viện 'schedule' để lên lịch thu thập tin vào mỗi buổi sáng.

Cách dùng:
  python news_pipeline/scheduler.py
  # Giữ tiến trình chạy để scheduler hoạt động
"""

import sys
import time
import logging
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import schedule
from news_pipeline.run_pipeline import run_pipeline

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ── Cấu hình lịch ─────────────────────────────────────────────────────────────
DAILY_RUN_TIME = "08:00"    # Chạy mỗi ngày lúc 08:00 sáng
KEYWORD        = "Vietnam"


def scheduled_job():
    """Job được gọi tự động theo lịch."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logger.info(f"[SCHEDULER] ⏰ Bắt đầu chạy định kỳ lúc {now}")
    print(f"\n{'='*50}")
    print(f"⏰ SCHEDULED RUN: {now}")
    print(f"{'='*50}")

    try:
        result = run_pipeline(keyword=KEYWORD)
        logger.info(f"[SCHEDULER] ✅ Hoàn tất: {result}")
    except Exception as e:
        logger.error(f"[SCHEDULER] ❌ Lỗi khi chạy pipeline: {e}")


def run_scheduler():
    """
    Khởi động scheduler — giữ chạy liên tục.
    Pipeline sẽ tự động chạy mỗi ngày lúc DAILY_RUN_TIME.
    """
    print(f"\n🕐 Vietnam News Scheduler đang chạy...")
    print(f"   Lịch chạy: mỗi ngày lúc {DAILY_RUN_TIME}")
    print(f"   Từ khóa:   {KEYWORD}")
    print(f"   Nhấn Ctrl+C để dừng.\n")

    # Đăng ký lịch chạy hằng ngày
    schedule.every().day.at(DAILY_RUN_TIME).do(scheduled_job)

    # Chạy ngay lần đầu khi khởi động
    print("[SCHEDULER] Chạy lần đầu ngay bây giờ...")
    scheduled_job()

    # Vòng lặp giữ scheduler hoạt động
    while True:
        schedule.run_pending()
        next_run = schedule.next_run()
        if next_run:
            delta = (next_run - datetime.now()).total_seconds()
            logger.debug(f"[SCHEDULER] Next run in {delta:.0f}s")
        time.sleep(60)   # Kiểm tra mỗi phút


if __name__ == "__main__":
    try:
        run_scheduler()
    except KeyboardInterrupt:
        print("\n\n[SCHEDULER] 🛑 Dừng scheduler theo yêu cầu.")
        sys.exit(0)

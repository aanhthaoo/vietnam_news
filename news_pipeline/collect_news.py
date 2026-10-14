"""
collect_news.py
===============
Bước 1 - Extract: Thu thập tin tức về Vietnam từ NewsAPI.
Docs: https://newsapi.org/docs/endpoints/everything
"""

import os
import sys
import logging
import requests
from datetime import datetime, timedelta
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

load_dotenv()

logger = logging.getLogger(__name__)

# ── Cấu hình từ biến môi trường ──────────────────────────────────────────────
API_KEY   = os.getenv("NEWS_API_KEY", "")
KEYWORD   = os.getenv("NEWS_KEYWORD", "Vietnam")
LANGUAGE  = os.getenv("NEWS_LANGUAGE", "en")
PAGE_SIZE = int(os.getenv("NEWS_PAGE_SIZE", "100"))

BASE_URL  = "https://newsapi.org/v2/everything"
# ─────────────────────────────────────────────────────────────────────────────


def fetch_articles(
    keyword:   str      = KEYWORD,
    language:  str      = LANGUAGE,
    page_size: int      = PAGE_SIZE,
    from_date: str | None = None,
    to_date:   str | None = None,
    page:      int      = 1,
) -> list[dict]:
    """
    Gọi NewsAPI /v2/everything và trả về list raw articles.

    Args:
        keyword:   Từ khóa tìm kiếm (mặc định "Vietnam")
        language:  Ngôn ngữ bài báo (mặc định "en")
        page_size: Số bài/trang, tối đa 100 (free tier)
        from_date: ISO date string "YYYY-MM-DD" (default: hôm qua)
        to_date:   ISO date string "YYYY-MM-DD" (default: hôm nay)
        page:      Số trang (default: 1)

    Returns:
        List[dict] — mỗi phần tử là raw article từ API
    """
    if not API_KEY:
        raise EnvironmentError(
            "Thiếu NEWS_API_KEY! Kiểm tra file .env hoặc biến môi trường."
        )

    # Mặc định: lấy tin trong 24h qua
    today     = datetime.utcnow().date()
    yesterday = today - timedelta(days=1)
    from_date = from_date or str(yesterday)
    to_date   = to_date   or str(today)

    params = {
        "q":        keyword,
        "language": language,
        "pageSize": page_size,
        "page":     page,
        "from":     from_date,
        "to":       to_date,
        "sortBy":   "publishedAt",
        "apiKey":   API_KEY,
    }

    logger.info(f"[API] Fetching '{keyword}' | {from_date} → {to_date} | page {page}")
    print(f"[API] 🔍 Tìm kiếm: '{keyword}' | Từ {from_date} đến {to_date} | Trang {page}")

    try:
        resp = requests.get(BASE_URL, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
    except requests.exceptions.Timeout:
        logger.error("[API] Timeout khi gọi NewsAPI.")
        raise
    except requests.exceptions.HTTPError as e:
        logger.error(f"[API] HTTP Error: {e} | Response: {resp.text[:300]}")
        raise

    status = data.get("status", "")
    if status != "ok":
        error_msg = data.get("message", "Lỗi không xác định")
        logger.error(f"[API] NewsAPI trả về lỗi: {error_msg}")
        raise ValueError(f"NewsAPI Error: {error_msg}")

    raw_articles = data.get("articles", [])
    total_results = data.get("totalResults", 0)

    logger.info(f"[API] Nhận được {len(raw_articles)} bài / Tổng: {total_results}")
    print(f"[API] ✅ Nhận được {len(raw_articles)} bài | Tổng kết quả API: {total_results}")

    return raw_articles


def normalize_article(raw: dict) -> dict:
    """
    Chuẩn hóa cấu trúc raw article từ API sang dict nội bộ.
    Chưa bao gồm NLP — sẽ được thêm ở transform_news.py.

    Args:
        raw: Dict trả về từ NewsAPI articles[]

    Returns:
        Dict chuẩn hóa với các keys nhất quán
    """
    source = raw.get("source") or {}

    return {
        "title":        (raw.get("title")       or "").strip(),
        "description":  (raw.get("description") or "").strip(),
        "content":      (raw.get("content")     or "").strip(),
        "url":          (raw.get("url")          or "").strip(),
        "source_name":  (source.get("name")     or "Unknown").strip(),
        "author":       (raw.get("author")       or "").strip(),
        "published_at": _parse_date(raw.get("publishedAt", "")),
        # NLP fields — sẽ được điền ở bước Transform
        "sentiment_label": None,
        "sentiment_score": None,
        "entities_org":    [],
        "entities_gpe":    [],
        "entities_person": [],
    }


def _parse_date(iso_str: str) -> str:
    """Chuyển ISO 8601 string sang SQLite-compatible datetime string."""
    if not iso_str:
        return ""
    try:
        # NewsAPI trả về format: "2024-01-15T10:30:00Z"
        dt = datetime.strptime(iso_str, "%Y-%m-%dT%H:%M:%SZ")
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except ValueError:
        return iso_str[:19].replace("T", " ")


def collect(
    keyword:    str       = KEYWORD,
    from_date:  str | None = None,
    to_date:    str | None = None,
    max_pages:  int       = 1,
) -> list[dict]:
    """
    Thu thập và chuẩn hóa tin tức từ NewsAPI (hỗ trợ multi-page).

    Args:
        keyword:   Từ khóa (mặc định "Vietnam")
        from_date: Ngày bắt đầu (ISO date)
        to_date:   Ngày kết thúc (ISO date)
        max_pages: Số trang tối đa cần lấy (free tier giới hạn page=1)

    Returns:
        List[dict] các bài báo đã chuẩn hóa
    """
    all_articles = []

    for page in range(1, max_pages + 1):
        try:
            raw_list = fetch_articles(
                keyword=keyword,
                from_date=from_date,
                to_date=to_date,
                page=page,
            )
        except Exception as e:
            logger.error(f"[API] Lỗi ở trang {page}: {e}")
            break

        if not raw_list:
            print(f"[API] Không còn bài ở trang {page}. Dừng.")
            break

        normalized = [normalize_article(r) for r in raw_list]
        # Lọc bỏ bài không có URL hoặc title
        normalized = [a for a in normalized if a["url"] and a["title"]]
        all_articles.extend(normalized)

        if len(raw_list) < PAGE_SIZE:
            break   # Hết dữ liệu, không cần lấy thêm

    print(f"[API] 📦 Tổng cộng thu thập: {len(all_articles)} bài (đã chuẩn hóa)")
    return all_articles


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    articles = collect()
    if articles:
        print(f"\n[SAMPLE] Bài đầu tiên:")
        print(f"  Title:   {articles[0]['title'][:80]}")
        print(f"  Source:  {articles[0]['source_name']}")
        print(f"  Date:    {articles[0]['published_at']}")
        print(f"  URL:     {articles[0]['url'][:60]}...")

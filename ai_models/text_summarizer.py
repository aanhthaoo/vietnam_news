"""
ai_models/text_summarizer.py
============================
Phụ trách: Thành viên 1 (Lead Developer)
Mục tiêu: Tóm tắt bài báo tự động bằng Google Gemini API (Gemini 1.5 Flash).
Có cơ chế Fallback tóm tắt trích xuất (Extractive fallback) khi chưa cấu hình Key hoặc lỗi mạng.
"""

import os
import sys
import re
import logging
from typing import Optional
from dotenv import load_dotenv

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


load_dotenv()
logger = logging.getLogger(__name__)

_gemini_configured = False
_model = None


def _init_gemini():
    """Khởi tạo Google Generative AI client."""
    global _gemini_configured, _model
    if _gemini_configured:
        return _model is not None

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        logger.info("[Gemini] Chưa cấu hình GEMINI_API_KEY trong .env. Sử dụng Extractive Fallback.")
        _gemini_configured = True
        _model = None
        return False

    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        # Sử dụng model nhanh, nhẹ gemini-1.5-flash
        _model = genai.GenerativeModel("gemini-1.5-flash")
        _gemini_configured = True
        logger.info("[Gemini] Đã kết nối thành công với Google Gemini API (gemini-1.5-flash).")
        return True
    except Exception as e:
        logger.warning(f"[Gemini] Không thể khởi tạo Gemini client: {e}")
        _gemini_configured = True
        _model = None
        return False


def fallback_summary(text: str, max_chars: int = 250) -> str:
    """
    Tóm tắt trích xuất dự phòng khi không có kết nối Gemini API.
    Lấy 1-2 câu đầu tiên có nghĩa.
    """
    if not text:
        return ""
    clean = re.sub(r"\s+", " ", text).strip()
    sentences = re.split(r"(?<=[.!?]) +", clean)
    summary_parts = []
    total_len = 0
    for s in sentences:
        if total_len + len(s) <= max_chars or not summary_parts:
            summary_parts.append(s)
            total_len += len(s)
        else:
            break
    res = " ".join(summary_parts)
    return res if res else clean[:max_chars]


def summarize_article(title: str, content: str, max_words: int = 60) -> str:
    """
    Tóm tắt bài báo bằng Gemini API hoặc Extractive Fallback.
    Returns chuỗi tóm tắt súc tích (1-2 câu).
    """
    raw_text = f"{title or ''}. {content or ''}".strip()
    if not raw_text or len(raw_text) < 30:
        return title or ""

    if _init_gemini() and _model:
        prompt = (
            f"Hãy tóm tắt ngắn gọn bài báo sau đây thành 1 đến 2 câu súc tích (dưới {max_words} từ), "
            f"nêu bật sự kiện chính. Ngôn ngữ tiếng Việt:\n\n{raw_text[:2000]}"
        )
        try:
            response = _model.generate_content(
                prompt,
                generation_config={"max_output_tokens": 120, "temperature": 0.2}
            )
            if response and response.text:
                return response.text.strip().replace("\n", " ")
        except Exception as e:
            logger.warning(f"[Gemini API Error] {e} -> Chuyển sang fallback.")

    return fallback_summary(raw_text)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    test_title = "Vietnam's economy grows 7.4% in Q3 driven by manufacturing and exports"
    test_body = (
        "Hanoi - Vietnam reported robust gross domestic product expansion in the third quarter of 2024. "
        "The manufacturing sector led gains despite headwinds from global supply chain disruptions. "
        "Foreign direct investment disbursements reached record highs according to the General Statistics Office."
    )
    print("--- TEST GEMINI / FALLBACK SUMMARIZER ---")
    summary = summarize_article(test_title, test_body)
    print("Tóm tắt:", summary)

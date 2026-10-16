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


VN_KEYWORDS = [
    r"\bvietnam\b", r"\bviet nam\b", r"\bvietnamese\b", r"\bhanoi\b",
    r"\bha noi\b", r"\bho chi minh\b", r"\bhcmc\b", r"\bsaigon\b",
    r"\bda nang\b", r"\bhai phong\b", r"\bcan tho\b", r"\bvinfast\b",
    r"\bvingroup\b", r"\bmekong\b", r"\bvnd\b"
]


def extract_vietnam_context(text: str) -> Optional[str]:
    """Tìm câu văn cụ thể trong bài có chứa từ khóa liên quan đến Việt Nam."""
    if not text:
        return None
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    pattern = re.compile("|".join(VN_KEYWORDS), re.IGNORECASE)
    for s in sentences:
        s_clean = s.strip()
        if pattern.search(s_clean) and len(s_clean) > 20:
            return s_clean
    return None


def fallback_summary(text: str, max_chars: int = 250) -> str:
    """
    Tóm tắt trích xuất cơ bản: lấy 1-2 câu đầu tiên có nghĩa.
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


def extract_contextual_summary(title: str, content: str, max_chars: int = 300) -> str:
    """
    Tóm tắt làm nổi bật bối cảnh Việt Nam kể cả khi bài viết nói về chủ đề quốc tế khác.
    """
    title_clean = (title or "").strip()
    full_text = f"{title_clean}. {content or ''}".strip()
    vn_in_title = bool(re.search(r"\b(vietnam|viet nam|vietnamese|hanoi|saigon|vinfast)\b", title_clean, re.I))

    # Tìm câu chứa ngữ cảnh Việt Nam trong nội dung bài
    vn_context = extract_vietnam_context(content)

    # Nếu ngay tiêu đề đã là về Việt Nam
    if vn_in_title:
        return fallback_summary(full_text, max_chars=max_chars)

    # Nếu tiêu đề không nói về VN nhưng nội dung có nhắc tới VN
    if vn_context and vn_context.lower() != title_clean.lower():
        lead = title_clean if len(title_clean) <= 130 else title_clean[:127] + "..."
        ctx = vn_context if len(vn_context) <= 160 else vn_context[:157] + "..."
        return f"[Chủ đề]: {lead} | 🇻🇳 [Ngữ cảnh VN]: {ctx}"

    return fallback_summary(full_text, max_chars=max_chars)


def summarize_article(title: str, content: str, max_words: int = 60) -> str:
    """
    Tóm tắt bài báo bằng Gemini API hoặc Contextual Fallback.
    BẮT BUỘC làm rõ lý do/ngữ cảnh xuất hiện của Việt Nam trong bài.
    """
    raw_text = f"{title or ''}. {content or ''}".strip()
    if not raw_text or len(raw_text) < 30:
        return title or ""

    if _init_gemini() and _model:
        prompt = (
            f"Bạn là chuyên gia phân tích dữ liệu tin tức BI. Hãy tóm tắt bài báo sau thành 1 đến 2 câu súc tích (dưới {max_words} từ).\n"
            f"YÊU CẦU ĐẶC BIỆT:\n"
            f"- Nếu bài viết là về Việt Nam: Nêu bật sự kiện chính tại Việt Nam.\n"
            f"- Nếu bài viết về chủ đề quốc tế nhưng có nhắc đến Việt Nam: BẮT BUỘC phải nêu chủ đề chính VÀ giải thích rõ Việt Nam được nhắc đến trong vai trò/ngữ cảnh gì (ví dụ: chuỗi cung ứng, đầu tư, ngoại giao, so sánh kinh tế...).\n\n"
            f"Tiêu đề: {title}\n"
            f"Nội dung: {content[:2500]}"
        )
        try:
            response = _model.generate_content(
                prompt,
                generation_config={"max_output_tokens": 140, "temperature": 0.2}
            )
            if response and response.text:
                return response.text.strip().replace("\n", " ")
        except Exception as e:
            logger.warning(f"[Gemini API Error] {e} -> Chuyển sang contextual fallback.")

    return extract_contextual_summary(title, content)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print("--- TEST CONTEXTUAL SUMMARIZER ---")
    
    # Test 1: Bài tin chuẩn về Việt Nam
    t1 = "Vietnam's economy grows 7.4% in Q3 driven by manufacturing and exports"
    b1 = "Hanoi - Vietnam reported robust gross domestic product expansion in the third quarter of 2024. The manufacturing sector led gains."
    print("\n[Bài 1 - Chuẩn Việt Nam]:")
    print(summarize_article(t1, b1))

    # Test 2: Bài tin quốc tế chỉ nhắc lướt Việt Nam
    t2 = "Apple Q3 earnings show strong global growth in wearable tech"
    b2 = "Tim Cook reported expanding margins across hardware divisions. The company highlighted continued resilience in its partner network across China, India, and Vietnam, where factory output rose modestly compared to the previous quarter."
    print("\n[Bài 2 - Quốc tế nhắc lướt]:")
    print(summarize_article(t2, b2))

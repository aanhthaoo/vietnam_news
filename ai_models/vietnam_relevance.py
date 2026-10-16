"""
ai_models/vietnam_relevance.py
==============================
Phụ trách: Thành viên 2 (Junior Developer)
Trạng thái: Hoàn thiện (Đã triển khai bộ từ khóa toàn diện & thuật toán phân loại)

MỤC TIÊU & GIẢI THUẬT:
1. Bộ từ khóa định danh Việt Nam (VIETNAM_KEYWORD_TAXONOMY & VIETNAM_KEYWORDS):
   - Phân loại đa tầng theo 6 lĩnh vực chính:
     + national_identity: Định danh quốc gia, dân tộc, quan hệ ngoại giao đa phương
     + geography_provinces: 63 tỉnh/thành phố và đô thị lớn (tiếng Anh & tiếng Việt có/không dấu)
     + landmarks_regions: Danh lam thắng cảnh, vùng kinh tế, hải đảo, di sản
     + politics_government: Cơ quan trung ương, lãnh đạo Nhà nước, tổ chức ngoại giao
     + business_finance: Tập đoàn lớn, ngân hàng, thị trường chứng khoán (VN-Index, HOSE, HNX)
     + culture_economy: Tiền tệ (VND, Đồng), lễ hội truyền thống, văn hóa ẩm thực
2. Bộ lọc nhiễu & giảm trừ ngữ cảnh lịch sử (WAR_RETROSPECTIVE_KEYWORDS):
   - Phát hiện bài báo chỉ nhắc đến "Vietnam War", cựu chiến binh Mỹ (veterans) mà hoàn toàn
     không phản ánh thực tế về đất nước, kinh tế, xã hội Việt Nam đương đại.
3. Giải thuật chấm điểm đa tiêu chí (calculate_vietnam_relevance):
   - Trọng số theo vị trí: Tiêu đề (4.0x) > Tóm tắt/Mô tả (2.0x) > Nội dung (1.0x)
   - Tần suất bão hòa logarit: Tránh bùng nổ điểm do lặp từ cục bộ
   - Điểm thưởng đa dạng ngữ nghĩa (Diversity Bonus): Nhiều từ khóa độc lập & đa danh mục
   - Phân ngưỡng quyết định (Threshold = 20): Trả về is_vietnam_relevant (1 hoặc 0)
"""

import sys
import re
import math
from typing import Dict, Any, List, Set

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


# ==============================================================================
# 1. BỘ TỪ KHÓA ĐỊNH DANH THEO DANH MỤC (VIETNAM_KEYWORD_TAXONOMY)
# ==============================================================================
VIETNAM_KEYWORD_TAXONOMY: Dict[str, Dict[str, Any]] = {
    "national_identity": {
        "weight": 12,
        "description": "Định danh quốc gia, quốc tịch, quan hệ ngoại giao",
        "keywords": [
            "vietnam", "viet nam", "vietnamese", "sino-vietnamese", "us-vietnam", "vietnam-us",
            "vietnam-china", "vietnam-eu", "vietnam-japan", "vietnam-korea", "vietnam-asean",
            "vietnam-australia", "vietnam-india", "vietnam-russia", "vietnam-uk",
            "việt nam", "người việt", "tiếng việt", "nước việt", "dân tộc việt",
            "sr vietnam", "socialist republic of vietnam", "chxhcn việt nam"
        ]
    },
    "geography_provinces": {
        "weight": 8,
        "description": "63 tỉnh/thành phố và đô thị trực thuộc",
        "keywords": [
            "hanoi", "ha noi", "hà nội",
            "ho chi minh city", "ho chi minh", "hcmc", "tp hcm", "tphcm", "saigon", "sai gon", "sài gòn",
            "da nang", "danang", "đà nẵng",
            "hai phong", "haiphong", "hải phòng",
            "can tho", "cantho", "cần thơ",
            "quang ninh", "quảng ninh", "hai duong", "hải dương", "bac ninh", "bắc ninh",
            "bac giang", "bắc giang", "vinh phuc", "vĩnh phúc", "dong nai", "đồng nai",
            "bien hoa", "biên hòa", "binh duong", "bình dương", "thu dau mot", "thủ dầu một",
            "ba ria vung tau", "bà rịa vũng tàu", "bà rịa - vũng tàu", "vung tau", "vũng tàu",
            "long an", "tan an", "tân an", "tien giang", "tiền giang", "my tho", "mỹ tho",
            "an giang", "chau doc", "châu đốc", "long xuyen", "long xuyên",
            "kien giang", "kiên giang", "rach gia", "rạch giá", "ha tien", "hà tiên",
            "khanh hoa", "khánh hòa", "nha trang", "cam ranh",
            "lam dong", "lâm đồng", "da lat", "dalat", "đà lạt", "bao loc", "bảo lộc",
            "dak lak", "đắk lắk", "buon ma thuot", "buôn ma thuột",
            "gia lai", "pleiku", "thua thien hue", "thừa thiên huế", "hue city", "tp huế", "thành phố huế",
            "quang nam", "quảng nam", "hoi an", "hội an", "tam ky", "tam kỳ",
            "quang ngai", "quảng ngãi", "binh dinh", "bình định", "quy nhon", "quy nhơn",
            "phu yen", "phú yên", "tuy hoa", "tuy hòa", "thanh hoa", "thanh hóa",
            "nghe an", "nghệ an", "vinh city", "thành phố vinh", "ha tinh", "hà tĩnh",
            "quang binh", "quảng bình", "dong hoi", "đồng hới",
            "lao cai", "lào cai", "sapa", "sa pa", "yen bai", "yên bái",
            "thai nguyen", "thái nguyên", "lang son", "lạng sơn", "son la", "sơn la",
            "dien bien", "điện biên", "dien bien phu", "điện biên phủ",
            "nam dinh", "nam định", "ninh binh", "ninh bình", "thai binh", "thái bình",
            "hung yen", "hưng yên", "ha nam", "hà nam", "phu ly", "phủ lý",
            "phu tho", "phú thọ", "viet tri", "việt trì", "tuyen quang", "tuyên quang",
            "cao bang", "cao bằng", "bac kan", "bắc kạn", "ha giang", "hà giang",
            "hoa binh", "hòa bình", "lai chau", "lai châu", "kon tum",
            "dak nong", "đắk nông", "gia nghia", "gia nghĩa",
            "tay ninh", "tây ninh", "binh phuoc", "bình phước", "dong xoai", "đồng xoài",
            "binh thuan", "bình thuận", "phan thiet", "phan thiết",
            "ninh thuan", "ninh thuận", "phan rang", "ben tre", "bến tre",
            "dong thap", "đồng tháp", "cao lanh", "cao lãnh", "sa dec", "sa đéc",
            "vinh long", "vĩnh long", "tra vinh", "trà vinh",
            "hau giang", "hậu giang", "vi thanh", "vị thanh",
            "soc trang", "sóc trăng", "bac lieu", "bạc liêu", "ca mau", "cà mau"
        ]
    },
    "landmarks_regions": {
        "weight": 7,
        "description": "Danh thắng, di sản, hải đảo và phân vùng địa lý",
        "keywords": [
            "ha long bay", "halong bay", "vinh ha long", "vịnh hạ long",
            "phu quoc", "phú quốc", "cat ba", "cát bà", "con dao", "côn đảo",
            "son doong", "sơn đoòng", "phong nha", "phong nha ke bang", "phong nha - kẻ bàng",
            "cu chi tunnels", "địa đạo củ chi", "ba na hills", "fansipan", "phan xi păng",
            "trang an", "tràng an", "tam coc", "tam cốc", "bich dong", "bích động",
            "mekong delta", "đồng bằng sông cửu long", "dbscl", "red river delta", "đồng bằng sông hồng",
            "truong sa", "trường sa", "hoang sa", "hoàng sa", "paracel islands", "spratly islands",
            "phu my hung", "thu thiem", "thủ thiêm"
        ]
    },
    "politics_government": {
        "weight": 8,
        "description": "Cơ quan Nhà nước, cơ quan ngoại giao và lãnh đạo",
        "keywords": [
            "communist party of vietnam", "cpv", "đảng cộng sản việt nam",
            "national assembly of vietnam", "quốc hội việt nam", "quoc hoi",
            "politburo of vietnam", "bộ chính trị", "ban chấp hành trung ương",
            "government of vietnam", "chính phủ việt nam", "thủ tướng chính phủ",
            "state bank of vietnam", "sbv", "ngân hàng nhà nước",
            "ministry of finance", "bộ tài chính",
            "ministry of industry and trade", "moit", "bộ công thương",
            "ministry of foreign affairs", "mofa", "bộ ngoại giao",
            "ministry of planning and investment", "mpi", "bộ kế hoạch và đầu tư",
            "general statistics office", "gso", "tổng cục thống kê",
            "vietnam customs", "tổng cục hải quan",
            "vietnam news agency", "vna", "thông tấn xã việt nam",
            "voice of vietnam", "vov", "vtv", "đài truyền hình việt nam",
            "to lam", "tô lâm",
            "pham minh chinh", "phạm minh chính",
            "luong cuong", "lương cường",
            "tran thanh man", "trần thanh mẫn",
            "nguyen phu trong", "nguyễn phú trọng",
            "vo van thuong", "võ văn thưởng",
            "nguyen xuan phuc", "nguyễn xuân phúc",
            "bui thanh son", "bùi thanh sơn",
            "ho chi minh", "hồ chí minh"
        ]
    },
    "business_finance": {
        "weight": 8,
        "description": "Tập đoàn kinh tế, ngân hàng, thị trường chứng khoán",
        "keywords": [
            "vinfast", "vingroup", "vinhomes", "vinpearl", "vinmec", "vinschool",
            "viettel", "viettel group", "viettel telecom",
            "fpt", "fpt software", "fpt telecom", "fpt corporation",
            "vnpt", "mobifone",
            "masan", "masan group", "winmart", "wincommerce",
            "hoa phat", "hoa phat group", "thép hòa phát",
            "thaco", "thaco group", "truong hai auto",
            "vietnam airlines", "vietjet", "vietjet air", "bamboo airways",
            "petrovietnam", "pvn", "vietsovpetro", "pv gas", "petrolimex", "bsr",
            "evn", "vietnam electricity", "tập đoàn điện lực việt nam",
            "vinacomin", "tập đoàn than khoáng sản",
            "vinamilk", "th true milk", "sabeco", "habeco", "trung nguyen legend",
            "gelex", "novaland", "sovico",
            "vietcombank", "bidv", "vietinbank", "agribank", "techcombank",
            "mbbank", "military bank", "vpbank", "acb", "sacombank",
            "hdbank", "shb", "tpbank", "vib", "lpbank", "seabank", "msb", "ocb",
            "vn-index", "vnindex", "vn30", "hnx-index", "hnx", "hose", "upcom",
            "ho chi minh stock exchange", "hanoi stock exchange"
        ]
    },
    "culture_economy": {
        "weight": 6,
        "description": "Tiền tệ, văn hóa, ẩm thực và đời sống xã hội",
        "keywords": [
            "vnd", "vietnamese dong", "vietnam dong", "dong currency",
            "tỷ đồng", "nghìn tỷ đồng", "ngàn tỷ đồng", "trillion dong", "billion dong",
            "tet holiday", "tet nguyen dan", "tết nguyên đán", "lunar new year in vietnam",
            "hung kings festival", "giỗ tổ hùng vương",
            "ao dai", "áo dài", "non la", "nón lá",
            "pho", "phở", "banh mi", "bánh mì", "bun cha", "bún chả", "cha ca", "chả cá",
            "ca phe sua da", "cà phê sữa đá", "vietnamese coffee", "nuoc mam", "nước mắm", "egg coffee"
        ]
    }
}

# Danh sách từ khóa phẳng theo yêu cầu giao diện module
VIETNAM_KEYWORDS: List[str] = sorted(list({
    kw.lower()
    for cat in VIETNAM_KEYWORD_TAXONOMY.values()
    for kw in cat["keywords"]
}))

# Danh sách từ khóa chiến tranh / hồi tưởng lịch sử (phục vụ lọc nhiễu)
WAR_RETROSPECTIVE_KEYWORDS: List[str] = [
    "vietnam war", "vietnam-era", "vietnam era", "vietnam veteran", "vietnam veterans",
    "vietnam war veteran", "vietnam war veterans", "vietnam memorial", "vietnam war memorial",
    "fall of saigon", "anti-war movement", "anti-war protest", "anti-war protesters",
    "gulf of tonkin incident", "agent orange"
]


# ==============================================================================
# 2. XÂY DỰNG BỘ MÃ HÓA PATTERN & TRA CỨU
# ==============================================================================
_KEYWORD_LOOKUP: Dict[str, Dict[str, Any]] = {}
for _cat_name, _cat_data in VIETNAM_KEYWORD_TAXONOMY.items():
    _w = _cat_data["weight"]
    for _kw in _cat_data["keywords"]:
        _norm = _kw.lower().strip()
        _KEYWORD_LOOKUP[_norm] = {
            "category": _cat_name,
            "weight": _w
        }

# Tiền biên dịch Regex khớp từ khóa (Ưu tiên cụm từ dài trước)
_SORTED_KEYWORDS = sorted(_KEYWORD_LOOKUP.keys(), key=len, reverse=True)
_MASTER_REGEX = re.compile(
    r"(?<![\w\-])(?:" + "|".join(re.escape(k) for k in _SORTED_KEYWORDS) + r")(?![\w\-])",
    re.IGNORECASE | re.UNICODE
)

_WAR_REGEX = re.compile(
    r"(?<![\w\-])(?:" + "|".join(re.escape(k) for k in sorted(WAR_RETROSPECTIVE_KEYWORDS, key=len, reverse=True)) + r")(?![\w\-])",
    re.IGNORECASE | re.UNICODE
)


def _scan_keywords_in_text(text: str) -> Dict[str, int]:
    """Quét và đếm tần suất xuất hiện của các từ khóa Việt Nam trong một chuỗi văn bản."""
    if not text:
        return {}
    counts: Dict[str, int] = {}
    for match in _MASTER_REGEX.finditer(text):
        token = match.group(0).lower().strip()
        counts[token] = counts.get(token, 0) + 1
    return counts


# ==============================================================================
# 3. THUẬT TOÁN CHẤM ĐIỂM & PHÂN LOẠI (CALCULATE_VIETNAM_RELEVANCE)
# ==============================================================================
def calculate_vietnam_relevance(title: str, description: str, content: str) -> Dict[str, Any]:
    """
    Tính điểm và xác định mức độ liên quan thực sự của bài báo đến Việt Nam.

    Đầu vào:
        title (str): Tiêu đề bài báo
        description (str): Tóm tắt bài báo
        content (str): Nội dung bài báo

    Đầu ra (dict):
        relevance_score (int): Tổng điểm liên quan (0 - 100)
        is_vietnam_relevant (int): 1 nếu liên quan (Score >= 20), 0 nếu ngoài lề/nhiễu
        matched_keywords (list): Danh sách các từ khóa tìm thấy (sắp xếp a-z)
        relevance_level (str): 'High' | 'Medium' | 'Low' | 'Irrelevant'
        matched_categories (list): Danh sách các chủ đề từ khóa xuất hiện
    """
    clean_title = (title or "").strip()
    clean_desc = (description or "").strip()
    clean_content = (content or "").strip()

    # 1. Quét từ khóa theo từng khu vực văn bản
    title_counts = _scan_keywords_in_text(clean_title)
    desc_counts = _scan_keywords_in_text(clean_desc)
    content_counts = _scan_keywords_in_text(clean_content)

    all_matched_kws: Set[str] = set(title_counts.keys()) | set(desc_counts.keys()) | set(content_counts.keys())
    matched_categories: Set[str] = {
        _KEYWORD_LOOKUP[k]["category"]
        for k in all_matched_kws
        if k in _KEYWORD_LOOKUP
    }

    # 2. Trọng số theo khu vực văn bản
    #    Tiêu đề: Trọng số cao nhất (4.0x)
    #    Mô tả/Tóm tắt: Trọng số vừa (2.0x)
    #    Nội dung: Trọng số cơ bản (1.0x)
    TITLE_WEIGHT = 4.0
    DESC_WEIGHT = 2.0
    CONTENT_WEIGHT = 1.0

    title_score = 0.0
    for kw, cnt in title_counts.items():
        base_w = _KEYWORD_LOOKUP.get(kw, {}).get("weight", 6)
        title_score += base_w * TITLE_WEIGHT * min(cnt, 2)

    desc_score = 0.0
    for kw, cnt in desc_counts.items():
        base_w = _KEYWORD_LOOKUP.get(kw, {}).get("weight", 6)
        desc_score += base_w * DESC_WEIGHT * min(cnt, 2)

    content_score = 0.0
    for kw, cnt in content_counts.items():
        base_w = _KEYWORD_LOOKUP.get(kw, {}).get("weight", 6)
        # Sử dụng logarit để tránh bão hòa khi bài báo lặp đi lặp lại 1 từ khóa
        content_score += base_w * CONTENT_WEIGHT * (1.0 + math.log(cnt))

    raw_score = title_score + desc_score + content_score

    # 3. Điểm thưởng độ đa dạng ngữ nghĩa (Diversity & Cross-domain Bonus)
    n_unique = len(all_matched_kws)
    diversity_bonus = 0.0
    if n_unique >= 5:
        diversity_bonus = 15.0
    elif n_unique >= 3:
        diversity_bonus = 10.0
    elif n_unique >= 2:
        diversity_bonus = 5.0

    category_bonus = 8.0 if len(matched_categories) >= 2 else 0.0
    total_score = raw_score + diversity_bonus + category_bonus

    # 4. Cơ chế giảm trừ bài báo chiến tranh/lịch sử (War Retrospective Discount)
    full_text = f"{clean_title} {clean_desc} {clean_content}".lower()
    war_matches = _WAR_REGEX.findall(full_text)
    has_war_context = len(war_matches) > 0

    contemporary_categories = {
        "geography_provinces", "politics_government",
        "business_finance", "culture_economy", "landmarks_regions"
    }
    has_contemporary_context = bool(matched_categories & contemporary_categories)

    # Nếu chỉ đề cập "Vietnam" trong bối cảnh cuộc chiến/cựu binh và không có thực thể đương đại
    if has_war_context and not has_contemporary_context:
        total_score = total_score * 0.2

    # 5. Cơ chế xử lý bài báo nhắc thoáng qua (Incidental Mention)
    # Ví dụ: Bài báo quốc tế dài liệt kê 20 nước và chỉ nhắc "Vietnam" 1 lần duy nhất trong nội dung
    total_matches_count = sum(title_counts.values()) + sum(desc_counts.values()) + sum(content_counts.values())
    if len(title_counts) == 0 and len(desc_counts) == 0 and total_matches_count == 1:
        if len(clean_content.split()) > 50:
            total_score = min(total_score, 12.0)

    # 6. Chuẩn hóa thang điểm [0, 100] và xác định nhãn quyết định
    final_score = int(min(100.0, max(0.0, round(total_score))))
    RELEVANCE_THRESHOLD = 20
    is_relevant = 1 if final_score >= RELEVANCE_THRESHOLD else 0

    if final_score >= 60:
        level = "High"
    elif final_score >= 20:
        level = "Medium"
    elif final_score >= 10:
        level = "Low"
    else:
        level = "Irrelevant"

    return {
        "relevance_score": final_score,
        "is_vietnam_relevant": is_relevant,
        "matched_keywords": sorted(list(all_matched_kws)),
        "relevance_level": level,
        "matched_categories": sorted(list(matched_categories))
    }


def get_keyword_taxonomy() -> Dict[str, Dict[str, Any]]:
    """Trả về bộ từ điển phân loại chủ đề từ khóa Việt Nam."""
    return VIETNAM_KEYWORD_TAXONOMY


if __name__ == "__main__":
    # Khối chạy thử nghiệm độc lập của Thành viên 2
    print("=" * 75)
    print("--- CHẠY THỬ NGHIỆM MODULE VIETNAM RELEVANCE (THÀNH VIÊN 2) ---")
    print("=" * 75)

    test_suite = [
        {
            "name": "Ca kiểm thử 1: Tin kinh tế doanh nghiệp trong nước (VinFast, Hà Nội, Đà Nẵng)",
            "title": "VinFast expands EV charging network across Hanoi and Da Nang",
            "desc": "The Vietnamese automaker announced new investments in domestic infrastructure.",
            "content": "Vietnam's automotive market is growing rapidly with strong VND capital."
        },
        {
            "name": "Ca kiểm thử 2: Tin công nghệ quốc tế nhắc thoáng qua (Incidental mention)",
            "title": "Apple Q3 earnings show strong growth in wearable tech",
            "desc": "CEO Tim Cook noted expanding margins across major global manufacturing bases.",
            "content": "The company highlighted continued resilience in its partner network across China, India, and Vietnam, where factory output rose modestly compared to the previous quarter."
        },
        {
            "name": "Ca kiểm thử 3: Tin cựu binh chiến tranh Mỹ (Historical War Retrospective)",
            "title": "Ohio town honors Vietnam War veterans on Memorial Day",
            "desc": "Community gathers to remember those who served during the Vietnam War.",
            "content": "Local veterans shared their experiences from the Vietnam War era and reflected on the anti-war protests back home."
        },
        {
            "name": "Ca kiểm thử 4: Tin ngoại giao đương đại có nhắc đến dấu mốc lịch sử",
            "title": "US and Vietnam deepen semiconductor partnership during Hanoi summit",
            "desc": "Fifty years after the Vietnam War, ties between Washington and Hanoi have evolved into a comprehensive strategic partnership.",
            "content": "Prime Minister Pham Minh Chinh welcomed US tech executives to Hanoi, discussing multi-billion dollar chip foundry investments and trade expansion in the Vietnamese market."
        },
        {
            "name": "Ca kiểm thử 5: Tin thời sự tiếng Việt (Chính phủ, Cần Thơ, NHNN, VND)",
            "title": "Thủ tướng Phạm Minh Chính chủ trì hội nghị phát triển kinh tế vùng ĐBSCL",
            "desc": "Chính phủ tập trung tháo gỡ khó khăn về hạ tầng giao thông tại Cần Thơ và các tỉnh miền Tây.",
            "content": "Ngân hàng Nhà nước cam kết điều hành tín dụng linh hoạt, hỗ trợ doanh nghiệp và thúc đẩy dòng vốn VND."
        },
        {
            "name": "Ca kiểm thử 6: Tin hoàn toàn ngoài lề (Tesla tại Texas)",
            "title": "Tesla Cybertruck production reaches new milestone in Texas",
            "desc": "Elon Musk announced that the Austin factory has expanded daily output by 20%.",
            "content": "Automotive analysts expect fourth quarter deliveries to beat expectations on Wall Street as demand in North America remains robust."
        }
    ]

    for tc in test_suite:
        res = calculate_vietnam_relevance(tc["title"], tc["desc"], tc["content"])
        print(f"\n[{tc['name']}]")
        print(f"  • Điểm số (Score)        : {res['relevance_score']}/100")
        print(f"  • Chuẩn tin Việt Nam     : {'CÓ (Đạt chuẩn)' if res['is_vietnam_relevant'] else 'KHÔNG (Loại trừ)'} [{res['relevance_level']}]")
        print(f"  • Từ khóa phát hiện      : {res['matched_keywords']}")
        print(f"  • Lĩnh vực liên quan     : {res['matched_categories']}")

    print("\n" + "=" * 75)
    print(f"Tổng số từ khóa định danh trong từ điển: {len(VIETNAM_KEYWORDS)}")
    print("Hoàn tất kiểm thử module Vietnam Relevance.")
    print("=" * 75)

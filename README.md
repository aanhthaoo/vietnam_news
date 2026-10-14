# 🗞️ Vietnam News Intelligence Pipeline

> **Bài tập:** Data Engineering Pipeline — Thu thập và phân tích tin tức quốc tế về Việt Nam  
> **Công nghệ:** NewsAPI · Python · PostgreSQL 16 · Apache Superset · AI/ML  

---

## 📁 Cấu Trúc Dự Án

```
vietnam_news/
├── news_pipeline/              ← ETL Pipeline (Extract → Transform → Load)
│   ├── __init__.py
│   ├── collect_news.py         # Bước 1: Gọi NewsAPI lấy tin
│   ├── transform_news.py       # Bước 2: Làm sạch + Sentiment + Topics + NER
│   ├── store_news.py           # Bước 3: Lưu vào PostgreSQL (hỗ trợ SQLite fallback)
│   ├── check_data_quality.py   # Bước 4: Kiểm định chất lượng dữ liệu
│   ├── run_pipeline.py         # Entry point: chạy toàn bộ ETL
│   └── scheduler.py            # Tự động chạy hằng ngày 08:00
├── ai_models/                  ← AI & Machine Learning
│   ├── vader_sentiment.py      # VADER Sentiment Analyzer
│   ├── volume_forecaster.py    # Dự báo khối lượng tin tức (LinearRegression)
│   └── text_summarizer.py      # Tóm tắt tin tức tự động
├── superset_config/            ← Cấu hình Apache Superset
│   ├── superset_config.py      # Superset settings
│   ├── setup_news_superset.py  # Tạo Database + Datasets trên PostgreSQL
│   └── build_ai_dashboard.py   # Tự động dựng Dashboard 8 charts
├── docker-compose.yml          ← Khởi động PostgreSQL 16 & Apache Superset
├── .env                        ← Biến môi trường (DATABASE_URL, API Key, ...)
└── requirements.txt            ← Thư viện Python cần cài
```

---

## ⚙️ Cài Đặt & Khởi Động

### Bước 1 — Cài thư viện Python

```bash
pip install -r requirements.txt

# Tải spaCy model tiếng Anh
python -m spacy download en_core_web_sm

# Tải TextBlob corpora
python -c "import nltk; nltk.download('punkt'); nltk.download('averaged_perceptron_tagger')"
```

### Bước 2 — Cấu hình `.env`

Kiểm tra file `.env` đã có sẵn API Key:

```env
NEWS_API_KEY=0ef074c3cb824ad786d18a687454e30e
NEWS_KEYWORD=Vietnam
NEWS_LANGUAGE=en
NEWS_PAGE_SIZE=100
NEWS_DB_PATH=vietnam_news.db
```

### Bước 3 — Chạy ETL Pipeline lần đầu

```bash
# Chạy thu thập ngay (lấy tin 24h qua)
python news_pipeline/run_pipeline.py

# Hoặc chỉ định khoảng ngày cụ thể
python news_pipeline/run_pipeline.py --from 2024-01-01 --to 2024-01-31

# Tìm theo từ khóa khác
python news_pipeline/run_pipeline.py --keyword "Vietnam economy"
```

### Bước 4 — Khởi động Apache Superset

```bash
docker-compose up -d
```

> Lần đầu sẽ tự động: khởi tạo DB metadata → tạo admin → setup Datasets

Truy cập: **http://localhost:8088**  
Login: `admin` / `admin`

### Bước 5 — Tạo Dashboard (nếu chưa tự tạo)

```bash
docker exec vietnam_news_superset \
  python /app/pythonpath/build_news_dashboard.py
```

### Bước 6 — Bật Scheduler tự động hằng ngày

```bash
# Giữ cửa sổ terminal mở, pipeline tự chạy lúc 08:00 mỗi ngày
python news_pipeline/scheduler.py
```

---

## 📊 Dashboard Superset

Dashboard **"🗞️ Vietnam News Intelligence"** gồm 6 charts:

| # | Chart | Loại | Dataset |
|---|---|---|---|
| 1 | Xu hướng tin tức theo ngày | Line Chart | `news_daily_summary` |
| 2 | Top nguồn báo phổ biến | Bar Chart | `news_source_ranking` |
| 3 | Phân bố cảm xúc | Pie Chart | `news_sentiment_breakdown` |
| 4 | Điểm cảm xúc theo nguồn | Bar Chart | `news_source_ranking` |
| 5 | Tổng số bài báo | Big Number | `news_vietnam_articles` |
| 6 | Danh sách tin mới nhất | Table | `news_full_view` |

---

## 🗄️ Schema Cơ Sở Dữ Liệu

Bảng `news_vietnam_articles`:

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | Auto increment |
| `title` | TEXT | Tiêu đề bài báo |
| `description` | TEXT | Mô tả ngắn |
| `content` | TEXT | Nội dung (200 ký tự, free tier) |
| `url` | TEXT UNIQUE | Đường dẫn gốc (deduplication key) |
| `source_name` | TEXT | Tên nguồn báo |
| `author` | TEXT | Tác giả |
| `published_at` | DATETIME | Ngày xuất bản |
| `collected_at` | DATETIME | Ngày thu thập |
| `sentiment_label` | TEXT | Positive / Negative / Neutral |
| `sentiment_score` | REAL | -1.0 đến +1.0 |
| `entities_org` | TEXT (JSON) | Danh sách tổ chức/công ty |
| `entities_gpe` | TEXT (JSON) | Danh sách địa danh |
| `entities_person` | TEXT (JSON) | Danh sách nhân vật |

---

## 🔧 Kiến Trúc ETL

```
NewsAPI
  │  (HTTP GET /v2/everything?q=Vietnam)
  ▼
collect_news.py  ──── fetch + normalize
  │
  ▼
transform_news.py ─── clean HTML + Sentiment (TextBlob) + NER (spaCy)
  │
  ▼
store_news.py ──────── INSERT OR IGNORE → vietnam_news.db (SQLite)
  │
  ▼
Apache Superset ────── Datasets → Charts → Dashboard
```

---

## 📌 Lưu Ý

- **NewsAPI Free Tier:** giới hạn 100 requests/ngày, content bị cắt ~200 ký tự.
- **spaCy Model:** cần download `en_core_web_sm` trước khi chạy NER.
- **Deduplication:** URL được dùng làm UNIQUE KEY, an toàn khi chạy lại nhiều lần.
- **Superset:** lần đầu khởi động mất 2-3 phút để initialize.

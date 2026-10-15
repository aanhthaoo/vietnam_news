# 🗞️ Vietnam News Intelligence & AI Analytics Pipeline

> **Bài tập lớn:** Data Engineering & Business Intelligence System — Thu thập, Xử lý NLP, Phân tích AI và Trực quan hóa Tin tức Quốc tế về Việt Nam  
> **Công nghệ:** NewsAPI · Python · PostgreSQL 16 · Apache Superset · Scikit-Learn · VADER & TextBlob · Gemini API · Docker  

---

## 🚀 DÀNH CHO THÀNH VIÊN NHÓM (KHỞI ĐỘNG NHANH 1 LỆNH)

> [!TIP]
> **Dữ liệu mẫu (>200 bài báo đã qua xử lý AI) đã được đóng gói sẵn trong kho lưu trữ.**  
> Các thành viên trong nhóm **KHÔNG CẦN** chạy lệnh cào tin NewsAPI (tránh lỗi hết hạn ngạch 100 requests/ngày).

Chỉ cần cài Docker Desktop, mở terminal tại thư mục dự án và chạy duy nhất 1 lệnh:

```bash
docker compose up -d
```

### ✨ Quá trình tự động diễn ra:
1. **PostgreSQL 16** khởi động và **tự động nạp sẵn toàn bộ 213 bài báo, từ khóa và phân cụm tin tức** từ thư mục `postgres_init/01_init_news.sql`.
2. **Apache Superset** tự động kết nối PostgreSQL, đồng bộ Datasets và **tự động khởi tạo toàn bộ 11 Biểu đồ AI**.
3. **Truy cập ngay Dashboard:** Mở trình duyệt vào **[http://localhost:8088](http://localhost:8088)**  
   - Tài khoản: `admin`  
   - Mật khẩu: `admin`  
   - Link Dashboard: **[http://localhost:8088/superset/dashboard/2/](http://localhost:8088/superset/dashboard/2/)**

---

## 📁 Cấu Trúc Dự Án

```
vietnam_news/
├── news_pipeline/              ← ETL Pipeline (Extract → Transform → Load)
│   ├── collect_news.py         # Bước 1: Gọi NewsAPI lấy tin tức
│   ├── transform_news.py       # Bước 2: Làm sạch + VADER + spaCy NER + TF-IDF Keywords
│   ├── store_news.py           # Bước 3: Lưu trữ PostgreSQL (hỗ trợ SQLite fallback)
│   ├── check_data_quality.py   # Bước 4: Kiểm định chất lượng dữ liệu (Thành viên 5)
│   ├── run_pipeline.py         # Entry point: Chạy toàn bộ 6 bước ETL tự động
│   └── scheduler.py            # Tự động hóa chạy pipeline định kỳ hằng ngày 08:00
├── ai_models/                  ← Hệ thống Mô hình AI & Machine Learning
│   ├── vader_sentiment.py      # Phân tích cảm xúc Ensemble (VADER + TextBlob)
│   ├── volume_forecaster.py    # Dự báo khối lượng tin tức 7 ngày (LinearRegression)
│   ├── text_summarizer.py      # Tóm tắt tin tức tự động (Gemini API & Extractive)
│   ├── tfidf_keywords.py       # Trích xuất từ khóa TF-IDF & Vận tốc xu hướng (Rising/Falling)
│   ├── deduplicator.py         # Gom cụm sự kiện bằng Cosine Similarity & TF-IDF
│   ├── breaking_news.py        # Phát hiện tin nóng đột biến bằng Rolling 7-day Z-Score
│   ├── source_credibility.py   # Chấm điểm độ tin cậy định lượng nguồn báo quốc tế
│   ├── vietnam_relevance.py    # Bộ lọc xác thực tin tức Việt Nam (Thành viên 2)
│   └── topic_classifier.py     # Phân loại 8 chủ đề tin tức (Thành viên 3)
├── superset_config/            ← Cấu hình Apache Superset BI
│   ├── superset_config.py      # Cấu hình hệ thống Superset
│   ├── setup_news_superset.py  # Đăng ký Database & Datasets vật lý / ảo
│   └── build_ai_dashboard.py   # Tự động khởi tạo Dashboard 11 biểu đồ phân tích
├── postgres_init/              ← Dữ liệu mồi tự động cho PostgreSQL (Docker)
│   └── 01_init_news.sql        # Bản dump CSDL đầy đủ bảng, views và dữ liệu bài báo
├── docker-compose.yml          ← Điều phối dịch vụ PostgreSQL 16 & Apache Superset
├── .env                        ← Biến môi trường (DATABASE_URL, API Key...)
└── requirements.txt            ← Thư viện Python phục vụ phát triển
```

---

## 👥 Phân Công Nhiệm Vụ Trong Nhóm

| Thành viên | Trách nhiệm chính | File phụ trách |
|---|---|---|
| **Người 1** *(Lead Dev)* | Kiến trúc ETL, CSDL song song, Core AI (Ensemble, Forecast, Gemini, TF-IDF, Deduplication, Breaking News, Credibility), Docker & Superset Dashboard | `store_news.py`, `run_pipeline.py`, các file AI chính, `build_ai_dashboard.py` |
| **Người 2** *(Junior Dev)* | Xây dựng bộ từ khóa và giải thuật lọc bài báo thực sự về Việt Nam | `ai_models/vietnam_relevance.py` |
| **Người 3** *(Junior Dev)* | Xây dựng bộ quy tắc phân loại bài báo vào 8 chủ đề chính | `ai_models/topic_classifier.py` |
| **Người 4** *(Writer/BA)* | Soạn thảo Báo cáo Kỹ thuật (Word) & Slide Thuyết trình bảo vệ | `docs/Bao_Cao_Ky_Thuat.docx`, `Slide_Bao_Ve.pptx` |
| **Người 5** *(Tester/QA)* | Viết kiểm thử chất lượng dữ liệu (Quality Check) & tính thống kê | `news_pipeline/check_data_quality.py` |

---

## 📊 Dashboard Apache Superset (11 Biểu Đồ AI)

Dashboard **"🤖 Vietnam News AI Analytics & Forecasting"** (ID: 2) bao gồm:

| # | Tên Biểu đồ | Loại Trực quan hóa | Nguồn Dữ liệu |
|---|---|---|---|
| 1 | 📰 Tổng số bài báo | Big Number | `news_vietnam_articles` |
| 2 | 🇻🇳 Tỉ lệ tin chuẩn Việt Nam | Donut Chart | `news_vietnam_relevance` |
| 3 | 🎭 Cảm xúc Đa mô hình Ensemble | Donut Chart | `news_ensemble_sentiment` |
| 4 | 🏷️ Phân loại 8 Chủ đề Tin tức | Bar Chart | `news_ai_topics` |
| 5 | 📈 Dự báo Lượng tin tức 7 ngày tới | Line Chart (Confidence 95%) | `news_forecast_vs_actual` |
| 6 | 🏆 Top 10 Nguồn báo & Khối lượng | Bar Chart | `news_source_ranking` |
| 7 | ☁️ Đám mây Từ khóa Tiêu biểu | Word Cloud | `news_keyword_cloud` |
| 8 | 📋 Danh sách Tin tức & Tóm tắt AI | Interactive Table | `news_ai_summary_table` |
| 9 | ⭐ Xếp hạng Uy tín Nguồn báo Quốc tế | Ranked Table | `news_source_credibility` |
| 10 | 🌐 Gom cụm Sự kiện & Độ lan tỏa | Clustered Table | `news_story_clusters` |
| 11 | ⚡ Xu hướng Từ khóa & Chiều biến động | Velocity Table | `news_keyword_trends` |

---

## 🛠️ Hướng Dẫn Dành Cho Lập Trình Viên (Nâng Cao)

### 1. Cài đặt môi trường Python (để chạy code cục bộ)
```bash
python -m venv .venv
# Kích hoạt venv (Windows):
.venv\Scripts\activate

pip install -r requirements.txt
python -m spacy download en_core_web_sm
```

### 2. Chạy thủ công Pipeline ETL (Thu thập tin mới)
Nếu muốn thu thập thêm tin tức trực tiếp từ NewsAPI:
```bash
python news_pipeline/run_pipeline.py
```

### 3. Cập nhật lại Dashboard sau khi sửa đổi cấu hình
```bash
docker exec vietnam_news_superset python /app/pythonpath/setup_news_superset.py
docker exec vietnam_news_superset python /app/pythonpath/build_ai_dashboard.py
```

### 4. Bật Scheduler tự động chạy mỗi ngày lúc 08:00
```bash
python news_pipeline/scheduler.py
```

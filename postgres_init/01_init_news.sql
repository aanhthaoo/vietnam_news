--
-- PostgreSQL database dump
--

\restrict 6iZpIhu5rNUjSmEJp3h2SPqG8RI6rK9oKjzjILHxjo9sZfR9nTJKbW6eDrZVAVc

-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: news_vietnam_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_vietnam_articles (
    id integer NOT NULL,
    title character varying(1000) NOT NULL,
    description text,
    content text,
    url text,
    source_name character varying(500),
    author text,
    published_at timestamp without time zone,
    collected_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    sentiment_label character varying(50),
    sentiment_score numeric(8,4),
    entities_org text,
    entities_gpe text,
    entities_person text,
    vader_compound numeric(8,4) DEFAULT 0.0,
    vader_label character varying(50),
    ensemble_sentiment_label character varying(50),
    vietnam_relevance_score integer DEFAULT 0,
    is_vietnam_relevant integer DEFAULT 0,
    topic_label character varying(100) DEFAULT 'General'::character varying,
    topic_confidence numeric(8,4) DEFAULT 0.0,
    ai_summary text,
    word_count integer DEFAULT 0,
    keywords text,
    story_cluster_id integer DEFAULT 0
);


--
-- Name: news_articles; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.news_articles AS
 SELECT id,
    title,
    description,
    content,
    url,
    source_name,
    author,
    published_at,
    collected_at,
    sentiment_label,
    sentiment_score,
    entities_org,
    entities_gpe,
    entities_person,
    vader_compound,
    vader_label,
    ensemble_sentiment_label,
    vietnam_relevance_score,
    is_vietnam_relevant,
    topic_label,
    topic_confidence,
    ai_summary,
    word_count,
    keywords,
    story_cluster_id
   FROM public.news_vietnam_articles;


--
-- Name: news_keyword_trends; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_keyword_trends (
    id integer NOT NULL,
    date_str character varying(50),
    keyword character varying(255),
    frequency integer DEFAULT 1,
    trend_direction character varying(50) DEFAULT 'Stable'::character varying,
    trend_delta numeric(8,2) DEFAULT 0.0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: news_keyword_trends_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_keyword_trends_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_keyword_trends_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_keyword_trends_id_seq OWNED BY public.news_keyword_trends.id;


--
-- Name: news_vietnam_articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_vietnam_articles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_vietnam_articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_vietnam_articles_id_seq OWNED BY public.news_vietnam_articles.id;


--
-- Name: news_volume_forecast; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_volume_forecast (
    id integer NOT NULL,
    forecast_date character varying(50),
    predicted_count numeric(8,2),
    lower_bound numeric(8,2),
    upper_bound numeric(8,2),
    model_type character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: news_volume_forecast_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_volume_forecast_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_volume_forecast_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_volume_forecast_id_seq OWNED BY public.news_volume_forecast.id;


--
-- Name: vw_sentiment_ensemble; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_sentiment_ensemble AS
 SELECT ensemble_sentiment_label,
    count(*) AS count
   FROM public.news_vietnam_articles
  GROUP BY ensemble_sentiment_label;


--
-- Name: vw_source_credibility; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_source_credibility AS
 SELECT source_name,
    count(*) AS total_articles,
    round(avg(COALESCE(word_count, 0)), 1) AS avg_word_count,
    round((avg(
        CASE
            WHEN (is_vietnam_relevant = 1) THEN 1.0
            ELSE 0.0
        END) * (100)::numeric), 1) AS vn_relevance_pct,
    round(avg(COALESCE(sentiment_score, (0)::numeric)), 3) AS avg_sentiment,
    round(LEAST(100.0, GREATEST(10.0, ((
        CASE
            WHEN (count(*) >= 5) THEN 30.0
            ELSE ((count(*))::numeric * 6.0)
        END + (avg(
        CASE
            WHEN (is_vietnam_relevant = 1) THEN 1.0
            ELSE 0.0
        END) * 35.0)) + LEAST((avg(COALESCE(word_count, 0)) / 20.0), 35.0)))), 1) AS credibility_score
   FROM public.news_vietnam_articles
  WHERE ((source_name IS NOT NULL) AND ((source_name)::text <> ''::text))
  GROUP BY source_name;


--
-- Name: vw_story_clusters; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_story_clusters AS
 SELECT story_cluster_id,
    min((title)::text) AS lead_title,
    count(*) AS article_count,
    count(DISTINCT source_name) AS unique_sources,
    min(published_at) AS first_published,
    max(published_at) AS last_published,
    max((topic_label)::text) AS main_topic,
    max((ensemble_sentiment_label)::text) AS dominant_sentiment
   FROM public.news_vietnam_articles
  WHERE ((story_cluster_id IS NOT NULL) AND (story_cluster_id > 0))
  GROUP BY story_cluster_id
  ORDER BY (count(*)) DESC;


--
-- Name: vw_topic_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_topic_summary AS
 SELECT topic_label,
    count(*) AS article_count,
    round(avg(COALESCE(sentiment_score, (0)::numeric)), 4) AS avg_sentiment
   FROM public.news_vietnam_articles
  GROUP BY topic_label;


--
-- Name: vw_vietnam_relevant; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_vietnam_relevant AS
 SELECT id,
    title,
    description,
    content,
    url,
    source_name,
    author,
    published_at,
    collected_at,
    sentiment_label,
    sentiment_score,
    entities_org,
    entities_gpe,
    entities_person,
    vader_compound,
    vader_label,
    ensemble_sentiment_label,
    vietnam_relevance_score,
    is_vietnam_relevant,
    topic_label,
    topic_confidence,
    ai_summary,
    word_count,
    keywords,
    story_cluster_id
   FROM public.news_vietnam_articles
  WHERE (is_vietnam_relevant = 1);


--
-- Name: news_keyword_trends id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_keyword_trends ALTER COLUMN id SET DEFAULT nextval('public.news_keyword_trends_id_seq'::regclass);


--
-- Name: news_vietnam_articles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_vietnam_articles ALTER COLUMN id SET DEFAULT nextval('public.news_vietnam_articles_id_seq'::regclass);


--
-- Name: news_volume_forecast id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_volume_forecast ALTER COLUMN id SET DEFAULT nextval('public.news_volume_forecast_id_seq'::regclass);


--
-- Data for Name: news_keyword_trends; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.news_keyword_trends (id, date_str, keyword, frequency, trend_direction, trend_delta, created_at) FROM stdin;
1	2026-10-01	accor	1	Stable	0.00	2026-10-16 00:04:40
2	2026-10-01	actually	2	Rising	100.00	2026-10-16 00:04:40
3	2026-10-01	advantage cheapest	1	Stable	0.00	2026-10-16 00:04:40
12	2026-10-01	announced	1	Rising	100.00	2026-10-16 00:04:40
18	2026-10-01	bay	1	Rising	100.00	2026-10-16 00:04:40
20	2026-10-01	belt	1	Rising	100.00	2026-10-16 00:04:40
21	2026-10-01	benefits	1	Rising	100.00	2026-10-16 00:04:40
23	2026-10-01	big	1	Stable	0.00	2026-10-16 00:04:40
25	2026-10-01	bonus	1	Rising	100.00	2026-10-16 00:04:40
26	2026-10-01	book	1	Stable	0.00	2026-10-16 00:04:40
27	2026-10-01	boyfriend	1	Stable	0.00	2026-10-16 00:04:40
34	2026-10-01	cheapest	1	Stable	0.00	2026-10-16 00:04:40
35	2026-10-01	cheapest option	1	Stable	0.00	2026-10-16 00:04:40
43	2026-10-01	continues	2	Stable	0.00	2026-10-16 00:04:40
49	2026-10-01	date november	1	Stable	0.00	2026-10-16 00:04:40
56	2026-10-01	doesn	1	Rising	100.00	2026-10-16 00:04:40
58	2026-10-01	donald trump	1	Stable	0.00	2026-10-16 00:04:40
65	2026-10-01	fall	1	Rising	100.00	2026-10-16 00:04:40
67	2026-10-01	film	1	Rising	100.00	2026-10-16 00:04:40
69	2026-10-01	firm	1	Rising	100.00	2026-10-16 00:04:40
94	2026-10-01	injunction	1	Stable	0.00	2026-10-16 00:04:40
97	2026-10-01	intruder	1	Stable	0.00	2026-10-16 00:04:40
99	2026-10-01	islands	1	Rising	100.00	2026-10-16 00:04:40
102	2026-10-01	john	2	Stable	0.00	2026-10-16 00:04:40
103	2026-10-01	judge	1	Stable	0.00	2026-10-16 00:04:40
104	2026-10-01	kills	1	Rising	100.00	2026-10-16 00:04:40
106	2026-10-01	know	1	Stable	0.00	2026-10-16 00:04:40
109	2026-10-01	leader	1	Rising	100.00	2026-10-16 00:04:40
119	2026-10-01	manufacturing	1	Rising	100.00	2026-10-16 00:04:40
120	2026-10-01	marketing	1	Stable	0.00	2026-10-16 00:04:40
121	2026-10-01	markets	1	Rising	100.00	2026-10-16 00:04:40
123	2026-10-01	maxim	1	Stable	0.00	2026-10-16 00:04:40
129	2026-10-01	men volleyball	1	Stable	0.00	2026-10-16 00:04:40
134	2026-10-01	missile	1	Stable	0.00	2026-10-16 00:04:40
135	2026-10-01	mode	1	Stable	0.00	2026-10-16 00:04:40
139	2026-10-01	north	1	Stable	0.00	2026-10-16 00:04:40
144	2026-10-01	opens million	3	Stable	0.00	2026-10-16 00:04:40
145	2026-10-01	option sample	2	Stable	0.00	2026-10-16 00:04:40
148	2026-10-01	particularly	1	Stable	0.00	2026-10-16 00:04:40
149	2026-10-01	partner	1	Rising	100.00	2026-10-16 00:04:40
151	2026-10-01	pay	1	Rising	100.00	2026-10-16 00:04:40
154	2026-10-01	photo	2	Stable	0.00	2026-10-16 00:04:40
159	2026-10-01	points	1	Stable	0.00	2026-10-16 00:04:40
167	2026-10-01	recent	1	Rising	100.00	2026-10-16 00:04:40
168	2026-10-01	relief	1	Rising	100.00	2026-10-16 00:04:40
170	2026-10-01	reporter	2	Stable	0.00	2026-10-16 00:04:40
171	2026-10-01	resilience	1	Rising	100.00	2026-10-16 00:04:40
175	2026-10-01	revive	2	Stable	0.00	2026-10-16 00:04:40
185	2026-10-01	service	1	Rising	100.00	2026-10-16 00:04:40
190	2026-10-01	silver medals	1	Stable	0.00	2026-10-16 00:04:40
191	2026-10-01	site	2	Rising	100.00	2026-10-16 00:04:40
195	2026-10-01	stocks	1	Stable	0.00	2026-10-16 00:04:40
197	2026-10-01	success	1	Rising	100.00	2026-10-16 00:04:40
200	2026-10-01	teams	1	Stable	0.00	2026-10-16 00:04:40
201	2026-10-01	tender	1	Stable	0.00	2026-10-16 00:04:40
202	2026-10-01	training	1	Rising	100.00	2026-10-16 00:04:40
203	2026-10-01	travelers	1	Rising	100.00	2026-10-16 00:04:40
205	2026-10-01	usa	1	Rising	100.00	2026-10-16 00:04:40
214	2026-10-11	affleck	1	Rising	100.00	2026-10-16 00:04:40
215	2026-10-11	apply	1	Rising	100.00	2026-10-16 00:04:40
217	2026-10-11	availability follow	2	Rising	100.00	2026-10-16 00:04:40
222	2026-10-11	controversial	1	Rising	100.00	2026-10-16 00:04:40
226	2026-10-11	fcc	1	Rising	100.00	2026-10-16 00:04:40
234	2026-10-11	labs	1	Rising	100.00	2026-10-16 00:04:40
237	2026-10-11	managing god	1	Rising	100.00	2026-10-16 00:04:40
242	2026-10-11	pastors	1	Rising	100.00	2026-10-16 00:04:40
243	2026-10-11	pastors point	1	Rising	100.00	2026-10-16 00:04:40
244	2026-10-11	point genesis	1	Rising	100.00	2026-10-16 00:04:40
245	2026-10-11	relief	1	Rising	100.00	2026-10-16 00:04:40
248	2026-10-11	south	1	Rising	100.00	2026-10-16 00:04:40
252	2026-10-11	training	1	Rising	100.00	2026-10-16 00:04:40
255	2026-10-11	understanding	1	Rising	100.00	2026-10-16 00:04:40
256	2026-10-11	use	1	Rising	100.00	2026-10-16 00:04:40
258	2026-10-12	actually	1	Rising	100.00	2026-10-16 00:04:40
261	2026-10-12	allegedly shooting	1	Rising	100.00	2026-10-16 00:04:40
263	2026-10-12	amid	1	Rising	100.00	2026-10-16 00:04:40
264	2026-10-12	announced	1	Rising	100.00	2026-10-16 00:04:40
270	2026-10-12	bacon	1	Rising	100.00	2026-10-16 00:04:40
271	2026-10-12	baiduri	1	Rising	100.00	2026-10-16 00:04:40
272	2026-10-12	baiduri bank	1	Rising	100.00	2026-10-16 00:04:40
274	2026-10-12	benefits	1	Rising	100.00	2026-10-16 00:04:40
277	2026-10-12	bonus	1	Rising	100.00	2026-10-16 00:04:40
278	2026-10-12	branded	1	Rising	100.00	2026-10-16 00:04:40
282	2026-10-12	capital	1	Rising	100.00	2026-10-16 00:04:40
285	2026-10-12	columbus	1	Rising	100.00	2026-10-16 00:04:40
288	2026-10-12	deals	1	Rising	100.00	2026-10-16 00:04:40
290	2026-10-12	destinations	1	Rising	100.00	2026-10-16 00:04:40
293	2026-10-12	election	1	Rising	100.00	2026-10-16 00:04:40
295	2026-10-12	escape	1	Rising	100.00	2026-10-16 00:04:40
296	2026-10-12	expected	1	Rising	100.00	2026-10-16 00:04:40
297	2026-10-12	experience	1	Rising	100.00	2026-10-16 00:04:40
299	2026-10-12	fish wildlife	1	Rising	100.00	2026-10-16 00:04:40
331	2026-10-12	issues	1	Rising	100.00	2026-10-16 00:04:40
334	2026-10-12	land	1	Rising	100.00	2026-10-16 00:04:40
336	2026-10-12	leader	1	Rising	100.00	2026-10-16 00:04:40
340	2026-10-12	long	1	Rising	100.00	2026-10-16 00:04:40
341	2026-10-12	lower	1	Rising	100.00	2026-10-16 00:04:40
342	2026-10-12	maga	1	Rising	100.00	2026-10-16 00:04:40
347	2026-10-12	member	1	Rising	100.00	2026-10-16 00:04:40
348	2026-10-12	meta	1	Rising	100.00	2026-10-16 00:04:40
353	2026-10-12	national	1	Rising	100.00	2026-10-16 00:04:40
354	2026-10-12	oct	1	Rising	100.00	2026-10-16 00:04:40
359	2026-10-12	partner	1	Rising	100.00	2026-10-16 00:04:40
362	2026-10-12	perry	1	Rising	100.00	2026-10-16 00:04:40
363	2026-10-12	perry bacon	1	Rising	100.00	2026-10-16 00:04:40
365	2026-10-12	place	1	Rising	100.00	2026-10-16 00:04:40
374	2026-10-12	programme	1	Rising	100.00	2026-10-16 00:04:40
376	2026-10-12	recent	1	Rising	100.00	2026-10-16 00:04:40
379	2026-10-12	resilience	1	Rising	100.00	2026-10-16 00:04:40
392	2026-10-12	set	1	Rising	100.00	2026-10-16 00:04:40
397	2026-10-12	specialists	1	Rising	100.00	2026-10-16 00:04:40
403	2026-10-12	teenagers	1	Rising	100.00	2026-10-16 00:04:40
406	2026-10-12	travelers	1	Rising	100.00	2026-10-16 00:04:40
407	2026-10-12	understanding	2	Rising	100.00	2026-10-16 00:04:40
409	2026-10-12	use	1	Rising	100.00	2026-10-16 00:04:40
413	2026-10-12	watch	2	Rising	100.00	2026-10-16 00:04:40
415	2026-10-13	america	1	Rising	100.00	2026-10-16 00:04:40
419	2026-10-13	asked	1	Rising	100.00	2026-10-16 00:04:40
423	2026-10-13	bay	1	Rising	100.00	2026-10-16 00:04:40
424	2026-10-13	belt	1	Rising	100.00	2026-10-16 00:04:40
425	2026-10-13	brands	2	Rising	100.00	2026-10-16 00:04:40
426	2026-10-13	built	2	Rising	100.00	2026-10-16 00:04:40
428	2026-10-13	california	1	Rising	100.00	2026-10-16 00:04:40
429	2026-10-13	capital	1	Rising	100.00	2026-10-16 00:04:40
430	2026-10-13	card	1	Rising	100.00	2026-10-16 00:04:40
440	2026-10-13	columbus	1	Rising	100.00	2026-10-16 00:04:40
441	2026-10-13	com	1	Rising	100.00	2026-10-16 00:04:40
442	2026-10-13	cooperation	1	Rising	100.00	2026-10-16 00:04:40
447	2026-10-13	deals	1	Rising	100.00	2026-10-16 00:04:40
449	2026-10-13	destinations	1	Rising	100.00	2026-10-16 00:04:40
450	2026-10-13	detection	1	Rising	100.00	2026-10-16 00:04:40
456	2026-10-13	electronics	1	Rising	100.00	2026-10-16 00:04:40
457	2026-10-13	energy	1	Rising	100.00	2026-10-16 00:04:40
458	2026-10-13	escape	2	Rising	100.00	2026-10-16 00:04:40
460	2026-10-13	expected	1	Rising	100.00	2026-10-16 00:04:40
461	2026-10-13	experience	1	Rising	100.00	2026-10-16 00:04:40
464	2026-10-13	fall	1	Rising	100.00	2026-10-16 00:04:40
465	2026-10-13	films	1	Rising	100.00	2026-10-16 00:04:40
466	2026-10-13	firm	1	Rising	100.00	2026-10-16 00:04:40
468	2026-10-13	foreign	1	Rising	100.00	2026-10-16 00:04:40
490	2026-10-13	investment	1	Rising	100.00	2026-10-16 00:04:40
492	2026-10-13	islands	1	Rising	100.00	2026-10-16 00:04:40
495	2026-10-13	kills	1	Rising	100.00	2026-10-16 00:04:40
498	2026-10-13	labs	1	Rising	100.00	2026-10-16 00:04:40
499	2026-10-13	lake	2	Rising	100.00	2026-10-16 00:04:40
500	2026-10-13	leader	1	Rising	100.00	2026-10-16 00:04:40
502	2026-10-13	learning	2	Rising	100.00	2026-10-16 00:04:40
503	2026-10-13	leaving	2	Rising	100.00	2026-10-16 00:04:40
504	2026-10-13	library	2	Rising	100.00	2026-10-16 00:04:40
505	2026-10-13	links	1	Rising	100.00	2026-10-16 00:04:40
507	2026-10-13	lower	1	Rising	100.00	2026-10-16 00:04:40
512	2026-10-13	member	1	Rising	100.00	2026-10-16 00:04:40
513	2026-10-13	meta	1	Rising	100.00	2026-10-16 00:04:40
520	2026-10-13	national	1	Rising	100.00	2026-10-16 00:04:40
526	2026-10-13	partner	1	Rising	100.00	2026-10-16 00:04:40
529	2026-10-13	patients	2	Rising	100.00	2026-10-16 00:04:40
530	2026-10-13	pay	1	Rising	100.00	2026-10-16 00:04:40
531	2026-10-13	planned	1	Rising	100.00	2026-10-16 00:04:40
533	2026-10-13	police department	1	Rising	100.00	2026-10-16 00:04:40
534	2026-10-13	policy seeks	1	Rising	100.00	2026-10-16 00:04:40
538	2026-10-13	projects	2	Rising	100.00	2026-10-16 00:04:40
544	2026-10-13	san	1	Rising	100.00	2026-10-16 00:04:40
552	2026-10-13	site	1	Rising	100.00	2026-10-16 00:04:40
553	2026-10-13	snow	1	Rising	100.00	2026-10-16 00:04:40
554	2026-10-13	southeast	1	Rising	100.00	2026-10-16 00:04:40
555	2026-10-13	southeast asia	1	Rising	100.00	2026-10-16 00:04:40
557	2026-10-13	square	1	Rising	100.00	2026-10-16 00:04:40
558	2026-10-13	standard	1	Rising	100.00	2026-10-16 00:04:40
562	2026-10-13	steel policy	1	Rising	100.00	2026-10-16 00:04:40
564	2026-10-13	sub	1	Rising	100.00	2026-10-16 00:04:40
565	2026-10-13	sub standard	1	Rising	100.00	2026-10-16 00:04:40
566	2026-10-13	success	1	Rising	100.00	2026-10-16 00:04:40
573	2026-10-13	training	1	Rising	100.00	2026-10-16 00:04:40
576	2026-10-13	usa	1	Rising	100.00	2026-10-16 00:04:40
578	2026-10-13	usd million	1	Rising	100.00	2026-10-16 00:04:40
579	2026-10-13	use	1	Rising	100.00	2026-10-16 00:04:40
587	2026-10-01	advantage	1	Rising	100.00	2026-10-16 00:25:00
4	2026-10-01	agency	1	Rising	100.00	2026-10-16 00:25:00
5	2026-10-01	air	1	Rising	100.00	2026-10-16 00:25:00
6	2026-10-01	ali	1	Rising	100.00	2026-10-16 00:25:00
7	2026-10-01	alleged	1	Rising	100.00	2026-10-16 00:25:00
8	2026-10-01	alleged intruder	1	Stable	0.00	2026-10-16 00:25:00
9	2026-10-01	america	2	Stable	0.00	2026-10-16 00:25:00
10	2026-10-01	amid	1	Stable	0.00	2026-10-16 00:25:00
11	2026-10-01	anniversary	2	Rising	100.00	2026-10-16 00:25:00
13	2026-10-01	appeared	1	Rising	100.00	2026-10-16 00:25:00
14	2026-10-01	asia pacific	1	Rising	100.00	2026-10-16 00:25:00
598	2026-10-01	asian	1	Stable	0.00	2026-10-16 00:25:00
15	2026-10-01	asian games	3	Stable	0.00	2026-10-16 00:25:00
600	2026-10-01	asian markets	1	Rising	100.00	2026-10-16 00:25:00
16	2026-10-01	asked	1	Stable	0.00	2026-10-16 00:25:00
602	2026-10-01	august	1	Rising	100.00	2026-10-16 00:25:00
17	2026-10-01	award	2	Rising	100.00	2026-10-16 00:25:00
604	2026-10-01	ban	1	Rising	100.00	2026-10-16 00:25:00
19	2026-10-01	beach	1	Rising	100.00	2026-10-16 00:25:00
22	2026-10-01	best	2	Rising	100.00	2026-10-16 00:25:00
24	2026-10-01	biggest	3	Rising	100.00	2026-10-16 00:25:00
608	2026-10-01	box	1	Rising	100.00	2026-10-16 00:25:00
28	2026-10-01	build	1	Rising	100.00	2026-10-16 00:25:00
29	2026-10-01	business	1	Rising	100.00	2026-10-16 00:25:00
30	2026-10-01	case	1	Rising	100.00	2026-10-16 00:25:00
31	2026-10-01	center	2	Rising	100.00	2026-10-16 00:25:00
613	2026-10-01	ceo	1	Rising	100.00	2026-10-16 00:25:00
614	2026-10-01	chain	1	Stable	0.00	2026-10-16 00:25:00
32	2026-10-01	challenges	1	Stable	0.00	2026-10-16 00:25:00
616	2026-10-01	changing	1	Rising	100.00	2026-10-16 00:25:00
33	2026-10-01	charts	2	Stable	0.00	2026-10-16 00:25:00
36	2026-10-01	chi	3	Rising	100.00	2026-10-16 00:25:00
37	2026-10-01	chi minh	4	Rising	100.00	2026-10-16 00:25:00
38	2026-10-01	chief	1	Rising	100.00	2026-10-16 00:25:00
39	2026-10-01	city	3	Rising	100.00	2026-10-16 00:25:00
622	2026-10-01	come	1	Stable	0.00	2026-10-16 00:25:00
40	2026-10-01	company	1	Rising	100.00	2026-10-16 00:25:00
41	2026-10-01	connecticut	1	Stable	0.00	2026-10-16 00:25:00
42	2026-10-01	content	1	Rising	100.00	2026-10-16 00:25:00
44	2026-10-01	corporation	1	Stable	0.00	2026-10-16 00:25:00
627	2026-10-01	created	1	Rising	100.00	2026-10-16 00:25:00
45	2026-10-01	cricket	1	Stable	0.00	2026-10-16 00:25:00
46	2026-10-01	crime	1	Rising	100.00	2026-10-16 00:25:00
47	2026-10-01	cruise	1	Stable	0.00	2026-10-16 00:25:00
48	2026-10-01	data	2	Rising	100.00	2026-10-16 00:25:00
632	2026-10-01	days	1	Rising	100.00	2026-10-16 00:25:00
50	2026-10-01	december	1	Rising	100.00	2026-10-16 00:25:00
51	2026-10-01	demand	1	Rising	100.00	2026-10-16 00:25:00
635	2026-10-01	developer	1	Stable	0.00	2026-10-16 00:25:00
52	2026-10-01	development	1	Rising	100.00	2026-10-16 00:25:00
53	2026-10-01	dfi	1	Stable	0.00	2026-10-16 00:25:00
638	2026-10-01	digital	1	Rising	100.00	2026-10-16 00:25:00
54	2026-10-01	dlc	3	Stable	0.00	2026-10-16 00:25:00
55	2026-10-01	does	2	Rising	100.00	2026-10-16 00:25:00
57	2026-10-01	domestic	1	Rising	100.00	2026-10-16 00:25:00
642	2026-10-01	economic	1	Rising	100.00	2026-10-16 00:25:00
59	2026-10-01	emerging	1	Rising	100.00	2026-10-16 00:25:00
60	2026-10-01	end	2	Rising	100.00	2026-10-16 00:25:00
61	2026-10-01	expand	1	Rising	100.00	2026-10-16 00:25:00
62	2026-10-01	expansion	2	Stable	0.00	2026-10-16 00:25:00
63	2026-10-01	export	1	Rising	100.00	2026-10-16 00:25:00
648	2026-10-01	exports	1	Rising	100.00	2026-10-16 00:25:00
64	2026-10-01	facility	2	Stable	0.00	2026-10-16 00:25:00
650	2026-10-01	festival	1	Rising	100.00	2026-10-16 00:25:00
66	2026-10-01	fights	1	Stable	0.00	2026-10-16 00:25:00
652	2026-10-01	film festival	1	Rising	100.00	2026-10-16 00:25:00
68	2026-10-01	films	1	Stable	0.00	2026-10-16 00:25:00
654	2026-10-01	flights	1	Rising	100.00	2026-10-16 00:25:00
655	2026-10-01	francisco	1	Rising	100.00	2026-10-16 00:25:00
70	2026-10-01	frazier	1	Stable	0.00	2026-10-16 00:25:00
71	2026-10-01	free	1	Rising	100.00	2026-10-16 00:25:00
72	2026-10-01	free dlc	1	Stable	0.00	2026-10-16 00:25:00
73	2026-10-01	fuel	1	Rising	100.00	2026-10-16 00:25:00
74	2026-10-01	future	2	Rising	100.00	2026-10-16 00:25:00
75	2026-10-01	game	1	Stable	0.00	2026-10-16 00:25:00
76	2026-10-01	game plus	1	Stable	0.00	2026-10-16 00:25:00
77	2026-10-01	games	2	Stable	0.00	2026-10-16 00:25:00
78	2026-10-01	global	2	Rising	100.00	2026-10-16 00:25:00
79	2026-10-01	glock	1	Stable	0.00	2026-10-16 00:25:00
80	2026-10-01	glock ban	1	Stable	0.00	2026-10-16 00:25:00
667	2026-10-01	goes	1	Rising	100.00	2026-10-16 00:25:00
81	2026-10-01	gold	1	Stable	0.00	2026-10-16 00:25:00
82	2026-10-01	gold silver	3	Stable	0.00	2026-10-16 00:25:00
83	2026-10-01	great	1	Rising	100.00	2026-10-16 00:25:00
671	2026-10-01	group	1	Rising	100.00	2026-10-16 00:25:00
84	2026-10-01	hanoi	1	Rising	100.00	2026-10-16 00:25:00
673	2026-10-01	hegseth	1	Rising	100.00	2026-10-16 00:25:00
674	2026-10-01	highlights	1	Rising	100.00	2026-10-16 00:25:00
85	2026-10-01	history	2	Rising	100.00	2026-10-16 00:25:00
86	2026-10-01	hopes	1	Rising	100.00	2026-10-16 00:25:00
87	2026-10-01	hotel	2	Rising	100.00	2026-10-16 00:25:00
88	2026-10-01	hotels	1	Rising	100.00	2026-10-16 00:25:00
89	2026-10-01	house	1	Rising	100.00	2026-10-16 00:25:00
90	2026-10-01	illegal	2	Rising	100.00	2026-10-16 00:25:00
91	2026-10-01	illegal ivory	1	Rising	100.00	2026-10-16 00:25:00
682	2026-10-01	image	1	Rising	100.00	2026-10-16 00:25:00
683	2026-10-01	includes	2	Stable	0.00	2026-10-16 00:25:00
92	2026-10-01	india	2	Rising	100.00	2026-10-16 00:25:00
93	2026-10-01	india emerging	1	Rising	100.00	2026-10-16 00:25:00
95	2026-10-01	intelligence	1	Rising	100.00	2026-10-16 00:25:00
96	2026-10-01	international	1	Rising	100.00	2026-10-16 00:25:00
98	2026-10-01	iran	1	Rising	100.00	2026-10-16 00:25:00
689	2026-10-01	iran war	1	Rising	100.00	2026-10-16 00:25:00
100	2026-10-01	ivory	1	Rising	100.00	2026-10-16 00:25:00
101	2026-10-01	jewelry	3	Stable	0.00	2026-10-16 00:25:00
692	2026-10-01	key	1	Rising	100.00	2026-10-16 00:25:00
105	2026-10-01	king	1	Rising	100.00	2026-10-16 00:25:00
107	2026-10-01	late	2	Stable	0.00	2026-10-16 00:25:00
108	2026-10-01	lead	2	Stable	0.00	2026-10-16 00:25:00
696	2026-10-01	learned	1	Rising	100.00	2026-10-16 00:25:00
110	2026-10-01	led	1	Rising	100.00	2026-10-16 00:25:00
111	2026-10-01	library	1	Stable	0.00	2026-10-16 00:25:00
112	2026-10-01	light	3	Stable	0.00	2026-10-16 00:25:00
113	2026-10-01	links	1	Rising	100.00	2026-10-16 00:25:00
114	2026-10-01	list	1	Rising	100.00	2026-10-16 00:25:00
115	2026-10-01	live	3	Rising	100.00	2026-10-16 00:25:00
116	2026-10-01	long	1	Rising	100.00	2026-10-16 00:25:00
117	2026-10-01	make	2	Rising	100.00	2026-10-16 00:25:00
118	2026-10-01	managing	1	Rising	100.00	2026-10-16 00:25:00
122	2026-10-01	marks	1	Rising	100.00	2026-10-16 00:25:00
124	2026-10-01	measures	1	Rising	100.00	2026-10-16 00:25:00
125	2026-10-01	medal	2	Stable	0.00	2026-10-16 00:25:00
126	2026-10-01	medals	2	Stable	0.00	2026-10-16 00:25:00
127	2026-10-01	media	2	Rising	100.00	2026-10-16 00:25:00
128	2026-10-01	men	2	Stable	0.00	2026-10-16 00:25:00
712	2026-10-01	middle east	1	Rising	100.00	2026-10-16 00:25:00
130	2026-10-01	military	2	Rising	100.00	2026-10-16 00:25:00
131	2026-10-01	million	1	Rising	100.00	2026-10-16 00:25:00
132	2026-10-01	minh	4	Rising	100.00	2026-10-16 00:25:00
133	2026-10-01	minh city	2	Rising	100.00	2026-10-16 00:25:00
717	2026-10-01	muhammad	1	Rising	100.00	2026-10-16 00:25:00
718	2026-10-01	muhammad ali	1	Rising	100.00	2026-10-16 00:25:00
136	2026-10-01	myanmar	2	Rising	100.00	2026-10-16 00:25:00
137	2026-10-01	narrative	1	Rising	100.00	2026-10-16 00:25:00
138	2026-10-01	need	2	Rising	100.00	2026-10-16 00:25:00
140	2026-10-01	offers	1	Rising	100.00	2026-10-16 00:25:00
141	2026-10-01	office	2	Rising	100.00	2026-10-16 00:25:00
142	2026-10-01	old	1	Rising	100.00	2026-10-16 00:25:00
725	2026-10-01	open	1	Rising	100.00	2026-10-16 00:25:00
143	2026-10-01	opened	1	Rising	100.00	2026-10-16 00:25:00
727	2026-10-01	option	2	Rising	100.00	2026-10-16 00:25:00
728	2026-10-01	organization	1	Rising	100.00	2026-10-16 00:25:00
146	2026-10-01	pakistan	2	Stable	0.00	2026-10-16 00:25:00
147	2026-10-01	pandora	4	Stable	0.00	2026-10-16 00:25:00
731	2026-10-01	pandora opens	2	Stable	0.00	2026-10-16 00:25:00
150	2026-10-01	path	1	Rising	100.00	2026-10-16 00:25:00
152	2026-10-01	peace	1	Rising	100.00	2026-10-16 00:25:00
734	2026-10-01	pentagon	1	Rising	100.00	2026-10-16 00:25:00
153	2026-10-01	people	1	Rising	100.00	2026-10-16 00:25:00
155	2026-10-01	places	2	Rising	100.00	2026-10-16 00:25:00
156	2026-10-01	plans	1	Rising	100.00	2026-10-16 00:25:00
157	2026-10-01	plant	2	Rising	100.00	2026-10-16 00:25:00
158	2026-10-01	plus	2	Stable	0.00	2026-10-16 00:25:00
160	2026-10-01	post	1	Rising	100.00	2026-10-16 00:25:00
161	2026-10-01	powered	2	Rising	100.00	2026-10-16 00:25:00
162	2026-10-01	president	1	Rising	100.00	2026-10-16 00:25:00
163	2026-10-01	production	2	Rising	100.00	2026-10-16 00:25:00
164	2026-10-01	project	2	Stable	0.00	2026-10-16 00:25:00
745	2026-10-01	questions	1	Rising	100.00	2026-10-16 00:25:00
165	2026-10-01	read	2	Rising	100.00	2026-10-16 00:25:00
166	2026-10-01	real	1	Rising	100.00	2026-10-16 00:25:00
748	2026-10-01	released	1	Rising	100.00	2026-10-16 00:25:00
169	2026-10-01	renewable	2	Stable	0.00	2026-10-16 00:25:00
172	2026-10-01	retail	2	Stable	0.00	2026-10-16 00:25:00
173	2026-10-01	revenue	1	Rising	100.00	2026-10-16 00:25:00
174	2026-10-01	review	1	Rising	100.00	2026-10-16 00:25:00
753	2026-10-01	reviews	1	Rising	100.00	2026-10-16 00:25:00
176	2026-10-01	rice	1	Stable	0.00	2026-10-16 00:25:00
177	2026-10-01	right	1	Rising	100.00	2026-10-16 00:25:00
756	2026-10-01	rising	1	Rising	100.00	2026-10-16 00:25:00
757	2026-10-01	rules	1	Rising	100.00	2026-10-16 00:25:00
178	2026-10-01	sailing	1	Stable	0.00	2026-10-16 00:25:00
759	2026-10-01	san francisco	1	Rising	100.00	2026-10-16 00:25:00
179	2026-10-01	school	1	Stable	0.00	2026-10-16 00:25:00
180	2026-10-01	secretary	1	Rising	100.00	2026-10-16 00:25:00
181	2026-10-01	secured	1	Stable	0.00	2026-10-16 00:25:00
182	2026-10-01	security	1	Rising	100.00	2026-10-16 00:25:00
183	2026-10-01	sepaktakraw	1	Stable	0.00	2026-10-16 00:25:00
184	2026-10-01	september	1	Rising	100.00	2026-10-16 00:25:00
186	2026-10-01	seven	2	Stable	0.00	2026-10-16 00:25:00
767	2026-10-01	seven asian	1	Rising	100.00	2026-10-16 00:25:00
187	2026-10-01	shaped	1	Rising	100.00	2026-10-16 00:25:00
188	2026-10-01	sign	1	Rising	100.00	2026-10-16 00:25:00
189	2026-10-01	silver	2	Stable	0.00	2026-10-16 00:25:00
192	2026-10-01	social	2	Rising	100.00	2026-10-16 00:25:00
193	2026-10-01	social media	1	Rising	100.00	2026-10-16 00:25:00
194	2026-10-01	sports	1	Rising	100.00	2026-10-16 00:25:00
196	2026-10-01	strategic	1	Rising	100.00	2026-10-16 00:25:00
198	2026-10-01	summit	1	Rising	100.00	2026-10-16 00:25:00
776	2026-10-01	supply	1	Rising	100.00	2026-10-16 00:25:00
199	2026-10-01	tax	1	Rising	100.00	2026-10-16 00:25:00
778	2026-10-01	team	1	Rising	100.00	2026-10-16 00:25:00
779	2026-10-01	trillion	1	Rising	100.00	2026-10-16 00:25:00
204	2026-10-01	trump	2	Rising	100.00	2026-10-16 00:25:00
206	2026-10-01	visa	1	Rising	100.00	2026-10-16 00:25:00
207	2026-10-01	visa advantage	2	Stable	0.00	2026-10-16 00:25:00
208	2026-10-01	volleyball	2	Stable	0.00	2026-10-16 00:25:00
209	2026-10-01	war	2	Rising	100.00	2026-10-16 00:25:00
210	2026-10-01	warfare	1	Rising	100.00	2026-10-16 00:25:00
786	2026-10-01	wednesday	2	Stable	0.00	2026-10-16 00:25:00
211	2026-10-01	weeks	2	Rising	100.00	2026-10-16 00:25:00
212	2026-10-01	wild	2	Rising	100.00	2026-10-16 00:25:00
789	2026-10-01	woman	1	Rising	100.00	2026-10-16 00:25:00
790	2026-10-01	women	1	Rising	100.00	2026-10-16 00:25:00
213	2026-10-01	world	1	Rising	100.00	2026-10-16 00:25:00
792	2026-10-01	wrestling	1	Rising	100.00	2026-10-16 00:25:00
793	2026-10-01	york	1	Rising	100.00	2026-10-16 00:25:00
794	2026-10-11	asia pacific	1	Rising	100.00	2026-10-16 00:25:00
216	2026-10-11	availability	3	Rising	100.00	2026-10-16 00:25:00
796	2026-10-11	ban	1	Rising	100.00	2026-10-16 00:25:00
218	2026-10-11	best	1	Rising	100.00	2026-10-16 00:25:00
219	2026-10-11	chicago	1	Rising	100.00	2026-10-16 00:25:00
220	2026-10-11	chinese	1	Rising	100.00	2026-10-16 00:25:00
800	2026-10-11	close	1	Rising	100.00	2026-10-16 00:25:00
221	2026-10-11	content	1	Rising	100.00	2026-10-16 00:25:00
802	2026-10-11	creation	1	Rising	100.00	2026-10-16 00:25:00
223	2026-10-11	date	3	Rising	100.00	2026-10-16 00:25:00
804	2026-10-11	department	1	Rising	100.00	2026-10-16 00:25:00
805	2026-10-11	devices	1	Rising	100.00	2026-10-16 00:25:00
224	2026-10-11	directed	2	Rising	100.00	2026-10-16 00:25:00
225	2026-10-11	electronics	1	Rising	100.00	2026-10-16 00:25:00
227	2026-10-11	film	2	Rising	100.00	2026-10-16 00:25:00
809	2026-10-11	finds	1	Rising	100.00	2026-10-16 00:25:00
228	2026-10-11	form	1	Rising	100.00	2026-10-16 00:25:00
811	2026-10-11	genesis	1	Rising	100.00	2026-10-16 00:25:00
812	2026-10-11	god	1	Rising	100.00	2026-10-16 00:25:00
229	2026-10-11	god creation	1	Rising	100.00	2026-10-16 00:25:00
814	2026-10-11	goes	1	Rising	100.00	2026-10-16 00:25:00
230	2026-10-11	half	1	Rising	100.00	2026-10-16 00:25:00
231	2026-10-11	including	1	Rising	100.00	2026-10-16 00:25:00
232	2026-10-11	income	1	Rising	100.00	2026-10-16 00:25:00
233	2026-10-11	king	1	Rising	100.00	2026-10-16 00:25:00
819	2026-10-11	like	1	Rising	100.00	2026-10-16 00:25:00
235	2026-10-11	links	1	Rising	100.00	2026-10-16 00:25:00
236	2026-10-11	major	1	Rising	100.00	2026-10-16 00:25:00
238	2026-10-11	miles	1	Rising	100.00	2026-10-16 00:25:00
239	2026-10-11	nearly	1	Rising	100.00	2026-10-16 00:25:00
240	2026-10-11	october	1	Rising	100.00	2026-10-16 00:25:00
241	2026-10-11	opened	1	Rising	100.00	2026-10-16 00:25:00
826	2026-10-11	pilot	1	Rising	100.00	2026-10-16 00:25:00
827	2026-10-11	point	1	Rising	100.00	2026-10-16 00:25:00
246	2026-10-11	returned	1	Rising	100.00	2026-10-16 00:25:00
247	2026-10-11	rising	1	Rising	100.00	2026-10-16 00:25:00
830	2026-10-11	sale nangsample	2	Rising	100.00	2026-10-16 00:25:00
249	2026-10-11	state	1	Rising	100.00	2026-10-16 00:25:00
250	2026-10-11	tax	1	Rising	100.00	2026-10-16 00:25:00
251	2026-10-11	testing	1	Rising	100.00	2026-10-16 00:25:00
253	2026-10-11	travel	3	Rising	100.00	2026-10-16 00:25:00
254	2026-10-11	travel date	3	Rising	100.00	2026-10-16 00:25:00
836	2026-10-11	turned	1	Rising	100.00	2026-10-16 00:25:00
837	2026-10-11	using	1	Rising	100.00	2026-10-16 00:25:00
257	2026-10-11	visa	1	Rising	100.00	2026-10-16 00:25:00
259	2026-10-12	agency	1	Rising	100.00	2026-10-16 00:25:00
260	2026-10-12	allegedly	1	Rising	100.00	2026-10-16 00:25:00
262	2026-10-12	american	1	Rising	100.00	2026-10-16 00:25:00
265	2026-10-12	appeared	1	Rising	100.00	2026-10-16 00:25:00
266	2026-10-12	armed	2	Rising	100.00	2026-10-16 00:25:00
267	2026-10-12	armed ground	1	Rising	100.00	2026-10-16 00:25:00
845	2026-10-12	asia pacific	1	Rising	100.00	2026-10-16 00:25:00
268	2026-10-12	award	1	Rising	100.00	2026-10-16 00:25:00
269	2026-10-12	awards	1	Rising	100.00	2026-10-16 00:25:00
273	2026-10-12	bank	1	Rising	100.00	2026-10-16 00:25:00
849	2026-10-12	beach	1	Rising	100.00	2026-10-16 00:25:00
275	2026-10-12	best	1	Rising	100.00	2026-10-16 00:25:00
851	2026-10-12	biggest	1	Rising	100.00	2026-10-16 00:25:00
276	2026-10-12	billion	2	Rising	100.00	2026-10-16 00:25:00
279	2026-10-12	build	1	Rising	100.00	2026-10-16 00:25:00
280	2026-10-12	business	1	Rising	100.00	2026-10-16 00:25:00
281	2026-10-12	california	1	Rising	100.00	2026-10-16 00:25:00
856	2026-10-12	change	1	Rising	100.00	2026-10-16 00:25:00
283	2026-10-12	circle	1	Rising	100.00	2026-10-16 00:25:00
284	2026-10-12	cloud	1	Rising	100.00	2026-10-16 00:25:00
859	2026-10-12	country	1	Rising	100.00	2026-10-16 00:25:00
860	2026-10-12	created	1	Rising	100.00	2026-10-16 00:25:00
286	2026-10-12	creation	1	Rising	100.00	2026-10-16 00:25:00
287	2026-10-12	crowd	2	Rising	100.00	2026-10-16 00:25:00
863	2026-10-12	deal	1	Rising	100.00	2026-10-16 00:25:00
289	2026-10-12	december	1	Rising	100.00	2026-10-16 00:25:00
291	2026-10-12	development	1	Rising	100.00	2026-10-16 00:25:00
866	2026-10-12	didn	1	Rising	100.00	2026-10-16 00:25:00
867	2026-10-12	digital	1	Rising	100.00	2026-10-16 00:25:00
868	2026-10-12	doc	1	Rising	100.00	2026-10-16 00:25:00
869	2026-10-12	domestic	1	Rising	100.00	2026-10-16 00:25:00
292	2026-10-12	economic	1	Rising	100.00	2026-10-16 00:25:00
871	2026-10-12	edition	1	Rising	100.00	2026-10-16 00:25:00
294	2026-10-12	emerging	1	Rising	100.00	2026-10-16 00:25:00
873	2026-10-12	end	1	Rising	100.00	2026-10-16 00:25:00
298	2026-10-12	film	1	Rising	100.00	2026-10-16 00:25:00
875	2026-10-12	fish	1	Rising	100.00	2026-10-16 00:25:00
300	2026-10-12	flight	2	Rising	100.00	2026-10-16 00:25:00
301	2026-10-12	flights	2	Rising	100.00	2026-10-16 00:25:00
302	2026-10-12	focus	2	Rising	100.00	2026-10-16 00:25:00
303	2026-10-12	foreign	1	Rising	100.00	2026-10-16 00:25:00
880	2026-10-12	form	1	Rising	100.00	2026-10-16 00:25:00
881	2026-10-12	fortune	1	Rising	100.00	2026-10-16 00:25:00
882	2026-10-12	francisco	1	Rising	100.00	2026-10-16 00:25:00
883	2026-10-12	friday	1	Rising	100.00	2026-10-16 00:25:00
304	2026-10-12	fuel	1	Rising	100.00	2026-10-16 00:25:00
305	2026-10-12	future	1	Rising	100.00	2026-10-16 00:25:00
306	2026-10-12	garlic	1	Rising	100.00	2026-10-16 00:25:00
307	2026-10-12	global	3	Rising	100.00	2026-10-16 00:25:00
308	2026-10-12	global poverty	2	Rising	100.00	2026-10-16 00:25:00
889	2026-10-12	good	1	Rising	100.00	2026-10-16 00:25:00
309	2026-10-12	great	1	Rising	100.00	2026-10-16 00:25:00
310	2026-10-12	ground	1	Rising	100.00	2026-10-16 00:25:00
311	2026-10-12	ground based	1	Rising	100.00	2026-10-16 00:25:00
312	2026-10-12	group	1	Rising	100.00	2026-10-16 00:25:00
313	2026-10-12	half	1	Rising	100.00	2026-10-16 00:25:00
314	2026-10-12	hasan	2	Rising	100.00	2026-10-16 00:25:00
315	2026-10-12	hasan piker	2	Rising	100.00	2026-10-16 00:25:00
897	2026-10-12	help	1	Rising	100.00	2026-10-16 00:25:00
316	2026-10-12	highlighted	1	Rising	100.00	2026-10-16 00:25:00
899	2026-10-12	highlights	1	Rising	100.00	2026-10-16 00:25:00
900	2026-10-12	home	1	Rising	100.00	2026-10-16 00:25:00
317	2026-10-12	horror	1	Rising	100.00	2026-10-16 00:25:00
318	2026-10-12	hotel	1	Rising	100.00	2026-10-16 00:25:00
319	2026-10-12	house	1	Rising	100.00	2026-10-16 00:25:00
320	2026-10-12	idaho	1	Rising	100.00	2026-10-16 00:25:00
321	2026-10-12	idaho voters	1	Rising	100.00	2026-10-16 00:25:00
322	2026-10-12	index	1	Rising	100.00	2026-10-16 00:25:00
323	2026-10-12	india	1	Rising	100.00	2026-10-16 00:25:00
324	2026-10-12	india emerging	1	Rising	100.00	2026-10-16 00:25:00
909	2026-10-12	indonesia	1	Rising	100.00	2026-10-16 00:25:00
325	2026-10-12	industrial	1	Rising	100.00	2026-10-16 00:25:00
326	2026-10-12	influencer	1	Rising	100.00	2026-10-16 00:25:00
327	2026-10-12	infrastructure	1	Rising	100.00	2026-10-16 00:25:00
328	2026-10-12	inner	1	Rising	100.00	2026-10-16 00:25:00
329	2026-10-12	inner circle	1	Rising	100.00	2026-10-16 00:25:00
330	2026-10-12	interview	2	Rising	100.00	2026-10-16 00:25:00
916	2026-10-12	iran	1	Rising	100.00	2026-10-16 00:25:00
332	2026-10-12	japan	1	Rising	100.00	2026-10-16 00:25:00
333	2026-10-12	kromadit	2	Rising	100.00	2026-10-16 00:25:00
335	2026-10-12	laos	2	Rising	100.00	2026-10-16 00:25:00
337	2026-10-12	liquid	1	Rising	100.00	2026-10-16 00:25:00
338	2026-10-12	list	2	Rising	100.00	2026-10-16 00:25:00
339	2026-10-12	live	1	Rising	100.00	2026-10-16 00:25:00
343	2026-10-12	make	1	Rising	100.00	2026-10-16 00:25:00
344	2026-10-12	managing	1	Rising	100.00	2026-10-16 00:25:00
925	2026-10-12	maritime	1	Rising	100.00	2026-10-16 00:25:00
345	2026-10-12	markets	2	Rising	100.00	2026-10-16 00:25:00
927	2026-10-12	marks	1	Rising	100.00	2026-10-16 00:25:00
346	2026-10-12	media	1	Rising	100.00	2026-10-16 00:25:00
349	2026-10-12	middle east	1	Rising	100.00	2026-10-16 00:25:00
350	2026-10-12	miles	1	Rising	100.00	2026-10-16 00:25:00
931	2026-10-12	minister	1	Rising	100.00	2026-10-16 00:25:00
351	2026-10-12	myanmar	1	Rising	100.00	2026-10-16 00:25:00
352	2026-10-12	narrative	1	Rising	100.00	2026-10-16 00:25:00
934	2026-10-12	october	1	Rising	100.00	2026-10-16 00:25:00
355	2026-10-12	offers	1	Rising	100.00	2026-10-16 00:25:00
356	2026-10-12	office	1	Rising	100.00	2026-10-16 00:25:00
357	2026-10-12	oji	1	Rising	100.00	2026-10-16 00:25:00
358	2026-10-12	old	3	Rising	100.00	2026-10-16 00:25:00
360	2026-10-12	past	1	Rising	100.00	2026-10-16 00:25:00
361	2026-10-12	people	1	Rising	100.00	2026-10-16 00:25:00
364	2026-10-12	piker	2	Rising	100.00	2026-10-16 00:25:00
366	2026-10-12	places	1	Rising	100.00	2026-10-16 00:25:00
367	2026-10-12	plans	1	Rising	100.00	2026-10-16 00:25:00
368	2026-10-12	plant	1	Rising	100.00	2026-10-16 00:25:00
369	2026-10-12	point	1	Rising	100.00	2026-10-16 00:25:00
370	2026-10-12	policy	1	Rising	100.00	2026-10-16 00:25:00
371	2026-10-12	post	1	Rising	100.00	2026-10-16 00:25:00
372	2026-10-12	poverty	2	Rising	100.00	2026-10-16 00:25:00
373	2026-10-12	president	1	Rising	100.00	2026-10-16 00:25:00
950	2026-10-12	proposed	1	Rising	100.00	2026-10-16 00:25:00
375	2026-10-12	read	1	Rising	100.00	2026-10-16 00:25:00
377	2026-10-12	record	1	Rising	100.00	2026-10-16 00:25:00
378	2026-10-12	regional	1	Rising	100.00	2026-10-16 00:25:00
954	2026-10-12	released	1	Rising	100.00	2026-10-16 00:25:00
955	2026-10-12	remains	1	Rising	100.00	2026-10-16 00:25:00
380	2026-10-12	right	2	Rising	100.00	2026-10-16 00:25:00
381	2026-10-12	rinrada	1	Rising	100.00	2026-10-16 00:25:00
382	2026-10-12	rises	1	Rising	100.00	2026-10-16 00:25:00
959	2026-10-12	rules	1	Rising	100.00	2026-10-16 00:25:00
960	2026-10-12	russia	1	Rising	100.00	2026-10-16 00:25:00
383	2026-10-12	samsung	1	Rising	100.00	2026-10-16 00:25:00
384	2026-10-12	samsung affiliates	2	Rising	100.00	2026-10-16 00:25:00
385	2026-10-12	san	1	Rising	100.00	2026-10-16 00:25:00
964	2026-10-12	san francisco	1	Rising	100.00	2026-10-16 00:25:00
386	2026-10-12	sea	2	Rising	100.00	2026-10-16 00:25:00
387	2026-10-12	season	1	Rising	100.00	2026-10-16 00:25:00
388	2026-10-12	seeks	1	Rising	100.00	2026-10-16 00:25:00
389	2026-10-12	semiconductor	2	Rising	100.00	2026-10-16 00:25:00
390	2026-10-12	semiconductor operations	2	Rising	100.00	2026-10-16 00:25:00
970	2026-10-12	series	1	Rising	100.00	2026-10-16 00:25:00
391	2026-10-12	service	1	Rising	100.00	2026-10-16 00:25:00
393	2026-10-12	shooting	1	Rising	100.00	2026-10-16 00:25:00
394	2026-10-12	shooting teenagers	1	Rising	100.00	2026-10-16 00:25:00
395	2026-10-12	social	1	Rising	100.00	2026-10-16 00:25:00
396	2026-10-12	social media	1	Rising	100.00	2026-10-16 00:25:00
976	2026-10-12	southeast asia	1	Rising	100.00	2026-10-16 00:25:00
398	2026-10-12	state	1	Rising	100.00	2026-10-16 00:25:00
399	2026-10-12	states	1	Rising	100.00	2026-10-16 00:25:00
979	2026-10-12	stories	1	Rising	100.00	2026-10-16 00:25:00
400	2026-10-12	strategic	1	Rising	100.00	2026-10-16 00:25:00
401	2026-10-12	team	1	Rising	100.00	2026-10-16 00:25:00
402	2026-10-12	technology	2	Rising	100.00	2026-10-16 00:25:00
404	2026-10-12	testing	1	Rising	100.00	2026-10-16 00:25:00
984	2026-10-12	thai	1	Rising	100.00	2026-10-16 00:25:00
405	2026-10-12	thailand	1	Rising	100.00	2026-10-16 00:25:00
986	2026-10-12	travel	1	Rising	100.00	2026-10-16 00:25:00
987	2026-10-12	trump	1	Rising	100.00	2026-10-16 00:25:00
988	2026-10-12	turned	1	Rising	100.00	2026-10-16 00:25:00
408	2026-10-12	united	1	Rising	100.00	2026-10-16 00:25:00
990	2026-10-12	usd	1	Rising	100.00	2026-10-16 00:25:00
410	2026-10-12	vikrom	2	Rising	100.00	2026-10-16 00:25:00
411	2026-10-12	vikrom kromadit	2	Rising	100.00	2026-10-16 00:25:00
412	2026-10-12	voters	1	Rising	100.00	2026-10-16 00:25:00
414	2026-10-12	weeks	1	Rising	100.00	2026-10-16 00:25:00
995	2026-10-12	wild	1	Rising	100.00	2026-10-16 00:25:00
416	2026-10-13	american	1	Rising	100.00	2026-10-16 00:25:00
417	2026-10-13	andaman	1	Rising	100.00	2026-10-16 00:25:00
418	2026-10-13	armed	1	Rising	100.00	2026-10-16 00:25:00
999	2026-10-13	asks	1	Rising	100.00	2026-10-16 00:25:00
1000	2026-10-13	association	1	Rising	100.00	2026-10-16 00:25:00
420	2026-10-13	australia	2	Rising	100.00	2026-10-16 00:25:00
421	2026-10-13	awards	1	Rising	100.00	2026-10-16 00:25:00
422	2026-10-13	ban	1	Rising	100.00	2026-10-16 00:25:00
1004	2026-10-13	based	1	Rising	100.00	2026-10-16 00:25:00
427	2026-10-13	business	1	Rising	100.00	2026-10-16 00:25:00
431	2026-10-13	center	1	Rising	100.00	2026-10-16 00:25:00
432	2026-10-13	change	1	Rising	100.00	2026-10-16 00:25:00
433	2026-10-13	chicago	1	Rising	100.00	2026-10-16 00:25:00
434	2026-10-13	chicago police	1	Rising	100.00	2026-10-16 00:25:00
435	2026-10-13	chief	1	Rising	100.00	2026-10-16 00:25:00
436	2026-10-13	chinese	1	Rising	100.00	2026-10-16 00:25:00
437	2026-10-13	circle	1	Rising	100.00	2026-10-16 00:25:00
438	2026-10-13	closed	1	Rising	100.00	2026-10-16 00:25:00
439	2026-10-13	cloud	1	Rising	100.00	2026-10-16 00:25:00
443	2026-10-13	countries	1	Rising	100.00	2026-10-16 00:25:00
444	2026-10-13	country	2	Rising	100.00	2026-10-16 00:25:00
445	2026-10-13	crime	1	Rising	100.00	2026-10-16 00:25:00
1018	2026-10-13	crystal	2	Rising	100.00	2026-10-16 00:25:00
1019	2026-10-13	crystal lake	2	Rising	100.00	2026-10-16 00:25:00
446	2026-10-13	data	1	Rising	100.00	2026-10-16 00:25:00
448	2026-10-13	demand	1	Rising	100.00	2026-10-16 00:25:00
1022	2026-10-13	department	1	Rising	100.00	2026-10-16 00:25:00
451	2026-10-13	does	1	Rising	100.00	2026-10-16 00:25:00
452	2026-10-13	doesn	1	Rising	100.00	2026-10-16 00:25:00
453	2026-10-13	draft	2	Rising	100.00	2026-10-16 00:25:00
454	2026-10-13	east	1	Rising	100.00	2026-10-16 00:25:00
455	2026-10-13	economic	1	Rising	100.00	2026-10-16 00:25:00
1028	2026-10-13	episode	1	Rising	100.00	2026-10-16 00:25:00
459	2026-10-13	europe	3	Rising	100.00	2026-10-16 00:25:00
1030	2026-10-13	exclusive	1	Rising	100.00	2026-10-16 00:25:00
462	2026-10-13	export	1	Rising	100.00	2026-10-16 00:25:00
463	2026-10-13	factory	1	Rising	100.00	2026-10-16 00:25:00
467	2026-10-13	flight	1	Rising	100.00	2026-10-16 00:25:00
469	2026-10-13	form	1	Rising	100.00	2026-10-16 00:25:00
470	2026-10-13	free	1	Rising	100.00	2026-10-16 00:25:00
471	2026-10-13	free trade	2	Rising	100.00	2026-10-16 00:25:00
472	2026-10-13	friday	1	Rising	100.00	2026-10-16 00:25:00
1038	2026-10-13	global	2	Rising	100.00	2026-10-16 00:25:00
473	2026-10-13	great	1	Rising	100.00	2026-10-16 00:25:00
474	2026-10-13	harold	1	Rising	100.00	2026-10-16 00:25:00
1041	2026-10-13	hdtv	1	Rising	100.00	2026-10-16 00:25:00
475	2026-10-13	help	1	Rising	100.00	2026-10-16 00:25:00
476	2026-10-13	history	1	Rising	100.00	2026-10-16 00:25:00
1044	2026-10-13	holiday	1	Rising	100.00	2026-10-16 00:25:00
1045	2026-10-13	hong kong	1	Rising	100.00	2026-10-16 00:25:00
477	2026-10-13	hopes	1	Rising	100.00	2026-10-16 00:25:00
1047	2026-10-13	hotels	1	Rising	100.00	2026-10-16 00:25:00
1048	2026-10-13	house	1	Rising	100.00	2026-10-16 00:25:00
478	2026-10-13	illegal	1	Rising	100.00	2026-10-16 00:25:00
479	2026-10-13	illegal ivory	1	Rising	100.00	2026-10-16 00:25:00
480	2026-10-13	imports	1	Rising	100.00	2026-10-16 00:25:00
481	2026-10-13	income	1	Rising	100.00	2026-10-16 00:25:00
482	2026-10-13	india	3	Rising	100.00	2026-10-16 00:25:00
483	2026-10-13	indian	1	Rising	100.00	2026-10-16 00:25:00
484	2026-10-13	indo	1	Rising	100.00	2026-10-16 00:25:00
485	2026-10-13	indo pacific	2	Rising	100.00	2026-10-16 00:25:00
486	2026-10-13	industry	1	Rising	100.00	2026-10-16 00:25:00
487	2026-10-13	infrastructure	1	Rising	100.00	2026-10-16 00:25:00
488	2026-10-13	inner	1	Rising	100.00	2026-10-16 00:25:00
489	2026-10-13	inner circle	1	Rising	100.00	2026-10-16 00:25:00
1061	2026-10-13	international	1	Rising	100.00	2026-10-16 00:25:00
491	2026-10-13	island	2	Rising	100.00	2026-10-16 00:25:00
493	2026-10-13	ivory	1	Rising	100.00	2026-10-16 00:25:00
494	2026-10-13	japan	2	Rising	100.00	2026-10-16 00:25:00
1065	2026-10-13	key	1	Rising	100.00	2026-10-16 00:25:00
496	2026-10-13	king	1	Rising	100.00	2026-10-16 00:25:00
1067	2026-10-13	kong	1	Rising	100.00	2026-10-16 00:25:00
497	2026-10-13	kumar	1	Rising	100.00	2026-10-16 00:25:00
501	2026-10-13	learned	1	Rising	100.00	2026-10-16 00:25:00
1070	2026-10-13	learning library	2	Rising	100.00	2026-10-16 00:25:00
1071	2026-10-13	ledger	1	Rising	100.00	2026-10-16 00:25:00
1072	2026-10-13	library built	2	Rising	100.00	2026-10-16 00:25:00
1073	2026-10-13	life	1	Rising	100.00	2026-10-16 00:25:00
506	2026-10-13	liquid	1	Rising	100.00	2026-10-16 00:25:00
1075	2026-10-13	machine	2	Rising	100.00	2026-10-16 00:25:00
508	2026-10-13	manufacturing	1	Rising	100.00	2026-10-16 00:25:00
509	2026-10-13	maritime	2	Rising	100.00	2026-10-16 00:25:00
510	2026-10-13	market	1	Rising	100.00	2026-10-16 00:25:00
1079	2026-10-13	measures	1	Rising	100.00	2026-10-16 00:25:00
511	2026-10-13	media	1	Rising	100.00	2026-10-16 00:25:00
514	2026-10-13	middle	2	Rising	100.00	2026-10-16 00:25:00
515	2026-10-13	middle east	1	Rising	100.00	2026-10-16 00:25:00
516	2026-10-13	miles	1	Rising	100.00	2026-10-16 00:25:00
517	2026-10-13	military	1	Rising	100.00	2026-10-16 00:25:00
518	2026-10-13	milk	1	Rising	100.00	2026-10-16 00:25:00
519	2026-10-13	million	2	Rising	100.00	2026-10-16 00:25:00
521	2026-10-13	nearly	2	Rising	100.00	2026-10-16 00:25:00
522	2026-10-13	needs	2	Rising	100.00	2026-10-16 00:25:00
523	2026-10-13	night	2	Rising	100.00	2026-10-16 00:25:00
1090	2026-10-13	north	1	Rising	100.00	2026-10-16 00:25:00
1091	2026-10-13	oct prnewswire	2	Rising	100.00	2026-10-16 00:25:00
524	2026-10-13	october	1	Rising	100.00	2026-10-16 00:25:00
525	2026-10-13	old	1	Rising	100.00	2026-10-16 00:25:00
1094	2026-10-13	opens	1	Rising	100.00	2026-10-16 00:25:00
1095	2026-10-13	option	1	Rising	100.00	2026-10-16 00:25:00
1096	2026-10-13	organization	1	Rising	100.00	2026-10-16 00:25:00
1097	2026-10-13	pacific	1	Rising	100.00	2026-10-16 00:25:00
527	2026-10-13	past	1	Rising	100.00	2026-10-16 00:25:00
528	2026-10-13	path	1	Rising	100.00	2026-10-16 00:25:00
532	2026-10-13	police	1	Rising	100.00	2026-10-16 00:25:00
1101	2026-10-13	policy	2	Rising	100.00	2026-10-16 00:25:00
535	2026-10-13	power	2	Rising	100.00	2026-10-16 00:25:00
1103	2026-10-13	powered	1	Rising	100.00	2026-10-16 00:25:00
536	2026-10-13	president	1	Rising	100.00	2026-10-16 00:25:00
1105	2026-10-13	prnewswire	1	Rising	100.00	2026-10-16 00:25:00
537	2026-10-13	production	2	Rising	100.00	2026-10-16 00:25:00
1107	2026-10-13	purpose	2	Rising	100.00	2026-10-16 00:25:00
1108	2026-10-13	purpose hcmute	2	Rising	100.00	2026-10-16 00:25:00
1109	2026-10-13	read	2	Rising	100.00	2026-10-16 00:25:00
539	2026-10-13	real	1	Rising	100.00	2026-10-16 00:25:00
1111	2026-10-13	resellers	1	Rising	100.00	2026-10-16 00:25:00
1112	2026-10-13	return	2	Rising	100.00	2026-10-16 00:25:00
540	2026-10-13	returned	1	Rising	100.00	2026-10-16 00:25:00
541	2026-10-13	revenue	1	Rising	100.00	2026-10-16 00:25:00
1115	2026-10-13	review	1	Rising	100.00	2026-10-16 00:25:00
1116	2026-10-13	sales	1	Rising	100.00	2026-10-16 00:25:00
542	2026-10-13	samsung	1	Rising	100.00	2026-10-16 00:25:00
543	2026-10-13	samsung affiliates	1	Rising	100.00	2026-10-16 00:25:00
545	2026-10-13	sea	1	Rising	100.00	2026-10-16 00:25:00
546	2026-10-13	season	1	Rising	100.00	2026-10-16 00:25:00
1121	2026-10-13	season episode	1	Rising	100.00	2026-10-16 00:25:00
547	2026-10-13	security	1	Rising	100.00	2026-10-16 00:25:00
1123	2026-10-13	seeks	2	Rising	100.00	2026-10-16 00:25:00
1124	2026-10-13	semiconductor operations	1	Rising	100.00	2026-10-16 00:25:00
548	2026-10-13	september	1	Rising	100.00	2026-10-16 00:25:00
1126	2026-10-13	series	1	Rising	100.00	2026-10-16 00:25:00
549	2026-10-13	service	1	Rising	100.00	2026-10-16 00:25:00
550	2026-10-13	shaped	1	Rising	100.00	2026-10-16 00:25:00
1129	2026-10-13	shipments	1	Rising	100.00	2026-10-16 00:25:00
551	2026-10-13	sister	1	Rising	100.00	2026-10-16 00:25:00
1131	2026-10-13	south	1	Rising	100.00	2026-10-16 00:25:00
556	2026-10-13	southeast asian	1	Rising	100.00	2026-10-16 00:25:00
559	2026-10-13	state	1	Rising	100.00	2026-10-16 00:25:00
560	2026-10-13	states	1	Rising	100.00	2026-10-16 00:25:00
561	2026-10-13	steel	2	Rising	100.00	2026-10-16 00:25:00
563	2026-10-13	story	1	Rising	100.00	2026-10-16 00:25:00
567	2026-10-13	summit	1	Rising	100.00	2026-10-16 00:25:00
1138	2026-10-13	sunday	1	Rising	100.00	2026-10-16 00:25:00
568	2026-10-13	supply	2	Rising	100.00	2026-10-16 00:25:00
1140	2026-10-13	supply chain	2	Rising	100.00	2026-10-16 00:25:00
569	2026-10-13	taiwan	3	Rising	100.00	2026-10-16 00:25:00
570	2026-10-13	technology	1	Rising	100.00	2026-10-16 00:25:00
571	2026-10-13	thailand	1	Rising	100.00	2026-10-16 00:25:00
572	2026-10-13	trade	3	Rising	100.00	2026-10-16 00:25:00
1145	2026-10-13	trillion	1	Rising	100.00	2026-10-16 00:25:00
574	2026-10-13	trump	1	Rising	100.00	2026-10-16 00:25:00
575	2026-10-13	united	2	Rising	100.00	2026-10-16 00:25:00
1148	2026-10-13	united states	2	Rising	100.00	2026-10-16 00:25:00
577	2026-10-13	usd	1	Rising	100.00	2026-10-16 00:25:00
580	2026-10-13	victory	2	Rising	100.00	2026-10-16 00:25:00
1151	2026-10-13	volume	1	Rising	100.00	2026-10-16 00:25:00
581	2026-10-13	war	1	Rising	100.00	2026-10-16 00:25:00
582	2026-10-13	warfare	1	Rising	100.00	2026-10-16 00:25:00
583	2026-10-13	wild	1	Rising	100.00	2026-10-16 00:25:00
1155	2026-10-13	won	2	Rising	100.00	2026-10-16 00:25:00
584	2026-10-13	world	1	Rising	100.00	2026-10-16 00:25:00
585	2026-10-13	worth	2	Rising	100.00	2026-10-16 00:25:00
586	2026-10-13	wrestling	1	Rising	100.00	2026-10-16 00:25:00
1159	2026-10-14	advantage	1	Rising	100.00	2026-10-16 00:25:00
1160	2026-10-14	agency	1	Rising	100.00	2026-10-16 00:25:00
1161	2026-10-14	air	1	Rising	100.00	2026-10-16 00:25:00
1162	2026-10-14	ali	1	Rising	100.00	2026-10-16 00:25:00
1163	2026-10-14	alleged	1	Rising	100.00	2026-10-16 00:25:00
1164	2026-10-14	allegedly	1	Rising	100.00	2026-10-16 00:25:00
1165	2026-10-14	american	1	Rising	100.00	2026-10-16 00:25:00
1166	2026-10-14	anniversary	1	Rising	100.00	2026-10-16 00:25:00
1167	2026-10-14	appeared	1	Rising	100.00	2026-10-16 00:25:00
1168	2026-10-14	arrested	3	Rising	100.00	2026-10-16 00:25:00
1169	2026-10-14	asian markets	1	Rising	100.00	2026-10-16 00:25:00
1170	2026-10-14	asks	1	Rising	100.00	2026-10-16 00:25:00
1171	2026-10-14	august	1	Rising	100.00	2026-10-16 00:25:00
1172	2026-10-14	ava	1	Rising	100.00	2026-10-16 00:25:00
1173	2026-10-14	ava duvernay	1	Rising	100.00	2026-10-16 00:25:00
1174	2026-10-14	award	1	Rising	100.00	2026-10-16 00:25:00
1175	2026-10-14	awards	1	Rising	100.00	2026-10-16 00:25:00
1176	2026-10-14	based	1	Rising	100.00	2026-10-16 00:25:00
1177	2026-10-14	beach	1	Rising	100.00	2026-10-16 00:25:00
1178	2026-10-14	big	1	Rising	100.00	2026-10-16 00:25:00
1179	2026-10-14	box	2	Rising	100.00	2026-10-16 00:25:00
1180	2026-10-14	build	1	Rising	100.00	2026-10-16 00:25:00
1181	2026-10-14	california	1	Rising	100.00	2026-10-16 00:25:00
1182	2026-10-14	case	1	Rising	100.00	2026-10-16 00:25:00
1183	2026-10-14	ceo	1	Rising	100.00	2026-10-16 00:25:00
1184	2026-10-14	change	1	Rising	100.00	2026-10-16 00:25:00
1185	2026-10-14	changing	1	Rising	100.00	2026-10-16 00:25:00
1186	2026-10-14	chi	1	Rising	100.00	2026-10-16 00:25:00
1187	2026-10-14	chi minh	1	Rising	100.00	2026-10-16 00:25:00
1188	2026-10-14	city	1	Rising	100.00	2026-10-16 00:25:00
1189	2026-10-14	climate	2	Rising	100.00	2026-10-16 00:25:00
1190	2026-10-14	cloud	1	Rising	100.00	2026-10-16 00:25:00
1191	2026-10-14	colleague	2	Rising	100.00	2026-10-16 00:25:00
1192	2026-10-14	company	1	Rising	100.00	2026-10-16 00:25:00
1193	2026-10-14	costs	3	Rising	100.00	2026-10-16 00:25:00
1194	2026-10-14	countries	2	Rising	100.00	2026-10-16 00:25:00
1195	2026-10-14	created	1	Rising	100.00	2026-10-16 00:25:00
1196	2026-10-14	crypto	2	Rising	100.00	2026-10-16 00:25:00
1197	2026-10-14	days	2	Rising	100.00	2026-10-16 00:25:00
1198	2026-10-14	decades	2	Rising	100.00	2026-10-16 00:25:00
1199	2026-10-14	didn	1	Rising	100.00	2026-10-16 00:25:00
1200	2026-10-14	doc	1	Rising	100.00	2026-10-16 00:25:00
1201	2026-10-14	doc nyc	2	Rising	100.00	2026-10-16 00:25:00
1202	2026-10-14	doc stories	2	Rising	100.00	2026-10-16 00:25:00
1203	2026-10-14	duvernay	1	Rising	100.00	2026-10-16 00:25:00
1204	2026-10-14	emerging	1	Rising	100.00	2026-10-16 00:25:00
1205	2026-10-14	episode	1	Rising	100.00	2026-10-16 00:25:00
1206	2026-10-14	estate	2	Rising	100.00	2026-10-16 00:25:00
1207	2026-10-14	expand	2	Rising	100.00	2026-10-16 00:25:00
1208	2026-10-14	explores	1	Rising	100.00	2026-10-16 00:25:00
1209	2026-10-14	exports	1	Rising	100.00	2026-10-16 00:25:00
1210	2026-10-14	festival	1	Rising	100.00	2026-10-16 00:25:00
1211	2026-10-14	film	1	Rising	100.00	2026-10-16 00:25:00
1212	2026-10-14	film festival	1	Rising	100.00	2026-10-16 00:25:00
1213	2026-10-14	finds	2	Rising	100.00	2026-10-16 00:25:00
1214	2026-10-14	foreign	2	Rising	100.00	2026-10-16 00:25:00
1215	2026-10-14	fortune	1	Rising	100.00	2026-10-16 00:25:00
1216	2026-10-14	free	2	Rising	100.00	2026-10-16 00:25:00
1217	2026-10-14	free trade	1	Rising	100.00	2026-10-16 00:25:00
1218	2026-10-14	fuel	1	Rising	100.00	2026-10-16 00:25:00
1219	2026-10-14	global	3	Rising	100.00	2026-10-16 00:25:00
1220	2026-10-14	grad	3	Rising	100.00	2026-10-16 00:25:00
1221	2026-10-14	grad student	3	Rising	100.00	2026-10-16 00:25:00
1222	2026-10-14	greatest	3	Rising	100.00	2026-10-16 00:25:00
1223	2026-10-14	grenades	2	Rising	100.00	2026-10-16 00:25:00
1224	2026-10-14	group	1	Rising	100.00	2026-10-16 00:25:00
1225	2026-10-14	hanoi	2	Rising	100.00	2026-10-16 00:25:00
1226	2026-10-14	hardware	1	Rising	100.00	2026-10-16 00:25:00
1227	2026-10-14	hdtv	1	Rising	100.00	2026-10-16 00:25:00
1228	2026-10-14	head	2	Rising	100.00	2026-10-16 00:25:00
1229	2026-10-14	hegseth	1	Rising	100.00	2026-10-16 00:25:00
1230	2026-10-14	highlights	1	Rising	100.00	2026-10-16 00:25:00
1231	2026-10-14	holiday	1	Rising	100.00	2026-10-16 00:25:00
1232	2026-10-14	home	2	Rising	100.00	2026-10-16 00:25:00
1233	2026-10-14	hong	1	Rising	100.00	2026-10-16 00:25:00
1234	2026-10-14	hong kong	1	Rising	100.00	2026-10-16 00:25:00
1235	2026-10-14	hope	2	Rising	100.00	2026-10-16 00:25:00
1236	2026-10-14	htx	1	Rising	100.00	2026-10-16 00:25:00
1237	2026-10-14	image	2	Rising	100.00	2026-10-16 00:25:00
1238	2026-10-14	imports	1	Rising	100.00	2026-10-16 00:25:00
1239	2026-10-14	india	2	Rising	100.00	2026-10-16 00:25:00
1240	2026-10-14	indonesia	1	Rising	100.00	2026-10-16 00:25:00
1241	2026-10-14	intelligence	1	Rising	100.00	2026-10-16 00:25:00
1242	2026-10-14	invest	1	Rising	100.00	2026-10-16 00:25:00
1243	2026-10-14	iran	1	Rising	100.00	2026-10-16 00:25:00
1244	2026-10-14	iran war	1	Rising	100.00	2026-10-16 00:25:00
1245	2026-10-14	kong	2	Rising	100.00	2026-10-16 00:25:00
1246	2026-10-14	learning library	3	Rising	100.00	2026-10-16 00:25:00
1247	2026-10-14	led	2	Rising	100.00	2026-10-16 00:25:00
1248	2026-10-14	ledger	2	Rising	100.00	2026-10-16 00:25:00
1249	2026-10-14	library built	3	Rising	100.00	2026-10-16 00:25:00
1250	2026-10-14	life	1	Rising	100.00	2026-10-16 00:25:00
1251	2026-10-14	like	2	Rising	100.00	2026-10-16 00:25:00
1252	2026-10-14	list	1	Rising	100.00	2026-10-16 00:25:00
1253	2026-10-14	live	1	Rising	100.00	2026-10-16 00:25:00
1254	2026-10-14	long	1	Rising	100.00	2026-10-16 00:25:00
1255	2026-10-14	machine	3	Rising	100.00	2026-10-16 00:25:00
1256	2026-10-14	manufacturing	2	Rising	100.00	2026-10-16 00:25:00
1257	2026-10-14	measures	1	Rising	100.00	2026-10-16 00:25:00
1258	2026-10-14	minh	1	Rising	100.00	2026-10-16 00:25:00
1259	2026-10-14	minh city	1	Rising	100.00	2026-10-16 00:25:00
1260	2026-10-14	minister	1	Rising	100.00	2026-10-16 00:25:00
1261	2026-10-14	muhammad	2	Rising	100.00	2026-10-16 00:25:00
1262	2026-10-14	muhammad ali	2	Rising	100.00	2026-10-16 00:25:00
1263	2026-10-14	narrative	1	Rising	100.00	2026-10-16 00:25:00
1264	2026-10-14	nearly	3	Rising	100.00	2026-10-16 00:25:00
1265	2026-10-14	need	1	Rising	100.00	2026-10-16 00:25:00
1266	2026-10-14	needs	1	Rising	100.00	2026-10-16 00:25:00
1267	2026-10-14	north	1	Rising	100.00	2026-10-16 00:25:00
1268	2026-10-14	nyc	2	Rising	100.00	2026-10-16 00:25:00
1269	2026-10-14	officials	2	Rising	100.00	2026-10-16 00:25:00
1270	2026-10-14	open	1	Rising	100.00	2026-10-16 00:25:00
1271	2026-10-14	organization	1	Rising	100.00	2026-10-16 00:25:00
1272	2026-10-14	oritain	2	Rising	100.00	2026-10-16 00:25:00
1273	2026-10-14	past	1	Rising	100.00	2026-10-16 00:25:00
1274	2026-10-14	path	1	Rising	100.00	2026-10-16 00:25:00
1275	2026-10-14	peace	1	Rising	100.00	2026-10-16 00:25:00
1276	2026-10-14	pentagon	1	Rising	100.00	2026-10-16 00:25:00
1277	2026-10-14	people	1	Rising	100.00	2026-10-16 00:25:00
1278	2026-10-14	pilot	1	Rising	100.00	2026-10-16 00:25:00
1279	2026-10-14	police	1	Rising	100.00	2026-10-16 00:25:00
1280	2026-10-14	post	1	Rising	100.00	2026-10-16 00:25:00
1281	2026-10-14	power	1	Rising	100.00	2026-10-16 00:25:00
1282	2026-10-14	president	1	Rising	100.00	2026-10-16 00:25:00
1283	2026-10-14	prime	1	Rising	100.00	2026-10-16 00:25:00
1284	2026-10-14	prnewswire	1	Rising	100.00	2026-10-16 00:25:00
1285	2026-10-14	purpose	3	Rising	100.00	2026-10-16 00:25:00
1286	2026-10-14	purpose hcmute	3	Rising	100.00	2026-10-16 00:25:00
1287	2026-10-14	questions	2	Rising	100.00	2026-10-16 00:25:00
1288	2026-10-14	real	1	Rising	100.00	2026-10-16 00:25:00
1289	2026-10-14	record	2	Rising	100.00	2026-10-16 00:25:00
1290	2026-10-14	remains	2	Rising	100.00	2026-10-16 00:25:00
1291	2026-10-14	report	2	Rising	100.00	2026-10-16 00:25:00
1292	2026-10-14	resellers	1	Rising	100.00	2026-10-16 00:25:00
1293	2026-10-14	return	1	Rising	100.00	2026-10-16 00:25:00
1294	2026-10-14	returned	1	Rising	100.00	2026-10-16 00:25:00
1295	2026-10-14	reveals	2	Rising	100.00	2026-10-16 00:25:00
1296	2026-10-14	reviews	1	Rising	100.00	2026-10-16 00:25:00
1297	2026-10-14	rising	1	Rising	100.00	2026-10-16 00:25:00
1298	2026-10-14	rules	1	Rising	100.00	2026-10-16 00:25:00
1299	2026-10-14	russia	1	Rising	100.00	2026-10-16 00:25:00
1300	2026-10-14	sale	1	Rising	100.00	2026-10-16 00:25:00
1301	2026-10-14	sales	1	Rising	100.00	2026-10-16 00:25:00
1302	2026-10-14	samsung	1	Rising	100.00	2026-10-16 00:25:00
1303	2026-10-14	san	1	Rising	100.00	2026-10-16 00:25:00
1304	2026-10-14	saw	1	Rising	100.00	2026-10-16 00:25:00
1305	2026-10-14	season episode	2	Rising	100.00	2026-10-16 00:25:00
1306	2026-10-14	secretary	1	Rising	100.00	2026-10-16 00:25:00
1307	2026-10-14	september	1	Rising	100.00	2026-10-16 00:25:00
1308	2026-10-14	series	1	Rising	100.00	2026-10-16 00:25:00
1309	2026-10-14	service	1	Rising	100.00	2026-10-16 00:25:00
1310	2026-10-14	seven asian	1	Rising	100.00	2026-10-16 00:25:00
1311	2026-10-14	shaped	1	Rising	100.00	2026-10-16 00:25:00
1312	2026-10-14	shipments	2	Rising	100.00	2026-10-16 00:25:00
1313	2026-10-14	short	2	Rising	100.00	2026-10-16 00:25:00
1314	2026-10-14	short list	2	Rising	100.00	2026-10-16 00:25:00
1315	2026-10-14	sign	1	Rising	100.00	2026-10-16 00:25:00
1316	2026-10-14	southeast	1	Rising	100.00	2026-10-16 00:25:00
1317	2026-10-14	sports	1	Rising	100.00	2026-10-16 00:25:00
1318	2026-10-14	state	1	Rising	100.00	2026-10-16 00:25:00
1319	2026-10-14	states	1	Rising	100.00	2026-10-16 00:25:00
1320	2026-10-14	stories	2	Rising	100.00	2026-10-16 00:25:00
1321	2026-10-14	student	1	Rising	100.00	2026-10-16 00:25:00
1322	2026-10-14	summit	2	Rising	100.00	2026-10-16 00:25:00
1323	2026-10-14	sunday	1	Rising	100.00	2026-10-16 00:25:00
1324	2026-10-14	supplier	1	Rising	100.00	2026-10-16 00:25:00
1325	2026-10-14	supply chain	1	Rising	100.00	2026-10-16 00:25:00
1326	2026-10-14	trade	4	Rising	100.00	2026-10-16 00:25:00
1327	2026-10-14	travel	1	Rising	100.00	2026-10-16 00:25:00
1328	2026-10-14	trump	2	Rising	100.00	2026-10-16 00:25:00
1329	2026-10-14	united	1	Rising	100.00	2026-10-16 00:25:00
1330	2026-10-14	united states	1	Rising	100.00	2026-10-16 00:25:00
1331	2026-10-14	victory	1	Rising	100.00	2026-10-16 00:25:00
1332	2026-10-14	vietjet	1	Rising	100.00	2026-10-16 00:25:00
1333	2026-10-14	volume	2	Rising	100.00	2026-10-16 00:25:00
1334	2026-10-14	war	2	Rising	100.00	2026-10-16 00:25:00
1335	2026-10-14	woman	1	Rising	100.00	2026-10-16 00:25:00
1336	2026-10-14	women	1	Rising	100.00	2026-10-16 00:25:00
1337	2026-10-14	work	3	Rising	100.00	2026-10-16 00:25:00
1338	2026-10-14	world	1	Rising	100.00	2026-10-16 00:25:00
1339	2026-10-14	york	1	Rising	100.00	2026-10-16 00:25:00
\.


--
-- Data for Name: news_vietnam_articles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.news_vietnam_articles (id, title, description, content, url, source_name, author, published_at, collected_at, sentiment_label, sentiment_score, entities_org, entities_gpe, entities_person, vader_compound, vader_label, ensemble_sentiment_label, vietnam_relevance_score, is_vietnam_relevant, topic_label, topic_confidence, ai_summary, word_count, keywords, story_cluster_id) FROM stdin;
12	Nigeria@66: From resilience to enduring capability	On its 66th anniversary, an analysis of NigeriaΓÇÖs journey from resilience to the need for enduring institutional capability to match its abundant talent.\n\nRead More:	Today, October 1,┬á 2026, Nigeria turns 66.\r\nThat anniversary invites neither self-congratulation nor despair. Both are too easy.\r\nNigeria has survived civil war, military rule, commodity shocks, insuΓÇª	https://punchng.com/nigeria66-from-resilience-to-enduring-capability/	The Punch	Punch Newspapers	2026-10-01 04:34:48	2026-10-02 14:39:48	Positive	0.3583	[]	["Nigeria"]	[]	0.1994	Positive	Positive	0	0	Technology	0.3300	Nigeria@66: From resilience to enduring capability. On its 66th anniversary, an analysis of NigeriaΓÇÖs journey from resilience to the need for enduring institutional capability to match its abundant talent. Read More:	59	["anniversary", "need", "read"]	12
13	Pandora Opens $150 Million Vietnam Production┬áFacility	The plant near Ho Chi Minh City is the companyΓÇÖs first production site outside Thailand and can produce up to 60 million pieces a year at capacity.	PARIS ΓÇö Pandora is bolstering its production capability as it eyes renewed growth.\r\nThe Danish jewelry giant on Thursday inaugurated a new manufacturing facility in Vietnam, its largest to date and tΓÇª	http://wwd.com/accessories-news/jewelry/pandora-vietnam-new-production-facility-opening-150-million-1239289887/	WWD	Lily Templeton	2026-10-01 04:00:00	2026-10-02 14:39:48	Neutral	0.0973	[]	["Pandora", "Ho Chi Minh City", "Thailand", "Vietnam"]	[]	0.3818	Positive	Positive	6	1	Economy	0.6700	Pandora Opens $150 Million Vietnam Production Facility. The plant near Ho Chi Minh City is the companyΓÇÖs first production site outside Thailand and can produce up to 60 million pieces a year at capacity.	66	["production", "million", "plant", "pandora opens", "pandora"]	13
14	How not to make crime pay	By J.R. DunnThis is one case where the old ways are the best ways.	The record shows clearly enough that when liberal-leftists donΓÇÖt want to do something but have to do it anyway, they go to great lengths to make it so complex, so convoluted, and so nonsensical as toΓÇª	https://www.americanthinker.com/blog/2026/10/how-not-to-make-crime-pay/	Americanthinker.com		2026-10-01 04:00:00	2026-10-02 14:39:48	Positive	0.3200	[]	[]	["J.R. DunnThis"]	0.8995	Positive	Positive	0	0	General	0.0000	How not to make crime pay. By J.R. DunnThis is one case where the old ways are the best ways.	56	["crime", "case", "make", "old", "best"]	14
15	Vietnam extends fuel tax relief measures until end-2026	HANOI, Oct 1 : Vietnam is extending a package of fuel-tax relief measures to the end of 2026, after having introduced them earlier this year to help stabilise the domestic market amid supply concerns due to war in the Middle East.ΓÇó Extending the package wouldΓÇª	HANOI, Oct 1 : Vietnam is extending a package of fuel-tax relief measures to the end of 2026, after having introduced them earlier this year to help stabilise the domestic market amid supply concernsΓÇª	https://www.channelnewsasia.com/business/vietnam-extends-fuel-tax-relief-measures-until-end-2026-6423271	CNA		2026-10-01 03:22:49	2026-10-02 14:39:48	Neutral	-0.0208	[]	["Vietnam"]	[]	0.8834	Positive	Positive	9	1	Economy	1.0000	Vietnam extends fuel tax relief measures until end-2026.	87	["tax", "fuel", "end", "measures", "middle east"]	15
16	India's Asian Games Volleyball Medal Hopes Dashed By Pakistan	The Indian men's volleyball team's hopes of ending a 40-year medal drought at the Asian Games were crushed after a 0-3 defeat to arch-rivals Pakistan in the quarterfinals. India, despite an all-win record in the group stage, failed to secure a podium finish.	The Indian men's volleyball team's long-cherished dream of securing an Asian Games medal was shattered after a decisive 0-3 defeat against arch-rivals Pakistan in the quarterfinals, ending their imprΓÇª	https://www.rediff.com/sports/report/india-lose-to-pakistan-in-asian-games-volleyball-quarterfinals/20261001.htm	Rediff.com	sports@rediff.co.in (Rediff Sports Desk)	2026-10-01 03:09:31	2026-10-02 14:39:48	Neutral	-0.0333	["Asian Games Volleyball Medal Hopes Dashed"]	["India", "Pakistan"]	[]	0.7430	Positive	Positive	0	0	Society	0.2500	India's Asian Games Volleyball Medal Hopes Dashed By Pakistan. The Indian men's volleyball team's hopes of ending a 40-year medal drought at the Asian Games were crushed after a 0-3 defeat to arch-rivals Pakistan in the quarterfinals.	81	["volleyball", "pakistan", "hopes", "asian games", "medal"]	3
17	DFI Retail to take over Maxim's Starbucks-licensed business in seven Asian markets	DFI Retail Group said on Wednesday (Sep 30) its unit will assume Maxim's Caterers' existing interests in the Starbucks -licensed business across seven Asian markets, as part of a reorganisation initiative.Maxim's will pay DFI US$340 million in cash and buy baΓÇª	DFI Retail Group said on Wednesday (Sep 30) its unit will assume Maxim's Caterers' existing interests in the Starbucks -licensed business across seven Asian markets, as part of a reorganisation initiΓÇª	https://www.channelnewsasia.com/business/dfi-retail-maxim-starbucks-licensed-business-6421281	CNA		2026-10-01 02:01:59	2026-10-02 14:39:48	Neutral	0.0000	["Maxim", "DFI Retail Group", "Starbucks", "DFI"]	[]	["DFI Retail"]	0.3818	Positive	Positive	0	0	Economy	0.3300	DFI Retail to take over Maxim's Starbucks-licensed business in seven Asian markets.	84	["dfi", "seven asian", "retail", "asian markets", "seven"]	16
18	Minor Hotels Wants a ΓÇÿVietnam Network,ΓÇÖ Not Just Beach Resorts	Minor Hotels built its Vietnam business around overseas travelers heading to the beach. Now rising domestic travel, corporate business and meetings are giving the hotel group a reason to move into Hanoi and Ho Chi Minh City.	Key Points\r\n Minor Hotels is adding urban hotels in Vietnam's commercial hubs to its resort portfolio, starting with the 310-room Avani+ Hanoi in 2028, its first city property in the country.<ΓÇª	https://skift.com/2026/09/30/minor-hotels-wants-a-vietnam-network-not-just-beach-resorts/	Skift	Montira Rungjirajittranon	2026-10-01 02:00:00	2026-10-02 14:39:48	Neutral	0.0273	["Hotels"]	["Vietnam", "Hanoi"]	["Hotels Wants", "Ho Chi Minh City"]	0.3400	Positive	Positive	11	1	Society	1.0000	Minor Hotels Wants a ΓÇÿVietnam Network,ΓÇÖ Not Just Beach Resorts. Minor Hotels built its Vietnam business around overseas travelers heading to the beach.	78	["hotels", "beach", "business", "hotel", "rising"]	17
33	YT-DLP is Being Treated as a Piracy Tool By The IFPI	Their submission to the EU's piracy watchlist places the open source tool in the same category as illegal downloading websites.	yt-dlp has over 195,000 stars on GitHub, supports thousands of platforms, and is actively maintained by a global developer community. Unfortunately, the IFPI would like to see it on the EU's piracy wΓÇª	https://itsfoss.com/news/yt-dlp-ifpi-piracy-watchlist/	Itsfoss.com	Sourav Rudra	2026-10-01 15:25:37	2026-10-02 18:40:05.339092	Negative	-0.1889	["YT-DLP", "EU", "GitHub"]	[]	[]	0.0772	Positive	Positive	0	0	Society	0.5000	YT-DLP is Being Treated as a Piracy Tool By The IFPI. Their submission to the EU's piracy watchlist places the open source tool in the same category as illegal downloading websites.	64	["places", "illegal", "open"]	30
34	007 First Light's first free DLC 'brings over 700 fixes and improvements' alongside New Game Plus, Photo Mode, and more playable content	007 First Light's first major free downloadable content (DLC) has been released, offering all-new playable content and huge improvements across the board.	007 First Light update 1.3.0 and the game's first free Extended Operations downloadable content (DLC) is now live The DLC adds New Game Plus, Photo Mode, a new mission, a difficulty lΓÇª	https://www.techradar.com/gaming/007-first-lights-first-free-dlc-brings-over-700-fixes-and-improvements-alongside-new-game-plus-photo-mode-and-more-playable-content	TechRadar	Demi Williams	2026-10-01 15:01:23	2026-10-02 18:40:05.339092	Positive	0.1913	["DLC", "First Light's", "First Light", "New Game Plus"]	[]	["Photo Mode"]	0.9286	Positive	Positive	4	1	General	0.0000	007 First Light's first free DLC 'brings over 700 fixes and improvements' alongside New Game Plus, Photo Mode, and more playable content.	76	["content", "light", "dlc", "free", "released"]	31
35	Trump Explodes on Reporter: ΓÇÿYou HavenΓÇÖt Asked Me One FΓÇôking Positive QuestionΓÇÖ	Donald Trump lost it on a reporter during an interview with "Time" in the Oval Office, complaining that he was only being asked "negative" questions.	Donald Trump has had it with the free press. HeΓÇÖs spent his second term trying to ban news outlets from the White House and ranting on social media about unfair coverage, and heΓÇÖs only growing more hΓÇª	http://www.rollingstone.com/politics/politics-news/trump-explodes-reporter-time-interview-1235635165/	Rolling Stone	Ryan Bort	2026-10-01 14:47:25	2026-10-02 18:40:05.339092	Neutral	0.0237	["the Oval Office", "the White House"]	[]	["Trump Explodes", "Donald Trump"]	-0.7096	Negative	Negative	0	0	Technology	1.0000	Trump Explodes on Reporter: ΓÇÿYou HavenΓÇÖt Asked Me One FΓÇôking Positive QuestionΓÇÖ. Donald Trump lost it on a reporter during an interview with "Time" in the Oval Office, complaining that he was only being asked "negative" questions.	74	["asked", "trump", "king", "office", "questions"]	32
36	10 Right-Wing Comic Characters Who Stand Out in a Traditionally Left-Leaning Medium	This post includes affiliate links. If you purchase anything through these affiliated links, the author/website may earn a commission. Comic books have always been a mirror to real-world politics. From the moment Captain America punched Hitler in the face on ΓÇª	John Walker is a Right-Wing superhero, a fact many casual fans may be unaware of. Image source: Amazon\r\nThis post includes affiliate links. If you purchase anything through these affiliated links, thΓÇª	https://www.pfadvice.com/2026/10/01/10-right-wing-comic-characters-who-stand-out-in-a-traditionally-left-leaning-medium/	Pfadvice.com	Allen Francis	2026-10-01 14:41:20	2026-10-02 18:40:05.339092	Neutral	0.0833	["Amazon"]	[]	["Hitler", "John Walker"]	0.1779	Positive	Positive	0	0	Politics	0.5000	10 Right-Wing Comic Characters Who Stand Out in a Traditionally Left-Leaning Medium. This post includes affiliate links. If you purchase anything through these affiliated links, the author/website may earn a commission.	85	["links", "right", "includes", "real", "america"]	33
37	India can emerge as key rice supplier as global production falls 9% and demand rises 14%: IREF	India's rice production is expected to decrease, while global demand is projected to rise significantly. The country possesses sufficient surplus stocks to address international market needs. Other major rice-producing nations are under pressure, which presenΓÇª	New Delhi: India is in a strong position to meet rising global demand for rice as global production is expected to fall by 9 per cent while demand is projected to increase by 14 per cent, Dev Garg, NΓÇª	https://economictimes.indiatimes.com/news/economy/agriculture/india-can-emerge-as-key-rice-supplier-as-global-production-falls-9-and-demand-rises-14-iref/articleshow/134622141.cms	The Times of India	ANI	2026-10-01 14:39:14	2026-10-02 18:40:05.339092	Neutral	0.0525	[]	["India", "New Delhi"]	["Dev Garg"]	0.1027	Positive	Neutral	0	0	Economy	1.0000	India can emerge as key rice supplier as global production falls 9% and demand rises 14%: IREF. India's rice production is expected to decrease, while global demand is projected to rise significantly.	91	["rice", "production", "demand", "india", "global"]	34
38	Dan Rather has followed the news wherever he goes, in a career that highlights 75 years of evolving journalism	Dan Rather anchored the ΓÇÿCBS Evening NewsΓÇÖ for over 20 years, starting on March 9, 1981. But he always seemed more in his element as a reporter, and now as a news analyst on social media.	CBS News anchor Dan Rather rehearses for election night coverage on Nov. 3, 2000, in New York. AP Photo/Mark Lennihan\r\nIn television news, there are two roles in front of the camera: reporter and ancΓÇª	https://theconversation.com/dan-rather-has-followed-the-news-wherever-he-goes-in-a-career-that-highlights-75-years-of-evolving-journalism-265967	The Conversation Africa	Walter Podrazik, Adjunct Lecturer in Communication, University of Illinois Chicago	2026-10-01 14:30:17	2026-10-02 18:40:05.339092	Positive	0.1674	["CBS News", "AP Photo/Mark Lennihan", "anc"]	["New York"]	["Dan Rather"]	0.0000	Neutral	Neutral	1	0	Society	1.0000	Dan Rather has followed the news wherever he goes, in a career that highlights 75 years of evolving journalism. Dan Rather anchored the ΓÇÿCBS Evening NewsΓÇÖ for over 20 years, starting on March 9, 1981.	90	["social media", "highlights", "goes", "social", "media"]	35
154	Russia, Satan, and the ΓÇ£Parviscient Ignorant CrowdΓÇ¥	Ten years ago I had lunch with a man who vehemently insisted that Vladimir Putin was the satanic leader of an evil country and Hilary Clinton was a great American who should be President. \nThis was two years after the ΓÇª\nThe post Russia, Satan, and the ΓÇ£ParvisΓÇª	Ten years ago I had lunch with a man who vehemently insisted that Vladimir Putin was the satanic leader of an evil country and Hilary Clinton was a great American who should be President. \r\nThis was ΓÇª	https://www.globalresearch.ca/russia-satan-parviscient-crowd/5943446	Globalresearch.ca	Edward Curtin	2026-10-12 13:59:37	2026-10-14 01:04:46.97239	Neutral	-0.0500	[]	["Russia", "Satan"]	["Vladimir Putin", "Hilary Clinton"]	-0.4019	Negative	Negative	0	0	General	0.0000	Russia, Satan, and the ΓÇ£Parviscient Ignorant CrowdΓÇ¥. Ten years ago I had lunch with a man who vehemently insisted that Vladimir Putin was the satanic leader of an evil country and Hilary Clinton was a great American who should be President.	92	["russia", "crowd", "president", "great", "country"]	110
155	FM Arrmanatha prioritizes economic resilience through diplomacy	Indonesian foreign policy must deliver tangible economic benefits directly to citizens, Foreign Minister Arrmanatha Nasir asserted, framing domestic economic ...	Jakarta (ANTARA) - Indonesian foreign policy must deliver tangible economic benefits directly to citizens, Foreign Minister Arrmanatha Nasir asserted, framing domestic economic resilience as the primΓÇª	https://en.antaranews.com/news/435136/fm-arrmanatha-prioritizes-economic-resilience-through-diplomacy	Antaranews.com	Nabil Ihsan, Yashinta Difa	2026-10-12 13:35:45	2026-10-14 01:04:46.97239	Neutral	0.0538	["ANTARA"]	["Arrmanatha", "Jakarta"]	["Arrmanatha Nasir"]	0.6369	Positive	Positive	0	0	Politics	0.6000	FM Arrmanatha prioritizes economic resilience through diplomacy. Indonesian foreign policy must deliver tangible economic benefits directly to citizens, Foreign Minister Arrmanatha Nasir asserted, framing domestic economic ...	53	["economic", "foreign", "minister", "policy", "domestic"]	111
351	Vietnam: Free Abducted Democracy Group Activists	Click to expand Image\n \n\n \n \n \n\n \n \n \n \n Tran Hiep.\n ┬⌐ Private\n \n \n\n \n(Bangkok) ΓÇô The┬áVietnamese authorities should immediately release three activists associated with the overseas Viet Tan organization who went missing in Cambodia, and drop all charges agΓÇª	(Bangkok) The┬áVietnamese authorities should immediately release three activists associated with the overseas Viet Tan organization who went missing in Cambodia, and drop all charges against them, HumΓÇª	https://www.hrw.org/news/2026/10/13/vietnam-free-abducted-democracy-group-activists	Human Rights Watch	Human Rights Watch	2026-10-14 00:00:00	2026-10-15 17:24:58.977342	Neutral	0.0000	["Free Abducted Democracy Group Activists Click", "Image", "ag"]	["Vietnam", "Bangkok", "Cambodia"]	["Tran Hiep", "Viet Tan", "Hum"]	-0.8176	Negative	Negative	0	0	General	0.0000	Vietnam: Free Abducted Democracy Group Activists. Click to expand Image Tran Hiep.	69	["organization", "image", "expand", "group", "free"]	192
163	What Hasan Piker Believes	HeΓÇÖs right to complain that a few provocative quotes do not capture his worldview.	About a year and a half ago, Hasan Piker, the left-wing activist and streamer, was hailed as the Democratic PartyΓÇÖs Joe RoganΓÇöan influencer who can reach young men. A wave of gushy profiles paid moreΓÇª	https://www.theatlantic.com/ideas/2026/10/hasan-piker-podcast-democrat/688956/?utm_source=feed	The Atlantic	Jonathan Chait	2026-10-12 11:00:00	2026-10-14 01:04:46.97239	Neutral	0.0048	["the Democratic PartyΓÇÖs Joe Rogan"]	[]	["Hasan Piker"]	-0.1280	Negative	Neutral	0	0	Society	0.5000	What Hasan Piker Believes. HeΓÇÖs right to complain that a few provocative quotes do not capture his worldview.	53	["piker", "hasan", "hasan piker", "right"]	119
108	ZelenskyΓÇÖs bullying worked on Europe. But Trump has the backbone to turn the screws back	KievΓÇÖs public shaming of allies may no longer pay off once Washington starts treating its leader, not Moscow, as the obstacle Read Full Article at RT.com	Vladimir Zelensky has a pattern in dealing with Western partners who disappoint him: raise the disagreement in public, question the partnerΓÇÖs judgment and explain why the decision benefits Russia andΓÇª	https://rt-english.com/news/647153-zelensky-trump-bullying-diesel/	Rt-english.com	RT	2026-10-13 17:36:21	2026-10-14 01:04:46.97239	Neutral	0.0700	["Trump"]	["Washington", "Moscow", "Russia"]	["Zelensky", "Kiev", "Vladimir Zelensky"]	-0.9179	Negative	Negative	0	0	Society	0.5000	ZelenskyΓÇÖs bullying worked on Europe. But Trump has the backbone to turn the screws back. KievΓÇÖs public shaming of allies may no longer pay off once Washington starts treating its leader, not Moscow, as the obstacle Read Full Article at RT.com	71	["europe", "read", "trump"]	67
166	US$110M Oji Liquid Pak Aseptic Packaging Plant Marks Oji Group's Southeast Asia Expansion	DONG NAI, Vietnam, Oct. 12, 2026 /PRNewswire/ -- Last week, OJI Group held the groundbreaking ceremony for its US$110 million aseptic carton packaging plant in Vietnam. Operated under the Oji Liquid Pak (OLP) name, the 57,000-square-metre plant at Long Thanh ΓÇª	DONG NAI, Vietnam, Oct. 12, 2026 /PRNewswire/ -- Last week, OJI Group held the groundbreaking ceremony for its US$110 million aseptic carton packaging plant in Vietnam. Operated under the Oji Liquid ΓÇª	https://biztoc.com/x/fd4be4ce8f27c41a	Biztoc.com	finance.yahoo.com	2026-10-12 09:59:50	2026-10-14 01:04:46.97239	Neutral	-0.0167	["Southeast Asia Expansion DONG NAI", "OJI Group", "OLP", "Long Thanh", "DONG NAI"]	["Vietnam"]	[]	0.0000	Neutral	Neutral	6	1	Society	0.5000	US$110M Oji Liquid Pak Aseptic Packaging Plant Marks Oji Group's Southeast Asia Expansion. DONG NAI, Vietnam, Oct.	86	["oji", "plant", "liquid", "group", "marks"]	122
188	The 76 Best Albums of 1976	Disco was king, Frampton came alive, new sounds like dub and punk were rising up, and the radio was full of Stevie Wonder and Kiss	The year was 1976. Everything was weird but especially the music. Everyone walked around saying Dy-no-mite! or Up your nose with a rubber hose. Jimmy Carter became the first President to hang out witΓÇª	http://www.rollingstone.com/music/music-lists/best-albums-1976-1235622589/	Rolling Stone	Rolling Stone	2026-10-11 17:35:11	2026-10-14 01:04:46.97239	Positive	0.1909	[]	["Frampton"]	["Disco", "Stevie Wonder", "Kiss", "Jimmy Carter"]	0.7177	Positive	Positive	0	0	Society	1.0000	The 76 Best Albums of 1976. Disco was king, Frampton came alive, new sounds like dub and punk were rising up, and the radio was full of Stevie Wonder and Kiss	65	["king", "like", "rising", "best"]	143
114	undata added to PyPI	UN data in Python, without the guessing: a friendly, unofficial client for the UN System Data Commons (data.un.org).	Type a country's name, get a table. undata is a Python package for the\r\nUN System Data Commons, which holds statistics from 26 UN System\r\nentities. It is written for colleagues who need numbers for aΓÇª	https://pypi.org/project/undata/	Pypi.org	islam50@un.org	2026-10-13 15:14:44	2026-10-14 01:04:46.97239	Positive	0.3750	["undata", "PyPI UN", "the UN System Data Commons", "UN System Data Commons", "UN System"]	["Python"]	["Python"]	0.4939	Positive	Positive	0	0	Politics	1.0000	undata added to PyPI. UN data in Python, without the guessing: a friendly, unofficial client for the UN System Data Commons (data.un.org).	58	["data"]	73
109	AiPower Corp., a division of Senci Power USA Inc., to Relaunch Iconic TecumsehPower and Snow King Brands for 2026-2027 Snow Season	OLIVE BRANCH, Miss., Oct. 13, 2026 /PRNewswire/ -- TecumsehPower and Snow King, two legendary names in outdoor power equipment, are returning to the North American market in Q4 2026. Through an exclusive agreement with AiPower Corp., the brands will once agaiΓÇª	OLIVE BRANCH, Miss., Oct. 13, 2026 /PRNewswire/ -- TecumsehPower and Snow King, two legendary names in outdoor power equipment, are returning to the North American market in Q4 2026. Through an excluΓÇª	https://www.prnewswire.com/news-releases/aipower-corp-a-division-of-senci-power-usa-inc-to-relaunch-iconic-tecumsehpower-and-snow-king-brands-for-20262027-snow-season-302907303.html	PRNewswire		2026-10-13 16:38:00	2026-10-14 01:04:46.97239	Positive	0.5000	["AiPower Corp.", "Senci Power USA Inc.", "Relaunch Iconic TecumsehPower", "Snow King Brands", "TecumsehPower"]	["Miss."]	["Snow King"]	0.3612	Positive	Positive	0	0	Economy	0.5000	AiPower Corp., a division of Senci Power USA Inc., to Relaunch Iconic TecumsehPower and Snow King Brands for 2026-2027 Snow Season. OLIVE BRANCH, Miss., Oct.	94	["power", "king", "north", "exclusive", "season"]	68
110	Wiwynn, Ayar Labs, and GUC Advance Co-Packaged Optics with Live Demonstration of Integrated Optical Compute System at OCP Global Summit 2026	Three-way collaboration showcases platform integration, real-time telemetry and system management readiness, accelerating CPO deployment into rack-scale AI infrastructure SAN JOSE, Calif., Oct. 13, 2026 /PRNewswire/ -- Wiwynn, an innovative cloud IT infrastruΓÇª	Three-way collaboration showcases platform integration, real-time telemetry and system management readiness, accelerating CPO deployment into rack-scale AI infrastructure\r\nSAN JOSE, Calif., Oct. 13, ΓÇª	https://www.prnewswire.com/news-releases/wiwynn-ayar-labs-and-guc-advance-co-packaged-optics-with-live-demonstration-of-integrated-optical-compute-system-at-ocp-global-summit-2026-302907032.html	PRNewswire		2026-10-13 16:30:00	2026-10-14 01:04:46.97239	Positive	0.2121	["OCP Global Summit 2026", "CPO"]	["AI", "SAN JOSE", "Calif."]	["Wiwynn", "Ayar Labs", "GUC Advance Co-Packaged Optics"]	0.7430	Positive	Positive	0	0	Technology	1.0000	Wiwynn, Ayar Labs, and GUC Advance Co-Packaged Optics with Live Demonstration of Integrated Optical Compute System at OCP Global Summit 2026.	77	["infrastructure", "cloud", "summit", "real", "oct prnewswire"]	69
111	CoalΓÇÖs revival is creating divisions in CanadaΓÇÖs energy heartland	Nearly 60 years after the Grassy Mountain coal mine closed, locals are pinning hopes for an economic revival on the mountainside. Read on	About 70 per cent of the worlds steel supply depends on metallurgical coal and Canada is the fifth-largest global supplier, accounting for roughly $9 billion in exports.\r\nNorthback isnt the only suchΓÇª	https://financialpost.com/commodities/energy/coals-revival-creating-divisions-canada-energy-heartland	Financial Post	Bloomberg News	2026-10-13 16:04:11	2026-10-14 01:04:46.97239	Neutral	0.0167	["Coal", "Grassy", "Northback"]	["Canada"]	[]	0.7269	Positive	Positive	0	0	Economy	0.4000	CoalΓÇÖs revival is creating divisions in CanadaΓÇÖs energy heartland. Nearly 60 years after the Grassy Mountain coal mine closed, locals are pinning hopes for an economic revival on the mountainside. Read on	64	["hopes", "closed", "economic", "read", "nearly"]	70
112	CRYSTAL LAKE Review: Prequel Series is a Slow-Burn Crime Drama That Doesn't Skimp on Slasher Violence	Pamela Voorhees is unraveling.┬á ┬á Reeling from her son JasonΓÇÖs drowning at camp, she tries to cope with a loss she just can't let go of. She gets close to the local police chief, Levon Brooks, who steps in to help. Heck, she even hits up a self-help motivatioΓÇª	Pamela Voorhees is unraveling.┬á\r\nReeling from her son JasonΓÇÖs drowning at camp, she tries to cope with a loss she just can't let go of. She gets close to the local police chief, Levon Brooks, who steΓÇª	https://screenanarchy.com/2026/10/crystal-lake-review.html	Screenanarchy.com	https://facebook.com/https://www.facebook.com/andrew.mack.735	2026-10-13 15:54:21	2026-10-14 01:04:46.97239	Neutral	-0.0500	[]	[]	["a Slow-Burn", "Pamela Voorhees", "Jason", "Levon Brooks"]	-0.8591	Negative	Negative	0	0	Military	1.0000	CRYSTAL LAKE Review: Prequel Series is a Slow-Burn Crime Drama That Doesn't Skimp on Slasher Violence. Pamela Voorhees is unraveling. Reeling from her son JasonΓÇÖs drowning at camp, she tries to cope with a loss she just can't let go of.	101	["help", "crystal lake", "crystal", "chief", "series"]	71
113	ΓÇÿCrystal LakeΓÇÖ Review: Over-the-Top Kills Succumb to an Underbaked Story in A24ΓÇÖs ΓÇÿFriday the 13thΓÇÖ Prequel	A new contender for the most maddening use of a penultimate flashback episode emerges in "Crystal Lake," Brad Caleb Kane's Voorhees family origin story that asks where the mother-son killers came from ΓÇö┬áand answers far too easily, and far too late.	To its credit, ΓÇ£Crystal LakeΓÇ¥ is not like a lot of modern TV horror. The ΓÇ£Friday the 13thΓÇ¥ prequel series isnΓÇÖt a remixed remake or a cheap rip-off. ItΓÇÖs not a horror show thatΓÇÖs actually a family drΓÇª	https://www.indiewire.com/criticism/shows/crystal-lake-review-watch-last-two-episodes-only-1235221420/	IndieWire	Ben Travers	2026-10-13 15:30:00	2026-10-14 01:04:46.97239	Neutral	0.0515	[]	[]	["Voorhees"]	-0.8626	Negative	Negative	0	0	General	0.0000	ΓÇÿCrystal LakeΓÇÖ Review: Over-the-Top Kills Succumb to an Underbaked Story in A24ΓÇÖs ΓÇÿFriday the 13thΓÇÖ Prequel.	96	["crystal lake", "crystal", "story", "asks", "friday"]	72
165	Baiduri Bank Establishes Inaugural EMTN Programme, Expanding Access to Global Capital Markets	Baiduri Bank Sendirian Berhad (Baiduri Bank) has established its inaugural USD2 billion Euro Medium Term Note Programme (EMTN Programme) on 5 October 2026, ...	UOB acts as sole arranger and dealer for the EMTN Programme, providingaplatformforBaiduriBanktostrengthenfundingresilience and expand its international investor base.Bandar Seri Begawan, Brunei (ANTAΓÇª	https://en.antaranews.com/news/435104/baiduri-bank-establishes-inaugural-emtn-programme-expanding-access-to-global-capital-markets	Antaranews.com	PR Wire	2026-10-12 10:28:00	2026-10-14 01:04:46.97239	Neutral	0.0000	["Baiduri Bank Establishes", "Expanding Access", "Global Capital Markets Baiduri Bank", "Baiduri Bank", "EMTN Programme", "UOB", "the EMTN Programme"]	["Brunei"]	["Bandar Seri Begawan"]	0.3182	Positive	Positive	0	0	Economy	0.6700	Baiduri Bank Establishes Inaugural EMTN Programme, Expanding Access to Global Capital Markets.	58	["bank", "usd", "markets", "october", "billion"]	121
132	MetaΓÇÖs TikTok Link Ban Could Hobble Media BuyersΓÇÖ Creator Campaigns	Blocking a rival makes sense, buyers say, but stopping brands from linking to TikTok is another matter.	Last week, Meta announced an abrupt change in its advertising policy, saying that it would no longer run ads from TikTok across its ecosystem of brands.Meta began enforcing the ban on Thursday, Oct. ΓÇª	https://www.adweek.com/social-marketing/meta-tiktok-ad-ban-advertisers/	Adweek	Mark Stenberg	2026-10-13 05:03:11	2026-10-14 01:04:46.97239	Neutral	-0.0625	["MetaΓÇÖs TikTok Link Ban Could", "TikTok", "Meta"]	[]	[]	-0.9109	Negative	Negative	0	0	Politics	0.5000	MetaΓÇÖs TikTok Link Ban Could Hobble Media BuyersΓÇÖ Creator Campaigns. Blocking a rival makes sense, buyers say, but stopping brands from linking to TikTok is another matter.	61	["ban", "media"]	90
145	Philippine Lower House Passes Bill Restricting Social Media Access of Minors	If passed into law, the country will become the fourth in Southeast Asia to introduce youth social media restrictions of some kind.	The Philippine House of Representatives yesterday approved a measure barring children under the age of 13 from social media. It has become the latest nation in Southeast Asia to tighten online safetyΓÇª	https://thediplomat.com/2026/10/philippine-lower-house-passes-bill-restricting-social-media-access-of-minors/	The Diplomat	Sebastian Strangio	2026-10-12 23:22:00	2026-10-14 01:04:46.97239	Positive	0.2000	["Philippine Lower House", "The Philippine House of Representatives"]	[]	["Bill Restricting Social"]	0.3400	Positive	Positive	0	0	Politics	1.0000	Philippine Lower House Passes Bill Restricting Social Media Access of Minors. If passed into law, the country will become the fourth in Southeast Asia to introduce youth social media restrictions of some kind.	65	["social media", "social", "media", "house", "southeast asia"]	101
146	The 25 best places to visit in 2027, according to Lonely Planet	From national parks in Kenya to California's ancient redwood forests, these are the 25 places to add to your 2027 travel bucket list.	Thousands of snow geese take flight at Bosque del Apache National Wildlife Refuge near San Antonio, New Mexico.Ronen Tivony/NurPhoto via Getty Images\r\n Lonely Planet curated a list of the bestΓÇª	https://www.businessinsider.com/best-places-cities-to-travel-visit-2026-10#article	Business Insider	Tristin Hoffman	2026-10-12 21:10:25	2026-10-14 01:04:46.97239	Positive	0.2073	["Bosque del Apache National Wildlife Refuge", "Getty Images"]	["Kenya", "California", "San Antonio", "New Mexico"]	["Ronen Tivony/NurPhoto"]	0.0516	Positive	Positive	1	0	Society	1.0000	The 25 best places to visit in 2027, according to Lonely Planet. From national parks in Kenya to California's ancient redwood forests, these are the 25 places to add to your 2027 travel bucket list.	65	["places", "california", "list", "best", "travel"]	102
147	India draws $351 billion in Greenfield FDI, outpaces China	Speaking to ET, Nikolaus Lang, managing director & senior partner at BCG highlighted the Indian market as the biggest draw for investors amid a sweeping global realignment. He, however, stressed on sustained focus on infrastructure development, skilling and cΓÇª	New Delhi: India attracted $351 billion in foreign direct investment (FDI) for greenfield projects during 2021-25, more than double that of China, according to the Boston Consulting Group (BCG). IndiΓÇª	https://economictimes.indiatimes.com/news/economy/finance/india-draws-351-billion-in-greenfield-fdi-outpaces-china/articleshow/134901834.cms	The Times of India	Sharmistha Mukherjee	2026-10-12 19:28:07	2026-10-14 01:04:46.97239	Positive	0.1019	["Greenfield FDI", "BCG", "FDI", "the Boston Consulting Group"]	["India", "New Delhi", "China"]	["Nikolaus Lang", "Indi"]	0.1027	Positive	Positive	0	0	Economy	0.5000	India draws $351 billion in Greenfield FDI, outpaces China. Speaking to ET, Nikolaus Lang, managing director & senior partner at BCG highlighted the Indian market as the biggest draw for investors amid a sweeping global realignment.	78	["managing", "infrastructure", "highlighted", "focus", "biggest"]	103
149	Top 5 Flight Bonus Miles and Points Offers for October 2026	Here are our Top 5 Flight Bonus Mile/Point Offers for this month. This post is of course for bonuses for flying this month however many of these offers go beyond so donΓÇÖt count them out for flights you need to book past this month. If none of the offers listeΓÇª	Here are our Top 5 Flight Bonus Mile/Point Offers for this month. This post is of course for bonuses for flying this month however many of these offers go beyond so dont count them out for flights yoΓÇª	https://blog.frequentflyerbonuses.com/2026/10/top-5-flight-bonus-october-2026.html	Frequentflyerbonuses.com	Frequent Flyer Bonuses	2026-10-12 17:02:49	2026-10-14 01:04:46.97239	Positive	0.2375	["Points Offers"]	[]	[]	0.9686	Positive	Positive	0	0	General	0.0000	Top 5 Flight Bonus Miles and Points Offers for October 2026. Here are our Top 5 Flight Bonus Mile/Point Offers for this month.	99	["offers", "flight", "point", "miles", "flights"]	105
150	Hasan Piker Defends Telling MAGA Fan ΓÇÿSuck My D*ck, Old LadyΓÇÖ in Wild Interview	Social media influencer Hasan Piker defended a controversial moment in which he hurled a barrage of vulgar insults at a pro-MAGA Vietnamese refugee.\nThe post Hasan Piker Defends Telling MAGA Fan ΓÇÿSuck My D*ck, Old LadyΓÇÖ in Wild Interview first appeared on MedΓÇª	Social media influencer Hasan Piker defended a controversial moment in which he hurled a barrage of vulgar insults at a pro-MAGA Vietnamese refugee.\r\nEarlier this year, Piker was harshly criticized fΓÇª	https://www.mediaite.com/media/podcasts/hasan-piker-defends-telling-maga-fan-suck-my-dck-old-lady-in-wild-interview/	Mediaite	Ahmad Austin Jr.	2026-10-12 16:16:01	2026-10-14 01:04:46.97239	Neutral	0.0167	["MedΓÇª Social", "Piker"]	["Wild Interview Social", "Wild Interview"]	["Hasan Piker Defends", "Hasan Piker"]	-0.7269	Negative	Negative	3	1	General	0.0000	Hasan Piker Defends Telling MAGA Fan ΓÇÿSuck My D*ck, Old LadyΓÇÖ in Wild Interview. Social media influencer Hasan Piker defended a controversial moment in which he hurled a barrage of vulgar insults at a pro-MAGA Vietnamese refugee.	88	["piker", "hasan", "hasan piker", "interview", "wild"]	106
4	2026 Tokyo Film Festival Lineup: Full List	Gala screenings include 'Godzilla Minus Zero,' 'Behemoth!,' 'Fjord' and 'Wild Horse Nine' and 15 films were selected for the main competition.	The Tokyo International Film Festival has revealed its full competition lineup for the 39th edition of AsiaΓÇÿs largest film event. \r\nAs ever, the lineup is a mix of new features from AsiaΓÇÖs best auteuΓÇª	http://www.hollywoodreporter.com/movies/movie-news/tokyo-film-festival-full-2026-lineup-1236718018/	Hollywood Reporter	Abid Rahman	2026-10-01 07:02:14	2026-10-02 14:39:48	Positive	0.2473	["Fjord"]	[]	[]	0.8977	Positive	Positive	0	0	Society	0.5000	2026 Tokyo Film Festival Lineup: Full List. Gala screenings include 'Godzilla Minus Zero,' 'Behemoth!,' 'Fjord' and 'Wild Horse Nine' and 15 films were selected for the main competition.	62	["film festival", "films", "festival", "wild", "list"]	4
1	School of War or School of Battle? Educating for an Uncertain Future	In 1901, military analyst Jan Bloch declared that new military technologies had changed war so radically that the study of history had become useless. He castigated military officers who prepared for future war based on ΓÇ£musty precedentsΓÇ¥ and who failed to reΓÇª	In 1901, military analyst Jan Bloch declared that new military technologies had changed war so radically that the study of history had become useless. He castigated military officers who prepared forΓÇª	https://warontherocks.com/school-of-war-or-school-of-battle-educating-for-an-uncertain-future/	War on the Rocks	Michael P. Ferguson, Clifford J. Rogers	2026-10-01 07:30:11	2026-10-02 14:39:48	Negative	-0.1406	["School of War or School of Battle", "an Uncertain Future"]	[]	["Jan Bloch"]	-0.9788	Negative	Negative	0	0	Society	0.3300	School of War or School of Battle? Educating for an Uncertain Future. In 1901, military analyst Jan Bloch declared that new military technologies had changed war so radically that the study of history had become useless.	85	["military", "war", "school", "future", "history"]	1
2	Vietnam's Ho Chi Minh City is learning to live with floods but climate change has raised the stakes	Ho Chi Minh City has learned to live with flooding as high tides from the Saigon River and smaller waterways regularly inundate roads and businesses	HO CHI MINH CITY, Vietnam -- It is the flood Vietnam's Ho Chi Minh City has learned to expect.\r\nForecasters warned on Sept. 27 that high tides could combine with heavy rain to increase the risk of flΓÇª	https://abcnews.com/Business/wireStory/vietnams-ho-chi-minh-city-learning-live-floods-136911209	Abcnews.com	THANH HUE Associated Press, ANIRUDDHA GHOSAL Associated Press	2026-10-01 07:24:35	2026-10-02 14:39:48	Neutral	0.0561	[]	["Vietnam"]	["Ho Chi Minh City", "HO CHI"]	-0.3291	Negative	Negative	12	1	Environment	0.6700	Vietnam's Ho Chi Minh City is learning to live with floods but climate change has raised the stakes. Ho Chi Minh City has learned to live with flooding as high tides from the Saigon River and smaller waterways regularly inundate roads and businesses	81	["live", "minh city", "minh", "chi minh", "chi"]	2
3	India bow out of Asian Games men's volleyball after Pakistan quarterfinal defeat	The Indian men's volleyball team concluded their Asian Games 2026 campaign with a loss to Pakistan. They were defeated 0-3 in the quarterfinals, failing to capitalize on early leads in each set. Earlier in the day, India secured a medal in men's sepaktakraw bΓÇª	Aichi-Nagoya: The Indian men's volleyball team's Asian Games 2026 campaign came to an end after a 0-3 loss to arch-rivals Pakistan in the quarterfinals at the Aichi-Nagoya Games on Thursday.India, whΓÇª	https://economictimes.indiatimes.com/news/sports/other-sports/india-bow-out-of-asian-games-mens-volleyball-after-pakistan-quarterfinal-defeat/articleshow/134608962.cms	The Times of India	ANI	2026-10-01 07:05:16	2026-10-02 14:39:48	Neutral	0.0200	["Asian Games", "Asian Games 2026"]	["India", "Pakistan"]	["Aichi-Nagoya"]	-0.8020	Negative	Negative	0	0	Society	0.3300	India bow out of Asian Games men's volleyball after Pakistan quarterfinal defeat. The Indian men's volleyball team concluded their Asian Games 2026 campaign with a loss to Pakistan.	87	["men", "volleyball", "pakistan", "asian games", "games"]	3
5	India Assured Sepaktakraw Medal	India's men's sepaktakraw quadrant team has secured at least a bronze medal at the Asian Games after advancing to the semifinals with an unbeaten run, topping Group A. They defeated Myanmar, Laos, and Vietnam, with the semifinals scheduled for Friday.	India's men's sepaktakraw quadrant team has guaranteed at least a bronze medal at the Asian Games by reaching the semifinals with an impressive unbeaten run, showcasing their dominance in Group A.\r\nKΓÇª	https://www.rediff.com/sports/report/india-assured-sepaktakraw-medal-at-asian-games/20261001.htm	Rediff.com	sports@rediff.co.in (Rediff Sports Desk)	2026-10-01 06:51:27	2026-10-02 14:39:48	Neutral	0.0800	["India Assured Sepaktakraw Medal India's"]	["Myanmar", "Laos", "Vietnam", "India"]	["Group A."]	0.9460	Positive	Positive	2	0	Sports	1.0000	India Assured Sepaktakraw Medal. India's men's sepaktakraw quadrant team has secured at least a bronze medal at the Asian Games after advancing to the semifinals with an unbeaten run, topping Group A.	76	["sepaktakraw", "medal", "india", "myanmar", "secured"]	5
6	Vietnam to move all Hanoi-listed stocks to Ho Chi Minh index in┬áDecember under market overhaul	HANOI, Oct 1 : Vietnam will move all its listed stocks to the main Ho Chi Minh City Stock Exchange in late December, completing a long-planned market restructuring and ending equity trading on the Hanoi Stock Exchange. The announcement, made late on WednesdayΓÇª	HANOI, Oct 1 : Vietnam will move all its listed stocks to the main Ho Chi Minh City Stock Exchange in late December, completing a long-planned market restructuring and ending equity trading on the HaΓÇª	https://www.channelnewsasia.com/business/vietnam-move-all-hanoi-listed-stocks-ho-chi-minh-index-in-december-under-market-overhaul-6423696	CNA		2026-10-01 06:36:51	2026-10-02 14:39:48	Negative	-0.1133	["the Hanoi Stock Exchange"]	["Vietnam", "Hanoi"]	["Ho Chi Minh", "Ho Chi Minh City Stock Exchange"]	0.0000	Neutral	Neutral	18	1	Economy	0.6700	Vietnam to move all Hanoi-listed stocks to Ho Chi Minh index in December under market overhaul.	94	["hanoi", "december", "late", "minh", "chi minh"]	6
7	Fondation BeyelerΓÇÖs Expansion and Safdie ArchitectsΓÇÖ Carnegie Library Restoration: This WeekΓÇÖs Review	Architecture this week reflects on how buildings and cities adapt to changing cultural, social, and environmental conditions. From the expansion of established institutions and the preservation of architectural archives to new approaches to housing and the usΓÇª	The expanded Ensemble of the Fondation Beyeler, Erlen Torhaus, Wyss Museum and Ammann Pavillon by Atelier Peter Zumthor. Image ┬⌐ Iwan Baan\r\nArchitecture this week reflects on how buildings and citiesΓÇª	https://www.archdaily.com/1186117/fondation-beyelers-expansion-and-safdie-architects-carnegie-library-restoration-this-weeks-review	ArchDaily	Reyyan Dogan	2026-10-01 06:30:00	2026-10-02 14:39:48	Neutral	0.0899	["Fondation BeyelerΓÇÖs Expansion", "the Fondation Beyeler", "Wyss Museum", "Ammann Pavillon", "Iwan Baan\\r\\nArchitecture"]	[]	["Erlen Torhaus", "Atelier Peter Zumthor"]	0.0000	Neutral	Neutral	0	0	Economy	0.5000	Fondation BeyelerΓÇÖs Expansion and Safdie ArchitectsΓÇÖ Carnegie Library Restoration: This WeekΓÇÖs Review. Architecture this week reflects on how buildings and cities adapt to changing cultural, social, and environmental conditions.	80	["expansion", "changing", "social", "review", "library"]	7
8	Where does illegal ivory go?	Where Does Illegal Ivory Go? A Shadowy Global Trade The vast majority of illegal ivory ends up in East Asia, particularly China and Vietnam, where it is carved into ornaments, jewelry, and religious items, driven by persistent demand despite international effΓÇª	Where Does Illegal Ivory Go? A Shadowy Global Trade\r\nThe vast majority of illegal ivory ends up in East Asia, particularly China and Vietnam, where it is carved into ornaments, jewelry, and religiousΓÇª	https://www.lifesciencesworld.com/where-does-illegal-ivory-go/	Lifesciencesworld.com	Ava Reynolds	2026-10-01 05:36:22	2026-10-02 14:39:48	Negative	-0.1667	["Shadowy Global Trade"]	["China", "Vietnam"]	["Illegal Ivory Go"]	-0.9640	Negative	Negative	3	1	Economy	0.5000	Where does illegal ivory go?. Where Does Illegal Ivory Go?	79	["ivory", "illegal ivory", "illegal", "does", "jewelry"]	8
9	Visa Expands "Infinite Tastes: Beyond the Menu" with a New Wave of Culinary Journeys Across Asia Pacific	Visa, a global leader in digital payments, today announced an expansion of Infinite Tastes: Beyond the Menu, its chef-led culinary marquee program created ...	Flagship chef-led program offers Visa Infinite cardholders access to exclusive dining experiences across 13 Asia Pacific markets, designed around deeper access, discovery and stories behind tΓÇª	https://en.antaranews.com/news/433667/visa-expands-infinite-tastes-beyond-the-menu-with-a-new-wave-of-culinary-journeys-across-asia-pacific	Antaranews.com	PR Wire	2026-10-01 05:23:31	2026-10-02 14:39:48	Neutral	-0.0234	["Culinary Journeys Across Asia Pacific Visa", "Menu"]	[]	["Visa Infinite"]	0.5106	Positive	Positive	0	0	Economy	0.3300	Visa Expands "Infinite Tastes: Beyond the Menu" with a New Wave of Culinary Journeys Across Asia Pacific.	67	["visa", "digital", "created", "asia pacific", "expansion"]	9
10	Federal Judge Issues Temporary Injunction Against Connecticut Glock Ban	On Wednesday, a judge in the U.S. District Court for the District of Connecticut issued a preliminary injunction blocking the implementation of Connecticut's Glock ban.\nThe post Federal Judge Issues Temporary Injunction Against Connecticut Glock Ban appeared ΓÇª	On Wednesday, a judge in the U.S. District Court for the District of Connecticut issued a preliminary injunction blocking the implementation of ConnecticutΓÇÖs Glock ban.\r\nBreitbart News reported that ΓÇª	https://www.breitbart.com/2nd-amendment/2026/09/30/federal-judge-issues-temporary-injunction-against-connecticut-glock-ban/	Breitbart News	AWR Hawkins	2026-10-01 04:55:02	2026-10-02 14:39:48	Neutral	0.0000	["the U.S.", "District Court", "Breitbart News"]	["Connecticut"]	["Glock"]	-0.9618	Negative	Negative	0	0	Society	0.5000	Federal Judge Issues Temporary Injunction Against Connecticut Glock Ban. On Wednesday, a judge in the U.S. District Court for the District of Connecticut issued a preliminary injunction blocking the implementation of Connecticut's Glock ban.	77	["connecticut", "glock ban", "glock", "ban", "wednesday"]	10
11	Show HN: Vietnam Tender Intelligence ΓÇô gov procurement data, AI-agent ready	Monitor Vietnam's official tender portal (VNEPS): procurement plans, tender notices, and award results by keyword. Clean JSON data for AI Agents via Api...	Monitors Vietnam's national e-procurement portal (VNEPS\r\n) by keyword and returns matching tenders as clean JSON: notice number, tender name, closing date, location, investment field.\r\nInput:keywordsΓÇª	https://apify.com/donerightlabs/tender-intelligence	Apify.com	tvttrace	2026-10-01 04:50:24	2026-10-02 14:39:48	Positive	0.3111	["Monitor Vietnam's", "VNEPS", "AI Agents"]	["AI", "Vietnam"]	["Vietnam Tender Intelligence", "JSON"]	0.9371	Positive	Positive	6	1	Economy	0.2500	Show HN: Vietnam Tender Intelligence ΓÇô gov procurement data, AI-agent ready. Monitor Vietnam's official tender portal (VNEPS): procurement plans, tender notices, and award results by keyword. Clean JSON data for AI Agents via Api...	60	["data", "intelligence", "award", "plans"]	11
19	Can MyanmarΓÇÖs New Government Revive the Stalled Dawei SEZ Project?	The flagship project struggled even during MyanmarΓÇÖs decade of opening. Attempting to revive it amid conflict and sanctions will test its economic and strategic rationale.	Myanmars military-backed administration is again trying to put the long-stalled Dawei Special Economic Zone (SEZ) project on the agenda. This time, Russia has emerged as a potential partner for some ΓÇª	https://thediplomat.com/2026/10/can-myanmars-new-government-revive-the-stalled-dawei-sez-project/	The Diplomat	Soe P.H.	2026-10-01 01:30:00	2026-10-02 14:39:48	Positive	0.1787	["the Stalled Dawei SEZ Project", "Dawei Special Economic Zone"]	["Myanmar", "Russia"]	[]	0.3400	Positive	Positive	0	0	Military	0.3300	Can MyanmarΓÇÖs New Government Revive the Stalled Dawei SEZ Project?. The flagship project struggled even during MyanmarΓÇÖs decade of opening. Attempting to revive it amid conflict and sanctions will test its economic and strategic rationale.	66	["project", "myanmar", "strategic", "economic", "amid"]	18
20	Cava names John Ludeke chief marketing officer	Cava has named John Ludeke chief marketing officer. He will lead the fast-casual chain's marketing organization as it continues to expand.	September 30, 2026\r\nCava has named John Ludeke chief marketing officer. He will lead the fast-casual chain's marketing organization as it continues to expand.\r\nLudeke most recently served as chief brΓÇª	https://www.fastcasual.com/news/cava-names-john-ludeke-chief-marketing-officer/	Fast Casual		2026-10-01 01:22:48	2026-10-02 14:39:48	Positive	0.2500	[]	[]	["Cava", "John Ludeke", "Ludeke"]	0.3182	Positive	Positive	0	0	Economy	0.5000	Cava names John Ludeke chief marketing officer. Cava has named John Ludeke chief marketing officer. He will lead the fast-casual chain's marketing organization as it continues to expand.	38	["chief", "organization", "expand", "lead", "chain"]	19
21	ChinaΓÇÖs Military Open New Logistics and Training Facility in Laos	The center north of Vientiane, a counterpart to a similar naval facility in Cambodia, marks a further extension of Beijing's security presence in mainland Southeast Asia.	This week, the Chinese military opened a new logistics and training facility at an airport in Laos, further expanding its regional security presence and marking the first overseas presence of the ChiΓÇª	https://thediplomat.com/2026/10/chinas-military-open-new-logistics-and-training-facility-in-laos/	The Diplomat	Sebastian Strangio	2026-10-01 01:08:00	2026-10-02 14:39:48	Neutral	0.0202	["Training Facility"]	["China", "Laos", "Vientiane", "Cambodia", "Beijing"]	["Chi"]	0.5859	Positive	Positive	0	0	Military	0.5000	ChinaΓÇÖs Military Open New Logistics and Training Facility in Laos. The center north of Vientiane, a counterpart to a similar naval facility in Cambodia, marks a further extension of Beijing's security presence in mainland Southeast Asia.	68	["facility", "security", "center", "military", "marks"]	20
22	'Best Minds'? Hegseth Taps Elon Musk, Palmer Luckey, and Newt Gingrich to Lead 'Future of Warfare' Project	US Defense Secretary Pete Hegseth announced Wednesday that three menΓÇönone of whom have served in the military and two who make billions of dollars from itΓÇöwill help lead a new Pentagon project on the ΓÇ£future of warfare," even as he moves to eliminate hundredsΓÇª	US Defense Secretary Pete Hegseth announced Wednesday that three mennone of whom have served in the military and two who make billions of dollars from itwill help lead a new Pentagon project on the fΓÇª	https://www.commondreams.org/news/hegseth-project-meridian	Common Dreams	Brett Wilkins	2026-10-01 00:26:49	2026-10-02 14:39:48	Positive	0.1532	["Lead 'Future of Warfare' Project US Defense", "Pentagon"]	["US"]	["Hegseth Taps Elon Musk", "Palmer Luckey", "Newt Gingrich", "Pete Hegseth"]	0.8020	Positive	Positive	0	0	Military	1.0000	'Best Minds'? Hegseth Taps Elon Musk, Palmer Luckey, and Newt Gingrich to Lead 'Future of Warfare' Project.	96	["project", "hegseth", "warfare", "future", "lead"]	21
23	ΓÇÿVerityΓÇÖ To Seduce $55M+ WW Opening As Box Office Braces For ΓÇÿDiggerΓÇÖ Impact ΓÇô Global Preview	Well, on the bright side of things, the autumn box office should continue at a great hum this weekend thanks to Amazon MGM StudioΓÇÖs feature take of Colleen Hoover thriller, Verity, starring Dakota Johnson, Anne Hathaway, and Josh Hartnett. The domestic outlooΓÇª	Well, on the bright side of things, the autumn box office should continue at a great hum this weekend thanks to Amazon MGM StudioΓÇÖs feature take of Colleen Hoover thriller, Verity, starring Dakota JoΓÇª	http://deadline.com/2026/10/box-office-digger-tom-cruise-verity-1237144416/	Deadline	Anthonypauldalessandro	2026-10-01 18:30:36	2026-10-02 18:40:05.339092	Positive	0.4250	["Box Office Braces For ΓÇÿDiggerΓÇÖ Impact", "Amazon MGM StudioΓÇÖs"]	[]	["Colleen Hoover", "Dakota Johnson", "Anne Hathaway", "Josh Hartnett", "Dakota Jo"]	0.9781	Positive	Positive	0	0	Society	1.0000	ΓÇÿVerityΓÇÖ To Seduce $55M+ WW Opening As Box Office Braces For ΓÇÿDiggerΓÇÖ Impact ΓÇô Global Preview.	92	["office", "box", "great", "domestic", "global"]	22
24	007 First LightΓÇÖs Free DLC Is Full of Requested Features	Image Courtesy of IO Interactive\n\nDeveloper IO Interactive found great success with the recent Hitman trilogy that has been going on for over a decade, showing that live service games can thrive if done thoughtfully and with restraint. The studio noted it wouΓÇª	Developer IO Interactive found great success with the recent Hitman trilogy that has been going on for over a decade, showing that live service games can thrive if done thoughtfully and with restrainΓÇª	http://comicbook.com/gaming/news/007-first-lights-free-dlc-is-full-of-requested-features/	ComicBook.com	Michael Leri	2026-10-01 18:02:23	2026-10-02 18:40:05.339092	Positive	0.3338	[]	[]	[]	0.9794	Positive	Positive	0	0	Technology	1.0000	007 First LightΓÇÖs Free DLC Is Full of Requested Features.	86	["light", "image", "free dlc", "dlc", "developer"]	23
25	Asiana: San Francisco ΓÇô Ho Chi Minh City, Vietnam. $766. Roundtrip, including all Taxes	A good sale to VietnamVietnam introduced a new e-Visa system - take advantage of it. Its the cheapest option.Sample Travel Date:November 16th - 23rdThis is just ONE SAM	A good sale to Vietnam\r\nVietnam introduced a new e-Visa system take advantage of it. Its the cheapest option.\r\nSign up for our Real Time Newsletter to receive economy class deals for your city about ΓÇª	https://www.theflightdeal.com/2026/10/01/asiana-san-francisco-ho-chi-minh-city-vietnam-766-roundtrip-including-all-taxes/	Theflightdeal.com	The Flight Deal	2026-10-01 17:23:00	2026-10-02 18:40:05.339092	Positive	0.3745	["Taxes", "VietnamVietnam", "Real Time Newsletter"]	["Asiana", "San Francisco", "Vietnam"]	["Ho Chi Minh City", "Roundtrip"]	0.8316	Positive	Positive	9	1	Society	0.6700	Asiana: San Francisco ΓÇô Ho Chi Minh City, Vietnam. $766. Roundtrip, including all Taxes. A good sale to VietnamVietnam introduced a new e-Visa system - take advantage of it.	78	["visa advantage", "francisco", "advantage", "san francisco", "option"]	24
26	Korean Air: Seattle ΓÇô Ho Chi Minh City, Vietnam. $774. Roundtrip, including all Taxes	A good sale to Ho Chi Minh City.Vietnam introduced a new e-Visa system - take advantage of it. Its the cheapest option.Sample Travel Date:November 5th - 12thThis is jus	A good sale to Ho Chi Minh City.\r\nVietnam introduced a new e-Visa system take advantage of it. Its the cheapest option.\r\nSign up for our Real Time Newsletter to receive economy class deals for your cΓÇª	https://www.theflightdeal.com/2026/10/01/korean-air-seattle-ho-chi-minh-city-vietnam-774-roundtrip-including-all-taxes/	Theflightdeal.com	The Flight Deal	2026-10-01 17:03:46	2026-10-02 18:40:05.339092	Positive	0.3745	["Taxes", "Real Time Newsletter"]	["Seattle", "Vietnam"]	["Ho Chi Minh City", "Roundtrip"]	0.8316	Positive	Positive	12	1	Society	0.5000	Korean Air: Seattle ΓÇô Ho Chi Minh City, Vietnam. $774. Roundtrip, including all Taxes. A good sale to Ho Chi Minh City.Vietnam introduced a new e-Visa system - take advantage of it.	80	["minh city", "minh", "chi", "chi minh", "city"]	24
27	Korean Air: Dallas ΓÇô Ho Chi Minh, Vietnam. $816. Roundtrip, including all Taxes	A good sale to Ho Chi Minh CityVietnam introduced a new e-Visa system - take advantage of it. Its the cheapest option.Sample Travel Date:November 4th - 11thThis is just	A good sale to Ho Chi Minh City\r\nVietnam introduced a new e-Visa system take advantage of it. Its the cheapest option.\r\nSign up for our Real Time Newsletter to receive economy class deals for your ciΓÇª	https://www.theflightdeal.com/2026/10/01/korean-air-dallas-ho-chi-minh-vietnam-816-roundtrip-including-all-taxes/	Theflightdeal.com	The Flight Deal	2026-10-01 16:43:06	2026-10-02 18:40:05.339092	Positive	0.3745	["Taxes", "Real Time Newsletter"]	["Dallas", "Vietnam"]	["Ho Chi Minh", "Roundtrip", "Ho Chi Minh CityVietnam", "Ho Chi Minh City"]	0.8316	Positive	Positive	12	1	Society	0.5000	Korean Air: Dallas ΓÇô Ho Chi Minh, Vietnam. $816. Roundtrip, including all Taxes. A good sale to Ho Chi Minh CityVietnam introduced a new e-Visa system - take advantage of it. Its the cheapest option.Sample Travel Date:November 4th - 11thThis is just	79	["minh", "chi minh", "chi", "visa advantage", "option"]	24
28	SJ Fall Summit: Realigning Supply Chains with Modern Retail┬áDynamics	Maithili Shenoy, founder and managing partner of the La Naia Group, was the keynote speaker at the Sourcing Journal Fall Summit.	Retail executives often blame both internal and external pressures, such as tariffs, geopolitical conflict and rising freight costs and shrinking profits. While these challenges are real, the bigger ΓÇª	http://wwd.com/sourcing-journal/industry-news/maithili-shenoy-sourcing-journal-fall-summit-adjusting-supply-chains-1239301232/	WWD	Arthur Zaczkiewicz	2026-10-01 16:19:39	2026-10-02 18:40:05.339092	Neutral	0.0667	["SJ Fall Summit: Realigning Supply Chains", "Modern Retail┬áDynamics Maithili Shenoy", "the La Naia Group", "the Sourcing Journal Fall Summit"]	[]	[]	-0.1779	Negative	Negative	0	0	Economy	0.4000	SJ Fall Summit: Realigning Supply Chains with Modern Retail Dynamics. Maithili Shenoy, founder and managing partner of the La Naia Group, was the keynote speaker at the Sourcing Journal Fall Summit.	60	["summit", "retail", "managing", "supply", "group"]	25
29	Woman Shoots, Kills Alleged Intruder, Later Learned It Was Her Ex-Boyfriend	A Philadelphia woman shot and killed an alleged intruder around 5 a.m. Wednesday and recognized him as her ex-boyfriend once his mask was removed.\nThe post Woman Shoots, Kills Alleged Intruder, Later Learned It Was Her Ex-Boyfriend appeared first on Breitbart.	A Philadelphia woman shot and killed an alleged intruder around 5 a.m. Wednesday and recognized him as her ex-boyfriend once his mask was removed.\r\nABC 7 reported┬áthat the alleged intruder broke intoΓÇª	https://www.breitbart.com/2nd-amendment/2026/10/01/woman-shoots-kills-alleged-intruder-later-learned-it-was-her-ex-boyfriend/	Breitbart News	AWR Hawkins	2026-10-01 16:09:56	2026-10-02 18:40:05.339092	Neutral	-0.0650	["Kills Alleged Intruder,", "ABC 7"]	["Shoots", "Philadelphia", "Breitbart"]	[]	-0.9628	Negative	Negative	0	0	Society	1.0000	Woman Shoots, Kills Alleged Intruder, Later Learned It Was Her Ex-Boyfriend. A Philadelphia woman shot and killed an alleged intruder around 5 a.m. Wednesday and recognized him as her ex-boyfriend once his mask was removed.	85	["alleged intruder", "woman", "alleged", "learned", "wednesday"]	26
30	Media Insider: Simon Dallow a contender for RNZ?; Paul Goldsmith on media and Paul Henry; Katie BradfordΓÇÖs new assignment; New Air NZ agency	New Air NZ ad agency, Katie Bradford's new political assignment, Phil Gifford remembered.	He is in Fiji and didnt wish to comment yesterday. Hes also just completed an official gig as a group tour guide through Vietnam and Cambodia another role hes keen to build on.\r\nGiven his intellect aΓÇª	https://www.nzherald.co.nz/business/media-insider/media-insider-simon-dallow-a-contender-for-rnz-paul-goldsmith-on-media-and-paul-henry-katie-bradfords-new-assignment-new-air-nz-agency/premium/OQOMVMN7XBHXDATIBACYS5AWPA/	New Zealand Herald	Shayne Currie	2026-10-01 16:00:16	2026-10-02 18:40:05.339092	Positive	0.1091	["Media Insider", "RNZ", "New Air NZ"]	["Fiji", "Vietnam", "Cambodia"]	["Simon Dallow", "Paul Goldsmith", "Paul Henry", "Katie BradfordΓÇÖs", "Katie Bradford's", "Phil Gifford"]	0.5778	Positive	Positive	1	0	Politics	0.5000	Media Insider: Simon Dallow a contender for RNZ?; Paul Goldsmith on media and Paul Henry; Katie BradfordΓÇÖs new assignment; New Air NZ agency. New Air NZ ad agency, Katie Bradford's new political assignment, Phil Gifford remembered.	73	["agency", "media", "air"]	27
31	How to Build an Unforgettable Personal Brand | Chris Do | 148	Personal brand has become one of the biggest buzzwords in the creator world. Creators everywhere are launching offers, building funnels, and posting consistently, yet very few are creating something people actually remember. I sat down with Chris Do, Emmy awaΓÇª	Personal brand has become one of the biggest buzzwords in the creator world. Creators everywhere are launching offers, building funnels, and posting consistently, yet very few are creating something ΓÇª	https://nathanbarry.com/how-to-build-an-unforgettable-personal-brand-chris-do-148/	Nathanbarry.com	Nathan Barry	2026-10-01 16:00:00	2026-10-02 18:40:05.339092	Neutral	0.0687	["Unforgettable Personal Brand", "148 Personal"]	[]	["Chris"]	0.6934	Positive	Positive	0	0	General	0.0000	How to Build an Unforgettable Personal Brand | Chris Do | 148. Personal brand has become one of the biggest buzzwords in the creator world.	82	["offers", "build", "people", "biggest", "world"]	28
32	µá¬σ╝ÅΣ╝Üτñ╛ZOZO NEXTπÇüµû░Σ╗úΦí¿σÅûτ╖áσ╜╣CEOπü½σ▒▒τö░ Φ▓┤σ║╖πüîσ░▒Σ╗╗	[µá¬σ╝ÅΣ╝Üτñ╛ZOZO]\n[τö╗σâÅ:	ZOZO NEXT ZOZO NEXTZOZOR&amp;DZOZO NEW ZEALAND LIMITEDCEO 2026101CEO\r\nZOZO NEXTCEO\r\nZOZO NEXTZOZOZOZOMATRIX\r\nZOZO202412ZOZO NEW ZEALAND LIMITEDCEOR&amp;DZOZO NEXT\r\nZOZO NEXTCEO\r\n1974115\r\n197420004EC2ΓÇª	https://prtimes.jp/main/html/rd/p/000000605.000096287.html	Prtimes.jp		2026-10-01 15:40:02	2026-10-02 18:40:05.339092	Neutral	0.0682	[]	[]	[]	0.0000	Neutral	Neutral	0	0	General	0.0000	µá¬σ╝ÅΣ╝Üτñ╛ZOZO NEXTπÇüµû░Σ╗úΦí¿σÅûτ╖áσ╜╣CEOπü½σ▒▒τö░ Φ▓┤σ║╖πüîσ░▒Σ╗╗. [µá¬σ╝ÅΣ╝Üτñ╛ZOZO] [τö╗σâÅ:	26	["ceo"]	29
39	007 First Light gets free new DLC today, adding New Game Plus and Photo modes, new TacSim missions and more	James Bond game 007 First Light is getting free DLC today in an Extended Operations update. This adds much-asked-for features to the game - such as New Game Plus, a new harder difficulty mode, a photo mode - as well as more TacSim mission challenges and a couΓÇª	James Bond game 007 First Light is getting free DLC today in an Extended Operations update. This adds much-asked-for features to the game - such as New Game Plus, a new harder difficulty mode, a photΓÇª	https://www.eurogamer.net/007-james-bond-first-light-free-dlc	Eurogamer.net	Robert Purchese	2026-10-01 14:28:56	2026-10-02 18:40:05.339092	Neutral	0.0726	["DLC", "Extended Operations"]	[]	["Photo", "James Bond"]	0.8300	Positive	Positive	6	1	General	0.0000	007 First Light gets free new DLC today, adding New Game Plus and Photo modes, new TacSim missions and more. James Bond game 007 First Light is getting free DLC today in an Extended Operations update.	104	["game", "game plus", "light", "plus", "dlc"]	36
40	The ΓÇ£Thrilla in ManilaΓÇ¥ Anniversary: The Story of the Fight That Changed Ali and Frazier Forever	Today marks the 51st anniversary of the ΓÇ£Thrilla in Manila,ΓÇ¥ the Oct. 1, 1975, showdown between the late Muhammad Ali and Joe Frazier that became one of boxingΓÇÖs most brutal fights. But the fight wasnΓÇÖt just happening in the ring. Ali famously called Frazier ΓÇª	Boxer Muhammad Ali steps away from a punch thrown by boxer Joe Frazier during their heavyweight title fight at Madison Square Garden in 1971. Frazier became the undisputed heavyweight champ of the woΓÇª	https://www.theroot.com/the-thrilla-in-manila-anniversary-the-story-of-the-f-2000128712	The Root	Asheea Smith	2026-10-01 14:09:41	2026-10-02 18:40:05.339092	Neutral	-0.0438	[]	["Manila"]	["Ali", "Muhammad Ali", "Joe Frazier", "Boxer Muhammad Ali"]	-0.7984	Negative	Negative	0	0	General	0.0000	The ΓÇ£Thrilla in ManilaΓÇ¥ Anniversary: The Story of the Fight That Changed Ali and Frazier Forever. Today marks the 51st anniversary of the ΓÇ£Thrilla in Manila,ΓÇ¥ the Oct.	94	["frazier", "ali", "anniversary", "muhammad", "muhammad ali"]	37
41	Tom CruiseΓÇÖs 10 Best Weird Performances, Ranked	We rank Tom CruiseΓÇÖs best subversive performances, from villainous Collateral to prosthetic-heavy Tropic Thunder and the wild new Digger.	MINDS FAR MORE powerful than yours and ours have tried to figure out what drives Tom Cruise. For four decades, Thomas Cruise Mapother IV has been in the big leagues of Hollywood stars, a bankable vesΓÇª	https://www.menshealth.com/entertainment/a73960371/tom-cruise-best-weird-performances-movies-roles/	menshealth.com	Rory Doherty	2026-10-01 14:00:00	2026-10-02 18:40:05.339092	Positive	0.1836	["Collateral", "MINDS"]	["Hollywood"]	["Tom CruiseΓÇÖs", "Ranked We", "Tropic Thunder", "Tom Cruise", "Thomas Cruise"]	0.8237	Positive	Positive	0	0	Economy	0.5000	Tom CruiseΓÇÖs 10 Best Weird Performances, Ranked. We rank Tom CruiseΓÇÖs best subversive performances, from villainous Collateral to prosthetic-heavy Tropic Thunder and the wild new Digger.	62	["cruise", "best", "wild"]	38
42	Did John Wayne buy 1,200 foreclosed homes for homeless Vietnam veterans?	Posts claimed the late actor started buying houses for the veterans in 1950, years before the U.S. entered the conflict.	Claim:\r\nBetween 1950 and 1979, late actor John Wayne bought 1,200 foreclosed homes for homeless veterans of the Vietnam War.\r\nIn September 2026, a rumor spread that late actor John Wayne acquired 1,2ΓÇª	https://www.snopes.com//fact-check/john-wayne-homes-veterans/	Snopes.com	Anna Rascou├½t-Paz	2026-10-01 13:00:00	2026-10-02 18:40:05.339092	Negative	-0.3000	[]	["Vietnam", "U.S."]	["John Wayne"]	-0.7351	Negative	Negative	4	1	Society	0.3300	Did John Wayne buy 1,200 foreclosed homes for homeless Vietnam veterans?. Posts claimed the late actor started buying houses for the veterans in 1950, years before the U.S. entered the conflict.	64	["late"]	39
43	Up-and-down progress of voting rights in America has been shaped by these 10 key moments	The history of voting and elections in America doesnΓÇÖt follow a steady path toward progress or retreat. It is marked by intense struggles, monumental victories and devastating losses.	A group of voters lining up on May 3, 1966, outside the polling station in Peachtree, Ala., after the Voting Rights Act was passed the previous year. MPI/Getty Images\r\nAs the 2026 midterm elections aΓÇª	https://theconversation.com/up-and-down-progress-of-voting-rights-in-america-has-been-shaped-by-these-10-key-moments-292096	The Conversation Africa	Gibbs Knotts, Professor of Political Science, Coastal Carolina University, Christopher A. Cooper, Professor of Political Science & Public Affairs, Western Carolina University	2026-10-01 12:41:14	2026-10-02 18:40:05.339092	Neutral	-0.1000	[]	["America", "Peachtree", "Ala."]	[]	-0.4215	Negative	Negative	0	0	General	0.0000	Up-and-down progress of voting rights in America has been shaped by these 10 key moments. The history of voting and elections in America doesnΓÇÖt follow a steady path toward progress or retreat.	78	["america", "shaped", "history", "path", "key"]	40
44	A US high school student won gold at the International AI Olympiad; Team USA returned with 1 gold, 1 silver, and 2 honourable mentions	The 2026 International Artificial Intelligence Olympiad in Ljubljana, Slovenia saw Team USA leaving a mark with four skilled students who clinched both a gold and a silver medal. Two others earned honourable mentions, showcasing exceptional talent. With backiΓÇª	News \r\n World News \r\n US News \r\n A US high school student won gold at the International AI Olympiad; Team USA returned with 1 gold, 1 silver, and 2 honourable mentions</lΓÇª	https://timesofindia.indiatimes.com/world/us/a-us-high-school-student-won-gold-at-the-international-ai-olympiad-team-usa-returned-with-1-gold-1-silver-and-2-honourable-mentions/articleshow/134619105.cms	The Times of India	TOI World Desk	2026-10-01 12:34:12	2026-10-02 18:40:05.339092	Positive	0.1108	["the International AI Olympiad", "Team USA", "International Artificial Intelligence Olympiad", "backiΓÇª News \\r\\n World News \\r\\n US News"]	["US", "Ljubljana", "Slovenia"]	[]	0.9776	Positive	Positive	0	0	Society	0.5000	A US high school student won gold at the International AI Olympiad; Team USA returned with 1 gold, 1 silver, and 2 honourable mentions.	91	["gold", "gold silver", "silver", "team", "international"]	41
45	BrahMos missile system to see over USD 600 million exports, is benchmark for India's emerging export story: Defence Secretary	Defence secretary Rajesh Kumar Singh hailed the BrahMos cruise missile as India's emerging export story, with exports to cross $600 million. He pointed out the major export destinations of the missile and highlighted the weapon's performance during Operation ΓÇª	New Delhi: BrahMos is a benchmark for India's emerging export story with exports to cross USD 600 million, Defence Secretary Rajesh Kumar Singh has said and noted that there are contracts or agreemenΓÇª	https://economictimes.indiatimes.com/news/defence/brahmos-missile-system-to-see-over-usd-600-million-exports-is-benchmark-for-indias-emerging-export-story-defence-secretary/articleshow/134618937.cms	The Times of India	ANI	2026-10-01 12:26:59	2026-10-02 18:40:05.339092	Neutral	0.0497	["BrahMos", "Defence"]	["India", "New Delhi"]	["Defence", "Rajesh Kumar Singh"]	0.4767	Positive	Positive	0	0	Economy	0.3300	BrahMos missile system to see over USD 600 million exports, is benchmark for India's emerging export story: Defence Secretary.	91	["export", "india emerging", "exports", "secretary", "emerging"]	42
46	India at Asiad: Silver medals in sailing and wrestling; Gold in sight in cricket, hockey	India's participation in the Asian Games saw notable silver medals in sailing by Prince Kurisinkal Noble and Manu Francis. The men's wrestling team also earned silver through Nitesh Siwach, adding to the medal tally. In cricket, the team, led by Shreyas Iyer,ΓÇª	Nagoya: Rare silver medals in skiff sailing and greco roman wrestling were the high points for India while the country's defending champion men's teams in cricket and hockey moved into the finals witΓÇª	https://economictimes.indiatimes.com/news/sports/other-sports/india-shines-at-asiad-with-silver-in-sailing-and-wrestling-eyes-gold-in-cricket-and-hockey-final/articleshow/134618949.cms	The Times of India	PTI	2026-10-01 12:22:50	2026-10-02 18:40:05.339092	Positive	0.3120	["Prince Kurisinkal Noble", "Nitesh Siwach"]	["India"]	["Manu Francis", "Shreyas Iyer", "Nagoya"]	0.8750	Positive	Positive	0	0	Society	0.3300	India at Asiad: Silver medals in sailing and wrestling; Gold in sight in cricket, hockey. India's participation in the Asian Games saw notable silver medals in sailing by Prince Kurisinkal Noble and Manu Francis.	90	["silver", "medals", "sailing", "cricket", "wrestling"]	43
47	India's Asian Games Success: Medals Across Sports, Teams In Finals	India's medal tally at the Asian Games surged to 65, highlighted by rare silver medals in men's skiff sailing and Greco-Roman wrestling. The men's cricket and hockey teams secured their spots in the finals with impressive victories, while squash teams and comΓÇª	India's athletes shine at the Asian Games, securing rare silver medals in sailing and wrestling, advancing to cricket and hockey finals, and adding multiple bronzes to boost the nation's overall medaΓÇª	https://www.rediff.com/sports/report/india-shines-at-asian-games-with-silvers-gold-in-sight/20261001.htm	Rediff.com	sports@rediff.co.in (Ajai Masand, Philem Dipak Singh)	2026-10-01 12:01:49	2026-10-02 18:40:05.339092	Positive	0.2111	["Asian Games Success", "Teams In Finals India's"]	["India"]	["Greco-Roman"]	0.9501	Positive	Positive	0	0	Sports	0.7500	India's Asian Games Success: Medals Across Sports, Teams In Finals. India's medal tally at the Asian Games surged to 65, highlighted by rare silver medals in men's skiff sailing and Greco-Roman wrestling.	83	["medals", "asian games", "men", "games", "asian"]	44
48	Second Chances	My friend the bon vivant bookseller Michael Seidenberg of Brazenhead Books, which he ran out of his apartment in New York City, died in 2019. IΓÇÖd known him since 1978, when as a teenager I apprenticed myself to his first shop. Michael loved pressing ΓÇ£lostΓÇ¥ boΓÇª	My friend the bon vivant bookseller Michael Seidenberg of Brazenhead Books, which he ran out of his apartment in New York City, died in 2019. IΓÇÖd known him since 1978, when as a teenager I apprenticeΓÇª	https://www.nybooks.com/articles/2026/10/22/second-chances-office-politics-wilfrid-sheed/	The New York Review of Books	Jonathan Lethem	2026-10-01 12:00:00	2026-10-02 18:40:05.339092	Positive	0.2445	[]	["New York City"]	["Michael Seidenberg", "Michael"]	0.5994	Positive	Positive	0	0	Society	1.0000	Second Chances. My friend the bon vivant bookseller Michael Seidenberg of Brazenhead Books, which he ran out of his apartment in New York City, died in 2019. IΓÇÖd known him since 1978, when as a teenager I apprenticed myself to his first shop.	84	["york", "city"]	45
49	How Tech Rules	One of the hallmarks of the modern corporation is the separation of ownership from control. The firm is owned by shareholders but led by managers, who answer to shareholders only indirectly. Actually, itΓÇÖs weirder than that. The corporation owns itself. ShareΓÇª	One of the hallmarks of the modern corporation is the separation of ownership from control. The firm is owned by shareholders but led by managers, who answer to shareholders only indirectly. ActuallyΓÇª	https://www.nybooks.com/articles/2026/10/22/how-tech-rules-silicon-empires-srnicek/	The New York Review of Books	Ben Tarnoff	2026-10-01 12:00:00	2026-10-02 18:40:05.339092	Neutral	0.0000	[]	[]	[]	-0.1901	Negative	Negative	0	0	General	0.0000	How Tech Rules. One of the hallmarks of the modern corporation is the separation of ownership from control. The firm is owned by shareholders but led by managers, who answer to shareholders only indirectly. Actually, itΓÇÖs weirder than that.	76	["corporation", "rules", "led"]	46
50	Think TrumpΓÇÖs $1.5 Trillion Pentagon Request Is Outrageous? ThisΓÇÖll Blow Your Mind.	On April 3, four weeks after Donald Trump claimed the Iran War would be over in four to five weeks, and with his approval ratings in reputable polls dipping below 40 percent, the president made a wildly audacious ask: Congress, he said, should approve a PentaΓÇª	Mother Jones illustration; Getty\r\nGet your news from a source thats not owned and controlled by oligarchs. Sign up for the free Mother Jones Daily.\r\nOn April 3, four weeks after Donald Trump claimed ΓÇª	https://www.motherjones.com/politics/2026/10/donald-trump-pete-hegseth-pentagon-budget-request-trillion-department-war-true-cost-military-spending/	Mother Jones	David Vine	2026-10-01 11:30:00	2026-10-02 18:40:05.339092	Neutral	0.0000	["Congress"]	["Penta"]	["Donald Trump", "Getty\\r\\nGet"]	0.1027	Positive	Neutral	0	0	Technology	1.0000	Think TrumpΓÇÖs $1.5 Trillion Pentagon Request Is Outrageous? ThisΓÇÖll Blow Your Mind..	93	["weeks", "trump", "pentagon", "trillion", "president"]	47
51	Pandora opens $150 million Vietnam jewelry factory powered by renewable energy	Pandora has opened the worldΓÇÖs largest fine-jewelry crafting facility in Vietnam, powered entirely by renewable electricity and using 100% recycled gold and silver	Pandora has opened the worlds largest fine-jewelry crafting facility in Vietnam, powered entirely by renewable electricity and using 100% recycled gold and silver\r\nThis story appeared on abcnews.com,ΓÇª	https://biztoc.com/x/3a7753ba1982231a	Biztoc.com	abcnews.com	2026-10-01 11:02:24	2026-10-02 18:40:05.339092	Neutral	0.0000	[]	["Vietnam", "Pandora"]	[]	0.2732	Positive	Positive	6	1	Environment	1.0000	Pandora opens $150 million Vietnam jewelry factory powered by renewable energy. Pandora has opened the worldΓÇÖs largest fine-jewelry crafting facility in Vietnam, powered entirely by renewable electricity and using 100% recycled gold and silver	62	["renewable", "powered", "jewelry", "pandora", "gold silver"]	48
52	Pandora opens $150 million Vietnam jewelry factory powered by renewable energy	Pandora has opened the worldΓÇÖs largest fine-jewelry crafting facility in Vietnam, powered entirely by renewable electricity and using 100% recycled gold and silver	HO CHI MINH CITY, Vietnam -- Danish jewelry company Pandora has opened the worlds largest fine-jewelry crafting facility in Vietnam, a $150 million factory powered entirely by renewable electricity aΓÇª	https://abcnews.com/Business/wireStory/pandora-opens-150-million-vietnam-jewelry-factory-powered-136913568	Abcnews.com	HAU DINH Associated Press, ANIRUDDHA GHOSAL Associated Press	2026-10-01 10:53:15	2026-10-02 18:40:05.339092	Neutral	0.0000	[]	["Vietnam", "Pandora"]	[]	0.2732	Positive	Positive	7	1	Environment	1.0000	Pandora opens $150 million Vietnam jewelry factory powered by renewable energy. Pandora has opened the worldΓÇÖs largest fine-jewelry crafting facility in Vietnam, powered entirely by renewable electricity and using 100% recycled gold and silver	64	["renewable", "powered", "jewelry", "pandora", "gold silver"]	48
53	ALL Accor+ Explorer Sign Up Promo With 3,000 Bonus Points October 1 ΓÇô 31, 2026	Accor PlusΓÇÖs updated pricing went live today (prices went up slightly + corrected currency fluctuation changes since the last ΓÇ£calibrationΓÇ¥), and there is a new sign-up promo that is valid until the end of the month. ALL Accor+ Explorer sign-ups will come witΓÇª	Accor PlusΓÇÖs updated pricing went live today (prices went up slightly + corrected currency fluctuation changes since the last ΓÇ£calibrationΓÇ¥), and there is a new sign-up promo that is valid until the ΓÇª	https://loyaltylobby.com/2026/10/01/all-accor-explorer-sign-up-promo-with-3000-bonus-points-october-1-31-2026/	Loyaltylobby.com	John Ollila	2026-10-01 10:39:54	2026-10-02 18:40:05.339092	Neutral	0.0265	["Bonus"]	[]	[]	0.5423	Positive	Positive	0	0	Economy	1.0000	ALL Accor+ Explorer Sign Up Promo With 3,000 Bonus Points October 1 ΓÇô 31, 2026.	91	["sign", "plus", "end", "come", "live"]	49
54	Iran War: The Narrative War Continues to Confuse and Confuddle	America has narrative dominance over the Strait, but does that translate into diesel at pumps around the world?	This is Naked Capitalism fundraising week. 1042 donors have already invested in our efforts to combat corruption and predatory conduct, particularly in the financial realm. Please join us and particiΓÇª	https://www.nakedcapitalism.com/2026/10/iran-war-the-narrative-war-continues-amidst-false-flags-and-big-explosions.html	Nakedcapitalism.com	Nat Wilson Turner	2026-10-01 10:05:06	2026-10-02 18:40:05.339092	Neutral	0.0556	[]	[]	[]	-0.3182	Negative	Negative	0	0	Society	0.5000	Iran War: The Narrative War Continues to Confuse and Confuddle. America has narrative dominance over the Strait, but does that translate into diesel at pumps around the world?	58	["narrative", "war", "does", "iran war", "iran"]	50
55	Vietnam Ha Long Bay week at 5Γ¡É∩╕Å hotel + flights UNDER ┬ú500	Ha Long Bay is one of those places that looks almost unreal in photos -- thousands of jagged limestone islands rising out of turquoise water -- and somehow it's even better in person.This seven-night stay puts you at a 5-star Hyatt Place with a swimming pool ΓÇª	We might be pirates, but were an honest bunch. We check all our deals when we review them to make sure everything is available. However, with deals this hot, things change quickly flight prices fluctΓÇª	https://www.holidaypirates.com/packages/hyatt-place-ha-long-bay-bai-chay-vietnam	Holidaypirates.com	Tilly	2026-10-01 10:00:01	2026-10-02 18:40:05.339092	Positive	0.3104	[]	[]	["Vietnam Ha Long Bay", "Hyatt Place"]	0.8945	Positive	Positive	10	1	Technology	1.0000	Vietnam Ha Long Bay week at 5Γ¡É∩╕Å hotel + flights UNDER ┬ú500.	94	["long", "places", "seven", "hotel", "flights"]	51
56	iPhone Duo Launch This Month:┬á8 Tips to Make Sure You Get One	Apple unveiled the iPhone Duo on September 9 at the company's "Surprise and Shine" event. Apple's first foldable is the biggest...	Apple unveiled the iPhone Duo on September 9 at the company's "Surprise and Shine" event. Apple's first foldable is the biggest shake-up of the iPhone design in almost a decade, and it's sure to be oΓÇª	https://www.macrumors.com/how-to/iphone-duo-launch-this-month-how-to-get-one/	MacRumors	Tim Hardwick	2026-10-01 09:36:00	2026-10-02 18:40:05.339092	Positive	0.3750	["Apple", "the iPhone Duo", "iPhone"]	[]	["Shine"]	0.7783	Positive	Positive	6	1	General	0.0000	iPhone Duo Launch This Month: 8 Tips to Make Sure You Get One. Apple unveiled the iPhone Duo on September 9 at the company's "Surprise and Shine" event. Apple's first foldable is the biggest...	70	["september", "biggest", "make", "company"]	52
57	ΓÇÿI Know I CouldnΓÇÖt Live HereΓÇÖ: Standing Up to a Data Center in AlabamaΓÇÖs Black Belt	Faced with little transparency about a mammoth facility, Lowndes County fights back.\nThe post ΓÇÿI Know I CouldnΓÇÖt Live HereΓÇÖ: Standing Up to a Data Center in AlabamaΓÇÖs Black Belt appeared first on The American Prospect.	Lowndes County is rural and impoverished, and its scars are in plain view. Residents have been plagued with a decades-old raw sewage crisis so horrible that a United Nations special representative trΓÇª	https://prospect.org/2026/10/01/data-center-alabama-lowndes-county-black-belt-cloverleaf-infrastructure-project-red-clay/	The American Prospect	Naomi Bethune and James Baratta	2026-10-01 09:30:00	2026-10-02 18:40:05.339092	Neutral	-0.0857	["a Data Center", "The American Prospect", "United Nations"]	["Alabama", "Lowndes County"]	[]	-0.6799	Negative	Negative	0	0	Technology	1.0000	ΓÇÿI Know I CouldnΓÇÖt Live HereΓÇÖ: Standing Up to a Data Center in AlabamaΓÇÖs Black Belt. Faced with little transparency about a mammoth facility, Lowndes County fights back.	84	["center", "live", "data", "fights", "facility"]	53
58	5 Book Reviews You Need to Read This Week	Our five-alarm fire of fabulous reviews this week includes Andrew Martin on Patrick deWittΓÇÖs┬áDodge City, Zito Madu on Chuck KlostermanΓÇÖs┬áFootball, A.O. Scott on Ayad AkhtarΓÇÖs┬áThe Radiance, Emma Hager on Devyn DefoeΓÇÖs┬áBurnside, and Melissa Harrison on Rebecca ΓÇª	Our five-alarm fire of fabulous reviews this week includes Andrew Martin on Patrick deWitts┬áDodge City, Zito Madu on Chuck Klostermans┬áFootball, A.O. Scott on Ayad Akhtars┬áThe Radiance, Emma Hager onΓÇª	https://lithub.com/5-book-reviews-you-need-to-read-this-week-17/	Lithub.com	Book Marks	2026-10-01 09:08:31	2026-10-02 18:40:05.339092	Positive	0.4000	["Patrick deWittΓÇÖs", "A.O. Scott"]	["Dodge City", "Rebecca"]	["Andrew Martin", "Zito Madu", "Chuck KlostermanΓÇÖs", "Emma Hager", "Devyn DefoeΓÇÖs", "Melissa Harrison", "Patrick deWitts", "Chuck Klostermans"]	0.7783	Positive	Positive	0	0	Society	0.5000	5 Book Reviews You Need to Read This Week. Our five-alarm fire of fabulous reviews this week includes Andrew Martin on Patrick deWittΓÇÖs Dodge City, Zito Madu on Chuck KlostermanΓÇÖs Football, A.O.	82	["reviews", "includes", "need", "read", "city"]	54
59	On Being Awarded the Women Waging Peace Award	Katrina vanden Heuvel\n\nIt has never been more urgent to revive the idea of peace, not as a slogan, but as the only serious, respectable, responsible, reasonable, humane position.\r\n\n\r\n\nThe post On Being Awarded the Women Waging Peace Award appeared first onΓÇª	Activism / October 1, 2026\r\nIt has never been more urgent to revive the idea of peace, not as a slogan, but as the only serious, respectable, responsible, reasonable, humane position.\r\nAd Policy\r\nAn ΓÇª	https://www.thenation.com/?post_type=article&p=611090	Thenation.com	Katrina vanden Heuvel	2026-10-01 09:00:00	2026-10-02 18:40:05.339092	Positive	0.1833	["Being Awarded the Women Waging Peace"]	[]	[]	0.9911	Positive	Positive	0	0	Politics	1.0000	On Being Awarded the Women Waging Peace Award. Katrina vanden Heuvel It has never been more urgent to revive the idea of peace, not as a slogan, but as the only serious, respectable, responsible, reasonable, humane position.	85	["peace", "women", "award", "appeared", "post"]	55
60	Pandora opens world's biggest jewellery plant in Vietnam	Danish jewellery maker Pandora has today opened a $150m factory in Ho Chi Minh City, its largest manufacturing facility and its first production site outside Thailand.	Danish jewellery maker Pandora has today opened a $150m factory in Ho Chi Minh City, its largest manufacturing facility and its first production site outside Thailand as it bids to diversify its manuΓÇª	https://www.rte.ie/news/business/2026/1001/1593610-pandora-opens-worlds-biggest-jewellery-plant-in-vietnam/	RTE	RT├ë News	2026-10-01 08:42:39	2026-10-02 18:40:05.339092	Positive	0.1250	[]	["Pandora", "Vietnam", "Ho Chi Minh City", "Thailand"]	[]	0.0000	Neutral	Neutral	6	1	Economy	0.5000	Pandora opens world's biggest jewellery plant in Vietnam. Danish jewellery maker Pandora has today opened a $150m factory in Ho Chi Minh City, its largest manufacturing facility and its first production site outside Thailand.	67	["pandora", "plant", "opened", "pandora opens", "biggest"]	56
61	PC and console revenue charts led by new releases in August | Newzoo charts	Several new releases entered Newzoo's Top 20 revenue charts in August, with EA Sports Madden NFL 27 debuting at No. 2 on console and House House's co-op title Big Walk ranking No. 3 on PC. Read more	Several new releases entered Newzoo's Top 20 revenue charts in August, with EA Sports Madden NFL 27 debuting at No. 2 on console and House House's co-op title Big Walk ranking No. 3 on PC.\r\nRespawn EΓÇª	https://www.gamesindustry.biz/pc-and-console-revenue-charts-led-by-new-releases-in-august-newzoo-charts	GamesIndustry.biz	Sophie McEvoy	2026-10-01 08:25:00	2026-10-02 18:40:05.339092	Positive	0.1909	["EA Sports Madden", "NFL", "House House's", "Big Walk"]	[]	["Newzoo"]	0.3818	Positive	Positive	0	0	Economy	0.3300	PC and console revenue charts led by new releases in August | Newzoo charts. Several new releases entered Newzoo's Top 20 revenue charts in August, with EA Sports Madden NFL 27 debuting at No.	88	["charts", "revenue", "august", "house", "sports"]	57
67	Development ΓÇ£off the chartsΓÇ¥: Vibe coding brings major benefits and new challenges to a public sector organisation	Thanks to AI tools such as Claude Code, IT development lead times at the Danish Environmental Portal have dropped from weeks to days. At the same time, this rapid pace of development is forcing management to rethink budgets and quality assurance procedures.	Whereas there used to be a waiting period from a development idea appearing on paper and the delivery of finished software, the situation is now completely different at the Danish Environment Portal.ΓÇª	https://ing.dk/artikel/development-charts-vibe-coding-brings-major-benefits-and-new-challenges-public-sector-organisation	Ing.dk	Rasmus Jessen Ginman	2026-10-01 06:43:00	2026-10-02 18:40:05.339092	Neutral	0.0570	["the Danish Environmental Portal", "the Danish Environment Portal"]	["AI"]	["Claude Code"]	0.8173	Positive	Positive	0	0	Technology	0.5000	Development ΓÇ£off the chartsΓÇ¥: Vibe coding brings major benefits and new challenges to a public sector organisation. Thanks to AI tools such as Claude Code, IT development lead times at the Danish Environmental Portal have dropped from weeks to days.	91	["development", "charts", "weeks", "days", "challenges"]	58
100	Ledger asks resellers to halt sales in Southeast Asia and Hong Kong	Ledger has asked resellers in six Southeast Asian countries and Hong Kong to suspend hardware wallet sales as it investigates reports of tampered devices.	Ledger has requested sellers and distributors of its devices in six Southeast Asian countries and Hong Kong to suspend sales and remove its hardware wallets from shelves as it investigates reports ofΓÇª	https://cointelegraph.com/news/ledger-asks-resellers-to-halt-sales-in-southeast-asia-and-hong-kong	Cointelegraph	Cointelegraph by Felix Ng	2026-10-13 23:28:19	2026-10-14 01:04:46.97239	Neutral	0.0000	[]	["Hong Kong"]	[]	-0.5574	Negative	Negative	0	0	Technology	1.0000	Ledger asks resellers to halt sales in Southeast Asia and Hong Kong. Ledger has asked resellers in six Southeast Asian countries and Hong Kong to suspend hardware wallet sales as it investigates reports of tampered devices.	68	["resellers", "sales", "ledger", "kong", "hong kong"]	59
101	The path I wish IΓÇÖd taken (GregΓÇÖs Wild Card Journal)	IΓÇÖm not particularly proud of the Wild Card trip I planned. I mean, there were definitely great parts. I stayed in fantastic hotels and creatively used Bonvoy points to book a great United flight at a great value. Other than that one big United flight, thoughΓÇª	IΓÇÖm not particularly proud of the Wild Card trip I planned. I mean, there were definitely great parts. I stayed in fantastic hotels and creatively used Bonvoy points to book a great United flight at ΓÇª	https://frequentmiler.com/the-path-i-wish-id-taken-gregs-wild-card-journal/	Frequentmiler.com	Greg The Frequent Miler	2026-10-13 22:45:31	2026-10-14 01:04:46.97239	Positive	0.2528	["United"]	[]	["Bonvoy"]	0.9928	Positive	Positive	0	0	Society	1.0000	The path I wish IΓÇÖd taken (GregΓÇÖs Wild Card Journal). IΓÇÖm not particularly proud of the Wild Card trip I planned. I mean, there were definitely great parts.	92	["great", "flight", "wild", "united", "hotels"]	60
102	Vietnamese American Business Association (VABA) Marks 15 Years of Uniting Entrepreneurs Under "Speak with One Voice"	Founded by David Duong in Silicon Valley, the Vietnamese American Business Association connects business owners through support, advocacy, investment relationships and community service in the United States and abroad. OAKLAND, Calif., Oct. 13, 2026 /PRNewswiΓÇª	Founded by David Duong in Silicon Valley, the Vietnamese American Business Association connects business owners through support, advocacy, investment relationships and community service in the UnitedΓÇª	https://www.prnewswire.com/news-releases/vietnamese-american-business-association-vaba-marks-15-years-of-uniting-entrepreneurs-under-speak-with-one-voice-302907679.html	PRNewswire		2026-10-13 22:12:00	2026-10-14 01:04:46.97239	Neutral	0.0000	["Vietnamese American Business Association", "VABA", "the Vietnamese American Business Association", "United"]	["the United States", "OAKLAND", "Calif."]	["Founded", "David Duong"]	0.8020	Positive	Positive	6	1	Economy	0.3300	Vietnamese American Business Association (VABA) Marks 15 Years of Uniting Entrepreneurs Under "Speak with One Voice".	77	["business", "association", "american", "united states", "service"]	61
103	The Inner Circle acknowledges Dr. Howard Anderson, as a Pinnacle Professional Member Inner Circle of Excellence	SAN ANTONIO, Oct. 13, 2026 /PRNewswire/ -- Prominently featured in The Inner Circle, Dr. Howard Anderson is acknowledged as a Pinnacle Professional Member Inner Circle of Excellence for his contributions to Leadership in Ministry, Consulting, and Community SeΓÇª	SAN ANTONIO, Oct. 13, 2026 /PRNewswire/ -- Prominently featured in The Inner Circle, Dr. Howard Anderson is acknowledged as a Pinnacle Professional Member Inner Circle of Excellence for his contributΓÇª	https://www.prnewswire.com/news-releases/the-inner-circle-acknowledges-dr-howard-anderson-as-a-pinnacle-professional-member-inner-circle-of-excellence-302907456.html	PRNewswire		2026-10-13 19:36:00	2026-10-14 01:04:46.97239	Positive	0.1182	["Pinnacle Professional", "Excellence SAN ANTONIO", "Consulting"]	["SAN ANTONIO"]	["Howard Anderson", "Inner Circle", "Community Se"]	0.9231	Positive	Positive	0	0	Society	1.0000	The Inner Circle acknowledges Dr. Howard Anderson, as a Pinnacle Professional Member Inner Circle of Excellence. SAN ANTONIO, Oct. 13, 2026 /PRNewswire/ -- Prominently featured in The Inner Circle, Dr.	84	["inner circle", "inner", "circle", "prnewswire", "oct prnewswire"]	62
104	Milk Cans? Cannons? Ranking The Best Mountain West, PAC-12 Rivalry Trophies	Where does the Milk Can trophy rank among the MW/Pac rivalry trophies? The Boise State Broncos left California with more than a victory. A Milk Can. Yep, the Broncos won the Milk Jug over Fresno State for the first time since 2022, potentially becoming one ofΓÇª	Where does the Milk Can trophy rank among the MW/Pac rivalry trophies?\r\nThe Boise State Broncos left California with more than a victory.\r\nA Milk Can.\r\nYep, the Broncos won the Milk Jug over Fresno SΓÇª	https://www.mwcconnection.com/mountain-west-discussion/94171/milk-cans-cannons-ranking-the-best-mountain-west-pac-12-rivalry-trophies	Mwcconnection.com	Dan Allison	2026-10-13 19:00:00	2026-10-14 01:04:46.97239	Positive	0.1222	["MW/Pac", "Fresno State", "Fresno S"]	["California"]	["Broncos"]	0.9514	Positive	Positive	0	0	Technology	1.0000	Milk Cans? Cannons? Ranking The Best Mountain West, PAC-12 Rivalry Trophies. Where does the Milk Can trophy rank among the MW/Pac rivalry trophies? The Boise State Broncos left California with more than a victory. A Milk Can.	93	["milk", "state", "victory", "does", "won"]	63
105	At 92, Cecil Calhoun still walks the course that shaped his legacy	For nearly a century, Cecil Calhoun has shaped the Country Club of Columbus and helped bring the Haskins Intercollegiate to life.	COLUMBUS, Ga. Cecil Calhoun's golf seat stick left small indentations in the putting green as he moved around to watch the action Monday at the Country Club of Columbus. Calhoun was using it more as ΓÇª	https://golfweek.usatoday.com/story/sports/golf/college/2026/10/13/haskins-intercollegiate-cecil-calhoun-country-club-of-columbus/92230420007/	USA Today	Cameron Jourdan, Golfweek	2026-10-13 18:57:59	2026-10-14 01:04:46.97239	Neutral	0.0417	["the Country Club"]	["Columbus", "COLUMBUS", "Ga."]	["Calhoun"]	0.0000	Neutral	Neutral	0	0	Environment	1.0000	At 92, Cecil Calhoun still walks the course that shaped his legacy. For nearly a century, Cecil Calhoun has shaped the Country Club of Columbus and helped bring the Haskins Intercollegiate to life.	69	["shaped", "life", "country", "nearly"]	64
106	Yue YuenΓÇÖs Footwear Shipments Show Positive Momentum in┬áSeptember	Yue Yuen's shoe manufacturing revenue in September rose 6.6 percent year-over-year.	Footwear shipments rose in September for shoe manufacturer Yue Yuen, a sign of improvement for the operation. \r\nThe company said that its manufacturing revenues rose 6.6 percent on a year-over-year bΓÇª	http://wwd.com/footwear-news/shoe-industry-news/yue-yuen-shoe-manufacturing-revenue-september-2026-1239345088/	WWD	Vicki M. Young	2026-10-13 18:40:49	2026-10-14 01:04:46.97239	Positive	0.5068	[]	[]	["Yue YuenΓÇÖs Footwear", "Yue Yuen's", "Yue Yuen"]	0.7650	Positive	Positive	0	0	Economy	0.6700	Yue YuenΓÇÖs Footwear Shipments Show Positive Momentum in September. Yue Yuen's shoe manufacturing revenue in September rose 6.6 percent year-over-year.	51	["september", "revenue", "shipments", "manufacturing"]	65
107	Coffee Break: Armed Madhouse ΓÇô The Phantom Limb of Decisive Warfare: Reaching for Catastrophic Victory	The nuclear revolution transformed the conditions of great-power warfare, yet military institutions continue to pursue decisive conventional victory. The phantom limb of traditional warfare survives through cultural admiration for martial courage and institutΓÇª	In medicine, a phantom limb is the persistent sensation of an amputated arm or leg. The missing limb may still seem to occupy its accustomed position, move, or experience pain. These sensations ariseΓÇª	https://www.nakedcapitalism.com/2026/10/coffee-break-armed-madhouse-the-phantom-limb-of-decisive-warfare-reaching-for-catastrophic-victory.html	Nakedcapitalism.com	Haig Hovaness	2026-10-13 18:00:19	2026-10-14 01:04:46.97239	Neutral	-0.0571	[]	[]	[]	-0.4588	Negative	Negative	0	0	Society	0.3300	Coffee Break: Armed Madhouse ΓÇô The Phantom Limb of Decisive Warfare: Reaching for Catastrophic Victory.	81	["warfare", "victory", "armed", "power", "military"]	66
115	The dual burden of disease: Depression among patients with multidrug resistance tuberculosis in low-income and lower- middle-income countries: A systematic review and meta-analysis	Introduction Multidrug-Resistant Tuberculosis (MDR-TB) continues to pose a serious global health challenge, particularly in low-income and lower-middle-income countries where the disease burden, fragile health systems, and socioeconomic hardships are most proΓÇª	Citation: Abate AW, Tedla A, Wubet GM, Legas G, Belete A, Shiferaw K, et al. (2026) The dual burden of disease: Depression among patients with multidrug resistance tuberculosis in low-income and loweΓÇª	https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0360738	Plos.org	Agmas Wasie Abate, Assasahegn Tedla, Gashaw Mehiret Wubet, Getasew Legas, Amsalu Belete, Kirubel Shiferaw, Getnet Mihretie Beyene, Assefa Agegnehu Teshome, Wondimnew Desalegn Addis, Melaku Mekonnen Agidew, Samuel Berihun Dagnew, Belete Asnake Sitotaw, Birhanu Mengist Munie	2026-10-13 14:00:00	2026-10-14 01:04:46.97239	Neutral	0.0667	["Introduction Multidrug-Resistant Tuberculosis", "MDR-TB", "Belete A", "Shiferaw K"]	[]	["Wubet GM", "Legas G", "al"]	-0.9538	Negative	Negative	0	0	Healthcare	0.6000	The dual burden of disease: Depression among patients with multidrug resistance tuberculosis in low-income and lower- middle-income countries: A systematic review and meta-analysis.	86	["income", "middle", "countries", "review", "global"]	74
116	Murphy Announces New Startups, Exploration Success	Murphy Oil began production at two projects in the United States Gulf of America and Vietnam, as well as made another discovery in the Southeast Asian country and successfully appraised an Ivorian discovery.	Murphy Oil Corp has begun production at two projects in the United States Gulf of America and Vietnam, as well as made another discovery in the Southeast Asian country and successfully appraised an IΓÇª	https://www.rigzone.com/news/murphy_announces_new_startups_exploration_success-13-oct-2026-184835-article/	Rigzone	Jov Onsat	2026-10-13 13:57:03	2026-10-14 01:04:46.97239	Positive	0.3227	["Murphy Announces New Startups", "Murphy Oil Corp"]	["the United States", "Vietnam"]	[]	0.9628	Positive	Positive	3	1	Technology	0.6700	Murphy Announces New Startups, Exploration Success.	73	["united states", "states", "southeast asian", "production", "united"]	75
117	Chicago Police Department Solves 65-Year-Old Cold Case: Finds One of Their Own Was the Murderer	The Chicago Police Department has solved a 65-year-old cold case regarding the death of┬áGloria Kowalewicz, an eight-year-old who was killed was while walking from her house to church on November 12, 1960.\nThe post Chicago Police Department Solves 65-Year-Old ΓÇª	The Chicago Police Department has solved a 65-year-old cold case regarding the death of┬áGloria Kowalewicz, an eight-year-old who was killed was while walking from her house to church on November 12, ΓÇª	https://www.breitbart.com/crime/2026/10/13/chicago-police-department-solves-65-year-old-cold-case-finds-one-of-their-own-was-the-murderer/	Breitbart News	AWR Hawkins	2026-10-13 13:51:24	2026-10-14 01:04:46.97239	Negative	-0.2667	["Chicago Police Department", "The Chicago Police Department"]	[]	["Gloria Kowalewicz"]	-0.9517	Negative	Negative	0	0	Society	0.5000	Chicago Police Department Solves 65-Year-Old Cold Case: Finds One of Their Own Was the Murderer.	89	["old", "chicago police", "chicago", "department", "police"]	76
118	A History of Taiwan and BeijingΓÇÖs Influence There	The territory most commonly known as Taiwan, an island area, is situated at its closest 81 miles from the coast of south-eastern China. Almost 14,000 square miles in size, Taiwan is by no means large but it is still bigger ΓÇª\nThe post A History of Taiwan and BΓÇª	The territory most commonly known as Taiwan, an island area, is situated at its closest 81 miles from the coast of south-eastern China. Almost 14,000 square miles in size, Taiwan is by no means largeΓÇª	https://www.globalresearch.ca/history-taiwan-beijing-influence/5943679	Globalresearch.ca	Shane Quinn	2026-10-13 13:47:27	2026-10-14 01:04:46.97239	Positive	0.1024	["BeijingΓÇÖs Influence"]	["Taiwan", "China"]	[]	-0.5267	Negative	Negative	0	0	Technology	1.0000	A History of Taiwan and BeijingΓÇÖs Influence There. The territory most commonly known as Taiwan, an island area, is situated at its closest 81 miles from the coast of south-eastern China.	92	["taiwan", "miles", "history", "island", "south"]	77
119	Super El Ni├▒o Could Ease AsiaΓÇÖs LNG Supply Concerns	The super El Ni├▒o is expected to raise the winter temperatures in South Korea, Japan, and parts of China, potentially easing the gas supply needs in these key Asian LNG importers and leaving more cargoes for Europe, which struggles to fill its gas storage sitΓÇª	Europe's grid is digitalizing fasterΓÇª\r\nU.S. sanctions continue to restrictΓÇª\r\nSet us as your preferred Google source\r\nBy Michael Kern - Oct 13, 2026, 8:30 AM CDTThe super El Ni├▒o is expected to raise ΓÇª	https://oilprice.com/Latest-Energy-News/World-News/Super-El-Nio-Could-Ease-Asias-LNG-Supply-Concerns.html	OilPrice.com	Michael Kern	2026-10-13 13:30:00	2026-10-14 01:04:46.97239	Positive	0.1444	["Super El Ni├▒o", "El Ni├▒o", "LNG", "Google"]	["South Korea", "Japan", "China", "U.S."]	["Michael Kern - Oct"]	0.9287	Positive	Positive	0	0	Technology	0.5000	Super El Ni├▒o Could Ease AsiaΓÇÖs LNG Supply Concerns.	89	["supply", "japan", "europe", "needs", "key"]	78
120	As Humanoid Robot Output Climbs Toward 100,000 Units, MES Inc. Outlines the Manufacturing Shift From Billet Machining to Volume Production	The Ohio-based sourcing and supply chain firm says the processes that carry a robot through prototyping won't carry it through volume, and the switch needs to be planned before production demand arrives COLUMBUS, Ohio, Oct. 13, 2026 /PRNewswire/ -- MES Inc., ΓÇª	The Ohio-based sourcing and supply chain firm says the processes that carry a robot through prototyping won't carry it through volume, and the switch needs to be planned before production demand arriΓÇª	https://www.prnewswire.com/news-releases/as-humanoid-robot-output-climbs-toward-100-000-units-mes-inc-outlines-the-manufacturing-shift-from-billet-machining-to-volume-production-302906626.html	PRNewswire		2026-10-13 13:30:00	2026-10-14 01:04:46.97239	Negative	-0.2000	["MES Inc."]	["Ohio", "COLUMBUS"]	[]	-0.2500	Negative	Negative	0	0	Economy	0.6700	As Humanoid Robot Output Climbs Toward 100,000 Units, MES Inc. Outlines the Manufacturing Shift From Billet Machining to Volume Production.	94	["volume", "production", "supply chain", "needs", "won"]	79
121	Tuesday: Hili dialogue	Welcome to The Cruelest Day, Tuesday, October 13, 2026 as well as National Yorkshire Pudding Day. I donΓÇÖt have a picture of this delectable treat, always served in England with the Sunday roast, but here are two plump puddings from Wikipedia as part of the whΓÇª	Welcome to The Cruelest Day, Tuesday, October 13, 2026 as well as National Yorkshire Pudding Day. I donΓÇÖt have a picture of this delectable treat, always served in England with the Sunday roast, but ΓÇª	https://whyevolutionistrue.com/2026/10/13/tuesday-hili-dialogue-601/	Whyevolutionistrue.com	whyevolutionistrue	2026-10-13 11:45:40	2026-10-14 01:04:46.97239	Positive	0.8000	["Wikipedia"]	["England"]	[]	0.9489	Positive	Positive	0	0	Society	1.0000	Tuesday: Hili dialogue. Welcome to The Cruelest Day, Tuesday, October 13, 2026 as well as National Yorkshire Pudding Day.	84	["sunday", "october"]	80
122	Why IndiaΓÇÖs factories struggle to keep up with the world	An Indian factory takes 23% longer to fill the same export order than a Vietnamese factory and pays for 18% more labour-hours to do it.	Regular work\r\nIndia does not allow any rearrangement of regular hours across days or weeks. In most countries, including India, the limit on regular hours in a day is 8, and in a week is between 44 aΓÇª	https://www.livemint.com/industry/india-factory-working-hours-rules-11791882358324.html	Livemint	mint	2026-10-13 11:26:30	2026-10-14 01:04:46.97239	Positive	0.1667	[]	["India"]	[]	-0.4526	Negative	Negative	2	0	Economy	1.0000	Why IndiaΓÇÖs factories struggle to keep up with the world. An Indian factory takes 23% longer to fill the same export order than a Vietnamese factory and pays for 18% more labour-hours to do it.	73	["factory", "export", "indian", "world", "india"]	81
123	The holiday destinations set to surge in 2027, form Northern Lights to Red Sea resorts - with return flights from less than ┬ú30	Forget the usual holiday hotspots - discover a futuristic Asian megacity, a crowd-free Italian coastal gem and a Greek island escape before the crowds arrive.	Every year, a handful of destinations begin to capture travellers imaginations, transforming from under-the-radar spots into the next big thing in travel.\r\nNow, Skyscanner has revealed its top trendiΓÇª	https://www.dailymail.com/travel/article-16196747/top-holiday-destinations-2027-skyscanner-trends.html	Dailymail.com	Erin Deborah Waks	2026-10-13 11:17:27	2026-10-14 01:04:46.97239	Neutral	0.0093	[]	[]	["Skyscanner"]	0.7402	Positive	Positive	0	0	Society	1.0000	The holiday destinations set to surge in 2027, form Northern Lights to Red Sea resorts - with return flights from less than ┬ú30.	77	["holiday", "sea", "return", "island", "form"]	82
124	Cashew Nutshell Liquid Market worth $979.8 million by 2031 - Exclusive Report by MarketsandMarketsΓäó	DELRAY BEACH, Fla., Oct. 13, 2026 /PRNewswire/ -- According to MarketsandMarketsΓäó, the Cashew Nutshell Liquid Market size was USD 568.5 million in 2026 and is projected to reach USD 979.8 million by 2031, at a CAGR of 11.50% between 2026 and 2031. Browse 280 ΓÇª	DELRAY BEACH, Fla., Oct. 13, 2026 /PRNewswire/ -- According to MarketsandMarkets, the Cashew Nutshell Liquid Market┬ásize was USD 568.5 million in 2026 and is projected to reach USD 979.8 million by 2ΓÇª	https://www.prnewswire.com/news-releases/cashew-nutshell-liquid-market-worth-979-8-million-by-2031---exclusive-report-by-marketsandmarkets-302906747.html	PRNewswire		2026-10-13 10:30:00	2026-10-14 01:04:46.97239	Positive	0.3000	["Cashew Nutshell Liquid", "MarketsandMarkets", "the Cashew Nutshell Liquid Market"]	["DELRAY BEACH", "Fla."]	[]	0.3818	Positive	Positive	0	0	Economy	1.0000	Cashew Nutshell Liquid Market worth $979.8 million by 2031 - Exclusive Report by MarketsandMarketsΓäó. DELRAY BEACH, Fla., Oct.	92	["million", "liquid", "usd", "market", "worth"]	83
125	CureMeAbroad ΓÇÿexperience centreΓÇÖ to give patients an idea of the treatment journey	CureMeAbroad opens Australia-based experience centres to guide international patients through treatment journeys with on-site consultations and global partner networks.	Medical tourism platform CureMeAbroad is expanding into Australia with a network of experience centres across multiple locations, the Pune-based start-up said, with the first centre scheduled to openΓÇª	https://www.thehindubusinessline.com/news/curemeabroad-experience-centre-to-give-patients-an-idea-of-the-treatment-journey/article71578706.ece	BusinessLine	BL Mumbai Bureau	2026-10-13 09:41:22	2026-10-14 01:04:46.97239	Neutral	0.0500	["Pune"]	["Australia"]	[]	0.0000	Neutral	Neutral	0	0	Healthcare	0.5000	CureMeAbroad ΓÇÿexperience centreΓÇÖ to give patients an idea of the treatment journey.	59	["australia", "opens", "international", "based", "global"]	84
126	I Traced Jane DoeΓÇÖs Path the Night of Her Assault. I Learned Something All the Reports Are Leaving Out.	Students should have been studying for exams and packing for fall break.	Stand outside to get a look at the Tri Delta sorority house, not too far from the Cornell campus, and a security guard will emerge to watch you right back. The three-floor house welcomes 32 sisters eΓÇª	https://slate.com/life/2026/10/cornell-jane-doe-student-protesters-visit.html	Slate Magazine	Scaachi Koul	2026-10-13 09:35:00	2026-10-14 01:04:46.97239	Neutral	0.0964	["Cornell"]	[]	[]	0.0772	Positive	Neutral	0	0	Society	0.5000	I Traced Jane DoeΓÇÖs Path the Night of Her Assault. I Learned Something All the Reports Are Leaving Out.. Students should have been studying for exams and packing for fall break.	68	["learned", "path", "night"]	85
127	A Reckoning With Civilization Itself: How the Genocide in Gaza Reshaped the Middle East	I have covered many wars in the past but nothingΓÇöabsolutely nothingΓÇöprepared me for the brutality, cruelty, and the sheer savagery of IsraelΓÇÖs war in Gaza. I wasnΓÇÖt alone. Veteran colleagues at Al JazeeraΓÇöbattle-hardened reporters who had walked the ruins of	I have covered many wars in the past but nothingabsolutely nothingprepared me for the brutality, cruelty, and the sheer savagery of Israels war in Gaza. I wasnt alone. Veteran colleagues at Al JazeerΓÇª	https://lithub.com/a-reckoning-with-civilization-itself-how-the-genocide-in-gaza-reshaped-the-middle-east/	Lithub.com	Marwan Bishara	2026-10-13 09:09:05	2026-10-14 01:04:46.97239	Neutral	0.0350	["Al Jazeera", "Al Jazeer"]	["Gaza", "Israel"]	[]	-0.9958	Negative	Negative	0	0	General	0.0000	A Reckoning With Civilization Itself: How the Genocide in Gaza Reshaped the Middle East. I have covered many wars in the past but nothingΓÇöabsolutely nothingΓÇöprepared me for the brutality, cruelty, and the sheer savagery of IsraelΓÇÖs war in Gaza.	87	["middle east", "middle", "past", "east", "war"]	86
128	Proposed steel policy seeks AI-supported framework for early detection of sub-standard steel imports	According to the draft, the imports of sub-standard or non-conforming steel, sudden import surges and possible circumvention of trade measures pose significant challenges for domestic producers	The draft steel policy seeks to put in place an AI-powered governance framework and advanced data analytics to ensure early detection of abnormal import trends and boost the competitiveness of the doΓÇª	https://www.thehindubusinessline.com/economy/proposed-steel-policy-seeks-ai-supported-framework-for-early-detection-of-sub-standard-steel-imports/article71578109.ece	BusinessLine	PTI	2026-10-13 08:04:33	2026-10-14 01:04:46.97239	Positive	0.1393	[]	["AI"]	[]	0.8126	Positive	Positive	0	0	Economy	0.5000	Proposed steel policy seeks AI-supported framework for early detection of sub-standard steel imports.	71	["steel", "imports", "draft", "measures", "seeks"]	87
129	The Andaman Islands could be India's next big trade trump card	India is focusing on strengthening the Andaman and Nicobar Islands' strategic maritime role for regional trade. The upcoming Andaman Dialogue 2027 will emphasize maritime infrastructure and economic cooperation among countries in the Indo-Pacific region. CommΓÇª	India is looking to strengthen the Andaman and Nicobar Islands' role as a maritime and economic gateway to the Indo-Pacific, with a focus on securing shipping routes, expanding port connectivity and ΓÇª	https://economictimes.indiatimes.com/news/economy/foreign-trade/andaman-nicobar-islands-dialogue-2027-indo-pacific-trade-india-maritime-strategy-asean-trade-southeast-asia-connectivity-piyush-goyal/articleshow/134910262.cms	The Times of India	ET Online	2026-10-13 06:47:08	2026-10-14 01:04:46.97239	Neutral	0.1000	["the Indo-Pacific"]	["India"]	[]	0.7783	Positive	Positive	0	0	Economy	0.6700	The Andaman Islands could be India's next big trade trump card. India is focusing on strengthening the Andaman and Nicobar Islands' strategic maritime role for regional trade.	78	["andaman", "maritime", "trade", "india", "indo pacific"]	88
130	Samsung's US$9B chip expansion faces funding, supply hurdles	Samsung affiliates plan to invest a combined KRW12.26 trillion (approx. US$9.18 billion) in semiconductor operations across South Korea and Vietnam, but the projects face different financial and supply-chain challenges. Samsung Electronics plans to finance abΓÇª	Keep me signed in\r\nSome subscribers prefer to save their log-in information so they do not have to enter their User ID and Password each time they visit the site. To activate this function, check theΓÇª	https://www.digitimes.com/news/a20261013VL215/samsung-expansion-funding-investment-testing.html	Digitimes	DIGITIMES	2026-10-13 06:40:00	2026-10-14 01:04:46.97239	Neutral	0.0000	["Samsung", "Samsung Electronics", "Password"]	["South Korea", "Vietnam"]	[]	0.6956	Positive	Positive	2	0	Technology	1.0000	Samsung's US$9B chip expansion faces funding, supply hurdles. Samsung affiliates plan to invest a combined KRW12.26 trillion (approx.	79	["samsung", "supply", "supply chain", "samsung affiliates", "semiconductor operations"]	89
131	Proposed steel policy seeks AI-led detection of sub-standard steel imports	The draft steel policy seeks to put in place an AI-powered governance framework and advanced data analytics to ensure early detection of abnormal import trends and boost the competitiveness of the domestic steel industry.\nAccording to the draft National SteelΓÇª	The draft steel policy seeks to put in place an AI-powered governance framework and advanced data analytics to ensure early detection of abnormal import trends and boost the competitiveness of the doΓÇª	https://www.business-standard.com/industry/news/proposed-steel-policy-seeks-ai-led-detection-of-sub-standard-steel-imports-126101300289_1.html	Business Standard	Press Trust of India	2026-10-13 05:24:48	2026-10-14 01:04:46.97239	Positive	0.2000	["National Steel"]	["AI"]	[]	0.9118	Positive	Positive	0	0	Economy	0.3300	Proposed steel policy seeks AI-led detection of sub-standard steel imports.	82	["steel", "draft", "seeks", "policy", "powered"]	87
133	Harold & Kumar Escape From Guantanamo Bay 2008 1080p AMZN WEB-DL H264-ViETNAM	Awards 1 win & 1 nomination total See more awards ┬╗ Plot: The morning they return from their White Castle road trip, Harold and Kumar decide to go to Amsterdam because Harold doesn't want to wait ten days to see Maria again. On the plane, Kumar lights up his ΓÇª	Awards 1 win &amp; 1 nomination total See more awards ┬╗\r\nPlot: The morning they return from their White Castle road trip, Harold and Kumar decide to go to Amsterdam because Harold doesnΓÇÖt want to waiΓÇª	https://post.rlsbb.cc/harold-kumar-escape-from-guantanamo-bay-2008-1080p-amzn-web-dl-h264-vietnam/	Rlsbb.cc	Damon	2026-10-13 04:41:20	2026-10-14 01:04:46.97239	Positive	0.2889	["Harold &", "AMZN WEB-DL", "Harold"]	["Kumar", "Amsterdam"]	["Kumar Escape", "Harold", "Maria", "wai"]	0.9701	Positive	Positive	3	1	Technology	1.0000	Harold & Kumar Escape From Guantanamo Bay 2008 1080p AMZN WEB-DL H264-ViETNAM.	98	["harold", "kumar", "awards", "return", "doesn"]	91
134	Foxconn's Vietnam unit Fukang Technology more than doubles registered capital to US$710.4 million	Fukang Technology, a northern Vietnam subsidiary of Taiwan's Hon Hai Precision Industry (Foxconn), has raised its registered capital by more than 109% to nearly VND17.47 trillion (US$710.4 million), according to business registration records reported by The IΓÇª	Fukang Technology, a northern Vietnam subsidiary of Taiwan's Hon Hai Precision Industry (Foxconn), has raised its registered capital by more than 109% to nearly VND17.47 trillion (US$710.4 million), ΓÇª	https://www.digitimes.com/news/a20261013VL202/foxconn-taiwan-subsidiary-investment-2026.html	Digitimes	DIGITIMES	2026-10-13 03:45:00	2026-10-14 01:04:46.97239	Positive	0.3400	["Fukang Technology", "Hon Hai Precision Industry"]	["Foxconn", "Vietnam", "Fukang", "Taiwan"]	[]	0.0000	Neutral	Positive	9	1	Technology	1.0000	Foxconn's Vietnam unit Fukang Technology more than doubles registered capital to US$710.4 million.	79	["technology", "million", "taiwan", "trillion", "industry"]	92
135	Govt's free trade push could lead to $140 billion GDP gain for India	The surge in US tariffs since President Donald Trump returned to the White House in January 2025 is redrawing global trade links	The surge in US tariffs since President Donald Trump returned to the White House in January 2025 is redrawing global trade links\r\nAfter surge in US tariffs, countries are diversifying trade links andΓÇª	https://www.business-standard.com/economy/news/govt-s-free-trade-push-could-lead-to-140-billion-gdp-gain-for-india-126101300147_1.html	Business Standard	Bloomberg	2026-10-13 03:42:35	2026-10-14 01:04:46.97239	Positive	0.1333	["Govt", "the White House"]	["India", "US"]	["Donald Trump"]	0.7717	Positive	Positive	0	0	Economy	0.7500	Govt's free trade push could lead to $140 billion GDP gain for India. The surge in US tariffs since President Donald Trump returned to the White House in January 2025 is redrawing global trade links	46	["trade", "free trade", "returned", "president", "house"]	93
136	PM Modi's free trade push could lead to $140 billion GDP gain for India	A more protectionist US could unexpectedly benefit India as New Delhi expands its free-trade agreements (FTAs) to diversify export markets and attract investment. A World Trade Organization-based model estimates that IndiaΓÇÖs concluded and proposed trade dealsΓÇª	A more protectionist US could prove an unexpected tailwind for IndiaΓÇÖs economy. As countries redraw supply chains around trusted partners and seek preferential market access, New Delhi has ended yearΓÇª	https://economictimes.indiatimes.com/news/economy/foreign-trade/pm-modis-free-trade-push-could-lead-to-140-billion-gdp-gain-for-india/articleshow/134906847.cms	The Times of India	Bloomberg	2026-10-13 03:42:09	2026-10-14 01:04:46.97239	Positive	0.2675	["A World Trade Organization"]	["India", "US", "New Delhi"]	[]	0.9501	Positive	Positive	0	0	Economy	0.7800	PM Modi's free trade push could lead to $140 billion GDP gain for India. A more protectionist US could unexpectedly benefit India as New Delhi expands its free-trade agreements (FTAs) to diversify export markets and attract investment.	80	["trade", "india", "free trade", "free", "organization"]	94
137	Vietnamese Franchise Sequel ΓÇÿSister Sister 3ΓÇÖ Lands at 3388 Films for Americas, Europe, Australia, Taiwan and Japan (EXCLUSIVE)	Vietnamese female-led franchise entry ΓÇ£Sister Sister 3ΓÇ¥ has been picked up by U.S.-based specialty distributor 3388 Films for the Americas, Europe, Australia, Taiwan and Japan. The deal was closed at the Asian Contents & Film Market (ACFM) in Busan. Directed ΓÇª	Vietnamese female-led franchise entry ΓÇ£Sister Sister 3ΓÇ¥ has been picked up by U.S.-based specialty distributor 3388 Films for the Americas, Europe, Australia, Taiwan and Japan. \r\nThe deal was closed ΓÇª	https://variety.com/2026/film/markets-festivals/vietnamese-franchise-sequel-sister-sister-3-3388-films-1236909706/	Variety	Naman Ramachandran	2026-10-13 03:26:43	2026-10-14 01:04:46.97239	Neutral	-0.0667	["Films for Americas", "the Asian Contents & Film Market"]	["Australia", "Taiwan", "Japan", "Busan"]	[]	0.3034	Positive	Positive	6	1	Economy	0.5000	Vietnamese Franchise Sequel ΓÇÿSister Sister 3ΓÇÖ Lands at 3388 Films for Americas, Europe, Australia, Taiwan and Japan (EXCLUSIVE).	89	["sister", "australia", "taiwan", "japan", "europe"]	95
138	Its Always Sunny in Philadelphia S18E10 720p HDTV x264-ViETNAM	Season 18, Episode 10 ΓÇô ΓÇ£The Guys Have a SleepoverΓÇ¥Blinded from LASIK surgery, Dee pleads for the guys to spend the night to keep her safe from neighborhood crime, but they listen to the wolves inside themselves and opt for a dudes-only sleepover of their ownΓÇª	Season 18, Episode 10 ΓÇ£The Guys Have a SleepoverΓÇ¥Blinded from LASIK surgery, Dee pleads for the guys to spend the night to keep her safe from neighborhood crime, but they listen to the wolves inside ΓÇª	https://post.rlsbb.cc/its-always-sunny-in-philadelphia-s18e10-720p-hdtv-x264-vietnam/	Rlsbb.cc	Will	2026-10-13 02:20:10	2026-10-14 01:04:46.97239	Positive	0.5000	[]	["Philadelphia"]	["Dee"]	-0.0772	Negative	Negative	3	1	General	0.0000	Its Always Sunny in Philadelphia S18E10 720p HDTV x264-ViETNAM.	91	["hdtv", "season episode", "crime", "episode", "night"]	96
139	Thailand Tightens Its Belt With 2027 Budget	The country's budget planners have been wrestling with the same intractable challenge since the COVID-19 pandemic.	Thailands budget for the 2027 fiscal year is out, and perhaps the most interesting feature is what it does not do: it barely increases spending at all. Approved expenditures came in at 3,788 billion ΓÇª	https://thediplomat.com/2026/10/thailand-tightens-its-belt-with-2027-budget/	The Diplomat	James Guild	2026-10-13 02:15:00	2026-10-14 01:04:46.97239	Positive	0.2625	["COVID-19"]	["Thailand"]	[]	0.7264	Positive	Positive	0	0	Technology	1.0000	Thailand Tightens Its Belt With 2027 Budget. The country's budget planners have been wrestling with the same intractable challenge since the COVID-19 pandemic.	58	["wrestling", "thailand", "country"]	97
140	utelearn 10.21.2026	A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	A required part of this site couldnt load. This may be due to a browser\r\n extension, network issues, or browser settings. Please check your\r\n connection, disable any ad blockers, or try using a diffeΓÇª	https://pypi.org/project/utelearn/10.21.2026/	Pypi.org	dung.cai@hcmute.edu.vn	2026-10-13 01:51:08	2026-10-14 01:04:46.97239	Neutral	0.0625	[]	["HCMUTE", "Vietnam"]	[]	0.3182	Positive	Positive	2	0	Society	1.0000	utelearn 10.21.2026. A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	49	["machine", "library built", "purpose hcmute", "purpose", "learning library"]	98
141	How much is illegal ivory worth?	How Much Is Illegal Ivory Worth? Unveiling the Dark Economics of a Tragic Trade The value of illegal ivory fluctuates based on location, quality, risk, and market demand, but generally ranges from $100 to $2,500 per kilogram. This seemingly high price fuels tΓÇª	How Much Is Illegal Ivory Worth? Unveiling the Dark Economics of a Tragic Trade\r\nThe value of illegal ivory fluctuates based on location, quality, risk, and market demand, but generally ranges from $ΓÇª	https://www.lifesciencesworld.com/how-much-is-illegal-ivory-worth/	Lifesciencesworld.com	Ava Reynolds	2026-10-13 01:46:43	2026-10-14 01:04:46.97239	Negative	-0.2093	["the Dark Economics"]	[]	[]	-0.9656	Negative	Negative	0	0	Economy	1.0000	How much is illegal ivory worth?. How Much Is Illegal Ivory Worth?	82	["ivory", "illegal ivory", "illegal", "worth", "demand"]	8
142	utelearn 10.20.2026	A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	A required part of this site couldnt load. This may be due to a browser\r\n extension, network issues, or browser settings. Please check your\r\n connection, disable any ad blockers, or try using a diffeΓÇª	https://pypi.org/project/utelearn/10.20.2026/	Pypi.org	dung.cai@hcmute.edu.vn	2026-10-13 01:38:13	2026-10-14 01:04:46.97239	Neutral	0.0625	[]	["HCMUTE", "Vietnam"]	[]	0.3182	Positive	Positive	2	0	Society	1.0000	utelearn 10.20.2026. A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	49	["machine", "library built", "purpose hcmute", "purpose", "learning library"]	98
143	Why ChinaΓÇÖs Training Center in Laos Will Not Change VietnamΓÇÖs Non-Aligned Foreign Policy	Hanoi's best option to keep its western neighbors neutral is to resist further Chinese encroachment by political means.	Chinas recent announcement of the opening of a new Joint Logistics and Training Center to train air force pilots in Ban Keun, Laos, has caused much concern about Chinas intentions and capabilities. TΓÇª	https://thediplomat.com/2026/10/why-chinas-training-center-in-laos-will-not-change-vietnams-non-aligned-foreign-policy/	The Diplomat	Khang Vu	2026-10-13 00:06:00	2026-10-14 01:04:46.97239	Neutral	0.0919	["Non-Aligned Foreign Policy", "Joint Logistics", "Chinas"]	["China", "Hanoi", "Ban Keun", "Laos"]	["Training Center"]	0.1531	Positive	Positive	5	1	Politics	0.5000	Why ChinaΓÇÖs Training Center in Laos Will Not Change VietnamΓÇÖs Non-Aligned Foreign Policy. Hanoi's best option to keep its western neighbors neutral is to resist further Chinese encroachment by political means.	64	["chinese", "center", "policy", "option", "change"]	99
144	Indo-Pacific Maritime Security Cooperation	This essay explores Southeast Asian perspectives on Quad-driven maritime security cooperation in the Indo-Pacific. Through expert analyses from Indonesia, Singapore, and Vietnam, it evaluates regional perceptions of Quad initiatives based on three primary varΓÇª	Dr. Le Hong Hiep is a senior fellow and coordinator of the Vietnam Studies Programme at the ISEASYusof Ishak Institute, Singapore, and editor of its flagship journal, Contemporary Southeast Asia. HieΓÇª	https://www.hoover.org/research/indo-pacific-maritime-security-cooperation	Hoover.org	October 13, 2026	2026-10-13 00:00:00	2026-10-14 01:04:46.97239	Positive	0.1889	["Indo-Pacific Maritime Security Cooperation", "the Indo-Pacific", "the Vietnam Studies Programme", "the ISEASYusof Ishak Institute", "Contemporary Southeast Asia"]	["Indonesia", "Singapore", "Vietnam", "Quad"]	["Le Hong Hiep"]	0.6369	Positive	Positive	3	1	Military	1.0000	Indo-Pacific Maritime Security Cooperation. This essay explores Southeast Asian perspectives on Quad-driven maritime security cooperation in the Indo-Pacific.	69	["security", "indo pacific", "indo", "maritime", "pacific"]	100
148	Native American Warriors Shatter AcademiaΓÇÖs Colonialism Narrative	On this Columbus Day, I am celebrating patriotism that is more powerful than the politics of resentment.\nThe post Native American Warriors Shatter AcademiaΓÇÖs Colonialism Narrative first appeared on Le┬╖gal In┬╖sur┬╖rec┬╖tion.	Reading the news from American colleges and universities, professors at these leftist indoctrination centers are inclined to make America sound less like a nation than a crime scene.\r\nWhen Native AmeΓÇª	https://legalinsurrection.com/2026/10/native-american-warriors-shatter-academias-colonialism-narrative/	Legalinsurrection.com	Leslie Eastman	2026-10-12 19:00:11	2026-10-14 01:04:46.97239	Positive	0.1370	[]	["America"]	["Native Ame"]	0.3818	Positive	Positive	0	0	Politics	1.0000	Native American Warriors Shatter AcademiaΓÇÖs Colonialism Narrative. On this Columbus Day, I am celebrating patriotism that is more powerful than the politics of resentment.	69	["narrative", "american", "appeared", "post"]	104
151	Global poverty rises for first time since 2010 ΓÇô UN	Global poverty has risen for the first time since 2010, with 1.2 billion people worldwide facing acute deprivation, according to a UN report Read Full Article at RT.com	Global poverty has risen for the first time since 2010, with 1.2 billion people facing acute deprivation, according to a new UN report.\r\nThe study, released on Monday by the UN Development Program (UΓÇª	https://rt-english.com/news/647088-un-global-poverty-growth/	Rt-english.com	RT	2026-10-12 16:10:24	2026-10-14 01:04:46.97239	Positive	0.2436	["UN Global", "UN", "the UN Development Program"]	[]	["Read Full Article"]	-0.9382	Negative	Negative	0	0	Society	1.0000	Global poverty rises for first time since 2010 ΓÇô UN. Global poverty has risen for the first time since 2010, with 1.2 billion people worldwide facing acute deprivation, according to a UN report Read Full Article at RT.com	72	["poverty", "global poverty", "global", "rises", "people"]	107
152	Transcript: TrumpΓÇÖs Two Choices in Iran	This is a lightly edited transcript of the October 17 edition of Right Now With Perry Bacon. You can watch the video here or by following this show on YouTube or Substack. Perry Bacon: Good morning. IΓÇÖm Perry Bacon. IΓÇÖm the host of Right Now on The New RepublΓÇª	Saunders: Not that much better.\r\nBacon: Not that much better. Fair enough. Hes trying to give a grand speech. Thats what Im trying to get at, the idea is to say something grand, but Im not sure if heΓÇª	https://newrepublic.com/article/216500/transcript-trump-running-foreign-policy-options	The New Republic	Right Now With Perry Bacon	2026-10-12 15:00:00	2026-10-14 01:04:46.97239	Positive	0.3275	["TrumpΓÇÖs Two Choices", "Substack", "The New Republ"]	["Iran"]	["Perry Bacon", "Bacon"]	0.1904	Positive	Positive	0	0	Technology	1.0000	Transcript: TrumpΓÇÖs Two Choices in Iran. This is a lightly edited transcript of the October 17 edition of Right Now With Perry Bacon. You can watch the video here or by following this show on YouTube or Substack. Perry Bacon: Good morning.	94	["right", "edition", "iran", "trump", "good"]	108
153	Vietnam veteran hitchhiked home 56 years ago: Top 5 most-read stories Oct. 5-11 [ICYMI]	Each Monday, our digital team takes a look at last weekΓÇÖs top stories on LancasterOnline.	Each Monday, our digital team takes a look at last weeks top stories on LancasterOnline.\r\nWe look at news, sports, business, life, culture and local history.\r\nHere are the most-read stories from MondΓÇª	https://lancasteronline.com/news/local/vietnam-veteran-hitchhiked-home-56-years-ago-top-5-most-read-stories-oct-5-11/article_cf6297ca-cf92-4826-8c34-5b1b8073f5af.html	LancasterOnline	LANCASTERONLINE | Staff	2026-10-12 14:07:00	2026-10-14 01:04:46.97239	Positive	0.1667	["LancasterOnline", "Mond"]	["Vietnam"]	[]	0.5267	Positive	Positive	3	1	Society	0.3300	Vietnam veteran hitchhiked home 56 years ago: Top 5 most-read stories Oct. 5-11 [ICYMI]. Each Monday, our digital team takes a look at last weekΓÇÖs top stories on LancasterOnline.	62	["stories", "home", "digital", "team", "read"]	109
156	Manchester United 1-1 Tottenham Hotspur: player ratings to the theme of Spooky Season songs	Patience is still required. Tottenham Hotspur played Manchester United off the Old Trafford pitch in the first half of their Premier League clash on Saturday, but SpursΓÇÖ inability to be clinical with the (numerous) chances they created resulted in a dramatic ΓÇª	Patience is still required. Tottenham Hotspur played Manchester United off the Old Trafford pitch in the first half of their Premier League clash on Saturday, but Spurs' inability to be clinical withΓÇª	https://cartilagefreecaptain.sbnation.com/community-player-ratings/74289/manchester-united-1-1-tottenham-hotspur-player-ratings-to-the-theme-of-spooky-season-songs	SB Nation	Dustin George-Miller	2026-10-12 13:21:12	2026-10-14 01:04:46.97239	Neutral	-0.0083	["Spooky Season", "Premier League"]	[]	["Manchester United 1-1 Tottenham Hotspur:", "Patience", "Tottenham Hotspur", "Manchester United", "Spurs"]	0.7845	Positive	Positive	0	0	General	0.0000	Manchester United 1-1 Tottenham Hotspur: player ratings to the theme of Spooky Season songs. Patience is still required.	88	["united", "half", "created", "season", "old"]	112
157	18-Year-Old Released After Allegedly Shooting Two Teenagers on October 2	Eighteen-year-old┬áAdam Abdihakeem Adam posted bond and was released from jail just over a week after allegedly shooting two teenagers during Eden Prairie High School homecoming night.\nThe post 18-Year-Old Released After Allegedly Shooting Two Teenagers on OctΓÇª	Eighteen-year-old┬áAdam Abdihakeem Adam posted bond and was released from jail just over a week after allegedly shooting two teenagers during Eden Prairie High School homecoming night.\r\nBreitbart NewsΓÇª	https://www.breitbart.com/2nd-amendment/2026/10/12/18-year-old-released-after-allegedly-shooting-two-teenagers-on-october-2/	Breitbart News	AWR Hawkins	2026-10-12 13:17:05	2026-10-14 01:04:46.97239	Neutral	-0.0350	["Breitbart News"]	[]	["Adam Abdihakeem Adam"]	0.0000	Neutral	Neutral	0	0	Society	0.6700	18-Year-Old Released After Allegedly Shooting Two Teenagers on October 2.	77	["shooting teenagers", "shooting", "released", "allegedly", "old"]	113
158	F1 Highlights The Realities Of Global SportΓÇÖs Chokepoint Problems	Recent armed conflicts caused problems for the global sports industry, specifically because of issues associated with maritime chokepoints, with tensions now rising in the Red Sea	With the concluding races of this season's F1 World Championship a matter of weeks away, it remains to be seen whether the series will conclude as planned.\r\nFollowing recent Houthi missile attacks onΓÇª	https://www.forbes.com/sites/simonchadwick/2026/10/12/f1-highlights-the-realities-of-global-sports-chokepoint-problems/	Forbes	Simon Chadwick , Contributor	2026-10-12 12:48:40	2026-10-14 01:04:46.97239	Neutral	0.0000	["F1 Highlights The Realities Of Global SportΓÇÖs Chokepoint Problems", "Houthi"]	[]	[]	-0.8625	Negative	Negative	0	0	Military	0.4000	F1 Highlights The Realities Of Global SportΓÇÖs Chokepoint Problems. Recent armed conflicts caused problems for the global sports industry, specifically because of issues associated with maritime chokepoints, with tensions now rising in the Red Sea	68	["global", "armed", "sea", "maritime", "highlights"]	114
159	Leeches Dipped in Guinness Turned Erratic, and the Ones Placed on Garlic Died	A 1994 BMJ experiment tried beer, garlic, and sour cream to make medical leeches bite faster. Beer backfired, and garlic proved fatal.	Two researchers in Norway once tried to solve a real surgical headache with ingredients that sound like a pub menu. Their paper in the BMJ, titled "Effect of ale, garlic, and soured cream on the appeΓÇª	https://www.medicaldaily.com/leeches-guinness-garlic-sour-cream-study-479849	Medical Daily	Ryan Archer	2026-10-12 12:00:09	2026-10-14 01:04:46.97239	Neutral	0.0300	["Guinness Turned Erratic", "BMJ"]	["Norway"]	["Leeches Dipped"]	-0.5859	Negative	Negative	0	0	Healthcare	1.0000	Leeches Dipped in Guinness Turned Erratic, and the Ones Placed on Garlic Died. A 1994 BMJ experiment tried beer, garlic, and sour cream to make medical leeches bite faster. Beer backfired, and garlic proved fatal.	71	["garlic", "turned", "make"]	115
160	US Travelers Eying Some Unexpected Destinations	The 2027 getaway crowd may be heading somewhere you didn't expect: Vero Beach, Florida. The Treasure Coast town tops Skyscanner's new Travel Trends 2027 list, with flight searches from US travelers jumping about 201%, outpacing buzzy international spots from ΓÇª	The 2027 getaway crowd may be heading somewhere you didn't expect: Vero Beach, Florida. The Treasure Coast town tops Skyscanner's new Travel Trends 2027 list, with flight searches from US travelers jΓÇª	https://www.newser.com/story/397876/top-trending-destination-for-us-travelers-is-domestic.html	Newser	Arden Dier with Newser.AI	2026-10-12 11:55:00	2026-10-14 01:04:46.97239	Neutral	0.0932	["US Travelers"]	["Vero Beach", "Florida", "US"]	["Skyscanner"]	0.8750	Positive	Positive	0	0	Society	1.0000	US Travelers Eying Some Unexpected Destinations. The 2027 getaway crowd may be heading somewhere you didn't expect: Vero Beach, Florida.	78	["didn", "flight", "crowd", "beach", "list"]	116
161	California Fish and Wildlife Using Armed 'Ground-Based Specialists' to Rid Catalina Island of Mule Deer	Armed "ground-based specialists" are being allowed to kill off the mule deer population on Catalina Island with permission granted by┬áCalifornia's Department of Fish and Wildlife.\nThe post California Fish and Wildlife Using Armed ΓÇÿGround-Based SpecialistsΓÇÖ toΓÇª	Armed ΓÇ£ground-based specialistsΓÇ¥ are being allowed to kill off the mule deer population on Catalina Island with permission granted by┬áCaliforniaΓÇÖs Department of Fish and Wildlife.\r\nMeeteater.com noteΓÇª	https://www.breitbart.com/sports/2026/10/12/california-fish-and-wildlife-using-armed-ground-based-specialists-to-rid-catalina-island-of-mule-deer/	Breitbart News	AWR Hawkins	2026-10-12 11:38:49	2026-10-14 01:04:46.97239	Neutral	0.0000	["Department of Fish and", "CaliforniaΓÇÖs Department of Fish and", "Meeteater.com"]	["California"]	[]	-0.8126	Negative	Negative	0	0	Society	1.0000	California Fish and Wildlife Using Armed 'Ground-Based Specialists' to Rid Catalina Island of Mule Deer.	80	["armed ground", "ground based", "ground", "fish", "armed"]	117
162	Two week 4Γ¡É Vietnam spa escape for less than one week	Bargain hunters, take note: this is the kind of deal that makes two weeks away actually cheaper than booking one.Fourteen nights in Hanoi at a 4-star hotel with its own spa, flights, luggage and breakfast included. Spend your mornings wandering the Old QuarteΓÇª	We might be pirates, but were an honest bunch. We check all our deals when we review them to make sure everything is available. However, with deals this hot, things change quickly flight prices fluctΓÇª	https://www.holidaypirates.com/packages/ha-noi-media-hotel-and-spa-vietnam	Holidaypirates.com	Lola	2026-10-12 11:24:31	2026-10-14 01:04:46.97239	Positive	0.3217	["the Old Quarte"]	["Vietnam", "Hanoi"]	[]	0.8462	Positive	Positive	5	1	Society	0.5000	Two week 4Γ¡É Vietnam spa escape for less than one week.	89	["hotel", "weeks", "flights", "deal", "old"]	118
164	Meta Bans ByteDance Ads on Its Platforms		Meta Platforms has banned advertisements from ByteDance on its platforms in the U.S. and several other markets, Bloomberg and other media outlets reported. Meta implemented the ByteDance ad ban in thΓÇª	https://www.theinformation.com/briefings/meta-bans-bytedance-ads-platforms	The Information	Juro Osawa	2026-10-12 10:43:32	2026-10-14 01:04:46.97239	Neutral	-0.0833	["Meta Bans ByteDance Ads on Its Platforms Meta Platforms", "ByteDance", "Meta"]	["U.S.", "Bloomberg"]	[]	-0.7650	Negative	Negative	0	0	Economy	1.0000	Meta Bans ByteDance Ads on Its Platforms. Meta Bans ByteDance Ads on Its Platforms Meta Platforms has banned advertisements from ByteDance on its platforms in the U.S. and several other markets, Bloomberg and other media outlets reported.	38	[]	120
167	Sea and OpenAI bring Regional Codex Hackathon to Malaysia with over RM200K in API credits up for grabs	Technology company Sea and artificial intelligence research firm OpenAI have officially announced the Malaysian edition of their Regional Codex Hackathon Series. Scheduled to take place at the Mandarin Oriental in Kuala Lumpur on Saturday, 5 December 2026, thΓÇª	Technology company Sea and artificial intelligence research firm OpenAI have officially announced the Malaysian edition of their Regional Codex Hackathon Series. \r\nScheduled to take place at the MandΓÇª	https://soyacincau.com/2026/10/12/sea-and-openai-bring-regional-codex-hackathon-to-malaysia-with-over-rm200k-in-api-credits-up-for-grabs/	SoyaCincau.com	Janarrthine Kannan	2026-10-12 09:49:30	2026-10-14 01:04:46.97239	Negative	-0.4000	["API", "OpenAI"]	["Hackathon", "Malaysia", "Kuala Lumpur"]	["RM200K"]	0.8271	Positive	Positive	0	0	Technology	0.6000	Sea and OpenAI bring Regional Codex Hackathon to Malaysia with over RM200K in API credits up for grabs.	84	["sea", "regional", "series", "technology", "december"]	123
168	Puravankara inks pact to jointly develop 12.76-acre land in BengaluruΓÇÖs Sathanur	The proposed development, with a saleable area of around 1.90 million sq ft, is expected to strengthen the companyΓÇÖs residential development pipeline in Bengaluru and help reinforce its focus on high-potential micro-markets and strategic land additions, the cΓÇª	MUMBAI: Realty developer Puravankara has entered into a Joint Development Agreement (JDA) for a 12.76-acre land parcel in Sathanur, North Bengaluru, with an estimated Gross Development Value (GDV) ofΓÇª	https://economictimes.indiatimes.com/industry/services/property-/-cstruction/puravankara-inks-pact-to-jointly-develop-12-76-acre-land-in-bengalurus-sathanur/articleshow/134888344.cms	The Times of India	Kailash Babar	2026-10-12 09:24:01	2026-10-14 01:04:46.97239	Neutral	-0.0500	["MUMBAI", "JDA", "Gross Development Value"]	["Bengaluru", "Sathanur", "North Bengaluru"]	["Puravankara"]	0.7579	Positive	Positive	0	0	Economy	0.5000	Puravankara inks pact to jointly develop 12.76-acre land in BengaluruΓÇÖs Sathanur.	78	["development", "proposed", "strategic", "focus", "markets"]	124
169	Vikrom Kromadit built his industrial park empire in Thailand and Vietnam. Laos is next	Thai real estate developer Amata Corporation says Laos will become its ΓÇ£largest focusΓÇ¥ in the years to come, CEO Vikrom Kromadit tells Fortune.\nΓÇ£Laos will become our largest focus because of the land bank that they have,ΓÇ¥ Kromadit tells Fortune. ΓÇ£They also haΓÇª	Thai real estate developer Amata Corporation says Laos will become its largest focus in the years to come, CEO Vikrom Kromadit tells Fortune.Laos will become our largest focus because of the land banΓÇª	https://biztoc.com/x/90f5a9780f93e0d8	Biztoc.com	fortune.com	2026-10-12 09:13:36	2026-10-14 01:04:46.97239	Positive	0.1333	["Amata Corporation"]	["Thailand", "Vietnam", "Laos"]	["Vikrom Kromadit"]	0.0000	Neutral	Neutral	3	1	Economy	0.5000	Vikrom Kromadit built his industrial park empire in Thailand and Vietnam. Laos is next. Thai real estate developer Amata Corporation says Laos will become its ΓÇ£largest focusΓÇ¥ in the years to come, CEO Vikrom Kromadit tells Fortune.	90	["kromadit", "laos", "vikrom kromadit", "vikrom", "fortune"]	125
170	'Sumo: Spirit Weighs Nothing' Doc Film Clip, Interview About Japan	Erik Shirai shares how his immersive cinematic experience, now screening at the London Film Fest, aims to change misconceptions and show how humility is built into the Japanese understanding of strength.	You may not realize how much you want to know about sumo until you go behind the scenes by experiencing Erik ShiraiΓÇÖs immersive Sumo: Spirit Weighs Nothing. The documentary, which world-premiered at ΓÇª	http://www.hollywoodreporter.com/movies/movie-news/sumo-spirit-weighs-nothing-doc-film-clip-lff-interview-1236727202/	Hollywood Reporter	Georg Szalai	2026-10-12 09:00:37	2026-10-14 01:04:46.97239	Neutral	-0.0400	["the London Film Fest", "Sumo"]	["Japan"]	["Doc Film Clip", "Erik Shirai", "Erik ShiraiΓÇÖs"]	0.7964	Positive	Positive	0	0	Society	0.5000	'Sumo: Spirit Weighs Nothing' Doc Film Clip, Interview About Japan.	74	["film", "japan", "interview", "change", "doc"]	126
171	How To Watch The Inner Circle 35 And ONE Friday Fights 175 Live On October 9	Find out where you can watch these two action-packed events anywhere in the world live!	ONE Championship is spicing up the month with one of its biggest triple-header weekends yet, and the action begins in Asia primetime.\r\nThe world's largest martial arts organization will broadcast┬áTheΓÇª	https://www.onefc.com/news/how-to-watch-the-inner-circle-35-and-one-friday-fights-175-live-on-october-9/	Onefc.com	Bear Frazer	2026-10-12 08:56:55	2026-10-14 01:04:46.97239	Neutral	0.0814	[]	[]	[]	0.1260	Positive	Neutral	0	0	Society	0.5000	How To Watch The Inner Circle 35 And ONE Friday Fights 175 Live On October 9. Find out where you can watch these two action-packed events anywhere in the world live!	62	["live", "inner circle", "inner", "circle", "friday"]	127
172	Vikrom Kromadit built his industrial park empire in Thailand and Vietnam. Laos is next	The Thai developer plans up to 200 square kilometers of industrial parks in Laos, as Chinese manufacturers expand into new hubs across Southeast Asia.	Thai real estate developer Amata Corporation says Laos will become its largest focus in the years to come, CEO Vikrom Kromadit tells Fortune.Laos will become our largest focus because of the land banΓÇª	https://fortune.com/2026/10/12/amata-industrial-park-thailand-vietnam-laos/	Fortune	Angelica Ang	2026-10-12 08:32:35	2026-10-14 01:04:46.97239	Neutral	0.0841	["Amata Corporation"]	["Thailand", "Vietnam", "Laos"]	["Vikrom Kromadit"]	0.3182	Positive	Positive	3	1	Technology	1.0000	Vikrom Kromadit built his industrial park empire in Thailand and Vietnam. Laos is next. The Thai developer plans up to 200 square kilometers of industrial parks in Laos, as Chinese manufacturers expand into new hubs across Southeast Asia.	71	["industrial", "laos", "kromadit", "vikrom kromadit", "vikrom"]	128
173	India, Vietnam, Thailand emerge as branded residence hotspots as growth hits 200%	Vietnam, Thailand, and India are emerging as key players in the global branded residences market. The growth rate for branded residential projects in India is projected to reach 126% over the next six years. Savills data indicates that Asia-Pacific accounts fΓÇª	New Delhi: Vietnam, Thailand and India are among the worlds top 10 markets for branded residences and have collectively recorded almost 200% growth over the past five years.According to Savills data,ΓÇª	https://economictimes.indiatimes.com/industry/services/property-/-cstruction/india-vietnam-thailand-emerge-as-branded-residence-hotspots-as-growth-hits-200/articleshow/134887084.cms	The Times of India	Faizan Haidar	2026-10-12 08:29:22	2026-10-14 01:04:46.97239	Neutral	0.0644	["Savills"]	["India", "Vietnam", "Thailand", "New Delhi"]	[]	0.8137	Positive	Positive	6	1	Economy	0.6700	India, Vietnam, Thailand emerge as branded residence hotspots as growth hits 200%. Vietnam, Thailand, and India are emerging as key players in the global branded residences market.	84	["india", "thailand", "india emerging", "emerging", "asia pacific"]	129
174	Global poverty index rises for first time since its 2010 creation	A U.N. global poverty index has risen for the first time since its creation in 2010, bringing the number of people affected to 1.2 billion, the United Nations Development Program reported on Oct. 12.	WASHINGTON\r\nMore than half of those in acute poverty were children. (AFP Photo)\r\nA U.N. global poverty index has risen for the first time since its creation in 2010, bringing the number of people affΓÇª	https://www.hurriyetdailynews.com/global-poverty-index-rises-for-first-time-since-its-2010-creation-228008	Hurriyet Daily News	hurriyetdailynews.com	2026-10-12 06:21:20	2026-10-14 01:04:46.97239	Positive	0.1870	["U.N.", "the United Nations Development Program", "WASHINGTON", "AFP Photo"]	[]	[]	-0.7269	Negative	Negative	1	0	General	0.0000	Global poverty index rises for first time since its 2010 creation. A U.N.	80	["poverty", "index", "global poverty", "creation", "global"]	130
175	Samsung affiliates to invest $9.15 billion in semiconductor operations, with major focus on Vietnam	Plans include memory testing facilities in Vietnam and expanded high-end substrate capacity in South Korea	Samsung affiliates plan to invest a combined 12.26 trillion won ($9.15 billion) in semiconductor operations, with nearly 8 trillion won ($5.99 billion) earmarked for Vietnam while expanding high-end ΓÇª	https://www.thehindubusinessline.com/info-tech/samsung-affiliates-to-invest-915-billion-in-semiconductor-operations-with-major-focus-on-vietnam/article71573748.ece	BusinessLine	ANI	2026-10-12 04:53:52	2026-10-14 01:04:46.97239	Neutral	0.0813	["Samsung"]	["Vietnam", "South Korea Samsung"]	[]	0.8126	Positive	Positive	6	1	Technology	1.0000	Samsung affiliates to invest $9.15 billion in semiconductor operations, with major focus on Vietnam. Plans include memory testing facilities in Vietnam and expanded high-end substrate capacity in South Korea	58	["semiconductor operations", "semiconductor", "samsung affiliates", "testing", "end"]	131
176	Samsung plans $9.15 billion semiconductor investment, with nearly $6 billion earmarked for Vietnam	Samsung affiliates are planning to invest over 12 trillion won in semiconductor operations across Vietnam and South Korea. The company aims to enhance its memory chip testing facilities in Thai Nguyen, Vietnam, set to begin in late 2027. Additionally, SamsungΓÇª	Seoul: Samsung affiliates plan to invest a combined 12.26 trillion won (USD 9.15 billion) in semiconductor operations, with nearly 8 trillion won (USD 5.99 billion) earmarked for Vietnam while expandΓÇª	https://economictimes.indiatimes.com/news/international/business/samsung-plans-9-15-billion-semiconductor-investment-with-nearly-6-billion-earmarked-for-vietnam/articleshow/134882197.cms	The Times of India	ANI	2026-10-12 04:19:51	2026-10-14 01:04:46.97239	Neutral	-0.0333	["Samsung", "Vietnam Samsung", "Thai Nguyen"]	["Vietnam", "South Korea", "Seoul"]	[]	0.9022	Positive	Positive	6	1	Technology	0.7500	Samsung plans $9.15 billion semiconductor investment, with nearly $6 billion earmarked for Vietnam. Samsung affiliates are planning to invest over 12 trillion won in semiconductor operations across Vietnam and South Korea.	83	["samsung", "semiconductor", "billion", "samsung affiliates", "semiconductor operations"]	131
177	My cofounder and I were rivals at hackathons. At 21, I've put college on hold to build a startup with him.	He was accepted into Singapore's top university, but had to request a leave of absence before his first day to build a startup in San Francisco.	This as-told-to essay is based on a conversation with Raymond Loong Ng, 21, the cofounder of Makeable, a San Francisco-based startup. It's been edited for length and clarity.\r\nI was born in Vietnam aΓÇª	https://www.businessinsider.com/gen-z-college-raise-funding-vc-startup-san-francisco-hackathon-2026-10#article	Business Insider	agoh@businessinsider.com (Amanda Goh)	2026-10-12 04:02:01	2026-10-14 01:04:46.97239	Positive	0.2458	["Makeable"]	["Singapore", "San Francisco", "Vietnam"]	["Raymond Loong Ng"]	0.6369	Positive	Positive	1	0	Society	0.6700	My cofounder and I were rivals at hackathons. At 21, I've put college on hold to build a startup with him.. He was accepted into Singapore's top university, but had to request a leave of absence before his first day to build a startup in San Francisco.	81	["build", "san francisco", "francisco", "san"]	132
178	Top Science Photography Award Winner Stripped For AI Use	Following the incident, Nikon said in a statement that it plans to 'revisit rules and evaluation procedures for future competition entries.'\nThe winner of one of the worldΓÇÖs most prestigious scientific photography awards has been stripped of the top prize aftΓÇª	The winner of one of the worlds most prestigious scientific photography awards has been stripped of the top prize after their entry was outed as using generative AI.\r\nDr Ning Xu, from Tsinghua UniverΓÇª	https://me.pcmag.com/en/ai/38305/top-science-photography-award-winner-stripped-for-ai-use	PCMag.com	Will Mccurdy	2026-10-12 03:07:11	2026-10-14 01:04:46.97239	Positive	0.3571	["Nikon"]	["AI"]	["Ning Xu", "Tsinghua Univer"]	0.9847	Positive	Positive	6	1	Technology	1.0000	Top Science Photography Award Winner Stripped For AI Use.	84	["rules", "future", "awards", "award", "plans"]	133
179	MyanmarΓÇÖs Min Aung Hlaing to Visit Indonesia and Brunei, Regime Spokesperson Says	Since taking office in April, the former general has visited five ASEAN member states as he seeks normalization with the Southeast Asian bloc.	Myanmars military-appointed President Min Aung Hlaing could follow up his controversial state visit to Malaysia with trips to Indonesia and Brunei, according to a Myanmar government spokesperson.\r\nSpΓÇª	https://thediplomat.com/2026/10/myanmars-min-aung-hlaing-to-visit-indonesia-and-brunei-regime-spokesperson-says/	The Diplomat	Sebastian Strangio	2026-10-12 01:54:00	2026-10-14 01:04:46.97239	Positive	0.1500	["ASEAN"]	["Myanmar", "Indonesia", "Brunei", "Malaysia"]	["Min Aung"]	-0.2023	Negative	Negative	0	0	Politics	0.5000	MyanmarΓÇÖs Min Aung Hlaing to Visit Indonesia and Brunei, Regime Spokesperson Says. Since taking office in April, the former general has visited five ASEAN member states as he seeks normalization with the Southeast Asian bloc.	63	["seeks", "myanmar", "office", "indonesia", "states"]	134
180	FPT and NAVER Cloud Form Strategic Alliance to Fuel AI Innovation Across Asia-Pacific and Beyond	HANOI, Vietnam, October 12, 2026--(BUSINESS WIRE)--Global ICT corporation FPT and NAVER Cloud, one of South Korea's largest technology companies, have signed a memorandum of understanding (MOU) to expand their AI Factory business and market presence across AsΓÇª	HANOI, Vietnam, October 12, 2026--(BUSINESS WIRE)--Global ICT corporation FPT and NAVER Cloud, one of South Korea's largest technology companies, have signed a memorandum of understanding (MOU) to exΓÇª	https://biztoc.com/x/5fefe1389aaa282b	Biztoc.com	finance.yahoo.com	2026-10-12 01:26:27	2026-10-14 01:04:46.97239	Neutral	0.0000	["FPT", "NAVER", "ICT", "MOU", "AI Factory"]	["Vietnam", "South Korea's"]	["Beyond HANOI", "NAVER Cloud"]	0.5994	Positive	Positive	12	1	Technology	0.8000	FPT and NAVER Cloud Form Strategic Alliance to Fuel AI Innovation Across Asia-Pacific and Beyond.	80	["cloud", "business", "technology", "fuel", "form"]	135
181	Idaho Voters Get to Help Choose State Firearm on Election Day	Idaho voters will be able to cast a vote for one of six guns on Election Day, and the votes will serve an "advisory" role to guide the legislature in choosing the official gun of Idaho.\nThe post Idaho Voters Get to Help Choose State Firearm on Election Day apΓÇª	Idaho voters will be able to cast a vote for one of six guns on Election Day, and the votes will serve an ΓÇ£advisoryΓÇ¥ role to guide the legislature in choosing the official gun of Idaho.\r\nIdaho News 6ΓÇª	https://www.breitbart.com/2nd-amendment/2026/10/11/idaho-voters-help-choose-state-firearm-election-day/	Breitbart News	AWR Hawkins	2026-10-12 01:15:32	2026-10-14 01:04:46.97239	Positive	0.5000	["Idaho Voters Get", "Idaho News"]	["Idaho"]	["Firearm"]	0.1531	Positive	Positive	0	0	Politics	1.0000	Idaho Voters Get to Help Choose State Firearm on Election Day. Idaho voters will be able to cast a vote for one of six guns on Election Day, and the votes will serve an "advisory" role to guide the legislature in choosing the official gun of Idaho.	100	["idaho", "idaho voters", "voters", "state", "help"]	136
182	Thai Horror ΓÇÿRinrada: The InfluencerΓÇÖ Scores Asia, Middle East Deals Around Screamfest Premiere (EXCLUSIVE)	Thai horror hit ΓÇ£Rinrada: The Influencer,ΓÇ¥ which stars Yoshi Rinrada in her first horror lead, has closed distribution deals in Asia and the Middle East around its North American debut at Screamfest. The story centers on an influencer whose life is wrecked byΓÇª	Thai horror hit ΓÇ£Rinrada: The Influencer,ΓÇ¥ which stars Yoshi Rinrada in her first horror lead, has closed distribution deals in Asia and the Middle East around its North American debut at Screamfest.ΓÇª	https://variety.com/2026/film/markets-festivals/thai-horror-rinrada-asia-middle-east-deals-1236908571/	Variety	Naman Ramachandran	2026-10-12 00:11:02	2026-10-14 01:04:46.97239	Neutral	0.0333	["The InfluencerΓÇÖ Scores Asia"]	["Screamfest"]	["Thai Horror ΓÇÿ"]	-0.9536	Negative	Negative	0	0	Technology	1.0000	Thai Horror ΓÇÿRinrada: The InfluencerΓÇÖ Scores Asia, Middle East Deals Around Screamfest Premiere (EXCLUSIVE).	89	["rinrada", "horror", "influencer", "thai", "middle east"]	137
183	DPAA Identifies Record Number of Missing Service Members	The Defense POW/MIA Accounting Agency identified the remains of 250 service members missing from past conflicts in fiscal year 2026, surpassing its previous record of 231 set last year. ┬á The last identification was Army Capt. Albert P. Wilcox from CaliforniaΓÇª	The Defense POW/MIA Accounting Agency identified the remains of 250 service members missing from past conflicts in fiscal year 2026, surpassing its previous record of 231 set last year. ┬á\r\nThe last iΓÇª	https://soldiersystems.net/2026/10/12/dpaa-identifies-record-number-of-missing-service-members/	Soldiersystems.net	Eric G	2026-10-12 00:00:00	2026-10-14 01:04:46.97239	Negative	-0.1303	["Army Capt", "The Defense POW/MIA Accounting Agency"]	["California"]	["Albert P. Wilcox"]	-0.8176	Negative	Negative	0	0	Military	0.7500	DPAA Identifies Record Number of Missing Service Members. The Defense POW/MIA Accounting Agency identified the remains of 250 service members missing from past conflicts in fiscal year 2026, surpassing its previous record of 231 set last year.	80	["service", "record", "remains", "agency", "past"]	138
184	A jihadi hiding in plain sight? A trail of extremist online posts, a confession he wished to 'die a martyr'... warning signs of British-trained co-pilot turned 'hijacker'	On July 10, 2019, the then Prince Charles opened a ┬ú75million state-of-the-art pilot training centre a couple of miles south of Gatwick Airport.	On July 10, 2019, the then Prince Charles opened a ┬ú75million state-of-the-art pilot training centre a couple of miles south of Gatwick.\r\nAfter testing out a cutting-edge flight simulator, the King aΓÇª	https://www.dailymail.com/news/article-16197009/trail-extremist-social-media-posts-British-flight-trained-pilot-attempted-hijack-jet-Israel-jihadi-hiding.html	Dailymail.com	Glen Keogh	2026-10-11 23:03:21	2026-10-14 01:04:46.97239	Negative	-0.2143	[]	[]	["Charles", "Gatwick"]	-0.8176	Negative	Negative	0	0	Society	0.5000	A jihadi hiding in plain sight? A trail of extremist online posts, a confession he wished to 'die a martyr'... warning signs of British-trained co-pilot turned 'hijacker'.	82	["pilot", "miles", "turned", "opened", "state"]	139
185	Hackaday Links: October 11, 2026	It probably goes without saying that if you send four humans to observe the Moon up close, theyΓÇÖll see things that those of us stuck here on Earth have never noticed. Luckily for us, they tooΓÇª	It probably goes without saying that if you send four humans to observe the Moon up close, theyΓÇÖll see things that those of us stuck here on Earth have never noticed. Luckily for us, they took impeccΓÇª	https://hackaday.com/2026/10/11/hackaday-links-october-11-2026/	Hackaday	Tom Nardi	2026-10-11 23:00:39	2026-10-14 01:04:46.97239	Positive	0.3333	[]	[]	["Hackaday", "Moon"]	-0.8128	Negative	Negative	0	0	Society	1.0000	Hackaday Links: October 11, 2026. It probably goes without saying that if you send four humans to observe the Moon up close, theyΓÇÖll see things that those of us stuck here on Earth have never noticed. Luckily for us, they tooΓÇª	78	["goes", "close", "links", "october"]	140
186	Robert De Niro's First Major Movie Was A Controversial Comedy From A Legendary Director	A very young Robert De Niro starred in this Brian De Palma-directed comedy film, which was fairly controversial at the time due to its content.	Brian De Palma's 1968 comedy movie "Greetings," starring a young Robert De Niro, was the very first narrative film to receive an "X" rating. Keep in mind, though, this was before the adult film indusΓÇª	https://www.slashfilm.com/2281028/robert-de-niro-first-major-movie-controversial-comedy-greetings/	/FILM	staff@slashfilm.com (Witney Seibold)	2026-10-11 21:00:00	2026-10-14 01:04:46.97239	Positive	0.2943	[]	[]	["Robert De Niro's", "Robert De Niro", "Brian De Palma-directed", "Brian De Palma's"]	0.7717	Positive	Positive	0	0	Technology	1.0000	Robert De Niro's First Major Movie Was A Controversial Comedy From A Legendary Director. A very young Robert De Niro starred in this Brian De Palma-directed comedy film, which was fairly controversial at the time due to its content.	74	["content", "directed", "major", "film"]	141
187	All 6 Ben Affleck-Directed Movies, Ranked (Including Animals)	Ben Affleck returned to the directors chair for his latest film, Animals. Here's how it ranks against the other movies Affleck has directed.	Now we get to the good stuff. Affleck's lightest film and the closest to a straight-up comedy, "Air" is about how Nike signed an endorsement deal with Michael Jordan in 1984, shortly before he becameΓÇª	https://www.slashfilm.com/2283288/ben-affleck-directed-movies-ranked/	/FILM	staff@slashfilm.com (Devin Meenan)	2026-10-11 18:30:00	2026-10-14 01:04:46.97239	Positive	0.2687	["Nike"]	[]	["Ben Affleck-Directed Movies", "Ben Affleck", "Affleck", "Michael Jordan"]	0.7717	Positive	Positive	0	0	Technology	1.0000	All 6 Ben Affleck-Directed Movies, Ranked (Including Animals). Ben Affleck returned to the directors chair for his latest film, Animals. Here's how it ranks against the other movies Affleck has directed.	66	["directed", "returned", "including", "film"]	142
189	Visa Survey Shows Nearly Half of APAC Consumers Eyeing Stablecoins for Everyday Use by 2031	VisaΓÇÖs Consumer 360 research finds 46% of Asia-Pacific consumers likely to adopt stablecoins within five years, up from 16% recent usage, with interest in spending and transfers but barriers in understanding and trust.\nThe post Visa Survey Shows Nearly Half oΓÇª	Visa is releasing new survey findings showing rising consumer interest in stablecoins for practical payments across Asia Pacific.\r\nThe company says 46% of consumers are likely to use stablecoins in tΓÇª	https://dailyhodl.com/2026/10/11/visa-survey-shows-nearly-half-of-apac-consumers-eyeing-stablecoins-for-everyday-use-by-2031/	The Daily Hodl	Daily Hodl Agent	2026-10-11 16:55:11	2026-10-14 01:04:46.97239	Neutral	-0.0567	["Visa"]	[]	["Visa Survey Shows"]	0.8957	Positive	Positive	0	0	Society	1.0000	Visa Survey Shows Nearly Half of APAC Consumers Eyeing Stablecoins for Everyday Use by 2031.	87	["visa", "half", "nearly", "asia pacific", "finds"]	144
190	Korean Air: Los Angeles ΓÇô Da Nang, Vietnam, Vietnam. $786. Roundtrip, including all Taxes	A good sale to Da NangSample Travel Date:March 3rd - 10th, 2027This is just ONE SAMPLE travel date, for more availability, please follow the "Fare Availability" and "How to	A good sale to Da Nang\r\nSign up for our Real Time Newsletter to receive economy class deals for your city about an hour before they are even posted on our website and social media channels - all for ΓÇª	https://www.theflightdeal.com/2026/10/11/korean-air-los-angeles-da-nang-vietnam-vietnam-786-roundtrip-including-all-taxes/	Theflightdeal.com	The Flight Deal	2026-10-11 16:53:54	2026-10-14 01:04:46.97239	Positive	0.3556	["Taxes", "Da NangSample Travel Date", "the \\"Fare Availability", "Real Time Newsletter"]	["Los Angeles", "Vietnam"]	["Roundtrip", "Da Nang\\r\\nSign"]	0.8115	Positive	Positive	9	1	Economy	0.3300	Korean Air: Los Angeles ΓÇô Da Nang, Vietnam, Vietnam. $786. Roundtrip, including all Taxes.	83	["availability", "travel date", "date", "travel", "sale nangsample"]	145
191	FCC Could Soon Ban Chinese Labs From Testing US Electronics	According to the FCCΓÇÖs data, 82% of devices authorized for sale in the US in 2025 were tested in China first.\nThe FCC is getting ready to vote on a proposal which could see Chinese labs banned from testing US electronics. Before any electronic device is markeΓÇª	The FCC is getting ready to vote on a proposal which could see Chinese labs banned from testing US electronics. Before any electronic device is marketed in the US, it must be tested by an approved laΓÇª	https://uk.pcmag.com/security/167865/fcc-could-soon-ban-chinese-labs-from-testing-us-electronics	PCMag.com	Will Mccurdy	2026-10-11 16:47:33	2026-10-14 01:04:46.97239	Positive	0.1083	["FCC"]	["US", "China"]	[]	-0.4215	Negative	Negative	0	0	Economy	1.0000	FCC Could Soon Ban Chinese Labs From Testing US Electronics. According to the FCCΓÇÖs data, 82% of devices authorized for sale in the US in 2025 were tested in China first.	94	["testing", "electronics", "chinese", "ban", "devices"]	146
192	Korean Air: Dallas ΓÇô Da Nang, Vietnam, Vietnam. $864. Roundtrip, including all Taxes	A good sale to Da NangSample Travel Date:February 10th - 17th, 2027This is just ONE SAMPLE travel date, for more availability, please follow the "Fare Availability" and "Ho	A good sale to Da Nang\r\nSign up for our Real Time Newsletter to receive economy class deals for your city about an hour before they are even posted on our website and social media channels - all for ΓÇª	https://www.theflightdeal.com/2026/10/11/korean-air-dallas-da-nang-vietnam-vietnam-864-roundtrip-including-all-taxes/	Theflightdeal.com	The Flight Deal	2026-10-11 16:43:03	2026-10-14 01:04:46.97239	Positive	0.4267	["Taxes", "Da NangSample Travel Date", "the \\"Fare Availability", "Real Time Newsletter"]	["Dallas", "Vietnam"]	["Da Nang", "Roundtrip", "Da Nang\\r\\nSign"]	0.8115	Positive	Positive	9	1	Economy	0.3300	Korean Air: Dallas ΓÇô Da Nang, Vietnam, Vietnam. $864. Roundtrip, including all Taxes.	81	["availability", "travel date", "date", "travel", "sale nangsample"]	145
193	Korean Air: Chicago ΓÇô Da Nang, Vietnam, Vietnam. $868. Roundtrip, including all Taxes	A good sale to Da NangSample Travel Date:February 10th - 17th, 2027This is just ONE SAMPLE travel date, for more availability, please follow the "Fare Availability" and "Ho	A good sale to Da Nang\r\nSign up for our Real Time Newsletter to receive economy class deals for your city about an hour before they are even posted on our website and social media channels - all for ΓÇª	https://www.theflightdeal.com/2026/10/11/korean-air-chicago-da-nang-vietnam-vietnam-868-roundtrip-including-all-taxes/	Theflightdeal.com	The Flight Deal	2026-10-11 16:33:36	2026-10-14 01:04:46.97239	Positive	0.4267	["Taxes", "Da NangSample Travel Date", "the \\"Fare Availability", "Real Time Newsletter"]	["Chicago", "Vietnam"]	["Roundtrip", "Da Nang\\r\\nSign"]	0.8115	Positive	Positive	9	1	Economy	0.3300	Korean Air: Chicago ΓÇô Da Nang, Vietnam, Vietnam. $868. Roundtrip, including all Taxes.	81	["availability", "travel date", "date", "travel", "chicago"]	145
194	Want relief from double taxation on foreign income under DTAA? Know how to apply for residency certificate using Form 42	Indian residents earning income abroad may need a Tax Residency Certificate to claim benefits under tax treaties. The Income Tax Department allows eligible taxpayers to apply online under the Income-tax Act, 2025. HereΓÇÖs how Form 42 works, who can apply and wΓÇª	Indian residents earning income from overseas may need a Tax Residency Certificate (TRC) to claim tax benefits under a Double Taxation Avoidance Agreement (DTAA).\r\nUnder the Income-tax Act, 2025, appΓÇª	https://www.livemint.com/money/personal-finance/want-relief-from-double-taxation-on-foreign-income-under-dtaa-know-how-to-apply-for-residency-certificate-using-form-42-11791732238647.html	Livemint	Sheetal Goel	2026-10-11 16:30:24	2026-10-14 01:04:46.97239	Neutral	-0.0417	["DTAA", "a Tax Residency Certificate", "The Income Tax Department"]	[]	[]	0.8442	Positive	Positive	0	0	Society	0.5000	Want relief from double taxation on foreign income under DTAA? Know how to apply for residency certificate using Form 42. Indian residents earning income abroad may need a Tax Residency Certificate to claim benefits under tax treaties.	92	["tax", "income", "form", "department", "using"]	147
195	Hunting Pastors Point to Genesis 1:26: 'We're Managing God's Creation'	Twin brothers Chad and James Hampton, both pastors, point to Genesis 1:26 as they hunt and say they are "managing God's creation."\nThe post Hunting Pastors Point to Genesis 1:26: ΓÇÿWeΓÇÖre Managing GodΓÇÖs CreationΓÇÖ appeared first on Breitbart.	Twin brothers Chad and James Hampton, both pastors, point to Genesis 1:26 as they hunt and say they are ΓÇ£managing GodΓÇÖs creation.ΓÇ¥\r\nFOX News spoke with the brothers, who founded HuntinΓÇÖ the Truth MinΓÇª	https://www.breitbart.com/2nd-amendment/2026/10/11/hunting-pastors-point-to-genesis-126-were-managing-gods-creation/	Breitbart News	AWR Hawkins	2026-10-11 16:15:42	2026-10-14 01:04:46.97239	Positive	0.2500	["FOX News", "Huntin"]	["Breitbart"]	["Chad", "James Hampton", "Twin"]	0.6705	Positive	Positive	0	0	Society	1.0000	Hunting Pastors Point to Genesis 1:26: 'We're Managing God's Creation'.	82	["god creation", "god", "genesis", "point", "creation"]	148
299	Doc Stories Unveils 12th Annual Film Lineup (EXCLUSIVE)	Ava DuVernayΓÇÖs ΓÇ£14thΓÇ¥ will open the 12th edition of San FranciscoΓÇÖs documentary film festival Doc Stories on Nov. 5. The Netflix film, which premiered at New York Film Festival earlier this month, is one of 10 Oscar-contending feature documentaries included iΓÇª	Ava DuVernayΓÇÿs ΓÇ£14thΓÇ¥ will open the 12th edition of San FranciscoΓÇÖs documentary film festival Doc Stories on Nov. 5.\r\nThe Netflix film, which premiered at New York Film Festival earlier this month, iΓÇª	https://variety.com/2026/film/news/doc-stories-film-lineup-14th-1236910719/	Variety	Addie Morfoot	2026-10-14 17:00:00	2026-10-15 17:24:58.977342	Neutral	0.0341	["Doc Stories Unveils", "Doc Stories", "New York Film Festival"]	["San FranciscoΓÇÖs", "Netflix"]	["Film Lineup"]	0.9329	Positive	Positive	0	0	General	0.0000	Doc Stories Unveils 12th Annual Film Lineup (EXCLUSIVE). Ava DuVernayΓÇÖs ΓÇ£14thΓÇ¥ will open the 12th edition of San FranciscoΓÇÖs documentary film festival Doc Stories on Nov. 5.	82	["film", "doc stories", "film festival", "stories", "festival"]	149
300	SFFILMΓÇÖs Doc Stories To Open With Ava DuVernayΓÇÖs ΓÇÿ14th,ΓÇÖ Showcase ΓÇÿTutu,ΓÇÖ ΓÇÿBlack Sunflowers,ΓÇÖ ΓÇÖSoul PatrolΓÇÖ & More	Oscar winners and Oscar-nominated filmmakers will be converging on San Francisco for the 12th edition of Doc Stories, the prestigious nonfiction film festival put on by SFFILM. The cinematic event running November 5-8 will open with 14th, Ava DuVernayΓÇÖs penetΓÇª	Oscar winners and Oscar-nominated filmmakers will be converging on San Francisco for the 12th edition of Doc Stories, the prestigious nonfiction film festival put on by SFFILM.\r\nThe cinematic event rΓÇª	http://deadline.com/2026/10/sffilm-doc-stories-2026-lineup-announcement-1237156521/	Deadline	Matthew Carey	2026-10-14 17:00:00	2026-10-15 17:24:58.977342	Neutral	0.0556	["Doc Stories", "SFFILM"]	["San Francisco"]	["SFFILMΓÇÖs Doc Stories", "Oscar", "Ava DuVernayΓÇÖs"]	0.9166	Positive	Positive	0	0	General	0.0000	SFFILMΓÇÖs Doc Stories To Open With Ava DuVernayΓÇÖs ΓÇÿ14th,ΓÇÖ Showcase ΓÇÿTutu,ΓÇÖ ΓÇÿBlack Sunflowers,ΓÇÖ ΓÇÖSoul PatrolΓÇÖ & More.	88	["doc stories", "stories", "ava duvernay", "ava", "duvernay"]	149
301	utelearn 10.24.2026	A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	A required part of this site couldnt load. This may be due to a browser\r\n extension, network issues, or browser settings. Please check your\r\n connection, disable any ad blockers, or try using a diffeΓÇª	https://pypi.org/project/utelearn/10.24.2026/	Pypi.org	dung.cai@hcmute.edu.vn	2026-10-14 16:57:23	2026-10-15 17:24:58.977342	Neutral	0.0625	[]	["HCMUTE", "Vietnam"]	[]	0.3182	Positive	Positive	0	0	General	0.0000	utelearn 10.24.2026. A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	49	["machine", "library built", "purpose hcmute", "purpose", "learning library"]	98
302	Charlie Plumb reveals how a Navy fighter pilot survived 2,103 days in the Hanoi Hilton by changing one single word in his own head: the ten lines below are the actual tools he used to come out the other side stronger instead of broken	BJ Ganem@BJGanem┬╖Oct 13Charlie Plumb reveals how a Navy fighter pilot survived 2,103 days in the Hanoi Hilton by changing one single word in his own head:He was tortured, isolated, and lied to for six straight years, and the ten lines below are the actual tooΓÇª	BJ Ganem@BJGanem┬╖Oct 13Charlie Plumb reveals how a Navy fighter pilot survived 2,103 days in the Hanoi Hilton by changing one single word in his own head:\r\nHe was tortured, isolated, and lied to for ΓÇª	https://freerepublic.com/focus/f-chat/4399159/posts	Freerepublic.com	X.com	2026-10-14 16:50:04	2026-10-15 17:24:58.977342	Neutral	0.0970	["Navy", "BJ"]	[]	["Charlie Plumb"]	-0.4404	Negative	Negative	0	0	General	0.0000	Charlie Plumb reveals how a Navy fighter pilot survived 2,103 days in the Hanoi Hilton by changing one single word in his own head: the ten lines below are the actual tools he used to come out the other side stronger instead of broken.	124	["pilot", "head", "changing", "reveals", "days"]	150
303	Show HN: An offline 0.8B model that ties Gemini Flash on OpenStreetMap questions	A 0.8B open-weights model trained with RL on three 3090s to answer travel questions over OpenStreetMap and a blog corpus, offline on an iPhone, scoring 83/100 on the new Ask Maps Basic eval, tied with Gemini 3.8 Flash.	When you are travelling the world you want the freedom to explore it without internet. There is a lot of amazing open data you can download to your phone, OpenStreetMap and Wikipedia among it, but soΓÇª	https://jonready.com/blog/posts/rl-on-a-0_8b-travel-agent.html	Jonready.com	mips_avatar	2026-10-14 16:46:21	2026-10-15 17:24:58.977342	Positive	0.1841	["OpenStreetMap", "iPhone", "Wikipedia"]	[]	["Gemini Flash", "RL", "Gemini", "3.8 Flash"]	0.5647	Positive	Positive	0	0	General	0.0000	Show HN: An offline 0.8B model that ties Gemini Flash on OpenStreetMap questions.	87	["questions", "open", "travel"]	151
304	ΓÇÿThe GreatestΓÇÖ Trailer: Prime Series Exec Produced By Michael B. Jordan Explores Life Of Iconic Boxer Muhammad Ali	WeΓÇÖve been very excited for ΓÇ£The Greatest,ΓÇ¥ a new Prime Video series that will cover the events surrounding the life of famed and beloved boxer and civil rights advocate Muhammad Ali (formerly known as Cassius Clay before his conversion to Islam and his growiΓÇª	WeΓÇÖve been very excited for ΓÇ£The Greatest,ΓÇ¥ a new Prime Video series that will cover the events surrounding the life of famed and beloved boxer and civil rights advocate Muhammad Ali (formerly known ΓÇª	https://theplaylist.net/the-greatest-trailer-prime-video-20261014/	Theplaylist.net	Christopher Marc	2026-10-14 16:37:08	2026-10-15 17:24:58.977342	Positive	0.5123	["Cassius Clay"]	[]	["Trailer", "Michael B. Jordan", "Muhammad Ali"]	0.8998	Positive	Positive	0	0	General	0.0000	ΓÇÿThe GreatestΓÇÖ Trailer: Prime Series Exec Produced By Michael B. Jordan Explores Life Of Iconic Boxer Muhammad Ali.	96	["muhammad ali", "series", "muhammad", "life", "greatest"]	152
305	SamsungΓÇÖs New Fridge DoesnΓÇÖt Just Chill Your Food; It Learns What You Eat	At its regional showcase in Hanoi, Vietnam, SamsungΓÇÖs consumer appliance narrative made one thing clear: the modern home is not being overhauled with radical hardware reinventions, but rather through iterative software upgrades and cloud-backed data. HeadliniΓÇª	At its regional showcase in Hanoi, Vietnam, Samsungs consumer appliance narrative made one thing clear: the modern home is not being overhauled with radical hardware reinventions, but rather through ΓÇª	https://soyacincau.com/2026/10/15/samsung-bespoke-ai-family-hub-refrigerator/	SoyaCincau.com	Sudarshan Duke	2026-10-14 16:00:55	2026-10-15 17:24:58.977342	Positive	0.1473	["SamsungΓÇÖs New Fridge Does", "Samsung"]	["Hanoi", "Vietnam"]	["Headlini"]	0.6369	Positive	Positive	0	0	General	0.0000	SamsungΓÇÖs New Fridge DoesnΓÇÖt Just Chill Your Food; It Learns What You Eat.	79	["samsung", "narrative", "home", "hardware", "cloud"]	153
306	ΓÇÿAmerican Doctor,ΓÇÖ ΓÇÿNAZA,ΓÇÖ ΓÇÿMusk,ΓÇÖ Elizabeth Holmes Doc And More Make DOC NYCΓÇÖs Prestigious Short List	DOC NYC announced its influential short lists Wednesday, often a reliable gauge of which documentaries are connecting with awards voters as Oscar season heats up. Among the films making the festivalΓÇÖs short list of features: Ava DuVernayΓÇÖs 14th; You Can See EΓÇª	DOC NYC announced its influential short lists Wednesday, often a reliable gauge of which documentaries are connecting with awards voters as Oscar season heats up.\r\nAmong the films making the festivalΓÇª	http://deadline.com/2026/10/doc-nyc-2026-short-lists-announcement-1237156501/	Deadline	Matthew Carey	2026-10-14 16:00:00	2026-10-15 17:24:58.977342	Neutral	0.0833	["DOC NYC"]	[]	["Elizabeth Holmes Doc", "Oscar", "Ava DuVernayΓÇÖs"]	0.8957	Positive	Positive	0	0	General	0.0000	ΓÇÿAmerican Doctor,ΓÇÖ ΓÇÿNAZA,ΓÇÖ ΓÇÿMusk,ΓÇÖ Elizabeth Holmes Doc And More Make DOC NYCΓÇÖs Prestigious Short List.	88	["short", "doc", "short list", "nyc", "doc nyc"]	154
329	The Nobel Peace Prize has become a fig leaf for left-wing activism	Alfred Nobel created an award for world peace, but Navi Pillay's selection highlights how the committee rewards progressive causes over diplomacy.	Alfred Nobel intended the peace prize for those who had done the most to advance peace among nations. Instead, it is increasingly handed out to the international activist class: people who say the riΓÇª	https://www.foxnews.com/opinion/nobel-peace-prize-has-become-fig-leaf-left-wing-activism	Fox News		2026-10-14 11:00:15	2026-10-15 17:24:58.977342	Positive	0.2500	["Navi Pillay's"]	[]	["Alfred Nobel"]	0.9816	Positive	Positive	0	0	General	0.0000	The Nobel Peace Prize has become a fig leaf for left-wing activism. Alfred Nobel created an award for world peace, but Navi Pillay's selection highlights how the committee rewards progressive causes over diplomacy.	67	["peace", "highlights", "created", "award", "world"]	174
307	From ΓÇÖYou Can See EverythingΓÇÖ to ΓÇÖ14thΓÇÖ and ΓÇÿMusk,ΓÇÖ DOC NYC 2026 Reveals Influential Awards Short List	The DOC NYC Short List is often predictive of December's eventual Oscar shortlist. Films that are also nominated for Best Feature at the Critics Choice Award Documentary Awards get a leg up for future non-fiction awards.	Seventeen-year-old DOC NYC, AmericaΓÇÖs largest documentary festival, has revealed its influential 15-film Short List. The festival will run its main lineup of 118 features, 26 world premieres, 27 U.S.ΓÇª	https://www.indiewire.com/awards/industry/doc-nyc-2026-awards-short-list-you-can-see-everything-musk-1235221889/	IndieWire	Anne Thompson	2026-10-14 16:00:00	2026-10-15 17:24:58.977342	Positive	0.1458	["DOC", "Best Feature", "the Critics Choice Award Documentary Awards", "Short List"]	["America", "U.S."]	["Oscar"]	0.9792	Positive	Positive	0	0	General	0.0000	From ΓÇÖYou Can See EverythingΓÇÖ to ΓÇÖ14thΓÇÖ and ΓÇÿMusk,ΓÇÖ DOC NYC 2026 Reveals Influential Awards Short List. The DOC NYC Short List is often predictive of December's eventual Oscar shortlist.	82	["awards", "short list", "short", "nyc", "doc nyc"]	154
308	From Bob Hope to MacyΓÇÖs Thanksgiving Day Parade to ΓÇÿWicked: One Wonderful NightΓÇÖ: How NBC Became AmericaΓÇÖs Home for TV Specials	It didnΓÇÖt get great reviews. The host was awkward on camera as he navigated the emerging medium. The musical numbers and sketches didnΓÇÖt translate well to the home screen. But none of it mattered. Bob HopeΓÇÖs first-ever television special for NBC ΓÇö ΓÇ£The FrigidΓÇª	It didnΓÇÖt get great reviews. The host was awkward on camera as he navigated the emerging medium. The musical numbers and sketches didnΓÇÖt translate well to the home screen.\r\nBut none of it mattered. BΓÇª	https://variety.com/2026/tv/news/bob-hope-macys-thanksgiving-day-parade-wicked-nbc-specials-1236909503/	Variety	Emily Longeretta	2026-10-14 15:15:00	2026-10-15 17:24:58.977342	Positive	0.1675	["MacyΓÇÖs", "Became AmericaΓÇÖs Home for TV Specials", "NBC", "Frigid"]	[]	["Bob Hope"]	0.9520	Positive	Positive	0	0	General	0.0000	From Bob Hope to MacyΓÇÖs Thanksgiving Day Parade to ΓÇÿWicked: One Wonderful NightΓÇÖ: How NBC Became AmericaΓÇÖs Home for TV Specials. It didnΓÇÖt get great reviews. The host was awkward on camera as he navigated the emerging medium.	100	["hope", "didn", "home", "reviews", "emerging"]	155
309	Joni Mitchell becomes an American citizen after more than 60 years	Joni Mitchell can see both sides of the U.S.-Canada border freely now.	Joni Mitchell can see both sides of the U.S.-Canada border freely now. \r\nThe famed Canadian singer-songwriter shared a major milestone with fans on Tuesday, posing with an American flag to reveal sheΓÇª	https://www.nbcnews.com/pop-culture/pop-culture-news/joni-mitchell-becomes-american-citizen-60-years-rcna603430	NBC News	Doha Madani	2026-10-14 15:14:22	2026-10-15 17:24:58.977342	Positive	0.1925	["U.S.-Canada"]	[]	["Joni Mitchell"]	0.6486	Positive	Positive	0	0	General	0.0000	Joni Mitchell becomes an American citizen after more than 60 years. Joni Mitchell can see both sides of the U.S.-Canada border freely now.	43	["american"]	156
310	Ledger Suspends Southeast Asian Resellers During $90 Million Crypto Wallet Hack Investigation	Ledger is asking resellers and distributors in Southeast Asia and Hong Kong to suspend sales of its cryptocurrency hardware wallets while it investigates an incident in which someone in the distribution chain tampered with the devices and later drained cryptoΓÇª	Ledger is asking resellers and distributors in Southeast Asia and Hong Kong to suspend sales of its cryptocurrency hardware wallets while it investigates an incident in which someone in the distributΓÇª	https://www.pymnts.com/cryptocurrency/2026/ledger-suspends-southeast-asian-resellers-during-90-million-crypto-wallet-hack-investigation/	pymnts.com	PYMNTS	2026-10-14 15:09:59	2026-10-15 17:24:58.977342	Neutral	0.0000	[]	["Hong Kong"]	[]	-0.7269	Negative	Negative	0	0	General	0.0000	Ledger Suspends Southeast Asian Resellers During $90 Million Crypto Wallet Hack Investigation.	83	["crypto", "resellers", "ledger", "southeast", "kong"]	59
311	HTX Publishes Its Q3 2026 Scorecard: Cumulative TradFi Trading Volume Approaches $6B Amid 13th Anniversary Celebration	Apia, Samoa, October 14, 2026 ΓÇô The crypto market saw a notable rally in the just-concluded third quarter. It was also the quarter in which HTX turned 13. Over the past 13 years, the industry has weathered multiple bull and bear cycles, and HTX has stood alonΓÇª	Strict editorial policy that focuses on accuracy, relevance, and impartiality\r\nCreated by industry experts and meticulously reviewed\r\nThe highest standards in reporting and publishing\r\nStrict editoriΓÇª	http://www.newsbtc.com/news/htx-publishes-its-q3-2026-scorecard-cumulative-tradfi-trading-volume-approaches-6b-amid-13th-anniversary-celebration/	newsBTC	BlockmanPR	2026-10-14 14:40:05	2026-10-15 17:24:58.977342	Neutral	0.0500	["Samoa", "HTX"]	[]	["Celebration Apia"]	0.2500	Positive	Positive	0	0	General	0.0000	HTX Publishes Its Q3 2026 Scorecard: Cumulative TradFi Trading Volume Approaches $6B Amid 13th Anniversary Celebration. Apia, Samoa, October 14, 2026 ΓÇô The crypto market saw a notable rally in the just-concluded third quarter.	89	["htx", "crypto", "anniversary", "volume", "saw"]	157
312	Actress Meenakshi Chaudhary in Vietnam holiday takes 3-day bike tour along Ha Giang Loop route; explores waterfalls and stunning mountains	Actress Meenakshi Chaudhary shared glimpses of her three-day bike trip through VietnamΓÇÖs Ha Giang Loop, featuring scenic mountain roads, lush valleys, waterfalls and swimming spots. The Lucky Bhaskar actress also posted pictures with fellow travellers and refΓÇª	Alpha Trade\r\nGet daily trade ideas from SEBI-registered research analysts.\r\nInvestment Ideas\r\nGrow your wealth with stock ideas &amp; sectoral trends.\r\nStock Reports Plus\r\nAll-in-one stock research wΓÇª	https://economictimes.indiatimes.com/magazines/panache/actress-meenakshi-chaudhary-in-vietnam-holiday-takes-3-day-bike-tour-along-ha-giang-loop-route-explores-waterfalls-and-stunning-mountains/articleshow/134943426.cms	The Times of India	ET Online	2026-10-14 14:14:28	2026-10-15 17:24:58.977342	Positive	0.2333	["Actress Meenakshi Chaudhary", "ref", "Alpha Trade\\r\\nGet"]	["Vietnam"]	["Ha Giang Loop", "Lucky Bhaskar"]	0.9477	Positive	Positive	0	0	General	0.0000	Actress Meenakshi Chaudhary in Vietnam holiday takes 3-day bike tour along Ha Giang Loop route; explores waterfalls and stunning mountains.	85	["holiday", "explores"]	158
313	Climate scientists issue a sobering diagnosis about Earth's 'vital signs'	ΓÇ£The climate emergency is already hereΓÇ¥	Earth faces ΓÇ£rapid destabilizationΓÇ¥ as a result of climate change, an international group of scientists find in the latest edition of an annual checkup of the planetΓÇÖs ΓÇ£vital signs.ΓÇ¥\r\nΓÇ£This is no lonΓÇª	https://www.scientificamerican.com/article/climate-scientists-issue-a-sobering-diagnosis-about-earths-vital-signs/	Scientific American	Jackie Flynn Mogensen	2026-10-14 14:00:00	2026-10-15 17:24:58.977342	Positive	0.1750	[]	[]	[]	-0.5267	Negative	Negative	0	0	General	0.0000	Climate scientists issue a sobering diagnosis about Earth's 'vital signs'. ΓÇ£The climate emergency is already hereΓÇ¥	49	["climate"]	159
314	Esquire First Look: The Greatest Goes Beyond the Ring to Show Muhammad AliΓÇÖs Family	Prime VideoΓÇÖs The Greatest explores Muhammad AliΓÇÖs rise through the family, faith, and early fights that shaped him into an icon.	Few people have lived a life like Muhammad Alis. The certified Greatest of All Time has had umpteen books, documentaries, and biographical dramas that tell and retell his years as a heavyweight champΓÇª	https://www.esquire.com/entertainment/tv/a74122978/prime-video-muhammad-ali-the-greatest/	esquire.com	Eric Francisco	2026-10-14 14:00:00	2026-10-15 17:24:58.977342	Positive	0.5250	[]	[]	["Muhammad AliΓÇÖs Family", "Muhammad AliΓÇÖs", "Muhammad Alis"]	0.9451	Positive	Positive	0	0	General	0.0000	Esquire First Look: The Greatest Goes Beyond the Ring to Show Muhammad AliΓÇÖs Family. Prime VideoΓÇÖs The Greatest explores Muhammad AliΓÇÖs rise through the family, faith, and early fights that shaped him into an icon.	68	["muhammad ali", "muhammad", "greatest", "ali", "shaped"]	152
315	Ledger Asks Resellers in Seven Asian Markets to Pull Devices After Suspected $86M Drain	European electronics chain MediaMarkt Saturn has also halted Ledger sales after a customer in Germany reported finding an implant.	In brief\r\n Ledger has asked resellers and distributors in six Southeast Asian countries and Hong Kong to suspend sales of its devices while it investigates tampered wallets. The companΓÇª	https://decrypt.co/380940/ledger-asks-resellers-in-seven-asian-markets-to-pull-devices-after-suspected-86m-drain	Decrypt	Decrypt Agent	2026-10-14 13:47:44	2026-10-15 17:24:58.977342	Neutral	0.0000	["Ledger Asks Resellers", "Ledger"]	["Germany", "Hong Kong"]	[]	-0.4939	Negative	Negative	0	0	General	0.0000	Ledger Asks Resellers in Seven Asian Markets to Pull Devices After Suspected $86M Drain. European electronics chain MediaMarkt Saturn has also halted Ledger sales after a customer in Germany reported finding an implant.	62	["ledger", "asian markets", "seven asian", "sales", "asks"]	160
316	Fortune Names Vinamilk CEO Among Asia's 100 Most Powerful Women for the Third Consecutive Year	HO CHI MINH CITY, Vietnam, Oct. 14, 2026 /PRNewswire/ -- Marking a significant milestone in its 50-year journey of pioneering nutritional advancements, Vietnam Dairy Products Joint Stock Company (Vinamilk) announces that CEO Mai Kieu Lien has been honored in ΓÇª	HO CHI MINH CITY, Vietnam, Oct. 14, 2026 /PRNewswire/ -- Marking a significant milestone in its 50-year journey of pioneering nutritional advancements, Vietnam Dairy Products Joint Stock Company (VinΓÇª	https://www.prnewswire.com/news-releases/fortune-names-vinamilk-ceo-among-asias-100-most-powerful-women-for-the-third-consecutive-year-302908636.html	PRNewswire		2026-10-14 13:36:00	2026-10-15 17:24:58.977342	Positive	0.3100	["Vietnam Dairy Products Joint Stock Company", "Vinamilk"]	["Vietnam"]	["Mai Kieu Lien", "Vin"]	0.8588	Positive	Positive	0	0	General	0.0000	Fortune Names Vinamilk CEO Among Asia's 100 Most Powerful Women for the Third Consecutive Year. HO CHI MINH CITY, Vietnam, Oct.	84	["ceo", "fortune", "women", "company", "prnewswire"]	161
317	Vietnam Buries Remains of 731 War Dead Nearly 6 Decades After the Tet Offensive	Generations in Vietnam have spent decades searching for loved ones who never returned from war, hoping to recover their remains.	HANOI, Vietnam (AP) Thousands carrying white flowers lined the roads in Vietnams Ho Chi Minh City Wednesday as the remains of 731 people believed to have been killed during the 1968 Tet Offensive werΓÇª	https://military.com/vietnam-buries-remains-of-731-war-dead-nearly-6-decades-after-the-tet-offensive	Military.com	MLT Staff	2026-10-14 13:25:16	2026-10-15 17:24:58.977342	Neutral	0.0500	["the Tet Offensive Generations", "AP"]	["Vietnam"]	[]	-0.8706	Negative	Negative	0	0	General	0.0000	Vietnam Buries Remains of 731 War Dead Nearly 6 Decades After the Tet Offensive. Generations in Vietnam have spent decades searching for loved ones who never returned from war, hoping to recover their remains.	68	["decades", "remains", "war", "returned", "nearly"]	162
318	Russia's Lavrov Arrives in Azerbaijan to Attend CICA Summit	Russian Foreign Minister Sergey Lavrov arrived in Azerbaijan on Wednesday, a day before the summit of the Conference on Interaction and Confidence-Building Measures in Asia (CICA), a Sputnik correspondent said.	Get the latest news from around the world, live coverage, off-beat stories, features and analysis.	https://sputnikglobe.com/20261014/russias-lavrov-arrives-in-azerbaijan-to-attend-cica-summit-1124881349.html	Sputnikglobe.com	Sputnik International	2026-10-14 13:20:53	2026-10-15 17:24:58.977342	Positive	0.1278	["Lavrov Arrives", "the Conference on Interaction and Confidence-Building Measures", "Sputnik"]	["Russia", "Azerbaijan"]	["Sergey Lavrov"]	0.0000	Neutral	Neutral	0	0	General	0.0000	Russia's Lavrov Arrives in Azerbaijan to Attend CICA Summit.	54	["summit", "russia", "measures", "minister", "foreign"]	163
319	Hong Kong Cinema @ BUSAN 2026 concludes successfully	Hong Kong Cinema @ BUSAN 2026, co-organised by the Cultural and Creative Industries Development Agency (CCIDA) of the Culture, Sports and Tourism Bureau ...	Hong Kong (ANTARA/ACN Newswire) -Hong Kong Cinema @BUSAN 2026, co-organised by the Cultural and Creative Industries Development Agency (CCIDA) of the Culture, Sports and Tourism Bureau (CSTB) of the ΓÇª	https://en.antaranews.com/news/435461/hong-kong-cinema-busan-2026-concludes-successfully	Antaranews.com	PR Wire	2026-10-14 13:15:41	2026-10-15 17:24:58.977342	Positive	0.3900	["the Cultural and Creative Industries Development Agency", "the Culture, Sports and Tourism Bureau", "ANTARA/ACN Newswire"]	["Hong Kong Cinema @ BUSAN 2026", "Hong Kong"]	[]	0.8402	Positive	Positive	0	0	General	0.0000	Hong Kong Cinema @ BUSAN 2026 concludes successfully. Hong Kong Cinema @ BUSAN 2026, co-organised by the Cultural and Creative Industries Development Agency (CCIDA) of the Culture, Sports and Tourism Bureau ...	62	["kong", "hong kong", "hong", "agency", "sports"]	164
320	Oritain Launches Supplier Intelligence Report, Revealing a New Era of Supply Chain Collaboration	Oritain, global leaders in forensic origin verification, announced the release of its Supplier Intelligence Report, a dedicated supplier deep dive building on ...	Singapore (ANTARA/ACN Newswire) -Oritain, global leaders in forensic origin verification, announced the release of its Supplier Intelligence Report, a dedicated supplier deep dive building on findingΓÇª	https://en.antaranews.com/news/435457/oritain-launches-supplier-intelligence-report-revealing-a-new-era-of-supply-chain-collaboration	Antaranews.com	PR Wire	2026-10-14 13:12:58	2026-10-15 17:24:58.977342	Neutral	0.0273	["Supplier Intelligence Report", "ANTARA/ACN Newswire"]	["Singapore"]	["Oritain Launches Supplier Intelligence Report"]	0.9360	Positive	Positive	0	0	General	0.0000	Oritain Launches Supplier Intelligence Report, Revealing a New Era of Supply Chain Collaboration.	62	["supplier", "oritain", "intelligence", "report", "supply chain"]	165
330	Grad student allegedly poisoned her colleague, tried to flee U.S.	Aili Wang, 32, was arrested at Los Angeles International Airport, where prosecutors allege she sought to return to China.	A Wyoming microbiology graduate student from China has been arrested on accusations she poisoned the tea of a colleague who had pending patents and with whom she didn't get along, then tried to flee ΓÇª	https://www.cbsnews.com/news/wyoming-grad-student-poisoned-colleague-arrested-fleeing-us/	CBS News		2026-10-14 10:43:44	2026-10-15 17:24:58.977342	Neutral	-0.0500	[]	["U.S.", "China", "Wyoming"]	[]	-0.9313	Negative	Negative	0	0	General	0.0000	Grad student allegedly poisoned her colleague, tried to flee U.S.. Aili Wang, 32, was arrested at Los Angeles International Airport, where prosecutors allege she sought to return to China.	64	["arrested", "return", "grad student", "grad", "colleague"]	175
321	Sherrod Brown's 1971 letter argued against releasing Vietnam War POWs, podcast hosts reveal	Sherrod Brown's 1971 letter argued against releasing Vietnam War POWs, raising questions about the Ohio Senate nominee's long-held political views.	The Ruthless Podcast hosts surfaced a striking letter to the editor from Ohio Democratic Senate nominee Sherrod Brown arguing against releasing the American Prisoners of War (POWs) during the VietnamΓÇª	https://www.foxnews.com/media/sherrod-browns-1971-letter-argued-against-releasing-vietnam-war-pows-podcast-hosts-reveal	Fox News		2026-10-14 13:00:29	2026-10-15 17:24:58.977342	Negative	-0.1250	["Ohio Senate", "Senate"]	["Ohio", "Vietnam"]	["Sherrod Brown's", "Sherrod Brown"]	-0.9719	Negative	Negative	0	0	General	0.0000	Sherrod Brown's 1971 letter argued against releasing Vietnam War POWs, podcast hosts reveal. Sherrod Brown's 1971 letter argued against releasing Vietnam War POWs, raising questions about the Ohio Senate nominee's long-held political views.	63	["war", "questions", "long"]	166
322	August Import Data Reveals Topsy-Turvy Apparel Trade Environment Driven by Tariff┬áTurmoil	Increased apparel shipments from China, surging imports from Canada and plummeting volumes from India were among the surprising trade trends took shape in August.	Increased apparel shipments from China, surging imports from Canada and plummeting volumes from India were among the surprising trade trends took shape in August, illuminating the topsy-turvy nature ΓÇª	http://wwd.com/sourcing-journal/trade/august-import-data-apparel-trade-tariff-turmoil-1239346195/	WWD	Kate Nishimura	2026-10-14 12:58:26	2026-10-15 17:24:58.977342	Positive	0.7000	["Import Data Reveals Topsy-Turvy Apparel Trade Environment Driven", "Tariff┬áTurmoil Increased"]	["China", "Canada", "India"]	[]	0.5994	Positive	Positive	0	0	General	0.0000	August Import Data Reveals Topsy-Turvy Apparel Trade Environment Driven by Tariff Turmoil.	65	["august", "trade", "shipments", "reveals", "imports"]	167
323	How Cotton Suppliers Really Feel About┬áTraceability	A new Oritain report finds that farmers, ginners, spinners and manufacturers are pursuing traceability for commercial advantage, even as inconsistent buyer demand and compliance costs complicate the path.	Traceability isnΓÇÖt something being thrust on unwilling cotton suppliers, a new report found. Rather than view compliance solely as a cost center or burden, the majority of farmers, ginners, spinners,ΓÇª	http://wwd.com/sourcing-journal/sustainability/oritain-cotton-traceability-supplier-intelligence-report-1239346242/	WWD	Jasmin Chua	2026-10-14 12:56:05	2026-10-15 17:24:58.977342	Neutral	0.0745	["Traceability"]	[]	["Oritain"]	-0.3400	Negative	Negative	0	0	General	0.0000	How Cotton Suppliers Really Feel About Traceability.	65	["oritain", "costs", "path", "finds", "advantage"]	168
324	UK calls for fundamental reset of global financial system for developing countries	Foreign Secretary Ed Miliband said the current system is failing developing economies and holding back shared global prosperity	Foreign Secretary uses World Bank and IMF Annual Meetings in Bangkok to call for urgent reform of the international financial system for developing countries UK proposes action on debΓÇª	https://www.gov.uk/government/news/uk-calls-for-fundamental-reset-of-global-financial-system-for-developing-countries	Www.gov.uk	Foreign, Commonwealth & Development Office	2026-10-14 12:49:45	2026-10-15 17:24:58.977342	Neutral	-0.0150	["World Bank and IMF Annual Meetings"]	["UK", "Bangkok"]	["Ed Miliband"]	-0.0258	Neutral	Neutral	0	0	General	0.0000	UK calls for fundamental reset of global financial system for developing countries. Foreign Secretary Ed Miliband said the current system is failing developing economies and holding back shared global prosperity	59	["global", "secretary", "foreign", "countries"]	169
325	BrokerΓÇÖs call: Pearl Global (Buy)	Pearl Global Industries is not a bare cut-and-sew job worker; it is a turnkey global apparel manufacturer with 25 plants in five countries ΓÇö India, Bangladesh, Vietnam, Indonesia and Guatemala ΓÇö offering design, sourcing and full-package manufacturing to globΓÇª	Target: 1,610\r\nCMP: 1,303.30\r\nPearl Global Industries (PGIL) is not a bare cut-and-sew job worker; it is a turnkey global apparel manufacturer with 25 plants in five countries India, Bangladesh, VietΓÇª	https://www.thehindubusinessline.com/markets/brokers-call-pearl-global-buy/article71583676.ece	BusinessLine	KS Badri Narayanan	2026-10-14 12:39:12	2026-10-15 17:24:58.977342	Neutral	-0.0071	["Target", "CMP", "Pearl Global Industries"]	["India", "Bangladesh", "Vietnam", "Indonesia", "Guatemala"]	["Pearl Global", "Viet"]	0.0000	Neutral	Neutral	0	0	General	0.0000	BrokerΓÇÖs call: Pearl Global (Buy).	75	["global", "indonesia", "countries", "manufacturing", "india"]	170
326	Live WWII-era grenades found in box bought at estate sale	Multiple live grenades dating back to World War II were discovered in a box purchased at an estate sale in Austin, Texas, police said.	An estate sale purchase in Austin, Texas, became a potential public safety hazard this week, when one patron's box of items was found to contain World War II-era explosives, police said.\r\nOfficers reΓÇª	https://www.cbsnews.com/news/world-war-ii-grenades-found-texas-estate-sale/	CBS News	Emily Mae  Czachor	2026-10-14 12:10:57	2026-10-15 17:24:58.977342	Neutral	0.0455	[]	["Austin", "Texas"]	[]	-0.7184	Negative	Negative	0	0	General	0.0000	Live WWII-era grenades found in box bought at estate sale. Multiple live grenades dating back to World War II were discovered in a box purchased at an estate sale in Austin, Texas, police said.	67	["grenades", "estate", "box", "live", "sale"]	171
327	Canal Disruptions Fuel Record Cargo Influx at California┬áPorts	Rising vessel fuel costs and uncertainty around the Panama and Suez Canals are prompting carriers to rethink traditional shipping allocations, helping drive record volumes at Los Angeles and Long Beach.	CaliforniaΓÇÖs neighboring ports of Los Angeles and Long Beach just closed the busiest month in the combined history of the San Pedro Bay gateway, handling 2.04 million 20-foot equivalent units (TEUs) ΓÇª	http://wwd.com/sourcing-journal/logistics/port-of-los-angeles-long-beach-cargo-panama-suez-canal-vietnam-1239346167/	WWD	Glenn Taylor	2026-10-14 12:00:00	2026-10-15 17:24:58.977342	Neutral	-0.0500	[]	["California", "Panama", "Los Angeles", "Long Beach"]	[]	-0.3818	Negative	Negative	0	0	General	0.0000	Canal Disruptions Fuel Record Cargo Influx at California Ports.	71	["fuel", "record", "costs", "beach", "california"]	172
328	Lest We Forget the Horrors: An Unending Catalog of TrumpΓÇÖs Cruelties, Collusions, Corruptions, and Crimes: September 2026: Atrocities 1281-1352	Early in President TrumpΓÇÖs first term, McSweeneyΓÇÖs editors began to catalog the head-spinning number of misdeeds coming from his administration. We called this list a collection of TrumpΓÇÖs cruelties, collusions, corruptions, and crimes, and it felt urgent to ΓÇª	Early in President TrumpΓÇÖs first term, McSweeneyΓÇÖs editors began to catalog the head-spinning number of misdeeds coming from his administration. We called this list a collection of TrumpΓÇÖs cruelties,ΓÇª	https://www.mcsweeneys.net/articles/september-2026-atrocities-1281-1352	Mcsweeneys.net	Emily Greenberg and Chris Monks	2026-10-14 11:35:00	2026-10-15 17:24:58.977342	Positive	0.1750	["TrumpΓÇÖs Cruelties, Collusions, Corruptions", "TrumpΓÇÖs"]	[]	["TrumpΓÇÖs", "McSweeney"]	-0.8689	Negative	Negative	0	0	General	0.0000	Lest We Forget the Horrors: An Unending Catalog of TrumpΓÇÖs Cruelties, Collusions, Corruptions, and Crimes: September 2026: Atrocities 1281-1352.	87	["trump", "head", "september", "president", "list"]	173
331	An Effective Movement for Palestine Needs Allies Like Zohran Mamdani	Hadas Thier\n\nIn order to build a broad-based coalition, we need to work togetherΓÇönot practice purity politics.\r\n\n\r\n\nThe post An Effective Movement for Palestine Needs Allies Like Zohran Mamdani appeared first on The Nation.	Politics / October 14, 2026\r\nIn order to build a broad-based coalition, we need to work togethernot practice purity politics.\r\nAd Policy\r\nNew York City Mayor Zohran Mamdani (C) joins anti-war demonstΓÇª	https://www.thenation.com/article/activism/movement-for-palestine-zohran-mamdani/	Thenation.com	Hadas Thier	2026-10-14 09:30:00	2026-10-15 17:24:58.977342	Positive	0.3966	["An Effective Movement", "The Nation", "Policy\\r\\nNew York City"]	[]	["Zohran Mamdani"]	0.8807	Positive	Positive	0	0	General	0.0000	An Effective Movement for Palestine Needs Allies Like Zohran Mamdani. Hadas Thier In order to build a broad-based coalition, we need to work togetherΓÇönot practice purity politics.	76	["like", "needs", "build", "work", "need"]	176
332	Behind big billions, the China hedge begins to take shape in India	Hyundai Motor Group plans to invest $15.5 billion in India over the period of 2026 to 2032. This initiative aims to strengthen local manufacturing and expand research and development facilities. Attracting global interest, especially with competitors like ToyΓÇª	Hyundai Motor Group's $15.5 billion investment pledge is about more than India's booming car market. It comes as multinational companies rethink their dependence on China and look for additional manuΓÇª	https://economictimes.indiatimes.com/news/company/corporate-trends/hyundai-15-billion-india-investment-china-plus-one-strategy-global-manufacturing-supply-chain-shift-foreign-direct-investment-greenfield-fdi/articleshow/134937580.cms	The Times of India	ET Online	2026-10-14 09:21:08	2026-10-15 17:24:58.977342	Neutral	0.0167	["Hyundai Motor Group", "ToyΓÇª", "Hyundai Motor Group's"]	["China", "India"]	[]	0.9093	Positive	Positive	0	0	General	0.0000	Behind big billions, the China hedge begins to take shape in India. Hyundai Motor Group plans to invest $15.5 billion in India over the period of 2026 to 2032.	80	["india", "like", "invest", "big", "expand"]	177
333	Switzerland, Norway, Vietnam to sign free trade deal on Sunday, officials say	The European Free Trade Association (EFTA) and Vietnam are set to sign a free trade deal on Sunday, officials said this week, after long-stalled talks were relaunched last year amid global tensions over US tariffs.\nVietnam and the EFTA bloc, which includes SwΓÇª	The European Free Trade Association (EFTA) and Vietnam are set to sign a free trade deal on Sunday, officials said this week, after long-stalled talks were relaunched last year amid global tensions oΓÇª	https://biztoc.com/x/223c5e10bf84019d	Biztoc.com	finance.yahoo.com	2026-10-14 09:15:39	2026-10-15 17:24:58.977342	Positive	0.1818	["The European Free Trade Association", "EFTA", "Sw"]	["Switzerland", "Norway", "Vietnam", "US"]	[]	0.9022	Positive	Positive	0	0	General	0.0000	Switzerland, Norway, Vietnam to sign free trade deal on Sunday, officials say.	88	["free trade", "free", "trade", "sunday", "officials"]	178
334	IndiaΓÇÖs oilmeal exports tumble 65% in July as soybean meal shipments slump	Uncompetitive soybean meal prices, cheaper South American supplies and rising freight costs led to a 65 per cent decline in overall oilmeal exports in July 2026.	Uncompetitive soybean meal prices, cheaper South American supplies and rising freight costs led to a 65 per cent decline in overall oilmeal exports in July 2026.\r\nAccording to the Solvent Extractors ΓÇª	https://www.thehindubusinessline.com/economy/agri-business/indias-oilmeal-exports-tumble-65-in-july-as-soybean-meal-shipments-slump/article71582700.ece	BusinessLine	BL Mangaluru Bureau	2026-10-14 09:01:32	2026-10-15 17:24:58.977342	Neutral	0.0000	[]	["India"]	[]	0.0000	Neutral	Neutral	0	0	General	0.0000	IndiaΓÇÖs oilmeal exports tumble 65% in July as soybean meal shipments slump. Uncompetitive soybean meal prices, cheaper South American supplies and rising freight costs led to a 65 per cent decline in overall oilmeal exports in July 2026.	44	["exports", "shipments", "costs", "rising", "led"]	179
335	Wyoming grad student accused of poisoning a colleague, arrested fleeing to China	She allegedly bought a chemical, acrylamide, over eBay, and it was first detected when the alleged victimΓÇÖs wife and others tested water from the coffee maker he used to brew tea.	A Wyoming microbiology graduate student from China has been arrested on accusations she poisoned the tea of a colleague who had pending patents and with whom she didnt get along, then tried to flee tΓÇª	https://nypost.com/2026/10/14/us-news/wyoming-grad-student-aili-wang-accused-of-poisoning-colleague-arrested-at-lax-fleeing-to-china/	New York Post	Associated Press	2026-10-14 07:38:11	2026-10-15 17:24:58.977342	Neutral	-0.0063	["eBay"]	["Wyoming", "China"]	[]	-0.9493	Negative	Negative	0	0	General	0.0000	Wyoming grad student accused of poisoning a colleague, arrested fleeing to China.	78	["arrested", "grad student", "grad", "colleague", "alleged"]	180
336	Customer Wars S09E03 1080p WEB h264-EDITH	Season 9, Episode 03 ΓÇô "Guard Down"In a restaurant in Georgia, a mother confronts a male customer who she claims complained about her child's volume. At a Florida bar, an allegedly intoxicated woman who is being escorted out by police answers a call from her ΓÇª	Season 9, Episode 03 "Guard Down"In a restaurant in Georgia, a mother confronts a male customer who she claims complained about her child's volume. At a Florida bar, an allegedly intoxicated woman whΓÇª	https://post.rlsbb.cc/customer-wars-s09e03-1080p-web-h264-edith/	Rlsbb.cc	Lisa	2026-10-14 07:23:41	2026-10-15 17:24:58.977342	Negative	-0.1389	[]	["Georgia", "Florida"]	[]	-0.8957	Negative	Negative	0	0	General	0.0000	Customer Wars S09E03 1080p WEB h264-EDITH. Season 9, Episode 03 ΓÇô "Guard Down"In a restaurant in Georgia, a mother confronts a male customer who she claims complained about her child's volume.	85	["woman", "season episode", "volume", "episode", "allegedly"]	181
337	Vietnam buries remains of 731 war dead nearly 6 decades after the Tet Offensive	The remains of 731 people believed killed during the 1968 Tet Offensive have been laid to rest in Ho Chi Minh City, nearly six decades after North Vietnamese communist forces launched coordinated surprise attacks across South Vietnam during the Lunar N...	HANOI, Vietnam -- Thousands carrying white flowers lined the roads in Vietnams Ho Chi Minh City Wednesday as the remains of 731 people believed to have been killed during the 1968 Tet Offensive were ΓÇª	https://abcnews.com/International/wireStory/vietnam-buries-remains-731-war-dead-6-decades-137248361	Abcnews.com	ANIRUDDHA GHOSAL Associated Press	2026-10-14 06:16:57	2026-10-15 17:24:58.977342	Neutral	-0.0667	[]	["Vietnam", "Ho Chi Minh City"]	["Tet Offensive"]	-0.9808	Negative	Negative	0	0	General	0.0000	Vietnam buries remains of 731 war dead nearly 6 decades after the Tet Offensive.	90	["decades", "remains", "nearly", "north", "people"]	162
346	utelearn 10.22.2026	A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	A required part of this site couldnt load. This may be due to a browser\r\n extension, network issues, or browser settings. Please check your\r\n connection, disable any ad blockers, or try using a diffeΓÇª	https://pypi.org/project/utelearn/10.22.2026/	Pypi.org	dung.cai@hcmute.edu.vn	2026-10-14 02:50:18	2026-10-15 17:24:58.977342	Neutral	0.0625	[]	["HCMUTE", "Vietnam"]	[]	0.3182	Positive	Positive	0	0	General	0.0000	utelearn 10.22.2026. A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	49	["machine", "library built", "purpose hcmute", "purpose", "learning library"]	98
338	VietJet Air Launches its Hanoi ΓÇô Almaty ΓÇô Prauge Service	Some good aviation news: VietJet Air is expanding its long-haul service, with it formally launching its Hanoi ΓÇô Almaty ΓÇô Prague service. Vietjet aircraft receives a ceremonial water salute upon arrival at Prague Airport ΓÇô Image, Vietjet The new air links offeΓÇª	Some good aviation news: VietJet Air is expanding its long-haul service, with it formally launching its Hanoi ΓÇô Almaty ΓÇô Prague service.\r\nVietjet aircraft receives a ceremonial water salute upon arriΓÇª	https://economyclassandbeyond.boardingarea.com/2026/10/14/vietjet-air-launches-its-hanoi-almaty-prauge-service/	Boardingarea.com	Economy Class & Beyond	2026-10-14 06:04:22	2026-10-15 17:24:58.977342	Positive	0.3273	["VietJet Air Launches", "VietJet Air"]	["Hanoi", "Prague"]	[]	0.7003	Positive	Positive	0	0	General	0.0000	VietJet Air Launches its Hanoi ΓÇô Almaty ΓÇô Prauge Service. Some good aviation news: VietJet Air is expanding its long-haul service, with it formally launching its Hanoi ΓÇô Almaty ΓÇô Prague service.	83	["vietjet", "service", "air", "hanoi", "image"]	182
339	Quiet revisions, loud victory claims: Pentagon raises Iran war death toll after Hegseth called the reports ├ó┬Ç┬£a complete lie├ó┬Ç┬¥	In the early days of the Iran conflict, the Pentagon spent days crowing about victory, but over time, the bravado turned up hollow, while the casualties occurred quietly.┬áU.S. bases took damage across the Middle East, as the victor continued to sing.┬áNow the ΓÇª	In the early days of the Iran conflict, the Pentagon spent days crowing about victory, but over time, the bravado turned up hollow, while the casualties occurred quietly.┬áU.S. bases took damage acrosΓÇª	https://www.naturalnews.com/2026-10-14-pentagon-raises-iran-war-death-toll-after-hegseth-called-the-reports-a-complete-lie.html	Naturalnews.com	Lance D Johnson	2026-10-14 06:00:00	2026-10-15 17:24:58.977342	Neutral	-0.0286	["Pentagon"]	["Iran", "U.S."]	["Hegseth"]	-0.9524	Negative	Negative	0	0	General	0.0000	Quiet revisions, loud victory claims: Pentagon raises Iran war death toll after Hegseth called the reports ├ó┬Ç┬£a complete lie├ó┬Ç┬¥.	97	["pentagon", "victory", "days", "iran", "hegseth"]	183
340	GreeceΓÇÖs next steps after GuilfoyleΓÇÖs removal: what will determine her successorΓÇÖs appointment	The $100,000 case that led to the US ambassadorΓÇÖs removal, the investigations under way and what comes next for her successor\nThe post GreeceΓÇÖs next steps after GuilfoyleΓÇÖs removal: what will determine her successorΓÇÖs appointment appeared first on ProtoThema ΓÇª	The removal of Kimberly Guilfoyle from the US Embassy in Athens and the reasons that led the US president to take this decision represent the first major crisis within Donald Trumps inner circle, comΓÇª	https://en.protothema.gr/2026/10/14/greeces-next-steps-after-guilfoyles-removal-what-will-determine-her-successors-appointment/	Protothema.gr	admin	2026-10-14 05:39:49	2026-10-15 17:24:58.977342	Neutral	0.0804	["GuilfoyleΓÇÖs", "ProtoThema", "Kimberly Guilfoyle", "the US Embassy"]	["Greece", "US", "Athens"]	["Donald Trumps"]	-0.5413	Negative	Negative	0	0	General	0.0000	GreeceΓÇÖs next steps after GuilfoyleΓÇÖs removal: what will determine her successorΓÇÖs appointment.	86	["case", "led", "appeared", "post"]	184
341	Texas man finds live World War II grenades in box he bought at estate sale, prompting bomb squad response	ΓÇ£Handling 80-year-old explosives with unknown stability is dangerous, precise work, and they do it with the professionalism this city counts on.ΓÇ¥	Thats an explosive find.\r\nA Texas man found live World War II-era grenades inside a box he bought at an estate sale, prompting police to send in the bomb squad.\r\nThe Austin Police Department said it ΓÇª	https://nypost.com/2026/10/14/us-news/live-world-war-ii-grenades-found-in-texas-estate-sale-box-safely-removed-by-austin-police-bomb-squad/	New York Post	Richard Pollina	2026-10-14 05:01:09	2026-10-15 17:24:58.977342	Neutral	-0.0055	["The Austin Police Department"]	["Texas"]	[]	-0.8779	Negative	Negative	0	0	General	0.0000	Texas man finds live World War II grenades in box he bought at estate sale, prompting bomb squad response.	77	["grenades", "estate", "box", "work", "finds"]	171
342	Vietnam says trade negotiations with United States almost completed	Vietnam and the United States are close to finalising a trade agreement, as stated by Deputy Prime Minister Pham Gia Tuc. The final text of the deal has been sent to the United States. Vietnamese officials hope for favorable market conditions for their goods ΓÇª	Alpha Trade\r\nGet daily trade ideas from SEBI-registered research analysts.\r\nInvestment Ideas\r\nGrow your wealth with stock ideas &amp; sectoral trends.\r\nStock Reports Plus\r\nAll-in-one stock research wΓÇª	https://economictimes.indiatimes.com/news/international/business/vietnam-says-trade-negotiations-with-united-states-almost-completed/articleshow/134932127.cms	The Times of India	Reuters	2026-10-14 04:38:18	2026-10-15 17:24:58.977342	Neutral	0.0000	["Alpha Trade\\r\\nGet"]	["Vietnam", "United States", "the United States"]	["Pham Gia Tuc"]	0.9628	Positive	Positive	0	0	General	0.0000	Vietnam says trade negotiations with United States almost completed. Vietnam and the United States are close to finalising a trade agreement, as stated by Deputy Prime Minister Pham Gia Tuc.	82	["united states", "states", "united", "trade", "hope"]	185
343	Will Donald TrumpΓÇÖs Iran War break America?	Trump's Presidency is a sign of the once greatest imperial power going down, down, down	( Tom Engelhardt Substack ) ΓÇô Only recently, after a mere two decades of intermittent conflict (with three years off), the last U.S. troops finally withdrew fromΓÇª yes, can you believe it?ΓÇª Iraq! DonΓÇÖΓÇª	https://www.juancole.com/2026/10/donald-trumps-america.html	Juancole.com	Informed Comment	2026-10-14 04:06:36	2026-10-15 17:24:58.977342	Neutral	0.0037	[]	["America", "U.S.", "Iraq"]	["Will Donald TrumpΓÇÖs", "Trump", "Tom Engelhardt Substack", "Don"]	0.3296	Positive	Positive	0	0	General	0.0000	Will Donald TrumpΓÇÖs Iran War break America?. Trump's Presidency is a sign of the once greatest imperial power going down, down, down	56	["trump", "sign", "power", "greatest", "iran war"]	186
344	Vietnam says trade talks with US nearly completed; US officials more cautious	HANOI: Vietnam and the US have nearly completed negotiations covering a trade deal, Vietnamese Deputy Prime Minister Pham Gia Tuc said on Wednesday (Oct 14) at an event in Hanoi, though US officials appeared more cautious.Vietnam has sent the final text of thΓÇª	HANOI: Vietnam and the US have nearly completed negotiations covering a trade deal, Vietnamese Deputy Prime Minister Pham Gia Tuc said on Wednesday (Oct 14) at an event in Hanoi, though US officials ΓÇª	https://www.channelnewsasia.com/asia/vietnam-says-trade-talks-us-nearly-completed-us-officials-more-cautious-6457586	CNA		2026-10-14 03:44:30	2026-10-15 17:24:58.977342	Positive	0.2167	[]	["Vietnam", "US", "Hanoi"]	["Pham Gia Tuc"]	-0.1761	Negative	Negative	0	0	General	0.0000	Vietnam says trade talks with US nearly completed; US officials more cautious.	89	["officials", "nearly", "trade", "hanoi", "prime"]	187
345	utelearn 10.23.2026	A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	A required part of this site couldnt load. This may be due to a browser\r\n extension, network issues, or browser settings. Please check your\r\n connection, disable any ad blockers, or try using a diffeΓÇª	https://pypi.org/project/utelearn/10.23.2026/	Pypi.org	dung.cai@hcmute.edu.vn	2026-10-14 03:06:09	2026-10-15 17:24:58.977342	Neutral	0.0625	[]	["HCMUTE", "Vietnam"]	[]	0.3182	Positive	Positive	0	0	General	0.0000	utelearn 10.23.2026. A custom machine learning library built for educational purpose from HCMUTE - Vietnam.	49	["machine", "library built", "purpose hcmute", "purpose", "learning library"]	98
347	The Real Housewives Of New York City S16E06 1080p HDTV x264-vietnam	Season 16, Episode 06 ΓÇô ΓÇ£Moskito MadnessΓÇ¥Cameras capture the lives of some busy, influential, rich and ambitious Manhattan women and their families.Links: HOMEPAGE┬áΓÇô┬áTVMThe.Real.Housewives.Of.New.York.City.S16E06.720p.HDTV.H264-JFFMKV | AC3 / dolby digital | ΓÇª	Season 16, Episode 06 ΓÇ£Moskito MadnessΓÇ¥Cameras capture the lives of some busy, influential, rich and ambitious Manhattan women and their families.\r\nLinks:HOMEPAGE┬á┬áTVM\r\nThe.Real.Housewives.Of.New.YorΓÇª	https://post.rlsbb.cc/the-real-housewives-of-new-york-city-s16e06-1080p-hdtv-x264-vietnam/	Rlsbb.cc	Lisa	2026-10-14 02:38:46	2026-10-15 17:24:58.977342	Positive	0.1985	["The Real Housewives Of", "Housewives"]	["New York City S16E06", "Manhattan"]	["Moskito", "Yor"]	0.9595	Positive	Positive	0	0	General	0.0000	The Real Housewives Of New York City S16E06 1080p HDTV x264-vietnam.	67	["hdtv", "york", "real", "city", "season episode"]	188
348	Compal Accelerates Time-to-AI with Next-Generation NVIDIA Platforms at OCP Global Summit 2026	From Blackwell Ultra systems for today's AI deployments to next-generation Rubin, Vera CPU and Spectrum-X, Compal combines engineering, rack integration and global manufacturing to turn accelerated computing into deployable AI capacityΓÇöfaster. SAN JOSE, CalifΓÇª	From Blackwell Ultra systems for today's AI deployments to next-generation Rubin, Vera CPU and Spectrum-X, Compal combines engineering, rack integration and global manufacturing to turn accelerated cΓÇª	https://www.prnewswire.com/news-releases/compal-accelerates-time-to-ai-with-next-generation-nvidia-platforms-at-ocp-global-summit-2026-302907696.html	PRNewswire		2026-10-14 02:00:00	2026-10-15 17:24:58.977342	Neutral	0.0000	["Next-Generation NVIDIA Platforms", "OCP Global Summit 2026", "Blackwell Ultra"]	["AI", "Rubin", "Compal", "SAN JOSE", "Calif"]	["Compal Accelerates Time-to-", "Spectrum-X"]	0.0000	Neutral	Neutral	0	0	General	0.0000	Compal Accelerates Time-to-AI with Next-Generation NVIDIA Platforms at OCP Global Summit 2026.	73	["global", "summit", "manufacturing", "san"]	189
349	By making protests conditional on state approval, governments are eroding our democracy	A new report maps how protest permit systems work in every state and territory. The result is a tangle of laws, council by-laws and complicated rules.	In July, a group in Bathurst, New South Wales wanted to hold a small rally in a local park against culling wild horses, known as brumbies.\n\nWhen an organiser notified the council, they were told theyΓÇª	https://theconversation.com/by-making-protests-conditional-on-state-approval-governments-are-eroding-our-democracy-292894	The Conversation Africa	Maria O'Sullivan, Associate Professor of Law, Member of Deakin Cyber and the Centre for Law as Protection, Deakin University, Deakin University	2026-10-14 01:49:01	2026-10-15 17:24:58.977342	Neutral	-0.0629	[]	["Bathurst"]	[]	0.0516	Positive	Neutral	0	0	General	0.0000	By making protests conditional on state approval, governments are eroding our democracy. A new report maps how protest permit systems work in every state and territory. The result is a tangle of laws, council by-laws and complicated rules.	74	["state", "rules", "work", "report"]	190
350	Grad student accused of trying to flee U.S. after police questioned her about alleged poisoning	A Wyoming microbiology graduate student from China has been arrested on accusations she poisoned the tea of a colleague who had pending patents, then tried to flee the U.S. after police questioned her.	A Wyoming microbiology graduate student from China has been arrested on accusations she poisoned the tea of a colleague who had pending patents, then tried to flee the U.S. after police questioned heΓÇª	https://www.cbc.ca/news/world/university-wyoming-microbiology-grad-student-arrested-9.7379753	CBC News		2026-10-14 01:29:57	2026-10-15 17:24:58.977342	Neutral	-0.1000	[]	["U.S.", "Wyoming", "China"]	[]	-0.9732	Negative	Negative	0	0	General	0.0000	Grad student accused of trying to flee U.S. after police questioned her about alleged poisoning.	81	["student", "police", "arrested", "grad student", "grad"]	191
352	Huy Phan Vol.2	Portfolio of Huy Phan (aka Huyml), an independent designer and art director, based in Ho Chi Minh city, Vietnam.	This website uses a colorpalette of 2 colors	https://www.awwwards.com/sites/huy-phan-vol-2	Awwwards.com		2026-10-14 00:00:00	2026-10-15 17:24:58.977342	Neutral	0.0000	["Huyml"]	["Ho Chi Minh", "Vietnam"]	[]	0.0000	Neutral	Neutral	0	0	General	0.0000	Huy Phan Vol.2. Portfolio of Huy Phan (aka Huyml), an independent designer and art director, based in Ho Chi Minh city, Vietnam.	30	["minh city", "based", "minh", "chi minh", "chi"]	193
353	Interhemispheric monsoon dynamics over the past 450,000 years	A 450ΓÇëka Andean speleothem record shows Southern and Northern Hemisphere monsoons generally vary out of phase, but occasionally synchronize during rapid climate change and glacial terminations.	Geen, R., Bordoni, S., Battisti, D. S. &amp; Hui, K. Monsoons, ITCZs, and the Concept of the Global Monsoon. Rev. Geophys.58, e2020RG000700 (2020).\r\nArticle┬á\r\n ADS┬á\r\nGoogle Scholar┬á\r\n McGΓÇª	https://www.nature.com/articles/s41586-026-11166-3	Nature.com	E. J. Olson, D. P. Gillikin, D. Parmenter, S. Burns, A. Verheyden, O. Miyawaki, M. Vuille, L. F. Piccirillo, R. Castro, G. Yurivilca, R. L. Edwards, D. T. Rodbell	2026-10-14 00:00:00	2026-10-15 17:24:58.977342	Neutral	-0.0400	["D. S. &", "McG"]	["Bordoni"]	["Geen"]	0.1406	Positive	Neutral	0	0	General	0.0000	Interhemispheric monsoon dynamics over the past 450,000 years.	63	["climate", "record", "change", "past"]	194
\.


--
-- Data for Name: news_volume_forecast; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.news_volume_forecast (id, forecast_date, predicted_count, lower_bound, upper_bound, model_type, created_at) FROM stdin;
1	2026-10-14	13.70	7.50	19.90	LinearRegression	2026-10-14 02:38:37.106113
2	2026-10-15	32.90	15.40	50.40	LinearRegression	2026-10-14 17:14:30.38228
3	2026-10-16	38.00	19.00	57.00	LinearRegression	2026-10-15 17:25:00.123354
4	2026-10-17	37.30	18.30	56.30	LinearRegression	2026-10-15 17:25:00.123354
5	2026-10-18	36.70	17.70	55.70	LinearRegression	2026-10-15 17:25:00.123354
6	2026-10-19	36.10	17.10	55.10	LinearRegression	2026-10-15 17:25:00.123354
7	2026-10-20	35.50	16.50	54.50	LinearRegression	2026-10-15 17:25:00.123354
21	2026-10-21	34.90	15.90	53.90	LinearRegression	2026-10-15 17:25:00.123354
28	2026-10-22	34.30	15.30	53.30	LinearRegression	2026-10-15 17:25:00.123354
\.


--
-- Name: news_keyword_trends_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.news_keyword_trends_id_seq', 1339, true);


--
-- Name: news_vietnam_articles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.news_vietnam_articles_id_seq', 353, true);


--
-- Name: news_volume_forecast_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.news_volume_forecast_id_seq', 28, true);


--
-- Name: news_keyword_trends news_keyword_trends_date_str_keyword_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_keyword_trends
    ADD CONSTRAINT news_keyword_trends_date_str_keyword_key UNIQUE (date_str, keyword);


--
-- Name: news_keyword_trends news_keyword_trends_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_keyword_trends
    ADD CONSTRAINT news_keyword_trends_pkey PRIMARY KEY (id);


--
-- Name: news_vietnam_articles news_vietnam_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_vietnam_articles
    ADD CONSTRAINT news_vietnam_articles_pkey PRIMARY KEY (id);


--
-- Name: news_vietnam_articles news_vietnam_articles_url_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_vietnam_articles
    ADD CONSTRAINT news_vietnam_articles_url_key UNIQUE (url);


--
-- Name: news_volume_forecast news_volume_forecast_forecast_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_volume_forecast
    ADD CONSTRAINT news_volume_forecast_forecast_date_key UNIQUE (forecast_date);


--
-- Name: news_volume_forecast news_volume_forecast_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_volume_forecast
    ADD CONSTRAINT news_volume_forecast_pkey PRIMARY KEY (id);


--
-- Name: idx_news_cluster; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_cluster ON public.news_vietnam_articles USING btree (story_cluster_id);


--
-- Name: idx_news_collected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_collected_at ON public.news_vietnam_articles USING btree (collected_at);


--
-- Name: idx_news_ensemble; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_ensemble ON public.news_vietnam_articles USING btree (ensemble_sentiment_label);


--
-- Name: idx_news_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_published_at ON public.news_vietnam_articles USING btree (published_at);


--
-- Name: idx_news_sentiment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_sentiment ON public.news_vietnam_articles USING btree (sentiment_label);


--
-- Name: idx_news_source_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_source_name ON public.news_vietnam_articles USING btree (source_name);


--
-- Name: idx_news_topic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_topic ON public.news_vietnam_articles USING btree (topic_label);


--
-- Name: idx_news_vn_relevant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_vn_relevant ON public.news_vietnam_articles USING btree (is_vietnam_relevant);


--
-- PostgreSQL database dump complete
--

\unrestrict 6iZpIhu5rNUjSmEJp3h2SPqG8RI6rK9oKjzjILHxjo9sZfR9nTJKbW6eDrZVAVc


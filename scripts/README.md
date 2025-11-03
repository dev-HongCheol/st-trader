# Scripts 디렉토리 구조

> 주식 트레이딩 시스템 데이터 수집 및 분석 스크립트

## 📂 폴더 구조

```
scripts/
├── run-pipeline.sh              # 전체 파이프라인 실행 스크립트
├── 1-data-collection/           # 주가/재무 데이터 수집 (Python)
│   └── collect_stock_prices.py
└── 2-news-pipeline/             # 뉴스 수집 및 AI 분석 (TypeScript)
    ├── 1-fetch_news_metadata.ts
    ├── 2-filter_news_by_title.ts
    ├── 3-crawl_filtered_news.ts
    ├── 4-analyze_news_sentiment.ts
    └── 5-import_analyzed_news.ts
```

## 🚀 전체 파이프라인 실행

```bash
./scripts/run-pipeline.sh
```

**예상 시간**: 12-15분
**예상 비용**: $2.0 (네이버 API 무료 + Claude AI)
**패키지 매니저**: pnpm (TypeScript), pip (Python venv)

---

## 📊 1. 데이터 수집 (Python)

### collect_stock_prices.py

**목적**: FinanceDataReader로 주가 및 재무 데이터 수집

**실행**:
```bash
# 1. 가상환경 활성화 (최초 1회 생성 필요)
source venv/bin/activate

# 2. 패키지 설치 (최초 1회)
pip install -r scripts/1-data-collection/requirements.txt

# 3. 스크립트 실행
python scripts/1-data-collection/collect_stock_prices.py
```

**입력**: 없음 (코드 내 종목 정의)
**출력**:
- `st_daily_prices` 테이블 (일별 OHLCV)
- `st_financial_snapshots` 테이블 (분기별 재무제표)

**대상 종목**: 삼성전자, SK하이닉스, NAVER, 카카오, 현대차

**필수 환경변수**:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

**Python 가상환경 (venv)**:
```bash
# 가상환경 생성 (프로젝트 루트에서 최초 1회)
python -m venv venv

# 활성화
source venv/bin/activate  # macOS/Linux
venv\Scripts\activate     # Windows

# 비활성화
deactivate
```

---

## 📰 2. 뉴스 파이프라인 (TypeScript)

### 2-1. fetch_news_metadata.ts

**목적**: 네이버 뉴스 검색 API로 제목/URL 메타데이터 수집

**실행**:
```bash
pnpm exec tsx scripts/2-news-pipeline/1-fetch_news_metadata.ts
```

**출력**: `data/news_metadata.json` (250개)
**소요 시간**: 1-2분
**비용**: 무료 (네이버 API)

**필수 환경변수**:
- `NAVER_CLIENT_ID`
- `NAVER_CLIENT_SECRET`

---

### 2-2. filter_news_by_title.ts

**목적**: Claude Haiku로 제목 기반 1차 필터링

**실행**:
```bash
pnpm exec tsx scripts/2-news-pipeline/2-filter_news_by_title.ts
```

**입력**: `data/news_metadata.json` (250개)
**출력**: `data/filtered_metadata.json` (80-100개)
**AI 모델**: `claude-3-5-haiku-20241022`
**소요 시간**: 2-3분
**비용**: ~$0.3

**필수 환경변수**:
- `ANTHROPIC_API_KEY`

---

### 2-3. crawl_filtered_news.ts

**목적**: Playwright로 필터링된 뉴스의 본문만 크롤링

**실행**:
```bash
pnpm exec tsx scripts/2-news-pipeline/3-crawl_filtered_news.ts
```

**입력**: `data/filtered_metadata.json` (80-100개)
**출력**: `data/crawled_news.json` (본문 포함)
**소요 시간**: 3-5분
**비용**: 무료

**필수 패키지**:
```bash
pnpm add -D playwright
pnpm exec playwright install chromium
```

---

### 2-4. analyze_news_sentiment.ts

**목적**: Claude Sonnet 4.5로 뉴스 심층 분석 (카테고리, 감성, 영향도)

**실행**:
```bash
pnpm exec tsx scripts/2-news-pipeline/4-analyze_news_sentiment.ts
```

**입력**: `data/crawled_news.json` (80-100개)
**출력**: `data/analyzed_news.json` (75개, 고신뢰도)
**AI 모델**: `claude-sonnet-4-20250514` (Prompt Caching 적용)
**소요 시간**: 5-8분
**비용**: ~$1.7

**분석 항목**:
- `category`: earnings|product|regulation|macro|geopolitics
- `sentiment`: positive|negative|neutral
- `impact`: high|medium|low
- `confidence`: 0.0-1.0

**필수 환경변수**:
- `ANTHROPIC_API_KEY`

---

### 2-5. import_analyzed_news.ts

**목적**: 분석된 뉴스를 Supabase DB에 저장

**실행**:
```bash
pnpm exec tsx scripts/2-news-pipeline/5-import_analyzed_news.ts
```

**입력**: `data/analyzed_news.json` (75개)
**출력**: `st_news_events` 테이블 (75개 레코드 UPSERT)
**소요 시간**: 1-2분
**비용**: 무료

**저장 컬럼**:
- `company_id`, `event_date`, `title`, `summary`
- `category`, `manual_sentiment`, `manual_impact`
- `ai_reasoning`, `ai_confidence`, `ai_model`

**필수 환경변수**:
- `NEXT_PUBLIC_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

**검증 쿼리**:
```bash
psql -h supa.devhong.cc -U postgres -d postgres -c "
  SELECT c.name, COUNT(*) as news_count, AVG(n.ai_confidence)::DECIMAL(3,2) as avg_confidence
  FROM st_news_events n
  JOIN st_companies c ON n.company_id = c.id
  WHERE n.ai_model = 'claude-sonnet-4-20250514'
  GROUP BY c.name ORDER BY c.name;
"
```

---

## 🔧 필수 환경변수 (`.env`)

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://supa.devhong.cc
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# 네이버 API
NAVER_CLIENT_ID=your-client-id
NAVER_CLIENT_SECRET=your-client-secret

# Anthropic API
ANTHROPIC_API_KEY=sk-ant-api03-...

# 크롤링 설정 (선택사항)
CRAWL_DELAY_MS=1000
CRAWL_MAX_RETRIES=3
```

---

## 📦 필수 패키지

### Python (venv 가상환경)
```bash
# 1. 가상환경 생성 (프로젝트 루트에서)
python -m venv venv

# 2. 가상환경 활성화
source venv/bin/activate  # macOS/Linux
venv\Scripts\activate     # Windows

# 3. 패키지 설치
pip install -r scripts/1-data-collection/requirements.txt
```

### Node.js (pnpm)
```bash
pnpm add -D playwright @anthropic-ai/sdk @supabase/supabase-js dotenv tsx typescript
pnpm exec playwright install chromium
```

---

## 📋 데이터 플로우

```
1. Python: collect_stock_prices.py
   → st_daily_prices, st_financial_snapshots

2. TypeScript: 1-fetch_news_metadata.ts
   → data/news_metadata.json (250개)

3. TypeScript: 2-filter_news_by_title.ts (Haiku)
   → data/filtered_metadata.json (80-100개)

4. TypeScript: 3-crawl_filtered_news.ts (Playwright)
   → data/crawled_news.json (본문 포함)

5. TypeScript: 4-analyze_news_sentiment.ts (Sonnet 4.5)
   → data/analyzed_news.json (75개)

6. TypeScript: 5-import_analyzed_news.ts
   → st_news_events (DB 저장)
```

---

## 🔍 로그 및 디버깅

### 로그 파일

전체 파이프라인 실행 시 로그 자동 저장:
```
logs/pipeline_YYYYMMDD_HHMMSS.log
```

### 중간 데이터 파일

각 단계별 출력 파일 확인 가능:
```
data/
├── news_metadata.json        # 네이버 API 결과
├── filtered_metadata.json    # Haiku 필터링
├── crawled_news.json         # Playwright 크롤링
└── analyzed_news.json        # Sonnet 4.5 분석
```

### 디버깅 팁

- 특정 단계만 재실행 가능 (각 스크립트 독립 실행)
- 에러 발생 시 중간 파일 확인
- API 호출 실패 시 재시도 횟수 조정 (`CRAWL_MAX_RETRIES`)

---

## 🗓️ 실행 주기 권장사항

### Phase 1: MVP (수동 실행)
- **주기**: 주 1회 (월요일 오전)
- **방법**: 터미널에서 직접 실행
- **비용**: $2/회 → **$8/월**

### Phase 2: 자동화 (Cron)
- **주기**: 일 1회 (새벽 2시)
- **방법**: crontab 설정
- **비용**: $2/일 → **$60/월**

### Phase 3: 실시간 (프로덕션)
- **주기**: 실시간 모니터링
- **방법**: Vercel Cron + Edge Functions
- **추가 기능**: 텔레그램 알림, 자동 매매 신호

---

## 📞 문제 해결

### 1. 네이버 API 호출 실패
```bash
❌ API 호출 실패: 401 Unauthorized
```
→ `.env`에서 `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET` 확인

### 2. Playwright 브라우저 미설치
```bash
❌ browserType.launch: Executable doesn't exist
```
→ `pnpm exec playwright install chromium` 실행

### 3. Supabase 연결 실패
```bash
❌ company_id 조회 실패
```
→ `.env`에서 Supabase URL/Key 확인
→ `st_companies` 테이블 존재 여부 확인

### 4. Claude API 할당량 초과
```bash
❌ rate_limit_error
```
→ API 키 할당량 확인
→ `BATCH_SIZE` 줄여서 재실행

---

**작성일**: 2025-10-26
**버전**: 2.0 (네이버 API + 하이브리드 AI 분석)

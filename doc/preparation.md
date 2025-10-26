# 주식 트레이딩 시스템 - 1차 MVP 설계서

## 프로젝트 개요

### 목표
> **"지난 3개월간 매일의 뉴스/이슈/재무정보를 분석했다면 실제 주가 변동을 얼마나 예측할 수 있었는가?"**

과거 데이터 백테스팅을 통해 분석 알고리즘의 정확도를 검증합니다.

### 사용자
- **현재**: 개인 투자용
- **향후**: 정확도 검증 후 최대 10명까지 공유 예정

### 핵심 전략
- **1차 MVP**: UI 없이 데이터 정확도 검증
- **비용**: 무료 API만 사용
- **기간**: 3주 개발 목표

---

## 기술 스택 및 아키텍처

### 아키텍처 선택: 모놀리식 (Monolithic)

**MSA 대신 모놀리식을 선택한 이유:**
1. **개발자 1명**: 서비스 분리 시 관리 포인트 증가
2. **사용자 10명 이하**: 트래픽 부하 없음
3. **빠른 검증 필요**: MSA 구성 시간 낭비
4. **확장 가능**: 나중에 필요한 모듈만 MSA로 분리 가능

**MSA 전환 시점:**
- 사용자 100명 이상
- 종목 50개 이상
- 개발팀 2명 이상
- 특정 기능 트래픽 집중

### 기술 스택

| 계층 | 기술 | 비고 |
|------|------|------|
| **프론트엔드** | Next.js 14+ (App Router) | TypeScript, React |
| **데이터베이스** | PostgreSQL (Supabase 셀프호스팅) | 오렌지파이5 도커 |
| **백엔드 로직** | Node.js (TypeScript) | 모듈식 구조 |
| **데이터 수집** | Python + Node.js | Python은 주가 수집만 |
| **UI 라이브러리** | TailwindCSS, shadcn/ui | - |
| **차트** | Recharts | - |
| **상태관리** | TanStack Query (React Query) | 서버 상태 |

### 인프라 구성

```
오렌지파이5 (Ubuntu/Armbian)
├── Docker
│   ├── Supabase (셀프호스팅)
│   │   └── PostgreSQL
│   ├── Next.js App (모든 비즈니스 로직 포함)
│   └── Nginx (Reverse Proxy + SSL)
└── Cloudflare DNS
```

**도메인**: `trade.yourdomain.com` (Cloudflare 적용 완료)

---

## 데이터 수집 전략

### 타임라인 역산 접근

```
현재일: 2025-10-23
분석 대상: 2025-07-23 ~ 2025-10-22 (3개월, 90일)

각 날짜(D)에 대해:
  ✓ D일 시점에 수집 가능했던 뉴스 (D-7일 ~ D일)
  ✓ D일 시점에 공개된 재무제표 (분기 실적)
  ✓ D일 주가 (종가)
  ✓ D+1일, D+3일, D+7일 주가 (예측 검증용)
```

### 데이터 소스별 전략

#### A. 주가 데이터 (최우선)

**방법**: Python `FinanceDataReader` 라이브러리

**선택 이유:**
- 한국 주식 과거 데이터 가장 쉽게 수집
- 코드 3-4줄로 90일치 OHLCV 데이터 수집 가능
- 무료

**대안 (Node.js):**
- `yahoo-finance2`: 티커 형식 복잡 (`005930.KS`)
- 네이버 금융 크롤링: 코드 복잡, 유지보수 어려움

**결정**: Python 스크립트 1개만 작성 (1회 실행용)

#### B. 재무제표 (DART API)

**제약사항:**
- 분기별 실적만 제공 (1Q, 2Q, 3Q, 4Q)
- 3개월 기간 = 2개 분기만 포함
  - 2025년 7월: 2Q 실적 (6월 말 데이터)
  - 2025년 10월: 3Q 실적 (9월 말 데이터)

**전략:**
- 실적 발표 전: 이전 분기 데이터 사용
- 발표 후: 최신 분기 데이터 사용

**수집 도구**: Node.js (TypeScript)

#### C. 뉴스 데이터 (하이브리드 AI 분석) ⭐ 업데이트됨

**문제점:**
- 네이버 뉴스 API: 과거 1개월만 조회 가능
- 과거 3개월 데이터는 API로 불가능
- 수동 큐레이션: 전문성 부족으로 낮은 신뢰도

**해결책 (하이브리드 전략):**
1. **네이버 뉴스 검색 크롤링**: 과거 3개월 기사 수집 (종목당 50개)
2. **Claude Haiku 1차 필터링**: 관련성 판단 (250개 → 100개)
3. **Claude Sonnet 4.5 심층 분석**: 감성/영향도 자동 분석 (100개 → 75개)
4. **Supabase 저장**: AI 분석 결과 + 근거(reasoning) 저장

**비용**: $1.70-2.20 (Prompt Caching 적용)
**시간**: 20-30분 (완전 자동화)
**정확도**: 기존 수동 대비 2-3배 향상 예상

**상세 문서**: [`doc/news-collection-strategy.md`](./news-collection-strategy.md)

**수집 항목:**
- 날짜, 종목, 제목, 요약, URL
- 카테고리: `earnings`, `product`, `regulation`, `macro`, `geopolitics`
- AI 라벨링: 감성(`positive`, `negative`, `neutral`), 영향도(`high`, `medium`, `low`)
- AI 메타데이터: `ai_reasoning`, `ai_confidence`, `ai_model`

### 대상 종목 (5개)

| 종목코드 | 종목명 | 시장 |
|---------|--------|------|
| 005930 | 삼성전자 | KOSPI |
| 000660 | SK하이닉스 | KOSPI |
| 035420 | NAVER | KOSPI |
| 035720 | 카카오 | KOSPI |
| 005380 | 현대차 | KOSPI |

---

## 데이터베이스 설계

상세 스키마: [`doc/schema.sql`](./schema.sql)

### 테이블 구조 요약

| 테이블 | 용도 | 예상 레코드 수 |
|--------|------|---------------|
| `companies` | 종목 정보 | 5개 |
| `daily_prices` | 일별 주가 (OHLCV) | 450개 (5종목 × 90일) |
| `financial_snapshots` | 분기별 재무제표 | 10개 (5종목 × 2분기) |
| `news_events` | 뉴스/이슈 (수동 입력) | 75개 (종목당 15개) |
| `backtest_predictions` | 백테스트 예측 결과 | 450개 (5종목 × 90일) |

### 핵심 필드

**재무 스냅샷:**
- 수익성: `operating_margin`, `net_margin`, `roe`
- 성장성: 전분기 대비 매출 증가율 (계산 필요)

**뉴스 이벤트:**
- 분류: `category`, `manual_sentiment`, `manual_impact`
- 시간: `event_date`

**백테스트 결과:**
- 입력: `financial_score`, `news_score`, `combined_score`
- 예측: `predicted_signal`, `predicted_direction`, `confidence`
- 검증: `actual_return_1d`, `actual_return_3d`, `actual_return_7d`
- 정확도: `direction_correct_1d`, `direction_correct_3d`, `direction_correct_7d`

---

## 분석 로직 설계

### 1. 재무 점수 계산 (0-100점)

**평가 항목:**

| 항목 | 배점 | 기준 |
|------|------|------|
| **수익성** | 30점 | |
| - 영업이익률 | 15점 | >15%: 15점, >10%: 10점, >5%: 5점 |
| - ROE | 15점 | >15%: 15점, >10%: 10점, >5%: 5점 |
| **성장성** | 20점 | |
| - 매출 성장률 | 20점 | >20%: 20점, >10%: 15점, >0%: 10점, <-10%: -20점 |

**기본 점수**: 50점 (중립)
**최종 범위**: 0-100점

### 2. 뉴스 점수 계산 (0-100점)

**평가 방법:**
- 최근 7일 뉴스만 분석
- 감성 점수: `positive` +10점, `negative` -10점
- 영향도 가중치: `high` ×2, `medium` ×1, `low` ×0.5
- 시간 감쇠: 최근일수록 높은 가중치 (7일 전 = 50% 가중치)

**기본 점수**: 50점 (뉴스 없을 때)
**최종 범위**: 0-100점

### 3. 신호 생성

**종합 점수 계산:**
```
종합점수 = 재무점수 × 0.6 + 뉴스점수 × 0.4
```

**신호 판단:**
- `종합점수 >= 70` → **매수 (BUY)**
- `종합점수 <= 40` → **매도 (SELL)**
- `40 < 종합점수 < 70` → **홀드 (HOLD)**

**가중치 튜닝 여지:**
- 백테스트 결과에 따라 재무:뉴스 비율 조정 가능 (70:30, 80:20 등)

### 4. 백테스트 프로세스

**단계:**
1. 각 날짜별로 해당 시점의 데이터 수집
2. 재무 점수 + 뉴스 점수 계산
3. 신호 생성 (매수/매도/홀드)
4. 미래 수익률 계산 (1일/3일/7일 후)
5. 방향 예측 정확도 판단
6. 결과 DB 저장

**주요 검증 지표:**
- 3일 방향 정확도 (주요 지표)
- 고신뢰도 신호 정확도 (75점 이상)
- 매수 신호 평균 수익률

---

## 프로젝트 디렉토리 구조

```
trade/  (단일 레포)
├── doc/
│   ├── preparation.md         # 본 문서
│   └── schema.sql             # DB 스키마
│
├── supabase/
│   ├── config.toml
│   └── migrations/
│       └── 001_initial.sql
│
├── scripts/                   # 1회성 스크립트
│   ├── collect_stock_prices.py      # Python (주가 수집)
│   ├── collect_financials.ts        # Node.js (재무 수집)
│   ├── import_news_csv.ts           # 뉴스 CSV 임포트
│   ├── run_backtest.ts              # 백테스트 실행
│   └── analyze_results.ts           # 결과 분석 리포트
│
├── src/
│   ├── app/                   # Next.js App Router
│   │   ├── (dashboard)/
│   │   │   ├── page.tsx              # 대시보드 (Phase 2)
│   │   │   ├── stocks/               # 종목 상세 (Phase 2)
│   │   │   └── signals/              # 매매 신호 (Phase 2)
│   │   └── layout.tsx
│   │
│   ├── modules/               # 비즈니스 로직 모듈
│   │   ├── scoring/
│   │   │   ├── financial-scorer.ts   # 재무 점수 계산
│   │   │   └── news-scorer.ts        # 뉴스 점수 계산
│   │   ├── signal-generator/
│   │   │   └── generator.ts          # 신호 생성 로직
│   │   └── backtest/
│   │       └── backtester.ts         # 백테스트 엔진
│   │
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts             # 브라우저용 클라이언트
│   │   │   └── server.ts             # 서버용 클라이언트
│   │   └── types/
│   │       └── index.ts              # 공통 타입 정의
│   │
│   └── components/            # UI 컴포넌트 (Phase 2)
│       └── ui/                # shadcn/ui
│
├── docker-compose.yml         # Supabase 셀프호스팅
├── .env.local
├── package.json
├── tsconfig.json
└── README.md
```

---

## 개발 일정 (3주)

### 1주차: 인프라 및 데이터 수집

- [ ] Supabase 셀프호스팅 설정 (오렌지파이5 도커)
- [ ] DB 스키마 생성 (`schema.sql` 실행)
- [ ] 주가 데이터 수집 (Python 스크립트)
- [ ] 재무 데이터 수집 (DART API, Node.js)
- [ ] 뉴스 데이터 수동 입력 (75개)
  - 구글 스프레드시트 템플릿 생성
  - 종목별 주요 이슈 조사
  - CSV 임포트

**산출물**: 채워진 데이터베이스

### 2주차: 분석 로직 구현

- [ ] 재무 점수 계산 함수 (`financial-scorer.ts`)
- [ ] 뉴스 점수 계산 함수 (`news-scorer.ts`)
- [ ] 신호 생성 로직 (`generator.ts`)
- [ ] 백테스트 엔진 (`backtester.ts`)
- [ ] 백테스트 실행 스크립트 (`run_backtest.ts`)

**산출물**: `backtest_predictions` 테이블 채워짐

### 3주차: 결과 분석 및 튜닝

- [ ] 결과 분석 스크립트 작성 (`analyze_results.ts`)
- [ ] CLI 리포트 생성
- [ ] 정확도 평가
- [ ] 파라미터 튜닝
  - 재무:뉴스 비율 조정
  - 신호 임계값 조정
  - 뉴스 기간 조정 (7일 → 3일/14일)
- [ ] 최종 정확도 평가

**산출물**: 분석 리포트, 검증 완료

---

## 성공 기준

### 정량적 목표

| 지표 | 목표 | 설명 |
|------|------|------|
| **3일 방향 정확도** | **55% 이상** | 동전 던지기(50%)보다 유의미하게 나아야 함 |
| **고신뢰도 정확도** | **65% 이상** | 확실한 신호(75점 이상 or 25점 이하)의 정확도 |
| **매수 신호 수익률** | **양수** | 매수 신호 평균 3일 수익률 > 0% |
| **False Positive** | **30% 이하** | 매수 신호 후 하락 비율 |

### 리포트 출력 예시

```
===== 백테스트 결과 =====

총 예측 횟수: 450 (5종목 × 90일)
1일 방향 정확도: 52.3%
3일 방향 정확도: 58.7% ✓
7일 방향 정확도: 61.2%

===== 종목별 정확도 =====
삼성전자: 63.4%
SK하이닉스: 71.2%
NAVER: 45.6%
카카오: 52.1%
현대차: 58.9%

===== 신호 타입별 성과 =====
매수 신호 (78회): 평균 3일 수익률 +1.8% ✓
매도 신호 (45회): 평균 3일 수익률 -1.2%
홀드 신호 (327회): 평균 3일 수익률 +0.2%

===== 신뢰도별 정확도 =====
고신뢰도 (75+ or 25-): 72.5% ✓ (103회 중 75회 정확)
중신뢰도 (40-70): 51.2%

===== 재무 vs 뉴스 기여도 =====
재무 점수만 (100%): 정확도 55.3%
뉴스 점수만 (100%): 정확도 49.1%
현재 조합 (60:40): 정확도 58.7%
최적 조합 발견 → 재무 75% : 뉴스 25% = 62.1% 정확도
```

---

## 실패 시 대응 방안

### 파라미터 튜닝

- [ ] 재무:뉴스 비율 조정
  - 70:30, 80:20, 50:50 테스트
- [ ] 뉴스 분석 기간 조정
  - 7일 → 3일 (최근 뉴스만)
  - 7일 → 14일 (더 넓은 범위)
- [ ] 신호 임계값 조정
  - 70/40 → 75/35 (더 보수적)
  - 70/40 → 65/45 (더 공격적)

### 데이터 정제

- [ ] 정확도 낮은 종목 제외
- [ ] 특정 카테고리 뉴스만 사용
  - 예: `earnings` (실적) 뉴스만
- [ ] 뉴스 라벨링 품질 재검토
  - 감성/영향도 재평가

### 전략 변경

- [ ] 재무 분석만 사용 (뉴스 제외)
- [ ] 뉴스 분석만 사용 (재무 제외)
- [ ] 단순 이동평균선 같은 기술적 지표 추가

---

## 서버 인프라 (오렌지파이5)

### 하드웨어 스펙 (예상)
- CPU: 8코어 ARM
- RAM: 16GB
- 스토리지: 256GB

### 도커 구성

```
오렌지파이5
├── Nginx (Reverse Proxy + SSL) - npm
│   - Cloudflare → 80/443 → 컨테이너
│   - Let's Encrypt 자동 갱신
│
├── Supabase (셀프호스팅)
│   - PostgreSQL
│   - PostgREST API
│   - GoTrue (Auth)
│   - Realtime (Phase 2)
│   - Storage (Phase 2)
│
└── Next.js App (모놀리식)
    - 프론트엔드 (Phase 2)
    - API Routes
    - 비즈니스 로직 모듈
```

### 리소스 예상 사용량

| 컨테이너 | 메모리 | CPU |
|---------|-------|-----|
| PostgreSQL | 512MB | 1 core |
| Nginx | 50MB | 0.5 core |
| Next.js App | 512MB | 1-2 cores |
| **합계** | **~1.1GB** | **2-3 cores** |

**여유분 포함**: 2GB 메모리 사용 예상 (8GB 모델 권장)

### 도메인 및 SSL

- **도메인**: Cloudflare 적용 완료
- **SSL**: Let's Encrypt (Nginx 자동 갱신)
- **포트 포워딩**: 공유기에서 80, 443 → 오렌지파이5

---

## Phase 2 계획 (MVP 성공 시)

### 실시간 시스템 구축 (4-6주)

**추가 기능:**
- [ ] 웹 UI 개발 (Next.js)
  - 대시보드 (종목 요약)
  - 종목 상세 (차트, 재무, 뉴스)
  - 매매 신호 페이지
- [ ] 실시간 뉴스 자동 수집
  - 네이버 뉴스 API (시간당 1회)
  - 자동 분석 (키워드 기반)
- [ ] 신호 생성 자동화
  - 일 1회 자동 실행
  - Supabase Cron 또는 시스템 Cron
- [ ] 알림 시스템
  - 텔레그램 봇
  - 고신뢰도 신호 발생 시 알림
- [ ] 정확도 자동 추적
  - 1-3일 후 자동 검증
  - 주간 리포트 생성

### Phase 3: 확장 (8주+)

- [ ] 종목 확대 (50개+)
- [ ] Claude API 통합 (뉴스 심층 분석)
- [ ] 키움증권 API 연동 (실거래)
- [ ] 사용자 관리 (10명 공유)
- [ ] 포트폴리오 추적 기능

---

## 환경 변수 (.env.local)

```bash
# Supabase (로컬)
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-local-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-local-service-key

# 프로덕션 (오렌지파이5)
# NEXT_PUBLIC_SUPABASE_URL=https://trade.yourdomain.com
# NEXT_PUBLIC_SUPABASE_ANON_KEY=your-prod-anon-key
# SUPABASE_SERVICE_ROLE_KEY=your-prod-service-key

# 외부 API
DART_API_KEY=your-dart-api-key
NAVER_CLIENT_ID=your-naver-client-id
NAVER_CLIENT_SECRET=your-naver-client-secret

# 알림 (Phase 2)
# TELEGRAM_BOT_TOKEN=your-telegram-token
# TELEGRAM_CHAT_ID=your-chat-id

# Claude API (Phase 3)
# ANTHROPIC_API_KEY=your-anthropic-key
```

---

## 다음 단계

### 즉시 시작

1. **DB 스키마 생성**
   - `doc/schema.sql` → Supabase에 실행

2. **데이터 수집 준비**
   - Python 환경 세팅 (`FinanceDataReader` 설치)
   - DART API 키 발급
   - 네이버 API 키 발급 (선택)

3. **뉴스 수집 준비** ⭐ 업데이트됨
   - Claude API 키 발급 (Anthropic)
   - Playwright 설치 (`npx playwright install chromium`)
   - 환경 변수 설정 (`ANTHROPIC_API_KEY`)
   - 상세 가이드: [`doc/news-collection-strategy.md`](./news-collection-strategy.md)

### 1주차 목표

**주가 + 재무 + 뉴스 데이터 수집 완료**
- 450개 주가 레코드 ✅
- 10개 재무 스냅샷
- 75개 뉴스 이벤트 (AI 자동 분석)

---

## 참고 문서

- [데이터베이스 스키마](./schema.sql)
- [뉴스 수집 전략 (하이브리드 AI)](./news-collection-strategy.md) ⭐ 신규
- [DART API 문서](https://opendart.fss.or.kr/guide/main.do)
- [FinanceDataReader 문서](https://github.com/FinanceData/FinanceDataReader)
- [Supabase 셀프호스팅 가이드](https://supabase.com/docs/guides/self-hosting)
- [Claude API 문서](https://docs.anthropic.com/en/api/getting-started)

---

**작성일**: 2025-10-23
**버전**: 1.0
**다음 리뷰**: 1주차 완료 후

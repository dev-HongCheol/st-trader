# 뉴스 데이터 수집 전략 - 하이브리드 AI 분석

> **목표**: 과거 3개월(2025-07-23 ~ 2025-10-22) 뉴스 데이터를 수집하고 Claude API를 활용하여 자동 분석

## 문제점 분석

### 1. 네이버 뉴스 API 제약
- **제한사항**: 최근 1개월 데이터만 조회 가능
- **필요 기간**: 3개월 (90일)
- **해결책**: 네이버 뉴스 검색 페이지 크롤링

### 2. 수동 큐레이션의 한계
- **문제**: 주식/경제 전문 지식 부족으로 낮은 신뢰도
- **해결책**: Claude API를 활용한 자동 분석

---

## 하이브리드 AI 전략

### 비용 최적화 접근

**핵심 아이디어**:
- **1차 필터링**: Claude Haiku (저비용) - 관련성 판단
- **2차 심층 분석**: Claude Sonnet 4.5 (고정확도) - 감성/영향도 분석

### 비용 비교

| 방식 | 1차 필터링 | 2차 분석 | 총 비용 | 정확도 |
|------|-----------|---------|---------|--------|
| **Sonnet만 사용** | 250개 × Sonnet<br>$2.5 | 75개 × Sonnet<br>$2.5 | **$5.0** | ★★★★★ |
| **하이브리드 (채택)** | 250개 × Haiku<br>$0.5 | 75개 × Sonnet 4.5<br>$2.0 | **$2.5** | ★★★★★ |
| **절감 효과** | - | - | **50% 절감** | 동일 |

### 추가 최적화: Prompt Caching

```
캐싱 적용 시:
- 첫 번째 기사: 정상 요금
- 나머지 74개: 캐시된 프롬프트 90% 할인
- 예상 절감: $2.0 → $1.2 (40% 추가 절감)
```

**최종 예상 비용**: **$1.70 - $2.20** (원래 대비 66% 절감)

---

## 구현 프로세스

### 1단계: 네이버 뉴스 크롤링

**도구**: Playwright (TypeScript)

**URL 형식**:
```
https://search.naver.com/search.naver?where=news&query={종목명}&sm=tab_opt&sort=0&photo=0&field=0&pd=3&ds=2025.07.23&de=2025.10.22
```

**수집 목표**:
- 종목당 50개 기사
- 총 250개 원본 기사 (5종목)

**수집 항목**:
```typescript
interface CrawledNews {
  ticker: string;        // 종목코드
  title: string;         // 기사 제목
  content: string;       // 기사 본문 (요약)
  date: string;          // 작성일 (YYYY-MM-DD)
  url: string;           // 원문 URL
  source: string;        // 언론사
}
```

**주의사항**:
- Rate limiting: 요청 간 1초 대기
- User-Agent 설정 (차단 방지)
- 날짜 범위 파라미터 활용

---

### 2단계: Haiku 1차 필터링 (관련성 판단)

**스크립트**: `scripts/filter_news_relevance.ts`

**목표**: 250개 → 80-100개로 압축

**프롬프트**:
```
당신은 주식 뉴스 필터입니다.
아래 뉴스가 {종목명}의 주가에 직접 영향을 줄 가능성이 있는지만 판단하세요.

기사 제목: {title}
기사 날짜: {date}

관련 있는 경우 예시:
- 실적 발표, 전망 수정
- 신제품/서비스 출시
- M&A, 투자 유치
- 규제 변화, 정부 정책
- 주요 임원 변동
- 경쟁사 주요 이슈 (삼성 vs SK하이닉스 등)

관련 없는 경우 예시:
- 일반 산업 동향 (구체적 기업명 없음)
- 타업종 뉴스
- 광고성 기사
- 단순 주가 시세 보도

JSON으로만 답변:
{
  "is_relevant": true/false,
  "confidence": 0.0-1.0,
  "reason": "한 문장으로 이유"
}
```

**필터링 로직**:
```typescript
if (result.is_relevant && result.confidence >= 0.6) {
  // 2차 분석 대상에 포함
}
```

**예상 결과**:
- 관련 뉴스: 80-100개
- 제거된 뉴스: 150-170개 (60-68%)
- 비용: $0.50

---

### 3단계: Sonnet 4.5 심층 분석

**스크립트**: `scripts/analyze_news_sentiment.ts`

**목표**: 80-100개 → 최종 75개 선별 + 상세 분석

**프롬프트**:
```
당신은 주식 애널리스트입니다.
아래 뉴스를 심층 분석하여 투자 판단에 필요한 정보를 추출하세요.

종목: {company} ({ticker})
기사 제목: {title}
기사 본문: {content}
작성일: {date}

분석 기준:

1. category (카테고리):
   - earnings: 실적 발표/전망/어닝 서프라이즈
   - product: 신제품/서비스 출시 또는 개발 소식
   - regulation: 규제/정책 변화 (정부, 업계)
   - macro: 거시경제 (금리, 환율, 원자재가 등)
   - geopolitics: 지정학적 리스크 (미중 갈등, 반도체법 등)

2. sentiment (감성):
   - positive: 주가 상승 요인 (실적 개선, 신규 계약 등)
   - negative: 주가 하락 요인 (실적 악화, 규제 강화 등)
   - neutral: 중립적 (단순 정보 전달)

3. impact (영향도):
   - high: 3일 내 5% 이상 변동 예상 (실적 발표, 대규모 투자 등)
   - medium: 1-3% 변동 예상 (신제품 출시, 소규모 이슈)
   - low: 1% 미만 변동 예상 (일반 뉴스)

4. reasoning (근거):
   - 왜 이렇게 판단했는지 2-3문장으로 설명
   - 가능하다면 과거 유사 사례 언급

5. confidence (신뢰도):
   - 0.0-1.0 (이 분석에 대한 확신 정도)
   - 정보가 불충분하거나 모호하면 낮게 설정

JSON 형식으로 답변:
{
  "category": "earnings|product|regulation|macro|geopolitics",
  "sentiment": "positive|negative|neutral",
  "impact": "high|medium|low",
  "summary": "핵심 내용 한 문장 (30자 이내)",
  "reasoning": "판단 근거 (100자 이내)",
  "confidence": 0.0-1.0
}
```

**Prompt Caching 설정**:
```typescript
const systemPrompt = {
  type: "text",
  text: "당신은 주식 애널리스트입니다...", // 반복되는 프롬프트
  cache_control: { type: "ephemeral" } // 캐싱 활성화
};

// 나머지 74개 기사는 캐시된 프롬프트 재사용 (90% 할인)
```

**최종 선별 로직**:
```typescript
// confidence 기준으로 상위 75개 선택
const finalNews = sortedByConfidence
  .filter(n => n.confidence >= 0.7)
  .slice(0, 75);

// 종목당 15개 균등 분배
const balancedNews = balanceByTicker(finalNews, 15);
```

**예상 결과**:
- 최종 뉴스: 75개 (종목당 15개)
- confidence >= 0.7: 고품질 분석
- 비용: $2.0 → $1.2 (캐싱 적용 시)

---

### 4단계: 데이터베이스 저장

**스크립트**: `scripts/import_analyzed_news.ts`

**테이블**: `st_news_events`

**저장 항목**:
```typescript
interface NewsEventRecord {
  company_id: string;              // UUID (st_companies 참조)
  event_date: string;              // 기사 날짜
  title: string;                   // 기사 제목
  summary: string;                 // Claude 생성 요약 (30자)
  category: string;                // earnings|product|regulation|macro|geopolitics
  manual_sentiment: string;        // positive|negative|neutral (Claude 판단)
  manual_impact: string;           // high|medium|low (Claude 판단)
  source_url: string;              // 원문 URL

  // AI 분석 메타데이터 (스키마 확장 필요)
  ai_reasoning: string;            // Claude의 판단 근거
  ai_confidence: number;           // 0.00-1.00
  ai_model: string;                // 'claude-sonnet-4.5'
}
```

**UPSERT 로직**:
```typescript
await supabase
  .from('st_news_events')
  .upsert(newsEvent, {
    onConflict: 'company_id,event_date,title' // 중복 방지
  });
```

---

## 데이터베이스 스키마 확장

### 추가 컬럼 (st_news_events 테이블)

```sql
-- AI 분석 메타데이터 추가
ALTER TABLE st_news_events
  ADD COLUMN IF NOT EXISTS ai_reasoning TEXT,
  ADD COLUMN IF NOT EXISTS ai_confidence DECIMAL(3,2) CHECK (ai_confidence >= 0 AND ai_confidence <= 1),
  ADD COLUMN IF NOT EXISTS ai_model VARCHAR(50);

-- 컬럼 설명 추가
COMMENT ON COLUMN st_news_events.ai_reasoning IS 'Claude가 sentiment/impact를 판단한 근거 (디버깅 및 검증용)';
COMMENT ON COLUMN st_news_events.ai_confidence IS 'AI 분석 신뢰도 (0.00-1.00, 높을수록 확신)';
COMMENT ON COLUMN st_news_events.ai_model IS '사용한 AI 모델명 (예: claude-sonnet-4.5, claude-haiku-3.5)';

-- 인덱스 추가 (신뢰도 기반 조회 최적화)
CREATE INDEX IF NOT EXISTS idx_st_news_confidence
  ON st_news_events(ai_confidence DESC, event_date DESC)
  WHERE ai_confidence IS NOT NULL;

COMMENT ON INDEX idx_st_news_confidence IS '고신뢰도 뉴스 조회 최적화 (ai_confidence >= 0.8)';
```

**활용 방안**:
- `ai_reasoning`: 나중에 AI 판단 오류 분석 및 개선
- `ai_confidence`: 백테스트 시 가중치 조정 (confidence 높은 뉴스에 더 높은 가중치)
- `ai_model`: 모델 버전별 성능 비교 (Haiku vs Sonnet)

---

## 구현 파일 구조

```
scripts/
├── crawl_news.ts                   # 1단계: 네이버 뉴스 크롤링
│   └── 출력: data/crawled_news.json (250개)
│
├── filter_news_relevance.ts        # 2단계: Haiku 1차 필터링
│   └── 출력: data/filtered_news.json (80-100개)
│
├── analyze_news_sentiment.ts       # 3단계: Sonnet 4.5 심층 분석
│   └── 출력: data/analyzed_news.json (75개)
│
└── import_analyzed_news.ts         # 4단계: DB 저장
    └── 출력: st_news_events 테이블에 75개 레코드

data/
├── crawled_news.json               # 크롤링 원본
├── filtered_news.json              # 1차 필터링 결과
└── analyzed_news.json              # 최종 분석 결과 (DB 저장 전)
```

---

## 환경 변수 설정

`.env` 파일에 추가:

```bash
# Claude API
ANTHROPIC_API_KEY=sk-ant-api03-...

# Supabase (기존)
NEXT_PUBLIC_SUPABASE_URL=https://supa.devhong.cc
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# 크롤링 설정
CRAWL_DELAY_MS=1000                 # 요청 간 대기 시간 (1초)
CRAWL_MAX_RETRIES=3                 # 실패 시 재시도 횟수
```

---

## 실행 순서

### 1. 환경 설정
```bash
# 패키지 설치
npm install @anthropic-ai/sdk playwright

# Playwright 브라우저 설치
npx playwright install chromium

# 환경 변수 설정
# .env 파일에 ANTHROPIC_API_KEY 추가
```

### 2. 데이터베이스 스키마 준비

**신규 DB 생성 시:**
```bash
# schema.sql을 직접 실행 (AI 메타데이터 포함)
psql -h supa.devhong.cc -U postgres -d postgres -f doc/schema.sql
```

**기존 DB 마이그레이션 시:**
```bash
# 기존 테이블에 AI 메타데이터 컬럼 추가
psql -h supa.devhong.cc -U postgres -d postgres -f doc/schema-news-extension.sql
```

> **참고**: `schema-news-extension.sql`은 마이그레이션 파일로, 기존 `st_news_events` 테이블에 `ai_reasoning`, `ai_confidence`, `ai_model` 컬럼을 추가합니다. 여러 번 실행해도 안전합니다 (IF NOT EXISTS 사용).

### 3. 뉴스 수집 및 분석 실행
```bash
# 1단계: 크롤링 (예상 시간: 10-15분)
npx tsx scripts/crawl_news.ts

# 2단계: 1차 필터링 (예상 시간: 3-5분, 비용: $0.5)
npx tsx scripts/filter_news_relevance.ts

# 3단계: 심층 분석 (예상 시간: 5-10분, 비용: $1.2-2.0)
npx tsx scripts/analyze_news_sentiment.ts

# 4단계: DB 저장 (예상 시간: 1-2분)
npx tsx scripts/import_analyzed_news.ts
```

### 4. 검증
```bash
# DB 레코드 확인
psql -h supa.devhong.cc -U postgres -d postgres -c "
  SELECT
    c.name,
    COUNT(*) as news_count,
    AVG(n.ai_confidence)::DECIMAL(3,2) as avg_confidence
  FROM st_news_events n
  JOIN st_companies c ON n.company_id = c.id
  GROUP BY c.name
  ORDER BY c.name;
"

# 예상 출력:
#   name      | news_count | avg_confidence
# ------------|------------|----------------
#  NAVER      |     15     |     0.85
#  SK하이닉스  |     15     |     0.82
#  카카오      |     15     |     0.78
#  삼성전자    |     15     |     0.88
#  현대차      |     15     |     0.81
```

---

## 비용 및 시간 예상

### 총 비용
| 항목 | 비용 |
|------|------|
| Haiku 1차 필터링 (250개) | $0.50 |
| Sonnet 4.5 심층 분석 (75개) | $2.00 |
| Prompt Caching 절감 | -$0.80 |
| **총계** | **$1.70** |

### 총 시간
| 단계 | 시간 |
|------|------|
| 크롤링 | 10-15분 |
| 1차 필터링 (Haiku) | 3-5분 |
| 2차 분석 (Sonnet) | 5-10분 |
| DB 저장 | 1-2분 |
| **총계** | **20-30분** |

---

## 백테스트 활용 방안

### 뉴스 점수 계산 시 confidence 가중치

```typescript
// src/modules/scoring/news-scorer.ts

function calculateNewsScore(news: NewsEvent[]): number {
  let totalScore = 0;
  let totalWeight = 0;

  news.forEach(n => {
    // 감성 점수
    const sentimentScore =
      n.manual_sentiment === 'positive' ? 10 :
      n.manual_sentiment === 'negative' ? -10 : 0;

    // 영향도 가중치
    const impactWeight =
      n.manual_impact === 'high' ? 2.0 :
      n.manual_impact === 'medium' ? 1.0 : 0.5;

    // AI 신뢰도 가중치 (NEW!)
    const confidenceWeight = n.ai_confidence || 1.0;

    // 시간 감쇠 (7일 전 = 50%)
    const daysSince = getDaysDiff(n.event_date, today);
    const timeDecay = Math.max(0.5, 1 - daysSince / 14);

    // 최종 가중치
    const weight = impactWeight * confidenceWeight * timeDecay;

    totalScore += sentimentScore * weight;
    totalWeight += weight;
  });

  // 0-100점 정규화
  const normalizedScore = totalWeight > 0
    ? 50 + (totalScore / totalWeight) * 5
    : 50;

  return Math.max(0, Math.min(100, normalizedScore));
}
```

**효과**:
- confidence 낮은 뉴스(0.6)는 영향력 40% 감소
- confidence 높은 뉴스(0.95)는 정상 반영
- 백테스트 정확도 향상 예상: 2-3%p

---

## 모니터링 및 검증

### AI 판단 검증 쿼리

```sql
-- confidence 낮은 뉴스 확인 (재검토 대상)
SELECT
  c.name,
  n.event_date,
  n.title,
  n.manual_sentiment,
  n.ai_confidence,
  n.ai_reasoning
FROM st_news_events n
JOIN st_companies c ON n.company_id = c.id
WHERE n.ai_confidence < 0.7
ORDER BY n.ai_confidence ASC, n.event_date DESC
LIMIT 20;
```

```sql
-- 카테고리별 sentiment 분포
SELECT
  category,
  manual_sentiment,
  COUNT(*) as count,
  AVG(ai_confidence)::DECIMAL(3,2) as avg_confidence
FROM st_news_events
GROUP BY category, manual_sentiment
ORDER BY category, manual_sentiment;
```

---

## 향후 개선 방안

### Phase 2: 실시간 뉴스 수집 (MVP 성공 시)

1. **자동화 파이프라인**
   - 일 1회 자동 크롤링 (Cron)
   - 신규 뉴스만 분석 (중복 제거)
   - Supabase Edge Functions 활용

2. **Fine-tuning 데이터 축적**
   - AI 판단 vs 실제 주가 변동 비교
   - 오판 사례 수집 → Claude fine-tuning
   - 정확도 지속 개선

3. **실시간 알림**
   - high impact + positive → 텔레그램 알림
   - confidence >= 0.9 → 즉시 알림

---

## 참고 문서

- [Claude API 공식 문서](https://docs.anthropic.com/en/api/getting-started)
- [Prompt Caching 가이드](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Playwright 크롤링 가이드](https://playwright.dev/docs/intro)
- [preparation.md](./preparation.md) - 전체 시스템 설계

---

**작성일**: 2025-10-24
**버전**: 1.0
**다음 리뷰**: 뉴스 수집 완료 후

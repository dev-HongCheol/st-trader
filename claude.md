# 주식 트레이딩 시스템 개발 명세서

## 프로젝트 개요

국내 주식의 재무정보와 뉴스 이슈를 분석하여 자동 매매 신호를 생성하는 웹 애플리케이션을 개발합니다.

## 기술 스택

- **Frontend**: Next.js 14+ (App Router), TypeScript, React
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Edge Functions)
- **UI**: TailwindCSS, shadcn/ui
- **차트**: Recharts
- **상태관리**: TanStack Query (React Query)
- **API**: 키움증권 OpenAPI, 네이버 뉴스 API, DART API, 한국은행 API

## 시스템 아키텍처

```
[사용자] 
    ↓
[Next.js Frontend]
    ↓
[Supabase Backend]
    ↓
[외부 API들: DART, 네이버뉴스, 한국은행, 키움증권]
```


## 2. 백엔드 기능 (Supabase Edge Functions)

### 2.1 데이터 수집 함수들

#### `collect-dart-data` (DART 재무제표 수집)
```typescript
// supabase/functions/collect-dart-data/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  // DART API로 재무제표 수집
  // companies 테이블에서 ticker 조회
  // DART API 호출
  // financial_statements 테이블에 저장
  // financial_ratios 계산 및 저장
})
```

#### `collect-news` (뉴스 수집)
```typescript
// supabase/functions/collect-news/index.ts
// 다층 키워드 전략으로 뉴스 수집
const keywords = {
  direct: ['삼성전자', 'SK하이닉스'],
  industry: ['반도체', 'AI칩', 'HBM'],
  macro: ['금리', '환율', '유가'],
  geopolitics: ['미중 갈등', '반도체 규제', '전쟁']
};

// 네이버 뉴스 API 호출
// news_articles 테이블에 저장
```

#### `analyze-news` (뉴스 분석)
```typescript
// supabase/functions/analyze-news/index.ts
// analyzed = false인 뉴스 조회
// 키워드 기반 relevance_score 계산
// 고득점 뉴스는 Claude API로 심층 분석 (선택)
// sentiment, impact_direction, confidence 업데이트
```

#### `calculate-signals` (매매 신호 생성)
```typescript
// supabase/functions/calculate-signals/index.ts
// 재무비율 점수 계산 (0-100)
// 뉴스 분석 점수 계산 (0-100)
// 종합 점수 산출
// 임계값 이상이면 trading_signals 생성
```

### 2.2 백테스팅 함수

#### `run-backtest` (백테스트 실행)
```typescript
// supabase/functions/run-backtest/index.ts
// 과거 기간 설정
// 과거 데이터로 신호 재생성
// 실제 주가 변동과 비교
// backtest_results에 저장
```

#### `verify-predictions` (예측 검증)
```typescript
// supabase/functions/verify-predictions/index.ts
// 1-3일 전 예측 조회
// 실제 주가 변동 확인
// accuracy_tracking 업데이트
// 주간 정확도 리포트 생성
```

### 2.3 스케줄러 (Supabase Cron Jobs)

```sql
-- pg_cron 활용
SELECT cron.schedule(
  'collect-news-hourly',
  '0 * * * *', -- 매시간
  $$SELECT net.http_post(url:='https://[project].supabase.co/functions/v1/collect-news')$$
);

SELECT cron.schedule(
  'analyze-news-5min',
  '*/5 * * * *', -- 5분마다
  $$SELECT net.http_post(url:='https://[project].supabase.co/functions/v1/analyze-news')$$
);

SELECT cron.schedule(
  'calculate-signals-daily',
  '0 0 * * *', -- 매일 자정
  $$SELECT net.http_post(url:='https://[project].supabase.co/functions/v1/calculate-signals')$$
);

SELECT cron.schedule(
  'verify-predictions-daily',
  '0 1 * * *', -- 매일 새벽 1시
  $$SELECT net.http_post(url:='https://[project].supabase.co/functions/v1/verify-predictions')$$
);
```

## 3. 프론트엔드 구조 (Next.js)

### 3.1 폴더 구조
```
src/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   └── signup/
│   ├── (dashboard)/
│   │   ├── page.tsx              # 대시보드 홈
│   │   ├── stocks/
│   │   │   ├── page.tsx          # 종목 리스트
│   │   │   └── [ticker]/
│   │   │       └── page.tsx      # 종목 상세
│   │   ├── signals/
│   │   │   └── page.tsx          # 매매 신호
│   │   ├── news/
│   │   │   └── page.tsx          # 뉴스 분석
│   │   ├── backtest/
│   │   │   └── page.tsx          # 백테스팅
│   │   └── accuracy/
│   │       └── page.tsx          # 정확도 대시보드
│   ├── api/
│   │   └── ... # API routes (필요시)
│   └── layout.tsx
├── components/
│   ├── ui/                        # shadcn/ui 컴포넌트
│   ├── charts/                    # 차트 컴포넌트
│   ├── tables/                    # 테이블 컴포넌트
│   └── features/                  # 기능별 컴포넌트
│       ├── financial-analysis/
│       ├── news-analysis/
│       ├── trading-signals/
│       └── backtest/
├── lib/
│   ├── supabase/
│   │   ├── client.ts
│   │   └── server.ts
│   ├── api/                       # 외부 API 클라이언트
│   │   ├── dart.ts
│   │   ├── naver-news.ts
│   │   └── bok.ts                 # 한국은행
│   ├── utils/
│   │   ├── financial-calculator.ts
│   │   └── date-utils.ts
│   └── types/
│       └── index.ts
└── hooks/
    ├── useCompanies.ts
    ├── useFinancials.ts
    ├── useNews.ts
    └── useSignals.ts
```

### 3.2 주요 페이지 컴포넌트

#### 대시보드 홈 (`app/(dashboard)/page.tsx`)
```typescript
// 표시 내용:
// - 관심 종목 요약 (가격, 변동률)
// - 최근 매매 신호 (상위 5개)
// - 중요 뉴스 (상위 10개)
// - 정확도 지표 (주간 평균)
// - 포트폴리오 수익률 (있다면)
```

#### 종목 상세 (`app/(dashboard)/stocks/[ticker]/page.tsx`)
```typescript
// 표시 내용:
// - 기본 정보 (회사명, 업종, 시가총액)
// - 주가 차트 (Recharts)
// - 재무제표 테이블 (최근 4분기)
// - 재무비율 차트
// - 관련 뉴스 타임라인
// - 현재 매매 신호
// - 과거 신호 정확도
```

#### 매매 신호 (`app/(dashboard)/signals/page.tsx`)
```typescript
// 표시 내용:
// - 신호 필터 (종목, 신호 유형, 신뢰도)
// - 신호 카드 리스트
//   - 종목명, 신호 유형, 신뢰도
//   - 근거 요약 (재무/뉴스/기술적)
//   - 목표가, 손절가
// - 신호 상세 모달
```

#### 뉴스 분석 (`app/(dashboard)/news/page.tsx`)
```typescript
// 표시 내용:
// - 뉴스 필터 (카테고리, 날짜, 감성)
// - 뉴스 타임라인
// - 감성 분석 차트 (긍정/부정 비율)
// - 주요 키워드 워드클라우드
// - 뉴스 상세 모달
```

#### 백테스팅 (`app/(dashboard)/backtest/page.tsx`)
```typescript
// 표시 내용:
// - 백테스트 설정 폼
//   - 종목 선택
//   - 기간 선택
//   - 전략 파라미터
// - 실행 버튼
// - 결과 차트
//   - 누적 수익률
//   - 거래 내역 타임라인
//   - 성과 지표 (승률, 평균 수익률 등)
```

#### 정확도 대시보드 (`app/(dashboard)/accuracy/page.tsx`)
```typescript
// 표시 내용:
// - 전체 정확도 지표
//   - 방향성 정확도
//   - 크기 정확도
//   - 시간 프레임 정확도
// - 카테고리별 정확도 차트
// - 주간 트렌드 그래프
// - 개선 제안 리스트
// - 예측 vs 실제 비교 테이블
```

### 3.3 컴포넌트 코드 컨밴션
- 구현된 모든 함수에 주석추가
- 분기문 내부 코드가 10라인 이상이면 주석 추가

## 4. 주요 기능 구현

### 4.1 재무 분석 시스템
```typescript
// lib/utils/financial-calculator.ts
export class FinancialCalculator {
  // 수익성 지표
  calculateGrossMargin(revenue: number, costOfRevenue: number): number
  calculateOperatingMargin(operatingIncome: number, revenue: number): number
  calculateNetProfitMargin(netIncome: number, revenue: number): number
  calculateROE(netIncome: number, equity: number): number
  calculateROA(netIncome: number, assets: number): number
  
  // 안정성 지표
  calculateCurrentRatio(currentAssets: number, currentLiabilities: number): number
  calculateQuickRatio(currentAssets: number, inventory: number, currentLiabilities: number): number
  calculateDebtToEquity(liabilities: number, equity: number): number
  
  // 성장성 지표
  calculateRevenueGrowth(currentRevenue: number, previousRevenue: number): number
  
  // 종합 점수 (0-100)
  calculateFinancialScore(ratios: FinancialRatios): number
}
```

### 4.2 뉴스 분석 시스템
```typescript
// lib/utils/news-analyzer.ts
export class NewsAnalyzer {
  // 키워드 기반 관련성 점수
  calculateRelevanceScore(article: NewsArticle, company: Company): number {
    // 직접 언급: +50
    // 산업 키워드: +30
    // 거시경제: +20
    // 지정학: +15
  }
  
  // 감성 분석 (간단한 키워드 기반)
  analyzeSentiment(text: string): 'positive' | 'negative' | 'neutral' {
    const positiveKeywords = ['수주', '증가', '성장', '호실적', '상승'];
    const negativeKeywords = ['감소', '하락', '적자', '리콜', '위기'];
    // 키워드 매칭으로 판단
  }
  
  // 영향도 분석
  analyzeImpact(article: NewsArticle): {
    direction: 'bullish' | 'bearish' | 'neutral',
    magnitude: 'high' | 'medium' | 'low',
    confidence: number
  }
}
```

### 4.3 매매 신호 생성
```typescript
// lib/utils/signal-generator.ts
export class SignalGenerator {
  generateSignal(
    company: Company,
    financials: FinancialRatios,
    news: NewsArticle[]
  ): TradingSignal {
    // 재무 점수 (0-100)
    const financialScore = this.calculateFinancialScore(financials);
    
    // 뉴스 점수 (0-100)
    const newsScore = this.calculateNewsScore(news);
    
    // 종합 점수
    const totalScore = (financialScore * 0.6) + (newsScore * 0.4);
    
    // 신호 생성
    if (totalScore >= 75) {
      return { type: 'buy', confidence: totalScore };
    } else if (totalScore <= 35) {
      return { type: 'sell', confidence: 100 - totalScore };
    } else {
      return { type: 'hold', confidence: 50 };
    }
  }
}
```

### 4.4 백테스팅 엔진
```typescript
// lib/utils/backtester.ts
export class Backtester {
  async run(params: BacktestParams): Promise<BacktestResult> {
    const { companyId, startDate, endDate, strategy } = params;
    
    // 1. 과거 데이터 로드
    const historicalData = await this.loadHistoricalData(companyId, startDate, endDate);
    
    // 2. 시뮬레이션
    let capital = 10000000; // 초기 자본
    const trades = [];
    
    for (const data of historicalData) {
      const signal = this.generateHistoricalSignal(data, strategy);
      
      if (signal.type === 'buy' && signal.confidence > strategy.buyThreshold) {
        // 매수 로직
      } else if (signal.type === 'sell' && position) {
        // 매도 로직
        trades.push(trade);
      }
    }
    
    // 3. 성과 계산
    return this.calculatePerformance(trades, capital);
  }
}
```

### 4.5 정확도 추적 시스템
```typescript
// lib/utils/accuracy-tracker.ts
export class AccuracyTracker {
  async trackPrediction(newsId: string, prediction: Prediction): Promise<void> {
    // accuracy_tracking 테이블에 예측 저장
  }
  
  async verifyPredictions(): Promise<void> {
    // 1-3일 전 예측들 조회
    // 실제 주가 변동 확인
    // direction_correct, magnitude_correct 업데이트
  }
  
  async calculateAccuracy(period: DateRange): Promise<AccuracyMetrics> {
    // 기간 내 모든 검증된 예측 조회
    // 방향성 정확도, 크기 정확도 계산
    // 카테고리별 분해
    return {
      overall: 75.3,
      byCategory: {
        earnings: 85.0,
        macro: 68.5,
        // ...
      }
    };
  }
}
```

## 6. 환경 변수 (.env.local)

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# 외부 API
DART_API_KEY=your-dart-api-key
NAVER_CLIENT_ID=your-naver-client-id
NAVER_CLIENT_SECRET=your-naver-client-secret
BOK_API_KEY=your-bok-api-key

# Claude API (선택)
ANTHROPIC_API_KEY=your-anthropic-api-key

# 키움증권 (추후)
KIWOOM_APP_KEY=your-kiwoom-key
KIWOOM_APP_SECRET=your-kiwoom-secret
```

## 7. 개발 우선순위

### Phase 1: 기본 인프라 (1-2주)
- [ ] Next.js 프로젝트 초기화
- [ ] Supabase 프로젝트 생성 및 DB 스키마 구축
- [ ] 인증 시스템 (Supabase Auth)
- [ ] 기본 UI 레이아웃 및 라우팅

### Phase 2: 데이터 수집 (2-3주)
- [ ] DART API 연동 (재무제표 수집)
- [ ] 네이버 뉴스 API 연동
- [ ] 한국은행 API 연동 (거시 지표)
- [ ] Edge Functions 구현
- [ ] Cron Jobs 설정

### Phase 3: 분석 엔진 (2-3주)
- [ ] 재무비율 계산 로직
- [ ] 뉴스 분석 로직 (키워드 기반)
- [ ] 매매 신호 생성 로직
- [ ] 관련성 점수 알고리즘

### Phase 4: 프론트엔드 (3-4주)
- [ ] 대시보드 페이지
- [ ] 종목 상세 페이지
- [ ] 매매 신호 페이지
- [ ] 뉴스 분석 페이지
- [ ] 차트 및 시각화

### Phase 5: 백테스팅 (2주)
- [ ] 백테스팅 엔진
- [ ] 백테스트 UI
- [ ] 성과 분석 차트

### Phase 6: 정확도 추적 (2주)
- [ ] 예측 저장 시스템
- [ ] 자동 검증 로직
- [ ] 정확도 대시보드
- [ ] 주간 리포트 생성

### Phase 7: 최적화 및 고도화 (지속적)
- [ ] 성능 최적화
- [ ] Claude API 통합 (선택적 AI 분석)
- [ ] 알림 시스템
- [ ] 모바일 최적화
- [ ] 키움증권 API 연동 (실거래)

## 8. 테스트 전략

### 8.1 백테스트 데이터
- **기간**: 2024년 1월 1일 ~ 2024년 12월 31일
- **종목**: 삼성전자, SK하이닉스, 현대차 등 주요 5-
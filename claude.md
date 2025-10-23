# 주식 트레이딩 시스템 - Claude 개발 지침서

> 상세 기획은 `doc/preparation.md` 참조

## 기술 스택

- **Frontend**: Next.js 14+ (App Router), TypeScript, React
- **Backend**: Supabase (PostgreSQL)
- **UI**: TailwindCSS, shadcn/ui
- **차트**: Recharts
- **상태관리**: TanStack Query
- **데이터 수집**: FinanceDataReader (Python), Supabase 직접 연결

## 핵심 아키텍처

```
Python Scripts → Supabase (st_* 테이블) → Next.js Frontend
```

## 현재 구현 상태

### Phase 1: 데이터 수집 (완료)

- ✅ Python 스크립트로 주가/재무 데이터 수집
- ✅ Supabase 직접 연결 및 저장
- ✅ st\_ prefix 테이블 구조

### 주요 테이블

- `st_companies`: 종목 정보 (5개)
- `st_daily_prices`: 일별 주가 (OHLCV)
- `st_financial_snapshots`: 분기별 재무제표
- `st_news_events`: 뉴스 이벤트 (수동 입력)
- `st_backtest_predictions`: 백테스트 결과

## 프론트엔드 구조

### 핵심 폴더 구조

```
src/
├── app/(dashboard)/
│   ├── page.tsx              # 대시보드 홈
│   ├── stocks/[ticker]/      # 종목 상세
│   ├── signals/              # 매매 신호
│   └── backtest/             # 백테스팅
├── lib/supabase/             # DB 연결
└── components/ui/            # shadcn/ui
```

## 코드 컨벤션

### TypeScript/React

- 모든 함수에 주석 추가
- 분기문 내부 10라인 이상 시 주석 추가
- Props 타입 정의 필수
- shadcn/ui 컴포넌트 사용
- next js기반의 SSR우선 적용과 FSD 아키텍쳐 적용

## 데이터베이스 작업 규칙

### DB 스키마 관리 원칙

1. **코멘트 필수**: 모든 테이블, 컬럼, 인덱스, 함수에 코멘트 작성
2. **SQL 파일 동기화**: doc/schema.sql 파일을 항상 최신 상태로 유지
3. **변경 이력**: 스키마 변경 시 migration 스크립트 작성

### 필수 작업 체크리스트

```sql
-- ✅ 테이블 생성 시
CREATE TABLE table_name (
  -- 컬럼 정의
);
COMMENT ON TABLE table_name IS '테이블 목적 설명';
COMMENT ON COLUMN table_name.column_name IS '컬럼 용도 및 제약사항';

-- ✅ 인덱스 생성 시
CREATE INDEX idx_name ON table_name(column1, column2);
-- 인덱스 목적을 코멘트로 설명

-- ✅ 함수/프로시저 생성 시
COMMENT ON FUNCTION function_name IS '함수 목적과 사용법';
```

### 성능 최적화 가이드

- 조회 패턴에 맞는 복합 인덱스 생성
- WHERE 절에 자주 사용되는 컬럼에 인덱스
- 파티셔닝 고려 (대용량 데이터)
- 제약조건으로 데이터 무결성 보장

### 네이밍 컨벤션

- 테이블: st\_ prefix + 복수형 (`st_companies`)
- 인덱스: `idx_st_table_column` 형식
- 제약조건: `chk_table_rule`

## 핵심 함수 시그니처

### 재무 분석

```typescript
// 재무 점수 계산 (0-100점)
calculateFinancialScore(ratios: FinancialRatios): number

// 종합 점수 = 재무점수 × 0.6 + 뉴스점수 × 0.4
```

### 신호 생성

```typescript
// 매매 신호 생성
generateSignal(financials: FinancialRatios, news: NewsArticle[]): TradingSignal
// 75점 이상: BUY, 25점 이하: SELL, 나머지: HOLD
```

### 환경 변수

```bash
NEXT_PUBLIC_SUPABASE_URL=https://supa.devhong.cc
SUPABASE_SERVICE_ROLE_KEY=your-service-key
```

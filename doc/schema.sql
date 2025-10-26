-- ====================================================================
-- 주식 트레이딩 시스템 - MVP 데이터베이스 스키마
-- ====================================================================
-- 목적: 백테스팅 기반 정확도 검증 시스템
-- 대상 기간: 2025-07-23 ~ 2025-10-22 (3개월)
-- 대상 종목: 5개 (삼성전자, SK하이닉스, NAVER, 카카오, 현대차)
-- 
-- 테이블 네이밍: st_ prefix 사용
-- 이유: 셀프호스팅 Supabase 환경에서 여러 프로젝트 사용으로 인한 네임스페이스 분리 필요
--      st = Stock Trading 약자로 명확한 의미 전달 및 충돌 방지
-- ====================================================================

-- 1. 종목 정보
-- 5개 주요 종목만 관리
CREATE TABLE st_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker VARCHAR(20) UNIQUE NOT NULL, -- 종목코드 예: '005930'
  name VARCHAR(100) NOT NULL,         -- 종목명 예: '삼성전자'
  market VARCHAR(20),                 -- 'KOSPI' or 'KOSDAQ'
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 초기 데이터 삽입
INSERT INTO st_companies (ticker, name, market) VALUES
('005930', '삼성전자', 'KOSPI'),
('000660', 'SK하이닉스', 'KOSPI'),
('035420', 'NAVER', 'KOSPI'),
('035720', '카카오', 'KOSPI'),
('005380', '현대차', 'KOSPI');

COMMENT ON TABLE st_companies IS '분석 대상 종목 정보';
COMMENT ON COLUMN st_companies.ticker IS '6자리 종목코드';

-- ====================================================================

-- 2. 일별 주가 데이터
-- 예상 레코드 수: 450개 (5종목 × 90일)
CREATE TABLE st_daily_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES st_companies(id) ON DELETE CASCADE,
  date DATE NOT NULL,

  -- OHLCV 데이터
  open_price INTEGER NOT NULL,      -- 시가
  high_price INTEGER NOT NULL,      -- 고가
  low_price INTEGER NOT NULL,       -- 저가
  close_price INTEGER NOT NULL,     -- 종가
  volume BIGINT,                    -- 거래량

  -- 메타데이터
  created_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(company_id, date)
);

-- 인덱스: 종목별 날짜 조회 최적화
CREATE INDEX idx_st_prices_company_date ON st_daily_prices(company_id, date DESC);

COMMENT ON TABLE st_daily_prices IS '일별 주가 데이터 (OHLCV)';
COMMENT ON COLUMN st_daily_prices.close_price IS '종가, 수익률 계산에 사용';

-- ====================================================================

-- 3. 재무 스냅샷 (분기별)
-- 예상 레코드 수: 10개 (5종목 × 2분기: 2025 2Q, 3Q)
CREATE TABLE st_financial_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES st_companies(id) ON DELETE CASCADE,
  quarter_date DATE NOT NULL,       -- 분기 마지막 날: 2025-06-30, 2025-09-30

  -- 손익계산서 핵심 지표
  revenue BIGINT,                   -- 매출액
  operating_income BIGINT,          -- 영업이익
  net_income BIGINT,                -- 순이익

  -- 대차대조표 핵심 지표
  total_assets BIGINT,              -- 총자산
  total_equity BIGINT,              -- 총자본

  -- 계산된 재무비율 (성능 최적화를 위해 미리 계산)
  operating_margin DECIMAL(5,2),    -- 영업이익률 = (영업이익 / 매출액) × 100
  net_margin DECIMAL(5,2),          -- 순이익률 = (순이익 / 매출액) × 100
  roe DECIMAL(5,2),                 -- ROE = (순이익 / 자기자본) × 100

  -- 메타데이터
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(company_id, quarter_date)
);

-- 인덱스: 종목별 최신 재무 조회
CREATE INDEX idx_st_financial_company_quarter ON st_financial_snapshots(company_id, quarter_date DESC);

COMMENT ON TABLE st_financial_snapshots IS '분기별 재무제표 스냅샷';
COMMENT ON COLUMN st_financial_snapshots.operating_margin IS '영업이익률 (%), 수익성 평가';
COMMENT ON COLUMN st_financial_snapshots.roe IS 'ROE (%), 자본 효율성 평가';

-- ====================================================================

-- 4. 뉴스/이슈 (AI 자동 분석)
-- 예상 레코드 수: 75개 (5종목 × 15개 주요 이슈)
CREATE TABLE st_news_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES st_companies(id) ON DELETE CASCADE,
  event_date DATE NOT NULL,         -- 뉴스 발생일

  -- 뉴스 내용
  title TEXT NOT NULL,              -- 뉴스 제목
  summary TEXT,                     -- 뉴스 요약 (AI 생성 또는 수동)
  source_url TEXT,                  -- 원문 URL

  -- 분류 (AI 자동 라벨링)
  category VARCHAR(50),             -- 'earnings', 'product', 'regulation', 'macro', 'geopolitics'

  -- AI 라벨링
  manual_sentiment VARCHAR(20),     -- 'positive', 'negative', 'neutral' (Claude 판단)
  manual_impact VARCHAR(20),        -- 'high', 'medium', 'low' (Claude 판단)

  -- AI 분석 메타데이터
  ai_reasoning TEXT,                -- Claude가 sentiment/impact를 판단한 근거
  ai_confidence DECIMAL(3,2),       -- AI 분석 신뢰도 (0.00-1.00)
  ai_model VARCHAR(50),             -- 사용한 AI 모델명 (예: claude-sonnet-4.5)

  -- 메타데이터
  created_at TIMESTAMP DEFAULT NOW()
);

-- 인덱스: 종목별 최근 뉴스 조회
CREATE INDEX idx_st_news_company_date ON st_news_events(company_id, event_date DESC);

-- 인덱스: 날짜 범위 조회 (백테스트용)
CREATE INDEX idx_st_news_date_range ON st_news_events(event_date);

COMMENT ON TABLE st_news_events IS 'AI 자동 분석된 뉴스/이슈 (Claude API 활용)';
COMMENT ON COLUMN st_news_events.category IS '뉴스 카테고리: earnings(실적), product(제품), regulation(규제), macro(거시경제), geopolitics(지정학)';
COMMENT ON COLUMN st_news_events.manual_sentiment IS 'AI 라벨링 감성: positive(긍정), negative(부정), neutral(중립)';
COMMENT ON COLUMN st_news_events.manual_impact IS 'AI 라벨링 영향도: high(높음), medium(중간), low(낮음)';
COMMENT ON COLUMN st_news_events.ai_reasoning IS 'Claude가 sentiment/impact를 판단한 근거 (디버깅 및 검증용). 예시: "실적 발표에서 예상치를 상회하는 영업이익을 기록하여 positive로 판단"';
COMMENT ON COLUMN st_news_events.ai_confidence IS 'AI 분석 신뢰도 (0.00-1.00). 0.9 이상: 매우 확실, 0.7-0.9: 높음, 0.5-0.7: 보통 (재검토 권장), 0.5 미만: 낮음 (백테스트 시 가중치 감소)';
COMMENT ON COLUMN st_news_events.ai_model IS '사용한 AI 모델명. 예시: claude-sonnet-4.5, claude-haiku-3.5. 모델 버전별 성능 비교 및 추적용';

-- ====================================================================

-- 5. 백테스트 예측 결과
-- 예상 레코드 수: 450개 (5종목 × 90일)
CREATE TABLE st_backtest_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES st_companies(id) ON DELETE CASCADE,
  prediction_date DATE NOT NULL,    -- 예측을 생성한 날짜

  -- 입력 점수 (분석 결과)
  financial_score INTEGER,          -- 재무 분석 점수 (0-100)
  news_score INTEGER,               -- 뉴스 분석 점수 (0-100)
  combined_score INTEGER,           -- 종합 점수 (0-100)

  -- 생성된 예측
  predicted_direction VARCHAR(20),  -- 'up', 'down', 'neutral'
  predicted_signal VARCHAR(20),     -- 'buy', 'sell', 'hold'
  confidence INTEGER,               -- 신뢰도 (0-100), combined_score와 동일하거나 조정됨

  -- 실제 결과 (백테스트 실행 시 계산)
  actual_return_1d DECIMAL(6,2),    -- 1일 후 수익률 (%)
  actual_return_3d DECIMAL(6,2),    -- 3일 후 수익률 (%)
  actual_return_7d DECIMAL(6,2),    -- 7일 후 수익률 (%)

  -- 정확도 판정
  direction_correct_1d BOOLEAN,     -- 1일 후 방향 예측 정확 여부
  direction_correct_3d BOOLEAN,     -- 3일 후 방향 예측 정확 여부
  direction_correct_7d BOOLEAN,     -- 7일 후 방향 예측 정확 여부

  -- 메타데이터
  created_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(company_id, prediction_date)
);

-- 인덱스: 종목별 예측 조회
CREATE INDEX idx_st_backtest_company_date ON st_backtest_predictions(company_id, prediction_date DESC);

-- 인덱스: 신호 타입별 분석
CREATE INDEX idx_st_backtest_signal ON st_backtest_predictions(predicted_signal);

-- 인덱스: 정확도 분석 (WHERE 절에 자주 사용)
CREATE INDEX idx_st_backtest_correct_3d ON st_backtest_predictions(direction_correct_3d)
WHERE direction_correct_3d IS NOT NULL;

-- 추가 인덱스: 뉴스 카테고리별 조회 최적화
CREATE INDEX idx_st_news_category ON st_news_events(category, event_date DESC);
COMMENT ON INDEX idx_st_news_category IS '뉴스 카테고리별 최신순 조회 최적화';

-- 추가 인덱스: 고신뢰도 뉴스 조회 최적화
CREATE INDEX idx_st_news_confidence ON st_news_events(ai_confidence DESC, event_date DESC)
WHERE ai_confidence IS NOT NULL;
COMMENT ON INDEX idx_st_news_confidence IS '고신뢰도 뉴스 우선 조회 최적화. 사용 예시: 백테스트 시 confidence >= 0.8인 뉴스만 사용, 알림 시스템에서 confidence >= 0.9인 뉴스만 전송';

-- 추가 인덱스: 낮은 신뢰도 뉴스 조회 (검증/개선용)
CREATE INDEX idx_st_news_low_confidence ON st_news_events(ai_confidence ASC, event_date DESC)
WHERE ai_confidence < 0.7;
COMMENT ON INDEX idx_st_news_low_confidence IS '낮은 신뢰도 뉴스 조회 (재검토 및 fine-tuning 데이터 수집용)';

-- 추가 인덱스: 백테스트 점수 범위 조회
CREATE INDEX idx_st_backtest_scores ON st_backtest_predictions(combined_score, prediction_date DESC);
COMMENT ON INDEX idx_st_backtest_scores IS '고신뢰도 예측 조회 최적화 (combined_score >= 75 OR <= 25)';

-- 추가 인덱스: 재무 지표별 조회
CREATE INDEX idx_st_financial_roe ON st_financial_snapshots(roe, quarter_date DESC)
WHERE roe IS NOT NULL;
COMMENT ON INDEX idx_st_financial_roe IS 'ROE 기준 종목 필터링 최적화';

COMMENT ON TABLE st_backtest_predictions IS '백테스트 예측 결과 및 검증';
COMMENT ON COLUMN st_backtest_predictions.combined_score IS '재무점수 × 0.6 + 뉴스점수 × 0.4';
COMMENT ON COLUMN st_backtest_predictions.actual_return_3d IS '3일 후 수익률, 주요 평가 지표';
COMMENT ON COLUMN st_backtest_predictions.direction_correct_3d IS '3일 방향 정확도, 목표: 55% 이상';

-- ====================================================================

-- 6. 유용한 뷰 (View)

-- 뷰 1: 종목별 백테스트 성과 요약
CREATE VIEW backtest_summary_by_company AS
SELECT
  c.name AS company_name,
  c.ticker,
  COUNT(*) AS total_predictions,

  -- 정확도
  ROUND(AVG(CASE WHEN b.direction_correct_1d THEN 1.0 ELSE 0.0 END) * 100, 1) AS accuracy_1d,
  ROUND(AVG(CASE WHEN b.direction_correct_3d THEN 1.0 ELSE 0.0 END) * 100, 1) AS accuracy_3d,
  ROUND(AVG(CASE WHEN b.direction_correct_7d THEN 1.0 ELSE 0.0 END) * 100, 1) AS accuracy_7d,

  -- 평균 수익률
  ROUND(AVG(b.actual_return_3d), 2) AS avg_return_3d,

  -- 신호 분포
  COUNT(CASE WHEN b.predicted_signal = 'buy' THEN 1 END) AS buy_signals,
  COUNT(CASE WHEN b.predicted_signal = 'sell' THEN 1 END) AS sell_signals,
  COUNT(CASE WHEN b.predicted_signal = 'hold' THEN 1 END) AS hold_signals
FROM
  st_backtest_predictions b
  JOIN st_companies c ON b.company_id = c.id
GROUP BY
  c.id, c.name, c.ticker
ORDER BY
  accuracy_3d DESC;

COMMENT ON VIEW backtest_summary_by_company IS '종목별 백테스트 성과 요약';

-- 뷰 2: 신호 타입별 성과
CREATE VIEW backtest_summary_by_signal AS
SELECT
  predicted_signal,
  COUNT(*) AS total_count,

  -- 정확도
  ROUND(AVG(CASE WHEN direction_correct_3d THEN 1.0 ELSE 0.0 END) * 100, 1) AS accuracy_3d,

  -- 수익률 통계
  ROUND(AVG(actual_return_3d), 2) AS avg_return_3d,
  ROUND(MIN(actual_return_3d), 2) AS min_return_3d,
  ROUND(MAX(actual_return_3d), 2) AS max_return_3d,
  ROUND(STDDEV(actual_return_3d), 2) AS stddev_return_3d,

  -- 승률 (양수 수익률 비율)
  ROUND(AVG(CASE WHEN actual_return_3d > 0 THEN 1.0 ELSE 0.0 END) * 100, 1) AS win_rate
FROM
  st_backtest_predictions
WHERE
  predicted_signal IS NOT NULL
GROUP BY
  predicted_signal
ORDER BY
  predicted_signal;

COMMENT ON VIEW backtest_summary_by_signal IS '신호 타입별 성과 분석';

-- ====================================================================

-- 7. 데이터 정합성 체크 함수

-- 함수: 특정 날짜에 사용 가능한 최신 재무 데이터 조회
CREATE OR REPLACE FUNCTION get_latest_financial_at_date(
  p_company_id UUID,
  p_date DATE
) RETURNS UUID AS $$
DECLARE
  v_financial_id UUID;
BEGIN
  -- p_date 이전 가장 최근 분기 데이터
  SELECT id INTO v_financial_id
  FROM st_financial_snapshots
  WHERE company_id = p_company_id
    AND quarter_date <= p_date
  ORDER BY quarter_date DESC
  LIMIT 1;

  RETURN v_financial_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_latest_financial_at_date IS '특정 날짜 시점에 사용 가능한 최신 재무 데이터 ID 반환';

-- ====================================================================

-- 8. 샘플 쿼리 (참고용)

-- 쿼리 1: 특정 종목의 최근 7일 뉴스
-- SELECT * FROM news_events
-- WHERE company_id = '...'
--   AND event_date BETWEEN '2025-10-15' AND '2025-10-22'
-- ORDER BY event_date DESC;

-- 쿼리 2: 고신뢰도 예측의 정확도
-- SELECT
--   COUNT(*) AS total,
--   AVG(CASE WHEN direction_correct_3d THEN 1.0 ELSE 0.0 END) * 100 AS accuracy
-- FROM backtest_predictions
-- WHERE combined_score >= 75 OR combined_score <= 25;

-- 쿼리 3: 매수 신호의 평균 수익률
-- SELECT
--   AVG(actual_return_3d) AS avg_return,
--   COUNT(*) AS signal_count
-- FROM backtest_predictions
-- WHERE predicted_signal = 'buy';

-- ====================================================================

-- 9. 제약조건 추가 (데이터 무결성 보장)

-- 주가 데이터 검증: 모든 가격은 양수여야 함
ALTER TABLE st_daily_prices ADD CONSTRAINT chk_prices_positive 
CHECK (open_price > 0 AND high_price > 0 AND low_price > 0 AND close_price > 0);
COMMENT ON CONSTRAINT chk_prices_positive ON st_daily_prices IS '주가 데이터는 양수만 허용';

-- 주가 논리 검증: 고가 >= 저가, 고가 >= 시가/종가, 저가 <= 시가/종가  
ALTER TABLE st_daily_prices ADD CONSTRAINT chk_prices_logic
CHECK (high_price >= low_price AND high_price >= open_price AND high_price >= close_price 
       AND low_price <= open_price AND low_price <= close_price);
COMMENT ON CONSTRAINT chk_prices_logic ON st_daily_prices IS '주가 논리적 일관성 검증 (고가>=저가 등)';

-- 재무비율 범위 검증
ALTER TABLE st_financial_snapshots ADD CONSTRAINT chk_margin_range 
CHECK (operating_margin >= -200 AND operating_margin <= 200 AND 
       net_margin >= -200 AND net_margin <= 200 AND
       roe >= -200 AND roe <= 200);
COMMENT ON CONSTRAINT chk_margin_range ON st_financial_snapshots IS '재무비율 합리적 범위 검증 (-200% ~ 200%)';

-- 백테스트 점수 범위 검증
ALTER TABLE st_backtest_predictions ADD CONSTRAINT chk_scores_range
CHECK (financial_score >= 0 AND financial_score <= 100 AND
       news_score >= 0 AND news_score <= 100 AND 
       combined_score >= 0 AND combined_score <= 100 AND
       confidence >= 0 AND confidence <= 100);
COMMENT ON CONSTRAINT chk_scores_range ON st_backtest_predictions IS '점수는 0-100 범위 내';

-- 수익률 합리적 범위 검증 (일일 변동폭 ±30% 제한)
ALTER TABLE st_backtest_predictions ADD CONSTRAINT chk_return_range
CHECK (actual_return_1d >= -30 AND actual_return_1d <= 30 AND
       actual_return_3d >= -50 AND actual_return_3d <= 50 AND
       actual_return_7d >= -70 AND actual_return_7d <= 70);
COMMENT ON CONSTRAINT chk_return_range ON st_backtest_predictions IS '수익률 합리적 범위 검증';

-- 뉴스 카테고리 값 제한
ALTER TABLE st_news_events ADD CONSTRAINT chk_news_category
CHECK (category IN ('earnings', 'product', 'regulation', 'macro', 'geopolitics'));
COMMENT ON CONSTRAINT chk_news_category ON st_news_events IS '뉴스 카테고리 값 제한';

-- 감성/영향도 값 제한
ALTER TABLE st_news_events ADD CONSTRAINT chk_sentiment_impact
CHECK (manual_sentiment IN ('positive', 'negative', 'neutral') AND
       manual_impact IN ('high', 'medium', 'low'));
COMMENT ON CONSTRAINT chk_sentiment_impact ON st_news_events IS '감성/영향도 값 제한';

-- AI 신뢰도 범위 검증
ALTER TABLE st_news_events ADD CONSTRAINT chk_ai_confidence_range
CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1));
COMMENT ON CONSTRAINT chk_ai_confidence_range ON st_news_events IS 'AI 신뢰도는 0.00-1.00 범위 내';

-- 예측 방향/신호 값 제한
ALTER TABLE st_backtest_predictions ADD CONSTRAINT chk_prediction_values
CHECK (predicted_direction IN ('up', 'down', 'neutral') AND
       predicted_signal IN ('buy', 'sell', 'hold'));
COMMENT ON CONSTRAINT chk_prediction_values ON st_backtest_predictions IS '예측 방향/신호 값 제한';

-- ====================================================================

-- 10. 성능 최적화 팁 (코멘트)

-- 성능 최적화 가이드:
-- 1. 대용량 데이터 시 st_daily_prices 테이블 월별 파티셔닝 고려
-- 2. 백테스트 결과 조회 시 인덱스 활용: WHERE combined_score >= 75
-- 3. 뉴스 분석 시 날짜 범위 제한: WHERE event_date BETWEEN ... 
-- 4. 재무 데이터 조회 시 get_latest_financial_at_date() 함수 활용
-- 5. 집계 쿼리는 미리 생성된 뷰 활용 권장

-- 데이터 타입 개선 고려사항:
-- - 주가 데이터: INTEGER → DECIMAL(10,2) 또는 BIGINT (정밀도 향상)
-- - 거래량: BIGINT → NUMERIC(15,0) (대용량 거래 대비)
-- - 수익률: DECIMAL(6,2) → DECIMAL(8,4) (정밀도 향상)

-- ====================================================================
-- 스키마 생성 완료 (v1.2 - AI 뉴스 분석 메타데이터 추가)
-- ====================================================================
-- 변경 이력:
-- v1.0: 초기 스키마 생성
-- v1.1: 제약조건 및 성능 최적화 추가
-- v1.2: st_news_events 테이블에 AI 분석 메타데이터 추가
--       - ai_reasoning, ai_confidence, ai_model 컬럼 추가
--       - AI 신뢰도 기반 인덱스 추가
--       - AI 신뢰도 범위 검증 제약조건 추가
-- ====================================================================

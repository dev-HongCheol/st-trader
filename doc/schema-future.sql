-- ====================================================================
-- 주식 트레이딩 시스템 - Future Phase 스키마 (향후 구현 예정)
-- ====================================================================
-- 목적: 뉴스 분석, 백테스팅 등 추후 개발할 기능들
-- 범위: st_news_events, st_backtest_predictions
-- ====================================================================

-- 4. 뉴스/이슈 (수동 큐레이션)
-- 예상 레코드 수: 75개 (5종목 × 15개 주요 이슈)
CREATE TABLE st_news_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES st_companies(id) ON DELETE CASCADE,
  event_date DATE NOT NULL,         -- 뉴스 발생일

  -- 뉴스 내용
  title TEXT NOT NULL,              -- 뉴스 제목
  summary TEXT,                     -- 뉴스 요약 (선택)
  source_url TEXT,                  -- 원문 URL

  -- 분류 (수동 입력)
  category VARCHAR(50),             -- 'earnings', 'product', 'regulation', 'macro', 'geopolitics'

  -- 수동 라벨링
  manual_sentiment VARCHAR(20),     -- 'positive', 'negative', 'neutral'
  manual_impact VARCHAR(20),        -- 'high', 'medium', 'low'

  -- 메타데이터
  created_at TIMESTAMP DEFAULT NOW()
);

-- 인덱스: 종목별 최근 뉴스 조회
CREATE INDEX idx_st_news_company_date ON st_news_events(company_id, event_date DESC);

-- 인덱스: 날짜 범위 조회 (백테스트용)
CREATE INDEX idx_st_news_date_range ON st_news_events(event_date);

-- 추가 인덱스: 뉴스 카테고리별 조회 최적화
CREATE INDEX idx_st_news_category ON st_news_events(category, event_date DESC);

COMMENT ON TABLE st_news_events IS '수동 큐레이션된 뉴스/이슈';
COMMENT ON COLUMN st_news_events.category IS '뉴스 카테고리: earnings(실적), product(제품), regulation(규제), macro(거시경제), geopolitics(지정학)';
COMMENT ON COLUMN st_news_events.manual_sentiment IS '수동 라벨링 감성: positive(긍정), negative(부정), neutral(중립)';
COMMENT ON COLUMN st_news_events.manual_impact IS '수동 라벨링 영향도: high(높음), medium(중간), low(낮음)';
COMMENT ON INDEX idx_st_news_category IS '뉴스 카테고리별 최신순 조회 최적화';

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

-- 추가 인덱스: 백테스트 점수 범위 조회
CREATE INDEX idx_st_backtest_scores ON st_backtest_predictions(combined_score, prediction_date DESC);

COMMENT ON TABLE st_backtest_predictions IS '백테스트 예측 결과 및 검증';
COMMENT ON COLUMN st_backtest_predictions.combined_score IS '재무점수 × 0.6 + 뉴스점수 × 0.4';
COMMENT ON COLUMN st_backtest_predictions.actual_return_3d IS '3일 후 수익률, 주요 평가 지표';
COMMENT ON COLUMN st_backtest_predictions.direction_correct_3d IS '3일 방향 정확도, 목표: 55% 이상';
COMMENT ON INDEX idx_st_backtest_scores IS '고신뢰도 예측 조회 최적화 (combined_score >= 75 OR <= 25)';

-- ====================================================================

-- 6. 유용한 뷰 (Future Phase용)

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

-- 8. 제약조건 (Future Phase)

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

-- 예측 방향/신호 값 제한
ALTER TABLE st_backtest_predictions ADD CONSTRAINT chk_prediction_values
CHECK (predicted_direction IN ('up', 'down', 'neutral') AND
       predicted_signal IN ('buy', 'sell', 'hold'));
COMMENT ON CONSTRAINT chk_prediction_values ON st_backtest_predictions IS '예측 방향/신호 값 제한';

-- ====================================================================
-- Future Phase 스키마 생성 완료 (뉴스 + 백테스팅)
-- ====================================================================
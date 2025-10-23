-- ====================================================================
-- 주식 트레이딩 시스템 - MVP 데이터베이스 스키마
-- ====================================================================
-- 목적: 백테스팅 기반 정확도 검증 시스템
-- 대상 기간: 2025-07-23 ~ 2025-10-22 (3개월)
-- 대상 종목: 5개 (삼성전자, SK하이닉스, NAVER, 카카오, 현대차)
-- ====================================================================

-- 1. 종목 정보
-- 5개 주요 종목만 관리
CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker VARCHAR(20) UNIQUE NOT NULL, -- 종목코드 예: '005930'
  name VARCHAR(100) NOT NULL,         -- 종목명 예: '삼성전자'
  market VARCHAR(20),                 -- 'KOSPI' or 'KOSDAQ'
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 초기 데이터 삽입
INSERT INTO companies (ticker, name, market) VALUES
('005930', '삼성전자', 'KOSPI'),
('000660', 'SK하이닉스', 'KOSPI'),
('035420', 'NAVER', 'KOSPI'),
('035720', '카카오', 'KOSPI'),
('005380', '현대차', 'KOSPI');

COMMENT ON TABLE companies IS '분석 대상 종목 정보';
COMMENT ON COLUMN companies.ticker IS '6자리 종목코드';

-- ====================================================================

-- 2. 일별 주가 데이터
-- 예상 레코드 수: 450개 (5종목 × 90일)
CREATE TABLE daily_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
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
CREATE INDEX idx_prices_company_date ON daily_prices(company_id, date DESC);

COMMENT ON TABLE daily_prices IS '일별 주가 데이터 (OHLCV)';
COMMENT ON COLUMN daily_prices.close_price IS '종가, 수익률 계산에 사용';

-- ====================================================================

-- 3. 재무 스냅샷 (분기별)
-- 예상 레코드 수: 10개 (5종목 × 2분기: 2025 2Q, 3Q)
CREATE TABLE financial_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
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
CREATE INDEX idx_financial_company_quarter ON financial_snapshots(company_id, quarter_date DESC);

COMMENT ON TABLE financial_snapshots IS '분기별 재무제표 스냅샷';
COMMENT ON COLUMN financial_snapshots.operating_margin IS '영업이익률 (%), 수익성 평가';
COMMENT ON COLUMN financial_snapshots.roe IS 'ROE (%), 자본 효율성 평가';

-- ====================================================================

-- 4. 뉴스/이슈 (수동 큐레이션)
-- 예상 레코드 수: 75개 (5종목 × 15개 주요 이슈)
CREATE TABLE news_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
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
CREATE INDEX idx_news_company_date ON news_events(company_id, event_date DESC);

-- 인덱스: 날짜 범위 조회 (백테스트용)
CREATE INDEX idx_news_date_range ON news_events(event_date);

COMMENT ON TABLE news_events IS '수동 큐레이션된 뉴스/이슈';
COMMENT ON COLUMN news_events.category IS '뉴스 카테고리: earnings(실적), product(제품), regulation(규제), macro(거시경제), geopolitics(지정학)';
COMMENT ON COLUMN news_events.manual_sentiment IS '수동 라벨링 감성: positive(긍정), negative(부정), neutral(중립)';
COMMENT ON COLUMN news_events.manual_impact IS '수동 라벨링 영향도: high(높음), medium(중간), low(낮음)';

-- ====================================================================

-- 5. 백테스트 예측 결과
-- 예상 레코드 수: 450개 (5종목 × 90일)
CREATE TABLE backtest_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
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
CREATE INDEX idx_backtest_company_date ON backtest_predictions(company_id, prediction_date DESC);

-- 인덱스: 신호 타입별 분석
CREATE INDEX idx_backtest_signal ON backtest_predictions(predicted_signal);

-- 인덱스: 정확도 분석 (WHERE 절에 자주 사용)
CREATE INDEX idx_backtest_correct_3d ON backtest_predictions(direction_correct_3d)
WHERE direction_correct_3d IS NOT NULL;

COMMENT ON TABLE backtest_predictions IS '백테스트 예측 결과 및 검증';
COMMENT ON COLUMN backtest_predictions.combined_score IS '재무점수 × 0.6 + 뉴스점수 × 0.4';
COMMENT ON COLUMN backtest_predictions.actual_return_3d IS '3일 후 수익률, 주요 평가 지표';
COMMENT ON COLUMN backtest_predictions.direction_correct_3d IS '3일 방향 정확도, 목표: 55% 이상';

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
  backtest_predictions b
  JOIN companies c ON b.company_id = c.id
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
  backtest_predictions
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
  FROM financial_snapshots
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
-- 스키마 생성 완료
-- ====================================================================

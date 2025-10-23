-- ====================================================================
-- 주식 트레이딩 시스템 - 데이터베이스 초기화 스크립트
-- ====================================================================
-- 목적: 개발/테스트 시 데이터베이스를 깨끗한 상태로 초기화
-- 주의: 운영 환경에서는 절대 실행하지 마세요!
-- ====================================================================

-- ⚠️ 경고: 이 스크립트는 모든 st_ 테이블의 데이터를 삭제합니다!
-- 실행 전 백업을 확인하세요.

-- ====================================================================
-- 1. 모든 데이터 삭제 (CASCADE로 연관 데이터도 함께 삭제)
-- ====================================================================

-- 순서 중요: 외래키 참조 관계를 고려하여 역순으로 삭제
DELETE FROM st_backtest_predictions;
DELETE FROM st_news_events;
DELETE FROM st_financial_snapshots;
DELETE FROM st_daily_prices;
DELETE FROM st_companies;

-- ====================================================================
-- 2. 시퀀스/ID 초기화 (UUID 사용하므로 해당 없음)
-- ====================================================================

-- UUID 사용으로 별도 시퀀스 초기화 불필요

-- ====================================================================
-- 3. 기본 종목 데이터 재삽입
-- ====================================================================

-- 5개 기본 종목 재삽입
INSERT INTO st_companies (ticker, name, market) VALUES
('005930', '삼성전자', 'KOSPI'),
('000660', 'SK하이닉스', 'KOSPI'),
('035420', 'NAVER', 'KOSPI'),
('035720', '카카오', 'KOSPI'),
('005380', '현대차', 'KOSPI');

-- ====================================================================
-- 4. 초기화 완료 메시지
-- ====================================================================

-- 초기화 결과 확인
SELECT 
  'st_companies' as table_name, 
  COUNT(*) as record_count 
FROM st_companies
UNION ALL
SELECT 
  'st_daily_prices' as table_name, 
  COUNT(*) as record_count 
FROM st_daily_prices
UNION ALL
SELECT 
  'st_financial_snapshots' as table_name, 
  COUNT(*) as record_count 
FROM st_financial_snapshots
UNION ALL
SELECT 
  'st_news_events' as table_name, 
  COUNT(*) as record_count 
FROM st_news_events
UNION ALL
SELECT 
  'st_backtest_predictions' as table_name, 
  COUNT(*) as record_count 
FROM st_backtest_predictions
ORDER BY table_name;

-- ====================================================================

-- 선택적 초기화 스크립트들 (주석 해제해서 사용)

-- ⚠️ 주의: 아래 스크립트들은 필요시에만 실행하세요!

-- ====================================================================
-- 5. 특정 테이블만 초기화 (선택적 실행)
-- ====================================================================

-- 주가 데이터만 삭제
-- DELETE FROM st_daily_prices;

-- 재무 데이터만 삭제  
-- DELETE FROM st_financial_snapshots;

-- 뉴스 데이터만 삭제
-- DELETE FROM st_news_events;

-- 백테스트 결과만 삭제
-- DELETE FROM st_backtest_predictions;

-- ====================================================================
-- 6. 완전 초기화 (테이블 구조도 삭제) - 매우 위험!
-- ====================================================================

-- ⚠️ 극도로 주의: 테이블 구조까지 완전히 삭제
-- 개발 초기 스키마 변경 시에만 사용
-- 실제 데이터가 있는 환경에서는 절대 실행하지 마세요!

/*
-- 뷰 삭제
DROP VIEW IF EXISTS backtest_summary_by_signal CASCADE;
DROP VIEW IF EXISTS backtest_summary_by_company CASCADE;
DROP VIEW IF EXISTS daily_returns CASCADE;
DROP VIEW IF EXISTS latest_financial_summary CASCADE;

-- 함수 삭제
DROP FUNCTION IF EXISTS get_latest_financial_at_date(UUID, DATE) CASCADE;

-- 테이블 삭제 (역순)
DROP TABLE IF EXISTS st_backtest_predictions CASCADE;
DROP TABLE IF EXISTS st_news_events CASCADE;
DROP TABLE IF EXISTS st_financial_snapshots CASCADE;
DROP TABLE IF EXISTS st_daily_prices CASCADE;
DROP TABLE IF EXISTS st_companies CASCADE;

-- 스키마 재생성이 필요한 경우
-- \i doc/schema-phase1.sql
-- \i doc/schema-future.sql (필요시)
*/

-- ====================================================================
-- 7. 테스트 데이터 삽입 (개발용)
-- ====================================================================

-- 샘플 주가 데이터 삽입 (개발/테스트용)
/*
-- 삼성전자 sample 데이터 (최근 5일)
WITH company_ids AS (
  SELECT id as company_id FROM st_companies WHERE ticker = '005930'
)
INSERT INTO st_daily_prices (company_id, date, open_price, high_price, low_price, close_price, volume)
SELECT 
  company_id,
  CURRENT_DATE - interval '4 days' + (i || ' days')::interval,
  70000 + (random() * 2000 - 1000)::integer,  -- 시가
  71000 + (random() * 2000 - 1000)::integer,  -- 고가  
  69000 + (random() * 2000 - 1000)::integer,  -- 저가
  70000 + (random() * 2000 - 1000)::integer,  -- 종가
  (random() * 1000000 + 500000)::bigint       -- 거래량
FROM company_ids, generate_series(0, 4) as i;
*/

-- ====================================================================

SELECT '🎉 데이터베이스 초기화 완료!' as message;
SELECT '✅ 기본 종목 5개가 다시 삽입되었습니다.' as status;
SELECT '📝 Python 스크립트를 실행하여 주가/재무 데이터를 수집하세요.' as next_step;

-- ====================================================================
-- 초기화 스크립트 완료
-- ====================================================================
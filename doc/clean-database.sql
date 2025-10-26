-- ====================================================================
-- 주식 트레이딩 시스템 - 데이터베이스 완전 클린업 스크립트
-- ====================================================================
-- 목적: 모든 테이블, 뷰, 함수, 인덱스를 삭제하여 깨끗한 상태로 초기화
-- 주의: ⚠️ 이 스크립트는 매우 위험합니다!
--      개발 초기 스키마 변경 시에만 사용하세요!
--      운영 환경이나 실제 데이터가 있는 환경에서는 절대 실행하지 마세요!
-- ====================================================================

-- ====================================================================
-- 실행 전 확인 사항
-- ====================================================================
-- 1. 백업이 있는지 확인
-- 2. 현재 환경이 개발 환경인지 확인
-- 3. 정말 모든 것을 삭제해도 되는지 확인
--
-- 실행 후:
-- - 모든 st_ 테이블 삭제
-- - 모든 뷰 삭제
-- - 모든 함수 삭제
-- - 모든 인덱스 삭제 (테이블과 함께 자동 삭제)
-- - 모든 제약조건 삭제 (테이블과 함께 자동 삭제)
-- ====================================================================

\echo '⚠️  WARNING: This will DELETE ALL stock trading system objects!'
\echo '⚠️  Press Ctrl+C to cancel, or Enter to continue...'
\prompt 'Type "DELETE EVERYTHING" to confirm: ' confirmation

-- ====================================================================
-- 1. 뷰 삭제 (먼저 삭제해야 테이블 삭제 가능)
-- ====================================================================

\echo '🗑️  Dropping views...'

DROP VIEW IF EXISTS backtest_summary_by_signal CASCADE;
DROP VIEW IF EXISTS backtest_summary_by_company CASCADE;

-- 혹시 추가로 만든 뷰가 있다면 여기에 추가
-- DROP VIEW IF EXISTS daily_returns CASCADE;
-- DROP VIEW IF EXISTS latest_financial_summary CASCADE;

\echo '✅ Views dropped.'

-- ====================================================================
-- 2. 함수 삭제
-- ====================================================================

\echo '🗑️  Dropping functions...'

DROP FUNCTION IF EXISTS get_latest_financial_at_date(UUID, DATE) CASCADE;

-- 혹시 추가로 만든 함수가 있다면 여기에 추가
-- DROP FUNCTION IF EXISTS calculate_returns(UUID, DATE, DATE) CASCADE;

\echo '✅ Functions dropped.'

-- ====================================================================
-- 3. 테이블 삭제 (역순 - 외래키 참조 관계 고려)
-- ====================================================================

\echo '🗑️  Dropping tables...'

-- 의존성이 있는 테이블부터 삭제 (자식 → 부모 순서)
DROP TABLE IF EXISTS st_backtest_predictions CASCADE;
DROP TABLE IF EXISTS st_news_events CASCADE;
DROP TABLE IF EXISTS st_financial_snapshots CASCADE;
DROP TABLE IF EXISTS st_daily_prices CASCADE;
DROP TABLE IF EXISTS st_companies CASCADE;

\echo '✅ Tables dropped (including all indexes and constraints).'

-- ====================================================================
-- 4. 삭제 확인
-- ====================================================================

\echo ''
\echo '📊 Checking remaining st_ objects...'

-- 남은 테이블 확인
SELECT
  'Tables' as object_type,
  COUNT(*) as remaining_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE 'st_%'
UNION ALL
-- 남은 뷰 확인
SELECT
  'Views' as object_type,
  COUNT(*) as remaining_count
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'st_%' OR table_name LIKE 'backtest_%'
UNION ALL
-- 남은 함수 확인
SELECT
  'Functions' as object_type,
  COUNT(*) as remaining_count
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE 'st_%' OR routine_name LIKE 'get_%';

-- ====================================================================
-- 5. 완료 메시지
-- ====================================================================

\echo ''
\echo '🎉 Database cleanup completed!'
\echo ''
\echo '📝 Next steps:'
\echo '  1. Run schema.sql to recreate tables:'
\echo '     psql -h supa.devhong.cc -U postgres -d postgres -f doc/schema.sql'
\echo ''
\echo '  2. Or run the schema creation in Supabase dashboard'
\echo ''
\echo '✅ All stock trading system objects have been removed.'
\echo ''

-- ====================================================================
-- 선택적 실행: 특정 객체만 삭제
-- ====================================================================

-- 아래 스크립트들은 필요시 주석 해제하여 사용

-- 뷰만 삭제
-- DROP VIEW IF EXISTS backtest_summary_by_signal CASCADE;
-- DROP VIEW IF EXISTS backtest_summary_by_company CASCADE;

-- 함수만 삭제
-- DROP FUNCTION IF EXISTS get_latest_financial_at_date(UUID, DATE) CASCADE;

-- 특정 테이블만 삭제
-- DROP TABLE IF EXISTS st_backtest_predictions CASCADE;
-- DROP TABLE IF EXISTS st_news_events CASCADE;
-- DROP TABLE IF EXISTS st_financial_snapshots CASCADE;
-- DROP TABLE IF EXISTS st_daily_prices CASCADE;
-- -- st_companies는 마지막에 삭제 (다른 테이블들이 참조)

-- ====================================================================
-- 정리 완료
-- ====================================================================

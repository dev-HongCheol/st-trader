-- ====================================================================
-- 뉴스 데이터 AI 분석 메타데이터 - 마이그레이션 스크립트
-- ====================================================================
-- 목적: 기존 st_news_events 테이블에 AI 분석 메타데이터 컬럼 추가
-- 용도: Claude API를 통한 뉴스 분석 결과의 신뢰도 및 근거를 저장
-- 작성일: 2025-10-24
-- 참고: doc/news-collection-strategy.md
--
-- 주의사항:
-- - 이 파일은 MIGRATION 파일입니다 (기존 DB에 실행)
-- - 신규 DB 생성 시에는 doc/schema.sql을 직접 실행하세요
-- - ALTER TABLE 사용으로 기존 데이터를 보존하면서 컬럼 추가
-- - 여러 번 실행해도 안전 (IF NOT EXISTS 사용)
-- ====================================================================

-- AI 분석 메타데이터 컬럼 추가
ALTER TABLE st_news_events
  ADD COLUMN IF NOT EXISTS ai_reasoning TEXT,
  ADD COLUMN IF NOT EXISTS ai_confidence DECIMAL(3,2),
  ADD COLUMN IF NOT EXISTS ai_model VARCHAR(50);

-- 제약조건 추가 (confidence 범위 검증)
-- 이미 존재하면 스킵
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_ai_confidence_range'
  ) THEN
    ALTER TABLE st_news_events
      ADD CONSTRAINT chk_ai_confidence_range
      CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1));
  END IF;
END $$;

-- 컬럼 설명
COMMENT ON COLUMN st_news_events.ai_reasoning IS
  'Claude가 sentiment/impact를 판단한 근거 (디버깅 및 검증용)
  예시: "실적 발표에서 예상치를 상회하는 영업이익을 기록하여 positive로 판단"';

COMMENT ON COLUMN st_news_events.ai_confidence IS
  'AI 분석 신뢰도 (0.00-1.00)
  - 0.9 이상: 매우 확실한 판단
  - 0.7-0.9: 높은 신뢰도
  - 0.5-0.7: 보통 신뢰도 (재검토 권장)
  - 0.5 미만: 낮은 신뢰도 (백테스트 시 가중치 감소)';

COMMENT ON COLUMN st_news_events.ai_model IS
  '사용한 AI 모델명
  예시: claude-sonnet-4.5, claude-haiku-3.5, claude-opus-4
  모델 버전별 성능 비교 및 추적용';

-- 인덱스 추가 (고신뢰도 뉴스 조회 최적화)
CREATE INDEX IF NOT EXISTS idx_st_news_confidence
  ON st_news_events(ai_confidence DESC, event_date DESC)
  WHERE ai_confidence IS NOT NULL;

COMMENT ON INDEX idx_st_news_confidence IS
  '고신뢰도 뉴스 우선 조회 최적화
  사용 예시:
  - 백테스트 시 confidence >= 0.8인 뉴스만 사용
  - 알림 시스템에서 confidence >= 0.9인 뉴스만 전송';

-- 낮은 신뢰도 뉴스 조회용 인덱스 (검증/개선용)
CREATE INDEX IF NOT EXISTS idx_st_news_low_confidence
  ON st_news_events(ai_confidence ASC, event_date DESC)
  WHERE ai_confidence < 0.7;

COMMENT ON INDEX idx_st_news_low_confidence IS
  '낮은 신뢰도 뉴스 조회 (재검토 및 fine-tuning 데이터 수집용)';

-- ====================================================================
-- 검증 쿼리
-- ====================================================================

-- 1. 컬럼 추가 확인
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'st_news_events'
      AND column_name IN ('ai_reasoning', 'ai_confidence', 'ai_model')
  ) THEN
    RAISE NOTICE '✅ AI 메타데이터 컬럼 추가 완료';
  ELSE
    RAISE WARNING '❌ 컬럼 추가 실패';
  END IF;
END $$;

-- 2. 인덱스 생성 확인
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE tablename = 'st_news_events'
      AND indexname IN ('idx_st_news_confidence', 'idx_st_news_low_confidence')
  ) THEN
    RAISE NOTICE '✅ AI 신뢰도 인덱스 생성 완료';
  ELSE
    RAISE WARNING '❌ 인덱스 생성 실패';
  END IF;
END $$;

-- ====================================================================
-- 유용한 쿼리 모음
-- ====================================================================

-- Q1. confidence 낮은 뉴스 확인 (재검토 대상)
-- SELECT
--   c.name,
--   n.event_date,
--   n.title,
--   n.manual_sentiment,
--   n.manual_impact,
--   n.ai_confidence,
--   LEFT(n.ai_reasoning, 80) as reasoning_preview
-- FROM st_news_events n
-- JOIN st_companies c ON n.company_id = c.id
-- WHERE n.ai_confidence < 0.7
-- ORDER BY n.ai_confidence ASC, n.event_date DESC
-- LIMIT 20;

-- Q2. 종목별 평균 confidence
-- SELECT
--   c.name,
--   COUNT(*) as news_count,
--   AVG(n.ai_confidence)::DECIMAL(3,2) as avg_confidence,
--   MIN(n.ai_confidence)::DECIMAL(3,2) as min_confidence,
--   MAX(n.ai_confidence)::DECIMAL(3,2) as max_confidence
-- FROM st_news_events n
-- JOIN st_companies c ON n.company_id = c.id
-- WHERE n.ai_confidence IS NOT NULL
-- GROUP BY c.name
-- ORDER BY avg_confidence DESC;

-- Q3. 카테고리별 sentiment 분포 및 평균 confidence
-- SELECT
--   category,
--   manual_sentiment,
--   COUNT(*) as count,
--   AVG(ai_confidence)::DECIMAL(3,2) as avg_confidence
-- FROM st_news_events
-- WHERE ai_confidence IS NOT NULL
-- GROUP BY category, manual_sentiment
-- ORDER BY category, manual_sentiment;

-- Q4. 모델별 성능 비교 (여러 모델 사용 시)
-- SELECT
--   ai_model,
--   COUNT(*) as analysis_count,
--   AVG(ai_confidence)::DECIMAL(3,2) as avg_confidence,
--   COUNT(*) FILTER (WHERE ai_confidence >= 0.8) as high_confidence_count
-- FROM st_news_events
-- WHERE ai_model IS NOT NULL
-- GROUP BY ai_model
-- ORDER BY avg_confidence DESC;

-- Q5. 고신뢰도 + 고영향도 뉴스 (알림 대상)
-- SELECT
--   c.name,
--   n.event_date,
--   n.title,
--   n.manual_sentiment,
--   n.manual_impact,
--   n.ai_confidence,
--   n.source_url
-- FROM st_news_events n
-- JOIN st_companies c ON n.company_id = c.id
-- WHERE n.ai_confidence >= 0.9
--   AND n.manual_impact = 'high'
-- ORDER BY n.event_date DESC, n.ai_confidence DESC;

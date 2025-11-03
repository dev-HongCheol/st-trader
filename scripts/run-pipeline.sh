#!/bin/bash

# 주식 트레이딩 시스템 - 전체 데이터 파이프라인 실행 스크립트
# 실행: ./scripts/run-pipeline.sh

set -e  # 에러 발생 시 즉시 중단

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 디렉토리 생성
mkdir -p logs

# 로그 파일 경로
LOG_FILE="logs/pipeline_$(date +%Y%m%d_%H%M%S).log"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  주식 데이터 파이프라인 시작${NC}"
echo -e "${BLUE}  시작 시간: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 로그 함수
log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

# 에러 핸들러
handle_error() {
  log "${RED}❌ 에러 발생: $1${NC}"
  log "${RED}파이프라인 중단됨${NC}"
  exit 1
}

# ===========================================
# 1단계: 주가/재무 데이터 수집 (Python)
# ===========================================
log "${GREEN}📊 [1/6] 주가/재무 데이터 수집 시작...${NC}"
python scripts/1-data-collection/collect_stock_prices.py 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  handle_error "주가 데이터 수집 실패"
fi

log "${GREEN}✅ 주가/재무 데이터 수집 완료${NC}"
echo ""

# ===========================================
# 2단계: 네이버 API 메타데이터 수집 (TypeScript)
# ===========================================
log "${GREEN}📰 [2/6] 네이버 API 메타데이터 수집 시작... (예상 시간: 1-2분)${NC}"
pnpm exec tsx scripts/2-news-pipeline/1-fetch_news_metadata.ts 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  handle_error "네이버 API 메타데이터 수집 실패"
fi

log "${GREEN}✅ 메타데이터 수집 완료 → data/news_metadata.json${NC}"
echo ""

# ===========================================
# 3단계: Haiku 제목 기반 필터링 (TypeScript)
# ===========================================
log "${GREEN}🤖 [3/6] Haiku 제목 필터링 시작... (예상 비용: \$0.3)${NC}"
pnpm exec tsx scripts/2-news-pipeline/2-filter_news_by_title.ts 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  handle_error "Haiku 제목 필터링 실패"
fi

log "${GREEN}✅ 제목 필터링 완료 → data/filtered_metadata.json${NC}"
echo ""

# ===========================================
# 4단계: Playwright 본문 크롤링 (TypeScript)
# ===========================================
log "${GREEN}📄 [4/6] 필터링된 뉴스 본문 크롤링 시작... (예상 시간: 3-5분)${NC}"
pnpm exec tsx scripts/2-news-pipeline/3-crawl_filtered_news.ts 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  handle_error "본문 크롤링 실패"
fi

log "${GREEN}✅ 본문 크롤링 완료 → data/crawled_news.json${NC}"
echo ""

# ===========================================
# 5단계: Sonnet 4.5 심층 분석 (TypeScript)
# ===========================================
log "${GREEN}🧠 [5/6] Sonnet 4.5 심층 분석 시작... (예상 비용: \$1.7)${NC}"
pnpm exec tsx scripts/2-news-pipeline/4-analyze_news_sentiment.ts 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  handle_error "AI 심층 분석 실패"
fi

log "${GREEN}✅ AI 심층 분석 완료 → data/analyzed_news.json${NC}"
echo ""

# ===========================================
# 6단계: DB 저장 (TypeScript)
# ===========================================
log "${GREEN}💾 [6/6] 데이터베이스 저장 시작...${NC}"
pnpm exec tsx scripts/2-news-pipeline/5-import_analyzed_news.ts 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
  handle_error "데이터베이스 저장 실패"
fi

log "${GREEN}✅ 데이터베이스 저장 완료${NC}"
echo ""

# ===========================================
# 완료 메시지
# ===========================================
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
log "${BLUE}========================================${NC}"
log "${BLUE}  🎉 전체 파이프라인 완료!${NC}"
log "${BLUE}  종료 시간: $END_TIME${NC}"
log "${BLUE}  로그 파일: $LOG_FILE${NC}"
log "${BLUE}========================================${NC}"

# 결과 요약 (선택사항 - DB 조회)
log ""
log "${YELLOW}📋 데이터 검증 (선택사항):${NC}"
log "${YELLOW}psql -h supa.devhong.cc -U postgres -d postgres -c \"${NC}"
log "${YELLOW}  SELECT c.name, COUNT(*) as news_count, AVG(n.ai_confidence)::DECIMAL(3,2) as avg_confidence${NC}"
log "${YELLOW}  FROM st_news_events n${NC}"
log "${YELLOW}  JOIN st_companies c ON n.company_id = c.id${NC}"
log "${YELLOW}  GROUP BY c.name ORDER BY c.name;${NC}"
log "${YELLOW}\"${NC}"

import FinanceDataReader as fdr
import pandas as pd
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import os
from supabase import create_client, Client
from dotenv import load_dotenv

# 환경변수 로드
load_dotenv()

# Supabase 연결 설정
url: str = os.environ.get("NEXT_PUBLIC_SUPABASE_URL") or ""
key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""

if not url or not key:
    print("❌ 환경변수 설정 필요: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY")
    exit(1)

supabase: Client = create_client(url, key)
print(f"✅ Supabase 연결 성공: {url}")

# 종목 검색 사이트 : https://data.krx.co.kr/contents/MDC/MAIN/main/index.cmd
# 대상 종목 설정 (preparation.md에 명시된 5개 종목)
target_stocks = {
    '005930': '삼성전자',
    '000660': 'SK하이닉스', 
    '035420': 'NAVER',
    '035720': '카카오',
    '005380': '현대차'
}

# 검색 기간 설정 (2025-07-23 ~ 2025-10-22)
end_date = datetime.today()
start_date = end_date - relativedelta(months=3)
print(f"주가 데이터 수집 시작: {start_date} ~ {end_date}")

""" 
TODO:
    - 수집된 데이터 항목 표시.
    - 해당 스크립트 웹에서 실행.
"""

# 종목 ID 매핑을 위한 함수
def get_company_id(ticker: str) -> str:
    """ticker로 company_id를 조회"""
    try:
        result = supabase.table('st_companies').select('id').eq('ticker', ticker).execute()
        if result.data:
            return result.data[0]['id']
        else:
            print(f"❌ {ticker} 종목을 st_companies 테이블에서 찾을 수 없습니다.")
            return ""
    except Exception as e:
        print(f"❌ {ticker} company_id 조회 실패: {e}")
        return ""

# 주가 데이터 저장 함수
def save_daily_prices(company_id: str, ticker: str, df: pd.DataFrame) -> int:
    """주가 데이터를 st_daily_prices 테이블에 저장"""
    if df.empty or not company_id:
        return 0
    
    saved_count = 0
    for date, row in df.iterrows():
        try:
            # 데이터 준비
            data = {
                'company_id': company_id,
                'date': date.strftime('%Y-%m-%d'),
                'open_price': int(row['Open']),
                'high_price': int(row['High']),
                'low_price': int(row['Low']),
                'close_price': int(row['Close']),
                'volume': int(row['Volume']) if pd.notna(row['Volume']) else None
            }
            
            # UPSERT (있으면 업데이트, 없으면 삽입)
            result = supabase.table('st_daily_prices').upsert(
                data, 
                on_conflict='company_id,date'
            ).execute()
            
            saved_count += 1
            
        except Exception as e:
            print(f"  ❌ {date.strftime('%Y-%m-%d')} 주가 저장 실패: {e}")
    
    return saved_count

# 재무제표 데이터 저장 함수
def save_financial_data(company_id: str, ticker: str, fs: pd.DataFrame) -> int:
    """재무제표 데이터를 st_financial_snapshots 테이블에 저장"""
    if fs.empty or not company_id:
        return 0
    
    saved_count = 0
    for quarter_date, row in fs.iterrows():
        try:
            # 분기 마지막 날로 변환 (2024-06 → 2024-06-30)
            quarter_end = pd.to_datetime(quarter_date).replace(day=1) + pd.offsets.QuarterEnd(0)
            
            # 데이터 준비 (한글 컬럼명 매핑)
            data = {
                'company_id': company_id,
                'quarter_date': quarter_end.strftime('%Y-%m-%d'),
                'revenue': int(row['매출액']) if pd.notna(row['매출액']) else None,
                'operating_income': int(row['영업이익']) if pd.notna(row['영업이익']) else None,
                'net_income': int(row['당기순이익']) if pd.notna(row['당기순이익']) else None,
                'total_assets': int(row['자산총계']) if pd.notna(row['자산총계']) else None,
                'total_equity': int(row['자본총계']) if pd.notna(row['자본총계']) else None,
                'operating_margin': float(row['영업이익률']) if pd.notna(row['영업이익률']) else None,
                'net_margin': float(row['순이익률']) if pd.notna(row['순이익률']) else None,
                'roe': float(row['ROE(%)']) if pd.notna(row['ROE(%)']) else None
            }
            
            # UPSERT
            result = supabase.table('st_financial_snapshots').upsert(
                data,
                on_conflict='company_id,quarter_date'
            ).execute()
            
            saved_count += 1
            
        except Exception as e:
            print(f"  ❌ {quarter_date} 재무제표 저장 실패: {e}")
    
    return saved_count

# 각 종목별 주가 데이터 수집 및 저장
for ticker, name in target_stocks.items():
    try:
        print(f"\n✓ {name}({ticker})")
        
        # company_id 조회
        company_id = get_company_id(ticker)
        if not company_id:
            print(f"  ⚠️ {name} company_id 조회 실패, 건너뜀")
            continue
        
        # 주가 데이터 수집 (OHLCV)
        df = fdr.DataReader(ticker, start_date, end_date)
        
        if not df.empty:
            print(f"  최신 종가: {df['Close'].iloc[-1]:,.0f}원")
            
            # 주가 데이터 저장
            saved_prices = save_daily_prices(company_id, ticker, df)
            print(f"  💾 주가 데이터: {saved_prices}/{len(df)}건 저장")
        else:
            print(f"  ❌ {name}: 주가 데이터 없음")
            
        # 재무제표 데이터 수집 (분기 K-IFRS 연결 - 전체 기간)
        try:
            fs = fdr.SnapDataReader(f'NAVER/FINSTATE-2Q/{ticker}')
            if not fs.empty:
                print(f"  📊 재무제표: {fs.shape[0]}분기 × {fs.shape[1]}항목")
                
                # 재무제표 데이터 저장
                saved_financials = save_financial_data(company_id, ticker, fs)
                print(f"  💾 재무제표: {saved_financials}/{len(fs)}건 저장")
            else:
                print(f"  ❌ {name} 재무제표: 데이터 없음")
        except Exception as fs_error:
            print(f"  ❌ {name} 재무제표: 수집 실패 ({str(fs_error)})")
            
    except Exception as e:
        print(f"❌ {name} 전체 처리 실패: {str(e)}")

print("\n🎉 데이터 수집 및 저장 완료!")
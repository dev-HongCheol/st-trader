export type Config = {
  /** 데이터 검색 기간(월) */
  dataCollectionMonths: number;
  /** 설명 */
  description: string;
};

export type Stock = {
  ticker: string;
  name: string;
  sector: string;
};

export type ConfigData = {
  config: Config;
  Stocks: Stock[];
};

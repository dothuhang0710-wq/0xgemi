//=========================== PART 1/4 ===============================
//| SR_ATR_Telegram_MultiTF_MAX5_MultiTrade.mq5                       |
//| UPDATED: Trend/Range/Squeeze Regime + Sweep v2 confirm (delay)     |
//| - Multi-symbol, Multi-TF                                          |
//| - SR zones (pivot clustering + ATR width cap)                      |
//| - 3-entry ladder (top/mid/bot) + MinEntrySpacingPoints             |
//| - Sweep v2: sweep candle -> store candidate -> confirm next candle  |
//| - Trend filter: avoid counter-trend "trade ngu"                    |
//| - Risk by OrderCalcProfit (digits + USC + metals safe)             |
//| - News filter, Wick confirm, RR filter                             |
//| - TP milestone: TP1 -> Partial close + BE + RR trailing            |
//=====================================================================

#property strict
#property icon "\\Images\\logo.ico"
#property description "The 0xGemi community's exclusive Forex bot\n"
#property description "Channel: https://t.me/Gemicrypto | Official contact (DM only): @Kan_0xGemi\n"
#property description "NOTICE: KAN / 0XGEMI NEVER SENDS FIRST MESSAGE. BE CAREFUL WITH IMPERSONATORS AND SCAMMERS.\n"
#property description "Edited by Mochi | Refactored by Senior Dev\n"

#include <Trade/Trade.mqh>
CTrade trade;

//==================================================================
// ENUMS
//==================================================================
enum ENUM_ONOFF { OFF=0, ON=1 };
enum DirType   { DIR_LONG=0, DIR_SHORT=1 };
enum BoxType   { BOX_SUPPORT=0, BOX_RESISTANCE=1 };

enum MarketRegime
{
   REG_UNKNOWN=0,
   REG_TREND_UP,
   REG_TREND_DOWN,
   REG_RANGE,
   REG_SQUEEZE
};

//==================================================================
// SYMBOL ENUM (CLICK)
//==================================================================
enum ENUM_SYMBOL
{
   NONE = 0,
   XAUUSDm,
   XAGUSDm,
   EURUSDm,
   GBPUSDm,
   USDJPYm,
   BTCUSDm,
   ETHUSDm
};

enum ZoneRole
{
   ROLE_UNKNOWN=0,
   ROLE_LIQUIDITY,
   ROLE_DISTRIBUTION,
   ROLE_FLIP
};


//==================================================================
// INPUTS
//==================================================================
// Symbols
input ENUM_SYMBOL Symbol1 = XAUUSDm;
input ENUM_SYMBOL Symbol2 = XAGUSDm;
input ENUM_SYMBOL Symbol3 = EURUSDm;
input ENUM_SYMBOL Symbol4 = NONE;
input ENUM_SYMBOL Symbol5 = NONE;
input string SymbolSuffix = "c";   // XAUUSDc, XAGUSDc, EURUSDc ...

// Timeframes
input ENUM_ONOFF TF_M5  = ON;
input ENUM_ONOFF TF_M15 = ON;
input ENUM_ONOFF TF_M30 = ON;
input ENUM_ONOFF TF_H1  = ON;
input ENUM_ONOFF TF_H4  = OFF;
input ENUM_ONOFF TF_H12 = OFF;

input group "=== SIGNAL SCORE (QUALITY GATE) ==="
input ENUM_ONOFF Use_Score_Filter = ON;
input int    MinSignalScore = 65;
input int    Score_RSI_Weight = 35;
input int    Score_BB_Weight  = 35;
input int    Score_SR_Weight  = 30;
input int    Score_Wick_Bonus = 12;     // NEW: nến reject đẹp +12 điểm (tăng chất, không bóp signal)
input int MinScore_M5  = 58;
input int MinScore_M15 = 62;
input int MinScore_M30 = 65;
input int MinScore_H1  = 68;
input int MinScore_Other = 65;


// Expire (minutes)
input int Expire_M5_Min  = 10;
input int Expire_M15_Min = 30;
input int Expire_M30_Min = 90;
input int Expire_H1_Min  = 180;
input int Expire_H4_Min  = 720;

// Scan
input int    ScanIntervalSeconds = 60;
input ulong  MagicNumber         = 24012101;
input int DailyMaxSignals = 10;

input ENUM_ONOFF Use_RR_Gate = OFF;   // OFF cho scalp Bollinger


// Risk Model (B)
input group "=== RISK SPLIT (B) ==="
input double RiskPct_XAU = 0.014;   // 1.4% / setup
input double RiskPct_XAG = 0.006;   // 0.6% / setup
input double RiskPct_EUR = 0.005;   // 0.5% / setup (you adjust)
input int    EntriesPerSetup = 3;   // 3 entries
input int    MaxTotalTrades  = 12;  // all symbols (pending+positions)
input int    MaxPerSymbolTFPerDir = 2; // guard
input group "=== ROLE RISK MULTIPLIER ==="
input double RiskMult_DIST = 1.00;
input double RiskMult_LIQ  = 0.85;
input double RiskMult_FLIP = 0.60;
input double RiskMult_UNK  = 0.55;
input group "=== SCALP RR TAKE / RESCUE ==="
input ENUM_ONOFF Use_RR_Scalp_Manager = ON;
input double RR_Take1 = 2.0;   // TP tối thiểu 2R
input double RR_Take2 = 3.0;   // RR>=3 đóng thêm entry xấu
input double RR_BE_At = 1.2;   // RR>=1.2 kéo SL về BE
input double RiskPct_BTC = 0.010;   // 1.0% / setup
input double RiskPct_ETH = 0.008;   // ví dụ

input group "=== CRYPTO RISK MODEL (SEPARATE) ==="
input ENUM_ONOFF Use_Crypto_Risk_Separate = ON;
input double Crypto_SL_ATR_Mult_BTC = 1.25;   // SL = ATR * mult (BTC)
input double Crypto_SL_ATR_Mult_ETH = 1.20;   // ETH
input double CryptoSLBufferPoints   = 5.0;    // Buffer in points for crypto SL (confirm candle extreme)

// USC cent support
input ENUM_ONOFF AutoDetectCentAccount = ON;
input double     CentBalanceDivisor    = 100.0;

// ATR
input int    ATR_Length  = 14;
input double ATR_SL_Mult = 1.4;

// TF FIT
input group "=== TF FIT (SL/TP by TF) ==="
input double SL_ATR_M5  = 0.85;
input double SL_ATR_M15 = 1.00;
input double SL_ATR_M30 = 1.15;
input double SL_ATR_H1  = 1.25;

input double TP_R_M5  = 1.20;
input double TP_R_M15 = 1.40;
input double TP_R_M30 = 1.70;
input double TP_R_H1  = 2.00;


// SR
input group "=== SR ==="
input int    SR_PivotPeriod   = 10;
input double SR_MaxWidthPct   = 4.0;
input int    SR_MinStrength   = 25;
input int    SR_MaxZones      = 6;
input int    SR_Loopback      = 290;
input int    SR_KlinesLimit   = 450;
input double SR_Width_ATR_Cap = 1.2; // width cap by ATR
input int    SR_MinPivotHits  = 2;
input int    SR_Role_Lookback = 140;         // số bar đánh giá hành vi
input double SR_Role_Wick_Body = 1.2;        // wick > body*1.2 coi là reject mạnh
input double SR_Role_Sweep_ATR = 0.05;       // break threshold ~ ATR*0.05

input group "=== SR ROLE TF FILTER (DIST) ==="
input int DistMin_M5  = 80;
input int DistMin_M15 = 70;
input int DistMin_M30 = 65;
input int DistMin_H1  = 60;   // optional, bạn có thể để 60 hoặc 65

// Entry spacing + grid/zone stacking
input group "=== ENTRIES / GRID ==="
input int    Max_Layers_Per_Zone     = 3;       // max positions+pendings inside same zone
input double Grid_Step_Points        = 100.0;   // minimum distance from existing trades (points)
input double MinEntrySpacingPoints   = 80.0;    // prevent entry1/2/3 too close (points)
input double EntryPadPoints          = 10.0;    // pad from boundary to avoid “inside spread” (points)

// ===== BOLLINGER + RSI (SCALP MEAN REVERSION) =====
input int    BB_Period = 20;
input double BB_Dev    = 2.0;
input double BB_MaxWidth_ATR = 2.5;   // band quá rộng => trend mạnh => skip

input int    RSI_Period = 14;
input double RSI_Overbought = 70.0;
input double RSI_Oversold   = 30.0;


// Filters
input group "=== FILTERS ==="
input double MaxSpreadPointsFX      = 35;
input double MaxSpreadPointsMetal   = 170;
input double MaxSpreadPointsCrypto  = 2000;

input ENUM_ONOFF Use_Candle_Confirm = OFF;

input ENUM_ONOFF Use_RR_Trailing    = ON;
input double RR_Min                = 3.0;  // enforce >=3.0
input double RR_Trail_Start        = 1.0;
input double RR_Trail_Step         = 0.5;

input double PartialClosePct       = 50.0;  // TP1 hit: close X%
input ENUM_ONOFF Use_Breakout_Trades = OFF; // range scalp => OFF
input double Breakout_Buffer_ATR     = 0.25; // breakout buffer

// ---- NEW: Regime / Trend filter ----
input group "=== REGIME / TREND FILTER ==="
input ENUM_ONOFF Use_Regime_Filter   = ON;
input int    ADX_Period        = 14;
input double ADX_Trend_Min     = 22.0;   // >=22 coi là trend rõ
input double ADX_Range_Max     = 18.0;   // <=18 coi là range rõ
input double Squeeze_BB_Width_ATR = 1.2; // BB width < ATR*1.2 => squeeze

input int MinScore_Range   = 60;
input int MinScore_Unknown = 65;
input int MinScore_Trend   = 75;

input group "=== HTF EXTREME FILTER ==="
input ENUM_ONOFF Use_HTF_Extreme_Filter = ON;
input ENUM_TIMEFRAMES Extreme_TF1 = PERIOD_H1;
input ENUM_TIMEFRAMES Extreme_TF2 = PERIOD_H4;
input int Extreme_Lookback_Bars = 120;         // lookback H1/H4
input double Extreme_Dist_ATR = 0.45;          // < 0.45*ATR(HTF) coi là “sát đỉnh/đáy”
input double Extreme_RSI_Block = 62.0;         // trend up + RSI > 62 => block long near top (tùy m)




// EMA periods (default scalp-friendly)
input int EMA_Fast = 34;
input int EMA_Mid  = 89;
input int EMA_Slow = 200;

input int    Trend_Slope_LookbackBars = 5;     // slope = EMAfast(shift) - EMAfast(shift+lookback)
input double Trend_Slope_Min_ATR      = 0.20;  // slope must be > ATR*0.20 to call strong trend

input double Range_EMA_Diff_ATR       = 0.25;  // abs(EMAfast-EMAmid) < ATR*0.25 => range-ish
input double Range_Slope_Max_ATR      = 0.12;  // abs(slope) < ATR*0.12 => range-ish

input int    ATR_LongLen             = 50;
input double Squeeze_ATR_Ratio       = 0.75;  // ATR(14) < ATR(50)*0.75 => squeeze-ish

// Sweep v2 confirm
input group "=== SWEEP v2 CONFIRM ==="
input ENUM_ONOFF Use_SweepV2          = ON;
input double Sweep_BodyMin_Ratio      = 0.40;  // body/range >= 0.40 on sweep candle
input double Sweep_CloseReclaim_Ratio = 0.55;  // close position inside candle (reclaim) threshold
input int    Sweep_Confirm_MaxBars    = 1;     // confirm on next bar only
input double Sweep_Confirm_ATR_Buffer = 0.10;  // confirm retest buffer = ATR*0.10

// Telegram
input group "=== TELEGRAM ==="
input ENUM_ONOFF UseTelegram = ON;
input string TelegramToken   = "TOKEN_CUA_BOT";
input long   TelegramChatID  = 123456789;
input int    TelegramTopicID = 0;
input ENUM_ONOFF TelegramDebugLog = ON;

// Logs
input ENUM_ONOFF VerboseLogs = ON;

// News filter
input group "=== NEWS FILTER ==="
input ENUM_ONOFF Use_News_Filter    = ON;
input int    News_Impact_Level      = 2;   // 2=High only
input int    News_Before_Min        = 30;
input int    News_After_Min         = 30;
input ENUM_ONOFF News_Close_All     = OFF;

//==================================================================
// STRUCTS
//==================================================================

struct SRBox {
   double top;
   double bot;
   double mid;
   BoxType kind;
   double strength;
   ZoneRole role;
   int      roleScore; // optional debug
};

struct Signal {
   string symbol;
   ENUM_TIMEFRAMES tf;
   DirType dir;
   string reason;

   // indicators snapshot
   double bbUpper;
   double bbMid;
   double bbLower;
   double rsi;

   // candle snapshot (NEW - để score BB penetration đúng)
   double curHigh;
   double curLow;
   double curClose;
   double curOpen;

   SRBox box;

   double entries[3];
   int    entry_count;
   double sl;
   double tps[3];
   int tp_count;
   datetime candle_time;
};


// ---- NEW: Sweep candidate memory (for failure-test style confirm) ----
struct SweepCandidate
{
   string symbol;
   ENUM_TIMEFRAMES tf;
   DirType dir;
   double top;
   double bot;
   double mid;
   datetime sweep_time;    // time of sweep candle (closed)
   double sweep_extreme;   // low for long, high for short
   int    bars_waited;     // increments per next candle
   bool   used;            // avoid double trigger
   ZoneRole role;
int roleScore;

};

//==================================================================
// GLOBALS
//==================================================================
string g_symbols[];
int    g_symbolCount=0;

ENUM_TIMEFRAMES g_tfs[6];
int g_tfCount=0;

datetime g_lastClosed[];
datetime g_lastScan[];

string g_seenKeys[];
int g_seenMax=600;

SweepCandidate g_sweeps[];
int g_sweepMax=200;

int g_dailyCount = 0;
int g_dayKey = -1;

int DayKey(datetime t)
{
   MqlDateTime x; TimeToStruct(t, x);
   return x.year*10000 + x.mon*100 + x.day;
}

//==================================================================
// FORWARD DECLARATIONS
//==================================================================
bool   IsCryptoSymbol(const string sym);
bool   IsSymbolTFAllowed(const string sym, ENUM_TIMEFRAMES tf);
double CalcVolCrypto_ByRisk(const string sym, ENUM_TIMEFRAMES tf, DirType dir,
                            double entry, double sl, double riskMoney, const MqlRates &confirmCandle);

bool IsNearHTFExtreme(const string sym, DirType dir, double rsiTF,
                      double &distToExtreme, ENUM_TIMEFRAMES &whichTF);
double GetATR_TF(const string sym, ENUM_TIMEFRAMES tf, int len); // hoặc reuse CalcATR + CopyRates
bool GetSwingExtreme(const string sym, ENUM_TIMEFRAMES tf, int lookback,
                     double &hh, double &ll);


int SignalScore(const Signal &s, const MqlRates &cur, double atr);
int GetMinScoreByRegime(MarketRegime reg);
string GV_RR2DONE(string sym, long posType);
string GV_RR3DONE(string sym, long posType);
int  GetDistMinByTF(ENUM_TIMEFRAMES tf);
bool PassDistTF(ENUM_TIMEFRAMES tf, const SRBox &box);


double LossPerLotToSL(string sym, DirType dir, double entry, double sl);

string ZoneRoleToStr(ZoneRole r);
void   EvaluateZoneRole(const MqlRates &r[], int bars, double atr, SRBox &box);

double RoleRiskMult(ZoneRole role);

void   Log(const string s);
bool   TelegramSend(string text);

string TFToLabel(ENUM_TIMEFRAMES tf);
int    GetExpireMinutesByTF(ENUM_TIMEFRAMES tf);
string EnumToSymbol(ENUM_SYMBOL s);

double GetNormalizedBalance();
double GetRiskPctBySymbol(const string sym);

bool   AutoTradingAllowed();
bool   IsTradable(string sym);
bool   SpreadOK(string sym);
double NormalizeVolume(string sym, double vol);

double CalcATR(const MqlRates &r[], int len);
bool   PivotHigh(const double &vals[], int prd, int idx, double &out);
bool   PivotLow (const double &vals[], int prd, int idx, double &out);

double EMAFromRates(const MqlRates &r[], int bars, int period, int shift);
MarketRegime DetectRegime(const string sym, ENUM_TIMEFRAMES tf,
                          const MqlRates &r[], int bars, double atr14, double atrLong);
bool RegimeAllows(const MarketRegime reg, DirType dir, bool isMeanReversion, ZoneRole role);


bool   IsWickRejection(const MqlRates &c, DirType dir);
bool   ConfirmEntryCandleOnly(const Signal &s);

int    BuildSRBoxes(const MqlRates &rates[], SRBox &out[]);
int    TPFromBoxes(DirType d, double price, const SRBox &boxes[], double &tps[]);

bool   ZoneBroken(const SRBox &box, double atr, DirType dir, const MqlRates &cur);

bool   Build3EntriesInZone(const string sym, const SRBox &box, DirType dir, double &e1, double &e2, double &e3);

bool   SweepCandleQuality(const MqlRates &cur, const SRBox &box, DirType dir);
void   RegisterSweepCandidate(const string sym, ENUM_TIMEFRAMES tf, DirType dir, const SRBox &box,
                             const MqlRates &cur);
bool   TryConfirmSweep(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &cur, const MqlRates &prev,
                       const SRBox &boxes[], double atr, Signal &out);

bool   ComputeSupportLong(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &prev, const MqlRates &cur,
                          const SRBox &box, const SRBox &boxes[], double atr, MarketRegime reg, Signal &out);
bool   ComputeResistanceShort(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &prev, const MqlRates &cur,
                              const SRBox &box, const SRBox &boxes[], double atr, MarketRegime reg, Signal &out);
bool   ComputeBreakResistanceLong(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &prev, const MqlRates &cur,
                                  const SRBox &box, const SRBox &boxes[], double atr, Signal &out);

bool   SeenKey(const string key);
void   RememberKey(const string key);

int    CountTotalActiveTrades();
int    CountPerSymbolTFDir(string sym, ENUM_TIMEFRAMES tf, DirType dir);
bool   IsDuplicateSetup(string sym, ENUM_TIMEFRAMES tf, DirType dir, double entry, double sl, double tp);

bool   ZoneBusy(string sym, ENUM_TIMEFRAMES tf, DirType dir, const SRBox &box);

double CalcVolByRiskMoney(string sym, DirType dir, double entry, double sl, double riskMoney);
bool   RRAllow(const Signal &s);

bool   PlaceSignal(const Signal &s);
void   CancelExpiredLimits();
void   ManageTPMilestones();

bool   GetBollinger(const string sym, ENUM_TIMEFRAMES tf,
                    double &upper, double &mid, double &lower);
double GetADX(const string sym, ENUM_TIMEFRAMES tf)
{
   int h = iADX(sym, tf, ADX_Period);
   if(h == INVALID_HANDLE) return 0.0;

   double a[];
   ArraySetAsSeries(a,true);

   // buffer 0 = ADX main line
   if(CopyBuffer(h, 0, 1, 1, a) <= 0) return 0.0;
   return a[0];
}
                    
double GetRSI(const string sym, ENUM_TIMEFRAMES tf);
bool   IsMeanReversionAllowed(double bbUpper, double bbLower, double atr);

int ClampInt(int v, int lo, int hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

double ClampD(double v, double lo, double hi)
{
   if(v < lo) return lo;
   if(v > hi) return hi;
   return v;
}

int GetMinScoreByRegime(MarketRegime reg)
{
   if(reg==REG_RANGE) return MinScore_Range;
   if(reg==REG_TREND_UP || reg==REG_TREND_DOWN) return MinScore_Trend;
   return MinScore_Unknown;
}

int GetDistMinByTF(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M5)  return DistMin_M5;
   if(tf == PERIOD_M15) return DistMin_M15;
   if(tf == PERIOD_M30) return DistMin_M30;
   if(tf == PERIOD_H1)  return DistMin_H1;
   return DistMin_M30; // default
}

int GetMinScoreByTF(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M5)  return MinScore_M5;
   if(tf == PERIOD_M15) return MinScore_M15;
   if(tf == PERIOD_M30) return MinScore_M30;
   if(tf == PERIOD_H1)  return MinScore_H1;
   return MinScore_Other;
}


// Chỉ siết khi role = DIST, còn LIQ/FLIP/UNK vẫn cho chạy bình thường
bool PassDistTF(ENUM_TIMEFRAMES tf, const SRBox &box)
{
   if(box.role != ROLE_DISTRIBUTION) return true;

   int need = GetDistMinByTF(tf);
   return (box.roleScore >= need);
}


int SignalScore(const Signal &s, const MqlRates &cur, double atr)

{
   if(atr <= 0) atr = 0.00001;

   // ===================
   // 1) RSI extreme score (0..100)
   // ===================
   double rsiScore = 0.0;

   if(s.dir == DIR_LONG)
   {
      if(s.rsi >= 50) rsiScore = 0;
      else if(s.rsi <= 20) rsiScore = 100;
      else rsiScore = (50.0 - s.rsi) / (50.0 - 20.0) * 100.0;
   }
   else
   {
      if(s.rsi <= 50) rsiScore = 0;
      else if(s.rsi >= 80) rsiScore = 100;
      else rsiScore = (s.rsi - 50.0) / (80.0 - 50.0) * 100.0;
   }

   // ===================
   // 2) BB penetration score (0..100) - dùng curHigh/curLow thật
   // ===================
   double pen = 0.0;

   if(s.dir == DIR_LONG)
   {
      // penetration = (bbLower - curLow)/atr
      pen = (s.bbLower - s.curLow) / atr;
   }
   else
   {
      // penetration = (curHigh - bbUpper)/atr
      pen = (s.curHigh - s.bbUpper) / atr;
   }

   // clamp 0..0.25 ATR là đẹp cho scalp mean (0.25 = full score)
   double penNorm = ClampD(pen / 0.25, 0.0, 1.0);
   double bbScore = penNorm * 100.0;

   // ===================
   // 3) SR strength + role (0..100)
   // ===================
   double st = s.box.strength;

   double srScore = 0.0;
   if(st <= SR_MinStrength) srScore = 0.0;
   else
   {
      double stNorm = (st - SR_MinStrength) / (80.0 - SR_MinStrength);
      stNorm = ClampD(stNorm, 0.0, 1.0);
      srScore = stNorm * 100.0;
   }

   double roleBonus = 0.0;
   if(s.box.role == ROLE_DISTRIBUTION) roleBonus = 10;
   else if(s.box.role == ROLE_FLIP)    roleBonus = 6;
   else if(s.box.role == ROLE_LIQUIDITY) roleBonus = 3;
   else roleBonus = 0;

   srScore = ClampD(srScore + roleBonus, 0.0, 100.0);

   // ===================
   // 4) Wick bonus (NEW) - bỏ hard filter, chuyển sang bonus score
   // ===================
   double wickBonus = 0.0;
if(IsWickRejection(cur, s.dir))
   wickBonus = (double)Score_Wick_Bonus;

   // ===================
   // FINAL
   // ===================
   double totalW = (double)Score_RSI_Weight + (double)Score_BB_Weight + (double)Score_SR_Weight;
   if(totalW <= 0) totalW = 100.0;

   double score =
      rsiScore * Score_RSI_Weight +
      bbScore  * Score_BB_Weight  +
      srScore  * Score_SR_Weight;

   score /= totalW;

   score = ClampD(score + wickBonus, 0.0, 100.0);
   return ClampInt((int)MathRound(score), 0, 100);
}


// TP storage
string GV_TP1(long ticket);
string GV_TP1HIT(long ticket);
string GV_TRAIL(long ticket);
void   SaveTPLevelsForTicket(long ticket, double tp1);
bool   LoadTP1ForTicket(long ticket, double &tp1, bool &hit1, bool &trailOn);
bool   ParseTPFromComment(string cmt, string key, double &outVal);

//=========================== PART 2/4 ===============================
// LOG + UTIL + ATR/EMA + REGIME + SWEEP v2 + SR BUILD

// ---------------- LOG ----------------
void Log(const string s)
{
   if(VerboseLogs!=ON) return;
   Print(TimeToString(TimeLocal(), TIME_SECONDS), " | ", s);
}

string TFToLabel(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_H12: return "H12";
      default:         return IntegerToString((int)tf);
   }
}

int GetExpireMinutesByTF(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M5)  return Expire_M5_Min;
   if(tf == PERIOD_M15) return Expire_M15_Min;
   if(tf == PERIOD_M30) return Expire_M30_Min;
   if(tf == PERIOD_H1)  return Expire_H1_Min;
   if(tf == PERIOD_H4)  return Expire_H4_Min;
   return 30;
}

string EnumToSymbol(ENUM_SYMBOL s)
{
   string suf = SymbolSuffix;
   if(s==XAUUSDm) return "XAUUSD" + suf;
   if(s==XAGUSDm) return "XAGUSD" + suf;
   if(s==EURUSDm) return "EURUSD" + suf;
   if(s==GBPUSDm) return "GBPUSD" + suf;
   if(s==USDJPYm) return "USDJPY" + suf;
   if(s==BTCUSDm) return "BTCUSD" + suf;
   if(s==ETHUSDm) return "ETHUSD" + suf;
   return "";
}

void LogSkip(string sym, ENUM_TIMEFRAMES tf, string why) { if(VerboseLogs!=ON) return; Log(StringFormat("[SKIP] %s %s | %s", sym, TFToLabel(tf), why)); }
double GetNormalizedBalance()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(AutoDetectCentAccount != ON) return bal;

   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   if(cur == "USC" || StringFind(cur, "USC") >= 0)
   {
      if(CentBalanceDivisor > 0.0) return bal / CentBalanceDivisor;
   }
   return bal;
}

double GetRiskPctBySymbol(const string sym)
{
   if(StringFind(sym, "XAU") >= 0) return RiskPct_XAU;
   if(StringFind(sym, "XAG") >= 0) return RiskPct_XAG;
   if(StringFind(sym, "BTC") >= 0) return RiskPct_BTC;
   if(StringFind(sym, "ETH") >= 0) return RiskPct_ETH;
   if(StringFind(sym, "EUR") >= 0) return RiskPct_EUR;
   return RiskPct_EUR;
}

double RoleRiskMult(ZoneRole role)
{
   if(role == ROLE_DISTRIBUTION) return RiskMult_DIST;
   if(role == ROLE_LIQUIDITY)    return RiskMult_LIQ;
   if(role == ROLE_FLIP)         return RiskMult_FLIP;
   return RiskMult_UNK;
}

bool AutoTradingAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   return true;
}

bool IsTradable(string sym)
{
   if(!SymbolSelect(sym,true)) return false;
   long mode = 0;
   if(!SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, mode)) return false;
   if(mode==SYMBOL_TRADE_MODE_DISABLED || mode==SYMBOL_TRADE_MODE_CLOSEONLY) return false;
   return true;
}

bool SpreadOK(string sym)
{
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0) return true;

   double sp = (ask - bid) / pt;

   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0)
      return (sp <= MaxSpreadPointsCrypto);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0)
      return (sp <= MaxSpreadPointsMetal);

   return (sp <= MaxSpreadPointsFX);
}

double NormalizeVolume(string sym, double vol)
{
   double minLot=0.01, maxLot=100.0, step=0.01;
   SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, minLot);
   SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX, maxLot);
   SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP, step);

   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;

   vol = MathFloor(vol/step)*step;
   return NormalizeDouble(vol, 2);
}

// ---------------- ATR ----------------
double CalcATR(const MqlRates &r[], int len)
{
   int n = ArraySize(r);
   if(len <= 0) return 0.0;
   if(n < len + 2) return 0.0;

   double atr = 0.0;
   for(int i = 2; i <= len + 1; i++)
   {
      double h  = r[i].high;
      double l  = r[i].low;
      double pc = r[i+1].close;

      double tr = h - l;
      double t2 = MathAbs(h - pc);
      double t3 = MathAbs(l - pc);
      if(t2 > tr) tr = t2;
      if(t3 > tr) tr = t3;
      atr += tr;
   }
   atr /= len;

   for(int i = len; i >= 1; i--)
   {
      double h  = r[i].high;
      double l  = r[i].low;
      double pc = r[i+1].close;

      double tr = h - l;
      double t2 = MathAbs(h - pc);
      double t3 = MathAbs(l - pc);
      if(t2 > tr) tr = t2;
      if(t3 > tr) tr = t3;

      atr = (atr * (len - 1) + tr) / len;
   }
   return atr;
}

double GetSL_ATR_Mult(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_M5)  return SL_ATR_M5;
   if(tf==PERIOD_M15) return SL_ATR_M15;
   if(tf==PERIOD_M30) return SL_ATR_M30;
   if(tf==PERIOD_H1)  return SL_ATR_H1;
   return 1.20;
}

double GetTP_R(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_M5)  return TP_R_M5;
   if(tf==PERIOD_M15) return TP_R_M15;
   if(tf==PERIOD_M30) return TP_R_M30;
   if(tf==PERIOD_H1)  return TP_R_H1;
   return 1.60;
}


// ---------------- EMA (from rates, no indicators) ----------------
// rates must be ArraySetAsSeries(true). shift=1 => last closed.
double EMAFromRates(const MqlRates &r[], int bars, int period, int shift)
{
   if(period <= 1) return 0.0;
   if(bars < period + shift + 5) return 0.0;

   double alpha = 2.0 / (period + 1.0);

   // warm-up using the oldest portion (simple recursive warm-up)
   int start = bars - 1;          // oldest index
   int end   = shift;             // newest index (closed bar)
   double ema = r[start].close;

   // run forward in time (from old -> new), which is start..end but indices decrease in series
   for(int i = start-1; i >= end; i--)
      ema = alpha * r[i].close + (1.0 - alpha) * ema;

   return ema;
}

bool GetBollinger(const string sym, ENUM_TIMEFRAMES tf,
                  double &upper, double &mid, double &lower)
{
   int h = iBands(sym, tf, BB_Period, 0, BB_Dev, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return false;

   double u[], m[], l[];
   ArraySetAsSeries(u,true);
   ArraySetAsSeries(m,true);
   ArraySetAsSeries(l,true);

   if(CopyBuffer(h,0,1,1,u)<=0) return false;
   if(CopyBuffer(h,1,1,1,m)<=0) return false;
   if(CopyBuffer(h,2,1,1,l)<=0) return false;

   upper=u[0];
   mid  =m[0];
   lower=l[0];
   return true;
}

double GetRSI(const string sym, ENUM_TIMEFRAMES tf)
{
   int h = iRSI(sym, tf, RSI_Period, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 50.0;

   double r[];
   ArraySetAsSeries(r,true);
   if(CopyBuffer(h,0,1,1,r)<=0) return 50.0;
   return r[0];
}

bool IsMeanReversionAllowed(double bbUpper, double bbLower, double atr)
{
   if(atr <= 0) return true;
   double width = bbUpper - bbLower;
   return (width <= atr * BB_MaxWidth_ATR);
}

bool GetSwingExtreme(const string sym, ENUM_TIMEFRAMES tf, int lookback, double &hh, double &ll)
{
   MqlRates rr[];
   ArraySetAsSeries(rr, true);

   int got = CopyRates(sym, tf, 1, lookback, rr);  // 1 = last closed bar
   if(got < 20) return false;

   hh = -DBL_MAX;
   ll =  DBL_MAX;

   for(int i=0; i<got; i++)
   {
      hh = MathMax(hh, rr[i].high);
      ll = MathMin(ll, rr[i].low);
   }
   return true;
}

double GetATR_TF(const string sym, ENUM_TIMEFRAMES tf, int len)
{
   MqlRates rr[];
   ArraySetAsSeries(rr, true);

   int need = len + 60;
   int got  = CopyRates(sym, tf, 0, need, rr);
   if(got < len + 5) return 0.0;

   return CalcATR(rr, len);
}

// dir = LONG: near HH ; dir = SHORT: near LL
bool IsNearHTFExtreme(const string sym, DirType dir, double rsiTF,
                      double &distToExtreme, ENUM_TIMEFRAMES &whichTF)
{
   distToExtreme = 0.0;
   whichTF = PERIOD_CURRENT;

   if(Use_HTF_Extreme_Filter != ON) return false;

   ENUM_TIMEFRAMES tfs[2];
   tfs[0] = Extreme_TF1;
   tfs[1] = Extreme_TF2;

   for(int k=0; k<2; k++)
   {
      ENUM_TIMEFRAMES tf = tfs[k];
      if(tf == PERIOD_CURRENT) continue;

      double hh, ll;
      if(!GetSwingExtreme(sym, tf, Extreme_Lookback_Bars, hh, ll))
         continue;

      double atrH = GetATR_TF(sym, tf, ATR_Length);
      if(atrH <= 0.0) continue;

      double price = (dir == DIR_LONG) ? SymbolInfoDouble(sym, SYMBOL_BID)
                                       : SymbolInfoDouble(sym, SYMBOL_ASK);

      if(dir == DIR_LONG)
      {
         double d = hh - price; // distance to top
         if(d <= atrH * Extreme_Dist_ATR && rsiTF >= Extreme_RSI_Block)
         {
            distToExtreme = d;
            whichTF = tf;
            return true;
         }
      }
      else
      {
         double d = price - ll; // distance to bottom
         if(d <= atrH * Extreme_Dist_ATR && rsiTF <= (100.0 - Extreme_RSI_Block))
         {
            distToExtreme = d;
            whichTF = tf;
            return true;
         }
      }
   }
   return false;
}



// ---------------- REGIME DETECTOR ----------------
MarketRegime DetectRegime(const string sym, ENUM_TIMEFRAMES tf,
                          const MqlRates &r[], int bars, double atr14, double atrLong)
{
   if(Use_Regime_Filter != ON) return REG_UNKNOWN;
   if(atr14 <= 0) return REG_UNKNOWN;

   // --- squeeze check: ATR low + BB width low ---
   double bbU=0, bbM=0, bbL=0;
   bool hasBB = GetBollinger(sym, tf, bbU, bbM, bbL);
   double bbWidth = hasBB ? (bbU - bbL) : 0.0;

   bool squeeze1 = (atrLong > 0 && atr14 < atrLong * Squeeze_ATR_Ratio);
   bool squeeze2 = (hasBB && bbWidth > 0 && bbWidth < atr14 * Squeeze_BB_Width_ATR);
   if(squeeze1 && squeeze2) return REG_SQUEEZE;

   // --- EMA alignment + slope ---
   double emaF = EMAFromRates(r, bars, EMA_Fast, 1);
   double emaM = EMAFromRates(r, bars, EMA_Mid,  1);
   double emaS = EMAFromRates(r, bars, EMA_Slow, 1);
   if(emaF==0 || emaM==0 || emaS==0) return REG_UNKNOWN;

   int lb = MathMax(1, Trend_Slope_LookbackBars);
   double emaF_back = EMAFromRates(r, bars, EMA_Fast, 1 + lb);
   double slope = (emaF - emaF_back);

   // --- ADX confirmation ---
   double adx = GetADX(sym, tf);

   bool trendUp = (emaF > emaM && emaM > emaS &&
                   slope > atr14 * Trend_Slope_Min_ATR &&
                   adx >= ADX_Trend_Min);

   bool trendDown = (emaF < emaM && emaM < emaS &&
                     slope < -atr14 * Trend_Slope_Min_ATR &&
                     adx >= ADX_Trend_Min);

   if(trendUp)   return REG_TREND_UP;
   if(trendDown) return REG_TREND_DOWN;

   // --- range-ish: low ADX + small EMA diff + small slope ---
   bool range1 = (adx > 0 && adx <= ADX_Range_Max);
   bool range2 = (MathAbs(emaF - emaM) < atr14 * Range_EMA_Diff_ATR);
   bool range3 = (MathAbs(slope) < atr14 * Range_Slope_Max_ATR);

   if(range1 && range2 && range3) return REG_RANGE;

   return REG_UNKNOWN;
}

bool RegimeAllows(const MarketRegime reg, DirType dir, bool isMeanReversion, ZoneRole role)
{
   if(Use_Regime_Filter != ON) return true;
   if(!isMeanReversion) return true;

   if(reg == REG_SQUEEZE) return false;

   if(reg == REG_TREND_UP)
      return (dir == DIR_LONG || role == ROLE_DISTRIBUTION);

   if(reg == REG_TREND_DOWN)
      return (dir == DIR_SHORT || role == ROLE_DISTRIBUTION);

   return true; // RANGE / UNKNOWN
}



string ZoneRoleToStr(ZoneRole r)
{
   if(r==ROLE_LIQUIDITY)    return "LIQ";
   if(r==ROLE_DISTRIBUTION) return "DIST";
   if(r==ROLE_FLIP)         return "FLIP";
   return "UNK";
}

void EvaluateZoneRole(const MqlRates &r[], int bars, double atr, SRBox &box)
{
   box.role = ROLE_UNKNOWN;
   box.roleScore = 0;

   if(bars < 60 || atr <= 0) return;

   int look = MathMin(SR_Role_Lookback, bars-3);
   if(look < 50) return;

   int touch=0, sweep=0, reject=0, flip=0;
   bool hadBreakUp=false, hadBreakDn=false;

   double brk = atr * SR_Role_Sweep_ATR;

   for(int i=look; i>=1; i--)
   {
      MqlRates c = r[i];

      bool overlap = (c.high >= box.bot && c.low <= box.top);
      if(overlap) touch++;

      bool sweepUp = (c.high > box.top && c.close < box.top);
      bool sweepDn = (c.low  < box.bot && c.close > box.bot);
      if(sweepUp || sweepDn) sweep++;

      double range = c.high - c.low;
      if(range > 0)
      {
         double body  = MathAbs(c.close - c.open);
         double upW   = c.high - MathMax(c.close, c.open);
         double lowW  = MathMin(c.close, c.open) - c.low;

         if(c.high >= box.top && upW > body * SR_Role_Wick_Body) reject++;
         if(c.low  <= box.bot && lowW > body * SR_Role_Wick_Body) reject++;
      }

      if(c.close > box.top + brk) hadBreakUp=true;
      if(c.close < box.bot - brk) hadBreakDn=true;

      if(hadBreakUp)
      {
         if(c.low <= box.top && c.close > box.top) { flip++; hadBreakUp=false; }
      }
      if(hadBreakDn)
      {
         if(c.high >= box.bot && c.close < box.bot) { flip++; hadBreakDn=false; }
      }
   }

   int scoreFlip = flip*3;
   int scoreLiq  = sweep*2;
   int scoreDist = reject*2;

   int best = scoreFlip;
   box.role = ROLE_FLIP;

   if(scoreLiq > best) { best=scoreLiq; box.role=ROLE_LIQUIDITY; }
   if(scoreDist > best){ best=scoreDist; box.role=ROLE_DISTRIBUTION; }

   if(touch < 3) box.role = ROLE_UNKNOWN;

   box.roleScore = best;
}


// ---------------- PIVOTS ----------------
bool PivotHigh(const double &vals[], int prd, int idx, double &out)
{
   int n = ArraySize(vals);
   if(idx + prd >= n || idx - prd < 1) return false;

   double mid = vals[idx];
   for(int i = idx - prd; i <= idx + prd; i++)
   {
      if(i <= 0) continue;
      if(vals[i] > mid) return false;
   }
   out = mid;
   return true;
}

bool PivotLow(const double &vals[], int prd, int idx, double &out)
{
   int n = ArraySize(vals);
   if(idx + prd >= n || idx - prd < 1) return false;

   double mid = vals[idx];
   for(int i = idx - prd; i <= idx + prd; i++)
   {
      if(i <= 0) continue;
      if(vals[i] < mid) return false;
   }
   out = mid;
   return true;
}

// ---------------- Candle confirm ----------------
bool IsWickRejection(const MqlRates &c, DirType dir)
{
   double body  = MathAbs(c.close - c.open);
   double range = c.high - c.low;
   if(range <= 0) return false;

   if(dir == DIR_LONG)
   {
      double lowerWick = MathMin(c.close, c.open) - c.low;
      if(lowerWick > range * 0.4 && lowerWick > body) return true;
   }
   else
   {
      double upperWick = c.high - MathMax(c.close, c.open);
      if(upperWick > range * 0.4 && upperWick > body) return true;
   }
   return false;
}

bool ConfirmEntryCandleOnly(const Signal &s)
{
   if(Use_Candle_Confirm == OFF) return true;

   MqlRates r[];
   ArrayResize(r, 2);
   ArraySetAsSeries(r, true);

   if(CopyRates(s.symbol, s.tf, 1, 2, r) < 2) return false;
   return IsWickRejection(r[0], s.dir);
}

// ---------------- Zone broken ----------------
bool ZoneBroken(const SRBox &box, double atr, DirType dir, const MqlRates &cur)
{
   double buffer = (atr > 0 ? atr * Breakout_Buffer_ATR : 0.0);

   if(dir == DIR_SHORT)
      return (cur.close > box.top + buffer);
   else
      return (cur.close < box.bot - buffer);
}

// ---------------- Sweep v2 helpers ----------------
bool SweepCandleQuality(const MqlRates &cur, const SRBox &box, DirType dir)
{
   // sweep candle must reclaim with enough body
   double range = cur.high - cur.low;
   if(range <= 0) return false;

   double body  = MathAbs(cur.close - cur.open);
   double bodyRatio = body / range;
   if(bodyRatio < Sweep_BodyMin_Ratio) return false;

   // close position inside the candle (reclaim)
   double closePos = (cur.close - cur.low) / range; // 0..1
   if(dir == DIR_LONG)
   {
      // want close nearer top side after sweeping below support
      if(closePos < Sweep_CloseReclaim_Ratio) return false;
      // must close back above bot of zone
      if(cur.close <= box.bot) return false;
   }
   else
   {
      // invert for short: want close nearer bottom side after sweeping above resistance
      if(closePos > (1.0 - Sweep_CloseReclaim_Ratio)) return false;
      if(cur.close >= box.top) return false;
   }

   return true;
}

void RegisterSweepCandidate(const string sym, ENUM_TIMEFRAMES tf, DirType dir, const SRBox &box,
                            const MqlRates &cur)
{
   if(Use_SweepV2 != ON) return;

   // avoid duplicates: same sym/tf/dir/mid/time
   for(int i=0;i<ArraySize(g_sweeps);i++)
   {
      if(g_sweeps[i].used) continue;
      if(g_sweeps[i].symbol!=sym) continue;
      if(g_sweeps[i].tf!=tf) continue;
      if(g_sweeps[i].dir!=dir) continue;
      if(g_sweeps[i].sweep_time==cur.time) return;
      if(MathAbs(g_sweeps[i].mid - box.mid) < (SymbolInfoDouble(sym,SYMBOL_POINT)*50))
         return;
   }

   int sz = ArraySize(g_sweeps);
if(sz < g_sweepMax)
{
   ArrayResize(g_sweeps, sz+1);
   g_sweeps[sz].symbol = sym;
   g_sweeps[sz].tf = tf;
   g_sweeps[sz].dir = dir;
   g_sweeps[sz].top = box.top;
   g_sweeps[sz].bot = box.bot;
   g_sweeps[sz].mid = box.mid;
   g_sweeps[sz].sweep_time = cur.time;
   g_sweeps[sz].bars_waited = 0;
   g_sweeps[sz].used = false;
   g_sweeps[sz].sweep_extreme = (dir==DIR_LONG ? cur.low : cur.high);
   g_sweeps[sz].role = box.role;
   g_sweeps[sz].roleScore = box.roleScore;
   return;
}

g_sweeps[sz].role = box.role;
g_sweeps[sz].roleScore = box.roleScore;

   // if full: overwrite oldest/used
   int pick=0;
   datetime oldest = (datetime)2147483647;
   for(int i=0;i<ArraySize(g_sweeps);i++)
   {
      if(g_sweeps[i].used) { pick=i; break; }
      if(g_sweeps[i].sweep_time < oldest) { oldest=g_sweeps[i].sweep_time; pick=i; }
   }
   g_sweeps[pick].symbol = sym;
   g_sweeps[pick].tf = tf;
   g_sweeps[pick].dir = dir;
   g_sweeps[pick].top = box.top;
   g_sweeps[pick].bot = box.bot;
   g_sweeps[pick].mid = box.mid;
   g_sweeps[pick].sweep_time = cur.time;
   g_sweeps[pick].bars_waited = 0;
   g_sweeps[pick].used = false;
   g_sweeps[pick].sweep_extreme = (dir==DIR_LONG ? cur.low : cur.high);
   g_sweeps[pick].role = box.role;
g_sweeps[pick].roleScore = box.roleScore;
}

// Confirm on next candle: “failure-test” lite
bool TryConfirmSweep(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &cur, const MqlRates &prev,
                     const SRBox &boxes[], double atr, Signal &out)
{
   if(Use_SweepV2 != ON) return false;

   for(int i=0;i<ArraySize(g_sweeps);i++)
   {
      if(g_sweeps[i].used) continue;
      if(g_sweeps[i].symbol != sym) continue;
      if(g_sweeps[i].tf != tf) continue;

      // wait only next bar(s)
      if(cur.time <= g_sweeps[i].sweep_time) continue;

      g_sweeps[i].bars_waited++;
      if(g_sweeps[i].bars_waited > MathMax(1, Sweep_Confirm_MaxBars))
      {
         g_sweeps[i].used = true;
         continue;
      }

      // build a temp box (use stored edges)
      SRBox box;
      box.top = g_sweeps[i].top;
      box.bot = g_sweeps[i].bot;
      box.mid = g_sweeps[i].mid;
      box.strength = 0;
      box.kind = (g_sweeps[i].dir==DIR_LONG ? BOX_SUPPORT : BOX_RESISTANCE);
      box.role = g_sweeps[i].role;
      box.roleScore = g_sweeps[i].roleScore;

      double buf = (atr>0 ? atr*Sweep_Confirm_ATR_Buffer : 0.0);

      bool ok=false;
      if(g_sweeps[i].dir == DIR_LONG)
      {
         // confirm: retest does NOT break again, close stays above bot
         ok = (cur.low > box.bot - buf && cur.close > box.bot);
      }
      else
      {
         ok = (cur.high < box.top + buf && cur.close < box.top);
      }

      if(!ok) continue;

      // build signal on confirm bar close
      out.symbol = sym;
      out.tf = tf;
      out.dir = g_sweeps[i].dir;
      out.box = box;
      out.reason = (out.dir==DIR_LONG ? "sweep_confirm_long" : "sweep_confirm_short");
      out.candle_time = cur.time;
      out.curHigh  = cur.high;
out.curLow   = cur.low;
out.curClose = cur.close;
out.curOpen  = cur.open;

double bbU, bbM, bbL;
if(!GetBollinger(sym, tf, bbU, bbM, bbL)) { g_sweeps[i].used=true; return false; }
out.bbUpper = bbU;
out.bbMid   = bbM;
out.bbLower = bbL;
out.rsi     = GetRSI(sym, tf);

      double e1,e2,e3;
      if(!Build3EntriesInZone(sym, box, out.dir, e1,e2,e3))
      {
         g_sweeps[i].used = true;
         return false;
      }
      out.entries[0]=e1; out.entries[1]=e2; out.entries[2]=e3;
      out.entry_count = EntriesPerSetup;

      // SL uses sweep extreme (from sweep candle) + ATR mult
      if(out.dir==DIR_LONG)
         out.sl = MathMin(g_sweeps[i].sweep_extreme, box.bot) - (atr * ATR_SL_Mult);
      else
         out.sl = MathMax(g_sweeps[i].sweep_extreme, box.top) + (atr * ATR_SL_Mult);

      out.tp_count = TPFromBoxes(out.dir, out.entries[0], boxes, out.tps);
      if(out.tp_count <= 0)
      {
         // fallback 3R
         if(out.dir==DIR_LONG) out.tps[0] = out.entries[0] + MathAbs(out.entries[0]-out.sl)*3.0;
         else                 out.tps[0] = out.entries[0] - MathAbs(out.sl-out.entries[0])*3.0;
         out.tp_count = 1;
      }

      g_sweeps[i].used = true;
      return true;
   }
   return false;
}

// ---------------- SR BUILD (ATR width cap + hits) ----------------
int BuildSRBoxes(const MqlRates &rates[], SRBox &out[])
{
   int n = ArraySize(rates);
   if(n < SR_Loopback + SR_PivotPeriod + 20) return 0;

   int m = MathMin(n-1, SR_KlinesLimit-1);
   if(m < 120) return 0;

   double highs[], lows[], closes[];
   ArrayResize(highs,  m);
   ArrayResize(lows,   m);
   ArrayResize(closes, m);

   // i=0 oldest
   for(int i=0; i<m; i++)
   {
      int si = m - i;
      highs[i]  = rates[si].high;
      lows[i]   = rates[si].low;
      closes[i] = rates[si].close;
   }

   double lastClose = rates[1].close;

   int len300 = MathMin(300, m);
   double prdHi = -DBL_MAX, prdLo = DBL_MAX;
   for(int i = m-len300; i < m; i++)
   {
      prdHi = MathMax(prdHi, highs[i]);
      prdLo = MathMin(prdLo, lows[i]);
   }

   double widthByRange = (prdHi - prdLo) * SR_MaxWidthPct / 100.0;
   if(widthByRange <= 0) return 0;

   double atr = CalcATR(rates, ATR_Length);
   double widthCap = (atr > 0 ? atr * SR_Width_ATR_Cap : widthByRange);
   double cwidth = MathMin(widthByRange, widthCap);
   if(cwidth <= 0) return 0;

   // pivots
   double pivotvals[];
   int    pivotlocs[];
   ArrayResize(pivotvals, 0);
   ArrayResize(pivotlocs, 0);

   int prd = SR_PivotPeriod;
   for(int i = prd; i < m - prd; i++)
   {
      double ph, pl;
      bool isPh = PivotHigh(highs, prd, i, ph);
      bool isPl = PivotLow (lows,  prd, i, pl);
      if(!isPh && !isPl) continue;

      double val = (isPh ? ph : pl);

      int sz = ArraySize(pivotvals);
      ArrayResize(pivotvals, sz+1);
      ArrayResize(pivotlocs, sz+1);
      pivotvals[sz] = val;
      pivotlocs[sz] = i;
   }

   int pvN = ArraySize(pivotvals);
   if(pvN == 0) return 0;

   double zoneStrength[], zoneHi[], zoneLo[];
   int zoneHits[];
   ArrayResize(zoneStrength, pvN);
   ArrayResize(zoneHi, pvN);
   ArrayResize(zoneLo, pvN);
   ArrayResize(zoneHits, pvN);

   for(int x=0; x<pvN; x++)
   {
      double center = pivotvals[x];
      double lo = center, hi = center;
      int hits = 0;

      for(int y=0; y<pvN; y++)
      {
         double cpp = pivotvals[y];
         if(MathAbs(cpp - center) <= cwidth)
         {
            lo = MathMin(lo, cpp);
            hi = MathMax(hi, cpp);
            hits++;
         }
      }

      zoneHits[x] = hits;
      double recencyBoost = 1.0 + (double)pivotlocs[x] / (double)m * 0.35;
      zoneStrength[x] = (double)hits * 20.0 * recencyBoost;
      zoneHi[x] = hi;
      zoneLo[x] = lo;
   }

   SRBox tmp[];
   ArrayResize(tmp, 0);

   for(int i=0; i<pvN; i++)
   {
      if(zoneHits[i] < SR_MinPivotHits) continue;
      if(zoneStrength[i] < SR_MinStrength) continue;

      double hi = zoneHi[i];
      double lo = zoneLo[i];
      if(hi <= lo) continue;

      bool merged=false;
      for(int k=0; k<ArraySize(tmp); k++)
      {
         double overlapMin = MathMax(tmp[k].bot, lo);
         double overlapMax = MathMin(tmp[k].top, hi);
         double overlap    = overlapMax - overlapMin;

         double w1 = tmp[k].top - tmp[k].bot;
         double w2 = hi - lo;
         double minW = MathMin(w1, w2);

         if(minW > 0 && overlap/minW > 0.65)
         {
            tmp[k].top = MathMax(tmp[k].top, hi);
            tmp[k].bot = MathMin(tmp[k].bot, lo);
            tmp[k].mid = (tmp[k].top + tmp[k].bot)/2.0;
            tmp[k].strength = MathMax(tmp[k].strength, zoneStrength[i]);
            merged=true;
            break;
         }
      }

      if(!merged)
      {
         int sz = ArraySize(tmp);
         ArrayResize(tmp, sz+1);
         tmp[sz].top = hi;
         tmp[sz].bot = lo;
         tmp[sz].mid = (hi + lo) / 2.0;
         tmp[sz].strength = zoneStrength[i];
      }
   }

   if(ArraySize(tmp)==0) return 0;

   for(int i=0;i<ArraySize(tmp)-1;i++)
      for(int j=i+1;j<ArraySize(tmp);j++)
         if(tmp[j].strength > tmp[i].strength)
         { SRBox x=tmp[i]; tmp[i]=tmp[j]; tmp[j]=x; }

   int outN = MathMin(SR_MaxZones, ArraySize(tmp));
   ArrayResize(out, outN);
   for(int i=0;i<outN;i++)
   {
      out[i]=tmp[i];
      out[i].kind = (out[i].mid <= lastClose ? BOX_SUPPORT : BOX_RESISTANCE);
   }
   return outN;
}

int TPFromBoxes(DirType d, double price, const SRBox &boxes[], double &tps[])
{
   double best = 0.0;
   bool found  = false;

   int n = ArraySize(boxes);

   for(int i=0;i<n;i++)
   {
      if(d == DIR_LONG)
      {
         if(boxes[i].kind != BOX_RESISTANCE) continue;
         double lvl = boxes[i].bot; // scalp: nearest edge
         if(lvl <= price) continue;
         if(!found || lvl < best) { best=lvl; found=true; }
      }
      else
      {
         if(boxes[i].kind != BOX_SUPPORT) continue;
         double lvl = boxes[i].top; // scalp: nearest edge
         if(lvl >= price) continue;
         if(!found || lvl > best) { best=lvl; found=true; }
      }
   }

   if(!found) return 0;
   tps[0] = best;
   return 1;
}

//=========================== PART 3/4 ===============================
// Dedup + ZoneBusy + Risk/Volume + 3 Entries + Signal Compute (UPDATED)

bool SeenKey(const string key)
{
   for(int i=0;i<ArraySize(g_seenKeys);i++)
      if(g_seenKeys[i]==key) return true;
   return false;
}

void RememberKey(const string key)
{
   int sz=ArraySize(g_seenKeys);
   if(sz<g_seenMax){
      ArrayResize(g_seenKeys,sz+1);
      g_seenKeys[sz]=key;
      return;
   }
   for(int i=1;i<sz;i++) g_seenKeys[i-1]=g_seenKeys[i];
   g_seenKeys[sz-1]=key;
}

bool Near(double a, double b, double tol) { return (MathAbs(a - b) <= tol); }

bool IsDuplicateSetup(string sym, ENUM_TIMEFRAMES tf, DirType dir, double entry, double sl, double tp)
{
   double tol = SymbolInfoDouble(sym, SYMBOL_POINT) * 10;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=sym) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(dir==DIR_LONG  && type!=POSITION_TYPE_BUY)  continue;
      if(dir==DIR_SHORT && type!=POSITION_TYPE_SELL) continue;

      double pe = PositionGetDouble(POSITION_PRICE_OPEN);
      double psl= PositionGetDouble(POSITION_SL);
      double ptp= PositionGetDouble(POSITION_TP);

      if(Near(pe,entry,tol) && Near(psl,sl,tol) && Near(ptp,tp,tol))
         return true;
   }

   for(int i=0;i<OrdersTotal();i++)
   {
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC)!=MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL)!=sym) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(dir==DIR_LONG  && type!=ORDER_TYPE_BUY_LIMIT)  continue;
      if(dir==DIR_SHORT && type!=ORDER_TYPE_SELL_LIMIT) continue;

      double pe = OrderGetDouble(ORDER_PRICE_OPEN);
      double psl= OrderGetDouble(ORDER_SL);
      double ptp= OrderGetDouble(ORDER_TP);

      if(Near(pe,entry,tol) && Near(psl,sl,tol) && Near(ptp,tp,tol))
         return true;
   }
   return false;
}

int CountTotalActiveTrades()
{
   int cnt = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber) cnt++;
   }
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) == MagicNumber) cnt++;
   }
   return cnt;
}

int CountPerSymbolTFDir(string sym, ENUM_TIMEFRAMES tf, DirType dir)
{
   int cnt = 0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=sym) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(dir==DIR_LONG  && type!=POSITION_TYPE_BUY)  continue;
      if(dir==DIR_SHORT && type!=POSITION_TYPE_SELL) continue;
      cnt++;
   }
   for(int i=0;i<OrdersTotal();i++)
   {
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC)!=MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL)!=sym) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(dir==DIR_LONG  && type!=ORDER_TYPE_BUY_LIMIT)  continue;
      if(dir==DIR_SHORT && type!=ORDER_TYPE_SELL_LIMIT) continue;
      cnt++;
   }
   return cnt;
}

// ZoneBusy (block if too close to existing trades OR too many layers)
bool ZoneBusy(string sym, ENUM_TIMEFRAMES tf, DirType dir, const SRBox &box)
{
   int countInZone = 0;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0) return false;

   double currentPrice = (dir == DIR_LONG) ? SymbolInfoDouble(sym, SYMBOL_ASK)
                                           : SymbolInfoDouble(sym, SYMBOL_BID);

   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=sym) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(dir==DIR_LONG  && type!=POSITION_TYPE_BUY)  continue;
      if(dir==DIR_SHORT && type!=POSITION_TYPE_SELL) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      if(openPrice >= box.bot && openPrice <= box.top)
      {
         countInZone++;
         double dist = MathAbs(openPrice - currentPrice) / point;
         if(dist < Grid_Step_Points) return true;
      }
   }

   for(int i=0; i<OrdersTotal(); i++)
   {
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC)!=MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL)!=sym) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(dir==DIR_LONG  && type!=ORDER_TYPE_BUY_LIMIT)  continue;
      if(dir==DIR_SHORT && type!=ORDER_TYPE_SELL_LIMIT) continue;

      double openPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      if(openPrice >= box.bot && openPrice <= box.top)
      {
         countInZone++;
         double dist = MathAbs(openPrice - currentPrice) / point;
         if(dist < Grid_Step_Points) return true;
      }
   }
   return (countInZone >= Max_Layers_Per_Zone);
}

// Risk->Volume by OrderCalcProfit
double CalcVolByRiskMoney(string sym, DirType dir, double entry, double sl, double riskMoney)
{
   if(riskMoney <= 0) return 0.0;

   ENUM_ORDER_TYPE otype = (dir==DIR_LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

   double profit = 0.0;
   if(!OrderCalcProfit(otype, sym, 1.0, entry, sl, profit))
   {
      Log(StringFormat("[RISK] OrderCalcProfit fail sym=%s err=%d", sym, GetLastError()));
      return 0.0;
   }

   double lossPerLot = MathAbs(profit);
   if(lossPerLot <= 0.0) return 0.0;

   double vol = riskMoney / lossPerLot;
   return NormalizeVolume(sym, vol);
}

double LossPerLotToSL(string sym, DirType dir, double entry, double sl)
{
   ENUM_ORDER_TYPE otype = (dir==DIR_LONG ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double profit = 0.0;

   if(!OrderCalcProfit(otype, sym, 1.0, entry, sl, profit))
   {
      Log(StringFormat("[RISK] OrderCalcProfit fail sym=%s err=%d", sym, GetLastError()));
      return 0.0;
   }
   return MathAbs(profit); // loss per 1.0 lot
}

bool IsCryptoSymbol(const string sym)
{
   return (StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0);
}

// Symbol-specific timeframe filtering
// XAU/XAG/EUR/GBP: M5+M15 only
// BTC/ETH: M5+M15+H1+H4
bool IsSymbolTFAllowed(const string sym, ENUM_TIMEFRAMES tf)
{
   // Crypto symbols: M5, M15, H1, H4
   if(IsCryptoSymbol(sym))
   {
      return (tf == PERIOD_M5 || tf == PERIOD_M15 || tf == PERIOD_H1 || tf == PERIOD_H4);
   }
   
   // Forex/Metals (XAU/XAG/EUR/GBP): M5 and M15 only
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0 ||
      StringFind(sym, "EUR") >= 0 || StringFind(sym, "GBP") >= 0)
   {
      return (tf == PERIOD_M5 || tf == PERIOD_M15);
   }
   
   // Default: allow all timeframes for other symbols
   return true;
}

// Volume theo risk cho crypto CFD: dùng tick value/size chuẩn của symbol
// Updated: SL calculation now based on confirm candle extreme + buffer
double CalcVolCrypto_ByRisk(const string sym, ENUM_TIMEFRAMES tf, DirType dir,
                            double entry, double sl, double riskMoney, const MqlRates &confirmCandle)
{
   if(riskMoney <= 0.0) return 0.0;

   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0.0) return 0.0;
   
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) return 0.0;

   // For crypto: SL based on confirm candle extreme + buffer (not ATR)
   double bufferPrice = CryptoSLBufferPoints * pt;
   double actualSL = sl;
   
   if(dir == DIR_LONG)
   {
      // Long: SL below confirm candle low
      actualSL = confirmCandle.low - bufferPrice;
   }
   else
   {
      // Short: SL above confirm candle high
      actualSL = confirmCandle.high + bufferPrice;
   }
   
   // Normalize to tick size
   actualSL = MathRound(actualSL / tickSize) * tickSize;

   // khoảng SL tính theo points
   double distPoints = MathAbs(entry - actualSL) / pt;
   if(distPoints <= 0.0) return 0.0;

   double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   if(tickVal <= 0.0) return 0.0;

   // risk cho 1 lot = distPoints * (tickVal/tickSize)
   // vì 1 tickSize ứng với tickVal tiền
   double riskPerLot = distPoints * (tickVal / tickSize);
   if(riskPerLot <= 0.0) return 0.0;

   double vol = riskMoney / riskPerLot;
   return NormalizeVolume(sym, vol);
}

// RR filter (>= RR_Min) - Updated to use average entry price
bool RRAllow(const Signal &s)
{
   if(s.tp_count <= 0 || s.entry_count <= 0) return false;

   // Calculate average entry price
   double avgEntry = 0.0;
   for(int i = 0; i < s.entry_count; i++)
      avgEntry += s.entries[i];
   avgEntry /= (double)s.entry_count;

   double sl    = s.sl;
   double tp1   = s.tps[0];

   double risk   = MathAbs(avgEntry - sl);
   double reward = MathAbs(tp1 - avgEntry);
   if(risk <= 0) return false;

   double rr = reward / risk;
   Log(StringFormat("[RR] %s %s RR 1:%.2f (min 1:%.2f) | Avg Entry=%.5f",
   s.symbol, TFToLabel(s.tf), rr, RR_Min, avgEntry
));

   return (rr >= RR_Min);
}

// build 3 entries inside zone with spacing guard
bool Build3EntriesInZone(const string sym, const SRBox &box, DirType dir, double &e1, double &e2, double &e3)
{
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0) return false;

   double pad = EntryPadPoints * pt;

   if(dir == DIR_LONG)
   {
      e1 = box.top - pad;
      e2 = box.mid;
      e3 = box.bot + pad;
   }
   else
   {
      e1 = box.bot + pad;
      e2 = box.mid;
      e3 = box.top - pad;
   }

   double minGap = MinEntrySpacingPoints * pt;
   if(MathAbs(e1 - e2) < minGap) return false;
   if(MathAbs(e2 - e3) < minGap) return false;

   return true;
}

// ---------------- UPDATED SIGNAL COMPUTE ----------------
// Support LONG: touch => can trade if regime allows; sweep => store candidate (SweepV2) then confirm later
bool ComputeSupportLong(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &prev, const MqlRates &cur,
                        const SRBox &box, const SRBox &boxes[], double atr, MarketRegime reg, Signal &out)
{
      if(box.kind != BOX_SUPPORT) return false;
      if(!RegimeAllows(reg, DIR_LONG, true, box.role)
) return false;


   double bbU, bbM, bbL;
   if(!GetBollinger(sym, tf, bbU, bbM, bbL)) return false;
   double rsi = GetRSI(sym, tf);
   double dExt=0; ENUM_TIMEFRAMES wtf=PERIOD_CURRENT;
if(IsNearHTFExtreme(sym, DIR_LONG, rsi, dExt, wtf))
{
   Log(StringFormat("[BLOCK EXTREME] %s %s LONG near top TF=%s d=%.5f",
      sym, TFToLabel(tf), TFToLabel(wtf), dExt
   ));
   return false;
}

   if(!IsMeanReversionAllowed(bbU, bbL, atr)) return false;

   bool condExtreme = (cur.low <= bbL) || (rsi <= RSI_Oversold);
if(!condExtreme) return false;

// if(!IsWickRejection(cur, DIR_LONG)) return false; // moved to score bonus


bool isTouch = (cur.low <= box.top && cur.close >= box.bot);
bool isSweep = (cur.low < box.bot && cur.close > box.bot);
if(!isTouch && !isSweep) return false;
double range = cur.high - cur.low;
if(range > 0)
{
   double closePos = (cur.close - cur.low) / range; // 0..1
   // touch LONG mà close yếu (đóng dưới nửa cây) => bỏ
   if(isTouch && closePos < 0.55)
   {
      LogSkip(sym, tf, "touch long closePos weak");
      return false;
   }
}

// ===== SR ROLE RULE =====
if(box.role == ROLE_LIQUIDITY)
{
   // Liquidity pool: KHÔNG chơi touch, chỉ chơi sweep-confirm
   if(isSweep)
   {
      if(SweepCandleQuality(cur, box, DIR_LONG))
      {
         RegisterSweepCandidate(sym, tf, DIR_LONG, box, cur);
         Log(StringFormat("[SWEEP REG][LIQ] %s %s LONG mid=%.5f",
            sym, TFToLabel(tf), box.mid
         ));
      }
   }
   return false;
}

// SWEEP: register candidate only, DO NOT trade now
if(isSweep)
{
   if(SweepCandleQuality(cur, box, DIR_LONG))
   {
      RegisterSweepCandidate(sym, tf, DIR_LONG, box, cur);

      Log(StringFormat("[SWEEP REG] %s %s LONG mid=%.5f time=%s",
         sym, TFToLabel(tf),
         box.mid, TimeToString(cur.time, TIME_DATE|TIME_MINUTES)
      ));
   }

   return false; // wait confirm on next candle
}


// TOUCH: trade immediately (normal mean reversion)
out.symbol = sym;
out.tf     = tf;
out.dir    = DIR_LONG;
out.box    = box;
out.reason = "support_touch_bb";

out.bbUpper = bbU;
out.bbMid   = bbM;
out.bbLower = bbL;
out.rsi     = rsi;

double e1,e2,e3;
if(!Build3EntriesInZone(sym, box, DIR_LONG, e1,e2,e3)) return false;

out.entries[0]=e1;
out.entries[1]=e2;
out.entries[2]=e3;
out.entry_count = EntriesPerSetup;

double safeLow = MathMin(cur.low, box.bot);
double slMult = GetSL_ATR_Mult(tf);
out.sl = safeLow - (atr * slMult);

double risk = MathAbs(out.entries[0] - out.sl);
double tpR  = GetTP_R(tf);
double tpByR = out.entries[0] + risk * tpR;

// scalp: tp không vượt quá bbMid (đúng TF, tránh over)
out.tps[0] = MathMin(bbM, tpByR);
out.tp_count = 1;



out.candle_time = cur.time;
out.curHigh  = cur.high;
out.curLow   = cur.low;
out.curClose = cur.close;
out.curOpen  = cur.open;

return true;


}

// Resistance SHORT: touch => regime allows; sweep => store candidate then confirm later
bool ComputeResistanceShort(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &prev, const MqlRates &cur,
                            const SRBox &box, const SRBox &boxes[], double atr, MarketRegime reg, Signal &out)
{
      if(box.kind != BOX_RESISTANCE) return false;

   double bbU, bbM, bbL;
   if(!GetBollinger(sym, tf, bbU, bbM, bbL)) return false;
   double rsi = GetRSI(sym, tf);
   double dExt=0; ENUM_TIMEFRAMES wtf=PERIOD_CURRENT;
if(IsNearHTFExtreme(sym, DIR_SHORT, rsi, dExt, wtf))
{
   Log(StringFormat("[BLOCK EXTREME] %s %s SHORT near bottom TF=%s d=%.5f",
      sym, TFToLabel(tf), TFToLabel(wtf), dExt
   ));
   return false;
}

   if(!IsMeanReversionAllowed(bbU, bbL, atr)) return false;
   if(!RegimeAllows(reg, DIR_SHORT, true, box.role)) return false;

   bool condExtreme = (cur.high >= bbU) || (rsi >= RSI_Overbought);
if(!condExtreme) return false;

// if(!IsWickRejection(cur, DIR_LONG)) return false; // moved to score bonus


bool isTouch = (cur.high >= box.bot && cur.close <= box.top);
bool isSweep = (cur.high > box.top && cur.close < box.top);
if(!isTouch && !isSweep) return false;
double range = cur.high - cur.low;
if(range > 0)
{
   double closePos = (cur.close - cur.low) / range; //0..1
   // touch SHORT mà close yếu (đóng trên nửa cây) => bỏ
   if(isTouch && closePos > 0.45)
   {
      LogSkip(sym, tf, "touch short closePos weak");
      return false;
   }
}

// ===== SR ROLE RULE =====
if(box.role == ROLE_LIQUIDITY)
{
   // Liquidity pool: KHÔNG chơi touch, chỉ chơi sweep-confirm
   if(isSweep)
   {
      if(SweepCandleQuality(cur, box, DIR_SHORT))
      {
         RegisterSweepCandidate(sym, tf, DIR_SHORT, box, cur);
         Log(StringFormat("[SWEEP REG][LIQ] %s %s SHORT mid=%.5f",
            sym, TFToLabel(tf), box.mid
         ));
      }
   }
   return false;
}

if(isSweep)
{
   if(SweepCandleQuality(cur, box, DIR_SHORT))
   {
      RegisterSweepCandidate(sym, tf, DIR_SHORT, box, cur);

      Log(StringFormat("[SWEEP REG] %s %s SHORT mid=%.5f time=%s",
         sym, TFToLabel(tf),
         box.mid, TimeToString(cur.time, TIME_DATE|TIME_MINUTES)
      ));
   }

   return false;
}


// TOUCH trade
out.symbol = sym;
out.tf     = tf;
out.dir    = DIR_SHORT;
out.box    = box;
out.reason = "resistance_touch_bb";

out.bbUpper = bbU;
out.bbMid   = bbM;
out.bbLower = bbL;
out.rsi     = rsi;

double e1,e2,e3;
if(!Build3EntriesInZone(sym, box, DIR_SHORT, e1,e2,e3)) return false;

out.entries[0]=e1;
out.entries[1]=e2;
out.entries[2]=e3;
out.entry_count = EntriesPerSetup;

double safeHigh = MathMax(cur.high, box.top);
double slMult = GetSL_ATR_Mult(tf);
out.sl = safeHigh + (atr * slMult);

double risk = MathAbs(out.sl - out.entries[0]);
double tpR  = GetTP_R(tf);
double tpByR = out.entries[0] - risk * tpR;

out.tps[0] = MathMax(bbM, tpByR);
out.tp_count = 1;



out.candle_time = cur.time;
out.curHigh  = cur.high;
out.curLow   = cur.low;
out.curClose = cur.close;
out.curOpen  = cur.open;

return true;


}

// Break + retest LONG (optional, disabled by default)
bool ComputeBreakResistanceLong(const string sym, ENUM_TIMEFRAMES tf, const MqlRates &prev, const MqlRates &cur,
                                const SRBox &box, const SRBox &boxes[], double atr, Signal &out)
{
   if(Use_Breakout_Trades != ON) return false;

   if(box.kind!=BOX_RESISTANCE) return false;
   if(!(prev.close <= box.top && cur.close > box.top)) return false;

   SRBox flipped = box;
   flipped.kind = BOX_SUPPORT;

   out.symbol = sym;
   out.tf     = tf;
   out.dir    = DIR_LONG;
   out.reason = "break_resistance";
   out.box    = flipped;

   double e1,e2,e3;
   if(!Build3EntriesInZone(sym, flipped, DIR_LONG, e1,e2,e3)) return false;

   out.entries[0]=e1; out.entries[1]=e2; out.entries[2]=e3;
   out.entry_count=EntriesPerSetup;

   out.sl = flipped.bot - (atr>0 ? ATR_SL_Mult*atr : 0.0);

   out.tp_count = TPFromBoxes(DIR_LONG, out.entries[0], boxes, out.tps);
   if(out.tp_count <= 0) return false;

   out.candle_time = cur.time;
   out.curHigh  = cur.high;
   return true;
}

//=========================== PART 4/4 ===============================
// Place Orders + TP Milestone + Expire + News Filter + Timer/Init + Telegram

// ---------------- NEWS FILTER ----------------
class CNewsFilter
{
private:
   void GetCurrencies(string sym, string &base, string &quote)
   {
      base=""; quote="";
      if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "XAG") >= 0 ||
         StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0)
      {
         base="USD"; quote="USD"; return;
      }
      base  = StringSubstr(sym, 0, 3);
      quote = StringSubstr(sym, 3, 3);
   }

public:
   bool IsNewsTime(string sym, int beforeMin, int afterMin, int impactThreshold)
   {
      if(Use_News_Filter == OFF) return false;

      string base="", quote="";
      GetCurrencies(sym, base, quote);

      datetime now = TimeCurrent();
      datetime from = now - (afterMin * 60);
      datetime to   = now + (beforeMin * 60);

      MqlCalendarValue values[];
      if(CalendarValueHistory(values, from, to) <= 0) return false;

      for(int i=0; i<ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event)) continue;
         if(event.importance < impactThreshold) continue;

         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country)) continue;

         string eventCurrency = country.currency;
         if(eventCurrency != "USD" && eventCurrency != base && eventCurrency != quote) continue;

         return true;
      }
      return false;
   }
};
CNewsFilter g_news;

// ---------------- Place 3 limit orders ----------------
bool PlaceSignal(const Signal &s)
{
   if(s.tp_count<=0 || s.entry_count<=0) return false;
   double tp1 = s.tps[0];
   if(tp1<=0) return false;

   string icon = (s.dir==DIR_LONG ? "🟢" : "🔴");
   string side = (s.dir==DIR_LONG ? "BUY" : "SELL");

   // ===== Telegram: SIGNAL format (pretty + 3 entries + RR 1:x) =====
{
   string icon = (s.dir==DIR_LONG ? "🟢" : "🔴");
   string side = (s.dir==DIR_LONG ? "BUY" : "SELL");

   // avg entry
   int nE = s.entry_count;
   double avgE = 0.0;
   for(int i=0;i<nE;i++) avgE += s.entries[i];
   if(nE > 0) avgE /= (double)nE;

   double tp1 = s.tps[0];

   // ===== RR CHUẨN TRADER =====
   double risk   = MathAbs(avgE - s.sl);
   double reward = MathAbs(tp1 - avgE);
   double rr     = (risk > 0.0 ? (reward / risk) : 0.0);


   // entry lines + icons
   string e1 = (nE>=1 ? DoubleToString(s.entries[0], _Digits) : "-");
   string e2 = (nE>=2 ? DoubleToString(s.entries[1], _Digits) : "-");
   string e3 = (nE>=3 ? DoubleToString(s.entries[2], _Digits) : "-");

   string msg =
   icon + " SIGNAL " + side + " " + s.symbol +
   " | TF:" + TFToLabel(s.tf) +
   " | RR:" + DoubleToString(rr, 2) + "\n" +
   "1️⃣ " + e1 + "  |  2️⃣ " + e2 + "  |  3️⃣ " + e3 + "\n" +
   "🛑 SL: " + DoubleToString(s.sl, _Digits) + "\n" +
   "🎯 TP: " + DoubleToString(tp1, _Digits);

   TelegramSend(msg);
}

   if(!AutoTradingAllowed()) return false;
   if(!IsTradable(s.symbol)) return false;
   if(!SpreadOK(s.symbol))   return false;

   if(CountTotalActiveTrades() >= MaxTotalTrades) return false;

   int cntDir = CountPerSymbolTFDir(s.symbol, s.tf, s.dir);
   if(cntDir >= MaxPerSymbolTFPerDir) return false;

// ================= PATCHED PlaceSignal (C3 Eligible Weight) =================
double balNorm = GetNormalizedBalance();
double riskPct = GetRiskPctBySymbol(s.symbol);

double roleMult = RoleRiskMult(s.box.role);
double riskSetupMoney = balNorm * riskPct * roleMult;

int nE = s.entry_count;
if(nE <= 0) return false;

// ---------------- PREP ----------------
double pt = SymbolInfoDouble(s.symbol, SYMBOL_POINT);
if(pt <= 0) pt = 0.00001;

double minDist = 5.0 * pt;   // tránh weight vô hạn

bool   eligible[3] = {false,false,false};
double lossPerLot[3] = {0,0,0};
double dist[3] = {0,0,0};
double w[3] = {0,0,0};
double sumW = 0.0;

// ---------------- STEP 1: xác định entry ELIGIBLE ----------------
for(int i=0;i<nE;i++)
{
   double entry = s.entries[i];

   // bỏ entry duplicate khỏi risk pool
   if(IsDuplicateSetup(s.symbol, s.tf, s.dir, entry, s.sl, tp1))
      continue;

   double lp = LossPerLotToSL(s.symbol, s.dir, entry, s.sl);
   if(lp <= 0.0) continue;

   double d = MathAbs(entry - s.sl);
   if(d < minDist) d = minDist;

   eligible[i]   = true;
   lossPerLot[i]= lp;
   dist[i]      = d;

   // OPTION B: entry càng gần SL càng ăn risk nhiều
   w[i] = 1.0 / d;
   sumW += w[i];
}

if(sumW <= 0.0) return false;

if(VerboseLogs==ON)
{
   Log(StringFormat(
      "[RISK SETUP] %s %s role=%s mult=%.2f setupRisk=%.2f$ eligible=%d/%d",
      s.symbol, TFToLabel(s.tf),
      ZoneRoleToStr(s.box.role), roleMult,
      riskSetupMoney,
      (eligible[0]?1:0)+(eligible[1]?1:0)+(eligible[2]?1:0),
      nE
   ));
}

trade.SetExpertMagicNumber((long)MagicNumber);
trade.SetDeviationInPoints(50);

bool any=false;

// ---------------- STEP 2: place lệnh – risk redistribute ----------------
for(int i=0;i<nE;i++)
{
   if(!eligible[i]) continue;

   double entry = s.entries[i];

   double riskMoney_i = riskSetupMoney * (w[i] / sumW);

   double vol = 0.0;

// ===== SEPARATE RISK FOR CRYPTO =====
if(Use_Crypto_Risk_Separate==ON && IsCryptoSymbol(s.symbol))
{
   // Build confirm candle from signal data
   MqlRates confirmCandle;
   confirmCandle.high = s.curHigh;
   confirmCandle.low = s.curLow;
   confirmCandle.close = s.curClose;
   confirmCandle.open = s.curOpen;
   
   // dùng entry & SL thật của từng entry => chia risk đúng
   // For crypto: SL is based on confirm candle extreme (handled inside CalcVolCrypto_ByRisk)
   vol = CalcVolCrypto_ByRisk(s.symbol, s.tf, s.dir, entry, s.sl, riskMoney_i, confirmCandle);

   if(VerboseLogs==ON)
      Log(StringFormat("[CRYPTO RISK] %s E%d alloc=%.2f$ vol=%.4f",
                       s.symbol, (i+1), riskMoney_i, vol));
}
else
{
   vol = riskMoney_i / lossPerLot[i];
   vol = NormalizeVolume(s.symbol, vol);
}

if(vol <= 0) continue;


   // ---- SAFETY: min lot không được phá risk quá mạnh ----
   double minLot=0.0;
   SymbolInfoDouble(s.symbol, SYMBOL_VOLUME_MIN, minLot);
   if(minLot > 0.0)
   {
      double riskMinLot = lossPerLot[i] * minLot;
      if(riskMinLot > riskMoney_i * 1.35)
      {
         if(VerboseLogs==ON)
            Log(StringFormat(
               "[RISK SKIP] %s E%d minLotRisk=%.2f$ > alloc=%.2f$",
               s.symbol, (i+1), riskMinLot, riskMoney_i
            ));
         continue;
      }
   }

   if(VerboseLogs==ON)
      Log(StringFormat(
         "[RISK ELIG] %s E%d entry=%.5f dist=%.1fpt loss/lot=%.2f$ alloc=%.2f$ vol=%.2f",
         s.symbol, (i+1),
         entry,
         dist[i]/pt,
         lossPerLot[i],
         riskMoney_i,
         vol
      ));

   string cmt = StringFormat("E%d|%s|%s|TP1=%.5f",
                             (i+1), s.reason, TFToLabel(s.tf), tp1);

   // Safety checks for stops level and freeze level
   double tickSize = SymbolInfoDouble(s.symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) tickSize = pt;
   
   // Normalize prices to tick size
   double normalizedEntry = MathRound(entry / tickSize) * tickSize;
   double normalizedSL = MathRound(s.sl / tickSize) * tickSize;
   double normalizedTP = MathRound(tp1 / tickSize) * tickSize;
   
   // Check stops level
   long stopsLevel = SymbolInfoInteger(s.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double stopsLevelPrice = stopsLevel * pt;
   
   double bid = SymbolInfoDouble(s.symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(s.symbol, SYMBOL_ASK);
   
   if(s.dir == DIR_LONG)
   {
      // For buy limit: entry must be below ask by at least stops level
      if(normalizedEntry >= ask - stopsLevelPrice && stopsLevel > 0)
      {
         if(VerboseLogs==ON)
            Log(StringFormat("[STOPS LEVEL] %s E%d entry too close to market", s.symbol, (i+1)));
         continue;
      }
      // SL distance check
      if(MathAbs(normalizedEntry - normalizedSL) < stopsLevelPrice && stopsLevel > 0)
      {
         if(VerboseLogs==ON)
            Log(StringFormat("[STOPS LEVEL] %s E%d SL too close to entry", s.symbol, (i+1)));
         continue;
      }
   }
   else
   {
      // For sell limit: entry must be above bid by at least stops level
      if(normalizedEntry <= bid + stopsLevelPrice && stopsLevel > 0)
      {
         if(VerboseLogs==ON)
            Log(StringFormat("[STOPS LEVEL] %s E%d entry too close to market", s.symbol, (i+1)));
         continue;
      }
      // SL distance check
      if(MathAbs(normalizedSL - normalizedEntry) < stopsLevelPrice && stopsLevel > 0)
      {
         if(VerboseLogs==ON)
            Log(StringFormat("[STOPS LEVEL] %s E%d SL too close to entry", s.symbol, (i+1)));
         continue;
      }
   }

   bool ok=false;
   if(s.dir==DIR_LONG)
      ok = trade.BuyLimit(vol, normalizedEntry, s.symbol, normalizedSL, normalizedTP, ORDER_TIME_GTC, 0, cmt);
   else
      ok = trade.SellLimit(vol, normalizedEntry, s.symbol, normalizedSL, normalizedTP, ORDER_TIME_GTC, 0, cmt);

   if(ok)
   {
      any=true;
      TelegramSend(StringFormat(
         "✅ PLACE %s %s E%d\nEntry=%.2f Vol=%.2f\nRisk=%.2f$",
         side, s.symbol, (i+1), entry, vol, riskMoney_i
      ));
   }
   else
   {
      Log(StringFormat(
         "[ORDER FAIL] %s %s E%d err=%d",
         side, s.symbol, (i+1), GetLastError()
      ));
   }
}

return any;
}

// ---- TP storage (simple: only TP1 milestone) ----
string GV_TP1(long ticket)    { return "TP1_"+(string)MagicNumber+"_"+(string)ticket; }
string GV_TP1HIT(long ticket) { return "TP1HIT_"+(string)MagicNumber+"_"+(string)ticket; }
string GV_TRAIL(long ticket)  { return "TRAIL_"+(string)MagicNumber+"_"+(string)ticket; }

void SaveTPLevelsForTicket(long ticket, double tp1)
{
   GlobalVariableSet(GV_TP1(ticket), tp1);
   GlobalVariableSet(GV_TP1HIT(ticket), 0.0);
   GlobalVariableSet(GV_TRAIL(ticket), 0.0);
}

bool LoadTP1ForTicket(long ticket, double &tp1, bool &hit1, bool &trailOn)
{
   if(!GlobalVariableCheck(GV_TP1(ticket))) return false;
   tp1 = GlobalVariableGet(GV_TP1(ticket));
   hit1 = GlobalVariableCheck(GV_TP1HIT(ticket)) && GlobalVariableGet(GV_TP1HIT(ticket))>0.5;
   trailOn = GlobalVariableCheck(GV_TRAIL(ticket)) && GlobalVariableGet(GV_TRAIL(ticket))>0.5;
   return true;
}

bool ParseTPFromComment(string cmt, string key, double &outVal)
{
   int pos = StringFind(cmt, key);
   if(pos<0) return false;
   string sub = StringSubstr(cmt, pos+StringLen(key));
   outVal = StringToDouble(sub);
   return true;
}

// Helper: Calculate average entry price for all positions with same symbol and direction
double CalcAvgEntryPrice(string sym, long posType)
{
   double totalVol = 0.0;
   double weightedPrice = 0.0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      if(PositionGetInteger(POSITION_TYPE) != posType) continue;
      
      double vol = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      
      weightedPrice += price * vol;
      totalVol += vol;
   }
   
   if(totalVol > 0.0)
      return weightedPrice / totalVol;
   
   return 0.0;
}
   outVal = 0.0;
   int p = StringFind(cmt, key+"=");
   if(p < 0) return false;

   string sub = StringSubstr(cmt, p + StringLen(key) + 1);
   int q = StringFind(sub, "|");
   if(q > 0) sub = StringSubstr(sub, 0, q);

   outVal = StringToDouble(sub);
   return (outVal > 0.0);
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong deal = trans.deal;
   if(deal == 0) return;
   if(!HistoryDealSelect(deal)) return;

   long mg = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
   if((ulong)mg != MagicNumber) return;

   long entryType = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entryType != DEAL_ENTRY_IN) return;

   string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
   long posId = (long)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   if(posId <= 0) return;

   string cmt = request.comment;
   if(StringLen(cmt) <= 0) cmt = HistoryDealGetString(deal, DEAL_COMMENT);

   double tp1=0.0;
   ParseTPFromComment(cmt, "TP1", tp1);

   if(tp1 <= 0.0)
   {
      if(PositionSelect(sym))
      {
         if((ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            tp1 = PositionGetDouble(POSITION_TP);
      }
   }

   if(tp1 > 0.0)
   {
      SaveTPLevelsForTicket(posId, tp1);
      Log(StringFormat("[TP SAVE] %s pos=%d tp1=%.5f", sym, posId, tp1));
   }
}

// ---- TP manage: TP1 -> partial + BE + trailing ----
void ManageTPMilestones()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      string sym = PositionGetString(POSITION_SYMBOL);

      double tp1=0;
      bool hit1=false, trailOn=false;
      if(!LoadTP1ForTicket((long)ticket, tp1, hit1, trailOn)) continue;

      long type = (long)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double sl  = PositionGetDouble(POSITION_SL);
      double tp  = PositionGetDouble(POSITION_TP);

      double bid=SymbolInfoDouble(sym,SYMBOL_BID);
      double ask=SymbolInfoDouble(sym,SYMBOL_ASK);

      bool reach1=false;
      if(type==POSITION_TYPE_BUY)  reach1 = (bid >= tp1);
      if(type==POSITION_TYPE_SELL) reach1 = (ask <= tp1);

      if(tp1>0 && reach1 && !hit1)
      {
         GlobalVariableSet(GV_TP1HIT((long)ticket), 1.0);

         if(PartialClosePct > 0.0 && PartialClosePct < 100.0)
         {
            double closeVol = vol * (PartialClosePct / 100.0);
            closeVol = NormalizeVolume(sym, closeVol);

            double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
            if(closeVol >= minLot && (vol - closeVol) >= minLot)
               trade.PositionClosePartial(ticket, closeVol);
         }

         trade.PositionModify(sym, openPrice, tp);
         GlobalVariableSet(GV_TRAIL((long)ticket), 1.0);

         TelegramSend(StringFormat("✅ TP1 HIT %s | Ticket=%d\nMove SL -> BE\nTP1=%.5f",
                                   sym, ticket, tp1));
      }

      if(trailOn && Use_RR_Trailing==ON)
      {
         double cur = (type==POSITION_TYPE_BUY)? bid : ask;

         // Use average entry price for RR calculation
         double avgEntry = CalcAvgEntryPrice(sym, type);
         if(avgEntry <= 0.0) avgEntry = openPrice; // fallback to single entry

         double risk = MathAbs(avgEntry - sl);
         if(risk <= 0) continue;

         double rr = (type==POSITION_TYPE_BUY) ? ((cur - avgEntry) / risk)
                                               : ((avgEntry - cur) / risk);

// ===== C5-A: AUTO BE @ 1R =====
if(rr >= 1.0)
{
   if(type==POSITION_TYPE_BUY && sl < openPrice)
   {
      trade.PositionModify(sym, openPrice, tp);
      if(VerboseLogs==ON) Log("[C5] BUY BE @1R " + sym);
   }
   if(type==POSITION_TYPE_SELL && sl > openPrice)
   {
      trade.PositionModify(sym, openPrice, tp);
      if(VerboseLogs==ON) Log("[C5] SELL BE @1R " + sym);
   }
}

// ===== C5-B: CLOSE WORST ENTRY @ >=1.2R =====
if(rr >= 1.2)
{
   // tránh spam: mỗi symbol/side chỉ đóng 1 lần trong vòng 5 phút
   string gv = "C5_WORST_" + sym + "_" + (type==POSITION_TYPE_BUY ? "B" : "S");
   if(!GlobalVariableCheck(gv) || (TimeCurrent() - (datetime)GlobalVariableGet(gv) > 300))
   {
      if(CloseWorstPositionBySymbol(sym, type))
      {
         GlobalVariableSet(gv, (double)TimeCurrent());
         TelegramSend("✂️ C5 CLOSE WORST @1.2R " + sym);
      }
   }
}

// ===== C5-C: EXIT ON REVERSAL AFTER PROFIT =====
if(rr >= 1.0)
{
   // Lấy 1 cây nến đã đóng gần nhất của chính symbol (TF hiện tại của chart)
   ENUM_TIMEFRAMES tfNow = (ENUM_TIMEFRAMES)Period();
   MqlRates c[];
   ArraySetAsSeries(c,true);
   if(CopyRates(sym, tfNow, 1, 1, c) == 1)
   {
      // RSI tại TF đó
      double rsiNow = GetRSI(sym, tfNow);

      bool reversal = false;

      if(type==POSITION_TYPE_BUY)
      {
         // đang BUY mà RSI cao + nến có wick reject xuống => có thể đảo
         if(rsiNow >= 65.0 && IsWickRejection(c[0], DIR_SHORT))
            reversal = true;
      }
      else
      {
         // đang SELL mà RSI thấp + nến có wick reject lên => có thể đảo
         if(rsiNow <= 35.0 && IsWickRejection(c[0], DIR_LONG))
            reversal = true;
      }

      if(reversal)
      {
         if(trade.PositionClose(ticket))
            TelegramSend("🚨 C5 EXIT REVERSAL >1R " + sym);
      }
   }
}


         if(rr < RR_Trail_Start) continue;

         int stepIndex = (int)MathFloor((rr - RR_Trail_Start) / RR_Trail_Step);
         double lockRR = RR_Trail_Start + stepIndex * RR_Trail_Step;

         double newSL = (type==POSITION_TYPE_BUY) ? (openPrice + lockRR*risk)
                                                  : (openPrice - lockRR*risk);

         if(type==POSITION_TYPE_BUY && newSL > sl)  trade.PositionModify(sym, newSL, tp);
         if(type==POSITION_TYPE_SELL && newSL < sl) trade.PositionModify(sym, newSL, tp);
         
      }
   }
}




//=========================== SCALP RR RESCUE (RR2/RR3 close worst entry) ===========================

// close "worst entry" for the symbol + side
// BUY: worst = highest open (đu đỉnh nhất)
// SELL: worst = lowest open (đu đáy nhất)
bool CloseWorstPositionBySymbol(string sym, long posType)
{
   double worstPrice = (posType==POSITION_TYPE_BUY ? -DBL_MAX : DBL_MAX);
   ulong  worstTicket = 0;

   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      if((long)PositionGetInteger(POSITION_TYPE) != posType) continue;

      double op = PositionGetDouble(POSITION_PRICE_OPEN);

      if(posType==POSITION_TYPE_BUY)
      {
         if(op > worstPrice) { worstPrice = op; worstTicket = tk; }
      }
      else
      {
         if(op < worstPrice) { worstPrice = op; worstTicket = tk; }
      }
   }

   if(worstTicket==0) return false;
   return trade.PositionClose(worstTicket);
}


// ---- Expire pending limits ----
void CancelExpiredLimits()
{
   datetime now = TimeCurrent();

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT) continue;

      string sym = OrderGetString(ORDER_SYMBOL);
      string cmt = OrderGetString(ORDER_COMMENT);

      ENUM_TIMEFRAMES tf = PERIOD_M15;
      if(StringFind(cmt,"M5")  >= 0) tf = PERIOD_M5;
      if(StringFind(cmt,"M15") >= 0) tf = PERIOD_M15;
      if(StringFind(cmt,"M30") >= 0) tf = PERIOD_M30;
      if(StringFind(cmt,"H1")  >= 0) tf = PERIOD_H1;
      if(StringFind(cmt,"H4")  >= 0) tf = PERIOD_H4;

      int expireMin = GetExpireMinutesByTF(tf);
      datetime setupTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int aliveMin = (int)((now - setupTime) / 60);

      if(aliveMin >= expireMin)
      {
         trade.OrderDelete(ticket);
         TelegramSend(StringFormat("⌛ LIMIT EXPIRED %s TF:%s\nCanceled after %d minutes",
                                   sym, TFToLabel(tf), aliveMin));
      }
   }
}

// ---- Init TF ----
void InitTF()
{
   g_tfCount=0;
   if(TF_M5==ON)  g_tfs[g_tfCount++]=PERIOD_M5;
   if(TF_M15==ON) g_tfs[g_tfCount++]=PERIOD_M15;
   if(TF_M30==ON) g_tfs[g_tfCount++]=PERIOD_M30;
   if(TF_H1==ON)  g_tfs[g_tfCount++]=PERIOD_H1;
   if(TF_H4==ON)  g_tfs[g_tfCount++]=PERIOD_H4;
   if(TF_H12==ON) g_tfs[g_tfCount++]=PERIOD_H12;
}

// ---- OnInit / OnDeinit ----
int OnInit()
{
   InitTF();
   EventSetTimer(MathMax(5, ScanIntervalSeconds));

   string tmp[5];
   int n=0;
   if(Symbol1!=NONE) tmp[n++] = EnumToSymbol(Symbol1);
   if(Symbol2!=NONE) tmp[n++] = EnumToSymbol(Symbol2);
   if(Symbol3!=NONE) tmp[n++] = EnumToSymbol(Symbol3);
   if(Symbol4!=NONE) tmp[n++] = EnumToSymbol(Symbol4);
   if(Symbol5!=NONE) tmp[n++] = EnumToSymbol(Symbol5);

   g_symbolCount=n;
   ArrayResize(g_symbols, g_symbolCount);
   for(int i=0;i<g_symbolCount;i++)
   {
      g_symbols[i]=tmp[i];
      SymbolSelect(g_symbols[i], true);
   }

   ArrayResize(g_lastClosed, g_symbolCount*6 + 10);
   ArrayInitialize(g_lastClosed, 0);
   ArrayResize(g_lastScan, g_symbolCount*6 + 10);
   ArrayInitialize(g_lastScan, 0);

   ArrayResize(g_sweeps, 0);

   double balNorm = GetNormalizedBalance();
   Log(StringFormat("EA init. Symbols=%d Currency=%s BalRaw=%.2f BalNorm=%.2f",
                    g_symbolCount, AccountInfoString(ACCOUNT_CURRENCY),
                    AccountInfoDouble(ACCOUNT_BALANCE), balNorm));

   if(UseTelegram==ON)
      TelegramSend(StringFormat("🛡️ An toàn là trên hết đã khởi động\nSymbols=%d | MaxTrades=%d",
                          g_symbolCount, MaxTotalTrades));

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Log("EA deinit. reason=" + IntegerToString(reason));
}


// ---- OnTimer scan ----
void OnTimer()
{
   CancelExpiredLimits();
   ManageTPMilestones();
   ManageScalpRRRescue();

   
   
   // ---- DAILY QUOTA RESET ----
   int dk = DayKey(TimeCurrent());
   if(dk != g_dayKey)
   {
      g_dayKey = dk;
      g_dailyCount = 0;
   }
   
   
   // nếu đã đạt quota thì khỏi scan nữa
   if(g_dailyCount >= DailyMaxSignals)
      return;

   for(int s=0; s<g_symbolCount; s++)
   {
      string sym = g_symbols[s];
      if(StringLen(sym)==0) continue;

      for(int t=0; t<g_tfCount; t++)
      {
         ENUM_TIMEFRAMES tf = g_tfs[t];

         // Apply symbol-specific timeframe filter
         if(!IsSymbolTFAllowed(sym, tf))
         {
            if(VerboseLogs==ON)
               Log(StringFormat("[SKIP TF] %s %s not allowed for this symbol", sym, TFToLabel(tf)));
            continue;
         }

         if(!SymbolSelect(sym,true)) continue;
         if(Bars(sym, tf) < 220) continue;

         MqlRates r[];
         ArraySetAsSeries(r,true);

         int got = CopyRates(sym, tf, 0, SR_KlinesLimit, r);
         if(got < 220) continue;

         MqlRates cur  = r[1];
         MqlRates prev = r[2];

         int idx = s*6 + t;
if(cur.time <= g_lastClosed[idx]) continue;

// chưa set ở đây


         if(Use_News_Filter==ON && g_news.IsNewsTime(sym, News_Before_Min, News_After_Min, News_Impact_Level))
            continue;

         double atr14   = CalcATR(r, ATR_Length);
         double atrLong = CalcATR(r, ATR_LongLen);

         SRBox boxes[];
         int bn = BuildSRBoxes(r, boxes);
         if(bn<=0)
         {
            // Fix g_lastClosed processing: update even when SR build fails
            g_lastClosed[idx] = cur.time;
            continue;
         }
         // TỚI ĐÂY MỚI SET
g_lastClosed[idx] = cur.time;
         for(int i=0;i<bn;i++)
         
{
   EvaluateZoneRole(r, got, atr14, boxes[i]);

   // debug log (tuỳ chọn)
   if(VerboseLogs==ON)
      Log(StringFormat("[SR ROLE] %s %s zone[%d] %.2f-%.2f => %s(%d)",
         sym, TFToLabel(tf), i,
         boxes[i].bot, boxes[i].top,
         ZoneRoleToStr(boxes[i].role), boxes[i].roleScore
      ));
}

         MarketRegime reg = DetectRegime(sym, tf, r, got, atr14, atrLong);

         if(Use_Regime_Filter==ON && VerboseLogs==ON)
            Log(StringFormat("[REGIME] %s %s => %d", sym, TFToLabel(tf), (int)reg));

         // 1) First try to confirm any stored sweep candidates on THIS new candle close
         Signal sweepSig;
         if(TryConfirmSweep(sym, tf, cur, prev, boxes, atr14, sweepSig))
         {
            // regime gate: confirm trades are still mean reversion at SR
            if(RegimeAllows(reg, sweepSig.dir, true, sweepSig.box.role))
            {
           
               // dedup key
               string keyS = sweepSig.symbol + "|" + TFToLabel(sweepSig.tf) + "|" +
                             (sweepSig.dir==DIR_LONG?"BUY":"SELL") + "|" +
                             DoubleToString(NormalizeDouble(sweepSig.box.mid, 5), 5) + "|" +
                             IntegerToString((int)sweepSig.candle_time);

               if(!SeenKey(keyS))
               {
                  RememberKey(keyS);
                  // Candle confirmation (nếu bật)
                  
if(Use_Score_Filter==ON)
{
   int sc = SignalScore(sweepSig, cur, atr14);
   if(VerboseLogs==ON)
      Log(StringFormat("[SCORE] %s %s sweep score=%d", sym, TFToLabel(tf), sc));
   int need = GetMinScoreByTF(tf);
if(sc < need) continue;

}

// PassDistTF gate: only for ROLE_DISTRIBUTION zones in sweep signals too
if(!PassDistTF(tf, sweepSig.box))
{
   if(VerboseLogs==ON)
      Log(StringFormat("[DIST GATE] %s %s DIST roleScore=%d < min=%d (sweep)",
         sym, TFToLabel(tf), sweepSig.box.roleScore, GetDistMinByTF(tf)));
   continue;
}


if(PlaceSignal(sweepSig))
{
   g_dailyCount++;
   if(g_dailyCount >= DailyMaxSignals) return;
}



               }
            }
         }

         // 2) Build fresh signals from SR boxes (touch trades + register sweeps)
         for(int i=0;i<bn;i++)
         {
            Signal sg;
            bool ok=false;

            if(ComputeSupportLong(sym, tf, prev, cur, boxes[i], boxes, atr14, reg, sg)) ok=true;
            if(!ok && ComputeResistanceShort(sym, tf, prev, cur, boxes[i], boxes, atr14, reg, sg)) ok=true;
            if(!ok && ComputeBreakResistanceLong(sym, tf, prev, cur, boxes[i], boxes, atr14, sg)) ok=true;
            if(!ok) continue;

            if(ZoneBusy(sg.symbol, sg.tf, sg.dir, sg.box)) continue;

            string key = sg.symbol + "|" + TFToLabel(sg.tf) + "|" +
                         (sg.dir==DIR_LONG?"BUY":"SELL") + "|" +
                         DoubleToString(NormalizeDouble(sg.box.mid, 5), 5) + "|" +
                         IntegerToString((int)sg.candle_time);

            if(SeenKey(key)) continue;
            RememberKey(key);

if(Use_Candle_Confirm==ON && !ConfirmEntryCandleOnly(sg)) continue;
if(Use_RR_Gate==ON && !RRAllow(sg)) continue;

// PassDistTF gate: only for ROLE_DISTRIBUTION zones
if(!PassDistTF(sg.tf, sg.box))
{
   if(VerboseLogs==ON)
      Log(StringFormat("[DIST GATE] %s %s DIST roleScore=%d < min=%d",
         sg.symbol, TFToLabel(sg.tf), sg.box.roleScore, GetDistMinByTF(sg.tf)));
   continue;
}

// SCORE gate (đặt TRƯỚC khi place)
if(Use_Score_Filter==ON)
{
   int sc = SignalScore(sg, cur, atr14);

   if(VerboseLogs==ON)
      Log(StringFormat("[SCORE] %s %s %s score=%d",
         sg.symbol, TFToLabel(sg.tf),
         (sg.dir==DIR_LONG?"LONG":"SHORT"), sc
      ));

   int need = GetMinScoreByTF(sg.tf);
if(sc < need) continue;
}


if(PlaceSignal(sg))
{
   g_dailyCount++;
   if(g_dailyCount >= DailyMaxSignals) return;
}


         }
      }
   }
}

//==================== RR SCALP RESCUE (2R/3R) ====================
string GV_RR2DONE(string sym, long posType)
{
   string side = (posType==POSITION_TYPE_BUY ? "BUY" : "SELL");
   return "RR2_"+(string)MagicNumber+"_"+sym+"_"+side;
}
string GV_RR3DONE(string sym, long posType)
{
   string side = (posType==POSITION_TYPE_BUY ? "BUY" : "SELL");
   return "RR3_"+(string)MagicNumber+"_"+sym+"_"+side;
}


void ManageScalpRRRescue()
{
   if(Use_RR_Scalp_Manager!=ON) return;

   for(int s=0; s<g_symbolCount; s++)
   {
      string sym = g_symbols[s];
      if(StringLen(sym)==0) continue;

      int buyCnt=0, sellCnt=0;
      ulong anyBuy=0, anySell=0;

      // đếm số lệnh đang mở theo symbol + magic
      for(int i=0;i<PositionsTotal();i++)
      {
         ulong tk = PositionGetTicket(i);
         if(tk==0) continue;
         if(!PositionSelectByTicket(tk)) continue;

         if((ulong)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL)!=sym) continue;

         long type = (long)PositionGetInteger(POSITION_TYPE);
         if(type==POSITION_TYPE_BUY)  { buyCnt++;  if(anyBuy==0)  anyBuy=tk;  }
         if(type==POSITION_TYPE_SELL) { sellCnt++; if(anySell==0) anySell=tk; }
      }

      // =========================
      // BUY rescue
      // =========================
      if(buyCnt>=2 && anyBuy!=0 && PositionSelectByTicket(anyBuy))
      {
         double sl  = PositionGetDouble(POSITION_SL);
         double tp  = PositionGetDouble(POSITION_TP);
         double bid = SymbolInfoDouble(sym,SYMBOL_BID);

         // Use average entry price for RR calculation
         double avgEntry = CalcAvgEntryPrice(sym, POSITION_TYPE_BUY);
         if(avgEntry <= 0.0) avgEntry = PositionGetDouble(POSITION_PRICE_OPEN); // fallback

         double risk = MathAbs(avgEntry - sl);
         if(risk>0)
         {
            double rr = (bid - avgEntry) / risk;

            // RR >= BE: kéo SL về avg entry
            if(rr >= RR_BE_At && sl < avgEntry)
               trade.PositionModify(anyBuy, avgEntry, tp);

            // RR >= 2R: đóng WORST entry 1 lần
            if(rr >= RR_Take1 &&
               (!GlobalVariableCheck(GV_RR2DONE(sym, POSITION_TYPE_BUY)) ||
                 GlobalVariableGet  (GV_RR2DONE(sym, POSITION_TYPE_BUY)) < 0.5))
            {
               if(CloseWorstPositionBySymbol(sym, POSITION_TYPE_BUY))
               {
                  GlobalVariableSet(GV_RR2DONE(sym, POSITION_TYPE_BUY), 1.0);

                  TelegramSend(
                     "🧹 RR2 SCALP RESCUE\n"
                     "━━━━━━━━━━━━━━\n"
                     "📍 Symbol: " + sym + "\n"
                     "📈 Direction: BUY\n"
                     "🧱 Action: Close WORST entry\n"
                     "🎯 Status: RR ≥ 2R\n"
                     "⚡ Mode: Scalp rescue\n"
                     "━━━━━━━━━━━━━━"
                  );
               }
            }

            // RR >= 3R: đóng thêm WORST entry 1 lần
            if(rr >= RR_Take2 &&
               (!GlobalVariableCheck(GV_RR3DONE(sym, POSITION_TYPE_BUY)) ||
                 GlobalVariableGet  (GV_RR3DONE(sym, POSITION_TYPE_BUY)) < 0.5))
            {
               if(CloseWorstPositionBySymbol(sym, POSITION_TYPE_BUY))
               {
                  GlobalVariableSet(GV_RR3DONE(sym, POSITION_TYPE_BUY), 1.0);

                  TelegramSend(
                     "🔥 RR3 SCALP CLEANUP\n"
                     "━━━━━━━━━━━━━━\n"
                     "📍 Symbol: " + sym + "\n"
                     "📈 Direction: BUY\n"
                     "🧱 Action: Close WORST entry\n"
                     "🎯 Status: RR ≥ 3R\n"
                     "💎 Only best entry left\n"
                     "━━━━━━━━━━━━━━"
                  );
               }
            }
         }
      }

      // =========================
      // SELL rescue
      // =========================
      if(sellCnt>=2 && anySell!=0 && PositionSelectByTicket(anySell))
      {
         double sl  = PositionGetDouble(POSITION_SL);
         double tp  = PositionGetDouble(POSITION_TP);
         double ask = SymbolInfoDouble(sym,SYMBOL_ASK);

         // Use average entry price for RR calculation
         double avgEntry = CalcAvgEntryPrice(sym, POSITION_TYPE_SELL);
         if(avgEntry <= 0.0) avgEntry = PositionGetDouble(POSITION_PRICE_OPEN); // fallback

         double risk = MathAbs(sl - avgEntry);
         if(risk>0)
         {
            double rr = (avgEntry - ask) / risk;

            // RR >= BE: kéo SL về avg entry
            if(rr >= RR_BE_At && sl > avgEntry)
               trade.PositionModify(anySell, avgEntry, tp);

            // RR >= 2R: đóng WORST entry 1 lần
            if(rr >= RR_Take1 &&
               (!GlobalVariableCheck(GV_RR2DONE(sym, POSITION_TYPE_SELL)) ||
                 GlobalVariableGet  (GV_RR2DONE(sym, POSITION_TYPE_SELL)) < 0.5))
            {
               if(CloseWorstPositionBySymbol(sym, POSITION_TYPE_SELL))
               {
                  GlobalVariableSet(GV_RR2DONE(sym, POSITION_TYPE_SELL), 1.0);

                  TelegramSend(
                     "🧹 RR2 SCALP RESCUE\n"
                     "━━━━━━━━━━━━━━\n"
                     "📍 Symbol: " + sym + "\n"
                     "📉 Direction: SELL\n"
                     "🧱 Action: Close WORST entry\n"
                     "🎯 Status: RR ≥ 2R\n"
                     "⚡ Mode: Scalp rescue\n"
                     "━━━━━━━━━━━━━━"
                  );
               }
            }

            // RR >= 3R: đóng thêm WORST entry 1 lần
            if(rr >= RR_Take2 &&
               (!GlobalVariableCheck(GV_RR3DONE(sym, POSITION_TYPE_SELL)) ||
                 GlobalVariableGet  (GV_RR3DONE(sym, POSITION_TYPE_SELL)) < 0.5))
            {
               if(CloseWorstPositionBySymbol(sym, POSITION_TYPE_SELL))
               {
                  GlobalVariableSet(GV_RR3DONE(sym, POSITION_TYPE_SELL), 1.0);

                  TelegramSend(
                     "🔥 RR3 SCALP CLEANUP\n"
                     "━━━━━━━━━━━━━━\n"
                     "📍 Symbol: " + sym + "\n"
                     "📉 Direction: SELL\n"
                     "🧱 Action: Close WORST entry\n"
                     "🎯 Status: RR ≥ 3R\n"
                     "💎 Only best entry left\n"
                     "━━━━━━━━━━━━━━"
                  );
               }
            }
         }
      }
   }
}

// ---- Telegram ----
bool TelegramSend(string text)
{
   if(UseTelegram!=ON) return false;
   if(StringLen(TelegramToken)<10 || TelegramChatID==0) return false;

   string url = "https://api.telegram.org/bot" + TelegramToken + "/sendMessage";

   string enc = text;
   StringReplace(enc, "%", "%25");
   StringReplace(enc, " ", "%20");
   StringReplace(enc, "\n", "%0A");
   StringReplace(enc, "#", "%23");
   StringReplace(enc, "&", "%26");
   StringReplace(enc, "+", "%2B");

   string body = "chat_id=" + (string)TelegramChatID + "&text=" + enc;

   if(TelegramTopicID > 0)
      body += "&message_thread_id=" + IntegerToString(TelegramTopicID);

   uchar post[];
   StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);

   uchar result[];
   string headers;
   int timeout = 5000;

   ResetLastError();
   int res = WebRequest("POST", url,
                        "application/x-www-form-urlencoded; charset=utf-8",
                        timeout, post, result, headers);

   if(TelegramDebugLog==ON)
   {
      string resp = CharArrayToString(result, 0, -1, CP_UTF8);
      Log(StringFormat("[TG] code=%d err=%d resp=%s", res, GetLastError(), resp));
   }

   return (res==200);
}

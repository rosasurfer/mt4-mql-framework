/**
 * Global constants and variables.
 */
#property stacksize 32768                                         // According to various MetaQuotes sources the default stacksize per MQL module in 2019 is 256KB
                                                                  // (some even claim 1-8MB). In build 225 the default stacksize was 16KB which at some point had
#include <mqldefines.mqh>                                         // to be increased. Using 32KB has always been sufficient.
#include <win32defines.mqh>                                       //
#include <structs/sizes.mqh>                                      //  @see  https://docs.mql4.com/basis/variables/local#stack
                                                                  //  @see  https://docs.mql4.com/basis/preprosessor/compilation

// global variables
int      __ExecutionContext[EXECUTION_CONTEXT_intSize];           // EXECUTION_CONTEXT
//int    __lpSuperContext;                                        // address of the super EXECUTION_CONTEXT (in indicators loaded by iCustom() and their libraries only)
//int    __lpTestedExpertContext;                                 // im Tester Zeiger auf den ExecutionContext des Experts (noch nicht implementiert)
//int    __CoreFunction;                                          // the core function currently executed by the MQL main module: CF_INIT|CF_START|CF_DEINIT
bool     __isChart;                                               // Whether the program runs on a visible chart. FALSE only during testing if "VisualMode=Off" or "Optimization=On".

bool     __STATUS_HISTORY_UPDATE;                                 // History-Update wurde getriggert
bool     __STATUS_OFF;                                            // Programm komplett abgebrochen (switched off)
int      __STATUS_OFF.reason;                                     // Ursache für Programmabbruch: Fehlercode (kann, muß aber nicht gesetzt sein)

double   Pip;                                                     // Betrag eines Pips des aktuellen Symbols (z.B. 0.0001 = Pip-Size)
int      PipDigits;                                               // Digits eines Pips des aktuellen Symbols (Annahme: Pip sind gradzahlig)
int      PipPoints;                                               // Dezimale Auflösung eines Pips des aktuellen Symbols (mögliche Werte: 1 oder 10)
string   PriceFormat="", PipPriceFormat="";                       // Preisformate des aktuellen Symbols für NumberToStr()
int      Ticks;                                                   // number of times MQL::start() was called (value survives init cycles, also in indicators)
datetime Tick.time;                                               // server time of the last received tick
bool     Tick.isVirtual;
int      ChangedBars;                                             // in indicators, it holds: Bars = ChangedBars + UnchangedBars                   (in experts and scripts: always -1)
int      UnchangedBars, ValidBars;                                // in indicators: UnchangedBars with alias ValidBars, same as IndicatorCounted() (in experts and scripts: always -1)
int      ShiftedBars;                                             // in indicators: non-zero in offline charts only                                (in experts and scripts: always -1)

int      last_error;                                              // last error of the current execution
int      prev_error;                                              // last error of the previous start() call

int      __orderStack[];                                          // FIFO stack of selected orders (per MQL module)


// special constants
#define NULL                        0
#define EMPTY_STR                   ""
#define MAX_STRING_LITERAL          "..............................................................................................................................................................................................................................................................."

#define HTML_TAB                    "&Tab;"                       // tab                        \t
#define HTML_BRVBAR                 "&brvbar;"                    // broken vertical bar        |
#define HTML_PIPE                   HTML_BRVBAR                   // pipe (alias)               |
#define HTML_LCUB                   "&lcub;"                      // left curly brace           {
#define HTML_RCUB                   "&rcub;"                      // right curly brace          }
#define HTML_APOS                   "&apos;"                      // apostrophe                 '
#define HTML_DQUOTE                 "&quot;"                      // double quote               "
#define HTML_SQUOTE                 HTML_APOS                     // single quote (alias)       '
#define HTML_COMMA                  "&comma;"                     // comma                      ,


// Special variables: werden in init() definiert, da in MQL nicht constant deklarierbar
double  NaN;                                                      // -1.#IND: indefinite quiet Not-a-Number (auf x86 CPUs immer negativ)
double  P_INF;                                                    //  1.#INF: positive infinity
double  N_INF;                                                    // -1.#INF: negative infinity, @see  http://blogs.msdn.com/b/oldnewthing/archive/2013/02/21/10395734.aspx


// Magic characters zur visuellen Darstellung von nicht darstellbaren Zeichen in binären Strings, siehe BufferToStr()
#define PLACEHOLDER_NUL_CHAR        '…'                           // 0x85 (133) - Ersatzzeichen für NUL-Bytes in Strings
#define PLACEHOLDER_CTRL_CHAR       '•'                           // 0x95 (149) - Ersatzzeichen für Control-Characters in Strings


// Mathematische Konstanten (internally 15 correct decimal digits)
#define Math.E                      2.7182818284590452354         // base of natural logarythm
#define Math.PI                     3.1415926535897932384


// MQL program types
#define PT_INDICATOR                PROGRAMTYPE_INDICATOR         // 1
#define PT_EXPERT                   PROGRAMTYPE_EXPERT            // 2
#define PT_SCRIPT                   PROGRAMTYPE_SCRIPT            // 4


// MQL module types (flags)
#define MT_INDICATOR                MODULETYPE_INDICATOR          // 1
#define MT_EXPERT                   MODULETYPE_EXPERT             // 2
#define MT_SCRIPT                   MODULETYPE_SCRIPT             // 4
#define MT_LIBRARY                  MODULETYPE_LIBRARY            // 8


// MQL program core function ids
#define CF_INIT                     COREFUNCTION_INIT
#define CF_START                    COREFUNCTION_START
#define CF_DEINIT                   COREFUNCTION_DEINIT


// MQL program launch types
#define LT_TEMPLATE                 LAUNCHTYPE_TEMPLATE           // via template
#define LT_PROGRAM                  LAUNCHTYPE_PROGRAM            // via iCustom()
#define LT_MANUAL                   LAUNCHTYPE_MANUAL             // by hand


// framework InitializeReason codes                               // +-- init reason --------------------------------+-- ui -----------+-- applies --+
#define IR_USER                     INITREASON_USER               // | loaded by the user (also in tester)           |    input dialog |   I, E, S   |   I = indicators
#define IR_TEMPLATE                 INITREASON_TEMPLATE           // | loaded by a template (also at terminal start) | no input dialog |   I, E      |   E = experts
#define IR_PROGRAM                  INITREASON_PROGRAM            // | loaded by iCustom()                           | no input dialog |   I         |   S = scripts
#define IR_PROGRAM_AFTERTEST        INITREASON_PROGRAM_AFTERTEST  // | loaded by iCustom() after end of test         | no input dialog |   I         |
#define IR_PARAMETERS               INITREASON_PARAMETERS         // | input parameters changed                      |    input dialog |   I, E      |
#define IR_TIMEFRAMECHANGE          INITREASON_TIMEFRAMECHANGE    // | chart period changed                          | no input dialog |   I, E      |
#define IR_SYMBOLCHANGE             INITREASON_SYMBOLCHANGE       // | chart symbol changed                          | no input dialog |   I, E      |
#define IR_RECOMPILE                INITREASON_RECOMPILE          // | reloaded after recompilation                  | no input dialog |   I, E      |
#define IR_TERMINAL_FAILURE         INITREASON_TERMINAL_FAILURE   // | terminal failure                              |    input dialog |      E      |   @see https://github.com/rosasurfer/mt4-mql/issues/1
                                                                  // +-----------------------------------------------+-----------------+-------------+

// UninitializeReason codes
#define UR_UNDEFINED                UNINITREASON_UNDEFINED
#define UR_REMOVE                   UNINITREASON_REMOVE
#define UR_RECOMPILE                UNINITREASON_RECOMPILE
#define UR_CHARTCHANGE              UNINITREASON_CHARTCHANGE
#define UR_CHARTCLOSE               UNINITREASON_CHARTCLOSE
#define UR_PARAMETERS               UNINITREASON_PARAMETERS
#define UR_ACCOUNT                  UNINITREASON_ACCOUNT
#define UR_TEMPLATE                 UNINITREASON_TEMPLATE
#define UR_INITFAILED               UNINITREASON_INITFAILED
#define UR_CLOSE                    UNINITREASON_CLOSE


// account types
#define ACCOUNT_TYPE_DEMO           1
#define ACCOUNT_TYPE_REAL           2


// TimeToStr() flags
#define TIME_DATE                   1
#define TIME_MINUTES                2
#define TIME_SECONDS                4
#define TIME_FULL                   7           // TIME_DATE | TIME_MINUTES | TIME_SECONDS


// DateTime2() flags
#define DATE_OF_ERA                 1           // relative to the era (1970-01-01)
#define DATE_OF_TODAY               2           // relative to today


// ParseTime() flags
#define DATE_YYYYMMDD               1           // 1980.07.19
#define DATE_DDMMYYYY               2           // 19.07.1980
//efine DATE_YEAR_OPTIONAL          4
//efine DATE_MONTH_OPTIONAL         8
//efine DATE_DAY_OPTIONAL          16
#define DATE_OPTIONAL              28           // (DATE_YEAR_OPTIONAL | DATE_MONTH_OPTIONAL | DATE_DAY_OPTIONAL)

//efine TIME_SECONDS_OPTIONAL      32
//efine TIME_MINUTES_OPTIONAL      64
//efine TIME_HOURS_OPTIONAL       128
#define TIME_OPTIONAL             224           // (TIME_HOURS_OPTIONAL | TIME_MINUTES_OPTIONAL | TIME_SECONDS_OPTIONAL)


// ParseTime() result element indexes
#define PT_YEAR                     0
#define PT_MONTH                    1
#define PT_DAY                      2
#define PT_HAS_DATE                 3
#define PT_HOUR                     4
#define PT_MINUTE                   5
#define PT_SECOND                   6
#define PT_HAS_TIME                 7
#define PT_ERROR                    8           // string*


// timeframe identifier
#define PERIOD_M1                   1           // 1 Minute
#define PERIOD_M5                   5           // 5 Minuten
#define PERIOD_M15                 15           // 15 Minuten
#define PERIOD_M30                 30           // 30 Minuten
#define PERIOD_H1                  60           // 1 Stunde
#define PERIOD_H4                 240           // 4 Stunden
#define PERIOD_D1                1440           // 1 Tag
#define PERIOD_W1               10080           // 1 Woche (7 Tage)
#define PERIOD_MN1              43200           // 1 Monat (30 Tage)
#define PERIOD_Q1              129600           // 1 Quartal (3 Monate)


// Arrayindizes für Timezone-Transitionsdaten
#define TRANSITION_TIME             0
#define TRANSITION_OFFSET           1
#define TRANSITION_DST              2


// Object property ids, siehe ObjectSet()
#define OBJPROP_TIME1               0
#define OBJPROP_PRICE1              1
#define OBJPROP_TIME2               2
#define OBJPROP_PRICE2              3
#define OBJPROP_TIME3               4
#define OBJPROP_PRICE3              5
#define OBJPROP_COLOR               6
#define OBJPROP_STYLE               7
#define OBJPROP_WIDTH               8
#define OBJPROP_BACK                9
#define OBJPROP_RAY                10
#define OBJPROP_ELLIPSE            11
#define OBJPROP_SCALE              12
#define OBJPROP_ANGLE              13
#define OBJPROP_ARROWCODE          14
#define OBJPROP_TIMEFRAMES         15
#define OBJPROP_DEVIATION          16
#define OBJPROP_FONTSIZE          100
#define OBJPROP_CORNER            101
#define OBJPROP_XDISTANCE         102
#define OBJPROP_YDISTANCE         103
#define OBJPROP_FIBOLEVELS        200
#define OBJPROP_LEVELCOLOR        201
#define OBJPROP_LEVELSTYLE        202
#define OBJPROP_LEVELWIDTH        203
#define OBJPROP_FIRSTLEVEL0       210
#define OBJPROP_FIRSTLEVEL1       211
#define OBJPROP_FIRSTLEVEL2       212
#define OBJPROP_FIRSTLEVEL3       213
#define OBJPROP_FIRSTLEVEL4       214
#define OBJPROP_FIRSTLEVEL5       215
#define OBJPROP_FIRSTLEVEL6       216
#define OBJPROP_FIRSTLEVEL7       217
#define OBJPROP_FIRSTLEVEL8       218
#define OBJPROP_FIRSTLEVEL9       219
#define OBJPROP_FIRSTLEVEL10      220
#define OBJPROP_FIRSTLEVEL11      221
#define OBJPROP_FIRSTLEVEL12      222
#define OBJPROP_FIRSTLEVEL13      223
#define OBJPROP_FIRSTLEVEL14      224
#define OBJPROP_FIRSTLEVEL15      225
#define OBJPROP_FIRSTLEVEL16      226
#define OBJPROP_FIRSTLEVEL17      227
#define OBJPROP_FIRSTLEVEL18      228
#define OBJPROP_FIRSTLEVEL19      229
#define OBJPROP_FIRSTLEVEL20      230
#define OBJPROP_FIRSTLEVEL21      231
#define OBJPROP_FIRSTLEVEL22      232
#define OBJPROP_FIRSTLEVEL23      233
#define OBJPROP_FIRSTLEVEL24      234
#define OBJPROP_FIRSTLEVEL25      235
#define OBJPROP_FIRSTLEVEL26      236
#define OBJPROP_FIRSTLEVEL27      237
#define OBJPROP_FIRSTLEVEL28      238
#define OBJPROP_FIRSTLEVEL29      239
#define OBJPROP_FIRSTLEVEL30      240
#define OBJPROP_FIRSTLEVEL31      241


// chart object visibility flags, see ObjectSet(label, OBJPROP_TIMEFRAMES, ...)
#define OBJ_PERIOD_M1          0x0001           //   1: object is shown on M1 charts
#define OBJ_PERIOD_M5          0x0002           //   2: object is shown on M5 charts
#define OBJ_PERIOD_M15         0x0004           //   4: object is shown on M15 charts
#define OBJ_PERIOD_M30         0x0008           //   8: object is shown on M30 charts
#define OBJ_PERIOD_H1          0x0010           //  16: object is shown on H1 charts
#define OBJ_PERIOD_H4          0x0020           //  32: object is shown on H4 charts
#define OBJ_PERIOD_D1          0x0040           //  64: object is shown on D1 charts
#define OBJ_PERIOD_W1          0x0080           // 128: object is shown on W1 charts
#define OBJ_PERIOD_MN1         0x0100           // 256: object is shown on MN1 charts
#define OBJ_PERIODS_ALL        0x01FF           // 511: object is shown on all timeframes (same as specifying NULL)
#define OBJ_PERIODS_NONE       EMPTY            //  -1: object is hidden on all timeframes


// name sanitizer modes for ProgramName(), ModuleName() and FullModuleName()
#define MODE_RAW               0
#define MODE_NICE              1


// modes to specify the pool to select an order from; see OrderSelect()
#define MODE_TRADES            0
#define MODE_HISTORY           1


// ids to control the order selection stack; see OrderPush(), OrderPop()
#define O_PUSH                 1
#define O_POP                  2


// default order display colors
#define CLR_OPEN_PENDING       DeepSkyBlue
#define CLR_OPEN_LONG          C'0,0,254'       // blue-ish: rgb(0,0,255) - rgb(1,1,1)
#define CLR_OPEN_SHORT         C'254,0,0'       // red-ish:  rgb(255,0,0) - rgb(1,1,1)
#define CLR_OPEN_TAKEPROFIT    LimeGreen
#define CLR_OPEN_STOPLOSS      Red

#define CLR_CLOSED_LONG        Blue             // entry marker      As "open" and "closed" entry markers use the same symbol
#define CLR_CLOSED_SHORT       Red              // entry marker      they must be slightly different to be able to distinguish them.
#define CLR_CLOSED             Orange           // exit marker


// timeseries identifiers, see ArrayCopySeries(), iLowest(), iHighest()
#define MODE_OPEN                         0     // open price
#define MODE_LOW                          1     // low price
#define MODE_HIGH                         2     // high price
#define MODE_CLOSE                        3     // close price
#define MODE_VOLUME                       4     // volume
#define MODE_TIME                         5     // bar open time


// MA method identifiers, see iMA()
#define MODE_SMA                          0     // simple moving average
#define MODE_EMA                          1     // exponential moving average
#define MODE_SMMA                         2     // smoothed moving average, same as EMA: SMMA(n) = EMA(2*n-1)
#define MODE_LWMA                         3     // linear weighted moving average
#define MODE_ALMA                         4     // Arnaud Legoux moving average


// indicator drawing shapes
#define DRAW_LINE                         0     // drawing line
#define DRAW_SECTION                      1     // drawing sections
#define DRAW_HISTOGRAM                    2     // drawing histogram
#define DRAW_ARROW                        3     // drawing arrows (symbols)
#define DRAW_ZIGZAG                       4     // drawing sections between even and odd indicator buffers
#define DRAW_NONE                         2     // no drawing


// indicator line styles
#define STYLE_SOLID                       0     // pen is solid
#define STYLE_DASH                        1     // pen is dashed
#define STYLE_DOT                         2     // pen is dotted
#define STYLE_DASHDOT                     3     // pen has alternating dashes and dots
#define STYLE_DASHDOTDOT                  4     // pen has alternating dashes and double dots


// indicator line identifiers, see iMACD(), iRVI(), iStochastic()
#define MODE_MAIN                         0     // main indicator line
#define MODE_SIGNAL                       1     // signal line

// indicator line identifiers, see iADX()
#define MODE_MAIN                         0     // base indicator line
#define MODE_PLUSDI                       1     // +DI indicator line
#define MODE_MINUSDI                      2     // -DI indicator line

// indicator line identifiers, see iBands(), iEnvelopes(), iEnvelopesOnArray(), iFractals(), iGator()
#define MODE_UPPER                        1     // upper line
#define MODE_LOWER                        2     // lower line

#define B_LOWER                           0     // custom
#define B_UPPER                           1     // custom


// custom indicator buffer identifiers
#define Bands.MODE_MA                     0     // MA value
#define Bands.MODE_UPPER                  1     // upper band value
#define Bands.MODE_LOWER                  2     // lower band value

#define Broketrader.MODE_MA               6     // Broketrader SMA value
#define Broketrader.MODE_TREND            7     // Broketrader trend direction and length

#define Fisher.MODE_MAIN          MODE_MAIN     // Fisher Transform main line (0)
#define Fisher.MODE_SECTION               1     // Fisher Transform section and section length

#define FDI.MODE_MAIN             MODE_MAIN     // Fractal Dimension main line (0)

#define HeikinAshi.MODE_OPEN              0     // Heikin-Ashi bar open price
#define HeikinAshi.MODE_CLOSE             1     // Heikin-Ashi bar close price
#define HeikinAshi.MODE_TREND             4     // Heikin-Ashi trend direction and length

#define HalfTrend.MODE_MAIN       MODE_MAIN     // HalfTrend SR line (0)
#define HalfTrend.MODE_TREND              1     // HalfTrend trend direction and length

#define MACD.MODE_MAIN            MODE_MAIN     // MACD main line (0)
#define MACD.MODE_SECTION                 1     // MACD section and section length

#define MMI.MODE_MAIN             MODE_MAIN     // MMI main line (0)

#define MovingAverage.MODE_MA             0     // MA value
#define MovingAverage.MODE_TREND          1     // MA trend direction and length

#define RSI.MODE_MAIN             MODE_MAIN     // RSI main line (0)
#define RSI.MODE_SECTION                  1     // RSI section and section length (midpoint = 50)

#define Slope.MODE_MAIN           MODE_MAIN     // slope main line (0)
#define Slope.MODE_TREND                  1     // slope trend direction and length

#define Stochastic.MODE_MAIN      MODE_MAIN     // Stochastic main line   (0)
#define Stochastic.MODE_SIGNAL  MODE_SIGNAL     // Stochastic signal line (1)
#define Stochastic.MODE_TREND             2     // Stochastic trend direction and length

#define SuperTrend.MODE_MAIN      MODE_MAIN     // SuperTrend SR line (0)
#define SuperTrend.MODE_TREND             1     // SuperTrend trend direction and length

#define ZigZag.MODE_SEMAPHORE_OPEN        0     // ZigZag semaphore open price
#define ZigZag.MODE_SEMAPHORE_CLOSE       1     // ZigZag semaphore close price
#define ZigZag.MODE_UPPER_BAND            2     // ZigZag upper channel band
#define ZigZag.MODE_LOWER_BAND            3     // ZigZag lower channel band
#define ZigZag.MODE_UPPER_CROSS           4     // ZigZag upper channel band crossing
#define ZigZag.MODE_LOWER_CROSS           5     // ZigZag lower channel band crossing
#define ZigZag.MODE_REVERSAL              6     // ZigZag leg reversal
#define ZigZag.MODE_TREND                 7     // ZigZag trend (combined known and unknown trend)


// sorting modes, see ArraySort()
#define MODE_ASC                          1     // ascending
#define MODE_DESC                         2     // descending
#define MODE_ASCEND                MODE_ASC     // MetaQuotes aliases
#define MODE_DESCEND              MODE_DESC


// Market info identifiers, see MarketInfo()
#define MODE_LOW                          1     // session low price (since midnight server time)
#define MODE_HIGH                         2     // session high price (since midnight server time)
//                                        3     // ?
//                                        4     // ?
#define MODE_TIME                         5     // last tick time
//                                        6     // ?
//                                        7     // ?
//                                        8     // ?
#define MODE_BID                          9     // last bid price                           (entspricht Bid bzw. Close[0])
#define MODE_ASK                         10     // last ask price                           (entspricht Ask)
#define MODE_POINT                       11     // point size in the quote currency         (entspricht Point)               price resolution, e.g.: 0.0000'1
#define MODE_DIGITS                      12     // number of digits after the decimal point (entspricht Digits)
#define MODE_SPREAD                      13     // spread value in points
#define MODE_STOPLEVEL                   14     // min. required stop/limit distance to be able to open an order in point (bucket shops only)
#define MODE_LOTSIZE                     15     // units of 1 lot                                                                                     100'000
#define MODE_TICKVALUE                   16     // tick value in the account currency
#define MODE_TICKSIZE                    17     // tick size in the quote currency                                        multiple of 1 point, e.g.: 0.0000'5
#define MODE_SWAPLONG                    18     // swap of long positions
#define MODE_SWAPSHORT                   19     // swap of short positions
#define MODE_STARTING                    20     // contract starting date (Futures)
#define MODE_EXPIRATION                  21     // contract expiration date (Futures)
#define MODE_TRADEALLOWED                22     // whether trading of the symbol is allowed
#define MODE_MINLOT                      23     // min. tradable lot size
#define MODE_LOTSTEP                     24     // min. lot increment size
#define MODE_MAXLOT                      25     // max. tradable lot size
#define MODE_SWAPTYPE                    26     // swap calculation method: 0 - in points; 1 - in base currency; 2 - by interest; 3 - in margin currency
#define MODE_PROFITCALCMODE              27     // profit calculation mode: 0 - Forex; 1 - CFD; 2 - Futures
#define MODE_MARGINCALCMODE              28     // margin calculation mode: 0 - Forex; 1 - CFD; 2 - Futures; 3 - CFD for indices
#define MODE_MARGININIT                  29     // units with margin requirement for opening a position of 1 lot        (0 = entsprechend MODE_MARGINREQUIRED)  100.000  @see (1)
#define MODE_MARGINMAINTENANCE           30     // units with margin requirement to maintain an open positions of 1 lot (0 = je nach Account-Stopoutlevel)               @see (2)
#define MODE_MARGINHEDGED                31     // units with margin requirement for a hedged position of 1 lot                                                  50.000
#define MODE_MARGINREQUIRED              32     // free margin requirement to open a position of 1 lot
#define MODE_FREEZELEVEL                 33     // min. required price distance to be able to modify an order in point (bucket shops only)
                                                //
                                                // (1) MARGIN_INIT (in Units) müßte, wenn es gesetzt ist, die eigentliche Marginrate sein. MARGIN_REQUIRED (in Account-Currency)
                                                //     könnte höher und MARGIN_MAINTENANCE niedriger sein (MARGIN_INIT wird z.B. von IC Markets gesetzt).
                                                //
                                                // (2) Ein Account-Stopoutlevel < 100% ist gleichbedeutend mit einem einheitlichen MARGIN_MAINTENANCE < MARGIN_INIT über alle
                                                //     Instrumente. Eine vom Stopoutlevel des Accounts abweichende MARGIN_MAINTENANCE einzelner Instrumente ist vermutlich nur
                                                //     bei einem Stopoutlevel von 100% sinnvoll. Beides zusammen ist ziemlich verwirrend.

/*
 The ENUM_SYMBOL_CALC_MODE enumeration provides information about how a symbol's margin requirements are calculated.

 @link  https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants#enum_symbol_calc_mode
+------------------------------+--------------------------------------------------------------+-------------------------------------------------------------+
| SYMBOL_CALC_MODE_FOREX       | Forex mode                                                   | Margin: Lots*ContractSize/Leverage                          |
|                              | calculation of profit and margin for Forex                   | Profit: (Close-Open)*ContractSize*Lots                      |
+------------------------------+--------------------------------------------------------------+-------------------------------------------------------------+
| SYMBOL_CALC_MODE_FUTURES     | Futures mode                                                 | Margin: Lots*InitialMargin*Percentage/100                   |
|                              | calculation of margin and profit for futures                 | Profit: (Close-Open)*TickPrice/TickSize*Lots                |
+------------------------------+--------------------------------------------------------------+-------------------------------------------------------------+
| SYMBOL_CALC_MODE_CFD         | CFD mode                                                     | Margin: Lots*ContractSize*MarketPrice*Percentage/100        |
|                              | calculation of margin and profit for CFD                     | Profit: (Close-Open)*ContractSize*Lots                      |
+------------------------------+--------------------------------------------------------------+-------------------------------------------------------------+
| SYMBOL_CALC_MODE_CFDINDEX    | CFD index mode                                               | Margin: (Lots*ContractSize*MarketPrice)*TickPrice/TickSize  |
|                              | calculation of margin and profit for CFD by indexes          | Profit: (Close-Open)*ContractSize*Lots                      |
+------------------------------+--------------------------------------------------------------+-------------------------------------------------------------+
| SYMBOL_CALC_MODE_CFDLEVERAGE | CFD leverage mode                                            | Margin: (Lots*ContractSize*MarketPrice*Percentage)/Leverage |
|                              | calculation of margin and profit for CFD at leverage trading | Profit: (Close-Open)*ContractSize*Lots                      |
+------------------------------+--------------------------------------------------------------+-------------------------------------------------------------+
*/


// Profit calculation modes, siehe MarketInfo(MODE_PROFITCALCMODE)
#define PCM_FOREX                      0
#define PCM_CFD                        1
#define PCM_FUTURES                    2


// Margin calculation modes, siehe MarketInfo(MODE_MARGINCALCMODE)
#define MCM_FOREX                      0
#define MCM_CFD                        1
#define MCM_CFD_FUTURES                2
#define MCM_CFD_INDEX                  3
#define MCM_CFD_LEVERAGE               4        // nur MetaTrader 5


// Free margin calculation modes, siehe AccountFreeMarginMode()
#define FMCM_USE_NO_PL                 0        // floating profits/losses of open positions are not used for calculation (only account balance)
#define FMCM_USE_PL                    1        // both floating profits and floating losses of open positions are used for calculation
#define FMCM_USE_PROFITS_ONLY          2        // only floating profits of open positions are used for calculation
#define FMCM_USE_LOSSES_ONLY           3        // only floating losses of open positions are used for calculation


// Margin stopout modes, siehe AccountStopoutMode()
#define MSM_PERCENT                    0
#define MSM_ABSOLUTE                   1


// swap types, see MarketInfo(MODE_SWAPTYPE)    // per day for 1 lot
#define SCM_POINTS                     0        // in points (quote currency), Forex standard
#define SCM_BASE_CURRENCY              1        // as amount of base currency   (see "symbols.raw")
#define SCM_INTEREST                   2        // in percentage terms
#define SCM_MARGIN_CURRENCY            3        // as amount of margin currency (see "symbols.raw")


// Symbol types, siehe struct SYMBOL
#define SYMBOL_TYPE_FOREX              1
#define SYMBOL_TYPE_CFD                2
#define SYMBOL_TYPE_INDEX              3
#define SYMBOL_TYPE_FUTURES            4


// IDs for positioning objects, see ObjectSet(label, OBJPROP_CORNER, ...)
#define CORNER_TOP_LEFT                0        // default
#define CORNER_TOP_RIGHT               1
#define CORNER_BOTTOM_LEFT             2
#define CORNER_BOTTOM_RIGHT            3


// Currency-IDs
#define CID_AUD                        1
#define CID_CAD                        2
#define CID_CHF                        3
#define CID_EUR                        4
#define CID_GBP                        5
#define CID_JPY                        6
#define CID_NZD                        7
#define CID_USD                        8        // zuerst die IDs der LFX-Indizes, dadurch "passen" diese in 3 Bits (für LFX-Tickets)

#define CID_CNY                        9
#define CID_CZK                       10
#define CID_DKK                       11
#define CID_HKD                       12
#define CID_HRK                       13
#define CID_HUF                       14
#define CID_INR                       15
#define CID_LTL                       16
#define CID_LVL                       17
#define CID_MXN                       18
#define CID_NOK                       19
#define CID_PLN                       20
#define CID_RUB                       21
#define CID_SAR                       22
#define CID_SEK                       23
#define CID_SGD                       24
#define CID_THB                       25
#define CID_TRY                       26
#define CID_TWD                       27
#define CID_ZAR                       28


// Currency-Kürzel
#define C_AUD                      "AUD"
#define C_CAD                      "CAD"
#define C_CHF                      "CHF"
#define C_CNY                      "CNY"
#define C_CZK                      "CZK"
#define C_DKK                      "DKK"
#define C_EUR                      "EUR"
#define C_GBP                      "GBP"
#define C_HKD                      "HKD"
#define C_HRK                      "HRK"
#define C_HUF                      "HUF"
#define C_INR                      "INR"
#define C_JPY                      "JPY"
#define C_LTL                      "LTL"
#define C_LVL                      "LVL"
#define C_MXN                      "MXN"
#define C_NOK                      "NOK"
#define C_NZD                      "NZD"
#define C_PLN                      "PLN"
#define C_RUB                      "RUB"
#define C_SAR                      "SAR"
#define C_SEK                      "SEK"
#define C_SGD                      "SGD"
#define C_USD                      "USD"
#define C_THB                      "THB"
#define C_TRY                      "TRY"
#define C_TWD                      "TWD"
#define C_ZAR                      "ZAR"


// FileOpen() modes (flags)
#define FILE_READ                      1
#define FILE_WRITE                     2
#define FILE_BIN                       4
#define FILE_CSV                       8


// File pointer positioning modes, siehe FileSeek()
#define SEEK_SET                       0        // from begin of file
#define SEEK_CUR                       1        // from current position
#define SEEK_END                       2        // from end of file


// Data types, siehe FileRead()/FileWrite()
#define CHAR_VALUE                     1        // char:   1 byte
#define SHORT_VALUE                    2        // WORD:   2 byte
#define LONG_VALUE                     4        // DWORD:  4 byte
#define FLOAT_VALUE                    4        // float:  4 byte
#define DOUBLE_VALUE                   8        // double: 8 byte


// FindFileNames() flags
#define FF_SORT                        1        // Ergebnisse von NTFS-Laufwerken sind immer sortiert
#define FF_DIRSONLY                    2
#define FF_FILESONLY                   4


// Flag zum Schreiben von Historyfiles
#define HST_BUFFER_TICKS               1
#define HST_SKIP_DUPLICATE_TICKS       2        // aufeinanderfolgende identische Ticks innerhalb einer Bar werden nicht geschrieben
#define HST_FILL_GAPS                  4
#define HST_TIME_IS_OPENTIME           8


// MessageBox() flags
#define MB_OK                       0x00000000  // buttons
#define MB_OKCANCEL                 0x00000001
#define MB_YESNO                    0x00000004
#define MB_YESNOCANCEL              0x00000003
#define MB_ABORTRETRYIGNORE         0x00000002
#define MB_CANCELTRYCONTINUE        0x00000006
#define MB_RETRYCANCEL              0x00000005
#define MB_HELP                     0x00004000  // additional help button

#define MB_DEFBUTTON1               0x00000000  // default button
#define MB_DEFBUTTON2               0x00000100
#define MB_DEFBUTTON3               0x00000200
#define MB_DEFBUTTON4               0x00000300

#define MB_ICONEXCLAMATION          0x00000030  // icons
#define MB_ICONWARNING      MB_ICONEXCLAMATION
#define MB_ICONINFORMATION          0x00000040
#define MB_ICONASTERISK     MB_ICONINFORMATION
#define MB_ICONQUESTION             0x00000020
#define MB_ICONSTOP                 0x00000010
#define MB_ICONERROR               MB_ICONSTOP
#define MB_ICONHAND                MB_ICONSTOP
#define MB_USERICON                 0x00000080

#define MB_APPLMODAL                0x00000000  // modality
#define MB_SYSTEMMODAL              0x00001000
#define MB_TASKMODAL                0x00002000

#define MB_DEFAULT_DESKTOP_ONLY     0x00020000  // other
#define MB_RIGHT                    0x00080000
#define MB_RTLREADING               0x00100000
#define MB_SETFOREGROUND            0x00010000
#define MB_TOPMOST                  0x00040000
#define MB_NOFOCUS                  0x00008000
#define MB_SERVICE_NOTIFICATION     0x00200000

#define MB_DONT_LOG                 0x10000000  // custom: don't log prompt and response


// MessageBox() return codes
#define IDOK                                 1
#define IDCANCEL                             2
#define IDABORT                              3
#define IDRETRY                              4
#define IDIGNORE                             5
#define IDYES                                6
#define IDNO                                 7
#define IDCLOSE                              8
#define IDHELP                               9
#define IDTRYAGAIN                          10
#define IDCONTINUE                          11


// arrow codes, see ObjectSet(label, OBJPROP_ARROWCODE, value)
#define SYMBOL_ORDEROPEN                     1  // right pointing arrow (default open order marker)
//                                           2  // same as SYMBOL_ORDEROPEN
#define SYMBOL_ORDERCLOSE                    3  // left pointing arrow  (default closed order marker)
#define SYMBOL_DASH                          4  // dash symbol          (default takeprofit and stoploss marker)
#define SYMBOL_LEFTPRICE                     5  // left-side price label
#define SYMBOL_RIGHTPRICE                    6  // right-side price label
#define SYMBOL_THUMBSUP                     67  // thumb up symbol
#define SYMBOL_THUMBSDOWN                   68  // thumb down symbol
#define SYMBOL_ARROWUP                     241  // arrow up symbol
#define SYMBOL_ARROWDOWN                   242  // arrow down symbol
#define SYMBOL_STOPSIGN                    251  // stop sign symbol
#define SYMBOL_CHECKSIGN                   252  // checkmark symbol


// String padding types, siehe StringPad()
#define STR_PAD_LEFT                         1
#define STR_PAD_RIGHT                        2
#define STR_PAD_BOTH                         3


// Array IDs für von ArrayCopyRates() definierte Arrays
#define BAR.time                             0
#define BAR.open                             1
#define BAR.low                              2
#define BAR.high                             3
#define BAR.close                            4
#define BAR.volume                           5


// Price-Bar IDs (siehe Historyfunktionen)
#define BAR_T                                0  // (double) datetime
#define BAR_O                                1
#define BAR_H                                2
#define BAR_L                                3
#define BAR_C                                4
#define BAR_V                                5


// Value indexes of the HSL color space (hue, saturation, luminosity). This model is used by the Windows color picker.
#define HSL_HUE                              0  // 0°...360°
#define HSL_SATURATION                       1  // 0%...100%
#define HSL_LIGHTNESS                        2  // 0%...100% (aka luminosity)


// Tester statistics identifiers for MQL5::TesterStatistics(), since build 600
#define STAT_INITIAL_DEPOSIT             99999  // initial deposit                                 (double)
#define STAT_PROFIT                      99999  // net profit: STAT_GROSS_PROFIT + STAT_GROSS_LOSS (double)
#define STAT_GROSS_PROFIT                99999  // sum of all positive trades: => 0                (double)
#define STAT_GROSS_LOSS                  99999  // sum of all negative trades: <= 0                (double)
#define STAT_MAX_PROFITTRADE             99999  // Maximum profit — the largest value of all profitable trades. The value is greater than or equal to zero                          double
#define STAT_MAX_LOSSTRADE               99999  // Maximum loss — the lowest value of all losing trades. The value is less than or equal to zero                                    double
#define STAT_CONPROFITMAX                99999  // Maximum profit in a series of profitable trades. The value is greater than or equal to zero                                      double
#define STAT_CONPROFITMAX_TRADES         99999  // The number of trades that have formed STAT_CONPROFITMAX (maximum profit in a series of profitable trades)                    int
#define STAT_MAX_CONWINS                 99999  // The total profit of the longest series of profitable trades                                                                       double
#define STAT_MAX_CONPROFIT_TRADES        99999  // The number of trades in the longest series of profitable trades STAT_MAX_CONWINS                                            int
#define STAT_CONLOSSMAX                  99999  // Maximum loss in a series of losing trades. The value is less than or equal to zero double
#define STAT_CONLOSSMAX_TRADES           99999  // The number of trades that have formed STAT_CONLOSSMAX (maximum loss in a series of losing trades) int
#define STAT_MAX_CONLOSSES               99999  // The total loss of the longest series of losing trades double
#define STAT_MAX_CONLOSS_TRADES          99999  // The number of trades in the longest series of losing trades STAT_MAX_CONLOSSES int
#define STAT_BALANCEMIN                  99999  // Minimum balance value (double)
#define STAT_BALANCE_DD                  99999  // Maximum balance drawdown in monetary terms (double)
#define STAT_BALANCEDD_PERCENT           99999  // Balance drawdown as a percentage that was recorded at the moment of the maximum balance drawdown in monetary terms (STAT_BALANCE_DD). double
#define STAT_BALANCE_DDREL_PERCENT       99999  // Maximum balance drawdown as a percentage. In the process of trading, a balance may have numerous drawdowns, for each of which the relative drawdown value in percents is calculated. The greatest value is returned double
#define STAT_BALANCE_DD_RELATIVE         99999  // Balance drawdown in monetary terms that was recorded at the moment of the maximum balance drawdown as a percentage (STAT_BALANCE_DDREL_PERCENT). double
#define STAT_EQUITYMIN                   99999  // Minimum equity value double
#define STAT_EQUITY_DD                   99999  // Maximum equity drawdown in monetary terms. In the process of trading, numerous drawdowns may appear on the equity; here the largest value is taken double
#define STAT_EQUITYDD_PERCENT            99999  // Drawdown in percent that was recorded at the moment of the maximum equity drawdown in monetary terms (STAT_EQUITY_DD). double
#define STAT_EQUITY_DDREL_PERCENT        99999  // Maximum equity drawdown as a percentage. In the process of trading, an equity may have numerous drawdowns, for each of which the relative drawdown value in percents is calculated. The greatest value is returned double
#define STAT_EQUITY_DD_RELATIVE          99999  // Equity drawdown in monetary terms that was recorded at the moment of the maximum equity drawdown in percent (STAT_EQUITY_DDREL_PERCENT). double
#define STAT_EXPECTED_PAYOFF             99999  // Expected payoff double
#define STAT_PROFIT_FACTOR               99999  // Profit factor, equal to the ratio of STAT_GROSS_PROFIT/STAT_GROSS_LOSS. If STAT_GROSS_LOSS=0, the profit factor is equal to DBL_MAX double
#define STAT_MIN_MARGINLEVEL             99999  // Minimum value of the margin level double
#define STAT_CUSTOM_ONTESTER             99999  // The value of the calculated custom optimization criterion returned by the OnTester() function double
#define STAT_TRADES                      99999  // The number of trades int
#define STAT_PROFIT_TRADES               99999  // Profitable trades int
#define STAT_LOSS_TRADES                 99999  // Losing trades int
#define STAT_SHORT_TRADES                99999  // Short trades int
#define STAT_LONG_TRADES                 99999  // Long trades int
#define STAT_PROFIT_SHORTTRADES          99999  // Profitable short trades int
#define STAT_PROFIT_LONGTRADES           99999  // Profitable long trades int
#define STAT_PROFITTRADES_AVGCON         99999  // Average length of a profitable series of trades int
#define STAT_LOSSTRADES_AVGCON           99999  // Average length of a losing series of trades int

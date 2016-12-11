/**
 * Globale Konstanten und Variablen
 */
#property stacksize 32768                                   // intern eine normale Konstante

#include <stderror.mqh>
#include <windows.mqh>                                      // Windows constants
#include <shared/defines.h>                                 // in MQL und C++ gemeinsam verwendete Konstanten
#include <structs/sizes.mqh>


// Globale Variablen
int      __ExecutionContext[EXECUTION_CONTEXT.intSize];     // aktueller ExecutionContext
//int    __lpSuperContext;                                  // Zeiger auf einen SuperContext (je Modultyp deklarierte globale Variable, die nur in Indikatoren gesetzt ist)
//int    __lpTestedExpertContext;                           // im Tester Zeiger auf den ExecutionContext des Experts (noch nicht implementiert)
int      __initFlags;
int      __deinitFlags;

string   __NAME__;                                          // Name des aktuellen Programms
int      __WHEREAMI__;                                      // ID der aktuell ausgeführten MQL-Rootfunktion: RF_INIT | RF_START | RF_DEINIT
bool     __CHART;                                           // ob ein Chart existiert (z.B. nicht bei VisualMode=Off oder Optimization=On)
bool     __LOG;                                             // ob das Logging aktiviert ist (defaults: Online=On, Tester=Off), @see IsLogging()
int      __LOG_LEVEL;                                       // TODO: der konfigurierte Loglevel
bool     __LOG_CUSTOM;                                      // ob ein eigenes Logfile benutzt wird
bool     __SMS.alerts;                                      // ob SMS-Benachrichtigungen aktiviert sind
string   __SMS.receiver;                                    // Empfänger-Nr. für SMS-Benachrichtigungen

bool     __STATUS_HISTORY_UPDATE;                           // History-Update wurde getriggert
bool     __STATUS_HISTORY_INSUFFICIENT;                     // History ist oder war nicht ausreichend
bool     __STATUS_RELAUNCH_INPUT;                           // Anforderung, Input-Dialog erneut zu öffnen
bool     __STATUS_INVALID_INPUT;                            // ungültige Parametereingabe im Input-Dialog
bool     __STATUS_OFF;                                      // Programm komplett abgebrochen (switched off)
int      __STATUS_OFF.reason;                               // Ursache für Programmabbruch: Fehlercode (kann, muß aber nicht gesetzt sein)


double   Pip, Pips;                                         // Betrag eines Pips des aktuellen Symbols (z.B. 0.0001 = Pip-Size)
int      PipDigits, SubPipDigits;                           // Digits eines Pips/Subpips des aktuellen Symbols (Annahme: Pips sind gradzahlig)
int      PipPoint, PipPoints;                               // Dezimale Auflösung eines Pips des aktuellen Symbols (Anzahl der möglichen Werte je Pip: 1 oder 10)
double   TickSize;                                          // kleinste Änderung des Preises des aktuellen Symbols je Tick (Vielfaches von Point)
string   PriceFormat, PipPriceFormat, SubPipPriceFormat;    // Preisformate des aktuellen Symbols für NumberToStr()
int      Tick, zTick;                                       // Tick: überlebt Timeframewechsel, zTick: wird bei Timeframewechsel auf 0 (zero) zurückgesetzt
datetime Tick.Time;
datetime Tick.prevTime;
bool     Tick.isVirtual;
int      ValidBars;
int      ChangedBars;
int      ShiftedBars;

int      prev_error;                                        // der letzte Fehler des vorherigen start()-Aufrufs
int      last_error;                                        // der letzte Fehler innerhalb der aktuellen Rootfunktion

string   __Timezones[] = {
   /*0                           =>*/ "server",             // default
   /*TIMEZONE_ID_ALPARI          =>*/ TIMEZONE_ALPARI,
   /*TIMEZONE_ID_AMERICA_NEW_YORK=>*/ TIMEZONE_AMERICA_NEW_YORK,
   /*TIMEZONE_ID_EUROPE_BERLIN   =>*/ TIMEZONE_EUROPE_BERLIN,
   /*TIMEZONE_ID_EUROPE_KIEV     =>*/ TIMEZONE_EUROPE_KIEV,
   /*TIMEZONE_ID_EUROPE_LONDON   =>*/ TIMEZONE_EUROPE_LONDON,
   /*TIMEZONE_ID_EUROPE_MINSK    =>*/ TIMEZONE_EUROPE_MINSK,
   /*TIMEZONE_ID_FXT             =>*/ TIMEZONE_FXT,
   /*TIMEZONE_ID_FXT_MINUS_0200  =>*/ TIMEZONE_FXT_MINUS_0200,
   /*TIMEZONE_ID_GLOBALPRIME     =>*/ TIMEZONE_GLOBALPRIME
   /*TIMEZONE_ID_GMT             =>*/ TIMEZONE_GMT
};


// Special constants
#define NULL                        0
#define INT_MIN            0x80000000                       // -2147483648: kleinster negativer (signed) Integer-Value                       (datetime) INT_MIN = '1901-12-13 20:45:52'
#define INT_MAX            0x7FFFFFFF                       //  2147483647: größter positiver (signed) Integer-Value                         (datetime) INT_MAX = '2038-01-19 03:14:07'
#define NaT                   INT_MIN                       // Not-a-Time = ungültiger DateTime-Value, für die eingebauten MQL-Funktionen gilt: min(datetime) = '1970-01-01 00:00:00'
#define EMPTY_VALUE           INT_MAX                       // MetaQuotes: empty custom indicator value (Integer, kein Double)                  max(datetime) = '2037-12-31 23:59:59'
#define EMPTY_STR                  ""                       //
#define WHOLE_ARRAY                 0                       // MetaQuotes
#define MAX_STRING_LITERAL          "..............................................................................................................................................................................................................................................................."

#define NL                          "\n"                    // new line: StringLen("\n")=1, die MQL-Dateifunktionen schreiben jedoch 0x0D0A (Länge=2)
#define TAB                         "\t"                    // tab

#define HTML_TAB                    "&Tab;"                 // tab                        \t
#define HTML_BRVBAR                 "&brvbar;"              // broken vertical bar        |
#define HTML_PIPE                   HTML_BRVBAR             // alias: pipe                |
#define HTML_LCUB                   "&lcub;"                // left curly brace           {
#define HTML_RCUB                   "&rcub;"                // right curly brace          }
#define HTML_APOS                   "&apos;"                // apostrophe                 '
#define HTML_SQUOTE                 HTML_APOS               // alias: single quote        '
#define HTML_QUOTE                  "&quot;"                // double quote               "
#define HTML_DQUOTE                 HTML_QUOTE              // alias: double quote        "
#define HTML_COMMA                  "&comma;"               // comma                      ,


// Special variables: werden in init() definiert, da in MQL nicht constant deklarierbar
double  NaN;                                                // -1.#IND: indefinite quiet Not-a-Number (auf x86 CPU's immer negativ)
double  P_INF;                                              //  1.#INF: positive infinity
double  N_INF;                                              // -1.#INF: negative infinity (@see  http://blogs.msdn.com/b/oldnewthing/archive/2013/02/21/10395734.aspx)


// Magic characters zur visuellen Darstellung von nicht darstellbaren Zeichen in binären Strings, siehe BufferToStr()
#define PLACEHOLDER_NUL_CHAR        '…'                     // 0x85 (133) - Ersatzzeichen für NUL-Bytes in Strings
#define PLACEHOLDER_CTRL_CHAR       '•'                     // 0x95 (149) - Ersatzzeichen für Control-Characters in Strings


// Mathematische Konstanten
#define Math.PI                     3.1415926535897932384   // intern 15 korrekte Dezimalstellen


// MQL Moduletyp-Flags
#define MT_INDICATOR    MODULETYPE_INDICATOR
#define MT_EXPERT       MODULETYPE_EXPERT
#define MT_SCRIPT       MODULETYPE_SCRIPT
#define MT_LIBRARY      MODULETYPE_LIBRARY


// MQL Root-Funktion-ID's
#define RF_INIT         ROOTFUNCTION_INIT
#define RF_START        ROOTFUNCTION_START
#define RF_DEINIT       ROOTFUNCTION_DEINIT


// Account-Types
#define ACCOUNT_TYPE_DEMO           1
#define ACCOUNT_TYPE_REAL           2


// Time-Flags, siehe TimeToStr()
#define TIME_DATE                   1
#define TIME_MINUTES                2
#define TIME_SECONDS                4
#define TIME_FULL                   7           // TIME_DATE | TIME_MINUTES | TIME_SECONDS


// Timeframe-Identifier, siehe Period()
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
#define I_TRANSITION_TIME           0
#define I_TRANSITION_OFFSET         1
#define I_TRANSITION_DST            2


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


// Object visibility flags, siehe ObjectSet(label, OBJPROP_TIMEFRAMES, ...)
#define OBJ_PERIOD_M1          0x0001           //   1: object is shown on 1-minute charts
#define OBJ_PERIOD_M5          0x0002           //   2: object is shown on 5-minute charts
#define OBJ_PERIOD_M15         0x0004           //   4: object is shown on 15-minute charts
#define OBJ_PERIOD_M30         0x0008           //   8: object is shown on 30-minute charts
#define OBJ_PERIOD_H1          0x0010           //  16: object is shown on 1-hour charts
#define OBJ_PERIOD_H4          0x0020           //  32: object is shown on 4-hour charts
#define OBJ_PERIOD_D1          0x0040           //  64: object is shown on daily charts
#define OBJ_PERIOD_W1          0x0080           // 128: object is shown on weekly charts
#define OBJ_PERIOD_MN1         0x0100           // 256: object is shown on monthly charts
#define OBJ_PERIODS_ALL        0x01FF           // 511: object is shown on all timeframes: {M1 | M5 | M15 | M30 | H1 | H4 | D1 | W1  | MN1}
#define OBJ_PERIODS_NONE       EMPTY            //  -1: object is hidden on all timeframes
#define OBJ_ALL_PERIODS        OBJ_PERIODS_ALL  // MetaQuotes-Alias (zusätzlich hat NULL denselben Effekt wie OBJ_PERIODS_ALL)


// Timeframe-Flags, siehe EventListener.Baropen()
#define F_PERIOD_M1            OBJ_PERIOD_M1    //    1
#define F_PERIOD_M5            OBJ_PERIOD_M5    //    2
#define F_PERIOD_M15           OBJ_PERIOD_M15   //    4
#define F_PERIOD_M30           OBJ_PERIOD_M30   //    8
#define F_PERIOD_H1            OBJ_PERIOD_H1    //   16
#define F_PERIOD_H4            OBJ_PERIOD_H4    //   32
#define F_PERIOD_D1            OBJ_PERIOD_D1    //   64
#define F_PERIOD_W1            OBJ_PERIOD_W1    //  128
#define F_PERIOD_MN1           OBJ_PERIOD_MN1   //  256
#define F_PERIOD_Q1            0x200            //  512
#define F_PERIODS_ALL          0x3FF            // 1023: {M1 | M5 | M15 | M30 | H1 | H4 | D1 | W1  | MN1 | Q1}
#define F_ALL_PERIODS          F_PERIODS_ALL


// Array-Indizes für Timeframe-Operationen
#define I_PERIOD_M1            0
#define I_PERIOD_M5            1
#define I_PERIOD_M15           2
#define I_PERIOD_M30           3
#define I_PERIOD_H1            4
#define I_PERIOD_H4            5
#define I_PERIOD_D1            6
#define I_PERIOD_W1            7
#define I_PERIOD_MN1           8
#define I_PERIOD_Q1            9


// Operation-Types, siehe OrderType()
#define OP_UNDEFINED                  -1        // custom: Default-Wert für nicht initialisierte Variable
#define OP_BUY                         0        // long position
#define OP_LONG                   OP_BUY
#define OP_SELL                        1        // short position
#define OP_SHORT                 OP_SELL
#define OP_BUYLIMIT                    2        // buy limit order
#define OP_SELLLIMIT                   3        // sell limit order
#define OP_BUYSTOP                     4        // stop buy order
#define OP_SELLSTOP                    5        // stop sell order
#define OP_BALANCE                     6        // account debit or credit transaction
#define OP_CREDIT                      7        // margin credit facility (no transaction)
#define OP_TRANSFER                    8        // custom: OP_BALANCE initiiert durch Kunden (Ein-/Auszahlung)
#define OP_VENDOR                      9        // custom: OP_BALANCE initiiert durch Criminal (Swap, sonstiges)


// OrderSelect-ID's zur Steuerung des Stacks der Orderkontexte, siehe OrderPush(), OrderPop() etc.
#define O_PUSH                         1
#define O_POP                          2


// Series array identifier, siehe ArrayCopySeries(), iLowest(), iHighest()
#define MODE_OPEN                      0        // open price
#define MODE_LOW                       1        // low price
#define MODE_HIGH                      2        // high price
#define MODE_CLOSE                     3        // close price
#define MODE_VOLUME                    4        // volume
#define MODE_TIME                      5        // bar open time


// MA method identifiers, siehe iMA()
#define MODE_SMA                       0        // simple moving average
#define MODE_EMA                       1        // exponential moving average
#define MODE_LWMA                      3        // linear weighted moving average
#define MODE_ALMA                      4        // Arnaud Legoux moving average


// Indicator line identifiers, siehe iMACD(), iRVI(), iStochastic()
#define MODE_MAIN                      0        // base indicator line
#define MODE_SIGNAL                    1        // signal line


// Indicator line identifiers, siehe iADX()
#define MODE_MAIN                      0        // base indicator line
#define MODE_PLUSDI                    1        // +DI indicator line
#define MODE_MINUSDI                   2        // -DI indicator line


// Indicator line identifiers, siehe iBands(), iEnvelopes(), iEnvelopesOnArray(), iFractals(), iGator()
#define MODE_UPPER                     1        // upper line
#define MODE_LOWER                     2        // lower line

#define B_LOWER                        0        // custom
#define B_UPPER                        1        // custom


// Indicator drawing shapes
#define DRAW_LINE                      0        // drawing line
#define DRAW_SECTION                   1        // drawing sections
#define DRAW_HISTOGRAM                 2        // drawing histogram
#define DRAW_ARROW                     3        // drawing arrows (symbols)
#define DRAW_ZIGZAG                    4        // drawing sections between even and odd indicator buffers
#define DRAW_NONE                     12        // no drawing


// Indicator line styles
#define STYLE_SOLID                    0        // pen is solid
#define STYLE_DASH                     1        // pen is dashed
#define STYLE_DOT                      2        // pen is dotted
#define STYLE_DASHDOT                  3        // pen has alternating dashes and dots
#define STYLE_DASHDOTDOT               4        // pen has alternating dashes and double dots


// Indicator buffer identifiers zur Verwendung mit iCustom()
#define BUFFER_INDEX_0                 0        // allgemein gültige ID's
#define BUFFER_INDEX_1                 1
#define BUFFER_INDEX_2                 2
#define BUFFER_INDEX_3                 3
#define BUFFER_INDEX_4                 4
#define BUFFER_INDEX_5                 5
#define BUFFER_INDEX_6                 6
#define BUFFER_INDEX_7                 7
#define BUFFER_1          BUFFER_INDEX_0
#define BUFFER_2          BUFFER_INDEX_1
#define BUFFER_3          BUFFER_INDEX_2
#define BUFFER_4          BUFFER_INDEX_3
#define BUFFER_5          BUFFER_INDEX_4
#define BUFFER_6          BUFFER_INDEX_5
#define BUFFER_7          BUFFER_INDEX_6
#define BUFFER_8          BUFFER_INDEX_7

#define MovingAverage.MODE_MA          0        // MA value
#define MovingAverage.MODE_TREND       1        // MA trend direction and length

#define Bands.MODE_UPPER               0        // upper band value
#define Bands.MODE_MAIN                1        // base line (if defined)
#define Bands.MODE_MA    Bands.MODE_MAIN        //
#define Bands.MODE_LOWER               2        // lower band value

#define SuperTrend.MODE_SIGNAL         0        // SuperTrend signal value
#define SuperTrend.MODE_TREND          1        // SuperTrend trend direction and length


// Sorting modes, siehe ArraySort()
#define MODE_ASC                       1        // aufsteigend
#define MODE_DESC                      2        // absteigend
#define MODE_ASCEND             MODE_ASC        // MetaQuotes-Aliasse
#define MODE_DESCEND           MODE_DESC


// Market info identifiers, siehe MarketInfo()
#define MODE_LOW                       1        // session low price (since midnight server time)
#define MODE_HIGH                      2        // session high price (since midnight server time)
//                                     3        // ???
//                                     4        // ???
#define MODE_TIME                      5        // last tick time
//                                     6        // ???
//                                     7        // ???
//                                     8        // ???
#define MODE_BID                       9        // last bid price                           (entspricht Bid bzw. Close[0])
#define MODE_ASK                      10        // last ask price                           (entspricht Ask)
#define MODE_POINT                    11        // point size in the quote currency         (entspricht Point)                           Preisauflösung: 0.0000'1
#define MODE_DIGITS                   12        // number of digits after the decimal point (entspricht Digits)
#define MODE_SPREAD                   13        // spread value in points
#define MODE_STOPLEVEL                14        // stops distance level in points
#define MODE_LOTSIZE                  15        // units of 1 lot                                                                                         100.000
#define MODE_TICKVALUE                16        // tick value in the account currency
#define MODE_TICKSIZE                 17        // tick size in the quote currency                                                 Vielfaches von Point: 0.0000'5
#define MODE_SWAPLONG                 18        // swap of long positions
#define MODE_SWAPSHORT                19        // swap of short positions
#define MODE_STARTING                 20        // contract starting date (usually for futures)
#define MODE_EXPIRATION               21        // contract expiration date (usually for futures)
#define MODE_TRADEALLOWED             22        // if trading is allowed for the symbol
#define MODE_MINLOT                   23        // minimum lot size
#define MODE_LOTSTEP                  24        // minimum lot increment size
#define MODE_MAXLOT                   25        // maximum lot size
#define MODE_SWAPTYPE                 26        // swap calculation method: 0 - in points; 1 - in base currency; 2 - by interest; 3 - in margin currency
#define MODE_PROFITCALCMODE           27        // profit calculation mode: 0 - Forex; 1 - CFD; 2 - Futures
#define MODE_MARGINCALCMODE           28        // margin calculation mode: 0 - Forex; 1 - CFD; 2 - Futures; 3 - CFD for indices
#define MODE_MARGININIT               29        // units with margin requirement for opening a position of 1 lot        (0 = entsprechend MODE_MARGINREQUIRED)  100.000  @see (1)
#define MODE_MARGINMAINTENANCE        30        // units with margin requirement to maintain an open positions of 1 lot (0 = je nach Account-Stopoutlevel)               @see (2)
#define MODE_MARGINHEDGED             31        // units with margin requirement for a hedged position of 1 lot                                                  50.000
#define MODE_MARGINREQUIRED           32        // free margin requirement to open a position of 1 lot
#define MODE_FREEZELEVEL              33        // order freeze level in points
                                                //
                                                // (1) MARGIN_INIT (in Units) müßte, wenn es gesetzt ist, die eigentliche Marginrate sein. MARGIN_REQUIRED (in Account-Currency)
                                                //     könnte höher und MARGIN_MAINTENANCE niedriger sein (MARGIN_INIT wird z.B. von IC Markets gesetzt).
                                                //
                                                // (2) Ein Account-Stopoutlevel < 100% ist gleichbedeutend mit einem einheitlichen MARGIN_MAINTENANCE < MARGIN_INIT über alle
                                                //     Instrumente. Eine vom Stopoutlevel des Accounts abweichende MARGIN_MAINTENANCE einzelner Instrumente ist vermutlich nur
                                                //     bei einem Stopoutlevel von 100% sinnvoll. Beides zusammen ist ziemlich verwirrend.

// Price identifiers, siehe iMA() etc.
#define PRICE_CLOSE                    0        // C
#define PRICE_OPEN                     1        // O
#define PRICE_HIGH                     2        // H
#define PRICE_LOW                      3        // L
#define PRICE_MEDIAN                   4        // (H+L)/2
#define PRICE_TYPICAL                  5        // (H+L+C)/3
#define PRICE_WEIGHTED                 6        // (H+L+C+C)/4
#define PRICE_BID                      7        // Bid
#define PRICE_ASK                      8        // Ask


// Event-Flags
#define EVENT_BAR_OPEN                 1
#define EVENT_ACCOUNT_CHANGE           2
#define EVENT_CHART_CMD                4        // Chart-Command


// Array-Identifier zum Zugriff auf verschiedene Pivotlevel, siehe iPivotLevel()
#define PIVOT_R3                       0
#define PIVOT_R2                       1
#define PIVOT_R1                       2
#define PIVOT_PP                       3
#define PIVOT_S1                       4
#define PIVOT_S2                       5
#define PIVOT_S3                       6


// Konstanten zum Zugriff auf die in CSV-Dateien gespeicherte Accounthistory
#define AH_COLUMNS                    20
#define I_AH_TICKET                    0
#define I_AH_OPENTIME                  1
#define I_AH_OPENTIMESTAMP             2
#define I_AH_TYPEDESCRIPTION           3
#define I_AH_TYPE                      4
#define I_AH_SIZE                      5
#define I_AH_SYMBOL                    6
#define I_AH_OPENPRICE                 7
#define I_AH_STOPLOSS                  8
#define I_AH_TAKEPROFIT                9
#define I_AH_CLOSETIME                10
#define I_AH_CLOSETIMESTAMP           11
#define I_AH_CLOSEPRICE               12
#define I_AH_MAGICNUMBER              13
#define I_AH_COMMISSION               14
#define I_AH_SWAP                     15
#define I_AH_NETPROFIT                16
#define I_AH_GROSSPROFIT              17
#define I_AH_BALANCE                  18
#define I_AH_COMMENT                  19


/*
 The ENUM_SYMBOL_CALC_MODE enumeration provides information about how a symbol's margin requirements are calculated.

 @see https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants#enum_symbol_calc_mode
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
| SYMBOL_CALC_MODE_CFDLEVERAGE | CFD Leverage mode                                            | Margin: (Lots*ContractSize*MarketPrice*Percentage)/Leverage |
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


// Swap types, siehe MarketInfo(MODE_SWAPTYPE): jeweils per Lot und Tag
#define SCM_POINTS                     0        // in points (quote currency), Forex standard
#define SCM_BASE_CURRENCY              1        // as amount of base currency   (see "symbols.raw")
#define SCM_INTEREST                   2        // in percentage terms
#define SCM_MARGIN_CURRENCY            3        // as amount of margin currency (see "symbols.raw")


// Commission calculation modes, siehe FXT_HEADER
#define COMMISSION_MODE_MONEY          0
#define COMMISSION_MODE_PIPS           1
#define COMMISSION_MODE_PERCENT        2


// Commission types, siehe FXT_HEADER
#define COMMISSION_TYPE_RT             0        // round-turn (both deals)
#define COMMISSION_TYPE_PER_DEAL       1        // per single deal


// Symbol types, siehe struct SYMBOL
#define SYMBOL_TYPE_FOREX              1
#define SYMBOL_TYPE_CFD                2
#define SYMBOL_TYPE_INDEX              3
#define SYMBOL_TYPE_FUTURES            4


// ID's zur Objektpositionierung, siehe ObjectSet(label, OBJPROP_CORNER,  int)
#define CORNER_TOP_LEFT                0        // default
#define CORNER_TOP_RIGHT               1
#define CORNER_BOTTOM_LEFT             2
#define CORNER_BOTTOM_RIGHT            3


// Currency-ID's
#define CID_AUD                        1
#define CID_CAD                        2
#define CID_CHF                        3
#define CID_EUR                        4
#define CID_GBP                        5
#define CID_JPY                        6
#define CID_NZD                        7
#define CID_USD                        8        // zuerst die ID's der LFX-Indizes, dadurch "passen" diese in 3 Bits (für LFX-Tickets)

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
#define C_AUD                   "AUD"
#define C_CAD                   "CAD"
#define C_CHF                   "CHF"
#define C_CNY                   "CNY"
#define C_CZK                   "CZK"
#define C_DKK                   "DKK"
#define C_EUR                   "EUR"
#define C_GBP                   "GBP"
#define C_HKD                   "HKD"
#define C_HRK                   "HRK"
#define C_HUF                   "HUF"
#define C_INR                   "INR"
#define C_JPY                   "JPY"
#define C_LTL                   "LTL"
#define C_LVL                   "LVL"
#define C_MXN                   "MXN"
#define C_NOK                   "NOK"
#define C_NZD                   "NZD"
#define C_PLN                   "PLN"
#define C_RUB                   "RUB"
#define C_SAR                   "SAR"
#define C_SEK                   "SEK"
#define C_SGD                   "SGD"
#define C_USD                   "USD"
#define C_THB                   "THB"
#define C_TRY                   "TRY"
#define C_TWD                   "TWD"
#define C_ZAR                   "ZAR"


// FileOpen() modes
#define FILE_READ                   1
#define FILE_WRITE                  2
#define FILE_BIN                    4
#define FILE_CSV                    8


// File pointer positioning modes, siehe FileSeek()
#define SEEK_SET                    0                    // from begin of file
#define SEEK_CUR                    1                    // from current position
#define SEEK_END                    2                    // from end of file


// Data types, siehe FileRead()/FileWrite()
#define CHAR_VALUE                  1                    // char:   1 byte
#define SHORT_VALUE                 2                    // WORD:   2 bytes
#define LONG_VALUE                  4                    // DWORD:  4 bytes (default)
#define FLOAT_VALUE                 4                    // float:  4 bytes
#define DOUBLE_VALUE                8                    // double: 8 bytes (default)


// FindFileNames() flags
#define FF_SORT                     1                    // Ergebnisse von NTFS-Laufwerken sind immer sortiert
#define FF_DIRSONLY                 2
#define FF_FILESONLY                4


// Flag zum Schreiben von Historyfiles
#define HST_BUFFER_TICKS            1
#define HST_SKIP_DUPLICATE_TICKS    2                    // aufeinanderfolgende identische Ticks innerhalb einer Bar werden nicht geschrieben
#define HST_FILL_GAPS               4
#define HST_TIME_IS_OPENTIME        8


// MessageBox() flags
#define MB_OK                       0x00000000           // buttons
#define MB_OKCANCEL                 0x00000001
#define MB_YESNO                    0x00000004
#define MB_YESNOCANCEL              0x00000003
#define MB_ABORTRETRYIGNORE         0x00000002
#define MB_CANCELTRYCONTINUE        0x00000006
#define MB_RETRYCANCEL              0x00000005
#define MB_HELP                     0x00004000           // additional help button

#define MB_DEFBUTTON1               0x00000000           // default button
#define MB_DEFBUTTON2               0x00000100
#define MB_DEFBUTTON3               0x00000200
#define MB_DEFBUTTON4               0x00000300

#define MB_ICONEXCLAMATION          0x00000030           // icons
#define MB_ICONWARNING      MB_ICONEXCLAMATION
#define MB_ICONINFORMATION          0x00000040
#define MB_ICONASTERISK     MB_ICONINFORMATION
#define MB_ICONQUESTION             0x00000020
#define MB_ICONSTOP                 0x00000010
#define MB_ICONERROR               MB_ICONSTOP
#define MB_ICONHAND                MB_ICONSTOP
#define MB_USERICON                 0x00000080

#define MB_APPLMODAL                0x00000000           // modality
#define MB_SYSTEMMODAL              0x00001000
#define MB_TASKMODAL                0x00002000

#define MB_DEFAULT_DESKTOP_ONLY     0x00020000           // other
#define MB_RIGHT                    0x00080000
#define MB_RTLREADING               0x00100000
#define MB_SETFOREGROUND            0x00010000
#define MB_TOPMOST                  0x00040000
#define MB_NOFOCUS                  0x00008000
#define MB_SERVICE_NOTIFICATION     0x00200000


// MessageBox() return codes
#define IDOK                                    1
#define IDCANCEL                                2
#define IDABORT                                 3
#define IDRETRY                                 4
#define IDIGNORE                                5
#define IDYES                                   6
#define IDNO                                    7
#define IDCLOSE                                 8
#define IDHELP                                  9
#define IDTRYAGAIN                             10
#define IDCONTINUE                             11


// Arrow-Codes, siehe ObjectSet(label, OBJPROP_ARROWCODE, value)
#define SYMBOL_ORDEROPEN                        1        // right pointing arrow (default open order marker)               // docs MetaQuotes: right pointing up arrow
//                                              2        // wie SYMBOL_ORDEROPEN                                           // docs MetaQuotes: right pointing down arrow
#define SYMBOL_ORDERCLOSE                       3        // left pointing arrow  (default closed order marker)
#define SYMBOL_DASH                             4        // dash symbol          (default takeprofit and stoploss marker)
#define SYMBOL_LEFTPRICE                        5        // left sided price label
#define SYMBOL_RIGHTPRICE                       6        // right sided price label
#define SYMBOL_THUMBSUP                        67        // thumb up symbol
#define SYMBOL_THUMBSDOWN                      68        // thumb down symbol
#define SYMBOL_ARROWUP                        241        // arrow up symbol
#define SYMBOL_ARROWDOWN                      242        // arrow down symbol
#define SYMBOL_STOPSIGN                       251        // stop sign symbol
#define SYMBOL_CHECKSIGN                      252        // check sign symbol


// Flags zur Fehlerbehandlung                            // korrespondierende Fehler werden statt "laut" "leise" gesetzt, wodurch sie individuell behandelt werden können
#define MUTE_ERR_INVALID_STOP                   1        // ERR_INVALID_STOP
#define MUTE_ERR_ORDER_CHANGED                  2        // ERR_ORDER_CHANGED
#define MUTE_ERR_CONCUR_MODIFICATION            4        // ERR_CONCURRENT_MODIFICATION
#define MUTE_ERR_SERIES_NOT_AVAILABLE           8        // ERR_SERIES_NOT_AVAILABLE
#define MUTE_ERR_INVALID_PARAMETER             16        // ERR_INVALID_PARAMETER
#define MUTE_ERS_EXECUTION_STOPPING            32        // ERS_EXECUTION_STOPPING        (Status)
#define MUTE_ERS_TERMINAL_NOT_YET_READY        64        // ERS_TERMINAL_NOT_YET_READY    (Status)

// String padding types, siehe StringPad()
#define STR_PAD_LEFT                            1
#define STR_PAD_RIGHT                           2
#define STR_PAD_BOTH                            3


// Array ID's für von ArrayCopyRates() definierte Arrays
#define I_BAR.time                              0
#define I_BAR.open                              1
#define I_BAR.low                               2
#define I_BAR.high                              3
#define I_BAR.close                             4
#define I_BAR.volume                            5


// Price-Bar ID's (siehe Historyfunktionen)
#define BAR_T                                   0        // (double) datetime
#define BAR_O                                   1
#define BAR_H                                   2
#define BAR_L                                   3
#define BAR_C                                   4
#define BAR_V                                   5


// AccountCompany-ShortNames
#define AC.Alpari                               "Alpari"
#define AC.APBG                                 "APBG"
#define AC.ATC                                  "ATC"
#define AC.AxiTrader                            "AxiTrader"
#define AC.BroCo                                "BroCo"
#define AC.CollectiveFX                         "CollectiveFX"
#define AC.Dukascopy                            "Dukascopy"
#define AC.EasyForex                            "EasyForex"
#define AC.FB_Capital                           "FB Capital"
#define AC.FinFX                                "FinFX"
#define AC.Forex_Ltd                            "Forex Ltd"
#define AC.FX_Primus                            "FX Primus"
#define AC.FXDD                                 "FXDD"
#define AC.FXOpen                               "FXOpen"
#define AC.FxPro                                "FxPro"
#define AC.Gallant                              "Gallant"
#define AC.GCI                                  "GCI"
#define AC.GFT                                  "GFT"
#define AC.Global_Prime                         "Global Prime"
#define AC.IC_Markets                           "IC Markets"
#define AC.InovaTrade                           "InovaTrade"
#define AC.Investors_Europe                     "Investors Europe"
#define AC.JFD_Brokers                          "JFD Brokers"
#define AC.LiteForex                            "LiteForex"
#define AC.London_Capital                       "London Capital"
#define AC.MB_Trading                           "MB Trading"
#define AC.MetaQuotes                           "MetaQuotes"
#define AC.MIG                                  "MIG"
#define AC.MyFX                                 "MyFX"
#define AC.Oanda                                "Oanda"
#define AC.Pepperstone                          "Pepperstone"
#define AC.PrimeXM                              "PrimeXM"
#define AC.SimpleTrader                         "SimpleTrader"
#define AC.STS                                  "STS"
#define AC.TeleTrade                            "TeleTrade"


// AccountCompany-ID's
#define AC_ID.Alpari                            1001
#define AC_ID.APBG                              1002
#define AC_ID.ATC                               1003
#define AC_ID.AxiTrader                         1004
#define AC_ID.BroCo                             1005
#define AC_ID.CollectiveFX                      1006
#define AC_ID.Dukascopy                         1007
#define AC_ID.EasyForex                         1008
#define AC_ID.FB_Capital                        1009
#define AC_ID.FinFX                             1010
#define AC_ID.Forex_Ltd                         1011
#define AC_ID.FX_Primus                         1012
#define AC_ID.FXDD                              1013
#define AC_ID.FXOpen                            1014
#define AC_ID.FxPro                             1015
#define AC_ID.Gallant                           1016
#define AC_ID.GCI                               1017
#define AC_ID.GFT                               1018
#define AC_ID.Global_Prime                      1019
#define AC_ID.IC_Markets                        1020
#define AC_ID.InovaTrade                        1021
#define AC_ID.Investors_Europe                  1022
#define AC_ID.JFD_Brokers                       1023
#define AC_ID.LiteForex                         1024
#define AC_ID.London_Capital                    1025
#define AC_ID.MB_Trading                        1026
#define AC_ID.MetaQuotes                        1027
#define AC_ID.MIG                               1028
#define AC_ID.MyFX                              1029
#define AC_ID.Oanda                             1030
#define AC_ID.Pepperstone                       1031
#define AC_ID.PrimeXM                           1032
#define AC_ID.SimpleTrader                      1033
#define AC_ID.STS                               1034
#define AC_ID.TeleTrade                         1035


// SimpleTrader Account-Aliasse
#define STA_ALIAS.AlexProfit                    "alexprofit"
#define STA_ALIAS.ASTA                          "asta"
#define STA_ALIAS.Caesar2                       "caesar2"
#define STA_ALIAS.Caesar21                      "caesar21"
#define STA_ALIAS.ConsistentProfit              "consistent"
#define STA_ALIAS.DayFox                        "dayfox"
#define STA_ALIAS.FXViper                       "fxviper"
#define STA_ALIAS.GCEdge                        "gcedge"
#define STA_ALIAS.GoldStar                      "goldstar"
#define STA_ALIAS.Kilimanjaro                   "kilimanjaro"
#define STA_ALIAS.NovoLRfund                    "novolr"
#define STA_ALIAS.OverTrader                    "overtrader"
#define STA_ALIAS.Ryan                          "ryan"
#define STA_ALIAS.SmartScalper                  "smartscalper"
#define STA_ALIAS.SmartTrader                   "smarttrader"
#define STA_ALIAS.SteadyCapture                 "steadycapture"
#define STA_ALIAS.Twilight                      "twilight"
#define STA_ALIAS.YenFortress                   "yenfortress"


// SimpleTrader Account-ID's (entsprechen den ID's der SimpleTrader-URLs)
#define STA_ID.AlexProfit                       2474
#define STA_ID.ASTA                             2370
#define STA_ID.Caesar2                          1619
#define STA_ID.Caesar21                         1803
#define STA_ID.ConsistentProfit                 4351
#define STA_ID.DayFox                           2465
#define STA_ID.FXViper                           633
#define STA_ID.GCEdge                            998
#define STA_ID.GoldStar                         2622
#define STA_ID.Kilimanjaro                      2905
#define STA_ID.NovoLRfund                       4322
#define STA_ID.OverTrader                       2973
#define STA_ID.Ryan                             5611
#define STA_ID.SmartScalper                     1086
#define STA_ID.SmartTrader                      1081
#define STA_ID.SteadyCapture                    4023
#define STA_ID.Twilight                         3913
#define STA_ID.YenFortress                      2877

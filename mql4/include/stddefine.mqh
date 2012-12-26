/**
 * Globale Konstanten, Variablen und Funktionen
 */
#include <stderror.mqh>


// globale Variablen, stehen überall zur Verfügung
string   __NAME__;                                          // Name des aktuellen Programms
int      __WHEREAMI__;                                      // ID der aktuell ausgeführten MQL-Rootfunktion: FUNC_INIT | FUNC_START | FUNC_DEINIT
bool     __LOG = true;                                      // ob das Logging aktiviert ist (default: ja; im Tester ggf. nein)
bool     __LOG_INSTANCE_ID;                                 // ob die Instanz-ID des Programms mitgeloggt wird
bool     __LOG_PER_INSTANCE;                                // ob ein instanz-eigenes Logfile benutzt wird
bool     __STATUS_TERMINAL_NOT_READY;                       // Status-Äquivalent für ERS_TERMINAL_NOT_READY, kein Fehler
bool     __STATUS_HISTORY_UPDATE;                           // History-Update wurde getriggert
bool     __STATUS_HISTORY_INSUFFICIENT;                     // History ist nicht ausreichend
bool     __STATUS_RELAUNCH_INPUT;                           // Anforderung, Input-Dialog erneut zu laden
bool     __STATUS_INVALID_INPUT;                            // ungültige Parametereingabe im Input-Dialog
bool     __STATUS_CANCELLED;                                // Ausführung durch Benutzer abgebrochen       (externe Ursache)
bool     __STATUS_ERROR;                                    // Ausführung durch Laufzeitfehler abgebrochen (interne Ursache)

double   Pip, Pips;                                         // Betrag eines Pips des aktuellen Symbols (z.B. 0.0001 = Pip-Size)
int      PipDigits, SubPipDigits;                           // Digits eines Pips/Subpips des aktuellen Symbols (Annahme: Pips sind gradzahlig)
int      PipPoint, PipPoints;                               // Auflösung eines Pips des aktuellen Symbols (Anzahl der Punkte auf der Dezimalskala je Pip)
double   TickSize;                                          // kleinste Änderung des Preises des aktuellen Symbols je Tick (Vielfaches von Point)
string   PriceFormat, PipPriceFormat, SubPipPriceFormat;    // Preisformate des aktuellen Symbols für NumberToStr()
int      Tick, Ticks;
datetime Tick.Time;
datetime Tick.prevTime;
int      ValidBars;
int      ChangedBars;

int      prev_error;                                        // der letzte Fehler des vorherigen start()-Aufrufs
int      last_error;                                        // der letzte Fehler des aktuellen start()-Aufrufs

string   objects[];                                         // Namen der Objekte, die mit Beenden des Programms automatisch entfernt werden


// Special constants
#define NULL                        0
#define INT_MIN            0x80000000           // kleinster Integer-Value: -2147483648
#define INT_MAX            0x7FFFFFFF           // größter Integer-Value:    2147483647
#define EMPTY                      -1
#define EMPTY_VALUE           INT_MAX           // empty custom indicator value
#define CLR_NONE                   -1           // no color
#define WHOLE_ARRAY                 0
#define MAX_SYMBOL_LENGTH          12
#define MAX_STRING_LITERAL          "..............................................................................................................................................................................................................................................................."
#define NL                          "\n"        // new line, MQL schreibt 0x0D0A
#define TAB                         "\t"        // tab


// Special chars
#define PLACEHOLDER_NUL_CHAR        '…'         // 0x85 - Platzhalter für NUL-Byte in Strings,          siehe BufferToStr()
#define PLACEHOLDER_CTL_CHAR        '•'         // 0x95 - Platzhalter für Control-Character in Strings, siehe BufferToStr()


// Mathematische Konstanten
#define Math.PI                     3.1415926535897932384626433832795028841971693993751      // intern 3.141592653589793 (15 korrekte Dezimalstellen)


// Zeitkonstanten
#define SECOND                      1
#define MINUTE                     60
#define HOUR                     3600
#define DAY                     86400
#define WEEK                   604800

#define SECONDS                SECOND
#define MINUTES                MINUTE
#define HOURS                    HOUR
#define DAYS                      DAY
#define WEEKS                    WEEK


// Wochentage, siehe TimeDayOfWeek()
#define SUNDAY                      0
#define MONDAY                      1
#define TUESDAY                     2
#define WEDNESDAY                   3
#define THURSDAY                    4
#define FRIDAY                      5
#define SATURDAY                    6


// Time-Flags, siehe TimeToStr()
#define TIME_DATE                   1
#define TIME_MINUTES                2
#define TIME_SECONDS                4
#define TIME_FULL                   7           // TIME_DATE | TIME_MINUTES | TIME_SECONDS


// Timeframe-Identifier, siehe Period()
#define PERIOD_M1                   1           // 1 minute
#define PERIOD_M5                   5           // 5 minutes
#define PERIOD_M15                 15           // 15 minutes
#define PERIOD_M30                 30           // 30 minutes
#define PERIOD_H1                  60           // 1 hour
#define PERIOD_H4                 240           // 4 hours
#define PERIOD_D1                1440           // daily
#define PERIOD_W1               10080           // weekly  (7 Tage)
#define PERIOD_MN1              43200           // monthly (30 Tage)


// MQL Programmtyp-Flags
#define T_INDICATOR                 1
#define T_EXPERT                    2
#define T_SCRIPT                    4
#define T_LIBRARY                   8


// MQL Root-Funktions-ID's (siehe __WHEREAMI__)
#define FUNC_INIT                   1
#define FUNC_START                  2
#define FUNC_DEINIT                 3


// init()-Flags
#define INIT_TIMEZONE               1           // stellt eine korrekte Timezone-Konfiguration sicher
#define INIT_PIPVALUE               2           // stellt sicher, daß der aktuelle PipValue berechnet werden kann (benötigt TickSize und TickValue)
#define INIT_BARS_ON_HIST_UPDATE    4           //
#define LOG_INSTANCE_ID             8           // versieht alle Logmessages mit der jeweiligen Instanz-ID
#define LOG_PER_INSTANCE           16           // erzeugt für jede Instanz ein separates Logfile


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
#define OBJ_PERIOD_M1          0x0001           // object is shown on 1-minute charts
#define OBJ_PERIOD_M5          0x0002           // object is shown on 5-minute charts
#define OBJ_PERIOD_M15         0x0004           // object is shown on 15-minute charts
#define OBJ_PERIOD_M30         0x0008           // object is shown on 30-minute charts
#define OBJ_PERIOD_H1          0x0010           // object is shown on 1-hour charts
#define OBJ_PERIOD_H4          0x0020           // object is shown on 4-hour charts
#define OBJ_PERIOD_D1          0x0040           // object is shown on daily charts
#define OBJ_PERIOD_W1          0x0080           // object is shown on weekly charts
#define OBJ_PERIOD_MN1         0x0100           // object is shown on monthly charts
#define OBJ_PERIODS_ALL        0x01FF           // object is shown on all timeframes: OBJ_PERIOD_M1 | OBJ_PERIOD_M5 | OBJ_PERIOD_M15 | OBJ_PERIOD_M30 | OBJ_PERIOD_H1 |
#define OBJ_ALL_PERIODS        OBJ_ALL_PERIODS  //                                    OBJ_PERIOD_H4 | OBJ_PERIOD_D1 | OBJ_PERIOD_W1  | OBJ_PERIOD_MN1


// Timeframe-Flags, siehe EventListener.Baropen()
#define F_PERIOD_M1            OBJ_PERIOD_M1
#define F_PERIOD_M5            OBJ_PERIOD_M5
#define F_PERIOD_M15           OBJ_PERIOD_M15
#define F_PERIOD_M30           OBJ_PERIOD_M30
#define F_PERIOD_H1            OBJ_PERIOD_H1
#define F_PERIOD_H4            OBJ_PERIOD_H4
#define F_PERIOD_D1            OBJ_PERIOD_D1
#define F_PERIOD_W1            OBJ_PERIOD_W1
#define F_PERIOD_MN1           OBJ_PERIOD_MN1
#define F_PERIODS_ALL          OBJ_PERIODS_ALL  // F_PERIOD_M1 | F_PERIOD_M5 | F_PERIOD_M15 | F_PERIOD_M30 | F_PERIOD_H1 | F_PERIOD_H4 | F_PERIOD_D1 | F_PERIOD_W1 | F_PERIOD_MN1
#define F_ALL_PERIODS          F_PERIODS_ALL


// Operation-Types, siehe OrderType()
#define OP_UNDEFINED               -1           // custom: Default-Wert für nicht initialisierte Variable
#define OP_BUY                      0           // long position
#define OP_LONG                OP_BUY
#define OP_SELL                     1           // short position
#define OP_SHORT              OP_SELL
#define OP_BUYLIMIT                 2           // buy limit order
#define OP_SELLLIMIT                3           // sell limit order
#define OP_BUYSTOP                  4           // stop buy order
#define OP_SELLSTOP                 5           // stop sell order
#define OP_BALANCE                  6           // account debit or credit transaction
#define OP_CREDIT                   7           // margin credit facility (no transaction)
#define OP_TRANSFER                 8           // custom: OP_BALANCE initiiert durch Kunden (Ein-/Auszahlung)
#define OP_VENDOR                   9           // custom: OP_BALANCE initiiert durch Criminal (Swap, sonstiges)


// Order-Flags, können logisch kombiniert werden, siehe EventListener.PositionOpen() u. EventListener.PositionClose()
#define OFLAG_CURRENTSYMBOL         1           // order of current symbol (active chart)
#define OFLAG_BUY                   2           // long order
#define OFLAG_SELL                  4           // short order
#define OFLAG_MARKETORDER           8           // market order
#define OFLAG_PENDINGORDER         16           // pending order (Limit- oder Stop-Order)


// OrderSelect-ID's zur Steuerung des Stacks der Orderkontexte, siehe OrderPush(), OrderPop() etc.
#define O_PUSH                      1
#define O_POP                       2


// Series array identifier, siehe ArrayCopySeries(), iLowest(), iHighest()
#define MODE_OPEN                   0           // open price
#define MODE_LOW                    1           // low price
#define MODE_HIGH                   2           // high price
#define MODE_CLOSE                  3           // close price
#define MODE_VOLUME                 4           // volume
#define MODE_TIME                   5           // bar open time


// MA method identifiers, siehe iMA()
#define MODE_SMA                    0           // simple moving average
#define MODE_EMA                    1           // exponential moving average
#define MODE_SMMA                   2           // smoothed moving average
#define MODE_LWMA                   3           // linear weighted moving average
#define MODE_ALMA                   4           // Arnaud Legoux moving average


// Indicator line identifiers used in iMACD(), iRVI() and iStochastic()
#define MODE_MAIN                   0           // base indicator line
#define MODE_SIGNAL                 1           // signal line


// Indicator line identifiers used in iADX()
#define MODE_MAIN                   0           // base indicator line
#define MODE_PLUSDI                 1           // +DI indicator line
#define MODE_MINUSDI                2           // -DI indicator line


// Indicator line identifiers used in iBands(), iEnvelopes(), iEnvelopesOnArray(), iFractals() and iGator()
#define MODE_UPPER                  1           // upper line
#define MODE_LOWER                  2           // lower line

#define B_LOWER                     0           // custom
#define B_UPPER                     1           // custom


// Indicator buffer identifiers used in iCustom()
#define BUFFER_INDEX_0              0
#define BUFFER_INDEX_1              1
#define BUFFER_INDEX_2              2
#define BUFFER_INDEX_3              3
#define BUFFER_INDEX_4              4
#define BUFFER_INDEX_5              5
#define BUFFER_INDEX_6              6
#define BUFFER_INDEX_7              7
#define BUFFER_1       BUFFER_INDEX_0
#define BUFFER_2       BUFFER_INDEX_1
#define BUFFER_3       BUFFER_INDEX_2
#define BUFFER_4       BUFFER_INDEX_3
#define BUFFER_5       BUFFER_INDEX_4
#define BUFFER_6       BUFFER_INDEX_5
#define BUFFER_7       BUFFER_INDEX_6
#define BUFFER_8       BUFFER_INDEX_7


// Indicator shared memory identifiers, siehe iCustom()
#define IC_PTR                      0
#define IC_LAST_ERROR               1


// Sorting modes, siehe ArraySort()
#define MODE_ASCEND                 1           // aufsteigend
#define MODE_DESCEND                2           // absteigend


// Market info identifiers, siehe MarketInfo()
#define MODE_LOW                    1           // low price of the current day (since midnight server time)
#define MODE_HIGH                   2           // high price of the current day (since midnight server time)
//                                  3           // ???
//                                  4           // ???
#define MODE_TIME                   5           // last tick time
//                                  6           // ???
//                                  7           // ???
//                                  8           // ???
#define MODE_BID                    9           // last bid price                       (entspricht Bid bzw. Close[0])
#define MODE_ASK                   10           // last ask price                       (entspricht Ask)
#define MODE_POINT                 11           // point size in the quote currency     (entspricht Point)                                               0.0000'1
#define MODE_DIGITS                12           // number of digits after decimal point (entspricht Digits)
#define MODE_SPREAD                13           // spread value in points
#define MODE_STOPLEVEL             14           // stop level in points
#define MODE_LOTSIZE               15           // unit size of 1 lot                                                                                    100.000
#define MODE_TICKVALUE             16           // tick value in the deposit currency
#define MODE_TICKSIZE              17           // tick size in the quote currency                                                                       0.0000'5
#define MODE_SWAPLONG              18           // swap of long positions
#define MODE_SWAPSHORT             19           // swap of short positions
#define MODE_STARTING              20           // contract starting date (usually for futures)
#define MODE_EXPIRATION            21           // contract expiration date (usually for futures)
#define MODE_TRADEALLOWED          22           // if trading is allowed for the symbol
#define MODE_MINLOT                23           // minimum lot size
#define MODE_LOTSTEP               24           // minimum lot increment size
#define MODE_MAXLOT                25           // maximum lot size
#define MODE_SWAPTYPE              26           // swap calculation method: 0 - in points; 1 - in base currency; 2 - by interest; 3 - in margin currency
#define MODE_PROFITCALCMODE        27           // profit calculation mode: 0 - Forex; 1 - CFD; 2 - Futures
#define MODE_MARGINCALCMODE        28           // margin calculation mode: 0 - Forex; 1 - CFD; 2 - Futures; 3 - CFD for indices
#define MODE_MARGININIT            29           // initial margin requirement for a position of 1 lot
#define MODE_MARGINMAINTENANCE     30           // margin to maintain an open positions of 1 lot
#define MODE_MARGINHEDGED          31           // units per side with margin maintenance requirement for a hedged position of 1 lot                     50.000
#define MODE_MARGINREQUIRED        32           // free margin requirement for a position of 1 lot
#define MODE_FREEZELEVEL           33           // order freeze level in points


// Price identifiers, siehe iMA() etc.
#define PRICE_CLOSE                 0           // close price
#define PRICE_OPEN                  1           // open price
#define PRICE_HIGH                  2           // high price
#define PRICE_LOW                   3           // low price
#define PRICE_MEDIAN                4           // median price: (high+low)/2
#define PRICE_TYPICAL               5           // typical price: (high+low+close)/3
#define PRICE_WEIGHTED              6           // weighted close price: (high+low+close+close)/4
#define PRICE_BID                   7           // custom: Bid-Preis
#define PRICE_ASK                   8           // custom: Ask-Preis


// Rates array identifier, siehe ArrayCopyRates()
#define RATE_TIME                   0           // bar open time
#define RATE_OPEN                   1           // open price
#define RATE_LOW                    2           // low price
#define RATE_HIGH                   3           // high price
#define RATE_CLOSE                  4           // close price
#define RATE_VOLUME                 5           // volume


// Event-Identifier siehe event()
#define EVENT_BAR_OPEN              0x0001
#define EVENT_ORDER_PLACE           0x0002
#define EVENT_ORDER_CHANGE          0x0004
#define EVENT_ORDER_CANCEL          0x0008
#define EVENT_POSITION_OPEN         0x0010
#define EVENT_POSITION_CLOSE        0x0020
#define EVENT_ACCOUNT_CHANGE        0x0040
#define EVENT_ACCOUNT_PAYMENT       0x0080      // Ein- oder Auszahlung
#define EVENT_CHART_CMD             0x0100      // Chart-Command             (aktueller Chart)
#define EVENT_INTERNAL_CMD          0x0200      // terminal-internes Command (globale Variablen)
#define EVENT_EXTERNAL_CMD          0x0400      // externes Command          (QuickChannel)


// Array-Identifier zum Zugriff auf verschiedene Pivotlevel, siehe iPivotLevel()
#define PIVOT_R3                    0
#define PIVOT_R2                    1
#define PIVOT_R1                    2
#define PIVOT_PP                    3
#define PIVOT_S1                    4
#define PIVOT_S2                    5
#define PIVOT_S3                    6


// Konstanten zum Zugriff auf die Spalten der Account-History
#define HISTORY_COLUMNS            22
#define AH_TICKET                   0
#define AH_OPENTIME                 1
#define AH_OPENTIMESTAMP            2
#define AH_TYPEDESCRIPTION          3
#define AH_TYPE                     4
#define AH_SIZE                     5
#define AH_SYMBOL                   6
#define AH_OPENPRICE                7
#define AH_STOPLOSS                 8
#define AH_TAKEPROFIT               9
#define AH_CLOSETIME               10
#define AH_CLOSETIMESTAMP          11
#define AH_CLOSEPRICE              12
#define AH_EXPIRATIONTIME          13
#define AH_EXPIRATIONTIMESTAMP     14
#define AH_MAGICNUMBER             15
#define AH_COMMISSION              16
#define AH_SWAP                    17
#define AH_NETPROFIT               18
#define AH_GROSSPROFIT             19
#define AH_BALANCE                 20
#define AH_COMMENT                 21


// Margin calculation modes, siehe MarketInfo(symbol, MODE_MARGINCALCMODE)
#define MCM_FOREX                   0
#define MCM_CFD                     1
#define MCM_CFDFUTURES              2
#define MCM_CFDINDEX                3
#define MCM_CFDLEVERAGE             4           // erst seit MT5 dokumentiert


// Swap calculation modes, siehe MarketInfo(symbol, MODE_SWAPTYPE)
#define SCM_POINTS                  0
#define SCM_BASE_CURRENCY           1
#define SCM_INTEREST                2
#define SCM_MARGIN_CURRENCY         3           // Deposit-Currency


// Profit calculation modes, siehe MarketInfo(symbol, MODE_PROFITCALCMODE)
#define PCM_FOREX                   0
#define PCM_CFD                     1
#define PCM_FUTURES                 2


// Account stopout modes, siehe AccountStopoutMode()
#define ASM_PERCENT                 0
#define ASM_ABSOLUTE                1


// ID's zur Objektpositionierung, siehe ObjectSet(label, OBJPROP_CORNER,  int)
#define CORNER_TOP_LEFT             0           // default
#define CORNER_TOP_RIGHT            1
#define CORNER_BOTTOM_LEFT          2
#define CORNER_BOTTOM_RIGHT         3


// UninitializeReason-Codes
#define REASON_UNDEFINED            0           // no uninitialize reason
#define REASON_REMOVE               1           // program removed from chart
#define REASON_RECOMPILE            2           // program recompiled
#define REASON_CHARTCHANGE          3           // chart symbol or timeframe changed
#define REASON_CHARTCLOSE           4           // chart closed or template changed
#define REASON_PARAMETERS           5           // input parameters changed
#define REASON_ACCOUNT              6           // account changed


// Currency-ID's
#define CID_AUD                     1
#define CID_CAD                     2
#define CID_CHF                     3
#define CID_EUR                     4
#define CID_GBP                     5
#define CID_JPY                     6
#define CID_USD                     7           // zuerst die ID's der Majors, dadurch "passen" diese in 3 Bits (für LFX etc.)

#define CID_CNY                     8
#define CID_CZK                     9
#define CID_DKK                    10
#define CID_HKD                    11
#define CID_HRK                    12
#define CID_HUF                    13
#define CID_INR                    14
#define CID_LTL                    15
#define CID_LVL                    16
#define CID_MXN                    17
#define CID_NOK                    18
#define CID_NZD                    19
#define CID_PLN                    20
#define CID_RUB                    21
#define CID_SAR                    22
#define CID_SEK                    23
#define CID_SGD                    24
#define CID_THB                    25
#define CID_TRY                    26
#define CID_TWD                    27
#define CID_ZAR                    28


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


// Data types, siehe FileRead()/FileWrite()
#define CHAR_VALUE                  1                    // integer: 1 byte
#define SHORT_VALUE                 2                    // integer: 2 bytes
#define LONG_VALUE                  4                    // integer: 4 bytes (default)
#define FLOAT_VALUE                 4                    // float:   4 bytes
#define DOUBLE_VALUE                8                    // float:   8 bytes (default)


// FindFileNames() flags
#define FF_SORT                     1                    // Ergebnisse von NTFS-Laufwerken sind immer sortiert
#define FF_DIRSONLY                 2
#define FF_FILESONLY                4


// Flag zum Schreiben von Historyfiles
#define HST_FILL_GAPS               1


// MessageBox() flags
#define MB_OK                       0x00000000        // buttons
#define MB_OKCANCEL                 0x00000001
#define MB_YESNO                    0x00000004
#define MB_YESNOCANCEL              0x00000003
#define MB_ABORTRETRYIGNORE         0x00000002
#define MB_CANCELTRYCONTINUE        0x00000006
#define MB_RETRYCANCEL              0x00000005
#define MB_HELP                     0x00004000        // additional help button

#define MB_DEFBUTTON1               0x00000000        // default button
#define MB_DEFBUTTON2               0x00000100
#define MB_DEFBUTTON3               0x00000200
#define MB_DEFBUTTON4               0x00000300

#define MB_ICONEXCLAMATION          0x00000030        // icons
#define MB_ICONWARNING      MB_ICONEXCLAMATION
#define MB_ICONINFORMATION          0x00000040
#define MB_ICONASTERISK     MB_ICONINFORMATION
#define MB_ICONQUESTION             0x00000020
#define MB_ICONSTOP                 0x00000010
#define MB_ICONERROR               MB_ICONSTOP
#define MB_ICONHAND                MB_ICONSTOP
#define MB_USERICON                 0x00000080

#define MB_APPLMODAL                0x00000000        // modality
#define MB_SYSTEMMODAL              0x00001000
#define MB_TASKMODAL                0x00002000

#define MB_DEFAULT_DESKTOP_ONLY     0x00020000        // other
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
#define SYMBOL_ORDEROPEN                        1     // right pointing arrow (default open ticket marker)
#define SYMBOL_ORDEROPEN_UP      SYMBOL_ORDEROPEN     // right pointing up arrow                               // ??? wird so nicht angezeigt
#define SYMBOL_ORDEROPEN_DOWN                   2     // right pointing down arrow                             // ??? wird so nicht angezeigt
#define SYMBOL_ORDERCLOSE                       3     // left pointing arrow (default closed ticket marker)

#define SYMBOL_DASH                             4     // dash symbol (default stoploss and takeprofit marker)
#define SYMBOL_LEFTPRICE                        5     // left sided price label
#define SYMBOL_RIGHTPRICE                       6     // right sided price label
#define SYMBOL_THUMBSUP                        67     // thumb up symbol
#define SYMBOL_THUMBSDOWN                      68     // thumb down symbol
#define SYMBOL_ARROWUP                        241     // arrow up symbol
#define SYMBOL_ARROWDOWN                      242     // arrow down symbol
#define SYMBOL_STOPSIGN                       251     // stop sign symbol
#define SYMBOL_CHECKSIGN                      252     // check sign symbol


// MT4 internal messages
#define MT4_TICK                                2     // künstlicher Tick: Ausführung von start()
#define MT4_COMPILE_REQUEST                 12345
#define MT4_COMPILE_PERMISSION              12346
#define MT4_COMPILE_FINISHED                12349     // Rescan und Reload modifizierter .ex4-Files


// MT4 command ids (Menüpunkte, Toolbars, Hotkeys)
#define IDC_EXPERTS_ONOFF                   33020     // Toolbar: Experts on/off                    Ctrl+E

#define IDC_CHART_REFRESH                   33324     // Chart: Refresh
#define IDC_CHART_STEPFORWARD               33197     //        eine Bar vorwärts                      F12
#define IDC_CHART_STEPBACKWARD              33198     //        eine Bar rückwärts               Shift+F12
#define IDC_CHART_EXPERT_PROPERTIES         33048     //        Expert Properties-Dialog                F7

#define IDC_MARKETWATCH_SYMBOLS             33171     // Market Watch: Symbols

#define IDC_TESTER_TICK     IDC_CHART_STEPFORWARD     // Tester: nächster Tick                         F12


// MT4 item ids (Fenster, Controls)
#define IDD_DOCKABLES_CONTAINER             59422     // window containing all child windows docked inside the main application window
#define IDD_UNDOCKED_CONTAINER              59423     // window containing undocked child windows (one per undocked child)

#define IDD_MARKETWATCH                        80     // Market Watch
#define IDD_MARKETWATCH_SYMBOLS             35441     // Market Watch - Symbols
#define IDD_MARKETWATCH_TICKCHART           35442     // Market Watch - Tick Chart

#define IDD_NAVIGATOR                          82     // Navigator
#define IDD_NAVIGATOR_COMMON                35439     // Navigator - Common
#define IDD_NAVIGATOR_FAVOURITES            35440     // Navigator - Favourites

#define IDD_TERMINAL                           81     // Terminal
#define IDD_TERMINAL_TRADE                  33217     // Terminal - Trade
#define IDD_TERMINAL_ACCOUNTHISTORY         33208     // Terminal - Account History
#define IDD_TERMINAL_NEWS                   33211     // Terminal - News
#define IDD_TERMINAL_ALERTS                 33206     // Terminal - Alerts
#define IDD_TERMINAL_MAILBOX                33210     // Terminal - Mailbox
#define IDD_TERMINAL_EXPERTS                35434     // Terminal - Experts
#define IDD_TERMINAL_JOURNAL                33209     // Terminal - Journal

#define IDD_TESTER                             83     // Tester
#define IDD_TESTER_SETTINGS                 33215     // Tester - Settings
#define IDC_TESTER_PAUSERESUME               1402     // Tester - Settings Pause/Resume button
#define IDC_TESTER_STARTSTOP                 1034     // Tester - Settings Start/Stop button
#define IDD_TESTER_RESULTS                  33214     // Tester - Results
#define IDD_TESTER_GRAPH                    33207     // Tester - Graph
#define IDD_TESTER_REPORT                   33213     // Tester - Report
#define IDD_TESTER_JOURNAL   IDD_TERMINAL_EXPERTS     // Tester - Journal (entspricht Terminal - Experts)


// Order execution flags                              // korrespondierende Fehler können individuell behandelt werden
#define OE_CATCH_INVALID_STOP                   1     // ERR_INVALID_STOP
#define OE_CATCH_ORDER_CHANGED                  2     // ERR_ORDER_CHANGED
#define OE_CATCH_EXECUTION_STOPPING             4     // ERS_EXECUTION_STOPPING (Status)


// Struct sizes
#define BAR.size                               44
#define BAR.intSize                            11     // ceil(BAR.size/4)
#define RATE_INFO.size                   BAR.size
#define RATE_INFO.intSize             BAR.intSize

#define HISTORY_HEADER.size                   148
#define HISTORY_HEADER.intSize                 37     // ceil(HISTORY_HEADER.size/4)

#define ICUSTOM.size                            8
#define ICUSTOM.intSize                         2     // ceil(ICUSTOM.size/4)

#define ORDER_EXECUTION.size                  136
#define ORDER_EXECUTION.intSize                34     // ceil(ORDER_EXECUTION.size/4)


// History bar ID's
#define BAR_O                                   0
#define BAR_L                                   1
#define BAR_H                                   2
#define BAR_C                                   3
#define BAR_V                                   4


/**
 * Lädt den Input-Dialog des aktuellen Programms neu.
 *
 * @return int - Fehlerstatus
 */
int start.RelaunchInputDialog() {
   if (__STATUS_CANCELLED)
      return(NO_ERROR);

   int error;

   if (IsExpert()) {
      if (!IsTesting())
         error = Chart.Expert.Properties();
   }
   else if (IsIndicator()) {
      //if (!IsTesting())
      //   error = Chart.Indicator.Properties();                     // TODO: implementieren
   }

   if (IsError(error))
      SetLastError(error);
   return(error);
}


#import "kernel32.dll"
   void OutputDebugStringA(string lpMessage);
#import


/**
 * Sends a message to OutputDebugString() to be viewed and logged by SysInternals DebugView.
 *
 * @param  string message - Message
 * @param  int    error   - Fehlercode
 *
 * @return int - derselbe Fehlercode
 *
 *
 * NOTE: Nur bei Implementierung in der Headerdatei wird das aktuell laufende Modul als Auslöser angezeigt.
 */
int debug(string message, int error=NO_ERROR) {
   static int debugToLog = -1;
   if (debugToLog == -1)
      debugToLog = GetLocalConfigBool("Logging", "DebugToLog", false);

   if (debugToLog == 1) {
      bool old.__LOG = __LOG; __LOG = true;
      log(message, error);    __LOG = old.__LOG;
      return(error);
   }

   if (IsError(error))
      message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");

   OutputDebugStringA(StringConcatenate("MetaTrader::", Symbol(), ",", PeriodDescription(NULL), "::", __NAME__, "::", message));
   return(error);
}


/**
 * Loggt eine Message.
 *
 * @param  string message - Message
 * @param  int    error   - Fehlercode
 *
 * @return int - derselbe Fehlercode
 *
 *
 * NOTE: Nur bei Implementierung in der Headerdatei wird das aktuell laufende Modul als Auslöser angezeigt.
 */
int log(string message, int error=NO_ERROR) {
   if (!__LOG) return(error);

   if (IsError(error))
      message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");

   if (__LOG_PER_INSTANCE)
      if (logToInstanceLog(StringConcatenate(__NAME__, "::", message)))    // ohne Instanz-ID, bei Fehler Fall-back zum Standard-Logging
         return(error);

   string name = __NAME__;
   if (__LOG_INSTANCE_ID) {
      int pos = StringFind(name, "::");
      if (pos == -1) name = StringConcatenate(           __NAME__,       "(", InstanceId(NULL), ")");
      else           name = StringConcatenate(StringLeft(__NAME__, pos), "(", InstanceId(NULL), ")", StringRight(__NAME__, -pos));
   }
   Print(StringConcatenate(name, "::", message));                          // ggf. mit Instanz-ID

   return(error);
}


/**
 * Loggt eine Message in das instanz-eigene Logfile.
 *
 * @param  string message - vollständige zu loggende Message (ohne Zeitstempel, Symbol, Timeframe)
 *
 * @return bool - Erfolgsstatus: u.a. FALSE, wenn das instanz-eigene Logfile (noch) nicht definiert ist
 */
bool logToInstanceLog(string message) {
   bool old.LOG_PER_INSTANCE = __LOG_PER_INSTANCE;
   int id = InstanceId(NULL);
   if (id == NULL)
      return(false);

   message = StringConcatenate(TimeToStr(TimeLocal(), TIME_FULL), "  ", StdSymbol(), ",", StringRightPad(PeriodDescription(NULL), 3, " "), "  ", message);

   string fileName = StringConcatenate(id, ".log");

   int hFile = FileOpen(fileName, FILE_READ|FILE_WRITE);
   if (hFile < 0) {
      __LOG_PER_INSTANCE = false; catch("logToInstanceLog(1)->FileOpen(\""+ fileName +"\")"); __LOG_PER_INSTANCE = old.LOG_PER_INSTANCE;
      return(false);
   }

   if (!FileSeek(hFile, 0, SEEK_END)) {
      __LOG_PER_INSTANCE = false; catch("logToInstanceLog(2)->FileSeek()"); __LOG_PER_INSTANCE = old.LOG_PER_INSTANCE;
      FileClose(hFile);
      return(_false(GetLastError()));
   }

   if (FileWrite(hFile, message) < 0) {
      __LOG_PER_INSTANCE = false; catch("logToInstanceLog(3)->FileWrite()"); __LOG_PER_INSTANCE = old.LOG_PER_INSTANCE;
      FileClose(hFile);
      return(_false(GetLastError()));
   }

   FileClose(hFile);
   return(true);
}


/**
 * Gibt optisch und akustisch eine Warnung aus.
 *
 * @param  string message - anzuzeigende Nachricht
 * @param  int    error   - anzuzeigender Fehlercode
 *
 * @return int - derselbe Fehlercode
 *
 *
 * NOTE: Nur bei Implementierung in der Headerdatei wird das aktuell laufende Modul als Auslöser angezeigt.
 */
int warn(string message, int error=NO_ERROR) {
   if (IsError(error))
      message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");


   // (1) Programmnamen ggf. um Instanz-ID erweitern
   string name = __NAME__;
   if (__LOG_INSTANCE_ID) {
      int pos = StringFind(name, "::");
      if (pos == -1) name = StringConcatenate(           __NAME__,       "(", InstanceId(NULL), ")");
      else           name = StringConcatenate(StringLeft(__NAME__, pos), "(", InstanceId(NULL), ")", StringRight(__NAME__, -pos));
   }


   // (2) Logging
   bool logged, alerted;
   if (__LOG_PER_INSTANCE)
      logged = logToInstanceLog(StringConcatenate("WARN: ", __NAME__, "::", message));                // ohne Instanz-ID, bei Fehler Fall-back zum Standard-Logging
   if (!logged) {
      Alert("WARN:   ", Symbol(), ",", PeriodDescription(NULL), "  ", name, "::", message);           // loggt automatisch, ggf. mit Instanz-ID
      alerted = true;
   }
   message = StringConcatenate(name, "::", message);


   // (3) Anzeige
   if (IsTesting()) {
      // im Tester: weder Alert() noch MessageBox() können verwendet werden
      string caption = StringConcatenate("Strategy Tester ", Symbol(), ",", PeriodDescription(NULL));
      pos = StringFind(message, ") ");                                                                // Message am ersten Leerzeichen nach der ersten
      if (pos == -1) message = StringConcatenate("WARN in ", message);                                // schließenden Klammer umbrechen
      else           message = StringConcatenate("WARN in ", StringLeft(message, pos+1), "\n\n", StringTrimLeft(StringRight(message, -pos-2)));

      ForceSound("alert.wav");
      ForceMessageBox(caption, message, MB_ICONERROR|MB_OK);
   }
   else if (!alerted) {
      // außerhalb des Testers
      Alert("WARN:   ", Symbol(), ",", PeriodDescription(NULL), "  ", message);
   }

   return(error);
}


/**
 * Prüft, ob ein Fehler aufgetreten ist und zeigt diesen optisch und akustisch an. Der Fehler wird in der globalen Variable last_error gespeichert.
 * Der mit der MQL-Funktion GetLastError() auslesbare letzte Fehler ist nach Aufruf dieser Funktion immer zurückgesetzt.
 *
 * @param  string location - Ortsbezeichner des Fehlers, kann zusätzlich eine anzuzeigende Nachricht enthalten
 * @param  int    error    - manuelles Forcieren eines bestimmten Fehlers
 * @param  bool   orderPop - ob ein zuvor gespeicherter Orderkontext wiederhergestellt werden soll (default: nein)
 *
 * @return int - der aufgetretene Fehler
 *
 *
 * NOTE: Nur bei Implementierung in der Headerdatei wird das aktuell laufende Modul als Auslöser angezeigt.
 */
int catch(string location, int error=NO_ERROR, bool orderPop=false) {
   if (error == NO_ERROR) error = GetLastError();
   else                           GetLastError();                    // externer Fehler angegeben, letzten tatsächlichen Fehler zurücksetzen

   if (error != NO_ERROR) {
      string message = StringConcatenate(location, "  [", error, " - ", ErrorDescription(error), "]");

      // (1) Programmnamen umschreiben
      string name = __NAME__;
      if (__LOG_INSTANCE_ID) {
         int pos = StringFind(name, "::");
         if (pos == -1) name = StringConcatenate(           __NAME__,       "(", InstanceId(NULL), ")");
         else           name = StringConcatenate(StringLeft(__NAME__, pos), "(", InstanceId(NULL), ")", StringRight(__NAME__, -pos));
      }

      // (2) Logging
      bool logged, alerted;
      if (__LOG_PER_INSTANCE)
         logged = logToInstanceLog(StringConcatenate("ERROR: ", __NAME__, "::", message));               // ohne Instanz-ID, bei Fehler Fall-back zum Standard-Logging
      if (!logged) {
         Alert("ERROR:   ", Symbol(), ",", PeriodDescription(NULL), "  ", name, "::", message);          // loggt automatisch, ggf. mit Instanz-ID
         alerted = true;
      }
      message = StringConcatenate(name, "::", message);

      // (3) Anzeige
      if (IsTesting()) {
         // im Tester: weder Alert() noch MessageBox() können verwendet werden
         string caption = StringConcatenate("Strategy Tester ", Symbol(), ",", PeriodDescription(NULL));
         pos = StringFind(message, ") ");                                                                // Message am ersten Leerzeichen nach der ersten
         if (pos == -1) message = StringConcatenate("ERROR in ", message);                               // schließenden Klammer umbrechen
         else           message = StringConcatenate("ERROR in ", StringLeft(message, pos+1), "\n\n", StringTrimLeft(StringRight(message, -pos-2)));

         ForceSound("alert.wav");
         ForceMessageBox(caption, message, MB_ICONERROR|MB_OK);
      }
      else if (!alerted) {
         // EA außerhalb des Testers, Script/Indikator im oder außerhalb des Testers
         Alert("ERROR:   ", Symbol(), ",", PeriodDescription(NULL), "  ", message);
      }
      SetLastError(error);                                                                               // je nach Programmtyp unterschiedlich Implementierung
   }

   if (orderPop)
      OrderPop(location);

   return(error);
   DummyCalls();
}


/**
 * Ob der angegebene Wert einen Fehler darstellt.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsError(int value) {
   return(value != NO_ERROR);
}


/**
 * Ob der angegebene Wert keinen Fehler darstellt.
 *
 * @param  int value
 *
 * @return bool
 */
bool IsNoError(int value) {
   return(value == NO_ERROR);
}


/**
 * Ob der interne Fehler-Code des aktuellen Moduls gesetzt ist.
 *
 * @return bool
 */
bool IsLastError() {
   return(last_error != NO_ERROR);
}


/**
 * Setzt den internen Fehlercode des aktuellen Moduls zurück.
 *
 * @return int - der vorm Zurücksetzen gesetzte Fehlercode
 */
int ResetLastError() {
   int error = last_error;
   SetLastError(NO_ERROR);
   return(error);
}


/**
 * Prüft, ob Events der angegebenen Typen aufgetreten sind und ruft bei Zutreffen deren Eventhandler auf.
 *
 * @param  int events - Event-Flags
 *
 * @return bool - ob mindestens eines der angegebenen Events aufgetreten ist
 *
 *
 * NOTE: Benutze HandleEvent(), um für die Prüfung weitere, event-spezifische Parameter anzugeben.
 */
bool HandleEvents(int events) {
   int status = 0;

   if (events & EVENT_BAR_OPEN        != 0) status |= HandleEvent(EVENT_BAR_OPEN       );
   if (events & EVENT_ORDER_PLACE     != 0) status |= HandleEvent(EVENT_ORDER_PLACE    );
   if (events & EVENT_ORDER_CHANGE    != 0) status |= HandleEvent(EVENT_ORDER_CHANGE   );
   if (events & EVENT_ORDER_CANCEL    != 0) status |= HandleEvent(EVENT_ORDER_CANCEL   );
   if (events & EVENT_POSITION_OPEN   != 0) status |= HandleEvent(EVENT_POSITION_OPEN  );
   if (events & EVENT_POSITION_CLOSE  != 0) status |= HandleEvent(EVENT_POSITION_CLOSE );
   if (events & EVENT_ACCOUNT_CHANGE  != 0) status |= HandleEvent(EVENT_ACCOUNT_CHANGE );
   if (events & EVENT_ACCOUNT_PAYMENT != 0) status |= HandleEvent(EVENT_ACCOUNT_PAYMENT);
   if (events & EVENT_CHART_CMD       != 0) status |= HandleEvent(EVENT_CHART_CMD      );
   if (events & EVENT_INTERNAL_CMD    != 0) status |= HandleEvent(EVENT_INTERNAL_CMD   );
   if (events & EVENT_EXTERNAL_CMD    != 0) status |= HandleEvent(EVENT_EXTERNAL_CMD   );

   return(status);                                                   // (bool) int
}


/**
 * Prüft, ob ein Event aufgetreten ist und ruft bei Zutreffen dessen Eventhandler auf. Ermöglicht die Angabe weiterer
 * eventspezifischer Prüfungskriterien.
 *
 * @param  int event    - Event-Flag
 * @param  int criteria - weitere eventspezifische Prüfungskriterien (default: keine)
 *
 * @return int - 1, wenn das Event aufgetreten ist; andererseits 0
 */
int HandleEvent(int event, int criteria=NULL) {
   bool   status;
   int    iResults[];                                                // die Listener müssen die Arrays selbst zurücksetzen
   string sResults[];                                                // ...

   switch (event) {
      case EVENT_BAR_OPEN       : if (EventListener.BarOpen        (iResults, criteria)) { status = true; onBarOpen        (iResults); } break;
      case EVENT_ORDER_PLACE    : if (EventListener.OrderPlace     (iResults, criteria)) { status = true; onOrderPlace     (iResults); } break;
      case EVENT_ORDER_CHANGE   : if (EventListener.OrderChange    (iResults, criteria)) { status = true; onOrderChange    (iResults); } break;
      case EVENT_ORDER_CANCEL   : if (EventListener.OrderCancel    (iResults, criteria)) { status = true; onOrderCancel    (iResults); } break;
      case EVENT_POSITION_OPEN  : if (EventListener.PositionOpen   (iResults, criteria)) { status = true; onPositionOpen   (iResults); } break;
      case EVENT_POSITION_CLOSE : if (EventListener.PositionClose  (iResults, criteria)) { status = true; onPositionClose  (iResults); } break;
      case EVENT_ACCOUNT_CHANGE : if (EventListener.AccountChange  (iResults, criteria)) { status = true; onAccountChange  (iResults); } break;
      case EVENT_ACCOUNT_PAYMENT: if (EventListener.AccountPayment (iResults, criteria)) { status = true; onAccountPayment (iResults); } break;
      case EVENT_CHART_CMD      : if (EventListener.ChartCommand   (sResults, criteria)) { status = true; onChartCommand   (sResults); } break;
      case EVENT_INTERNAL_CMD   : if (EventListener.InternalCommand(sResults, criteria)) { status = true; onInternalCommand(sResults); } break;
      case EVENT_EXTERNAL_CMD   : if (EventListener.ExternalCommand(sResults, criteria)) { status = true; onExternalCommand(sResults); } break;

      default:
         return(_false(catch("HandleEvent(1)   unknown event = "+ event, ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   return(status);                                                   // (int) bool
}


int stack.orderSelections[];                                         // @see OrderPush(), OrderPop()


/**
 * Ob das angegebene Ticket existiert und erreichbar ist.
 *
 * @param  int ticket - Ticket-Nr.
 *
 * @return bool
 *
 *
 * NOTE: Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Modul benutzt werden können.
 */
bool IsTicket(int ticket) {
   OrderPush("IsTicket(1)");

   bool result = OrderSelect(ticket, SELECT_BY_TICKET);

   GetLastError();
   OrderPop("IsTicket(2)");

   return(result);
}


/**
 * Selektiert ein Ticket.
 *
 * @param  int    ticket                  - Ticket-Nr.
 * @param  string location                - Bezeichner für evt. Fehlermeldung
 * @param  bool   storeSelection          - ob die aktuelle Selektion gespeichert werden soll (default: nein)
 * @param  bool   onErrorRestoreSelection - ob im Fehlerfall die letzte Selektion wiederhergestellt werden soll
 *                                          (default: bei storeSelection=TRUE ja; bei storeSelection=FALSE nein)
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Modul benutzt werden können.
 */
bool SelectTicket(int ticket, string location, bool storeSelection=false, bool onErrorRestoreSelection=false) {
   if (storeSelection) {
      OrderPush(location);
      onErrorRestoreSelection = true;
   }

   if (OrderSelect(ticket, SELECT_BY_TICKET))
      return(true);                             // Success

   if (onErrorRestoreSelection)                 // Fehler
      OrderPop(location);

   int error = GetLastError();
   return(_false(catch(location +"->SelectTicket()   ticket="+ ticket, ifInt(IsError(error), error, ERR_INVALID_TICKET))));
}


/**
 * Schiebt den aktuellen Orderkontext auf den Kontextstack (fügt ihn ans Ende an).
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return int - Ticket des aktuellen Kontexts oder 0, wenn keine Order selektiert ist oder ein Fehler auftrat
 *
 *
 * NOTE: Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Programm benutzt werden können.
 */
int OrderPush(string location) {
   int error = GetLastError();
   if (IsError(error))
      return(_ZERO(catch(location +"->OrderPush(1)", error)));

   int ticket = OrderTicket();

   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error != ERR_NO_ORDER_SELECTED)
      return(_ZERO(catch(location +"->OrderPush(2)", error)));

   ArrayPushInt(stack.orderSelections, ticket);
   return(ticket);
}


/**
 * Entfernt den letzten Orderkontext vom Ende des Kontextstacks und restauriert ihn.
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Programm benutzt werden können.
 */
bool OrderPop(string location) {
   int ticket = ArrayPopInt(stack.orderSelections);

   if (ticket > 0)
      return(SelectTicket(ticket, StringConcatenate(location, "->OrderPop()")));

   if (ticket==0) /*&&*/ if (IsLastError())
      return(false);

   OrderSelect(0, SELECT_BY_TICKET);
   return(true);
}


/**
 * Wartet darauf, daß das angegebene Ticket im OpenOrders- bzw. History-Pool des Accounts erscheint.
 *
 * @param  int  ticket    - Orderticket
 * @param  bool orderKeep - ob der aktuelle Orderkontext bewahrt werden soll (default: ja)
 *                          wenn FALSE, ist das angegebene Ticket nach Rückkehr selektiert
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Ist in der Headerdatei implementiert, um Default-Parameter zu ermöglichen.
 */
bool WaitForTicket(int ticket, bool orderKeep=true) {
   if (ticket <= 0)
      return(_false(catch("WaitForTicket(1)   illegal parameter ticket = "+ ticket, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (orderKeep) {
      if (OrderPush("WaitForTicket(2)") == 0)
         return(!IsLastError());
   }

   int i, delay=100;                                                 // je 0.1 Sekunden warten

   while (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      if (IsTesting())           warn(StringConcatenate("WaitForTicket(3)   #", ticket, " not yet accessible"));
      else if (i > 0 && i%10==0) warn(StringConcatenate("WaitForTicket(4)   #", ticket, " not yet accessible after ", DoubleToStr(i*delay/1000.0, 1), " s"));
      Sleep(delay);
      i++;
   }

   if (orderKeep) {
      if (!OrderPop("WaitForTicket(5)"))
         return(false);
   }

   return(true);
}


/**
 * Gibt den PipValue des aktuellen Instrument für die angegebene Lotsize zurück.
 *
 * @param  double lots - Lotsize (default: 1 lot)
 *
 * @return double - PipValue oder 0, falls ein Fehler auftrat
 *
 *
 * NOTE: Ist in der Headerdatei implementiert, um Default-Parameter zu ermöglichen.
 */
double PipValue(double lots = 1.0) {
   if (lots < 0.00000001) return(_ZERO(catch("PipValue(1)   illegal parameter lots = "+ NumberToStr(lots, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (TickSize == 0)     return(_ZERO(catch("PipValue(2)   illegal TickSize = "+ NumberToStr(TickSize, ".+"), ERR_RUNTIME_ERROR)));

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);          // TODO: wenn QuoteCurrency == AccountCurrency, ist dies nur ein einziges Mal notwendig

   int error = GetLastError();
   if (IsError(error)) return(_ZERO(catch("PipValue(3)", error)));
   if (tickValue == 0) return(_ZERO(catch("PipValue(4)   illegal TickValue = "+ NumberToStr(tickValue, ".+"), ERR_INVALID_MARKET_DATA)));

   return(Pip/TickSize * tickValue * lots);
}


/**
 * Ob im Tester das Logging für den aktuellen EA aktiviert ist. Standardmäßig ist im Tester das Logging zur Performancesteigerung NICHT aktiv.
 *
 * @return bool
 *
 *
 * NOTE: In der Headerdatei implementiert, um Verwendung vor Aufruf von stdlib_init() zu ermöglichen.
 */
bool Tester.IsLogging() {
   if (!IsExpert())
      return(false);

   string name = __NAME__;

   if (IsLibrary()) {
      if (StringLen(__NAME__) == 0)
         return(_false(catch("Tester.IsLogging()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
      name = StringSubstr(__NAME__, 0, StringFind(__NAME__, ":")) ;
   }
   return(GetConfigBool(name, "Logger.Tester", false));
}


/**
 * Inlined conditional Boolean-Statement.
 *
 * @param  bool condition
 * @param  bool thenValue
 * @param  bool elseValue
 *
 * @return bool
 */
bool ifBool(bool condition, bool thenValue, bool elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Integer-Statement.
 *
 * @param  bool condition
 * @param  int  thenValue
 * @param  int  elseValue
 *
 * @return int
 */
int ifInt(bool condition, int thenValue, int elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional Double-Statement.
 *
 * @param  bool   condition
 * @param  double thenValue
 * @param  double elseValue
 *
 * @return double
 */
double ifDouble(bool condition, double thenValue, double elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Inlined conditional String-Statement.
 *
 * @param  bool   condition
 * @param  string thenValue
 * @param  string elseValue
 *
 * @return string
 */
string ifString(bool condition, string thenValue, string elseValue) {
   if (condition)
      return(thenValue);
   return(elseValue);
}


/**
 * Korrekter Vergleich zweier Doubles auf "Lower-Then".
 *
 * @param  double double1 - erster Wert
 * @param  double double2 - zweiter Wert
 * @param  int    digits  - Anzahl der zu berücksichtigenden Nachkommastellen (default: 8)
 *
 * @return bool
 */
bool LT(double double1, double double2, int digits=8) {
   if (EQ(double1, double2, digits))
      return(false);
   return(double1 < double2);
}


/**
 * Korrekter Vergleich zweier Doubles auf "Lower-Or-Equal".
 *
 * @param  double double1 - erster Wert
 * @param  double double2 - zweiter Wert
 * @param  int    digits  - Anzahl der zu berücksichtigenden Nachkommastellen (default: 8)
 *
 * @return bool
 */
bool LE(double double1, double double2, int digits=8) {
   if (double1 < double2)
      return(true);
   return(EQ(double1, double2, digits));
}


/**
 * Korrekter Vergleich zweier Doubles auf Gleichheit "Equal".
 *
 * @param  double double1 - erster Wert
 * @param  double double2 - zweiter Wert
 * @param  int    digits  - Anzahl der zu berücksichtigenden Nachkommastellen (default: 8)
 *
 * @return bool
 */
bool EQ(double double1, double double2, int digits=8) {
   if (digits < 0 || digits > 8)
      return(_false(catch("EQ()   illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double diff = NormalizeDouble(double1, digits) - NormalizeDouble(double2, digits);
   if (diff < 0)
      diff = -diff;
   return(diff < 0.000000000000001);

   /*
   switch (digits) {
      case  0: return(diff <= 0                 );
      case  1: return(diff <= 0.1               );
      case  2: return(diff <= 0.01              );
      case  3: return(diff <= 0.001             );
      case  4: return(diff <= 0.0001            );
      case  5: return(diff <= 0.00001           );
      case  6: return(diff <= 0.000001          );
      case  7: return(diff <= 0.0000001         );
      case  8: return(diff <= 0.00000001        );
      case  9: return(diff <= 0.000000001       );
      case 10: return(diff <= 0.0000000001      );
      case 11: return(diff <= 0.00000000001     );
      case 12: return(diff <= 0.000000000001    );
      case 13: return(diff <= 0.0000000000001   );
      case 14: return(diff <= 0.00000000000001  );
      case 15: return(diff <= 0.000000000000001 );
      case 16: return(diff <= 0.0000000000000001);
   }
   return(_false(catch("EQ()   illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));
   */
}


/**
 * Korrekter Vergleich zweier Doubles auf Ungleichheit "Not-Equal".
 *
 * @param  double double1 - erster Wert
 * @param  double double2 - zweiter Wert
 * @param  int    digits  - Anzahl der zu berücksichtigenden Nachkommastellen (default: 8)
 *
 * @return bool
 */
bool NE(double double1, double double2, int digits=8) {
   return(!EQ(double1, double2, digits));
}


/**
 * Korrekter Vergleich zweier Doubles auf "Greater-Or-Equal".
 *
 * @param  double double1 - erster Wert
 * @param  double double2 - zweiter Wert
 * @param  int    digits  - Anzahl der zu berücksichtigenden Nachkommastellen (default: 8)
 *
 * @return bool
 */
bool GE(double double1, double double2, int digits=8) {
   if (double1 > double2)
      return(true);
   return(EQ(double1, double2, digits));
}


/**
 * Korrekter Vergleich zweier Doubles auf "Greater-Then".
 *
 * @param  double double1 - erster Wert
 * @param  double double2 - zweiter Wert
 * @param  int    digits  - Anzahl der zu berücksichtigenden Nachkommastellen (default: 8)
 *
 * @return bool
 */
bool GT(double double1, double double2, int digits=8) {
   if (EQ(double1, double2, digits))
      return(false);
   return(double1 > double2);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als boolean TRUE zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return bool - TRUE
 */
bool _true(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(true);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als boolean FALSE zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return bool - FALSE
 */
bool _false(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(false);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als NULL = 0 (int) zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden. Ist funktional identisch zu _ZERO().
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - NULL
 */
int _NULL(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(NULL);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den Fehlerstatus NO_ERROR zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden. Ist funktional identisch zu _ZERO().
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - NO_ERROR
 */
int _NO_ERROR(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(NO_ERROR);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den letzten Fehlercode zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - last_error
 */
int _last_error(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(last_error);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als (int) 0 zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return int - 0
 */
int _ZERO(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(0);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als "" (Leerstring) zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  beliebige Parameter (werden ignoriert)
 *
 * @return string - Leerstring
 */
string _empty(int param1=NULL, int param2=NULL, int param3=NULL) {
   return("");
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  bool param1 - Boolean
 * @param  ...         - beliebige weitere Parameter (werden ignoriert)
 *
 * @return bool - der erste Parameter
 */
bool _bool(bool param1, int param2=NULL, int param3=NULL) {
   return(param1);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  int param1 - Integer
 * @param  ...        - beliebige weitere Parameter (werden ignoriert)
 *
 * @return int - der erste Parameter
 */
int _int(int param1, int param2=NULL, int param3=NULL) {
   return(param1);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  double param1 - Double
 * @param  ...           - beliebige weitere Parameter (werden ignoriert)
 *
 * @return double - der erste Parameter
 */
double _double(double param1, int param2=NULL, int param3=NULL) {
   return(param1);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als den ersten Parameter zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  string param1 - String
 * @param  ...           - beliebige weitere Parameter (werden ignoriert)
 *
 * @return string - der erste Parameter
 */
string _string(string param1, int param2=NULL, int param3=NULL) {
   return(param1);
}


/**
 * Integer-Version von MathMin()
 *
 * Ermittelt die kleinere zweier Ganzzahlen.
 *
 * @param  int  value1
 * @param  int  value2
 *
 * @return int
 */
int Min(int value1, int value2) {
   if (value1 < value2)
      return(value1);
   return(value2);
}


/**
 * Integer-Version von MathMax()
 *
 * Ermittelt die größere zweier Ganzzahlen.
 *
 * @param  int  value1
 * @param  int  value2
 *
 * @return int
 */
int Max(int value1, int value2) {
   if (value1 > value2)
      return(value1);
   return(value2);
}


/**
 * Integer-Version von MathAbs()
 *
 * Ermittelt den Absolutwert einer Ganzzahl.
 *
 * @param  int  value
 *
 * @return int
 */
int Abs(int value) {
   if (value < 0)
      return(-value);
   return(value);
}


/**
 * Gibt das Vorzeichen einer Zahl zurück.
 *
 * @param  double number - Zahl
 *
 * @return int - Vorzeichen (+1, 0, -1)
 */
int Sign(double number) {
   if (GT(number, 0)) return( 1);
   if (LT(number, 0)) return(-1);
   return(0);
}


/**
 * Integer-Version von MathRound(), entspricht dem sauberen Casten eines Doubles in einen Integer.
 *
 * @param  double value - Zahl
 *
 * @return int
 */
int Round(double value) {
   value = MathRound(value);
   if (value < 0) value -= 0.1;
   else           value += 0.1;
   return(value);
}


/**
 * Integer-Version von MathFloor()
 *
 * @param  double value - Zahl
 *
 * @return int
 */
int Floor(double value) {
   return(Round(MathFloor(value)));
}


/**
 * Integer-Version von MathCeil()
 *
 * @param  double value - Zahl
 *
 * @return int
 */
int Ceil(double value) {
   return(Round(MathCeil(value)));
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   _bool(NULL);
   _double(NULL);
   _empty();
   _false();
   _int(NULL);
   _last_error();
   _NO_ERROR();
   _NULL();
   _string(NULL);
   _true();
   _ZERO();
   Abs(NULL);
   catch(NULL, NULL, NULL);
   Ceil(NULL);
   debug(NULL);
   EQ(NULL, NULL);
   Floor(NULL);
   GE(NULL, NULL);
   GT(NULL, NULL);
   HandleEvent(NULL);
   HandleEvents(NULL);
   ifBool(NULL, NULL, NULL);
   ifDouble(NULL, NULL, NULL);
   ifInt(NULL, NULL, NULL);
   ifString(NULL, NULL, NULL);
   Indicator.IsICustom();
   IsError(NULL);
   IsExpert();
   IsIndicator();
   IsLastError();
   IsNoError(NULL);
   IsScript();
   IsTicket(NULL);
   LE(NULL, NULL);
   log(NULL);
   logToInstanceLog(NULL);
   LT(NULL, NULL);
   Max(NULL, NULL);
   Min(NULL, NULL);
   NE(NULL, NULL);
   OrderPop(NULL);
   OrderPush(NULL);
   PipValue();
   ResetLastError();
   Round(NULL);
   SelectTicket(NULL, NULL);
   SetLastError(NULL);
   Sign(NULL);
   start.RelaunchInputDialog();
   Tester.IsLogging();
   WaitForTicket(NULL);
   warn(NULL);
}

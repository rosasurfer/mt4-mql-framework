/**
 * Globale MQL-Funktionen, Variablen und Konstanten.
 */


// Programmtypen
#define T_INDICATOR              1
#define T_EXPERT                 2
#define T_SCRIPT                 3


// Special constants
#define NULL                     0     //
#define EMPTY                   -1     //
#define EMPTY_VALUE     0x7FFFFFFF     // empty custom indicator value (= 2147483647)
#define CLR_NONE                -1     // no color
#define WHOLE_ARRAY              0     //


// Strings
#define MT4_TERMINAL_CLASSNAME   "MetaQuotes::MetaTrader::4.00"
#define MAX_STRING_LITERAL       "..............................................................................................................................................................................................................................................................."
#define NL                       "\n"     // new line (entspricht in MQL CR+LF)
#define TAB                      "\t"


// Chars
#define PLACEHOLDER_ZERO_CHAR    '…'     // 0x85 - Platzhalter für NULL-Byte in Strings,         siehe BufferToStr()
#define PLACEHOLDER_CTL_CHAR     '•'     // 0x95 - Platzhalter für Control-Character in Strings, siehe BufferToStr()


// Mathematische Konstanten
#define Math.PI                  3.14159265358979323846264338327950288419716939937510     // intern 3.141592653589793 (15 korrekte Dezimalstellen)


// Zeitkonstanten
#define SECOND                   1
#define MINUTE                  60
#define HOUR                  3600
#define DAY                  86400
#define WEEK                604800

#define SECONDS             SECOND
#define MINUTES             MINUTE
#define HOURS                 HOUR
#define DAYS                   DAY
#define WEEKS                 WEEK


// Wochentage, siehe TimeDayOfWeek()
#define SUNDAY                   0
#define MONDAY                   1
#define TUESDAY                  2
#define WEDNESDAY                3
#define THURSDAY                 4
#define FRIDAY                   5
#define SATURDAY                 6


// Timeframe-Identifier, siehe Period()
#define PERIOD_M1                1     // 1 minute
#define PERIOD_M5                5     // 5 minutes
#define PERIOD_M15              15     // 15 minutes
#define PERIOD_M30              30     // 30 minutes
#define PERIOD_H1               60     // 1 hour
#define PERIOD_H4              240     // 4 hours
#define PERIOD_D1             1440     // daily
#define PERIOD_W1            10080     // weekly
#define PERIOD_MN1           43200     // monthly


// Timeframe-Flags, können logisch kombiniert werden, siehe EventListener.Baropen()
#define PERIODFLAG_M1            1     // 1 minute
#define PERIODFLAG_M5            2     // 5 minutes
#define PERIODFLAG_M15           4     // 15 minutes
#define PERIODFLAG_M30           8     // 30 minutes
#define PERIODFLAG_H1           16     // 1 hour
#define PERIODFLAG_H4           32     // 4 hours
#define PERIODFLAG_D1           64     // daily
#define PERIODFLAG_W1          128     // weekly
#define PERIODFLAG_MN1         256     // monthly


// Operation-Types, siehe OrderSend() u. OrderType()
#define OP_BUY                   0     // long position
#define OP_LONG             OP_BUY
#define OP_SELL                  1     // short position
#define OP_SHORT           OP_SELL
#define OP_BUYLIMIT              2     // buy limit order
#define OP_SELLLIMIT             3     // sell limit order
#define OP_BUYSTOP               4     // stop buy order
#define OP_SELLSTOP              5     // stop sell order
#define OP_BALANCE               6     // account credit or withdrawel transaction
#define OP_CREDIT                7     // credit facility, no transaction


// Custom Operation-Types
#define OP_UNDEFINED            -1     // Default-Wert für nicht initialisierte Variable
#define OP_TRANSFER              8     // Balance-Änderung durch Kunden (Ein-/Auszahlung)
#define OP_VENDOR                9     // Balance-Änderung durch Criminal (Swap, sonstiges)


// Order-Flags, können logisch kombiniert werden, siehe EventListener.PositionOpen() u. EventListener.PositionClose()
#define OFLAG_CURRENTSYMBOL      1     // order of current symbol (active chart)
#define OFLAG_BUY                2     // long order
#define OFLAG_SELL               4     // short order
#define OFLAG_MARKETORDER        8     // market order
#define OFLAG_PENDINGORDER      16     // pending order (Limit- oder Stop-Order)


// OrderSelect-ID's zur Steuerung des Stacks der Orderkontexte, siehe OrderPush(), OrderPop() etc.
#define O_PUSH                   1
#define O_POP                    2


// Series array identifier, siehe ArrayCopySeries(), iLowest() u. iHighest()
#define MODE_OPEN                0     // open price
#define MODE_LOW                 1     // low price
#define MODE_HIGH                2     // high price
#define MODE_CLOSE               3     // close price
#define MODE_VOLUME              4     // volume
#define MODE_TIME                5     // bar open time


// MA method identifiers, siehe iMA()
#define MODE_SMA                 0     // simple moving average
#define MODE_EMA                 1     // exponential moving average
#define MODE_SMMA                2     // smoothed moving average
#define MODE_LWMA                3     // linear weighted moving average
#define MODE_ALMA                4     // Arnaud Legoux moving average


// Indicator line identifiers used in iMACD(), iRVI() and iStochastic()
#define MODE_MAIN                0     // base indicator line
#define MODE_SIGNAL              1     // signal line


// Indicator line identifiers used in iADX()
#define MODE_MAIN                0     // base indicator line
#define MODE_PLUSDI              1     // +DI indicator line
#define MODE_MINUSDI             2     // -DI indicator line


// Indicator line identifiers used in iBands(), iEnvelopes(), iEnvelopesOnArray(), iFractals() and iGator()
#define MODE_UPPER               1     // upper line
#define MODE_LOWER               2     // lower line

#define B_LOWER                  0
#define B_UPPER                  1


// Sorting modes, siehe ArraySort()
#define MODE_ASCEND              1     // aufsteigend
#define MODE_DESCEND             2     // absteigend


// Price identifiers, siehe iMA()
#define PRICE_CLOSE              0     // close price
#define PRICE_OPEN               1     // open price
#define PRICE_HIGH               2     // high price
#define PRICE_LOW                3     // low price
#define PRICE_MEDIAN             4     // median price: (high+low)/2
#define PRICE_TYPICAL            5     // typical price: (high+low+close)/3
#define PRICE_WEIGHTED           6     // weighted close price: (high+low+close+close)/4

#define PRICE_BID                7
#define PRICE_ASK                8


// Rates array identifier, siehe ArrayCopyRates()
#define RATE_TIME                0     // bar open time
#define RATE_OPEN                1     // open price
#define RATE_LOW                 2     // low price
#define RATE_HIGH                3     // high price
#define RATE_CLOSE               4     // close price
#define RATE_VOLUME              5     // volume


// Event-Identifier siehe event()
#define EVENT_BAR_OPEN           1
#define EVENT_ORDER_PLACE        2
#define EVENT_ORDER_CHANGE       4
#define EVENT_ORDER_CANCEL       8
#define EVENT_POSITION_OPEN     16
#define EVENT_POSITION_CLOSE    32
#define EVENT_ACCOUNT_CHANGE    64
#define EVENT_ACCOUNT_PAYMENT  128     // Ein- oder Auszahlung
#define EVENT_HISTORY_CHANGE   256     // EVENT_POSITION_CLOSE | EVENT_ACCOUNT_PAYMENT


// Array-Identifier zum Zugriff auf verschiedene Pivotlevel, siehe iPivotLevel()
#define PIVOT_R3                 0
#define PIVOT_R2                 1
#define PIVOT_R1                 2
#define PIVOT_PP                 3
#define PIVOT_S1                 4
#define PIVOT_S2                 5
#define PIVOT_S3                 6


// Konstanten zum Zugriff auf die Spalten der Account-History
#define HISTORY_COLUMNS         22
#define AH_TICKET                0
#define AH_OPENTIME              1
#define AH_OPENTIMESTAMP         2
#define AH_TYPEDESCRIPTION       3
#define AH_TYPE                  4
#define AH_SIZE                  5
#define AH_SYMBOL                6
#define AH_OPENPRICE             7
#define AH_STOPLOSS              8
#define AH_TAKEPROFIT            9
#define AH_CLOSETIME            10
#define AH_CLOSETIMESTAMP       11
#define AH_CLOSEPRICE           12
#define AH_EXPIRATIONTIME       13
#define AH_EXPIRATIONTIMESTAMP  14
#define AH_MAGICNUMBER          15
#define AH_COMMISSION           16
#define AH_SWAP                 17
#define AH_NETPROFIT            18
#define AH_GROSSPROFIT          19
#define AH_BALANCE              20
#define AH_COMMENT              21


// Margin calculation modes, siehe MarketInfo(symbol, MODE_MARGINCALCMODE)
#define MCM_FOREX                0
#define MCM_CFD                  1
#define MCM_CFDFUTURES           2
#define MCM_CFDINDEX             3
#define MCM_CFDLEVERAGE          4     // MT4, doch erst seit MT5 dokumentiert


// Swap calculation modes, siehe MarketInfo(symbol, MODE_SWAPTYPE)
#define SCM_POINTS               0
#define SCM_BASE_CURRENCY        1
#define SCM_INTEREST             2
#define SCM_MARGIN_CURRENCY      3     // Deposit-Currency


// Profit calculation modes, siehe MarketInfo(symbol, MODE_PROFITCALCMODE)
#define PCM_FOREX                0
#define PCM_CFD                  1
#define PCM_FUTURES              2


// Account stopout modes, siehe AccountStopoutMode()
#define ASM_PERCENT              0
#define ASM_ABSOLUTE             1


// Flags zur Objektpositionierung, siehe ObjectSet(label, OBJPROP_CORNER,  int)
#define CORNER_TOP_LEFT          0
#define CORNER_TOP_RIGHT         1
#define CORNER_BOTTOM_LEFT       2
#define CORNER_BOTTOM_RIGHT      3


// deinit()-Reasons, siehe UninitializeReason()
#define REASON_APPEXIT           0   // application exit
#define REASON_REMOVE            1   // program removed from chart
#define REASON_RECOMPILE         2   // program recompiled
#define REASON_CHARTCHANGE       3   // chart symbol or timeframe changed
#define REASON_CHARTCLOSE        4   // chart closed
#define REASON_PARAMETERS        5   // input parameters changed by user
#define REASON_ACCOUNT           6   // account changed


// Currency-ID's
#define CID_AUD                  1
#define CID_CAD                  2
#define CID_CHF                  3
#define CID_EUR                  4
#define CID_GBP                  5
#define CID_JPY                  6
#define CID_USD                  7  // zuerst die ID's der LFX-Währungen, dadurch "passen" diese in 3 Bits

#define CID_CNY                  8
#define CID_CZK                  9
#define CID_DKK                 10
#define CID_HKD                 11
#define CID_HRK                 12
#define CID_HUF                 13
#define CID_INR                 14
#define CID_LTL                 15
#define CID_LVL                 16
#define CID_MXN                 17
#define CID_NOK                 18
#define CID_NZD                 19
#define CID_PLN                 20
#define CID_RUB                 21
#define CID_SAR                 22
#define CID_SEK                 23
#define CID_SGD                 24
#define CID_THB                 25
#define CID_TRY                 26
#define CID_TWD                 27
#define CID_ZAR                 28


// Currency-Kürzel
#define C_AUD                "AUD"
#define C_CAD                "CAD"
#define C_CHF                "CHF"
#define C_CNY                "CNY"
#define C_CZK                "CZK"
#define C_DKK                "DKK"
#define C_EUR                "EUR"
#define C_GBP                "GBP"
#define C_HKD                "HKD"
#define C_HRK                "HRK"
#define C_HUF                "HUF"
#define C_INR                "INR"
#define C_JPY                "JPY"
#define C_LTL                "LTL"
#define C_LVL                "LVL"
#define C_MXN                "MXN"
#define C_NOK                "NOK"
#define C_NZD                "NZD"
#define C_PLN                "PLN"
#define C_RUB                "RUB"
#define C_SAR                "SAR"
#define C_SEK                "SEK"
#define C_SGD                "SGD"
#define C_USD                "USD"
#define C_THB                "THB"
#define C_TRY                "TRY"
#define C_TWD                "TWD"
#define C_ZAR                "ZAR"


// Flags für zusätzliche Initialisierungstasks, siehe onInit()
#define IT_CHECK_TIMEZONE_CONFIG                        1  // prüft die Timezone-Konfiguration des aktuellen MT-Servers
#define IT_RESET_BARS_ON_HIST_UPDATE                    2  //


// MessageBox() flags
#define MB_OK                                  0x00000000  // buttons
#define MB_OKCANCEL                            0x00000001
#define MB_ABORTRETRYIGNORE                    0x00000002
#define MB_CANCELTRYCONTINUE                   0x00000006
#define MB_RETRYCANCEL                         0x00000005
#define MB_YESNO                               0x00000004
#define MB_YESNOCANCEL                         0x00000003
#define MB_HELP                                0x00004000  // additional help button

#define MB_DEFBUTTON1                          0x00000000  // default button
#define MB_DEFBUTTON2                          0x00000100
#define MB_DEFBUTTON3                          0x00000200
#define MB_DEFBUTTON4                          0x00000300

#define MB_ICONEXCLAMATION                     0x00000030  // icons
#define MB_ICONWARNING                 MB_ICONEXCLAMATION
#define MB_ICONINFORMATION                     0x00000040
#define MB_ICONASTERISK                MB_ICONINFORMATION
#define MB_ICONQUESTION                        0x00000020
#define MB_ICONSTOP                            0x00000010
#define MB_ICONERROR                          MB_ICONSTOP
#define MB_ICONHAND                           MB_ICONSTOP
#define MB_USERICON                            0x00000080

#define MB_APPLMODAL                           0x00000000  // modality
#define MB_SYSTEMMODAL                         0x00001000
#define MB_TASKMODAL                           0x00002000

#define MB_DEFAULT_DESKTOP_ONLY                0x00020000  // other
#define MB_RIGHT                               0x00080000
#define MB_RTLREADING                          0x00100000
#define MB_SETFOREGROUND                       0x00010000
#define MB_TOPMOST                             0x00040000
#define MB_NOFOCUS                             0x00008000
#define MB_SERVICE_NOTIFICATION                0x00200000


// MessageBox() return codes
#define IDOK                                            1
#define IDCANCEL                                        2
#define IDABORT                                         3
#define IDRETRY                                         4
#define IDIGNORE                                        5
#define IDYES                                           6
#define IDNO                                            7
#define IDCLOSE                                         8
#define IDHELP                                          9
#define IDTRYAGAIN                                     10
#define IDCONTINUE                                     11


// Arrow-Codes, siehe ObjectSet(label, OBJPROP_ARROWCODE, value)
#define SYMBOL_ORDEROPEN                                1   // right pointing arrow (default open ticket marker)
#define SYMBOL_ORDEROPEN_UP              SYMBOL_ORDEROPEN   // right pointing up arrow                               // ??? wird so nicht angezeigt
#define SYMBOL_ORDEROPEN_DOWN                           2   // right pointing down arrow                             // ??? wird so nicht angezeigt
#define SYMBOL_ORDERCLOSE                               3   // left pointing arrow (default closed ticket marker)

#define SYMBOL_DASH                                     4   // dash symbol (default stoploss and takeprofit marker)
#define SYMBOL_LEFTPRICE                                5   // left sided price label
#define SYMBOL_RIGHTPRICE                               6   // right sided price label
#define SYMBOL_THUMBSUP                                67   // thumb up symbol
#define SYMBOL_THUMBSDOWN                              68   // thumb down symbol
#define SYMBOL_ARROWUP                                241   // arrow up symbol
#define SYMBOL_ARROWDOWN                              242   // arrow down symbol
#define SYMBOL_STOPSIGN                               251   // stop sign symbol
#define SYMBOL_CHECKSIGN                              252   // check sign symbol


// MQL-Fehlercodes (Win32-Fehlercodes siehe win32api.mqh)
#define ERR_NO_ERROR                                    0
#define NO_ERROR                             ERR_NO_ERROR

// trade server errors
#define ERR_NO_RESULT                                   1
#define ERR_COMMON_ERROR                                2   // trade denied
#define ERR_INVALID_TRADE_PARAMETERS                    3
#define ERR_SERVER_BUSY                                 4
#define ERR_OLD_VERSION                                 5
#define ERR_NO_CONNECTION                               6
#define ERR_NOT_ENOUGH_RIGHTS                           7
#define ERR_TOO_FREQUENT_REQUESTS                       8
#define ERR_MALFUNCTIONAL_TRADE                         9
#define ERR_ACCOUNT_DISABLED                           64
#define ERR_INVALID_ACCOUNT                            65
#define ERR_TRADE_TIMEOUT                             128
#define ERR_INVALID_PRICE                             129   // Kurs bewegt sich zu schnell (aus dem Fenster)
#define ERR_INVALID_STOPS                             130
#define ERR_INVALID_TRADE_VOLUME                      131
#define ERR_MARKET_CLOSED                             132
#define ERR_TRADE_DISABLED                            133
#define ERR_NOT_ENOUGH_MONEY                          134
#define ERR_PRICE_CHANGED                             135
#define ERR_OFF_QUOTES                                136
#define ERR_BROKER_BUSY                               137
#define ERR_REQUOTE                                   138
#define ERR_ORDER_LOCKED                              139
#define ERR_LONG_POSITIONS_ONLY_ALLOWED               140
#define ERR_TOO_MANY_REQUESTS                         141
#define ERR_TRADE_MODIFY_DENIED                       145
#define ERR_TRADE_CONTEXT_BUSY                        146
#define ERR_TRADE_EXPIRATION_DENIED                   147
#define ERR_TRADE_TOO_MANY_ORDERS                     148
#define ERR_TRADE_HEDGE_PROHIBITED                    149
#define ERR_TRADE_PROHIBITED_BY_FIFO                  150

// runtime errors
#define ERR_RUNTIME_ERROR                            4000   // common runtime error (no mql error)
#define ERR_WRONG_FUNCTION_POINTER                   4001
#define ERR_ARRAY_INDEX_OUT_OF_RANGE                 4002
#define ERR_NO_MEMORY_FOR_CALL_STACK                 4003
#define ERR_RECURSIVE_STACK_OVERFLOW                 4004
#define ERR_NOT_ENOUGH_STACK_FOR_PARAM               4005
#define ERR_NO_MEMORY_FOR_PARAM_STRING               4006
#define ERR_NO_MEMORY_FOR_TEMP_STRING                4007
#define ERR_NOT_INITIALIZED_STRING                   4008
#define ERR_NOT_INITIALIZED_ARRAYSTRING              4009
#define ERR_NO_MEMORY_FOR_ARRAYSTRING                4010
#define ERR_TOO_LONG_STRING                          4011
#define ERR_REMAINDER_FROM_ZERO_DIVIDE               4012
#define ERR_ZERO_DIVIDE                              4013
#define ERR_UNKNOWN_COMMAND                          4014
#define ERR_WRONG_JUMP                               4015
#define ERR_NOT_INITIALIZED_ARRAY                    4016
#define ERR_DLL_CALLS_NOT_ALLOWED                    4017
#define ERR_CANNOT_LOAD_LIBRARY                      4018
#define ERR_CANNOT_CALL_FUNCTION                     4019
#define ERR_EXTERNAL_CALLS_NOT_ALLOWED               4020
#define ERR_NO_MEMORY_FOR_RETURNED_STR               4021
#define ERR_SYSTEM_BUSY                              4022
#define ERR_INVALID_FUNCTION_PARAMSCNT               4050   // invalid parameters count
#define ERR_INVALID_FUNCTION_PARAMVALUE              4051   // invalid parameter value
#define ERR_STRING_FUNCTION_INTERNAL                 4052
#define ERR_SOME_ARRAY_ERROR                         4053   // some array error
#define ERR_INCORRECT_SERIESARRAY_USING              4054
#define ERR_CUSTOM_INDICATOR_ERROR                   4055   // custom indicator error
#define ERR_INCOMPATIBLE_ARRAYS                      4056   // incompatible arrays
#define ERR_GLOBAL_VARIABLES_PROCESSING              4057
#define ERR_GLOBAL_VARIABLE_NOT_FOUND                4058
#define ERR_FUNC_NOT_ALLOWED_IN_TESTING              4059
#define ERR_FUNCTION_NOT_CONFIRMED                   4060
#define ERR_SEND_MAIL_ERROR                          4061
#define ERR_STRING_PARAMETER_EXPECTED                4062
#define ERR_INTEGER_PARAMETER_EXPECTED               4063
#define ERR_DOUBLE_PARAMETER_EXPECTED                4064
#define ERR_ARRAY_AS_PARAMETER_EXPECTED              4065
#define ERR_HISTORY_WILL_UPDATED                     4066   // history in update state
#define ERR_HISTORY_UPDATE       ERR_HISTORY_WILL_UPDATED
#define ERR_TRADE_ERROR                              4067   // error in trading function
#define ERR_END_OF_FILE                              4099   // end of file
#define ERR_SOME_FILE_ERROR                          4100   // some file error
#define ERR_WRONG_FILE_NAME                          4101
#define ERR_TOO_MANY_OPENED_FILES                    4102
#define ERR_CANNOT_OPEN_FILE                         4103
#define ERR_INCOMPATIBLE_FILEACCESS                  4104
#define ERR_NO_ORDER_SELECTED                        4105   // no order selected
#define ERR_UNKNOWN_SYMBOL                           4106   // unknown symbol
#define ERR_INVALID_PRICE_PARAM                      4107
#define ERR_INVALID_TICKET                           4108   // invalid ticket
#define ERR_TRADE_NOT_ALLOWED                        4109
#define ERR_LONGS_NOT_ALLOWED                        4110
#define ERR_SHORTS_NOT_ALLOWED                       4111
#define ERR_OBJECT_ALREADY_EXISTS                    4200
#define ERR_UNKNOWN_OBJECT_PROPERTY                  4201
#define ERR_OBJECT_DOES_NOT_EXIST                    4202
#define ERR_UNKNOWN_OBJECT_TYPE                      4203
#define ERR_NO_OBJECT_NAME                           4204
#define ERR_OBJECT_COORDINATES_ERROR                 4205
#define ERR_NO_SPECIFIED_SUBWINDOW                   4206
#define ERR_SOME_OBJECT_ERROR                        4207

// custom errors
#define ERR_WIN32_ERROR                              5000   // win32 api error
#define ERR_FUNCTION_NOT_IMPLEMENTED                 5001   // function not implemented
#define ERR_INVALID_INPUT_PARAMVALUE                 5002   // invalid input parameter value
#define ERR_INVALID_CONFIG_PARAMVALUE                5003   // invalid configuration parameter value
#define ERR_TERMINAL_NOT_YET_READY                   5004   // terminal not yet ready
#define ERR_INVALID_TIMEZONE_CONFIG                  5005   // invalid or missing timezone configuration
#define ERR_INVALID_MARKETINFO                       5006   // invalid MarketInfo() data
#define ERR_FILE_NOT_FOUND                           5007   // file not found
#define ERR_CANCELLED_BY_USER                        5008   // action cancelled by user intervention


// globale Variablen, die überall zur Verfügung stehen
int    __TYPE__;                                            // Typ des laufenden Programms (T_INDICATOR | T_EXPERT | T_SCRIPT)
string __SCRIPT__;                                          // Name des laufenden Programms

bool   init       = true;                                   // Flag, wird nach erfolgreichem Verlassen von init() zurückgesetzt
int    last_error = NO_ERROR;                               // der letzte aufgetretene Fehler des aktuellen Aufrufs
int    prev_error = NO_ERROR;                               // der letzte aufgetretene Fehler des vorherigen Ticks bzw. Aufrufs

double Pip, Pips;                                           // Betrag eines Pips des aktuellen Symbols (z.B. 0.0001 = PipSize)
int    PipDigits;                                           // Digits eines Pips des aktuellen Symbols (Annahme: Pips sind gradzahlig)
int    PipPoint, PipPoints;                                 // Auflösung eines Pips des aktuellen Symbols (Anzahl der Punkte auf der Dezimalskala je Pip)
double TickSize;                                            // kleinste Änderung des Preises des aktuellen Symbols je Tick (Vielfaches von MODE_POINT)
string PriceFormat;                                         // Preisformat des aktuellen Symbols für NumberToStr()
int    Tick, Ticks;
int    ValidBars;
int    ChangedBars;

string objects[];


// Variablen für ChartInfo-Funktionen, diese werden sowohl im Indikator ChartInfos als auch in jedem EA verwendet.
string ChartInfo.instrument,
       ChartInfo.price,
       ChartInfo.spread,
       ChartInfo.unitSize,
       ChartInfo.position,
       ChartInfo.time,
       ChartInfo.freezeLevel,
       ChartInfo.stopoutLevel;

int    ChartInfo.appliedPrice = PRICE_MEDIAN;               // Bid | Ask | Median (default)

double ChartInfo.leverage,                                  // Hebel zur UnitSize-Berechnung
       ChartInfo.longPosition,
       ChartInfo.shortPosition,
       ChartInfo.totalPosition;

bool   ChartInfo.positionChecked,
       ChartInfo.noPosition,
       ChartInfo.flatPosition;


/**
 * Setzt allgemein benötigte interne Variablen und führt allgemein benötigte Laufzeit-Initialisierungen durch.
 *
 * @param  int    scriptType - Typ des aufrufenden Programms
 * @param  int    initFlags  - optionale, zusätzlich durchzuführende Initialisierungstasks (default: NULL)
 *                             Werte: [IT_CHECK_TIMEZONE_CONFIG | IT_RESET_BARS_ON_HIST_UPDATE]
 * @return int - Fehlerstatus
 */
int onInit(int scriptType, int initFlags=NULL) {
   __TYPE__   = scriptType;
   __SCRIPT__ = WindowExpertName();
   last_error = stdlib_onInit(__TYPE__, __SCRIPT__, initFlags, UninitializeReason());

   if (last_error == NO_ERROR) {
      PipDigits   = Digits & (~1);
      PipPoint    = MathPow(10, Digits-PipDigits) +0.1;              // (int) double
      PipPoints   = PipPoint;
      Pip         = 1/MathPow(10, PipDigits);
      Pips        = Pip;
      PriceFormat = StringConcatenate(".", PipDigits, ifString(Digits==PipDigits, "", "'"));
      TickSize    = MarketInfo(Symbol(), MODE_TICKSIZE);

      int error = GetLastError();
      if (error == ERR_UNKNOWN_SYMBOL) {                             // Symbol nicht subscribed (Start, Account- oder Templatewechsel)
         last_error = ERR_TERMINAL_NOT_YET_READY;                    // (das Symbol kann später evt. noch "auftauchen")
      }
      else if (IsError(error))        return(catch("onInit(1)", error));
      else if (TickSize < 0.00000001) return(catch("onInit(2)   TickSize = "+ NumberToStr(TickSize, ".+"), ERR_INVALID_MARKETINFO));
   }

   if (last_error == NO_ERROR) {
    //if (initFlags & IT_CHECK_TIMEZONE_CONFIG     != 0) {}          // @see stdlib_onInit(): dort ist das Errorhandling der entspr. Funktion einfacher
   }

   if (last_error == NO_ERROR) {
      if (initFlags & IT_RESET_BARS_ON_HIST_UPDATE != 0) {}          // noch nicht implementiert
   }

   if (last_error == NO_ERROR) {
      if (IsExpert()) {                                              // nach Neuladen eines EA's seinen Orderkontext ausdrücklich zurücksetzen
         int reasons[] = { REASON_REMOVE, REASON_CHARTCLOSE, REASON_ACCOUNT, REASON_APPEXIT };
         if (IntInArray(UninitializeReason(), reasons))
            OrderSelect(0, SELECT_BY_TICKET);
      }
   }

   if (last_error == NO_ERROR) {
      if (IsVisualMode()) {
         // Im Tester übernimmt der jeweilige EA die Chartinfo-Anzeige, die hier konfiguriert wird (@see ChartInfo-Indikator).
         ChartInfo.appliedPrice = PRICE_BID;                         // im Tester immer PRICE_BID (bessere Performance)
         ChartInfo.leverage     = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
         if (LT(ChartInfo.leverage, 1)) return(catch("onInit(3)  invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(ChartInfo.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));
         ChartInfo.CreateLabels();
      }
   }

   return(last_error);
}


/**
 * Führt allgemein benötigte Aufräumarbeiten durch.
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   int error;

   if (IsExpert()) {
      if (IsTesting()) {                                             // Der Tester schließt beim Beenden nur offene Positionen,
         if (!DeletePendingOrders(CLR_NONE))                         // offene Pending-Orders werden jedoch nicht gelöscht.
            error = stdlib_PeekLastError();
      }
   }

   if (IsError(error)) /*&&*/ if (!IsLastError())
      last_error = error;
   return(error);
}


/**
 * Originale Main-Funktion. Führt diverse Laufzeit-Checks durch, setzt entsprechende Variablen und ruft danach und *nur* bei Erfolg
 * die neu eingeführten Main-Funktionen des jeweiligen Programmtyps auf (bei Indikatoren und EA's onTick(), bei Scripten onStart()).
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++; Ticks = Tick;
   prev_error = last_error;
   ValidBars  = IndicatorCounted();


   // (1) letzten Fehler behandeln
   if (last_error == NO_ERROR) {
      init = false;                                                  // init() war immer erfolgreich
   }
   else if (init) {                                                  // init()-error abfangen
      if (last_error == ERR_TERMINAL_NOT_YET_READY) {
         if (!IsScript())
            init();                                                  // in Indikatoren und EA's wird init() erneut aufgerufen
      }
      if (IsError(last_error))
         return(last_error);                                         // regular exit for init()-error
      init = false;
      ValidBars = 0;                                                 // init() war nach erneutem Aufruf erfolgreich
   }
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) {              // start()-error des letzten start()-Aufrufs
      ValidBars = 0;
   }
   last_error = NO_ERROR;


   // (2) Abschluß der Chart-Initialisierung überprüfen
   if (Bars == 0)
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));              // kann bei Terminal-Start auftreten


   /*
   // (2.1) Werden in Indikatoren Zeichenpuffer verwendet (indicator_buffers > 0), muß deren Initialisierung
   //       überprüft werden (kann nicht hier, sondern erst in onTick() erfolgen).
   if (ArraySize(iBuffer) == 0)
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));              // kann bei Terminal-Start auftreten
   */

   // (3) ChangedBars berechnen
   ChangedBars = Bars - ValidBars;


   // (4) stdLib benachrichtigen
   stdlib_onStart(Ticks, ValidBars, ChangedBars);


   // (5) Im Tester übernimmt der jeweilige EA die Anzeige der Chartinformationen (@see ChartInfo-Indikator)
   if (IsVisualMode()) {
      ChartInfo.positionChecked = false;
      ChartInfo.UpdatePrice();
      ChartInfo.UpdateSpread();
      ChartInfo.UpdateUnitSize();
      ChartInfo.UpdatePosition();
      ChartInfo.UpdateTime();
      ChartInfo.UpdateMarginLevels();
   }


   // (6) neue Main-Funktion aufrufen
   if (IsScript()) last_error = onStart();
   else            last_error = onTick();

   return(last_error);
   DummyCalls();                                                     // unterdrücken Compilerwarnungen über unreferenzierte Funktionen
}


/**
 * Erzeugt die einzelnen ChartInfo-Label.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.CreateLabels() {
   // Label definieren
   ChartInfo.instrument   = "ChartInfo.Instrument";
   ChartInfo.price        = "ChartInfo.Price";
   ChartInfo.spread       = "ChartInfo.Spread";
   ChartInfo.unitSize     = "ChartInfo.UnitSize";
   ChartInfo.position     = "ChartInfo.Position";
   ChartInfo.time         = "ChartInfo.Time";
   ChartInfo.freezeLevel  = "ChartInfo.MarginFreezeLevel";
   ChartInfo.stopoutLevel = "ChartInfo.MarginStopoutLevel";


   // Instrument-Label erzeugen
   if (ObjectFind(ChartInfo.instrument) >= 0)
      ObjectDelete(ChartInfo.instrument);
   if (ObjectCreate(ChartInfo.instrument, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(ChartInfo.instrument, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet(ChartInfo.instrument, OBJPROP_XDISTANCE, 4);
      ObjectSet(ChartInfo.instrument, OBJPROP_YDISTANCE, 1);
      ArrayPushString(objects, ChartInfo.instrument);
   }
   else GetLastError();

   // Die Instrumentanzeige wird sofort und *nur hier* gesetzt.
   string name = GetLongSymbolNameOrAlt(Symbol(), GetSymbolName(Symbol()));
   if      (StringIEndsWith(Symbol(), "_ask")) name = StringConcatenate(name, " (Ask)");
   else if (StringIEndsWith(Symbol(), "_avg")) name = StringConcatenate(name, " (Avg)");
   ObjectSetText(ChartInfo.instrument, name, 9, "Tahoma Fett", Black);


   // Kurs-Label erzeugen
   if (ObjectFind(ChartInfo.price) >= 0)
      ObjectDelete(ChartInfo.price);
   if (ObjectCreate(ChartInfo.price, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(ChartInfo.price, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(ChartInfo.price, OBJPROP_XDISTANCE, 14);
      ObjectSet(ChartInfo.price, OBJPROP_YDISTANCE, 15);
      ObjectSetText(ChartInfo.price, " ", 1);
      ArrayPushString(objects, ChartInfo.price);
   }
   else GetLastError();


   // Spread-Label erzeugen
   if (ObjectFind(ChartInfo.spread) >= 0)
      ObjectDelete(ChartInfo.spread);
   if (ObjectCreate(ChartInfo.spread, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(ChartInfo.spread, OBJPROP_CORNER, CORNER_TOP_RIGHT);
      ObjectSet(ChartInfo.spread, OBJPROP_XDISTANCE, 33);
      ObjectSet(ChartInfo.spread, OBJPROP_YDISTANCE, 38);
      ObjectSetText(ChartInfo.spread, " ", 1);
      ArrayPushString(objects, ChartInfo.spread);
   }
   else GetLastError();


   // UnitSize-Label erzeugen
   if (ObjectFind(ChartInfo.unitSize) >= 0)
      ObjectDelete(ChartInfo.unitSize);
   if (ObjectCreate(ChartInfo.unitSize, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(ChartInfo.unitSize, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(ChartInfo.unitSize, OBJPROP_XDISTANCE, 290);
      ObjectSet(ChartInfo.unitSize, OBJPROP_YDISTANCE, 9);
      ObjectSetText(ChartInfo.unitSize, " ", 1);
      ArrayPushString(objects, ChartInfo.unitSize);
   }
   else GetLastError();


   // Position-Label erzeugen
   if (ObjectFind(ChartInfo.position) >= 0)
      ObjectDelete(ChartInfo.position);
   if (ObjectCreate(ChartInfo.position, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(ChartInfo.position, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(ChartInfo.position, OBJPROP_XDISTANCE, 530);
      ObjectSet(ChartInfo.position, OBJPROP_YDISTANCE, 9);
      ObjectSetText(ChartInfo.position, " ", 1);
      ArrayPushString(objects, ChartInfo.position);
   }
   else GetLastError();


   // Time-Label erzeugen (nur im Tester)
   if (IsVisualMode()) {
      if (ObjectFind(ChartInfo.time) >= 0)
         ObjectDelete(ChartInfo.time);
      if (ObjectCreate(ChartInfo.time, OBJ_LABEL, 0, 0, 0)) {
         ObjectSet(ChartInfo.time, OBJPROP_CORNER, CORNER_BOTTOM_RIGHT);
         ObjectSet(ChartInfo.time, OBJPROP_XDISTANCE, 14);
         ObjectSet(ChartInfo.time, OBJPROP_YDISTANCE, 14);
         ObjectSetText(ChartInfo.time, " ", 1);
         ArrayPushString(objects, ChartInfo.time);
      }
      else GetLastError();
   }

   return(catch("ChartInfo.CreateLabels()"));
}


/**
 * Aktualisiert die Kursanzeige.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.UpdatePrice() {
   static string priceFormat;
   if (StringLen(priceFormat) == 0)
      priceFormat = StringConcatenate(",,", PriceFormat);

   double price;
   switch (ChartInfo.appliedPrice) {
      case PRICE_BID:    price =  Bid;          break;
      case PRICE_ASK:    price =  Ask;          break;
      case PRICE_MEDIAN: price = (Bid + Ask)/2; break;
   }

   ObjectSetText(ChartInfo.price, NumberToStr(price, priceFormat), 13, "Microsoft Sans Serif", Black);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("ChartInfo.UpdatePrice()", error));
   return(NO_ERROR);
}


/**
 * Aktualisiert die Spreadanzeige.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.UpdateSpread() {
   string strSpread = DoubleToStr(MarketInfo(Symbol(), MODE_SPREAD)/PipPoints, Digits-PipDigits);

   ObjectSetText(ChartInfo.spread, strSpread, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("ChartInfo.UpdateSpread()", error));
   return(NO_ERROR);
}


/**
 * Aktualisiert die UnitSize-Anzeige.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.UpdateUnitSize() {
   bool   tradeAllowed = IsTesting() || NE(MarketInfo(Symbol(), MODE_TRADEALLOWED), 0);   // MODE_TRADEALLOWED ist im Tester idiotischerweise false
   double tickValue    =    MarketInfo(Symbol(), MODE_TICKVALUE);
   string strUnitSize  = " ";

   if (tradeAllowed) /*&&*/ if (tickValue > 0.00000001) {            // bei Start oder Accountwechsel
      double equity = AccountEquity()-AccountCredit();

      if (equity > 0.00000001) {                                     // Accountequity wird mit 'leverage' gehebelt
         double lotValue = Bid / TickSize * tickValue;               // Lotvalue in Account-Currency
         double unitSize = equity / lotValue * ChartInfo.leverage;   // unitSize = equity/lotValue entspricht Hebel von 1

         if      (unitSize <    0.02000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.001) *   0.001, 3);   // 0.007-0.02: Vielfaches von   0.001
         else if (unitSize <    0.04000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.002) *   0.002, 3);   //  0.02-0.04: Vielfaches von   0.002
         else if (unitSize <    0.07000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.005) *   0.005, 3);   //  0.04-0.07: Vielfaches von   0.005
         else if (unitSize <    0.20000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.01 ) *   0.01 , 2);   //   0.07-0.2: Vielfaches von   0.01
         else if (unitSize <    0.40000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.02 ) *   0.02 , 2);   //    0.2-0.4: Vielfaches von   0.02
         else if (unitSize <    0.70000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.05 ) *   0.05 , 2);   //    0.4-0.7: Vielfaches von   0.05
         else if (unitSize <    2.00000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.1  ) *   0.1  , 1);   //      0.7-2: Vielfaches von   0.1
         else if (unitSize <    4.00000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.2  ) *   0.2  , 1);   //        2-4: Vielfaches von   0.2
         else if (unitSize <    7.00000001) unitSize = NormalizeDouble(MathRound(unitSize/  0.5  ) *   0.5  , 1);   //        4-7: Vielfaches von   0.5
         else if (unitSize <   20.00000001) unitSize = MathRound      (MathRound(unitSize/  1    ) *   1);          //       7-20: Vielfaches von   1
         else if (unitSize <   40.00000001) unitSize = MathRound      (MathRound(unitSize/  2    ) *   2);          //      20-40: Vielfaches von   2
         else if (unitSize <   70.00000001) unitSize = MathRound      (MathRound(unitSize/  5    ) *   5);          //      40-70: Vielfaches von   5
         else if (unitSize <  200.00000001) unitSize = MathRound      (MathRound(unitSize/ 10    ) *  10);          //     70-200: Vielfaches von  10
         else if (unitSize <  400.00000001) unitSize = MathRound      (MathRound(unitSize/ 20    ) *  20);          //    200-400: Vielfaches von  20
         else if (unitSize <  700.00000001) unitSize = MathRound      (MathRound(unitSize/ 50    ) *  50);          //    400-700: Vielfaches von  50
         else if (unitSize < 2000.00000001) unitSize = MathRound      (MathRound(unitSize/100    ) * 100);          //   700-2000: Vielfaches von 100

         strUnitSize = StringConcatenate("UnitSize:  ", NumberToStr(unitSize, ", .+"), " lot");
      }
   }
   ObjectSetText(ChartInfo.unitSize, strUnitSize, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("ChartInfo.UpdateUnitSize()", error));
   return(NO_ERROR);
}


/**
 * Ermittelt und speichert die momentane Marktpositionierung für das aktuelle Instrument.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.CheckPosition() {
   if (ChartInfo.positionChecked)
      return(NO_ERROR);

   ChartInfo.longPosition  = 0;
   ChartInfo.shortPosition = 0;
   ChartInfo.totalPosition = 0;

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde woanders eine aktive Order entfernt
         break;

      if (OrderSymbol() == Symbol()) {
         if      (OrderType() == OP_BUY ) ChartInfo.longPosition  += OrderLots();
         else if (OrderType() == OP_SELL) ChartInfo.shortPosition += OrderLots();
      }
   }
   ChartInfo.totalPosition   = ChartInfo.longPosition - ChartInfo.shortPosition;
   ChartInfo.flatPosition    = EQ(ChartInfo.totalPosition, 0);
   ChartInfo.noPosition      = EQ(ChartInfo.longPosition, 0) && EQ(ChartInfo.shortPosition, 0);
   ChartInfo.positionChecked = true;

   return(catch("ChartInfo.CheckPosition()"));
}


/**
 * Aktualisiert die Positionsanzeige.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.UpdatePosition() {
   if (!ChartInfo.positionChecked)
      ChartInfo.CheckPosition();

   string strPosition;

   if      (ChartInfo.noPosition)   strPosition = " ";
   else if (ChartInfo.flatPosition) strPosition = StringConcatenate("Position:  ±", NumberToStr(ChartInfo.longPosition, ", .+"), " lot (hedged)");
   else                             strPosition = StringConcatenate("Position:  " , NumberToStr(ChartInfo.totalPosition, "+, .+"), " lot");

   ObjectSetText(ChartInfo.position, strPosition, 9, "Tahoma", SlateGray);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("ChartInfo.UpdatePosition()", error));
   return(NO_ERROR);
}


/**
 * Aktualisiert die Zeitanzeige.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.UpdateTime() {
   static datetime lastTime;

   datetime now = TimeCurrent();
   if (now == lastTime)
      return(NO_ERROR);

   string date = TimeToStr(now, TIME_DATE),
          yyyy = StringSubstr(date, 0, 4),
          mm   = StringSubstr(date, 5, 2),
          dd   = StringSubstr(date, 8, 2),
          time = TimeToStr(now, TIME_MINUTES|TIME_SECONDS);

   ObjectSetText(ChartInfo.time, StringConcatenate(dd, ".", mm, ".", yyyy, " ", time), 9, "Tahoma", SlateGray);

   lastTime = now;

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("ChartInfo.UpdateTime()", error));
   return(NO_ERROR);
}


/**
 * Aktualisiert die Anzeige der aktuellen Freeze- und Stopoutlevel.
 *
 * @return int - Fehlerstatus
 */
int ChartInfo.UpdateMarginLevels() {
   if (!ChartInfo.positionChecked)
      ChartInfo.CheckPosition();

   if (ChartInfo.flatPosition) {                                              // keine Position im Markt: ggf. vorhandene Marker löschen
      ObjectDelete(ChartInfo.freezeLevel);
      ObjectDelete(ChartInfo.stopoutLevel);
   }
   else {
      // Kurslevel für Margin-Freeze/-Stopout berechnen und anzeigen
      double equity         = AccountEquity();
      double usedMargin     = AccountMargin();
      int    stopoutMode    = AccountStopoutMode();
      int    stopoutLevel   = AccountStopoutLevel();
      double marginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
      double tickValue      = MarketInfo(Symbol(), MODE_TICKVALUE);
      double marginLeverage = Bid / TickSize * tickValue / marginRequired;    // Hebel der real zur Verfügung gestellten Kreditlinie für das Symbol
             tickValue      = tickValue * MathAbs(ChartInfo.totalPosition);   // TickValue der gesamten Position

      int error = GetLastError();
      if (tickValue < 0.00000001)                                             // bei Start oder Accountwechsel
         return(SetLastError(ERR_UNKNOWN_SYMBOL));

      bool showFreezeLevel = true;

      if (stopoutMode == ASM_ABSOLUTE) { double equityStopoutLevel = stopoutLevel;                        }
      else if (stopoutLevel == 100)    {        equityStopoutLevel = usedMargin; showFreezeLevel = false; } // Freeze- und StopoutLevel sind identisch, nur StopOut anzeigen
      else                             {        equityStopoutLevel = stopoutLevel / 100.0 * usedMargin;   }

      double quoteFreezeDiff  = (equity - usedMargin        ) / tickValue * TickSize;
      double quoteStopoutDiff = (equity - equityStopoutLevel) / tickValue * TickSize;

      double quoteFreezeLevel, quoteStopoutLevel;

      if (ChartInfo.totalPosition > 0.00000001) {                             // long position
         quoteFreezeLevel  = NormalizeDouble(Bid - quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Bid - quoteStopoutDiff, Digits);
      }
      else {                                                                  // short position
         quoteFreezeLevel  = NormalizeDouble(Ask + quoteFreezeDiff, Digits);
         quoteStopoutLevel = NormalizeDouble(Ask + quoteStopoutDiff, Digits);
      }
      /*
      debug("ChartInfo.UpdateMarginLevels()   equity="+ NumberToStr(equity, ", .2")
                                         +"   equity(100%)="+ NumberToStr(usedMargin, ", .2") +" ("+ NumberToStr(equity-usedMargin, "+, .2") +" => "+ NumberToStr(quoteFreezeLevel, PriceFormat) +")"
                                         +"   equity(so:"+ ifString(stopoutMode==ASM_ABSOLUTE, "abs", stopoutLevel+"%") +")="+ NumberToStr(equityStopoutLevel, ", .2") +" ("+ NumberToStr(equity-equityStopoutLevel, "+, .2") +" => "+ NumberToStr(quoteStopoutLevel, PriceFormat) +")"
      );
      */

      // FreezeLevel anzeigen
      if (showFreezeLevel) {
         if (ObjectFind(ChartInfo.freezeLevel) == -1) {
            ObjectCreate(ChartInfo.freezeLevel, OBJ_HLINE, 0, 0, 0);
            ObjectSet(ChartInfo.freezeLevel, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet(ChartInfo.freezeLevel, OBJPROP_COLOR, C'0,201,206');
            ObjectSet(ChartInfo.freezeLevel, OBJPROP_BACK , true);
            ObjectSetText(ChartInfo.freezeLevel, StringConcatenate("Freeze   1:", DoubleToStr(marginLeverage, 0)));
            ArrayPushString(objects, ChartInfo.freezeLevel);
         }
         ObjectSet(ChartInfo.freezeLevel, OBJPROP_PRICE1, quoteFreezeLevel);
      }

      // StopoutLevel anzeigen
      if (ObjectFind(ChartInfo.stopoutLevel) == -1) {
         ObjectCreate(ChartInfo.stopoutLevel, OBJ_HLINE, 0, 0, 0);
         ObjectSet(ChartInfo.stopoutLevel, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSet(ChartInfo.stopoutLevel, OBJPROP_COLOR, OrangeRed);
         ObjectSet(ChartInfo.stopoutLevel, OBJPROP_BACK , true);
            if (stopoutMode == ASM_PERCENT) string description = StringConcatenate("Stopout  1:", DoubleToStr(marginLeverage, 0));
            else                                   description = StringConcatenate("Stopout  ", NumberToStr(stopoutLevel, ", ."), AccountCurrency());
         ObjectSetText(ChartInfo.stopoutLevel, description);
         ArrayPushString(objects, ChartInfo.stopoutLevel);
      }
      ObjectSet(ChartInfo.stopoutLevel, OBJPROP_PRICE1, quoteStopoutLevel);
   }

   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)  // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("ChartInfo.UpdateMarginLevels()", error));
   return(NO_ERROR);
}


/**
 * Prüft, ob ein Fehler aufgetreten ist und zeigt diesen optisch und akustisch an. Der Fehler wird in der globalen Variable last_error gespeichert,
 * wenn diese noch keinen Fehler enthält.  Bereits vorher aufgetretene Fehler werden also nicht überschrieben. Der mit der MQL-Funktion GetLastError()
 * auslesbare letzte MQL-Fehler ist nach Aufruf dieser Funktion zurückgesetzt.
 *
 * @param  string location - Ortsbezeichner des Fehlers, kann zusätzlich eine anzuzeigende Nachricht enthalten
 * @param  int    error    - manuelles Forcieren eines bestimmten Error-Codes
 * @param  bool   orderPop - ob ein zuvor gespeicherter Orderkontext wiederhergestellt werden soll (default: nein)
 *
 * @return int - der aufgetretene Error-Code
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, um Default-Parameter zu unterstützen und damit das laufende Script als Auslöser angezeigt wird.
 */
int catch(string location, int error=NO_ERROR, bool orderPop=false) {
   if (error == NO_ERROR)   error = GetLastError();
   else                             GetLastError();                  // externer Fehler angegeben, letzten tatsächlichen Fehler zurücksetzen

   if (error != NO_ERROR) {
      string message = ifString(StringLen(location) > 0, location, "???");

      Alert("ERROR:   "+ Symbol() +","+ PeriodDescription(NULL) +"  "+ __SCRIPT__ +"::"+ message +"  ["+ error +" - "+ ErrorDescription(error) +"]");

      if (IsTesting()) {                                             // Im Tester werden Alerts() in Experts ignoriert, deshalb Fehler dort manuell signalisieren.
         string caption = "Strategy Tester "+ Symbol() +","+ PeriodDescription(NULL);
         string strings[];
         if (Explode(message, ")", strings, 2)==1) message = "ERROR in "+ __SCRIPT__ + NL + NL + StringTrimLeft(message +"  ["+ error +" - "+ ErrorDescription(error) +"]");
         else                                      message = "ERROR in "+ __SCRIPT__ +"::"+ StringTrim(strings[0]) +")"+ NL + NL + StringTrimLeft(strings[1] +"  ["+ error +" - "+ ErrorDescription(error) +"]");

         // TODO: Das Splitten muß nach dem letzten Funktionsnamen erfolgen (mehrere Klammerpaare sind möglich, nicht nur eines).

         ForceSound("alert.wav");
         ForceMessageBox(message, caption, MB_ICONERROR|MB_OK);
      }

      if (last_error == NO_ERROR)                                    // bereits existierenden Fehler nicht überschreiben
         last_error = error;
   }

   if (orderPop) {
      if (!OrderPop(location))
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
   }
   return(error);
}


/**
 * Logged eine Message und einen ggf. angegebenen Fehler.
 *
 * @param  string message - Message
 * @param  int    error   - Error-Code
 *
 * @return int - der angegebene Error-Code
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, damit das laufende Script als Auslöser angezeigt wird.
 */
int log(string message="", int error=NO_ERROR) {
   if (StringLen(message) == 0)
      message = "???";

   message = StringConcatenate(__SCRIPT__, "::", message);

   if (error != NO_ERROR)
      message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");

   Print(message);
   return(error);
}


#import "kernel32.dll"
   void OutputDebugStringA(string lpMessage);
#import


/**
 * Send information to OutputDebugString() to be viewed and logged by SysInternals DebugView.
 *
 * @param  string message - Message
 * @param  int    error   - Error-Code
 *
 * @return void - immer 0; als int deklariert, um Verwendung als Funktionsargument zu ermöglichen
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, damit das laufende Script als Auslöser angezeigt wird.
 */
int debug(string message, int error=NO_ERROR) {
   static int debugToLog = -1;

   if (debugToLog == -1)
      debugToLog = GetLocalConfigBool("Logging", "DebugToLog", false);

   if (debugToLog == 1) {
      log(message, error);
   }
   else {
      if (error != NO_ERROR)
         message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");
      OutputDebugStringA(StringConcatenate("MetaTrader::", Symbol(), ",", PeriodDescription(NULL), "::", __SCRIPT__, "::", message));
   }
}


/**
 * Ob der interne Fehler-Code des aktuellen Scripts gesetzt ist.
 *
 * @return bool
 */
bool IsLastError() {
   return(last_error != NO_ERROR);
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
 * Setzt den internen Fehlercode des aktuellen Scripts.
 *
 * @param  int error - Fehlercode
 *
 * @return int - derselbe Fehlercode (for chaining)
 */
int SetLastError(int error) {
   last_error = error;
   return(error);
}


/**
 * Zeigt eine MessageBox an, wenn Alert() im aktuellen Kontext des Terminals unterdrückt wird (z.B. im Tester).
 *
 * @param string s1-s63 - bis zu 63 beliebige Parameter
 *
 * @return void - immer 0; als int deklariert, um Verwendung als Funktionsargument zu ermöglichen
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, um Default-Parameter zu ermöglichen.
 */
int ForceAlert(string s1="", string s2="", string s3="", string s4="", string s5="", string s6="", string s7="", string s8="", string s9="", string s10="", string s11="", string s12="", string s13="", string s14="", string s15="", string s16="", string s17="", string s18="", string s19="", string s20="", string s21="", string s22="", string s23="", string s24="", string s25="", string s26="", string s27="", string s28="", string s29="", string s30="", string s31="", string s32="", string s33="", string s34="", string s35="", string s36="", string s37="", string s38="", string s39="", string s40="", string s41="", string s42="", string s43="", string s44="", string s45="", string s46="", string s47="", string s48="", string s49="", string s50="", string s51="", string s52="", string s53="", string s54="", string s55="", string s56="", string s57="", string s58="", string s59="", string s60="", string s61="", string s62="", string s63="") {
   string message = StringConcatenate(s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, s23, s24, s25, s26, s27, s28, s29, s30, s31, s32, s33, s34, s35, s36, s37, s38, s39, s40, s41, s42, s43, s44, s45, s46, s47, s48, s49, s50, s51, s52, s53, s54, s55, s56, s57, s58, s59, s60, s61, s62, s63);
   Alert(message);

   if (IsTesting()) {
      ForceSound("alert.wav");
      ForceMessageBox(message, __SCRIPT__, MB_ICONINFORMATION|MB_OK);
   }
}


/**
 * Prüft, ob Events der angegebenen Typen aufgetreten sind und ruft bei Zutreffen deren Eventhandler auf.
 *
 * @param  int events - ein oder mehrere durch logisches ODER verknüpfte Eventbezeichner
 *
 * @return bool - ob mindestens eines der angegebenen Events aufgetreten ist
 *
 *  NOTE:
 *  -----
 *  (1) Ist in der Headerdatei implementiert, damit lokale Implementierungen der Eventhandler zuerst gefunden werden.
 *  (2) Um zusätzliche event-spezifische Parameter für die Prüfung anzugeben, muß HandleEvent() für jedes Event einzeln aufgerufen werden.
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
   if (events & EVENT_HISTORY_CHANGE  != 0) status |= HandleEvent(EVENT_HISTORY_CHANGE );

   return(status!=0 && catch("HandleEvents()")==NO_ERROR);
}


/**
 * Prüft, ob ein Event aufgetreten ist und ruft bei Zutreffen dessen Eventhandler auf.
 * Im Gegensatz zu HandleEvents() ermöglicht die Verwendung dieser Funktion die Angabe weiterer eventspezifischer Prüfungsflags.
 *
 * @param  int event - Eventbezeichner
 * @param  int flags - zusätzliche eventspezifische Flags (default: 0)
 *
 * @return bool - ob das Event aufgetreten ist oder nicht
 *
 * NOTE:  Ist in der Headerdatei implementiert, damit die lokalen Eventhandler gefunden werden.
 * -----
 */
int HandleEvent(int event, int flags=0) {
   bool status;
   int  results[];                        // zurücksetzen hier nicht nötig, da die EventListener den Array-Parameter immer zurücksetzen

   switch (event) {
      case EVENT_BAR_OPEN       : if (EventListener.BarOpen       (results, flags)) { status = true; onBarOpen       (results); } break;
      case EVENT_ORDER_PLACE    : if (EventListener.OrderPlace    (results, flags)) { status = true; onOrderPlace    (results); } break;
      case EVENT_ORDER_CHANGE   : if (EventListener.OrderChange   (results, flags)) { status = true; onOrderChange   (results); } break;
      case EVENT_ORDER_CANCEL   : if (EventListener.OrderCancel   (results, flags)) { status = true; onOrderCancel   (results); } break;
      case EVENT_POSITION_OPEN  : if (EventListener.PositionOpen  (results, flags)) { status = true; onPositionOpen  (results); } break;
      case EVENT_POSITION_CLOSE : if (EventListener.PositionClose (results, flags)) { status = true; onPositionClose (results); } break;
      case EVENT_ACCOUNT_CHANGE : if (EventListener.AccountChange (results, flags)) { status = true; onAccountChange (results); } break;
      case EVENT_ACCOUNT_PAYMENT: if (EventListener.AccountPayment(results, flags)) { status = true; onAccountPayment(results); } break;
      case EVENT_HISTORY_CHANGE : if (EventListener.HistoryChange (results, flags)) { status = true; onHistoryChange (results); } break;

      default:
         catch("HandleEvent(1)   unknown event = "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   }

   return(status && catch("HandleEvent(2)")==NO_ERROR);
}


int stack.selectedOrders[];                                          // @see OrderPush(), OrderPop()


/**
 * Selektiert eine Order anhand des Tickets.
 *
 * @param  int    ticket          - Ticket
 * @param  string location        - Bezeichner für eine evt. Fehlermeldung
 * @param  bool   orderPush       - Ob der aktuelle Orderkontext vorm Neuselektieren gespeichert werden soll (default: nein).
 * @param  bool   onErrorOrderPop - Ob *im Fehlerfall* der letzte Orderkontext wiederhergestellt werden soll (default: nein).
 *                                  Ist orderPush TRUE, wird dieser Parameter, wenn nicht anders angegeben, automatisch auf TRUE gesetzt.
 * @return bool - Erfolgsstatus
 *
 *  NOTE:
 *  -----
 * Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Programm benutzt werden können.
 */
bool OrderSelectByTicket(int ticket, string location, bool orderPush=false, bool onErrorOrderPop=false) {
   if (orderPush) {
      OrderPush(location);
      onErrorOrderPop = true;
   }

   if (OrderSelect(ticket, SELECT_BY_TICKET))
      return(true);

   if (onErrorOrderPop)                                              // im Fehlerfall alten Kontext restaurieren und Order-Stack bereinigen
      OrderPop(location);

   int error = GetLastError();
   return(_false(catch(location +"->OrderSelectByTicket()   ticket = "+ ticket, ifInt(IsError(error), error, ERR_INVALID_TICKET))));
}


/**
 * Schiebt den aktuellen Orderkontext auf den Order-Stack (fügt ihn ans Ende an).
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return int - Ticket des aktuellen Kontexts oder 0, wenn keine Order selektiert ist oder ein Fehler auftrat
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Programm benutzt werden können.
 */
int OrderPush(string location) {
   int error = GetLastError();
   if (IsError(error))
      return(_ZERO(catch(location +"->OrderPush(1)", error)));

   int ticket = OrderTicket();

   error = GetLastError();
   if (IsError(error)) /*&&*/ if (error != ERR_NO_ORDER_SELECTED)
      return(_ZERO(catch(location +"->OrderPush(2)", error)));

   ArrayPushInt(stack.selectedOrders, ticket);
   return(ticket);
}


/**
 * Entfernt den letzten auf dem Order-Stack befindlichen Kontext und restauriert ihn.
 *
 * @param  string location - Bezeichner für eine evt. Fehlermeldung
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, da OrderSelect() und die Orderfunktionen nur im jeweils selben Programm benutzt werden können.
 */
bool OrderPop(string location) {
   int ticket = ArrayPopInt(stack.selectedOrders);

   if (ticket > 0)
      return(OrderSelectByTicket(ticket, StringConcatenate(location, "->OrderPop()")));

   if (ticket==0) /*&&*/ if (IsLastError())
      return(false);

   OrderSelect(0, SELECT_BY_TICKET);
   return(true);
}


/**
 * Wartet darauf, daß das angegebene Ticket im OpenOrders- bzw. History-Pool des Accounts erscheint.
 *
 * @param  int  ticket            - Orderticket
 * @param  bool keepCurrentTicket - ob der aktuelle Orderkontext bewahrt werden soll (default: ja)
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, um Default-Parameter zu ermöglichen.
 */
bool WaitForTicket(int ticket, bool keepCurrentTicket=true) {
   if (ticket <= 0)
      return(_false(catch("WaitForTicket(1)   illegal parameter ticket = "+ ticket, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (keepCurrentTicket) {
      if (OrderPush("WaitForTicket(2)") == 0)
         return(!IsLastError());
   }

   int i, delay=100;                                                 // je 0.1 Sekunden warten

   while (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      if (IsTesting())           ForceAlert("WaitForTicket()   ticket #", ticket, " not yet accessible");
      else if (i > 0 && i%10==0)      Alert("WaitForTicket()   ticket #", ticket, " not yet accessible after ", DoubleToStr(i*delay/1000.0, 1), " s");
      Sleep(delay);
      i++;
   }

   if (keepCurrentTicket) {
      if (!OrderPop("WaitForTicket(3)"))
         return(false);
   }

   return(true);
}


/**
 * Gibt den PipValue des aktuellen Instrument für die angegebene Lotsize zurück.
 *
 * @param  double lots - Lotsize (default: 1)
 *
 * @return double - PipValue oder 0, wenn ein Fehler auftrat
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, um Default-Parameter zu ermöglichen.
 */
double PipValue(double lots = 1.0) {
   if (lots     < 0.00000001)  return(_ZERO(catch("PipValue(1)   illegal parameter lots = "+ NumberToStr(lots, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (TickSize < 0.00000001)  return(_ZERO(catch("PipValue(2)   illegal TickSize = "+ NumberToStr(TickSize, ".+"), ERR_RUNTIME_ERROR)));

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);          // TODO: wenn QuoteCurrency == AccountCurrency, ist dies nur ein einziges Mal notwendig

   int error = GetLastError();

   if (IsError(error))         return(_ZERO(catch("PipValue(3)", error)));
   if (tickValue < 0.00000001) return(_ZERO(catch("PipValue(4)   illegal TickValue = "+ NumberToStr(tickValue, ".+"), ERR_INVALID_MARKETINFO)));

   return(Pip/TickSize * tickValue * lots);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   return(__TYPE__ == T_INDICATOR);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   return(__TYPE__ == T_EXPERT);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   return(__TYPE__ == T_SCRIPT);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als boolean TRUE zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  ... - beliebige Parameter (werden ignoriert)
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
 * @param  ... - beliebige Parameter (werden ignoriert)
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
 * @param  ... - beliebige Parameter (werden ignoriert)
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
 * @param  ... - beliebige Parameter (werden ignoriert)
 *
 * @return int - NO_ERROR
 */
int _NO_ERROR(int param1=NULL, int param2=NULL, int param3=NULL) {
   return(NO_ERROR);
}


/**
 * Pseudo-Funktion, die nichts weiter tut, als (int) 0 zurückzugeben. Kann zur Verbesserung der Übersichtlichkeit
 * und Lesbarkeit verwendet werden.
 *
 * @param  ... - beliebige Parameter (werden ignoriert)
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
 * @param  ... - beliebige Parameter (werden ignoriert)
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
 * Dummy-Calls, unterdrücken Compilerwarnungen über unreferenzierte Funktionen
 */
void DummyCalls() {
   _bool(NULL);
   _double(NULL);
   _empty();
   _false();
   _int(NULL);
   _NO_ERROR();
   _NULL();
   _string(NULL);
   _true();
   _ZERO();
   catch(NULL);
   ChartInfo.CreateLabels();
   ChartInfo.UpdateMarginLevels();
   ChartInfo.UpdatePosition();
   ChartInfo.UpdatePrice();
   ChartInfo.UpdateSpread();
   ChartInfo.UpdateTime();
   ChartInfo.UpdateUnitSize();
   debug(NULL);
   ForceAlert();
   HandleEvent(NULL);
   HandleEvents(NULL);
   IsError(NULL);
   IsExpert();
   IsIndicator();
   IsLastError();
   IsNoError(NULL);
   IsScript();
   log();
   onInit(NULL);
   OrderPop(NULL);
   OrderPush(NULL);
   OrderSelectByTicket(NULL, NULL);
   PipValue();
   SetLastError(NULL);
   start();
   WaitForTicket(NULL);
}

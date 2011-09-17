/**
 * Globale MQL-Funktionen, Variablen und Konstanten.
 */

// Special constants
#define NULL                     0     //
#define EMPTY                   -1     //
#define EMPTY_VALUE     0x7FFFFFFF     // empty custom indicator value (= 2147483647)
#define CLR_NONE                -1     // no color
#define WHOLE_ARRAY              0     //


// String maximaler Länge
#define MAX_STRING_LITERAL     "..............................................................................................................................................................................................................................................................."
#define MAX_STRING_LITERAL_LEN 255
#define NL                     "\n"    // new line, entspricht CR+LF in MQL


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


// MessageBox() flags
#define MB_OK                                      0x0000
#define MB_OKCANCEL                                0x0001
#define MB_ABORTRETRYIGNORE                        0x0002
#define MB_YESNOCANCEL                             0x0003
#define MB_YESNO                                   0x0004
#define MB_RETRYCANCEL                             0x0005
#define MB_CANCELTRYCONTINUE                       0x0006
#define MB_ICONHAND                                0x0010
#define MB_ICONQUESTION                            0x0020
#define MB_ICONEXCLAMATION                         0x0030
#define MB_ICONASTERISK                            0x0040
#define MB_USERICON                                0x0080
#define MB_ICONWARNING                 MB_ICONEXCLAMATION
#define MB_ICONERROR                          MB_ICONHAND
#define MB_ICONINFORMATION                MB_ICONASTERISK
#define MB_ICONSTOP                           MB_ICONHAND
#define MB_DEFBUTTON1                              0x0000
#define MB_DEFBUTTON2                              0x0100
#define MB_DEFBUTTON3                              0x0200
#define MB_DEFBUTTON4                              0x0300


// MessageBox() command IDs (return codes)
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


// MQL-Fehlercodes (Win32-Fehlercodes siehe win32api.mqh)
#define ERR_NO_ERROR                                    0
#define NO_ERROR                             ERR_NO_ERROR

// trade server errors
#define ERR_NO_RESULT                                   1
#define ERR_COMMON_ERROR                                2   // manual confirmation denied | broker rejects order
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
#define ERR_WINDOWS_ERROR                            5000   // win32 api error
#define ERR_FUNCTION_NOT_IMPLEMENTED                 5001   // function not implemented
#define ERR_INVALID_INPUT_PARAMVALUE                 5002   // invalid input parameter value
#define ERR_INVALID_CONFIG_PARAMVALUE                5003   // invalid configuration parameter value
#define ERR_TERMINAL_NOT_YET_READY                   5004   // terminal not yet ready
#define ERR_INVALID_TIMEZONE_CONFIG                  5005   // invalid or missing timezone configuration
#define ERR_INVALID_MARKETINFO                       5006   // invalid MarketInfo() data
#define ERR_FILE_NOT_FOUND                           5007   // file not found


// globale Variablen, stehen überall (auch in Libraries) zur Verfügung
string __SCRIPT__    = "";
bool   init          = false;
int    init_error    = NO_ERROR;
int    last_error    = NO_ERROR;
int    Tick          =  0;
int    UnchangedBars = -1;
int    ChangedBars   = -1;


/**
 * Prüft, ob ein Fehler aufgetreten ist und zeigt diesen optisch und akustisch an. Bei Aufruf in einer init()-Funktion wird der Fehler in der globalen
 * Variable init_error gespeichert, außerhalb von init() in der globalen Variable last_error. Der mit der MQL-Funktion GetLastError() auslesbare interne
 * MQL-Fehler-Code ist nach Aufruf dieser Funktion immer zurückgesetzt.
 *
 * @param  string message - zusätzlich anzuzeigende Nachricht (z.B. Ort des Aufrufs)
 * @param  int    error   - manuelles Forcieren eines bestimmten Error-Codes
 *
 * @return int - der aufgetretene Error-Code
 *
 * NOTE:   Ist in der Headerdatei implementiert, weil (a) Libraries keine Default-Parameter unterstützen und damit
 * -----                                              (b) in der Ausgabe das laufende Script als Auslöser angezeigt werden kann.
 */
int catch(string message="", int error=NO_ERROR) {
   if (StringLen(__SCRIPT__) == 0)
      __SCRIPT__ = WindowExpertName();

   if (error == NO_ERROR) error = GetLastError();
   else                           GetLastError();     // forcierter Error angegeben, den letzten tatsächlichen Fehler zurücksetzen

   if (error != NO_ERROR) {
      if (StringLen(message) == 0)
         message = "???";

      Alert(StringConcatenate("ERROR:   ", Symbol(), ",", PeriodDescription(NULL), "  ", __SCRIPT__, "::", message, "  [", error, " - ", ErrorDescription(error), "]"));

      if (init) init_error = error;
      else      last_error = error;
   }
   return(error);

   // unreachable Code, unterdrückt Compilerwarnungen über unreferenzierte Funktionen
   processError(NULL);
   log(NULL);
   debug(NULL);
   HandleEvent(NULL);
   HandleEvents(NULL);
}


/**
 * Speichert je nachdem, ob der Aufruf in der Funktion init() erfolgt oder nicht, den in einer Libraray aufgetretenen Fehler in den globalen Variablen
 * init_error oder last_error.
 *
 * @param  int error - Fehler-Code
 *
 * @return int - derselbe Fehler-Code
 */
int processError(int error) {
   if (error != NO_ERROR) {
      if (init) init_error = error;
      else      last_error = error;
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
 * NOTE:   Ist in der Headerdatei implementiert, weil (a) Libraries keine Default-Parameter unterstützen und damit
 * -----                                              (b) im Log das laufende Script als Auslöser angezeigt wird.
 */
int log(string message="", int error=NO_ERROR) {
   if (StringLen(__SCRIPT__) == 0)
      __SCRIPT__ = WindowExpertName();

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
 * NOTE:   Ist in der Headerdatei implementiert, weil (a) Libraries keine Default-Parameter unterstützen und damit
 * -----                                              (b) im Log das laufende Script als Auslöser angezeigt wird.
 */
void debug(string message, int error=NO_ERROR) {
   if (StringLen(__SCRIPT__) == 0)
      __SCRIPT__ = WindowExpertName();

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
 *
 * NOTE:   Ist in der Headerdatei implementiert, damit lokale Implementierungen der Eventhandler zuerst gefunden werden.
 * -----
 */
int HandleEvent(int event, int flags=0) {
   bool status = false;
   int  results[];      // zurücksetzen hier nicht nötig, da alle EventListener.*() den Array-Parameter selbst zurücksetzen

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


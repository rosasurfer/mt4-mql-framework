/**
 * Globale Konstanten, Variablen und Funktionen
 */

// Special constants
#define NULL                     0
#define INT_MIN         0x80000000        // kleinster Integer-Value: -2147483648
#define INT_MAX         0x7FFFFFFF        // größter Integer-Value:    2147483647
#define EMPTY                   -1
#define EMPTY_VALUE        INT_MAX        // empty custom indicator value
#define CLR_NONE                -1        // no color
#define WHOLE_ARRAY              0
#define MAX_STRING_LITERAL       "..............................................................................................................................................................................................................................................................."
#define NL                       "\n"     // new line, MQL: 0x0D0A
#define TAB                      "\t"


// Special chars
#define PLACEHOLDER_ZERO_CHAR    '…'      // 0x85 - Platzhalter für NUL-Byte in Strings,          siehe BufferToStr()
#define PLACEHOLDER_CTL_CHAR     '•'      // 0x95 - Platzhalter für Control-Character in Strings, siehe BufferToStr()


// Mathematische Konstanten
#define Math.PI                  3.1415926535897932384626433832795028841971693993751      // intern 3.141592653589793 (15 korrekte Dezimalstellen)

                                                                                          // in Libraries vorerst nichts tun
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


// Time-Flags, siehe TimeToStr()
#define TIME_DATE                1
#define TIME_MINUTES             2
#define TIME_SECONDS             4
#define TIME_FULL                7        // TIME_DATE | TIME_MINUTES | TIME_SECONDS


// Timeframe-Identifier, siehe Period()
#define PERIOD_M1                1        // 1 minute
#define PERIOD_M5                5        // 5 minutes
#define PERIOD_M15              15        // 15 minutes
#define PERIOD_M30              30        // 30 minutes
#define PERIOD_H1               60        // 1 hour
#define PERIOD_H4              240        // 4 hours
#define PERIOD_D1             1440        // daily
#define PERIOD_W1            10080        // weekly
#define PERIOD_MN1           43200        // monthly


// Object property ids, siehe ObjectSet()
#define OBJPROP_TIME1            0
#define OBJPROP_PRICE1           1
#define OBJPROP_TIME2            2
#define OBJPROP_PRICE2           3
#define OBJPROP_TIME3            4
#define OBJPROP_PRICE3           5
#define OBJPROP_COLOR            6
#define OBJPROP_STYLE            7
#define OBJPROP_WIDTH            8
#define OBJPROP_BACK             9
#define OBJPROP_RAY             10
#define OBJPROP_ELLIPSE         11
#define OBJPROP_SCALE           12
#define OBJPROP_ANGLE           13
#define OBJPROP_ARROWCODE       14
#define OBJPROP_TIMEFRAMES      15
#define OBJPROP_DEVIATION       16
#define OBJPROP_FONTSIZE       100
#define OBJPROP_CORNER         101
#define OBJPROP_XDISTANCE      102
#define OBJPROP_YDISTANCE      103
#define OBJPROP_FIBOLEVELS     200
#define OBJPROP_LEVELCOLOR     201
#define OBJPROP_LEVELSTYLE     202
#define OBJPROP_LEVELWIDTH     203
#define OBJPROP_FIRSTLEVEL0    210
#define OBJPROP_FIRSTLEVEL1    211
#define OBJPROP_FIRSTLEVEL2    212
#define OBJPROP_FIRSTLEVEL3    213
#define OBJPROP_FIRSTLEVEL4    214
#define OBJPROP_FIRSTLEVEL5    215
#define OBJPROP_FIRSTLEVEL6    216
#define OBJPROP_FIRSTLEVEL7    217
#define OBJPROP_FIRSTLEVEL8    218
#define OBJPROP_FIRSTLEVEL9    219
#define OBJPROP_FIRSTLEVEL10   220
#define OBJPROP_FIRSTLEVEL11   221
#define OBJPROP_FIRSTLEVEL12   222
#define OBJPROP_FIRSTLEVEL13   223
#define OBJPROP_FIRSTLEVEL14   224
#define OBJPROP_FIRSTLEVEL15   225
#define OBJPROP_FIRSTLEVEL16   226
#define OBJPROP_FIRSTLEVEL17   227
#define OBJPROP_FIRSTLEVEL18   228
#define OBJPROP_FIRSTLEVEL19   229
#define OBJPROP_FIRSTLEVEL20   230
#define OBJPROP_FIRSTLEVEL21   231
#define OBJPROP_FIRSTLEVEL22   232
#define OBJPROP_FIRSTLEVEL23   233
#define OBJPROP_FIRSTLEVEL24   234
#define OBJPROP_FIRSTLEVEL25   235
#define OBJPROP_FIRSTLEVEL26   236
#define OBJPROP_FIRSTLEVEL27   237
#define OBJPROP_FIRSTLEVEL28   238
#define OBJPROP_FIRSTLEVEL29   239
#define OBJPROP_FIRSTLEVEL30   240
#define OBJPROP_FIRSTLEVEL31   241


// Object visibility flags, siehe ObjectSet(label, OBJPROP_TIMEFRAMES, ...)
#define OBJ_PERIOD_M1       0x0001        // object is shown on 1-minute charts
#define OBJ_PERIOD_M5       0x0002        // object is shown on 5-minute charts
#define OBJ_PERIOD_M15      0x0004        // object is shown on 15-minute charts
#define OBJ_PERIOD_M30      0x0008        // object is shown on 30-minute charts
#define OBJ_PERIOD_H1       0x0010        // object is shown on 1-hour charts
#define OBJ_PERIOD_H4       0x0020        // object is shown on 4-hour charts
#define OBJ_PERIOD_D1       0x0040        // object is shown on daily charts
#define OBJ_PERIOD_W1       0x0080        // object is shown on weekly charts
#define OBJ_PERIOD_MN1      0x0100        // object is shown on monthly charts
#define OBJ_ALL_PERIODS     0x01FF        // object is shown on all timeframes


// Timeframe-Flags, siehe EventListener.Baropen()
#define F_PERIOD_M1         OBJ_PERIOD_M1
#define F_PERIOD_M5         OBJ_PERIOD_M5
#define F_PERIOD_M15        OBJ_PERIOD_M15
#define F_PERIOD_M30        OBJ_PERIOD_M30
#define F_PERIOD_H1         OBJ_PERIOD_H1
#define F_PERIOD_H4         OBJ_PERIOD_H4
#define F_PERIOD_D1         OBJ_PERIOD_D1
#define F_PERIOD_W1         OBJ_PERIOD_W1
#define F_PERIOD_MN1        OBJ_PERIOD_MN1


// Operation-Types, siehe OrderType()
#define OP_UNDEFINED            -1        // custom: Default-Wert für nicht initialisierte Variable

#define OP_BUY                   0        // long position
#define OP_LONG             OP_BUY
#define OP_SELL                  1        // short position
#define OP_SHORT           OP_SELL
#define OP_BUYLIMIT              2        // buy limit order
#define OP_SELLLIMIT             3        // sell limit order
#define OP_BUYSTOP               4        // stop buy order
#define OP_SELLSTOP              5        // stop sell order
#define OP_BALANCE               6        // account debit or credit transaction
#define OP_CREDIT                7        // margin credit facility (no transaction)

#define OP_TRANSFER              8        // custom: OP_BALANCE initiiert durch Kunden (Ein-/Auszahlung)
#define OP_VENDOR                9        // custom: OP_BALANCE initiiert durch Criminal (Swap, sonstiges)


// Order-Flags, können logisch kombiniert werden, siehe EventListener.PositionOpen() u. EventListener.PositionClose()
#define OFLAG_CURRENTSYMBOL      1        // order of current symbol (active chart)
#define OFLAG_BUY                2        // long order
#define OFLAG_SELL               4        // short order
#define OFLAG_MARKETORDER        8        // market order
#define OFLAG_PENDINGORDER      16        // pending order (Limit- oder Stop-Order)


// OrderSelect-ID's zur Steuerung des Stacks der Orderkontexte, siehe OrderPush(), OrderPop() etc.
#define O_PUSH                   1
#define O_POP                    2


// Series array identifier, siehe ArrayCopySeries(), iLowest() u. iHighest()
#define MODE_OPEN                0        // open price
#define MODE_LOW                 1        // low price
#define MODE_HIGH                2        // high price
#define MODE_CLOSE               3        // close price
#define MODE_VOLUME              4        // volume
#define MODE_TIME                5        // bar open time


// MA method identifiers, siehe iMA()
#define MODE_SMA                 0        // simple moving average
#define MODE_EMA                 1        // exponential moving average
#define MODE_SMMA                2        // smoothed moving average
#define MODE_LWMA                3        // linear weighted moving average
#define MODE_ALMA                4        // Arnaud Legoux moving average


// Indicator line identifiers used in iMACD(), iRVI() and iStochastic()
#define MODE_MAIN                0        // base indicator line
#define MODE_SIGNAL              1        // signal line


// Indicator line identifiers used in iADX()
#define MODE_MAIN                0        // base indicator line
#define MODE_PLUSDI              1        // +DI indicator line
#define MODE_MINUSDI             2        // -DI indicator line


// Indicator line identifiers used in iBands(), iEnvelopes(), iEnvelopesOnArray(), iFractals() and iGator()
#define MODE_UPPER               1        // upper line
#define MODE_LOWER               2        // lower line

#define B_LOWER                  0
#define B_UPPER                  1


// Sorting modes, siehe ArraySort()
#define MODE_ASCEND              1        // aufsteigend
#define MODE_DESCEND             2        // absteigend


// Price identifiers, siehe iMA()
#define PRICE_CLOSE              0        // close price
#define PRICE_OPEN               1        // open price
#define PRICE_HIGH               2        // high price
#define PRICE_LOW                3        // low price
#define PRICE_MEDIAN             4        // median price: (high+low)/2
#define PRICE_TYPICAL            5        // typical price: (high+low+close)/3
#define PRICE_WEIGHTED           6        // weighted close price: (high+low+close+close)/4

#define PRICE_BID                7
#define PRICE_ASK                8


// Rates array identifier, siehe ArrayCopyRates()
#define RATE_TIME                0        // bar open time
#define RATE_OPEN                1        // open price
#define RATE_LOW                 2        // low price
#define RATE_HIGH                3        // high price
#define RATE_CLOSE               4        // close price
#define RATE_VOLUME              5        // volume


// Event-Identifier siehe event()
#define EVENT_BAR_OPEN           0x0001
#define EVENT_ORDER_PLACE        0x0002
#define EVENT_ORDER_CHANGE       0x0004
#define EVENT_ORDER_CANCEL       0x0008
#define EVENT_POSITION_OPEN      0x0010
#define EVENT_POSITION_CLOSE     0x0020
#define EVENT_ACCOUNT_CHANGE     0x0040
#define EVENT_ACCOUNT_PAYMENT    0x0080   // Ein- oder Auszahlung
#define EVENT_CHART_CMD          0x0100   // Chart-Command             (aktueller Chart)
#define EVENT_INTERNAL_CMD       0x0200   // terminal-internes Command (globale Variablen)
#define EVENT_EXTERNAL_CMD       0x0400   // externes Command          (QuickChannel)


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
#define MCM_CFDLEVERAGE          4        // erst seit MT5 dokumentiert


// Swap calculation modes, siehe MarketInfo(symbol, MODE_SWAPTYPE)
#define SCM_POINTS               0
#define SCM_BASE_CURRENCY        1
#define SCM_INTEREST             2
#define SCM_MARGIN_CURRENCY      3        // Deposit-Currency


// Profit calculation modes, siehe MarketInfo(symbol, MODE_PROFITCALCMODE)
#define PCM_FOREX                0
#define PCM_CFD                  1
#define PCM_FUTURES              2


// Account stopout modes, siehe AccountStopoutMode()
#define ASM_PERCENT              0
#define ASM_ABSOLUTE             1


// ID's zur Objektpositionierung, siehe ObjectSet(label, OBJPROP_CORNER,  int)
#define CORNER_TOP_LEFT          0        // default
#define CORNER_TOP_RIGHT         1
#define CORNER_BOTTOM_LEFT       2
#define CORNER_BOTTOM_RIGHT      3


// UninitializeReason-Codes
#define REASON_UNDEFINED         0        // no uninitialize reason
#define REASON_REMOVE            1        // program removed from chart
#define REASON_RECOMPILE         2        // program recompiled
#define REASON_CHARTCHANGE       3        // chart symbol or timeframe changed
#define REASON_CHARTCLOSE        4        // chart closed or template changed
#define REASON_PARAMETERS        5        // input parameters changed
#define REASON_ACCOUNT           6        // account changed


// Currency-ID's
#define CID_AUD                  1
#define CID_CAD                  2
#define CID_CHF                  3
#define CID_EUR                  4
#define CID_GBP                  5
#define CID_JPY                  6
#define CID_USD                  7        // zuerst die ID's der Majors, dadurch "passen" diese in 3 Bits (für LFX etc.)

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


// Struct sizes
#define ORDER_EXECUTION.size                72


// Element-ID's ausführungsspezifischer Orderdaten, siehe Parameter execution[] der Orderfunktionen
#define EXEC_TIME                            0
#define EXEC_PRICE                           1
#define EXEC_SWAP                            2
#define EXEC_COMMISSION                      3
#define EXEC_PROFIT                          4
#define EXEC_DURATION                        5
#define EXEC_REQUOTES                        6
#define EXEC_SLIPPAGE                        7
#define EXEC_TICKET                          8


// FindFileNames() flags
#define FF_SORT                              1     // Ergebnisse von NTFS-Laufwerken sind immer sortiert
#define FF_DIRSONLY                          2
#define FF_FILESONLY                         4


// MessageBox() flags
#define MB_OK                       0x00000000     // buttons
#define MB_OKCANCEL                 0x00000001
#define MB_YESNO                    0x00000004
#define MB_YESNOCANCEL              0x00000003
#define MB_ABORTRETRYIGNORE         0x00000002
#define MB_CANCELTRYCONTINUE        0x00000006
#define MB_RETRYCANCEL              0x00000005
#define MB_HELP                     0x00004000     // additional help button

#define MB_DEFBUTTON1               0x00000000     // default button
#define MB_DEFBUTTON2               0x00000100
#define MB_DEFBUTTON3               0x00000200
#define MB_DEFBUTTON4               0x00000300

#define MB_ICONEXCLAMATION          0x00000030     // icons
#define MB_ICONWARNING      MB_ICONEXCLAMATION
#define MB_ICONINFORMATION          0x00000040
#define MB_ICONASTERISK     MB_ICONINFORMATION
#define MB_ICONQUESTION             0x00000020
#define MB_ICONSTOP                 0x00000010
#define MB_ICONERROR               MB_ICONSTOP
#define MB_ICONHAND                MB_ICONSTOP
#define MB_USERICON                 0x00000080

#define MB_APPLMODAL                0x00000000     // modality
#define MB_SYSTEMMODAL              0x00001000
#define MB_TASKMODAL                0x00002000

#define MB_DEFAULT_DESKTOP_ONLY     0x00020000     // other
#define MB_RIGHT                    0x00080000
#define MB_RTLREADING               0x00100000
#define MB_SETFOREGROUND            0x00010000
#define MB_TOPMOST                  0x00040000
#define MB_NOFOCUS                  0x00008000
#define MB_SERVICE_NOTIFICATION     0x00200000


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


// Arrow-Codes, siehe ObjectSet(label, OBJPROP_ARROWCODE, value)
#define SYMBOL_ORDEROPEN                     1     // right pointing arrow (default open ticket marker)
#define SYMBOL_ORDEROPEN_UP   SYMBOL_ORDEROPEN     // right pointing up arrow                               // ??? wird so nicht angezeigt
#define SYMBOL_ORDEROPEN_DOWN                2     // right pointing down arrow                             // ??? wird so nicht angezeigt
#define SYMBOL_ORDERCLOSE                    3     // left pointing arrow (default closed ticket marker)

#define SYMBOL_DASH                          4     // dash symbol (default stoploss and takeprofit marker)
#define SYMBOL_LEFTPRICE                     5     // left sided price label
#define SYMBOL_RIGHTPRICE                    6     // right sided price label
#define SYMBOL_THUMBSUP                     67     // thumb up symbol
#define SYMBOL_THUMBSDOWN                   68     // thumb down symbol
#define SYMBOL_ARROWUP                     241     // arrow up symbol
#define SYMBOL_ARROWDOWN                   242     // arrow down symbol
#define SYMBOL_STOPSIGN                    251     // stop sign symbol
#define SYMBOL_CHECKSIGN                   252     // check sign symbol


// MT4 internal messages
#define MT4_TICK                             2     // künstlicher Tick, führt start() aus
#define MT4_COMPILE_REQUEST              12345
#define MT4_COMPILE_PERMISSION           12346
#define MT4_COMPILE_FINISHED             12349     // Rescan und Reload modifizierter .ex4-Files


// MT4 command ids (menu or accelerator identifier)
#define ID_EXPERTS_ONOFF                 33020     // Toolbar: Experts on/off                    Ctrl+E

#define ID_CHART_STEPFORWARD             33197     // Chart: eine Bar vorwärts                      F12
#define ID_CHART_STEPBACKWARD            33198     //        eine Bar rückwärts               Shift+F12
#define ID_CHART_EXPERT_PROPERTIES       33048     //        Expert Properties-Dialog                F7

#define ID_TESTER_TICK    ID_CHART_STEPFORWARD     // Tester: nächster Tick                         F12


// MT4 item ids (dialog or control identifier)
#define ID_DOCKABLES_CONTAINER           59422     // window containing all child windows docked inside the main application window
#define ID_UNDOCKED_CONTAINER            59423     // window containing undocked child windows (one per undocked child)

#define ID_MARKETWATCH                      80     // Market Watch
#define ID_MARKETWATCH_SYMBOLS           35441     // Market Watch - Symbols
#define ID_MARKETWATCH_TICKCHART         35442     // Market Watch - Tick Chart

#define ID_NAVIGATOR                        82     // Navigator
#define ID_NAVIGATOR_COMMON              35439     // Navigator - Common
#define ID_NAVIGATOR_FAVOURITES          35440     // Navigator - Favourites

#define ID_TERMINAL                         81     // Terminal
#define ID_TERMINAL_TRADE                33217     // Terminal - Trade
#define ID_TERMINAL_ACCOUNTHISTORY       33208     // Terminal - Account History
#define ID_TERMINAL_NEWS                 33211     // Terminal - News
#define ID_TERMINAL_ALERTS               33206     // Terminal - Alerts
#define ID_TERMINAL_MAILBOX              33210     // Terminal - Mailbox
#define ID_TERMINAL_EXPERTS              35434     // Terminal - Experts
#define ID_TERMINAL_JOURNAL              33209     // Terminal - Journal

#define ID_TESTER                           83     // Tester
#define ID_TESTER_SETTINGS               33215     // Tester - Settings
#define ID_TESTER_PAUSERESUME             1402     // Tester - Settings Pause/Resume button
#define ID_TESTER_STARTSTOP               1034     // Tester - Settings Start/Stop button
#define ID_TESTER_RESULTS                33214     // Tester - Results
#define ID_TESTER_GRAPH                  33207     // Tester - Graph
#define ID_TESTER_REPORT                 33213     // Tester - Report
#define ID_TESTER_JOURNAL  ID_TERMINAL_EXPERTS     // Tester - Journal (entspricht Terminal - Experts)


// MQL-Fehlercodes
#define ERR_NO_ERROR                                                  0
#define NO_ERROR                                           ERR_NO_ERROR

// Trade server errors
#define ERR_NO_RESULT                                                 1    // Tradeserver-Wechsel während OrderModify()
#define ERR_COMMON_ERROR                                              2    // trade denied
#define ERR_INVALID_TRADE_PARAMETERS                                  3
#define ERR_SERVER_BUSY                                               4
#define ERR_OLD_VERSION                                               5
#define ERR_NO_CONNECTION                                             6
#define ERR_NOT_ENOUGH_RIGHTS                                         7
#define ERR_TOO_FREQUENT_REQUESTS                                     8
#define ERR_MALFUNCTIONAL_TRADE                                       9
#define ERR_ACCOUNT_DISABLED                                         64
#define ERR_INVALID_ACCOUNT                                          65
#define ERR_TRADE_TIMEOUT                                           128
#define ERR_INVALID_PRICE                                           129    // Kurs bewegt sich zu schnell (aus dem Fenster)
#define ERR_INVALID_STOPS                                           130
#define ERR_INVALID_TRADE_VOLUME                                    131
#define ERR_MARKET_CLOSED                                           132
#define ERR_TRADE_DISABLED                                          133
#define ERR_NOT_ENOUGH_MONEY                                        134
#define ERR_PRICE_CHANGED                                           135
#define ERR_OFF_QUOTES                                              136
#define ERR_BROKER_BUSY                                             137
#define ERR_REQUOTE                                                 138
#define ERR_ORDER_LOCKED                                            139
#define ERR_LONG_POSITIONS_ONLY_ALLOWED                             140
#define ERR_TOO_MANY_REQUESTS                                       141
#define ERR_TRADE_MODIFY_DENIED                                     145
#define ERR_TRADE_CONTEXT_BUSY                                      146
#define ERR_TRADE_EXPIRATION_DENIED                                 147
#define ERR_TRADE_TOO_MANY_ORDERS                                   148
#define ERR_TRADE_HEDGE_PROHIBITED                                  149
#define ERR_TRADE_PROHIBITED_BY_FIFO                                150

// Errors causing an immediate execution stop
#define ERR_WRONG_FUNCTION_POINTER                                 4001    // If execution stopped due to one of those errors, the error code is available
#define ERR_NO_MEMORY_FOR_CALL_STACK                               4003    // at the next call of start() or deinit().
#define ERR_RECURSIVE_STACK_OVERFLOW                               4004
#define ERR_NO_MEMORY_FOR_PARAM_STRING                             4006
#define ERR_NO_MEMORY_FOR_TEMP_STRING                              4007
#define ERR_NO_MEMORY_FOR_ARRAYSTRING                              4010
#define ERR_TOO_LONG_STRING                                        4011
#define ERR_REMAINDER_FROM_ZERO_DIVIDE                             4012
#define ERR_ZERO_DIVIDE                                            4013
#define ERR_UNKNOWN_COMMAND                                        4014

// Errors causing an immediate execution stop until the program is re-initialized; start() or deinit() will not get called again
#define ERR_CANNOT_LOAD_LIBRARY                                    4018
#define ERR_CANNOT_CALL_FUNCTION                                   4019
#define ERR_DLL_CALLS_NOT_ALLOWED                                  4017    // DLL imports
#define ERR_EXTERNAL_CALLS_NOT_ALLOWED                             4020    // ex4 library imports

// Runtime errors
#define ERR_RUNTIME_ERROR                                          4000    // user runtime error (never generated by the terminal)
#define ERR_ARRAY_INDEX_OUT_OF_RANGE                               4002
#define ERR_NOT_ENOUGH_STACK_FOR_PARAM                             4005
#define ERR_NOT_INITIALIZED_STRING                                 4008
#define ERR_NOT_INITIALIZED_ARRAYSTRING                            4009
#define ERR_WRONG_JUMP                                             4015
#define ERR_NOT_INITIALIZED_ARRAY                                  4016
#define ERR_NO_MEMORY_FOR_RETURNED_STR                             4021
#define ERR_SYSTEM_BUSY                                            4022
//                                                                 4023    // ???
#define ERR_INVALID_FUNCTION_PARAMSCNT                             4050    // invalid parameters count
#define ERR_INVALID_FUNCTION_PARAMVALUE                            4051    // invalid parameter value
#define ERR_STRING_FUNCTION_INTERNAL                               4052
#define ERR_SOME_ARRAY_ERROR                                       4053    // some array error
#define ERR_INCORRECT_SERIESARRAY_USING                            4054
#define ERR_CUSTOM_INDICATOR_ERROR                                 4055    // custom indicator error
#define ERR_INCOMPATIBLE_ARRAYS                                    4056    // incompatible arrays
#define ERR_GLOBAL_VARIABLES_PROCESSING                            4057
#define ERR_GLOBAL_VARIABLE_NOT_FOUND                              4058
#define ERR_FUNC_NOT_ALLOWED_IN_TESTING                            4059    // function not allowed in tester
#define ERR_FUNC_NOT_ALLOWED_IN_TESTER  ERR_FUNC_NOT_ALLOWED_IN_TESTING
#define ERR_FUNCTION_NOT_CONFIRMED                                 4060
#define ERR_SEND_MAIL_ERROR                                        4061
#define ERR_STRING_PARAMETER_EXPECTED                              4062
#define ERR_INTEGER_PARAMETER_EXPECTED                             4063
#define ERR_DOUBLE_PARAMETER_EXPECTED                              4064
#define ERR_ARRAY_AS_PARAMETER_EXPECTED                            4065
#define ERR_HISTORY_WILL_UPDATED                                   4066    // history in update state
#define ERR_HISTORY_UPDATE                     ERR_HISTORY_WILL_UPDATED
#define ERR_TRADE_ERROR                                            4067    // error in trading function
#define ERR_END_OF_FILE                                            4099    // end of file
#define ERR_SOME_FILE_ERROR                                        4100    // some file error
#define ERR_WRONG_FILE_NAME                                        4101
#define ERR_TOO_MANY_OPENED_FILES                                  4102
#define ERR_CANNOT_OPEN_FILE                                       4103
#define ERR_INCOMPATIBLE_FILEACCESS                                4104
#define ERR_NO_ORDER_SELECTED                                      4105    // no order selected
#define ERR_UNKNOWN_SYMBOL                                         4106    // unknown symbol
#define ERR_INVALID_PRICE_PARAM                                    4107
#define ERR_INVALID_TICKET                                         4108    // invalid ticket
#define ERR_TRADE_NOT_ALLOWED                                      4109
#define ERR_LONGS_NOT_ALLOWED                                      4110
#define ERR_SHORTS_NOT_ALLOWED                                     4111
#define ERR_OBJECT_ALREADY_EXISTS                                  4200
#define ERR_UNKNOWN_OBJECT_PROPERTY                                4201
#define ERR_OBJECT_DOES_NOT_EXIST                                  4202
#define ERR_UNKNOWN_OBJECT_TYPE                                    4203
#define ERR_NO_OBJECT_NAME                                         4204
#define ERR_OBJECT_COORDINATES_ERROR                               4205
#define ERR_NO_SPECIFIED_SUBWINDOW                                 4206
#define ERR_SOME_OBJECT_ERROR                                      4207

// Custom errors
#define ERR_WIN32_ERROR                                            5000    // win32 api error
#define ERR_FUNCTION_NOT_IMPLEMENTED                               5001    // function not implemented
#define ERR_INVALID_INPUT                                          5002    // invalid input parameter
#define ERR_INVALID_CONFIG_PARAMVALUE                              5003    // invalid configuration parameter
#define ERR_TERMINAL_NOT_YET_READY                                 5004    // terminal not yet ready
#define ERR_INVALID_TIMEZONE_CONFIG                                5005    // invalid or missing timezone configuration
#define ERR_INVALID_MARKET_DATA                                    5006    // invalid market data
#define ERR_FILE_NOT_FOUND                                         5007    // file not found
#define ERR_CANCELLED_BY_USER                                      5008    // execution cancelled by user
#define ERR_FUNC_NOT_ALLOWED                                       5009    // function not allowed
#define ERR_INVALID_COMMAND                                        5010    // invalid or unknow command
#define ERR_ILLEGAL_STATE                                          5011    // illegal state


// Variablen für ChartInfo-Block (siehe unten)
string ChartInfo.instrument,
       ChartInfo.price,
       ChartInfo.spread,
       ChartInfo.unitSize,
       ChartInfo.position,
       ChartInfo.time,
       ChartInfo.freezeLevel,
       ChartInfo.stopoutLevel;

int    ChartInfo.appliedPrice = PRICE_MEDIAN;                        // Bid | Ask | Median (default)

double ChartInfo.leverage,                                           // Hebel zur UnitSize-Berechnung
       ChartInfo.longPosition,
       ChartInfo.shortPosition,
       ChartInfo.totalPosition;

bool   ChartInfo.positionChecked,
       ChartInfo.noPosition,
       ChartInfo.flatPosition;


// globale Variablen, stehen überall zur Verfügung
string __NAME__;                                                     // Name des aktuellen MQL-Programms
int    __WHEREAMI__;                                                 // ID der vom Terminal momentan ausgeführten Basisfunktion: FUNC_INIT | FUNC_START | FUNC_DEINIT
bool   __LOG = true;
bool   __LOG_INSTANCE_ID;
bool   __LOG_PER_INSTANCE;
bool   __STATUS__HISTORY_UPDATE;                                     // History-Update wurde getriggert
bool   __STATUS__INVALID_INPUT;                                      // ungültige Parametereingabe im Input-Dialog
bool   __STATUS__RELAUNCH_INPUT;                                     // Anforderung, den Input-Dialog zu laden
bool   __STATUS__CANCELLED;                                          // Programmausführung durch Benutzer-Dialog abgebrochen

int    prev_error = NO_ERROR;                                        // der letzte Fehler des vorherigen start()-Aufrufs
int    last_error = NO_ERROR;                                        // der letzte Fehler des aktuellen start()-Aufrufs

double Pip, Pips;                                                    // Betrag eines Pips des aktuellen Symbols (z.B. 0.0001 = PipSize)
int    PipDigits;                                                    // Digits eines Pips des aktuellen Symbols (Annahme: Pips sind gradzahlig)
int    PipPoint, PipPoints;                                          // Auflösung eines Pips des aktuellen Symbols (Anzahl der Punkte auf der Dezimalskala je Pip)
double TickSize;                                                     // kleinste Änderung des Preises des aktuellen Symbols je Tick (Vielfaches von MODE_POINT)
string PriceFormat;                                                  // Preisformat des aktuellen Symbols für NumberToStr()
int    Tick, Ticks;
int    ValidBars;
int    ChangedBars;


string objects[];                                                    // Namen der Objekte, die mit Beenden des Programms automatisch entfernt werden


/**
 * Globale init()-Funktion für alle MQL-Programme.
 *
 * Ist das Flag __STATUS__CANCELLED gesetzt, bricht init() ab.  Nur bei Aufruf durch das Terminal wird
 * der letzte Errorcode 'last_error' in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int init() { /*throws ERR_TERMINAL_NOT_YET_READY*/
   if (IsLibrary())
      return(NO_ERROR);                                                       // in Libraries vorerst nichts tun

   __NAME__                       = WindowExpertName();
     int initFlags                = SumInts(__INIT_FLAGS__);
   __LOG_INSTANCE_ID              = initFlags & LOG_INSTANCE_ID;
   __LOG_PER_INSTANCE             = initFlags & LOG_PER_INSTANCE;
   bool _INIT_TIMEZONE            = initFlags & INIT_TIMEZONE;
   bool _INIT_TICKVALUE           = initFlags & INIT_TICKVALUE;
   bool _INIT_BARS_ON_HIST_UPDATE = initFlags & INIT_BARS_ON_HIST_UPDATE;

   if (__STATUS__CANCELLED) return(NO_ERROR);

   if (__WHEREAMI__ == NULL) {                                                // Aufruf durch Terminal: last_error sichern und zurücksetzen
      __WHEREAMI__ = FUNC_INIT;
      prev_error   = last_error;
      last_error   = NO_ERROR;
   }
   if (IsTesting())
      __LOG = (__LOG && GetGlobalConfigBool(__NAME__, "Logger.Tester", true));


   // (1) globale Variablen und stdlib re-initialisieren (Indikatoren setzen Variablen nach jedem deinit() zurück)
   PipDigits   = Digits & (~1);
   PipPoints   = Round(MathPow(10, Digits-PipDigits)); PipPoint = PipPoints;
   Pip         =     1/MathPow(10, PipDigits);         Pips     = Pip;
   PriceFormat = StringConcatenate(".", PipDigits, ifString(Digits==PipDigits, "", "'"));
   TickSize    = MarketInfo(Symbol(), MODE_TICKSIZE);

   int error = GetLastError();                                                // Symbol nicht subscribed (Start, Account- oder Templatewechsel),
   if (error == ERR_UNKNOWN_SYMBOL) {                                         // das Symbol kann später evt. noch "auftauchen"
      debug("init()   ERR_TERMINAL_NOT_YET_READY (MarketInfo() => ERR_UNKNOWN_SYMBOL)");
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
   }
   if (IsError(error))        return(catch("init(1)", error));
   if (TickSize < 0.00000001) return(catch("init(2)   TickSize = "+ NumberToStr(TickSize, ".+"), ERR_INVALID_MARKET_DATA));

   // stdlib
   error = stdlib_init(__TYPE__, __NAME__, __WHEREAMI__, initFlags, UninitializeReason());
   if (IsError(error))
      return(SetLastError(error));


   // (2) User-spezifische Init-Tasks ausführen
   if (_INIT_TIMEZONE) {                                                      // @see stdlib_init()
   }
   if (_INIT_TICKVALUE) {                                                     // schlägt fehl, wenn noch kein (alter) Tick vorhanden ist
      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      if (tickValue < 0.00000001) {
         debug("init()   ERR_TERMINAL_NOT_YET_READY (TickValue = "+ NumberToStr(tickValue, ".+") +")");
         return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
      }
   }
   if (_INIT_BARS_ON_HIST_UPDATE) {                                           // noch nicht implementiert
   }


   // (3) für EA's durchzuführende globale Initialisierungen
   if (IsExpert()) {                                                          // ggf. EA's aktivieren
      int reasons1[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE };
      if (!IsTesting()) /*&&*/ if (!IsExpertEnabled()) /*&&*/ if (IntInArray(reasons1, UninitializeReason())) {
         error = Menu.Experts(true);                                          // !!! TODO: Bug, wenn mehrere EA's den Modus gleichzeitig umschalten
         if (IsError(error))
            return(SetLastError(error));
      }
                                                                              // nach Neuladen Orderkontext wegen Bug ausdrücklich zurücksetzen (siehe MQL.doc)
      int reasons2[] = { REASON_UNDEFINED, REASON_CHARTCLOSE, REASON_REMOVE, REASON_ACCOUNT };
      if (IntInArray(reasons2, UninitializeReason()))
         OrderSelect(0, SELECT_BY_TICKET);


      if (IsVisualMode()) {                                                   // Im Tester übernimmt der EA die ChartInfo-Anzeige, die hier konfiguriert wird.
         ChartInfo.appliedPrice = PRICE_BID;                                  // PRICE_BID ist in EA's ausreichend und schneller (@see ChartInfo-Indikator)
         ChartInfo.leverage     = GetGlobalConfigDouble("Leverage", "CurrencyPair", 1);
         if (LT(ChartInfo.leverage, 1))
            return(catch("init(3)  invalid configuration value [Leverage] CurrencyPair = "+ NumberToStr(ChartInfo.leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));
         error = ChartInfo.CreateLabels();
         if (IsError(error))
            return(error);
      }
   }


   // (4) User-spezifische init()-Routinen aufrufen
   if (onInit() == -1)                                                        // User-Routinen *können*, müssen aber nicht implementiert werden.
      return(last_error);                                                     // Preprocessing-Hook
                                                                              //
   switch (UninitializeReason()) {                                            // - Gibt eine der Funktionen einen Fehler zurück oder setzt das Flag __STATUS__CANCELLED,
      case REASON_UNDEFINED  : error = onInitUndefined();       break;        //   bricht init() *nicht* ab.
      case REASON_CHARTCLOSE : error = onInitChartClose();      break;        //
      case REASON_REMOVE     : error = onInitRemove();          break;        // - Gibt eine der Funktionen -1 zurück, bricht init() ab.
      case REASON_RECOMPILE  : error = onInitRecompile();       break;        //
      case REASON_PARAMETERS : error = onInitParameterChange(); break;        //
      case REASON_CHARTCHANGE: error = onInitChartChange();     break;        //
      case REASON_ACCOUNT    : error = onInitAccountChange();   break;        //
   }                                                                          //
   if (error == -1)                                                           //
      return(last_error);                                                     //
                                                                              //
   afterInit();                                                               // Postprocessing-Hook
   if (IsLastError() || __STATUS__CANCELLED)                                  //
      return(last_error);                                                     //


   // (5) nur EA's: nicht auf den nächsten echten Tick warten, sondern (so spät wie möglich) selbst einen Tick schicken
   if (IsExpert()) {
      if (!IsTesting()) {                                                     // nicht bei REASON_CHARTCHANGE
         if (UninitializeReason() != REASON_CHARTCHANGE)
            Chart.SendTick(false);                                            // So spät wie möglich, da Ticks aus init() verloren gehen können, wenn die entsprechende
      }                                                                       // Message vor Verlassen von init() vom UI-Thread verarbeitet wurde.
   }

   catch("init(4)");
   return(last_error);
}


/**
 * Globale start()-Funktion für alle MQL-Programme.
 *
 * - Ist das Flag __STATUS__CANCELLED gesetzt, bricht start() ab.
 *
 * - Erfolgt der Aufruf nach einem vorherigem init()-Aufruf und init() kehrte mit dem Fehler ERR_TERMINAL_NOT_YET_READY zurück,
 *   wird versucht, init() erneut auszuführen. Bei erneutem init()-Fehler bricht start() ab.
 *   Wurde init() fehlerfrei ausgeführt, wird der letzte Errorcode 'last_error' vor Abarbeitung zurückgesetzt.
 *
 * - Der letzte Errorcode 'last_error' wird in 'prev_error' gespeichert und vor Abarbeitung zurückgesetzt.
 *
 * @return int - Fehlerstatus
 */
int start() {
   if (__STATUS__CANCELLED)
      return(NO_ERROR);


   // Time machine bug im Tester abfangen
   static datetime lastTime;
   if (lastTime!=0) /*&&*/ if (TimeCurrent() < lastTime) {
      __STATUS__CANCELLED = true;
      return(catch("start(1)   Time is running backward here:   current tick='"+ TimeToStr(TimeCurrent(), TIME_FULL) +"'   last tick='"+ TimeToStr(lastTime, TIME_FULL) +"'", ERR_RUNTIME_ERROR));
   }
   lastTime = TimeCurrent();



   int error;

   Tick++; Ticks = Tick;
   ValidBars = IndicatorCounted();


   // (1) Falls wir aus init() kommen, prüfen, ob es erfolgreich war und *nur dann* Flag zurücksetzen.
   if (__WHEREAMI__ == FUNC_INIT) {
      if (IsLastError()) {                                           // init() ist mit Fehler zurückgekehrt
         if (IsScript() || last_error!=ERR_TERMINAL_NOT_YET_READY)
            return(last_error);
         __WHEREAMI__ = FUNC_START;
         error = init();                                             // Indikatoren und EA's können init() erneut aufrufen
         if (IsError(error)) {                                       // erneuter Fehler
            __WHEREAMI__ = FUNC_INIT;
            return(error);
         }
      }
      last_error = NO_ERROR;                                         // init() war (ggf. nach erneutem Aufruf) erfolgreich
      ValidBars  = 0;
   }
   else {
      prev_error = last_error;                                       // weiterer Tick: last_error sichern und zurücksetzen
      last_error = NO_ERROR;
      if (prev_error == ERR_TERMINAL_NOT_YET_READY)
         ValidBars = 0;                                              // falls das Terminal beim vorherigen start()-Aufruf noch nicht bereit war
   }
   __WHEREAMI__ = FUNC_START;


   // (2) bei Bedarf Input-Dialog aufrufen
   if (__STATUS__RELAUNCH_INPUT) {
      __STATUS__RELAUNCH_INPUT = false;
      return(start.RelaunchInputDialog());
   }


   // (3) Abschluß der Chart-Initialisierung überprüfen (kann bei Terminal-Start auftreten)
   if (Bars == 0) {
      debug("start()   ERR_TERMINAL_NOT_YET_READY (Bars = 0)");
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));
   }


   /*
   // (4) Werden in Indikatoren Zeichenpuffer verwendet (indicator_buffers > 0), muß deren Initialisierung überprüft werden
   //     (kann nicht hier, sondern erst in onTick() erfolgen).
   if (ArraySize(iBuffer) == 0)
      return(SetLastError(ERR_TERMINAL_NOT_YET_READY));              // kann bei Terminal-Start auftreten
   */


   // (5) ChangedBars berechnen
   ChangedBars = Bars - ValidBars;


   // (6) stdLib benachrichtigen
   if (stdlib_start(Tick, ValidBars, ChangedBars) != NO_ERROR)
      return(SetLastError(stdlib_PeekLastError()));


   // (7) Im Tester übernimmt der jeweilige EA die Anzeige der Chartinformationen (@see ChartInfo-Indikator)
   if (IsVisualMode()) {
      error = NO_ERROR;
      ChartInfo.positionChecked = false;
      error |= ChartInfo.UpdatePrice();
      error |= ChartInfo.UpdateSpread();
      error |= ChartInfo.UpdateUnitSize();
      error |= ChartInfo.UpdatePosition();
      error |= ChartInfo.UpdateTime();
      error |= ChartInfo.UpdateMarginLevels();
      if (IsError(error))                                            // NICHT error (ist hier die Summe aller in ChartInfo.* aufgetretenen Fehler)
         return(last_error);
   }


   // (8) neue Main-Funktion aufrufen
   if (IsScript()) error = onStart();
   else            error = onTick();

   return(error);
   DummyCalls();                                                     // unterdrücken unnütze Compilerwarnungen
}


/**
 * Globale deinit()-Funktion für alle MQL-Programme. Ist das Flag __STATUS__CANCELLED gesetzt, bricht deinit() *nicht* ab.
 * Es liegt in der Verantwortung des Users, diesen Status selbst auszuwerten.
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   __WHEREAMI__ = FUNC_DEINIT;

   if (IsLibrary())                                                              // in Libraries vorerst nichts tun
      return(NO_ERROR);


   // (1) User-spezifische deinit()-Routinen aufrufen                            // User-Routinen *können*, müssen aber nicht implementiert werden.
   int error = onDeinit();                                                       // Preprocessing-Hook
                                                                                 //
   if (error != -1) {                                                            // - Gibt eine der Funktionen einen Fehler zurück oder setzt das Flag __STATUS__CANCELLED,
      switch (UninitializeReason()) {                                            //   bricht deinit() *nicht* ab.
         case REASON_UNDEFINED  : error = onDeinitUndefined();       break;      //
         case REASON_CHARTCLOSE : error = onDeinitChartClose();      break;      // - Gibt eine der Funktionen -1 zurück, bricht deinit() alle weiteren User-Routinen ab.
         case REASON_REMOVE     : error = onDeinitRemove();          break;      //
         case REASON_RECOMPILE  : error = onDeinitRecompile();       break;      //
         case REASON_PARAMETERS : error = onDeinitParameterChange(); break;      //
         case REASON_CHARTCHANGE: error = onDeinitChartChange();     break;      //
         case REASON_ACCOUNT    : error = onDeinitAccountChange();   break;      //
      }                                                                          //
   }                                                                             //
   if (error != -1)                                                              //
      error = afterDeinit();                                                     // Postprocessing-Hook


   // (2) User-spezifische Deinit-Tasks ausführen
   if (error != -1) {
      // do something...
   }


   // (3) stdlib deinitialisieren
   error = stdlib_deinit(SumInts(__DEINIT_FLAGS__), UninitializeReason());
   if (IsError(error))
      SetLastError(error);

   return(last_error);
}


/**
 * Lädt den Input-Dialog des aktuellen Programms neu.
 *
 * @return int - Fehlerstatus
 */
int start.RelaunchInputDialog() {
   if (__STATUS__CANCELLED)
      return(NO_ERROR);

   int error;

   if (IsExpert()) {
      if (!IsTesting())
         error = Chart.Expert.Properties();
   }
   else if (IsIndicator()) {
      //error = LaunchIndicatorPropertiesDlg();                      // TODO: implementieren
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
 * NOTE:
 * -----
 * Nur bei Implementierung in der Headerdatei wird das tatsächlich laufende Script als Auslöser angezeigt.
 */
int debug(string message, int error=NO_ERROR) {
   static int static.debugToLog = -1;
   if (static.debugToLog == -1)
      static.debugToLog = GetLocalConfigBool("Logging", "DebugToLog", false);

   if (static.debugToLog == 1) {
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
 * NOTE:
 * -----
 * Nur bei Implementierung in der Headerdatei wird das tatsächlich laufende Script als Auslöser angezeigt.
 */
int log(string message, int error=NO_ERROR) {
   if (!__LOG) return(error);

   if (IsError(error))
      message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");

   if (__LOG_PER_INSTANCE)
      if (logInstance(StringConcatenate(__NAME__, "::", message)))         // ohne Instanz-ID, bei Fehler Fall-back zum Standard-Logging
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
 * Loggt eine Message in das instanz-eigenes Logfile.
 *
 * @param  string message - vollständige, zu loggende Message (ohne Zeitstempel, Symbol, Timeframe)
 *
 * @return bool - Erfolgsstatus: u.a. FALSE, wenn das instanz-eigene Logfile (noch) nicht definiert ist
 */
bool logInstance(string message) {
   if (!__LOG) return(true);

   bool old.LOG_PER_INSTANCE = __LOG_PER_INSTANCE;
   int id = InstanceId(NULL);
   if (id == NULL)
      return(false);

   message = StringConcatenate(TimeToStr(TimeLocal(), TIME_FULL), "  ", StdSymbol(), ",", StringRightPad(PeriodDescription(NULL), 3, " "), "  ", message);

   string fileName = StringConcatenate(id, ".log");

   int hFile = FileOpen(fileName, FILE_READ|FILE_WRITE);
   if (hFile < 0) {
      __LOG_PER_INSTANCE = false; catch("logInstance(1) ->FileOpen(\""+ fileName +"\")"); __LOG_PER_INSTANCE = old.LOG_PER_INSTANCE;
      return(false);
   }

   if (!FileSeek(hFile, 0, SEEK_END)) {
      __LOG_PER_INSTANCE = false; catch("logInstance(2) ->FileSeek()"); __LOG_PER_INSTANCE = old.LOG_PER_INSTANCE;
      FileClose(hFile);
      return(_false(GetLastError()));
   }

   if (FileWrite(hFile, message) < 0) {
      __LOG_PER_INSTANCE = false; catch("logInstance(3) ->FileWrite()"); __LOG_PER_INSTANCE = old.LOG_PER_INSTANCE;
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
 * NOTE:
 * -----
 * Nur bei Implementierung in der Headerdatei wird das tatsächlich laufende Script als Auslöser angezeigt.
 */
int warn(string message, int error=NO_ERROR) {
   if (IsError(error))
      message = StringConcatenate(message, "  [", error, " - ", ErrorDescription(error), "]");


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
      logged = logInstance(StringConcatenate("WARN: ", __NAME__, "::", message));                     // ohne Instanz-ID, bei Fehler Fall-back zum Standard-Logging
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
 * NOTE:
 * -----
 * Nur bei Implementierung in der Headerdatei wird das tatsächlich laufende Script als Auslöser angezeigt.
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
         logged = logInstance(StringConcatenate("ERROR: ", __NAME__, "::", message));                    // ohne Instanz-ID, bei Fehler Fall-back zum Standard-Logging
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
         // außerhalb des Testers
         Alert("ERROR:   ", Symbol(), ",", PeriodDescription(NULL), "  ", message);
      }
      last_error = error;
   }

   if (orderPop)
      OrderPop(location);

   return(error);
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
 * Ob der interne Fehler-Code des aktuellen Scripts gesetzt ist.
 *
 * @return bool
 */
bool IsLastError() {
   return(last_error != NO_ERROR);
}


/**
 * Setzt den internen Fehlercode des aktuellen Scripts.
 *
 * @param  int error - Fehlercode
 *
 * @return int - derselbe Fehlercode (for chaining)
 *
 *
 *  NOTE: Akzeptiert einen weiteren beliebigen Parameter, der bei der Verarbeitung jedoch ignoriert wird.
 *  -----
 */
int SetLastError(int error, int param=NULL) {
   last_error = error;
   return(error);
}


/**
 * Setzt den internen Fehlercode des aktuellen Programms zurück.
 *
 * @return int - der vorm Zurücksetzen gesetzte Fehlercode
 */
int ResetLastError() {
   int error = last_error;
   last_error = NO_ERROR;
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
 * NOTE:
 * -----
 * @use  HandleEvent(), um für die Prüfung weitere, event-spezifische Parameter anzugeben
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
   int    iResults[];                                                // zurücksetzen nicht nötig, da die Listener die Arrays selbst zurücksetzen
   string sResults[];

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


int stack.selectedOrders[];                                          // @see OrderPush(), OrderPop()


/**
 * Selektiert eine Order anhand des Tickets.
 *
 * @param  int    ticket          - Ticket
 * @param  string location        - Bezeichner für eine evt. Fehlermeldung
 * @param  bool   orderPush       - ob der aktuelle Orderkontext vorm Neuselektieren gespeichert werden soll (default: nein)
 * @param  bool   onErrorOrderPop - ob im Fehlerfall der letzte Orderkontext wiederhergestellt werden soll (default: nein bei orderPush=FALSE, ja bei orderPush=TRUE)
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE:
 * -----
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
 * Schiebt den aktuellen Orderkontext auf den Kontextstack (fügt ihn ans Ende an).
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
 * Entfernt den letzten Orderkontext vom Ende des Kontextstacks und restauriert ihn.
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
 * @param  int  ticket    - Orderticket
 * @param  bool orderKeep - ob der aktuelle Orderkontext bewahrt werden soll (default: ja)
 *                          wenn FALSE, ist das Ticket nach Rückkehr selektiert
 *
 * @return bool - Erfolgsstatus
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei implementiert, um Default-Parameter zu ermöglichen.
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
      string message = StringConcatenate(Symbol(), ",", PeriodDescription(NULL), "  ", __NAME__, "::WaitForTicket()   #", ticket, " not yet accessible");

      if (IsTesting())           warn (message);
      else if (i > 0 && i%10==0) Alert(message, " after ", DoubleToStr(i*delay/1000.0, 1), " s");
      Sleep(delay);
      i++;
   }

   if (orderKeep) {
      if (!OrderPop("WaitForTicket(3)"))
         return(false);
   }

   return(true);
}


/**
 * Gibt den PipValue des aktuellen Instrument für die angegebene Lotsize zurück.
 *
 * @param  double lots - Lotsize (default: 1 lot)
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
   if (tickValue < 0.00000001) return(_ZERO(catch("PipValue(4)   illegal TickValue = "+ NumberToStr(tickValue, ".+"), ERR_INVALID_MARKET_DATA)));

   return(Pip/TickSize * tickValue * lots);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Indikator ist.
 *
 * @return bool
 */
bool IsIndicator() {
   if (__TYPE__ == T_LIBRARY)
      return(_false(catch("IsIndicator()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
   return(__TYPE__ & T_INDICATOR);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Expert Adviser ist.
 *
 * @return bool
 */
bool IsExpert() {
   if (__TYPE__ == T_LIBRARY)
      return(_false(catch("IsExpert()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
   return(__TYPE__ & T_EXPERT);
}


/**
 * Ob das aktuelle ausgeführte Programm ein Script ist.
 *
 * @return bool
 */
bool IsScript() {
   if (__TYPE__ == T_LIBRARY)
      return(_false(catch("IsScript()   function must not be used before library initialization", ERR_RUNTIME_ERROR)));
   return(__TYPE__ & T_SCRIPT);
}


/**
 * Ob das aktuelle ausgeführte Programm eine Library ist.
 *
 * @return bool
 */
bool IsLibrary() {
   return(__TYPE__ & T_LIBRARY);
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
      return(_false(catch("EQ()  illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));

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
   return(_false(catch("EQ()  illegal parameter digits = "+ digits, ERR_INVALID_FUNCTION_PARAMVALUE)));
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


// =======================================================================================================================================================
// ============================  Beginn ChartInfo-Block (wird sowohl im ChartInfos-Indikator als auch in jedem EA verwendet)  ============================
// =======================================================================================================================================================


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
   if (ObjectFind(ChartInfo.instrument) == 0)
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
   if (ObjectFind(ChartInfo.price) == 0)
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
   if (ObjectFind(ChartInfo.spread) == 0)
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
   if (ObjectFind(ChartInfo.unitSize) == 0)
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
   if (ObjectFind(ChartInfo.position) == 0)
      ObjectDelete(ChartInfo.position);
   if (ObjectCreate(ChartInfo.position, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet(ChartInfo.position, OBJPROP_CORNER, CORNER_BOTTOM_LEFT);
      ObjectSet(ChartInfo.position, OBJPROP_XDISTANCE, 530);
      ObjectSet(ChartInfo.position, OBJPROP_YDISTANCE, 9);
      ObjectSetText(ChartInfo.position, " ", 1);
      ArrayPushString(objects, ChartInfo.position);
   }
   else GetLastError();


   // nur im Tester: Time-Label erzeugen
   if (IsVisualMode()) {
      if (ObjectFind(ChartInfo.time) == 0)
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
   bool   tradeAllowed = IsTesting() || NE(MarketInfo(Symbol(), MODE_TRADEALLOWED), 0);   // MODE_TRADEALLOWED ist im Tester idiotischerweise FALSE
   double tickValue    = MarketInfo(Symbol(), MODE_TICKVALUE);
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


// =======================================================================================================================================================
// =============================  Ende ChartInfo-Block (wird sowohl im ChartInfos-Indikator als auch in jedem EA verwendet)  =============================
// =======================================================================================================================================================


/**
 * Dummy-Calls, unterdrücken unnütze Compilerwarnungen
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
   ChartInfo.CreateLabels();
   ChartInfo.UpdateMarginLevels();
   ChartInfo.UpdatePosition();
   ChartInfo.UpdatePrice();
   ChartInfo.UpdateSpread();
   ChartInfo.UpdateTime();
   ChartInfo.UpdateUnitSize();
   debug(NULL);
   EQ(NULL, NULL);
   GE(NULL, NULL);
   GT(NULL, NULL);
   HandleEvent(NULL);
   HandleEvents(NULL);
   ifBool(NULL, NULL, NULL);
   ifDouble(NULL, NULL, NULL);
   ifInt(NULL, NULL, NULL);
   ifString(NULL, NULL, NULL);
   IsError(NULL);
   IsExpert();
   IsIndicator();
   IsLastError();
   IsNoError(NULL);
   IsScript();
   LE(NULL, NULL);
   log(NULL);
   LT(NULL, NULL);
   Max(NULL, NULL);
   Min(NULL, NULL);
   NE(NULL, NULL);
   OrderPop(NULL);
   OrderPush(NULL);
   OrderSelectByTicket(NULL, NULL);
   PipValue();
   ResetLastError();
   Round(NULL);
   SetLastError(NULL);
   Sign(NULL);
   WaitForTicket(NULL);
   warn(NULL);
}

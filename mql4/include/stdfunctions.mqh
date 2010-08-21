/**
 * stddefine.mqh
 *
 * MQL function declarations and constant definitions
 */


// String maximaler Länge
#define MAX_LEN_STRING         "..............................................................................................................................................................................................................................................................."
#define MAX_STRING_LEN         255


// Zeitkonstanten
#define SECOND                   1
#define MINUTE                  60
#define HOUR                  3600
#define DAY                  86400

#define SECONDS             SECOND
#define MINUTES             MINUTE
#define HOURS                 HOUR
#define DAYS                   DAY


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


// weitere Operation-Types, siehe OrderSend() u. OrderType()
#define OP_BUY                   0     // long position
#define OP_SELL                  1     // short position
#define OP_BUYLIMIT              2     // pending buy limit position
#define OP_SELLLIMIT             3     // pending sell limit position
#define OP_BUYSTOP               4     // pending stop buy position
#define OP_SELLSTOP              5     // pending stop sell position
#define OP_BALANCE               6     // account balance or withdrawel transaction
#define OP_MARGINCREDIT          7     // margin credit facility (no transaction)


// Series array identifier, siehe ArrayCopySeries(), iLowest() u. iHighest()
#define MODE_OPEN                0     // open price
#define MODE_LOW                 1     // low price
#define MODE_HIGH                2     // high price
#define MODE_CLOSE               3     // close price
#define MODE_VOLUME              4     // volume
#define MODE_TIME                5     // bar open time


// Moving average method identifiers, siehe iMA()
#define MODE_SMA                 0     // simple moving average
#define MODE_EMA                 1     // exponential moving average
#define MODE_SMMA                2     // smoothed moving average
#define MODE_LWMA                3     // linear weighted moving average


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


// Array-Identifier zum Zugriff auf Pivotlevel-Ergebnisse, siehe iPivotLevel()
#define PIVOT_R3                 0
#define PIVOT_R2                 1
#define PIVOT_R1                 2
#define PIVOT_PP                 3     // daily pivots only: regular bank closing time (21:00 GMT)
#define PIVOT_S1                 4
#define PIVOT_S2                 5
#define PIVOT_S3                 6
#define PIVOT_PP_IBC             7     // daily pivots only: interbank market closing time (22:00 GMT)


// Konstanten zum Zugriff auf die Spalten der Account-History
#define HISTORY_COLUMNS         23
#define HC_TICKET                0
#define HC_OPENTIME              1
#define HC_OPENTIMESTAMP         2
#define HC_TYPEDESCRIPTION       3
#define HC_TYPE                  4
#define HC_SIZE                  5
#define HC_SYMBOL                6
#define HC_OPENPRICE             7
#define HC_STOPLOSS              8
#define HC_TAKEPROFIT            9
#define HC_CLOSETIME            10
#define HC_CLOSETIMESTAMP       11
#define HC_CLOSEPRICE           12
#define HC_EXPIRATIONTIME       13
#define HC_EXPIRATIONTIMESTAMP  14
#define HC_MAGICNUMBER          15
#define HC_COMMISSION           16
#define HC_SWAP                 17
#define HC_NETPROFIT            18
#define HC_GROSSPROFIT          19
#define HC_NORMALIZEDPROFIT     20
#define HC_BALANCE              21
#define HC_COMMENT              22


// Swap calculation modes, siehe MarketInfo(symbol, MODE_SWAPTYPE)
#define SCM_POINTS               0
#define SCM_BASE_CURRENCY        1
#define SCM_INTEREST             2
#define SCM_MARGIN_CURRENCY      3


// Profit calculation modes, siehe MarketInfo(symbol, MODE_PROFITCALCMODE)
#define PCM_FOREX                0
#define PCM_CFD                  1
#define PCM_FUTURES              2


// Margin calculation modes, siehe MarketInfo(symbol, MODE_MARGINCALCMODE)
#define MCM_FOREX                0
#define MCM_CFD                  1
#define MCM_FUTURES              2
#define MCM_INDICES              3


// Flags zur Objektpositionierung, siehe ObjectSet(label, OBJPROP_CORNER,  int)
#define CORNER_TOP_LEFT          0
#define CORNER_TOP_RIGHT         1
#define CORNER_BOTTOM_LEFT       2
#define CORNER_BOTTOM_RIGHT      3


// weiterer deinit()-Reason, siehe UninitializeReason()
#define REASON_FINISHED          0   // execution finished
#define REASON_REMOVE            1   // expert or indicator removed from chart
#define REASON_RECOMPILE         2   // expert or indicator recompiled
#define REASON_CHARTCHANGE       3   // chart symbol or timeframe changed
#define REASON_CHARTCLOSE        4   // chart closed
#define REASON_PARAMETERS        5   // input parameters changed by user
#define REASON_ACCOUNT           6   // account changed


// MQL-Fehlercodes (Win32-Fehlercodes siehe win32api.mqh)
#define ERR_NO_ERROR                            0

// trade server errors
#define ERR_NO_RESULT                           1
#define ERR_COMMON_ERROR                        2
#define ERR_INVALID_TRADE_PARAMETERS            3
#define ERR_SERVER_BUSY                         4
#define ERR_OLD_VERSION                         5
#define ERR_NO_CONNECTION                       6
#define ERR_NOT_ENOUGH_RIGHTS                   7
#define ERR_TOO_FREQUENT_REQUESTS               8
#define ERR_MALFUNCTIONAL_TRADE                 9
#define ERR_ACCOUNT_DISABLED                   64
#define ERR_INVALID_ACCOUNT                    65
#define ERR_TRADE_TIMEOUT                     128
#define ERR_INVALID_PRICE                     129
#define ERR_INVALID_STOPS                     130
#define ERR_INVALID_TRADE_VOLUME              131
#define ERR_MARKET_CLOSED                     132
#define ERR_TRADE_DISABLED                    133
#define ERR_NOT_ENOUGH_MONEY                  134
#define ERR_PRICE_CHANGED                     135
#define ERR_OFF_QUOTES                        136
#define ERR_BROKER_BUSY                       137
#define ERR_REQUOTE                           138
#define ERR_ORDER_LOCKED                      139
#define ERR_LONG_POSITIONS_ONLY_ALLOWED       140
#define ERR_TOO_MANY_REQUESTS                 141
#define ERR_TRADE_MODIFY_DENIED               145
#define ERR_TRADE_CONTEXT_BUSY                146
#define ERR_TRADE_EXPIRATION_DENIED           147
#define ERR_TRADE_TOO_MANY_ORDERS             148
#define ERR_TRADE_HEDGE_PROHIBITED            149
#define ERR_TRADE_PROHIBITED_BY_FIFO          150

// runtime errors
#define ERR_RUNTIME_ERROR                    4000  // common runtime error (no mql error)
#define ERR_WRONG_FUNCTION_POINTER           4001
#define ERR_ARRAY_INDEX_OUT_OF_RANGE         4002
#define ERR_NO_MEMORY_FOR_CALL_STACK         4003
#define ERR_RECURSIVE_STACK_OVERFLOW         4004
#define ERR_NOT_ENOUGH_STACK_FOR_PARAM       4005
#define ERR_NO_MEMORY_FOR_PARAM_STRING       4006
#define ERR_NO_MEMORY_FOR_TEMP_STRING        4007
#define ERR_NOT_INITIALIZED_STRING           4008
#define ERR_NOT_INITIALIZED_ARRAYSTRING      4009
#define ERR_NO_MEMORY_FOR_ARRAYSTRING        4010
#define ERR_TOO_LONG_STRING                  4011
#define ERR_REMAINDER_FROM_ZERO_DIVIDE       4012
#define ERR_ZERO_DIVIDE                      4013
#define ERR_UNKNOWN_COMMAND                  4014
#define ERR_WRONG_JUMP                       4015
#define ERR_NOT_INITIALIZED_ARRAY            4016
#define ERR_DLL_CALLS_NOT_ALLOWED            4017
#define ERR_CANNOT_LOAD_LIBRARY              4018
#define ERR_CANNOT_CALL_FUNCTION             4019
#define ERR_EXTERNAL_CALLS_NOT_ALLOWED       4020
#define ERR_NO_MEMORY_FOR_RETURNED_STR       4021
#define ERR_SYSTEM_BUSY                      4022
#define ERR_INVALID_FUNCTION_PARAMSCNT       4050  // invalid parameters count
#define ERR_INVALID_FUNCTION_PARAMVALUE      4051  // invalid parameter value
#define ERR_STRING_FUNCTION_INTERNAL         4052
#define ERR_SOME_ARRAY_ERROR                 4053  // some array error
#define ERR_INCORRECT_SERIESARRAY_USING      4054
#define ERR_CUSTOM_INDICATOR_ERROR           4055  // custom indicator error
#define ERR_INCOMPATIBLE_ARRAYS              4056  // incompatible arrays
#define ERR_GLOBAL_VARIABLES_PROCESSING      4057
#define ERR_GLOBAL_VARIABLE_NOT_FOUND        4058
#define ERR_FUNC_NOT_ALLOWED_IN_TESTING      4059
#define ERR_FUNCTION_NOT_CONFIRMED           4060
#define ERR_SEND_MAIL_ERROR                  4061
#define ERR_STRING_PARAMETER_EXPECTED        4062
#define ERR_INTEGER_PARAMETER_EXPECTED       4063
#define ERR_DOUBLE_PARAMETER_EXPECTED        4064
#define ERR_ARRAY_AS_PARAMETER_EXPECTED      4065
#define ERR_HISTORY_WILL_UPDATED             4066  // history in update state
#define ERR_TRADE_ERROR                      4067  // ???
#define ERR_END_OF_FILE                      4099  // end of file
#define ERR_SOME_FILE_ERROR                  4100  // some file error
#define ERR_WRONG_FILE_NAME                  4101
#define ERR_TOO_MANY_OPENED_FILES            4102
#define ERR_CANNOT_OPEN_FILE                 4103
#define ERR_INCOMPATIBLE_FILEACCESS          4104
#define ERR_NO_ORDER_SELECTED                4105
#define ERR_UNKNOWN_SYMBOL                   4106
#define ERR_INVALID_PRICE_PARAM              4107
#define ERR_INVALID_TICKET                   4108
#define ERR_TRADE_NOT_ALLOWED                4109
#define ERR_LONGS_NOT_ALLOWED                4110
#define ERR_SHORTS_NOT_ALLOWED               4111
#define ERR_OBJECT_ALREADY_EXISTS            4200
#define ERR_UNKNOWN_OBJECT_PROPERTY          4201
#define ERR_OBJECT_DOES_NOT_EXIST            4202
#define ERR_UNKNOWN_OBJECT_TYPE              4203
#define ERR_NO_OBJECT_NAME                   4204
#define ERR_OBJECT_COORDINATES_ERROR         4205
#define ERR_NO_SPECIFIED_SUBWINDOW           4206
#define ERR_SOME_OBJECT_ERROR                4207

// custom errors
#define ERR_WINDOWS_ERROR                    5000  // Windows error
#define ERR_FUNCTION_NOT_IMPLEMENTED         5001  // function not implemented
#define ERR_INVALID_INPUT_PARAMVALUE         5002  // invalid input parameter value
#define ERR_TERMINAL_NOT_YET_READY           5003  // terminal not yet ready


// Sommerzeit-Umschaltzeiten für EET/EEST (Sofia) GMT+0200,GMT+0300
datetime EEST_schedule[50][4] = {
   // Umschaltzeiten in EET/EEST                      // Umschaltzeiten in GMT
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   D'1975.04.12 00:00:00', D'1975.11.26 01:00:00',    D'1975.04.11 22:00:00', D'1975.11.25 22:00:00',
   D'1976.04.11 02:00:00', D'1976.10.10 03:00:00',    D'1976.04.11 00:00:00', D'1976.10.10 00:00:00',
   D'1977.04.03 02:00:00', D'1977.09.26 03:00:00',    D'1977.04.03 00:00:00', D'1977.09.26 00:00:00',
   D'1978.04.02 02:00:00', D'1978.09.24 04:00:00',    D'1978.04.02 00:00:00', D'1978.09.24 01:00:00',
   D'1979.04.01 09:00:00', D'1979.09.29 02:00:00',    D'1979.04.01 07:00:00', D'1979.09.28 23:00:00',
   D'1980.04.01 00:00:00', D'1980.09.28 00:00:00',    D'1980.03.31 22:00:00', D'1980.09.27 21:00:00',
   D'1981.03.29 03:00:00', D'1981.09.27 04:00:00',    D'1981.03.29 01:00:00', D'1981.09.27 01:00:00',
   D'1982.03.28 03:00:00', D'1982.09.26 04:00:00',    D'1982.03.28 01:00:00', D'1982.09.26 01:00:00',
   D'1983.03.27 03:00:00', D'1983.09.25 04:00:00',    D'1983.03.27 01:00:00', D'1983.09.25 01:00:00',
   D'1984.03.25 03:00:00', D'1984.09.30 04:00:00',    D'1984.03.25 01:00:00', D'1984.09.30 01:00:00',
   D'1985.03.31 03:00:00', D'1985.09.29 04:00:00',    D'1985.03.31 01:00:00', D'1985.09.29 01:00:00',
   D'1986.03.30 03:00:00', D'1986.09.28 04:00:00',    D'1986.03.30 01:00:00', D'1986.09.28 01:00:00',
   D'1987.03.29 03:00:00', D'1987.09.27 04:00:00',    D'1987.03.29 01:00:00', D'1987.09.27 01:00:00',
   D'1988.03.27 03:00:00', D'1988.09.25 04:00:00',    D'1988.03.27 01:00:00', D'1988.09.25 01:00:00',
   D'1989.03.26 03:00:00', D'1989.09.24 04:00:00',    D'1989.03.26 01:00:00', D'1989.09.24 01:00:00',
   D'1990.03.25 03:00:00', D'1990.09.30 04:00:00',    D'1990.03.25 01:00:00', D'1990.09.30 01:00:00',
   D'1991.03.31 03:00:00', D'1991.09.29 04:00:00',    D'1991.03.31 01:00:00', D'1991.09.29 01:00:00',
   D'1992.03.29 03:00:00', D'1992.09.27 04:00:00',    D'1992.03.29 01:00:00', D'1992.09.27 01:00:00',
   D'1993.03.28 03:00:00', D'1993.09.26 04:00:00',    D'1993.03.28 01:00:00', D'1993.09.26 01:00:00',
   D'1994.03.27 03:00:00', D'1994.09.25 04:00:00',    D'1994.03.27 01:00:00', D'1994.09.25 01:00:00',
   D'1995.03.26 03:00:00', D'1995.09.24 04:00:00',    D'1995.03.26 01:00:00', D'1995.09.24 01:00:00',
   D'1996.03.31 03:00:00', D'1996.10.27 04:00:00',    D'1996.03.31 01:00:00', D'1996.10.27 01:00:00',
   D'1997.03.30 03:00:00', D'1997.10.26 04:00:00',    D'1997.03.30 01:00:00', D'1997.10.26 01:00:00',
   D'1998.03.29 03:00:00', D'1998.10.25 04:00:00',    D'1998.03.29 01:00:00', D'1998.10.25 01:00:00',
   D'1999.03.28 03:00:00', D'1999.10.31 04:00:00',    D'1999.03.28 01:00:00', D'1999.10.31 01:00:00',
   D'2000.03.26 03:00:00', D'2000.10.29 04:00:00',    D'2000.03.26 01:00:00', D'2000.10.29 01:00:00',
   D'2001.03.25 03:00:00', D'2001.10.28 04:00:00',    D'2001.03.25 01:00:00', D'2001.10.28 01:00:00',
   D'2002.03.31 03:00:00', D'2002.10.27 04:00:00',    D'2002.03.31 01:00:00', D'2002.10.27 01:00:00',
   D'2003.03.30 03:00:00', D'2003.10.26 04:00:00',    D'2003.03.30 01:00:00', D'2003.10.26 01:00:00',
   D'2004.03.28 03:00:00', D'2004.10.31 04:00:00',    D'2004.03.28 01:00:00', D'2004.10.31 01:00:00',
   D'2005.03.27 03:00:00', D'2005.10.30 04:00:00',    D'2005.03.27 01:00:00', D'2005.10.30 01:00:00',
   D'2006.03.26 03:00:00', D'2006.10.29 04:00:00',    D'2006.03.26 01:00:00', D'2006.10.29 01:00:00',
   D'2007.03.25 03:00:00', D'2007.10.28 04:00:00',    D'2007.03.25 01:00:00', D'2007.10.28 01:00:00',
   D'2008.03.30 03:00:00', D'2008.10.26 04:00:00',    D'2008.03.30 01:00:00', D'2008.10.26 01:00:00',
   D'2009.03.29 03:00:00', D'2009.10.25 04:00:00',    D'2009.03.29 01:00:00', D'2009.10.25 01:00:00',
   D'2010.03.28 03:00:00', D'2010.10.31 04:00:00',    D'2010.03.28 01:00:00', D'2010.10.31 01:00:00',
   D'2011.03.27 03:00:00', D'2011.10.30 04:00:00',    D'2011.03.27 01:00:00', D'2011.10.30 01:00:00',
   D'2012.03.25 03:00:00', D'2012.10.28 04:00:00',    D'2012.03.25 01:00:00', D'2012.10.28 01:00:00',
   D'2013.03.31 03:00:00', D'2013.10.27 04:00:00',    D'2013.03.31 01:00:00', D'2013.10.27 01:00:00',
   D'2014.03.30 03:00:00', D'2014.10.26 04:00:00',    D'2014.03.30 01:00:00', D'2014.10.26 01:00:00',
   D'2015.03.29 03:00:00', D'2015.10.25 04:00:00',    D'2015.03.29 01:00:00', D'2015.10.25 01:00:00',
   D'2016.03.27 03:00:00', D'2016.10.30 04:00:00',    D'2016.03.27 01:00:00', D'2016.10.30 01:00:00',
   D'2017.03.26 03:00:00', D'2017.10.29 04:00:00',    D'2017.03.26 01:00:00', D'2017.10.29 01:00:00',
   D'2018.03.25 03:00:00', D'2018.10.28 04:00:00',    D'2018.03.25 01:00:00', D'2018.10.28 01:00:00',
   D'2019.03.31 03:00:00', D'2019.10.27 04:00:00',    D'2019.03.31 01:00:00', D'2019.10.27 01:00:00',
};


// Sommerzeit-Umschaltzeiten für CET/CEST (Berlin) GMT+0100,GMT+0200
datetime CEST_schedule[50][4] = {
   // Umschaltzeiten in CET/CEST                      // Umschaltzeiten in GMT
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   -1,                     -1,                        -1,                     -1,
   D'1980.04.06 02:00:00', D'1980.09.28 03:00:00',    D'1980.04.06 01:00:00', D'1980.09.28 01:00:00',
   D'1981.03.29 02:00:00', D'1981.09.27 03:00:00',    D'1981.03.29 01:00:00', D'1981.09.27 01:00:00',
   D'1982.03.28 02:00:00', D'1982.09.26 03:00:00',    D'1982.03.28 01:00:00', D'1982.09.26 01:00:00',
   D'1983.03.27 02:00:00', D'1983.09.25 03:00:00',    D'1983.03.27 01:00:00', D'1983.09.25 01:00:00',
   D'1984.03.25 02:00:00', D'1984.09.30 03:00:00',    D'1984.03.25 01:00:00', D'1984.09.30 01:00:00',
   D'1985.03.31 02:00:00', D'1985.09.29 03:00:00',    D'1985.03.31 01:00:00', D'1985.09.29 01:00:00',
   D'1986.03.30 02:00:00', D'1986.09.28 03:00:00',    D'1986.03.30 01:00:00', D'1986.09.28 01:00:00',
   D'1987.03.29 02:00:00', D'1987.09.27 03:00:00',    D'1987.03.29 01:00:00', D'1987.09.27 01:00:00',
   D'1988.03.27 02:00:00', D'1988.09.25 03:00:00',    D'1988.03.27 01:00:00', D'1988.09.25 01:00:00',
   D'1989.03.26 02:00:00', D'1989.09.24 03:00:00',    D'1989.03.26 01:00:00', D'1989.09.24 01:00:00',
   D'1990.03.25 02:00:00', D'1990.09.30 03:00:00',    D'1990.03.25 01:00:00', D'1990.09.30 01:00:00',
   D'1991.03.31 02:00:00', D'1991.09.29 03:00:00',    D'1991.03.31 01:00:00', D'1991.09.29 01:00:00',
   D'1992.03.29 02:00:00', D'1992.09.27 03:00:00',    D'1992.03.29 01:00:00', D'1992.09.27 01:00:00',
   D'1993.03.28 02:00:00', D'1993.09.26 03:00:00',    D'1993.03.28 01:00:00', D'1993.09.26 01:00:00',
   D'1994.03.27 02:00:00', D'1994.09.25 03:00:00',    D'1994.03.27 01:00:00', D'1994.09.25 01:00:00',
   D'1995.03.26 02:00:00', D'1995.09.24 03:00:00',    D'1995.03.26 01:00:00', D'1995.09.24 01:00:00',
   D'1996.03.31 02:00:00', D'1996.10.27 03:00:00',    D'1996.03.31 01:00:00', D'1996.10.27 01:00:00',
   D'1997.03.30 02:00:00', D'1997.10.26 03:00:00',    D'1997.03.30 01:00:00', D'1997.10.26 01:00:00',
   D'1998.03.29 02:00:00', D'1998.10.25 03:00:00',    D'1998.03.29 01:00:00', D'1998.10.25 01:00:00',
   D'1999.03.28 02:00:00', D'1999.10.31 03:00:00',    D'1999.03.28 01:00:00', D'1999.10.31 01:00:00',
   D'2000.03.26 02:00:00', D'2000.10.29 03:00:00',    D'2000.03.26 01:00:00', D'2000.10.29 01:00:00',
   D'2001.03.25 02:00:00', D'2001.10.28 03:00:00',    D'2001.03.25 01:00:00', D'2001.10.28 01:00:00',
   D'2002.03.31 02:00:00', D'2002.10.27 03:00:00',    D'2002.03.31 01:00:00', D'2002.10.27 01:00:00',
   D'2003.03.30 02:00:00', D'2003.10.26 03:00:00',    D'2003.03.30 01:00:00', D'2003.10.26 01:00:00',
   D'2004.03.28 02:00:00', D'2004.10.31 03:00:00',    D'2004.03.28 01:00:00', D'2004.10.31 01:00:00',
   D'2005.03.27 02:00:00', D'2005.10.30 03:00:00',    D'2005.03.27 01:00:00', D'2005.10.30 01:00:00',
   D'2006.03.26 02:00:00', D'2006.10.29 03:00:00',    D'2006.03.26 01:00:00', D'2006.10.29 01:00:00',
   D'2007.03.25 02:00:00', D'2007.10.28 03:00:00',    D'2007.03.25 01:00:00', D'2007.10.28 01:00:00',
   D'2008.03.30 02:00:00', D'2008.10.26 03:00:00',    D'2008.03.30 01:00:00', D'2008.10.26 01:00:00',
   D'2009.03.29 02:00:00', D'2009.10.25 03:00:00',    D'2009.03.29 01:00:00', D'2009.10.25 01:00:00',
   D'2010.03.28 02:00:00', D'2010.10.31 03:00:00',    D'2010.03.28 01:00:00', D'2010.10.31 01:00:00',
   D'2011.03.27 02:00:00', D'2011.10.30 03:00:00',    D'2011.03.27 01:00:00', D'2011.10.30 01:00:00',
   D'2012.03.25 02:00:00', D'2012.10.28 03:00:00',    D'2012.03.25 01:00:00', D'2012.10.28 01:00:00',
   D'2013.03.31 02:00:00', D'2013.10.27 03:00:00',    D'2013.03.31 01:00:00', D'2013.10.27 01:00:00',
   D'2014.03.30 02:00:00', D'2014.10.26 03:00:00',    D'2014.03.30 01:00:00', D'2014.10.26 01:00:00',
   D'2015.03.29 02:00:00', D'2015.10.25 03:00:00',    D'2015.03.29 01:00:00', D'2015.10.25 01:00:00',
   D'2016.03.27 02:00:00', D'2016.10.30 03:00:00',    D'2016.03.27 01:00:00', D'2016.10.30 01:00:00',
   D'2017.03.26 02:00:00', D'2017.10.29 03:00:00',    D'2017.03.26 01:00:00', D'2017.10.29 01:00:00',
   D'2018.03.25 02:00:00', D'2018.10.28 03:00:00',    D'2018.03.25 01:00:00', D'2018.10.28 01:00:00',
   D'2019.03.31 02:00:00', D'2019.10.27 03:00:00',    D'2019.03.31 01:00:00', D'2019.10.27 01:00:00',
};


// Sommerzeit-Umschaltzeiten für EST/EDT (New York) GMT-0500,GMT-0400
datetime EDT_schedule[50][4] = {
   // Umschaltzeiten in EST/EDT                       // Umschaltzeiten in GMT
   D'1970.04.26 02:00:00', D'1970.10.25 02:00:00',    D'1970.04.26 07:00:00', D'1970.10.25 06:00:00',
   D'1971.04.25 02:00:00', D'1971.10.31 02:00:00',    D'1971.04.25 07:00:00', D'1971.10.31 06:00:00',
   D'1972.04.30 02:00:00', D'1972.10.29 02:00:00',    D'1972.04.30 07:00:00', D'1972.10.29 06:00:00',
   D'1973.04.29 02:00:00', D'1973.10.28 02:00:00',    D'1973.04.29 07:00:00', D'1973.10.28 06:00:00',
   D'1974.01.06 02:00:00', D'1974.10.27 02:00:00',    D'1974.01.06 07:00:00', D'1974.10.27 06:00:00',
   D'1975.02.23 02:00:00', D'1975.10.26 02:00:00',    D'1975.02.23 07:00:00', D'1975.10.26 06:00:00',
   D'1976.04.25 02:00:00', D'1976.10.31 02:00:00',    D'1976.04.25 07:00:00', D'1976.10.31 06:00:00',
   D'1977.04.24 02:00:00', D'1977.10.30 02:00:00',    D'1977.04.24 07:00:00', D'1977.10.30 06:00:00',
   D'1978.04.30 02:00:00', D'1978.10.29 02:00:00',    D'1978.04.30 07:00:00', D'1978.10.29 06:00:00',
   D'1979.04.29 02:00:00', D'1979.10.28 02:00:00',    D'1979.04.29 07:00:00', D'1979.10.28 06:00:00',
   D'1980.04.27 02:00:00', D'1980.10.26 02:00:00',    D'1980.04.27 07:00:00', D'1980.10.26 06:00:00',
   D'1981.04.26 02:00:00', D'1981.10.25 02:00:00',    D'1981.04.26 07:00:00', D'1981.10.25 06:00:00',
   D'1982.04.25 02:00:00', D'1982.10.31 02:00:00',    D'1982.04.25 07:00:00', D'1982.10.31 06:00:00',
   D'1983.04.24 02:00:00', D'1983.10.30 02:00:00',    D'1983.04.24 07:00:00', D'1983.10.30 06:00:00',
   D'1984.04.29 02:00:00', D'1984.10.28 02:00:00',    D'1984.04.29 07:00:00', D'1984.10.28 06:00:00',
   D'1985.04.28 02:00:00', D'1985.10.27 02:00:00',    D'1985.04.28 07:00:00', D'1985.10.27 06:00:00',
   D'1986.04.27 02:00:00', D'1986.10.26 02:00:00',    D'1986.04.27 07:00:00', D'1986.10.26 06:00:00',
   D'1987.04.05 02:00:00', D'1987.10.25 02:00:00',    D'1987.04.05 07:00:00', D'1987.10.25 06:00:00',
   D'1988.04.03 02:00:00', D'1988.10.30 02:00:00',    D'1988.04.03 07:00:00', D'1988.10.30 06:00:00',
   D'1989.04.02 02:00:00', D'1989.10.29 02:00:00',    D'1989.04.02 07:00:00', D'1989.10.29 06:00:00',
   D'1990.04.01 02:00:00', D'1990.10.28 02:00:00',    D'1990.04.01 07:00:00', D'1990.10.28 06:00:00',
   D'1991.04.07 02:00:00', D'1991.10.27 02:00:00',    D'1991.04.07 07:00:00', D'1991.10.27 06:00:00',
   D'1992.04.05 02:00:00', D'1992.10.25 02:00:00',    D'1992.04.05 07:00:00', D'1992.10.25 06:00:00',
   D'1993.04.04 02:00:00', D'1993.10.31 02:00:00',    D'1993.04.04 07:00:00', D'1993.10.31 06:00:00',
   D'1994.04.03 02:00:00', D'1994.10.30 02:00:00',    D'1994.04.03 07:00:00', D'1994.10.30 06:00:00',
   D'1995.04.02 02:00:00', D'1995.10.29 02:00:00',    D'1995.04.02 07:00:00', D'1995.10.29 06:00:00',
   D'1996.04.07 02:00:00', D'1996.10.27 02:00:00',    D'1996.04.07 07:00:00', D'1996.10.27 06:00:00',
   D'1997.04.06 02:00:00', D'1997.10.26 02:00:00',    D'1997.04.06 07:00:00', D'1997.10.26 06:00:00',
   D'1998.04.05 02:00:00', D'1998.10.25 02:00:00',    D'1998.04.05 07:00:00', D'1998.10.25 06:00:00',
   D'1999.04.04 02:00:00', D'1999.10.31 02:00:00',    D'1999.04.04 07:00:00', D'1999.10.31 06:00:00',
   D'2000.04.02 02:00:00', D'2000.10.29 02:00:00',    D'2000.04.02 07:00:00', D'2000.10.29 06:00:00',
   D'2001.04.01 02:00:00', D'2001.10.28 02:00:00',    D'2001.04.01 07:00:00', D'2001.10.28 06:00:00',
   D'2002.04.07 02:00:00', D'2002.10.27 02:00:00',    D'2002.04.07 07:00:00', D'2002.10.27 06:00:00',
   D'2003.04.06 02:00:00', D'2003.10.26 02:00:00',    D'2003.04.06 07:00:00', D'2003.10.26 06:00:00',
   D'2004.04.04 02:00:00', D'2004.10.31 02:00:00',    D'2004.04.04 07:00:00', D'2004.10.31 06:00:00',
   D'2005.04.03 02:00:00', D'2005.10.30 02:00:00',    D'2005.04.03 07:00:00', D'2005.10.30 06:00:00',
   D'2006.04.02 02:00:00', D'2006.10.29 02:00:00',    D'2006.04.02 07:00:00', D'2006.10.29 06:00:00',
   D'2007.03.11 02:00:00', D'2007.11.04 02:00:00',    D'2007.03.11 07:00:00', D'2007.11.04 06:00:00',
   D'2008.03.09 02:00:00', D'2008.11.02 02:00:00',    D'2008.03.09 07:00:00', D'2008.11.02 06:00:00',
   D'2009.03.08 02:00:00', D'2009.11.01 02:00:00',    D'2009.03.08 07:00:00', D'2009.11.01 06:00:00',
   D'2010.03.14 02:00:00', D'2010.11.07 02:00:00',    D'2010.03.14 07:00:00', D'2010.11.07 06:00:00',
   D'2011.03.13 02:00:00', D'2011.11.06 02:00:00',    D'2011.03.13 07:00:00', D'2011.11.06 06:00:00',
   D'2012.03.11 02:00:00', D'2012.11.04 02:00:00',    D'2012.03.11 07:00:00', D'2012.11.04 06:00:00',
   D'2013.03.10 02:00:00', D'2013.11.03 02:00:00',    D'2013.03.10 07:00:00', D'2013.11.03 06:00:00',
   D'2014.03.09 02:00:00', D'2014.11.02 02:00:00',    D'2014.03.09 07:00:00', D'2014.11.02 06:00:00',
   D'2015.03.08 02:00:00', D'2015.11.01 02:00:00',    D'2015.03.08 07:00:00', D'2015.11.01 06:00:00',
   D'2016.03.13 02:00:00', D'2016.11.06 02:00:00',    D'2016.03.13 07:00:00', D'2016.11.06 06:00:00',
   D'2017.03.12 02:00:00', D'2017.11.05 02:00:00',    D'2017.03.12 07:00:00', D'2017.11.05 06:00:00',
   D'2018.03.11 02:00:00', D'2018.11.04 02:00:00',    D'2018.03.11 07:00:00', D'2018.11.04 06:00:00',
   D'2019.03.10 02:00:00', D'2019.11.03 02:00:00',    D'2019.03.10 07:00:00', D'2019.11.03 06:00:00',
};


/**
 * Prüft, ob ein Fehler aufgetreten ist und zeigt diesen optisch und akustisch an. Nach Rückkehr ist der letzte Error-Code
 * immer zurückgesetzt.
 *
 * @param string message - zusätzlich anzuzeigende Nachricht (z.B. Ort des Aufrufs)
 * @param int    error   - manuelles Forcieren eines bestimmten Error-Codes
 *
 * @return int - der aufgetretene Error-Code
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei definiert, weil (a) Libraries keine Default-Parameter unterstützen und damit
 * (b) im Log möglichst das laufende Script als Auslöser angezeigt wird.
 */
int catch(string message="", int error=ERR_NO_ERROR) {
   if (error != ERR_NO_ERROR)
      GetLastError();                     // bei forciertem Fehler letzten tatsächlichen Fehler zurücksetzen
   else
      error = GetLastError();

   if (error != ERR_NO_ERROR) {
      if (message == "")
         message = "?";
      Alert(StringConcatenate("ERROR: ", message, "   [", error, " - ", GetErrorDescription(error), "]"));
   }

   return(error);

   // unreachable Code, unterdrückt Compilerwarnungen über unreferenzierte Funktionen
   HandleEvent(0);
   HandleEvents(0);
}


/**
 * Prüft, ob ein einzelnes Event aufgetreten ist und ruft ggf. dessen Eventhandler auf.
 * Im Gegensatz zu HandleEvents() ermöglicht die Verwendung dieser Funktion die Angabe weiterer eventspezifischer Prüfungsflags.
 *
 * @param int event - Eventbezeichner
 * @param int flags - zusätzliche Flags (default: 0)
 *
 * @return bool - ob das Event aufgetreten ist oder nicht
 *
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei definiert, damit lokale Implementierungen der Eventhandler zuerst gefunden werden.
 */
int HandleEvent(int event, int flags=0) {
   bool status = false;
   int  results[];      // zurücksetzen nicht notwendig, da EventListener() immer zurücksetzt

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
         catch("HandleEvent()   unknown event: "+ event, ERR_INVALID_FUNCTION_PARAMVALUE);
   }

   catch("HandleEvent()");
   return(status);
}


/**
 * Prüft, ob Events der angegebenen Typen aufgetreten sind und ruft ggf. deren Eventhandler auf.
 *
 * @param int events - ein oder mehrere durch logisches ODER verknüpfte Eventbezeichner
 *
 * @return bool - ob mindestens eines der angegebenen Events aufgetreten ist
 *
 *
 * NOTE:
 * -----
 * Ist in der Headerdatei definiert, damit lokale Implementierungen der Eventhandler zuerst gefunden werden.
 */
int HandleEvents(int events) {
   int status = 0;

   if (events & EVENT_BAR_OPEN        != 0) status |= HandleEvent(EVENT_BAR_OPEN);
   if (events & EVENT_ORDER_PLACE     != 0) status |= HandleEvent(EVENT_ORDER_PLACE);
   if (events & EVENT_ORDER_CHANGE    != 0) status |= HandleEvent(EVENT_ORDER_CHANGE);
   if (events & EVENT_ORDER_CANCEL    != 0) status |= HandleEvent(EVENT_ORDER_CANCEL);
   if (events & EVENT_POSITION_OPEN   != 0) status |= HandleEvent(EVENT_POSITION_OPEN);
   if (events & EVENT_POSITION_CLOSE  != 0) status |= HandleEvent(EVENT_POSITION_CLOSE);
   if (events & EVENT_ACCOUNT_CHANGE  != 0) status |= HandleEvent(EVENT_ACCOUNT_CHANGE);
   if (events & EVENT_ACCOUNT_PAYMENT != 0) status |= HandleEvent(EVENT_ACCOUNT_PAYMENT);
   if (events & EVENT_HISTORY_CHANGE  != 0) status |= HandleEvent(EVENT_HISTORY_CHANGE);

   catch("HandleEvents()");
   return(status != 0);
}

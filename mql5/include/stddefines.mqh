/**
 * Custom constants, macros and global variables.
 *
 * Unlike MQL4, the redefinition of constants (even with the same value) in MQL5 is not allowed.
 */
#include <shared.mqh>
#include <win32defines.mqh>


// global variables
int last_error;                     // last error of the current start() call
int prev_error;                     // last error of the previous start() call


// special constants
#define NULL                        0
#define EMPTY_STR                   ""
#define MAX_STRING_LITERAL          "..............................................................................................................................................................................................................................................................."

#define HTML_TAB                    "&Tab;"                       // tab                                 \t
#define HTML_BRVBAR                 "&brvbar;"                    // broken vertical bar                 |
#define HTML_PIPE                   "&brvbar;"                    // pipe (alias of HTML_BRVBAR)         |        MQL4 bug: string constants cannot reference each other
#define HTML_LCUB                   "&lcub;"                      // left curly brace                    {
#define HTML_RCUB                   "&rcub;"                      // right curly brace                   }
#define HTML_APOS                   "&apos;"                      // apostrophe                          '
#define HTML_SQUOTE                 "&apos;"                      // single quote (alias of HTML_APOS)   '        MQL4 bug: string constants cannot reference each other
#define HTML_DQUOTE                 "&quot;"                      // double quote                        "
#define HTML_COMMA                  "&comma;"                     // comma                               ,


// special double values, defined in init(), string representation depends on the VisualStudio version used for building "terminal.exe"
double  NaN;                                                      // -1.#IND | -nan(ind): indefinite quiet Not-a-Number (on x86 CPUs always negative)
double  INF;                                                      //  1.#INF |  inf:      positive infinity
//     -INF                                                       // -1.#INF | -inf:      negative infinity, @see  http://blogs.msdn.com/b/oldnewthing/archive/2013/02/21/10395734.aspx

// magic characters to represent non-printable chars in binry strings, @see BufferToStr()
#define PLACEHOLDER_NUL_CHAR        '…'                           // 0x85 (133) - replacement for NUL chars in strings
#define PLACEHOLDER_CTRL_CHAR       '•'                           // 0x95 (149) - replacement for Control chars in strings


// mathematical constants (internally 15 correct digits)
#define M_E                         2.71828182845904523536        // base of natural logarythm
#define M_PI                        3.14159265358979323846


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
#define LT_USER                     LAUNCHTYPE_USER               // by user


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
#define TIME_FULL                   (TIME_DATE | TIME_MINUTES | TIME_SECONDS)


// DateTime2() flags
#define DATE_OF_ERA                 1           // relative to the era (1970-01-01)
#define DATE_OF_TODAY               2           // relative to today


// ParseDateTime() flags
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


// ParseDateTime() result indexes
#define PT_YEAR                     0
#define PT_MONTH                    1
#define PT_DAY                      2
#define PT_HAS_DATE                 3
#define PT_HOUR                     4
#define PT_MINUTE                   5
#define PT_SECOND                   6
#define PT_HAS_TIME                 7
#define PT_ERROR                    8           // string*


// array indexes of timezone transitions
#define TRANSITION_TIME             0
#define TRANSITION_OFFSET           1
#define TRANSITION_DST              2


// object property ids, @see ObjectSet()
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


// modes to specify the pool to select an order from; see OrderSelect()
#define MODE_TRADES            0
#define MODE_HISTORY           1


// flags to control order selection; see SelectTicket()
#define O_SAVE_CURRENT         1                // TRUE (MQL4 doesn't support constant booleans)
#define O_RESTORE              1                // TRUE


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
#define MODE_SMMA                         2     // smoothed exponential moving average: SMMA(n) = EMA(2*n-1)
#define MODE_LWMA                         3     // linear weighted moving average
#define MODE_ALMA                         4     // Arnaud Legoux moving average


// indicator drawing shapes
#define DRAW_LINE                         0     // drawing line
#define DRAW_SECTION                      1     // drawing sections
#define DRAW_HISTOGRAM                    2     // drawing histogram
#define DRAW_ARROW                        3     // drawing arrows (symbols)
#define DRAW_ZIGZAG                       4     // drawing sections between even and odd indicator buffers
#define DRAW_NONE                        12     // no drawing


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
#ifndef MODE_MAIN
#define MODE_MAIN                         0     // base indicator line
#endif
#define MODE_PLUSDI                       1     // +DI indicator line
#define MODE_MINUSDI                      2     // -DI indicator line


// indicator line identifiers, see iBands(), iEnvelopes(), iEnvelopesOnArray(), iFractals(), iGator()
#define MODE_UPPER                        1     // upper line
#define MODE_LOWER                        2     // lower line

#define B_LOWER                           0     // custom
#define B_UPPER                           1     // custom


// --- snip -----------------------------------------------------------------------------------------------------------------
// ...

/**
 * Custom constants shared between MQL and C++
 */

// Special constants
#define EMPTY                    0xFFFFFFFF              // -1
#define CLR_NONE                 0xFFFFFFFF              // no color in contrast to White = 0x00FFFFFF
#define EMPTY_COLOR              0xFFFFFFFE              // invalid color (-2)
#define MAX_SYMBOL_LENGTH                11
#define MAX_ORDER_COMMENT_LENGTH         27
#define MIN_VALID_POINTER        0x00010000              // minimum value of a valid 32 bit pointer (x86)


// Log level
#define L_OFF                    0x80000000              // explizit, da INT_MIN in C++ intern definiert ist, in MQL jedoch nicht
#define L_FATAL                       10000              //
#define L_ERROR                       20000              // Tests umgekehrt zu log4j mit: if (__LOG_LEVEL >= msg_level) log  (...);
#define L_WARN                        30000              // oder einfacher:               if (__LOG_DEBUG)              debug(...);
#define L_INFO                        40000              //
#define L_NOTICE                      50000              //
#define L_DEBUG                       60000              //
#define L_ALL                    0x7FFFFFFF              // explizit, da INT_MAX in C++ intern definiert ist, in MQL jedoch nicht


// Moduletyp-Flags
#define MODULETYPE_INDICATOR              1
#define MODULETYPE_EXPERT                 2
#define MODULETYPE_SCRIPT                 4
#define MODULETYPE_LIBRARY                8              // no independent program


// MQL program types
#define PROGRAMTYPE_INDICATOR             MODULETYPE_INDICATOR
#define PROGRAMTYPE_EXPERT                MODULETYPE_EXPERT
#define PROGRAMTYPE_SCRIPT                MODULETYPE_SCRIPT


// MQL root function ids
#define ROOTFUNCTION_INIT                 1
#define ROOTFUNCTION_START                2
#define ROOTFUNCTION_DEINIT               3


// MQL program launch types
#define LAUNCHTYPE_TEMPLATE               1              // loaded by applying a template
#define LAUNCHTYPE_PROGRAM                2              // loaded by iCustom()
#define LAUNCHTYPE_MANUAL                 3              // loaded manually

                                                         // +--------------------------------------+----------------------------------+
                                                         // | builds <= 509                        | builds > 509                     |
// MetaQuotes UninitializeReason() return values         // +--------------------------------------+----------------------------------+
#define REASON_UNDEFINED                  0              // | no reason                            | -                                |
#define REASON_PROGRAM     REASON_UNDEFINED              // | -                                    | expert removed by ExpertRemove() |
                                                         // +--------------------------------------+----------------------------------+
#define REASON_REMOVE                     1              // | program removed from chart                                              |
#define REASON_RECOMPILE                  2              // | program recompiled                                                      |
#define REASON_CHARTCHANGE                3              // | chart symbol or timeframe changed                                       |
                                                         // +--------------------------------------+----------------------------------+
#define REASON_CHARTCLOSE                 4              // | chart closed or new template applied | chart closed                     |
                                                         // +--------------------------------------+----------------------------------+
#define REASON_PARAMETERS                 5              // | input parameters changed                                                |
#define REASON_ACCOUNT                    6              // | reconnection due to changed account settings                            |
                                                         // +--------------------------------------+----------------------------------+
#define REASON_TEMPLATE                   7              // | -                                    | new template applied             |
#define REASON_INITFAILED                 8              // | -                                    | OnInit() returned an error       |
#define REASON_CLOSE                      9              // | -                                    | terminal closed                  |
                                                         // +--------------------------------------+----------------------------------+

// custom InitializeReason codes (atm indicators only)
#define INITREASON_USER                   1              // bei Laden durch den User                               -      Input-Dialog
#define INITREASON_TEMPLATE               2              // bei Laden durch ein Template (auch bei Terminal-Start) - kein Input-Dialog
#define INITREASON_PROGRAM                3              // bei Laden durch iCustom()                              - kein Input-Dialog
#define INITREASON_PROGRAM_AFTERTEST      4              // bei Laden durch iCustom() nach Testende                - kein Input-Dialog
#define INITREASON_PARAMETERS             5              // nach Änderung der Indikatorparameter                   -      Input-Dialog
#define INITREASON_TIMEFRAMECHANGE        6              // nach Timeframewechsel des Charts                       - kein Input-Dialog
#define INITREASON_SYMBOLCHANGE           7              // nach Symbolwechsel des Charts                          - kein Input-Dialog
#define INITREASON_RECOMPILE              8              // bei Reload nach Recompilation                          - kein Input-Dialog


// custom UninitializeReason codes (match REASON_* codes)
#define UNINITREASON_UNDEFINED            0
#define UNINITREASON_REMOVE               1
#define UNINITREASON_RECOMPILE            2
#define UNINITREASON_CHARTCHANGE          3
#define UNINITREASON_CHARTCLOSE           4
#define UNINITREASON_PARAMETERS           5
#define UNINITREASON_ACCOUNT              6
#define UNINITREASON_TEMPLATE             7
#define UNINITREASON_INITFAILED           8
#define UNINITREASON_CLOSE                9


// Timeframe-Identifier
#define PERIOD_M1                         1              // 1 Minute
#define PERIOD_M5                         5              // 5 Minuten
#define PERIOD_M15                       15              // 15 Minuten
#define PERIOD_M30                       30              // 30 Minuten
#define PERIOD_H1                        60              // 1 Stunde
#define PERIOD_H4                       240              // 4 Stunden
#define PERIOD_D1                      1440              // 1 Tag
#define PERIOD_W1                     10080              // 1 Woche (7 Tage)
#define PERIOD_MN1                    43200              // 1 Monat (30 Tage)
#define PERIOD_Q1                    129600              // 1 Quartal (3 Monate)


// Order- und Operation-Types
#define OP_UNDEFINED                     -1              // custom: Default-Wert für nicht initialisierte Variable
#define OP_BUY                            0              // long position
#define OP_LONG                      OP_BUY
#define OP_SELL                           1              // short position
#define OP_SHORT                    OP_SELL
#define OP_BUYLIMIT                       2              // buy limit order
#define OP_SELLLIMIT                      3              // sell limit order
#define OP_BUYSTOP                        4              // stop buy order
#define OP_SELLSTOP                       5              // stop sell order
#define OP_BALANCE                        6              // account debit or credit transaction
#define OP_CREDIT                         7              // margin credit facility (no transaction)


// trade directions, can be used as flags
#define TRADE_DIRECTIONS_LONG             1
#define TRADE_DIRECTIONS_SHORT            2
#define TRADE_DIRECTIONS_BOTH             3


// Zeitkonstanten
#define SECOND                            1
#define MINUTE                           60              //  60 Sekunden
#define HOUR                           3600              //  60 Minuten
#define DAY                           86400              //  24 Stunden
#define WEEK                         604800              //   7 Tage
#define MONTH                       2678400              //  31 Tage                   // Die Werte sind auf das jeweilige Maximum ausgelegt, sodaß
#define QUARTER                     8035200              //   3 Monate (3 x 31 Tage)   // bei Datumsarithmetik immer ein Wechsel in die jeweils nächste
#define YEAR                       31622400              // 366 Tage                   // Periode garantiert ist.

#define SECONDS                      SECOND
#define MINUTES                      MINUTE
#define HOURS                          HOUR
#define DAYS                            DAY
#define WEEKS                          WEEK
#define MONTHS                        MONTH
#define QUARTERS                    QUARTER
#define YEARS                          YEAR


// auf Sonntag=0 basierende Wochentagskonstanten und ihre Abkürzungen (wie von DayOfWeek() und TimeDayOfWeek() zurückgegeben)
#define SUNDAY                            0
#define MONDAY                            1
#define TUESDAY                           2
#define WEDNESDAY                         3
#define THURSDAY                          4
#define FRIDAY                            5
#define SATURDAY                          6

#define SUN                          SUNDAY
#define MON                          MONDAY
#define TUE                         TUESDAY
#define WED                       WEDNESDAY
#define THU                        THURSDAY
#define FRI                          FRIDAY
#define SAT                        SATURDAY


// auf Januar=0 basierende Monatskonstanten und ihre Abkürzungen
#define zJANUARY                          0
#define zFEBRUARY                         1
#define zMARCH                            2
#define zAPRIL                            3
#define zMAY                              4
#define zJUNE                             5
#define zJULY                             6
#define zAUGUST                           7
#define zSEPTEMBER                        8
#define zOCTOBER                          9
#define zNOVEMBER                        10
#define zDECEMBER                        11

#define zJAN                       zJANUARY
#define zFEB                      zFEBRUARY
#define zMAR                         zMARCH
#define zAPR                         zAPRIL
//efine zMAY                           zMAY
#define zJUN                          zJUNE
#define zJUL                          zJULY
#define zAUG                        zAUGUST
#define zSEP                     zSEPTEMBER
#define zOCT                       zOCTOBER
#define zNOV                      zNOVEMBER
#define zDEC                      zDECEMBER


// auf Januar=1 basierende Monatskonstanten und ihre Abkürzungen (wie von Month() und TimeMonth() zurückgegeben)
#define JANUARY                           1
#define FEBRUARY                          2
#define MARCH                             3
#define APRIL                             4
#define MAY                               5
#define JUNE                              6
#define JULY                              7
#define AUGUST                            8
#define SEPTEMBER                         9
#define OCTOBER                          10
#define NOVEMBER                         11
#define DECEMBER                         12

#define JAN                         JANUARY
#define FEB                        FEBRUARY
#define MAR                           MARCH
#define APR                           APRIL
//efine MAY                             MAY
#define JUN                            JUNE
#define JUL                            JULY
#define AUG                          AUGUST
#define SEP                       SEPTEMBER
#define OCT                         OCTOBER
#define NOV                        NOVEMBER
#define DEC                        DECEMBER


// init()-Flags
#define INIT_TIMEZONE                     1                    // stellt eine korrekte Timezone-Konfiguration sicher
#define INIT_PIPVALUE                     2                    // stellt sicher, daß der aktuelle PipValue berechnet werden kann (benötigt TickSize und TickValue)
#define INIT_BARS_ON_HIST_UPDATE          4                    //
#define INIT_CUSTOMLOG                    8                    // das Programm verwendet ein eigenes Logfile
#define INIT_NO_BARS_REQUIRED            16                    // Script, das auch ohne vorhandene Bars der jeweiligen Zeitreihe ausgeführt werden kann


// Timezones
#define TIMEZONE_ALPARI                   "Alpari"             // bis 03/2012 "Europe/Berlin", ab 04/2012 "Europe/Kiev"
#define TIMEZONE_AMERICA_NEW_YORK         "America/New_York"
#define TIMEZONE_EUROPE_BERLIN            "Europe/Berlin"
#define TIMEZONE_EUROPE_KIEV              "Europe/Kiev"
#define TIMEZONE_EUROPE_LONDON            "Europe/London"
#define TIMEZONE_EUROPE_MINSK             "Europe/Minsk"
#define TIMEZONE_FXT                      "FXT"                // "Europe/Kiev"   mit DST-Wechseln von "America/New_York"
#define TIMEZONE_FXT_MINUS_0200           "FXT-0200"           // "Europe/London" mit DST-Wechseln von "America/New_York"
#define TIMEZONE_GLOBALPRIME              "GlobalPrime"        // bis 24.10.2015 "FXT", dann durch Fehler "Europe/Kiev" (einmalig?)
#define TIMEZONE_GMT                      "GMT"


// Timezone-IDs
#define TIMEZONE_ID_ALPARI                1
#define TIMEZONE_ID_AMERICA_NEW_YORK      2
#define TIMEZONE_ID_EUROPE_BERLIN         3
#define TIMEZONE_ID_EUROPE_KIEV           4
#define TIMEZONE_ID_EUROPE_LONDON         5
#define TIMEZONE_ID_EUROPE_MINSK          6
#define TIMEZONE_ID_FXT                   7
#define TIMEZONE_ID_FXT_MINUS_0200        8
#define TIMEZONE_ID_GLOBALPRIME           9
#define TIMEZONE_ID_GMT                  10


// MT4 internal messages
#define MT4_TICK                          2                    // künstlicher Tick: Ausführung von start()

#define MT4_LOAD_STANDARD_INDICATOR      13
#define MT4_LOAD_CUSTOM_INDICATOR        15
#define MT4_LOAD_EXPERT                  14
#define MT4_LOAD_SCRIPT                  16

#define MT4_OPEN_CHART                   51

#define MT4_COMPILE_REQUEST           12345
#define MT4_COMPILE_PERMISSION        12346
#define MT4_MQL_REFRESH               12349                    // Rescan und Reload modifizierter .ex4-Files


// Konfiguration-Flags für synthetische Ticks
#define TICK_OFFLINE_EA                   1                    // Default-Tick, Expert::start() wird in Offline-Charts getriggert (bei bestehender Server-Connection)
#define TICK_CHART_REFRESH                2                    // statt eines regulären Ticks wird das Command ID_CHART_REFRESH an den Chart geschickt (für Offline- und synth. Charts)
#define TICK_TESTER                       4                    // statt eines regulären Ticks wird das Command ID_CHART_STEPFORWARD an den Chart geschickt (für Tester)
#define TICK_IF_VISIBLE                   8                    // Ticks werden nur verschickt, wenn der Chart mindestens teilweise sichtbar ist (default: off)
#define TICK_PAUSE_ON_WEEKEND            16                    // Ticks werden nur zu regulären Forex-Handelszeiten verschickt (default: off)


/**
 * MT4 command ids (Menüs, Toolbars, Hotkeys)
 *
 * ID naming and numbering conventions used by MFC 2.0 for resources, commands, strings, controls and child windows:
 * @see  https://msdn.microsoft.com/en-us/library/t2zechd4.aspx
 */
#define ID_EXPERTS_ONOFF                    33020              // Toolbar: Experts on/off                    Ctrl+E

#define ID_CHART_REFRESH                    33324              // Chart: Refresh
#define ID_CHART_STEPFORWARD                33197              //        eine Bar vorwärts                      F12
#define ID_CHART_STEPBACKWARD               33198              //        eine Bar rückwärts               Shift+F12
#define ID_CHART_EXPERT_PROPERTIES          33048              //        Expert Properties-Dialog                F7
#define ID_CHART_OBJECTS_UNSELECTALL        35462              //        Objects: Unselect All

#define ID_MARKETWATCH_SYMBOLS              33171              // Market Watch: Symbols

#define ID_TESTER_TICK       ID_CHART_STEPFORWARD              // Tester: nächster Tick                         F12


// MT4 control ids (Controls, Fenster)
#define IDC_TOOLBAR                         59419              // Toolbar
#define IDC_TOOLBAR_COMMUNITY_BUTTON        38160              // MQL4/MQL5-Button (Builds <= 509)
#define IDC_TOOLBAR_SEARCHBOX               38213              // Suchbox          (Builds  > 509)
#define IDC_STATUSBAR                       59393              // Statusbar
#define IDC_MDI_CLIENT                      59648              // MDI-Container (enthält alle Charts)
#define IDC_DOCKABLES_CONTAINER             59422              // window containing all child windows docked to the main application window
#define IDC_UNDOCKED_CONTAINER              59423              // window containing a single undocked/floating dockable child window (ggf. mehrere, sind keine Top-Level-Windows)

#define IDC_MARKETWATCH                        80              // Market Watch
#define IDC_MARKETWATCH_SYMBOLS             35441              // Market Watch - Symbols
#define IDC_MARKETWATCH_TICKCHART           35442              // Market Watch - Tick Chart

#define IDC_NAVIGATOR                          82              // Navigator
#define IDC_NAVIGATOR_COMMON                35439              // Navigator - Common
#define IDC_NAVIGATOR_FAVOURITES            35440              // Navigator - Favourites

#define IDC_TERMINAL                           81              // Terminal
#define IDC_TERMINAL_TRADE                  33217              // Terminal - Trade
#define IDC_TERMINAL_ACCOUNTHISTORY         33208              // Terminal - Account History
#define IDC_TERMINAL_NEWS                   33211              // Terminal - News
#define IDC_TERMINAL_ALERTS                 33206              // Terminal - Alerts
#define IDC_TERMINAL_MAILBOX                33210              // Terminal - Mailbox
#define IDC_TERMINAL_COMPANY                 4078              // Terminal - Company
#define IDC_TERMINAL_MARKET                  4081              // Terminal - Market
#define IDC_TERMINAL_SIGNALS                 1405              // Terminal - Signals
#define IDC_TERMINAL_CODEBASE               33212              // Terminal - Code Base
#define IDC_TERMINAL_EXPERTS                35434              // Terminal - Experts
#define IDC_TERMINAL_JOURNAL                33209              // Terminal - Journal

#define IDC_TESTER                             83              // Tester
#define IDC_TESTER_SETTINGS                 33215              // Tester - Settings
#define IDC_TESTER_SETTINGS_PAUSERESUME      1402              // Tester - Settings Pause/Resume button
#define IDC_TESTER_SETTINGS_STARTSTOP        1034              // Tester - Settings Start/Stop button
#define IDC_TESTER_RESULTS                  33214              // Tester - Results
#define IDC_TESTER_GRAPH                    33207              // Tester - Graph
#define IDC_TESTER_REPORT                   33213              // Tester - Report
#define IDC_TESTER_JOURNAL   IDC_TERMINAL_EXPERTS              // Tester - Journal (entspricht Terminal - Experts)


// Farben
#define AliceBlue                        0xFFF8F0
#define AntiqueWhite                     0xD7EBFA
#define Aqua                             0xFFFF00
#define Aquamarine                       0xD4FF7F
#define Beige                            0xDCF5F5
#define Bisque                           0xC4E4FF
#define Black                            0x000000
#define BlanchedAlmond                   0xCDEBFF
#define Blue                             0xFF0000
#define BlueViolet                       0xE22B8A
#define Brown                            0x2A2AA5
#define BurlyWood                        0x87B8DE
#define CadetBlue                        0xA09E5F
#define Chartreuse                       0x00FF7F
#define Chocolate                        0x1E69D2
#define Coral                            0x507FFF
#define CornflowerBlue                   0xED9564
#define Cornsilk                         0xDCF8FF
#define Crimson                          0x3C14DC
#define DarkBlue                         0x8B0000
#define DarkGoldenrod                    0x0B86B8
#define DarkGray                         0xA9A9A9
#define DarkGreen                        0x006400
#define DarkKhaki                        0x6BB7BD
#define DarkOliveGreen                   0x2F6B55
#define DarkOrange                       0x008CFF
#define DarkOrchid                       0xCC3299
#define DarkSalmon                       0x7A96E9
#define DarkSeaGreen                     0x8BBC8F
#define DarkSlateBlue                    0x8B3D48
#define DarkSlateGray                    0x4F4F2F
#define DarkTurquoise                    0xD1CE00
#define DarkViolet                       0xD30094
#define DeepPink                         0x9314FF
#define DeepSkyBlue                      0xFFBF00
#define DimGray                          0x696969
#define DodgerBlue                       0xFF901E
#define FireBrick                        0x2222B2
#define ForestGreen                      0x228B22
#define Gainsboro                        0xDCDCDC
#define Gold                             0x00D7FF
#define Goldenrod                        0x20A5DA
#define Gray                             0x808080
#define Green                            0x008000
#define GreenYellow                      0x2FFFAD
#define Honeydew                         0xF0FFF0
#define HotPink                          0xB469FF
#define IndianRed                        0x5C5CCD
#define Indigo                           0x82004B
#define Ivory                            0xF0FFFF
#define Khaki                            0x8CE6F0
#define Lavender                         0xFAE6E6
#define LavenderBlush                    0xF5F0FF
#define LawnGreen                        0x00FC7C
#define LemonChiffon                     0xCDFAFF
#define LightBlue                        0xE6D8AD
#define LightCoral                       0x8080F0
#define LightCyan                        0xFFFFE0
#define LightGoldenrod                   0xD2FAFA
#define LightGray                        0xD3D3D3
#define LightGreen                       0x90EE90
#define LightPink                        0xC1B6FF
#define LightSalmon                      0x7AA0FF
#define LightSeaGreen                    0xAAB220
#define LightSkyBlue                     0xFACE87
#define LightSlateGray                   0x998877
#define LightSteelBlue                   0xDEC4B0
#define LightYellow                      0xE0FFFF
#define Lime                             0x00FF00
#define LimeGreen                        0x32CD32
#define Linen                            0xE6F0FA
#define Magenta                          0xFF00FF
#define Maroon                           0x000080
#define MediumAquamarine                 0xAACD66
#define MediumBlue                       0xCD0000
#define MediumOrchid                     0xD355BA
#define MediumPurple                     0xDB7093
#define MediumSeaGreen                   0x71B33C
#define MediumSlateBlue                  0xEE687B
#define MediumSpringGreen                0x9AFA00
#define MediumTurquoise                  0xCCD148
#define MediumVioletRed                  0x8515C7
#define MidnightBlue                     0x701919
#define MintCream                        0xFAFFF5
#define MistyRose                        0xE1E4FF
#define Moccasin                         0xB5E4FF
#define NavajoWhite                      0xADDEFF
#define Navy                             0x800000
#define OldLace                          0xE6F5FD
#define Olive                            0x008080
#define OliveDrab                        0x238E6B
#define Orange                           0x00A5FF
#define OrangeRed                        0x0045FF
#define Orchid                           0xD670DA
#define PaleGoldenrod                    0xAAE8EE
#define PaleGreen                        0x98FB98
#define PaleTurquoise                    0xEEEEAF
#define PaleVioletRed                    0x9370DB
#define PapayaWhip                       0xD5EFFF
#define PeachPuff                        0xB9DAFF
#define Peru                             0x3F85CD
#define Pink                             0xCBC0FF
#define Plum                             0xDDA0DD
#define PowderBlue                       0xE6E0B0
#define Purple                           0x800080
#define Red                              0x0000FF
#define RosyBrown                        0x8F8FBC
#define RoyalBlue                        0xE16941
#define SaddleBrown                      0x13458B
#define Salmon                           0x7280FA
#define SandyBrown                       0x60A4F4
#define SeaGreen                         0x578B2E
#define Seashell                         0xEEF5FF
#define Sienna                           0x2D52A0
#define Silver                           0xC0C0C0
#define SkyBlue                          0xEBCE87
#define SlateBlue                        0xCD5A6A
#define SlateGray                        0x908070
#define Snow                             0xFAFAFF
#define SpringGreen                      0x7FFF00
#define SteelBlue                        0xB48246
#define Tan                              0x8CB4D2
#define Teal                             0x808000
#define Thistle                          0xD8BFD8
#define Tomato                           0x4763FF
#define Turquoise                        0xD0E040
#define Violet                           0xEE82EE
#define Wheat                            0xB3DEF5
#define White                            0xFFFFFF
#define WhiteSmoke                       0xF5F5F5
#define Yellow                           0x00FFFF
#define YellowGreen                      0x32CD9A


// LFX-TradeCommands
#define TC_LFX_ORDER_CREATE              1
#define TC_LFX_ORDER_OPEN                2
#define TC_LFX_ORDER_CLOSE               3
#define TC_LFX_ORDER_CLOSEBY             4
#define TC_LFX_ORDER_HEDGE               5
#define TC_LFX_ORDER_MODIFY              6
#define TC_LFX_ORDER_DELETE              7

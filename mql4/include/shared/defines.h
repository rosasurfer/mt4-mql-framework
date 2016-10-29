/**
 * Custom constants shared between MQL and C++
 *
 * @see  shared Windows constants at the end of file
 */

// Special constants
#define CLR_NONE                 0xFFFFFFFF                    // MetaQuotes: no color = 0xFFFFFFFF (-1), im Gegensatz zu weiß = 0x00FFFFFF
#define EMPTY_COLOR              0xFFFFFFFE                    // ungültige Farbe (-2)
#define MAX_SYMBOL_LENGTH                11
#define MIN_VALID_POINTER        0x00010000                    // kleinster möglicher Wert für einen gültigen Pointer (x86)


// Log level
#define L_OFF                    0x80000000                    // explizit, da INT_MIN in C++ intern definiert ist, in MQL jedoch nicht
#define L_FATAL                       10000                    //
#define L_ERROR                       20000                    // Tests umgekehrt zu log4j mit: if (__LOG_LEVEL >= msg_level) log  (...);
#define L_WARN                        30000                    // oder einfacher:               if (__LOG_DEBUG)              debug(...);
#define L_INFO                        40000                    //
#define L_NOTICE                      50000                    //
#define L_DEBUG                       60000                    //
#define L_ALL                    0x7FFFFFFF                    // explizit, da INT_MAX in C++ intern definiert ist, in MQL jedoch nicht


// Moduletyp-Flags
#define MODULETYPE_INDICATOR              1
#define MODULETYPE_EXPERT                 2
#define MODULETYPE_SCRIPT                 4
#define MODULETYPE_LIBRARY                8                    // kein eigenständiges Programm


// Programm-Typen
#define PROGRAMTYPE_INDICATOR             MODULETYPE_INDICATOR
#define PROGRAMTYPE_EXPERT                MODULETYPE_EXPERT
#define PROGRAMTYPE_SCRIPT                MODULETYPE_SCRIPT


// MQL Root-Funktion-ID's
#define ROOTFUNCTION_INIT                 1
#define ROOTFUNCTION_START                2
#define ROOTFUNCTION_DEINIT               3


// MQL Launchtypen eines Programms
#define LAUNCHTYPE_TEMPLATE               1                    // von Template geladen
#define LAUNCHTYPE_PROGRAM                2                    // von iCustom() geladen
#define LAUNCHTYPE_MANUAL                 3                    // von Hand geladen


// Timeframe-Identifier
#define PERIOD_M1                         1                    // 1 Minute
#define PERIOD_M5                         5                    // 5 Minuten
#define PERIOD_M15                       15                    // 15 Minuten
#define PERIOD_M30                       30                    // 30 Minuten
#define PERIOD_H1                        60                    // 1 Stunde
#define PERIOD_H4                       240                    // 4 Stunden
#define PERIOD_D1                      1440                    // 1 Tag
#define PERIOD_W1                     10080                    // 1 Woche (7 Tage)
#define PERIOD_MN1                    43200                    // 1 Monat (30 Tage)
#define PERIOD_Q1                    129600                    // 1 Quartal (3 Monate)


// Zeitkonstanten
#define SECOND                            1
#define MINUTE                           60                    //  60 Sekunden
#define HOUR                           3600                    //  60 Minuten
#define DAY                           86400                    //  24 Stunden
#define WEEK                         604800                    //   7 Tage
#define MONTH                       2678400                    //  31 Tage                   // Die Werte sind auf das jeweilige Maximum ausgelegt, sodaß
#define QUARTER                     8035200                    //   3 Monate (3 x 31 Tage)   // bei Datumsarithmetik immer ein Wechsel in die jeweils nächste
#define YEAR                       31622400                    // 366 Tage                   // Periode garantiert ist.

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


// UninitializeReason-Codes                                    // MT4 builds <= 509                      // MT4 builds > 509
#define REASON_UNDEFINED                  0                    // no uninitialize reason                 // = REASON_PROGRAM: EA terminated by ExpertRemove()
#define REASON_REMOVE                     1                    // program removed from chart             //
#define REASON_RECOMPILE                  2                    // program recompiled                     //
#define REASON_CHARTCHANGE                3                    // chart symbol or timeframe changed      //
#define REASON_CHARTCLOSE                 4                    // chart closed or template changed       // chart closed
#define REASON_PARAMETERS                 5                    // input parameters changed               //
#define REASON_ACCOUNT                    6                    // account changed                        // account or account settings changed
// ab Build > 509
#define REASON_TEMPLATE                   7                    // -                                      // template changed
#define REASON_INITFAILED                 8                    // -                                      // OnInit() returned with an error
#define REASON_CLOSE                      9                    // -                                      // terminal closed


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

#define MT4_COMPILE_REQUEST           12345
#define MT4_COMPILE_PERMISSION        12346
#define MT4_MQL_REFRESH               12349                    // Rescan und Reload modifizierter .ex4-Files


// Konfiguration-Flags für synthetische Ticks
#define TICK_OFFLINE_EA          0x00000001                    //  1: Default-Tick, Expert::start() wird in Offline-Charts getriggert (bei bestehender Server-Connection)
#define TICK_CHART_REFRESH       0x00000010                    //  2: statt eines regulären Ticks wird das Command ID_CHART_REFRESH an den Chart geschickt (für Offline- und synth. Charts)
#define TICK_TESTER              0x00000100                    //  4: statt eines regulären Ticks wird das Command ID_CHART_STEPFORWARD an den Chart geschickt (für Tester)
#define TICK_IF_VISIBLE          0x00001000                    //  8: Ticks werden nur verschickt, wenn der Chart mindestens teilweise sichtbar ist (default: off)
#define TICK_PAUSE_ON_WEEKEND    0x00010000                    // 16: Ticks werden nur zu regulären Forex-Handelszeiten verschickt (default: off)


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


/**
 * Windows constants shared between MQL and C++
 */

// AnimateWindow() commands
#define AW_HOR_POSITIVE                   0x00000001
#define AW_HOR_NEGATIVE                   0x00000002
#define AW_VER_POSITIVE                   0x00000004
#define AW_VER_NEGATIVE                   0x00000008
#define AW_CENTER                         0x00000010
#define AW_HIDE                           0x00010000
#define AW_ACTIVATE                       0x00020000
#define AW_SLIDE                          0x00040000
#define AW_BLEND                          0x00080000


// Standard Cursor IDs
#define IDC_APPSTARTING                        32650  // standard arrow and small hourglass (not in win3.1)
#define IDC_ARROW                              32512  // standard arrow
#define IDC_CROSS                              32515  // crosshair
#define IDC_IBEAM                              32513  // text I-beam
#define IDC_ICON                               32641  // Windows NT only: empty icon
#define IDC_NO                                 32648  // slashed circle (not in win3.1)
#define IDC_SIZE                               32640  // Windows NT only: four-pointed arrow
#define IDC_SIZEALL                            32646  // same as IDC_SIZE
#define IDC_SIZENESW                           32643  // double-pointed arrow pointing northeast and southwest
#define IDC_SIZENS                             32645  // double-pointed arrow pointing north and south
#define IDC_SIZENWSE                           32642  // double-pointed arrow pointing northwest and southeast
#define IDC_SIZEWE                             32644  // double-pointed arrow pointing west and east
#define IDC_UPARROW                            32516  // vertical arrow
#define IDC_WAIT                               32514  // hourglass
#define IDC_HAND                               32649  // WINVER >= 0x0500
#define IDC_HELP                               32651  // WINVER >= 0x0400


// Dialog flags
#define MB_OK                             0x00000000  // buttons
#define MB_OKCANCEL                       0x00000001
#define MB_ABORTRETRYIGNORE               0x00000002
#define MB_CANCELTRYCONTINUE              0x00000006
#define MB_RETRYCANCEL                    0x00000005
#define MB_YESNO                          0x00000004
#define MB_YESNOCANCEL                    0x00000003
#define MB_HELP                           0x00004000  // additional help button

#define MB_DEFBUTTON1                     0x00000000  // default button
#define MB_DEFBUTTON2                     0x00000100
#define MB_DEFBUTTON3                     0x00000200
#define MB_DEFBUTTON4                     0x00000300

#define MB_ICONEXCLAMATION                0x00000030  // icons
#define MB_ICONWARNING            MB_ICONEXCLAMATION
#define MB_ICONINFORMATION                0x00000040
#define MB_ICONASTERISK           MB_ICONINFORMATION
#define MB_ICONQUESTION                   0x00000020
#define MB_ICONSTOP                       0x00000010
#define MB_ICONERROR                     MB_ICONSTOP
#define MB_ICONHAND                      MB_ICONSTOP
#define MB_USERICON                       0x00000080

#define MB_APPLMODAL                      0x00000000  // modality
#define MB_SYSTEMMODAL                    0x00001000
#define MB_TASKMODAL                      0x00002000

#define MB_DEFAULT_DESKTOP_ONLY           0x00020000  // other
#define MB_RIGHT                          0x00080000
#define MB_RTLREADING                     0x00100000
#define MB_SETFOREGROUND                  0x00010000
#define MB_TOPMOST                        0x00040000
#define MB_NOFOCUS                        0x00008000
#define MB_SERVICE_NOTIFICATION           0x00200000


// Dialog return codes
#define IDOK                                       1
#define IDCANCEL                                   2
#define IDABORT                                    3
#define IDRETRY                                    4
#define IDIGNORE                                   5
#define IDYES                                      6
#define IDNO                                       7
#define IDCLOSE                                    8
#define IDHELP                                     9
#define IDTRYAGAIN                                10
#define IDCONTINUE                                11


// File & I/O constants
#define MAX_PATH                                 260     // for example the maximum path on drive D is "D:\some-256-character-path-string<NUL>"

#define AT_NORMAL                               0x00     // DOS file attributes
#define AT_READONLY                             0x01
#define AT_HIDDEN                               0x02
#define AT_SYSTEM                               0x04
#define AT_ARCHIVE                              0x20

#define FILE_ATTRIBUTE_READONLY                    1
#define FILE_ATTRIBUTE_HIDDEN                      2
#define FILE_ATTRIBUTE_SYSTEM                      4
#define FILE_ATTRIBUTE_DIRECTORY                  16
#define FILE_ATTRIBUTE_ARCHIVE                    32
#define FILE_ATTRIBUTE_DEVICE                     64
#define FILE_ATTRIBUTE_NORMAL                    128
#define FILE_ATTRIBUTE_TEMPORARY                 256
#define FILE_ATTRIBUTE_SPARSE_FILE               512
#define FILE_ATTRIBUTE_REPARSE_POINT            1024
#define FILE_ATTRIBUTE_COMPRESSED               2048
#define FILE_ATTRIBUTE_OFFLINE                  4096
#define FILE_ATTRIBUTE_NOT_INDEXED              8192     // FILE_ATTRIBUTE_NOT_CONTENT_INDEXED ist zu lang für MQL
#define FILE_ATTRIBUTE_ENCRYPTED               16384
#define FILE_ATTRIBUTE_VIRTUAL                 65536

#define OF_READ                                 0x00
#define OF_WRITE                                0x01
#define OF_READWRITE                            0x02
#define OF_SHARE_COMPAT                         0x00
#define OF_SHARE_EXCLUSIVE                      0x10
#define OF_SHARE_DENY_WRITE                     0x20
#define OF_SHARE_DENY_READ                      0x30
#define OF_SHARE_DENY_NONE                      0x40

#define HFILE_ERROR                       0xFFFFFFFF     // -1
#define INVALID_FILE_SIZE                 0xFFFFFFFF     // -1


// GDI region codes, @see GetClipBox()
#define ERROR                                      0
#define NULLREGION                                 1
#define SIMPLEREGION                               2
#define COMPLEXREGION                              3
#define RGN_ERROR                              ERROR


// GetAncestor() constants
#define GA_PARENT                                  1
#define GA_ROOT                                    2
#define GA_ROOTOWNER                               3


// GetSystemMetrics() codes
#define SM_CXSCREEN                                0
#define SM_CYSCREEN                                1
#define SM_CXVSCROLL                               2
#define SM_CYHSCROLL                               3
#define SM_CYCAPTION                               4
#define SM_CXBORDER                                5
#define SM_CYBORDER                                6
#define SM_CXDLGFRAME                              7
#define SM_CYDLGFRAME                              8
#define SM_CYVTHUMB                                9
#define SM_CXHTHUMB                               10
#define SM_CXICON                                 11
#define SM_CYICON                                 12
#define SM_CXCURSOR                               13
#define SM_CYCURSOR                               14
#define SM_CYMENU                                 15
#define SM_CXFULLSCREEN                           16
#define SM_CYFULLSCREEN                           17
#define SM_CYKANJIWINDOW                          18
#define SM_MOUSEPRESENT                           19
#define SM_CYVSCROLL                              20
#define SM_CXHSCROLL                              21
#define SM_DEBUG                                  22
#define SM_SWAPBUTTON                             23
#define SM_RESERVED1                              24
#define SM_RESERVED2                              25
#define SM_RESERVED3                              26
#define SM_RESERVED4                              27
#define SM_CXMIN                                  28
#define SM_CYMIN                                  29
#define SM_CXSIZE                                 30
#define SM_CYSIZE                                 31
#define SM_CXFRAME                                32
#define SM_CYFRAME                                33
#define SM_CXMINTRACK                             34
#define SM_CYMINTRACK                             35
#define SM_CXDOUBLECLK                            36
#define SM_CYDOUBLECLK                            37
#define SM_CXICONSPACING                          38
#define SM_CYICONSPACING                          39
#define SM_MENUDROPALIGNMENT                      40
#define SM_PENWINDOWS                             41
#define SM_DBCSENABLED                            42
#define SM_CMOUSEBUTTONS                          43
#define SM_SECURE                                 44
#define SM_CXEDGE                                 45
#define SM_CYEDGE                                 46
#define SM_CXMINSPACING                           47
#define SM_CYMINSPACING                           48
#define SM_CXSMICON                               49
#define SM_CYSMICON                               50
#define SM_CYSMCAPTION                            51
#define SM_CXSMSIZE                               52
#define SM_CYSMSIZE                               53
#define SM_CXMENUSIZE                             54
#define SM_CYMENUSIZE                             55
#define SM_ARRANGE                                56
#define SM_CXMINIMIZED                            57
#define SM_CYMINIMIZED                            58
#define SM_CXMAXTRACK                             59
#define SM_CYMAXTRACK                             60
#define SM_CXMAXIMIZED                            61
#define SM_CYMAXIMIZED                            62
#define SM_NETWORK                                63
#define SM_CLEANBOOT                              67
#define SM_CXDRAG                                 68
#define SM_CYDRAG                                 69
#define SM_SHOWSOUNDS                             70
#define SM_CXMENUCHECK                            71     // use instead of GetMenuCheckMarkDimensions()
#define SM_CYMENUCHECK                            72
#define SM_SLOWMACHINE                            73
#define SM_MIDEASTENABLED                         74
#define SM_MOUSEWHEELPRESENT                      75
#define SM_XVIRTUALSCREEN                         76
#define SM_YVIRTUALSCREEN                         77
#define SM_CXVIRTUALSCREEN                        78
#define SM_CYVIRTUALSCREEN                        79
#define SM_CMONITORS                              80
#define SM_SAMEDISPLAYFORMAT                      81


// GetTimeZoneInformation() constants
#define TIME_ZONE_ID_UNKNOWN                       0
#define TIME_ZONE_ID_STANDARD                      1
#define TIME_ZONE_ID_DAYLIGHT                      2


// GetWindow() constants
#define GW_HWNDFIRST                               0
#define GW_HWNDLAST                                1
#define GW_HWNDNEXT                                2
#define GW_HWNDPREV                                3
#define GW_OWNER                                   4
#define GW_CHILD                                   5
#define GW_ENABLEDPOPUP                            6


// RedrawWindow() flags
#define RDW_INVALIDATE                        0x0001
#define RDW_INTERNALPAINT                     0x0002
#define RDW_ERASE                             0x0004

#define RDW_VALIDATE                          0x0008
#define RDW_NOINTERNALPAINT                   0x0010
#define RDW_NOERASE                           0x0020

#define RDW_NOCHILDREN                        0x0040
#define RDW_ALLCHILDREN                       0x0080

#define RDW_UPDATENOW                         0x0100
#define RDW_ERASENOW                          0x0200

#define RDW_FRAME                             0x0400
#define RDW_NOFRAME                           0x0800


// Handles
#define INVALID_HANDLE_VALUE              0xFFFFFFFF     // -1


// Keyboard events
#define KEYEVENTF_EXTENDEDKEY                   0x01
#define KEYEVENTF_KEYUP                         0x02


// Memory protection constants, see VirtualAlloc()
#define PAGE_EXECUTE                            0x10     // options
#define PAGE_EXECUTE_READ                       0x20
#define PAGE_EXECUTE_READWRITE                  0x40
#define PAGE_EXECUTE_WRITECOPY                  0x80
#define PAGE_NOACCESS                           0x01
#define PAGE_READONLY                           0x02
#define PAGE_READWRITE                          0x04
#define PAGE_WRITECOPY                          0x08

#define PAGE_GUARD                             0x100     // modifier
#define PAGE_NOCACHE                           0x200
#define PAGE_WRITECOMBINE                      0x400


// Messages
#define WM_NULL                               0x0000
#define WM_CREATE                             0x0001
#define WM_DESTROY                            0x0002
#define WM_MOVE                               0x0003
#define WM_SIZE                               0x0005
#define WM_ACTIVATE                           0x0006
#define WM_SETFOCUS                           0x0007
#define WM_KILLFOCUS                          0x0008
#define WM_ENABLE                             0x000A
#define WM_SETREDRAW                          0x000B
#define WM_SETTEXT                            0x000C
#define WM_GETTEXT                            0x000D
#define WM_GETTEXTLENGTH                      0x000E
#define WM_PAINT                              0x000F
#define WM_CLOSE                              0x0010
#define WM_QUERYENDSESSION                    0x0011
#define WM_QUIT                               0x0012
#define WM_QUERYOPEN                          0x0013
#define WM_ERASEBKGND                         0x0014
#define WM_SYSCOLORCHANGE                     0x0015
#define WM_ENDSESSION                         0x0016
#define WM_SHOWWINDOW                         0x0018
#define WM_WININICHANGE                       0x001A
#define WM_SETTINGCHANGE                      0x001A     // WM_WININICHANGE
#define WM_DEVMODECHANGE                      0x001B
#define WM_ACTIVATEAPP                        0x001C
#define WM_FONTCHANGE                         0x001D
#define WM_TIMECHANGE                         0x001E
#define WM_CANCELMODE                         0x001F
#define WM_SETCURSOR                          0x0020
#define WM_MOUSEACTIVATE                      0x0021
#define WM_CHILDACTIVATE                      0x0022
#define WM_QUEUESYNC                          0x0023
#define WM_GETMINMAXINFO                      0x0024
#define WM_PAINTICON                          0x0026
#define WM_ICONERASEBKGND                     0x0027
#define WM_NEXTDLGCTL                         0x0028
#define WM_SPOOLERSTATUS                      0x002A
#define WM_DRAWITEM                           0x002B
#define WM_MEASUREITEM                        0x002C
#define WM_DELETEITEM                         0x002D
#define WM_VKEYTOITEM                         0x002E
#define WM_CHARTOITEM                         0x002F
#define WM_SETFONT                            0x0030
#define WM_GETFONT                            0x0031
#define WM_SETHOTKEY                          0x0032
#define WM_GETHOTKEY                          0x0033
#define WM_QUERYDRAGICON                      0x0037
#define WM_COMPAREITEM                        0x0039
#define WM_GETOBJECT                          0x003D
#define WM_COMPACTING                         0x0041
#define WM_WINDOWPOSCHANGING                  0x0046
#define WM_WINDOWPOSCHANGED                   0x0047
#define WM_COPYDATA                           0x004A
#define WM_CANCELJOURNAL                      0x004B
#define WM_NOTIFY                             0x004E
#define WM_INPUTLANGCHANGEREQUEST             0x0050
#define WM_INPUTLANGCHANGE                    0x0051
#define WM_TCARD                              0x0052
#define WM_HELP                               0x0053
#define WM_USERCHANGED                        0x0054
#define WM_NOTIFYFORMAT                       0x0055
#define WM_CONTEXTMENU                        0x007B
#define WM_STYLECHANGING                      0x007C
#define WM_STYLECHANGED                       0x007D
#define WM_DISPLAYCHANGE                      0x007E
#define WM_GETICON                            0x007F
#define WM_SETICON                            0x0080
#define WM_NCCREATE                           0x0081
#define WM_NCDESTROY                          0x0082
#define WM_NCCALCSIZE                         0x0083
#define WM_NCHITTEST                          0x0084
#define WM_NCPAINT                            0x0085
#define WM_NCACTIVATE                         0x0086
#define WM_GETDLGCODE                         0x0087
#define WM_SYNCPAINT                          0x0088
#define WM_NCMOUSEMOVE                        0x00A0
#define WM_NCLBUTTONDOWN                      0x00A1
#define WM_NCLBUTTONUP                        0x00A2
#define WM_NCLBUTTONDBLCLK                    0x00A3
#define WM_NCRBUTTONDOWN                      0x00A4
#define WM_NCRBUTTONUP                        0x00A5
#define WM_NCRBUTTONDBLCLK                    0x00A6
#define WM_NCMBUTTONDOWN                      0x00A7
#define WM_NCMBUTTONUP                        0x00A8
#define WM_NCMBUTTONDBLCLK                    0x00A9
#define WM_KEYFIRST                           0x0100
#define WM_KEYDOWN                            0x0100
#define WM_KEYUP                              0x0101
#define WM_CHAR                               0x0102
#define WM_DEADCHAR                           0x0103
#define WM_SYSKEYDOWN                         0x0104
#define WM_SYSKEYUP                           0x0105
#define WM_SYSCHAR                            0x0106
#define WM_SYSDEADCHAR                        0x0107
#define WM_KEYLAST                            0x0108
#define WM_INITDIALOG                         0x0110
#define WM_COMMAND                            0x0111
#define WM_SYSCOMMAND                         0x0112
#define WM_TIMER                              0x0113
#define WM_HSCROLL                            0x0114
#define WM_VSCROLL                            0x0115
#define WM_INITMENU                           0x0116
#define WM_INITMENUPOPUP                      0x0117
#define WM_MENUSELECT                         0x011F
#define WM_MENUCHAR                           0x0120
#define WM_ENTERIDLE                          0x0121
#define WM_MENURBUTTONUP                      0x0122
#define WM_MENUDRAG                           0x0123
#define WM_MENUGETOBJECT                      0x0124
#define WM_UNINITMENUPOPUP                    0x0125
#define WM_MENUCOMMAND                        0x0126
#define WM_CTLCOLORMSGBOX                     0x0132
#define WM_CTLCOLOREDIT                       0x0133
#define WM_CTLCOLORLISTBOX                    0x0134
#define WM_CTLCOLORBTN                        0x0135
#define WM_CTLCOLORDLG                        0x0136
#define WM_CTLCOLORSCROLLBAR                  0x0137
#define WM_CTLCOLORSTATIC                     0x0138
#define WM_MOUSEFIRST                         0x0200
#define WM_MOUSEMOVE                          0x0200
#define WM_LBUTTONDOWN                        0x0201
#define WM_LBUTTONUP                          0x0202
#define WM_LBUTTONDBLCLK                      0x0203
#define WM_RBUTTONDOWN                        0x0204
#define WM_RBUTTONUP                          0x0205
#define WM_RBUTTONDBLCLK                      0x0206
#define WM_MBUTTONDOWN                        0x0207
#define WM_MBUTTONUP                          0x0208
#define WM_MBUTTONDBLCLK                      0x0209
#define WM_PARENTNOTIFY                       0x0210
#define WM_ENTERMENULOOP                      0x0211
#define WM_EXITMENULOOP                       0x0212
#define WM_NEXTMENU                           0x0213
#define WM_SIZING                             0x0214
#define WM_CAPTURECHANGED                     0x0215
#define WM_MOVING                             0x0216
#define WM_DEVICECHANGE                       0x0219
#define WM_MDICREATE                          0x0220
#define WM_MDIDESTROY                         0x0221
#define WM_MDIACTIVATE                        0x0222
#define WM_MDIRESTORE                         0x0223
#define WM_MDINEXT                            0x0224
#define WM_MDIMAXIMIZE                        0x0225
#define WM_MDITILE                            0x0226
#define WM_MDICASCADE                         0x0227
#define WM_MDIICONARRANGE                     0x0228
#define WM_MDIGETACTIVE                       0x0229
#define WM_MDISETMENU                         0x0230
#define WM_ENTERSIZEMOVE                      0x0231
#define WM_EXITSIZEMOVE                       0x0232
#define WM_DROPFILES                          0x0233
#define WM_MDIREFRESHMENU                     0x0234
#define WM_MOUSEHOVER                         0x02A1
#define WM_MOUSELEAVE                         0x02A3
#define WM_CUT                                0x0300
#define WM_COPY                               0x0301
#define WM_PASTE                              0x0302
#define WM_CLEAR                              0x0303
#define WM_UNDO                               0x0304
#define WM_RENDERFORMAT                       0x0305
#define WM_RENDERALLFORMATS                   0x0306
#define WM_DESTROYCLIPBOARD                   0x0307
#define WM_DRAWCLIPBOARD                      0x0308
#define WM_PAINTCLIPBOARD                     0x0309
#define WM_VSCROLLCLIPBOARD                   0x030A
#define WM_SIZECLIPBOARD                      0x030B
#define WM_ASKCBFORMATNAME                    0x030C
#define WM_CHANGECBCHAIN                      0x030D
#define WM_HSCROLLCLIPBOARD                   0x030E
#define WM_QUERYNEWPALETTE                    0x030F
#define WM_PALETTEISCHANGING                  0x0310
#define WM_PALETTECHANGED                     0x0311
#define WM_HOTKEY                             0x0312
#define WM_PRINT                              0x0317
#define WM_PRINTCLIENT                        0x0318
#define WM_HANDHELDFIRST                      0x0358
#define WM_HANDHELDLAST                       0x035F
#define WM_AFXFIRST                           0x0360
#define WM_AFXLAST                            0x037F
#define WM_PENWINFIRST                        0x0380
#define WM_PENWINLAST                         0x038F
#define WM_APP                                0x8000


// Mouse events
#define MOUSEEVENTF_MOVE                      0x0001     // mouse move
#define MOUSEEVENTF_LEFTDOWN                  0x0002     // left button down
#define MOUSEEVENTF_LEFTUP                    0x0004     // left button up
#define MOUSEEVENTF_RIGHTDOWN                 0x0008     // right button down
#define MOUSEEVENTF_RIGHTUP                   0x0010     // right button up
#define MOUSEEVENTF_MIDDLEDOWN                0x0020     // middle button down
#define MOUSEEVENTF_MIDDLEUP                  0x0040     // middle button up
#define MOUSEEVENTF_WHEEL                     0x0800     // wheel button rolled
#define MOUSEEVENTF_ABSOLUTE                  0x8000     // absolute move


// PlaySound() flags
#define SND_SYNC                                0x00     // play synchronously (default)
#define SND_ASYNC                               0x01     // play asynchronously
#define SND_NODEFAULT                           0x02     // silence (!default) if sound not found
#define SND_MEMORY                              0x04     // lpSound points to a memory file
#define SND_LOOP                                0x08     // loop the sound until next sndPlaySound
#define SND_NOSTOP                              0x10     // don't stop any currently playing sound

#define SND_NOWAIT                        0x00002000     // don't wait if the driver is busy
#define SND_ALIAS                         0x00010000     // name is a registry alias
#define SND_ALIAS_ID                      0x00110000     // alias is a predefined ID
#define SND_FILENAME                      0x00020000     // name is file name
#define SND_RESOURCE                      0x00040004     // name is resource name or atom

#define SND_PURGE                             0x0040     // purge non-static events for task
#define SND_APPLICATION                       0x0080     // look for application specific association
#define SND_SENTRY                        0x00080000     // generate a SoundSentry event with this sound
#define SND_SYSTEM                        0x00200000     // treat this as a system sound


// Process creation flags, see CreateProcess()
#define DEBUG_PROCESS                    0x00000001
#define DEBUG_ONLY_THIS_PROCESS          0x00000002
#define CREATE_SUSPENDED                 0x00000004
#define DETACHED_PROCESS                 0x00000008
#define CREATE_NEW_CONSOLE               0x00000010
#define CREATE_NEW_PROCESS_GROUP         0x00000200
#define CREATE_UNICODE_ENVIRONMENT       0x00000400
#define CREATE_SEPARATE_WOW_VDM          0x00000800
#define CREATE_SHARED_WOW_VDM            0x00001000
#define INHERIT_PARENT_AFFINITY          0x00010000
#define CREATE_PROTECTED_PROCESS         0x00040000
#define EXTENDED_STARTUPINFO_PRESENT     0x00080000
#define CREATE_BREAKAWAY_FROM_JOB        0x01000000
#define CREATE_PRESERVE_CODE_AUTHZ_LEVEL 0x02000000
#define CREATE_DEFAULT_ERROR_MODE        0x04000000
#define CREATE_NO_WINDOW                 0x08000000


// Process priority flags, see CreateProcess()
#define IDLE_PRIORITY_CLASS                   0x0040
#define BELOW_NORMAL_PRIORITY_CLASS           0x4000
#define NORMAL_PRIORITY_CLASS                 0x0020
#define ABOVE_NORMAL_PRIORITY_CLASS           0x8000
#define HIGH_PRIORITY_CLASS                   0x0080
#define REALTIME_PRIORITY_CLASS               0x0100


// ShowWindow() constants
#define SW_SHOW               5  // Activates the window and displays it in its current size and position.
#define SW_SHOWNA             8  // Displays the window in its current size and position. Similar to SW_SHOW, except that the window is not activated.
#define SW_HIDE               0  // Hides the window and activates another window.

#define SW_SHOWMAXIMIZED      3  // Activates the window and displays it as a maximized window.

#define SW_SHOWMINIMIZED      2  // Activates the window and displays it as a minimized window.
#define SW_SHOWMINNOACTIVE    7  // Displays the window as a minimized window. Similar to SW_SHOWMINIMIZED, except the window is not activated.
#define SW_MINIMIZE           6  // Minimizes the specified window and activates the next top-level window in the Z order.
#define SW_FORCEMINIMIZE     11  // Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when
                                 // minimizing windows from a different thread.

#define SW_SHOWNORMAL         1  // Activates and displays a window. If the window is minimized or maximized, Windows restores it to its original size and
                                 // position. An application should specify this flag when displaying the window for the first time.
#define SW_SHOWNOACTIVATE     4  // Displays a window in its most recent size and position. Similar to SW_SHOWNORMAL, except that the window is not activated.
#define SW_RESTORE            9  // Activates and displays the window. If the window is minimized or maximized, Windows restores it to its original size and
                                 // position. An application should specify this flag when restoring a minimized window.

#define SW_SHOWDEFAULT       10  // Sets the show state based on the SW_ flag specified in the STARTUPINFO structure passed to the CreateProcess() function by
                                 // the program that started the application.

// ShellExecute() error codes
#define SE_ERR_FNF                                 2     // file not found
#define SE_ERR_PNF                                 3     // path not found
#define SE_ERR_ACCESSDENIED                        5     // access denied
#define SE_ERR_OOM                                 8     // out of memory
#define SE_ERR_SHARE                              26     // a sharing violation occurred
#define SE_ERR_ASSOCINCOMPLETE                    27     // file association information incomplete or invalid
#define SE_ERR_DDETIMEOUT                         28     // DDE operation timed out
#define SE_ERR_DDEFAIL                            29     // DDE operation failed
#define SE_ERR_DDEBUSY                            30     // DDE operation is busy
#define SE_ERR_NOASSOC                            31     // file association not available
#define SE_ERR_DLLNOTFOUND                        32     // DLL not found


// STARTUPINFO structure flags
#define STARTF_FORCEONFEEDBACK                0x0040
#define STARTF_FORCEOFFFEEDBACK               0x0080
#define STARTF_PREVENTPINNING                 0x2000
#define STARTF_RUNFULLSCREEN                  0x0020
#define STARTF_TITLEISAPPID                   0x1000
#define STARTF_TITLEISLINKNAME                0x0800
#define STARTF_USECOUNTCHARS                  0x0008
#define STARTF_USEFILLATTRIBUTE               0x0010
#define STARTF_USEHOTKEY                      0x0200
#define STARTF_USEPOSITION                    0x0004
#define STARTF_USESHOWWINDOW                  0x0001
#define STARTF_USESIZE                        0x0002
#define STARTF_USESTDHANDLES                  0x0100


// VirtualAlloc() allocation type flags
#define MEM_COMMIT                        0x00001000
#define MEM_RESERVE                       0x00002000
#define MEM_RESET                         0x00080000
#define MEM_TOP_DOWN                      0x00100000
#define MEM_WRITE_WATCH                   0x00200000
#define MEM_PHYSICAL                      0x00400000
#define MEM_LARGE_PAGES                   0x20000000


// Wait function constants, see WaitForSingleObject()
#define WAIT_ABANDONED                    0x00000080
#define WAIT_OBJECT_0                     0x00000000
#define WAIT_TIMEOUT                      0x00000102
#define WAIT_FAILED                       0xFFFFFFFF
#define INFINITE                          0xFFFFFFFF     // infinite timeout


// Window class styles, see WNDCLASS structure
#define CS_VREDRAW                            0x0001
#define CS_HREDRAW                            0x0002
#define CS_DBLCLKS                            0x0008
#define CS_OWNDC                              0x0020
#define CS_CLASSDC                            0x0040
#define CS_PARENTDC                           0x0080
#define CS_NOCLOSE                            0x0200
#define CS_SAVEBITS                           0x0800
#define CS_BYTEALIGNCLIENT                    0x1000
#define CS_BYTEALIGNWINDOW                    0x2000
#define CS_GLOBALCLASS                        0x4000


// Win32 error codes (für Fehlerbeschreibungen @see FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastWin32Error(), ...))
#define ERROR_SUCCESS                              0     // The operation completed successfully.
#define ERROR_INVALID_FUNCTION                     1     // Incorrect function.
#define ERROR_FILE_NOT_FOUND                       2     // The system cannot find the file specified.
#define ERROR_PATH_NOT_FOUND                       3     // The system cannot find the path specified.
#define ERROR_TOO_MANY_OPEN_FILES                  4     // The system cannot open the file.
#define ERROR_ACCESS_DENIED                        5     // Access is denied.
#define ERROR_INVALID_HANDLE                       6     // The handle is invalid.
#define ERROR_ARENA_TRASHED                        7     // The storage control blocks were destroyed.
#define ERROR_NOT_ENOUGH_MEMORY                    8     // Not enough storage is available to process this command.
#define ERROR_INVALID_BLOCK                        9     // The storage control block address is invalid.
#define ERROR_BAD_ENVIRONMENT                     10     // The environment is incorrect.
#define ERROR_BAD_FORMAT                          11     // An attempt was made to load a program with an incorrect format.
#define ERROR_INVALID_ACCESS                      12     // The access code is invalid.
#define ERROR_INVALID_DATA                        13     // The data is invalid.
#define ERROR_OUTOFMEMORY                         14     // Not enough storage is available to complete this operation.
#define ERROR_INVALID_DRIVE                       15     // The system cannot find the drive specified.
#define ERROR_CURRENT_DIRECTORY                   16     // The directory cannot be removed.
#define ERROR_NOT_SAME_DEVICE                     17     // The system cannot move the file to a different disk drive.
#define ERROR_NO_MORE_FILES                       18     // There are no more files.
#define ERROR_WRITE_PROTECT                       19     // The media is write protected.
#define ERROR_BAD_UNIT                            20     // The system cannot find the device specified.
#define ERROR_NOT_READY                           21     // The device is not ready.
#define ERROR_BAD_COMMAND                         22     // The device does not recognize the command.
#define ERROR_CRC                                 23     // Data error (cyclic redundancy check).
#define ERROR_BAD_LENGTH                          24     // The program issued a command but the command length is incorrect.
#define ERROR_SEEK                                25     // The drive cannot locate a specific area or track on the disk.
#define ERROR_NOT_DOS_DISK                        26     // The specified disk or diskette cannot be accessed.
#define ERROR_SECTOR_NOT_FOUND                    27     // The drive cannot find the sector requested.
#define ERROR_OUT_OF_PAPER                        28     // The printer is out of paper.
#define ERROR_WRITE_FAULT                         29     // The system cannot write to the specified device.
#define ERROR_READ_FAULT                          30     // The system cannot read from the specified device.
#define ERROR_GEN_FAILURE                         31     // A device attached to the system is not functioning.
#define ERROR_SHARING_VIOLATION                   32     // The process cannot access the file because it is being used by another process.
#define ERROR_LOCK_VIOLATION                      33     // The process cannot access the file because another process has locked a portion of the file.
#define ERROR_WRONG_DISK                          34     // The wrong diskette is in the drive. Insert %2 (Volume Serial Number: %3 ) into drive %1.
#define ERROR_SHARING_BUFFER_EXCEEDED             36     // Too many files opened for sharing.
#define ERROR_HANDLE_EOF                          38     // Reached the end of the file.
#define ERROR_HANDLE_DISK_FULL                    39     // The disk is full.
#define ERROR_NOT_SUPPORTED                       50     // The request is not supported.
#define ERROR_REM_NOT_LIST                        51     // Windows cannot find the network path.
#define ERROR_DUP_NAME                            52     // You were not connected because a duplicate name exists on the network.
#define ERROR_BAD_NETPATH                         53     // The network path was not found.
#define ERROR_NETWORK_BUSY                        54     // The network is busy.
#define ERROR_DEV_NOT_EXIST                       55     // The specified network resource or device is no longer available.
#define ERROR_TOO_MANY_CMDS                       56     // The network BIOS command limit has been reached.
#define ERROR_ADAP_HDW_ERR                        57     // A network adapter hardware error occurred.
#define ERROR_BAD_NET_RESP                        58     // The specified server cannot perform the requested operation.
#define ERROR_UNEXP_NET_ERR                       59     // An unexpected network error occurred.
#define ERROR_BAD_REM_ADAP                        60     // The remote adapter is not compatible.
#define ERROR_PRINTQ_FULL                         61     // The printer queue is full.
#define ERROR_NO_SPOOL_SPACE                      62     // Space to store the file waiting to be printed is not available on the server.
#define ERROR_PRINT_CANCELLED                     63     // Your file waiting to be printed was deleted.

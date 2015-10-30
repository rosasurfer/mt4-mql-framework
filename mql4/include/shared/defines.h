/**
 * In MQL und C++ gemeinsam verwendete Konstanten.
 */

// Log level
#define L_OFF                    0x80000000                    // INT_MIN: ausdrücklich, da in C++ bereits intern definiert
#define L_FATAL                       10000                    //
#define L_ERROR                       20000                    // Tests umgekehrt zu log4j mit: if (__LOG_LEVEL >= msg_level) log(...);
#define L_WARN                        30000                    // oder einfacher:               if (__LOG_DEBUG)              debug(...);
#define L_INFO                        40000                    //
#define L_NOTICE                      50000                    //
#define L_DEBUG                       60000                    //
#define L_ALL                    0x7FFFFFFF                    // INT_MAX: ausdrücklich, da in C++ bereits intern definiert


// Special constants
#define MIN_VALID_POINTER        0x00010000                    // kleinster möglicher Wert für einen gültigen Pointer (x86)
#define MAX_SYMBOL_LENGTH                11


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


// UninitializeReason-Codes                                                                           // MQL5: builds > 509
#define REASON_UNDEFINED                  0                    // no uninitialize reason                 // = REASON_PROGRAM: EA terminated by ExpertRemove()
#define REASON_REMOVE                     1                    // program removed from chart             //
#define REASON_RECOMPILE                  2                    // program recompiled                     //
#define REASON_CHARTCHANGE                3                    // chart symbol or timeframe changed      //
#define REASON_CHARTCLOSE                 4                    // chart closed or template changed       // chart closed
#define REASON_PARAMETERS                 5                    // input parameters changed               //
#define REASON_ACCOUNT                    6                    // account changed                        // account or account settings changed
#define REASON_TEMPLATE                   7                    // n/a                                    // template changed
#define REASON_INITFAILED                 8                    // n/a                                    // OnInit() returned with an error
#define REASON_CLOSE                      9                    // n/a                                    // terminal closed


// Timezones
#define TIMEZONE_ALPARI                   "Alpari"             // bis 03/2012 "Europe/Berlin", ab 04/2012 "Europe/Kiev"
#define TIMEZONE_AMERICA_NEW_YORK         "America/New_York"
#define TIMEZONE_EUROPE_BERLIN            "Europe/Berlin"
#define TIMEZONE_EUROPE_KIEV              "Europe/Kiev"
#define TIMEZONE_EUROPE_LONDON            "Europe/London"
#define TIMEZONE_EUROPE_MINSK             "Europe/Minsk"
#define TIMEZONE_FXT                      "FXT"                // Europe/Kiev   (GMT+0200/+0300) mit DST-Wechseln von America/New_York
#define TIMEZONE_FXT_MINUS_0200           "FXT-0200"           // Europe/London (GMT+0000/+0100) mit DST-Wechseln von America/New_York
#define TIMEZONE_GLOBALPRIME              "GlobalPrime"        // bis 24.10.2015 "FXT", dann durch Fehler "Europe/Kiev" (hoffentlich einmalig)
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
#define TICK_OFFLINE_EA              0x0001                    // 1: Expert:start() wird auch in Offline-Charts getriggert
#define TICK_OFFLINE_REFRESH         0x0010                    // 2: Offline-Charts werden bei jedem Tick refreshed
#define TICK_PAUSE_ON_WEEKEND        0x0100                    // 4: am Wochenende (FXT) werden keine Ticks generiert


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

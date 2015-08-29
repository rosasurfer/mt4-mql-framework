/**
 * In MQL und C++ gemeinsam verwendete Konstanten.
 */

// Log level
#define L_OFF                 0x80000000                    // INT_MIN: ausdrücklich, da in C++ bereits intern definiert
#define L_FATAL                    10000                    //
#define L_ERROR                    20000                    // Tests umgekehrt zu log4j mit: if (__LOG_LEVEL >= msg_level) log(...);
#define L_WARN                     30000                    // oder einfacher:               if (__LOG_DEBUG)              debug(...);
#define L_INFO                     40000                    //
#define L_NOTICE                   50000                    //
#define L_DEBUG                    60000                    //
#define L_ALL                 0x7FFFFFFF                    // INT_MAX: ausdrücklich, da in C++ bereits intern definiert


// Special constants
#define MIN_VALID_POINTER     0x00010000                    // kleinster möglicher Wert für einen gültigen Pointer (x86)
#define MAX_SYMBOL_LENGTH             11


// Moduletyp-Flags
#define MODULETYPE_INDICATOR           1
#define MODULETYPE_EXPERT              2
#define MODULETYPE_SCRIPT              4
#define MODULETYPE_LIBRARY             8                    // kein eigenständiges Programm


// Programm-Typen
#define PROGRAMTYPE_INDICATOR          MODULETYPE_INDICATOR
#define PROGRAMTYPE_EXPERT             MODULETYPE_EXPERT
#define PROGRAMTYPE_SCRIPT             MODULETYPE_SCRIPT


// MQL Root-Funktion-ID's
#define ROOTFUNCTION_INIT              1
#define ROOTFUNCTION_START             2
#define ROOTFUNCTION_DEINIT            3


// MQL Launchtypen eines Programms
#define LAUNCHTYPE_TEMPLATE            1                    // von Template geladen
#define LAUNCHTYPE_PROGRAM             2                    // von iCustom() geladen
#define LAUNCHTYPE_MANUAL              3                    // von Hand geladen


// Timeframe-Identifier
#define PERIOD_M1                      1                    // 1 Minute
#define PERIOD_M5                      5                    // 5 Minuten
#define PERIOD_M15                    15                    // 15 Minuten
#define PERIOD_M30                    30                    // 30 Minuten
#define PERIOD_H1                     60                    // 1 Stunde
#define PERIOD_H4                    240                    // 4 Stunden
#define PERIOD_D1                   1440                    // 1 Tag
#define PERIOD_W1                  10080                    // 1 Woche (7 Tage)
#define PERIOD_MN1                 43200                    // 1 Monat (30 Tage)
#define PERIOD_Q1                 129600                    // 1 Quartal (3 Monate)


// UninitializeReason-Codes                                                                           // MQL5: builds > 509
#define REASON_UNDEFINED               0                    // no uninitialize reason                 // = REASON_PROGRAM: EA terminated by ExpertRemove()
#define REASON_REMOVE                  1                    // program removed from chart             //
#define REASON_RECOMPILE               2                    // program recompiled                     //
#define REASON_CHARTCHANGE             3                    // chart symbol or timeframe changed      //
#define REASON_CHARTCLOSE              4                    // chart closed or template changed       // chart closed
#define REASON_PARAMETERS              5                    // input parameters changed               //
#define REASON_ACCOUNT                 6                    // account changed                        // account or account settings changed
#define REASON_TEMPLATE                7                    // n/a                                    // template changed
#define REASON_INITFAILED              8                    // n/a                                    // OnInit() returned with an error
#define REASON_CLOSE                   9                    // n/a                                    // terminal closed


// Timezones
#define TIMEZONE_ALPARI                "Alpari"             // bis 03.2012 "Europe/Berlin", ab 04.2012 "Europe/Kiev"
#define TIMEZONE_AMERICA_NEW_YORK      "America/New_York"
#define TIMEZONE_EUROPE_BERLIN         "Europe/Berlin"
#define TIMEZONE_EUROPE_KIEV           "Europe/Kiev"
#define TIMEZONE_EUROPE_LONDON         "Europe/London"
#define TIMEZONE_EUROPE_MINSK          "Europe/Minsk"
#define TIMEZONE_FXT                   "FXT"                // Europe/Kiev   (GMT+0200/+0300) mit DST-Wechseln von America/New_York
#define TIMEZONE_FXT_M_0200            "FXT-0200"           // Europe/London (GMT+0000/+0100) mit DST-Wechseln von America/New_York
#define TIMEZONE_GMT                   "GMT"


// Timezone-IDs
#define TIMEZONE_ID_ALPARI             1
#define TIMEZONE_ID_AMERICA_NEW_YORK   2
#define TIMEZONE_ID_EUROPE_BERLIN      3
#define TIMEZONE_ID_EUROPE_KIEV        4
#define TIMEZONE_ID_EUROPE_LONDON      5
#define TIMEZONE_ID_EUROPE_MINSK       6
#define TIMEZONE_ID_FXT                7
#define TIMEZONE_ID_FXT_M_0200         8
#define TIMEZONE_ID_GMT                9

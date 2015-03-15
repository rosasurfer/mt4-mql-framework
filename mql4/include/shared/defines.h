/**
 * In MQL und C++ gemeinsam verwendete Konstanten.
 */

// Special constants
#define MIN_VALID_POINTER  0x00010000           // kleinster möglicher Wert für einen gültigen Pointer (x86)
#define MAX_SYMBOL_LENGTH          11


// Moduletyp-Flags
#define MODULETYPE_INDICATOR        1
#define MODULETYPE_EXPERT           2
#define MODULETYPE_SCRIPT           4
#define MODULETYPE_LIBRARY          8


// MQL Root-Funktion-ID's
#define ROOTFUNCTION_INIT           1
#define ROOTFUNCTION_START          2
#define ROOTFUNCTION_DEINIT         3


// MQL Launchtypen eines Programms
#define LAUNCHTYPE_TEMPLATE         1           // von Template geladen
#define LAUNCHTYPE_PROGRAM          2           // von iCustom() geladen
#define LAUNCHTYPE_MANUAL           3           // von Hand geladen


// Timeframe-Identifier
#define PERIOD_M1                   1           // 1 Minute
#define PERIOD_M5                   5           // 5 Minuten
#define PERIOD_M15                 15           // 15 Minuten
#define PERIOD_M30                 30           // 30 Minuten
#define PERIOD_H1                  60           // 1 Stunde
#define PERIOD_H4                 240           // 4 Stunden
#define PERIOD_D1                1440           // 1 Tag
#define PERIOD_W1               10080           // 1 Woche (7 Tage)
#define PERIOD_MN1              43200           // 1 Monat (30 Tage)
#define PERIOD_Q1              129600           // 1 Quartal (3 Monate)

//
// MQL structure HISTORY_HEADER
//
// typedef struct _HISTORY_HEADER {
//   int  version;               //   4      => hh[ 0]      // HST-Formatversion (MT4: immer 400)
//   char description[64];       //  64      => hh[ 1]      // Beschreibung
//   char symbol[12];            //  12      => hh[17]      // Symbol
//   int  period;                //   4      => hh[20]      // Timeframe
//   int  digits;                //   4      => hh[21]      // Digits
//   int  dbVersion;             //   4      => hh[22]      // Server-Datenbankversion (timestamp)
//   int  prevDbVersion;         //   4      => hh[23]      // LastSync                (timestamp)    // unbenutzt
//   int  reserved[13];          //  52      => hh[24]      //                                        // unbenutzt
// } HISTORY_HEADER, hh;         // 148 byte = int[37]
//

template    "MT4 History Header"
description "Files '*.hst'"

applies_to  file
fixed_start 0

begin
   uint32       "Version"
   char[64]     "Description"
   char[12]     "Symbol"
   uint32       "Timeframe (minutes)"
   uint32       "Digits"
   UNIXDateTime "DbVersion"
   UNIXDateTime "PrevDbVersion"
end

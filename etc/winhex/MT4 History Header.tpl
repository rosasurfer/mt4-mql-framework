//
// MQL structure HISTORY_HEADER
//
// struct HISTORY_HEADER {
//    int    format;             //   4            Barformat, bis Build 509: 400, danach: 401
//    szchar description[64];    //  64            Beschreibung
//    szchar symbol[12];         //  12            Symbol
//    int    period;             //   4            Timeframe
//    int    digits;             //   4            Digits
//    int    syncMark;           //   4            Server-SyncMark (timestamp)
//    int    lastSync;           //   4            LastSync        (unbenutzt)
//    int    timezoneId;         //   4            Timezone-ID (default: 0 => Server-Timezone)
//    BYTE   reserved[48];       //  48            unbenutzt
// };                            // 148 byte
//

template    "MT4 History Header"
description "Files '*.hst'"

applies_to  file
fixed_start 0

begin
   endsection

   uint32       "Format"

   move         64
   char[12]     "Symbol"

   move         -76
   char[64]     "Description"

   move         12
   uint32       "Timeframe (minutes)"
   uint32       "Digits"
   UNIXDateTime "SyncMark"
   UNIXDateTime "LastSync"
   uint32       "Timezone ID"
end

//
// MetaTrader structure HISTORY_HEADER: HistoryFile Header
//
//
// @see  Definition in MT4Expander::Expander.h
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

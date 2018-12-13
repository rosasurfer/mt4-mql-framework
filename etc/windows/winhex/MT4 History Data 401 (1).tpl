//
// MT4 structure HISTORY_BAR_401
//
// HistoryFile Barformat v401 (ab Build 510), entspricht dem MetaQuotes-Struct MqlRates
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 History Data v401 (1)"
description "Files '*.hst'"

applies_to   file
multiple

begin
   endsection

   UnixDateTime "Time"
   move         4
   double       "Open"
   double       "High"
   double       "Low"
   double       "Close"
   int64        "Ticks"
   int32        "Spread"
   int64        "Volume"
end

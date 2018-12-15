//
// MetaTrader structure HISTORY_BAR_400
//
// HistoryFile Barformat v400 (bis Build 509), entspricht dem MetaQuotes-Struct RateInfo
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 History Data v400 (1)"
description "Files '*.hst'"

applies_to   file
multiple

begin
   endsection

   UNIXDateTime "Time"
   double       "Open"
   move         8
   double       "High"
   move         -16
   double       "Low"
   move         8
   double       "Close"
   double       "Ticks"
end

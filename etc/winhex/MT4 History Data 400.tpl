//
// MQL structure HISTORY_BAR_400 (Barformat in "*.hst" bis Build 509)
//
//                                        size
// struct HISTORY_BAR_400 {               ----
//   uint   time;                           4         // Open-Time
//   double open;                           8
//   double low;                            8
//   double high;                           8
//   double close;                          8
//   double volume;                         8         // immer Ganzzahl
// };                                    = 44 byte
//

template    "MT4 History Data v400 (1 bar)"
description "Files '*.hst'"

applies_to  file
fixed_start 148
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
   double       "Volume"
end

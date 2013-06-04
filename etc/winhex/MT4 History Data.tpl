//
// MQL structure BAR (Dateiformat ".hst")
//
//                                        size        offset
// typedef struct _BAR {                  ----        ------
//   int    time;                           4            0        // BarOpen-Time
//   double open;                           8            4
//   double low;                            8           12
//   double high;                           8           20
//   double close;                          8           28
//   double volume;                         8           36        // Double, jedoch immer Ganzzahl
// } BAR, bar;                           = 44 byte
//

template    "MT4 History Data"
description "Files '*.hst'"

applies_to  file
fixed_start 148
multiple

begin
   { endsection
      UNIXDateTime "Time"
      double       "Open"
      move         8
      double       "High"
      move         -16
      double       "Low"
      move         8
      double       "Close"
      double       "Volume"
   }[3]
end

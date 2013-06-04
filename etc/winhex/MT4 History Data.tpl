//
// MQL structure BarInfo
//
// typedef struct _BAR {
//   int    time;       //  4        bar[   0]
//   double open;       //  8        bar[1, 2]
//   double low;        //  8        bar[3, 4]
//   double high;       //  8        bar[5, 6]
//   double close;      //  8        bar[7, 8]
//   double volume;     //  8        bar[9,10]
// } BAR, bar;          // 44 byte = int[  11]
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

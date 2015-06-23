//
// MQL structure HISTORY_BAR_401 (Barformat in "*.hst" nach Build 509)
//
//                                        size
// struct HISTORY_BAR_401 {               ----
//    __int64          time;                8         // Open-Time
//    double           open;                8
//    double           high;                8
//    double           low;                 8
//    double           close;               8
//    unsigned __int64 tickVolume;          8
//    int              spread;              4
//    unsigned __int64 realVolume;          8
// };                                    = 60 bytes
//

template    "MT4 History Data v401"
description "Files '*.hst'"

applies_to  file
fixed_start 148
multiple

begin
   { endsection
      UnixDateTime "Time"
      move         4
      double       "Open"
      double       "High"
      double       "Low"
      double       "Close"
      int64        "TickVolume"
      int32        "Spread"
      int64        "RealVolume"
   }[3]
end

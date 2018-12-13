//
// Structure XTRADE_PIP_BAR (Dateiformat "{Period}.myfx")
//
//                                             size        offset      description
// struct little-endian XTRADE_PIP_BAR {       ----        ------      -------------
//    uint   time;                               4            0        FXT timestamp
//    double open;                               8            4        in pips
//    double high;                               8           12        in pips
//    double low;                                8           20        in pips
//    double close;                              8           28        in pips
// };                                    = 36 byte
//

template    "XTrade Pip Bar Data"
description "Files '{Period}.myfx'"

applies_to file
multiple

begin
   { endsection
      UNIXDateTime "Time FXT"
      double       "Open"
      double       "High"
      double       "Low"
      double       "Close"
   }[8]
end

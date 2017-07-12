//
// Structure XTRADE_PRICE_BAR (Dateiformat "{Period}.myfx")
//
//                                             size        offset      description
// struct little-endian XTRADE_PRICE_BAR {     ----        ------      -------------
//   int    time;                                4            0        FXT-Timestamp
//   int    open;                                4            4        in Points
//   int    high;                                4           16        in Points
//   int    low;                                 4           12        in Points
//   int    close;                               4            8        in Points
//   int    ticks;                               4           20
// };                                    = 24 byte
//

template    "XTrade Price Bar Data"
description "Files '{Period}.myfx'"

applies_to file
multiple

begin
   { endsection
      UNIXDateTime "Time FXT"
      uint32       "Open"
      uint32       "High"
      uint32       "Low"
      uint32       "Close"
      uint32       "Ticks"
   }[8]
end

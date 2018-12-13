//
// Structure XTRADE_TICK (Dateiformat "{Hour}h_ticks.myfx")
//
//                                      size        offset      description
// struct little-endian MYFX_TICK {     ----        ------      ------------------------------------
//    uint timeDelta;                     4            0        milliseconds since start of the hour
//    uint bid;                           4            4        in Points
//    uint ask;                           4            8        in Points
// };                             = 12 byte
//

template    "XTrade Tick Data"
description "Files '{Hour}h_ticks.myfx'"

applies_to file
multiple

begin
   { endsection
      uint32  "TimeDelta (msec)"
      uint32  "Bid"
      uint32  "Ask"
   }[8]
end

//
// Rosatrader structure ROSATRADER_TICK (file format "{Hour}h_ticks.bin")
//
//
// struct ROSATRADER_TICK {             // -- offset --- size --- description -----------------------------------------------
//     uint timeDelta;                  //         0        4     milliseconds since start of the hour
//     uint bid;                        //         4        4     in point
//     uint ask;                        //         8        4     in point
// };                                   // ----------------------------------------------------------------------------------
//                                      //               = 12

template    "Rosatrader Tick Data"
description "Files '{Hour}h_ticks.bin'"

applies_to file
multiple

begin
   { endsection
      uint32  "TimeDelta (msec)"
      uint32  "Bid"
      uint32  "Ask"
   }[8]
end

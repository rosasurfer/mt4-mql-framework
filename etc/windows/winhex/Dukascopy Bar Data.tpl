//
// Structure DUKASCOPY_BAR (file format "BID|ASK_candles_*.bin")
//
//
// struct big-endian DUKASCOPY_BAR {    // -- offset --- size --- description -----------------------------------------------
//     uint  timeDelta;                 //         0        4     time difference in seconds since 00:00 GMT
//     uint  open;                      //         4        4     in point
//     uint  close;                     //         8        4     in point
//     uint  low;                       //        12        4     in point
//     uint  high;                      //        16        4     in point
//     float volume;                    //        20        4     cumulated lotsize per side
// };                                   // ----------------------------------------------------------------------------------
//                                      //               = 24

template    "Dukascopy Bar Data"
description "Files 'BID|ASK_candles_*.bin'"

applies_to  file
big-endian
multiple

begin
   { endsection
      uint32   "TimeDelta (sec)"
      uint32   "Open"
      move  8
      uint32   "High"
      move -8
      uint32   "Low"
      move -8
      uint32   "Close"
      move  8
      float    "Volume"
   }[32]
end

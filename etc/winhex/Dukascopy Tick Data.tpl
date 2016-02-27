//
// Structure DUKASCOPY_TICK (Dateiformat "{Hour}h_ticks.bin")
//
//                                        size        offset      description
// struct big-endian DUKASCOPY_TICK {     ----        ------      -------------------------------------------------
//   uint  timeDelta;                       4            0        Zeitdifferenz in Millisekunden seit Stundenbeginn
//   uint  ask;                             4            4        in Points
//   uint  bid;                             4            8        in Points
//   float askVolume;                       4           12
//   float bidVolume;                       4           16
// };                                    = 20 byte
//

template    "Dukascopy Tick Data"
description "Files '{Hour}h_ticks.bin'"

applies_to  file
big-endian
multiple

begin
   { endsection
      uint32   "TimeDelta (millisec)"
      move  4
      uint32   "Bid"
      move -8
      uint32   "Ask"
      move  8
      float    "BidVol"
      move -8
      float    "AskVol"
      move  4
   }[32]
end

//
// Structure DUKASCOPY_BAR (Dateiformat "BID|ASK_candles_*.bin")
//
//                                        size        offset      description
// struct big-endian DUKASCOPY_BAR {      ----        ------      --------------------------------------
//   uint  timeDelta;                       4            0        Zeitdifferenz in Sekunden zu 00:00 GMT
//   uint  open;                            4            4        in Points
//   uint  close;                           4            8        in Points
//   uint  low;                             4           12        in Points
//   uint  high;                            4           16        in Points
//   float lots                             4           20        kumulierte Angebotsseite in Lots (siehe DUKASCOPY_TICK)
// };                                    = 24 byte
//

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
      float    "Lots"
   }[32]
end

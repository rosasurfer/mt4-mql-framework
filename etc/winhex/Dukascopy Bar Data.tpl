//
// Dukascopy structure BAR (Dateiformat "BID|ASK_candles_*.bin", Big-Endian)
//
//                                        size        offset
// struct BAR {                           ----        ------
//   int    timedelta;                      4            0        // Zeitdifferenz in Sekunden zum Dateistart
//   int    open;                           4            4        // in Points
//   int    close;                          4            8        // in Points
//   int    low;                            4           12        // in Points
//   int    high;                           4           16        // in Points
//   int    volume;                         4           20
// } bar;                                = 24 byte
//

template    "Dukascopy Bar Data"
description "Files 'BID|ASK_candles_*.bin'"

applies_to  file
fixed_start 0
big-endian
multiple

begin
   { endsection
      uint32   "TimeDelta"
      uint32   "Open"
      move  8
      uint32   "High"
      move -8
      uint32   "Low"
      move -8
      uint32   "Close"
      move  8
      uint32   "Volume"
   }[64]
end

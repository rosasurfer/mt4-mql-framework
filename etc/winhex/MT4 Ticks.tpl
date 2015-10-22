//
// MQL structure TICK (Dateiformat "ticks.raw")
//
//                                        size        offset
// struct TICK {                          ----        ------
//   char   symbol[12];                    12            0        // Symbol
//   int    time;                           4           12        // Timestamp
//   double bid;                            8           16
//   double ask;                            8           24
//   int    counter;                        4           32        // fortlaufender Zähler innerhalb der Datei
//   int    reserved[1];                    4           36
// } t;                                  = 40 byte
//

template    "MT4 Ticks"
description "File 'ticks.raw'"

applies_to  file
fixed_start 0
multiple

begin
   { 
   endsection

   char[12]     "Symbol"
   UNIXDateTime "Time"
   double       "Bid"
   double       "Ask"
   uint32       "Counter"
   move 4
   }[unlimited]
end

//
// MT4 structure SUBSCRIBED_SYMBOL (Dateiformat "symbols.sel")
//
//                                        size        offset
// struct SUBSCRIBED_SYMBOL {             ----        ------
//   char   symbol[12];                    12            0        // Symbol
//   int    digits;                         4           12        // Digits
//   int    index;                          4           16        // Index des Symbols in "symbols.raw"
//   char   undocumented[12];              12           20
//   double point;                          8           32        // Point
//   int    spread;                         4           40        // Spread (evt. NULL)
//   char   undocumented[4];                4           44
//   int    tick;                           4           48        // Direction: 0 - Uptick, 1 - Downtick, 2 - n/a
//   char   undocumented[4];                4           52
//   int    time;                           4           56        // Time
//   char   undocumented[4];                4           60
//   double bid;                            8           64        // Bid
//   double ask;                            8           72        // Ask
//   double high;                           8           80        // Session High
//   double low;                            8           88        // Session Low
//   char   reserved[16];                  16           96
//   double bid;                            8          112        // Bid (Wiederholung)
//   double ask;                            8          120        // Ask (Wiederholung)
// } ss;                                = 128 byte
//

template    "MT4 Subscribed Symbols"
description "File 'symbols.sel'"

applies_to  file
fixed_start 0
requires    0 "90 01"               // Version = 400

begin
   move 4
  { endsection
     char[12]     "Symbol"
     move 4
     uint32       "Index (symbols.raw)"
     move -8
     uint32       "Digits"
     move 4
     hex 12       "(undocumented)"
     double       "Point"
     uint32       "Spread"
     hex  4       "(undocumented)"
     uint32       "Tick: 0 - Up, 1 - Down, 2 - n/a"
     hex  4       "(undocumented)"
     UNIXDateTime "Time"
     hex  4       "(undocumented)"
     double       "Bid"
     double       "Ask"
     double       "Session High"
     double       "Session Low"
     move 32
  }[128]


//{ char[12]     "Symbol"
//  move 28
//  uint32       "Spread"
//  move 84
//}[128]
end

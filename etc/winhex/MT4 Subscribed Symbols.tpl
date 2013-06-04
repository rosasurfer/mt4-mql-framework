//
// MQL structure SYMBOL_SUBSCRIBED (Dateiformat "symbols.sel")
//
//                                        size        offset
// typedef struct _SYMBOL_SUBSCRIBED {    ----        ------
//   char   symbol[12];                    12            0        // Symbol
//   int    digits;                         4           12        // Digits
//   char   undocumented[16];              16           16
//   double point;                          8           32        // Point (oder TickSize ???)
//   char   undocumented[16];              16           40
//   int    time;                           4           56        // Time
//   char   undocumented[4];                4           60
//   double bid;                            8           64        // Bid
//   double ask;                            8           72        // Ask
//   double high;                           8           80        // Session High
//   double low;                            8           88        // Session Low
//   char   undocumented[16];              16           96
//   double bid;                            8          112        // Bid (Wiederholung)
//   double ask;                            8          120        // Ask (Wiederholung)
// } SYMBOL_SUBSCRIBED, ss;             = 128 byte
//

template    "MT4 Subscribed Symbols"
description "File 'symbols.sel'"

applies_to  file
fixed_start 0
requires    0 "90 01"      // Version = 400

begin
   move 4
   { endsection
      char[12]     "Symbol"
      uint32       "Digits"
      hex 16       "(undocumented)"
      double       "Point"
      hex 16       "(undocumented)"
      UNIXDateTime "Time"
      hex  4       "(undocumented)"
      double       "Bid"
      double       "Ask"
      double       "Session High"
      double       "Session Low"
      hex 16       "(undocumented)"
      double       "Bid"
      double       "Ask"
   }[6]
end

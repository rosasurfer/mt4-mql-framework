//
// MQL structure SYMBOL_SUBSCRIBED (Dateiformat "symbols.sel")
//
//                                        size        offset
// typedef struct _SYMBOL_SUBSCRIBED {    ----        ------
//   char symbol[12];                      12            0        // Symbol
// } SYMBOL_SUBSCRIBED, ss;             = 128 byte
//

template    "MT4 Subscribed Symbols"
description "File 'symbols.sel'"

applies_to  file
fixed_start 0

begin
   { endsection
      char[12] "Symbol"
   }[4]
end

//
// MQL structure SYMBOL (Dateiformat "symbols.raw")
//
//                                        size        offset
// typedef struct _SYMBOL {               ----        ------
// } SYMBOL, symbol;
//

template    "MT4 Symbols"
description "File 'symbols.raw'"

applies_to  file
fixed_start 0

begin
   { endsection
      char[12] "Symbol"
   }[4]
end

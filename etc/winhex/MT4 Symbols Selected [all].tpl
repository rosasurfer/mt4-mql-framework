//
// MT4 structure SYMBOL_SELECTED: Dateiformat "symbols.sel"
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 Symbols Selected [all]"
description "File 'symbols.sel'"

applies_to   file
fixed_start  4
requires    -4 "90 01"              // Version = 400

begin
   numbering 1

   { endsection

   char[12]     "Symbol  ~"
   move 4
   uint32       "Symbol Index"
   hex  4       "(undocumented)"
   uint32       "Group Index"
   hex  4       "(undocumented)"
   move -20
   uint32       "Digits"
   move 16
   double       "Point"
   int32        "Spread"
   hex  4       "(undocumented)"
   uint32       "Tick Type: 0=Up, 1=Down, 2=n/a"
   hex  4       "(undocumented)"
   UNIXDateTime "Time"
   hex  4       "(undocumented)"
   double       "Bid"
   double       "Ask"
   double       "Session High"
   double       "Session Low"
   move 32
   }[unlimited]
end

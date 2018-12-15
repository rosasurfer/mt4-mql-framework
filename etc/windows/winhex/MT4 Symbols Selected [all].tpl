//
// MetaTrader structure SYMBOL_SELECTED: Dateiformat "symbols.sel"
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
      uint32       "Array Key"
      uint32       "(undocumented DWORD)"

      uint32       "Group Index"
      uint32       "(undocumented DWORD)"

      move -20
      uint32       "Digits"
      move 16
      double       "Point"
      uint32       "Fixed Spread"
      uint32       "(undocumented DWORD)"

      uint32       "Tick Type: 0=Up, 1=Down, 2=n/a"
      uint16       "(undocumented WORD)"
      uint16       "(undocumented WORD)"

      UNIXDateTime "Time"
      uint32       "(undocumented DWORD)"
      double       "Bid"
      double       "Ask"
      double       "Session High"
      double       "Session Low"
      hex  16      "(undocumented)"
      double       "Bid"                                // Bid und Ask werden wiederholt
      double       "Ask"
   }[unlimited]
end

//
// MetaTrader structure SYMBOL_GROUP: file format of "symgroups.raw"
//
// The file size is fixed, a file always contains 32 groups. Unused group entries are empty (zeroed).
//
//
// @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/mt4/SymbolGroup.h
//

template    "MT4 Symbol Groups"
description "File 'symgroups.raw'"

applies_to  file
fixed_start 0

begin
   { endsection
      char[16] "Name  ~"
      char[60] "Description"           // original size: 64
      hex 4    "Background Color"      // custom
   }[unlimited]
end

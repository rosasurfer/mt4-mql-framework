//
// MT4 structure SYMBOL_GROUP: Dateiformat "symgroups.raw"
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 Symbol Groups"
description "File 'symgroups.raw'"

applies_to  file
fixed_start 0

begin
   { endsection

   char[16] "Name  ~"
   char[64] "Description"
   }[unlimited]
end

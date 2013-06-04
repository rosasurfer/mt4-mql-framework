//
// MQL structure SYMBOL_GROUP (Dateiformat "symgroups.raw")
//
// typedef struct _SYMBOL_GROUP {
//   char name       [16];       //  16      => grp[ 0]     // Name
//   char description[64];       //  64      => grp[ 4]     // Beschreibung
// } SYMBOL_GROUP, symbol.grp;   //  80 byte =  int[20]
//

template    "MT4 Symbol Groups"
description "File 'symgroups.raw'"

applies_to  file
fixed_start 0

begin
   { endsection
      char[16] "Name"
      char[64] "Description"
   }[32]
end

//
// MQL structure SYMBOL_GROUP (Dateiformat "symgroups.raw")
//
//                                        size        offset
// typedef struct _SYMBOL_GROUP {         ----        ------
//   char name       [16];                 16            0        // Name
//   char description[64];                 64            4        // Beschreibung
// } SYMBOL_GROUP, sg;                   = 80 byte
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

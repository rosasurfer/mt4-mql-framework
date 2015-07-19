//
// MT4 structure SYMBOL: Dateiformat "symbols.raw"
//
// Die Symbole in der Datei sind alphabetisch nach Symbolnamen sortiert.
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 Symbols"
description "File 'symbols.raw'"

applies_to  file
fixed_start 0

begin
   { endsection
                                 // -------------- offset -
   char[12] "Symbol  ~"          //                     0
   char[64] "Description"        //                    64
   char[12] "Symbol (alt)"       //                    76
   char[12] "Base Currency"      //                    88
   uint32   "Group Index"        //                   100
   uint32   "Digits"             //                   104

   move 1532                     //                   108
   double   "?"                  //                  1640

   move 12                       //                  1648
   uint32   "Fixed Spread"       //                  1660

   move 16                       //                  1664
   double   "Swap Long"          //                  1680
   double   "Swap Short"         //                  1688

   uint32   "?"                  //                  1696
   move 4                        //                  1700
   double   "Lot Size"           //                  1704
   move 16                       //                  1712
   uint32   "Stop Level"         //                  1728
   move 12                       //                  1732
   double   "Margin Init"        //                  1744
   double   "Margin Maintenance" //                  1752
   double   "Margin Hedged"      //                  1760

   double   "?"                  //                  1768
   double   "Point Size"         //                  1776
   double   "Points per Unit"    //                  1784

   move 24                       //                  1792
   char[12] "Currency"           //                  1816

   move 104                      //                  1828
   uint32   "?"                  //                  1932
   }[unlimited]                  // sizeof(SYMBOL) = 1936
end

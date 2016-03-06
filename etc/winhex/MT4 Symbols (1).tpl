//
// MT4 structure SYMBOL: Dateiformat "symbols.raw"
//
// Die Symbole in der Datei sind alphabetisch nach Symbolnamen sortiert.
//
//
// @see  Definition in MT4Expander::Expander.h
//

template    "MT4 Symbols (1)"
description "File 'symbols.raw'"

applies_to  file
multiple

begin
   { endsection                     // -------------- offset -
      char[12] "Symbol"             //                     0
      char[54] "Description"        //                    12

      move 50                       //                    66
      uint32   "ID"                 //                   116
      move -54                      //                   120

      char[10] "origin"             //                    66
      char[12] "Alt Symbol"         //                    76
      char[12] "Base Currency"      //                    88
      uint32   "Group"              //                   100
      uint32   "Digits"             //                   104

      uint32   "Trade Mode"         //                   108
      hex 4    "Background Color"   //                   112

      move 1524                     //                   116
      double   "?"                  //                  1640

      move 12                       //                  1648
      uint32   "Spread"             //                  1660

      move 16                       //                  1664
      double   "Swap Long"          //                  1680
      double   "Swap Short"         //                  1688

      uint32   "?"                  //                  1696
      move 4                        //                  1700
      double   "Contract Size"      //                  1704
      move 16                       //                  1712
      uint32   "Stop Distance"      //                  1728
      move 12                       //                  1732
      double   "Margin Init"        //                  1744
      double   "Margin Maintenance" //                  1752
      double   "Margin Hedged"      //                  1760
      double   "Margin Divider"     //                  1768

      double   "Point Size"         //                  1776
      double   "Points per Unit"    //                  1784

      move 24                       //                  1792
      char[12] "Margin Currency"    //                  1816

      move 104                      //                  1828
      uint32   "?"                  //                  1932
   }                                // sizeof(SYMBOL) = 1936
end

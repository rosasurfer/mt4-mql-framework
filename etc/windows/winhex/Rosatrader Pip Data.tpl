//
// Rosatrader structure ROSATRADER_PIP (file format "{Period}.bin")
//
//
// struct ROSATRADER_PIP {              // -- offset --- size --- description -----------------------------------------------
//     uint   time;                     //         0        4     timestamp (FXT)
//     double open;                     //         4        8     in pip
//     double high;                     //        12        8     in pip
//     double low;                      //        20        8     in pip
//     double close;                    //        28        8     in pip
// };                                   // ----------------------------------------------------------------------------------
//                                      //               = 36

template    "Rosatrader Pip Data"
description "Files '{Period}.bin'"

applies_to file
multiple

begin
   { endsection
      UNIXDateTime "Time FXT"
      double       "Open"
      double       "High"
      double       "Low"
      double       "Close"
   }[8]
end

//
// RSX structure RSX_PRICE_BAR (file format "{Period}.dat")
//
//
// struct RSX_PRICE_BAR {               // -- offset --- size --- description -----------------------------------------------
//     int time;                        //         0        4     timestamp (FXT)
//     int open;                        //         4        4     in point
//     int high;                        //        16        4     in point
//     int low;                         //        12        4     in point
//     int close;                       //         8        4     in point
//     int ticks;                       //        20        4
// };                                   // ----------------------------------------------------------------------------------
//                                      //               = 24

template    "RSX Price Bar Data"
description "Files '{Period}.dat'"

applies_to file
multiple

begin
   { endsection
      UNIXDateTime "Time FXT"
      uint32       "Open"
      uint32       "High"
      uint32       "Low"
      uint32       "Close"
      uint32       "Ticks"
   }[8]
end

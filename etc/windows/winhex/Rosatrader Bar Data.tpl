//
// Rosatrader structure ROSATRADER_BAR (file format "{Period}.bin")
//
//
// struct ROSATRADER_BAR {              // -- offset --- size --- description -----------------------------------------------
//     int time;                        //         0        4     timestamp (FXT)
//     int open;                        //         4        4     in point
//     int high;                        //        16        4     in point
//     int low;                         //        12        4     in point
//     int close;                       //         8        4     in point
//     int ticks;                       //        20        4
// };                                   // ----------------------------------------------------------------------------------
//                                      //               = 24

template    "Rosatrader Bar Data"
description "Files '{Period}.bin'"

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

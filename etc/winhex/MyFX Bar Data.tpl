//
// Structure MYFX_BAR (Dateiformat "M1,Bid|Ask|Median.bin", Little-Endian)
//
//                                        size        offset
// struct MYFX_BAR {                      ----        ------
//   int    time;                           4            0        // FXT-Timestamp
//   int    open;                           4            4        // in Points
//   int    high;                           4           16        // in Points
//   int    low;                            4           12        // in Points
//   int    close;                          4            8        // in Points
//   int    volume;                         4           20        // in Lots
// };                                    = 24 byte
//

template    "XTrade Bar Data"
description "Files 'M1,Bid|Ask|Median.bin'"

applies_to file
multiple

begin
   { endsection
   
   UNIXDateTime "Time FXT"
   uint32       "Open"
   uint32       "High"
   uint32       "Low"
   uint32       "Close"
   uint32       "Volume"
   }[32]
end

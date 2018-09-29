/**
 * TestScript
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iChangedBars.mqh>
#include <win32api.mqh>


#import "rsfExpander.Release.dll"
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   int mode = 5;

   if (!(mode & (FILE_READ|FILE_WRITE))) {
      debug("onStart(1)  invalid mode="+ mode +" (must be FILE_READ="+ FILE_READ +", FILE_WRITE="+ FILE_WRITE +" or FILE_READ|FILE_WRITE="+ (FILE_READ|FILE_WRITE));
      return(last_error);
   }

   mode &= (FILE_READ|FILE_WRITE);
   debug("onStart(2)  mode="+ mode +" (alle anderen Bits gelöscht)");

   bool read_only  = !(mode &  FILE_WRITE);
   bool read_write =  (mode & (FILE_READ|FILE_WRITE) == (FILE_READ|FILE_WRITE));
   bool write_only = !(mode &  FILE_READ);

   debug("onStart(3)  ro="+ read_only +"  rw="+ read_write +"  wo="+ write_only);


   return(last_error);


   double value;
   string format;

   value  = 9.567;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));

   value  = 9.456;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));


   value  = -9.567;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));

   value  = -9.456;
   format = "+R3";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));
   format = "+R.0";
   debug("onStart()  NumberToStr("+ NumberToStr(value, ".+") +", "+ DoubleQuoteStr(format) +") = "+ NumberToStr(value, format));

   return(last_error);


   int cb1, cb2;
   cb1 = iChangedBars(NULL, PERIOD_M15, F_ERR_SERIES_NOT_AVAILABLE);
   cb2 = iChangedBars("EURUSD", PERIOD_M30, F_ERR_SERIES_NOT_AVAILABLE);
   debug("onStart()  changedBars(M15)="+ cb1 +"  changedBars(M30)="+ cb2);

   cb1 = iChangedBars(NULL, PERIOD_M15, F_ERR_SERIES_NOT_AVAILABLE);
   cb2 = iChangedBars("EURUSD", PERIOD_M30, F_ERR_SERIES_NOT_AVAILABLE);
   debug("onStart()  changedBars(M15)="+ cb1 +"  changedBars(M30)="+ cb2);
   return(catch("onStart(1)"));

   iChangedBars(NULL, NULL);
}

/**
 * MA Tunnel Monitor
 *
 * A signal monitor for an "MA Tunnel" setup.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string __a____________________________ = "=== MA 1 =====================================";
extern bool   UseMA1                          = true;
extern int    MA1.Periods                     = 9;
extern string MA1.Method                      = "SMA | LWMA | EMA* | SMMA";
extern string MA1.AppliedPrice                = "Open | High | Low | Close | Median* | Typical | Weighted";

extern string __b____________________________ = "=== MA 2 =====================================";
extern bool   UseMA2                          = true;
extern int    MA2.Periods                     = 36;
extern string MA2.Method                      = "SMA | LWMA | EMA* | SMMA";
extern string MA2.AppliedPrice                = "Open | High | Low | Close | Median* | Typical | Weighted";

extern string __c____________________________ = "=== MA 3 =====================================";
extern bool   UseMA3                          = true;
extern int    MA3.Periods                     = 144;
extern string MA3.Method                      = "SMA | LWMA | EMA* | SMMA";
extern string MA3.AppliedPrice                = "Open | High | Low | Close | Median* | Typical | Weighted";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window
#property indicator_buffers   1
#property indicator_color1    CLR_NONE

int ma1Periods;
int ma1Method;
int ma1AppliedPrice;

int ma2Periods;
int ma2Method;
int ma2AppliedPrice;

int ma3Periods;
int ma3Method;
int ma3AppliedPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // input validation
   if (UseMA1) {
      // MA1.Periods
      if (MA1.Periods < 1)                                         return(catch("onInit(1)  invalid input parameter MA1.Periods: "+ MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
      ma1Periods = MA1.Periods;
      // MA1.Method
      string sValues[], sValue = MA1.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         int size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma1Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (ma1Method == -1)                                         return(catch("onInit(2)  invalid input parameter MA1.Method: "+ DoubleQuoteStr(MA1.Method), ERR_INVALID_INPUT_PARAMETER));
      MA1.Method = MaMethodDescription(ma1Method);
      // MA1.AppliedPrice
      sValue = MA1.AppliedPrice;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      if (sValue == "") sValue = "close";                          // default price type
      ma1AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma1AppliedPrice==-1 || ma1AppliedPrice > PRICE_WEIGHTED) return(catch("onInit(3)  invalid input parameter MA1.AppliedPrice: "+ DoubleQuoteStr(MA1.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
      MA1.AppliedPrice = PriceTypeDescription(ma1AppliedPrice);
   }

   if (UseMA2) {
      // MA2.Periods
      if (MA2.Periods < 1)                                         return(catch("onInit(4)  invalid input parameter MA2.Periods: "+ MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
      ma2Periods = MA2.Periods;
      // MA2.Method
      sValue = MA2.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma2Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (ma2Method == -1)                                         return(catch("onInit(5)  invalid input parameter MA2.Method: "+ DoubleQuoteStr(MA2.Method), ERR_INVALID_INPUT_PARAMETER));
      MA2.Method = MaMethodDescription(ma2Method);
      // MA2.AppliedPrice
      sValue = MA2.AppliedPrice;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      if (sValue == "") sValue = "close";                          // default price type
      ma2AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma2AppliedPrice==-1 || ma2AppliedPrice > PRICE_WEIGHTED) return(catch("onInit(6)  invalid input parameter MA2.AppliedPrice: "+ DoubleQuoteStr(MA2.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
      MA2.AppliedPrice = PriceTypeDescription(ma2AppliedPrice);
   }

   if (UseMA3) {
      // MA3.Periods
      if (MA3.Periods < 1)                                         return(catch("onInit(7)  invalid input parameter MA3.Periods: "+ MA3.Periods, ERR_INVALID_INPUT_PARAMETER));
      ma3Periods = MA3.Periods;
      // MA3.Method
      sValue = MA3.Method;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      ma3Method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
      if (ma3Method == -1)                                         return(catch("onInit(8)  invalid input parameter MA3.Method: "+ DoubleQuoteStr(MA3.Method), ERR_INVALID_INPUT_PARAMETER));
      MA3.Method = MaMethodDescription(ma3Method);
      // MA3.AppliedPrice
      sValue = MA3.AppliedPrice;
      if (Explode(sValue, "*", sValues, 2) > 1) {
         size = Explode(sValues[0], "|", sValues, NULL);
         sValue = sValues[size-1];
      }
      if (sValue == "") sValue = "close";                          // default price type
      ma3AppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
      if (ma3AppliedPrice==-1 || ma3AppliedPrice > PRICE_WEIGHTED) return(catch("onInit(9)  invalid input parameter MA3.AppliedPrice: "+ DoubleQuoteStr(MA3.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
      MA3.AppliedPrice = PriceTypeDescription(ma3AppliedPrice);
   }

   // signal configuration
   // buffer management
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("UseMA1=",           BoolToStr(UseMA1),                ";", NL,
                            "MA1.Periods=",      MA1.Periods,                      ";", NL,
                            "MA1.Method=",       DoubleQuoteStr(MA1.Method),       ";", NL,
                            "MA1.AppliedPrice=", DoubleQuoteStr(MA1.AppliedPrice), ";", NL,
                            "UseMA2=",           BoolToStr(UseMA2),                ";", NL,
                            "MA2.Periods=",      MA2.Periods,                      ";", NL,
                            "MA2.Method=",       DoubleQuoteStr(MA2.Method),       ";", NL,
                            "MA2.AppliedPrice=", DoubleQuoteStr(MA2.AppliedPrice), ";", NL,
                            "UseMA3=",           BoolToStr(UseMA3),                ";", NL,
                            "MA3.Periods=",      MA3.Periods,                      ";", NL,
                            "MA3.Method=",       DoubleQuoteStr(MA3.Method),       ";", NL,
                            "MA3.AppliedPrice=", DoubleQuoteStr(MA3.AppliedPrice), ";")
   );
}

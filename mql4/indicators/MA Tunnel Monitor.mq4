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


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   return(catch("onDeinit(1)"));
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

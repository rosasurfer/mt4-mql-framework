/**
 * FX Volume
 *
 * Displays real FX volume from the BankersFX data feed.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Dummy = 12;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#property indicator_separate_window
#property indicator_level1  20

#property indicator_buffers 4

#property indicator_width1  1
#property indicator_width2  0
#property indicator_width3  2
#property indicator_width4  2

double bufferMACD[];
double bufferTrend[];
double bufferUpper[];
double bufferLower[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(catch("onTick(1)"));
}


/**
 * Return a string representation of the input parameters (logging).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",
                            "Dummy=", Dummy, "; ")
   );
}

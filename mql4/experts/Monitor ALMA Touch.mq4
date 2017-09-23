/**
 * Monitor the market for an ALMA crossing and execute a trade command.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int    ALMA.Periods                    = 38;
extern string ALMA.Timeframe                  = "M5";             // M1 | M5 | M15...
extern string _1_____________________________ = "";
extern string Open.Direction                  = "long | short";
extern double Open.Lots                       = 0.01;
extern string Open.MagicNumber                = "";
extern string Open.Comment                    = "";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <functions/EventListener.BarOpen.MTF.mqh>
#include <functions/JoinStrings.mqh>
#include <iCustom/icMovingAverage.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/xtrade/LFXOrder.mqh>


int ma.periods;
int ma.timeframe;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) initialize trade account
   if (!InitTradeAccount())
      return(last_error);

   // (2) validate input parameters
   // ALMA.Periods
   if (ALMA.Periods < 2)   return(catch("onInit(1)  Invalid input parameter ALMA.Periods = "+ ALMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = ALMA.Periods;

   // ALMA.Timeframe
   ma.timeframe = StrToTimeframe(ALMA.Timeframe, MUTE_ERR_INVALID_PARAMETER);
   if (ma.timeframe == -1) return(catch("onInit(2)  Invalid input parameter ALMA.Timeframe = "+ DoubleQuoteStr(ALMA.Timeframe), ERR_INVALID_INPUT_PARAMETER));
   ALMA.Timeframe = TimeframeDescription(ma.timeframe);

   // Open | Close | Hedge

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(last_error);
}

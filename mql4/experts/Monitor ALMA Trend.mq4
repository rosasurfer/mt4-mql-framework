/**
 * Monitor the market for an ALMA trend change and execute a trade command.
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
extern string _2_____________________________ = "";
extern string Close.Tickets                   = "";               // one or multiple tickets
extern string _3_____________________________ = "";
extern string Hedge.Tickets                   = "";               // one or multiple tickets

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <functions/JoinStrings.mqh>
#include <iCustom/icMovingAverage.mqh>
#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/myfx/LFXOrder.mqh>


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
   if (ma.timeframe == -1) return(catch("onInit(2)  Invalid input parameter ALMA.Timeframe = \""+ ALMA.Timeframe +"\"", ERR_INVALID_INPUT_PARAMETER));
   ALMA.Timeframe = TimeframeDescription(ma.timeframe);

   return(catch("onInit(3)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check ALMA trend on BarOpen of current timeframe
   if (1 || EventListener.BarOpen()) {
      debug("onTick(1)  BarOpen");

      int timeframe = ma.timeframe;
      int maxValues = 10;
      int iBar      = 1;
      int trend = icMovingAverage(timeframe, ALMA.Periods, ALMA.Timeframe, MODE_ALMA, PRICE_CLOSE, maxValues, MovingAverage.MODE_TREND, iBar);
      debug("onTick(2)  ALMA trend: "+ trend);

      if (trend == 1) {
         // ALMA turned up
      }
      else if (trend == -1) {
         // ALMA turned down
      }
   }
   return(last_error);
}

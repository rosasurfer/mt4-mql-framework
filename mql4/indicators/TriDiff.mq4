/**
 * TriDiff
 *
 * @origin  https://futures.io/download/metatrader/mt4-mq4-indicators/1281-download.html
 */


// #######################################################################################
// # Author:    glennw (bigmiketrading.com)                                              #
// # Indicator: GW_TriDiff  Version: 1.0                                                 #
// # Timeframe: Any                                                                      #
// #                                                                                     #
// # This indicator is the plot of the difference between a triangular moving average    #
// # and a weighted moving average. There is a fast and slow plot The slow plot denotes  #
// # the longer term trend (cyan line) being above or below zero line.There is a cloud   #
// # function to help visulize the longer term trend above and below the zeroline        #
// # (Red = downtrend, yellow = uptrend).                                                #
// # You can use it to scalp by playing crossovers of the cyan line and the signal line  #
// # (gray). The orange line being above/below zero is confirmation of the trade         #
// # direction. You must wait for bar to close. Don't try to catch the exact top/bottom. #
// # Stop is low/high of signal bar or whatever you use. For higher probability trades   #
// # only take setups in the direction of the longer term trend. I always exit when      #
// # price breaks the low/high of the previous bar and crosses the 5 period offset       #
// # moving average or crosses and closes above/below the 5 period ATR Stop with a 1.5   #
// # range multiplier.                                                                   #
// #######################################################################################
//
// input length     =  6;
// input slowlength = 30;
// input smooth     =  3;
// input wmaPeriods =  3;
//
// def effectiveLength     = Ceil((length + 1) / 2);
// def effectiveLengthslow = Ceil((slowlength + 1) / 2);
//
// def wma     = WMA(PRICE_CLOSE, wmaPeriods);
// def tma     = SMA(SMA(PRICE_CLOSE, effectiveLength    ), effectiveLength    );
// def tmaSlow = SMA(SMA(PRICE_CLOSE, effectiveLengthslow), effectiveLengthslow);
//
// plot iTriDiff     = wma - tma;
// plot iTriDiffSlow = wma - tmaSlow;              // STYLE_HISTOGRAM
// plot iSignal      = SMA(iTriDiffSlow, smooth);


//#include <stddefine.mqh>
//int   __INIT_FLAGS__[];
//int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////// Configuration ///////////////////////////////////////////////////////////////

extern int LMA.Periods =  6;
extern int TMA.Periods = 20;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//#include <core/indicator.mqh>
//#include <stdfunctions.mqh>


///---- Properties
#property indicator_separate_window
#property indicator_buffers         3
#property indicator_color1          LimeGreen      // GW_TriDiffslowU
#property indicator_color2          Red            // GW_TriDiffslowD
#property indicator_color3          DodgerBlue     // GW_TriDiffSlow

#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 1

#property indicator_style3 STYLE_DOT


//---- Buffers
double bufferTriDiff    [];
double bufferTriDiffUp  [];
double bufferTriDiffDown[];
double bufferTMA.sma    [];


/**
 *
 */
int init() {
   // Total buffers
   IndicatorBuffers(4);

   // drawing settings
   SetIndexBuffer(0, bufferTriDiffUp  ); SetIndexStyle(0, DRAW_HISTOGRAM);
   SetIndexBuffer(1, bufferTriDiffDown); SetIndexStyle(1, DRAW_HISTOGRAM);
   SetIndexBuffer(2, bufferTriDiff    ); SetIndexStyle(2, DRAW_LINE     );

   // one additional indicator buffer
   SetIndexBuffer(3, bufferTMA.sma);

   // name for Data Window
   IndicatorShortName("MACD: LMA("+ LMA.Periods +"), TMA("+ TMA.Periods +")  ");

   return(0);
}


/**
 *
 */
int start() {
   int limit;
   int counted_bars = IndicatorCounted();

   if (counted_bars > 0)
      counted_bars--;
   limit = Bars-counted_bars;

    int tma.periods.1 = TMA.Periods / 2;
    int tma.periods.2 = TMA.Periods - tma.periods.1 + 1;

   for (int bar=0; bar < limit; bar++) {
      bufferTMA.sma[bar] = iMA(NULL, 0, tma.periods.1, 0, MODE_SMA, PRICE_CLOSE, bar);
   }

   for (bar=0; bar < limit; bar++) {
      double wma = iMA(NULL, 0, LMA.Periods, 0, MODE_LMA, PRICE_CLOSE, bar);
      double tma = iMAOnArray(bufferTMA.sma, Bars, tma.periods.2, 0, MODE_SMA, bar);
      bufferTriDiff[bar] = wma - tma;

    if (bufferTriDiff[bar] > 0) bufferTriDiffUp  [bar] = bufferTriDiff[bar];
    else                            bufferTriDiffDown[bar] = bufferTriDiff[bar];
   }
   return(0);
}

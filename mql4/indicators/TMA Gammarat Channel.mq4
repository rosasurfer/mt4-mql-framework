/**
 * TMA Gammarat Channel
 *
 * An asymmetric non-standard deviation channel around a shifted and repainting Triangular Moving Average (TMA). The TMA is a
 * twice applied Simple Moving Average (SMA) who's resulting MA weights form the shape of a triangle. It holds:
 *
 *  TMA(n) = SMA(floor(n/2)+1) of SMA(ceil(n/2))
 *
 * @link  https://user42.tuxfamily.org/chart/manual/Triangular-Moving-Average.html#               [Triangular Moving Average]
 * @link  https://forex-station.com/viewtopic.php?f=579496&t=8423458#                    [Centered Triangular Moving Average]
 * @link  http://www.gammarat.com/Forex/#                                                                    [GammaRat Forex]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods       = 9;                // 111
extern string MA.AppliedPrice  = "Open | High | Low | Close | Median | Typical | Weighted*";

extern double Bands.Deviations = 2.5;
extern color  Bands.Color      = Magenta;          // LightSkyBlue
extern int    Bands.LineWidth  = 1;                // 3
extern string __a___________________________;

extern bool   RepaintingMode   = true;             // toggle repainting mode
extern bool   MarkReversals    = true;
extern int    Max.Bars         = 5000;             // max. values to calculate (-1: all available)
extern string __b___________________________;

extern bool   AlertsOn         = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Bands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/ManageIndicatorBuffer.mqh>

#define MODE_TMA_RP              0                 // indicator buffer ids
#define MODE_UPPER_BAND_RP       1                 //
#define MODE_LOWER_BAND_RP       2                 //
#define MODE_UPPER_BAND_NRP      3                 //
#define MODE_LOWER_BAND_NRP      4                 //
#define MODE_REVERSAL_MARKER     5                 //
#define MODE_REVERSAL_AGE        6                 //
#define MODE_UPPER_VARIANCE_RP   7                 //
#define MODE_LOWER_VARIANCE_RP   8                 // managed by the framework

#property indicator_chart_window
#property indicator_buffers   7                    // buffers visible to the user
int       terminal_buffers  = 8;                   // buffers managed by the terminal
int       framework_buffers = 1;                   // buffers managed by the framework

#property indicator_color1    Magenta              // repainting TMA
#property indicator_color2    CLR_NONE             // repainting upper channel band
#property indicator_color3    CLR_NONE             // repainting lower channel band
#property indicator_color4    Blue                 // non-repainting upper channel band
#property indicator_color5    Blue                 // non-repainting lower channel band
#property indicator_color6    Magenta              // price reversals

#property indicator_style1    STYLE_DOT

#property indicator_width6    2                    // reversal markers

double tmaRP          [];
double upperVarianceRP[];
double lowerVarianceRP[];
double upperBandRP    [];
double lowerBandRP    [];
double upperBandNRP   [];
double lowerBandNRP   [];

double reversalMarker[];
double reversalAge   [];

int    maPeriods;
int    maAppliedPrice;
int    maxValues;
double tmaWindow[];

string indicatorName;
string legendLabel;

// debug settings                                  // see ::afterInit()
bool   test.onSignalPause = false;                 // whether to pause a test on a signal


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // MA.Periods
   if (MA.Periods < 1)                                        return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (MA.Periods & 1 == 0)                                   return(catch("onInit(2)  invalid input parameter MA.Periods: "+ MA.Periods +" (must be an odd value)", ERR_INVALID_INPUT_PARAMETER));
   maPeriods = MA.Periods;
   // MA.AppliedPrice
   string sValues[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_WEIGHTED) return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Bands.Deviations
   if (Bands.Deviations < 0)                                  return(catch("onInit(4)  invalid input parameter Bands.Deviations: "+ NumberToStr(Bands.Deviations, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   // Bands.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;
   // Bands.LineWidth
   if (Bands.LineWidth < 0)                                   return(catch("onInit(5)  invalid input parameter Bands.LineWidth: "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Bands.LineWidth > 5)                                   return(catch("onInit(6)  invalid input parameter Bands.LineWidth: "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   // Max.Bars
   if (Max.Bars < -1)                                         return(catch("onInit(7)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_TMA_RP,            tmaRP          ); SetIndexEmptyValue(MODE_TMA_RP,          0);
   SetIndexBuffer(MODE_UPPER_BAND_RP,     upperBandRP    ); SetIndexEmptyValue(MODE_UPPER_BAND_RP,   0);
   SetIndexBuffer(MODE_LOWER_BAND_RP,     lowerBandRP    ); SetIndexEmptyValue(MODE_LOWER_BAND_RP,   0);
   SetIndexBuffer(MODE_UPPER_BAND_NRP,    upperBandNRP   ); SetIndexEmptyValue(MODE_UPPER_BAND_NRP,  0);
   SetIndexBuffer(MODE_LOWER_BAND_NRP,    lowerBandNRP   ); SetIndexEmptyValue(MODE_LOWER_BAND_NRP,  0);
   SetIndexBuffer(MODE_REVERSAL_MARKER,   reversalMarker ); SetIndexEmptyValue(MODE_REVERSAL_MARKER, 0);
   SetIndexBuffer(MODE_REVERSAL_AGE,      reversalAge    ); SetIndexEmptyValue(MODE_REVERSAL_AGE,    0);
   SetIndexBuffer(MODE_UPPER_VARIANCE_RP, upperVarianceRP);                                              // not visible

   // chart legend
   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // names, labels and display options
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = "TMA("+ maPeriods + sAppliedPrice +") Gammarat Channel"+ ifString(RepaintingMode, " RP", " NRP");
   string shortName = "TMA("+ maPeriods +") Gammarat Channel";
   IndicatorShortName(shortName);                           // chart tooltips and context menu
   SetIndexLabel(MODE_TMA_RP,          "TMA");              // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_BAND_RP,   "Gamma Upper Band");
   SetIndexLabel(MODE_LOWER_BAND_RP,   "Gamma Lower Band");
   SetIndexLabel(MODE_UPPER_BAND_NRP,  "Gamma Upper Band NRP"); if (RepaintingMode) SetIndexLabel(MODE_UPPER_BAND_NRP, NULL);
   SetIndexLabel(MODE_LOWER_BAND_NRP,  "Gamma Lower Band NRP"); if (RepaintingMode) SetIndexLabel(MODE_LOWER_BAND_NRP, NULL);
   SetIndexLabel(MODE_REVERSAL_MARKER, NULL);
   SetIndexLabel(MODE_REVERSAL_AGE,    "Reversal age");
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // initialize global vars
   ArrayResize(tmaWindow, maPeriods);

   return(catch("onInit(8)"));
}


/**
 * Initialization postprocessing. Called only if the reason-specific handler returned without error.
 *
 * @return int - error status
 */
int afterInit() {
   if (This.IsTesting()) {                                  // read test configuration
      string section = ProgramName() +".Tester";
      test.onSignalPause = GetConfigBool(section, "OnSignalPause", false);
   }
   return(catch("afterInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(tmaRP)) return(logInfo("onTick(1)  size(tmaRP) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   ManageIndicatorBuffer(MODE_LOWER_VARIANCE_RP, lowerVarianceRP);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(tmaRP,           0);
      ArrayInitialize(upperVarianceRP, 0);
      ArrayInitialize(lowerVarianceRP, 0);
      ArrayInitialize(upperBandRP,     0);
      ArrayInitialize(lowerBandRP,     0);
      ArrayInitialize(upperBandNRP,    0);
      ArrayInitialize(lowerBandNRP,    0);
      ArrayInitialize(reversalMarker,  0);
      ArrayInitialize(reversalAge,     0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(tmaRP,           Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperVarianceRP, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerVarianceRP, Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperBandRP,     Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerBandRP,     Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(upperBandNRP,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(lowerBandNRP,    Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(reversalMarker,  Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(reversalAge,     Bars, ShiftedBars, 0);
   }

   // calculate start bars
   int maHalfLength  = maPeriods/2;
   int requestedBars = Min(ChangedBars, maxValues);
   int maxTmaBars    = Bars - maHalfLength;                    // max. possible TMA bars

   int bars = Min(requestedBars, maxTmaBars);                  // actual number of TMA bars to be updated w/o a channel
   int tmaStartbar = bars - 1;                                 // non-repainting TMA startbar w/o a channel
   if (tmaStartbar < 0)        return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));
   int tmaStartbarRP = Max(tmaStartbar, maHalfLength);         // repainting TMA startbar

   int maxChannelBars = maxTmaBars - maPeriods + 1;            // max. possible channel bars                      TODO: adjust to final algorithm
   bars = Min(requestedBars, maxChannelBars);                  // actual number of channel bars to be updated
   int channelStartbarNRP = bars - 1;
   if (channelStartbarNRP < 0) return(logInfo("onTick(3)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   // recalculate TMA and Gammarat channel
   if (true || RepaintingMode) {
      CalculateRepaintingTMA(tmaStartbarRP);                   // repainting calculation
      UpdatePriceReversals(tmaRP, upperBandRP, lowerBandRP, tmaStartbarRP);
      CheckSignals(tmaRP, upperBandRP, lowerBandRP);
   }
   if (!RepaintingMode) {
      RecalculateChannel(channelStartbarNRP);                  // non-repainting calculation
      //UpdatePriceReversals(tmaRP, upperBandNRP, lowerBandNRP, channelStartbarNRP);
      //CheckSignals(tmaRP, upperBandNRP, lowerBandNRP);
   }

   return(catch("onTick(4)"));
}


/**
 * Original repainting TMA and channel calculation.
 */
void CalculateRepaintingTMA(int startbar) {
   int j, w, maHalfLength=maPeriods/2;

   for (int i=startbar; i >= 0; i--) {
      // TMA calculation
      double price = GetPrice(i);
      double sum = (maHalfLength+1) * price;
      int   sumw = (maHalfLength+1);

      for (j=1, w=maHalfLength; j <= maHalfLength; j++, w--) {
         sum  += w * GetPrice(i+j);
         sumw += w;
         if (j <= i) {
            sum  += w * GetPrice(i-j);
            sumw += w;
         }
      }
      tmaRP[i] = sum/sumw;                            // TMA(55) is with the built-in MAs "SMA(56) of SMA(56) shift -55"

      double diff = price - tmaRP[i];

      // rolling variance using the previous values
      if (diff > 0) {
         upperVarianceRP[i] = (upperVarianceRP[i+1] * (maPeriods-1) + MathPow(diff, 2))/maPeriods;
         lowerVarianceRP[i] = (lowerVarianceRP[i+1] * (maPeriods-1) + 0)               /maPeriods;
      }
      else {                                          // with real prices diff==0 is not possible
         upperVarianceRP[i] = (upperVarianceRP[i+1] * (maPeriods-1) + 0)               /maPeriods;
         lowerVarianceRP[i] = (lowerVarianceRP[i+1] * (maPeriods-1) + MathPow(diff, 2))/maPeriods;
      }
      // non-standard deviation
      upperBandRP[i] = tmaRP[i] + Bands.Deviations * MathSqrt(upperVarianceRP[i]);
      lowerBandRP[i] = tmaRP[i] - Bands.Deviations * MathSqrt(lowerVarianceRP[i]);
   }

   if (!IsSuperContext()) {
      @Bands.UpdateLegend(legendLabel, indicatorName, "", Bands.Color, upperBandRP[0], lowerBandRP[0], Digits, Time[0]);
   }
   return(last_error);
}


/**
 * Recalculate the Gammarat channel starting from the specified bar offset using history only (no peeking into the future,
 * i.e. no access of data younger than the currently calculated bar value).
 *
 * @param  int startbar - bar offset
 *
 * @return bool - success status
 */
bool RecalculateChannel(int startbar) {
   int maHalfLength = maPeriods/2;
   double diff, upperVariance, lowerVariance;

   for (int i=startbar; i >= 0; i--) {
      CalculateTMASeries(i, tmaWindow);                     // populate the TMA window with the TMA series at offset i without peeking
      upperVariance = upperVarianceRP[i+maHalfLength+1];
      lowerVariance = lowerVarianceRP[i+maHalfLength+1];

      for (int n=i+maHalfLength; n >= i; n--) {
         diff = GetPrice(n) - tmaWindow[n-i];

         if (diff > 0) {
            upperVariance = (upperVariance * (maPeriods-1) + MathPow(diff, 2))/maPeriods;
            lowerVariance = (lowerVariance * (maPeriods-1) + 0)               /maPeriods;
         }
         else {                                             // with real prices diff==0 is not possible
            upperVariance = (upperVariance * (maPeriods-1) + 0)               /maPeriods;
            lowerVariance = (lowerVariance * (maPeriods-1) + MathPow(diff, 2))/maPeriods;
         }
      }
      upperBandNRP[i] = tmaWindow[0] + Bands.Deviations * MathSqrt(upperVariance);
      lowerBandNRP[i] = tmaWindow[0] - Bands.Deviations * MathSqrt(lowerVariance);
   }
   return(!catch("RecalculateChannel(1)"));
}


/**
 * Calculate the centered TMA series at the specified bar offset using history only (no peeking into the future, i.e. no
 * access of data younger than the specified offset).
 *
 * @param  _In_  int    bar    - bar offset
 * @param  _Out_ double values - resulting TMA values
 *
 * @return bool - success status
 */
bool CalculateTMASeries(int bar, double &values[]) {
   for (int i=maPeriods-1; i >= 0 ; i--) {
      values[i] = CalculateTMA(bar+i, bar);
   }
   return(!catch("CalculateTMASeries(1)"));
}


/**
 * Calculate and return the centered TMA at the specified bar offset using history only (no peeking into the future, i.e. no
 * access of data younger than the specified history limit).
 *
 * @param  int bar   - bar offset
 * @param  int limit - limit history to this bar offset (younger data is not accessed)
 *
 * @return double - TMA value or NULL (0) in ase of errors
 */
double CalculateTMA(int bar, int limit) {
   if (bar < limit) return(!catch("CalculateTMA(1)  parameter mis-match: bar ("+ bar +") must be >= limit ("+ limit +")", ERR_INVALID_INPUT_PARAMETER));
   int maHalfLength = maPeriods/2;

   // initialize weigth summing with the center point
   double sum = (maHalfLength+1) * GetPrice(bar);
   int   sumW = (maHalfLength+1);

   // add LHS and RHS weigths of the triangle
   int weight = maHalfLength;                         // the weight next to the center point
   for (int i=1; weight > 0; i++, weight--) {
      sum  += weight * GetPrice(bar+i);               // walk backward and sum-up the LHS of the triangle
      sumW += weight;

      int rOffset = bar-i;                            // RHS bar offset
      if (rOffset >= limit) {
         sum  += weight * GetPrice(rOffset);          // walk forward and sum-up the available RHS of the triangle
         sumW += weight;
      }
   }
   return(sum/sumW);
}


/**
 * Recalculate and update price reversals starting from the specified bar offset.
 *
 * @param  double ma[]        - timeseries array holding the MA values
 * @param  double upperBand[] - timeseries array holding the upper band values
 * @param  double lowerBand[] - timeseries array holding the lower band values
 * @param  int    startbar    - startbar offset
 *
 * @return bool - success status
 */
bool UpdatePriceReversals(double ma[], double upperBand[], double lowerBand[], int startbar) {
 	for (int i=startbar; i >= 0; i--) {
 	   if (!lowerBand[i+1]) continue;

      bool wasCross, longReversal=false, shortReversal=false, bullishPattern=false, bearishPattern=IsBearishPattern(i);
      if (!bearishPattern) bullishPattern = IsBullishPattern(i);
 	   int iMaCross, iCurrMax, iCurrMin, iPrevMax, iPrevMin, iNull;      // bar index of TMA cross and swing extrems

      // check new reversals
      if (reversalAge[i+1] < 0) {                                       // previous short reversal
         // check for another short or a new long reversal
         if (bearishPattern) {
            wasCross = WasPriceCross(ma, i+1, i-reversalAge[i+1]-1, iMaCross);

            if (WasPriceAbove(upperBand, i, ifInt(wasCross, iMaCross-1, i-reversalAge[i+1]-1), iNull)) {
               if (!wasCross) {
                  iCurrMax = iHighest(NULL, NULL, MODE_HIGH, -reversalAge[i+1], i);
                  iPrevMax = iHighest(NULL, NULL, MODE_HIGH, MathAbs(reversalAge[_int(i-reversalAge[i+1]+1)]), i-reversalAge[i+1]);
                  shortReversal = (High[iCurrMax] > High[iPrevMax]);    // the current swing exceeds the previous one
               }
               else shortReversal = true;
            }
         }
         else if (bullishPattern) longReversal = WasPriceBelow(lowerBand, i, i-reversalAge[i+1]-1, iNull);
      }
      else if (reversalAge[i+1] > 0) {                                  // previous long reversal
         // check for another long or a new short reversal
         if (bullishPattern) {
            wasCross = WasPriceCross(ma, i+1, i+reversalAge[i+1]-1, iMaCross);

            if (WasPriceBelow(lowerBand, i, ifInt(wasCross, iMaCross-1, i+reversalAge[i+1]-1), iNull)) {
               if (!wasCross) {
                  iCurrMin = iLowest(NULL, NULL, MODE_LOW, reversalAge[i+1], i);
                  iPrevMin = iLowest(NULL, NULL, MODE_LOW, MathAbs(reversalAge[_int(i+reversalAge[i+1]+1)]), i+reversalAge[i+1]);
                  longReversal = (Low[iCurrMin] < Low[iPrevMin]);       // the current swing exceeds the previous one
               }
               else longReversal = true;
            }
         }
         else if (bearishPattern) shortReversal = WasPriceAbove(upperBand, i, i+reversalAge[i+1]-1, iNull);
      }
      else {                                                            // no previous signal
         if      (bullishPattern) longReversal  = WasPriceBelow(lowerBand, i, i+1, iNull);
         else if (bearishPattern) shortReversal = WasPriceAbove(upperBand, i, i+1, iNull);
      }

      // set marker and update reversal age
      if (longReversal) {
         reversalMarker[i] = Low[i];
         reversalAge   [i] = 1;
      }
      else if (shortReversal) {
         reversalMarker[i] = High[i];
         reversalAge   [i] = -1;
      }
      else {
         reversalMarker[i] = 0;
         reversalAge   [i] = reversalAge[i+1] + Sign(reversalAge[i+1]);
      }
   }

   return(!catch("UpdatePriceReversals(1)"));
}


/**
 * Check for and trigger signals. The following signals are monitored:
 *  - the crossing of a channel band since last crossing of the MA
 *  - a new high/low after a previous channel band crossing
 *  - on BarOpen a finished price reversal
 *
 * @param  double ma[]        - timeseries array holding the MA values
 * @param  double upperBand[] - timeseries array holding the upper band values
 * @param  double lowerBand[] - timeseries array holding the lower band values
 *
 * @return bool - success status
 */
bool CheckSignals(double ma[], double upperBand[], double lowerBand[]) {
   if (!AlertsOn) return(false);

   static double lastBid, lastHigh, lastLow;                                  // last prices
   static datetime lastTimeUp, lastTimeDn;                                    // bar opentimes of last crossings
   int iMaCross, iNull;

   // re/initialize last high/Low
   if (ChangedBars > 2 || !lastHigh) {
      int i=-1, n, lastLongReversal=-1, lastShortReversal=-1;
      lastHigh = NULL;
      lastLow  = NULL;

      while (lastLongReversal==-1 || lastShortReversal==-1) {                 // find the last long and short reversal
         i++;
         i += Abs(reversalAge[i])-1;
         if (i >= Bars) break;

         if (reversalAge[i] < 0) {                                            // always -1 or +1
            if (lastShortReversal == -1) {
               lastShortReversal = i;                                         // resolve the previous high
               WasPriceAbove(upperBand, lastShortReversal, Bars-1, n);        // find the first price above the band
               WasBarBelow(upperBand, n+1, Bars-1, n);                        // find the next full bar below the band
               lastHigh = High[iHighest(NULL, NULL, MODE_HIGH, n, 0)];
            }
         }
         else {
            if (lastLongReversal == -1) {
               lastLongReversal = i;                                          // resolve the previous low
               WasPriceBelow(lowerBand, lastLongReversal, Bars-1, n);         // find the first price bar below the band
               WasBarAbove(lowerBand, n+1, Bars-1, n);                        // find the next full bar above the band
               lastLow = Low[iLowest(NULL, NULL, MODE_LOW, n, 0)];
            }
         }
      }
      if (!lastHigh) lastHigh = INT_MAX;                                      // in this case high/low monitoring is reset at the next reversal
      if (!lastLow)  lastLow  = INT_MIN;
   }

   // detect new channel crossings (higher priority) and new high/lows (lower priority)
   if (lastBid != NULL) {
      // upper band crossings
      if (lastBid < upperBand[0] && Bid > upperBand[0]) {                     // price crossed the upper band
         if (Time[0] > lastTimeUp) {                                          // handle only the first crossing per bar
            if (WasPriceCross(ma, 0, MathAbs(reversalAge[0])-1, iMaCross)) {  // get the last MA cross
               if (!WasPriceAbove(upperBand, 1, iMaCross, iNull)) {           // signal if the first crossing since the MA cross
                  onNewCrossing("upper band crossing at "+ NumberToStr(upperBand[0], PriceFormat));
                  lastHigh = High[0];                                         // reset the current high
               }
            }
         }
         lastTimeUp = Time[0];
      }

      // lower band crossings
      if (lastBid > lowerBand[0] && Bid < lowerBand[0]) {                     // price crossed the lower band
         if (Time[0] > lastTimeDn) {                                          // handle only the first crossing per bar
            if (WasPriceCross(ma, 0, MathAbs(reversalAge[0])-1, iMaCross)) {  // get the last MA cross
               if (!WasPriceBelow(lowerBand, 1, iMaCross, iNull)) {           // signal if the first crossing since the MA cross
                  onNewCrossing("lower band crossing at "+ NumberToStr(lowerBand[0], PriceFormat));
                  lastLow = Low[0];                                           // reset the current low
               }
            }
         }
         lastTimeDn = Time[0];
      }

      // detect new highs/lows
      if (Bid > lastHigh) { onNewHigh(); lastHigh = High[0]; }                // update the current high
      if (Bid < lastLow)  { onNewLow();  lastLow  = Low[0];  }                // update the current low
   }
   lastBid = Bid;

   // detect finished price reversals
   if (IsBarOpen()) {
      if (Abs(reversalAge[1]) == 1) onReversal();
   }

   return(!catch("CheckSignals(1)"));
}


/**
 * Get the price of the configured type at the specified bar offset.
 *
 * @param  int bar - bar offset
 *
 * @return double - price or NULL (0) in case of errors
 */
double GetPrice(int bar) {
   if (bar >= Bars || bar < 0) return(!catch("GetPrice(1)  invalid parameter bar: "+ bar + ifString(bar>=Bars, " (must be lower then Bars="+ Bars +")", ""), ERR_INVALID_INPUT_PARAMETER));
   return(iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar));

   GetLWMA(NULL);
}


/**
 * Get the LWMA at the specified bar offset.
 *
 * @param  int bar - bar offset
 *
 * @return double - value or NULL (0) in case of errors
 */
double GetLWMA(int bar) {
   if (bar >= Bars || bar < 0) return(!catch("GetLWMA(1)  invalid parameter bar: "+ bar + ifString(bar>=Bars, " (must be lower then Bars="+ Bars +")", ""), ERR_INVALID_INPUT_PARAMETER));
   return(iMA(NULL, NULL, maPeriods/2+1, 0, MODE_LWMA, maAppliedPrice, bar));
}


/**
 * Whether the bar at the specified offset forms a bullish candle pattern.
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsBullishPattern(int bar) {
   if (bar >= Bars || bar < 0) return(false);
   return(Open[bar] < Close[bar] || (EQ(Open[bar], Close[bar]) && Close[bar+1] < Close[bar]));
}


/**
 * Whether the bar at the specified offset forms a bearish candle pattern.
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsBearishPattern(int bar) {
   if (bar >= Bars || bar < 0) return(false);
   return(Open[bar] > Close[bar] || (EQ(Open[bar], Close[bar]) && Close[bar+1] > Close[bar]));
}


/**
 * Whether price in the specified bar range was at least once above the given indicator line.
 *
 * @param  _In_  double buffer[] - indicator line buffer
 * @param  _In_  int    from     - start offset of the bar range to check
 * @param  _In_  int    to       - end offset of the bar range to check
 * @param  _Out_ int    &bar     - offset of the first found bar or EMPTY (-1) if there was none
 *
 * @return bool
 */
bool WasPriceAbove(double buffer[], int from, int to, int &bar) {
   bar = -1;
   if (from >= Bars) return(false);
   if (to   >= Bars) to = Bars-1;

   for (int i=from; i <= to; i++) {
      if (High[i] >= buffer[i]) {
         bar = i;
         break;
      }
   }
   return(bar != -1);
}


/**
 * Whether price in the specified bar range was at least once below the given indicator line.
 *
 * @param  _In_  double buffer[] - indicator line buffer
 * @param  _In_  int    from     - start offset of the bar range to check
 * @param  _In_  int    to       - end offset of the bar range to check
 * @param  _Out_ int    &bar     - offset of the first found bar or EMPTY (-1) if there was none
 *
 * @return bool
 */
bool WasPriceBelow(double buffer[], int from, int to, int &bar) {
   bar = -1;
   if (from >= Bars) return(false);
   if (to   >= Bars) to = Bars-1;

   for (int i=from; i <= to; i++) {
      if (Low[i] <= buffer[i]) {
         bar = i;
         break;
      }
   }
   return(bar != -1);
}


/**
 * Whether price in the specified bar range crossed the given indicator line.
 *
 * @param  _In_  double buffer[] - indicator line buffer
 * @param  _In_  int    from     - start offset of the bar range to check
 * @param  _In_  int    to       - end offset of the bar range to check
 * @param  _Out_ int    &bar     - bar offset of the first crossing or EMPTY (-1) if there was none
 *
 * @return bool
 */
bool WasPriceCross(double buffer[], int from, int to, int &bar) {
   bar = -1;
   if (from >= Bars) return(false);
   if (to   >= Bars) to = Bars-1;

   for (int i=from; i <= to; i++) {
      if (High[i] > buffer[i] && Low[i] < buffer[i]) {   // in practice High==buffer or Low==buffer cannot happen
         bar = i;
         break;
      }
   }
   return(bar != -1);
}


/**
 * Whether any bar in the specified bar range was completely above the given indicator line.
 *
 * @param  _In_  double buffer[] - indicator line buffer
 * @param  _In_  int    from     - start offset of the bar range to check
 * @param  _In_  int    to       - end offset of the bar range to check
 * @param  _Out_ int    &bar     - offset of the first found bar or EMPTY (-1) if there was none
 *
 * @return bool
 */
bool WasBarAbove(double buffer[], int from, int to, int &bar) {
   bar = -1;
   if (from >= Bars) return(false);
   if (to   >= Bars) to = Bars-1;

   for (int i=from; i <= to; i++) {
      if (Low[i] > buffer[i]) {
         bar = i;
         break;
      }
   }
   return(bar != -1);
}



/**
 * Whether any bar in the specified bar range was completely below the given indicator line.
 *
 * @param  _In_  double buffer[] - indicator line buffer
 * @param  _In_  int    from     - start offset of the bar range to check
 * @param  _In_  int    to       - end offset of the bar range to check
 * @param  _Out_ int    &bar     - offset of the first found bar or EMPTY (-1) if there was none
 *
 * @return bool
 */
bool WasBarBelow(double buffer[], int from, int to, int &bar) {
   bar = -1;
   if (from >= Bars) return(false);
   if (to   >= Bars) to = Bars-1;

   for (int i=from; i <= to; i++) {
      if (High[i] < buffer[i]) {
         bar = i;
         break;
      }
   }
   return(bar != -1);
}


/**
 *
 */
void onNewCrossing(string msg) {
   logNotice(" "+ msg);
}


/**
 *
 */
void onNewHigh() {
   logInfo("  new high "+ NumberToStr(Bid, PriceFormat));
}


/**
 *
 */
void onNewLow() {
   logInfo("  new low "+ NumberToStr(Bid, PriceFormat));
}


/**
 *
 */
void onReversal() {
   logInfo(" "+ ifString(reversalAge[1] > 0, "LONG", "SHORT") +" reversal at "+ NumberToStr(Close[1], PriceFormat));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);

   //SetIndexStyle(int index, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)
   if (!Bands.LineWidth) { int drawType = DRAW_NONE, drawWidth = EMPTY;           }
   else                  {     drawType = DRAW_LINE; drawWidth = Bands.LineWidth; }

   SetIndexStyle(MODE_TMA_RP,        DRAW_LINE);
   SetIndexStyle(MODE_UPPER_BAND_RP, drawType, EMPTY, drawWidth, Bands.Color);
   SetIndexStyle(MODE_LOWER_BAND_RP, drawType, EMPTY, drawWidth, Bands.Color);

   //SetIndexStyle(MODE_UPPER_BAND_NRP,  DRAW_LINE, EMPTY, EMPTY, indicator_color5);
   //SetIndexStyle(MODE_LOWER_BAND_NRP,  DRAW_LINE, EMPTY, EMPTY, indicator_color6);

   if (MarkReversals) drawType = DRAW_ARROW;
   else               drawType = DRAW_NONE;
   SetIndexStyle(MODE_REVERSAL_MARKER, drawType); SetIndexArrow(MODE_REVERSAL_MARKER, 82);
   SetIndexStyle(MODE_REVERSAL_AGE,    DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",       MA.Periods,                           ";", NL,
                            "MA.AppliedPrice=",  DoubleQuoteStr(MA.AppliedPrice),      ";", NL,
                            "Bands.Deviations=", NumberToStr(Bands.Deviations, ".1+"), ";", NL,
                            "Bands.Color=",      ColorToStr(Bands.Color),              ";", NL,
                            "Bands.LineWidth=",  Bands.LineWidth,                      ";", NL,
                            "RepaintingMode=",   BoolToStr(RepaintingMode),            ";", NL,
                            "MarkReversals=",    BoolToStr(MarkReversals),             ";", NL,
                            "Max.Bars=",         Max.Bars,                             ";", NL,
                            "AlertsOn=",         BoolToStr(AlertsOn),                  ";")
   );
}

/**
 * TMA Gammarat Channel
 *
 * An asymmetric non-standard deviation channel around a shifted - thus repainting - Triangular Moving Average (TMA). The TMA
 * is a twice applied Simple Moving Average (SMA) who's resulting MA weights form the shape of a triangle. It holds:
 *
 *  TMA(n) = SMA(floor(n/2)+1) of SMA(ceil(n/2))
 *
 * @link    https://user42.tuxfamily.org/chart/manual/Triangular-Moving-Average.html#             [Triangular Moving Average]
 * @link    https://forex-station.com/viewtopic.php?f=579496&t=8423458#                  [Centered Triangular Moving Average]
 * @author  Chris Brobeck aka gammarat (channel algorythm)
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods       = 7;
extern int    MA.HalfLength    = 55;
extern string MA.AppliedPrice  = "Open | High | Low | Close | Median | Typical | Weighted*";

extern double Bands.Deviations = 2.5;
extern color  Bands.Color      = Magenta;          // Gold LightSkyBlue
extern int    Bands.LineWidth  = 1;                // 3
extern string __a____________________________;

extern bool   RepaintingMode   = false;            // toggle repainting mode
extern bool   MarkReversals    = false;
extern int    Max.Bars         = 5000;             // max. values to calculate (-1: all available)
extern string __b____________________________;

extern bool   AlertsOn         = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Bands.mqh>
#include <functions/ManageIndicatorBuffer.mqh>

#define SIGNAL_UP                1                 // signal ids
#define SIGNAL_DOWN              2

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
#property indicator_buffers   7                    // buffers visible in input dialog
int       terminal_buffers  = 8;                   // buffers managed by the terminal
int       framework_buffers = 1;                   // buffers managed by the framework

#property indicator_color1    Magenta              // repainting TMA
#property indicator_color2    CLR_NONE             // repainting upper channel band
#property indicator_color3    CLR_NONE             // repainting lower channel band
#property indicator_color4    Blue                 // non-repainting upper channel band
#property indicator_color5    Blue                 // non-repainting lower channel band
#property indicator_color6    Magenta              // breakout reversals

#property indicator_style1    STYLE_DOT

#property indicator_width6    2                    // breakout reversal markers

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
   // MA.Periods / MA.HalfLength
   if (!MA.Periods) {
      if (MA.HalfLength < 1)                                  return(catch("onInit(1)  invalid input parameter MA.HalfLength: "+ MA.HalfLength, ERR_INVALID_INPUT_PARAMETER));
      maPeriods = 2 * MA.HalfLength + 1;
   }
   else {
      if (MA.Periods < 1)                                     return(catch("onInit(2)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
      if (MA.Periods & 1 == 0)                                return(catch("onInit(3)  invalid input parameter MA.Periods: "+ MA.Periods +" (must be an odd value)", ERR_INVALID_INPUT_PARAMETER));
      maPeriods = MA.Periods;
   }
   // MA.AppliedPrice
   string sValues[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_WEIGHTED) return(catch("onInit(4)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Bands.Deviations
   if (Bands.Deviations < 0)                                  return(catch("onInit(5)  invalid input parameter Bands.Deviations: "+ NumberToStr(Bands.Deviations, ".1+"), ERR_INVALID_INPUT_PARAMETER));
   // Bands.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;
   // Bands.LineWidth
   if (Bands.LineWidth < 0)                                   return(catch("onInit(6)  invalid input parameter Bands.LineWidth: "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Bands.LineWidth > 5)                                   return(catch("onInit(7)  invalid input parameter Bands.LineWidth: "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   // Max.Bars
   if (Max.Bars < -1)                                         return(catch("onInit(8)  invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
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
   SetIndexLabel(MODE_UPPER_BAND_RP,   "GC upper band RP");
   SetIndexLabel(MODE_LOWER_BAND_RP,   "GC lower band RP");
   SetIndexLabel(MODE_UPPER_BAND_NRP,  "GC upper band NRP");
   SetIndexLabel(MODE_LOWER_BAND_NRP,  "GC lower band NRP");
   SetIndexLabel(MODE_REVERSAL_MARKER, NULL);
   SetIndexLabel(MODE_REVERSAL_AGE,    "Reversal age");
   IndicatorDigits(8);                                      // TODO: reset to Digits after finishing
   SetIndicatorOptions();

   // initialize global vars
   ArrayResize(tmaWindow, maPeriods);

   return(catch("onInit(9)"));
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
   if (!ArraySize(tmaRP)) return(logDebug("onTick(1)  size(tmaRP) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   ManageIndicatorBuffer(MODE_LOWER_VARIANCE_RP, lowerVarianceRP);

   // reset all buffers before performing a full recalculation
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
      CalculateBreakoutReversals(tmaRP, upperBandRP, lowerBandRP, tmaStartbarRP);
      CheckSignals(upperBandRP, lowerBandRP);
   }
   if (!RepaintingMode) {
      RecalculateChannel(channelStartbarNRP);                  // non-repainting calculation
      //CalculateBreakoutReversals(tmaRP, upperBandNRP, lowerBandNRP, channelStartbarNRP);
      //CheckSignals(upperBandNRP, lowerBandNRP);
   }

   return(catch("onTick(4)"));
}


/**
 * Original repainting TMA and channel calculation.
 */
void CalculateRepaintingTMA(int startBar) {
   int j, w, maHalfLength=maPeriods/2;

   for (int i=startBar; i >= 0; i--) {
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
 * Recalculate breakout reversals starting from the specified bar offset.
 *
 * @param  double tma[]       - timeseries array holding the TMA values
 * @param  double upperBand[] - timeseries array holding the upper band values
 * @param  double lowerBand[] - timeseries array holding the lower band values
 * @param  int    startbar    - startbar offset
 *
 * @return bool - success status
 */
bool CalculateBreakoutReversals(double tma[], double upperBand[], double lowerBand[], int startbar) {
   if (!MarkReversals) return(false);

 	for (int i=startbar; i >= 0; i--) {
 	   if (!lowerBand[i+1]) continue;

      bool longReversal=false, shortReversal=false, bullishPattern=false, bearishPattern=IsBearishPattern(i);
      if (!bearishPattern) bullishPattern = IsBullishPattern(i);
 	   int iMaCross, iCurrMax, iCurrMin, iPrevMax, iPrevMin;                // bar index of TMA cross and swing extrems

      // check new reversals
      if (reversalAge[i+1] < 0) {                                          // previous short reversal
         // check for another short or a new long reversal
         if (bearishPattern) {
            iMaCross = iMedianCross(tma, i+1, i-reversalAge[i+1]-1);

            if (HasPriceCrossedUpperBand(upperBand, i, ifInt(iMaCross, iMaCross-1, i-reversalAge[i+1]-1))) {
               if (!iMaCross) {
                  iCurrMax = iHighest(NULL, NULL, MODE_HIGH, -reversalAge[i+1], i);
                  iPrevMax = iHighest(NULL, NULL, MODE_HIGH, MathAbs(reversalAge[_int(i-reversalAge[i+1]+1)]), i-reversalAge[i+1]);
                  shortReversal = (High[iCurrMax] > High[iPrevMax]);       // the current swing exceeds the previous one
               }
               else shortReversal = true;
            }
         }
         else if (bullishPattern) longReversal = HasPriceCrossedLowerBand(lowerBand, i, i-reversalAge[i+1]-1);
      }
      else if (reversalAge[i+1] > 0) {                                     // previous long reversal
         // check for another long or a new short reversal
         if (bullishPattern) {
            iMaCross = iMedianCross(tma, i+1, i+reversalAge[i+1]-1);

            if (HasPriceCrossedLowerBand(lowerBand, i, ifInt(iMaCross, iMaCross-1, i+reversalAge[i+1]-1))) {
               if (!iMaCross) {
                  iCurrMin = iLowest(NULL, NULL, MODE_LOW, reversalAge[i+1], i);
                  iPrevMin = iLowest(NULL, NULL, MODE_LOW, MathAbs(reversalAge[_int(i+reversalAge[i+1]+1)]), i+reversalAge[i+1]);
                  longReversal = (Low[iCurrMin] < Low[iPrevMin]);          // the current swing exceeds the previous one
               }
               else longReversal = true;
            }
         }
         else if (bearishPattern) shortReversal = HasPriceCrossedUpperBand(upperBand, i, i+reversalAge[i+1]-1);
      }
      else {                                                               // no previous signal
         if      (bullishPattern) longReversal  = HasPriceCrossedLowerBand(lowerBand, i, i+1);
         else if (bearishPattern) shortReversal = HasPriceCrossedUpperBand(upperBand, i, i+1);
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

   return(!catch("CalculateBreakoutReversals(1)"));
}


/**
 * Check for and process signals.
 *
 * @param  double upperBand[] - timeseries array holding the upper band values
 * @param  double lowerBand[] - timeseries array holding the lower band values
 *
 * @return bool - success status
 */
bool CheckSignals(double upperBand[], double lowerBand[]) {
   if (!AlertsOn) return(false);

   static double lastBid; if (lastBid != NULL) {
      if (Open[0] < upperBand[0] && lastBid < upperBand[0] && Bid > upperBand[0]) onSignal(SIGNAL_UP,   "upper band at "+ NumberToStr(upperBand[0], PriceFormat) +" crossed");
      if (Open[0] > lowerBand[0] && lastBid > lowerBand[0] && Bid < lowerBand[0]) onSignal(SIGNAL_DOWN, "lower band at "+ NumberToStr(lowerBand[0], PriceFormat) +" crossed");
   }
   lastBid = Bid;

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
   return(Open[bar] < Close[bar] || (Open[bar]==Close[bar] && Close[bar+1] < Close[bar]));
}


/**
 * Whether the bar at the specified offset forms a bearish candle pattern.
 *
 * @param  int bar - bar offset
 *
 * @return bool
 */
bool IsBearishPattern(int bar) {
   return(Open[bar] > Close[bar] || (Open[bar]==Close[bar] && Close[bar+1] > Close[bar]));
}


/**
 * Whether the High price of the specified bar range has crossed the upper channel band.
 *
 * @param  double band[] - upper channel band
 * @param  int    from   - start offset of the bar range to check
 * @param  int    to     - end offset of the bar range to check
 *
 * @return bool
 */
bool HasPriceCrossedUpperBand(double band[], int from, int to) {
   for (int i=from; i <= to; i++) {
      if (High[i] >= band[i]) {
         return(true);
      }
   }
   return(false);
}


/**
 * Whether the Low price of the specified bar range has crossed the lower channel band.
 *
 * @param  double band[] - lower channel band
 * @param  int    from   - start offset of the bar range to check
 * @param  int    to     - end offset of the bar range to check
 *
 * @return bool
 */
bool HasPriceCrossedLowerBand(double band[], int from, int to) {
   for (int i=from; i <= to; i++) {
      if (Low[i] <= band[i]) {
         return(true);
      }
   }
   return(false);
}


/**
 * Return the offset of the bar in the specified range which crossed the channel mean (i.e. the Moving Average).
 *
 * @param  double ma[] - moving average
 * @param  int    from - start offset of the bar range to check
 * @param  int    to   - end offset of the bar range to check
 *
 * @return int - positive bar offset or NULL (0) if no bar in the specified range crossed the MA
 */
int iMedianCross(double ma[], int from, int to) {
   for (int i=from; i <= to; i++) {
      if (High[i] > ma[i] && Low[i] < ma[i]) {        // in practice High==ma or Low==ma cannot happen
         return(i);
      }
   }
   return(NULL);
}


/**
 *
 */
void onSignal(int signal, string msg) {
   static int lastSignal;
   static datetime lastTime;

   if (signal!=lastSignal || Time[0]!=lastTime) {
      lastSignal = signal;
      lastTime = Time[0];
      logNotice(" "+ msg);

      if (This.IsTesting()) {                         // pause a test if configured
         if (__isChart && test.onSignalPause) Tester.Pause("onSignal(1)");
      }
   }
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   //SetIndexStyle(int index, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)
   IndicatorBuffers(terminal_buffers);

   if (!Bands.LineWidth) { int bandsDrawType = DRAW_NONE, bandsWidth = EMPTY;           }
   else                  {     bandsDrawType = DRAW_LINE; bandsWidth = Bands.LineWidth; }

   SetIndexStyle(MODE_TMA_RP,        DRAW_LINE);
   SetIndexStyle(MODE_UPPER_BAND_RP, bandsDrawType, EMPTY, bandsWidth, Bands.Color);
   SetIndexStyle(MODE_LOWER_BAND_RP, bandsDrawType, EMPTY, bandsWidth, Bands.Color);

   //SetIndexStyle(MODE_UPPER_BAND_NRP,  DRAW_LINE, EMPTY, EMPTY, indicator_color5);
   //SetIndexStyle(MODE_LOWER_BAND_NRP,  DRAW_LINE, EMPTY, EMPTY, indicator_color6);

   SetIndexStyle(MODE_REVERSAL_MARKER, DRAW_ARROW); SetIndexArrow(MODE_REVERSAL_MARKER, 82);
   SetIndexStyle(MODE_REVERSAL_AGE,    DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",       MA.Periods,                           ";", NL,
                            "MA.HalfLength=",    MA.HalfLength,                        ";", NL,
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

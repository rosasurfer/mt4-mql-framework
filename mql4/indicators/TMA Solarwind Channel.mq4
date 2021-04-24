/**
 * TMA Solarwind Channel
 *
 * A standard deviation derived channel around a centered - thus repainting - Triangular Moving Average (TMA). The TMA is a
 * twice applied Simple Moving Average (SMA) who's resulting MA weights form the shape of a triangle (see first link).
 * It holds:
 *
 *  TMA[n] = SMA[floor(n/2)+1] of SMA[ceil(n/2)]
 *
 * @link  https://user42.tuxfamily.org/chart/manual/Triangular-Moving-Average.html
 * @link  https://www.mql5.com/en/forum/181241
 * @link  https://forex-station.com/viewtopic.php?f=579496&t=8423458
 * @link  https://www.forexfactory.com/thread/922947-lazytma-trading
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.HalfLength    = 55;
extern string MA.AppliedPrice  = "Open | High | Low | Close | Median | Typical | Weighted*";
extern double Bands.Deviations = 2.5;
extern bool   RepaintingMode   = true;       // enable repainting mode
extern bool   MarkSignals      = false;
extern bool   AlertsOn         = false;
extern int    Max.Bars         = 10000;      // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Bands.mqh>
#include <functions/ManageIndicatorBuffer.mqh>

#define MODE_TMA                 0           // indicator buffer ids
#define MODE_UPPER_BAND_RP       1           //
#define MODE_LOWER_BAND_RP       2           //
#define MODE_LWMA                3           //
#define MODE_UPPER_BAND_NRP      4           //
#define MODE_LOWER_BAND_NRP      5           //
#define MODE_SIGNALS             6           //
#define MODE_UPPER_VARIANCE_RP   7           // managed by the framework
#define MODE_LOWER_VARIANCE_RP   8           // ...
#define MODE_UPPER_VARIANCE_NRP  9           // ...
#define MODE_LOWER_VARIANCE_NRP 10           // ...

#property indicator_chart_window
#property indicator_buffers   7              // buffers managed by the terminal
int       framework_buffers = 4;             // buffers managed by the framework

#property indicator_color1    Magenta        // TMA
#property indicator_color2    LightSkyBlue   // upper repainting channel band
#property indicator_color3    LightSkyBlue   // lower repainting channel band (PowderBlue)
#property indicator_color4    CLR_NONE       // CLR_NONE Blue                    // LWMA
#property indicator_color5    Blue           // CLR_NONE Blue                    // upper non-repainting channel band
#property indicator_color6    Blue           // CLR_NONE Blue                    // lower non-repainting channel band
#property indicator_color7    Magenta        // signals

#property indicator_width1    1
#property indicator_width2    3
#property indicator_width3    3
#property indicator_width4    1
#property indicator_width5    1
#property indicator_width6    1
#property indicator_width7    4

#property indicator_style1    STYLE_DOT
#property indicator_style4    STYLE_DOT

double tma            [];
double upperVarianceRP[];
double lowerVarianceRP[];
double upperBandRP    [];
double lowerBandRP    [];

double lwma            [];
double upperVarianceNRP[];
double lowerVarianceNRP[];
double upperBandNRP    [];
double lowerBandNRP    [];

double signal[];

int    maPeriods;
int    maAppliedPrice;
int    maxValues;

string indicatorName;
string legendLabel;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // MA.HalfLength
   if (MA.HalfLength < 1)                                     return(catch("onInit(1)  invalid input parameter MA.HalfLength: "+ MA.HalfLength, ERR_INVALID_INPUT_PARAMETER));
   maPeriods = 2 * MA.HalfLength + 1;

   // MA.AppliedPrice
   string sValues[], sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_WEIGHTED) return(catch("onInit(2)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);

   // Max.Bars
   if (Max.Bars < -1)                                         return(catch("onInit(3)  invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // buffer management
   SetIndexBuffer(MODE_TMA,            tma         );
   SetIndexBuffer(MODE_UPPER_BAND_RP,  upperBandRP );
   SetIndexBuffer(MODE_LOWER_BAND_RP,  lowerBandRP );
   SetIndexBuffer(MODE_LWMA,           lwma        );
   SetIndexBuffer(MODE_UPPER_BAND_NRP, upperBandNRP);
   SetIndexBuffer(MODE_LOWER_BAND_NRP, lowerBandNRP);
   SetIndexBuffer(MODE_SIGNALS,        signal      ); SetIndexEmptyValue(MODE_SIGNALS, 0);

   // chart legend
   if (!IsSuperContext()) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // names, labels and display options
   indicatorName = "TMA Channel("+ MA.HalfLength +")";
   IndicatorShortName(indicatorName);                       // chart tooltips and context menu
   SetIndexLabel(MODE_TMA,            "TMA");               // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_BAND_RP,  "TMA upper band");
   SetIndexLabel(MODE_LOWER_BAND_RP,  "TMA lower band");
   SetIndexLabel(MODE_LWMA,           "LWMA");
   SetIndexLabel(MODE_UPPER_BAND_NRP, "LWMA upper band");
   SetIndexLabel(MODE_LOWER_BAND_NRP, "LWMA lower band");
   SetIndexLabel(MODE_SIGNALS,        NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(4)"));
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
   if (!ArraySize(tma)) return(logDebug("onTick(1)  size(tma) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   ManageIndicatorBuffer(MODE_UPPER_VARIANCE_RP,  upperVarianceRP);
   ManageIndicatorBuffer(MODE_LOWER_VARIANCE_RP,  lowerVarianceRP);
   ManageIndicatorBuffer(MODE_UPPER_VARIANCE_NRP, upperVarianceNRP);
   ManageIndicatorBuffer(MODE_LOWER_VARIANCE_NRP, lowerVarianceNRP);

   // reset all buffers before performing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(tma,              EMPTY_VALUE);
      ArrayInitialize(upperVarianceRP,  EMPTY_VALUE);
      ArrayInitialize(lowerVarianceRP,  EMPTY_VALUE);
      ArrayInitialize(upperBandRP,      EMPTY_VALUE);
      ArrayInitialize(lowerBandRP,      EMPTY_VALUE);
      ArrayInitialize(lwma,             EMPTY_VALUE);
      ArrayInitialize(upperVarianceNRP, EMPTY_VALUE);
      ArrayInitialize(lowerVarianceNRP, EMPTY_VALUE);
      ArrayInitialize(upperBandNRP,     EMPTY_VALUE);
      ArrayInitialize(lowerBandNRP,     EMPTY_VALUE);
      ArrayInitialize(signal,           0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(tma,              Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperVarianceRP,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerVarianceRP,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperBandRP,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerBandRP,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lwma,             Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperVarianceNRP, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerVarianceNRP, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperBandNRP,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerBandNRP,     Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(signal,           Bars, ShiftedBars, 0);
   }

   int FullLength = maPeriods;
   int HalfLength = MA.HalfLength;

   // recalculate changed LWMA bars
   int bars = Min(ChangedBars, Max.Bars);
   int startBar = Min(bars-1, Bars-(HalfLength+1));
   if (startBar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   for (int i=startBar; i >= 0; i--) {
      lwma[i] = iMA(NULL, NULL, HalfLength+1, 0, MODE_LWMA, maAppliedPrice, i);
   }
   //if (!UnchangedBars) debug("onTick()  lwma[44] = "+ NumberToStr(lwma[44], PriceFormat) +" (startBar="+ startBar +", "+ TimeToStr(Time[44], TIME_DATE|TIME_MINUTES) +")");


   // original repainting TMA calculation
   bars = Min(Bars, Max.Bars);
   startBar = ChangedBars + HalfLength + 1;
   if (startBar >= bars) startBar = bars-1;
   CalculateTMA(bars, startBar);


   // new non-repainting TMA calculation
   double values[];
   int offset = 0;
   CalculateTMAValues(values, offset);


   // signal calculation
   if (MarkSignals) {
    	for (i=startBar; i >= 0; i--) {
         signal[i] = 0;
         // original
         if (Low [i+1] < lowerBandRP[i+1] && Close[i+1] < Open[i+1] && Close[i] > Open[i]) signal[i] =  Low[i];
         if (High[i+1] > upperBandRP[i+1] && Close[i+1] > Open[i+1] && Close[i] < Open[i]) signal[i] = High[i];
         // new
         //if (( Low[i+1] < lowerBandRP[i+1] ||  Low[i] < lowerBandRP[i]) && Close[i] > Open[i] && !longSignal [i+1]) signal[i] =  Low[i];
         //if ((High[i+1] > upperBandRP[i+1] || High[i] > upperBandRP[i]) && Close[i] < Open[i] && !shortSignal[i+1]) signal[i] = High[i];
      }
   }

   // alerts
   if (AlertsOn) {
      if (Close[0] > upperBandRP[0] && Close[1] < upperBandRP[1]) onSignal("upper band at "+ NumberToStr(upperBandRP[0], PriceFormat) +" touched");
      if (Close[0] < lowerBandRP[0] && Close[1] > lowerBandRP[1]) onSignal("lower band at "+ NumberToStr(upperBandRP[0], PriceFormat) +" touched");
   }
   return(0);
}


/**
 *
 */
void CalculateTMAValues(double &values[], int offset) {
   ArrayResize(values, maPeriods);
}


/**
 *
 */
void CalculateTMA(int bars, int startBar) {
   int j, w, HalfLength=MA.HalfLength, FullLength=maPeriods;

   for (int i=startBar; i >= 0; i--) {
      double price = GetPrice(i);            // TMA calculation
      double sum = (HalfLength+1) * price;
      int   sumw = (HalfLength+1);

      for (j=1, w=HalfLength; j<=HalfLength; j++, w--) {
         sum  += w * GetPrice(i+j);
         sumw += w;
         if (j <= i) {
            sum  += w * GetPrice(i-j);
            sumw += w;
         }
      }
      tma[i] = sum/sumw;

      if (!UnchangedBars && !i) {
         //double values[]; ArrayResize(values, FullLength);
         //for (int n=0; n < FullLength; n++) values[n] = tma[n];
         //debug("CalcTMA()  last "+ FullLength +" tma[]: "+ DoublesToStrEx(values, NULL, Digits+1));
      }


      // diff between price and TMA
      double diffRP = price - tma[i];

      if (i > bars-HalfLength-1) continue;

      if (i < bars-HalfLength-1) {
         if (diffRP >= 0) {
            upperVarianceRP[i] = (upperVarianceRP[i+1] * (FullLength-1) + MathPow(diffRP, 2)) /FullLength;
            lowerVarianceRP[i] = (lowerVarianceRP[i+1] * (FullLength-1) + 0)                  /FullLength;
         }
         else {
            upperVarianceRP[i] = (upperVarianceRP[i+1] * (FullLength-1) + 0)                  /FullLength;
            lowerVarianceRP[i] = (lowerVarianceRP[i+1] * (FullLength-1) + MathPow(diffRP, 2)) /FullLength;
         }
         //if (ChangedBars == 1) debug("CalcTMA()  i="+ i +"  added diff "+ diffRP + ifString(EQ(tma[i], iMA(NULL, NULL, HalfLength+1, 0, MODE_LWMA, appliedPrice, i)), " (TMA = LWMA)", " (TMA != LWMA)"));
      }
      else /*i == bars-HalfLength-1*/{
         if (diffRP >= 0) {
            upperVarianceRP[i] = MathPow(diffRP, 2);
            lowerVarianceRP[i] = 0;
         }
         else {
            upperVarianceRP[i] = 0;
            lowerVarianceRP[i] = MathPow(diffRP, 2);
         }
      }

      // deviation
      upperBandRP[i] = tma[i] + Bands.Deviations * MathSqrt(upperVarianceRP[i]);
      lowerBandRP[i] = tma[i] - Bands.Deviations * MathSqrt(lowerVarianceRP[i]);
   }

   if (!IsSuperContext()) {
      @Bands.UpdateLegend(legendLabel, indicatorName, "", indicator_color2, upperBandRP[0], lowerBandRP[0], Digits, Time[0]);
   }

   //upperBandNRP[0] = upperBandRP[0];
   //lowerBandNRP[0] = lowerBandRP[0];
}


/**
 * @param  int bar - bar offset
 *
 * @return double
 */
double GetPrice(int bar) {
   return(iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
   SetIndexStyle(MODE_SIGNALS, DRAW_ARROW);
   SetIndexArrow(MODE_SIGNALS, 82);
}


/**
 *
 */
void onSignal(string msg) {
   static string lastMsg = "";
   static datetime lastTime;

   if (msg!=lastMsg || Time[0]!=lastTime) {
      lastMsg = msg;
      lastTime = Time[0];
      logNotice(" "+ msg);
   }
}

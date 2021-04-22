/**
 * TMA Solarwind
 *
 * TMA[n] = SMA[floor(n/2)+1] of SMA[ceil(n/2)]
 *
 *
 * @see  https://user42.tuxfamily.org/chart/manual/Triangular-Moving-Average.html
 * @see  https://www.mql5.com/en/forum/181241
 * @see  https://forex-station.com/viewtopic.php?f=579496&t=8423458
 * @see  https://www.forexfactory.com/thread/922947-lazytma-trading
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    HalfLength      = 55;
extern string AppliedPrice    = "Open | High | Low | Close | Median | Typical | Weighted*";
extern double BandsDeviations = 2.5;
extern bool   AlertsOn        = false;
extern bool   MarkSignals     = false;
extern bool   SolarwindMode   = true;        // enable repainting mode
extern int    Max.Bars        = 5000;        // max. values to calculate (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ManageIndicatorBuffer.mqh>

#define MODE_TMA                 0           // indicator buffer ids
#define MODE_UPPER_BAND_RP       1           //
#define MODE_LOWER_BAND_RP       2           //
#define MODE_LWMA                3           //
#define MODE_UPPER_BAND_NRP      4           //
#define MODE_LOWER_BAND_NRP      5           //
#define MODE_LONG_SIGNAL         6           //
#define MODE_SHORT_SIGNAL        7           //
#define MODE_UPPER_VARIANCE_RP   8           // managed by the framework
#define MODE_LOWER_VARIANCE_RP   9           // ...
#define MODE_UPPER_VARIANCE_NRP 10           // ...
#define MODE_LOWER_VARIANCE_NRP 11           // ...

#property indicator_chart_window
#property indicator_buffers   8              // buffers managed by the terminal
int       framework_buffers = 4;             // buffers managed by the framework

#property indicator_color1    Magenta        // TMA
#property indicator_color2    LightSkyBlue   // upper repainting channel band
#property indicator_color3    LightSkyBlue   // lower repainting channel band (PowderBlue)
#property indicator_color4    CLR_NONE       // CLR_NONE Blue                    // LWMA
#property indicator_color5    Blue           // CLR_NONE Blue                    // upper non-repainting channel band
#property indicator_color6    Blue           // CLR_NONE Blue                    // lower non-repainting channel band
#property indicator_color7    Magenta        // long signals
#property indicator_color8    Magenta        // short signals

#property indicator_width1    1
#property indicator_width2    3
#property indicator_width3    3
#property indicator_width4    1
#property indicator_width5    1
#property indicator_width6    1
#property indicator_width7    6
#property indicator_width8    6

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

double longSignal [];
double shortSignal[];

int    appliedPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // HalfLength
   HalfLength = MathMax(HalfLength, 1);

   // AppliedPrice
   string sValues[], sValue = StrToLower(AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (appliedPrice==-1 || appliedPrice > PRICE_WEIGHTED) return(catch("onInit(1)  invalid input parameter AppliedPrice: "+ DoubleQuoteStr(AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   AppliedPrice = PriceTypeDescription(appliedPrice);

   // buffer management
   SetIndexBuffer(MODE_TMA,            tma         );
   SetIndexBuffer(MODE_UPPER_BAND_RP,  upperBandRP );
   SetIndexBuffer(MODE_LOWER_BAND_RP,  lowerBandRP );
   SetIndexBuffer(MODE_LWMA,           lwma        );
   SetIndexBuffer(MODE_UPPER_BAND_NRP, upperBandNRP);
   SetIndexBuffer(MODE_LOWER_BAND_NRP, lowerBandNRP);
   SetIndexBuffer(MODE_LONG_SIGNAL,    longSignal  ); SetIndexEmptyValue(MODE_LONG_SIGNAL,  0); SetIndexArrow(MODE_LONG_SIGNAL,  82);
   SetIndexBuffer(MODE_SHORT_SIGNAL,   shortSignal ); SetIndexEmptyValue(MODE_SHORT_SIGNAL, 0); SetIndexArrow(MODE_SHORT_SIGNAL, 82);

   // names, labels and display options
   IndicatorShortName(WindowExpertName());                  // chart tooltips and context menu
   SetIndexLabel(MODE_TMA,            "TMA");               // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_BAND_RP,  "TMA band RP");
   SetIndexLabel(MODE_LOWER_BAND_RP,  "TMA band RP");
   SetIndexLabel(MODE_LWMA,           "LWMA");
   SetIndexLabel(MODE_UPPER_BAND_NRP, "LWMA band NRP");
   SetIndexLabel(MODE_LOWER_BAND_NRP, "LWMA band NRP");
   SetIndexLabel(MODE_LONG_SIGNAL,    NULL);
   SetIndexLabel(MODE_SHORT_SIGNAL,   NULL);
   IndicatorDigits(Digits + 1);
   SetIndicatorOptions();

   return(catch("onInit(1)"));
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

   // reset all buffers before doing a full recalculation
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
      ArrayInitialize(longSignal,       0);
      ArrayInitialize(shortSignal,      0);
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
      ShiftIndicatorBuffer(longSignal,       Bars, ShiftedBars, 0);
      ShiftIndicatorBuffer(shortSignal,      Bars, ShiftedBars, 0);
   }


   // recalculate changed LWMA bars
   int bars = Min(ChangedBars, Max.Bars);
   int startBar = Min(bars-1, Bars-(HalfLength+1));
   if (startBar < 0) return(logInfo("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));

   for (int i=startBar; i >= 0; i--) {
      lwma[i] = iMA(NULL, NULL, HalfLength+1, 0, MODE_LWMA, appliedPrice, i);
   }
   //if (!UnchangedBars) debug("onTick()  lwma[44] = "+ NumberToStr(lwma[44], PriceFormat) +" (startBar="+ startBar +", "+ TimeToStr(Time[44], TIME_DATE|TIME_MINUTES) +")");


   // new TMA calculation at offset 0
   double values[];
   int offset = 0;
   CalculateTMAValues(values, offset);



   // original repainting TMA calculation
   bars = Min(Bars, Max.Bars);
   startBar = ChangedBars + HalfLength + 1;
   if (startBar >= bars) startBar = bars-1;
   CalculateTMA(bars, startBar);


   // signal calculation
   if (MarkSignals) {
    	for (i=startBar; i >= 0; i--) {
         longSignal [i] = 0;
         shortSignal[i] = 0;
         // original
         if (Low [i+1] < lowerBandRP[i+1] && Close[i+1] < Open[i+1] && Close[i] > Open[i]) longSignal [i] = Low [i];
         if (High[i+1] > upperBandRP[i+1] && Close[i+1] > Open[i+1] && Close[i] < Open[i]) shortSignal[i] = High[i];
         // new
         //if (( Low[i+1] < lowerBandRP[i+1] ||  Low[i] < lowerBandRP[i]) && Close[i] > Open[i] && !longSignal [i+1]) longSignal [i] =  Low[i];
         //if ((High[i+1] > upperBandRP[i+1] || High[i] > upperBandRP[i]) && Close[i] < Open[i] && !shortSignal[i+1]) shortSignal[i] = High[i];
      }
   }

   // alerts
   if (AlertsOn) {
      if (Close[0] > upperBandRP[0] && Close[1] < upperBandRP[1]) onSignal("upper channel band crossed");
      if (Close[0] < lowerBandRP[0] && Close[1] > lowerBandRP[1]) onSignal("lower channel band crossed");
   }
   return(0);
}


/**
 *
 */
void CalculateTMAValues(double &values[], int offset) {
   int halfLength = HalfLength;
   int fullLength = 2*halfLength + 1;
   ArrayResize(values, fullLength);

}


/**
 *
 */
void CalculateTMA(int bars, int startBar) {
   int j, w, FullLength=2*HalfLength + 1;

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
      upperBandRP[i] = tma[i] + BandsDeviations * MathSqrt(upperVarianceRP[i]);
      lowerBandRP[i] = tma[i] - BandsDeviations * MathSqrt(lowerVarianceRP[i]);
   }
   return;
   //upperBandNRP[0] = upperBandRP[0];
   //lowerBandNRP[0] = lowerBandRP[0];
}


/**
 * @param  int bar - bar offset
 *
 * @return double
 */
double GetPrice(int bar) {
   return(iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
   SetIndexStyle(MODE_LONG_SIGNAL,  DRAW_ARROW);
   SetIndexStyle(MODE_SHORT_SIGNAL, DRAW_ARROW);
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

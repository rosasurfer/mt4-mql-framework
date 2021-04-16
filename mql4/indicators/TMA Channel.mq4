/**
 * TMA Channel
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
extern int    Price           = PRICE_WEIGHTED;
extern double BandsDeviations = 2.5;
extern bool   AlertsOn        = false;
extern bool   MarkSignals     = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ManageIndicatorBuffer.mqh>

#define MODE_TMA              0              // indicator buffer ids
#define MODE_UPPER_BAND_RP    1              //
#define MODE_LOWER_BAND_RP    2              //
#define MODE_UPPER_BAND_NRP   3              //
#define MODE_LOWER_BAND_NRP   4              //
#define MODE_SHORT_SIGNALS    5              //
#define MODE_LONG_SIGNALS     6              //
#define MODE_UPPER_VARIANCE   7              // managed by the framework
#define MODE_LOWER_VARIANCE   8              // managed by the framework

#property indicator_chart_window
#property indicator_buffers   7
int       terminal_buffers  = 7;             // buffers managed by the terminal
int       framework_buffers = 2;             // buffers managed by the framework

#property indicator_color1    Magenta        // TMA
#property indicator_color2    LightPink      // upper repainting channel band
#property indicator_color3    PowderBlue     // lower repainting channel band
#property indicator_color4    CLR_NONE       // Blue           // upper non-repainting channel band
#property indicator_color5    CLR_NONE       // Blue           // lower non-repainting channel band
#property indicator_color6    Magenta        // short signals
#property indicator_color7    Magenta        // long signals

#property indicator_width1    1
#property indicator_width2    3
#property indicator_width3    3
#property indicator_width4    1
#property indicator_width5    1
#property indicator_width6    6
#property indicator_width7    6

#property indicator_style1    STYLE_DOT

double tma         [];
double upperBandRP [];
double lowerBandRP [];
double upperBandNRP[];
double lowerBandNRP[];

double upperVariance[];
double lowerVariance[];

double longSignals [];
double shortSignals[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   HalfLength = MathMax(HalfLength, 1);

   // buffer management
   SetIndexBuffer(MODE_TMA,            tma         ); SetIndexDrawBegin(MODE_TMA,            HalfLength);
   SetIndexBuffer(MODE_UPPER_BAND_RP,  upperBandRP ); SetIndexDrawBegin(MODE_UPPER_BAND_RP,  HalfLength);
   SetIndexBuffer(MODE_LOWER_BAND_RP,  lowerBandRP ); SetIndexDrawBegin(MODE_LOWER_BAND_RP,  HalfLength);
   SetIndexBuffer(MODE_UPPER_BAND_NRP, upperBandNRP); SetIndexDrawBegin(MODE_UPPER_BAND_NRP, HalfLength);
   SetIndexBuffer(MODE_LOWER_BAND_NRP, lowerBandNRP); SetIndexDrawBegin(MODE_LOWER_BAND_NRP, HalfLength);

   SetIndexBuffer(MODE_LONG_SIGNALS,  longSignals ); SetIndexStyle(MODE_LONG_SIGNALS,  DRAW_ARROW); SetIndexArrow(MODE_LONG_SIGNALS,  82);
   SetIndexBuffer(MODE_SHORT_SIGNALS, shortSignals); SetIndexStyle(MODE_SHORT_SIGNALS, DRAW_ARROW); SetIndexArrow(MODE_SHORT_SIGNALS, 82);
   //SetIndexBuffer(5, upperVariance);
   //SetIndexBuffer(6, lowerVariance);

   // names, labels and display options
   IndicatorShortName(WindowExpertName());                  // chart tooltips and context menu
   SetIndexLabel(MODE_TMA,            "TMA");               // chart tooltips and "Data" window
   SetIndexLabel(MODE_UPPER_BAND_RP,  "TMA channel RP");
   SetIndexLabel(MODE_LOWER_BAND_RP,  "TMA channel RP");
   SetIndexLabel(MODE_UPPER_BAND_NRP, "TMA channel NRP");
   SetIndexLabel(MODE_LOWER_BAND_NRP, "TMA channel NRP");
   SetIndexLabel(MODE_LONG_SIGNALS,   NULL);
   SetIndexLabel(MODE_SHORT_SIGNALS,  NULL);
   IndicatorDigits(Digits);
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

   ManageIndicatorBuffer(MODE_UPPER_VARIANCE, upperVariance);
   ManageIndicatorBuffer(MODE_LOWER_VARIANCE, lowerVariance);

   // reset all buffers before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(tma,           EMPTY_VALUE);
      ArrayInitialize(upperBandRP,   EMPTY_VALUE);
      ArrayInitialize(lowerBandRP,   EMPTY_VALUE);
      ArrayInitialize(upperBandNRP,  EMPTY_VALUE);
      ArrayInitialize(lowerBandNRP,  EMPTY_VALUE);
      ArrayInitialize(upperVariance, EMPTY_VALUE);
      ArrayInitialize(lowerVariance, EMPTY_VALUE);
      ArrayInitialize(longSignals,   EMPTY_VALUE);
      ArrayInitialize(shortSignals,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(tma,           Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperBandRP,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerBandRP,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperBandNRP,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerBandNRP,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(upperVariance, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(lowerVariance, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(longSignals,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(shortSignals,  Bars, ShiftedBars, EMPTY_VALUE);
   }



   // original
   int startBar = ChangedBars + 1 + HalfLength;
   if (startBar >= Bars) startBar = Bars-1;

   CalculateTMA(startBar);

   if (!MarkSignals) return(0);

 	for (int i=startBar; i >= 0; i--) {
      longSignals [i] = EMPTY_VALUE;
      shortSignals[i] = EMPTY_VALUE;

      if (Low [i+1] < lowerBandRP[i+1] && Close[i+1] < Open[i+1] && Close[i] > Open[i]) longSignals [i] = Low [i];
      if (High[i+1] > upperBandRP[i+1] && Close[i+1] > Open[i+1] && Close[i] < Open[i]) shortSignals[i] = High[i];
   }

   if (AlertsOn) {
      if (Close[0] >= upperBandRP[0] && Close[1] < upperBandRP[1]) onSignal("upper channel band crossed");
      if (Close[0] <= lowerBandRP[0] && Close[1] > lowerBandRP[1]) onSignal("lower channel band crossed");
   }
   return(0);
}


/**
 *
 */
void CalculateTMA(int startBar) {
   int j, k;
   double FullLength = 2*HalfLength + 1;

   for (int i=startBar; i >= 0; i--) {
      double sum  = (HalfLength+1) * iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i);
      double sumw = (HalfLength+1);

      for (j=1, k=HalfLength; j<=HalfLength; j++, k--) {
         sum  += k * iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i+j);
         sumw += k;
         if (j <= i) {
            sum  += k * iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i-j);
            sumw += k;
         }
      }
      tma[i] = sum/sumw;                     // at bar=0 same as iMA(NULL, NULL, HalfLength+1, 0, MODE_LWMA, Price, i)

      double diff = iMA(NULL, NULL, 1, 0, MODE_SMA, Price, i) - tma[i];

      if (i > Bars-HalfLength-1)
         continue;

      if (i == Bars-HalfLength-1) {
         if (diff >= 0) {
            upperVariance[i] = MathPow(diff, 2);
            lowerVariance[i] = 0;
         }
         else {
            upperVariance[i] = 0;
            lowerVariance[i] = MathPow(diff, 2);
         }
      }
      else {
         if (diff >= 0) {
            upperVariance[i] = (upperVariance[i+1] * (FullLength-1) + MathPow(diff, 2)) /FullLength;
            lowerVariance[i] = (lowerVariance[i+1] * (FullLength-1) + 0)                /FullLength;
         }
         else {
            upperVariance[i] = (upperVariance[i+1] * (FullLength-1) + 0)                /FullLength;
            lowerVariance[i] = (lowerVariance[i+1] * (FullLength-1) + MathPow(diff, 2)) /FullLength;
         }
      }
      upperBandRP[i] = tma[i] + BandsDeviations * MathSqrt(upperVariance[i]);
      lowerBandRP[i] = tma[i] - BandsDeviations * MathSqrt(lowerVariance[i]);

      if (i == 0) {
         upperBandNRP[i] = upperBandRP[i];
         lowerBandNRP[i] = lowerBandRP[i];
      }
   }
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(terminal_buffers);
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

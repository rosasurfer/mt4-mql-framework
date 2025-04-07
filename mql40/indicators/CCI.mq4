/**
 * Commodity Channel Index - a momentum indicator
 *
 * Defined as the upscaled ratio of current distance to average distance from a Moving Average (default: SMA).
 * The scaling factor of 66.67 was chosen so that the majority of indicator values falls between +200 and -200.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    CCI.Periods           = 14;
extern string CCI.AppliedPrice      = "Open | High | Low | Close | Median | Typical* | Weighted";

extern string ___a__________________________ = "=== Display settings ===";
extern color  Histogram.Color.Long  = LimeGreen;
extern color  Histogram.Color.Short = Red;
extern int    Histogram.Width       = 2;
extern int    MaxBarsBack           = 10000;       // max. values to calculate (-1: all available)

extern string ___b__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern string Signal.onTrendChange.Types     = "sound* | alert | mail | sms";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/IsBarOpen.mqh>

#define MODE_MAIN            0                     // indicator buffer ids
#define MODE_TREND           1
#define MODE_LONG            2
#define MODE_SHORT           3

#property indicator_separate_window
#property indicator_buffers  4                     // visible buffers

#property indicator_color1   CLR_NONE
#property indicator_color2   CLR_NONE
#property indicator_color3   CLR_NONE
#property indicator_color4   CLR_NONE

#property indicator_level1   +100
#property indicator_level2      0
#property indicator_level3   -100

#property indicator_maximum  +180
#property indicator_minimum  -180

double cci     [];                                 // all CCI values
double cciLong [];                                 // long trade segments
double cciShort[];                                 // short trade segments
double trend   [];                                 // trade segment length

int    cci.appliedPrice;

bool   signal.sound;
bool   signal.alert;
bool   signal.mail;
bool   signal.sms;

string indicatorName = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // CCI.Periods
   if (AutoConfiguration) CCI.Periods = GetConfigInt(indicator, "CCI.Periods", CCI.Periods);
   if (CCI.Periods < 1)        return(catch("onInit(1)  invalid input parameter CCI.Periods: "+ CCI.Periods +" (must be > 0)", ERR_INVALID_INPUT_PARAMETER));
   // CCI.AppliedPrice
   string sValues[], sValue = CCI.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "CCI.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "typical";              // default price type
   cci.appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (cci.appliedPrice == -1) return(catch("onInit(2)  invalid input parameter CCI.AppliedPrice: "+ DoubleQuoteStr(CCI.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   CCI.AppliedPrice = PriceTypeDescription(cci.appliedPrice);
   // Histogram.Width
   if (AutoConfiguration) Histogram.Width = GetConfigInt(indicator, "Histogram.Width", Histogram.Width);
   if (Histogram.Width < 0)    return(catch("onInit(3)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Width > 5)    return(catch("onInit(4)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.Long  = GetConfigColor(indicator, "Histogram.Color.Long",  Histogram.Color.Long);
   if (AutoConfiguration) Histogram.Color.Short = GetConfigColor(indicator, "Histogram.Color.Short", Histogram.Color.Short);
   if (Histogram.Color.Long  == 0xFF000000) Histogram.Color.Long  = CLR_NONE;
   if (Histogram.Color.Short == 0xFF000000) Histogram.Color.Short = CLR_NONE;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)       return(catch("onInit(5)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;

   // Signal.onTrendChange
   string signalId = "Signal.onTrendChange";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrendChange.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.sms)) {
         return(catch("onInit(6)  invalid input parameter Signal.onTrendChange.Types: "+ DoubleQuoteStr(Signal.onTrendChange.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.sound || signal.alert || signal.mail || signal.sms);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   SetIndicatorOptions();
   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands
   if (__isChart) {}

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(cci,      EMPTY_VALUE);
      ArrayInitialize(cciLong,  EMPTY_VALUE);
      ArrayInitialize(cciShort, EMPTY_VALUE);
      ArrayInitialize(trend,              0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(cci,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(cciLong,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(cciShort, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,    Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-CCI.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      // CCI: upscaled ratio of current to average distance from MA
      // ----------------------------------------------------------
      // double ma       = iMA(NULL, NULL, CCI.Periods, 0, MODE_SMA, cci.appliedPrice, bar);
      // double distance = GetPrice(bar) - ma;
      // double sum = 0;
      // for (int n=bar+CCI.Periods-1; n >= bar; n--) {
      //    sum += MathAbs(GetPrice(n) - ma);
      // }
      // double avgDistance = sum / CCI.Periods;
      // cci[bar] = MathDiv(distance, avgDistance) / 0.015;    // 1/0.015 = 66.6667

      cci[bar] = iCCI(NULL, NULL, CCI.Periods, cci.appliedPrice, bar);

      if (bar < Bars-1) {
         int prevTrend = trend[bar+1];

         // update trade direction and length
         if (prevTrend > 0) {
            if (cci[bar] > -100) trend[bar] = prevTrend + 1;   // continue long segment
            else                 trend[bar] = -1;              // new short signal
         }
         else if (prevTrend < 0) {
            if (cci[bar] < 100) trend[bar] = prevTrend - 1;    // continue short segment
            else                trend[bar] = 1;                // long signal
         }
         else if (cci[bar+1] != EMPTY_VALUE) {
            if (cci[bar+1] < 100 && cci[bar] >= 100) {
               trend[bar] = 1;                                 // 1st long signal
            }
            else if (cci[bar+1] > -100 && cci[bar] <= -100) {
               trend[bar] = -1;                                // 1st short signal
            }
         }

         // update direction buffers
         if (trend[bar] > 0) {
            cciLong [bar] = cci[bar];
            cciShort[bar] = EMPTY_VALUE;
         }
         else if (trend[bar] < 0) {
            cciLong [bar] = EMPTY_VALUE;
            cciShort[bar] = cci[bar];
         }
         else {
            cciLong [bar] = EMPTY_VALUE;
            cciShort[bar] = EMPTY_VALUE;
         }
      }
   }

   if (!__isSuperContext) {
      // monitor signals
      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {
         int iTrend = trend[1];
         if      (iTrend ==  1) onTrendChange(MODE_LONG);
         else if (iTrend == -1) onTrendChange(MODE_SHORT);
      }
   }
   return(catch("onTick(2)"));
}


/**
 * Event handler called on BarOpen if direction of the trend changed.
 *
 * @param  int direction
 *
 * @return bool - success status
 */
bool onTrendChange(int direction) {
   if (direction!=MODE_LONG && direction!=MODE_SHORT) return(!catch("onTrendChange(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // skip the signal if it already has been signaled elsewhere
   int hWnd = ifInt(__isTesting, __ExecutionContext[EC.chart], GetDesktopWindow());
   string sPeriod = PeriodDescription();
   string sEvent  = "rsf::"+ StdSymbol() +","+ sPeriod +"."+ indicatorName +".onTrendChange("+ direction +")."+ TimeToStr(Time[0]);
   if (GetPropA(hWnd, sEvent) != 0) return(true);
   SetPropA(hWnd, sEvent, 1);                         // immediately mark as signaled (prevents duplicate signals on slow CPU)

   string message = indicatorName +" signal "+ ifString(direction==MODE_LONG, "long", "short") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);

   message = Symbol() +","+ PeriodDescription() +": "+ message;
   string sAccount = "("+ TimeToStr(TimeLocalEx("onTrendChange(3)"), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";

   if (signal.alert) Alert(message);
   if (signal.sound) PlaySoundEx(ifString(direction==MODE_LONG, Signal.Sound.Up, Signal.Sound.Down));
   if (signal.mail)  SendEmail("", "", message, message + NL + sAccount);
   if (signal.sms)   SendSMS("", message + NL + sAccount);
   return(!catch("onTrendChange(4)"));
}


/**
 * Set indicator options. After recompilation the function must be called from start() for options not to be ignored.
 *
 * @param  bool redraw [optional] - whether to redraw the chart (default: no)
 *
 * @return bool - success status
 */
bool SetIndicatorOptions(bool redraw = false) {
   redraw = redraw!=0;
   indicatorName = "CCI("+ CCI.Periods +")";
   IndicatorShortName(indicatorName);

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,  cci     );
   SetIndexBuffer(MODE_LONG,  cciLong );
   SetIndexBuffer(MODE_SHORT, cciShort);
   SetIndexBuffer(MODE_TREND, trend   );
   IndicatorDigits(2);

   int drawBegin = Max(CCI.Periods-1, Bars-MaxBarsBack);
   SetIndexDrawBegin(MODE_LONG,  drawBegin);
   SetIndexDrawBegin(MODE_SHORT, drawBegin);

   SetIndexLabel(MODE_MAIN,  indicatorName);    // displays values in indicator and "Data" window
   SetIndexLabel(MODE_LONG,  NULL);
   SetIndexLabel(MODE_SHORT, NULL);
   SetIndexLabel(MODE_TREND, NULL);             // prevents trend value in indicator window

   SetIndexStyle(MODE_MAIN,  DRAW_NONE);
   SetIndexStyle(MODE_TREND, DRAW_NONE);

   int drawType = ifInt(Histogram.Width, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(MODE_LONG,  drawType, EMPTY, Histogram.Width, Histogram.Color.Long);
   SetIndexStyle(MODE_SHORT, drawType, EMPTY, Histogram.Width, Histogram.Color.Short);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("CCI.Periods=",                CCI.Periods,                                ";", NL,
                            "CCI.AppliedPrice=",           DoubleQuoteStr(CCI.AppliedPrice),           ";", NL,

                            "Histogram.Color.Long=",       ColorToStr(Histogram.Color.Long),           ";", NL,
                            "Histogram.Color.Short=",      ColorToStr(Histogram.Color.Short),          ";", NL,
                            "Histogram.Width=",            Histogram.Width,                            ";", NL,
                            "MaxBarsBack=",                MaxBarsBack,                                ";", NL,

                            "Signal.onTrendChange=",       BoolToStr(Signal.onTrendChange),            ";"+ NL,
                            "Signal.onTrendChange.Types=", DoubleQuoteStr(Signal.onTrendChange.Types), ";"+ NL,
                            "Signal.Sound.Up=",            DoubleQuoteStr(Signal.Sound.Up),            ";"+ NL,
                            "Signal.Sound.Down=",          DoubleQuoteStr(Signal.Sound.Down),          ";")
   );
}

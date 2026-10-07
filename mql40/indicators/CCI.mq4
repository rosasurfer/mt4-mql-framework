/**
 * Commodity Channel Index - a true momentum indicator. Measures sudden price acceleration.
 *
 * Defined as the upscaled ratio of current distance to average distance from a Moving Average (default: SMA).
 * The upscaling factor of 66.67 was chosen so that the majority of indicator values falls between +200 and -200.
 *
 * The signal level determines when the CCI histogram changes color. It changes upon the first cross of the signal level in
 * the other direction.
 *
 * A CCI crossing the signal level says nothing about trend. It simply says that above-average momentum has occurred in that
 * particular bar - nothing more, nothing less. Whether such a crossing leads to a trend becomes apparent only if price
 * continues to move in the same direction.
 *
 *
 * Input parameters
 * ----------------
 *  • Periods:                 Look-back periods.
 *  • Periods.Step:            Option to control parameter "Period" via keyboard. If non-zero it defines the step size of
 *                             the parameter stepper. If 0 (zero) stepping of parameter "Period" is disabled.
 *  • AppliedPrice:            Price type to use for CCI calculation.
 *
 *  • Histogram.Color.Up:      Color of histogram segments marking an assumed up trend.
 *  • Histogram.Color.Down:    Color of histogram segments marking an assumed down trend.
 *  • Histogram.Width:         Width of displayed histogram bars.
 *  • MaxBarsBack:             Maximum number of bars back to calculate the indicator for (affects performance).
 *
 *  • Signal.Level:            CCI level to cross to create a flip of the histogram color (default: +/-100).
 *  • Signal.onMomentum:       Whether to signal momentum bursts reaching the configured signal level.
 *  • Signal.onMomentum.Types: Signaling methods, a combination of "sound", "alert", "email" and/or "telegram".
 *  • Signal.Sound.Up:         Sound file for histogram changes to an assumed up trend.
 *  • Signal.Sound.Down:       Sound file for histogram changes to an assumed down trend.
 *
 *  • AutoConfiguration:       If enabled all input parameters can be pre-defined in the configuration.
 *
 *
 * TODO
 * ----
 *  - parameter stepper for Signal.Level
 *  - display additional indicator levels at signal level != 100 (needs input option)
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods                        = 20;
extern int    Periods.Step                   = 0;                       // step size for parameter stepping
extern string AppliedPrice                   = "Open | High | Low | Close | Median | Typical* | Weighted";

extern string ___a__________________________ = "=== Display settings ===";
extern color  Histogram.Color.Up             = LimeGreen;
extern color  Histogram.Color.Down           = Red;
extern int    Histogram.Width                = 2;
extern int    MaxBarsBack                    = 10000;                   // max. values to calculate (-1: all available)

extern string ___b__________________________ = "=== Signaling ===";
extern int    Signal.Level                   = 100;
extern bool   Signal.onMomentum              = false;
extern string Signal.onMomentum.Types        = "sound* | alert | mail | telegram";
extern string Signal.Sound.Up                = "Signal Up.wav";
extern string Signal.Sound.Down              = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/HandleCommands.mqh>
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

#property indicator_maximum  +200
#property indicator_minimum  -200

double cci     [];                                 // all CCI values
double cciLong [];                                 // long colored CCI values (contains positive + negative values)
double cciShort[];                                 // short colored CCI values (contains positive + negative values)
double trend   [];                                 // last color segment length

int appliedPrice;

bool signal.sound;
bool signal.alert;
bool signal.mail;
bool signal.telegram;

// parameter stepper directions
#define STEP_UP    1
#define STEP_DOWN -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // Periods
   if (AutoConfiguration) Periods = GetConfigInt(indicator, "Periods", Periods);
   if (Periods < 1)         return(catch("onInit(1)  invalid input parameter Periods: "+ Periods +" (must be > 0)", ERR_INVALID_INPUT_PARAMETER));
   // Periods.Step
   if (AutoConfiguration) Periods.Step = GetConfigInt(indicator, "Periods.Step", Periods.Step);
   if (Periods.Step < 0)    return(catch("onInit(2)  invalid input parameter Periods.Step: "+ Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // AppliedPrice
   string sValues[], sValue = AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "typical";              // default price type
   appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (appliedPrice == -1)  return(catch("onInit(3)  invalid input parameter AppliedPrice: "+ DoubleQuoteStr(AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   AppliedPrice = PriceTypeDescription(appliedPrice);
   // Histogram.Width
   if (AutoConfiguration) Histogram.Width = GetConfigInt(indicator, "Histogram.Width", Histogram.Width);
   if (Histogram.Width < 0) return(catch("onInit(4)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Width > 5) return(catch("onInit(5)  invalid input parameter Histogram.Width: "+ Histogram.Width +" (must be from 0-5)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Histogram.Color.Up   = GetConfigColor(indicator, "Histogram.Color.Up",   Histogram.Color.Up);
   if (AutoConfiguration) Histogram.Color.Down = GetConfigColor(indicator, "Histogram.Color.Down", Histogram.Color.Down);
   if (Histogram.Color.Up   == 0xFF000000) Histogram.Color.Up   = CLR_NONE;
   if (Histogram.Color.Down == 0xFF000000) Histogram.Color.Down = CLR_NONE;
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)    return(catch("onInit(6)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // Signal.Level
   if (AutoConfiguration) Signal.Level = GetConfigInt(indicator, "Signal.Level", Signal.Level);
   Signal.Level = Abs(Signal.Level);
   if (Signal.Level > 300)  return(catch("onInit(7)  invalid input parameter Signal.Level: "+ Signal.Level +" (must be from 0-300)", ERR_INVALID_INPUT_PARAMETER));

   // Signal.onMomentum
   string signalId = "Signal.onMomentum";
   ConfigureSignals(signalId, AutoConfiguration, Signal.onMomentum);
   if (Signal.onMomentum) {
      if (!ConfigureSignalTypes(signalId, Signal.onMomentum.Types, AutoConfiguration, signal.sound, signal.alert, signal.mail, signal.telegram)) {
         return(catch("onInit(7)  invalid input parameter Signal.onMomentum.Types: "+ DoubleQuoteStr(Signal.onMomentum.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onMomentum = (signal.sound || signal.alert || signal.mail || signal.telegram);
   }
   // Signal.Sound.*
   if (AutoConfiguration) Signal.Sound.Up   = GetConfigString(indicator, "Signal.Sound.Up",   Signal.Sound.Up);
   if (AutoConfiguration) Signal.Sound.Down = GetConfigString(indicator, "Signal.Sound.Down", Signal.Sound.Down);

   // reset an active command handler
   if (__isChart && Periods.Step) {
      GetChartCommand("ParameterStepper", sValues);
   }
   RestoreStatus();

   SetIndicatorOptions();
   return(catch("onInit(8)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

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
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-Periods), signalLevel = Signal.Level;
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

      cci[bar] = iCCI(NULL, NULL, Periods, appliedPrice, bar);

      if (bar < Bars-1) {
         int prevTrend = trend[bar+1];

         // update trend direction and length
         if (signalLevel != 0) {
            // signalLevel is non-zero: histogram color flips on touch
            if (prevTrend > 0) {
               if (cci[bar] > -signalLevel) trend[bar] = prevTrend + 1;       // continue long segment
               else                         trend[bar] = -1;                  // new short segment
            }
            else if (prevTrend < 0) {
               if (cci[bar] < signalLevel) trend[bar] = prevTrend - 1;        // continue short segment
               else                        trend[bar] = 1;                    // new log segment
            }
            else if (cci[bar+1] != EMPTY_VALUE) {
               if (cci[bar+1] < signalLevel && cci[bar] >= signalLevel) {
                  trend[bar] = 1;                                             // 1st long segment
               }
               else if (cci[bar+1] > -signalLevel && cci[bar] <= -signalLevel) {
                  trend[bar] = -1;                                            // 1st short segment
               }
            }
         }
         else {
            // signalLevel is zero: histogram color flips on cross
            if (prevTrend > 0) {
               if (cci[bar] >= 0) trend[bar] = prevTrend + 1;                 // continue long segment
               else               trend[bar] = -1;                            // new short segment
            }
            else if (prevTrend < 0) {
               if (cci[bar] <= 0) trend[bar] = prevTrend - 1;                 // continue short segment
               else               trend[bar] = 1;                             // new log segment
            }
            else if (cci[bar+1] != EMPTY_VALUE) {
               if (cci[bar+1] <= 0 && cci[bar] > 0) {
                  trend[bar] = 1;                                             // 1st long segment
               }
               else if (cci[bar+1] >= 0 && cci[bar] < 0) {
                  trend[bar] = -1;                                            // 1st short segment
               }
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

   if (!__isSuperContext && Signal.onMomentum) {
      if (IsBarOpen()) {
         int iTrend = trend[1];
         if      (iTrend ==  1) onMomentum(MODE_LONG);
         else if (iTrend == -1) onMomentum(MODE_SHORT);
      }
   }
   return(last_error);
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - flags of pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   if (cmd == "parameter") {
      if (params == "up")   return(ParameterStepper(STEP_UP, keys));
      if (params == "down") return(ParameterStepper(STEP_DOWN, keys));
   }
   return(!logNotice("onCommand(1)  unsupported command: "+ DoubleQuoteStr(cmd +":"+ params +":"+ keys)));
}


/**
 * Event handler called onBarOpen if sudden momentun occurred in the other direction.
 *
 * @param  int direction
 *
 * @return bool - success status
 */
bool onMomentum(int direction) {
   if (direction!=MODE_LONG && direction!=MODE_SHORT) return(!catch("onMomentum(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // compose signal messages
   string sPeriod   = PeriodDescription();
   string indicator = "CCI("+ Periods +")";
   string eventName = "rsf."+ StdSymbol() +","+ sPeriod +"."+ indicator +".onMomentum("+ direction +","+ Signal.Level +")."+ TimeToStr(Time[0]), propertyName = "";
   string sSigLevel = Signal.Level;
   if (Signal.Level != 0) sSigLevel = ifString(direction==MODE_LONG, "+", "-") + sSigLevel;
   string message1  = indicator +" momentum "+ ifString(direction==MODE_LONG, "up", "down") +": "+ sSigLevel +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   string message2  = Symbol() +","+ PeriodDescription() +": "+ message1;
   string localTime = TimeToStr(TimeLocalEx("onMomentum(2)"), TIME_MINUTES|TIME_SECONDS);
   string alias     = GetAccountAlias();

   int hWndTerminal = GetTerminalMainWindow(), hWndDesktop = GetDesktopWindow();
   bool eventAction;

   // log: once per terminal
   if (IsLogInfo()) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|log";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) logInfo("onMomentum(3)  "+ message1);
   }

   // sound: once per system
   if (signal.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(ifString(direction==MODE_LONG, Signal.Sound.Up, Signal.Sound.Down));
   }

   // alert: once per terminal
   if (signal.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ alias +")");
   }

   // telegram: once per system
   if (signal.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ alias +")");
   }
   return(!catch("onMomentum(4)"));
}


/**
 * Step up/down an input parameter.
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - pressed modifier keys
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // step up/down input parameter "Periods"
   int step = Periods.Step;

   if (!step || Periods + direction*step < 1) {       // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) Periods += step;
   else                      Periods -= step;

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads and terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"Periods", Periods);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart.
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (!__isChart) return(true);
   string prefix = "rsf."+ WindowExpertName() +".";

   int iValue;
   if (Chart.RestoreInt(prefix +"Periods", iValue)) {       // restore and remove it
      if (Periods.Step > 0) {                               // apply if stepper is still active
         if (iValue > 0) Periods = iValue;                  // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
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

   string stepSize      = ifString(Periods.Step, ":"+ Periods.Step, "");
   string sAppliedPrice = ifString(appliedPrice==PRICE_TYPICAL, "", ", "+ PriceTypeDescription(appliedPrice));
   string sSignal       = ifString(Signal.onMomentum, "  signal@"+ Signal.Level, "") +"  ";
   string name          = "CCI("+ Periods + stepSize + sAppliedPrice +")"+ sSignal;
   IndicatorShortName(name);                          // subwindow chart legend

   IndicatorBuffers(indicator_buffers);
   SetIndexBuffer(MODE_MAIN,  cci     );
   SetIndexBuffer(MODE_LONG,  cciLong );
   SetIndexBuffer(MODE_SHORT, cciShort);
   SetIndexBuffer(MODE_TREND, trend   );
   IndicatorDigits(2);

   int drawBegin = Max(Periods-1, Bars-MaxBarsBack);
   SetIndexDrawBegin(MODE_LONG,  drawBegin);
   SetIndexDrawBegin(MODE_SHORT, drawBegin);

   SetIndexLabel(MODE_MAIN,  "CCI("+ Periods +")");   // "Data" window labels
   SetIndexLabel(MODE_LONG,  NULL);
   SetIndexLabel(MODE_SHORT, NULL);
   SetIndexLabel(MODE_TREND, NULL);

   SetIndexStyle(MODE_MAIN,  DRAW_NONE);
   SetIndexStyle(MODE_TREND, DRAW_NONE);

   int drawType = ifInt(Histogram.Width, DRAW_HISTOGRAM, DRAW_NONE);
   SetIndexStyle(MODE_LONG,  drawType, EMPTY, Histogram.Width, Histogram.Color.Up);
   SetIndexStyle(MODE_SHORT, drawType, EMPTY, Histogram.Width, Histogram.Color.Down);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "Periods=",                 Periods,                                 ";", NL,
      "Periods.Step=",            Periods.Step,                            ";", NL,
      "AppliedPrice=",            DoubleQuoteStr(AppliedPrice),            ";", NL,

      "Histogram.Color.Up=",      ColorToStr(Histogram.Color.Up),          ";", NL,
      "Histogram.Color.Down=",    ColorToStr(Histogram.Color.Down),        ";", NL,
      "Histogram.Width=",         Histogram.Width,                         ";", NL,
      "MaxBarsBack=",             MaxBarsBack,                             ";", NL,

      "Signal.Level=",            Signal.Level,                            ";", NL,
      "Signal.onMomentum=",       BoolToStr(Signal.onMomentum),            ";", NL,
      "Signal.onMomentum.Types=", DoubleQuoteStr(Signal.onMomentum.Types), ";", NL,
      "Signal.Sound.Up=",         DoubleQuoteStr(Signal.Sound.Up),         ";", NL,
      "Signal.Sound.Down=",       DoubleQuoteStr(Signal.Sound.Down),       ";")
   );
}

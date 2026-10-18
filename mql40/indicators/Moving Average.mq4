/**
 * A "Moving Average" indicator with additional non-standard features.
 *
 *
 * Moving Average methods
 * ----------------------
 *  - SMA  = Simple Moving Average:          equal bar weighting
 *  - LWMA = Linear Weighted Moving Average: bar weighting using a linear function
 *  - EMA  = Exponential Moving Average:     bar weighting using an exponential function
 *  - SMMA = Smoothed Moving Average:        bar weighting using an exponential function (@see notes)
 *  - ALMA = Arnaud Legoux Moving Average:   bar weighting using a Gaussian function (@see notes)
 *
 *
 * Trend calculation methods
 * -------------------------
 *  - Slope:   The standard method. Trend changes when MA slope changes direction.
 *  - Channel: Trend changes when bars cross the High/Low channel of the same MA (requires MA.AppliedPrice != High|Low).
 *
 *
 * Input parameters
 * ----------------
 *
 *
 * Usage with iCustom()
 * --------------------
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values denote a downtrend (-1...-n)
 *    - trend length:           the absolute value of the direction is the trend length in bars since the last reversal
 *
 *
 * Notes
 * -----
 *  - EMA calculation:
 *    @link https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Exponential_moving_average
 *
 *  - SMMA calculation: The SMMA is in fact an EMA with a different period. It holds true: SMMA(n) = EMA(2*n-1)
 *    @link https://web.archive.org/web/20221120050520/https://en.wikipedia.org/wiki/Moving_average#Modified_moving_average
 *
 *  - ALMA calculation:
 *    @link http://web.archive.org/web/20180307031850/http://www.arnaudlegoux.com/
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string MA.Method                      = "SMA* | LWMA | EMA | SMMA | ALMA";
extern int    MA.Periods                     = 100;
extern int    MA.Periods.Step                = 0;                 // step size for parameter stepping
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Typical | Weighted";
extern string Trend.Method                   = "Slope* | Channel";

extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern int    Background.Width               = 2;                 // background for Draw.Type = "Line"
extern color  Background.Color               = DarkGray;
extern color  UpTrend.Color                  = DeepSkyBlue;
extern color  DownTrend.Color                = Gold;

extern string ___a__________________________ = "=== Display options ===";
extern bool   ShowChartLegend                = true;
extern int    MaxBarsBack                    = 10000;             // max. values to calculate (-1: all available)
extern int    SaveCPU                        = 0;                 // update the current bar every X seconds only

extern string ___b__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern string Signal.onTrendChange.Types     = "sound* | alert | mail | telegram";
extern string Signal.onTrendChange.SoundUp   = "Signal Up.wav";
extern string Signal.onTrendChange.SoundDown = "Signal Down.wav";

extern string Sound.onCross                  = "off* | up | down";
extern string Sound.onCross.File             = "Signal Cross.wav";
extern int    Sound.onCross.Repeat           = 8;                 // how many times to repeat the sound
extern int    Sound.onCross.Pause            = 2;                 // how many seconds to pause between consecutive sounds

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/chartlegend.mqh>
#include <rsf/functions/ConfigureSignals.mqh>
#include <rsf/functions/HandleCommands.mqh>
#include <rsf/functions/IsBarOpen.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/functions/trend.mqh>
#include <rsf/functions/ta/ALMA.mqh>
#include <rsf/win32api.mqh>

#define MODE_MA               MovingAverage.MODE_MA      // 0: indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND   // 1
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4
#define MODE_UPPER_BAND       5
#define MODE_LOWER_BAND       6

#property indicator_chart_window
#property indicator_buffers  5
int       terminal_buffers = 7;

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double main     [];                                      // MA main values:      visible (background), displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend  [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

int    maMethod;
int    maAppliedPrice;
double almaWeights[];                                    // ALMA bar weights (if applicable)
int    trendMethod;
double upperChannelBand[];                               // MA channel bands for trend method TREND_CHANNEL
double lowerChannelBand[];                               //

string indicatorName = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
int    drawType;

bool   signal.onTrendChange.sound;
bool   signal.onTrendChange.alert;
bool   signal.onTrendChange.mail;
bool   signal.onTrendChange.telegram;

int    sound.onCross;
int    sound.onCross.played;                             // how many times the sound has been played

#define MODE_UP         MODE_UPTREND                     // trend/price crossing directions
#define MODE_DOWN       MODE_DOWNTREND

#define TREND_SLOPE     1                                // trend calculation methods
#define TREND_CHANNEL   2

#define STEP_UP         1                                // parameter stepper directions
#define STEP_DOWN      -1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // MA.Method
   string sValues[], sValue = MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)       return(catch("onInit(1)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)       return(catch("onInit(2)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Periods.Step
   if (AutoConfiguration) MA.Periods.Step = GetConfigInt(indicator, "MA.Periods.Step", MA.Periods.Step);
   if (MA.Periods.Step < 0)  return(catch("onInit(3)  invalid input parameter MA.Periods.Step: "+ MA.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   if (StrTrim(sValue) == "") sValue = "close";               // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1) return(catch("onInit(4)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Trend.Method
   sValue = Trend.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Trend.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("slope",   sValue)) { trendMethod = TREND_SLOPE;   Trend.Method = "Slope";   }
   else if (StrStartsWith("channel", sValue)) { trendMethod = TREND_CHANNEL; Trend.Method = "Channel"; }
   else                      return(catch("onInit(5)  invalid input parameter Trend.Method: "+ DoubleQuoteStr(Trend.Method), ERR_INVALID_INPUT_PARAMETER));
   if (trendMethod == TREND_CHANNEL) {
      if (maAppliedPrice==PRICE_HIGH || maAppliedPrice==PRICE_LOW) {
         return(catch("onInit(6)  invalid parameter combination MA.AppliedPrice/Trend.Method: trend method \"Channel\" can't be used with price types \"High/Low\"", ERR_INVALID_INPUT_PARAMETER));
      }
   }
   // Draw.Type
   sValue = Draw.Type;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "Draw.Type", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                      return(catch("onInit(7)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)       return(catch("onInit(8)  invalid input parameter Draw.Width: "+ Draw.Width +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // Background.Width
   if (AutoConfiguration) Background.Width = GetConfigInt(indicator, "Background.Width", Background.Width);
   if (Background.Width < 0) return(catch("onInit(9)  invalid input parameter Background.Width: "+ Background.Width +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Background.Color = GetConfigColor(indicator, "Background.Color", Background.Color);
   if (AutoConfiguration) UpTrend.Color    = GetConfigColor(indicator, "UpTrend.Color",    UpTrend.Color);
   if (AutoConfiguration) DownTrend.Color  = GetConfigColor(indicator, "DownTrend.Color",  DownTrend.Color);
   if (Background.Color == 0xFF000000) Background.Color = CLR_NONE;
   if (UpTrend.Color    == 0xFF000000) UpTrend.Color    = CLR_NONE;
   if (DownTrend.Color  == 0xFF000000) DownTrend.Color  = CLR_NONE;
   // ShowChartLegend
   if (AutoConfiguration) ShowChartLegend = GetConfigBool(indicator, "ShowChartLegend", ShowChartLegend);
   // MaxBarsBack
   if (AutoConfiguration) MaxBarsBack = GetConfigInt(indicator, "MaxBarsBack", MaxBarsBack);
   if (MaxBarsBack < -1)     return(catch("onInit(10)  invalid input parameter MaxBarsBack: "+ MaxBarsBack, ERR_INVALID_INPUT_PARAMETER));
   if (MaxBarsBack == -1) MaxBarsBack = INT_MAX;
   // SaveCPU
   if (AutoConfiguration) SaveCPU = GetConfigInt(indicator, "SaveCPU", SaveCPU);
   if (SaveCPU <  0)         return(catch("onInit(11)  illegal input parameter SaveCPU: "+ SaveCPU +" (must be from 0-59)", ERR_INVALID_INPUT_PARAMETER));
   if (SaveCPU > 59)         return(catch("onInit(12)  illegal input parameter SaveCPU: "+ SaveCPU +" (must be from 0-59)", ERR_INVALID_INPUT_PARAMETER));

   // Signal.onTrendChange.*
   string signalId = "Signal.onTrendChange";
   legendInfo = "";
   if (!ConfigureSignals(signalId, AutoConfiguration, Signal.onTrendChange)) return(last_error);
   if (Signal.onTrendChange) {
      if (!ConfigureSignalTypes(signalId, Signal.onTrendChange.Types, AutoConfiguration, signal.onTrendChange.sound, signal.onTrendChange.alert, signal.onTrendChange.mail, signal.onTrendChange.telegram)) {
         return(catch("onInit(13)  invalid input parameter Signal.onTrendChange.Types: "+ DoubleQuoteStr(Signal.onTrendChange.Types), ERR_INVALID_INPUT_PARAMETER));
      }
      Signal.onTrendChange = (signal.onTrendChange.sound || signal.onTrendChange.alert || signal.onTrendChange.mail || signal.onTrendChange.telegram);
      if (Signal.onTrendChange) {
         legendInfo = "("+ StrLeft(ifString(signal.onTrendChange.sound, "sound,", "") + ifString(signal.onTrendChange.alert, "alert,", "") + ifString(signal.onTrendChange.mail, "mail,", "") + ifString(signal.onTrendChange.telegram, "tgm,", ""), -1) +")";
         legendInfo = StrReplace(legendInfo, "sound,alert", "alert");
      }
      if (AutoConfiguration) Signal.onTrendChange.SoundUp   = GetConfigString(indicator, "Signal.onTrendChange.SoundUp",   Signal.onTrendChange.SoundUp);
      if (AutoConfiguration) Signal.onTrendChange.SoundDown = GetConfigString(indicator, "Signal.onTrendChange.SoundDown", Signal.onTrendChange.SoundDown);
   }

   // Sound.onCross.*
   sound.onCross = NULL;
   sound.onCross.played = 0;
   if (AutoConfiguration) Sound.onCross = GetConfigString(indicator, "Sound.onCross", Sound.onCross);
   sValue = Sound.onCross;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if      (sValue == "")                  { Sound.onCross = "off";                             }
   else if (StrStartsWith("off",  sValue)) { Sound.onCross = "off";                             }
   else if (StrStartsWith("up",   sValue)) { Sound.onCross = "up";   sound.onCross = MODE_UP;   }
   else if (StrStartsWith("down", sValue)) { Sound.onCross = "down"; sound.onCross = MODE_DOWN; }
   else                             return(catch("onInit(14)  invalid input parameter Sound.onCross: "+ DoubleQuoteStr(Sound.onCross), ERR_INVALID_INPUT_PARAMETER));
   if (sound.onCross != NULL) {
      if (AutoConfiguration) Sound.onCross.File = GetConfigString(indicator, "Sound.onCross.File", Sound.onCross.File);
      if (AutoConfiguration) Sound.onCross.Repeat = GetConfigInt(indicator, "Sound.onCross.Repeat", Sound.onCross.Repeat);
      if (Sound.onCross.Repeat < 0) return(catch("onInit(15)  invalid input parameter Sound.onCross.Repeat: "+ Sound.onCross.Repeat +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
      if (AutoConfiguration) Sound.onCross.Pause = GetConfigInt(indicator, "Sound.onCross.Pause", Sound.onCross.Pause);
      if (Sound.onCross.Pause < 0)  return(catch("onInit(16)  invalid input parameter Sound.onCross.Pause: "+ Sound.onCross.Pause +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
      if (legendInfo == "") legendInfo = "(c)";
      else                  legendInfo = StrLeft(legendInfo, -1) +",c)";
      ShowChartLegend = 1;
      SaveCPU = 0;
   }

   // reset an active command handler
   if (__isChart && MA.Periods.Step) {
      GetChartCommand("ParameterStepper", sValues);
   }
   RestoreStatus();

   // calculate ALMA bar weights
   if (maMethod == MODE_ALMA) {
      double almaOffset=0.85, almaSigma=6.0;
      ALMA.CalculateWeights(MA.Periods, almaOffset, almaSigma, almaWeights);
   }

   if (ShowChartLegend) legendLabel = CreateChartLegend();
   SetIndicatorOptions();

   return(catch("onInit(17)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   StoreStatus();
   return(last_error);
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && MA.Periods.Step) {
      if (!HandleCommands("ParameterStepper")) return(last_error);
   }

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(main,      EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      ArrayInitialize(uptrend,   EMPTY_VALUE);
      ArrayInitialize(downtrend, EMPTY_VALUE);
      ArrayInitialize(uptrend2,  EMPTY_VALUE);
      ArrayInitialize(upperChannelBand,    0);
      ArrayInitialize(lowerChannelBand,    0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(main,             Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,            Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(uptrend,          Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(downtrend,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(uptrend2,         Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(upperChannelBand, Bars, ShiftedBars, 0);
      ShiftDoubleIndicatorBuffer(lowerChannelBand, Bars, ShiftedBars, 0);
   }

   // save CPU cycles if enabled (current bar only)
   if (ChangedBars == 1) {
      if (!__isSuperContext && SaveCPU) {
         static datetime lastUpdate = NULL;
         if (lastUpdate + SaveCPU > Tick.time) {
            return(last_error);
         }
         lastUpdate = Tick.time;
      }
   }

   // calculate start bar
   int startbar = Min(MaxBarsBack-1, ChangedBars-1, Bars-MA.Periods);
   if (startbar < 0 && MaxBarsBack) return(logInfo("onTick(1)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      if (maMethod == MODE_ALMA) {              // ALMA
         main[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {   // TODO: move nested loop to MT4Expander (performance)
            main[bar] += almaWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
         }
         if (trendMethod == TREND_CHANNEL) {
            upperChannelBand[bar] = 0;
            lowerChannelBand[bar] = 0;
            for (i=0; i < MA.Periods; i++) {    // TODO: move nested loop to MT4Expander (performance)
               upperChannelBand[bar] += almaWeights[i] * High[bar+i];
               lowerChannelBand[bar] += almaWeights[i] * Low [bar+i];
            }
         }
      }
      else {                                    // built-in moving averages
         main[bar] = iMA(NULL, NULL, MA.Periods, 0, maMethod, maAppliedPrice, bar);

         if (trendMethod == TREND_CHANNEL) {
            upperChannelBand[bar] = iMA(NULL, NULL, MA.Periods, 0, maMethod, PRICE_HIGH, bar);
            lowerChannelBand[bar] = iMA(NULL, NULL, MA.Periods, 0, maMethod, PRICE_LOW,  bar);
         }
      }
      UpdateMaTrend(bar);
   }

   if (!__isSuperContext) {
      if (__isChart && ShowChartLegend) UpdateTrendLegend(legendLabel, indicatorName, legendInfo, UpTrend.Color, DownTrend.Color, main[0], trend[0]);

      // signal price crossings
      static double lastBid = 0;
      if (ChangedBars > 2) lastBid = 0;

      if (lastBid > 0) {
         if (sound.onCross == MODE_UP) {
            if (Bid >= main[0]) {
               if (lastBid < main[0] || sound.onCross.played) {
                  onCross(MODE_UP);
               }
            }
         }
         else if (sound.onCross == MODE_DOWN) {
            if (Bid <= main[0]) {
               if (lastBid > main[0] || sound.onCross.played) {
                  onCross(MODE_DOWN);
               }
            }
         }
      }
      lastBid = _Bid;

      // signal trend changes
      if (Signal.onTrendChange) /*&&*/ if (IsBarOpen()) {
         int iTrend = trend[1];
         if      (iTrend ==  1) onTrendChange(MODE_UP);
         else if (iTrend == -1) onTrendChange(MODE_DOWN);
      }
   }
   return(last_error);
}


/**
 * Event handler for price crossings.
 *
 * @param  int direction - direction identifier
 *
 * @return bool - success status
 */
bool onCross(int direction) {
   if (direction!=MODE_UP && direction!=MODE_DOWN) return(!catch("onCross(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   static int lastSound;

   if (Sound.onCross.Repeat > 0) {
      int msecPause = Sound.onCross.Pause * 1000;

      if (lastSound + msecPause < GetTickCount()) {      // pause between consecutive sounds
         if (!PlaySoundEx(Sound.onCross.File)) {
            lastSound = GetTickCount();
            sound.onCross.played++;
            Sound.onCross.Repeat--;
         }
      }
   }
   return(!catch("onCross(2)"));
}


/**
 * Event handler for trend changes.
 *
 * @param  int direction - direction identifier
 *
 * @return bool - success status
 */
bool onTrendChange(int direction) {
   if (direction!=MODE_UP && direction!=MODE_DOWN) return(!catch("onTrendChange(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // skip the signal if it was already handled elsewhere
   string sPeriod   = PeriodDescription();
   string eventName = "rsf."+ StdSymbol() +","+ sPeriod +"."+ MA.Method +"("+ MA.Periods +", "+ PriceTypeDescription(maAppliedPrice) +").onTrendChange("+ direction +")."+ TimeToStr(Time[0]), propertyName = "";
   string message1  = indicatorName +" turned "+ ifString(direction==MODE_UP, "up", "down") +" (bid: "+ NumberToStr(_Bid, PriceFormat) +")";
   string message2  = Symbol() +","+ sPeriod +": "+ message1;
   string localTime = TimeToStr(TimeLocalEx("onTrendChange(2)"), TIME_MINUTES|TIME_SECONDS);
   string acntAlias = GetAccountAlias();

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
      if (eventAction) logInfo("onTrendChange(3)  "+ message1);
   }

   // sound: once per system
   if (signal.onTrendChange.sound) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|sound";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) PlaySoundEx(ifString(direction==MODE_UP, Signal.onTrendChange.SoundUp, Signal.onTrendChange.SoundDown));
   }

   // alert: once per terminal
   if (signal.onTrendChange.alert) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|alert";
         eventAction = !GetWindowPropertyA(hWndTerminal, propertyName);
         SetWindowPropertyA(hWndTerminal, propertyName, 1);
      }
      if (eventAction) Alert(message2);
   }

   // mail: once per system
   if (signal.onTrendChange.mail) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|mail";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendEmail("", "", message2, message2 + NL +"("+ localTime +", "+ acntAlias +")");
   }

   // telegram: once per system
   if (signal.onTrendChange.telegram) {
      eventAction = true;
      if (!__isTesting) {
         propertyName = eventName +"|telegram";
         eventAction = !GetWindowPropertyA(hWndDesktop, propertyName);
         SetWindowPropertyA(hWndDesktop, propertyName, 1);
      }
      if (eventAction) SendTelegramMessage("signal", message2 + NL +"("+ localTime +", "+ acntAlias +")");
   }
   return(!catch("onTrendChange(4)"));
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
 * Step up/down an input parameter.
 *
 * @param  int direction - STEP_UP | STEP_DOWN
 * @param  int keys      - pressed modifier keys
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, int keys) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));

   // step up/down input parameter "MA.Periods"
   int step = MA.Periods.Step;

   if (!step || MA.Periods + direction*step < 1) {       // stop if parameter limit reached
      PlaySoundEx("Plonk.wav");
      return(false);
   }
   if (direction == STEP_UP) MA.Periods += step;
   else                      MA.Periods -= step;

   if (maMethod == MODE_ALMA) {                          // recalculate ALMA bar weights
      double almaOffset=0.85, almaSigma=6.0;
      ALMA.CalculateWeights(MA.Periods, almaOffset, almaSigma, almaWeights);
   }

   ChangedBars = Bars;
   ValidBars   = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Update the Moving Average's buffers for trend direction and coloring.
 *
 * @param  int bar - bar offset to update
 *
 * @return bool - success status
 */
bool UpdateMaTrend(int bar) {
   if (trendMethod == TREND_SLOPE) {
      return(UpdateTrend(main, bar, trend, uptrend, downtrend, uptrend2, true, true, drawType, Digits));
   }

   if (trendMethod == TREND_CHANNEL) {
      if (bar == Bars-1) {
         trend    [bar] = 0;
         uptrend  [bar] = EMPTY_VALUE;
         downtrend[bar] = EMPTY_VALUE;
         uptrend2 [bar] = EMPTY_VALUE;
         return(true);
      }

      // trend direction/length
      int prevTrend = trend[bar+1];
      if      (Close[bar] > upperChannelBand[bar]) trend[bar] = Max(prevTrend, 0) + 1;
      else if (Close[bar] < lowerChannelBand[bar]) trend[bar] = Min(prevTrend, 0) - 1;
      else                                         trend[bar] = prevTrend + Sign(prevTrend);

      // trend coloring
      if (trend[bar] > 0) {                                                // uptrend
         uptrend  [bar] = main[bar];
         downtrend[bar] = EMPTY_VALUE;

         if (drawType == DRAW_LINE) {                                      // if DRAW_LINE...
            if      (trend[bar+1] < 0) uptrend  [bar+1] = main[bar+1];     // and downtrend before, set another data point to make the terminal draw the line
            else if (trend[bar+1] > 0) downtrend[bar+1] = EMPTY_VALUE;
         }
      }
      else if (trend[bar] < 0) {                                           // downtrend
         uptrend  [bar] = EMPTY_VALUE;
         downtrend[bar] = main[bar];

         if (drawType == DRAW_LINE) {                                      // if DRAW_LINE...
            if (trend[bar+1] > 0) {                                        // and uptrend before, set another data point to make the terminal draw the line
               downtrend[bar+1] = main[bar+1];
               if (Bars > bar+2) {
                  if (trend[bar+2] < 0) {                                  // if that uptrend was a 1-bar reversal, copy it to uptrend2 (to overlay),
                     uptrend2[bar+2] = main[bar+2];                        // otherwise the visual gets lost through the just added data point
                     uptrend2[bar+1] = main[bar+1];
                  }
               }
            }
            else if (trend[bar+1] < 0) {
               uptrend[bar+1] = EMPTY_VALUE;
            }
         }
      }
      else if (main[bar] != EMPTY_VALUE) {                                 // trend length is 0 (still undefined during the first visible swing)
         if (main[bar+1] == EMPTY_VALUE) {
            uptrend  [bar] = EMPTY_VALUE;
            downtrend[bar] = EMPTY_VALUE;
         }
         else if (main[bar] > main[bar+1]) {
            uptrend  [bar] = main[bar];
            downtrend[bar] = EMPTY_VALUE;
         }
         else /*main[bar] < main[bar+1]*/ {
            uptrend  [bar] = EMPTY_VALUE;
            downtrend[bar] = main[bar];
         }
      }
      return(true);
   }

   return(!catch("UpdateMaTrend(1)  illegal trendMethod: "+ trendMethod, ERR_ILLEGAL_STATE));
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

   // names, labels and display options
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   string stepSize      = ifString(MA.Periods.Step, ":"+ MA.Periods.Step, "");
   indicatorName        = MA.Method +"("+ MA.Periods + stepSize + sAppliedPrice +")";
   string shortName     = MA.Method +"("+ MA.Periods +")";
   IndicatorShortName(shortName);                        // chart tooltips and context menu

   IndicatorBuffers(terminal_buffers);
   SetIndexBuffer(MODE_MA,         main            );    // MA main values:       background, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,      trend           );    // trend direction:      invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,    uptrend         );    // uptrend values:       visible
   SetIndexBuffer(MODE_DOWNTREND,  downtrend       );    // downtrend values:     visible
   SetIndexBuffer(MODE_UPTREND2,   uptrend2        );    // single-bar uptrends:  visible
   SetIndexBuffer(MODE_UPPER_BAND, upperChannelBand);    // for TREND_CHANNEL:    invisible
   SetIndexBuffer(MODE_LOWER_BAND, lowerChannelBand);    // ...
   IndicatorDigits(Digits);

   int width = Draw.Width + Background.Width;
   int type = ifInt(drawType==DRAW_LINE && width, drawType, DRAW_NONE);
   SetIndexStyle(MODE_MA,        type,      EMPTY, width, Background.Color);
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY, CLR_NONE        );

   type = ifInt(Draw.Width, drawType, DRAW_NONE);
   SetIndexStyle(MODE_UPTREND,   type, EMPTY, Draw.Width, UpTrend.Color  ); SetIndexArrow(MODE_UPTREND,   158);
   SetIndexStyle(MODE_DOWNTREND, type, EMPTY, Draw.Width, DownTrend.Color); SetIndexArrow(MODE_DOWNTREND, 158);
   SetIndexStyle(MODE_UPTREND2,  type, EMPTY, Draw.Width, UpTrend.Color  ); SetIndexArrow(MODE_UPTREND2,  158);

   SetIndexLabel(MODE_MA,        shortName);
   SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexLabel(MODE_UPTREND,   NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);

   if (redraw) WindowRedraw();
   return(!catch("SetIndicatorOptions(1)"));
}


/**
 * Store the status of the parameter stepper in the chart (for init cyles, template reloads and terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && MA.Periods.Step) {
      string prefix = "rsf."+ WindowExpertName() +".";
      Chart.StoreInt(prefix +"MA.Periods", MA.Periods);
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
   if (Chart.RestoreInt(prefix +"MA.Periods", iValue)) {    // restore and remove it
      if (MA.Periods.Step > 0) {                            // apply if stepper is still active
         if (iValue > 0) MA.Periods = iValue;               // silent validation
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate(
      "MA.Method=",                      DoubleQuoteStr(MA.Method)                      +";"+ NL,
      "MA.Periods=",                     MA.Periods                                     +";"+ NL,
      "MA.Periods.Step=",                MA.Periods.Step                                +";"+ NL,
      "MA.AppliedPrice=",                DoubleQuoteStr(MA.AppliedPrice)                +";"+ NL,
      "Trend.Method=",                   DoubleQuoteStr(Trend.Method)                   +";"+ NL,

      "Draw.Type=",                      DoubleQuoteStr(Draw.Type)                      +";"+ NL,
      "Draw.Width=",                     Draw.Width                                     +";"+ NL,
      "Background.Width=",               Background.Width                               +";"+ NL,
      "Background.Color=",               ColorToStr(Background.Color)                   +";"+ NL,
      "UpTrend.Color=",                  ColorToStr(UpTrend.Color)                      +";"+ NL,
      "DownTrend.Color=",                ColorToStr(DownTrend.Color)                    +";"+ NL,

      "ShowChartLegend=",                BoolToStr(ShowChartLegend)                     +";"+ NL,
      "MaxBarsBack=",                    MaxBarsBack                                    +";"+ NL,
      "SaveCPU=",                        SaveCPU                                        +";"+ NL,

      "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange)                +";"+ NL,
      "Signal.onTrendChange.Types=",     DoubleQuoteStr(Signal.onTrendChange.Types)     +";"+ NL,
      "Signal.onTrendChange.SoundUp=",   DoubleQuoteStr(Signal.onTrendChange.SoundUp)   +";"+ NL,
      "Signal.onTrendChange.SoundDown=", DoubleQuoteStr(Signal.onTrendChange.SoundDown) +";"+ NL,

      "Sound.onCross=",                  DoubleQuoteStr(Sound.onCross)                  +";"+ NL,
      "Sound.onCross.File=",             DoubleQuoteStr(Sound.onCross.File)             +";"+ NL,
      "Sound.onCross.Repeat=",           Sound.onCross.Repeat                           +";"+ NL,
      "Sound.onCross.Pause=",            Sound.onCross.Pause                            +";"+ NL
   ));
}

/**
 * NonLag Moving Average
 *
 * A moving average using a cosine wave function for weight calculation. Corrected and enhanced version of the original
 * published by Igor Durkin aka igorad.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 *  @link  https://www.forexfactory.com/thread/571026#                                           [NonLag Moving Average v4.0]
 *  @link  http://www.yellowfx.com/nonlagma-v7-1-mq4-indicator.htm#                              [NonLag Moving Average v7.1]
 *  @link  http://www.mql5.com/en/forum/175037/page62#comment_4583907                            [NonLag Moving Average v7.8]
 *  @link  https://www.mql5.com/en/forum/175037/page74#comment_4584032                           [NonLag Moving Average v7.9]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    WaveCycle.Periods              = 20;                // bar periods per cosine wave cycle
extern int    WaveCycle.Periods.Step         = 0;                 // step size for a stepped input parameter (hotkeys)
extern string MA.AppliedPrice                = "Open | High | Low | Close* | Median | Average | Typical | Weighted";
extern double MA.ReversalFilter              = 0.7;               // min. MA change in std-deviations for a trend reversal
extern double MA.ReversalFilter.Step         = 0;                 // step size for a stepped input parameter (hotkeys + VK_SHIFT)

extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  Color.UpTrend                  = Magenta;
extern color  Color.DownTrend                = Yellow;
extern int    Max.Bars                       = 10000;             // max. values to calculate (-1: all available)

extern string ___a__________________________ = "=== Signaling ===";
extern bool   Signal.onTrendChange           = false;
extern bool   Signal.onTrendChange.Sound     = true;
extern string Signal.onTrendChange.SoundUp   = "Signal Up.wav";
extern string Signal.onTrendChange.SoundDown = "Signal Down.wav";
extern bool   Signal.onTrendChange.Popup     = false;
extern bool   Signal.onTrendChange.Mail      = false;
extern bool   Signal.onTrendChange.SMS       = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/trend.mqh>
#include <functions/legend.mqh>
#include <functions/ta/NLMA.mqh>

#define MODE_MA_FILTERED      MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4
#define MODE_MA_RAW           5
#define MODE_MA_CHANGE        6
#define MODE_AVG              7

#property indicator_chart_window
#property indicator_buffers   5                          // visible buffers
int       terminal_buffers  = 8;                         // all buffers

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double maRaw     [];                                     // MA raw main values:      invisible
double maFiltered[];                                     // MA filtered main values: invisible, displayed in legend and "Data" window
double trend     [];                                     // trend direction:         invisible, displayed in "Data" window
double uptrend   [];                                     // uptrend values:          visible
double downtrend [];                                     // downtrend values:        visible
double uptrend2  [];                                     // single-bar uptrends:     visible

double maChange  [];                                     // absolute change of current maRaw[] to previous maFiltered[]
double maAverage [];                                     // average of maChange[] over the last 'waveCyclePeriods' bars

int    waveCycles = 4;                                   // 4 initial cycles (1 more is added later)
int    maPeriods;
int    maAppliedPrice;
double maWeights[];                                      // bar weighting of the MA
int    drawType;
int    maxValues;

string indicatorName = "";
string shortName     = "";
string legendLabel   = "";
string legendInfo    = "";                               // additional chart legend info
bool   enableMultiColoring;

bool   signalTrendChange;
bool   signalTrendChange.sound;
bool   signalTrendChange.popup;
bool   signalTrendChange.mail;
string signalTrendChange.mailSender   = "";
string signalTrendChange.mailReceiver = "";
bool   signalTrendChange.sms;
string signalTrendChange.smsReceiver = "";

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
   // WaveCycle.Periods
   if (AutoConfiguration) WaveCycle.Periods = GetConfigInt(indicator, "WaveCycle.Periods", WaveCycle.Periods);
   if (WaveCycle.Periods < 3)                                return(catch("onInit(1)  invalid input parameter WaveCycle.Periods: "+ WaveCycle.Periods +" (min. 3)", ERR_INVALID_INPUT_PARAMETER));
   // WaveCycle.Periods.Step
   if (AutoConfiguration) WaveCycle.Periods.Step = GetConfigInt(indicator, "WaveCycle.Periods.Step", WaveCycle.Periods.Step);
   if (WaveCycle.Periods.Step < 0)                           return(catch("onInit(2)  invalid input parameter WaveCycle.Periods.Step: "+ WaveCycle.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.AppliedPrice
   string sValues[], sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_AVERAGE) return(catch("onInit(3)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // MA.ReversalFilter
   if (AutoConfiguration) MA.ReversalFilter = GetConfigDouble(indicator, "MA.ReversalFilter", MA.ReversalFilter);
   if (MA.ReversalFilter < 0)                                return(catch("onInit(4)  invalid input parameter MA.ReversalFilter: "+ NumberToStr(MA.ReversalFilter, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter.StepS
   if (AutoConfiguration) MA.ReversalFilter.Step = GetConfigDouble(indicator, "MA.ReversalFilter.Step", MA.ReversalFilter.Step);
   if (MA.ReversalFilter.Step < 0)                           return(catch("onInit(5)  invalid input parameter MA.ReversalFilter.Step: "+ NumberToStr(MA.ReversalFilter.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else                                                      return(catch("onInit(6)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)                                       return(catch("onInit(7)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend);
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // Max.Bars
   if (AutoConfiguration) Max.Bars = GetConfigInt(indicator, "Max.Bars", Max.Bars);
   if (Max.Bars < -1)                                        return(catch("onInit(8)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // signaling
   signalTrendChange       = Signal.onTrendChange;
   signalTrendChange.sound = Signal.onTrendChange.Sound;
   signalTrendChange.popup = Signal.onTrendChange.Popup;
   signalTrendChange.mail  = Signal.onTrendChange.Mail;
   signalTrendChange.sms   = Signal.onTrendChange.SMS;
   legendInfo              = "";
   string signalId = "Signal.onTrendChange";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalTrendChange)) return(last_error);
   if (signalTrendChange) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalTrendChange.sound))                                                              return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalTrendChange.popup))                                                              return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalTrendChange.mail, signalTrendChange.mailSender, signalTrendChange.mailReceiver)) return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalTrendChange.sms, signalTrendChange.smsReceiver))                                 return(last_error);
      if (signalTrendChange.sound || signalTrendChange.popup || signalTrendChange.mail || signalTrendChange.sms) {
         legendInfo = StrLeft(ifString(signalTrendChange.sound, "sound,", "") + ifString(signalTrendChange.popup, "popup,", "") + ifString(signalTrendChange.mail, "mail,", "") + ifString(signalTrendChange.sms, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else signalTrendChange = false;
   }

   // restore a stored runtime status
   RestoreStatus();

   // buffer management and options
   SetIndexBuffer(MODE_MA_RAW,      maRaw     );   // MA raw main values:      invisible
   SetIndexBuffer(MODE_MA_FILTERED, maFiltered);   // MA filtered main values: invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,       trend     );   // trend direction:         invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,     uptrend   );   // uptrend values:          visible
   SetIndexBuffer(MODE_DOWNTREND,   downtrend );   // downtrend values:        visible
   SetIndexBuffer(MODE_UPTREND2,    uptrend2  );   // single-bar uptrends:     visible
   SetIndexBuffer(MODE_MA_CHANGE,   maChange  );   //                          invisible
   SetIndexBuffer(MODE_AVG,         maAverage );   //                          invisible
   SetIndicatorOptions();

   // calculate NLMA bar weights
   NLMA.CalculateWeights(waveCycles, WaveCycle.Periods, maWeights);
   maPeriods = ArraySize(maWeights);

   // chart legend and coloring
   legendLabel = CreateLegend();
   enableMultiColoring = !__isSuperContext;

   return(catch("onInit(9)"));
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
   int starttime = GetTickCount();

   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(maRaw)) return(logInfo("onTick(1)  sizeof(maRaw) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // process incoming commands (may rewrite ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && (WaveCycle.Periods.Step || MA.ReversalFilter.Step)) HandleCommands("ParameterStepper", false);

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(maRaw,                0);
      ArrayInitialize(maFiltered, EMPTY_VALUE);
      ArrayInitialize(maChange,             0);
      ArrayInitialize(maAverage,            0);
      ArrayInitialize(trend,                0);
      ArrayInitialize(uptrend,    EMPTY_VALUE);
      ArrayInitialize(downtrend,  EMPTY_VALUE);
      ArrayInitialize(uptrend2,   EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(maRaw,      Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(maFiltered, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(maChange,   Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(maAverage,  Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(trend,      Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(uptrend,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(downtrend,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(uptrend2,   Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startbar = Min(bars-1, Bars-maPeriods);
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ maPeriods, ERR_HISTORY_INSUFFICIENT));

   double sum, stdDev, minChange;

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      maRaw[bar] = 0;
      for (int i=0; i < maPeriods; i++) {
         maRaw[bar] += maWeights[i] * GetPrice(maAppliedPrice, bar+i);
      }
      maFiltered[bar] = maRaw[bar];

      if (MA.ReversalFilter > 0) {
         maChange[bar] = maFiltered[bar] - maFiltered[bar+1];        // calculate the change of current raw to previous filtered MA
         sum = 0;
         for (i=0; i < WaveCycle.Periods; i++) {                     // calculate average(change) over last 'WaveCycle.Periods'
            sum += maChange[bar+i];
         }
         maAverage[bar] = sum/WaveCycle.Periods;

         if (maChange[bar] * trend[bar+1] < 0) {                     // on opposite signs = trend reversal
            sum = 0;                                                 // calculate stdDeviation(maChange[]) over last 'WaveCycle.Periods'
            for (i=0; i < WaveCycle.Periods; i++) {
               sum += MathPow(maChange[bar+i] - maAverage[bar+i], 2);
            }
            stdDev = MathSqrt(sum/WaveCycle.Periods);
            minChange = MA.ReversalFilter * stdDev;                  // calculate required min. change

            if (MathAbs(maChange[bar]) < minChange) {
               maFiltered[bar] = maFiltered[bar+1];                  // discard trend reversal if MA change is smaller
            }
         }
      }
      UpdateTrendDirection(maFiltered, bar, trend, uptrend, downtrend, uptrend2, enableMultiColoring, enableMultiColoring, drawType, Digits);
   }

   if (!__isSuperContext) {
      UpdateTrendLegend(legendLabel, indicatorName, legendInfo, Color.UpTrend, Color.DownTrend, maFiltered[0], Digits, trend[0], Time[0]);

      if (signalTrendChange) /*&&*/ if (IsBarOpen()) {               // monitor trend reversals
         int iTrend = Round(trend[1]);
         if      (iTrend ==  1) onTrendChange(MODE_UPTREND);
         else if (iTrend == -1) onTrendChange(MODE_DOWNTREND);
      }
   }

   int millis = (GetTickCount()-starttime);
   //if (!ValidBars) debug("onTick(0.1)  Tick="+ Ticks +"  bars="+ (startbar+1) +"  time="+ DoubleToStr(millis/1000., 3) +" sec");
   return(last_error);
}


/**
 * Event handler for trend changes.
 *
 * @param  int trend - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int trend) {
   string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = NO_ERROR;

   if (trend == MODE_UPTREND) {
      message = shortName +" turned up (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signalTrendChange.popup)          Alert(message);
      if (signalTrendChange.sound) error |= PlaySoundEx(Signal.onTrendChange.SoundUp);
      if (signalTrendChange.mail)  error |= !SendEmail(signalTrendChange.mailSender, signalTrendChange.mailReceiver, message, message + NL + accountTime);
      if (signalTrendChange.sms)   error |= !SendSMS(signalTrendChange.smsReceiver, message + NL + accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = shortName +" turned down (bid: "+ NumberToStr(Bid, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signalTrendChange.popup)          Alert(message);
      if (signalTrendChange.sound) error |= PlaySoundEx(Signal.onTrendChange.SoundDown);
      if (signalTrendChange.mail)  error |= !SendEmail(signalTrendChange.mailSender, signalTrendChange.mailReceiver, message, message + NL + accountTime);
      if (signalTrendChange.sms)   error |= !SendSMS(signalTrendChange.smsReceiver, message + NL + accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend: "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd                  - command name
 * @param  string params [optional]    - command parameters (default: none)
 * @param  string modifiers [optional] - command modifiers (default: none)
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params="", string modifiers="") {
   static int lastTickcount = 0;
   int tickcount = StrToInteger(params);

   // stepper cmds are not removed from the queue: compare tickcount with last processed command and skip if old
   if (__isChart) {
      string label = "rsf."+ WindowExpertName() +".cmd.tickcount";
      bool objExists = (ObjectFind(label) != -1);

      if (objExists) lastTickcount = StrToInteger(ObjectDescription(label));
      if (tickcount <= lastTickcount) return(false);

      if (!objExists) ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
      ObjectSetText(label, ""+ tickcount);
   }
   else if (tickcount <= lastTickcount) return(false);
   lastTickcount = tickcount;

   bool shiftKey = (modifiers == "VK_SHIFT");

   if (cmd == "parameter-up")   return(ParameterStepper(STEP_UP, shiftKey));
   if (cmd == "parameter-down") return(ParameterStepper(STEP_DOWN, shiftKey));

   return(!logNotice("onCommand(1)  unsupported command: \""+ cmd +":"+ params +":"+ modifiers +"\""));
}


/**
 * Step up/down an input parameter.
 *
 * @param  int  direction - STEP_UP | STEP_DOWN
 * @param  bool shiftKey  - whether VK_SHIFT was pressed when receiving the stepper command
 *
 * @return bool - success status
 */
bool ParameterStepper(int direction, bool shiftKey) {
   if (direction!=STEP_UP && direction!=STEP_DOWN) return(!catch("ParameterStepper(1)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
   shiftKey = shiftKey!=0;

   if (!shiftKey) {
      // step up/down input parameter "WaveCycle.Periods"
      double step = WaveCycle.Periods.Step;

      if (!step || WaveCycle.Periods + direction*step < 3) {   // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) WaveCycle.Periods += step;
      else                      WaveCycle.Periods -= step;

      if (!NLMA.CalculateWeights(waveCycles, WaveCycle.Periods, maWeights)) return(false);
      maPeriods = ArraySize(maWeights);
   }
   else {
      // step up/down input parameter "MA.ReversalFilter"
      step = MA.ReversalFilter.Step;

      if (!step || MA.ReversalFilter + direction*step < 0) {   // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) MA.ReversalFilter += step;
      else                      MA.ReversalFilter -= step;
   }

   ChangedBars = Bars;
   ValidBars   = 0;
   ShiftedBars = 0;

   PlaySoundEx("Parameter Step.wav");
   return(true);
}


/**
 * Get the price of the specified type at the given bar offset.
 *
 * @param  int type - price type
 * @param  int i    - bar offset
 *
 * @return double - price or NULL in case of errors
 */
double GetPrice(int type, int i) {
   if (i < 0 || i >= Bars) return(!catch("GetPrice(1)  invalid parameter i: "+ i +" (out of range)", ERR_INVALID_PARAMETER));

   switch (type) {
      case PRICE_CLOSE:                                                          // 0
      case PRICE_BID:      return(Close[i]);                                     // 8
      case PRICE_OPEN:     return( Open[i]);                                     // 1
      case PRICE_HIGH:     return( High[i]);                                     // 2
      case PRICE_LOW:      return(  Low[i]);                                     // 3
      case PRICE_MEDIAN:                                                         // 4: (H+L)/2
      case PRICE_TYPICAL:                                                        // 5: (H+L+C)/3
      case PRICE_WEIGHTED: return(iMA(NULL, NULL, 1, 0, MODE_SMA, type, i));     // 6: (H+L+C+C)/4
      case PRICE_AVERAGE:  return((Open[i] + High[i] + Low[i] + Close[i])/4);    // 7: (O+H+L+C)/4
   }
   return(!catch("GetPrice(2)  invalid or unsupported price type: "+ type, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   string sMaFilter     = ifString(MA.ReversalFilter || MA.ReversalFilter.Step, "/"+ NumberToStr(MA.ReversalFilter, ".1+"), "");
   string sAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName        = "NonLagMA("+ ifString(WaveCycle.Periods.Step || MA.ReversalFilter.Step, "step:", "") + WaveCycle.Periods + sMaFilter + sAppliedPrice +")";
   shortName            = "NLMA("+ WaveCycle.Periods +")";
   IndicatorShortName(shortName);

   int draw_type = ifInt(Draw.Width, drawType, DRAW_NONE);

   IndicatorBuffers(terminal_buffers);
   SetIndexStyle(MODE_MA_FILTERED, DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_MA_FILTERED, shortName);
   SetIndexStyle(MODE_TREND,       DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );                                     SetIndexLabel(MODE_TREND,       shortName +" trend");
   SetIndexStyle(MODE_UPTREND,     draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND,   158); SetIndexLabel(MODE_UPTREND,     NULL);
   SetIndexStyle(MODE_DOWNTREND,   draw_type, EMPTY, Draw.Width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 158); SetIndexLabel(MODE_DOWNTREND,   NULL);
   SetIndexStyle(MODE_UPTREND2,    draw_type, EMPTY, Draw.Width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  158); SetIndexLabel(MODE_UPTREND2,    NULL);
   IndicatorDigits(Digits);
}


/**
 * Store the status of an active parameter stepper in the chart (for init cyles, template reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool StoreStatus() {
   if (__isChart && (WaveCycle.Periods.Step || MA.ReversalFilter.Step)) {
      string prefix = "rsf."+ WindowExpertName() +".";

      Chart.StoreInt   (prefix +"WaveCycle.Periods", WaveCycle.Periods);
      Chart.StoreDouble(prefix +"MA.ReversalFilter", MA.ReversalFilter);
   }
   return(catch("StoreStatus(1)"));
}


/**
 * Restore the status of the parameter stepper from the chart if it wasn't changed in between (for init cyles, template
 * reloads and/or terminal restarts).
 *
 * @return bool - success status
 */
bool RestoreStatus() {
   if (__isChart) {
      string prefix = "rsf."+ WindowExpertName() +".";

      int iValue;
      if (Chart.RestoreInt(prefix +"WaveCycle.Periods", iValue)) {
         if (WaveCycle.Periods.Step > 0) {
            if (iValue >= 3) WaveCycle.Periods = iValue;       // silent validation
         }
      }

      double dValue;
      if (Chart.RestoreDouble(prefix +"MA.ReversalFilter", dValue)) {
         if (MA.ReversalFilter.Step > 0) {
            if (dValue >= 0) MA.ReversalFilter = dValue;       // silent validation
         }
      }
   }
   return(!catch("RestoreStatus(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("WaveCycle.Periods=",              WaveCycle.Periods,                              ";"+ NL,
                            "WaveCycle.Periods.Step=",         WaveCycle.Periods.Step,                         ";"+ NL,
                            "MA.AppliedPrice=",                DoubleQuoteStr(MA.AppliedPrice),                ";"+ NL,
                            "MA.ReversalFilter=",              NumberToStr(MA.ReversalFilter, ".1+"),          ";"+ NL,
                            "MA.ReversalFilter.Step=",         NumberToStr(MA.ReversalFilter.Step, ".1+"),     ";"+ NL,

                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";"+ NL,
                            "Draw.Width=",                     Draw.Width,                                     ";"+ NL,
                            "Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";"+ NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";"+ NL,
                            "Max.Bars=",                       Max.Bars,                                       ";"+ NL,

                            "Signal.onTrendChange=",           BoolToStr(Signal.onTrendChange),                ";"+ NL,
                            "Signal.onTrendChange.Sound=",     BoolToStr(Signal.onTrendChange.Sound),          ";"+ NL,
                            "Signal.onTrendChange.SoundUp=",   DoubleQuoteStr(Signal.onTrendChange.SoundUp),   ";"+ NL,
                            "Signal.onTrendChange.SoundDown=", DoubleQuoteStr(Signal.onTrendChange.SoundDown), ";"+ NL,
                            "Signal.onTrendChange.Popup=",     BoolToStr(Signal.onTrendChange.Popup),          ";"+ NL,
                            "Signal.onTrendChange.Mail=",      BoolToStr(Signal.onTrendChange.Mail),           ";"+ NL,
                            "Signal.onTrendChange.SMS=",       BoolToStr(Signal.onTrendChange.SMS),            ";")
   );
}

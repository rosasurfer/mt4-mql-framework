/**
 * T3 Moving Average by Tim Tillson
 *
 * The T3 is a six-pole nonlinear Kalman filter. Kalman filters use the error to correct themselves. In technical analysis
 * they are called adaptive moving averages, they track the time series more aggressively when it makes large moves.
 *
 * The input parameter 'T3.Periods' is scaled following Matulich (2). This modification is of cosmetic nature only, it makes
 * the T3 look more synchron with an SMA or EMA with the same 'Periods' parameter.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 *  @see   (1) "/etc/doc/t3ma/Smoothing Techniques for More Accurate Signals [Tillson].pdf"    [Stocks & Commodities, 1998/1]
 *  @link  (2) http://unicorn.us.com/trading/el.html#_T3Average                                 [T3 Moving Average, Matulich]
 *
 *  @see   additional notes at the end of this file
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___a__________________________ = "=== T3 settings ===";
extern int    T3.Periods                     = 14;                // bar periods for alpha calculation
extern int    T3.Periods.Step                = 0;                 // step size for a stepped input parameter (default keys)
extern double T3.VolumeFactor                = 0.7;
extern double T3.VolumeFactor.Step           = 0;                 // step size for a stepped input parameter (default keys + VK_LWIN)
extern string T3.AppliedPrice                = "Open | High | Low | Close* | Median | Average | Typical | Weighted";

extern string ___b__________________________ = "=== Trend reversal filter ===";
extern double MA.ReversalFilter              = 0;                 // min. MA change in std-deviations for a trend reversal
extern double MA.ReversalFilter.Step         = 0;                 // step size for a stepped input parameter (default keys + VK_SHIFT)

extern string ___c__________________________ = "=== Drawing options ===";
extern string Draw.Type                      = "Line* | Dot";
extern int    Draw.Width                     = 3;
extern color  Color.UpTrend                  = Magenta;
extern color  Color.DownTrend                = Yellow;
extern int    Max.Bars                       = 10000;             // max. values to calculate (-1: all available)

extern string ___d__________________________ = "=== Signaling ===";
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
#include <functions/ManageDoubleIndicatorBuffer.mqh>
#include <functions/legend.mqh>
#include <functions/trend.mqh>

#define MODE_MA_FILTERED      MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND2         4
#define MODE_MA_RAW           5
#define MODE_MA_CHANGE        6
#define MODE_AVG              7
#define MODE_EMA1             8
#define MODE_EMA2             9
#define MODE_EMA3            10
#define MODE_EMA4            11
#define MODE_EMA5            12
#define MODE_EMA6            13

#property indicator_chart_window
#property indicator_buffers   5                          // visible buffers
int       terminal_buffers  = 8;                         // buffers managed by the terminal
int       framework_buffers = 6;                         // buffers managed by the framework

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

double maChange [];                                      // absolute change of current maRaw[] to previous maFiltered[]
double maAverage[];                                      // average of maChange[] over the last 'MA.Periods' bars

double ema1[];                                           // EMA buffers
double ema2[];                                           //
double ema3[];                                           //
double ema4[];                                           //
double ema5[];                                           //
double ema6[];                                           //

double c1;                                               // T3 coefficients
double c2;                                               //
double c3;                                               //
double c4;                                               //
double alpha;                                            // weight of the current price

int    appliedPrice;
int    requiredBars;
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
   // T3.Periods
   if (AutoConfiguration) T3.Periods = GetConfigDouble(indicator, "T3.Periods", T3.Periods);
   if (T3.Periods < 1)                                   return(catch("onInit(1)  invalid input parameter T3.Periods: "+ T3.Periods, ERR_INVALID_INPUT_PARAMETER));
   // T3.Periods.Step
   if (AutoConfiguration) T3.Periods.Step = GetConfigInt(indicator, "T3.Periods.Step", T3.Periods.Step);
   if (T3.Periods.Step < 0)                              return(catch("onInit(2)  invalid input parameter T3.Periods.Step: "+ T3.Periods.Step +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // T3.VolumeFactor
   if (AutoConfiguration) T3.VolumeFactor = GetConfigDouble(indicator, "T3.VolumeFactor", T3.VolumeFactor);
   if (LT(T3.VolumeFactor, 0) || GT(T3.VolumeFactor, 1)) return(catch("onInit(3)  invalid input parameter T3.VolumeFactor: "+ NumberToStr(T3.VolumeFactor, ".1+") +" (must be from 0 to 1)", ERR_INVALID_INPUT_PARAMETER));
   // T3.VolumeFactor.Step
   if (AutoConfiguration) T3.VolumeFactor.Step = GetConfigDouble(indicator, "T3.VolumeFactor.Step", T3.VolumeFactor.Step);
   if (T3.VolumeFactor.Step < 0)                         return(catch("onInit(4)  invalid input parameter T3.VolumeFactor.Step: "+ NumberToStr(T3.VolumeFactor.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // T3.AppliedPrice
   string sValues[], sValue = T3.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "T3.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   appliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (appliedPrice==-1 || appliedPrice > PRICE_AVERAGE) return(catch("onInit(5)  invalid input parameter T3.AppliedPrice: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   T3.AppliedPrice = PriceTypeDescription(appliedPrice);
   // MA.ReversalFilter
   if (AutoConfiguration) MA.ReversalFilter = GetConfigDouble(indicator, "MA.ReversalFilter", MA.ReversalFilter);
   if (MA.ReversalFilter < 0)                            return(catch("onInit(6)  invalid input parameter MA.ReversalFilter: "+ NumberToStr(MA.ReversalFilter, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
   // MA.ReversalFilter.StepS
   if (AutoConfiguration) MA.ReversalFilter.Step = GetConfigDouble(indicator, "MA.ReversalFilter.Step", MA.ReversalFilter.Step);
   if (MA.ReversalFilter.Step < 0)                       return(catch("onInit(7)  invalid input parameter MA.ReversalFilter.Step: "+ NumberToStr(MA.ReversalFilter.Step, ".1+") +" (must be >= 0)", ERR_INVALID_INPUT_PARAMETER));
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
   else                                                  return(catch("onInit(8)  invalid input parameter Draw.Type: "+ DoubleQuoteStr(sValue), ERR_INVALID_INPUT_PARAMETER));
   // Draw.Width
   if (AutoConfiguration) Draw.Width = GetConfigInt(indicator, "Draw.Width", Draw.Width);
   if (Draw.Width < 0)                                   return(catch("onInit(9)  invalid input parameter Draw.Width: "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.UpTrend   = GetConfigColor(indicator, "Color.UpTrend",   Color.UpTrend  );
   if (AutoConfiguration) Color.DownTrend = GetConfigColor(indicator, "Color.DownTrend", Color.DownTrend);
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;
   // Max.Bars
   if (AutoConfiguration) Max.Bars = GetConfigInt(indicator, "Max.Bars", Max.Bars);
   if (Max.Bars < -1)                                    return(catch("onInit(10)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
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
   SetIndexBuffer(MODE_MA_RAW,      maRaw     );      // MA raw main values:      invisible
   SetIndexBuffer(MODE_MA_FILTERED, maFiltered);      // MA filtered main values: invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,       trend     );      // trend direction:         invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND,     uptrend   );      // uptrend values:          visible
   SetIndexBuffer(MODE_DOWNTREND,   downtrend );      // downtrend values:        visible
   SetIndexBuffer(MODE_UPTREND2,    uptrend2  );      // single-bar uptrends:     visible
   SetIndexBuffer(MODE_MA_CHANGE,   maChange  );      //                          invisible
   SetIndexBuffer(MODE_AVG,         maAverage );      //                          invisible
   SetIndicatorOptions();

   // chart legend and coloring
   legendLabel = CreateLegend();
   enableMultiColoring = !__isSuperContext;

   InitializeT3();
   return(catch("onInit(11)"));
}


/**
 * Initialize T3 calculation.
 *
 * @return bool - success status
 */
bool InitializeT3() {                                 // see notes at the end of this file
   double v = T3.VolumeFactor;

   // initialize T3 coefficients and weight of the current price (alpha)
   c1 = -1*v*v*v;                                     // -1v³
   c2 =  3*v*v*v +3*v*v;                              //  3v³ +3v²
   c3 = -3*v*v*v -6*v*v -3*v;                         // -3v³ -6v² -3v
   c4 =  1*v*v*v +3*v*v +3*v +1;                      //  1v³ +3v² +3v +1
   alpha = 4./(T3.Periods + 3);                       // Matulich: 2/(N+1) with N = (N-1)/2 + 1

   // initialize required bars for 99.9% of weights covered by known data
   double rel   = MathPow(0.999, 1/6.);               // 99.9% reliability for all EMAs => 99.98% per single EMA
   double bars  = MathLog(1-rel)/MathLog(1-alpha);    // k = log(1-rel)/log(1-alpha)
   requiredBars = MathCeil(bars);

   return(!catch("InitializeT3(1)"));
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

   // process incoming commands (rewrites ValidBars/ChangedBars/ShiftedBars)
   if (__isChart && (T3.Periods.Step || MA.ReversalFilter.Step)) HandleCommands("ParameterStepper", false);

   ManageDoubleIndicatorBuffer(MODE_EMA1, ema1);
   ManageDoubleIndicatorBuffer(MODE_EMA2, ema2);
   ManageDoubleIndicatorBuffer(MODE_EMA3, ema3);
   ManageDoubleIndicatorBuffer(MODE_EMA4, ema4);
   ManageDoubleIndicatorBuffer(MODE_EMA5, ema5);
   ManageDoubleIndicatorBuffer(MODE_EMA6, ema6);

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
      ArrayInitialize(ema1,                 0);
      ArrayInitialize(ema2,                 0);
      ArrayInitialize(ema3,                 0);
      ArrayInitialize(ema4,                 0);
      ArrayInitialize(ema5,                 0);
      ArrayInitialize(ema6,                 0);
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
      ShiftDoubleIndicatorBuffer(ema1,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema2,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema3,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema4,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema5,       Bars, ShiftedBars,           0);
      ShiftDoubleIndicatorBuffer(ema6,       Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int limit = Min(ChangedBars, Bars-1, maxValues+requiredBars-1);      // how many bars need recalculation
   int startbar = limit-1;
   if (Bars < requiredBars) return(logInfo("onTick(2)  Tick="+ Ticks +"  Bars="+ Bars +"  needed="+ requiredBars, ERR_HISTORY_INSUFFICIENT));

   if (!ValidBars) {
      string name = "T3MA() first accessed bar";
      if (ObjectFind(name) == -1) if (!ObjectCreateRegister(name, OBJ_VLINE, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet    (name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet    (name, OBJPROP_COLOR, Blue);
      ObjectSet    (name, OBJPROP_BACK,  true);
      ObjectSet    (name, OBJPROP_TIME1, Time[limit]);
      ObjectSetText(name, "T3("+ T3.Periods +") first accessed bar");

      name = "T3MA() first reliable bar";
      if (ObjectFind(name) == -1) if (!ObjectCreateRegister(name, OBJ_VLINE, 0, 0, 0, 0, 0, 0, 0)) return(false);
      ObjectSet    (name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet    (name, OBJPROP_COLOR, Blue);
      ObjectSet    (name, OBJPROP_BACK,  true);
      ObjectSet    (name, OBJPROP_TIME1, Time[limit-requiredBars]);
      ObjectSetText(name, "T3("+ T3.Periods +") first reliable bar");

      debug("onTick(0.1)  Bars="+ Bars +"  T3.Periods="+ T3.Periods +"  alpha="+ StrPadRight(NumberToStr(alpha, ".1+"), 10) +"  requiredBars="+ requiredBars);
   }

   double price, sum, stdDev, minChange, maFilterPeriods=T3.Periods;

   // initialize an empty previous bar
   if (!ema1[limit]) {
      price = GetPrice(appliedPrice, limit);
      ema1      [limit] = price;
      ema2      [limit] = price;
      ema3      [limit] = price;
      ema4      [limit] = price;
      ema5      [limit] = price;
      ema6      [limit] = price;
      maRaw     [limit] = price;
      maFiltered[limit] = price;
   }

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      price = GetPrice(appliedPrice, bar);
      ema1[bar] = ema1[bar+1] + alpha * (price     - ema1[bar+1]);
      ema2[bar] = ema2[bar+1] + alpha * (ema1[bar] - ema2[bar+1]);
      ema3[bar] = ema3[bar+1] + alpha * (ema2[bar] - ema3[bar+1]);
      ema4[bar] = ema4[bar+1] + alpha * (ema3[bar] - ema4[bar+1]);
      ema5[bar] = ema5[bar+1] + alpha * (ema4[bar] - ema5[bar+1]);
      ema6[bar] = ema6[bar+1] + alpha * (ema5[bar] - ema6[bar+1]);

      maRaw     [bar] = c1 * ema6[bar] + c2 * ema5[bar] + c3 * ema4[bar] + c4 * ema3[bar];
      maFiltered[bar] = maRaw[bar];

      if (MA.ReversalFilter > 0) {
         maChange[bar] = maFiltered[bar] - maFiltered[bar+1];        // calculate the change of current raw to previous filtered MA
         sum = 0;
         for (int i=0; i < maFilterPeriods; i++) {                   // calculate average(change) over last 'maFilterPeriods'
            sum += maChange[bar+i];
         }
         maAverage[bar] = sum/maFilterPeriods;

         if (maChange[bar] * trend[bar+1] < 0) {                     // on opposite signs = trend reversal
            sum = 0;                                                 // calculate stdDeviation(maChange[]) over last 'maFilterPeriods'
            for (i=0; i < maFilterPeriods; i++) {
               sum += MathPow(maChange[bar+i] - maAverage[bar+i], 2);
            }
            stdDev = MathSqrt(sum/maFilterPeriods);
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
      // step up/down input parameter "T3.Periods"
      double step = T3.Periods.Step;

      if (!step || T3.Periods + direction*step < 1) {          // no stepping if parameter limit reached
         PlaySoundEx("Plonk.wav");
         return(false);
      }
      if (direction == STEP_UP) T3.Periods += step;
      else                      T3.Periods -= step;

      if (!InitializeT3()) return(false);
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
   string sAppliedPrice = ifString(appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(appliedPrice));
   indicatorName        = "T3MA("+ ifString(T3.Periods.Step || MA.ReversalFilter.Step, "step:", "") + T3.Periods + sMaFilter + sAppliedPrice +")";
   shortName            = "T3MA("+ T3.Periods +")";
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
   if (__isChart && (T3.Periods.Step || MA.ReversalFilter.Step)) {
      string prefix = "rsf."+ WindowExpertName() +".";

      Chart.StoreInt   (prefix +"T3.Periods",        T3.Periods);
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
      if (Chart.RestoreInt(prefix +"T3.Periods", iValue)) {
         if (T3.Periods.Step > 0) {
            if (iValue >= 1) T3.Periods = iValue;              // silent validation
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
   return(StringConcatenate("T3.Periods=",                     T3.Periods,                                     ";"+ NL,
                            "T3.Periods.Step=",                T3.Periods.Step,                                ";"+ NL,
                            "T3.VolumeFactor=",                NumberToStr(T3.VolumeFactor, ".1+"),            ";"+ NL,
                            "T3.VolumeFactor.Step=",           NumberToStr(T3.VolumeFactor.Step, ".1+"),       ";"+ NL,
                            "T3.AppliedPrice=",                DoubleQuoteStr(T3.AppliedPrice),                ";"+ NL,

                            "MA.ReversalFilter=",              NumberToStr(MA.ReversalFilter, ".1+"),          ";"+ NL,
                            "MA.ReversalFilter.Step=",         NumberToStr(MA.ReversalFilter.Step, ".1+"),     ";"+ NL,

                            "Draw.Type=",                      DoubleQuoteStr(Draw.Type),                      ";"+ NL,
                            "Draw.Width=",                     Draw.Width,                                     ";"+ NL,
                            "Color.DownTrend=",                ColorToStr(Color.DownTrend),                    ";"+ NL,
                            "Color.UpTrend=",                  ColorToStr(Color.UpTrend),                      ";"+ NL,
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


/*
T3 calculation
--------------
int periods = 8;                                   // T3 length
double v    = 0.7;                                 // volume factor between 0 and 1 (default: 0.7)

double ema1 = ema(PRICE_CLOSE, periods)
double ema2 = ema(ema1, periods)
double ema3 = ema(ema2, periods)
double ema4 = ema(ema3, periods)
double ema5 = ema(ema4, periods)
double ema6 = ema(ema5, periods)
double c1   = -1v³
double c2   =  3v³ +3v²
double c3   = -3v³ -6v² -3v
double c4   =  1v³ +3v² +3v +1
double T3   = c1*ema6 + c2*ema5 + c3*ema4 + c4*ema3


EMA calculation
---------------
EMA = weight * price + (1-weight) * EMA(prev)      // "weigth" = "alpha"
or
EMA = EMA(prev) + weight * (price-EMA(prev))
                                                   // @see  https://en.wikipedia.org/wiki/Moving_average#Approximating_the_EMA_with_a_limited_number_of_terms
required values: k = log(0.001)/log(1-alpha)       // 99.9% of weights are covered by known data, 0.1% = 0.001 are covered by unknown data:

EMA:    alpha = 2/(N + 1)                          // @see  https://en.wikipedia.org/wiki/Moving_average#Relationship_between_SMA_and_EMA
equals: N     = 2/alpha - 1

EMA(10) - an EMA having weights with the same "center of mass" as an SMA(10): alpha = 0.181818
- requires 19.5 values to be reliable to 98%
- requires 22.9 values to be reliable to 99%
- requires 34.4 values to be reliable to 99.9%

Fast-EMA: substitutes N = (N-1)/2 + 1              // Matulich: The Length parameter is divided by two to make the T3's lag equivalent to the lag of traditional
          alpha = 4/(N + 3)                        // moving averages. This way the T3 can be used with the same Length parameter as an SMA or EMA.
equals:   N     = 4/alpha - 3                      // @see  http://unicorn.us.com/trading/el.html#_T3Average

it holds: SMMA(n) = EMA(2*n-1)                     // All three EMAs are identical (length looks different, alpha is the same).
          EMA(n)  = Fast-EMA(2*n-1)                // e.g. SMMA(10) = EMA(19) = Fast-EMA(37)
*/

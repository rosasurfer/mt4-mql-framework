/**
 * Broketrader system
 *
 * Marks long and short position periods of the Broketrader EURUSD-H1 swing trading system.
 *
 * Indicator buffers for iCustom():
 *  • Broketrader.MODE_TREND: trend direction and length
 *    - trend direction: positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:    the absolute direction value is the length of the trend in bars since the last reversal
 *
 * @link  https://www.forexfactory.com/showthread.php?t=970975
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    SMA.Periods            = 96;
extern int    Stochastic.Periods     = 96;
extern int    Stochastic.MA1.Periods = 10;
extern int    Stochastic.MA2.Periods = 6;
extern int    RSI.Periods            = 96;

extern color  Color.Long             = GreenYellow;
extern color  Color.Short            = C'81,211,255';       // lightblue-ish
extern bool   FillSections           = true;
extern int    SMA.DrawWidth          = 2;
extern string StartDate              = "yyyy.mm.dd";        // start date of calculated values
extern int    Max.Bars               = 10000;               // max. values to calculate (-1: all available)
extern string ___a__________________________;

extern string Signal.onReversal      = "on | off | auto*";
extern string Signal.Sound           = "on | off | auto*";
extern string Signal.Mail            = "on | off | auto*";
extern string Signal.SMS             = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>
#include <functions/ConfigureSignalsByMail.mqh>
#include <functions/ConfigureSignalsBySMS.mqh>
#include <functions/ConfigureSignalsBySound.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/IsBarOpen.mqh>
#include <functions/ParseTime.mqh>
#include <functions/Trend.mqh>

#define MODE_HIST_L_PRICE1    0                             // indicator buffer ids
#define MODE_HIST_L_PRICE2    1
#define MODE_HIST_S_PRICE1    2
#define MODE_HIST_S_PRICE2    3
#define MODE_MA_L             4                             // the SMA overlays the histogram
#define MODE_MA_S             5
#define MODE_MA               Broketrader.MODE_MA           // 6
#define MODE_TREND            Broketrader.MODE_TREND        // 7

#property indicator_chart_window
#property indicator_buffers   8                             // buffers visible to the user

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE
#property indicator_color6    CLR_NONE
#property indicator_color7    CLR_NONE
#property indicator_color8    CLR_NONE

double   ma             [];                                 // MA main values:         invisible, displayed in legend and "Data" window
double   maLong         [];                                 // MA long:                visible
double   maShort        [];                                 // MA short:               visible
double   histLongPrice1 [];                                 // long histogram price1:  visible
double   histLongPrice2 [];                                 // long histogram price2:  visible
double   histShortPrice1[];                                 // short histogram price1: visible
double   histShortPrice2[];                                 // short histogram price2: visible
double   trend          [];                                 // trend direction:        invisible (-n..+n), displayed in "Data" window

int      smaPeriods;
int      stochPeriods;
int      stochMa1Periods;
int      stochMa2Periods;
int      rsiPeriods;

datetime startTime;
int      maxValues;

bool     prevReversal;                                      // trend reversal state of the previous bar
bool     currentReversal;                                   // trend reversal state of the current bar
bool     reversalInitialized;                               // whether the reversal states are initialized

string   indicatorName = "";
string   legendLabel   = "";
string   legendInfo    = "";                                // additional chart legend info

bool     signals;
bool     signal.sound;
string   signal.sound.trendChange_up   = "Signal Up.wav";
string   signal.sound.trendChange_down = "Signal Down.wav";
bool     signal.mail;
string   signal.mail.sender   = "";
string   signal.mail.receiver = "";
bool     signal.sms;
string   signal.sms.receiver = "";

#define D_LONG   TRADE_DIRECTION_LONG                       // 1
#define D_SHORT TRADE_DIRECTION_SHORT                       // 2


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (SMA.Periods < 1)            return(catch("onInit(1)  invalid input parameter SMA.Periods: "+ SMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.Periods < 2)     return(catch("onInit(2)  invalid input parameter Stochastic.Periods: "+ Stochastic.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA1.Periods < 1) return(catch("onInit(3)  invalid input parameter Stochastic.MA1.Periods: "+ Stochastic.MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA2.Periods < 1) return(catch("onInit(4)  invalid input parameter Stochastic.MA2.Periods: "+ Stochastic.MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (RSI.Periods < 2)            return(catch("onInit(5)  invalid input parameter RSI.Periods: "+ RSI.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   smaPeriods      = SMA.Periods;
   stochPeriods    = Stochastic.Periods;
   stochMa1Periods = Stochastic.MA1.Periods;
   stochMa2Periods = Stochastic.MA2.Periods;
   rsiPeriods      = RSI.Periods;
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.Long  == 0xFF000000) Color.Long  = CLR_NONE;
   if (Color.Short == 0xFF000000) Color.Short = CLR_NONE;
   // SMA.DrawWidth
   if (SMA.DrawWidth < 0)          return(catch("onInit(6)  invalid input parameter SMA.DrawWidth: "+ SMA.DrawWidth, ERR_INVALID_INPUT_PARAMETER));
   // StartDate
   string sValue = StrTrim(StartDate);
   if (sValue!="" && sValue!="yyyy.mm.dd") {
      int pt[];
      bool success = ParseTime(sValue, DATE_YYYYMMDD|DATE_DDMMYYYY|TIME_OPTIONAL, pt);
      if (!success)                return(catch("onInit(7)  invalid input parameter StartDate: "+ DoubleQuoteStr(StartDate), ERR_INVALID_INPUT_PARAMETER));
      startTime = DateTime2(pt);
   }
   // Max.Bars
   if (Max.Bars < -1)              return(catch("onInit(8)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // signaling
   if (!ConfigureSignals("Broketrader", Signal.onReversal, signals))                                    return(last_error);
   if (signals) {
      if (!ConfigureSignalsBySound(Signal.Sound,         signal.sound                                )) return(last_error);
      if (!ConfigureSignalsByMail (Signal.Mail, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalsBySMS  (Signal.SMS,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         legendInfo = "Reversal="+ StrLeft(ifString(signal.sound, "Sound+", "") + ifString(signal.mail, "Mail+", "") + ifString(signal.sms, "SMS+", ""), -1);
      }
      else signals = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA,            ma             );  // MA main values:         invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_MA_L,          maLong         );  // MA long:                visible, displayed in legend
   SetIndexBuffer(MODE_MA_S,          maShort        );  // MA short:               visible, displayed in legend
   SetIndexBuffer(MODE_HIST_L_PRICE1, histLongPrice1 );  // long histogram price1:  visible
   SetIndexBuffer(MODE_HIST_L_PRICE2, histLongPrice2 );  // long histogram price2:  visible
   SetIndexBuffer(MODE_HIST_S_PRICE1, histShortPrice1);  // short histogram price1: visible
   SetIndexBuffer(MODE_HIST_S_PRICE2, histShortPrice2);  // short histogram price2: visible
   SetIndexBuffer(MODE_TREND,         trend          );  // trend direction:        invisible (-n..+n), displayed in "Data" window
   SetIndexEmptyValue(MODE_TREND, 0);

   // chart legend
   if (!__isSuperContext) {
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // names, labels and display options
   indicatorName = "Broketrader SMA("+ smaPeriods +")";
   IndicatorShortName(indicatorName);                           // chart tooltips and context menu
   SetIndexLabel(MODE_MA,            indicatorName);            // chart tooltips and "Data" window
   SetIndexLabel(MODE_MA_L,          NULL);
   SetIndexLabel(MODE_MA_S,          NULL);
   SetIndexLabel(MODE_HIST_L_PRICE1, NULL);
   SetIndexLabel(MODE_HIST_L_PRICE2, NULL);
   SetIndexLabel(MODE_HIST_S_PRICE1, NULL);
   SetIndexLabel(MODE_HIST_S_PRICE2, NULL);
   SetIndexLabel(MODE_TREND,         "Broketrader trend");
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   return(catch("onInit(9)"));
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
   if (!ArraySize(maLong)) return(logInfo("onTick(1)  sizeof(maLong) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(ma,              EMPTY_VALUE);
      ArrayInitialize(maLong,          EMPTY_VALUE);
      ArrayInitialize(maShort,         EMPTY_VALUE);
      ArrayInitialize(histLongPrice1,  EMPTY_VALUE);
      ArrayInitialize(histLongPrice2,  EMPTY_VALUE);
      ArrayInitialize(histShortPrice1, EMPTY_VALUE);
      ArrayInitialize(histShortPrice2, EMPTY_VALUE);
      ArrayInitialize(trend,                     0);
      SetIndicatorOptions();
      reversalInitialized = false;
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(ma,              Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(maLong,          Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(maShort,         Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(histLongPrice1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(histLongPrice2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(histShortPrice1, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(histShortPrice2, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(trend,           Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int maxSMAValues   = Bars - smaPeriods + 1;                                                     // max. possible SMA values
   int maxStochValues = Bars - rsiPeriods - stochPeriods - stochMa1Periods - stochMa2Periods - 1;  // max. possible Stochastic values (see Stochastic of RSI)
   int requestedBars  = Min(ChangedBars, maxValues);
   int bars           = Min(requestedBars, Min(maxSMAValues, maxStochValues));                     // actual number of bars to be updated
   int startbar       = bars - 1;
   if (startbar < 0) return(logInfo("onTick(2)  Tick="+ Ticks, ERR_HISTORY_INSUFFICIENT));
   if (Time[startbar]+Period()*MINUTES-1 < startTime)
      startbar = iBarShiftNext(NULL, NULL, startTime);

   double sma, stoch, price1, price2;

   // re/initialize the reversal state of the previous bar => Bar[startbar+1]
   if (!reversalInitialized || ChangedBars > 2) {
      int prevBar = startbar + 1;
      sma   = iMA(NULL, NULL, smaPeriods, 0, MODE_SMA, PRICE_CLOSE, prevBar);
      stoch = GetStochasticOfRSI(prevBar); if (last_error != 0) return(last_error);

      prevReversal = false;
      if      (trend[prevBar] < 0) prevReversal = (Close[prevBar] > sma && stoch > 40);
      else if (trend[prevBar] > 0) prevReversal = (Close[prevBar] < sma && stoch < 60);
      reversalInitialized = true;
   }

   // recalculate changed bars
   for (int bar=startbar; bar >= 0; bar--) {
      sma   = iMA(NULL, NULL, smaPeriods, 0, MODE_SMA, PRICE_CLOSE, bar);
      stoch = GetStochasticOfRSI(bar); if (last_error != 0) return(last_error);

      trend[bar]      = 0;
      currentReversal = false;

      // check previous bar and set trend
      if (!trend[bar+1]) {
         // check start condition for first trend
         if      (Close[bar] > sma && stoch > 40) trend[bar] =  2;                                 // long condition satisfied but trend reversal time is unknown
         else if (Close[bar] < sma && stoch < 60) trend[bar] = -2;                                 // short condition satisfied but trend reversal time is unknown
      }
      else {
         // update existing trend
         int prevTrend = trend[bar+1];
         if (!prevReversal) trend[bar] = prevTrend + Sign(prevTrend);                              // extend existing trend
         else               trend[bar] = -Sign(prevTrend);                                         // toggle trend

         // update reversal state of the current bar
         if      (trend[bar] < 0) currentReversal = (Close[bar] > sma && stoch > 40);              // mark long reversal
         else if (trend[bar] > 0) currentReversal = (Close[bar] < sma && stoch < 60);              // mark short reversal
      }

      // MA
      ma[bar] = sma;

      if (prevReversal) {
         maLong [bar] = sma;
         maShort[bar] = sma;
      }
      else if (trend[bar] > 0) {
         maLong [bar] = sma;
         maShort[bar] = EMPTY_VALUE;
      }
      else if (trend[bar] < 0) {
         maLong [bar] = EMPTY_VALUE;
         maShort[bar] = sma;
      }
      else {
         maLong [bar] = EMPTY_VALUE;
         maShort[bar] = EMPTY_VALUE;
      }

      // histogram
      if (Low[bar] > sma) {
         price1 = MathMax(Open[bar], Close[bar]);
         price2 = sma;
      }
      else if (High[bar] < sma) {
         price1 = MathMin(Open[bar], Close[bar]);
         price2 = sma;
      }
      else                   {
         price1 = MathMax(sma, MathMax(Open[bar], Close[bar]));
         price2 = MathMin(sma, MathMin(Open[bar], Close[bar]));
      }

      if (trend[bar] > 0) {
         histLongPrice1 [bar] = price1;
         histLongPrice2 [bar] = price2;
         histShortPrice1[bar] = EMPTY_VALUE;
         histShortPrice2[bar] = EMPTY_VALUE;
      }
      else if (trend[bar] < 0) {
         histLongPrice1 [bar] = EMPTY_VALUE;
         histLongPrice2 [bar] = EMPTY_VALUE;
         histShortPrice1[bar] = price1;
         histShortPrice2[bar] = price2;
      }
      else {
         histLongPrice1 [bar] = EMPTY_VALUE;
         histLongPrice2 [bar] = EMPTY_VALUE;
         histShortPrice1[bar] = EMPTY_VALUE;
         histShortPrice2[bar] = EMPTY_VALUE;
      }

      if (bar > 0) prevReversal = currentReversal;
   }

   if (!__isSuperContext) {
      color legendColor = ifInt(trend[0] > 0, Green, DodgerBlue);
      Trend.UpdateLegend(legendLabel, indicatorName, legendInfo, legendColor, legendColor, sma, Digits, trend[0], Time[0]);

      // monitor trend reversals
      if (signals) /*&&*/ if (IsBarOpen()) {
         int iTrend = trend[0];
         if      (iTrend ==  1) onReversal(D_LONG);
         else if (iTrend == -1) onReversal(D_SHORT);
      }
   }

   return(catch("onTick(3)"));
}


/**
 * Event handler for position direction reversals.
 *
 * @param  int direction
 *
 * @return bool - success status
 */
bool onReversal(int direction) {
   string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ GetAccountAlias() +")";
   int error = 0;

   if (direction == D_LONG) {
      message = "Broketrader LONG signal (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onReversal(1)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.sound) error |= PlaySoundEx(signal.sound.trendChange_up);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message + NL + accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message + NL + accountTime);
      return(!error);
   }

   if (direction == D_SHORT) {
      message = "Broketrader SHORT signal (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (IsLogInfo()) logInfo("onReversal(2)  "+ message);
      message = Symbol() +","+ PeriodDescription() +": "+ message;

      if (signal.sound) error |= PlaySoundEx(signal.sound.trendChange_down);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message + NL + accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message + NL + accountTime);
      return(!error);
   }

   return(!catch("onReversal(3)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   SetIndexStyle(MODE_MA,    DRAW_NONE);
   SetIndexStyle(MODE_TREND, DRAW_NONE);

   int   maType        = ifInt(SMA.DrawWidth, DRAW_LINE, DRAW_NONE);
   color darkenedLong  = ModifyColor(Color.Long,  NULL, NULL, -30);
   color darkenedShort = ModifyColor(Color.Short, NULL, NULL, -30);

   if (FillSections) {
      SetIndexStyle(MODE_MA_L, maType,  EMPTY, SMA.DrawWidth, darkenedLong );
      SetIndexStyle(MODE_MA_S, maType,  EMPTY, SMA.DrawWidth, darkenedShort);

      SetIndexStyle(MODE_HIST_L_PRICE1, DRAW_HISTOGRAM, EMPTY, 5, Color.Long );
      SetIndexStyle(MODE_HIST_L_PRICE2, DRAW_HISTOGRAM, EMPTY, 5, Color.Long );
      SetIndexStyle(MODE_HIST_S_PRICE1, DRAW_HISTOGRAM, EMPTY, 5, Color.Short);
      SetIndexStyle(MODE_HIST_S_PRICE2, DRAW_HISTOGRAM, EMPTY, 5, Color.Short);
   }
   else {
      SetIndexStyle(MODE_MA_L, maType,  EMPTY, SMA.DrawWidth, darkenedLong );
      SetIndexStyle(MODE_MA_S, maType,  EMPTY, SMA.DrawWidth, darkenedShort);

      SetIndexStyle(MODE_HIST_L_PRICE1, DRAW_NONE);
      SetIndexStyle(MODE_HIST_L_PRICE2, DRAW_NONE);
      SetIndexStyle(MODE_HIST_S_PRICE1, DRAW_NONE);
      SetIndexStyle(MODE_HIST_S_PRICE2, DRAW_NONE);
   }
}


/**
 * Return a Stochastic(RSI) indicator value.
 *
 * @param  int iBar - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetStochasticOfRSI(int iBar) {
   return(icStochasticOfRSI(NULL, stochPeriods, stochMa1Periods, stochMa2Periods, rsiPeriods, Stochastic.MODE_SIGNAL, iBar));
}


/**
 * Load the "Stochastic of RSI" indicator and return a value.
 *
 * @param  int timeframe              - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int stochMainPeriods       - indicator parameter
 * @param  int stochSlowedMainPeriods - indicator parameter
 * @param  int stochSignalPeriods     - indicator parameter
 * @param  int rsiPeriods             - indicator parameter
 * @param  int iBuffer                - indicator buffer index of the value to return
 * @param  int iBar                   - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double icStochasticOfRSI(int timeframe, int stochMainPeriods, int stochSlowedMainPeriods, int stochSignalPeriods, int rsiPeriods, int iBuffer, int iBar) {
   static int lpSuperContext = 0; if (!lpSuperContext)
      lpSuperContext = GetIntsAddress(__ExecutionContext);

   double value = iCustom(NULL, timeframe, ".attic/Stochastic of RSI",
                          stochMainPeriods,                                // int    Stoch.Main.Periods
                          stochSlowedMainPeriods,                          // int    Stoch.SlowedMain.Periods
                          stochSignalPeriods,                              // int    Stoch.Signal.Periods
                          rsiPeriods,                                      // int    RSI.Periods
                          Blue,                                            // color  Main.Color
                          Red,                                             // color  Signal.Color
                          "Line",                                          // string Signal.DrawType
                          1,                                               // int    Signal.DrawWidth
                          -1,                                              // int    Max.Bars
                          "",                                              // string ______________________
                          false,                                           // bool   AutoConfiguration
                          lpSuperContext,                                  // int    __lpSuperContext

                          iBuffer, iBar);

   int error = GetLastError();
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icStochasticOfRSI(1)", error));
      logWarn("icStochasticOfRSI(2)  "+ PeriodDescription(ifInt(!timeframe, Period(), timeframe)) +" (tick="+ Ticks +")", ERS_HISTORY_UPDATE);
   }

   error = __ExecutionContext[EC.mqlError];                                // TODO: synchronize execution contexts
   if (!error)
      return(value);
   return(!SetLastError(error));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SMA.Periods=",            SMA.Periods,                       ";", NL,
                            "Stochastic.Periods=",     Stochastic.Periods,                ";", NL,
                            "Stochastic.MA1.Periods=", Stochastic.MA1.Periods,            ";", NL,
                            "Stochastic.MA2.Periods=", Stochastic.MA2.Periods,            ";", NL,
                            "RSI.Periods=",            RSI.Periods,                       ";", NL,
                            "Color.Long=",             ColorToStr(Color.Long),            ";", NL,
                            "Color.Short=",            ColorToStr(Color.Short),           ";", NL,
                            "FillSections=",           BoolToStr(FillSections),           ";", NL,
                            "SMA.DrawWidth=",          SMA.DrawWidth,                     ";", NL,
                            "StartDate=",              DoubleQuoteStr(StartDate),         ";", NL,
                            "Max.Bars=",               Max.Bars,                          ";", NL,
                            "Signal.onReversal=",      DoubleQuoteStr(Signal.onReversal), ";", NL,
                            "Signal.Sound=",           DoubleQuoteStr(Signal.Sound),      ";", NL,
                            "Signal.Mail=",            DoubleQuoteStr(Signal.Mail),       ";", NL,
                            "Signal.SMS=",             DoubleQuoteStr(Signal.SMS),        ";")
   );
}

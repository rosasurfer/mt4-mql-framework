/**
 * Broketrader Signal
 *
 * Marks long and short position periods of the Broketrader EURUSD-H1 swing trading system.
 *
 *
 * Indicator buffers for iCustom():
 *  • Broketrader.MODE_POSITION: positioning direction and duration
 *    - positioning direction: positive values denote a long position (+1...+n), negative values a short position (-1...-n)
 *    - positioning duration:  the absolute direction value is the age in bars since position open
 *
 * @see  https://www.forexfactory.com/showthread.php?t=970975
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    SMA.Periods            = 96;
extern int    Stochastic.Periods     = 96;
extern int    Stochastic.MA1.Periods = 10;
extern int    Stochastic.MA2.Periods = 6;
extern int    RSI.Periods            = 96;

extern color  Color.Long             = GreenYellow;
extern color  Color.Short            = C'81,211,255';    // lightblue-ish
extern bool   FillSections           = true;
extern int    SMA.DrawWidth          = 2;
extern int    Max.Values             = 10000;            //  max. amount of values to calculate (-1: all)
extern string __________________________;

extern string Signal.onReversal      = "on | off | auto*";
extern string Signal.Sound           = "on | off | auto*";
extern string Signal.Mail.Receiver   = "on | off | auto* | {email-address}";
extern string Signal.SMS.Receiver    = "on | off | auto* | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>

#define MODE_HIST_L_PRICE1    0                          // indicator buffer ids
#define MODE_HIST_L_PRICE2    1
#define MODE_HIST_S_PRICE1    2
#define MODE_HIST_S_PRICE2    3
#define MODE_MA_L             4                          // the SMA overlays the histogram
#define MODE_MA_S             5
#define MODE_POSITION         Broketrader.MODE_POSITION
#define MODE_EXIT             7

#property indicator_chart_window
#property indicator_buffers   6                          // buffers visible in input dialog
int       allocated_buffers = 8;

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE
#property indicator_color6    CLR_NONE

double maLong         [];                                // MA long:                visible, displayed in legend
double maShort        [];                                // MA short:               visible, displayed in legend
double histLongPrice1 [];                                // long histogram price1:  visible
double histLongPrice2 [];                                // long histogram price2:  visible
double histShortPrice1[];                                // short histogram price1: visible
double histShortPrice2[];                                // short histogram price2: visible
double position       [];                                // position duration:      invisible (-n..0..+n)
double exit           [];                                // exit bar marker:        invisible (0..1)

int    smaPeriods;
int    stochPeriods;
int    stochMa1Periods;
int    stochMa2Periods;
int    rsiPeriods;
int    maxValues;

string indicatorName;
string chartLegendLabel;

bool   signals;
bool   signal.sound;
string signal.sound.trendChange_up   = "Signal-Up.wav";
string signal.sound.trendChange_down = "Signal-Down.wav";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";
bool   signal.sms;
string signal.sms.receiver = "";
string signal.info = "";                                 // additional chart legend info

#define D_LONG   TRADE_DIRECTION_LONG                    // 1
#define D_SHORT TRADE_DIRECTION_SHORT                    // 2


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   if (SMA.Periods < 1)            return(catch("onInit(1)  Invalid input parameter SMA.Periods: "+ SMA.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.Periods < 2)     return(catch("onInit(2)  Invalid input parameter Stochastic.Periods: "+ Stochastic.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA1.Periods < 1) return(catch("onInit(3)  Invalid input parameter Stochastic.MA1.Periods: "+ Stochastic.MA1.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (Stochastic.MA2.Periods < 1) return(catch("onInit(4)  Invalid input parameter Stochastic.MA2.Periods: "+ Stochastic.MA2.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (RSI.Periods < 2)            return(catch("onInit(5)  Invalid input parameter RSI.Periods: "+ RSI.Periods +" (min. 2)", ERR_INVALID_INPUT_PARAMETER));
   smaPeriods      = SMA.Periods;
   stochPeriods    = Stochastic.Periods;
   stochMa1Periods = Stochastic.MA1.Periods;
   stochMa2Periods = Stochastic.MA2.Periods;
   rsiPeriods      = RSI.Periods;

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.Long  == 0xFF000000) Color.Long  = CLR_NONE;
   if (Color.Short == 0xFF000000) Color.Short = CLR_NONE;

   // SMA.DrawWidth
   if (SMA.DrawWidth < 0)          return(catch("onInit(6)  Invalid input parameter SMA.DrawWidth = "+ SMA.DrawWidth, ERR_INVALID_INPUT_PARAMETER));
   if (SMA.DrawWidth > 5)          return(catch("onInit(7)  Invalid input parameter SMA.DrawWidth = "+ SMA.DrawWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)            return(catch("onInit(8)  Invalid input parameter Max.Values: "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // signals
   if (!Configure.Signal("Broketrader", Signal.onReversal, signals))                                            return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         signal.info = "Reversal="+ StrLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail, "Mail,", "") + ifString(signal.sms, "SMS,", ""), -1);
      }
      else signals = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA_L,          maLong         );  // MA long:                visible, displayed in legend
   SetIndexBuffer(MODE_MA_S,          maShort        );  // MA short:               visible, displayed in legend
   SetIndexBuffer(MODE_HIST_L_PRICE1, histLongPrice1 );  // long histogram price1:  visible
   SetIndexBuffer(MODE_HIST_L_PRICE2, histLongPrice2 );  // long histogram price2:  visible
   SetIndexBuffer(MODE_HIST_S_PRICE1, histShortPrice1);  // short histogram price1: visible
   SetIndexBuffer(MODE_HIST_S_PRICE2, histShortPrice2);  // short histogram price2: visible
   SetIndexBuffer(MODE_POSITION,      position      );   // position duration:      invisible (-n..0..+n)
   SetIndexBuffer(MODE_EXIT,          exit          );   // exit bar marker:        invisible (0..1)

   SetIndexEmptyValue(MODE_POSITION, 0);
   SetIndexEmptyValue(MODE_EXIT,     0);

   // chart legend
   indicatorName = "SMA("+ smaPeriods +")";
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel(indicatorName);
       ObjectRegister(chartLegendLabel);
   }

   // names, labels and display options
   IndicatorShortName(indicatorName);
   SetIndexLabel(MODE_MA_L,          indicatorName);
   SetIndexLabel(MODE_MA_S,          indicatorName);
   SetIndexLabel(MODE_HIST_L_PRICE1, NULL);
   SetIndexLabel(MODE_HIST_L_PRICE2, NULL);
   SetIndexLabel(MODE_HIST_S_PRICE1, NULL);
   SetIndexLabel(MODE_HIST_S_PRICE2, NULL);
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
   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(maLong)) return(log("onTick(1)  size(maLong) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(maLong,          EMPTY_VALUE);
      ArrayInitialize(maShort,         EMPTY_VALUE);
      ArrayInitialize(histLongPrice1,  EMPTY_VALUE);
      ArrayInitialize(histLongPrice2,  EMPTY_VALUE);
      ArrayInitialize(histShortPrice1, EMPTY_VALUE);
      ArrayInitialize(histShortPrice2, EMPTY_VALUE);
      ArrayInitialize(position,                  0);
      ArrayInitialize(exit,                      0);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(maLong,          Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(maShort,         Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histLongPrice1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histLongPrice2,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histShortPrice1, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(histShortPrice2, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(position,        Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(exit,            Bars, ShiftedBars,           0);
   }

   // calculate start bar
   int maxSMAValues   = Bars - smaPeriods + 1;                                                     // max. possible SMA values
   int maxStochValues = Bars - rsiPeriods - stochPeriods - stochMa1Periods - stochMa2Periods - 1;  // max. possible Stochastic values
   int requestedBars  = Min(ChangedBars, maxValues);
   int bars           = Min(requestedBars, Min(maxSMAValues, maxStochValues));                     // actual number of bars to be updated
   int startBar       = bars - 1;
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));

   // recalculate changed bars
   for (int i=startBar; i >= 0; i--) {
      double ma    = iMA(NULL, NULL, smaPeriods, 0, MODE_SMA, PRICE_CLOSE, i), price1, price2;
      double stoch = GetStochasticOfRSI(i); if (last_error || 0) return(last_error);

      // update positioning and exit
      if (Close[i] > ma && stoch > 40) {                                               // long condition
         if      (exit[i+1] > 0)     position[i] = 1;                                  // reverse direction
         else if (position[i+1] < 0) position[i] = position[i+1] - 1;                  // continue short
         else                        position[i] = position[i+1] + 1;                  // continue/start long (position[i+1] may be 0)
         if (position[i] < 0)        exit    [i] = 1;                                  // mark short exit
      }
      else if (Close[i] < ma && stoch < 60) {                                          // short condition
         if      (exit[i+1] > 0)     position[i] = -1;                                 // reverse direction
         else if (position[i+1] > 0) position[i] = position[i+1] + 1;                  // continue long
         else                        position[i] = position[i+1] - 1;                  // continue/start short (position[i+1] may be 0)
         if (position[i] > 0)        exit    [i] = 1;                                  // mark long exit
      }
      else {
         if (exit[i+1] > 0) position[i] = -Sign(position[i+1]);                        // reverse direction
         else               position[i] = position[i+1] + Sign(position[i+1]);         // continue existing/no position
         exit[i] = 0;                                                                  // reset exit marker
      }

      // MA
      if (exit[i+1] > 0) {
         maLong [i] = ma;
         maShort[i] = ma;
      }
      else if (position[i] > 0) {
         maLong [i] = ma;
         maShort[i] = EMPTY_VALUE;
      }
      else if (position[i] < 0) {
         maLong [i] = EMPTY_VALUE;
         maShort[i] = ma;
      }
      else {
         maLong [i] = EMPTY_VALUE;
         maShort[i] = EMPTY_VALUE;
      }

      // histogram
      if (Low[i] > ma) {
         price1 = MathMax(Open[i], Close[i]);
         price2 = ma;
      }
      else if (High[i] < ma) {
         price1 = MathMin(Open[i], Close[i]);
         price2 = ma;
      }
      else                   {
         price1 = MathMax(ma, MathMax(Open[i], Close[i]));
         price2 = MathMin(ma, MathMin(Open[i], Close[i]));
      }

      if (position[i] > 0) {
         histLongPrice1 [i] = price1;
         histLongPrice2 [i] = price2;
         histShortPrice1[i] = EMPTY_VALUE;
         histShortPrice2[i] = EMPTY_VALUE;
      }
      else if (position[i] < 0) {
         histLongPrice1 [i] = EMPTY_VALUE;
         histLongPrice2 [i] = EMPTY_VALUE;
         histShortPrice1[i] = price1;
         histShortPrice2[i] = price2;
      }
      else {
         histLongPrice1 [i] = EMPTY_VALUE;
         histLongPrice2 [i] = EMPTY_VALUE;
         histShortPrice1[i] = EMPTY_VALUE;
         histShortPrice2[i] = EMPTY_VALUE;
      }
   }

   if (!IsSuperContext()) {
      color legendColor = ifInt(position[0] > 0, Green, DodgerBlue);
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, signal.info, legendColor, legendColor, ma, Digits, position[0], Time[0]);

      // monitor position reversals
      if (signals) /*&&*/ if (IsBarOpenEvent()) {
         int iPosition = Round(position[0]);
         if      (iPosition ==  1) onReversal(D_LONG);
         else if (iPosition == -1) onReversal(D_SHORT);
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
   string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ AccountAlias(ShortAccountCompany(), GetAccountNumber()) +")";
   int error = 0;

   if (direction == D_LONG) {
      message = "Broketrader signal LONG (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (__LOG()) log("onReversal(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_up);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message + NL + accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message + NL + accountTime);
      return(!error);
   }

   if (direction == D_SHORT) {
      message = "Broketrader signal SHORT (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (__LOG()) log("onReversal(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_down);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message + NL + accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message + NL + accountTime);
      return(!error);
   }

   return(!catch("onReversal(3)  invalid parameter direction: "+ direction, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(allocated_buffers);
   //SetIndexStyle(int buffer, int drawType, int lineStyle=EMPTY, int drawWidth=EMPTY, color drawColor=NULL)

   int maType = ifInt(SMA.DrawWidth, DRAW_LINE, DRAW_NONE);

   if (FillSections) {
      SetIndexStyle(MODE_MA_L, maType,  EMPTY, SMA.DrawWidth, ModifyColor(Color.Long,  NULL, NULL, -30));
      SetIndexStyle(MODE_MA_S, maType,  EMPTY, SMA.DrawWidth, ModifyColor(Color.Short, NULL, NULL, -30));

      SetIndexStyle(MODE_HIST_L_PRICE1, DRAW_HISTOGRAM, EMPTY, 5, Color.Long );
      SetIndexStyle(MODE_HIST_L_PRICE2, DRAW_HISTOGRAM, EMPTY, 5, Color.Long );
      SetIndexStyle(MODE_HIST_S_PRICE1, DRAW_HISTOGRAM, EMPTY, 5, Color.Short);
      SetIndexStyle(MODE_HIST_S_PRICE2, DRAW_HISTOGRAM, EMPTY, 5, Color.Short);
   }
   else {
      SetIndexStyle(MODE_MA_L, maType,  EMPTY, SMA.DrawWidth, Color.Long );
      SetIndexStyle(MODE_MA_S, maType,  EMPTY, SMA.DrawWidth, Color.Short);

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
   return(iStochasticOfRSI(NULL, stochPeriods, stochMa1Periods, stochMa2Periods, rsiPeriods, Stochastic.MODE_SIGNAL, iBar));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("SMA.Periods=",            SMA.Periods,                          ";", NL,
                            "Stochastic.Periods=",     Stochastic.Periods,                   ";", NL,
                            "Stochastic.MA1.Periods=", Stochastic.MA1.Periods,               ";", NL,
                            "Stochastic.MA2.Periods=", Stochastic.MA2.Periods,               ";", NL,
                            "RSI.Periods=",            RSI.Periods,                          ";", NL,
                            "Color.Long=",             ColorToStr(Color.Long),               ";", NL,
                            "Color.Short=",            ColorToStr(Color.Short),              ";", NL,
                            "FillSections=",           BoolToStr(FillSections),              ";", NL,
                            "SMA.DrawWidth=",          SMA.DrawWidth,                        ";", NL,
                            "Max.Values=",             Max.Values,                           ";", NL,
                            "Signal.onReversal=",      DoubleQuoteStr(Signal.onReversal),    ";", NL,
                            "Signal.Sound=",           DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail.Receiver=",   DoubleQuoteStr(Signal.Mail.Receiver), ";", NL,
                            "Signal.SMS.Receiver=",    DoubleQuoteStr(Signal.SMS.Receiver),  ";")
   );
}

/**
 * Bagovino - a simple trend following system
 *
 *
 * - entries on two Moving Averages cross-over and RSI confirmation
 * - partial profit taking
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Fast.MA.Periods     = 0;
extern string Fast.MA.Method      = "SMA | LWMA | EMA* | ALMA";
extern int    Slow.MA.Periods     = 0;
extern string Slow.MA.Method      = "SMA | LWMA | EMA* | ALMA";

extern int    RSI.Periods         = 0;

extern double Lotsize             = 0.1;
extern int    TakeProfit.Level.1  = 0;
extern int    TakeProfit.Level.2  = 0;

extern string _1_____________________________;

extern string Notify.onOpenSignal = "on | off | auto*";           // send notifications as configured

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>
#include <functions/EventListener.BarOpen.mqh>
#include <iCustom/icMACD.mqh>
#include <iCustom/icRSI.mqh>
#include <rsfLibs.mqh>

// indiactor settings
int fast.ma.periods;
int fast.ma.method;
int slow.ma.periods;
int slow.ma.method;

int rsi.periods;

// signaling
bool   signals;
bool   signal.sound;
string signal.sound.open_long  = "Signal-Up.wav";
string signal.sound.open_short = "Signal-Down.wav";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";
bool   signal.sms;
string signal.sms.receiver = "";

int last.signal = OP_UNDEFINED;

// position management
int long.position;
int short.position;

// OrderSend() defaults
double os.slippage    = 0.1;
double os.takeProfit  = NULL;
double os.stopLoss    = NULL;
int    os.magicNumber = NULL;
string os.comment     = "";

// order marker colors
#define CLR_OPEN_LONG         C'0,0,254'              // Blue - C'1,1,1'
#define CLR_OPEN_SHORT        C'254,0,0'              // Red  - C'1,1,1'
#define CLR_OPEN_TAKEPROFIT   Blue
#define CLR_OPEN_STOPLOSS     Red
#define CLR_CLOSE             Orange


/**
 * Initialization.
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // Fast.MA.Periods
   if (Fast.MA.Periods < 1)  return(catch("onInit(1)  Invalid input parameter Fast.MA.Periods: "+ Fast.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   fast.ma.periods = Fast.MA.Periods;

   // Fast.MA.Method
   string sValue, values[];
   if (Explode(Fast.MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StrTrim(Fast.MA.Method);
      if (sValue == "") sValue = "SMA";                           // default MA method
   }
   fast.ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (fast.ma.method == -1) return(catch("onInit(2)  Invalid input parameter Fast.MA.Method: "+ DoubleQuoteStr(Fast.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Fast.MA.Method = MaMethodDescription(fast.ma.method);

   // Slow.MA.Periods
   if (Slow.MA.Periods < 1)  return(catch("onInit(3)  Invalid input parameter Slow.MA.Periods: "+ Slow.MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   slow.ma.periods = Slow.MA.Periods;

   // Slow.MA.Method
   if (Explode(Slow.MA.Method, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StrTrim(Slow.MA.Method);
      if (sValue == "") sValue = "SMA";                           // default MA method
   }
   slow.ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (slow.ma.method == -1) return(catch("onInit(4)  Invalid input parameter Slow.MA.Method: "+ DoubleQuoteStr(Slow.MA.Method), ERR_INVALID_INPUT_PARAMETER));
   Slow.MA.Method = MaMethodDescription(slow.ma.method);

   // RSI.Periods
   if (RSI.Periods < 2)      return(catch("onInit(5)  Invalid input parameter RSI.Periods: "+ RSI.Periods, ERR_INVALID_INPUT_PARAMETER));
   rsi.periods = RSI.Periods;

   // signals
   if (!Configure.Signal("Bagovino", Notify.onOpenSignal, signals))                              return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound("auto", signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail ("auto", signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  ("auto", signal.sms,                      signal.sms.receiver )) return(last_error);
      signals = (signal.sound || signal.mail || signal.sms);
      if (signals) log("onInit(6)  Notify.onOpenSignal="+ Notify.onOpenSignal +"  Sound="+ signal.sound +"  Mail="+ ifString(signal.mail, signal.mail.receiver, "0") +"  SMS="+ ifString(signal.sms, signal.sms.receiver, "0"));
   }
   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (EventListener.BarOpen()) {                                 // check the current period
      // check long conditions
      if (!long.position) Long.CheckOpenPosition();
      else                Long.CheckClosePosition();

      // check short conditions
      if (!short.position) Short.CheckOpenPosition();
      else                 Short.CheckClosePosition();
   }
   return(last_error);
}


/**
 * Check for long entry conditions.
 *
 * @return bool - success status
 */
bool Long.CheckOpenPosition() {
   int macd = GetMACD(MACD.MODE_SECTION, 1);
   int rsi  = GetRSI(RSI.MODE_SECTION, 1);
   //debug("CheckOpenPosition(1)  macd="+ macd +"  rsi="+ rsi);

   if ((macd>0 && rsi==1) || (rsi>0 && macd==1)) {
      if (last.signal != OP_LONG) {
         if (signals) onSignal.OpenPosition(OP_LONG);

         if (IsTradeAllowed()) {
            // close an existing short position
            int oe[], oeFlags = NULL;
            if (short.position != 0) {
               if (!OrderCloseEx(short.position, NULL, NULL, os.slippage, CLR_CLOSE, oeFlags, oe)) return(false);
               short.position = 0;
            }

            // open a new long position
            long.position = OrderSendEx(Symbol(), OP_BUY, Lotsize, NULL, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, NULL, CLR_OPEN_LONG, oeFlags, oe);
            if (!long.position) return(false);
         }
      }
   }
   return(true);
}


/**
 * Check for long exit conditions.
 *
 * @return bool - success status
 */
void Long.CheckClosePosition() {
   return(true);
}


/**
 * Check for short entry conditions.
 *
 * @return bool - success status
 */
bool Short.CheckOpenPosition() {
   int macd = GetMACD(MACD.MODE_SECTION, 1);
   int rsi  = GetRSI(RSI.MODE_SECTION, 1);
   //debug("Short.CheckOpenPosition(1)  macd="+ macd +"  rsi="+ rsi);

   if ((macd<0 && rsi==-1) || (rsi<0 && macd==-1)) {
      if (last.signal != OP_SHORT) {
         if (signals) onSignal.OpenPosition(OP_SHORT);

         if (IsTradeAllowed()) {
            // close an existing long position
            int oe[], oeFlags = NULL;
            if (long.position != 0) {
               if (!OrderCloseEx(long.position, NULL, NULL, os.slippage, CLR_CLOSE, oeFlags, oe)) return(false);
               long.position = 0;
            }

            // open a new short position
            short.position = OrderSendEx(Symbol(), OP_SELL, Lotsize, NULL, os.slippage, os.stopLoss, os.takeProfit, os.comment, os.magicNumber, NULL, CLR_OPEN_SHORT, oeFlags, oe);
            if (!short.position) return(false);
         }
      }
   }
   return(true);
}


/**
 * Check for short exit conditions.
 *
 * @return bool - success status
 */
void Short.CheckClosePosition() {
   return(true);
}


/**
 * Return a MACD indicator value.
 *
 * @param  int mode - buffer index of the value to return
 * @param  int bar  - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetMACD(int buffer, int bar) {
   int maxValues = slow.ma.periods + 100;             // should cover the longest possible trending period (seen: 95)
   return(icMACD(NULL, fast.ma.periods, Fast.MA.Method, PRICE_CLOSE, slow.ma.periods, Slow.MA.Method, PRICE_CLOSE, maxValues, buffer, bar));
}


/**
 * Return an RSI indicator value.
 *
 * @param  int mode - buffer index of the value to return
 * @param  int bar  - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetRSI(int buffer, int bar) {
   int maxValues = 100;                               // must cover the oldest indicator value we will access in this program
   return(icRSI(NULL, rsi.periods, PRICE_CLOSE, maxValues, buffer, bar));
}


/**
 * Event handler called if an position-open signal was triggered.
 *
 * @param  int direction - trade direction: OP_LONG | OP_SHORT
 *
 * @return bool - success status
 */
bool onSignal.OpenPosition(int direction) {
   string name, message;
   if (Fast.MA.Method == Slow.MA.Method) name = __NAME__ +"("+ Fast.MA.Method +"("+ Fast.MA.Periods +","+ Slow.MA.Periods +"), RSI("+ RSI.Periods +"))";
   else                                  name = __NAME__ +"("+ Fast.MA.Method +"("+ Fast.MA.Periods +"), "+ Slow.MA.Method +"("+ Slow.MA.Periods +"), RSI("+ RSI.Periods +"))";
   int success = 0;

   if (direction == OP_LONG) {
      message = name +" signal \"open long position\"";
      log("onSignal.OpenPosition(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.open_long));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      last.signal = direction;
      return(success != 0);
   }

   if (direction == OP_SHORT) {
      message = name +" signal \"open short position\"";
      log("onSignal.OpenPosition(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) success &= _int(PlaySoundEx(signal.sound.open_short));
      if (signal.mail)  success &= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)   success &= !SendSMS(signal.sms.receiver, message);
      last.signal = direction;
      return(success != 0);
   }

   return(!catch("onSignal.OpenPosition(3)  invalid parameter direction: "+ direction +" (unknown)", ERR_INVALID_PARAMETER));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Fast.MA.Periods=",     Fast.MA.Periods,                     ";", NL,
                            "Fast.MA.Method=",      DoubleQuoteStr(Fast.MA.Method),      ";", NL,
                            "Slow.MA.Periods=",     Slow.MA.Periods,                     ";", NL,
                            "Slow.MA.Method=",      DoubleQuoteStr(Slow.MA.Method),      ";", NL,

                            "RSI.Periods=",         RSI.Periods,                         ";", NL,

                            "Lotsize=",             NumberToStr(Lotsize, ".1+"),         ";", NL,
                            "TakeProfit.Level.1=",  TakeProfit.Level.1,                  ";", NL,
                            "TakeProfit.Level.2=",  TakeProfit.Level.2,                  ";", NL,

                            "Notify.onOpenSignal=", DoubleQuoteStr(Notify.onOpenSignal), ";")
   );
}

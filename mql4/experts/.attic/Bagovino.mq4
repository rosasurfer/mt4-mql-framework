/**
 * Bagovino
 *
 * A trend following strategy with entries on combined MACD and RSI signals and multiple profit targets. Stoploss is either
 * fixed, on breakeven or on opposite signal (whichever comes first).
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MACD.Fast.Periods   = 0;
extern string MACD.Fast.Method    = "SMA | LWMA | EMA* | ALMA";
extern int    MACD.Slow.Periods   = 0;
extern string MACD.Slow.Method    = "SMA | LWMA | EMA* | ALMA";

extern int    RSI.Periods         = 0;

extern double Lotsize             = 0.1;

extern int    TakeProfit.1        = 0;                            // Target.1 = OpenPrice + TakeProfit.1*Pips
extern int    TakeProfit.2        = 0;                            // Target.2 = Target.1  + TakeProfit.2*Pips
extern int    TakeProfit.3        = 0;                            // Target.3 = Target.2  + TakeProfit.3*Pips
extern int    StopLoss            = 0;

extern string _1_____________________________;
extern string Notify.onOpenSignal = "on | off | auto*";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>

// indicator settings
int macd.fast.periods;
int macd.fast.method;
int macd.slow.periods;
int macd.slow.method;

int rsi.periods;

// position management
int long.position;
int short.position;

// order defaults
double o.slippage    = 0.1;
double o.takeProfit  = NULL;
double o.stopLoss    = NULL;
int    o.magicNumber = NULL;
string o.comment     = "";

// order marker colors
#define CLR_OPEN_LONG         C'0,0,254'              // Blue - C'1,1,1'
#define CLR_OPEN_SHORT        C'254,0,0'              // Red  - C'1,1,1'
#define CLR_OPEN_TAKEPROFIT   Blue
#define CLR_OPEN_STOPLOSS     Red
#define CLR_CLOSE             Orange

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

int    last.signal = OP_UNDEFINED;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // MACD.Fast.Periods
   if (MACD.Fast.Periods < 1)  return(catch("onInit(1)  Invalid input parameter MACD.Fast.Periods: "+ MACD.Fast.Periods, ERR_INVALID_INPUT_PARAMETER));
   macd.fast.periods = MACD.Fast.Periods;

   // MACD.Fast.Method
   string sValue, values[];
   if (Explode(MACD.Fast.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StrTrim(MACD.Fast.Method);
   }
   macd.fast.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (macd.fast.method == -1) return(catch("onInit(2)  Invalid input parameter MACD.Fast.Method: "+ DoubleQuoteStr(MACD.Fast.Method), ERR_INVALID_INPUT_PARAMETER));
   MACD.Fast.Method = MaMethodDescription(macd.fast.method);

   // MACD.Slow.Periods
   if (MACD.Slow.Periods < 1)  return(catch("onInit(3)  Invalid input parameter MACD.Slow.Periods: "+ MACD.Slow.Periods, ERR_INVALID_INPUT_PARAMETER));
   macd.slow.periods = MACD.Slow.Periods;

   // MACD.Slow.Method
   if (Explode(MACD.Slow.Method, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else {
      sValue = StrTrim(MACD.Slow.Method);
   }
   macd.slow.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (macd.slow.method == -1) return(catch("onInit(4)  Invalid input parameter MACD.Slow.Method: "+ DoubleQuoteStr(MACD.Slow.Method), ERR_INVALID_INPUT_PARAMETER));
   MACD.Slow.Method = MaMethodDescription(macd.slow.method);

   // RSI.Periods
   if (RSI.Periods < 2)      return(catch("onInit(5)  Invalid input parameter RSI.Periods: "+ RSI.Periods, ERR_INVALID_INPUT_PARAMETER));
   rsi.periods = RSI.Periods;

   // signaling
   if (!Configure.Signal("Bagovino", Notify.onOpenSignal, signals))                               return(last_error);
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
   bool result;

   if (IsBarOpenEvent()) {
      if (!long.position)  result = Long.CheckOpenPosition();
      else                 result = Long.CheckClosePosition();  if (!result) return(last_error);

      if (!short.position) result = Short.CheckOpenPosition();
      else                 result = Short.CheckClosePosition(); if (!result) return(last_error);
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

   if ((macd>0 && rsi==1) || (rsi>0 && macd==1)) {
      if (last.signal != OP_LONG) {
         if (signals) onSignal.OpenPosition(OP_LONG);

         if (IsTradeAllowed()) {
            // close an existing short position
            int oe[], oeFlags = NULL;
            if (short.position != 0) {
               if (!OrderCloseEx(short.position, NULL, o.slippage, CLR_CLOSE, oeFlags, oe)) return(false);
               short.position = 0;
            }

            // open a new long position
            long.position = OrderSendEx(Symbol(), OP_BUY, Lotsize, NULL, o.slippage, o.stopLoss, o.takeProfit, o.comment, o.magicNumber, NULL, CLR_OPEN_LONG, oeFlags, oe);
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
bool Long.CheckClosePosition() {
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

   if ((macd<0 && rsi==-1) || (rsi<0 && macd==-1)) {
      if (last.signal != OP_SHORT) {
         if (signals) onSignal.OpenPosition(OP_SHORT);

         if (IsTradeAllowed()) {
            // close an existing long position
            int oe[], oeFlags = NULL;
            if (long.position != 0) {
               if (!OrderCloseEx(long.position, NULL, o.slippage, CLR_CLOSE, oeFlags, oe)) return(false);
               long.position = 0;
            }

            // open a new short position
            short.position = OrderSendEx(Symbol(), OP_SELL, Lotsize, NULL, o.slippage, o.stopLoss, o.takeProfit, o.comment, o.magicNumber, NULL, CLR_OPEN_SHORT, oeFlags, oe);
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
bool Short.CheckClosePosition() {
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
   return(iMACDX(NULL, macd.fast.periods, macd.fast.method, PRICE_CLOSE, macd.slow.periods, macd.slow.method, PRICE_CLOSE, buffer, bar));
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
   return(iRSIX(NULL, rsi.periods, PRICE_CLOSE, buffer, bar));
}


/**
 * Event handler called if "open position" coditions are satisfied.
 *
 * @param  int direction - trade direction: OP_LONG|OP_SHORT
 *
 * @return bool - success status
 */
bool onSignal.OpenPosition(int direction) {
   if (!signals) return(true);

   string name, message;
   if (MACD.Fast.Method == MACD.Slow.Method) name = __NAME() +"("+ MACD.Fast.Method +"("+ MACD.Fast.Periods +","+                          MACD.Slow.Periods +"), RSI("+ RSI.Periods +"))";
   else                                      name = __NAME() +"("+ MACD.Fast.Method +"("+ MACD.Fast.Periods +"), "+ MACD.Slow.Method +"("+ MACD.Slow.Periods +"), RSI("+ RSI.Periods +"))";
   int error = 0;

   if (direction == OP_LONG) {
      message = name +" signal \"open long position\"";
      log("onSignal.OpenPosition(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.open_long);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message);
      last.signal = direction;
      return(!error);
   }

   if (direction == OP_SHORT) {
      message = name +" signal \"open short position\"";
      log("onSignal.OpenPosition(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.open_short);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message);
      last.signal = direction;
      return(!error);
   }

   return(!catch("onSignal.OpenPosition(3)  invalid parameter direction: "+ direction +" (unknown)", ERR_INVALID_PARAMETER));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MACD.Fast.Periods=",   MACD.Fast.Periods,                   ";", NL,
                            "MACD.Fast.Method=",    DoubleQuoteStr(MACD.Fast.Method),    ";", NL,
                            "MACD.Slow.Periods=",   MACD.Slow.Periods,                   ";", NL,
                            "MACD.Slow.Method=",    DoubleQuoteStr(MACD.Slow.Method),    ";", NL,

                            "RSI.Periods=",         RSI.Periods,                         ";", NL,

                            "Lotsize=",             NumberToStr(Lotsize, ".1+"),         ";", NL,

                            "TakeProfit.1=",        TakeProfit.1,                        ";", NL,
                            "TakeProfit.2=",        TakeProfit.2,                        ";", NL,
                            "TakeProfit.3=",        TakeProfit.3,                        ";", NL,

                            "StopLoss=",            StopLoss,                            ";", NL,

                            "Notify.onOpenSignal=", DoubleQuoteStr(Notify.onOpenSignal), ";")
   );
}

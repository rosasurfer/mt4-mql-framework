/**
 * MA Tunnel
 *
 * A signal monitor for price crossing a High/Low channel (aka tunnel) around a single Moving Average.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods                 = 36;
extern string MA.Method                  = "SMA | LWMA | EMA* | SMMA";
extern string MA.AppliedPrice            = "Open | Close | Median* | Typical | Weighted";    // High|Low can't be used to create a H/L tunnel
extern color  Tunnel.Color               = Magenta;
extern int    Max.Bars                   = 10000;     // max. values to calculate (-1: all available)
extern string ___a__________________________;

extern bool   Signal.onTunnelCross       = false;
extern bool   Signal.onTunnelCross.Sound = true;
extern bool   Signal.onTunnelCross.Popup = false;
extern bool   Signal.onTunnelCross.Mail  = false;
extern bool   Signal.onTunnelCross.SMS   = false;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/ConfigureSignals.mqh>

#define MODE_TUNNEL_HIGH      0                    // indicator buffer ids
#define MODE_TUNNEL_LOW       1                    //
#define MODE_TREND            2                    // direction and shift of the last tunnel crossing: +1...+n=up, -1...-n=down

#property indicator_chart_window
#property indicator_buffers   3

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE

int    maMethod;
int    maAppliedPrice;
int    maxBarsBack;

string legendInfo = "";                            // additional chart legend info

bool   signalCrossing;
bool   signalCrossing.sound;
bool   signalCrossing.popup;
bool   signalCrossing.mail;
bool   signalCrossing.sms;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // MA.Periods
   if (AutoConfiguration) MA.Periods = GetConfigInt(indicator, "MA.Periods", MA.Periods);
   if (MA.Periods < 1)                  return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   // MA.Method
   string sValues[], sValue = MA.Method;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.Method", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   maMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)                  return(catch("onInit(2)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   if (maMethod > MODE_LWMA)            return(catch("onInit(3)  unsupported input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);
   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (AutoConfiguration) sValue = GetConfigString(indicator, "MA.AppliedPrice", sValue);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   if (StrTrim(sValue) == "") sValue = "close";    // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice == -1)            return(catch("onInit(4)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   if (maAppliedPrice > PRICE_WEIGHTED) return(catch("onInit(5)  unsupported input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   if (maAppliedPrice == PRICE_HIGH)    return(catch("onInit(6)  unsupported input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   if (maAppliedPrice == PRICE_LOW)     return(catch("onInit(7)  unsupported input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);
   // Tunnel.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Tunnel.Color = GetConfigColor(indicator, "Tunnel.Color", Tunnel.Color);
   if (Tunnel.Color == 0xFF000000) Tunnel.Color = CLR_NONE;
   // Max.Bars
   if (AutoConfiguration) Max.Bars = GetConfigInt(indicator, "Max.Bars", Max.Bars);
   if (Max.Bars < -1)                   return(catch("onInit(8)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));
   maxBarsBack = ifInt(Max.Bars==-1, INT_MAX, Max.Bars);

   // configure signaling
   signalCrossing       = Signal.onTunnelCross;
   signalCrossing.sound = Signal.onTunnelCross.Sound;
   signalCrossing.popup = Signal.onTunnelCross.Popup;
   signalCrossing.mail  = Signal.onTunnelCross.Mail;
   signalCrossing.sms   = Signal.onTunnelCross.SMS;
   legendInfo           = "";
   string signalId = "Signal.onTunnelCross";
   if (!ConfigureSignals2(signalId, AutoConfiguration, signalCrossing)) return(last_error);
   if (signalCrossing) {
      if (!ConfigureSignalsBySound2(signalId, AutoConfiguration, signalCrossing.sound)) return(last_error);
      if (!ConfigureSignalsByPopup (signalId, AutoConfiguration, signalCrossing.popup)) return(last_error);
      if (!ConfigureSignalsByMail2 (signalId, AutoConfiguration, signalCrossing.mail))  return(last_error);
      if (!ConfigureSignalsBySMS2  (signalId, AutoConfiguration, signalCrossing.sms))   return(last_error);
      if (signalCrossing.sound || signalCrossing.popup || signalCrossing.mail || signalCrossing.sms) {
         legendInfo = StrLeft(ifString(signalCrossing.sound, "sound,", "") + ifString(signalCrossing.popup, "popup,", "") + ifString(signalCrossing.mail, "mail,", "") + ifString(signalCrossing.sms, "sms,", ""), -1);
         legendInfo = "("+ legendInfo +")";
      }
      else signalCrossing = false;
   }

   return(catch("onInit(9)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   return(catch("onTick(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",                MA.Periods,                            ";", NL,
                            "MA.Method=",                 DoubleQuoteStr(MA.Method),             ";", NL,
                            "MA.AppliedPrice=",           DoubleQuoteStr(MA.AppliedPrice),       ";", NL,
                            "Tunnel.Color=",              ColorToStr(Tunnel.Color),              ";", NL,
                            "Max.Bars=",                  Max.Bars,                              ";", NL,

                            "Signal.onTunnelCross",       BoolToStr(Signal.onTunnelCross),       ";", NL,
                            "Signal.onTunnelCross.Sound", BoolToStr(Signal.onTunnelCross.Sound), ";", NL,
                            "Signal.onTunnelCross.Popup", BoolToStr(Signal.onTunnelCross.Popup), ";", NL,
                            "Signal.onTunnelCross.Mail",  BoolToStr(Signal.onTunnelCross.Mail),  ";", NL,
                            "Signal.onTunnelCross.SMS",   BoolToStr(Signal.onTunnelCross.SMS),   ";")
   );
}

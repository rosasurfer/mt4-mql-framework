/**
 * Signal indicator for the "L'mas system"
 *
 * - long:
 *    entry onBarClose: Close > UpperTunnel && MA > UpperTunnel && MACD > 0
 *    stop  onTick:     Close < LowerTunnel && MA < LowerTunnel
 *
 * - short:
 *    entry onBarClose: Close < LowerTunnel && MA < LowerTunnel && MACD < 0
 *    stop  onTick:     Close > UpperTunnel && MA > UpperTunnel
 *
 *
 * TODO:
 *  - MA Tunnel
 *     support MA method MODE_ALMA
 *
 *  - ALMA
 *     add Background.Color+Background.Width
 *     merge includes icALMA() and functions/ta/ALMA.mqh
 *
 *  - Moving Average
 *     add parameter stepping
 *
 *  - MACD
 *     rename const MODE_SECTION => MODE_TREND
 *     support SMMA
 *     add parameter stepping
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Tunnel.MA.Method               = "SMA | LWMA* | EMA | SMMA | ALMA";
extern int    Tunnel.MA.Periods              = 55;

extern string MA.Method                      = "SMA | LWMA | EMA | SMMA | ALMA*";
extern int    MA.Periods                     = 10;                                  // original: EMA(5)

extern string MACD.FastMA.Method             = "SMA | LWMA | EMA* | SMMA | ALMA";
extern int    MACD.FastMA.Periods            = 12;
extern string MACD.SlowMA.Method             = "SMA | LWMA | EMA* | SMMA | ALMA";
extern int    MACD.SlowMA.Periods            = 26;

extern string ___a__________________________ = "=== Display settings ===";
extern int    MaxBarsBack                    = 10000;                               // max. values to calculate (-1: all available)

extern string ___b__________________________ = "=== Signaling ===";
extern bool   Signal.onEntry                 = false;
extern string Signal.onEntry.Types           = "sound* | alert | mail | sms";
extern bool   Signal.onExit                  = false;
extern string Signal.onExit.Types            = "sound* | alert | mail | sms";

extern string Signal.Sound.EntryLong         = "Signal Up.wav";
extern string Signal.Sound.EntryShort        = "Signal Down.wav";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Tunnel.MA.Method
   // Tunnel.MA.Periods
   // MA.Method
   // MA.Periods
   // MACD.FastMA.Method
   // MACD.FastMA.Periods
   // MACD.SlowMA.Method
   // MACD.SlowMA.Periods




   return(catch("onInit(1)"));
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
   return(StringConcatenate("Tunnel.MA.Method=",        DoubleQuoteStr(Tunnel.MA.Method),        ";", NL,
                            "Tunnel.MA.Periods=",       Tunnel.MA.Periods,                       ";", NL,
                            "MA.Method=",               DoubleQuoteStr(MA.Method),               ";", NL,
                            "MA.Periods=",              MA.Periods,                              ";", NL,
                            "MACD.FastMA.Method=",      DoubleQuoteStr(MACD.FastMA.Method),      ";", NL,
                            "MACD.FastMA.Periods=",     MACD.FastMA.Periods,                     ";", NL,
                            "MACD.SlowMA.Method=",      DoubleQuoteStr(MACD.SlowMA.Method),      ";", NL,
                            "MACD.SlowMA.Periods=",     MACD.SlowMA.Periods,                     ";", NL,

                            "MaxBarsBack=",             MaxBarsBack,                             ";", NL,

                            "Signal.onEntry=",          BoolToStr(Signal.onEntry),               ";", NL,
                            "Signal.onEntry.Types=",    DoubleQuoteStr(Signal.onEntry.Types),    ";", NL,
                            "Signal.onExit=",           BoolToStr(Signal.onExit),                ";", NL,
                            "Signal.onExit.Types=",     DoubleQuoteStr(Signal.onExit.Types),     ";", NL,
                            "Signal.Sound.EntryLong=",  DoubleQuoteStr(Signal.Sound.EntryLong),  ";", NL,
                            "Signal.Sound.EntryShort=", DoubleQuoteStr(Signal.Sound.EntryShort), ";")
   );
}

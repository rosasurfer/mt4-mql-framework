/**
 ****************************************************************************************************************************
 *                                           WORK-IN-PROGRESS, DO NOT YET USE                                               *
 ****************************************************************************************************************************
 *
 * Rewritten version of "Opto123 EA" v1.1 (USDBot). The original trade logic is unchanged.
 *
 *  @source  https://www.forexfactory.com/thread/210023-123-pattern-ea
 *  @origin  optojay
 *
 *
 * Changes
 * -------
 *  - replaced MetaQuotes ZigZag with rosasurfer version
 *  - removed dynamic lot sizing
 *  - removed TrailingStop (to be re-added later)
 *  - replaced BreakevenStop by MovingStop configuration
 *  - restored close on opposite breakout
 *
 *
 * TODO:
 *  - visualization of current position
 *  - log execution of limits
 *  - optimize ManagePosition(): precalculate target prices, track processing status of levels
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////
                                                                                                                           //
extern string Instance.ID                    = "";          // instance to load from a status file (format "[T]123")       //
extern int    MagicNumber                    = 123456;                                                                     //
                                                                                                                           //  +-------------+-------------+-------------+
extern string ___a__________________________ = "=== Signal settings ===";                                                  //  |  @rraygun   | @matrixebiz |  @optojay   |
extern int    ZigZag.Periods                 = 6;                                                                          //  +-------------+-------------+-------------+
extern int    MinBreakoutDistance            = 0;           // in pip (0: breakout at semaphore level)                     //  |   off (0)   |   off (0)   |   off (0)   |
                                                                                                                           //  +-------------+-------------+-------------+
extern string ___b__________________________ = "=== Trade settings ===";                                                   //  |             |             |             |
extern double Lots                           = 0.1;                                                                        //  |             |             |             |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Initial.TakeProfit             = 100;         // in pip (0: partial targets only or no TP)                   //  |  off (60)   |  on (100)   |  on (400)   |
extern int    Initial.StopLoss               = 50;          // in pip (0: moving stops only or no SL                       //  |  on (100)   |  on (100)   |  on (100)   |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target1                        = 0;           // in pip                                                      //  |      50     |      10     |      20     |
extern int    Target1.ClosePercent           = 0;           // size to close (0: nothing)                                  //  |      0%     |     10%     |     25%     |
extern int    Target1.MoveStopTo             = 1;           // in pip (0: don't move stop)                                 //  |       1     |       1     |     -50     | 1: Breakeven-Stop (OpenPrice + 1 pip)
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target2                        = 0;           // ...                                                         //  |             |      20     |      40     |
extern int    Target2.ClosePercent           = 30;          // ...                                                         //  |             |     10%     |     25%     |
extern int    Target2.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |     -30     |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target3                        = 0;           // ...                                                         //  |             |      40     |     100     |
extern int    Target3.ClosePercent           = 30;          // ...                                                         //  |             |     10%     |     20%     |
extern int    Target3.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |      20     |
                                                                                                                           //  +-------------+-------------+-------------+
extern int    Target4                        = 0;           // ...                                                         //  |             |      60     |     200     |
extern int    Target4.ClosePercent           = 30;          // ...                                                         //  |             |     10%     |     20%     |
extern int    Target4.MoveStopTo             = 0;           // ...                                                         //  |             |      -      |      -      |
                                                                                                                           //  +-------------+-------------+-------------+
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/iCustom/ZigZag.mqh>
#include <structs/rsf/OrderExecution.mqh>

#define STRATEGY_ID      109           // unique strategy id (used for magic order numbers)

#define INSTANCE_ID_MIN    1           // range of valid instance ids
#define INSTANCE_ID_MAX  999           //

#define SIGNAL_LONG        1           // signal flags, can be combined
#define SIGNAL_SHORT       2
#define SIGNAL_CLOSE       4

double targets[4][4];                  // profit targets and stop configurations

#define T_LEVEL            0           // indexes of converted targets
#define T_CLOSE_PCT        1
#define T_REMAINDER        2
#define T_MOVE_STOP        3

// instance data
int      instance.id;                  // used for magic order numbers
string   instance.name = "";
datetime instance.created;
int      instance.status = -1;
bool     instance.isTest;

// order data
int      open.ticket;
int      open.type;
double   open.lots;
double   open.price;
double   open.stoploss;
double   open.takeprofit;

// other
int      order.slippage = 1;           // in MQL point

#include <ea/123-trader/init.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(catch("onTick(1)  illegal instance.status: "+ instance.status, ERR_ILLEGAL_STATE));

   if (__isChart) HandleCommands();    // process incoming commands
   int signal, oe[];

   // manage an open position
   if (open.ticket > 0) {
      if (IsExitSignal()) {
         if (!OrderCloseEx(open.ticket, NULL, order.slippage, CLR_CLOSED, NULL, oe)) return(oe.Error(oe));
         open.ticket = NULL;
      }
      else if (!ManagePosition()) return(last_error);
   }

   // check for entry signal and open a new position
   if (!open.ticket) {
      if (IsEntrySignal(signal)) {
         int  type = ifInt(signal==SIGNAL_LONG, OP_BUY, OP_SELL), colors[]={CLR_OPEN_LONG, CLR_OPEN_SHORT};
         double sl = CalculateInitialStopLoss(type);
         double tp = CalculateInitialTakeProfit(type);

         int ticket = OrderSendEx(NULL, type, Lots, NULL, order.slippage, sl, tp, "123 v1.1|"+ MagicNumber, MagicNumber, NULL, colors[type], NULL, oe);
         if (!ticket) return(oe.Error(oe));
         open.ticket     = ticket;
         open.type       = type;
         open.lots       = Lots;
         open.price      = oe.OpenPrice(oe);
         open.stoploss   = sl;
         open.takeprofit = tp;
      }
   }
   return(catch("onTick(1)"));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   string fullCmd = cmd +":"+ params +":"+ keys;

   if (cmd == "toggle-open-orders") {
      return(ToggleOpenOrders());
   }
   else return(!logNotice("onCommand(1)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(2)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Toggle the display of open orders.
 *
 * @param  bool soundOnNone [optional] - whether to play a sound if no open orders exist (default: yes)
 *
 * @return bool - success status
 */
bool ToggleOpenOrders(bool soundOnNone = true) {
   return(!catch("ToggleOpenOrders(1)  not implemented", ERR_NOT_IMPLEMENTED));
}


/**
 * Calculate a position's initial StopLoss value.
 *
 * @param  int direction - trade direction
 *
 * @return double - StopLoss value or NULL if no initial StopLoss is configured
 */
double CalculateInitialStopLoss(int direction) {
   double sl = 0;

   if (Initial.StopLoss > 0) {
      if (direction == OP_LONG) sl = Bid - Initial.StopLoss*Pip;
      else                      sl = Ask + Initial.StopLoss*Pip;
   }
   return(NormalizeDouble(sl, Digits));
}


/**
 * Calculate a position's initial TakeProfit value.
 *
 * @param  int direction - trade direction
 *
 * @return double - TakeProfit value or NULL if no initial TakeProfit is configured
 */
double CalculateInitialTakeProfit(int direction) {
   double tp = 0;

   if (Initial.TakeProfit > 0) {
      if      (direction == OP_LONG)  tp = Ask + Initial.TakeProfit*Pip;
      else if (direction == OP_SHORT) tp = Bid - Initial.TakeProfit*Pip;
   }
   return(NormalizeDouble(tp, Digits));
}


/**
 * Manage partial profits and moving stops of an open position.
 *
 * @return bool - success status
 */
bool ManagePosition() {
   if (!open.ticket) return(!catch("ManagePosition(1)  no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   int sizeTargets = ArrayRange(targets, 0);

   // process configured profit targets
   for (int i=sizeTargets-1; i >= 0; i--) {
      if (targets[i][T_CLOSE_PCT] > 0) {
         if (open.type == OP_BUY) {
            if (Bid >= open.price + targets[i][T_LEVEL]*Pip) {
               if (!TakePartialProfit(targets[i][T_REMAINDER])) return(false);
               break;
            }
         }
         else if (Ask <= open.price - targets[i][T_LEVEL]*Pip) {
            if (!TakePartialProfit(targets[i][T_REMAINDER])) return(false);
            break;
         }
      }
   }

   // process configured stops
   if (open.ticket > 0) {
      for (i=sizeTargets-1; i >= 0; i--) {
         if (targets[i][T_MOVE_STOP] != 0) {
            if (open.type == OP_BUY) {
               if (Bid >= open.price + targets[i][T_LEVEL]*Pip) {
                  if (!MoveStop(targets[i][T_MOVE_STOP])) return(false);
                  break;
               }
            }
            else if (Ask <= open.price - targets[i][T_LEVEL]*Pip) {
               if (!MoveStop(targets[i][T_MOVE_STOP])) return(false);
               break;
            }
         }
      }
   }
   return(!catch("ManagePosition(2)"));
}


/**
 * Close a partial amount of the open position. If the position is smaller then the required open lotsize after profit
 * taking, then this function does nothing.
 *
 * @param  double remainder - required remaining open lotsize
 *
 * @return bool - success status
 */
bool TakePartialProfit(double remainder) {
   if (!open.ticket) return(!catch("TakePartialProfit(1)  no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   if (open.lots > remainder) {
      int oe[];
      if (!OrderCloseEx(open.ticket, open.lots-remainder, order.slippage, CLR_CLOSED, NULL, oe)) return(!SetLastError(oe.Error(oe)));

      open.ticket = oe.RemainingTicket(oe);
      if (open.ticket > 0) {
         open.lots = oe.RemainingLots(oe);
      }
   }
   return(true);
}


/**
 * Move the StopLoss of the open position the specified distance away from the open price.
 *
 * @param  int distFromOpen - distance from open price in pip
 *
 * @return bool - success status
 */
bool MoveStop(int distFromOpen) {
   if (!open.ticket) return(!catch("MoveStop(1)  no open position found: open.ticket=0", ERR_ILLEGAL_STATE));

   if (open.type == OP_BUY) double newStop = open.price + distFromOpen*Pip;
   else                            newStop = open.price - distFromOpen*Pip;

   if (NE(newStop, open.stoploss, Digits)) {
      int oe[];
      if (!OrderModifyEx(open.ticket, open.price, newStop, open.takeprofit, NULL, CLR_OPEN_STOPLOSS, NULL, oe)) return(!SetLastError(oe.Error(oe)));
      open.stoploss = newStop;
   }
   return(true);
}


/**
 * Whether a signal occurred to open a new position.
 *
 * @param  _Out_ int &signal - variable receiving the signal identifier of the triggered condition
 *
 * @return bool
 */
bool IsEntrySignal(int &signal) {
   if (IsTradeSignal(signal)) {
      if (signal & SIGNAL_LONG != 0) {
         signal = SIGNAL_LONG;
         return(true);
      }
      if (signal & SIGNAL_SHORT != 0) {
         signal = SIGNAL_SHORT;
         return(true);
      }
   }
   return(false);
}


/**
 * Whether a signal occurred to close an open position.
 *
 * @return bool
 */
bool IsExitSignal() {
   int signal;
   if (IsTradeSignal(signal)) {
      return(signal & SIGNAL_CLOSE != 0);
   }
   return(false);
}


/**
 * Whether a trade signal occurred.
 *
 * @param  _Out_ int &signal - variable receiving a combination of signal flags of triggered conditions
 *
 * @return bool
 */
bool IsTradeSignal(int &signal) {
   signal = NULL;
   static int lastTick, lastResult;

   if (Ticks == lastTick) {                              // return the same result for the same tick
      signal = lastResult;
   }
   else {
      // find the previous 3 ZigZag semaphores
      int s1Bar, s2Bar, s3Bar, s2Type, iNull;
      double s1Level, s2Level, s3Level, entryLevel, dNull;
      if (!FindNextSemaphore(    0, s3Bar, iNull,  s3Level)) return(false);
      if (!FindNextSemaphore(s3Bar, s2Bar, s2Type, s2Level)) return(false);
      if (!FindNextSemaphore(s2Bar, s1Bar, iNull,  s1Level)) return(false);
      int trend = ifInt(s2Type==MODE_HIGH, OP_LONG, OP_SHORT);

      // check for a close signal for an open position
      if (open.ticket > 0) {
         if (open.type == OP_LONG) {
            if (trend == OP_SHORT) {
               if (Bid < s2Level) signal = SIGNAL_CLOSE;
            }
         }
         else if (trend == OP_LONG) {
            if (Bid > s2Level) signal = SIGNAL_CLOSE;    // Bid prevents the close signal to be triggered by spread widening
         }
      }

      // check for an open signal for a new position
      if (!open.ticket || signal==SIGNAL_CLOSE) {
         if (trend == OP_LONG) {
            entryLevel = s2Level + MinBreakoutDistance*Pip;
            if (s1Level < s3Level && Bid > entryLevel) signal |= SIGNAL_LONG;
         }
         else {
            entryLevel = s2Level - MinBreakoutDistance*Pip;
            if (s1Level > s3Level && Bid < entryLevel) signal |= SIGNAL_SHORT;
         }
      }

      if (signal != NULL) {
         if (IsLogNotice()) {
            if (signal & SIGNAL_CLOSE               != 0) logNotice("IsTradeSignal(1)  close signal at "+ NumberToStr(s2Level, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
            if (signal & (SIGNAL_LONG|SIGNAL_SHORT) != 0) logNotice("IsTradeSignal(2)  "+ ifString(signal & SIGNAL_LONG, "long", "short") +" signal at "+ NumberToStr(entryLevel, PriceFormat) +" (market: "+ NumberToStr(Bid, PriceFormat) +"/"+ NumberToStr(Ask, PriceFormat) +")");
         }
      }
      lastTick = Ticks;
      lastResult = signal;
   }
   return(signal != NULL);
}


/**
 * Find the next ZigZag semaphore starting at the specified bar offset.
 *
 * @param  _In_  int    startbar - startbar to search from
 * @param  _Out_ int    &offset  - offset of the found ZigZag semaphore
 * @param  _Out_ int    &type    - type of the found semaphore: MODE_HIGH|MODE_LOW
 * @param  _Out_ double &price   - price level of the found semaphore
 *
 * @return bool - success status
 */
bool FindNextSemaphore(int startbar, int &offset, int &type, double &price) {
   int trend = MathRound(icZigZag(NULL, ZigZag.Periods, ZigZag.MODE_TREND, startbar));
   if (!trend) return(false);

   int absTrend = MathAbs(trend);
   offset = startbar + (absTrend % 100000) + (absTrend / 100000);

   if (trend < 0) {
      type = MODE_HIGH;
      price = High[offset];
   }
   else {
      type = MODE_LOW;
      price = Low[offset];
   }

   //debug("FindNextSemaphore(1)  Tick="+ Ticks +"  startbar="+ startbar +"  trend="+ trend +"  semaphore["+ offset +"]="+ TimeToStr(Time[offset], TIME_DATE|TIME_MINUTES) +"  "+ PriceTypeDescription(type));
   return(true);
}


/**
 * Return a readable representation of an instance status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case NULL: return("(null)"           );
      case -1:   return("(not-implemented)");
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of an instance status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case NULL: return("undefined"      );
      case -1:   return("not-implemented");
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Display the current runtime status.
 *
 * @param  int error [optional] - error to display (default: none)
 *
 * @return int - the same error or the current error status if no error was specified
 */
int ShowStatus(int error = NO_ERROR) {
   if (!__isChart) return(error);

   static bool isRecursion = false;          // to prevent recursive calls a specified error is displayed only once
   if (error != 0) {
      if (isRecursion) return(error);
      isRecursion = true;
   }
   string sStatus="", sError="";

   switch (instance.status) {
      case NULL: sStatus = StringConcatenate(instance.name, "  not initialized");          break;
      case -1:   sStatus = StringConcatenate(instance.name, "  (status not implemented)"); break;
      default:
         return(catch("ShowStatus(1)  "+ instance.name +" illegal instance status: "+ instance.status, ERR_ILLEGAL_STATE));
   }
   if (__STATUS_OFF) sError = StringConcatenate("  [switched off => ", ErrorDescription(__STATUS_OFF.reason), "]");

   string text = StringConcatenate(ProgramName(), "    ", sStatus, sError, NL);

   // 3 lines margin-top for instrument and indicator legends
   Comment(NL, NL, NL, text);
   if (__CoreFunction == CF_INIT) WindowRedraw();

   // store status in the chart to enable sending of chart commands
   string label = "EA.status";
   if (ObjectFind(label) != 0) {
      ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   }
   ObjectSetText(label, StringConcatenate(Instance.ID, "|", StatusDescription(instance.status)));

   error = intOr(catch("ShowStatus(2)"), error);
   isRecursion = false;
   return(error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=",          DoubleQuoteStr(Instance.ID), ";"+ NL +
                            "MagicNumber=",          MagicNumber,                 ";"+ NL +

                            "ZigZag.Periods=",       ZigZag.Periods,              ";"+ NL +
                            "MinBreakoutDistance=",  MinBreakoutDistance,         ";"+ NL +
                            "Lots=",                 NumberToStr(Lots, ".1+"),    ";"+ NL +

                            "Initial.TakeProfit=",   Initial.TakeProfit,          ";"+ NL +
                            "Initial.StopLoss=",     Initial.StopLoss,            ";"+ NL +
                            "Target1=",              Target1,                     ";"+ NL +
                            "Target1.ClosePercent=", Target1.ClosePercent,        ";"+ NL +
                            "Target1.MoveStopTo=",   Target1.MoveStopTo,          ";"+ NL +
                            "Target2=",              Target2,                     ";"+ NL +
                            "Target2.ClosePercent=", Target2.ClosePercent,        ";"+ NL +
                            "Target2.MoveStopTo=",   Target2.MoveStopTo,          ";"+ NL +
                            "Target3=",              Target3,                     ";"+ NL +
                            "Target3.ClosePercent=", Target3.ClosePercent,        ";"+ NL +
                            "Target3.MoveStopTo=",   Target3.MoveStopTo,          ";"+ NL +
                            "Target4=",              Target4,                     ";"+ NL +
                            "Target4.ClosePercent=", Target4.ClosePercent,        ";"+ NL +
                            "Target4.MoveStopTo=",   Target4.MoveStopTo,          ";")
   );
}

/**
 * A system following the trend of the SuperTrend or HalfTrend indicator.
 *
 * Note: Test prototype, don't use in a real account.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern double Lotsize = 0.1;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/JoinStrings.mqh>
#include <structs/rsf/OrderExecution.mqh>

// position management
int long.position;
int short.position;

// order marker colors
#define CLR_OPEN_LONG   Blue
#define CLR_OPEN_SHORT  Red
#define CLR_CLOSE       Orange


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (IsBarOpenEvent()) {
      int trend = GetSuperTrend(SuperTrend.MODE_TREND, 1);

      if (trend == 1) {
         ClosePosition(OP_SHORT);
         OpenPosition(OP_LONG);
      }
      if (trend == -1) {
         ClosePosition(OP_LONG);
         OpenPosition(OP_SHORT);
      }
   }
   return(catch("onTick(1)"));
}


/**
 * Return a SuperTrend indicator value.
 *
 * @param  int mode - buffer index of the value to return
 * @param  int bar  - bar index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetSuperTrend(int mode, int bar) {
   int atrPeriods = 5;
   int smaPeriods = 50;
   return(iSuperTrend(NULL, atrPeriods, smaPeriods, mode, bar));
}


/**
 * Open a position at the current price.
 *
 * @param  int type - position type: OP_LONG|OP_SHORT
 *
 * @return bool - success status
 */
bool OpenPosition(int type) {
   string   symbol      = Symbol();
   double   lots        = Lotsize;
   double   price       = NULL;
   double   slippage    = 0.1;
   double   stopLoss    = NULL; //stopLoss   = ifDouble(type==OP_LONG, Ask - 500*Pip, Bid + 500*Pip);
   double   takeProfit  = NULL; //takeProfit = ifDouble(type==OP_LONG, Ask + 500*Pip, Bid - 500*Pip);
   string   comment     = "";
   int      magicNumber = NULL;
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int oe[], oeFlags    = NULL;

   int ticket = OrderSendEx(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(false);

   if (type == OP_LONG) long.position  = ticket;
   else                 short.position = ticket;
   return(true);
}


/**
 * Close an open position.
 *
 * @param  int type - position type: OP_LONG|OP_SHORT
 *
 * @return bool - success status
 */
bool ClosePosition(int type) {
   if      (type == OP_LONG) int ticket = long.position;
   else if (type == OP_SHORT)    ticket = short.position;
   else return(!catch("ClosePosition(1)  invalid parameter type = "+ type, ERR_INVALID_PARAMETER));
   if (!ticket) return(true);

   double slippage = 0.1;
   int oeFlags = F_ERR_INVALID_TRADE_PARAMETERS, oe[];

   bool success = OrderCloseEx(ticket, NULL, slippage, CLR_CLOSE, oeFlags, oe);
   if (success || oe.Error(oe)==ERR_INVALID_TRADE_PARAMETERS) {      // the order may be already closed by SL/TP
      if (type == OP_LONG) long.position  = 0;
      else                 short.position = 0;
      return(true);
   }
   return(false);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Lotsize=", NumberToStr(Lotsize, ".1+"), ";"));
}

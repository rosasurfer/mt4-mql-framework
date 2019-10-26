/**
 * A system following the trend of the SuperTrend or HalfTrend indicator.
 *
 * Note: Incomplete work in progress, don't use in real account.
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
#define CLR_OPEN_LONG   C'0,0,254'              // Blue - rgb(1,1,1)
#define CLR_OPEN_SHORT  C'254,0,0'              // Red  - rgb(1,1,1)
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
         debug("onTick(1)  SuperTrend turned up");
         if (short.position != 0) ClosePosition(short.position);
         OpenPosition(OP_LONG);
      }
      if (trend == -1) {
         debug("onTick(2)  SuperTrend turned down");
         if (long.position != 0) ClosePosition(long.position);
         OpenPosition(OP_SHORT);
      }
   }
   return(catch("onTick(3)"));
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
   return(icSuperTrend(NULL, atrPeriods, smaPeriods, mode, bar));
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
   double   stopLoss    = NULL;
   double   takeProfit  = NULL;
   string   comment     = "";
   int      magicNumber = NULL;
   datetime expires     = NULL;
   color    markerColor = ifInt(type==OP_BUY, CLR_OPEN_LONG, CLR_OPEN_SHORT);
   int oe[], oeFlags    = NULL;

   int ticket = OrderSendEx(symbol, type, lots, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (!ticket) return(false);

   if (type == OP_BUY) long.position  = ticket;
   else                short.position = ticket;
   return(true);
}


/**
 * Close an open position.
 *
 * @param  int ticket
 *
 * @return bool - success status
 */
bool ClosePosition(int ticket) {
   double slippage = 0.1;
   int oe[], oeFlags = NULL;

   if (!OrderCloseEx(ticket, NULL, slippage, CLR_CLOSE, oeFlags, oe)) return(false);

   if (oe.Type(oe) == OP_BUY) long.position  = 0;
   else                       short.position = 0;
   return(true);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Lotsize=", NumberToStr(Lotsize, ".1+"), ";"));
}

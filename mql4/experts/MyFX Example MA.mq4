/**
 * Auf das XTrade-Framework umgestellte Version des "MetaQuotes Example MA". Die Strategie ist unverändert.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int    MA.Period      = 12;
extern int    MA.Shift       =  6;
extern double Lotsize        =  0.5;
extern double DecreaseFactor = 10.0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>


#define MAGICNO_MA  20050610

int slippage = 5;


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // check runtime status
   if (Bars < 100 || !IsTradeAllowed()) return(last_error);

   // check current position
   if (!IsOpenPosition()) CheckForOpenSignal();
   else                   CheckForCloseSignal();      // Es ist maximal eine Position (Long oder Short) offen.

   return(last_error);
}


/**
 * Ob die Strategie im Moment offene Positionen hat.
 *
 * @return bool
 */
bool IsOpenPosition() {
   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;

      if (OrderMagicNumber()==MAGICNO_MA) /*&&*/ if (OrderSymbol()==Symbol()) {
         if (OrderType() == OP_BUY ) return(true);
         if (OrderType() == OP_SELL) return(true);
      }
   }
   return(false);
}


/**
 * Check for entry conditions
 */
void CheckForOpenSignal() {
   if (Volume[0] > 1)            // open positions only onBarOpen
      return;

   static double   stopLoss   = NULL;
   static double   takeProfit = NULL;
   static string   comment    = "";
   static datetime expiration = NULL;

   // Simple Moving Average of Bar[MA.Shift]
   double ma = iMA(NULL, NULL, MA.Period, MA.Shift, MODE_SMA, PRICE_CLOSE, 0);                                    // MA[0] mit MA.Shift entspricht MA[Shift] bei Shift=0.
                                                                                                                  // Mit einem SMA(12) liegt jede Bar zumindest in der Nähe des
   // Blödsinn: Long-Signal, wenn die letzte Bar bullish war und MA[6] innerhalb ihres Bodies liegt.              // MA, die Entry-Signale sind also praktisch zufällig.
   if (Open[1] < ma && Close[1] > ma) {
      OrderSend(Symbol(), OP_BUY, CalculateLotsize(), Ask, slippage, stopLoss, takeProfit, comment, MAGICNO_MA, expiration, Blue);
      return;
   }

   // Blödsinn: Short-Signal, wenn kein Long-Signal, die letzte Bar bearish war und MA[6] innerhalb ihres Bodies liegt.
   if (Open[1] > ma && Close[1] < ma) {
      OrderSend(Symbol(), OP_SELL, CalculateLotsize(), Bid, slippage, stopLoss, takeProfit, comment, MAGICNO_MA, expiration, Red);
      return;
   }
}


/**
 * Check for exit conditions                                                     // Da es keinen TakeProfit gibt und der fast zufällige Exit in der Nähe des Entries
 *                                                                               // wie ein kleiner StopLoss wirkt, provoziert die Strategie viele kleine Verluste.
 * Es ist maximal eine Position (Long oder Short) offen.                         // Sie verhält sich ähnlich einer umgedrehten Scalping-Strategie, entsprechend verursachen
 */                                                                              // Slippage, Spread und Gebühren massive Schwankungen (in diesem Fall beim Verlust).
void CheckForCloseSignal() {
   if (Volume[0] > 1)                                                            // close only onBarOpen
      return;

   // Simple Moving Average of MA[Shift]
   double ma = iMA(NULL, NULL, MA.Period, MA.Shift, MODE_SMA, PRICE_CLOSE, 0);

   int orders = OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         break;

      if (OrderMagicNumber()==MAGICNO_MA) /*&&*/ if (OrderSymbol()==Symbol()) {
         if (OrderType() == OP_BUY) {                                            // Blödsinn analog zum Entry-Signal
            if (Open[1] > ma) /*&&*/ if(Close[1] < ma) {
               OrderClose(OrderTicket(), OrderLots(), Bid, slippage, Orange);    // Exit-Long, wenn die letzte Bar bearisch war und MA[Shift] innerhalb ihres Bodies liegt.
            }
            break;
         }
         if (OrderType() == OP_SELL) {
            if (Open[1] < ma) /*&&*/ if (Close[1] > ma) {                        // Exit-Short, wenn die letzte Bar bullish war und MA[Shift] innerhalb ihres Bodies liegt.
               OrderClose(OrderTicket(), OrderLots(), Ask, slippage, Orange);
            }
            break;
         }
      }
   }
}


/**
 * Berechnet die zu verwendende Lotsize.
 *
 * @return double
 */
double CalculateLotsize() {
   // default lot size
   double lots = Lotsize;

   if (DecreaseFactor > 0) {
      // calculate number of consecutive losses
      int consecutiveLosses, orders=HistoryTotal();

      for (int i=orders-1; i >= 0; i--) {                      // rückwärts, um den letzten geschlossenen Trade auszuwerten
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            break;
         if (OrderMagicNumber()==MAGICNO_MA) /*&&*/ if (OrderType()<=OP_SELL) /*&&*/ if (OrderSymbol()==Symbol()) {
            if (OrderProfit() > 0) break;
            if (OrderProfit() < 0) consecutiveLosses++;
         }
      }
      if (consecutiveLosses > 1)
         lots -= consecutiveLosses/DecreaseFactor * lots;
   }

   if (lots < 0.1)
      lots = 0.1;
   return(NormalizeDouble(lots, 1));
}
/**
 * CloseOrders
 *
 * Closes all open orders matching the specified input criteria.
 *
 *
 * TODO:
 *  - FATAL  CloseOrders::rsfStdlib::OrderCloseByEx(10)  opposite ticket #487167489 is not an open position (anymore)  [ERR_INVALID_TRADE_PARAMETERS]
 *
 *  - INFO   CloseOrders::rsfStdlib::OrdersCloseSameSymbol(16)  closing 16 XAUUSD positions...
 *    INFO   CloseOrders::rsfStdlib::OrdersHedge(17)  hedging 16 XAUUSD positions...
 *    FATAL  CloseOrders::rsfStdlib::OrderSendEx(28)  error while trying to Buy 0.14 XAUUSD at 2'329.99 after 0.000 s  [ERR_NOT_ENOUGH_MONEY]
 *  - support deletion of TP/SL limits
 *  - Bybit: use config for IsDemoFix()
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED, INIT_AUTO_TRADING};
int __DeinitFlags[];
#property show_inputs

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Close.Symbols      = "(current)"; // symbols separated by comma (default: current symbol, *: all symbols)
extern string Close.Tickets      = "";          // tickets separated by comma (with or w/o leading "#")                    // or a full logmessage produced by CustomPositions.LogOrders(); or the text of an order arrow
extern string Close.OrderTypes   = "";          // order types separated by comma (Buy, Sell, Long, Short, P[ending], Buy[-]Limit, Sell[-]Limit, Stop[-]Buy, Stop[-]Sell)
extern string Close.MagicNumbers = "0";         // magic numbers separated by comma (0: manual trades only)
extern string Close.Comments     = "";          // prefix of order comments separated by comma
extern bool   Close.HedgedPart   = false;       // close hedged part of matching tickets only

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/structs/OrderExecution.mqh>

bool   closeAllSymbols;
string closeSymbols [];                         // symbols to close
int    closeTypes   [];
int    closeTickets [];
int    closeMagics  [];
string closeComments[];


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Close.Symbols
   closeAllSymbols = false;
   string sValues[], sValue = Close.Symbols;
   int size = Explode(sValue, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;

      if (sValue == "*") {
         ArrayResize(closeSymbols, 0);
         closeAllSymbols = true;
         break;
      }
      if (sValue == "(current)") ArrayPushString(closeSymbols, Symbol());
      else                       ArrayPushString(closeSymbols, sValue);
   }

   // Close.Tickets
   sValue = StrTrim(Close.Tickets);
   if (StrContains(sValue, "{") && StrEndsWith(sValue, "}")) { // if a log message from AnalyzePositions() => "log message text {#ticket1:lotsize, ..., #ticketN}"
      sValue = StrRightFrom(StrLeft(sValue, -1), "{", -1);     // extract the ticket substring
   }
   size = Explode(sValue, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;
      if (sValue == "(NULL)") {                                // log messages from AnalyzePositions() may contain "(NULL)" for empty ticket entries
         if (!ArraySize(closeTickets)) {
            ArrayPushInt(closeTickets, 0);                     // add ticket #0 as marker for existing input
         }
         continue;
      }
      if (StrStartsWith(sValue, "#")) {
         sValue = StrSubstr(sValue, 1);                        // cut the hash char
         sValue = StrLeftTo(sValue, ":");                      // log messages may contain a lotsize after the ticket: "#ticket1:lotsize"
         sValue = StrLeftTo(sValue, " ");                      // object descriptions of order arrows contain trailing text: "#633270489 buy 0.01 at 77'590.70"
         sValue = StrTrim(sValue);
      }
      if (!StrIsDigits(sValue)) return(catch("onInit(1)  invalid input parameter Close.Tickets: "+ DoubleQuoteStr(sValues[i]), ERR_INVALID_INPUT_PARAMETER));
      int iValue = StrToInteger(sValue);
      if (iValue <= 0)          return(catch("onInit(2)  invalid input parameter Close.Tickets: "+ DoubleQuoteStr(sValues[i]), ERR_INVALID_INPUT_PARAMETER));
      ArrayPushInt(closeTickets, iValue);
   }

   // Close.OrderTypes
   sValue = StrToLower(Close.OrderTypes);
   size = Explode(sValue, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;

      if (StrStartsWith("pending", sValue)) {
         ArrayPushInt(closeTypes, OP_BUYLIMIT);
         ArrayPushInt(closeTypes, OP_SELLLIMIT);
         ArrayPushInt(closeTypes, OP_BUYSTOP);
         ArrayPushInt(closeTypes, OP_SELLSTOP);
      }
      else if (sValue == "l"    )                 ArrayPushInt(closeTypes, OP_BUY);
      else if (sValue == "long" )                 ArrayPushInt(closeTypes, OP_BUY);
      else if (sValue == "s"    )                 ArrayPushInt(closeTypes, OP_SELL);
      else if (sValue == "short")                 ArrayPushInt(closeTypes, OP_SELL);
      else if (sValue == "bl" || sValue == "b-l") ArrayPushInt(closeTypes, OP_BUYLIMIT);
      else if (sValue == "bs" || sValue == "b-s") ArrayPushInt(closeTypes, OP_BUYSTOP);
      else if (sValue == "sl" || sValue == "s-l") ArrayPushInt(closeTypes, OP_SELLLIMIT);
      else if (sValue == "ss" || sValue == "s-s") ArrayPushInt(closeTypes, OP_SELLSTOP);
      else {
         int type = StrToOperationType(sValue);
         if (type < OP_BUY || type > OP_SELLSTOP) return(catch("onInit(3)  invalid input parameter Close.OrderTypes: "+ DoubleQuoteStr(Close.OrderTypes), ERR_INVALID_INPUT_PARAMETER));
         ArrayPushInt(closeTypes, type);
      }
   }

   // Close.MagicNumbers
   size = Explode(Close.MagicNumbers, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;
      if (!StrIsDigits(sValue)) return(catch("onInit(4)  invalid input parameter Close.MagicNumbers: "+ DoubleQuoteStr(Close.MagicNumbers), ERR_INVALID_INPUT_PARAMETER));
      iValue = StrToInteger(sValue);
      if (iValue < 0)           return(catch("onInit(5)  invalid input parameter Close.MagicNumbers: "+ DoubleQuoteStr(Close.MagicNumbers), ERR_INVALID_INPUT_PARAMETER));
      ArrayPushInt(closeMagics, iValue);
   }

   // Close.Comments
   size = Explode(Close.Comments, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "") continue;
      ArrayPushString(closeComments, sValue);
   }

   // Close.HedgedPart
   if (Close.HedgedPart) {
      size = ArraySize(closeTypes);
      for (i=0; i < size; i++) {
         if (IsPendingOrderType(closeTypes[i])) return(catch("onInit(6)  invalid input combination Close.OrderTypes/HedgedPart: can't close hedged part of order type \""+ OperationTypeDescription(closeTypes[i]) +"\"", ERR_INVALID_INPUT_PARAMETER));
      }
   }
   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // get the tickets to close
   int pendingOrders[], openPositions[], hedgedLong[], hedgedShort[];
   if (!CollectTickets(pendingOrders, openPositions, hedgedLong, hedgedShort)) return(last_error);

   int sizePendingOrders = ArraySize(pendingOrders);
   int sizeOpenPositions = ArraySize(openPositions);
   int sizeHedgedLong    = ArraySize(hedgedLong);
   int sizeHedgedShort   = ArraySize(hedgedShort);

   // close orders
   int oe[], oes[][ORDER_EXECUTION_intSize], oeFlags=NULL;

   if (sizePendingOrders || sizeOpenPositions) {
      string sPendingOrders = ifString(sizePendingOrders, "delete "+ sizePendingOrders +" pending order"+ Pluralize(sizePendingOrders), "");
      string sAnd           = ifString(sizePendingOrders && sizeOpenPositions, " and ", "");
      string sOpenPositions = ifString(sizeOpenPositions, "close "+ sizeOpenPositions +" open position"+ Pluralize(sizeOpenPositions), "");
      string msg            = "Do you really want to "+ sPendingOrders + sAnd + sOpenPositions +"?";

      PlaySoundEx("Windows Notify.wav");
      int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, WindowExpertName(), MB_ICONQUESTION|MB_OKCANCEL);

      if (button == IDOK) {
         // refresh selected tickets (orders may have changed during wait for confirmation)
         if (!CollectTickets(pendingOrders, openPositions, hedgedLong, hedgedShort)) return(last_error);
         sizePendingOrders = ArraySize(pendingOrders);
         sizeOpenPositions = ArraySize(openPositions);
         sizeHedgedLong    = ArraySize(hedgedLong);
         sizeHedgedShort   = ArraySize(hedgedShort);

         if (sizeOpenPositions > 0) {
            if (!OrdersClose(openPositions, 1, CLR_NONE, oeFlags, oes)) return(SetLastError(oes.Error(oes)));
         }
         for (int i=0; i < sizePendingOrders; i++) {
            if (!OrderDeleteEx(pendingOrders[i], CLR_NONE, oeFlags, oe)) return(SetLastError(oe.Error(oe)));
         }
      }
   }
   else if (sizeHedgedLong && sizeHedgedShort) {
      msg = "Do you really want to close the hedged part of "+ (sizeHedgedLong + sizeHedgedShort) +" positions?";

      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, WindowExpertName(), MB_ICONQUESTION|MB_OKCANCEL);

      if (button == IDOK) {
         // refresh selected tickets (orders may have changed during wait for confirmation)
         if (!CollectTickets(pendingOrders, openPositions, hedgedLong, hedgedShort)) return(last_error);
         sizePendingOrders = ArraySize(pendingOrders);
         sizeOpenPositions = ArraySize(openPositions);
         sizeHedgedLong    = ArraySize(hedgedLong);
         sizeHedgedShort   = ArraySize(hedgedShort);

         while (sizeHedgedLong && sizeHedgedShort) {
            int longTicket  = ArrayShiftInt(hedgedLong);
            int shortTicket = ArrayShiftInt(hedgedShort);
            sizeHedgedLong--;
            sizeHedgedShort--;

            if (!OrderCloseByEx(longTicket, shortTicket, CLR_NONE, oeFlags, oe)) return(SetLastError(oe.Error(oe)));

            int remainder = oe.RemainingTicket(oe);
            if (remainder != 0) {
               if (!SelectTicket(remainder, "onStart(1)")) return(last_error);
               if (OrderType() == OP_LONG) {
                  ArrayUnshiftInt(hedgedLong, remainder);
                  sizeHedgedLong++;
               }
               else {
                  ArrayUnshiftInt(hedgedShort, remainder);
                  sizeHedgedShort++;
               }
            }
         }
      }
   }
   else {
      PlaySoundEx("Plonk.wav");
      MessageBox("No matching orders found.", WindowExpertName(), MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}


/**
 * Collect all open tickets to close.
 *
 * @param  _Out_ int pendingOrders[]
 * @param  _Out_ int openPositions[]
 * @param  _Out_ int hedgedLong[]
 * @param  _Out_ int hedgedShort[]
 *
 * @return bool - success status
 */
bool CollectTickets(int &pendingOrders[], int &openPositions[], int &hedgedLong[], int &hedgedShort[]) {
   // Don't cache the results. Order counters don't change if pending entry orders are executed.
   ArrayResize(pendingOrders, 0);
   ArrayResize(openPositions, 0);
   ArrayResize(hedgedLong,    0);
   ArrayResize(hedgedShort,   0);

   int orders = OrdersTotal();
   int sizeOfComments = ArraySize(closeComments);

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;     // an open order was closed/deleted elsewhere
      if (OrderType() > OP_SELLSTOP) continue;

      bool close = true;
      if (close) close = (closeAllSymbols          || StringInArrayI(closeSymbols, OrderSymbol()));
      if (close) close = ((!ArraySize(closeTypes)  ||     IntInArray(closeTypes,   OrderType())) && (!Close.HedgedPart || !IsPendingOrderType(OrderType())));
      if (close) close = (!ArraySize(closeTickets) ||     IntInArray(closeTickets, OrderTicket()));
      if (close) close = (!ArraySize(closeMagics)  ||     IntInArray(closeMagics,  OrderMagicNumber()));

      if (close) {
         for (int n=0; n < sizeOfComments; n++) {
            if (StrStartsWithI(OrderComment(), closeComments[n])) break;
         }
         if (sizeOfComments != 0) close = (n < sizeOfComments);   // order matches if break was triggered
      }

      if (close) {
         if (IsPendingOrderType(OrderType())) {
            if (!IntInArray(pendingOrders, OrderTicket())) ArrayPushInt(pendingOrders, OrderTicket());
         }
         else if (Close.HedgedPart) {
            if (OrderType() == OP_LONG) {
               if (!IntInArray(hedgedLong, OrderTicket())) ArrayPushInt(hedgedLong, OrderTicket());
            }
            else {
               if (!IntInArray(hedgedShort, OrderTicket())) ArrayPushInt(hedgedShort, OrderTicket());
            }
         }
         else {
            if (!IntInArray(openPositions, OrderTicket())) ArrayPushInt(openPositions, OrderTicket());
         }
      }
   }

   SortTicketsChronological(hedgedLong);
   SortTicketsChronological(hedgedShort);

   return(!catch("CollectTickets(1)"));
}

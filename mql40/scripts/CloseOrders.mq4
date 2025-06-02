/**
 * Close all orders matching the specified input.
 *
 *
 * TODO:
 *  - FATAL CloseOrders::rsfStdlib::OrderCloseByEx(10)  opposite ticket #487167489 is not an open position (anymore)  [ERR_INVALID_TRADE_PARAMETERS]

 *  - XAUUSD,M5         HedgePosition::rsfStdlib::OrdersHedge(17)  hedging 16 XAUUSD positions {#488535371:+0.01, #488535604:-0.01, #488535606:-0.01, #488535608:-0.01, #488535609:-0.01, #488535614:-0.01, #488535616:-0.01, #488535617:-0.01, #488535619:-0.01, #488535625:-0.01, #488535629:-0.01, #488535631:-0.01, #488535635:-0.01, #488535637:-0.01, #488535640:-0.01, #488535758:-0.01}
 *    XAUUSD,M5  FATAL  HedgePosition::rsfStdlib::OrderSendEx(28)  error while trying to Buy 0.14 XAUUSD at 2'330.04 (market: 2'329.96/2'330.04) after 0.000 s  [ERR_NOT_ENOUGH_MONEY]
 *
 *  - XAUUSD,M5         CloseOrders::rsfStdlib::OrdersCloseSameSymbol(16)  closing 16 XAUUSD positions {#488535371:+0.01, #488535604:-0.01, #488535606:-0.01, #488535608:-0.01, #488535609:-0.01, #488535614:-0.01, #488535616:-0.01, #488535617:-0.01, #488535619:-0.01, #488535625:-0.01, #488535629:-0.01, #488535631:-0.01, #488535635:-0.01, #488535637:-0.01, #488535640:-0.01, #488535758:-0.01}
 *    XAUUSD,M5         CloseOrders::rsfStdlib::OrdersHedge(17)  hedging 16 XAUUSD positions {#488535371:+0.01, #488535604:-0.01, #488535606:-0.01, #488535608:-0.01, #488535609:-0.01, #488535614:-0.01, #488535616:-0.01, #488535617:-0.01, #488535619:-0.01, #488535625:-0.01, #488535629:-0.01, #488535631:-0.01, #488535635:-0.01, #488535637:-0.01, #488535640:-0.01, #488535758:-0.01}
 *    XAUUSD,M5  FATAL  CloseOrders::rsfStdlib::OrderSendEx(28)  error while trying to Buy 0.14 XAUUSD at 2'329.99 (market: 2'329.93/2'329.99) after 0.000 s  [ERR_NOT_ENOUGH_MONEY]
 *
 *  - support ticket numbers from chart objects (order arrows)
 *  - support deletion of TP/SL limits
 *  - Bybit: use config for IsDemoFix()
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];

#property show_inputs

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Close.Symbols      = "(current)";    // symbols separated by comma (default: current symbol, *: all symbols)
extern string Close.Tickets      = "";             // tickets separated by comma (with or w/o leading "#")                    // or a full logmessage produced by CustomPositions.LogOrders(); or the text of an order arrow
extern string Close.OrderTypes   = "";             // order types separated by comma (Buy, Sell, Long, Short, P[ending], Buy[-]Limit, Sell[-]Limit, Stop[-]Buy, Stop[-]Sell)
extern string Close.MagicNumbers = "";             // magic numbers separated by comma
extern string Close.Comments     = "";             // prefix/start of order comments separated by comma
extern bool   Close.HedgedPart   = false;          // close hedged part of resulting tickets only

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/script.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/structs/OrderExecution.mqh>

bool   closeAllSymbols = false;

string closeSymbols [];
int    closeTypes   [];
int    closeTickets [];
int    closeMagics  [];
string closeComments[];

int    hedgedLong [];         // hedged part: long tickets of the position
int    hedgedShort[];         // hedged part: short tickets of the position


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   // Close.Symbols
   closeAllSymbols = false;
   string sValues[], sValue=Close.Symbols;
   int size = Explode(sValue, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (StringLen(sValue) > 0) {
         if (sValue == "*") {
            ArrayResize(closeSymbols, 0);
            closeAllSymbols = true;
            break;
         }
         if (sValue == "(current)") ArrayPushString(closeSymbols, Symbol());
         else                       ArrayPushString(closeSymbols, sValue);
      }
   }
   // Close.OrderTypes
   size = Explode(StrToLower(Close.OrderTypes), ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (StringLen(sValue) > 0) {
         if (StrStartsWith("pending", sValue)) {
            ArrayPushInt(closeTypes, OP_BUYLIMIT );
            ArrayPushInt(closeTypes, OP_SELLLIMIT);
            ArrayPushInt(closeTypes, OP_BUYSTOP  );
            ArrayPushInt(closeTypes, OP_SELLSTOP );
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
            if (type < OP_BUY || type > OP_SELLSTOP) return(catch("onInit(1)  invalid input parameter Close.OrderTypes: "+ DoubleQuoteStr(Close.OrderTypes), ERR_INVALID_INPUT_PARAMETER));
            ArrayPushInt(closeTypes, type);
         }
      }
   }
   // Close.Tickets
   sValue = Close.Tickets;
   if (StrContains(sValue, "{") && StrEndsWith(sValue, "}")) {    // extract the ticket substring from an AnalyzePositions(F_LOG_TICKETS) message: "log-message {#ticket1, ..., #ticketN}"
      sValue = StrRightFrom(StrLeft(sValue, -1), "{", -1);
   }
   size = Explode(sValue, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (sValue == "(NULL)") {
         ArrayPushInt(closeTickets, 0);                           // add non-existing ticket #0 to mark existing input
      }
      else if (sValue != "") {
         if (StrStartsWith(sValue, "#")) {
            sValue = StrSubstr(sValue, 1);                        // cut the hash char
            sValue = StrLeftTo(sValue, ":");                      // cut an optional lotsize after ":"
            sValue = StrTrim(sValue);
         }
         if (!StrIsDigits(sValue)) return(catch("onInit(2)  invalid value in input parameter Close.Tickets: "+ DoubleQuoteStr(sValues[i]), ERR_INVALID_INPUT_PARAMETER));
         int iValue = StrToInteger(sValue);
         if (iValue <= 0)          return(catch("onInit(3)  invalid value in input parameter Close.Tickets: "+ DoubleQuoteStr(sValues[i]), ERR_INVALID_INPUT_PARAMETER));
         ArrayPushInt(closeTickets, iValue);
      }
   }
   // Close.MagicNumbers
   size = Explode(Close.MagicNumbers, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (StringLen(sValue) > 0) {
         if (!StrIsDigits(sValue)) return(catch("onInit(4)  invalid value in input parameter Close.MagicNumbers: "+ DoubleQuoteStr(Close.MagicNumbers), ERR_INVALID_INPUT_PARAMETER));
         iValue = StrToInteger(sValue);
         if (iValue < 0)           return(catch("onInit(5)  invalid value in input parameter Close.MagicNumbers: "+ DoubleQuoteStr(Close.MagicNumbers), ERR_INVALID_INPUT_PARAMETER));
         ArrayPushInt(closeMagics, iValue);
      }
   }
   // Close.Comments
   size = Explode(Close.Comments, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (StringLen(sValue) > 0) ArrayPushString(closeComments, sValue);
   }
   // Close.HedgedPart
   if (Close.HedgedPart) {
      size = ArraySize(closeTypes);
      for (i=0; i < size; i++) {
         if (IsPendingOrderType(closeTypes[i])) return(catch("onInit(6)  invalid input combination: can't close HedgedPart of OrderType \""+ OperationTypeDescription(closeTypes[i]) +"\"", ERR_INVALID_INPUT_PARAMETER));
      }
   }

   // enable auto-trading if disabled
   if (!IsExpertEnabled()) {
      int error = Toolbar.Experts(true);
      if (IsError(error)) return(error);

      PlaySoundEx("Windows Notify.wav");                             // we must return as scripts don't update their internal auto-trading status
      MessageBox("Please call the script again!"+ NL +"(\"auto-trading\" was not enabled)", ProgramName(), MB_ICONINFORMATION|MB_OK);
      return(SetLastError(ERR_TERMINAL_AUTOTRADE_DISABLED));
   }
   return(catch("onInit(7)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   int orders = OrdersTotal(), pendingOrders[], openPositions[];

   // select orders to close
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;        // FALSE: an open order was closed/deleted in another thread
      if (OrderType() > OP_SELLSTOP)                   continue;

      bool close = true;
      if (close) close = (closeAllSymbols          || StringInArrayI(closeSymbols, OrderSymbol()));
      if (close) close = ((!ArraySize(closeTypes)  ||     IntInArray(closeTypes,   OrderType())) && (!Close.HedgedPart || !IsPendingOrderType(OrderType())));
      if (close) close = (!ArraySize(closeTickets) ||     IntInArray(closeTickets, OrderTicket()));
      if (close) close = (!ArraySize(closeMagics)  ||     IntInArray(closeMagics,  OrderMagicNumber()));

      if (close) {
         int sizeOfComments = ArraySize(closeComments);
         for (int n=0; n < sizeOfComments; n++) {
            if (StrStartsWithI(OrderComment(), closeComments[n])) break;
         }
         if (sizeOfComments != 0) close = (n < sizeOfComments);      // order matches if break was triggered
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
   int sizeOfPendingOrders = ArraySize(pendingOrders);
   int sizeOfOpenPositions = ArraySize(openPositions);
   int sizeOfHedgedLong    = ArraySize(hedgedLong);
   int sizeOfHedgedShort   = ArraySize(hedgedShort);
   SortTicketsChronological(hedgedLong);
   SortTicketsChronological(hedgedShort);

   // close orders
   int oe[], oes[][ORDER_EXECUTION_intSize], oeFlags=NULL;

   if (sizeOfPendingOrders || sizeOfOpenPositions) {
      string sPendingOrders = ifString(sizeOfPendingOrders, "delete "+ sizeOfPendingOrders +" pending order"+ Pluralize(sizeOfPendingOrders), "");
      string sAnd           = ifString(sizeOfPendingOrders && sizeOfOpenPositions, " and ", "");
      string sOpenPositions = ifString(sizeOfOpenPositions, "close "+ sizeOfOpenPositions +" open position"+ Pluralize(sizeOfOpenPositions), "");
      string msg            = "Do you really want to "+ sPendingOrders + sAnd + sOpenPositions +"?";

      PlaySoundEx("Windows Notify.wav");
      int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, ProgramName(), MB_ICONQUESTION|MB_OKCANCEL);

      if (button == IDOK) {
         if (sizeOfOpenPositions > 0) {
            if (!OrdersClose(openPositions, 1, CLR_NONE, oeFlags, oes))  return(SetLastError(oes.Error(oes)));
         }
         for (i=0; i < sizeOfPendingOrders; i++) {
            if (!OrderDeleteEx(pendingOrders[i], CLR_NONE, oeFlags, oe)) return(SetLastError(oe.Error(oe)));
         }
      }
   }
   else if (sizeOfHedgedLong && sizeOfHedgedShort) {
      msg = "Do you really want to close the hedged part of "+ (sizeOfHedgedLong+sizeOfHedgedShort) +" positions?";

      PlaySoundEx("Windows Notify.wav");
      button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, ProgramName(), MB_ICONQUESTION|MB_OKCANCEL);

      if (button == IDOK) {
         while (sizeOfHedgedLong && sizeOfHedgedShort) {
            int longTicket  = ArrayShiftInt(hedgedLong);
            int shortTicket = ArrayShiftInt(hedgedShort);
            sizeOfHedgedLong--;
            sizeOfHedgedShort--;

            if (!OrderCloseByEx(longTicket, shortTicket, CLR_NONE, oeFlags, oe)) return(SetLastError(oe.Error(oe)));

            int remainder = oe.RemainingTicket(oe);
            if (remainder != 0) {
               if (!SelectTicket(remainder, "onStart(1)")) return(last_error);
               if (OrderType() == OP_LONG) {
                  ArrayUnshiftInt(hedgedLong, remainder);
                  sizeOfHedgedLong++;
               }
               else {
                  ArrayUnshiftInt(hedgedShort, remainder);
                  sizeOfHedgedShort++;
               }
            }
         }
      }
   }
   else {
      PlaySoundEx("Plonk.wav");
      MessageBox("No matching orders found.", ProgramName(), MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}

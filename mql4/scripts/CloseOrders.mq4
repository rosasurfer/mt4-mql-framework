/**
 * Close all orders matching the specified input.
 */
#include <stddefines.mqh>
int   __InitFlags[] = { INIT_NO_BARS_REQUIRED };
int __DeinitFlags[];

#property show_inputs

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Close.Symbols      = "(current)";    // symbols separated by comma (default: the current symbol, "*" for all symbols)
extern string Close.OrderTypes   = "";             // order types separated by comma (Buy, Sell, BuyLimit, SellLimit, StopBuy, StopSell)
extern string Close.Tickets      = "";             // tickets separated by comma (w/wo the leeding "#") or a logmessage as generated by AnalyzePositions(F_LOG_TICKETS)
extern string Close.MagicNumbers = "";             // magic numbers separated by comma
extern string Close.Comments     = "";             // order comment prefixes separated by comma

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

string closeSymbols [];
int    closeTypes   [];
int    closeTickets [];
int    closeMagics  [];
string closeComments[];

bool closeAllSymbols = false;


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
   size = Explode(Close.OrderTypes, ",", sValues, NULL);
   for (i=0; i < size; i++) {
      sValue = StrTrim(sValues[i]);
      if (StringLen(sValue) > 0) {
         int type = StrToOperationType(sValue);
         if (type < OP_BUY || type > OP_SELLSTOP) return(catch("onInit(1)  invalid input parameter Close.OrderTypes: "+ DoubleQuoteStr(Close.OrderTypes), ERR_INVALID_INPUT_PARAMETER));
         ArrayPushInt(closeTypes, type);
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

   return(catch("onInit(6)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   int orders = OrdersTotal(), pendingOrders[], openPositions[];

   debug("onStart(0.1)  symbols="+ StringsToStr(closeSymbols, NULL));

   // select orders to close
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) break;
      if (OrderType() > OP_SELLSTOP)                   continue;

      bool close = true;
      if (close) close = (closeAllSymbols          || StringInArrayI(closeSymbols, OrderSymbol()));
      if (close) close = (!ArraySize(closeTypes)   ||     IntInArray(closeTypes,   OrderType()));
      if (close) close = (!ArraySize(closeTickets) ||     IntInArray(closeTickets, OrderTicket()));
      if (close) close = (!ArraySize(closeMagics)  ||     IntInArray(closeMagics,  OrderMagicNumber()));

      if (close) {
         int sizeOfComments = ArraySize(closeComments);
         for (int n=0; n < sizeOfComments; n++) {
            if (StrStartsWithI(OrderComment(), closeComments[n])) break;
         }
         if (sizeOfComments != 0) close = (n < sizeOfComments);         // order matches if break was triggered
      }

      if (close) {
         if (IsPendingOrderType(OrderType())) {
            if (!IntInArray(pendingOrders, OrderTicket())) ArrayPushInt(pendingOrders, OrderTicket());
         }
         else {
            if (!IntInArray(openPositions, OrderTicket())) ArrayPushInt(openPositions, OrderTicket());
         }
      }
   }

   // close orders
   int sizeOfPendingOrders = ArraySize(pendingOrders);
   int sizeOfOpenPositions = ArraySize(openPositions);
   PlaySoundEx("Windows Notify.wav");

   if (sizeOfPendingOrders || sizeOfOpenPositions) {
      string sPendingOrders = ifString(sizeOfPendingOrders, "delete "+ sizeOfPendingOrders +" pending order"+ Pluralize(sizeOfPendingOrders), "");
      string sAnd           = ifString(sizeOfPendingOrders && sizeOfOpenPositions, " and ", "");
      string sOpenPositions = ifString(sizeOfOpenPositions, "close "+ sizeOfOpenPositions +" open position"+ Pluralize(sizeOfOpenPositions), "");
      string msg            = "Do you really want to "+ sPendingOrders + sAnd + sOpenPositions +"?";

      int button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n") + msg, ProgramName(), MB_ICONQUESTION|MB_OKCANCEL);
      if (button == IDOK) {
         int oe[], oes[][ORDER_EXECUTION_intSize], oeFlags=NULL;

         if (sizeOfOpenPositions > 0) {
            if (!OrdersClose(openPositions, 1, CLR_NONE, oeFlags, oes))  return(ERR_RUNTIME_ERROR);
         }
         for (i=0; i < sizeOfPendingOrders; i++) {
            if (!OrderDeleteEx(pendingOrders[i], CLR_NONE, oeFlags, oe)) return(ERR_RUNTIME_ERROR);
         }
      }
   }
   else {
      MessageBox("No matching orders found.", ProgramName(), MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(1)"));
}

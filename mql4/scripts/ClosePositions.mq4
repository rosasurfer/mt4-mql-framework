/**
 * Schließt die angegebenen Positionen. Ohne zusätzliche Parameter werden alle offenen Positionen geschlossen.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Close.Symbols      = "";    // Symbole:                      kommagetrennt
extern string Close.Direction    = "";    // (B)uy|(L)ong|(S)ell|(S)hort
extern string Close.Tickets      = "";    // Tickets:                      kommagetrennt
extern string Close.MagicNumbers = "";    // MagicNumbers:                 kommagetrennt
extern string Close.Comments     = "";    // Kommentare:                   kommagetrennt, Prüfung per OrderComment().StringIStartsWith(value)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string orderSymbols [];
int    orderType = OP_UNDEFINED;
int    orderTickets [];
int    orderMagics  [];
string orderComments[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Parametervalidierung
   // Close.Symbols
   string values[], sValue;
   int size = Explode(StringToUpper(Close.Symbols), ",", values, NULL);
   for (int i=0; i < size; i++) {
      sValue = StringTrim(values[i]);
      if (StringLen(sValue) > 0)
         ArrayPushString(orderSymbols, sValue);
   }

   // Close.Direction
   string direction = StringToUpper(StringTrim(Close.Direction));
   if (StringLen(direction) > 0) {
      switch (StringGetChar(direction, 0)) {
         case 'B':
         case 'L': orderType = OP_BUY;  Close.Direction = "long";  break;
         case 'S': orderType = OP_SELL; Close.Direction = "short"; break;
         default:
            return(catch("onInit(1)   Invalid input parameter Close.Direction = \""+ Close.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      }
   }

   // Close.Tickets
   size = Explode(Close.Tickets, ",", values, NULL);
   for (i=0; i < size; i++) {
      sValue = StringTrim(values[i]);
      if (StringLen(sValue) > 0) {
         if (!StringIsDigit(sValue))
            return(catch("onInit(2)   Invalid input parameter Close.Tickets = \""+ Close.Tickets +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         int iValue = StrToInteger(sValue);
         if (iValue <= 0)
            return(catch("onInit(3)   Invalid input parameter Close.Tickets = \""+ Close.Tickets +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         ArrayPushInt(orderTickets, iValue);
      }
   }

   // Close.MagicNumbers
   size = Explode(Close.MagicNumbers, ",", values, NULL);
   for (i=0; i < size; i++) {
      sValue = StringTrim(values[i]);
      if (StringLen(sValue) > 0) {
         if (!StringIsDigit(sValue))
            return(catch("onInit(4)   Invalid input parameter Close.MagicNumbers = \""+ Close.MagicNumbers +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         iValue = StrToInteger(sValue);
         if (iValue <= 0)
            return(catch("onInit(5)   Invalid input parameter Close.MagicNumbers = \""+ Close.MagicNumbers +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         ArrayPushInt(orderMagics, iValue);
      }
   }

   // Close.Comments
   size = Explode(Close.Comments, ",", values, NULL);
   for (i=0; i < size; i++) {
      sValue = StringTrim(values[i]);
      if (StringLen(sValue) > 0)
         ArrayPushString(orderComments, sValue);
   }

   return(catch("onInit(6)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int orders = OrdersTotal();
   int tickets[]; ArrayResize(tickets, 0);


   // zu schließende Positionen selektieren
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine Order geschlossen oder gestrichen
         break;
      if (OrderType() > OP_SELL)                                     // Nicht-Positionen überspringen
         continue;

      bool close = true;
      if (close) close = (ArraySize(orderSymbols)== 0            || StringInArray(orderSymbols, OrderSymbol()));
      if (close) close = (orderType              == OP_UNDEFINED || OrderType() == orderType);
      if (close) close = (ArraySize(orderTickets)== 0            || IntInArray(orderTickets, OrderTicket()));
      if (close) close = (ArraySize(orderMagics) == 0            || IntInArray(orderMagics, OrderMagicNumber()));
      if (close) {
         int commentsSize = ArraySize(orderComments);
         for (int n=0; n < commentsSize; n++) {
            if (StringIStartsWith(OrderComment(), orderComments[n]))
               break;
         }
         if (commentsSize != 0)                                      // Comments angegeben
            close = (n < commentsSize);                              // Order paßt, wenn break getriggert
      }
      if (close) /*&&*/ if (!IntInArray(tickets, OrderTicket()))
         ArrayPushInt(tickets, OrderTicket());
   }
   bool isInput = (ArraySize(orderSymbols) + ArraySize(orderTickets) + ArraySize(orderMagics) + ArraySize(orderComments) + (orderType!=OP_UNDEFINED)) != 0;


   // Positionen schließen
   int selected = ArraySize(tickets);
   if (selected > 0) {
      PlaySound("notify.wav");
      int button = MessageBox(ifString(!IsDemo(), "- Real Money Account -\n\n", "") +"Do you really want to close "+ ifString(isInput, "the specified "+ selected, "all "+ selected +" open") +" position"+ ifString(selected==1, "", "s") +"?", __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button == IDOK) {
         int oeFlags = NULL;
         /*ORDER_EXECUTION*/int oes[][ORDER_EXECUTION.intSize]; ArrayResize(oes, selected); InitializeByteBuffer(oes, ORDER_EXECUTION.size);
         if (!OrderMultiClose(tickets, 0.1, Orange, oeFlags, oes))
            return(SetLastError(stdlib.GetLastError()));
         ArrayResize(oes, 0);
      }
   }
   else {
      PlaySound("notify.wav");
      MessageBox("No "+ ifString(isInput, "matching", "open") +" positions found.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
   }

   return(last_error);
}

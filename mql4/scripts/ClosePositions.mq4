/**
 * Schließt die angegebenen Positionen. Ohne zusätzliche Parameter werden alle offenen Positionen geschlossen.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Close.Symbols      = "";    // <leer> | Symbols                    (kommagetrennt)
extern string Close.Direction    = "";    // <leer> | buy | long | sell | short
extern string Close.Tickets      = "";    // <leer> | Tickets                    (kommagetrennt)
extern string Close.MagicNumbers = "";    // <leer> | MagicNumbers               (kommagetrennt)
extern string Close.Comment      = "";    // <leer> | Kommentar                  (Prüfung per OrderComment().StringIStartsWith(value))

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

string orderSymbols[], orderComment;
int    orderTickets[], orderMagics[], orderType=OP_UNDEFINED;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) + 0.1;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");

   // Parametervalidierung
   // Close.Symbols
   string values[];
   int size = Explode(StringToUpper(Close.Symbols), ",", values, NULL);
   for (int i=0; i < size; i++) {
      string strValue = StringTrim(values[i]);
      if (StringLen(strValue) > 0)
         ArrayPushString(orderSymbols, strValue);
   }

   // Close.Direction
   string direction = StringToUpper(StringTrim(Close.Direction));
   if (StringLen(direction) > 0) {
      switch (StringGetChar(direction, 0)) {
         case 'B':
         case 'L': orderType = OP_BUY;  Close.Direction = "long";  break;
         case 'S': orderType = OP_SELL; Close.Direction = "short"; break;
         default:
            return(catch("init(1)  Invalid input parameter Close.Direction = \""+ Close.Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      }
   }

   // Close.Tickets
   size = Explode(Close.Tickets, ",", values, NULL);
   for (i=0; i < size; i++) {
      strValue = StringTrim(values[i]);
      if (StringLen(strValue) > 0) {
         if (!StringIsDigit(strValue))
            return(catch("init(2)  Invalid input parameter Close.Tickets = \""+ Close.Tickets +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         int iValue = StrToInteger(strValue);
         if (iValue <= 0)
            return(catch("init(3)  Invalid input parameter Close.Tickets = \""+ Close.Tickets +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         ArrayPushInt(orderTickets, iValue);
      }
   }

   // Close.MagicNumbers
   size = Explode(Close.MagicNumbers, ",", values, NULL);
   for (i=0; i < size; i++) {
      strValue = StringTrim(values[i]);
      if (StringLen(strValue) > 0) {
         if (!StringIsDigit(strValue))
            return(catch("init(4)  Invalid input parameter Close.MagicNumbers = \""+ Close.MagicNumbers +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         iValue = StrToInteger(strValue);
         if (iValue <= 0)
            return(catch("init(5)  Invalid input parameter Close.MagicNumbers = \""+ Close.MagicNumbers +"\"", ERR_INVALID_INPUT_PARAMVALUE));
         ArrayPushInt(orderMagics, iValue);
      }
   }

   // Close.Comment
   orderComment = StringTrim(Close.Comment);

   return(catch("init(6)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);
   // ------------------------


   int orders = OrdersTotal();
   int tickets[]; ArrayResize(tickets, 0);


   // zu schließende Positionen selektieren
   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))      // FALSE: während des Auslesens wird in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;

      bool close = true;
      if (close) close = (ArraySize(orderSymbols)== 0 || StringInArray(OrderSymbol(),   orderSymbols));
      if (close) close = (orderType              ==-1 || OrderType() == orderType                    );
      if (close) close = (ArraySize(orderTickets)== 0 || IntInArray(OrderTicket(),      orderTickets));
      if (close) close = (ArraySize(orderMagics) == 0 || IntInArray(OrderMagicNumber(), orderMagics ));

      if (close) /*&&*/ if (orderComment!="") /*&&*/ if (!StringIStartsWith(OrderComment(), orderComment))  // Workaround um MQL-Conditions-Bug
         close = false;

      if (close)
         ArrayPushInt(tickets, OrderTicket());
   }


   bool filtered = !(ArraySize(orderSymbols)+orderType+ArraySize(orderTickets)+ArraySize(orderMagics)==-1 && orderComment=="");


   // Positionen schließen
   int selected = ArraySize(tickets);
   if (selected > 0) {
      PlaySound("notify.wav");
      int button = MessageBox("Do you really want to close "+ ifString(filtered, "the specified "+ ArraySize(tickets), "all "+ ArraySize(tickets) +" open") +" positions?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button == IDOK) {
         if (!OrderCloseMultiple(tickets, 0.1, Orange))
            return(processLibError(stdlib_PeekLastError()));
         SendTick(false);
      }
   }
   else {
      PlaySound("notify.wav");
      MessageBox("No "+ ifString(filtered, "matching", "open") +" positions found.", __SCRIPT__, MB_ICONEXCLAMATION|MB_OK);
   }

   return(catch("start()"));
}

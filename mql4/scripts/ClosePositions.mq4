/**
 * Schließt die angegebenen Positionen. Ohne zusätzliche Parameter werden alle offenen Positionen geschlossen.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Close.Symbols      = "";    // <leer> | Symbols                    (kommagetrennt)
extern string Close.Direction    = "";    // <leer> | Buy | Long | Sell | Short
extern string Close.Tickets      = "";    // <leer> | Tickets                    (kommagetrennt)
extern string Close.MagicNumbers = "";    // <leer> | MagicNumbers               (kommagetrennt)
extern string Close.Comment      = "";    // <leer> | Kommentar                  (Prüfung per OrderComment().StringIStartsWith(value))

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

string orderSymbols[], orderComment;
int    orderTickets[], orderMagics[], orderType=-1;


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
         case 'L': orderType = OP_BUY;  break;
         case 'S': orderType = OP_SELL; break;
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


   bool filtered = !(ArraySize(orderSymbols) + orderType + ArraySize(orderTickets) + ArraySize(orderMagics)==-1 && orderComment=="");


   // Positionen schließen
   int selected = ArraySize(tickets);
   if (selected > 0) {
      PlaySound("notify.wav");
      int button = MessageBox("Do you really want to close "+ ifString(filtered, "the specified", "all open") +" positions?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (button == IDOK) {
         if (!OrderCloseMultiple(tickets, 1, Orange))
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


/**
 * Schließt mehrere offene Positionen auf die effektivste Art und Weise. Mehrere offene Positionen im selben Instrument werden mit einer einzigen Order per Hedge
 * geschlossen, Brokerbetrug durch Berechnung doppelter Spreads wird verhindert.
 *
 * @param  int    tickets[]   - Ticket-Nr. der zu schließenden Positionen
 * @param  double slippage    - akzeptable Slippage in Pip (default: 0          )
 * @param  color  markerColor - Farbe des Chart-Markers    (default: kein Marker)
 *
 * @return bool - Erfolgsstatus: FALSE, wenn mindestens eines der Tickets nicht geschlossen werden konnte
 */
bool OrderCloseMultiple(int tickets[], double slippage=0, color markerColor=CLR_NONE) {
   debug("OrderCloseMultiple()   tickets = "+ IntArrayToStr(tickets, NULL));

   // (1) Beginn Parametervalidierung --
   // tickets
   int sizeOfTickets = ArraySize(tickets);
   if (sizeOfTickets == 0) return(catch("OrderCloseMultiple(1)   invalid size of parameter tickets = "+ IntArrayToStr(tickets, NULL), ERR_INVALID_FUNCTION_PARAMVALUE)==NO_ERROR);

   for (int i=0; i < sizeOfTickets; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) {
         int error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("OrderCloseMultiple(2)   invalid ticket #"+ tickets[i] +" in parameter tickets = "+ IntArrayToStr(tickets, NULL), error)==NO_ERROR);
      }
      if (OrderCloseTime() != 0)                                return(catch("OrderCloseMultiple(3)   ticket #"+ tickets[i] +" is already closed", ERR_INVALID_TICKET)==NO_ERROR);
      if (OrderType()!=OP_BUY) /*&&*/ if (OrderType()!=OP_SELL) return(catch("OrderCloseMultiple(4)   ticket #"+ tickets[i] +" is not an open position", ERR_INVALID_TICKET)==NO_ERROR);
   }
   // slippage
   if (LT(slippage, 0))                                         return(catch("OrderCloseMultiple(5)   illegal parameter slippage = "+ NumberToStr(slippage, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)==NO_ERROR);
   // markerColor
   if (markerColor < CLR_NONE || markerColor > C'255,255,255')  return(catch("OrderCloseMultiple(6)   illegal parameter markerColor = "+ markerColor, ERR_INVALID_FUNCTION_PARAMVALUE)==NO_ERROR);
   // -- Ende Parametervalidierung --


   // (2) schnelles Close, wenn nur ein einziges Ticket angegeben wurde
   if (sizeOfTickets == 1)
      return(OrderCloseEx(tickets[0], NULL, NULL, slippage, markerColor));


   // Das Array tickets[] wird in der Folge modifiziert. Um Änderungen am übergebenen Ausgangsarray zu verhindern, müssen wir auf einer Kopie arbeiten.
   int ticketsCopy[]; ArrayResize(ticketsCopy, 0);
   ArrayCopy(ticketsCopy, tickets);


   // (3) Zuordnung der Tickets zu Symbolen ermitteln
   string symbols      []; ArrayResize(symbols, 0);
   int    ticketSymbols[]; ArrayResize(ticketSymbols, sizeOfTickets);

   for (i=0; i < sizeOfTickets; i++) {
      if (!OrderSelect(ticketsCopy[i], SELECT_BY_TICKET)) {
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("OrderCloseMultiple(7)", error)==NO_ERROR);
      }
      int symbolIndex = ArraySearchString(OrderSymbol(), symbols);
      if (symbolIndex == -1)
         symbolIndex = ArrayPushString(symbols, OrderSymbol())-1;
      ticketSymbols[i] = symbolIndex;
   }


   // (4) Gehören die Tickets zu mehreren Symbolen, Tickets jeweils eines Symbols auslesen und per Symbol schließen.
   int sizeOfSymbols = ArraySize(symbols);

   if (sizeOfSymbols > 1) {
      int hedgedSymbolIndices[]; ArrayResize(hedgedSymbolIndices, 0);

      for (symbolIndex=0; symbolIndex < sizeOfSymbols; symbolIndex++) {
         int perSymbolTickets[]; ArrayResize(perSymbolTickets, 0);
         for (i=0; i < sizeOfTickets; i++) {
            if (symbolIndex == ticketSymbols[i])
               ArrayPushInt(perSymbolTickets, ticketsCopy[i]);
         }
         int sizeOfPerSymbolTickets = ArraySize(perSymbolTickets);
         if (sizeOfPerSymbolTickets == 1) {
            // nur eine Position des Symbols => kann sofort komplett geschlossen werden
            if (!OrderCloseEx(perSymbolTickets[0], NULL, NULL, slippage, markerColor))
               return(false);
         }
         else {
            // Da wir hier Tickets mehrerer Symbole auf einmal schließen und mehrere Positionen je Symbol haben, muß zunächst
            // per Hedge die Gesamtposition ausgeglichen und die Teilpositionen erst zum Schluß geschlossen werden.
            double totalLots;
            for (int n=0; n < sizeOfPerSymbolTickets; n++) {
               if (!OrderSelect(perSymbolTickets[n], SELECT_BY_TICKET)) {
                  error = GetLastError();
                  if (error == NO_ERROR)
                     error = ERR_INVALID_TICKET;
                  return(catch("OrderCloseMultiple(8)", error)==NO_ERROR);
               }
               if (OrderType() == OP_BUY) totalLots += OrderLots();           // Gesamtposition berechnen
               else                       totalLots -= OrderLots();
            }
            if (NE(totalLots, 0)) {                                           // Gesamtposition hedgen
               int type = ifInt(LT(totalLots, 0), OP_BUY, OP_SELL);

               log(StringConcatenate("OrderCloseMultiple()   opening ", OperationTypeDescription(type), " hedge for multiple positions in ", OrderSymbol()));

               int hedge = OrderSendEx(OrderSymbol(), type, MathAbs(totalLots), NULL, slippage, NULL, NULL, NULL, NULL, NULL, CLR_NONE);
               if (hedge == -1)
                  return(false);
               // Hedge-Position zu den zu schließenden Tickets dieses Symbols hinzufügen
               sizeOfTickets = ArrayPushInt(ticketsCopy,   hedge      );
                               ArrayPushInt(ticketSymbols, symbolIndex);
            }
            // Gesamtposition ist gehedged => Hedge-Symbol zum späteren Schließen vormerken
            ArrayPushInt(hedgedSymbolIndices, symbolIndex);
         }
      }

      // jetzt die gehedgten Symbole per rekursivem Aufruf komplett schließen

      debug("OrderCloseMultiple()   symbols             = "+ StringArrayToStr(symbols, NULL));
      debug("OrderCloseMultiple()   hedgedSymbolIndices = "+ IntArrayToStr(hedgedSymbolIndices, NULL));

      int hedges = ArraySize(hedgedSymbolIndices);
      for (i=0; i < hedges; i++) {
         symbolIndex = hedgedSymbolIndices[i];
         ArrayResize(perSymbolTickets, 0);
         for (n=0; n < sizeOfTickets; n++) {
            if (ticketSymbols[n] == symbolIndex)
               ArrayPushInt(perSymbolTickets, ticketsCopy[n]);
         }

         debug("calling  OrderCloseMultiple()           symbols = "+ StringArrayToStr(symbols, NULL) +" for "+ symbols[symbolIndex] +" tickets to close = "+ IntArrayToStr(perSymbolTickets, NULL));

         if (!OrderCloseMultiple(perSymbolTickets, slippage, markerColor))
            return(false);

         debug("call to  OrderCloseMultiple() returned, symbols = "+ StringArrayToStr(symbols, NULL));
      }
      return(catch("OrderCloseMultiple(9)")==NO_ERROR);
   }


   // (5) mehrere Tickets, die alle zu einem Symbol gehören
   totalLots = 0;
   for (i=0; i < sizeOfTickets; i++) {                                  // Gesamtposition berechnen
      if (!OrderSelect(ticketsCopy[i], SELECT_BY_TICKET)) {
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("OrderCloseMultiple(10)", error)==NO_ERROR);
      }
      if (OrderType() == OP_BUY) totalLots += OrderLots();
      else                       totalLots -= OrderLots();
   }
   if (NE(totalLots, 0)) {                                              // Gesamtposition ausgleichen
      type = ifInt(LT(totalLots, 0), OP_BUY, OP_SELL);

      log(StringConcatenate("OrderCloseMultiple()   opening ", OperationTypeDescription(type), " hedge for multiple ", symbols[0] ," positions"));

      hedge = OrderSendEx(OrderSymbol(), type, MathAbs(totalLots), NULL, slippage, NULL, NULL, NULL, NULL, NULL, CLR_NONE);
      if (hedge == -1)
         return(false);
      sizeOfTickets = ArrayPushInt(ticketsCopy, hedge);                 // Hedge den zu schließenden Tickets hinzufügen
   }


   // (6) alle Teilpositionen nacheinander auflösen
   log(StringConcatenate("OrderCloseMultiple()   closing multiple ", symbols[0], " positions ", IntArrayToStr(ticketsCopy, NULL)));
   while (sizeOfTickets > 0) {
      ChronologicalSortTickets(ticketsCopy);

      int first = ticketsCopy[0];
      hedge     = 0;
      if (!OrderSelect(first, SELECT_BY_TICKET)) {
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("OrderCloseMultiple(11)", error)==NO_ERROR);
      }
      int firstType = OrderType();

      for (i=1; i < sizeOfTickets; i++) {
         if (!OrderSelect(ticketsCopy[i], SELECT_BY_TICKET)) {
            error = GetLastError();
            if (error == NO_ERROR)
               error = ERR_INVALID_TICKET;
            return(catch("OrderCloseMultiple(12)", error)==NO_ERROR);
         }
         if (OrderType() == firstType ^ 1) {
            hedge = ticketsCopy[i];                                     // hedgende Position ermitteln
            break;
         }
      }
      if (hedge == 0) return(catch("OrderCloseMultiple(13)   cannot find hedging position for "+ OperationTypeDescription(firstType) +" ticket #"+ first, ERR_RUNTIME_ERROR)==NO_ERROR);

      int remainder[];
      if (!OrderCloseByEx(first, hedge, remainder, markerColor))        // erste und hedgende Position schließen
         return(false);

      if (i+1 < sizeOfTickets)                                          // hedgendes[i] Ticket löschen
         ArrayCopy(ticketsCopy, ticketsCopy, i, i+1);
      sizeOfTickets--;
      ArrayResize(ticketsCopy, sizeOfTickets);

      ArrayShiftInt(ticketsCopy);                                       // erstes[0] Ticket löschen
      sizeOfTickets--;

      if (ArraySize(remainder) != 0)                                    // Restposition zu verbleibenden Teilpositionen hinzufügen
         sizeOfTickets = ArrayPushInt(ticketsCopy, remainder[0]);
   }

   return(catch("OrderCloseMultiple(14)")==NO_ERROR);
}

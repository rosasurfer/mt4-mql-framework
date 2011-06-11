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


double   Pip;
int      PipDigits;
string   PriceFormat;

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

   PipDigits   = Digits - Digits%2;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");


   // Parameter auswerten

   // Close.Symbols
   string values[];
   int size = Explode(StringToUpper(Close.Symbols), ",", values);
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
   size = Explode(Close.Tickets, ",", values);
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
   size = Explode(Close.MagicNumbers, ",", values);
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
   // -----------------------------------------------------------------------------


   int orders = OrdersTotal();
   int tickets[];
   ArrayResize(tickets, 0);

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
      int answer = MessageBox("Do you really want to close "+ ifString(filtered, "the specified", "all open") +" positions?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
      if (answer == IDOK) {
         for (i=0; i < selected; i++) {
            if (!OrderCloseEx(tickets[i]))
               break;
         }
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
 * Erweiterte OrderClose()-Funktion.  Schließt eine offene Position und fängt dabei auftretende temporäre Tradeserver-Fehler ab.
 *
 * @param  int    ticket   - Ticket-Nr. der zu schließenden Position
 * @param  double volume   - zu schließendes Volumen in Lots (default: -1 = komplette Position)
 * @param  int    slippage - akzeptable Slippage in Points   (default: 1                      )
 * @param  color  marker   - Farbe des Chart-Markers         (default: kein Marker            )
 *
 * @return bool - Erfolgsstatus
 */
bool OrderCloseEx(int ticket, double volume=-1, int slippage=1, color marker=CLR_NONE) {
   // -- Beginn Parametervalidierung --
   // ticket
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      catch("OrderCloseEx(1)   invalid parameter ticket = "+ ticket, error);
      return(false);
   }
   if (OrderCloseTime() != 0) {
      catch("OrderCloseEx(2)   ticket #"+ ticket +" is already closed", ERR_TRADE_ERROR);
      return(false);
   }
   // volume
   int    digits  = MarketInfo(OrderSymbol(), MODE_DIGITS);
   double minLot  = MarketInfo(OrderSymbol(), MODE_MINLOT);
   double lotStep = MarketInfo(OrderSymbol(), MODE_LOTSTEP);
   error = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderCloseEx(3)   symbol=\""+ OrderSymbol() +"\"", error);
      return(false);
   }
   if (EQ(volume, -1)) {
      volume = OrderLots();
   }
   else if (NE(volume, OrderLots())) {
      if (NormalizeDouble(volume-minLot, 8) < 0) {
         catch("OrderCloseEx(4)   illegal parameter volume = "+ NumberToStr(volume, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
      if (NormalizeDouble(volume-OrderLots(), 8) > 0) {
         catch("OrderCloseEx(5)   illegal parameter volume = "+ NumberToStr(volume, ".+") +" (OpenLots="+ NumberToStr(OrderLots(), ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
      if (NE(MathModFix(volume, lotStep), 0)) {
         catch("OrderCloseEx(6)   illegal parameter volume = "+ NumberToStr(volume, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
   }
   volume = NormalizeDouble(volume, CountDecimals(lotStep));
   // slippage
   if (slippage < 0) {
      catch("OrderCloseEx(7)   illegal parameter slippage = "+ slippage, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(false);
   }
   // TODO: marker - Farbe des Chartmarkers
   // -- Ende Parametervalidierung --


   // Endlosschleife, bis Position geschlossen wurde oder ein permanenter Fehler auftritt
   while (!IsStopped()) {
      if (IsTradeContextBusy()) {
         log("OrderSendEx()   trade context busy, waiting...");
      }
      else {
         double price = NormalizeDouble(MarketInfo(OrderSymbol(), ifInt(OrderType()==OP_BUY, MODE_BID, MODE_ASK)), digits);
         int time     = GetTickCount();
         if (OrderClose(ticket, volume, price, slippage)) {
            time = GetTickCount()-time;

            // akustische Rückmeldung und ausführliche Logmessage
            PlaySound("OrderOk.wav");
            log("OrderCloseEx()   closed "+ OrderCloseEx.LogMessage(ticket, volume, price, digits, time));

            error = GetLastError();
            if (error != NO_ERROR) {
               catch("OrderCloseEx(8)", error);
               return(false);
            }
            return(true);                    // regular exit
         }
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         if (!IsTemporaryTradeError(error))  // TODO: ERR_MARKET_CLOSED abfangen und besser behandeln
            break;
         Alert("OrderCloseEx()   temporary trade error "+ ErrorToStr(error) +", retrying...");    // Alert() nach Fertigstellung durch log() ersetzen
      }
      error = NO_ERROR;
      Sleep(300);                            // 0.3 Sekunden warten
   }

   catch("OrderCloseEx(9)   permanent trade error", error);
   return(false);
}


/**
 *
 */
string OrderCloseEx.LogMessage(int ticket, double volume, double price, int digits, int time) {
   int pipDigits = digits - digits%2;

   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      catch("OrderCloseEx.LogMessage(1)   error selecting ticket #"+ ticket, error);
      return("");
   }

   string strType   = OperationTypeDescription(OrderType());
   string strVolume = NumberToStr(OrderLots(), ".+");

   string strPrice = DoubleToStr(OrderClosePrice(), digits);
   if (NE(price, OrderClosePrice())) {
      string strSlippage = NumberToStr(MathAbs(OrderClosePrice()-price)/Pip, ".+");
      bool plus = (OrderClosePrice() > price);
      if ((OrderType()==OP_BUY && !plus) || (OrderType()==OP_SELL && plus)) strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip slippage)");
      else                                                                  strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip positive slippage)");
   }

   string message = StringConcatenate("#", ticket, " ", strType, " ", strVolume, " ", OrderSymbol(), " at ", strPrice, ", used time: ", time, " ms");

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderCloseEx.LogMessage(2)", error);
      return("");
   }
   return(message);
}

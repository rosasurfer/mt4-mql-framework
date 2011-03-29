/**
 * Schlieﬂt die angegebenen Positionen. Ohne zus‰tzliche Parameter werden alle offenen Positionen geschlossen.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern int    Close.Ticket      = 0;

extern string Close.Symbol      = "";     // <leer> | Symbol
extern string Close.Direction   = "";     // <leer> | Long | Short
extern string Close.MagicNumber = "";     // <leer> | MagicNumber
extern string Close.Comment     = "";     // <leer> | Kommentar, Pr¸fung per StringStartsWith(OrderComment(), Close.Comment)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);
   return(catch("init()"));
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

   int result = OrderCloseEx(Close.Ticket);

   return(catch("start()"));

   /*
   PlaySound("notify.wav");
   int answer = MessageBox("Do you really want to close the specified positions?", WindowExpertName(), MB_ICONQUESTION|MB_OKCANCEL);
   if (answer == IDOK)
      SendTick(false);
   */
}


/**
 * Erweiterte OrderClose()-Funktion.  Schlieﬂt eine offene Position und f‰ngt dabei auftretende tempor‰re Tradeserver-Fehler ab.
 *
 * @param  int    ticket   - Ticket-Nr. der zu schlieﬂenden Position
 * @param  double volume   - zu schlieﬂendes Volumen in Lots (default: -1 = komplette Position)
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
   if (CompareDoubles(volume, -1)) {
      volume = OrderLots();
   }
   else if (!CompareDoubles(volume, OrderLots())) {
      if (NormalizeDouble(volume-minLot, 8) < 0) {
         catch("OrderCloseEx(4)   illegal parameter volume = "+ NumberToStr(volume, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
      if (NormalizeDouble(volume-OrderLots(), 8) > 0) {
         catch("OrderCloseEx(5)   illegal parameter volume = "+ NumberToStr(volume, ".+") +" (OpenLots="+ NumberToStr(OrderLots(), ".+") +")", ERR_INVALID_FUNCTION_PARAMVALUE);
         return(false);
      }
      if (!CompareDoubles(MathModFix(volume, lotStep), 0)) {
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

            // akustische R¸ckmeldung und ausf¸hrliche Logmessage
            PlaySound("PositionClosed.wav");
            log("OrderCloseEx()   closed "+ OrderCloseEx.CreateLogMessage(ticket, volume, price, digits, time));

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
string OrderCloseEx.CreateLogMessage(int ticket, double volume, double price, int digits, int time) {
   if (!OrderSelect(ticket, SELECT_BY_TICKET)) {
      int error = GetLastError();
      if (error == NO_ERROR)
         error = ERR_INVALID_TICKET;
      catch("OrderCloseEx.CreateLogMessage(1)   error selecting ticket #"+ ticket, error);
      return("");
   }

   string strType   = OperationTypeDescription(OrderType());
   string strVolume = NumberToStr(OrderLots(), ".+");

   string strPrice = DoubleToStr(OrderClosePrice(), digits);
   if (!CompareDoubles(price, OrderClosePrice())) {
      string strSlippage = NumberToStr(MathAbs(OrderClosePrice()-price) * MathPow(10, digits-digits%2), ".+");
      bool plus = (OrderClosePrice() > price);
      if ((OrderType()==OP_BUY && !plus) || (OrderType()==OP_SELL && plus)) strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip slippage)");
      else                                                                  strPrice = StringConcatenate(strPrice, " (", strSlippage, " pip positive slippage)");
   }

   string message = StringConcatenate("#", ticket, " ", strType, " ", strVolume, " ", OrderSymbol(), " at ", strPrice, ", used time: ", time, " ms");

   error = GetLastError();
   if (error != NO_ERROR) {
      catch("OrderSendEx.CreateLogMessage(2)", error);
      return("");
   }
   return(message);
}

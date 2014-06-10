/**
 * LFX.ExecuteTradeCmd
 *
 * Script, daß intern zur Ausführung von zwischen den Terminals verschickten TradeCommands benutzt wird. Ein manueller Aufruf ist nicht möglich.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>

#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>

#include <core/script.ParameterProvider.mqh>
#include <LFX/functions.mqh>
#include <LFX/quickchannel.mqh>

#include <structs/pewa/LFX_ORDER.mqh>


//////////////////////////////////////////////////////////////////////  Scriptparameter (Übergabe per QickChannel)  ///////////////////////////////////////////////////////////////////////

string command = "";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

int    lfxTicket;                         // geparste Details des übergebenen TradeCommands
string action;
double leverage;

bool   sms.alerts;
string sms.receiver;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Scriptparameter einlesen
   string names[], values[];
   int size = GetScriptParameters(names, values);
   if (size == -1) return(last_error);
   for (int i=0; i < size; i++) {
      if (names[i] == "command") {
         command = values[i];
         break;
      }
   }
   if (i >= size) return(catch("onInit(1)   missing script parameter (command)", ERR_INVALID_INPUT_PARAMVALUE));


   // (2) Scriptparameter validieren, Format: "LFX:{iTicket}:{Action}", z.B. "LFX:428371265:open"
   if (StringLeft(command, 4) != "LFX:")            return(catch("onInit(2)   invalid parameter command = \""+ command +"\" (prefix)", ERR_INVALID_INPUT_PARAMVALUE));
   int pos = StringFind(command, ":", 4);
   if (pos == -1)                                   return(catch("onInit(3)   invalid parameter command = \""+ command +"\" (action)", ERR_INVALID_INPUT_PARAMVALUE));
   string sValue = StringSubstrFix(command, 4, pos-4);
   if (!StringIsDigit(sValue))                      return(catch("onInit(4)   invalid parameter command = \""+ command +"\" (ticket)", ERR_INVALID_INPUT_PARAMVALUE));
   lfxTicket = StrToInteger(sValue);
   if (!lfxTicket)                                  return(catch("onInit(5)   invalid parameter command = \""+ command +"\" (ticket)", ERR_INVALID_INPUT_PARAMVALUE));
   action = StringToLower(StringSubstr(command, pos+1));
   if (action!="open" && action!="close")           return(catch("onInit(6)   invalid parameter command = \""+ command +"\" (action)", ERR_INVALID_INPUT_PARAMVALUE));


   // (3) ggf. Leverage-Konfiguration einlesen und validieren
   if (action == "open") {
      if (!IsGlobalConfigKey("Leverage", "Basket")) return(catch("onInit(7)   Missing global MetaTrader config value [Leverage]->Basket", ERR_INVALID_CONFIG_PARAMVALUE));
      sValue = GetGlobalConfigString("Leverage", "Basket", "");
      if (!StringIsNumeric(sValue))                 return(catch("onInit(8)   Invalid MetaTrader config value [Leverage]->Basket = \""+ sValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
      leverage = StrToDouble(sValue);
      if (leverage < 1)                             return(catch("onInit(9)   Invalid MetaTrader config value [Leverage]->Basket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));
   }


   // (4) SMS-Konfiguration einlesen
   sms.alerts = GetLocalConfigBool("EventTracker", "SMS.Alerts", false);
   if (sms.alerts) {
      sms.receiver = GetConfigString("SMS", "Receiver", "");
      if (!StringLen(sms.receiver))                 return(catch("onInit(10)   missing setting [SMS]->Receiver", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   return(catch("onInit(11)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   QC.StopChannels();
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // Order holen
   int result = LFX.GetOrder(lfxTicket, lfxOrder);
   if (result < 1) { if (!result) return(last_error); return(catch("onStart(1)   LFX order "+ lfxTicket +" not found (command = \""+ command +"\")", ERR_INVALID_INPUT_PARAMVALUE)); }


   // Action ausführen
   if (action == "open") {
      if (!OpenPendingOrder(lfxOrder)) return(last_error);
   }
   else if (action == "close") {
      if (!ClosePosition(lfxOrder))    return(last_error);
   }
   else {
      warn("onStart(2)   "+ action +" command not implemented");
   }
   return(last_error);
}


/**
 * Öffnet eine Pending-Order.
 *
 * @param  LFX_ORDER lo[] - die zu öffnende Order
 *
 * @return bool - Erfolgsstatus
 */
bool OpenPendingOrder(/*LFX_ORDER*/int lo[]) {
   if (!lo.IsPending(lo))
      return(!catch("OpenPendingOrder(1)   #"+ lo.Ticket(lo) +" cannot open "+ ifString(lo.IsOpen(lo), "an already open", "a closed") +" order", ERR_RUNTIME_ERROR));


   // (1) Trade-Parameter einlesen
   string lfxCurrency  = lo.Currency(lo);
   int    lfxDirection = IsShortTradeOperation(lo.Type(lo));
   double lfxUnits     = lo.Units(lo);


   // (2) zu handelnde Pairs bestimmen                                                 // TODO: Brokerspezifische Symbole ermitteln
   string symbols    [7];
   int    symbolsSize;
   double preciseLots[7], roundedLots[7], realUnits;
   int    directions [7];
   int    tickets    [7];
   if      (lfxCurrency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD";                        symbolsSize = 6; }
   else if (lfxCurrency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD";                        symbolsSize = 6; }
   else if (lfxCurrency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF";                        symbolsSize = 6; }
   else if (lfxCurrency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD";                        symbolsSize = 6; }
   else if (lfxCurrency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD";                        symbolsSize = 6; }
   else if (lfxCurrency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY";                        symbolsSize = 6; }
   else if (lfxCurrency == "NZD") { symbols[0] = "AUDNZD"; symbols[1] = "EURNZD"; symbols[2] = "GBPNZD"; symbols[3] = "NZDCAD"; symbols[4] = "NZDCHF"; symbols[5] = "NZDJPY"; symbols[6] = "NZDUSD"; symbolsSize = 7; }
   else if (lfxCurrency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY";                        symbolsSize = 6; }


   // (3) Lotsizes je Pair berechnen
   double equity = MathMin(AccountBalance(), AccountEquity()-AccountCredit());
   string errorMsg, overLeverageMsg;

   for (int retry, i=0; i < symbolsSize; i++) {
      // (3.1) notwendige Daten ermitteln
      double bid           = MarketInfo(symbols[i], MODE_BID      );
      double tickSize      = MarketInfo(symbols[i], MODE_TICKSIZE );
      double tickValue     = MarketInfo(symbols[i], MODE_TICKVALUE);
      double minLot        = MarketInfo(symbols[i], MODE_MINLOT   );
      double maxLot        = MarketInfo(symbols[i], MODE_MAXLOT   );
      double lotStep       = MarketInfo(symbols[i], MODE_LOTSTEP  );
      int    lotStepDigits = CountDecimals(lotStep);
      if (IsError(catch("OpenPendingOrder(2)   \""+ symbols[i] +"\"")))                // TODO: auf ERR_UNKNOWN_SYMBOL prüfen
         return(_false(lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo)));

      // (3.2) auf ungültige MarketInfo()-Daten prüfen
      errorMsg = "";
      if      (LT(bid, 0.5)          || GT(bid, 300)      ) errorMsg = "Bid(\""      + symbols[i] +"\") = "+ NumberToStr(bid      , ".+");
      else if (LT(tickSize, 0.00001) || GT(tickSize, 0.01)) errorMsg = "TickSize(\"" + symbols[i] +"\") = "+ NumberToStr(tickSize , ".+");
      else if (LT(tickValue, 0.5)    || GT(tickValue, 20) ) errorMsg = "TickValue(\""+ symbols[i] +"\") = "+ NumberToStr(tickValue, ".+");
      else if (LT(minLot, 0.01)      || GT(minLot, 0.1)   ) errorMsg = "MinLot(\""   + symbols[i] +"\") = "+ NumberToStr(minLot   , ".+");
      else if (LT(maxLot, 50)                             ) errorMsg = "MaxLot(\""   + symbols[i] +"\") = "+ NumberToStr(maxLot   , ".+");
      else if (LT(lotStep, 0.01)     || GT(lotStep, 0.1)  ) errorMsg = "LotStep(\""  + symbols[i] +"\") = "+ NumberToStr(lotStep  , ".+");

      // (3.3) ungültige MarketInfo()-Daten behandeln
      if (StringLen(errorMsg) > 0) {
         if (retry < 3) {                                                              // 3 stille Versuche, korrekte Werte zu lesen
            Sleep(200);                                                                // bei Mißerfolg jeweils xxx Millisekunden warten
            i = -1;
            retry++;
            continue;
         }
         return(_false(catch("OpenPendingOrder(3)   invalid MarketInfo() data: "+ errorMsg, ERR_INVALID_MARKET_DATA), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo)));
      }

      // (3.4) Lotsize berechnen (dabei immer abrunden)
      double lotValue = bid / tickSize * tickValue;                                    // Lotvalue eines Lots in Account-Currency
      double unitSize = equity / lotValue * leverage / symbolsSize;                    // equity/lotValue entspricht einem Hebel von 1, dieser Wert wird mit leverage gehebelt
      preciseLots[i] = lfxUnits * unitSize;                                            // perfectLots zunächst auf Vielfaches von MODE_LOTSTEP abrunden
      roundedLots[i] = NormalizeDouble(MathFloor(preciseLots[i]/lotStep) * lotStep, lotStepDigits);

      // Schrittweite mit zunehmender Lotsize über MODE_LOTSTEP hinaus erhöhen (entspricht Algorythmus in ChartInfos-Indikator)
      if      (roundedLots[i] <=    0.3 ) {                                                                                                       }   // Abstufung max. 6.7% je Schritt
      else if (roundedLots[i] <=    0.75) { if (lotStep <   0.02) roundedLots[i] = NormalizeDouble(MathFloor(roundedLots[i]/  0.02) *   0.02, 2); }   // 0.3-0.75: Vielfaches von   0.02
      else if (roundedLots[i] <=    1.2 ) { if (lotStep <   0.05) roundedLots[i] = NormalizeDouble(MathFloor(roundedLots[i]/  0.05) *   0.05, 2); }   // 0.75-1.2: Vielfaches von   0.05
      else if (roundedLots[i] <=    3.  ) { if (lotStep <   0.1 ) roundedLots[i] = NormalizeDouble(MathFloor(roundedLots[i]/  0.1 ) *   0.1 , 1); }   //    1.2-3: Vielfaches von   0.1
      else if (roundedLots[i] <=    7.5 ) { if (lotStep <   0.2 ) roundedLots[i] = NormalizeDouble(MathFloor(roundedLots[i]/  0.2 ) *   0.2 , 1); }   //    3-7.5: Vielfaches von   0.2
      else if (roundedLots[i] <=   12.  ) { if (lotStep <   0.5 ) roundedLots[i] = NormalizeDouble(MathFloor(roundedLots[i]/  0.5 ) *   0.5 , 1); }   //   7.5-12: Vielfaches von   0.5
      else if (roundedLots[i] <=   30.  ) { if (lotStep <   1.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/  1   ) *   1      ); }   //    12-30: Vielfaches von   1
      else if (roundedLots[i] <=   75.  ) { if (lotStep <   2.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/  2   ) *   2      ); }   //    30-75: Vielfaches von   2
      else if (roundedLots[i] <=  120.  ) { if (lotStep <   5.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/  5   ) *   5      ); }   //   75-120: Vielfaches von   5
      else if (roundedLots[i] <=  300.  ) { if (lotStep <  10.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/ 10   ) *  10      ); }   //  120-300: Vielfaches von  10
      else if (roundedLots[i] <=  750.  ) { if (lotStep <  20.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/ 20   ) *  20      ); }   //  300-750: Vielfaches von  20
      else if (roundedLots[i] <= 1200.  ) { if (lotStep <  50.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/ 50   ) *  50      ); }   // 750-1200: Vielfaches von  50
      else                                { if (lotStep < 100.  ) roundedLots[i] = MathRound      (MathFloor(roundedLots[i]/100   ) * 100      ); }   // 1200-...: Vielfaches von 100

      // (3.5) Lotsize validieren
      if (GT(roundedLots[i], maxLot)) return(_false(catch("OpenPendingOrder(4)   #"+ lo.Ticket(lo) +" too large trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(roundedLots[i], ".+") +" lot (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo)));

      // (3.6) bei zu geringer Equity Leverage erhöhen und Details für Warnung in (3.8) hinterlegen
      if (LT(roundedLots[i], minLot)) {
         roundedLots[i]  = minLot;
         overLeverageMsg = StringConcatenate(overLeverageMsg, ", ", symbols[i], " ", NumberToStr(roundedLots[i], ".+"), " instead of ", preciseLots[i], " lot");
      }

      // (3.7) tatsächlich zu handelnde Units (nach Auf-/Abrunden) berechnen
      realUnits += (roundedLots[i] / preciseLots[i] / symbolsSize);
   }
   realUnits = NormalizeDouble(realUnits * lfxUnits, 1);

   // (3.8) bei Leverageüberschreitung Warnung ausgeben, jedoch nicht abbrechen
   if (StringLen(overLeverageMsg) > 0)
      warn("OpenPendingOrder(5)   #"+ lo.Ticket(lo) +" Not enough money! The following positions will over-leverage: "+ StringRight(overLeverageMsg, -2) +". Resulting trade: "+ DoubleToStr(realUnits, 1) + ifString(EQ(realUnits, lfxUnits), " units (unchanged)", " instead of "+ DoubleToStr(lfxUnits, 1) +" units"+ ifString(LT(realUnits, lfxUnits), " (not realizable)", "")));


   // (4) Directions der Teilpositionen bestimmen
   for (i=0; i < symbolsSize; i++) {
      if (StringStartsWith(symbols[i], lfxCurrency)) directions[i]  = lfxDirection;
      else                                           directions[i]  = lfxDirection ^ 1;   // 0=>1, 1=>0
      if (lfxCurrency == "JPY")                      directions[i] ^= 1;                  // JPY ist invers notiert
   }


   // (5) LFX-Order sperren, bis alle Teilpositionen geöffnet sind und die Order gespeichert ist               TODO: system-weites Lock setzen
   string mutex = "mutex.LFX.#"+ lfxTicket;
   if (!AquireLock(mutex, true))
      return(_false(SetLastError(stdlib.GetLastError()), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo)));


   // (6) Teilorders ausführen und Gesamt-OpenPrice berechnen
   string comment = lo.Comment(lo);
      if ( StringStartsWith(comment, lfxCurrency)) comment = StringSubstr(comment, 3);
      if ( StringStartsWith(comment, "."        )) comment = StringSubstr(comment, 1);
      if ( StringStartsWith(comment, "#"        )) comment = StringSubstr(comment, 1);
      if (!StringStartsWith(comment, lfxCurrency)) comment = lfxCurrency +"."+ comment;
   double openPrice = 1.0;

   if (__LOG) log("OpenPendingOrder(6)   "+ lfxAccountCompany +": "+ lfxAccountName +" ("+ lfxAccount +"), "+ lfxAccountCurrency);

   for (i=0; i < symbolsSize; i++) {
      double   price       = NULL;
      double   slippage    = 0.1;
      double   sl          = NULL;
      double   tp          = NULL;
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;
      int      oeFlags     = NULL;
                                                                                       // vor Trade-Request alle evt. aufgetretenen Fehler abfangen
      if (IsError(stdlib.GetLastError()))        return(_false(SetLastError(stdlib.GetLastError()), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo), ReleaseLock(mutex)));
      if (IsError(catch("OpenPendingOrder(7)"))) return(_false(                                     lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo), ReleaseLock(mutex)));

      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      tickets[i] = OrderSendEx(symbols[i], directions[i], roundedLots[i], price, slippage, sl, tp, comment, lfxTicket, expiration, markerColor, oeFlags, oe);
      if (tickets[i] == -1)
         return(_false(SetLastError(stdlib.GetLastError()), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo), ReleaseLock(mutex)));

      if (StringStartsWith(symbols[i], lfxCurrency)) openPrice *= oe.OpenPrice(oe);
      else                                           openPrice /= oe.OpenPrice(oe);
   }
   openPrice = MathPow(openPrice, 1/7.);
   if (lfxCurrency == "JPY")
      openPrice = 1/openPrice;                                       // JPY ist invers notiert


   // (7) Order speichern
   lo.setType      (lo, lfxDirection);
   lo.setUnits     (lo, realUnits   );
   lo.setOpenTime  (lo, TimeGMT()   );
   lo.setOpenPrice (lo, openPrice   );
   lo.setOpenEquity(lo, equity      );
   if (!LFX.SaveOrder(lo))
      return(_false(ReleaseLock(mutex)));                            // TODO: Kein Abbruch, falls Speichern wegen ERR_CONCURRENT_MODIFICATION fehlschlägt


   // (8) Order freigeben
   if (!ReleaseLock(mutex))
      return(!SetLastError(stdlib.GetLastError()));


   // (9) Logmessage ausgeben
   string lfxFormat = ifString(lo.CurrencyId(lo)==CID_JPY, ".2'", ".4'");
   if (__LOG) log("OpenPendingOrder(8)   "+ comment +" "+ ifString(lfxDirection==OP_BUY, "long", "short") +" position opened at "+ NumberToStr(lo.OpenPrice(lo), lfxFormat) +" (LFX price: "+ NumberToStr(lo.OpenPriceLfx(lo), lfxFormat) +")");


   // (10) ggf. SMS verschicken
   if (sms.alerts) {
      string message = lfxAccountAlias +": "+ comment +" "+ ifString(lfxDirection==OP_BUY, "long", "short") +" position opened at "+ NumberToStr(lo.OpenPriceLfx(lo), lfxFormat);
      if (!SendSMS(sms.receiver, TimeToStr(TimeLocal(), TIME_MINUTES) +" "+ message))
         return(SetLastError(stdlib.GetLastError()));
      if (__LOG) log("OpenPendingOrder(9)   SMS sent to "+ sms.receiver);
   }


   // (11) Ausführungsbestätigung ans LFX-Terminal schicken
   if (!QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":open=1"))
      return(false);

   return(true);
}


/**
 * Schleßt eine offene Position.
 *
 * @param  LFX_ORDER lo[] - die zu schließende Order
 *
 * @return bool - Erfolgsstatus
 */
bool ClosePosition(/*LFX_ORDER*/int lo[]) {
   if (!lo.IsOpen(lo))
      return(!catch("ClosePosition(1)   #"+ lo.Ticket(lo) +" cannot close "+ ifString(lo.IsPending(lo), "a pending", "an already closed") +" order", ERR_RUNTIME_ERROR));


   // (1) zu schließende Einzelpositionen selektieren
   int tickets[], orders=OrdersTotal();

   for (int i=0; i < orders; i++) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine aktive Order geschlossen oder gestrichen
         break;
      if (OrderType() > OP_SELL)
         continue;
      if (OrderMagicNumber() == lo.Ticket(lo))
         ArrayPushInt(tickets, OrderTicket());
   }
   int ticketsSize = ArraySize(tickets);
   if (!ticketsSize)
      return(!catch("ClosePosition(2)   #"+ lo.Ticket(lo) +" no matching open MT4 tickets found ", ERR_RUNTIME_ERROR));


   // (2) Positionen schließen
   double slippage    = 0.1;
   color  markerColor = CLR_NONE;
   int    oeFlags     = NULL;

   if (IsError(stdlib.GetLastError()))     return(!SetLastError(stdlib.GetLastError())); // vor Trade-Request alle evt. aufgetretenen Fehler abfangen
   if (IsError(catch("ClosePosition(3)"))) return(false);

   if (__LOG) log("ClosePosition(4)   "+ lfxAccountCompany +": "+ lfxAccountName +" ("+ lfxAccount +"), "+ lfxAccountCurrency);

   /*ORDER_EXECUTION*/int oes[][ORDER_EXECUTION.intSize]; ArrayResize(oes, ticketsSize); InitializeByteBuffer(oes, ORDER_EXECUTION.size);
   if (!OrderMultiClose(tickets, slippage, markerColor, oeFlags, oes))
      return(!SetLastError(stdlib.GetLastError()));


   // (3) Gesamt-ClosePrice und -Profit berechnen
   string currency = lo.Currency(lo);
   double closePrice=1.0, profit=0;
   for (i=0; i < ticketsSize; i++) {
      if (StringStartsWith(oes.Symbol(oes, i), currency)) closePrice *= oes.ClosePrice(oes, i);
      else                                                closePrice /= oes.ClosePrice(oes, i);
      profit += oes.Swap(oes, i) + oes.Commission(oes, i) + oes.Profit(oes, i);
   }
   closePrice = MathPow(closePrice, 1/7.);
   if (currency == "JPY")
      closePrice = 1/closePrice;                                     // JPY ist invers notiert


   // (4) LFX-Order aktualisieren und speichern (erst nach SMS, falls Speichern fehlschlägt)
   lo.setCloseTime (lo, TimeGMT() );
   lo.setClosePrice(lo, closePrice);
   lo.setProfit    (lo, profit    );
      string oldComment = lo.Comment(lo);
   lo.setComment   (lo, ""        );
   if (!LFX.SaveOrder(lo))                      // TODO: Kein Abbruch, wenn Speichern wegen ERR_CONCURRENT_MODIFICATION fehlschlägt
      return(false);


   // (5) Logmessage ausgeben                                        // letzten Counter ermitteln
   if (StringStartsWith(oldComment, lo.Currency(lo))) oldComment = StringRight(oldComment, -3);
   if (StringStartsWith(oldComment, "."            )) oldComment = StringRight(oldComment, -1);
   if (StringStartsWith(oldComment, "#"            )) oldComment = StringRight(oldComment, -1);
   int    counter   = StrToInteger(oldComment);
   string sCounter  = ifString(!counter, "", "."+ counter);
   string lfxFormat = ifString(lo.CurrencyId(lo)==CID_JPY, ".2'", ".4'");
   if (__LOG) log("ClosePosition(5)   "+ currency + sCounter +" closed at "+ NumberToStr(lo.ClosePrice(lo), lfxFormat) +" (LFX price: "+ NumberToStr(lo.ClosePriceLfx(lo), lfxFormat) +"), profit: "+ DoubleToStr(lo.Profit(lo), 2));


   // (6) ggf. SMS verschicken
   if (sms.alerts) {
      string message = lfxAccountAlias +": "+ currency + sCounter +" closed at "+ NumberToStr(lo.ClosePriceLfx(lo), lfxFormat);
      if (!SendSMS(sms.receiver, TimeToStr(TimeLocal(), TIME_MINUTES) +" "+ message))
         return(SetLastError(stdlib.GetLastError()));
      if (__LOG) log("ClosePosition(6)   SMS sent to "+ sms.receiver);
   }


   // (7) LFX-Terminal benachrichtigen
   if (!QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":close=1"))
      return(false);

   return(true);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


/*abstract*/bool ProcessTradeToLfxTerminalMsg(string s1) { return(!catch("ProcessTradeToLfxTerminalMsg()",  ERR_WRONG_JUMP)); }


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "struct.ORDER_EXECUTION.ex4"
   double oe.OpenPrice  (/*ORDER_EXECUTION*/int oe[]         );
   double oes.ClosePrice(/*ORDER_EXECUTION*/int oe[][], int i);
   double oes.Commission(/*ORDER_EXECUTION*/int oe[][], int i);
   double oes.Profit    (/*ORDER_EXECUTION*/int oe[][], int i);
   double oes.Swap      (/*ORDER_EXECUTION*/int oe[][], int i);
   string oes.Symbol    (/*ORDER_EXECUTION*/int oe[][], int i);
#import

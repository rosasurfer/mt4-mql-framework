/**
 * LFX.ExecuteTradeCmd
 *
 * Script, daß nur intern zur Ausführung von zwischen den Terminals verschickten TradeCommands benutzt wird. Ein manueller Aufruf ist nicht möglich.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <lfx.mqh>
#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>
#include <core/script.ParameterProvider.mqh>


//////////////////////////////////////////////////////////////////////  Scriptparameter (Übergabe per QickChannel)  ///////////////////////////////////////////////////////////////////////

string command = "";

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int    lfxTicket;
string action;
double leverage;


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


   // (2) Scriptparameter validieren, Format: "LFX.{Ticket}.{Action}", z.B. "LFX.428371265.open"
   if (StringLeft(command, 4) != "LFX.")            return(catch("onInit(2)   invalid parameter command = \""+ command +"\" (prefix)", ERR_INVALID_INPUT_PARAMVALUE));
   int pos = StringFind(command, ".", 4);
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

   return(catch("onInit(7)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // Order holen
   if (!LFX.GetOrder(lfxTicket, lfxOrder))
      return(last_error);

   if (action == "open") {
      if (!OpenPendingOrder(lfxOrder)) return(last_error);
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
      return(!catch("OpenPendingOrder(1)   cannot open "+ ifString(lo.IsOpen(lo), "an already open", "a closed") +" order", ERR_RUNTIME_ERROR));


   // (1) Trade-Parameter einlesen
   string lfxCurrency  = lo.Currency  (lo);
   int    lfxDirection = IsShortTradeOperation(lo.Type(lo));
   double lfxUnits     = lo.Units(lo);


   // (2) zu handelnde Pairs bestimmen                                                 // TODO: Brokerspezifische Symbole ermitteln
   string symbols    [6];
   double preciseLots[6], roundedLots[6];
   int    directions [6];
   int    tickets    [6];
   if      (lfxCurrency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD"; }
   else if (lfxCurrency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD"; }
   else if (lfxCurrency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF"; }
   else if (lfxCurrency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD"; }
   else if (lfxCurrency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD"; }
   else if (lfxCurrency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY"; }
   else if (lfxCurrency == "NZD") { symbols[0] = "AUDNZD"; symbols[1] = "EURNZD"; symbols[2] = "NZDCAD"; symbols[3] = "GBPNZD"; symbols[4] = "NZDUSD"; symbols[5] = "NZDJPY"; }
   else if (lfxCurrency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY"; }


   // (3) Lotsizes je Pair berechnen
   double equity = MathMin(AccountBalance(), AccountEquity()-AccountCredit());
   string errorMsg, overLeverageMsg;

   for (int retry, i=0; i < 6; i++) {
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
      double unitSize = equity / lotValue * leverage / 6;                              // equity/lotValue entspricht einem Hebel von 1, dieser Wert wird mit leverage gehebelt
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
      if (GT(roundedLots[i], maxLot)) return(_false(catch("OpenPendingOrder(4)   too large trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(roundedLots[i], ".+") +" lot (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo)));

      // (3.6) bei zu geringer Equity Leverage erhöhen und Details für Warnung in (2.7) hinterlegen
      if (LT(roundedLots[i], minLot)) {
         roundedLots[i]  = minLot;
         overLeverageMsg = StringConcatenate(overLeverageMsg, ", ", symbols[i], " ", NumberToStr(roundedLots[i], ".+"), " instead of ", preciseLots[i], " lot");
      }
   }

   // (3.7) bei Leverageüberschreitung in (2.6) Warnung ausgeben, jedoch nicht abbrechen
   if (StringLen(overLeverageMsg) > 0)
      warn("OpenPendingOrder(5)   Not enough money. The following positions will over-leverage: "+ StringRight(overLeverageMsg, -2));


   // (4) Directions der Teilpositionen bestimmen
   for (i=0; i < 6; i++) {
      if (StringStartsWith(symbols[i], lfxCurrency)) directions[i]  = lfxDirection;
      else                                           directions[i]  = lfxDirection ^ 1;   // 0=>1, 1=>0
      if (lfxCurrency == "JPY")                      directions[i] ^= 1;                  // JPY ist invers notiert
   }


   // (5) Lock auf die neue Position (LFX-Ticket) setzen, damit andere Indikatoren/Charts nicht schon vor Ende des Scripts auftauchende Teilpositionen verarbeiten.
   string mutex = "mutex.LFX.#"+ lfxTicket;
   if (!AquireLock(mutex, true))
      return(_false(SetLastError(stdlib_GetLastError()), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo)));


   // (6) Order ausführen und dabei Gesamt-OpenPrice berechnen
   string comment = lo.Comment(lo);
      if ( StringStartsWith(comment, "#"        )) comment = StringSubstr(comment, 1);
      if (!StringStartsWith(comment, lfxCurrency)) comment = lfxCurrency +"."+ comment;
   double openPrice = 1.0;

   for (i=0; i < 6; i++) {
      double   price       = NULL;
      double   slippage    = 0.1;
      double   sl          = NULL;
      double   tp          = NULL;
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;
      int      oeFlags     = NULL;
                                                                                       // vor Trade-Request alle evt. aufgetretenen Fehler abfangen
      if (IsError(stdlib_GetLastError()))        return(_false(SetLastError(stdlib_GetLastError()), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo), ReleaseLock(mutex)));
      if (IsError(catch("OpenPendingOrder(6)"))) return(_false(                                     lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo), ReleaseLock(mutex)));

      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      tickets[i] = OrderSendEx(symbols[i], directions[i], roundedLots[i], price, slippage, sl, tp, comment, lfxTicket, expiration, markerColor, oeFlags, oe);
      if (tickets[i] == -1)
         return(_false(SetLastError(stdlib_GetLastError()), lo.setOpenTime(lo, -TimeGMT()), LFX.SaveOrder(lo), ReleaseLock(mutex)));

      if (StringStartsWith(symbols[i], lfxCurrency)) openPrice *= oe.OpenPrice(oe);
      else                                           openPrice /= oe.OpenPrice(oe);
   }
   openPrice = MathPow(openPrice, 1.0/7);
   if (lfxCurrency == "JPY")
      openPrice = 1/openPrice;                     // JPY ist invers notiert


   // (7) Logmessage ausgeben
   int    lfxDigits = lo.Digits(lo);
   string lfxFormat = ifString(lfxCurrency=="JPY", ".2'", ".4'");
          openPrice = NormalizeDouble(openPrice, lfxDigits);
   if (__LOG) log("OpenPendingOrder(7)   "+ comment +" "+ ifString(lfxDirection==OP_BUY, "long", "short") +" position opened at "+ NumberToStr(openPrice, lfxFormat));


   // (8) LFX-Order speichern
   lo.setType      (lo, lfxDirection);
   lo.setOpenTime  (lo, TimeGMT()   );
   lo.setOpenPrice (lo, openPrice   );
   lo.setOpenEquity(lo, equity      );

   if (!LFX.SaveOrder(lo))
      return(_false(ReleaseLock(mutex)));


   // (9) Lock auf die neue Position wieder freigeben
   if (!ReleaseLock(mutex))
      return(!SetLastError(stdlib_GetLastError()));

   return(true);
}

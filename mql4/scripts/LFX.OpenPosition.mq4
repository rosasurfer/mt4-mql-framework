/**
 * Öffnet eine LFX-Position.
 *
 * TODO: Fehler im Position-Marker, wenn gleichzeitig zwei Orders erzeugt und die finalen Bestätigungsdialoge gehalten
 *       werden (2 x CHF.3).
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs
////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string LFX.Currency = "";                                     // AUD | CAD | CHF | EUR | GBP | JPY | NZD | USD
extern string Direction    = "long | short";                         // B[uy] | S[ell] | L[ong] | S[hort]
extern double Units        = 0.2;                                    // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 3.0)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/xtrade/LFXOrder.mqh>
#include <structs/xtrade/OrderExecution.mqh>


int    direction;
double leverage;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) TradeAccount und Status initialisieren
   if (!InitTradeAccount())
      return(last_error);


   // (2.1) Parametervalidierung: LFX.Currency
   string value = StringToUpper(StringTrim(LFX.Currency));
   string currencies[] = {"AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"};
   if (!StringInArray(currencies, value)) return(HandleScriptError("onInit(1)", "Invalid parameter LFX.Currency = \""+ LFX.Currency +"\"\n(not a LFX currency)", ERR_INVALID_INPUT_PARAMETER));
   lfxCurrency   = value;
   lfxCurrencyId = GetCurrencyId(lfxCurrency);

   // (2.2) Direction
   value = StringToUpper(StringTrim(Direction));
   if      (value=="B" || value=="BUY"  || value=="L" || value=="LONG" ) { Direction = "long";  direction = OP_BUY;  }
   else if (value=="S" || value=="SELL"               || value=="SHORT") { Direction = "short"; direction = OP_SELL; }
   else                                   return(HandleScriptError("onInit(2)", "Invalid parameter Direction = \""+ Direction +"\"", ERR_INVALID_INPUT_PARAMETER));

   // (2.3) Units
   if (!EQ(MathModFix(Units, 0.1), 0))    return(HandleScriptError("onInit(3)", "Invalid parameter Units = "+ NumberToStr(Units, ".+") +"\n(not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMETER));
   if (Units < 0.1 || Units > 3)          return(HandleScriptError("onInit(4)", "Invalid parameter Units = "+ NumberToStr(Units, ".+") +"\n(valid range is from 0.1 to 3.0)", ERR_INVALID_INPUT_PARAMETER));
   Units = NormalizeDouble(Units, 1);


   // (3) Leverage-Konfiguration einlesen und validieren
   string section = "MoneyManagement";
   string key     = "BasketLeverage";
   if (!IsGlobalConfigKey(section, key))  return(HandleScriptError("onInit(5)", "Missing global MetaTrader config value ["+ section +"]->"+ key, ERR_INVALID_CONFIG_PARAMVALUE));
   value = GetGlobalConfigString(section, key);
   if (!StringIsNumeric(value))           return(HandleScriptError("onInit(6)", "Invalid MetaTrader config value ["+ section +"]->"+ key +" = \""+ value +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   leverage = StrToDouble(value);
   if (leverage < 1)                      return(HandleScriptError("onInit(7)", "Invalid MetaTrader config value ["+ section +"]->"+ key +" = "+ NumberToStr(leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));


   // (4) alle Orders des Symbols einlesen
   int size = LFX.GetOrders(lfxCurrency, NULL, lfxOrders);
   if (size < 0)
      return(last_error);
   return(catch("onInit(8)"));
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
   string symbols   [7];
   int    symbolsSize;
   double exactLots [7], roundedLots[7], realUnits;
   int    directions[7];
   int    tickets   [7];


   // (1) zu handelnde Pairs bestimmen
   //     TODO: Brokerspezifische Symbole ermitteln
   if      (lfxCurrency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD";                        symbolsSize = 6; }
   else if (lfxCurrency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD";                        symbolsSize = 6; }
   else if (lfxCurrency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF";                        symbolsSize = 6; }
   else if (lfxCurrency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD";                        symbolsSize = 6; }
   else if (lfxCurrency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD";                        symbolsSize = 6; }
   else if (lfxCurrency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY";                        symbolsSize = 6; }
   else if (lfxCurrency == "NZD") { symbols[0] = "AUDNZD"; symbols[1] = "EURNZD"; symbols[2] = "GBPNZD"; symbols[3] = "NZDCAD"; symbols[4] = "NZDCHF"; symbols[5] = "NZDJPY"; symbols[6] = "NZDUSD"; symbolsSize = 7; }
   else if (lfxCurrency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY";                        symbolsSize = 6; }


   // (2) Lotsizes berechnen
   double externalAssets = GetExternalAssets(tradeAccount.company, tradeAccount.number);
   double visibleEquity  = AccountEquity()-AccountCredit();                            // bei negativer AccountBalance wird nur visibleEquity benutzt
      if (AccountBalance() > 0) visibleEquity = MathMin(AccountBalance(), visibleEquity);
   double equity = visibleEquity + externalAssets;

   int    button;
   string errorMsg, overLeverageMsg;

   for (int retry, i=0; i < symbolsSize; i++) {
      // (2.1) notwendige Daten ermitteln
      double bid       = MarketInfo(symbols[i], MODE_BID      );
      double tickSize  = MarketInfo(symbols[i], MODE_TICKSIZE );
      double tickValue = MarketInfo(symbols[i], MODE_TICKVALUE);
      double minLot    = MarketInfo(symbols[i], MODE_MINLOT   );
      double maxLot    = MarketInfo(symbols[i], MODE_MAXLOT   );
      double lotStep   = MarketInfo(symbols[i], MODE_LOTSTEP  );
      if (IsError(catch("onStart(1)  \""+ symbols[i] +"\"")))                          // TODO: auf ERR_SYMBOL_NOT_AVAILABLE prüfen
         return(last_error);

      // (2.2) Werte auf ungültige MarketInfo()-Daten prüfen
      errorMsg = "";
      if      (LT(bid, 0.5)          || GT(bid, 300)      ) errorMsg = "Bid(\""      + symbols[i] +"\") = "+ NumberToStr(bid      , ".+");
      else if (LT(tickSize, 0.00001) || GT(tickSize, 0.01)) errorMsg = "TickSize(\"" + symbols[i] +"\") = "+ NumberToStr(tickSize , ".+");
      else if (LT(tickValue, 0.5)    || GT(tickValue, 20) ) errorMsg = "TickValue(\""+ symbols[i] +"\") = "+ NumberToStr(tickValue, ".+");
      else if (LT(minLot, 0.01)      || GT(minLot, 0.1)   ) errorMsg = "MinLot(\""   + symbols[i] +"\") = "+ NumberToStr(minLot   , ".+");
      else if (LT(maxLot, 50)                             ) errorMsg = "MaxLot(\""   + symbols[i] +"\") = "+ NumberToStr(maxLot   , ".+");
      else if (LT(lotStep, 0.01)     || GT(lotStep, 0.1)  ) errorMsg = "LotStep(\""  + symbols[i] +"\") = "+ NumberToStr(lotStep  , ".+");

      // (2.3) ungültige MarketInfo()-Daten behandeln
      if (StringLen(errorMsg) > 0) {
         if (retry < 3) {                                                              // 3 stille Versuche, korrekte Werte zu lesen
            Sleep(200);                                                                // bei Mißerfolg jeweils xxx Millisekunden warten
            i = -1;
            retry++;
            continue;
         }
         PlaySoundEx("Windows Notify.wav");                                            // bei weiterem Mißerfolg Bestätigung für Fortsetzung einholen
         button = MessageBox("Invalid MarketInfo() data.\n\n"+ errorMsg, __NAME__, MB_ICONINFORMATION|MB_RETRYCANCEL);
         if (button == IDRETRY) {
            i = -1;
            continue;                                                                  // Datenerhebung wiederholen...
         }
         return(catch("onStart(2)"));                                                  // ...oder abbrechen
      }

      // (2.4) Lotsize berechnen
      double lotValue = bid/tickSize * tickValue;                                      // Value eines Lots in Account-Currency
      double unitSize = equity / lotValue * leverage / symbolsSize;                    // equity/lotValue ist die ungehebelte Lotsize (Hebel 1:1) und wird mit leverage gehebelt
      exactLots  [i]  = Units * unitSize;                                              // exactLots zunächst auf Vielfaches von MODE_LOTSTEP runden
      roundedLots[i]  = NormalizeDouble(MathRound(exactLots[i]/lotStep) * lotStep, CountDecimals(lotStep));

      // Schrittweite mit zunehmender Lotsize über MODE_LOTSTEP hinaus erhöhen (entspricht Algorythmus in ChartInfos-Indikator)
      if      (roundedLots[i] <=    0.3 ) {                                                                                                       }   // Abstufung maximal 6.7% je Schritt
      else if (roundedLots[i] <=    0.75) { if (lotStep <   0.02) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.02) *   0.02, 2); }   // 0.3-0.75: Vielfaches von   0.02
      else if (roundedLots[i] <=    1.2 ) { if (lotStep <   0.05) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.05) *   0.05, 2); }   // 0.75-1.2: Vielfaches von   0.05
      else if (roundedLots[i] <=    3.  ) { if (lotStep <   0.1 ) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.1 ) *   0.1 , 1); }   //    1.2-3: Vielfaches von   0.1
      else if (roundedLots[i] <=    7.5 ) { if (lotStep <   0.2 ) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.2 ) *   0.2 , 1); }   //    3-7.5: Vielfaches von   0.2
      else if (roundedLots[i] <=   12.  ) { if (lotStep <   0.5 ) roundedLots[i] = NormalizeDouble(MathRound(roundedLots[i]/  0.5 ) *   0.5 , 1); }   //   7.5-12: Vielfaches von   0.5
      else if (roundedLots[i] <=   30.  ) { if (lotStep <   1.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/  1   ) *   1      ); }   //    12-30: Vielfaches von   1
      else if (roundedLots[i] <=   75.  ) { if (lotStep <   2.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/  2   ) *   2      ); }   //    30-75: Vielfaches von   2
      else if (roundedLots[i] <=  120.  ) { if (lotStep <   5.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/  5   ) *   5      ); }   //   75-120: Vielfaches von   5
      else if (roundedLots[i] <=  300.  ) { if (lotStep <  10.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/ 10   ) *  10      ); }   //  120-300: Vielfaches von  10
      else if (roundedLots[i] <=  750.  ) { if (lotStep <  20.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/ 20   ) *  20      ); }   //  300-750: Vielfaches von  20
      else if (roundedLots[i] <= 1200.  ) { if (lotStep <  50.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/ 50   ) *  50      ); }   // 750-1200: Vielfaches von  50
      else                                { if (lotStep < 100.  ) roundedLots[i] =       MathRound(MathRound(roundedLots[i]/100   ) * 100      ); }   // 1200-...: Vielfaches von 100

      // (2.5) Lotsize validieren
      if (GT(roundedLots[i], maxLot)) return(catch("onStart(3)  too large trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(roundedLots[i], ".+") +" lot (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));

      // (2.6) bei zu geringer Equity MinLotSize verwenden und Details für spätere Warnung hinterlegen
      if (LT(roundedLots[i], minLot)) {
         roundedLots[i]  = minLot;
         overLeverageMsg = StringConcatenate(overLeverageMsg, NL, GetSymbolName(symbols[i]), ": ", NumberToStr(roundedLots[i], ".+"), " instead of ", exactLots[i], " lot");
      }
      log("onStart(4)  lot size "+ symbols[i] +": calculated="+ DoubleToStr(exactLots[i], 4) +"  result="+ NumberToStr(roundedLots[i], ".+") +" ("+ NumberToStr(roundedLots[i]/exactLots[i]*100-100, "+.0R") +"%)");

      // (2.7) resultierende Units berechnen (nach Auf-/Abrunden)
      realUnits += (roundedLots[i] / exactLots[i] / symbolsSize);
   }
   realUnits = NormalizeDouble(realUnits * Units, 1);
   log("onStart(5)  units: input="+ DoubleToStr(Units, 1) +"  result="+ DoubleToStr(realUnits, 1));

   // (2.8) bei Leverageüberschreitung ausdrückliche Bestätigung einholen
   if (StringLen(overLeverageMsg) > 0) {
      PlaySoundEx("Windows Notify.wav");
      button = MessageBox("Not enough money! The following positions will over-leverage:"+ NL
                         + overLeverageMsg                                               + NL
                         + NL
                         +"Resulting position: "+ DoubleToStr(realUnits, 1) + ifString(EQ(realUnits, Units), " units (unchanged)", " instead of "+ DoubleToStr(Units, 1) +" units"+ ifString(LT(realUnits, Units), " (not obtainable)", "")) + NL
                         + NL
                         +"Continue?",
                         __NAME__,
                         MB_ICONWARNING|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(6)"));
   }


   // (3) Directions der Teilpositionen bestimmen
   for (i=0; i < symbolsSize; i++) {
      if (StringStartsWith(symbols[i], lfxCurrency)) directions[i] = direction;
      else                                           directions[i] = direction ^ 1;    // 0=>1, 1=>0
   }


   // (4) finale Sicherheitsabfrage
   PlaySoundEx("Windows Notify.wav");
   button = MessageBox(ifString(IsDemoFix(), "", "- Real Account -\n\n")
                     +"Do you really want to "+ StringToLower(OperationTypeDescription(direction)) +" "+ NumberToStr(realUnits, ".+") + ifString(realUnits==1, " unit ", " units ") + lfxCurrency +"?"
                     + ifString(LT(realUnits, Units), "\n("+ DoubleToStr(Units, 1) +" is not obtainable)", ""),
                     __NAME__,
                     MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(7)"));

   // TODO: Fehler im Marker, wenn gleichzeitig zwei Orderdialoge aufgerufen und gehalten werden (2 x CHF.3)
   int    magicNumber = LFX.CreateMagicNumber(lfxOrders, lfxCurrency);
   int    marker      = LFX.GetMaxOpenOrderMarker(lfxOrders, lfxCurrencyId) + 1;
   string comment     = lfxCurrency +"."+ marker;


   // (5) LFX-Order sperren, bis alle Teilpositionen geöffnet sind und die Order gespeichert ist               TODO: System-weites Lock setzen
   string mutex = "mutex.LFX.#"+ magicNumber;
   if (!AquireLock(mutex, true))
      return(ERR_RUNTIME_ERROR);


   // (6) Teilorders ausführen und Gesamt-OpenPrice berechnen
   double openPrice = 1.0;

   for (i=0; i < symbolsSize; i++) {
      double   price       = NULL;
      double   slippage    = 0.1;
      double   sl          = NULL;
      double   tp          = NULL;
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;
      int      oeFlags     = NULL;
                                                                                       // vor Trade-Request auf evt. aufgetretene Fehler prüfen
      if (IsError(catch("onStart8)"))) return(_last_error(ReleaseLock(mutex)));

      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      tickets[i] = OrderSendEx(symbols[i], directions[i], roundedLots[i], price, slippage, sl, tp, comment, magicNumber, expiration, markerColor, oeFlags, oe);
      if (!tickets[i])
         return(_int(ERR_RUNTIME_ERROR, ReleaseLock(mutex)));

      if (StringStartsWith(symbols[i], lfxCurrency)) openPrice *= oe.OpenPrice(oe);
      else                                           openPrice /= oe.OpenPrice(oe);
   }
   openPrice = MathPow(openPrice, 1/7.);
   if (lfxCurrency == "JPY")
      openPrice *= 100;                                                                // JPY wird normalisiert


   // (7) neue LFX-Order erzeugen und speichern
   datetime now.fxt = TimeFXT(); if (!now.fxt) return(last_error);

   /*LFX_ORDER*/int lo[]; InitializeByteBuffer(lo, LFX_ORDER.size);
      lo.setTicket           (lo, magicNumber);                                        // Ticket immer zuerst, damit im Struct Currency-ID und Digits ermittelt werden können
      lo.setType             (lo, direction  );
      lo.setUnits            (lo, realUnits  );
      lo.setOpenTime         (lo, now.fxt    );
      lo.setOpenEquity       (lo, equity     );
      lo.setOpenPrice        (lo, openPrice  );
      lo.setStopLossValue    (lo, EMPTY_VALUE);
      lo.setStopLossPercent  (lo, EMPTY_VALUE);
      lo.setTakeProfitValue  (lo, EMPTY_VALUE);
      lo.setTakeProfitPercent(lo, EMPTY_VALUE);
      lo.setComment          (lo, "#"+ marker);
   if (!LFX.SaveOrder(lo))
      return(_last_error(ReleaseLock(mutex)));


   // (8) Logmessage ausgeben
   log("onStart(9)  "+ lfxCurrency +"."+ marker +" "+ ifString(direction==OP_BUY, "long", "short") +" position opened at "+ NumberToStr(lo.OpenPrice(lo), ".4'"));


   // (9) Order freigeben
   if (!ReleaseLock(mutex))
      return(ERR_RUNTIME_ERROR);


   // (9) LFX-Terminal benachrichtigen
   QC.SendOrderNotification(lo.CurrencyId(lo), "LFX:"+ lo.Ticket(lo) +":open=1");

   return(last_error);
}

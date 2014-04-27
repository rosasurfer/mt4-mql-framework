/**
 * Öffnet eine LFX-Position.
 *
 *
 *  TODO:
 *  -----
 *  - Fehler in Counter und damit in MagicNumber, wenn 2 Positionen gleichzeitig geöffnet werden (2 x CHF.3)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#include <lfx.mqh>
#include <win32api.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string LFX.Currency = "";                                     // AUD | CAD | CHF | EUR | GBP | JPY | NZD | USD
extern string Direction    = "long | short";                         // (B)uy | (S)ell | (L)ong | (S)hort
extern double Units        = 1.0;                                    // Positionsgröße (Vielfaches von 0.1 im Bereich von 0.1 bis 1.0)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string lfxCurrency;
int    lfxCurrencyId;
int    direction;
double leverage;

int    openPositions.instanceId[];                                   // Daten der aktuell offenen LFX-Positionen
int    openPositions.maxCounter;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1.1) Parametervalidierung: LFX.Currency
   string value = StringToUpper(StringTrim(LFX.Currency));
   string currencies[] = {"AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"};
   if (!StringInArray(currencies, value))        return(catch("onInit(1)   Invalid input parameter LFX.Currency = \""+ LFX.Currency +"\" (not a LFX currency)", ERR_INVALID_INPUT_PARAMVALUE));
   lfxCurrency   = value;
   lfxCurrencyId = GetCurrencyId(lfxCurrency);

   // (1.2) Direction
   value = StringToUpper(StringTrim(Direction));
   if      (value=="B" || value=="BUY"  || value=="L" || value=="LONG" ) { Direction = "long";  direction = OP_BUY;  }
   else if (value=="S" || value=="SELL"               || value=="SHORT") { Direction = "short"; direction = OP_SELL; }
   else                                          return(catch("onInit(2)   Invalid input parameter Direction = \""+ Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // (1.3) Units
   if (NE(MathModFix(Units, 0.1), 0))            return(catch("onInit(3)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (not a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   if (Units < 0.1 || Units > 1)                 return(catch("onInit(4)   Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (valid range is from 0.1 to 1.0)", ERR_INVALID_INPUT_PARAMVALUE));
   Units = NormalizeDouble(Units, 1);


   // (2) Leverage-Konfiguration einlesen und validieren
   if (!IsGlobalConfigKey("Leverage", "Basket")) return(catch("onInit(5)   Missing global MetaTrader config value [Leverage]->Basket", ERR_INVALID_CONFIG_PARAMVALUE));
   value = GetGlobalConfigString("Leverage", "Basket", "");
   if (!StringIsNumeric(value))                  return(catch("onInit(6)   Invalid MetaTrader config value [Leverage]->Basket = \""+ value +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   leverage = StrToDouble(value);
   if (leverage < 1)                             return(catch("onInit(7)   Invalid MetaTrader config value [Leverage]->Basket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_CONFIG_PARAMVALUE));

   return(catch("onInit(8)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string symbols    [6];
   double preciseLots[6], roundedLots[6];
   int    directions [6];
   int    tickets    [6];


   // (1) zu handelnde Pairs bestimmen
   //     TODO: Brokerspezifische Symbole ermitteln
   if      (lfxCurrency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD"; }
   else if (lfxCurrency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD"; }
   else if (lfxCurrency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF"; }
   else if (lfxCurrency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD"; }
   else if (lfxCurrency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD"; }
   else if (lfxCurrency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY"; }
   else if (lfxCurrency == "NZD") { symbols[0] = "AUDNZD"; symbols[1] = "EURNZD"; symbols[2] = "NZDCAD"; symbols[3] = "GBPNZD"; symbols[4] = "NZDUSD"; symbols[5] = "NZDJPY"; }
   else if (lfxCurrency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY"; }


   // (2) Lotsizes berechnen
   double equity = MathMin(AccountBalance(), AccountEquity()-AccountCredit());
   int    button;
   string errorMsg, overLeverageMsg;

   for (int retry, i=0; i < 6; i++) {
      // (2.1) notwendige Daten ermitteln
      double bid           = MarketInfo(symbols[i], MODE_BID      );
      double tickSize      = MarketInfo(symbols[i], MODE_TICKSIZE );
      double tickValue     = MarketInfo(symbols[i], MODE_TICKVALUE);
      double minLot        = MarketInfo(symbols[i], MODE_MINLOT   );
      double maxLot        = MarketInfo(symbols[i], MODE_MAXLOT   );
      double lotStep       = MarketInfo(symbols[i], MODE_LOTSTEP  );
      int    lotStepDigits = CountDecimals(lotStep);
      int error = GetLastError();
      if (error != NO_ERROR)                                                           // Todo: auf ERR_UNKNOWN_SYMBOL prüfen
         return(catch("onStart(1)   \""+ symbols[i] +"\"", error));

      // (2.2) auf ERR_INVALID_MARKET_DATA prüfen
      errorMsg = "";
      if      (LT(bid, 0.5)          || GT(bid, 300)      ) errorMsg = StringConcatenate("Bid(\""      , symbols[i], "\") = ", NumberToStr(bid      , ".+"));
      else if (LT(tickSize, 0.00001) || GT(tickSize, 0.01)) errorMsg = StringConcatenate("TickSize(\"" , symbols[i], "\") = ", NumberToStr(tickSize , ".+"));
      else if (LT(tickValue, 0.5)    || GT(tickValue, 20) ) errorMsg = StringConcatenate("TickValue(\"", symbols[i], "\") = ", NumberToStr(tickValue, ".+"));
      else if (LT(minLot, 0.01)      || GT(minLot, 0.1)   ) errorMsg = StringConcatenate("MinLot(\""   , symbols[i], "\") = ", NumberToStr(minLot   , ".+"));
      else if (LT(maxLot, 50)                             ) errorMsg = StringConcatenate("MaxLot(\""   , symbols[i], "\") = ", NumberToStr(maxLot   , ".+"));
      else if (LT(lotStep, 0.01)     || GT(lotStep, 0.1)  ) errorMsg = StringConcatenate("LotStep(\""  , symbols[i], "\") = ", NumberToStr(lotStep  , ".+"));

      // (2.3) ERR_INVALID_MARKET_DATA behandeln
      if (StringLen(errorMsg) > 0) {
         if (retry < 3) {                                                              // 3 stille Versuche, korrekte Werte zu lesen
            Sleep(200);                                                                // bei Mißerfolg jeweils xxx Millisekunden warten
            i = -1;
            retry++;
            continue;
         }
         PlaySound("notify.wav");                                                      // bei weiterem Mißerfolg Bestätigung für Fortsetzung einholen
         button = MessageBox("Invalid MarketInfo() data.\n\n"+ errorMsg, __NAME__, MB_ICONINFORMATION|MB_RETRYCANCEL);
         if (button == IDRETRY) {
            i = -1;
            continue;                                                                  // Datenerhebung wiederholen...
         }
         return(catch("onStart(2)"));                                                  // ...oder abbrechen
      }

      // (2.4) Lotsize berechnen (dabei immer abrunden)
      double lotValue = bid / tickSize * tickValue;                                    // Lotvalue eines Lots in Account-Currency
      double unitSize = equity / lotValue * leverage / 6;                              // equity/lotValue entspricht einem Hebel von 1, dieser Wert wird mit leverage gehebelt
      preciseLots[i] = Units * unitSize;                                               // perfectLots zunächst auf Vielfaches von MODE_LOTSTEP abrunden
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

      // (2.5) Lotsize validieren
      if (GT(roundedLots[i], maxLot)) return(catch("onStart(3)   Too large trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(roundedLots[i], ".+") +" lot (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));

      // (2.6) bei zu geringer Equity Leverage erhöhen und Details für spätere Warnung hinterlegen
      if (LT(roundedLots[i], minLot)) {
         roundedLots[i]  = minLot;
         overLeverageMsg = StringConcatenate(overLeverageMsg, "\n", GetSymbolName(symbols[i]), ": ", NumberToStr(roundedLots[i], ".+"), " instead of ", preciseLots[i], " lot");
      }
   }

   // (2.7) bei Leverageüberschreitung ausdrückliche Bestätigung einholen
   if (StringLen(overLeverageMsg) > 0) {
      PlaySound("notify.wav");
      button = MessageBox("Not enough money.\nThe following positions will over-leverage:\n"+ overLeverageMsg +"\n\nContinue?", __NAME__, MB_ICONWARNING|MB_OKCANCEL);
      if (button != IDOK)
         return(catch("onStart(4)"));
   }


   // (3) Directions der Teilpositionen bestimmen
   for (i=0; i < 6; i++) {
      if (StringStartsWith(symbols[i], lfxCurrency)) directions[i]  = direction;
      else                                           directions[i]  = direction ^ 1;   // 0=>1, 1=>0
      if (lfxCurrency == "JPY")                      directions[i] ^= 1;               // JPY ist invers notiert
   }


   // (4) finale Sicherheitsabfrage
   PlaySound("notify.wav");
   button = MessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to "+ StringToLower(OperationTypeDescription(direction)) +" "+ NumberToStr(Units, ".+") + ifString(Units==1, " unit ", " units ") + lfxCurrency +"?", __NAME__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("onStart(5)"));


   // (5) Lock auf die neue Position (MagicNumber) setzen, damit andere Indikatoren/Charts nicht schon vor Ende von LFX.OpenPosition Teilpositionen verarbeiten
   //     TODO: Fehler in Counter und damit in MagicNumber, wenn 2 Positionen gleichzeitig geöffnet werden (2 x CHF.3)
   int counter     = GetPositionCounter() + 1;   if (!counter)     return(catch("onStart(6)"));    // Abbruch, falls GetPositionCounter() oder
   int magicNumber = CreateMagicNumber(counter); if (!magicNumber) return(catch("onStart(7)"));    // CreateMagicNumber() Fehler melden
   string comment  = lfxCurrency +"."+ counter;
   string mutex    = "mutex.LFX.#"+ magicNumber;
   if (!AquireLock(mutex, true))
      return(SetLastError(stdlib_GetLastError()));


   // (6) Order ausführen und dabei Gesamt-OpenPrice berechnen
   double openPrice = 1.0;

   for (i=0; i < 6; i++) {
      double   price       = NULL;
      double   slippage    = 0.1;
      double   sl          = NULL;
      double   tp          = NULL;
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;
      int      oeFlags     = NULL;

      if (IsError(stdlib_GetLastError())) return(SetLastError(stdlib_GetLastError())); // vor Trade-Request alle evt. aufgetretenen Fehler abfangen
      if (IsError(catch("onStart(8)")))   return(last_error);

      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      tickets[i] = OrderSendEx(symbols[i], directions[i], roundedLots[i], price, slippage, sl, tp, comment, magicNumber, expiration, markerColor, oeFlags, oe);
      if (tickets[i] == -1)
         return(SetLastError(stdlib_GetLastError()));

      if (StringStartsWith(symbols[i], lfxCurrency)) openPrice *= oe.OpenPrice(oe);
      else                                           openPrice /= oe.OpenPrice(oe);
   }
   openPrice = MathPow(openPrice, 1.0/7);
   if (lfxCurrency == "JPY")
      openPrice = 1/openPrice;                     // JPY ist invers notiert


   // (7) Daten in openPositions.* aktualisieren
   ArrayPushInt(openPositions.instanceId, LFX.InstanceId(magicNumber));
   openPositions.maxCounter = counter;


   // (8) Logmessage ausgeben
   int    lfxDigits =    ifInt(lfxCurrency=="JPY",    3,     5 );
   string lfxFormat = ifString(lfxCurrency=="JPY", ".2'", ".4'");
          openPrice = NormalizeDouble(openPrice, lfxDigits);
   if (__LOG) log("onStart(9)   "+ comment +" "+ ifString(direction==OP_BUY, "long", "short") +" position opened at "+ NumberToStr(openPrice, lfxFormat));


   // (9) LFX-Order speichern
   if (!LFX.WriteTicket(magicNumber, "#"+ counter, direction, Units, TimeGMT(), equity, openPrice, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TimeGMT()))
      return(last_error);


   // (10) Lock auf die neue Position wieder freigeben
   if (!ReleaseLock(mutex))
      return(SetLastError(stdlib_GetLastError()));

   return(last_error);
}


/**
 * Gibt den Positionszähler der letzten offenen Position im aktuellen Instrument zurück.
 *
 * @return int - Zähler oder -1, falls ein Fehler auftrat
 */
int GetPositionCounter() {
   // Sicherstellen, daß die vorhandenen offenen Positionen eingelesen wurden
   if (!LFX.ReadInstanceIdsCounter(lfxCurrency, openPositions.instanceId, openPositions.maxCounter))
      return(-1);
   return(openPositions.maxCounter);
}


/**
 * Generiert aus den internen Daten einen Wert für OrderMagicNumber().
 *
 * @param  int counter - Position-Zähler, für den eine MagicNumber erzeugt werden soll
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int counter) {
   if (counter < 1)
      return(_NULL(catch("CreateMagicNumber()   invalid parameter counter = "+ counter, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int iStrategy = STRATEGY_ID & 0x3FF << 22;                        // 10 bit (Bits 23-32)
   int iCurrency = GetCurrencyId(lfxCurrency) & 0xF << 18;           //  4 bit (Bits 19-22)
   int iUnits    = Round(Units * 10) & 0xF << 14;                    //  4 bit (Bits 15-18)
   int iInstance = GetCreateInstanceId() & 0x3FF << 4;               // 10 bit (Bits  5-14)
   int pCounter  = counter & 0xF;                                    //  4 bit (Bits  1-4 )

   if (!iInstance)
      return(NULL);
   return(iStrategy + iCurrency + iUnits + iInstance + pCounter);
}


/**
 * Gibt die aktuelle Instanz-ID zurück. Existiert noch keine, wird eine neue erzeugt.
 *
 * @return int - Instanz-ID im Bereich 1-1023 (10 bit) oder NULL, falls ein Fehler auftrat
 */
int GetCreateInstanceId() {
   static int id;

   if (!id) {
      // sicherstellen, daß die offenen Positionen eingelesen wurden
      if (!LFX.ReadInstanceIdsCounter(lfxCurrency, openPositions.instanceId, openPositions.maxCounter))
         return(NULL);

      MathSrand(GetTickCount());
      while (!id) {
         id = MathRand();
         while (id > 1023) {
            id >>= 1;
         }
         if (IntInArray(openPositions.instanceId, id))               // sicherstellen, daß alle aktuell benutzten Instanz-ID's eindeutig sind
            id = 0;
      }
   }
   return(id);
}

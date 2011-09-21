/**
 * Öffnet eine Position in einer der LiteForex-Indizes.
 *
 *
 *  Regeln:
 *  -------
 *  - automatisierter StopLoss aller Positionen bei 50% von MaxEquity
 *  - maximal 2 offene Positionen
 *  - weitere Positionen im selben Instrument werden erst nach Tagesende eröffnet
 *  - Positionsgrößen: 0.7 - 1.0 - 1.3
 *  - nach Gewinnen ist ein MA(Equity) Ausgangsbasis für neue Positionen
 *  - zu jeder Position wird eine TakeProfit-Order in den Markt gelegt
 *  - Positionen möglichst am Bollinger-Band eingehen
 *  - 25% aller Gewinne werden sofort aus dem Markt genommen (Reserve für Stop-Out-Fall)
 *
 *
 *  TODO:
 *  -----
 *  - Fehler im Counter, wenn 2 Positionen gleichzeitig eröffnet werden (2 x CHF.3)
 *  - Anzeige des Stoploss-Levels und des Stop-Out-Levels des Brokers
 *  - Berechnung des ClosePrice automatisieren
 *  - Anzeige der Positionen im SIG-Account implementieren
 *  - Buy-/Sell-Limits implementieren
 *  - TakeProfit-Limits implementieren
 *  - Breakeven-Orders implementieren
 *
 *
 *  Format von MagicNumber:
 *  -----------------------
 *  Strategy-Id:   10 bit (Bit 23-32) => Bereich 0-1023 (immer größer 100)
 *  Currency-Id:    4 bit (Bit 19-22) => Bereich 0-15
 *  Units:          5 bit (Bit 14-18) => Bereich 0-31   (Vielfaches von 0.1 zwischen 0.1 und 1.5)
 *  Instance-ID:    9 bit (Bit  5-13) => Bereich 0-511  (immer größer 0)
 *  Counter:        4 bit (Bit  1-4 ) => Bereich 0-15   (immer größer 0)
 */
#include <stdlib.mqh>
#include <win32api.mqh>


#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Currency  = "";             // AUD | CAD | CHF | EUR | GBP | JPY | USD
extern string Direction = "long";         // buy | sell | long | short
extern double Units     = 1.0;            // Vielfaches von 0.1 im Bereich 0.1-1.5

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int Strategy.Id = 102;                    // eindeutige ID der Strategie (Bereich 101-1023)

int    iDirection;
double leverage;

int    positions.magic   [];              // Daten der aktuell offenen Positionen dieser Strategie
string positions.currency[];
double positions.units   [];
int    positions.instance[];
int    positions.counter [];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);


   // -- Beginn - Parametervalidierung
   // Currency
   string value = StringToUpper(StringTrim(Currency));
   string currencies[] = { "AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "USD" };
   if (!StringInArray(value, currencies))
      return(catch("init(1)  Invalid input parameter Currency = \""+ Currency +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   Currency = value;
   // Direction
   value = StringToUpper(StringTrim(Direction));
   if (value == "")
      return(catch("init(2)  Invalid input parameter Direction = \""+ Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   switch (StringGetChar(value, 0)) {
      case 'B':
      case 'L': Direction = "long";  iDirection = OP_BUY;  break;
      case 'S': Direction = "short"; iDirection = OP_SELL; break;
      default:
         return(catch("init(3)  Invalid input parameter Direction = \""+ Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
   }
   // Units
   if (LT(Units, 0.1) || GT(Units, 1.5))
      return(catch("init(4)  Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (needs to be between 0.1 and 1.5)", ERR_INVALID_INPUT_PARAMVALUE));
   if (NE(MathModFix(Units, 0.1), 0))
      return(catch("init(5)  Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (needs to be a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   Units = NormalizeDouble(Units, 1);
   // -- Ende - Parametervalidierung


   // Leverage-Konfiguration einlesen
   leverage = GetGlobalConfigDouble("Leverage", "CurrencyBasket", 0);
   if (LT(leverage, 1))
      return(catch("init(6)  Invalid configuration value [Leverage] CurrencyBasket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   return(catch("init(7)"));
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

   string symbols   [6];
   double lots      [6];
   int    directions[6];
   int    tickets   [6];


   // (1) Pairs bestimmen
   if      (Currency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD"; }
   else if (Currency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD"; }
   else if (Currency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF"; }
   else if (Currency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD"; }
   else if (Currency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD"; }
   else if (Currency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY"; }
   else if (Currency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY"; }


   // (2) Lotsizes berechnen
   double equity = AccountEquity() - AccountCredit();

   for (int retry, i=0; i < 6; i++) {
      double bid       = MarketInfo(symbols[i], MODE_BID      );
      double tickSize  = MarketInfo(symbols[i], MODE_TICKSIZE );
      double tickValue = MarketInfo(symbols[i], MODE_TICKVALUE);
      double minLot    = MarketInfo(symbols[i], MODE_MINLOT   );
      double maxLot    = MarketInfo(symbols[i], MODE_MAXLOT   );
      double lotStep   = MarketInfo(symbols[i], MODE_LOTSTEP  );

      int error = GetLastError();                     // auf ERR_UNKNOWN_SYMBOL prüfen
      if (error != NO_ERROR)
         return(catch("start(1)   \""+ symbols[i] +"\"", error));

      // auf ERR_INVALID_MARKETINFO prüfen
      string errorMsg = "";
      if      (LT(bid, 0.5)          || GT(bid, 150)      ) errorMsg = StringConcatenate("Bid(\""      , symbols[i], "\") = ", NumberToStr(bid      , ".+"));
      else if (LT(tickSize, 0.00001) || GT(tickSize, 0.01)) errorMsg = StringConcatenate("TickSize(\"" , symbols[i], "\") = ", NumberToStr(tickSize , ".+"));
      else if (LT(tickValue, 0.5)    || GT(tickValue, 20) ) errorMsg = StringConcatenate("TickValue(\"", symbols[i], "\") = ", NumberToStr(tickValue, ".+"));
      else if (LT(minLot, 0.01)      || GT(minLot, 0.1)   ) errorMsg = StringConcatenate("MinLot(\""   , symbols[i], "\") = ", NumberToStr(minLot   , ".+"));
      else if (LT(maxLot, 50)                             ) errorMsg = StringConcatenate("MaxLot(\""   , symbols[i], "\") = ", NumberToStr(maxLot   , ".+"));
      else if (LT(lotStep, 0.01)     || GT(lotStep, 0.1)  ) errorMsg = StringConcatenate("LotStep(\""  , symbols[i], "\") = ", NumberToStr(lotStep  , ".+"));

      // ERR_INVALID_MARKETINFO behandeln
      if (StringLen(errorMsg) > 0) {
         if (retry < 3) {                                                                       // 3 stille Versuche, korrekte Werte zu lesen
            Sleep(200);
            i = -1;
            retry++;
            continue;
         }
         PlaySound("notify.wav");                                                               // danach Bestätigung per Dialog
         int button = MessageBox("Invalid MarketInfo() data.\n\n"+ errorMsg, __SCRIPT__, MB_ICONINFORMATION|MB_RETRYCANCEL);
         if (button == IDRETRY) {
            i = -1;
            continue;
         }
         return(catch("start(2)"));
      }

      double lotValue = bid / tickSize * tickValue;                                             // Lotvalue in Account-Currency
      double unitSize = equity / lotValue * leverage;                                           // equity/lotValue entspricht einem Hebel von 1, dieser Wert wird mit leverage gehebelt
      lots[i] = Units * unitSize;
      lots[i] = NormalizeDouble(MathRound(lots[i]/lotStep) * lotStep, CountDecimals(lotStep));  // auf Vielfaches von MODE_LOTSTEP runden

      if (LT(lots[i], minLot))
         return(catch("start(3)   Invalid trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(lots[i], ".+") +"  (minLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));
      if (GT(lots[i], maxLot))
         return(catch("start(4)   Invalid trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(lots[i], ".+") +"  (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));
   }


   // (3) Directions bestimmen
   for (i=0; i < 6; i++) {
      if (StringStartsWith(symbols[i], Currency)) directions[i]  = iDirection;
      else                                        directions[i]  = iDirection ^ 1;              // 0=>1, 1=>0
      if (Currency == "JPY")                      directions[i] ^= 1;                           // JPY ist invers notiert
   }


   // (4) Sicherheitsabfrage
   PlaySound("notify.wav");
   button = MessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to "+ StringToLower(OperationTypeDescription(iDirection)) +" "+ NumberToStr(Units, ".+") + ifString(EQ(Units, 1), " unit ", " units ") + Currency +"?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("start(5)"));


   // (5) Daten bereits offener Positionen einlesen
   if (!ReadOpenPositions())
      return(last_error);


   // (6) neue Position öffnen
   int    counter     = GetPositionCounter() + 1;
   string comment     = Currency +"."+ counter +"/"+ DoubleToStr(Units, 1);
   int    magicNumber = CreateMagicNumber(counter);

   for (i=0; i < 6; i++) {
      double   price       = NULL;
      double   slippage    = 0.1;
      double   sl          = NULL;
      double   tp          = NULL;
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;

      if (stdlib_PeekLastError() != NO_ERROR) return(processError(stdlib_PeekLastError()));  // vor Orderaufgabe alle aufgetretenen Fehler abfangen
      if (catch("start(6)")      != NO_ERROR) return(last_error);

      tickets[i] = OrderSendEx(symbols[i], directions[i], lots[i], price, slippage, sl, tp, comment, magicNumber, expiration, markerColor);
      if (tickets[i] == -1)
         return(processError(stdlib_PeekLastError()));
   }


   // (7) OpenPrice der neuen Position berechnen
   double openPrice = 1.0;

   for (i=0; i < 6; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) {
         error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("start(7)", error));
      }
      if (StringStartsWith(OrderSymbol(), Currency)) openPrice *= OrderOpenPrice();
      else                                           openPrice /= OrderOpenPrice();
   }
   openPrice = MathPow(openPrice, 1.0/7);
   if (Currency == "JPY")
      openPrice = 1/openPrice;                                       // JPY ist invers notiert


   // (8) Logmessage ausgeben
   int    lfxDigits = ifInt(Currency=="JPY", 3, 5);
   string lfxFormat = ifString(Currency=="JPY", ".2'", ".4'");
          openPrice = NormalizeDouble(openPrice, lfxDigits);
   log("start()   "+ comment +" "+ ifString(iDirection==OP_BUY, "long", "short") +" position opened at "+ NumberToStr(openPrice, lfxFormat));


   // (9) Position in ...\SIG\external_positions.ini eintragen
   string file    = TerminalPath() +"\\experts\\files\\SIG\\external_positions.ini";
   string section = ShortAccountCompany() +"."+ AccountNumber();
   string key     = Currency +"."+ counter;
   string value   = TimeToStr(OrderOpenTime(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) +" | "+ ifString(iDirection==OP_BUY, "L", "S") +" | "+ DoubleToStr(Units, 1) +" | "+ DoubleToStr(openPrice, lfxDigits);

   if (!WritePrivateProfileStringA(section, key, value, file))
      return(catch("start(8)   kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\") failed", ERR_WINDOWS_ERROR));

   return(catch("start(9)"));
}


/**
 * Liest die Daten der offenen Positionen dieser Strategie ein.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadOpenPositions() {
   ArrayResize(positions.magic   , 0);
   ArrayResize(positions.currency, 0);
   ArrayResize(positions.units   , 0);
   ArrayResize(positions.instance, 0);
   ArrayResize(positions.counter , 0);

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
         continue;

      // alle offenen Positionen dieser Strategie finden und Daten einlesen
      if (IsMyOrder()) {
         if (OrderType()!=OP_BUY) /*&&*/ if (OrderType()!=OP_SELL)
            continue;
         if (IntInArray(OrderMagicNumber(), positions.magic))
            continue;
         ArrayPushInt   (positions.magic   ,              OrderMagicNumber() );
         ArrayPushString(positions.currency, LFX.Currency(OrderMagicNumber()));
         ArrayPushDouble(positions.units   , LFX.Units   (OrderMagicNumber()));
         ArrayPushInt   (positions.instance, LFX.Instance(OrderMagicNumber()));
         ArrayPushInt   (positions.counter , LFX.Counter (OrderMagicNumber()));
      }
   }

   return(catch("ReadOpenPositions()")==NO_ERROR);
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört.
 *
 * @return bool
 */
bool IsMyOrder() {
   return(StrategyId(OrderMagicNumber()) == Strategy.Id);
}


/**
 * Generiert aus den internen Daten einen Wert für OrderMagicNumber().
 *
 * @param  int counter - Position-Zähler, für den eine MagicNumber erzeugt werden soll
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int counter) {
   if (counter < 1) {
      catch("CreateMagicNumber(1)   Invalid parameter counter = "+ counter, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   int strategy  = Strategy.Id & 0x3FF << 22;                        // 10 bit (Bits 23-32)
   int iCurrency = GetCurrencyId(Currency) & 0xF << 18;              //  4 bit (Bits 19-22)
   int iUnits    = MathRound(Units * 10) +0.1;                       // (int) double
       iUnits    = iUnits & 0x1F << 13;                              //  5 bit (Bits 14-18)
   int instance  = GetInstance() & 0x1FF << 4;                       //  9 bit (Bits  5-13)
   int pCounter  = counter & 0xF;                                    //  4 bit (Bits  1-4 )

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("CreateMagicNumber(2)", error);
      return(-1);
   }
   return(strategy + iCurrency + iUnits + instance + pCounter);
}


/**
 * Gibt den Positionszähler der letzten offenen Position im aktuellen Instrument zurück.
 *
 * @return int - Anzahl
 */
int GetPositionCounter() {
   int counter, size=ArraySize(positions.currency);

   for (int i=0; i < size; i++) {
      if (positions.currency[i] == Currency) {
         if (positions.counter[i] > counter)
            counter = positions.counter[i];
      }
   }
   return(counter);
}


/**
 * Gibt die aktuelle Instanz-ID zurück. Existiert noch keine, wird eine neue erzeugt.
 *
 * @return int - Instanz-ID im Bereich 1-511 (9 bit)
 */
int GetInstance() {
   static int id;

   if (id == 0) {
      MathSrand(GetTickCount());
      while (id == 0) {
         id = MathRand();
         while (id > 511) {
            id >>= 1;
         }
         if (IntInArray(id, positions.instance))      // sicherstellen, daß die Instanz-ID's der im Moment offenen Positionen eindeutig sind
            id = 0;
      }
   }
   return(id);
}

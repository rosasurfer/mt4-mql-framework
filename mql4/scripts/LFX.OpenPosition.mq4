/**
 * Öffnet eine Position in einer der LiteForex-Indizes.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Currency  = "";             // AUD | CAD | CHF | EUR | GBP | JPY | USD
extern string Direction = "long";         // buy | sell | long | short
extern double Units     = 1.0;            // Vielfaches von 0.1 im Bereich 0.1-3.0

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int Strategy.uniqueId = 102;              // eindeutige ID der Strategie (im Bereich 0-1023)

string currency;
int    direction;
double units;
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


   // (1) Parametervalidierung
   // Open.Currency
   currency = StringToUpper(StringTrim(Currency));
   string currencies[] = { "AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "USD" };
   if (!StringInArray(currency, currencies))
      return(catch("init(1)  Invalid input parameter Currency = \""+ Currency +"\"", ERR_INVALID_INPUT_PARAMVALUE));

   // Open.Direction
   string strDirection = StringToUpper(StringTrim(Direction));
   if (StringLen(strDirection) > 0) {
      switch (StringGetChar(strDirection, 0)) {
         case 'B':
         case 'L': direction = OP_BUY;  break;
         case 'S': direction = OP_SELL; break;
         default:
            return(catch("init(2)  Invalid input parameter Direction = \""+ Direction +"\"", ERR_INVALID_INPUT_PARAMVALUE));
      }
   }

   // Open.Units
   if (LT(Units, 0.1) || GT(Units, 3))
      return(catch("init(3)  Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (needs to be between 0.1 and 3.0)", ERR_INVALID_INPUT_PARAMVALUE));
   if (NE(MathModFix(Units, 0.1), 0))
      return(catch("init(4)  Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (needs to be a multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   units = NormalizeDouble(Units, 1);


   // (2) Leverage-Konfiguration einlesen
   leverage = GetGlobalConfigDouble("Leverage", "CurrencyBasket", 0);
   if (LT(leverage, 1))
      return(catch("init(5)  Invalid configuration value [Leverage] CurrencyBasket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

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

   string symbols   [6];
   double lots      [6];
   int    directions[6];
   double margin;


   // (1) Pairs bestimmen
   if      (currency == "AUD") { symbols[0] = "AUDCAD"; symbols[1] = "AUDCHF"; symbols[2] = "AUDJPY"; symbols[3] = "AUDUSD"; symbols[4] = "EURAUD"; symbols[5] = "GBPAUD"; }
   else if (currency == "CAD") { symbols[0] = "AUDCAD"; symbols[1] = "CADCHF"; symbols[2] = "CADJPY"; symbols[3] = "EURCAD"; symbols[4] = "GBPCAD"; symbols[5] = "USDCAD"; }
   else if (currency == "CHF") { symbols[0] = "AUDCHF"; symbols[1] = "CADCHF"; symbols[2] = "CHFJPY"; symbols[3] = "EURCHF"; symbols[4] = "GBPCHF"; symbols[5] = "USDCHF"; }
   else if (currency == "EUR") { symbols[0] = "EURAUD"; symbols[1] = "EURCAD"; symbols[2] = "EURCHF"; symbols[3] = "EURGBP"; symbols[4] = "EURJPY"; symbols[5] = "EURUSD"; }
   else if (currency == "GBP") { symbols[0] = "EURGBP"; symbols[1] = "GBPAUD"; symbols[2] = "GBPCAD"; symbols[3] = "GBPCHF"; symbols[4] = "GBPJPY"; symbols[5] = "GBPUSD"; }
   else if (currency == "JPY") { symbols[0] = "AUDJPY"; symbols[1] = "CADJPY"; symbols[2] = "CHFJPY"; symbols[3] = "EURJPY"; symbols[4] = "GBPJPY"; symbols[5] = "USDJPY"; }
   else if (currency == "USD") { symbols[0] = "AUDUSD"; symbols[1] = "EURUSD"; symbols[2] = "GBPUSD"; symbols[3] = "USDCAD"; symbols[4] = "USDCHF"; symbols[5] = "USDJPY"; }


   // (2) Lotsizes berechnen
   double equity = AccountEquity()-AccountCredit();

   for (int i=0; i < 6; i++) {
      double bid            = MarketInfo(symbols[i], MODE_BID           );
      double tickSize       = MarketInfo(symbols[i], MODE_TICKSIZE      );
      double tickValue      = MarketInfo(symbols[i], MODE_TICKVALUE     );
      double minLot         = MarketInfo(symbols[i], MODE_MINLOT        );
      double lotStep        = MarketInfo(symbols[i], MODE_LOTSTEP       );
      double maxLot         = MarketInfo(symbols[i], MODE_MAXLOT        );
      double marginRequired = MarketInfo(symbols[i], MODE_MARGINREQUIRED);

      int error = GetLastError();
      if (error != NO_ERROR)
         return(catch("start(1)   \""+ symbols[i] +"\"", error));

      // ERR_MARKETINFO_UPDATE abfangen (erst nach Auslesen aller Werte)
      string errorMsg = "";
      if (LT(bid, 0.5)            || GT(bid, 150)            ) errorMsg = StringConcatenate(errorMsg, "Bid(\""           , symbols[i], "\") = ", NumberToStr(bid           , ".+"), NL);
      if (LT(tickSize, 0.00001)   || GT(tickSize, 0.01)      ) errorMsg = StringConcatenate(errorMsg, "TickSize(\""      , symbols[i], "\") = ", NumberToStr(tickSize      , ".+"), NL);
      if (LT(tickValue, 0.5)      || GT(tickValue, 20)       ) errorMsg = StringConcatenate(errorMsg, "TickValue(\""     , symbols[i], "\") = ", NumberToStr(tickValue     , ".+"), NL);
      if (LT(minLot, 0.01)        || GT(minLot, 0.1)         ) errorMsg = StringConcatenate(errorMsg, "MinLot(\""        , symbols[i], "\") = ", NumberToStr(minLot        , ".+"), NL);
      if (LT(lotStep, 0.01)       || GT(lotStep, 0.1)        ) errorMsg = StringConcatenate(errorMsg, "LotStep(\""       , symbols[i], "\") = ", NumberToStr(lotStep       , ".+"), NL);
      if (LT(maxLot, 50)                                     ) errorMsg = StringConcatenate(errorMsg, "MaxLot(\""        , symbols[i], "\") = ", NumberToStr(maxLot        , ".+"), NL);
      if (LT(marginRequired, 200) || GT(marginRequired, 1500)) errorMsg = StringConcatenate(errorMsg, "MarginRequired(\"", symbols[i], "\") = ", NumberToStr(marginRequired, ".+"), NL);
      errorMsg = StringTrim(errorMsg);

      // ERR_MARKETINFO_UPDATE behandeln
      if (StringLen(errorMsg) > 0) {
         PlaySound("notify.wav");
         int button = MessageBox("Instrument data in update state.\n\n"+ errorMsg, __SCRIPT__, MB_ICONINFORMATION|MB_RETRYCANCEL);
         if (button == IDRETRY) {
            i = -1;
            continue;
         }
         return(catch("start(2)"));
      }

      double lotValue = bid / tickSize * tickValue;                                             // Lotvalue in Account-Currency
      double unitSize = equity / lotValue * leverage;                                           // equity / lotValue entspricht einem Hebel von 1, dies wird mit leverage gehebelt
      lots[i] = units * unitSize;
      lots[i] = NormalizeDouble(MathRound(lots[i]/lotStep) * lotStep, CountDecimals(lotStep));  // auf Vielfaches von MODE_LOTSTEP runden

      if (LT(lots[i], minLot))
         return(catch("start(3)   Invalid trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(lots[i], ".+") +"  (minLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));
      if (GT(lots[i], maxLot))
         return(catch("start(4)   Invalid trade volume for "+ GetSymbolName(symbols[i]) +": "+ NumberToStr(lots[i], ".+") +"  (maxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_TRADE_VOLUME));

      margin += lots[i] * marginRequired;                                                       // required margin berechnen
   }


   // (3) Directions bestimmen
   for (i=0; i < 6; i++) {
      if (StringStartsWith(symbols[i], currency)) directions[i]  = direction;
      else                                        directions[i]  = direction ^ 1;   // 0=>1, 1=>0
      if (currency == "JPY")                      directions[i] ^= 1;               // JPY ist invers notiert
   }


   // (4) Sicherheitsabfrage
   PlaySound("notify.wav");
   button = MessageBox(ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to "+ StringToLower(OperationTypeDescription(direction)) +" "+ NumberToStr(units, ".+") + ifString(EQ(units, 1), " unit ", " units ") + currency +"?\n\n(required margin: "+ DoubleToStr(margin, 2) +")", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
   if (button != IDOK)
      return(catch("start(5)"));


   // (5) Daten bereits offener Positionen einlesen
   if (!ReadOpenPositionStatus())
      return(last_error);


   // (6) neue Position öffnen
   for (i=0; i < 6; i++) {
      int digits    = MarketInfo(symbols[i], MODE_DIGITS) + 0.1;                 // +0.1 fängt evt. Präzisionsfehler beim Casten ab: (int) double
      int pipDigits = digits & (~1);
      int counter   = GetPositionCounter() + 1;

      double   price       = NULL;
      int      slippage    = ifInt(digits==pipDigits, 0, 1);                     // keine Slippage bei 2- oder 4-Digits-Brokern
      double   sl          = NULL;
      double   tp          = NULL;
      string   comment     = currency +"."+ counter +"/"+ DoubleToStr(units, 1);
      int      magicNumber = CreateMagicNumber(counter);
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;

      if (stdlib_PeekLastError() != NO_ERROR) return(stdlib_PeekLastError());    // vor Orderaufgabe alle evt. aufgetretenen Fehler abfangen
      if (catch("start(6)")      != NO_ERROR) return(last_error);

      int ticket = OrderSendEx(symbols[i], directions[i], lots[i], price, slippage, sl, tp, comment, magicNumber, expiration, markerColor);
      if (ticket == -1)
         return(stdlib_PeekLastError());
   }

   return(catch("start(7)"));
}


/**
 * Liest die Daten bereits offener Positionen ein.
 *
 * @return bool - Erfolgsstatus
 */
bool ReadOpenPositionStatus() {
   ArrayResize(positions.magic   , 0);
   ArrayResize(positions.currency, 0);
   ArrayResize(positions.units   , 0);
   ArrayResize(positions.instance, 0);
   ArrayResize(positions.counter , 0);

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wird in einem anderen Thread eine offene Order entfernt
         continue;

      // alle Positionen dieser Strategie finden und Daten einlesen
      if (IsMyOrder()) {
         if (IntInArray(OrderMagicNumber(), positions.magic))
            continue;

         int currency = OrderMagicNumber() >> 17 & 0x1F;             //  5 bit | in MagicNumber: Bits 18-22
         int units    = OrderMagicNumber() >> 12 & 0x1F;             //  5 bit | in MagicNumber: Bits 13-17
         int instance = OrderMagicNumber() >> 3 & 0x1FF;             //  9 bit | in MagicNumber: Bits  4-12
         int counter  = OrderMagicNumber() & 0x7;                    //  3 bit | in MagicNumber: Bits  1-3

         ArrayPushInt   (positions.magic   , OrderMagicNumber()   );
         ArrayPushString(positions.currency, GetCurrency(currency));
         ArrayPushDouble(positions.units   , units/10.0           );
         ArrayPushInt   (positions.instance, instance             );
         ArrayPushInt   (positions.counter , counter              );
      }
   }
   return(catch("ReadOpenPositionStatus()")==NO_ERROR);
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört.
 *
 * @return bool
 */
bool IsMyOrder() {
   if (OrderType()==OP_BUY || OrderType()==OP_SELL)
      return(OrderMagicNumber() >> 22 == Strategy.uniqueId);
   return(false);
}


/**
 * Generiert aus den internen Daten einen Wert für OrderMagicNumber().
 *
 * @param  int counter - Position-Zähler, für den eine MagicNumber erteugt werden soll
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int counter) {
   if (counter < 1) {
      catch("CreateMagicNumber(1)   Invalid parameter counter = "+ counter, ERR_INVALID_FUNCTION_PARAMVALUE);
      return(-1);
   }
   int strategy   = Strategy.uniqueId & 0x3FF << 22;                 // 10 bit (Bits größer 10 nullen und auf 32 Bit erweitern)  | in MagicNumber: Bits 23-32
   int currencyId = GetCurrencyId(currency) & 0x1F << 17;            //  5 bit (Bits größer 5 nullen und auf 22 Bit erweitern)   | in MagicNumber: Bits 18-22
   int iUnits     = MathRound(units * 10) + 0.1;                     //    +0.1 fängt evt. Präzisionsfehler beim Casten ab
       iUnits     = iUnits & 0x1F << 12;                             //  5 bit (Bits größer 5 nullen und auf 17 Bit erweitern)   | in MagicNumber: Bits 13-17
   int instance   = GetInstanceId() & 0x1FF << 3;                    //  9 bit (Bits größer 9 nullen und auf 12 Bit erweitern)   | in MagicNumber: Bits  4-12
   int pCounter   = counter & 0x7;                                   //  3 bit (Bits größer 3 nullen)                            | in MagicNumber: Bits  1-3

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("CreateMagicNumber(2)", error);
      return(-1);
   }
   return(strategy + currencyId + iUnits + instance + pCounter);
}


/**
 * Gibt den Positionszähler der letzten offenen Position im aktuellen Instrument zurück.
 *
 * @return int - Anzahl
 */
int GetPositionCounter() {
   int counter, size=ArraySize(positions.currency);

   for (int i=0; i < size; i++) {
      if (positions.currency[i] == currency) {
         if (positions.counter[i] > counter)
            counter = positions.counter[i];
      }
   }
   return(counter);
}


/**
 * Gibt die aktuelle Instanz-ID zurück. Existiert noch keine, wird eine neue erzeugt.
 *
 * @return int - Instanz-ID im Bereich 1-511 (9 bit), zusammen mit der Currency-ID (5 bit) und dem Positionszähler (3 bit) ist das ausreichend
 */
int GetInstanceId() {
   static int id;

   if (id == 0) {
      MathSrand(GetTickCount());
      while (id == 0) {
         id = MathRand();
         while (id > 511) {
            id >>= 1;
         }
         if (IntInArray(id, positions.instance))   // zusätzlich sicherstellen, daß wir im selben Moment nie zwei gleiche Instanz-ID's benutzen
            id = 0;
      }
   }
   return(id);
}

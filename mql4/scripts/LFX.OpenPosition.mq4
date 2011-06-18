/**
 * Öffnet eine Position in einer der LiteForex-Indizes.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

//extern string Currency  = "";                   // AUD | CAD | CHF | EUR | GBP | JPY | USD
//extern string Direction = "[ Long | Short ]";   // Buy | Long | Sell | Short
//extern double Units     = 1.0;                  // Vielfaches von 0.1 im Bereich 0.1-3.0
extern string Currency  = "CHF";
extern string Direction = "Long";
extern double Units     = 0.9;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int Strategy.uniqueId = 102;                       // eindeutige ID der Strategie (im Bereich 0-1023)


string currency;
int    direction;
double units;
double leverage;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   // Parameter auswerten

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
      return(catch("init(4)  Invalid input parameter Units = "+ NumberToStr(Units, ".+") +" (needs to be multiple of 0.1)", ERR_INVALID_INPUT_PARAMVALUE));
   units = NormalizeDouble(Units, 1);

   // Leverage-Konfiguration
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
      double bid       = MarketInfo(symbols[i], MODE_BID      );
      double tickSize  = MarketInfo(symbols[i], MODE_TICKSIZE );
      double tickValue = MarketInfo(symbols[i], MODE_TICKVALUE);

      int error = GetLastError();
      if (error != NO_ERROR)
         return(catch("start(1)   \""+ symbols[i] +"\"", error));

      double lotValue = bid / tickSize * tickValue;                     // Lotvalue in Account-Currency
      double unitSize = equity / lotValue * leverage;                   // equity / lotValue entspricht einem Hebel von 1
      lots[i] = units * unitSize;                                       // Account-Equity wird mit leverage gehebelt

      double lotStep = MarketInfo(symbols[i], MODE_LOTSTEP);            // auf Vielfaches von MODE_LOTSTEP runden
      lots[i] = NormalizeDouble(MathRound(lots[i]/lotStep) * lotStep, CountDecimals(lotStep));
   }


   // (3) Directions bestimmen
   for (i=0; i < 6; i++) {
      if (StringStartsWith(symbols[i], currency)) directions[i] =  direction;
      else                                        directions[i] = ~direction & 1;   // 0=>1, 1=>0
   }


   // (4) Sicherheitsabfrage
   PlaySound("notify.wav");
   int answer = MessageBox(ifString(!IsDemo(), "Live Account\n\n", "") +"Do you really want to "+ StringToLower(OperationTypeDescription(direction)) +" "+ NumberToStr(units, ".+") + ifString(EQ(units, 1), " unit ", " units ") + currency +"?", __SCRIPT__, MB_ICONQUESTION|MB_OKCANCEL);
   if (answer != IDOK)
      return(catch("start(2)"));


   // (5) Positionen öffnen
   for (i=0; i < 6; i++) {
      int digits    = MarketInfo(symbols[i], MODE_DIGITS) + 0.1;                 // +0.1 fängt evt. Präzisionsfehler beim Casten ab: (int) double
      int pipDigits = digits - digits%2;

      double   price       = NULL;
      int      slippage    = ifInt(digits==pipDigits, 0, 1);                     // keine Slippage bei 4-Digits-Brokern
      double   sl          = NULL;
      double   tp          = NULL;
      int      counter     = GetPositionCounter() + 1;
      string   comment     = "L."+ currency +"-Index."+ counter;
      int      magicNumber = CreateMagicNumber(counter);
      datetime expiration  = NULL;
      color    markerColor = CLR_NONE;

      if (stdlib_PeekLastError() != NO_ERROR) return(stdlib_PeekLastError());    // vor Orderaufgabe alle evt. aufgetretenen Fehler abfangen
      if (catch("start(3)")      != NO_ERROR) return(last_error);

      int ticket = OrderSendEx(symbols[i], directions[i], lots[i], price, slippage, sl, tp, comment, magicNumber, expiration, markerColor);
      if (ticket == -1)
         return(stdlib_PeekLastError());
   }

   return(catch("start(4)"));
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
   int strategy   = Strategy.uniqueId & 0x3FF << 22;        // 10 bit (Bits größer 10 nullen und auf 32 Bit erweitern)  | in MagicNumber: Bits 23-32
   int currencyId = GetCurrencyId(currency) & 0x1F << 17;   //  5 bit (Bits größer 5 nullen und auf 22 Bit erweitern)   | in MagicNumber: Bits 18-22
   int iUnits     = MathRound(units * 10) + 0.1;            //    +0.1 fängt evt. Präzisionsfehler beim Casten ab
       iUnits     = iUnits & 0x1F << 12;                    //  5 bit (Bits größer 5 nullen und auf 17 Bit erweitern)   | in MagicNumber: Bits 13-17
   int pCounter   = counter & 0x7 << 9;                     //  3 bit (Bits größer 3 nullen und auf 12 Bit erweitern)   | in MagicNumber: Bits 10-12
   int instance   = GetInstanceId() & 0x1FF;                //  9 bit (Bits größer 9 nullen)                            | in MagicNumber: Bits  1-9

   // Der Position-Counter steht nicht am Ende, damit die resultierenden MagicNumbers mehrerer Positionen nicht aufeinander folgende Zahlen sind.

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("CreateMagicNumber(2)", error);
      return(-1);
   }
   return(strategy + currencyId + iUnits + pCounter + instance);
}


/**
 * Gibt den Positionszähler der letzten offenen Position im aktuellen Instrument zurück.
 *
 * @return int - Anzahl
 */
int GetPositionCounter() {
   return(0);
}


/**
 * Gibt die aktuelle Instanz-ID zurück. Existiert noch keine, wird eine neue erzeugt.
 *
 * @return int - Instanz-ID im Bereich 1-511 (9 bit), zusammen mit der Currency-ID (5 bit) ist das ausreichend
 */
int GetInstanceId() {
   static int id;

   if (id == 0) {
      MathSrand(GetTickCount());
      while (id == 0) {
         id = MathRand();
         if (id > 511)
            id >>= 1;
      }
   }
   return(id);
}

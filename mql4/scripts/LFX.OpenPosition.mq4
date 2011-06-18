/**
 * Öffnet eine Position in einer der LiteForex-Indizes.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

//extern string Currency  = "";                   // AUD | CAD | CHF | EUR | GBP | JPY | USD
//extern string Direction = "[ Long | Short ]";   // Buy | Long | Sell | Short
//extern double Units     = 1;                    // 0.1 ... 1.9
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
   if (LE(Units, 0))
      return(catch("init(3)  Invalid input parameter Units = "+ NumberToStr(Units, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
   units = Units;

   // Leverage-Konfiguration
   leverage = GetGlobalConfigDouble("Leverage", "CurrencyBasket", 0);
   if (LT(leverage, 1))
      return(catch("init(4)  Invalid configuration value [Leverage] CurrencyBasket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

   return(catch("init(5)"));
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

      double lotValue = bid / tickSize * tickValue;                                 // Lotvalue in Account-Currency
      double unitSize = equity / lotValue * leverage;                               // equity / lotValue entspricht einem Hebel von 1
      lots[i] = units * unitSize;                                                   // Account-Equity wird mit leverage gehebelt

      double lotStep = MarketInfo(symbols[i], MODE_LOTSTEP);                        // auf Vielfaches von MODE_LOTSTEP runden
      lots[i] = NormalizeDouble(MathRound(lots[i]/lotStep) * lotStep, CountDecimals(lotStep));
   }
   //debug("start()   lots = "+ DoubleArrayToStr(lots));


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
      int digits    = MarketInfo(symbols[i], MODE_DIGITS) + 0.1;        // +0.1 fängt evt. Präzisionsfehler beim Casten ab: (int) double
      int pipDigits = digits - digits%2;

      int    magicNumber = CreateMagicNumber();
      string comment     = "LI."+ currency +".1";
      int    slippage    = ifInt(digits==pipDigits, 0, 1);              // keine Slippage bei 4-Digits-Brokern
      color  markerColor = CLR_NONE;

      int ticket = OrderSendEx(symbols[i], directions[i], lots[i], NULL, slippage, NULL, NULL, comment, magicNumber, NULL, markerColor);
      if (ticket == -1)
         return(stdlib_GetLastError());
   }

   return(catch("start(3)"));
}


/**
 * Generiert aus den internen Daten einen Wert für OrderMagicNumber().
 *
 * @return int - MagicNumber
 */
int CreateMagicNumber() {
   int strategy = Strategy.uniqueId << 22;            // 10 bit (Bereich 0-1023)                              | in MagicNumber: Bits 23-32
   int instance = GetInstanceId() << 18 >> 10;        // Bits größer 14 löschen und Wert auf 22 Bit erweitern | in MagicNumber: Bits  9-22

   //int length   = sequenceLength   & 0x000F << 4;     // 4 bit (Bereich 1-12), auf 8 bit erweitern            | in MagicNumber: Bits  5-8
   //int level    = progressionLevel & 0x000F;          // 4 bit (Bereich 1-12)                                 | in MagicNumber: Bits  1-4

   int length;
   int level;

   return(strategy + instance + length + level);
}


/**
 * Gibt die aktuelle Instanz-ID zurück.
 *
 * @return int - Instanz-ID im Bereich 1000-16383 (14 bit)
 */
int GetInstanceId() {
   static int id;

   if (id == 0) {
      MathSrand(GetTickCount());
      while (id < 2000) {           // Das abschließende Shiften halbiert den Wert und wir wollen mindestens eine 4-stellige ID haben.
         id = MathRand();
      }
      id >>= 1;
   }
   return(id);
}

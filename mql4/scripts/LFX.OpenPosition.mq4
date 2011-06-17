/**
 * Öffnet eine Position in einer der LiteForex-Indizes.
 */
#include <stdlib.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern string Currency  = "";                   // AUD | CAD | CHF | EUR | GBP | JPY | USD
extern string Direction = "[ Long | Short ]";   // Buy | Long | Sell | Short
extern double Units     = 1;                    // 0.1 ... 1.9

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


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
   if (GE(Units, 2))
      return(catch("init(4)  Parameter Units is too big: "+ NumberToStr(Units, ".+"), ERR_INVALID_INPUT_PARAMVALUE));
   units = Units;


   // Leverage-Konfiguration auslesen
   leverage = GetGlobalConfigDouble("Leverage", "CurrencyBasket", 0);
   if (LT(leverage, 1))
      return(catch("init(5)  Invalid configuration value [Leverage] CurrencyBasket = "+ NumberToStr(leverage, ".+"), ERR_INVALID_INPUT_PARAMVALUE));

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

   // (1) Pairs bestimmen
   string pairs[6];
   if      (currency == "AUD") { pairs[0] = "AUDCAD"; pairs[1] = "AUDCHF"; pairs[2] = "AUDJPY"; pairs[3] = "AUDUSD"; pairs[4] = "EURAUD"; pairs[5] = "GPBAUD"; }
   else if (currency == "CAD") { pairs[0] = "AUDCAD"; pairs[1] = "CADCHF"; pairs[2] = "CADJPY"; pairs[3] = "EURCAD"; pairs[4] = "GBPCAD"; pairs[5] = "USDCAD"; }
   else if (currency == "CHF") { pairs[0] = "AUDCHF"; pairs[1] = "CADCHF"; pairs[2] = "CHFJPY"; pairs[3] = "EURCHF"; pairs[4] = "GBPCHF"; pairs[5] = "USDCHF"; }
   else if (currency == "EUR") { pairs[0] = "EURAUD"; pairs[1] = "EURCAD"; pairs[2] = "EURCHF"; pairs[3] = "EURGBP"; pairs[4] = "EURJPY"; pairs[5] = "EURUSD"; }
   else if (currency == "GBP") { pairs[0] = "EURGBP"; pairs[1] = "GBPAUD"; pairs[2] = "GBPCAD"; pairs[3] = "GBPCHF"; pairs[4] = "GBPJPY"; pairs[5] = "GBPUSD"; }
   else if (currency == "JPY") { pairs[0] = "AUDJPY"; pairs[1] = "CADJPY"; pairs[2] = "CHFJPY"; pairs[3] = "EURJPY"; pairs[4] = "GBPJPY"; pairs[5] = "USDJPY"; }
   else if (currency == "USD") { pairs[0] = "AUDUSD"; pairs[1] = "EURUSD"; pairs[2] = "GBPUSD"; pairs[3] = "USDCAD"; pairs[4] = "USDCHF"; pairs[5] = "USDJPY"; }


   // (2) Lotsizes berechnen
   double lotSizes[6];
   double equity = AccountEquity()-AccountCredit();

   for (int i=0; i < 6; i++) {
      double bid       = MarketInfo(pairs[i], MODE_BID      );
      double tickSize  = MarketInfo(pairs[i], MODE_TICKSIZE );
      double tickValue = MarketInfo(pairs[i], MODE_TICKVALUE);

      int error = GetLastError();
      if (error != NO_ERROR)
         return(catch("start(1)   \""+ pairs[i] +"\"", error));

      double lotValue = bid / tickSize * tickValue;               // Lotvalue in Account-Currency
      double unitSize = equity / lotValue * leverage;             // equity / lotValue entspricht einem Hebel von 1
                                                                  // Account-Equity wird mit 'leverage' gehebelt
      lotSizes[i] = units * unitSize;
   }
   debug("start()   lotSizes = "+ DoubleArrayToStr(lotSizes));




   // (3) Positionen öffnen

   return(catch("start(2)"));
}

/**
 *  Format der LFX-MagicNumber:
 *  ---------------------------
 *  Strategy-Id:  10 bit (Bit 23-32) => Bereich 101-1023
 *  Currency-Id:   4 bit (Bit 19-22) => Bereich   1-15         @see: stdlib1::GetCurrencyId()
 *  Units:         4 bit (Bit 15-18) => Bereich   1-15         Vielfaches von 0.1 von 1 bis 10
 *  Instance-ID:  10 bit (Bit  5-14) => Bereich   1-1023
 *  Counter:       4 bit (Bit  1-4 ) => Bereich   1-15
 */
#define STRATEGY_ID   102                                            // eindeutige ID der Strategie (Bereich 101-1023)


// Currency-ID's (entsprechen den ID's in stddefine.mqh)
#define CID_AUD       1
#define CID_CAD       2
#define CID_CHF       3
#define CID_EUR       4
#define CID_GBP       5
#define CID_JPY       6
#define CID_NZD       7
#define CID_USD       8


// LFX-Currencies und LFX-QuickChannel-Namen: Arrayindizes stimmen mit Currency-ID's überein
string lfxCurrencies     [] = {"",            "AUD",            "CAD",            "CHF",            "EUR",            "GBP",            "JPY",            "NZD",            "USD"};
string channels.lfxProfit[] = {"", "LFX.Profit.AUD", "LFX.Profit.CAD", "LFX.Profit.CHF", "LFX.Profit.EUR", "LFX.Profit.GBP", "LFX.Profit.JPY", "LFX.Profit.NZD", "LFX.Profit.USD"};


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört.
 *
 * @return bool
 */
bool LFX.IsMyOrder() {
   return(OrderMagicNumber() >> 22 == STRATEGY_ID);                  // 10 bit (Bit 23-32) => Bereich 101-1023
}


/**
 * Gibt die Currency-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Currency-ID, entsprechend stdlib1::GetCurrencyId()
 */
int LFX.GetCurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 1-15
}


/**
 * Gibt die Units der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return double - Units
 */
double LFX.GetUnits(int magicNumber) {
   return(magicNumber >> 14 & 0xF / 10.);                            // 4 bit (Bit 15-18) => Bereich 1-15
}


/**
 * Gibt die Instanz-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Instanz-ID
 */
int LFX.GetInstanceId(int magicNumber) {
   return(magicNumber >> 4 & 0x3FF);                                 // 10 bit (Bit 5-14) => Bereich 1-1023
}


/**
 * Gibt den Position-Counter der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Counter
 */
int LFX.GetCounter(int magicNumber) {
   return(magicNumber & 0xF);                                        // 4 bit (Bit 1-4 ) => Bereich 1-15
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   LFX.IsMyOrder();
   LFX.GetCounter(NULL);
   LFX.GetCurrencyId(NULL);
   LFX.GetInstanceId(NULL);
   LFX.GetUnits(NULL);
}

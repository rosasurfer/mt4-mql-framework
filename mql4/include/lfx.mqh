/**
 *  Format von MagicNumber:
 *  -----------------------
 *  Strategy-Id:   10 bit (Bit 23-32) => Bereich 100-1023
 *  Currency-Id:    4 bit (Bit 19-22) => Bereich   0-15
 *  Units:          4 bit (Bit 15-18) => Bereich   0-15   (Vielfaches von 0.1 von 1 bis 10)
 *  Instance-ID:   10 bit (Bit  5-14) => Bereich   0-1023 (immer größer 0)
 *  Counter:        4 bit (Bit  1-4 ) => Bereich   0-15   (immer größer 0)
 */


/**
 * Gibt die Currency-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Currency-ID
 */
int LFX.GetCurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 0-15
}


/**
 * Gibt die Units der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return double - Units
 */
double LFX.GetUnits(int magicNumber) {
   return(magicNumber >> 14 & 0xF / 10.);                            // 4 bit (Bit 15-18) => Bereich 0-15
}


/**
 * Gibt die Instanz-ID der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Instanz-ID
 */
int LFX.GetInstanceId(int magicNumber) {
   return(magicNumber >> 4 & 0x3FF);                                 // 10 bit (Bit 5-14) => Bereich 0-1023
}


/**
 * Gibt den Position-Counter der MagicNumber einer LFX-Position zurück.
 *
 * @param  int magicNumber
 *
 * @return int - Counter
 */
int LFX.GetCounter(int magicNumber) {
   return(magicNumber & 0xF);                                        // 4 bit (Bit 1-4 ) => Bereich 0-15
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört.
 *
 * @return bool
 */
bool IsMyOrder() {
   return(OrderMagicNumber() >> 22 == STRATEGY_ID);                  // 10 bit (Bit 23-32) => Bereich 0-1023, jedoch immer größer 100
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   IsMyOrder();
   LFX.GetCounter(NULL);
   LFX.GetCurrencyId(NULL);
   LFX.GetInstanceId(NULL);
   LFX.GetUnits(NULL);
}

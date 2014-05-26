/**
 * TODO: Doppelte Implementierung von LFX.CurrencyId() entfernen (hier und in "include/LFX/functions.mqh").
 */
#property library
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/library.mqh>


#include <structs/pewa/LFX_ORDER.mqh>


/**
 * Gibt die Currency-ID der MagicNumber einer LFX-Order zurück.      // TODO: !!! doppelte Implementierung entfernen !!!
 *
 * @param  int magicNumber
 *
 * @return int - Currency-ID, entsprechend stdlib1::GetCurrencyId()
 */
int LFX.CurrencyId(int magicNumber) {
   return(magicNumber >> 18 & 0xF);                                  // 4 bit (Bit 19-22) => Bereich 1-15
}


/**
 * Wird nur im Tester in library::init() aufgerufen, um alle verwendeten globalen Arrays zurücksetzen zu können (EA-Bugfix).
 */
void Tester.ResetGlobalArrays() {
   ArrayResize(stack.orderSelections, 0);
}

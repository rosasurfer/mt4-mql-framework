/**
 * TradeCmd.Sender
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = { INIT_NO_BARS_REQUIRED };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <functions/JoinStrings.mqh>
#include <stdlibs.mqh>

#include <MT4iQuickChannel.mqh>
#include <lfx.mqh>
#include <structs/xtrade/LFXOrder.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // TradeAccount initialisieren
   if (!InitTradeAccount())
      return(last_error);
   return(catch("onInit(1)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   QC.StopChannels();
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   QC.SendTradeCommand("LFX:428371265:open");               // Sell Limit 0.1 CAD.1

   return(last_error);
}

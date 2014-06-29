/**
 * TradeCmd.Sender
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdlib.mqh>

#include <win32api.mqh>
#include <MT4iQuickChannel.mqh>

#include <LFX/functions.mqh>
#include <LFX/quickchannel.mqh>
#include <structs/pewa/LFX_ORDER.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   QC.SendTradeCommand("LFX:428371265:open");               // Sell Limit 0.1 CAD.1

   return(last_error);
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


/*abstract*/bool QC.StopScriptParameterSender()  { return(!catch("QC.StopScriptParameterSender()", ERR_WRONG_JUMP)); }

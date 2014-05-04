/**
 * TradeCmd.Sender
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/script.mqh>
#include <win32api.mqh>

#include <lfx.mqh>
#include <MT4iQuickChannel.mqh>
#include <ChartInfos/quickchannel.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   QC.SendTradeCommand("LFX.428371265.open");               // Sell Limit 0.1 CAD.1

   return(last_error);
}


/*abstract*/bool QC.StopScriptParameterSender()  { return(!catch("QC.StopScriptParameterSender()", ERR_NOT_IMPLEMENTED)); }
/*abstract*/bool RunScript(string s1, string s2) { return(!catch("RunScript()",                    ERR_NOT_IMPLEMENTED)); }

/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RemoveChartObjects();

   // QuickChannel-Sender-Handles schließen
   for (int i=ArraySize(hLfxSenderChannels)-1; i >= 0; i--) {
      if (hLfxSenderChannels[i] != NULL) {
         if (!QC_ReleaseSender(hLfxSenderChannels[i]))
            catch("onDeinit(1)->MT4iQuickChannel::QC_ReleaseSender(hChannel=0x"+ IntToHexStr(hLfxSenderChannels[i]) +")   error closing QuickChannel sender: "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
         hLfxSenderChannels[i] = NULL;
      }
   }

   // QuickChannel-Receiver-Handle schließen
   if (hLfxReceiverChannel != NULL) {
      if (!QC_ReleaseReceiver(hLfxReceiverChannel))
         catch("onDeinit(2)->MT4iQuickChannel::QC_ReleaseReceiver(hChannel=0x"+ IntToHexStr(hLfxReceiverChannel) +")   error releasing QuickChannel receiver: "+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
      hLfxReceiverChannel = NULL;
   }

   return(catch("onDeinit(3)"));
}

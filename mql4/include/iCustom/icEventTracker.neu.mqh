/**
 * Ruft den "EventTracker.neu"-Indikator auf. Der Indikator hat keine Buffer und gibt keinen Wert zurück.
 *
 * @param  int timeframe - Timeframe, in dem der Indikator geladen werden soll (default: der aktuelle Timeframe)
 *
 * @return bool - Erfolgsstatus
 */
bool icEventTracker.neu(int timeframe=NULL) {

   bool   trackOrders       = false;
   bool   trackSignals      = true;
   bool   alertSound        = true;
   string alertMailReceiver = "";
   string alertSmsReceiver  = "";
   string alertIrcChannel   = "";
   string alertHttpUrl      = "";
   int    lpLocalContext    = GetIntsAddress(__ExecutionContext);          // TODO: Aufruf statisch machen


   iCustom(NULL, timeframe, "EventTracker.neu",
           trackOrders,                                                    // Track.Orders
           trackSignals,                                                   // Track.Signals
           "",                                                             // ____________________
           alertSound,                                                     // Signal.Sound
           alertMailReceiver,                                              // Signal.Mail.Receiver
           alertSmsReceiver,                                               // Signal.SMS.Receiver
           alertIrcChannel,                                                // Signal.IRC.Channel
           alertHttpUrl,                                                   // Signal.HTTP.Url
           "",                                                             // ____________________
           lpLocalContext,                                                 // __SuperContext__
           0,                                                              // iBuffer
           0);                                                             // iBar

   int error = GetLastError();

   if (IsError(error)) {
      if (error != ERS_HISTORY_UPDATE)
         return(!catch("icEventTracker.neu(1)", error));
      warn("icEventTracker.neu(2)  ERS_HISTORY_UPDATE (tick="+ Tick +")"); // TODO: geladene Bars prüfen
   }

   error = ec_LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(true);
   return(!SetLastError(error));
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "Expander.dll"
   int ec_LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import

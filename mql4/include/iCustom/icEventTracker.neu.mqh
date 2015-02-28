/**
 * Ruft den "EventTracker.neu"-Indikator auf. Der Indikator hat keine Buffer und gibt keinen Wert zurück.
 *
 * @param  int timeframe - Timeframe, in dem der Indikator geladen werden soll (default: der aktuelle Timeframe)
 *
 * @return bool - Erfolgsstatus
 */
bool icEventTracker.neu(int timeframe=NULL) {

   bool   trackOrderEvents   = false;
   bool   trackPriceEvents   = true;
   bool   alertsSound        = true;
   string alertsMailReceiver = "";
   string alertsSMSReceiver  = "";
   string alertsHTTPUrl      = "";
   string alertsICQUserID    = "";
   int    lpLocalContext     = GetBufferAddress(__ExecutionContext);       // TODO: Aufruf statisch machen


   iCustom(NULL, timeframe, "EventTracker.neu",
           trackOrderEvents,                                               // Track.Order.Events
           trackPriceEvents,                                               // Track.Price.Events
           "",                                                             // ____________________
           alertsSound,                                                    // Alerts.Sound
           alertsMailReceiver,                                             // Alerts.Mail.Receiver
           alertsSMSReceiver,                                              // Alerts.SMS.Receiver
           alertsHTTPUrl,                                                  // Alerts.HTTP.Url
           alertsICQUserID,                                                // Alerts.ICQ.UserID
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

   error = ec.LastError(__ExecutionContext);                               // TODO: Synchronisation von Original und Kopie sicherstellen
   if (!error)
      return(true);
   return(!SetLastError(error));
}


// --------------------------------------------------------------------------------------------------------------------------------------------------


#import "Expander.dll"
   int GetBufferAddress(int buffer[]);

#import "struct.EXECUTION_CONTEXT.ex4"
   int ec.LastError(/*EXECUTION_CONTEXT*/int ec[]);
#import

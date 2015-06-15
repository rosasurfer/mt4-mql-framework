/**
 * Ruft den "EventTracker.neu"-Indikator auf. Der Indikator hat keine Buffer und gibt keinen Wert zurück.
 *
 * @param  int timeframe - Timeframe, in dem der Indikator geladen werden soll (default: der aktuelle Timeframe)
 *
 * @return bool - Erfolgsstatus
 */
bool icEventTracker.neu(int timeframe=NULL) {

   bool   trackOrderEvents  = false;
   bool   trackPriceEvents  = true;
   bool   alertSound        = true;
   string alertMailReceiver = "";
   string alertSMSReceiver  = "";
   string alertHTTPUrl      = "";
   string alertICQUserID    = "";
   int    lpLocalContext    = GetBufferAddress(__ExecutionContext);        // TODO: Aufruf statisch machen


   iCustom(NULL, timeframe, "EventTracker.neu",
           trackOrderEvents,                                               // Track.Order.Events
           trackPriceEvents,                                               // Track.Price.Events
           "",                                                             // ____________________
           alertSound,                                                     // Alert.Sound
           alertMailReceiver,                                              // Alert.Mail.Receiver
           alertSMSReceiver,                                               // Alert.SMS.Receiver
           alertHTTPUrl,                                                   // Alert.HTTP.Url
           alertICQUserID,                                                 // Alert.ICQ.UserID
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
   int ec_LastError(/*EXECUTION_CONTEXT*/int ec[]);
   int GetBufferAddress(int buffer[]);
#import

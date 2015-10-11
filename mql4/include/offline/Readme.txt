
=================================================================================================================================
 Allgemein 
=================================================================================================================================

 • Neue MetaTrader-Versionen setzen die Variablen Digits und Point in Offline-Charts permanent falsch, bei alten Versionen reicht 
   es, das Charttemplate neuzuladen.

 • Charting synthetischer Instrumente:
   - Um die Chartperiode dynamisch umschalten zu können, muß das Instrument in "symbols.raw" eingetragen und eine Verbindung zum 
     Trade-Server verhindert werden. Für das Terminal sieht das synthetische Instrument dann wie ein reguläres Instrument aus.

   - Bei Verbindung zum Trade-Server wird eine modifizierte Datei "symbols.raw" überschrieben und dort eingetragene synthetische
     Instrumente gehen verloren.

   - Ohne Serververbindung muß eine modifizierte Datei "symbols.raw" nicht zusätzlich geschützt werden.

   - Dynamische Charts können wie Offline-Charts durch das Command ID_CHART_REFRESH aktualisiert werden, wenn der erste Chart 
     dieses Instruments und dieser Periode während der gesamten Terminal-Laufzeit ein Offline-Chart war. Dies wird vom Offline-
     QuotesProvider genutzt, um dynamische Charts synthetischer Instrumente wie reguläre Offline-Charts zu aktualisieren.


 TODO: Das Wechseln der SuperBar-Timeframes funktioniert in Offline-Charts noch nicht.



=================================================================================================================================
 Automatische Aktualisierung von Offline-Charts 
=================================================================================================================================

  Subscription-Prozeß: Informationsfluß zwischen Quote-Provider und Subscribern
  -----------------------------------------------------------------------------
  Beliebige Clients (z.B. Charts in beliebigen Terminals) können sich per Subscription-Modell beim Quote-Provider anmelden.
  Auch ein weiterer, parallel laufender Quote-Provider kann sich als Subscriber anmelden, um benachrichtigt zu werden, wenn der 
  aktuelle Provider herunterfährt oder offline geht. In diesem Fall kann der zusätzliche Provider den Subscription-Channel des 
  herunterfahrenden Providers inkl. dort auflaufender Messages nahtlos übernehmen und die Subscriber können sich sofort und ohne 
  Unterbrechung erneut anmelden. Aus Sicht des Subscribers erfolgt ein Resubscribe, ohne den Wechsel der Quote-Provider-Instanz 
  zu bemerken.
  
  Subscription-Channel: "MetaTrader::QuoteServer::{Symbol}"             - ein Channel für jedes vom Provider angebotene Symbol 
  Back-Channel:         "MetaTrader::QuoteClient::{Symbol}::{UniqueId}" - ein Channel für jeden Subscriber


(1) Chart meldet sich beim Quote-Provider an
    • Subscription-Ausgangsstatus des Charts: "offline"
    • Chart als Sender auf Subscription-Channel registrieren
    • Chart als Receiver auf Back-Channel registrieren

    • Subscribe-Message schicken:       >> "Subscribe|{HWND_CHART}|{BackChannelName}"
      - Subscriptionstatus des Charts:  "connecting"

    • Online-Status des Providers prüfen: Test mit QC_ChannelHasReceiver("{SubscriptionChannel}")
      - Provider online:  
        • auf Bestätigung warten:       << "Subscribe|{HWND_CHART}|{BackChannelName}|ACK" 

      - Provider offline:
        • Subscriptionstatus des Charts: "offline"     
        • auf Bestätigung warten 
        • regelmäßig Online-Status des Providers prüfen (nur in DLL möglich) 



(2) Chart meldet sich beim Quote-Provider ab
    • Unsubscription
      - ein aktiver Provider hört auf dem Channel "MetaTrader::QuoteServer::{Symbol}" (ist Receiver)
      - Test, ob Quote-Provider online ist: QC_ChannelHasReceiver() ?
        • nein: Abbruch (Quote-Provider offline, Abmeldung nicht notwendig)
        • ja:   fortfahren
      - Chart als Sender   auf "MetaTrader::QuoteServer::{Symbol}"             registrieren (Channel sollte bereits offen sein)
      - Chart als Receiver auf "MetaTrader::QuoteClient::{Symbol}::{UniqueId}" registrieren (Channel sollte bereits offen sein)
      - Unsubscribe-Message schicken:                   >> "Unsubscribe|{HWND_CHART}|{BackChannelName}"
      - Bestätigung braucht nicht abgewartet zu werden: << "Unsubscribe|{HWND_CHART}|ACK"



(3) Quote-Provider startet oder geht online
    • Provider als Receiver auf "MetaTrader::QuoteServer::{Symbol}" registrieren (jeweils ein Channel je Symbol)
    • prüfen, ob in den Channels Subscribe-Messages von wartenden Clients existieren
      - nein: Abbruch
      - ja:   fortfahren
    • für jeden wartenden Client:
      - Subscribe-Message parsen:                              << "Subscribe|{HWND_CHART}|{BackChannelName}"
      - ChartHandle HWND_CHART validieren
      - prüfen, ob auf "{BackChannelName}" ein Receiver online ist: QC_ChannelHasReceiver() ?
        • nein: Abbruch
        • ja:   fortfahren
      - Provider als Sender auf "{BackChannelName}" registrieren
      - Subscribe-Bestätigung auf "{BackChannelName}" schicken: >> "Subscribe|{HWND_CHART}|ACK"
    • bei neuem Tick Command ID_CHART_REFRESH an den jeweiligen Subscriber schicken
    • regelmäßig prüfen, ob Subscriber noch online ist (PostMessage(), Fensterhandle oder Back-Channel)



(4) Quote-Provider endet oder geht offline
    • Provider muß als Receiver auf "MetaTrader::QuoteServer::{Symbol}" registriert sein (jeweils ein Channel je Symbol)
    • Provider muß als Sender auf allen BackChannels der Subscriber registriert sein

    • für jedes angebotene Symbol:
      - Messages im Channel "MetaTrader::QuoteServer::{Symbol}" verarbeiten

    • für jedes angebotene Symbol:
      - Channel "MetaTrader::QuoteServer::{Symbol}" verlassen

    • für jeden registrierten Subscriber:
      - prüfen, ob der Subscriber noch online ist (Fensterhandle und Back-Channel)
        • nein: Abbruch
        • ja:   fortfahren
      - auf "{BackChannelName}" Ende der Subscription signalisieren: >> "QuoteServer|{Symbol}|SubscriptionCancelled"
      - auf "{BackChannelName}" Shutdown-Benachrichtigung schicken:  >> "QuoteServer|Shutdown"
      - es wird keine Bestätigung durch den Subscriber abgewartet



 
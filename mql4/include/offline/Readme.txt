
=================================================================================================================================
 Allgemeine Offline-Chart-Infos  
=================================================================================================================================

 • Neue MetaTrader-Versionen setzen die Variablen Digits und Point in Offline-Charts permanent falsch, bei alten Versionen reicht 
   es, das Charttemplate neuzuladen.

 • EA's führen die start()-Funktion bei künstlichen Ticks in Offline- (und in regulären) Charts nur mit Serververbindung, 
   Indikatoren in jedem Fall auch ohne Serververbindung aus.

 • Charting synthetischer Instrumente:
   - Um die Chartperiode dynamisch umschalten zu können, muß das Instrument in "symbols.raw" eingetragen und eine Verbindung zum 
     Tradeserver verhindert werden. Für das Terminal sieht das synthetische Instrument dann wie ein reguläres Instrument aus.

   - Bei Verbindung zum Tradeserver wird eine modifizierte Datei "symbols.raw" überschrieben und dort eingetragene synthetische
     Instrumente gehen verloren.

   - Ohne Serververbindung muß eine modifizierte Datei "symbols.raw" nicht zusätzlich geschützt werden.

   - Dynamische Charts können wie Offline-Charts durch das Command ID_CHART_REFRESH aktualisiert werden, wenn der erste Chart 
     dieses Instruments dieser Periode während der gesamten Terminal-Laufzeit ein Offline-Chart war. Dies wird vom Offline-
     QuoteServer genutzt, um dynamische Charts synthetischer Instrumente wie reguläre Offline-Charts zu aktualisieren.


 TODO: Das Wechseln der SuperBar-Timeframes funktioniert in Offline-Charts noch nicht.



=================================================================================================================================
 Automatische Aktualisierung von Offline-Charts 
=================================================================================================================================

  Subscription-Prozeß: Informationsfluß zwischen QuoteServer und QuoteClient (Subscribern)
  ----------------------------------------------------------------------------------------
  Beliebige Clients (z.B. Charts in beliebigen Terminals) können sich per Subscription-Modell beim QuoteServer anmelden. Auch ein 
  weiterer, parallel laufender QuoteServer kann sich als Subscriber anmelden, um benachrichtigt zu werden, wenn der momentan  
  laufende QuoteServer herunterfährt oder offline geht. In diesem Fall kann der zusätzliche QuoteServer den Subscription-Channel 
  des herunterfahrenden QuoteServers inkl. dort auflaufender Messages nahtlos übernehmen und die Subscriber können sich sofort und 
  ohne Unterbrechung erneut anmelden. Aus Sicht des Subscribers erfolgt ein Resubscribe, ohne den Wechsel der QuoteServer-Instanz 
  zu bemerken.
  
  Subscription-Channel: "MetaTrader::QuoteServer::{Symbol}"             - ein Channel für jedes vom QuoteServer angebotene Symbol 
  Backchannel:          "MetaTrader::QuoteClient::{Symbol}::{UniqueId}" - ein Channel für jeden Subscriber


  TODO: MQL kann in deinit() einen UninitReason noch nicht eindeutig erkennen, sondern erst im folgenden init(). Daher ist es nicht 
        möglich, externe Resourcen (z.B. ein QuickChannel-Handle) abhängig vom UninitReason korrekt zu speichern oder freizugeben. 
        Dies kann erst mit einer UninitReason-Erkennung via DLL zuverlässig erreicht werden. Externe Resourcen müssen daher bei jedem 
        deinit() freigegeben und ein komplettes Unsubscribe-Subscribe durchgeführt werden. 
       
        Wegen dieses unnötigen Mehraufwandes wurde vorläufig die Bestätigung jeder einzelnen Message entfernt. Dementsprechend ist der 
        Subscriber statuslos.       


(1) QuoteClient des Charts meldet sich beim QuoteServer an
    • Subscription-Ausgangsstatus des QuoteClients: "offline"
    • QuoteClient als Sender auf Subscription-Channel registrieren
    • QuoteClient als Receiver auf Backchannel registrieren

    • Subscribe-Message schicken: >> "Subscribe|{HWND_CHART}|{BackChannelName}|{ChannelMsgId}"
      - Subscriptionstatus des QuoteClients: "connecting"

    • Online-Status des QuoteServers prüfen: Test mit QC_ChannelHasReceiver("{SubscriptionChannel}")
      - QuoteServer online:  fortfahren        
      - QuoteServer offline: Subscriptionstatus des QuoteClients: "offline"     
        
    • auf Bestätigung warten:     << "{ChannelMsgId}|OK"
    • regelmäßig Online-Status des QuoteServers prüfen (nur in DLL möglich) 



(2) QuoteClient des Charts läuft
    • im Backchannel eingehende Messages verarbeiten:
      - Messagebestätigungen:                    << "{ChannelMsgId}|OK"
      - vom QuoteServer initiiertes Unsubscribe: << "QuoteServer|{HWND_CHART}|Unsubscribed|Shutdown"



(3) QuoteClient des Charts meldet sich beim QuoteServer ab
    • QuoteClient muß als Sender auf Subscription-Channel registriert sein

    • Unsubscription
      - Unsubscribe-Message schicken: >> "Unsubscribe|{HWND_CHART}|{ChannelMsgId}"
      - Serverbestätigung:            << "{ChannelMsgId}|OK"
      - Die Serverbestätigung kann, muß aber nicht abgewartet werden. Der Backchannel muß also nicht zwangsläufig offen sein. 
        Die Bestätigung bedeutet für den QuoteClient nur, daß der QuoteServer tatsächlich aufgehört hat, Updates zu schicken.    


(4) QuoteServer startet oder geht online
    • QuoteServer als Receiver auf "MetaTrader::QuoteServer::{Symbol}" registrieren (jeweils ein Channel je angebotenem Symbol)



(5) QuoteServer ist online bzw. läuft
    • Preis-Updates an die jeweiligen Subscriber schicken (Command ID_CHART_REFRESH)

    • in den Subscription-Channels eingehende Messages verarbeiten:
      - einhehende Subscribes verarbeiten
        • Subscribe-Message parsen:                                    << "Subscribe|{HWND}|{BackChannelName}|{ChannelMsgId}"
        • ChartHandle HWND_CHART validieren
        • prüfen, ob auf "{BackChannelName}" ein Receiver online ist: QC_ChannelHasReceiver() ?
          - nein: Abbruch
          - ja:   fortfahren
        • QuoteServer als Sender auf "{BackChannelName}" registrieren
        • Subscribe-Bestätigung auf "{BackChannelName}" verschicken:   >> "{ChannelMsgId}|OK"
        • Subscriber speichern        
      
      - eingehende Unsubscribes verarbeiten
        • Unsubscribe-Message parsen:                                  << "Unsubscribe|{HWND}|{ChannelMsgId}"
        • entsprechenden Subscriber ermitteln        
        • Unsubscribe-Bestätigung auf "{BackChannelName}" verschicken: >> "{ChannelMsgId}|OK"
        • Backchannel schließen
        • Subscriber löschen        

    • regelmäßig prüfen, ob die Subscriber noch online sind (PostMessage(), Fensterhandle, Back-Channel)



(6) QuoteServer endet oder geht offline
    • QuoteServer muß als Receiver auf "MetaTrader::QuoteServer::{Symbol}" registriert sein (jeweils ein Channel je Symbol)
    • QuoteServer muß als Sender auf allen Backchannels der Subscriber registriert sein

    • für jedes angebotene Symbol:
      - Channel "MetaTrader::QuoteServer::{Symbol}" verlassen

    • für jeden registrierten Subscriber:
      - prüfen, ob der Subscriber noch online ist (Fensterhandle und Back-Channel)
        • nein: Abbruch
        • ja:   fortfahren
      - auf "{BackChannelName}" Ende der Subscription signalisieren: >> "QuoteServer|{HWND}|Unsubscribed"
      - auf "{BackChannelName}" Shutdown-Benachrichtigung schicken:  >> "QuoteServer|Shutdown"
      - eine Bestätigung durch den Subscriber ist nicht notwendig



 

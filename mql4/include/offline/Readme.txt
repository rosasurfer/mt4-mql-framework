
 • Neue MetaTrader-Versionen setzen die Variablen Digits und Point in Offline-Charts permanent falsch, bei alten Versionen reicht es,
   das Charttemplate neuzuladen.


 • Charting synthetischer Instrumente:
   - Um die Chartperiode dynamisch umschalten zu können, muß das Instrument in "symbols.raw" eingetragen und eine Verbindung zum
     Trade-Server verhindert werden. Für das Terminal sieht das synthetische Instrument dann wie ein reguläres Instrument aus.

   - Bei Verbindung zum Trade-Server wird eine modifizierte Datei "symbols.raw" überschrieben und dort eingetragene synthetische
     Instrumente gehen verloren.

   - Ohne Serververbindung muß eine modifizierte Datei "symbols.raw" nicht zusätzlich geschützt werden.

   - Dynamische Charts können wie Offline-Charts durch das Command ID_CHART_REFRESH aktualisiert werden, wenn der erste Chart dieses
     Instruments und dieser Periode während der gesamten Terminal-Laufzeit ein Offline-Chart war. Dies wird vom Offline-QuotesProvider
     genutzt, um dynamische Charts synthetischer Instrumente wie reguläre Offline-Charts zu aktualisieren.


 TODO: Das Wechseln der SuperBar-Timeframes funktioniert in Offline-Charts noch nicht.
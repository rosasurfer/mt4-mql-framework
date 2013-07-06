/**
 * Grid Manager
 *
 * Verwaltet ein bis zwei manuell initiierte Trades (kein automatisierter Einstieg).
 *
 *
 * Regeln: - Einstieg nach Momentum, nach News oder nach Erreichen eines neuen relativen Highs/Lows *mit* dem Trend
 *         - höchstens ein Trade je Richtung
 *         - Stoploss spätestens bei Erreichen von Gridlevel 6 oder eines Drawdowns von 25% Startequity (Hedge der Gesamtposition)
 *         - ausgestoppte Position durch Trades in der Gegenrichtung sukzessive abbauen
 *         - bis zum Abbau der ausgestoppten Position keine Trades in derselben Richtung (TODO: je nach Trend)
 *
 *
 * Todo: - Multi-Account-Fähigkeit (Master/Client)
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   return(last_error);
}

/**
 * Grid Manager für zwei diskretionäre Trades
 *
 *
 * Regeln:
 * -------
 *  - Einstieg nach Momentum, nach News oder nach Erreichen eines neuen relativen Highs/Lows mit dem Trend
 *  - ein Trade je Richtung
 *  - Stoploss 1 bei Erreichen von Gridlevel 6 oder eines Drawdowns von 25% Startequity (Hedge der Gesamtposition)     !!! => Werte anpassen    !!!
 *  - Stoploss 2 bei Drawdown in Höhe der Gewinne der letzten rollenden Woche
 *  - ausgestoppte Position durch Trades in der Gegenrichtung sukzessive abbauen
 *  - bis zum Abbau der ausgestoppten Position keine Trades in derselben Richtung                                      !!! => an Trend anpassen !!!
 *
 *
 * Todo:
 * -----
 *  - Anzeige des aktuellen SL-Levels vor Einstieg
 *  - Multi-Account-Fähigkeit (Master/Client)
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


/*          1     2     3
           --------------
Level 1:    0     0     0           1: Gridsize 10
Level 2:   10    10    12           2: Gridsize 10-11-12-13-14
Level 3:   20    21    26           3: Gridsize 12-14-16-18-20
Level 4:   30    33    42
Level 5:   40    46    60
Level 6:   50    60    80
*/

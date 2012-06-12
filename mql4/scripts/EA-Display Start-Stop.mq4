/**
 * SnowRoller StartStopDisplay
 *
 * Schickt der SnowRoller-Instanz im aktuellen Chart das Kommando, den Modus der Start/Stop-Anzeige zu wechseln.
 */
#include <types.mqh>
#define     __TYPE__    T_SCRIPT
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   string ids [];
   int  status[], sizeOfIds;


   // (1) Sequenzen im aktuellen Chart ermitteln
   if (FindChartSequences(ids, status)) {
      sizeOfIds = ArraySize(ids);


      // (2) für Command unzutreffende Sequenzen herausfiltern
      for (int i=sizeOfIds-1; i >= 0; i--) {
         switch (status[i]) {
            case STATUS_WAITING    :                                             // STATUS_UNINITIALIZED:   // entfernen
            case STATUS_STARTING   :                                             // STATUS_WAITING      :   // ok
            case STATUS_PROGRESSING:                                             // STATUS_STARTING     :   // ok
            case STATUS_STOPPING   :                                             // STATUS_PROGRESSING  :   // ok
            case STATUS_STOPPED    :                                             // STATUS_STOPPING     :   // ok
               continue;                                                         // STATUS_STOPPED      :   // ok
            default:                                                             // STATUS_DISABLED     :   // entfernen
               ArraySpliceStrings(ids, i, 1);
               ArraySpliceInts(status, i, 1);
               sizeOfIds--;
         }
      }


      for (i=0; i < sizeOfIds; i++) {                                            // TODO: Zugriff synchronisieren
         // (3) Command setzen                                                   // TODO: Commands zu bereits existierenden Commands hinzufügen
         string label = StringConcatenate("SnowRoller.", ids[i], ".command");
         if (ObjectFind(label) != 0) {
            if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
               return(catch("onStart(1)"));
            ObjectSet(label, OBJPROP_TIMEFRAMES, EMPTY);                         // hidden on all timeframes
         }
         ObjectSetText(label, "startstopdisplay", 1);


         // (4) Tick senden
         Chart.SendTick(false);
         return(catch("onStart(2)"));                                            // regular exit
      }
   }

   if (!IsLastError()) {
      if (sizeOfIds == 0) {
         ForceSound("chord.wav");
         ForceMessageBox("No sequence found.", __NAME__, MB_ICONEXCLAMATION|MB_OK);
      }
      catch("onStart(3)");
   }
   return(last_error);
}

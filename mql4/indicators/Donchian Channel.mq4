/**
 * Donchian Channel Indikator
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern int Periods = 50;                        // Anzahl der auszuwertenden Perioden

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#property indicator_chart_window

#property indicator_buffers 2

double iUpperLevel[];                           // oberer Level
double iLowerLevel[];                           // unterer Level


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Periods
   if (Periods < 2) return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_CONFIG_PARAMVALUE));

   // Buffer zuweisen
   IndicatorBuffers(2);
   SetIndexBuffer(0, iUpperLevel);
   SetIndexBuffer(1, iLowerLevel);

   // Anzeigeoptionen
   string indicatorName = "Donchian Channel("+ Periods +")";
   IndicatorShortName(indicatorName);

   SetIndexLabel(0, "Donchian Upper("+ Periods +")");                // Daten-Anzeige
   SetIndexLabel(1, "Donchian Lower("+ Periods +")");
   IndicatorDigits(Digits);

   // Legende
   string legendLabel = CreateLegendLabel(indicatorName);
   ObjectRegister(legendLabel);
   ObjectSetText (legendLabel, indicatorName, 9, "Arial Fett", Blue);
   int error = GetLastError();
   if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST) // bei offenem Properties-Dialog oder Object::onDrag()
      return(catch("onInit(2)", error));

   // Zeichenoptionen
   SetIndicatorStyles();                                             // Workaround um diverse Terminalbugs (siehe dort)

   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {

   // TODO: bei Parameteränderungen darf die vorhandene Legende nicht gelöscht werden

   DeleteRegisteredObjects(NULL);
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 *
 * @throws ERS_TERMINAL_NOT_YET_READY
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (ArraySize(iUpperLevel) == 0)                                  // kann bei Terminal-Start auftreten
      return(debug("onTick(1)  size(iUpperLevel) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // vor Neuberechnung alle Indikatorwerte zurücksetzen
   if (!ValidBars) {
      ArrayInitialize(iUpperLevel, EMPTY_VALUE);
      ArrayInitialize(iLowerLevel, EMPTY_VALUE);
      SetIndicatorStyles();                                          // Workaround um diverse Terminalbugs (siehe dort)
   }

   // Startbar ermitteln
   int startBar = Min(ChangedBars-1, Bars-Periods);

   // Schleife über alle zu aktualisierenden Bars
   for (int i, bar=startBar; bar >= 0; bar--) {
      iUpperLevel[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar+1)];
      iLowerLevel[bar] = Low [iLowest (NULL, NULL, MODE_LOW,  Periods, bar+1)];
   }

   return(catch("onTick(2)"));
}


/**
 * Indikator-Styles setzen. Workaround um diverse Terminalbugs (Farbänderungen nach Recompilation, Parameteränderung etc.), die erfordern,
 * daß die Styles generell zwar in init(), manchmal jedoch in start() gesetzt werden müssen, um korrekt angezeigt zu werden.
 */
void SetIndicatorStyles() {
   SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY, Blue);
   SetIndexStyle(1, DRAW_LINE, EMPTY, EMPTY, Red );
}

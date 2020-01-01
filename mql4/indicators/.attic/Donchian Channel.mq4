/**
 * Donchian Channel Indikator
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 50;                        // Anzahl der auszuwertenden Perioden

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Blue
#property indicator_color2    Red
#property indicator_width1    2
#property indicator_width2    2


double iUpperLevel[];                           // oberer Level
double iLowerLevel[];                           // unterer Level


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // Periods
   if (Periods < 2) return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_CONFIG_VALUE));

   // Buffer zuweisen
   SetIndexBuffer(0, iUpperLevel);
   SetIndexBuffer(1, iLowerLevel);

   // Anzeigeoptionen
   string indicatorName = "Donchian Channel("+ Periods +")";
   IndicatorShortName(indicatorName);

   SetIndexLabel(0, "Donchian Upper("+ Periods +")");                // Daten-Anzeige
   SetIndexLabel(1, "Donchian Lower("+ Periods +")");
   IndicatorDigits(Digits);

   // Legende
   if (!IsSuperContext()) {
       string legendLabel = CreateLegendLabel(indicatorName);
       ObjectRegister(legendLabel);
       ObjectSetText (legendLabel, indicatorName, 9, "Arial Fett", Blue);
       int error = GetLastError();
       if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST) // bei offenem Properties-Dialog oder Object::onDrag()
          return(catch("onInit(2)", error));
   }

   // Zeichenoptionen
   SetIndicatorOptions();

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
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (!ArraySize(iUpperLevel))                                      // kann bei Terminal-Start auftreten
      return(log("onTick(1)  size(iUpperLevel) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(iUpperLevel, EMPTY_VALUE);
      ArrayInitialize(iLowerLevel, EMPTY_VALUE);
      SetIndicatorOptions();
   }


   // (1) synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(iUpperLevel, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(iLowerLevel, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // Startbar ermitteln
   int startBar = Min(ChangedBars-1, Bars-Periods);


   // Schleife über alle zu aktualisierenden Bars
   for (int bar=startBar; bar >= 0; bar--) {
      iUpperLevel[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar+1)];
      iLowerLevel[bar] = Low [iLowest (NULL, NULL, MODE_LOW,  Periods, bar+1)];
   }

   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
   SetIndexStyle(0, DRAW_LINE, EMPTY, EMPTY);
   SetIndexStyle(1, DRAW_LINE, EMPTY, EMPTY);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=", Periods, ";"));
}

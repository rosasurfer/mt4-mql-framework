/**
 * Donchian Channel Indikator
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int Periods = 50;                        // Anzahl der auszuwertenden Perioden

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_chart_window
#property indicator_buffers   2

#property indicator_color1    Blue
#property indicator_color2    Red
#property indicator_width1    2
#property indicator_width2    2


double iUpperLevel[];                           // oberer Level
double iLowerLevel[];                           // unterer Level


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // Periods
   if (Periods < 2) return(catch("onInit(1)  invalid input parameter Periods: "+ Periods, ERR_INVALID_CONFIG_VALUE));

   // Buffer zuweisen
   SetIndexBuffer(0, iUpperLevel);
   SetIndexBuffer(1, iLowerLevel);

   // Anzeigeoptionen
   string indicatorName = "Donchian Channel("+ Periods +")";
   IndicatorShortName(indicatorName);                               // chart tooltips and context menu
   SetIndexLabel(0, "Donchian Upper("+ Periods +")");               // chart tooltips and "Data" window
   SetIndexLabel(1, "Donchian Lower("+ Periods +")");
   IndicatorDigits(Digits);

   // Legende
   if (!__isSuperContext) {
       string legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
       ObjectSetText (legendLabel, indicatorName, 9, "Arial Fett", Blue);
       int error = GetLastError();
       if (error!=NO_ERROR) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)   // on ObjectDrag or opened "Properties" dialog
          return(catch("onInit(2)", error));
   }

   // Zeichenoptionen
   SetIndicatorOptions();

   return(catch("onInit(3)"));
}


/**
 * Deinitialisierung
 *
 * @return int - error status
 */
int onDeinit() {
   // TODO: bei Parameteränderungen darf die vorhandene Legende nicht gelöscht werden
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - error status
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (!ArraySize(iUpperLevel))                                      // kann bei Terminal-Start auftreten
      return(logInfo("onTick(1)  sizeof(iUpperLevel) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset buffers before performing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(iUpperLevel, EMPTY_VALUE);
      ArrayInitialize(iLowerLevel, EMPTY_VALUE);
      SetIndicatorOptions();
   }


   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftDoubleIndicatorBuffer(iUpperLevel, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftDoubleIndicatorBuffer(iLowerLevel, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // Startbar ermitteln
   int startbar = Min(ChangedBars-1, Bars-Periods);


   // Schleife über alle zu aktualisierenden Bars
   for (int bar=startbar; bar >= 0; bar--) {
      iUpperLevel[bar] = High[iHighest(NULL, NULL, MODE_HIGH, Periods, bar+1)];
      iLowerLevel[bar] = Low [iLowest (NULL, NULL, MODE_LOW,  Periods, bar+1)];
   }

   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
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

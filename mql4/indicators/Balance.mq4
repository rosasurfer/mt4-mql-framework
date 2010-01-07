/**
 * Zeichnet den Balance-Verlauf des Accounts (als Vorstufe zum Equity-Indikator).
 */

#include <stdlib.mqh>


#property indicator_separate_window

#property indicator_buffers 1
#property indicator_color1  Blue
#property indicator_width1  1


double Balance[];


/**
 *
 */
int init() {
   SetIndexBuffer(0, Balance);
   SetIndexLabel (0, "Balance");
   SetIndexStyle (0, DRAW_LINE);

   IndicatorDigits(2);

   return(catch("init()"));
}


/**
 *
 */
int start() {
   ArrayInitialize(Balance, EMPTY_VALUE);

   datetime times[];
   double   values[];

   // Datenreihen mit Balance-Werten holen
   GetBalanceData(times, values);

   int bar, firstBar, size=ArrayRange(times, 0);

   // Balance-Werte in Indikator eintragen...
   for (int i=0; i<size; i++) {
      bar = iBarShift(NULL, 0, times[i]);
      if (i == 0)
         firstBar = bar;
      Balance[bar] = values[i];
   }

   // ... und Lücken ohne Balanceänderung füllen
   double lastBalance = values[0];

   for (i=firstBar; i>=0; i--) {
      if (Balance[i] == EMPTY_VALUE)
         Balance[i] = lastBalance;
      lastBalance = Balance[i];
   }

   return(catch("start()"));
}


/**
 *
 */
int deinit() {
   return(catch("deinit()"));
}
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

   // Zeitreihen mit Balance-Werten holen
   datetime times[];
   double   values[];

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
int GetBalanceData(datetime& times[], double& values[]) {
   // Header-Werte und Array-Indizes definieren
   string header[21] = { "Ticket","OpenTime","OpenTimestamp","Type","TypeNum","Size","Symbol","OpenPrice","StopLoss","TakeProfit","CloseTime","CloseTimestamp","ClosePrice","Commission","Swap","NetProfit","GrossProfit","ExpirationTime","ExpirationTimestamp","MagicNumber","Comment" };

   int TICKET              =  0,
       OPENTIME            =  1,
       OPENTIMESTAMP       =  2,
       TYPE                =  3,
       TYPENUM             =  4,
       SIZE                =  5,
       SYMBOL              =  6,
       OPENPRICE           =  7,
       STOPLOSS            =  8,
       TAKEPROFIT          =  9,
       CLOSETIME           = 10,
       CLOSETIMESTAMP      = 11,
       CLOSEPRICE          = 12,
       COMMISSION          = 13,
       SWAP                = 14,
       NETPROFIT           = 15,
       GROSSPROFIT         = 16,
       EXPIRATIONTIME      = 17,
       EXPIRATIONTIMESTAMP = 18,
       MAGICNUMBER         = 19,
       COMMENT             = 20;


   // Rohdaten der Account-History holen
   string data[][21];
   GetRawHistory(data);


   double profits[][2], profit;
   int n=0, size=ArrayRange(data, 0);

   // Profitdatensätze auslesen
   for (int i=0; i<size; i++) {
      if (StrToInteger(data[i][TYPENUM]) != OP_CREDIT) { // credit lines ignorieren

         profit = StrToDouble(data[i][GROSSPROFIT]);

         if (profit != 0.0) {
            ArrayResize(profits, n+1);
            profits[n][0] = StrToInteger(data[i][CLOSETIMESTAMP]);
            profits[n][1] = profit;
            n++;
         }
      }
   }

   // Profitdatensätze nach CloseTime sortieren und Größe der Zielarrays anpassen
   ArraySort(profits);
   size = ArrayRange(profits, 0);
   ArrayResize(times, size);
   ArrayResize(values, size);


   // Balance-Werte berechnen und Ergebnisse in Zielarrays schreiben
   double balance = 0.00;

   for (i=0; i<size; i++) {
      balance += profits[i][1];

      times [i] = profits[i][0];
      values[i] = balance;
   }

   return(catch("GetBalanceData()"));
}


/**
 *
 */
int deinit() {
   return(catch("deinit()"));
}
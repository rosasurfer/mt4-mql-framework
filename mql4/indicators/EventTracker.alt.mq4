/**
 * EventTracker
 *
 * Überwacht ein Instrument auf verschiedene, konfigurierbare Signale und benachrichtigt darüber optisch, akustisch und/oder per SMS.
 */

#include <stdlib.mqh>
#include <win32api.mqh>


#property indicator_chart_window


//////////////////////////////////////////////////////////////// Default-Konfiguration ////////////////////////////////////////////////////////////

bool   Alerts          = false;        //
int    Alerts.Gridsize = 25;           //
string SMS.Receiver    = "";           // Telefon-Nr. für SMS-Benachrichtigungen (ohne führende Nullen)

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string soundFileUp   = "alert3.wav";
string soundFileDown = "alert4.wav";

string instrName, instrShortName;


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);


   // Konfiguration einlesen
   Alerts = GetConfigBool("EventTracker", "Alerts", Alerts);

   if (Alerts) {
      SMS.Receiver    = GetConfigString("SMS"         , "Receiver"       , SMS.Receiver);
      Alerts.Gridsize = GetConfigInt   ("EventTracker", "Alerts.Gridsize", Alerts.Gridsize);
      string symbols  = GetConfigString("EventTracker", "Track.Symbols"  , "");

      if (SMS.Receiver=="" || !StringContains(","+symbols+",", ","+Symbol()+","))
         Alerts = false;
   }

   instrName      = GetConfigString("Instrument.Names"     , Symbol() , Symbol());
   instrShortName = GetConfigString("Instrument.ShortNames", instrName, instrName);


   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init()"));
}


/**
 *
 */
int start() {
   if (IsConnected()) {                               // nur bei Verbindung zum Tradeserver
      int processedBars = IndicatorCounted();

      if (processedBars == 0) {                       // nach Start oder Data-Pumping
         // TODO: Limite neu initialisieren
         //Print("start()   not calling CheckLimits()  Bars: "+ Bars +"   processedBars: "+ processedBars +"   previousBar: "+ TimeToStr(Time[1]) +"   lastBar: "+ TimeToStr(Time[0]) +"   Bid: "+ FormatPrice(Bid, Digits));
      }
      else {
         if (Alerts) {
            //Print("start()   calling CheckLimits()  Bars: "+ Bars +"   processedBars: "+ processedBars +"   previousBar: "+ TimeToStr(Time[1]) +"   lastBar: "+ TimeToStr(Time[0]) +"   Bid: "+ FormatPrice(Bid, Digits));
            if (CheckLimits() == ERR_HISTORY_WILL_UPDATED)
               return(ERR_HISTORY_WILL_UPDATED);
         }
      }
   }

   return(catch("start()"));
}


/**
 * @return int - Fehlerstatus
 */
int CheckLimits() {
   if (!Alerts)
      return(0);

   int error;

   double gridSize = Alerts.Gridsize / 10000.0;
   double limits[2];                                     // {lowerLimit, upperLimit}

   // aktuelle Limite ermitteln
   if (limits[0] == 0) {                                 // sind Limite nicht initialisiert oder wurden Parameter geändert => Limite neu berechnen
      if (!EventTracker.Limits(NULL, limits) || UninitializeReason()==REASON_PARAMETERS) {
         if (GetCurrentLimits(limits, gridSize) == ERR_HISTORY_WILL_UPDATED)
            return(ERR_HISTORY_WILL_UPDATED);

         EventTracker.Limits(NULL, limits);              // Limite in Library speichern
         Print("CheckLimits()   limits initialized: "+ DoubleToStr(limits[0], 4) +"  <=>  "+ DoubleToStr(limits[1], 4));
         return(catch("CheckLimits(1)"));
      }
   }

   double upperLimit = limits[1]-0.000011,               // +- 1/10 pip, um Alert geringfügig früher auszulösen
          lowerLimit = limits[0]+0.000011;               // +- 1/100 pip, um Fehler beim Vergleich von Doubles zu vermeiden

   // Limite überprüfen
   if (Ask > upperLimit) {
      error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", instrShortName, " => ", DoubleToStr(limits[1], 4)));
      if (error != ERR_NO_ERROR)
         return(catch("CheckLimits(2)   error sending text message to "+ SMS.Receiver, error));
      PlaySound(soundFileUp);
      Print("CheckLimits()   SMS alert sent to ", SMS.Receiver, ":  ", instrName, " => ", DoubleToStr(limits[1], 4), "   (Ask: ", FormatPrice(Ask, Digits), ")");


      limits[1] = NormalizeDouble(limits[1] + gridSize, 4);
      limits[0] = NormalizeDouble(limits[1] - gridSize - gridSize, 4);     // Abstand: 2 x GridSize
      EventTracker.Limits(NULL, limits);                                   // neue Limite in Library speichern
      Print("CheckLimits()   limits adjusted: "+ DoubleToStr(limits[0], 4) +"  <=>  "+ DoubleToStr(limits[1], 4));
   }
   else if (Bid < lowerLimit) {
      error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", instrShortName, " <= ", DoubleToStr(limits[0], 4)));
      if (error != ERR_NO_ERROR)
         return(catch("CheckSMSLimits(3)   error sending text message to "+ SMS.Receiver, error));
      PlaySound(soundFileDown);
      Print("CheckLimits()   SMS alert sent to ", SMS.Receiver, ":  ", instrName, " <= ", DoubleToStr(limits[0], 4), "   (Bid: ", FormatPrice(Bid, Digits), ")");


      limits[0] = NormalizeDouble(limits[0] - gridSize, 4);
      limits[1] = NormalizeDouble(limits[0] + gridSize + gridSize, 4);     // Abstand: 2 x GridSize
      EventTracker.Limits(NULL, limits);                                   // neue Limite in Library speichern
      Print("CheckLimits()   limits adjusted: ", DoubleToStr(limits[0], 4), "  <=>  ", DoubleToStr(limits[1], 4));
   }

   return(catch("CheckLimits(4)"));
}


/**
 * Berechnet die aktuell gültigen Limite.
 *
 * @param double& results  - Array zum Speichern der errechneten Werte {lowerLimit, upperLimit}
 * @param double  gridSize - Schrittweite der Limite
 *
 * @return int - Fehlerstatus
 */
int GetCurrentLimits(double& limits[2], double gridSize) {
   int error;

   int faktor = MathFloor((Bid+Ask) / 2.0 / gridSize);

   limits[0] = NormalizeDouble(gridSize * faktor, 4);
   limits[1] = NormalizeDouble(gridSize * (faktor+1), 4);   // Abstand: 1 x GridSize
   //Print("GetCurrentLimits()   simple limits: "+ DoubleToStr(limits[0], 4) +"  <=>  "+ DoubleToStr(limits[1], 4));

   // letztes Signal ermitteln und Limit in diese Richtung auf 2 x GridSize erweitern
   bool up=false, down=false;
   int period = Period();                                   // Ausgangsbasis ist der aktuelle Timeframe

   while (!up && !down) {
      for (int bar=0; bar <= Bars-1; bar++) {
         // TODO: Verwendung von Bars ist nicht sauber
         if (iLow(NULL, period, bar)  < limits[0]+0.00001) down = true;    // nicht (double1 <= double2) verwenden (siehe CompareDoubles())
         if (iHigh(NULL, period, bar) > limits[1]-0.00001) up   = true;

         error = GetLastError();
         if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
         if (error != ERR_NO_ERROR            ) return(catch("GetCurrentLimits(1)", error));

         if (up || down)
            break;
      }

      if (up && down) {                                     // Bar hat beide Limite berührt
         if (period == PERIOD_M1)
            break;
         period = DecreasePeriod(period);                   // Timeframe verringern
         //Print("GetCurrentLimits()   period decreased to: "+ GetPeriodDescription(period));
         up   = false;
         down = false;
      }
      else if (!up && !down) {
         return(catch("GetCurrentLimits(2)   error calculating current limits", ERR_RUNTIME_ERROR));
      }
   }
   if (down) limits[0] = NormalizeDouble(limits[0] - gridSize, 4);
   if (up  ) limits[1] = NormalizeDouble(limits[1] + gridSize, 4);

   //Print("GetCurrentLimits()   limits calculated: "+ DoubleToStr(limits[0], 4) +"  <=>  "+ DoubleToStr(limits[1], 4));
   return(catch("GetCurrentLimits(3)"));
}


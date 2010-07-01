/**
 * EventTracker
 *
 * Überwacht ein Instrument auf verschiedene, konfigurierbare Signale und benachrichtigt optisch, akustisch und/oder per SMS.
 */

#include <stdlib.mqh>


#property indicator_chart_window


int init_error = ERR_NO_ERROR;


//////////////////////////////////////////////////////////////// Default-Konfiguration ////////////////////////////////////////////////////////////

bool   Sound.Alerts                 = true;
string Sound.File.Up                = "alert3.wav";
string Sound.File.Down              = "alert4.wav";
string Sound.File.PositionOpen      = "OrderFilled.wav";
string Sound.File.PositionClose     = "PositionClosed.wav";

bool   SMS.Alerts                   = true;
string SMS.Receiver                 = "";

bool   Track.Positions              = false;

bool   Track.QuoteChanges           = false;
int    Grid.Size                    = 0;

bool   Track.BollingerBands         = false;
int    BollingerBands.Periods       = 0;
int    BollingerBands.Timeframe     = 0;
int    BollingerBands.MA.Method     = MODE_EMA;
double BollingerBands.MA.Deviation  = 0;

bool   Track.PivotLevels            = false;
bool   PivotLevels.PreviousDayRange = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// sonstige Variablen
string Instrument.Name;

double Grid.Limits[2];                       // { UPPER_VALUE, LOWER_VALUE }
double Band.Limits[3];                       // { UPPER_VALUE, MA_VALUE, LOWER_VALUE }


/**
 *
 */
int init() {
   init_error = ERR_NO_ERROR;

   int account = GetAccountNumber();         // evt. ERR_TERMINAL_NOT_YET_READY
   if (!account) {
      init_error = GetLastLibraryError();
      return(init_error);
   }


   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(Grid.Limits, 0);
      ArrayInitialize(Band.Limits, 0);
   }
   

   // Konfiguration auswerten
   string instrument   = GetGlobalConfigString("Instruments", Symbol(), Symbol());
   string instrSection = "EventTracker."+ instrument;
   Instrument.Name     = GetGlobalConfigString("Instrument.Names", instrument, instrument);

   // Sound- und SMS-Einstellungen
   Sound.Alerts = GetConfigBool("EventTracker", "Sound.Alerts", Sound.Alerts);
   SMS.Alerts   = GetConfigBool("EventTracker", "SMS.Alerts"  , SMS.Alerts);
   if (SMS.Alerts) {
      SMS.Receiver = GetGlobalConfigString("SMS", "Receiver", SMS.Receiver);
      if (!StringIsDigit(SMS.Receiver)) {
         catch("init(1)  Invalid input parameter SMS.Receiver: "+ SMS.Receiver, ERR_INVALID_INPUT_PARAMVALUE);
         SMS.Alerts = false;
      }
   }

   // Positionen
   string accounts = GetConfigString("EventTracker", "Track.Accounts", "");
   if (StringContains(","+accounts+",", ","+account+","))
      Track.Positions = true;

   // Kursänderungen
   Track.QuoteChanges = GetConfigBool(instrSection, "QuoteChanges", Track.QuoteChanges);
   if (Track.QuoteChanges) {
      Grid.Size = GetConfigInt(instrSection, "QuoteChanges.Gridsize", Grid.Size);
      if (Grid.Size < 1) {
         catch("init(2)  Invalid input parameter Grid.Size: "+ GetConfigString(instrSection, "QuoteChanges.Gridsize", ""), ERR_INVALID_INPUT_PARAMVALUE);
         Track.QuoteChanges = false;
      }
   }

   // Bollinger-Bänder
   Track.BollingerBands = GetConfigBool(instrSection, "BollingerBands", Track.BollingerBands);
   if (Track.BollingerBands) {
      BollingerBands.Periods = GetGlobalConfigInt("BollingerBands."+ instrument, "Slow.Periods", BollingerBands.Periods);
      if (BollingerBands.Periods == 0)
         BollingerBands.Periods = GetGlobalConfigInt("BollingerBands", "Slow.Periods", BollingerBands.Periods);
      if (BollingerBands.Periods < 2) {
         catch("init(3)  Invalid input parameter Slow.Periods: "+ GetGlobalConfigString("BollingerBands."+ instrument, "Slow.Periods", GetGlobalConfigString("BollingerBands", "Slow.Periods", "")), ERR_INVALID_INPUT_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      string strValue = GetGlobalConfigString("BollingerBands."+ instrument, "Slow.Timeframe", "");
      if (strValue == "")
         strValue = GetGlobalConfigString("BollingerBands", "Slow.Timeframe", strValue);
      BollingerBands.Timeframe = GetPeriod(strValue);
      if (BollingerBands.Timeframe == 0) {
         catch("init(4)  Invalid input parameter value Slow.Timeframe: "+ strValue, ERR_INVALID_INPUT_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      BollingerBands.MA.Deviation = GetGlobalConfigDouble("BollingerBands."+ instrument, "Deviation.EMA", BollingerBands.MA.Deviation);
      if (CompareDoubles(BollingerBands.MA.Deviation, 0))
         BollingerBands.MA.Deviation = GetGlobalConfigDouble("BollingerBands", "Deviation.EMA", BollingerBands.MA.Deviation);
      if (BollingerBands.MA.Deviation < 0 || CompareDoubles(BollingerBands.MA.Deviation, 0)) {
         catch("init(5)  Invalid input parameter Deviation.EMA: "+ BollingerBands.MA.Deviation, ERR_INVALID_INPUT_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }

   // Pivot-Level
   Track.PivotLevels = GetConfigBool(instrSection, "PivotLevels", Track.PivotLevels);
   if (Track.PivotLevels)
      PivotLevels.PreviousDayRange = GetConfigBool(instrSection, "PivotLevels.PreviousDayRange", PivotLevels.PreviousDayRange);

   
   //Print("init()    Sound.Alerts=", Sound.Alerts, "   SMS.Alerts=", SMS.Alerts, "   Track.Positions: ", Track.Positions, "   Track.QuoteChanges=", Track.QuoteChanges, " (", Grid.Size, ")   Track.BollingerBands=", Track.BollingerBands, "   Track.PivotLevels=", Track.PivotLevels);


   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init(6)"));
}


/**
 *
 */
int start() {
   // falls init() ERR_TERMINAL_NOT_YET_READY zurückgegeben hat, nochmal aufrufen oder abbrechen (bei anderem Fehler)
   if (init_error != ERR_NO_ERROR) {
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }


   // TODO: nach Config-Änderung Limite zurücksetzen

   int processedBars = IndicatorCounted();

   if (processedBars == 0) {                                   // Chartänderung => alle Limite zurücksetzen
      ArrayInitialize(Grid.Limits, 0);
      ArrayInitialize(Band.Limits, 0);
      EventTracker.SetGridLimits(Grid.Limits);
      EventTracker.SetBandLimits(Band.Limits);
   }

   // Positionen
   if (Track.Positions) {
      HandleEvents(EVENT_POSITION_OPEN | EVENT_POSITION_CLOSE);
   }

   // Kursänderungen
   if (Track.QuoteChanges)
      if (CheckGrid() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);

   // Bollinger-Bänder
   if (Track.BollingerBands) {
      HandleEvent(EVENT_BAR_OPEN, PERIODFLAG_M1);              // einmal je Minute die Limite aktualisieren
      if (CheckBollingerBands() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);
   }

   // Pivot-Level
   if (Track.PivotLevels)
      if (CheckPivotLevels() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);

   return(catch("start()"));
}


/**
 * Handler für PositionOpen-Events.
 *
 * @param int tickets[] - Tickets der neuen Positionen
 *
 * @return int - Fehlerstatus
 */
int onPositionOpen(int tickets[]) {
   if (!Track.Positions)
      return(0);

   // TODO: Sound und SMS nur bei ausgeführter Limit-Order und nicht bei manueller Market-Order auslösen
   // TODO: Unterscheidung zwischen Remote- und Home-Terminal, um Accountmißbrauch zu erkennen

   bool playSound = false;
   int size = ArraySize(tickets);

   for (int i=0; i < size; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET))
         continue;

      // nur Events des aktuellen Instruments berücksichtigen
      if (Symbol() == OrderSymbol()) {
         string type       = GetOperationTypeDescription(OrderType());
         string lots       = DoubleToStrTrim(OrderLots());
         string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
         string price      = FormatPrice(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS));
         string message    = StringConcatenate("Position opened: ", type, " ", lots, " ", instrument, " @ ", price);

         // zuerst SMS, dann Sound
         if (SMS.Alerts) {
            int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
            if (error != ERR_NO_ERROR)
               return(catch("onPositionOpen(1)   error sending text message to "+ SMS.Receiver, error));
            Print("onPositionOpen()   SMS sent to ", SMS.Receiver, ":  ", message);
         }
         else {
            Print("onPositionOpen()   ", message);
         }
         playSound = true;                            // Flag für Sound-Status
      }
   }

   if (Sound.Alerts) if (playSound)                   // max. ein Sound
      PlaySound(Sound.File.PositionOpen);

   return(catch("onPositionOpen(2)"));
}


/**
 * Handler für PositionClose-Events.
 *
 * @param int tickets[] - Tickets der geschlossenen Positionen
 *
 * @return int - Fehlerstatus
 */
int onPositionClose(int tickets[]) {
   if (!Track.Positions)
      return(0);

   bool playSound = false;
   int size = ArraySize(tickets);

   for (int i=0; i < size; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) // false: praktisch nahezu unmöglich
         continue;

      // nur PositionClose-Events des aktuellen Instruments berücksichtigen
      if (Symbol() == OrderSymbol()) {
         string type       = GetOperationTypeDescription(OrderType());
         string lots       = DoubleToStrTrim(OrderLots());
         string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
         int    digits     = MarketInfo(OrderSymbol(), MODE_DIGITS);
         string openPrice  = FormatPrice(OrderOpenPrice(), digits);
         string closePrice = FormatPrice(OrderClosePrice(), digits);
         string message    = StringConcatenate("Position closed: ", type, " ", lots, " ", instrument, " @ ", openPrice, " -> ", closePrice);

         // zuerst SMS, dann Sound
         if (SMS.Alerts) {
            int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
            if (error != ERR_NO_ERROR)
               return(catch("onPositionClose(1)   error sending text message to "+ SMS.Receiver, error));
            Print("onPositionClose()   SMS sent to ", SMS.Receiver, ":  ", message);
         }
         else {
            Print("onPositionClose()   ", message);
         }
         playSound = true;                            // Flag für Sound-Status setzen
      }
   }

   if (Sound.Alerts) if (playSound)                   // max. ein Sound, auch bei mehreren Positionen
      PlaySound(Sound.File.PositionClose);

   return(catch("onPositionClose(2)"));
}


/**
 * Handler für BarOpen-Events.
 *
 * @param int timeframes[] - Flags der Timeframes, in denen das Event aufgetreten ist
 *
 * @return int - Fehlerstatus
 */
int onBarOpen(int timeframes[]) {
   // BollingerBand-Limite zurücksetzen
   if (Track.BollingerBands) {
      ArrayInitialize(Band.Limits, 0);
      EventTracker.SetBandLimits(Band.Limits);           // auch in Library
   }
   return(catch("onBarOpen()"));
}


/**
 * Prüft, ob die normalen Kurslimite verletzt wurden und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus
 */
int CheckGrid() {
   if (!Track.QuoteChanges)
      return(0);

   // aktuelle Limite ermitteln, ggf. neu berechnen
   if (Grid.Limits[0] == 0) if (!EventTracker.GetGridLimits(Grid.Limits)) {
      if (InitializeGrid() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);

      EventTracker.SetGridLimits(Grid.Limits);           // Limite in Library timeframe-übergreifend speichern
      return(catch("CheckGrid(1)"));                     // nach Initialisierung ist Test überflüssig
   }


   double gridSize = Grid.Size / 10000.0;
   string message, bid, ask;
   int    error;

   // Limite überprüfen
   if (Ask > Grid.Limits[1]) {
      message = StringConcatenate(Instrument.Name, " => ", DoubleToStr(Grid.Limits[1], 4));
      ask     = FormatPrice(Ask, Digits);

      // zuerst SMS, dann Sound
      if (SMS.Alerts) {
         error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != ERR_NO_ERROR)
            return(catch("CheckGrid(2)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Ask: ", ask, ")");
      }
      else {
         Print("CheckGrid()   ", message, "   (Ask: ", ask, ")");
      }
      if (Sound.Alerts)
         PlaySound(Sound.File.Up);

      Grid.Limits[1] = NormalizeDouble(Grid.Limits[1] + gridSize, 4);
      Grid.Limits[0] = NormalizeDouble(Grid.Limits[1] - gridSize - gridSize, 4);    // Abstand: 2 x GridSize
      EventTracker.SetGridLimits(Grid.Limits);                                      // neue Limite in Library speichern
      Print("CheckGrid()   Grid adjusted: ", DoubleToStr(Grid.Limits[0], 4), "  <=>  ", DoubleToStr(Grid.Limits[1], 4));
   }

   else if (Bid < Grid.Limits[0]) {
      message = StringConcatenate(Instrument.Name, " <= ", DoubleToStr(Grid.Limits[0], 4));
      bid     = FormatPrice(Bid, Digits);
      
      // zuerst SMS, dann Sound
      if (SMS.Alerts) {
         error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != ERR_NO_ERROR)
            return(catch("CheckGrid(3)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Bid: ", bid, ")");
      }
      else {
         Print("CheckGrid()   ", message, "   (Bid: ", bid, ")");
      }
      if (Sound.Alerts)
         PlaySound(Sound.File.Down);

      Grid.Limits[0] = NormalizeDouble(Grid.Limits[0] - gridSize, 4);
      Grid.Limits[1] = NormalizeDouble(Grid.Limits[0] + gridSize + gridSize, 4);    // Abstand: 2 x GridSize
      EventTracker.SetGridLimits(Grid.Limits);                                      // neue Limite in Library speichern
      Print("CheckGrid()   Grid adjusted: ", DoubleToStr(Grid.Limits[0], 4), "  <=>  ", DoubleToStr(Grid.Limits[1], 4));
   }

   return(catch("CheckGrid(4)"));
}


/**
 * Prüft, ob die aktuellen BollingerBand-Limite verletzt wurden und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_WILL_UPDATED, falls die Kurse gerade aktualisiert werden)
 */
int CheckBollingerBands() {
   if (!Track.BollingerBands)
      return(0);

   // Limite ggf. initialisieren
   if (Band.Limits[0] == 0) if (!EventTracker.GetBandLimits(Band.Limits)) {
      if (InitializeBandLimits() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);
      EventTracker.SetBandLimits(Band.Limits);                 // Limite in Library timeframe-übergreifend speichern
   }

   Print("CheckBollingerBands()   checking bands ...    ", FormatPrice(Band.Limits[2], Digits), "  <=  ", FormatPrice(Band.Limits[1], Digits), "  =>  ", FormatPrice(Band.Limits[0], Digits));

   double upperBand = Band.Limits[0]-0.000001,                 // +- 1/100 pip, um Fehler beim Vergleich von Doubles zu vermeiden
          movingAvg = Band.Limits[1]+0.000001,
          lowerBand = Band.Limits[2]+0.000001;

   //Print("CheckBollingerBands()   limits checked");
   return(catch("CheckBollingerBands(2)"));
}


/**
 * @return int - Fehlerstatus
 */
int CheckPivotLevels() {
   if (!Track.PivotLevels)
      return(0);

   return(catch("CheckPivotLevels()"));
}


/**
 * Initialisiert die aktuellen Grid-Limite.
 *
 * @return int - Fehlerstatus
 */
int InitializeGrid() {
   double gridSize = Grid.Size / 10000.0;
   int    faktor   = MathFloor((Bid+Ask) / 2.0 / gridSize);

   Grid.Limits[0] = NormalizeDouble(gridSize * faktor, 4);
   Grid.Limits[1] = NormalizeDouble(gridSize * (faktor+1), 4);             // Abstand: 1 x GridSize

   // letztes Signal ermitteln und Limit in diese Richtung auf 2 x GridSize erweitern
   bool up=false, down=false;
   int error, period=Period();                                             // Ausgangsbasis ist der aktuelle Timeframe

   while (!up && !down) {
      for (int bar=0; bar <= Bars-1; bar++) {
         // TODO: Verwendung von Bars ist nicht sauber
         if (iLow (NULL, period, bar) < Grid.Limits[0]) down = true;
         if (iHigh(NULL, period, bar) > Grid.Limits[1]) up   = true;

         error = GetLastError();
         if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
         if (error != ERR_NO_ERROR            ) return(catch("InitializeGrid(1)", error));

         if (up || down)
            break;
      }

      if (up && down) {                                                    // Bar hat beide Limite berührt
         if (period == PERIOD_M1)
            break;
         period = DecreasePeriod(period);                                  // Timeframe verringern
         up   = false;
         down = false;
      }
      else if (!up && !down) {
         return(catch("InitializeGrid(2)   error initializing grid limits", ERR_RUNTIME_ERROR));
      }
   }
   if (down) Grid.Limits[0] = NormalizeDouble(Grid.Limits[0] - gridSize, 4);
   if (up  ) Grid.Limits[1] = NormalizeDouble(Grid.Limits[1] + gridSize, 4);

   Print("InitializeGrid()   Grid initialized: ", DoubleToStr(Grid.Limits[0], 4), "  <=>  ", DoubleToStr(Grid.Limits[1], 4));
   return(catch("InitializeGrid(3)"));
}


/**
 * Initialisiert (berechnet und speichert) die aktuellen BollingerBand-Limite.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_WILL_UPDATED, falls die Kursreihe gerade aktualisiert wird)
 */
int InitializeBandLimits() {
   // für höhere Genauigkeit Timeframe wenn möglich auf M5 umrechnen
   int timeframe = BollingerBands.Timeframe;
   int periods   = BollingerBands.Periods;

   if (timeframe > PERIOD_M5) {
      double minutes = timeframe * periods;     // Timeframe * Anzahl Bars = Range in Minuten
      timeframe = PERIOD_M5;
      periods   = MathRound(minutes/PERIOD_M5);
   }

   int error = iBollingerBands(Symbol(), timeframe, periods, BollingerBands.MA.Method, PRICE_MEDIAN, BollingerBands.MA.Deviation, 0, Band.Limits);

   if (error == ERR_HISTORY_WILL_UPDATED) return(error);
   if (error != ERR_NO_ERROR            ) return(catch("InitializeBandLimits()", error));

   Print("InitializeBandLimits()   Bollinger band limits calculated: ", FormatPrice(Band.Limits[2], Digits), "  <=  ", FormatPrice(Band.Limits[1], Digits), "  =>  ", FormatPrice(Band.Limits[0], Digits));
   return(error);
}


/**
 * Berechnet die BollingerBand-Werte (UpperBand, MovingAverage, LowerBand) für eine Chart-Bar und speichert die Ergebnisse im angegebenen Array.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_WILL_UPDATED, falls die Kursreihe gerade aktualisiert wird)
 */
int iBollingerBands(string symbol, int timeframe, int periods, int maMethod, int appliedPrice, double deviation, int bar, double& results[]) {
   if (symbol == "0")      // MQL: NULL ist ein Integer
      symbol = Symbol();

   double ma  = iMA    (symbol, timeframe, periods, 0, maMethod, appliedPrice, bar);
   double dev = iStdDev(symbol, timeframe, periods, 0, maMethod, appliedPrice, bar) * deviation;
   results[0] = ma + dev;
   results[1] = ma;
   results[2] = ma - dev;

   int error = GetLastError();
   if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
   if (error != ERR_NO_ERROR            ) return(catch("iBollingerBands()", error));

   //Print("iBollingerBands(bar "+ bar +")   symbol: "+ symbol +"   timeframe: "+ timeframe +"   periods: "+ periods +"   maMethod: "+ maMethod +"   appliedPrice: "+ appliedPrice +"   deviation: "+ deviation +"   results: "+ FormatPrice(results[2], 5) +"  <=  "+ FormatPrice(results[1], 5) +"  =>  "+ FormatPrice(results[1], 5));
   return(error);
}


/**
 * EventTracker
 *
 * Überwacht ein Instrument auf verschiedene, konfigurierbare Signale und benachrichtigt optisch, akustisch und/oder per SMS.
 */

#include <stdlib.mqh>


#property indicator_chart_window


bool init       = false;
int  init_error = ERR_NO_ERROR;


//////////////////////////////////////////////////////////////// Default-Konfiguration ////////////////////////////////////////////////////////////

bool   Sound.Alerts                 = false;
string Sound.File.Up                = "alert3.wav";
string Sound.File.Down              = "alert4.wav";
string Sound.File.PositionOpen      = "OrderFilled.wav";
string Sound.File.PositionClose     = "PositionClosed.wav";

bool   SMS.Alerts                   = false;
string SMS.Receiver                 = "";

bool   Track.Positions              = false;

bool   Track.RateChanges            = false;
int    RateGrid.Size                = 0;

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

double RateGrid.Limits[2];                   // { UPPER_VALUE, LOWER_VALUE }
double Band.Limits[3];                       // { UPPER_VALUE, MA_VALUE, LOWER_VALUE }


/**
 *
 */
int init() {
   init = true;
   init_error = ERR_NO_ERROR;

   // ERR_TERMINAL_NOT_YET_READY abfangen
   if (!GetAccountNumber()) {
      init_error = GetLastLibraryError();
      return(init_error);
   }

   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(RateGrid.Limits, 0);
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
   int    account  = GetAccountNumber();
   string accounts = GetConfigString("EventTracker", "Track.Accounts", "");
   if (StringContains(","+accounts+",", ","+account+","))
      Track.Positions = true;

   // Kursänderungen
   Track.RateChanges = GetConfigBool(instrSection, "RateChanges", Track.RateChanges);
   if (Track.RateChanges) {
      RateGrid.Size = GetConfigInt(instrSection, "RateChanges.Gridsize", RateGrid.Size);
      if (RateGrid.Size < 1) {
         catch("init(2)  Invalid input parameter RateGrid.Size: "+ GetConfigString(instrSection, "RateChanges.Gridsize", ""), ERR_INVALID_INPUT_PARAMVALUE);
         Track.RateChanges = false;
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

   //Print("init()    Sound.Alerts=", Sound.Alerts, "   SMS.Alerts=", SMS.Alerts, "   Track.Positions=", Track.Positions, "   Track.RateChanges=", Track.RateChanges, IfString(Track.RateChanges, " (Grid: "+RateGrid.Size+")", ""), "   Track.BollingerBands=", Track.BollingerBands, "   Track.PivotLevels=", Track.PivotLevels);

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
   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                      // Aufruf nach erstem init()
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {           // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }


   // TODO: nach Config-Änderung Limite zurücksetzen

   int processedBars = IndicatorCounted();

   if (processedBars == 0) {                                   // Chartänderung => alle Limite zurücksetzen

      // TODO: processedBars ist bei jedem Timeframe-Wechsel 0, wir wollen processedBars==0 aber nur bei Chartänderungen detektieren

      //ArrayInitialize(RateGrid.Limits, 0);
      //EventTracker.SetRateGridLimits(RateGrid.Limits);

      ArrayInitialize(Band.Limits, 0);
      EventTracker.SetBandLimits(Band.Limits);
   }

   // Positionen
   if (Track.Positions) {                                      // nur pending Orders tracken, manuelle Market-Orders nicht
      HandleEvents(EVENT_POSITION_OPEN | EVENT_POSITION_CLOSE, OTFLAG_PENDINGORDER);  
   }

   // Kursänderungen
   if (Track.RateChanges)
      if (CheckRateGrid() == ERR_HISTORY_WILL_UPDATED)
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

   bool playSound = false;
   int  positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) {
         int error = GetLastError();
         if (error == ERR_NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         return(catch("onPositionOpen(1)   error selecting opened position with ticket #"+ tickets[i], error));
      }

      // nur Events des aktuellen Instruments berücksichtigen
      if (OrderSymbol() == Symbol()) {    // Unterscheidung von Limit- und Market-Orders ist hier nicht möglich und erfolgt im EventListener
         playSound = true;                // Flag für Sound-Status

         int digits = MarketInfo(OrderSymbol(), MODE_DIGITS);
         if (digits==3 || digits==5) string priceFormat = StringConcatenate(".", digits-1, "'");
         else                               priceFormat = StringConcatenate(".", digits);

         string type       = GetOperationTypeDescription(OrderType());
         string lots       = FormatNumber(OrderLots(), ".+");
         string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
         string price      = FormatNumber(OrderOpenPrice(), priceFormat);
         string message    = StringConcatenate("Position opened: ", type, " ", lots, " ", instrument, " @ ", price);

         // ggf. SMS verschicken
         if (SMS.Alerts) {
            error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
            if (error != ERR_NO_ERROR)
               return(catch("onPositionOpen(2)   error sending text message to "+ SMS.Receiver, error));
            Print("onPositionOpen()   SMS sent to ", SMS.Receiver, ":  ", message);
         }
         else {
            Print("onPositionOpen()   ", message);
         }
      }
   }

   // ggf. Sound abspielen (max. einmal)
   if (Sound.Alerts) if (playSound)
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
   int  positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET))
         continue;                        // TODO: Meldung ausgeben, daß der Filter im History-Tab aktuelle Transaktionen ausfiltert

      // nur Events des aktuellen Instruments berücksichtigen
      if (OrderSymbol() == Symbol()) {    // Unterscheidung von Limit- und Market-Orders erfolgt im EventListener
         playSound = true;                // Flag für Sound-Status

         int digits = MarketInfo(OrderSymbol(), MODE_DIGITS);
         if (digits==3 || digits==5) string priceFormat = StringConcatenate(".", digits-1, "'");
         else                               priceFormat = StringConcatenate(".", digits);

         string type       = GetOperationTypeDescription(OrderType());
         string lots       = FormatNumber(OrderLots(), ".+");
         string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
         string openPrice  = FormatNumber(OrderOpenPrice(), priceFormat);
         string closePrice = FormatNumber(OrderClosePrice(), priceFormat);
         string message    = StringConcatenate("Position closed: ", type, " ", lots, " ", instrument, " @ ", openPrice, " -> ", closePrice);

         // ggf. SMS verschicken
         if (SMS.Alerts) {
            int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
            if (error != ERR_NO_ERROR)
               return(catch("onPositionClose(1)   error sending text message to "+ SMS.Receiver, error));
            Print("onPositionClose()   SMS sent to ", SMS.Receiver, ":  ", message);
         }
         else {
            Print("onPositionClose()   ", message);
         }
      }
   }

   // ggf. Sound abspielen (max. einmal)
   if (Sound.Alerts) if (playSound)
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
int CheckRateGrid() {
   if (!Track.RateChanges)
      return(0);

   // aktuelle Limite ermitteln, ggf. neu berechnen
   if (RateGrid.Limits[0] == 0) if (!EventTracker.GetRateGridLimits(RateGrid.Limits)) {
      if (InitializeRateGrid() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);

      EventTracker.SetRateGridLimits(RateGrid.Limits);   // Limite in Library timeframe-übergreifend speichern
      return(catch("CheckRateGrid(1)"));                 // nach Initialisierung ist Test überflüssig
   }


   double gridSize = RateGrid.Size / 10000.0;
   string message, bid, ask;
   int    error;

   // Limite überprüfen
   if (Ask > RateGrid.Limits[1]) {
      message = StringConcatenate(Instrument.Name, " => ", DoubleToStr(RateGrid.Limits[1], 4));
      ask     = FormatNumber(Ask, StringConcatenate(".", Digits));

      // zuerst SMS, dann Sound
      if (SMS.Alerts) {
         error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != ERR_NO_ERROR)
            return(catch("CheckRateGrid(2)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckRateGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Ask: ", ask, ")");
      }
      else {
         Print("CheckRateGrid()   ", message, "   (Ask: ", ask, ")");
      }
      if (Sound.Alerts)
         PlaySound(Sound.File.Up);

      RateGrid.Limits[1] = NormalizeDouble(RateGrid.Limits[1] + gridSize, 4);
      RateGrid.Limits[0] = NormalizeDouble(RateGrid.Limits[1] - gridSize - gridSize, 4);  // Abstand: 2 x GridSize
      EventTracker.SetRateGridLimits(RateGrid.Limits);                                    // neue Limite in Library speichern
      Print("CheckRateGrid()   Grid adjusted: ", DoubleToStr(RateGrid.Limits[0], 4), "  <=>  ", DoubleToStr(RateGrid.Limits[1], 4));
   }

   else if (Bid < RateGrid.Limits[0]) {
      message = StringConcatenate(Instrument.Name, " <= ", DoubleToStr(RateGrid.Limits[0], 4));
      bid     = FormatNumber(Bid, StringConcatenate(".", Digits));

      // zuerst SMS, dann Sound
      if (SMS.Alerts) {
         error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != ERR_NO_ERROR)
            return(catch("CheckRateGrid(3)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckRateGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Bid: ", bid, ")");
      }
      else {
         Print("CheckRateGrid()   ", message, "   (Bid: ", bid, ")");
      }
      if (Sound.Alerts)
         PlaySound(Sound.File.Down);

      RateGrid.Limits[0] = NormalizeDouble(RateGrid.Limits[0] - gridSize, 4);
      RateGrid.Limits[1] = NormalizeDouble(RateGrid.Limits[0] + gridSize + gridSize, 4);  // Abstand: 2 x GridSize
      EventTracker.SetRateGridLimits(RateGrid.Limits);                                    // neue Limite in Library speichern
      Print("CheckRateGrid()   Grid adjusted: ", DoubleToStr(RateGrid.Limits[0], 4), "  <=>  ", DoubleToStr(RateGrid.Limits[1], 4));
   }

   return(catch("CheckRateGrid(4)"));
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

   string mask = StringConcatenate(".", Digits);
   Print("CheckBollingerBands()   checking bands ...    ", FormatNumber(Band.Limits[2], mask), "  <=  ", FormatNumber(Band.Limits[1], mask), "  =>  ", FormatNumber(Band.Limits[0], mask));

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
 * Initialisiert die aktuellen RateGrid-Limite.
 *
 * @return int - Fehlerstatus
 */
int InitializeRateGrid() {
   if (Digits==3 || Digits==5) int digits = Digits-1;
   else                            digits = Digits;

   double gridSize = RateGrid.Size / 10000.0;
   int    faktor   = MathFloor((Bid+Ask) / 2 / gridSize);

   RateGrid.Limits[0] = NormalizeDouble(gridSize * faktor    , digits);
   RateGrid.Limits[1] = NormalizeDouble(gridSize * (faktor+1), digits);    // Abstand: 1 x GridSize

   /*
   // letztes Signal ermitteln und Limit in diese Richtung auf 2 x GridSize erweitern
   bool up=false, down=false;
   int error, period=Period();                                             // Ausgangsbasis ist der aktuelle Timeframe

   while (!up && !down) {
      for (int bar=0; bar <= Bars-1; bar++) {
         // TODO: Verwendung von Bars ist nicht sauber
         if (iLow (NULL, period, bar) < RateGrid.Limits[0]) down = true;
         if (iHigh(NULL, period, bar) > RateGrid.Limits[1]) up   = true;

         error = GetLastError();
         if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
         if (error != ERR_NO_ERROR            ) return(catch("InitializeRateGrid(1)", error));

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
         return(catch("InitializeRateGrid(2)   error initializing grid limits", ERR_RUNTIME_ERROR));
      }
   }
   if (down) RateGrid.Limits[0] = NormalizeDouble(RateGrid.Limits[0] - gridSize, digits);
   if (up  ) RateGrid.Limits[1] = NormalizeDouble(RateGrid.Limits[1] + gridSize, digits);
   */

   Print("InitializeRateGrid()   Grid initialized: ", DoubleToStr(RateGrid.Limits[0], digits), "  <=>  ", DoubleToStr(RateGrid.Limits[1], digits));
   return(catch("InitializeRateGrid(3)"));
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

   string mask = StringConcatenate(".", Digits);
   Print("InitializeBandLimits()   Bollinger band limits calculated: ", FormatNumber(Band.Limits[2], mask), "  <=  ", FormatNumber(Band.Limits[1], mask), "  =>  ", FormatNumber(Band.Limits[0], mask));
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

   //Print("iBollingerBands(bar "+ bar +")   symbol: "+ symbol +"   timeframe: "+ timeframe +"   periods: "+ periods +"   maMethod: "+ maMethod +"   appliedPrice: "+ appliedPrice +"   deviation: "+ deviation +"   results: "+ FormatNumber(results[2], ".5") +"  <=  "+ FormatNumber(results[1], ".5") +"  =>  "+ FormatNumber(results[1], ".5"));
   return(error);
}


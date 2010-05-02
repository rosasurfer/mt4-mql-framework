/**
 * EventTracker
 *
 * Überwacht ein Instrument auf verschiedene, konfigurierbare Signale und benachrichtigt darüber optisch, akustisch und/oder per SMS.
 */

#include <stdlib.mqh>


#property indicator_chart_window


//////////////////////////////////////////////////////////////// Default-Konfiguration ////////////////////////////////////////////////////////////

bool   Sound.Alerts                 = true;
string Sound.File.Up                = "alert3.wav";
string Sound.File.Down              = "alert4.wav";
string Sound.File.PositionOpen      = "market order.wav";
string Sound.File.PositionClose     = "positionclosed.wav";

bool   SMS.Alerts                   = true;
string SMS.Receiver                 = "";

bool   Track.Positions              = false;

bool   Track.QuoteChanges           = false;
int    QuoteChanges.Gridsize        = 25;

bool   Track.BollingerBands         = false;
int    BollingerBands.MA.Timeframe  = 0;
int    BollingerBands.MA.Periods    = 0;
int    BollingerBands.MA.Method     = MODE_SMA;
double BollingerBands.Deviation     = 2;

bool   Track.PivotLevels            = false;
bool   PivotLevels.PreviousDayRange = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// sonstige Variablen
string Instrument.Name, Instrument.ShortName;


/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);


   // Konfiguration auswerten
   string symbols = GetConfigString("EventTracker", "Track.Symbols", "");

   // Soll das aktuelle Instrument überwacht werden?
   if (StringContains(","+symbols+",", ","+Symbol()+",")) {
      Instrument.Name      = GetConfigString("Instrument.Names"     , Symbol() , Symbol());
      Instrument.ShortName = GetConfigString("Instrument.ShortNames", Instrument.Name, Instrument.Name);

      // Sound- und SMS-Einstellungen
      Sound.Alerts = GetConfigBool("EventTracker", "Sound.Alerts", Sound.Alerts);
      SMS.Alerts   = GetConfigBool("EventTracker", "SMS.Alerts"  , SMS.Alerts);
      if (SMS.Alerts) {
         SMS.Receiver = GetConfigString("SMS", "Receiver", SMS.Receiver);
         if (!StringIsDigit(SMS.Receiver)) {
            catch("init(1)  invalid phone number SMS.Receiver: "+ SMS.Receiver, ERR_INVALID_INPUT_PARAMVALUE);
            SMS.Alerts = false;
         }
      }

      // offene Positionen
      string accounts = GetConfigString("EventTracker", "Track.Accounts", "");
      if (StringContains(","+accounts+",", ","+GetAccountNumber()+","))
         Track.Positions = true;

      string section = "EventTracker."+ Symbol();

      // Kursänderungen
      Track.QuoteChanges = GetConfigBool(section, "QuoteChanges"  , Track.QuoteChanges);
      if (Track.QuoteChanges) {
         QuoteChanges.Gridsize = GetConfigInt(section, "QuoteChanges.Gridsize", QuoteChanges.Gridsize);
         if (QuoteChanges.Gridsize < 1) {
            catch("init(2)  invalid value QuoteChanges.Gridsize: "+ GetConfigString(section, "QuoteChanges.Gridsize", ""), ERR_INVALID_INPUT_PARAMVALUE);
            Track.QuoteChanges = false;
         }
      }

      // Bollinger-Bänder
      Track.BollingerBands = GetConfigBool(section, "BollingerBands", Track.BollingerBands);
      if (Track.BollingerBands) {
         string value = GetConfigString(section, "BollingerBands.MA.Timeframe", BollingerBands.MA.Timeframe);
         BollingerBands.MA.Timeframe = GetPeriod(value);
         if (BollingerBands.MA.Timeframe == 0) {
            catch("init(3)  invalid value BollingerBands.MA.Timeframe: "+ value, ERR_INVALID_INPUT_PARAMVALUE);
            Track.BollingerBands = false;
         }
      }
      if (Track.BollingerBands) {
         BollingerBands.MA.Periods = GetConfigInt(section, "BollingerBands.MA.Periods", BollingerBands.MA.Periods);
         if (BollingerBands.MA.Periods < 2) {
            catch("init(4)  invalid value BollingerBands.MA.Periods: "+ GetConfigString(section, "BollingerBands.MA.Periods", ""), ERR_INVALID_INPUT_PARAMVALUE);
            Track.BollingerBands = false;
         }
      }
      if (Track.BollingerBands) {
         value = GetConfigString(section, "BollingerBands.MA.Method", BollingerBands.MA.Method);
         BollingerBands.MA.Method = GetMovingAverageMethod(value);
         if (BollingerBands.MA.Method < 0) {
            catch("init(5)  invalid value BollingerBands.MA.Method: "+ value, ERR_INVALID_INPUT_PARAMVALUE);
            Track.BollingerBands = false;
         }
      }
      if (Track.BollingerBands) {
         BollingerBands.Deviation = GetConfigDouble(section, "BollingerBands.Deviation", BollingerBands.Deviation);
         if (BollingerBands.Deviation < 0 || CompareDoubles(BollingerBands.Deviation, 0)) {
            catch("init(6)  invalid value BollingerBands.Deviation: "+ GetConfigString(section, "BollingerBands.Deviation", ""), ERR_INVALID_INPUT_PARAMVALUE);
            Track.BollingerBands = false;
         }
      }

      // Pivot-Level
      Track.PivotLevels = GetConfigBool(section, "PivotLevels", Track.PivotLevels);
      if (Track.PivotLevels)
         PivotLevels.PreviousDayRange = GetConfigBool(section, "PivotLevels.PreviousDayRange", PivotLevels.PreviousDayRange);
   }


   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   //Print("init()   Sound.Alerts="+ Sound.Alerts +"   SMS.Alerts="+ SMS.Alerts +"   Track.Positions: "+ Track.Positions +"   Track.QuoteChanges="+ Track.QuoteChanges +"   Track.BollingerBands="+ Track.BollingerBands +"   Track.PivotLevels="+ Track.PivotLevels);
   return(catch("init(7)"));
}


/**
 *
 */
int start() {
   if (IsConnected()) {                               // nur bei Verbindung zum Quoteserver
      int processedBars = IndicatorCounted();

      if (processedBars == 0) {                       // nach Start oder Data-Pumping
         // TODO: Limite neu initialisieren
      }
      else {
         if (Track.Positions) {
            HandleEvents(EVENT_POSITION_OPEN | EVENT_POSITION_CLOSE);
         }

         if (Track.QuoteChanges) {
            if (CheckQuoteChanges() == ERR_HISTORY_WILL_UPDATED)
               return(ERR_HISTORY_WILL_UPDATED);
         }

         if (Track.BollingerBands) {
            if (CheckBollingerBands() == ERR_HISTORY_WILL_UPDATED)
               return(ERR_HISTORY_WILL_UPDATED);
         }

         if (Track.PivotLevels) {
            CheckPivotLevels();
         }
      }
   }

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

   bool soundPlayed = false;
   int size = ArraySize(tickets);

   for (int i=0; i < size; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) // false: praktisch nahezu unmöglich
         continue;

      // nur PositionOpen-Events des aktuellen Instruments berücksichtigen
      if (Symbol() == OrderSymbol()) {
         if (Sound.Alerts) if (!soundPlayed) {        // max. 1 x Sound, auch bei mehreren Positionen
            PlaySound(Sound.File.PositionOpen);
            soundPlayed = true;
         }

         if (SMS.Alerts) {
            string type       = GetOperationTypeDescription(OrderType());
            string lots       = DoubleToStrTrim(OrderLots());
            string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
            string price      = FormatPrice(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS));

            string message = StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " Position opened: ", type, " ", lots, " ", instrument, " @ ", price);
            int error = SendTextMessage(SMS.Receiver, message);
            if (error != ERR_NO_ERROR)
               return(catch("onPositionOpen(1)   error sending text message to "+ SMS.Receiver, error));
            Print("onPositionOpen()   SMS sent to ", SMS.Receiver, ":  ", message);
         }
      }
   }

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

   bool soundPlayed = false;
   int size = ArraySize(tickets);

   for (int i=0; i < size; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) // false: praktisch nahezu unmöglich
         continue;

      // nur PositionClose-Events des aktuellen Instruments berücksichtigen
      if (Symbol() == OrderSymbol()) {
         if (Sound.Alerts) if (!soundPlayed) {        // max. 1 x Sound, auch bei mehreren Positionen
            PlaySound(Sound.File.PositionClose);
            soundPlayed = true;
         }

         if (SMS.Alerts) {
            string type       = GetOperationTypeDescription(OrderType());
            string lots       = DoubleToStrTrim(OrderLots());
            string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
            int    digits     = MarketInfo(OrderSymbol(), MODE_DIGITS);
            string openPrice  = FormatPrice(OrderOpenPrice(), digits);
            string closePrice = FormatPrice(OrderClosePrice(), digits);

            string message = StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " Position closed: ", type, " ", lots, " ", instrument, " @ ", openPrice, " -> ", closePrice);
            int error = SendTextMessage(SMS.Receiver, message);
            if (error != ERR_NO_ERROR)
               return(catch("onPositionClose(1)   error sending text message to "+ SMS.Receiver, error));
            Print("onPositionClose()   SMS sent to ", SMS.Receiver, ":  ", message);
         }
      }
   }

   return(catch("onPositionClose(2)"));
}


/**
 * @return int - Fehlerstatus
 */
int CheckQuoteChanges() {
   if (!Track.QuoteChanges)
      return(0);

   int error;

   double gridSize = QuoteChanges.Gridsize / 10000.0;
   double limits[2];                                     // {lowerLimit, upperLimit}

   // aktuelle Limite ermitteln
   if (limits[0] == 0) {                                 // sind Limite nicht initialisiert oder wurden Parameter geändert => Limite neu berechnen
      if (!EventTracker.QuoteLimits(limits) || UninitializeReason()==REASON_PARAMETERS) {
         if (CalculateQuoteLimits(gridSize, limits) == ERR_HISTORY_WILL_UPDATED)
            return(ERR_HISTORY_WILL_UPDATED);

         EventTracker.QuoteLimits(limits);               // Limite in Library speichern
         Print("CheckQuoteChanges()   quote limits initialized: "+ DoubleToStr(limits[0], 4) +"  <=>  "+ DoubleToStr(limits[1], 4));
         return(catch("CheckQuoteChanges(1)"));
      }
   }

   double upperLimit = limits[1]-0.000011,               // +- 1/10 pip, um Alert geringfügig früher auszulösen
          lowerLimit = limits[0]+0.000011;               // +- 1/100 pip, um Fehler beim Vergleich von Doubles zu vermeiden
   string message;

   // Limite überprüfen
   if (Ask > upperLimit) {
      if (Sound.Alerts)
         PlaySound(Sound.File.Up);

      if (SMS.Alerts) {
         message = StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", Instrument.ShortName, " => ", DoubleToStr(limits[1], 4));
         error = SendTextMessage(SMS.Receiver, message);
         if (error != ERR_NO_ERROR)
            return(catch("CheckQuoteChanges(2)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckQuoteChanges()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Ask: ", FormatPrice(Ask, Digits), ")");
      }

      limits[1] = NormalizeDouble(limits[1] + gridSize, 4);
      limits[0] = NormalizeDouble(limits[1] - gridSize - gridSize, 4);     // Abstand: 2 x GridSize
      EventTracker.QuoteLimits(limits);                                    // neue Limite in Library speichern
      Print("CheckQuoteChanges()   quote limits adjusted: "+ DoubleToStr(limits[0], 4) +"  <=>  "+ DoubleToStr(limits[1], 4));
   }
   else if (Bid < lowerLimit) {
      if (Sound.Alerts)
         PlaySound(Sound.File.Down);

      if (SMS.Alerts) {
         message = StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", Instrument.ShortName, " <= ", DoubleToStr(limits[0], 4));
         error = SendTextMessage(SMS.Receiver, message);
         if (error != ERR_NO_ERROR)
            return(catch("CheckQuoteChanges(3)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckQuoteChanges()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Bid: ", FormatPrice(Bid, Digits), ")");
      }

      limits[0] = NormalizeDouble(limits[0] - gridSize, 4);
      limits[1] = NormalizeDouble(limits[0] + gridSize + gridSize, 4);     // Abstand: 2 x GridSize
      EventTracker.QuoteLimits(limits);                                    // neue Limite in Library speichern
      Print("CheckQuoteChanges()   quote limits adjusted: ", DoubleToStr(limits[0], 4), "  <=>  ", DoubleToStr(limits[1], 4));
   }

   return(catch("CheckQuoteChanges(4)"));
}


/**
 * @return int - Fehlerstatus
 */
int CheckBollingerBands() {
   if (!Track.BollingerBands)
      return(0);

   double limits[3];                            // {upperBand, movingAvg, lowerBand}

   // aktuelle Limite ermitteln
   if (limits[0] == 0) {                        // sind Limite nicht initialisiert oder wurden Parameter geändert => Limite neu berechnen
      if (!EventTracker.BandLimits(limits) || UninitializeReason()==REASON_PARAMETERS) {   // TODO: statt Parameteränderung Konfig-Änderung überwachen
         if (CalculateBandLimits(limits) == ERR_HISTORY_WILL_UPDATED)
            return(ERR_HISTORY_WILL_UPDATED);

         EventTracker.BandLimits(limits);       // Limite in Library timeframe-übergreifend speichern
         Print("CheckBollingerBands()   band limits initialized: "+ DoubleToStr(limits[2], 4) +"  <  "+ DoubleToStr(limits[1], 4) +"  >  "+ DoubleToStr(limits[0], 4));
         return(catch("CheckBollingerBands(1)"));
      }
   }

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
 * Berechnet die aktuell gültigen normalen Kurslimite.
 *
 * @param double  gridSize   - Schrittweite der Limite
 * @param double& results[2] - Array zum Speichern der errechneten Werte {lowerLimit, upperLimit}
 *
 * @return int - Fehlerstatus
 */
int CalculateQuoteLimits(double gridSize, double& results[]) {
   int error;

   int faktor = MathFloor((Bid+Ask) / 2.0 / gridSize);

   results[0] = NormalizeDouble(gridSize * faktor, 4);
   results[1] = NormalizeDouble(gridSize * (faktor+1), 4);                 // Abstand: 1 x GridSize
   //Print("CalculateQuoteLimits()   simple quote limits: "+ DoubleToStr(results[0], 4) +"  <=>  "+ DoubleToStr(results[1], 4));

   // letztes Signal ermitteln und Limit in diese Richtung auf 2 x GridSize erweitern
   bool up=false, down=false;
   int period = Period();                                                  // Ausgangsbasis ist der aktuelle Timeframe

   while (!up && !down) {
      for (int bar=0; bar <= Bars-1; bar++) {
         // TODO: Verwendung von Bars ist nicht sauber
         if (iLow (NULL, period, bar) < results[0]+0.00001) down = true;   // nicht (double1 <= double2) verwenden (siehe CompareDoubles())
         if (iHigh(NULL, period, bar) > results[1]-0.00001) up   = true;

         error = GetLastError();
         if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
         if (error != ERR_NO_ERROR            ) return(catch("CalculateQuoteLimits(1)", error));

         if (up || down)
            break;
      }

      if (up && down) {                                                    // Bar hat beide Limite berührt
         if (period == PERIOD_M1)
            break;
         period = DecreasePeriod(period);                                  // Timeframe verringern
         //Print("CalculateQuoteLimits()   period decreased to: "+ GetPeriodDescription(period));
         up   = false;
         down = false;
      }
      else if (!up && !down) {
         return(catch("CalculateQuoteLimits(2)   error calculating quote limits", ERR_RUNTIME_ERROR));
      }
   }
   if (down) results[0] = NormalizeDouble(results[0] - gridSize, 4);
   if (up  ) results[1] = NormalizeDouble(results[1] + gridSize, 4);

   //Print("CalculateQuoteLimits()   quote limits calculated: "+ DoubleToStr(results[0], 4) +"  <=>  "+ DoubleToStr(results[1], 4));
   return(catch("CalculateQuoteLimits(3)"));
}


/**
 * Berechnet die aktuell gültigen BollingerBand-Limite.
 *
 * @param double& results[3] - Array zum Speichern der errechneten Werte {upperBand, movingAvg, lowerBand}
 *
 * @return int - Fehlerstatus
 */
int CalculateBandLimits(double& results[]) {
   int error = iBollingerBands(Symbol(), BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, BollingerBands.MA.Method, PRICE_MEDIAN, BollingerBands.Deviation, 0, results);
   
   if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
   if (error != ERR_NO_ERROR            ) return(catch("CalculateBandLimits(1)", error));

   //Print("CalculateBandLimits()   band limits calculated: "+ DoubleToStr(results[2], 4) +"  <  "+ DoubleToStr(results[1], 4) +"  >  "+ DoubleToStr(results[0], 4));
   return(catch("CalculateBandLimits(2)"));
}


/**
 * @return int - Fehlerstatus
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
   if (error == ERR_HISTORY_WILL_UPDATED)
      return(ERR_HISTORY_WILL_UPDATED);
   return(catch("iBollingerBands()", error));
}


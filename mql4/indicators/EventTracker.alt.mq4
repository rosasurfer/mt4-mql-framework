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

double quoteLimits[2];                       // {lowerLimit, upperLimit}
double bandLimits [3];                       // {MODE_BASE, MODE_UPPER, MODE_LOWER}



/**
 *
 */
int init() {
   // DataBox-Anzeige ausschalten
   SetIndexLabel(0, NULL);


   // nach jeder Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(quoteLimits, 0);
      ArrayInitialize(bandLimits , 0);
   }


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
   //Print("start()   IsConnected="+ IsConnected() +"   Bars: "+ Bars +"   processedBars: "+ IndicatorCounted());

   if (IsConnected()) {                               // nur bei Verbindung zum Quoteserver
      int processedBars = IndicatorCounted();

      if (processedBars == 0) {                       // Limite neu initialisieren
         /*      
         ArrayInitialize(quoteLimits, 0);
         ArrayInitialize(bandLimits , 0);

         if (Track.QuoteChanges) {
            //if (InitializeQuoteLimits(quoteLimits) == ERR_HISTORY_WILL_UPDATED)
            //   return(ERR_HISTORY_WILL_UPDATED);
         }

         if (Track.BollingerBands) {
            //if (InitializeBandLimits(bandLimits) == ERR_HISTORY_WILL_UPDATED)
            //   return(ERR_HISTORY_WILL_UPDATED);
         }

         if (Track.PivotLevels) {
            //if (InitializePivotLimits() == ERR_HISTORY_WILL_UPDATED)
            //   return(ERR_HISTORY_WILL_UPDATED);
         }
         */
      }
      else {
         if (Track.Positions)
            HandleEvents(EVENT_POSITION_OPEN | EVENT_POSITION_CLOSE);

         if (Track.QuoteChanges)
            if (CheckQuoteChanges() == ERR_HISTORY_WILL_UPDATED)
               return(ERR_HISTORY_WILL_UPDATED);

         if (Track.BollingerBands)
            if (CheckBollingerBands() == ERR_HISTORY_WILL_UPDATED)
               return(ERR_HISTORY_WILL_UPDATED);

         if (Track.PivotLevels)
            if (CheckPivotLevels() == ERR_HISTORY_WILL_UPDATED)
               return(ERR_HISTORY_WILL_UPDATED);
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
 * Prüft, ob die normalen Kurslimite verletzt wurden und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus
 */
int CheckQuoteChanges() {
   if (!Track.QuoteChanges)
      return(0);

   // TODO: nach Config-Änderung Limite zurücksetzen

   // aktuelle Limite ermitteln (und ggf. neu berechnen)
   if (quoteLimits[0] == 0) if (!EventTracker.QuoteLimits(quoteLimits)) {
      if (InitializeQuoteLimits(quoteLimits) == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);

      EventTracker.QuoteLimits(quoteLimits);             // Limite in Library speichern
      return(catch("CheckQuoteChanges(1)"));
   }


   double gridSize   = QuoteChanges.Gridsize / 10000.0;
   double upperLimit = quoteLimits[1]-0.000011,          // +-  1/10 pip, um Alert geringfügig früher auszulösen
          lowerLimit = quoteLimits[0]+0.000011;          // +- 1/100 pip, um Fehler beim Vergleich von Doubles zu vermeiden
   string message;
   int    error;

   // Limite überprüfen
   if (Ask > upperLimit) {
      if (Sound.Alerts)
         PlaySound(Sound.File.Up);

      if (SMS.Alerts) {
         message = StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", Instrument.ShortName, " => ", DoubleToStr(quoteLimits[1], 4));
         error = SendTextMessage(SMS.Receiver, message);
         if (error != ERR_NO_ERROR)
            return(catch("CheckQuoteChanges(2)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckQuoteChanges()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Ask: ", FormatPrice(Ask, Digits), ")");
      }

      quoteLimits[1] = NormalizeDouble(quoteLimits[1] + gridSize, 4);
      quoteLimits[0] = NormalizeDouble(quoteLimits[1] - gridSize - gridSize, 4);    // Abstand: 2 x GridSize
      EventTracker.QuoteLimits(quoteLimits);                                        // neue Limite in Library speichern
      Print("CheckQuoteChanges()   quote limits adjusted: "+ DoubleToStr(quoteLimits[0], 4) +"  <=>  "+ DoubleToStr(quoteLimits[1], 4));
   }
   else if (Bid < lowerLimit) {
      if (Sound.Alerts)
         PlaySound(Sound.File.Down);

      if (SMS.Alerts) {
         message = StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", Instrument.ShortName, " <= ", DoubleToStr(quoteLimits[0], 4));
         error = SendTextMessage(SMS.Receiver, message);
         if (error != ERR_NO_ERROR)
            return(catch("CheckQuoteChanges(3)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckQuoteChanges()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Bid: ", FormatPrice(Bid, Digits), ")");
      }

      quoteLimits[0] = NormalizeDouble(quoteLimits[0] - gridSize, 4);
      quoteLimits[1] = NormalizeDouble(quoteLimits[0] + gridSize + gridSize, 4);    // Abstand: 2 x GridSize
      EventTracker.QuoteLimits(quoteLimits);                                        // neue Limite in Library speichern
      Print("CheckQuoteChanges()   quote limits adjusted: ", DoubleToStr(quoteLimits[0], 4), "  <=>  ", DoubleToStr(quoteLimits[1], 4));
   }

   return(catch("CheckQuoteChanges(4)"));
}


/**
 * Prüft, ob die aktuellen BollingerBand-Limite verletzt wurden und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_WILL_UPDATED, falls die Kursreihe gerade aktualisiert wird)
 */
int CheckBollingerBands() {
   if (!Track.BollingerBands)
      return(0);

   // TODO: nach Config-Änderung Limite zurücksetzen

   // aktuelle Limite ermitteln (und ggf. neu berechnen)
   if (bandLimits[0] == 0) if (!EventTracker.BandLimits(bandLimits)) {
      if (InitializeBandLimits(bandLimits) == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);
      EventTracker.BandLimits(bandLimits);               // Limite in Library timeframe-übergreifend speichern
   }

   return(catch("CheckBollingerBands()"));
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
 * Initialisiert (berechnet und speichert) die aktuellen normalen Kurslimite.
 *
 * @param double& results[2] - Array zum Speichern der errechneten Werte {lowerLimit, upperLimit}
 *
 * @return int - Fehlerstatus
 */
int InitializeQuoteLimits(double& results[]) {
   double gridSize = QuoteChanges.Gridsize / 10000.0;
   int    faktor   = MathFloor((Bid+Ask) / 2.0 / gridSize);

   results[0] = NormalizeDouble(gridSize * faktor, 4);
   results[1] = NormalizeDouble(gridSize * (faktor+1), 4);                 // Abstand: 1 x GridSize
   //Print("InitializeQuoteLimits()   simple quote limits: "+ DoubleToStr(results[0], 4) +"  <=>  "+ DoubleToStr(results[1], 4));

   // letztes Signal ermitteln und Limit in diese Richtung auf 2 x GridSize erweitern
   bool up=false, down=false;
   int error, period=Period();                                             // Ausgangsbasis ist der aktuelle Timeframe

   while (!up && !down) {
      for (int bar=0; bar <= Bars-1; bar++) {
         // TODO: Verwendung von Bars ist nicht sauber
         if (iLow (NULL, period, bar) < results[0]+0.00001) down = true;   // nicht (double1 <= double2) verwenden (siehe CompareDoubles())
         if (iHigh(NULL, period, bar) > results[1]-0.00001) up   = true;

         error = GetLastError();
         if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
         if (error != ERR_NO_ERROR            ) return(catch("InitializeQuoteLimits(1)", error));

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
         return(catch("InitializeQuoteLimits(2)   error initializing quote limits", ERR_RUNTIME_ERROR));
      }
   }
   if (down) results[0] = NormalizeDouble(results[0] - gridSize, 4);
   if (up  ) results[1] = NormalizeDouble(results[1] + gridSize, 4);

   Print("InitializeQuoteLimits()   quote limits initialized: "+ DoubleToStr(results[0], 4) +"  <=>  "+ DoubleToStr(results[1], 4));
   return(catch("InitializeQuoteLimits(3)"));
}


/**
 * Initialisiert (berechnet und speichert) die aktuellen BollingerBand-Limite.
 *
 * @param double& results[3] - Array zum Speichern der errechneten Werte
 *
 * @return int - Fehlerstatus (ERR_HISTORY_WILL_UPDATED, falls die Kursreihe gerade aktualisiert wird)
 */
int InitializeBandLimits(double& results[]) {
   // für höhere Genauigkeit Timeframe möglichst auf M15 umrechnen
   int timeframe = BollingerBands.MA.Timeframe;
   int periods   = BollingerBands.MA.Periods;

   if (timeframe > PERIOD_M15) {
      double minutes = timeframe * periods;     // Timeframe * Anzahl Bars = Range in Minuten
      timeframe = PERIOD_M15;
      periods   = MathRound(minutes/PERIOD_M15);
   }

   int error = iBollingerBands(Symbol(), timeframe, periods, BollingerBands.MA.Method, PRICE_MEDIAN, BollingerBands.Deviation, 0, results);

   if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
   if (error != ERR_NO_ERROR            ) return(catch("InitializeBandLimits()", error));
   
   Print("InitializeBandLimits()   band limits initialized: "+ DoubleToStr(results[MODE_LOWER], 4) +"  <=  "+ DoubleToStr(results[MODE_BASE], 4) +"  =>  "+ DoubleToStr(results[MODE_UPPER], 4));
   return(error);
}


/**
 * Berechnet die BollingerBand-Werte (lowerBand, movingAverage, upperband) für eine Chart-Bar und speichert die Ergebnisse im angegebenen Array.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_WILL_UPDATED, falls die Kursreihe gerade aktualisiert wird)
 */
int iBollingerBands(string symbol, int timeframe, int periods, int maMethod, int appliedPrice, double deviation, int bar, double& results[]) {
   if (symbol == "0")      // MQL: NULL ist ein Integer
      symbol = Symbol();

   double ma  = iMA    (symbol, timeframe, periods, 0, maMethod, appliedPrice, bar);
   double dev = iStdDev(symbol, timeframe, periods, 0, maMethod, appliedPrice, bar) * deviation;
   results[MODE_UPPER] = ma + dev;
   results[MODE_BASE ] = ma;
   results[MODE_LOWER] = ma - dev;

   int error = GetLastError();
   if (error == ERR_HISTORY_WILL_UPDATED) return(ERR_HISTORY_WILL_UPDATED);
   if (error != ERR_NO_ERROR            ) return(catch("iBollingerBands()", error));
   
   //Print("iBollingerBands(bar "+ bar +")   symbol: "+ symbol +"   timeframe: "+ timeframe +"   periods: "+ periods +"   maMethod: "+ maMethod +"   appliedPrice: "+ appliedPrice +"   deviation: "+ deviation +"   results: "+ FormatPrice(results[MODE_LOWER], 5) +"  <=  "+ FormatPrice(results[MODE_BASE], 5) +"  =>  "+ FormatPrice(results[MODE_UPPER], 5));
   return(error);
}


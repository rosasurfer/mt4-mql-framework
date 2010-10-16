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
int    RateGrid.Size                = 0;           // GridSize in Pip

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

double RateGrid.Limits[2];                         // { UPPER_VALUE, LOWER_VALUE }
double Band.Limits[3];                             // { UPPER_VALUE, MA_VALUE, LOWER_VALUE }

int    gridDigits;
double gridSize;



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
      gridDigits = Digits - ifInt(Digits==3 || Digits==5, 1, 0);
      gridSize   = NormalizeDouble(RateGrid.Size * Point  * ifDouble(Digits==3 || Digits==5, 10, 1), gridDigits);
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

   //Print("init()    Sound.Alerts=", Sound.Alerts, "   SMS.Alerts=", SMS.Alerts, "   Track.Positions=", Track.Positions, "   Track.RateChanges=", Track.RateChanges, ifString(Track.RateChanges, " (Grid: "+RateGrid.Size+")", ""), "   Track.BollingerBands=", Track.BollingerBands, "   Track.PivotLevels=", Track.PivotLevels);

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


   // Accountwechsel erkennen
   int account = AccountNumber();

   static int      accountNumber[1];
   static datetime accountInitTime[1];                      // aktuelle, tatsächliche Server-Zeit (nicht die des letzten Ticks)

   if (accountNumber[0] == 0) {                             // 1. Lib-Aufruf
      accountNumber[0]   = account;
      accountInitTime[0] = GmtToServerTime(TimeLocal() - GetLocalToGmtOffset(-1));
      //Print("start()   Account "+ account +" nach 1. Lib-Aufruf initialisiert, ServerTime="+ TimeToStr(accountInitTime[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      return(catch("start(1)"));
   }
   else if (accountNumber[0] != account) {                  // Aufruf nach Accountwechsel zur Laufzeit
      accountNumber[0]   = account;
      accountInitTime[0] = GmtToServerTime(TimeLocal() - GetLocalToGmtOffset(-1));
      //Print("start()   Account "+ account +" nach Accountwechsel initialisiert, ServerTime="+ TimeToStr(accountInitTime[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      return(catch("start(2)"));
   }
   else if (TimeCurrent() < accountInitTime[0]) {           // alte Ticks abfangen (Data-Pumping etc.)
      //Print("start()   Account "+ account +"    alter Tick="+ FormatNumber(Close[0], ".4'"));
      return(catch("start(3)"));
   }


   // sämtliche Events werden nur nach einem neuen Tick überprüft
   //Print("start()   Account "+ account +"    neuer Tick="+ FormatNumber(Bid, ".4'"));

   // Positionen
   if (Track.Positions) {                                   // nur pending Orders des aktuellen Instruments tracken (manuelle nicht)
      HandleEvent(EVENT_POSITION_CLOSE, OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
      HandleEvent(EVENT_POSITION_OPEN , OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
   }

   // Kursänderungen
   if (Track.RateChanges)                                   // TODO: nach Config-Änderungen Limite zurücksetzen
      if (CheckRateGrid() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);




   int processedBars = IndicatorCounted();

   if (processedBars == 0) { // TODO: processedBars ist bei jedem Timeframe-Wechsel 0, wir wollen processedBars==0 aber nur bei Chartänderungen detektieren
      //ArrayInitialize(RateGrid.Limits, 0);
      //EventTracker.SetRateGridLimits(RateGrid.Limits);
      //ArrayInitialize(Band.Limits, 0);
      //EventTracker.SetBandLimits(Band.Limits);
   }


   // Bollinger-Bänder
   if (false && Track.BollingerBands) {
      HandleEvent(EVENT_BAR_OPEN, PERIODFLAG_M1);              // einmal je Minute die Limite aktualisieren
      if (CheckBollingerBands() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);
   }

   // Pivot-Level
   if (false && Track.PivotLevels)
      if (CheckPivotLevels() == ERR_HISTORY_WILL_UPDATED)
         return(ERR_HISTORY_WILL_UPDATED);

   return(catch("start()"));
}


/**
 * Handler für PositionOpen-Events. Die Unterscheidung von Limit- und Market-Orders erfolgt im EventListener.
 *
 * @param int tickets[] - Tickets der neuen Positionen
 *
 * @return int - Fehlerstatus
 */
int onPositionOpen(int tickets[]) {
   if (!Track.Positions)
      return(0);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) {
         int error = GetLastError();
         if (error == ERR_NO_ERROR)
            error = ERR_RUNTIME_ERROR;
         return(catch("onPositionOpen(1)   error selecting opened position #"+ tickets[i], error));
      }

      // alle Positionen sind im aktuellen Instrument
      if (Digits==3 || Digits==5) string priceFormat = StringConcatenate(".", Digits-1, "'");
      else                               priceFormat = StringConcatenate(".", Digits);

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

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Sound.File.PositionOpen);

   return(catch("onPositionOpen(2)"));
}


/**
 * Handler für PositionClose-Events. Die Unterscheidung von Limit- und Market-Orders erfolgt im EventListener.
 *
 * @param int tickets[] - Tickets der geschlossenen Positionen
 *
 * @return int - Fehlerstatus
 */
int onPositionClose(int tickets[]) {
   if (!Track.Positions)
      return(0);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET))
         continue;                        // TODO: Meldung ausgeben, daß der History-Tab-Filter aktuelle Transaktionen ausfiltert

      // alle Positionen sind im aktuellen Instrument
      if (Digits==3 || Digits==5) string priceFormat = StringConcatenate(".", Digits-1, "'");
      else                               priceFormat = StringConcatenate(".", Digits);

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

   // ggf. Sound abspielen
   if (Sound.Alerts)
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

   // Limite überprüfen
   if (Ask > RateGrid.Limits[1]) {
      string message = StringConcatenate(Instrument.Name, " => ", DoubleToStr(RateGrid.Limits[1], gridDigits));
      string ask     = FormatNumber(Ask, StringConcatenate(".", gridDigits, ifString(gridDigits==Digits, "", "'")));

      // zuerst SMS, dann Sound
      if (SMS.Alerts) {
         int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != ERR_NO_ERROR)
            return(catch("CheckRateGrid(2)   error sending text message to "+ SMS.Receiver, error));
         Print("CheckRateGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Ask: ", ask, ")");
      }
      else {
         Print("CheckRateGrid()   ", message, "   (Ask: ", ask, ")");
      }
      if (Sound.Alerts)
         PlaySound(Sound.File.Up);

      while (Ask > RateGrid.Limits[1]) {
         RateGrid.Limits[1] = NormalizeDouble(RateGrid.Limits[1] + gridSize, gridDigits);
      }
      RateGrid.Limits[0] = NormalizeDouble(RateGrid.Limits[1] - gridSize - gridSize, gridDigits);
      EventTracker.SetRateGridLimits(RateGrid.Limits);
      Print("CheckRateGrid()   Grid adjusted: ", DoubleToStr(RateGrid.Limits[0], gridDigits), "  <=>  ", DoubleToStr(RateGrid.Limits[1], gridDigits));
   }

   else if (Bid < RateGrid.Limits[0]) {
      message    = StringConcatenate(Instrument.Name, " <= ", DoubleToStr(RateGrid.Limits[0], gridDigits));
      string bid = FormatNumber(Bid, StringConcatenate(".", gridDigits, ifString(gridDigits==Digits, "", "'")));

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

      while (Bid < RateGrid.Limits[0]) {
         RateGrid.Limits[0] = NormalizeDouble(RateGrid.Limits[0] - gridSize, gridDigits);
      }
      RateGrid.Limits[1] = NormalizeDouble(RateGrid.Limits[0] + gridSize + gridSize, gridDigits);
      EventTracker.SetRateGridLimits(RateGrid.Limits);
      Print("CheckRateGrid()   Grid adjusted: ", DoubleToStr(RateGrid.Limits[0], gridDigits), "  <=>  ", DoubleToStr(RateGrid.Limits[1], gridDigits));
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


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

bool   Track.PivotLevels            = false;
bool   PivotLevels.PreviousDayRange = false;

bool   Track.BollingerBands         = false;
int    BollingerBands.Periods       = 0;
int    BollingerBands.Timeframe     = 0;
int    BollingerBands.MA.Method     = MODE_EMA;
double BollingerBands.MA.Deviation  = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// sonstige Variablen
string instrument, instrument.Name, instrument.Section;

double RateGrid.Limits[2];                         // { UPPER_VALUE, LOWER_VALUE }
double Band.Limits[3];                             // { UPPER_VALUE, MA_VALUE, LOWER_VALUE }

int    gridDigits;
double gridSize;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
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
   instrument         = GetGlobalConfigString("Instruments", Symbol(), Symbol());
   instrument.Name    = GetGlobalConfigString("Instrument.Names", instrument, instrument);
   instrument.Section = StringConcatenate("EventTracker.", instrument);

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
   string accounts = GetConfigString("EventTracker", "Track.Positions.Accounts", "");
   if (StringContains(","+accounts+",", ","+account+","))
      Track.Positions = true;

   // Kursänderungen
   Track.RateChanges = GetConfigBool(instrument.Section, "RateChanges", Track.RateChanges);
   if (Track.RateChanges) {
      RateGrid.Size = GetConfigInt(instrument.Section, "RateChanges.Gridsize", RateGrid.Size);
      if (RateGrid.Size < 1) {
         catch("init(2)  Invalid input parameter RateGrid.Size: "+ GetConfigString(instrument.Section, "RateChanges.Gridsize", ""), ERR_INVALID_INPUT_PARAMVALUE);
         Track.RateChanges = false;
      }
      gridDigits = Digits - ifInt(Digits==3 || Digits==5, 1, 0);
      gridSize   = NormalizeDouble(RateGrid.Size * Point  * ifDouble(Digits==3 || Digits==5, 10, 1), gridDigits);
   }

   // Pivot-Level
   Track.PivotLevels = GetConfigBool(instrument.Section, "PivotLevels", Track.PivotLevels);
   if (Track.PivotLevels)
      PivotLevels.PreviousDayRange = GetConfigBool(instrument.Section, "PivotLevels.PreviousDayRange", PivotLevels.PreviousDayRange);

   // Bollinger-Bänder
   Track.BollingerBands = GetConfigBool(instrument.Section, "BollingerBands", Track.BollingerBands);
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

   Print("init()    Sound.Alerts=", Sound.Alerts, "   SMS.Alerts=", SMS.Alerts, "   Track.Positions=", Track.Positions, "   Track.RateChanges=", Track.RateChanges, ifString(Track.RateChanges, " (Grid="+RateGrid.Size+")", ""), "   Track.PivotLevels=", Track.PivotLevels, "   Track.BollingerBands=", Track.BollingerBands);

   // nach Parameteränderung sofort start() aufrufen und nicht auf den nächsten Tick warten
   if (UninitializeReason() == REASON_PARAMETERS) {
      start();
      WindowRedraw();
   }

   return(catch("init(6)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   UnchangedBars = IndicatorCounted();
   ChangedBars   = Bars - UnchangedBars;
   stdLib_onTick(UnchangedBars);

   // init() nach ERR_TERMINAL_NOT_YET_READY nochmal aufrufen oder abbrechen
   if (init) {                                        // Aufruf nach erstem init()
      init = false;
      if (init_error != ERR_NO_ERROR)               return(0);
   }
   else if (init_error != ERR_NO_ERROR) {             // Aufruf nach Tick
      if (init_error != ERR_TERMINAL_NOT_YET_READY) return(0);
      if (init()     != ERR_NO_ERROR)               return(0);
   }


   // Accountinitialiserung abfangen (bei Start und Accountwechsel)
   if (AccountNumber() == 0)
      return(ERR_NO_CONNECTION);


   // aktuelle Accountdaten holen
   static int accountData[3];                               // { last_account_number, current_account_number, current_account_init_servertime }
   EventListener.AccountChange(accountData, 0);             // der Eventlistener gibt unabhängig vom Auftreten des Events immer die aktuellen Accountdaten zurück


   // alte Ticks abfangen, alle Events werden nur nach neuen Ticks überprüft
   if (TimeCurrent() < accountData[2]) {
      //Print("start()   Account "+ accountData[1] +"    alter Tick="+ NumberToStr(Close[0], ".4'"));
      return(catch("start(1)"));
   }
   //Print("start()   Account "+ accountData[1] +"    ServerTime="+ TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"    RealServerTime="+ TimeToStr(GmtToServerTime(TimeGMT()), TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"    accountInitTime="+ TimeToStr(accountData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"    neuer Tick="+ NumberToStr(Close[0], ".4'"));


   // Positionen
   if (Track.Positions) {                                   // nur pending Orders des aktuellen Instruments tracken (manuelle nicht)
      HandleEvent(EVENT_POSITION_CLOSE, OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
      HandleEvent(EVENT_POSITION_OPEN , OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
   }

   // Kursänderungen
   if (Track.RateChanges) {                                 // TODO: Limite nach Config-Änderungen reinitialisieren
      if (CheckRateGrid() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);
   }

   // Pivot-Level
   if (Track.PivotLevels)
      if (CheckPivotLevels() == ERR_HISTORY_UPDATE) {
         log("start(Tick="+ Tick +")    CheckPivotLevels() returned ERR_HISTORY_UPDATE");
         return(ERR_HISTORY_UPDATE);
      }

   // Bollinger-Bänder
   if (false && Track.BollingerBands) {
      HandleEvent(EVENT_BAR_OPEN, PERIODFLAG_M1);              // einmal je Minute die Limite aktualisieren
      if (CheckBollingerBands() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);
   }



   // TODO: UnchangedBars ist bei jedem Timeframe-Wechsel 0, wir wollen UnchangedBars==0 aber nur bei Chartänderungen detektieren
   if (UnchangedBars == 0) {
      //ArrayInitialize(RateGrid.Limits, 0);
      //EventTracker.SetRateGridLimits(RateGrid.Limits);
      //ArrayInitialize(Band.Limits, 0);
      //EventTracker.SetBandLimits(Band.Limits);
   }

   return(catch("start(2)"));
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

      string type       = OperationTypeToStr(OrderType());
      string lots       = NumberToStr(OrderLots(), ".+");
      string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
      string price      = NumberToStr(OrderOpenPrice(), priceFormat);
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

      string type       = OperationTypeToStr(OrderType());
      string lots       = NumberToStr(OrderLots(), ".+");
      string instrument = GetConfigString("Instrument.Names", OrderSymbol(), OrderSymbol());
      string openPrice  = NumberToStr(OrderOpenPrice(), priceFormat);
      string closePrice = NumberToStr(OrderClosePrice(), priceFormat);
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
 * @return int - Fehlerstatus (ggf. ERR_HISTORY_UPDATE)
 */
int CheckRateGrid() {
   if (!Track.RateChanges)
      return(0);

   // aktuelle Limite ermitteln, ggf. neu berechnen
   if (RateGrid.Limits[0] == 0) if (!EventTracker.GetRateGridLimits(RateGrid.Limits)) {
      if (InitializeRateGrid() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);

      EventTracker.SetRateGridLimits(RateGrid.Limits);   // Limite in Library timeframe-übergreifend speichern
      return(catch("CheckRateGrid(1)"));                 // nach Initialisierung ist Test überflüssig
   }

   // Limite überprüfen
   if (Ask > RateGrid.Limits[1]) {
      string message = instrument.Name +" => "+ DoubleToStr(RateGrid.Limits[1], gridDigits);
      string ask     = NumberToStr(Ask, "."+ gridDigits + ifString(gridDigits==Digits, "", "'"));

      // SMS verschicken
      if (SMS.Alerts) {
         if (SendTextMessage(SMS.Receiver, TimeToStr(TimeLocal(), TIME_MINUTES) +" "+ message) == ERR_NO_ERROR)
            Print("CheckRateGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Ask: ", ask, ")");
      }
      else Print("CheckRateGrid()   ", message, "   (Ask: ", ask, ")");

      // Sound abspielen
      if (Sound.Alerts)
         PlaySound(Sound.File.Up);

      // Signal speichern
      GlobalVariableSet("EventTracker."+ instrument +".RateGrid.LastSignal", RateGrid.Limits[1]);
      GlobalVariableSet("EventTracker."+ instrument +".RateGrid.LastTime" , ServerToGMT(TimeCurrent()));

      // Limite nachziehen
      while (Ask > RateGrid.Limits[1]) {
         RateGrid.Limits[1] = NormalizeDouble(RateGrid.Limits[1] + gridSize, gridDigits);
      }
      RateGrid.Limits[0] = NormalizeDouble(RateGrid.Limits[1] - gridSize - gridSize, gridDigits);
      EventTracker.SetRateGridLimits(RateGrid.Limits);
      Print("CheckRateGrid()   Grid adjusted: ", DoubleToStr(RateGrid.Limits[0], gridDigits), "  <=>  ", DoubleToStr(RateGrid.Limits[1], gridDigits));
   }

   else if (Bid < RateGrid.Limits[0]) {
      message    = instrument.Name +" <= "+ DoubleToStr(RateGrid.Limits[0], gridDigits);
      string bid = NumberToStr(Bid, "."+ gridDigits + ifString(gridDigits==Digits, "", "'"));

      // SMS verschicken
      if (SMS.Alerts) {
         if (SendTextMessage(SMS.Receiver, TimeToStr(TimeLocal(), TIME_MINUTES) +" "+ message) == ERR_NO_ERROR)
            Print("CheckRateGrid()   SMS sent to ", SMS.Receiver, ":  ", message, "   (Bid: ", bid, ")");
      }
      else Print("CheckRateGrid()   ", message, "   (Bid: ", bid, ")");

      // Sound abspielen
      if (Sound.Alerts)
         PlaySound(Sound.File.Down);

      // Signal speichern
      GlobalVariableSet("EventTracker."+ instrument +".RateGrid.LastSignal", RateGrid.Limits[0]);
      GlobalVariableSet("EventTracker."+ instrument +".RateGrid.LastTime" , ServerToGMT(TimeCurrent()));

      // Limite nachziehen
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
 * Initialisiert die aktuellen RateGrid-Limite.
 *
 * @return int - Fehlerstatus (ggf. ERR_HISTORY_UPDATE)
 */
int InitializeRateGrid() {
   //Print("InitializeRateGrid()   bars="+ Bars +"    unchangedBars="+ IndicatorCounted() +"    ServerTime="+ TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"    Time[0]="+ TimeToStr(Time[0]) +"    Close[0]="+ NumberToStr(Close[0], "."+gridDigits+"\'") +"    Bid="+ NumberToStr(Bid, "."+gridDigits+"\'"));

   int cells = MathFloor((Bid+Ask)/2 / gridSize);

   static double limits[2];
   limits[0] = NormalizeDouble(gridSize *  cells   , gridDigits);
   limits[1] = NormalizeDouble(gridSize * (cells+1), gridDigits);    // Abstand: 1 x GridSize
   //Print("InitializeRateGrid()   grid cells initialized: ", DoubleToStr(limits[0], gridDigits), "  <=>  ", DoubleToStr(limits[1], gridDigits));

   bool up, down;
   int  period = Period();                                                    // Ausgangsbasis ist der aktuelle Timeframe

   // wenn vorhanden, letztes Signal auslesen
   string varLastSignalValue = "EventTracker."+ instrument +".RateGrid.LastSignal",
          varLastSignalTime  = "EventTracker."+ instrument +".RateGrid.LastTime";

   bool     lastSignal;
   double   lastSignalValue = GlobalVariableGet(varLastSignalValue);
   datetime lastSignalTime  = GlobalVariableGet(varLastSignalTime );
   int      lastSignalBar   = -1;

   int error = GetLastError();
   if (error != ERR_NO_ERROR) if (error != ERR_GLOBAL_VARIABLE_NOT_FOUND)
      return(catch("InitializeRateGrid(1)", error));

   if (lastSignalValue > 0) if (lastSignalTime > 0) {
      if (lastSignalValue <= limits[0] || lastSignalValue >= limits[1]) {
         //Print("InitializeRateGrid()    last stored signal: "+ DoubleToStr(lastSignalValue, gridDigits) +" is ignored (not inside of cells)");
      }
      else {
         lastSignal     = true;
         lastSignalTime = GmtToServerTime(lastSignalTime);
         //Print("InitializeRateGrid()    last stored signal: "+ DoubleToStr(lastSignalValue, gridDigits) +" at ServerTime="+ TimeToStr(lastSignalTime));
      }
   }

   // tatsächliches, letztes Signal ermitteln und Limit in diese Richtung auf 2 x GridSize erweitern
   while (!up && !down) {
      //Print("InitializeRateGrid()    looking for last signal in timeframe "+ PeriodToStr(period) +" and lastSignal="+ lastSignal);
      if (lastSignal) {
         lastSignalBar = iBarShiftPrevious(NULL, period, lastSignalTime);     // kann ERR_HISTORY_UPDATE auslösen (return=EMPTY_VALUE)
         if (lastSignalBar == EMPTY_VALUE) {
            error = GetLastLibraryError();
            if (error == ERR_HISTORY_UPDATE)
               return(error);
            if (error == ERR_NO_ERROR)
               error = ERR_RUNTIME_ERROR;
            return(catch("InitializeRateGrid(2)", error));
         }
      }
      //Print("InitializeRateGrid()    looking for last signal in timeframe "+ PeriodToStr(period) +" with lastSignalBar="+ lastSignalBar);

      for (int bar=0; bar <= Bars-1; bar++) {
         if (bar == lastSignalBar) {
            down = (MathMin(lastSignalValue, iLow (NULL, period, bar)) <= limits[0]);
            up   = (MathMax(lastSignalValue, iHigh(NULL, period, bar)) >= limits[1]);
         }
         else {
            down = (iLow (NULL, period, bar) <= limits[0]);
            up   = (iHigh(NULL, period, bar) >= limits[1]);
         }

         error = GetLastError();
         if (error == ERR_HISTORY_UPDATE) return(error);
         if (error != ERR_NO_ERROR      ) return(catch("InitializeRateGrid(2)", error));

         if (up || down) {
            //Print("InitializeRateGrid()    last signal found in timeframe "+ PeriodToStr(period) +" at bar="+ bar);
            break;
         }
      }
      if (!up && !down)                                                       // Grid ist zu groß: Limite bleiben bei Abstand = 1 x GridSize
         break;

      if (up && down) {                                                       // Bar hat beide Limite berührt
         if (period == PERIOD_M1)
            break;
         //Print("InitializeRateGrid()    bar "+ bar +" in timeframe "+ PeriodToStr(period) +" touched both limits, decreasing timeframe");
         period = DecreasePeriod(period);                                     // Timeframe verringern
         up = false; down = false;
      }
   }
   /*
   if      ( up &&  down) Print("InitializeRateGrid()    bar "+ bar +" in timeframe "+ PeriodToStr(period) +" touched both limits");
   else if (!up || !down) Print("InitializeRateGrid()    bar "+ bar +" in timeframe "+ PeriodToStr(period) +" touched one limit");
   else                   Print("InitializeRateGrid()    no bar ever touched a limit");
   */

   if (down) limits[0] = NormalizeDouble(limits[0] - gridSize, gridDigits);
   if (up  ) limits[1] = NormalizeDouble(limits[1] + gridSize, gridDigits);

   RateGrid.Limits[0] = limits[0];
   RateGrid.Limits[1] = limits[1];

   Print("InitializeRateGrid()   Grid initialized: ", DoubleToStr(RateGrid.Limits[0], gridDigits), "  <=>  ", DoubleToStr(RateGrid.Limits[1], gridDigits));
   return(catch("InitializeRateGrid(3)"));
}


/**
 * @return int - Fehlerstatus (ggf. ERR_HISTORY_UPDATE)
 */
int CheckPivotLevels() {
   if (!Track.PivotLevels)
      return(0);

   static bool done;
   if (done) return(0);


   // Pivot-Level ermitteln
   // ---------------------
   double today[4];
   int period = PERIOD_H1;
   int error = iOHLCTime(today, NULL, period, TimeCurrent());

   if (error != ERR_NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE)
         catch("CheckPivotLevels()    iOHLCTime() returned unexpected", error);
      return(error);
   }

   double todaysHigh = today[MODE_HIGH];
   double todaysLow  = today[MODE_LOW ];

   Print("CheckPivotLevels()    todaysHigh("+ PeriodToStr(period) +")="+ NumberToStr(todaysHigh, ".4'"));
   Print("CheckPivotLevels()    todaysLow(" + PeriodToStr(period) +")="+ NumberToStr(todaysLow , ".4'"));


   // yesterdayHigh
   // yesterdayLow
   // yesterdayClose
   // yesterdayInsideDay


   // Pivot-Level überprüfen
   // ----------------------

   done = true;
   return(catch("CheckPivotLevels()"));
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitpunkt einer Periode und schreibt sie in das angegebene Zielarray.
 * Die Ergebnisse sind die Werte der Bar, die den Zeitpunkt abdeckt.
 *
 * @param  double&  destination[4] - Zielarray für die Werte { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string   symbol         - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int      timeframe      - Periode (default: 0 = aktuelle Periode)
 * @param  datetime time           - Zeitpunkt
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn für den angegebenen Zeitpunkt keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 */
int iOHLCTime(double& destination[4], string symbol/*=NULL*/, int timeframe/*=0*/, datetime time) {
   if (symbol == "0")                                       // MQL: NULL ist ein Integer (0)
      symbol = Symbol();

   // Timeframe kleiner H4
   if (timeframe < PERIOD_H4) {
      // um ERR_HISTORY_UPDATE zu vermeiden, nach Möglichkeit die aktuelle Chartperiode benutzen

      // (1) prüfen, ob Chartperiode paßt
      if (Period() <= timeframe) {
         // ja
         // (2) Beginn- und Endzeit der gefragten Periode berechnen
         // (3) Beginn- und Endbars ermitteln
         // (4) OHLC für diese Range ermitteln
      }
      else {
         // nein
      }



      int bar   = iBarShift(symbol, timeframe, time, true);
      int error = GetLastError();                           // ERR_HISTORY_UPDATE ???

      if (error != ERR_NO_ERROR) {
         if (error != ERR_HISTORY_UPDATE) catch("iOHLCTime(1)", error);
         return(error);
      }
      if (bar == -1)                                        // keine Kurse für diesen Zeitpunkt
         return(ERR_NO_RESULT);

      destination[MODE_OPEN ] = iOpen (symbol, timeframe, bar);
      destination[MODE_HIGH ] = iHigh (symbol, timeframe, bar);
      destination[MODE_LOW  ] = iLow  (symbol, timeframe, bar);
      destination[MODE_CLOSE] = iClose(symbol, timeframe, bar);
   }
   else {
      // Timeframe größer H1: auf H1 herunterbrechen
      log("iOHLCTime(1.2)");
   }

   return(catch("iOHLCTime(2)"));

   iOHLCBar      (destination, 0, 0, 0);
   iOHLCBarRange (destination, 0, 0, 0, 0);
   iOHLCTimeRange(destination, 0, 0, 0);
}

int iOHLCTimeRange(double& destination[4], string symbol/*=NULL*/, datetime from, datetime to) {}
int iOHLCBar      (double& destination[4], string symbol/*=NULL*/, int timeframe/*=0*/, int bar) {}
int iOHLCBarRange (double& destination[4], string symbol/*=NULL*/, int timeframe/*=0*/, int from, int to) {}

/**
 * Prüft, ob die aktuellen BollingerBand-Limite verletzt wurden und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_UPDATE, falls die Kurse gerade aktualisiert werden)
 */
int CheckBollingerBands() {
   if (!Track.BollingerBands)
      return(0);

   // Limite ggf. initialisieren
   if (Band.Limits[0] == 0) if (!EventTracker.GetBandLimits(Band.Limits)) {
      if (InitializeBandLimits() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);
      EventTracker.SetBandLimits(Band.Limits);                 // Limite in Library timeframe-übergreifend speichern
   }

   string mask = StringConcatenate(".", Digits);
   Print("CheckBollingerBands()   checking bands ...    ", NumberToStr(Band.Limits[2], mask), "  <=  ", NumberToStr(Band.Limits[1], mask), "  =>  ", NumberToStr(Band.Limits[0], mask));

   double upperBand = Band.Limits[0]-0.000001,                 // +- 1/100 pip, um Fehler beim Vergleich von Doubles zu vermeiden
          movingAvg = Band.Limits[1]+0.000001,
          lowerBand = Band.Limits[2]+0.000001;

   //Print("CheckBollingerBands()   limits checked");
   return(catch("CheckBollingerBands(2)"));
}


/**
 * Initialisiert (berechnet und speichert) die aktuellen BollingerBand-Limite.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_UPDATE, falls die Kursreihe gerade aktualisiert wird)
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

   if (error == ERR_HISTORY_UPDATE) return(error);
   if (error != ERR_NO_ERROR      ) return(catch("InitializeBandLimits()", error));

   string mask = StringConcatenate(".", Digits);
   Print("InitializeBandLimits()   Bollinger band limits calculated: ", NumberToStr(Band.Limits[2], mask), "  <=  ", NumberToStr(Band.Limits[1], mask), "  =>  ", NumberToStr(Band.Limits[0], mask));
   return(error);
}


/**
 * Berechnet die BollingerBand-Werte (UpperBand, MovingAverage, LowerBand) für eine Chart-Bar und speichert die Ergebnisse im angegebenen Array.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_UPDATE, falls die Kursreihe gerade aktualisiert wird)
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
   if (error == ERR_HISTORY_UPDATE) return(ERR_HISTORY_UPDATE);
   if (error != ERR_NO_ERROR      ) return(catch("iBollingerBands()", error));

   //Print("iBollingerBands(bar "+ bar +")   symbol: "+ symbol +"   timeframe: "+ timeframe +"   periods: "+ periods +"   maMethod: "+ maMethod +"   appliedPrice: "+ appliedPrice +"   deviation: "+ deviation +"   results: "+ NumberToStr(results[2], ".5") +"  <=  "+ NumberToStr(results[1], ".5") +"  =>  "+ NumberToStr(results[1], ".5"));
   return(error);
}


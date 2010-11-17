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
      init_error = stdlib_GetLastError();
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
   //Print("init()    Sound.Alerts=", Sound.Alerts, "   SMS.Alerts=", SMS.Alerts, "   Track.Positions=", Track.Positions, "   Track.RateChanges=", Track.RateChanges, ifString(Track.RateChanges, " (Grid="+RateGrid.Size+")", ""), "   Track.PivotLevels=", Track.PivotLevels, "   Track.BollingerBands=", Track.BollingerBands);

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
   stdlib_onTick(UnchangedBars);
   //log("start(Tick="+ Tick +")   UnchangedBars="+ UnchangedBars +"   ChangedBars="+ ChangedBars);

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
   if (TimeCurrent() < accountData[2])
      return(catch("start(1)"));
   //Print("start()   account="+ accountData[1] +"   ServerTime="+ TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   RealServerTime="+ TimeToStr(GmtToServerTime(TimeGMT()), TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   accountInitTime="+ TimeToStr(accountData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   neuer Tick="+ NumberToStr(Close[0], ".4'"));


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
   if (Track.PivotLevels) {
      if (CheckPivotLevels() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);
   }

   // Bollinger-Bänder
   if (false && Track.BollingerBands) {
      HandleEvent(EVENT_BAR_OPEN, PERIODFLAG_M1);              // einmal je Minute die Limite aktualisieren
      if (CheckBollingerBands() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);
   }


   /* // TODO: UnchangedBars ist bei jedem Timeframe-Wechsel 0, wir wollen UnchangedBars==0 aber nur bei Chartänderungen detektieren
   if (UnchangedBars == 0) {
      ArrayInitialize(RateGrid.Limits, 0);
      EventTracker.SetRateGridLimits(RateGrid.Limits);
      ArrayInitialize(Band.Limits, 0);
      EventTracker.SetBandLimits(Band.Limits);
   } */
   return(catch("start(2)"));

   double destination[4]; iOHLCBar(destination, 0, 0, 0); iOHLCBarRange(destination, 0, 0, 0, 0); iOHLCTime(destination, 0, 0, 0); iOHLCTimeRange(destination, 0, 0, 0);
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
   int period = PERIOD_D1;
   int from   = 1;
   int to     = 1;

   double today[4];
   //int error = iOHLCBarRange(today, NULL, period, from, to);
   int error = iOHLCTimeRange(today, NULL, D'2010.11.10 00:00:10', D'2010.11.11 23:59:30');

   if (error != ERR_NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE)
         catch("CheckPivotLevels()    iOHLCTimeRange() returned unexpected error", error);
      log("CheckPivotLevels()    iOHLCTimeRange() returned "+ ErrorToID(error));
      return(error);
   }

   //Print("CheckPivotLevels("+ PeriodToStr(period) +")    from="+ TimeToStr(iTime(NULL, period, from)) +"   to="+ TimeToStr(iTime(NULL, period, to)+ period*MINUTES));
   Print("CheckPivotLevels("+ PeriodToStr(period) +")    Open="+ NumberToStr(today[MODE_OPEN], ".4'") +"    High="+ NumberToStr(today[MODE_HIGH], ".4'") +"    Low="+ NumberToStr(today[MODE_LOW], ".4'") +"    Close="+ NumberToStr(today[MODE_CLOSE], ".4'"));


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
 * Ermittelt die OHLC-Werte eines Instruments für eine einzelne Bar einer Periode und schreibt sie in das angegebene Zielarray.
 * Existiert die angegebene Bar nicht, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double& destination[4] - Zielarray für die Werte { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string  symbol         - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     timeframe      - Periode (default: 0 = aktuelle Periode)
 * @param  int     bar            - Bar-Offset
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Bar nicht existiert,
 *                             ggf. ERR_HISTORY_UPDATE
 *
 * NOTE:    Diese Funktion wertet die in der History gespeicherten Bars unabhängig davon aus, ob diese Bars realen Bars entsprechen.
 * -----    Siehe: iOHLCTime(destination, symbol, timeframe, time, exact=TRUE)
 */
int iOHLCBar(double& destination[4], string symbol/*=NULL*/, int timeframe/*=0*/, int bar) {
   if (symbol == "0")                           // NULL ist ein Integer (0)
      symbol = Symbol();

   if (bar < 0)
      return(catch("iOHLCBar(1)  invalid parameter bar: "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE));

   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden
   destination[MODE_OPEN ] = iOpen (symbol, timeframe, bar);
   destination[MODE_HIGH ] = iHigh (symbol, timeframe, bar);
   destination[MODE_LOW  ] = iLow  (symbol, timeframe, bar);
   destination[MODE_CLOSE] = iClose(symbol, timeframe, bar);

   int error = GetLastError();                  // ERR_HISTORY_UPDATE ???

   if (error != ERR_NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE)
         catch("iOHLCBar(2)", error);
   }
   else if (destination[MODE_OPEN] == 0) {
      error = ERR_NO_RESULT;
   }
   return(error);
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für eine Bar-Range einer Periode und schreibt sie in das angegebene Zielarray.
 * Existiert die angegebene Startbar (from) nicht, wird die nächste existierende Bar verwendet.
 * Existiert die angegebene Endbar (to) nicht, wird die letzte existierende Bar verwendet.
 * Existiert die resultierende Bar-Range nicht, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double& destination[4] - Zielarray für die Werte { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string  symbol         - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     timeframe      - Periode (default: 0 = aktuelle Periode)
 * @param  int     from           - Offset der Startbar
 * @param  int     to             - Offset der Endbar
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Range nicht existiert,
 *                             ggf. ERR_HISTORY_UPDATE
 *
 * NOTE:    Diese Funktion wertet die in der History gespeicherten Bars unabhängig davon aus, ob diese Bars realen Bars entsprechen.
 * -----    Siehe: iOHLCTime(destination, symbol, timeframe, time, exact=TRUE)
 */
int iOHLCBarRange(double& destination[4], string symbol/*=NULL*/, int timeframe/*=0*/, int from, int to) {
   if (symbol == "0")                           // NULL ist ein Integer (0)
      symbol = Symbol();

   if (from < 0) return(catch("iOHLCBarRange(1)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (to   < 0) return(catch("iOHLCBarRange(2)  invalid parameter to: "  + to  , ERR_INVALID_FUNCTION_PARAMVALUE));

   if (from < to) {
      int tmp = from;
      from = to;
      to   = tmp;
   }

   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden
   int bars = iBars(symbol, timeframe);

   int error = GetLastError();                  // ERR_HISTORY_UPDATE ???
   if (error != ERR_NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE)
         catch("iOHLCBarRange(3)", error);
      return(error);
   }

   if (bars-1 < to) {                           // History enthält zu wenig Daten in dieser Periode
      destination[MODE_OPEN ] = 0;
      destination[MODE_HIGH ] = 0;
      destination[MODE_LOW  ] = 0;
      destination[MODE_CLOSE] = 0;
      return(ERR_NO_RESULT);
   }

   if (from > bars-1)
      from = bars-1;

   int high=from, low=from;

   if (from != to) {
      high = iHighest(symbol, timeframe, MODE_HIGH, from-to+1, to);
      low  = iLowest (symbol, timeframe, MODE_LOW , from-to+1, to);
      error = GetLastError();                   // ERR_HISTORY_UPDATE ???
      if (error != ERR_NO_ERROR) if (error != ERR_HISTORY_UPDATE)
         catch("iOHLCBarRange(4)", error);
      return(error);
   }

   destination[MODE_OPEN ] = iOpen (symbol, timeframe, from);
   destination[MODE_HIGH ] = iHigh (symbol, timeframe, high);
   destination[MODE_LOW  ] = iLow  (symbol, timeframe, low );
   destination[MODE_CLOSE] = iClose(symbol, timeframe, to  );

   error = GetLastError();                      // ERR_HISTORY_UPDATE ???
   if (error != ERR_NO_ERROR) if (error != ERR_HISTORY_UPDATE)
      catch("iOHLCBarRange(5)", error);
   return(error);
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitpunkt einer Periode und schreibt sie in das angegebene Zielarray.
 * Ergebnis sind die Werte der Bar, die diesen Zeitpunkt abdeckt.
 *
 * @param  double&  destination[4] - Zielarray für die Werte { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string   symbol         - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int      timeframe      - Periode (default: 0 = aktuelle Periode)
 * @param  datetime time           - Zeitpunkt
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn für den Zeitpunkt keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 */
int iOHLCTime(double& destination[4], string symbol/*=NULL*/, int timeframe/*=0*/, datetime time) {
   if (symbol == "0")                           // NULL ist ein Integer (0)
      symbol = Symbol();

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden
   int bar = iBarShift(symbol, timeframe, time, true);

   int error = GetLastError();                  // ERR_HISTORY_UPDATE ???
   if (error != ERR_NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE)
         catch("iOHLCTime(1)", error);
      return(error);
   }

   if (bar == -1) {                             // keine Kurse für diesen Zeitpunkt
      destination[MODE_OPEN ] = 0;
      destination[MODE_HIGH ] = 0;
      destination[MODE_LOW  ] = 0;
      destination[MODE_CLOSE] = 0;
      return(ERR_NO_RESULT);
   }

   error = iOHLCBar(destination, symbol, timeframe, bar);

   if (error != ERR_NO_ERROR) if (error != ERR_HISTORY_UPDATE)
      catch("iOHLCTime(2)", error);
   return(error);
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitraum und schreibt sie in das angegebene Zielarray.
 * Existieren in diesem Zeitraum keine Kurse, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double&  destination[4] - Zielarray für die Werte { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string   symbol         - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  datetime from           - Beginn des Zeitraumes
 * @param  datetime to             - Ende des Zeitraumes
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn im Zeitraum keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 */
int iOHLCTimeRange(double& destination[4], string symbol/*=NULL*/, datetime from, datetime to) {
   if (symbol == "0")                           // NULL ist ein Integer (0)
      symbol = Symbol();

   if (from < 0) return(catch("iOHLCTimeRange(1)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (to   < 0) return(catch("iOHLCTimeRange(2)  invalid parameter to: "  + to  , ERR_INVALID_FUNCTION_PARAMVALUE));

   if (from > to) {
      datetime tmp = from;
      from = to;
      to   = tmp;
   }

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   // größtmögliche für from und to geeignete Periode bestimmen
   int pMinutes[60] = { PERIOD_H1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M15, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M30, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M15, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1 };
   int pHours  [24] = { PERIOD_D1, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1 };

   int tSec = TimeSeconds(to);                  // 'to' wird zur nächsten Minute aufgerundet
   if (tSec > 0)
      to += 60 - tSec;

   int period = MathMin(pMinutes[TimeMinute(from)], pMinutes[TimeMinute(to)]);

   if (period == PERIOD_H1) {
      period = MathMin(pHours[TimeHour(from)], pHours[TimeHour(to)]);

      if (period==PERIOD_D1) if (TimeDayOfWeek(from)==MONDAY) if (TimeDayOfWeek(to)==SATURDAY)
         period = PERIOD_W1;
      // die weitere Prüfung auf PERIOD_MN1 ist wenig sinnvoll
   }

   // from- und toBar ermitteln (to zeigt auf Beginn der nächsten Bar)
   int fromBar = iBarShiftNext(symbol, period, from);
   if (fromBar == EMPTY_VALUE)                  // ERR_HISTORY_UPDATE ???
      return(stdlib_GetLastError());

   int toBar = iBarShiftPrevious(symbol, period, to-1);
   if (toBar == EMPTY_VALUE)                    // ERR_HISTORY_UPDATE ???
      return(stdlib_GetLastError());

   if (fromBar==-1 || toBar==-1) {              // Zeitraum ist zu alt oder zu jung für den Chart
      destination[MODE_OPEN ] = 0;
      destination[MODE_HIGH ] = 0;
      destination[MODE_LOW  ] = 0;
      destination[MODE_CLOSE] = 0;
      return(ERR_NO_RESULT);
   }

   // high- und lowBar ermitteln (identisch zu iOHLCBarRange(), wir sparen hier aber alle zusätzlichen Checks)
   int highBar=fromBar, lowBar=fromBar;

   if (fromBar != toBar) {
      highBar = iHighest(symbol, period, MODE_HIGH, fromBar-toBar+1, toBar);
      lowBar  = iLowest (symbol, period, MODE_LOW , fromBar-toBar+1, toBar);
      int error = GetLastError();                   // ERR_HISTORY_UPDATE ???
      if (error != ERR_NO_ERROR) {
         if (error != ERR_HISTORY_UPDATE) catch("iOHLCTimeRange(3)", error);
         return(error);
      }
   }

   destination[MODE_OPEN ] = iOpen (symbol, period, fromBar);
   destination[MODE_HIGH ] = iHigh (symbol, period, highBar);
   destination[MODE_LOW  ] = iLow  (symbol, period, lowBar );
   destination[MODE_CLOSE] = iClose(symbol, period, toBar  );
   //Print("iOHLCTimeRange()    from="+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +" (bar="+ fromBar +")   to="+ TimeToStr(to, TIME_DATE|TIME_MINUTES) +" (bar="+ toBar +")   period="+ PeriodToStr(period));

   error = GetLastError();                      // ERR_HISTORY_UPDATE ???
   if (error != ERR_NO_ERROR) if (error != ERR_HISTORY_UPDATE)
      catch("iOHLCTimeRange(4)", error);
   return(error);
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
            error = stdlib_GetLastError();
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
   if (symbol == "0")         // NULL ist ein Integer (0)
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


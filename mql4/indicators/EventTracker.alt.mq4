/**
 * Überwacht ein Instrument auf verschiedene Signale und benachrichtigt akustisch und/oder per SMS.
 */
#include <types.mqh>
#define     __TYPE__   T_INDICATOR
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>


#property indicator_chart_window


////////////////////////////////////////////////// Default-Konfiguration (keine Input-Variablen) //////////////////////////////////////////////////

bool   Sound.Alerts                 = true;
string Sound.PositionOpen           = "OrderFilled.wav";
string Sound.PositionClose          = "PositionClosed.wav";

bool   SMS.Alerts                   = false;
string SMS.Receiver                 = "";

bool   Track.Positions              = true;

bool   Track.BollingerBands         = false;
int    BollingerBands.MA.Periods    = 0;
int    BollingerBands.MA.Timeframe  = 0;                 // M1, M5, M15 etc. (0 => aktueller Timeframe)
int    BollingerBands.MA.Method     = MODE_SMA;          // SMA | EMA | SMMA | LWMA | ALMA
double BollingerBands.Deviation     = 2.0;               // Std.-Abweichung

bool   Track.PivotLevels            = false;
bool   PivotLevels.PreviousDayRange = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string symbolName;
int    BBands.MA.Periods.orig, BBands.MA.Timeframe.orig;


/**
 * Initialisierung
 *
 * @param  bool userCall - ob der Aufruf der zugrunde liegenden init()-Funktion durch das Terminal oder durch Userland-Code erfolgte
 *
 * @return int - Fehlerstatus
 */
int onInit(bool userCall) {
   // globale Variablen
   symbolName = GetSymbolName(StdSymbol());


   // -- Beginn - Parametervalidierung
   // Sound.Alerts
   Sound.Alerts = GetConfigBool("EventTracker", "Sound.Alerts", Sound.Alerts);

   // SMS.Alerts
   SMS.Alerts = GetConfigBool("EventTracker", "SMS.Alerts", SMS.Alerts);
   if (SMS.Alerts) {
      SMS.Receiver = GetConfigString("SMS", "Receiver", SMS.Receiver);
      if (!StringIsDigit(SMS.Receiver)) {
         catch("onInit(1)   Invalid config value SMS.Receiver = \""+ SMS.Receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         SMS.Alerts = false;
      }
   }

   // Track.Positions
   Track.Positions = GetConfigBool("EventTracker", "Track.Positions", Track.Positions);

   /*
   // Track.PivotLevels
   Track.PivotLevels = GetConfigBool(symbolSection, "PivotLevels", Track.PivotLevels);
   if (Track.PivotLevels)
      PivotLevels.PreviousDayRange = GetConfigBool(symbolSection, "PivotLevels.PreviousDayRange", PivotLevels.PreviousDayRange);
   */

   // Track.BollingerBands
   Track.BollingerBands = GetConfigBool("EventTracker."+ StdSymbol(), "BollingerBands", Track.BollingerBands);
   if (Track.BollingerBands) {
      // BollingerBands.MA.Periods
      BollingerBands.MA.Periods = GetConfigInt("EventTracker."+ StdSymbol(), "BollingerBands.MA.Periods", BollingerBands.MA.Periods);
      if (BollingerBands.MA.Periods < 2) {
         catch("onInit(2)   Invalid config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Periods = \""+ GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.MA.Periods", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      // BollingerBands.MA.Timeframe
      string strValue = GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.MA.Timeframe", BollingerBands.MA.Timeframe);
      BollingerBands.MA.Timeframe = PeriodToId(strValue);
      if (BollingerBands.MA.Timeframe == -1) {
         if (IsConfigKey("EventTracker."+ StdSymbol(), "BollingerBands.MA.Timeframe")) {
            catch("onInit(3)   Invalid config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Timeframe = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
            Track.BollingerBands = false;
         }
         else {
            BollingerBands.MA.Timeframe = Period();
         }
      }
   }
   if (Track.BollingerBands) {
      // BollingerBands.MA.Method
      strValue = GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.MA.Method", MovingAverageMethodDescription(BollingerBands.MA.Method));
      BollingerBands.MA.Method = MovingAverageMethodToId(strValue);
      if (BollingerBands.MA.Method == -1) {
         catch("onInit(4)   Invalid config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Method = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      // BollingerBands.Deviation
      BollingerBands.Deviation = GetConfigDouble("EventTracker."+ StdSymbol(), "BollingerBands.Deviation", BollingerBands.Deviation);
      if (LE(BollingerBands.Deviation, 0)) {
         catch("onInit(5)   Invalid config value [EventTracker."+ StdSymbol() +"] BollingerBands.Deviation = \""+ GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.Deviation", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      // für konstante Werte bei Timeframe-Wechseln Timeframe möglichst nach M5 umrechnen
      BBands.MA.Periods.orig   = BollingerBands.MA.Periods;
      BBands.MA.Timeframe.orig = BollingerBands.MA.Timeframe;

      if (BollingerBands.MA.Timeframe > PERIOD_M5) {
         BollingerBands.MA.Periods   = BollingerBands.MA.Timeframe * BollingerBands.MA.Periods / PERIOD_M5;
         BollingerBands.MA.Timeframe = PERIOD_M5;
      }
   }
   // -- Ende - Parametervalidierung
   //debug("onInit()    Sound.Alerts="+ Sound.Alerts +"   SMS.Alerts="+ SMS.Alerts +"   Track.Positions="+ Track.Positions +"   Track.PivotLevels="+ Track.PivotLevels +"   Track.BollingerBands="+ Track.BollingerBands + ifString(Track.BollingerBands, " ("+ BollingerBands.MA.Periods +"x"+ PeriodDescription(BollingerBands.MA.Timeframe) +"/"+ MovingAverageMethodDescription(BollingerBands.MA.Method) +"/"+ NumberToStr(BollingerBands.Deviation, ".1+") +")", ""));


   // Anzeigeoptionen
   SetIndexLabel(0, NULL);

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("onInit(6)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (prev_error == ERR_HISTORY_UPDATE)
      ValidBars = 0;

   // unvollständige Accountinitialisierung abfangen (bei Start und Accountwechseln mit schnellen Prozessoren)
   if (AccountNumber() == 0)
      return(SetLastError(ERR_NO_CONNECTION));

   // aktuelle Accountdaten holen und alte Ticks abfangen: sämtliche Events werden nur nach neuen Ticks überprüft
   static int loginData[3];                                    // { Login.PreviousAccount, Login.CurrentAccount, Login.Servertime }
   EventListener.AccountChange(loginData, 0);                  // Der Eventlistener schreibt unabhängig vom Egebnis immer die aktuellen Accountdaten ins Array.
   if (TimeCurrent() < loginData[2]) {
      //debug("onTick()   old tick=\""+ TimeToStr(TimeCurrent(), TIME_FULL) +"\"   login=\""+ TimeToStr(loginData[2], TIME_FULL) +"\"");
      return(catch("onTick(1)"));
   }

   // Positionen
   if (Track.Positions) {                                      // nur pending Orders des aktuellen Instruments tracken (manuelle nicht)
      HandleEvent(EVENT_POSITION_CLOSE, OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
      HandleEvent(EVENT_POSITION_OPEN,  OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
   }

   // Bollinger-Bänder
   if (Track.BollingerBands) {
      if (CheckBollingerBands() != NO_ERROR)
         return(last_error);
   }

   return(catch("onTick(2)"));
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
      return(NO_ERROR);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!OrderSelectByTicket(tickets[i], "onPositionOpen(1)"))
         return(last_error);

      // alle Positionen werden im aktuellen Instrument gehalten
      string type    = OperationTypeDescription(OrderType());
      string lots    = NumberToStr(OrderLots(), ".+");
      string price   = NumberToStr(OrderOpenPrice(), PriceFormat);
      string message = StringConcatenate("Position opened: ", type, " ", lots, " ", symbolName, " at ", price);

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (IsError(error))
            return(SetLastError(error));
         log(StringConcatenate("onPositionOpen()   SMS sent to ", SMS.Receiver, ":  ", message));
      }
      else {
         log(StringConcatenate("onPositionOpen()   ", message));
      }
   }

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Sound.PositionOpen);
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
      return(NO_ERROR);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!OrderSelectByTicket(tickets[i], "onPositionClose(1)"))
         continue;

      // alle Positionen wurden im aktuellen Instrument gehalten
      string type       = OperationTypeDescription(OrderType());
      string lots       = NumberToStr(OrderLots(), ".+");
      string openPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
      string closePrice = NumberToStr(OrderClosePrice(), PriceFormat);
      string message    = StringConcatenate("Position closed: ", type, " ", lots, " ", symbolName, " at ", openPrice, " -> ", closePrice);

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (IsError(error))
            return(SetLastError(error));
         log(StringConcatenate("onPositionClose()   SMS sent to ", SMS.Receiver, ":  ", message));
      }
      else {
         log(StringConcatenate("onPositionClose()   ", message));
      }
   }

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Sound.PositionClose);
   return(catch("onPositionClose(2)"));
}


#include <bollingerbandCrossing.mqh>


/**
 * Prüft, ob das aktuelle BollingerBand verletzt wurde und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus
 */
int CheckBollingerBands() {
   double event[3];

   // EventListener aufrufen und bei Erfolg Event signalisieren
   if (EventListener.BandsCrossing(BollingerBands.MA.Periods, BollingerBands.MA.Timeframe, BollingerBands.MA.Method, BollingerBands.Deviation, event, DeepSkyBlue)) {
      int    crossing = event[CROSSING_TYPE ] +0.1;                  // (int) double
      double value    = ifDouble(crossing==CROSSING_LOW, event[CROSSING_LOW_VALUE], event[CROSSING_HIGH_VALUE]);
      debug("CheckBollingerBands()   new "+ ifString(crossing==CROSSING_LOW, "low", "high") +" bands crossing at "+ TimeToStr(TimeCurrent(), TIME_FULL) + ifString(crossing==CROSSING_LOW, "  <= ", "  => ") + NumberToStr(value, PriceFormat));

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         string message = StringConcatenate(symbolName, ifString(crossing==CROSSING_LOW, " lower", " upper"), " BollingerBand(", BBands.MA.Periods.orig, "x", PeriodDescription(BBands.MA.Timeframe.orig), ") @ ", NumberToStr(value, PriceFormat), " crossed");
         int error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != NO_ERROR)
            return(SetLastError(error));
         log(StringConcatenate("CheckBollingerBands()   SMS sent to ", SMS.Receiver, ":  ", message));
      }
      else {
         log(StringConcatenate("CheckBollingerBands()   ", message));
      }

      // ggf. Sound abspielen
      if (Sound.Alerts)
         PlaySound("Close order.wav");
   }

   return(catch("CheckBollingerBands()"));
}


/**
 * @return int - Fehlerstatus (ggf. ERR_HISTORY_UPDATE)
 *
int CheckPivotLevels() {
   if (!Track.PivotLevels)
      return(0);

   static bool done;
   if (done) return(0);

   // heutige und vorherige Tradingranges und deren InsideBar-Status ermitteln
   // ------------------------------------------------------------------------
   double ranges[0][5];
   int bar, MODE_INSIDEBAR = 4, period = PERIOD_H1;

   while (true) {
      // Tagesrange
      double range[4];
      int error = iOHLCBar(range, Symbol(), period, bar, true);
      if (error == ERR_NO_RESULT) catch("CheckPivotLevels(1)    iOHLCBar(bar="+ bar +") => ", error);
      if (error != NO_ERROR     ) return(error);

      // Abbruch, wenn die vorherige Bar keine Inside-Bar ist
      if (bar > 1 ) if (range[MODE_HIGH] < ranges[bar-1][MODE_HIGH] || range[MODE_LOW] > ranges[bar-1][MODE_LOW])
         break;

      ArrayResize(ranges, bar+1);
      ranges[bar][MODE_OPEN ] = range[MODE_OPEN ];
      ranges[bar][MODE_HIGH ] = range[MODE_HIGH ];
      ranges[bar][MODE_LOW  ] = range[MODE_LOW  ];
      ranges[bar][MODE_CLOSE] = range[MODE_CLOSE];
      debug("CheckPivotLevels()    "+ PeriodDescription(period) +":range"+ bar +"   Open="+ NumberToStr(range[MODE_OPEN], ".4'") +"    High="+ NumberToStr(range[MODE_HIGH], ".4'") +"    Low="+ NumberToStr(range[MODE_LOW], ".4'") +"    Close="+ NumberToStr(range[MODE_CLOSE], ".4'"));

      // InsideBar-Status bestimmen und speichern
      if (bar > 0) {
         if (ranges[bar][MODE_HIGH] >= ranges[bar-1][MODE_HIGH] && ranges[bar][MODE_LOW] <= ranges[bar-1][MODE_LOW])
            ranges[bar-1][MODE_INSIDEBAR] = 1;
         else break;
      }
      bar++;
      continue;
   }


   // Pivot-Level überprüfen
   // ----------------------

   done = true;
   return(catch("CheckPivotLevels(2)"));
}
 */


/**
 *
 *
int GetDailyStartEndBars(string symbol/*=NULL, int bar, int& lpStartBar, int& lpEndBar) {
   if (symbol == "0")                                                   // NULL ist Integer (0)
      symbol = Symbol();
   int period = PERIOD_H1;

   // Ausgangspunkt ist die Startbar der aktuellen Session
   datetime startTime = iTime(symbol, period, 0);
   if (GetLastError() == ERR_HISTORY_UPDATE)
      return(SetLastError(ERR_HISTORY_UPDATE));

   startTime = GetServerSessionStartTime_old(startTime);
   if (startTime == -1)                                                 // Wochenend-Candles
      startTime = GetServerPrevSessionEndTime(iTime(symbol, period, 0));

   int endBar=0, startBar=iBarShiftNext(symbol, period, startTime);
   if (startBar == -1)
      return(catch("GetDailyStartEndBars(1)(symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(startTime), ERR_RUNTIME_ERROR));

   // Bars durchlaufen und Bar-Range der gewünschten Periode ermitteln
   for (int i=1; i<=bar; i++) {
      endBar = startBar + 1;                                            // Endbar der nächsten Range ist die der letzten Startbar vorhergehende Bar
      if (endBar >= Bars) {                                             // Chart deckt die Session nicht ab => Abbruch
         catch("GetDailyStartEndBars(2)");
         return(ERR_NO_RESULT);
      }

      startTime = GetServerSessionStartTime_old(iTime(symbol, period, endBar));
      while (startTime == -1) {                                         // Endbar kann theoretisch wieder eine Wochenend-Candle sein
         startBar = iBarShiftNext(symbol, period, GetServerPrevSessionEndTime(iTime(symbol, period, endBar)));
         if (startBar == -1)
            return(catch("GetDailyStartEndBars(3)(symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(GetServerPrevSessionEndTime(iTime(symbol, period, endBar))), ERR_RUNTIME_ERROR));

         endBar = startBar + 1;
         if (endBar >= Bars) {                                          // Chart deckt die Session nicht ab => Abbruch
            catch("GetDailyStartEndBars(4)");
            return(ERR_NO_RESULT);
         }
         startTime = GetServerSessionStartTime_old(iTime(symbol, period, endBar));
      }

      startBar = iBarShiftNext(symbol, period, startTime);
      if (startBar == -1)
         return(catch("GetDailyStartEndBars(5)(symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(startTime), ERR_RUNTIME_ERROR));
   }

   lpStartBar = startBar;
   lpEndBar   = endBar;

   return(catch("GetDailyStartEndBars(6)"));
}
 */


/**
 * Ermittelt die OHLC-Werte eines Instruments für eine Bar-Range. Existieren die angegebene Startbar (from) bzw. die angegebene Endbar (to) nicht,
 * werden stattdessen die nächste bzw. die letzte existierende Bar verwendet.
 *
 * @param  double& results[4] - Ergebnisarray {Open, Low, High, Close}
 * @param  string  symbol     - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     period     - Periode (default: 0 = aktuelle Periode)
 * @param  int     from       - Offset der Startbar
 * @param  int     to         - Offset der Endbar
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Range nicht existiert, ggf. ERR_HISTORY_UPDATE
 *
 * NOTE:
 * -----
 * Diese Funktion wertet die in der History gespeicherten Bars unabhängig davon aus, ob diese Bars realen Bars entsprechen.
 *
 * @see iOHLCTime(destination, symbol, timeframe, time, exact=TRUE)
 *
int iOHLCBarRange(string symbol/*=NULL, int period/*=0, int from, int to, double& results[4]) {
   // TODO: um ERR_HISTORY_UPDATE zu vermeiden, möglichst die aktuelle Periode benutzen

   if (symbol == "0")                           // NULL ist Integer (0)
      symbol = Symbol();

   if (from < 0) return(catch("iOHLCBarRange(1)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (to   < 0) return(catch("iOHLCBarRange(2)  invalid parameter to: "  + to  , ERR_INVALID_FUNCTION_PARAMVALUE));

   if (from < to) {
      int tmp = from;
      from = to;
      to   = tmp;
   }

   int bars = iBars(symbol, period);

   int error = GetLastError();                  // ERR_HISTORY_UPDATE ???
   if (error != NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE) catch("iOHLCBarRange(3)", error);
      return(error);
   }

   if (bars-1 < to) {                           // History enthält zu wenig Daten in dieser Periode
      results[MODE_OPEN ] = 0;
      results[MODE_HIGH ] = 0;
      results[MODE_LOW  ] = 0;
      results[MODE_CLOSE] = 0;
      return(SetLastError(ERR_NO_RESULT));
   }

   if (from > bars-1)
      from = bars-1;

   int high=from, low=from;

   if (from != to) {
      high = iHighest(symbol, period, MODE_HIGH, from-to+1, to);
      low  = iLowest (symbol, period, MODE_LOW , from-to+1, to);
   }

   results[MODE_OPEN ] = iOpen (symbol, period, from);
   results[MODE_HIGH ] = iHigh (symbol, period, high);
   results[MODE_LOW  ] = iLow  (symbol, period, low );
   results[MODE_CLOSE] = iClose(symbol, period, to  );

   return(catch("iOHLCBarRange(5)"));
}
*/


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitpunkt einer Periode und schreibt sie in das angegebene Ergebnisarray.
 * Ergebnis sind die Werte der Bar, die diesen Zeitpunkt abdeckt.
 *
 * @param  double&  results[4] - Ergebnisarray {Open, Low, High, Close}
 * @param  string   symbol     - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int      timeframe  - Periode (default: 0 = aktuelle Periode)
 * @param  datetime time       - Zeitpunkt
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn für den Zeitpunkt keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 *
int iOHLCTime(double& results[4], string symbol/*=NULL, int timeframe/*=0, datetime time) {

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                           // NULL ist Integer (0)
      symbol = Symbol();

   int bar = iBarShift(symbol, timeframe, time, true);

   int error = GetLastError();                  // ERR_HISTORY_UPDATE ???
   if (error != NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE) catch("iOHLCTime(1)", error);
      return(error);
   }

   if (bar == -1) {                             // keine Kurse für diesen Zeitpunkt
      results[MODE_OPEN ] = 0;
      results[MODE_HIGH ] = 0;
      results[MODE_LOW  ] = 0;
      results[MODE_CLOSE] = 0;
      return(SetLastError(ERR_NO_RESULT));
   }

   error = iOHLCBar(results, symbol, timeframe, bar);
   if (error == ERR_NO_RESULT)
      catch("iOHLCTime(2)", error);
   return(error);
}
 */


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitraum und schreibt sie in das angegebene Ergebnisarray.
 * Existieren in diesem Zeitraum keine Kurse, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double&  results[4] - Ergebnisarray {Open, Low, High, Close}
 * @param  string   symbol     - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  datetime from       - Beginn des Zeitraumes
 * @param  datetime to         - Ende des Zeitraumes
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn im Zeitraum keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 *
int iOHLCTimeRange(double& results[4], string symbol/*=NULL, datetime from, datetime to) {

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                           // NULL ist Integer (0)
      symbol = Symbol();

   if (from < 0) return(catch("iOHLCTimeRange(1)  invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (to   < 0) return(catch("iOHLCTimeRange(2)  invalid parameter to: "  + to  , ERR_INVALID_FUNCTION_PARAMVALUE));

   if (from > to) {
      datetime tmp = from;
      from = to;
      to   = tmp;
   }

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
      return(stdlib_PeekLastError());

   int toBar = iBarShiftPrevious(symbol, period, to-1);

   if (fromBar==-1 || toBar==-1) {              // Zeitraum ist zu alt oder zu jung für den Chart
      results[MODE_OPEN ] = 0;
      results[MODE_HIGH ] = 0;
      results[MODE_LOW  ] = 0;
      results[MODE_CLOSE] = 0;
      return(SetLastError(ERR_NO_RESULT));
   }

   // high- und lowBar ermitteln (identisch zu iOHLCBarRange(), wir sparen hier aber alle zusätzlichen Checks)
   int highBar=fromBar, lowBar=fromBar;

   if (fromBar != toBar) {
      highBar = iHighest(symbol, period, MODE_HIGH, fromBar-toBar+1, toBar);
      lowBar  = iLowest (symbol, period, MODE_LOW , fromBar-toBar+1, toBar);
   }
   results[MODE_OPEN ] = iOpen (symbol, period, fromBar);
   results[MODE_HIGH ] = iHigh (symbol, period, highBar);
   results[MODE_LOW  ] = iLow  (symbol, period, lowBar );
   results[MODE_CLOSE] = iClose(symbol, period, toBar  );
   //debug("iOHLCTimeRange()    from="+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +" (bar="+ fromBar +")   to="+ TimeToStr(to, TIME_DATE|TIME_MINUTES) +" (bar="+ toBar +")   period="+ PeriodDescription(period));

   return(catch("iOHLCTimeRange(3)"));
}
*/


/**
 * Ermittelt die OHLC-Werte eines Symbols für eine einzelne Bar einer Periode. Im Unterschied zu den eingebauten Funktionen iHigh(), iLow() etc.
 * ermittelt diese Funktion alle 4 Werte mit einem einzigen Funktionsaufruf.
 *
 * @param  string symbol     - Symbol  (default: aktuelles Symbol)
 * @param  int    period     - Periode (default: aktuelle Periode)
 * @param  int    bar        - Bar-Offset
 * @param  double results[4] - Ergebnisarray {Open, Low, High, Close}
 *
 * @return int - Fehlerstatus; ERR_NO_RESULT, wenn die angegebene Bar nicht existiert (ggf. ERR_HISTORY_UPDATE)
 *
int iOHLC(string symbol, int period, int bar, double& results[4]) {
   if (symbol == "0")                     // NULL ist Integer (0)
      symbol = Symbol();
   if (bar < 0)
      return(catch("iOHLC(1)  invalid parameter bar: "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (ArraySize(results) != 4)
      ArrayResize(results, 4);

   // TODO: um ERR_HISTORY_UPDATE zu vermeiden, möglichst die aktuelle Periode benutzen

   // Scheint für Bars größer als ChartBars Nonsense zurückzugeben

   results[MODE_OPEN ] = iOpen (symbol, period, bar);
   results[MODE_HIGH ] = iHigh (symbol, period, bar);
   results[MODE_LOW  ] = iLow  (symbol, period, bar);
   results[MODE_CLOSE] = iClose(symbol, period, bar);

   int error = GetLastError();

   if (error == NO_ERROR) {
      if (EQ(results[MODE_CLOSE], 0))
         error = ERR_NO_RESULT;
   }
   else if (error != ERR_HISTORY_UPDATE) {
      catch("iOHLCBar(2)", error);
   }
   return(error);
}
 */

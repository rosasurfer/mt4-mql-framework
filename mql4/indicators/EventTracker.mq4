/**
 * Überwacht ein Instrument auf verschiedene Ereignisse und benachrichtigt akustisch und/oder per SMS.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

//////////////////////////////////////////////////////////////////////////// Default-Konfiguration ////////////////////////////////////////////////////////////////////////////
//                                                 (Konfiguration nicht per Input-Parametern, sondern per Konfigurationsdatei)
bool   Sound.Alerts                = true;
bool   SMS.Alerts                  = false;
string SMS.Receiver                = "";

bool   Track.Positions             = false;
string Positions.SoundOnOpen       = "OrderFilled.wav";
string Positions.SoundOnClose      = "PositionClosed.wav";

bool   Track.MovingAverage         = false;
double MovingAverage.Periods       = 0;                              // die Angabe fraktionaler Werte ist möglich, z.B. 3.5 x D1
int    MovingAverage.Timeframe     = 0;                              // M1 | M5 | M15 etc.
int    MovingAverage.Method        = MODE_SMA;                       // SMA | EMA | SMMA | LWMA | ALMA

bool   Track.BollingerBands        = false;
int    BollingerBands.MA.Periods   = 0;
int    BollingerBands.MA.Timeframe = 0;                              // M1 | M5 | M15 etc.
int    BollingerBands.MA.Method    = MODE_SMA;                       // SMA | EMA | SMMA | LWMA | ALMA
double BollingerBands.Deviation    = 2.0;                            // Std.-Abweichung

bool   Track.NewHighLow            = false;

bool   Track.BreakPreviousRange    = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <iCustom/icMovingAverage.mqh>

#property indicator_chart_window

int    movingAverage.TimeframeFlag;                                  // Timeframe-Flag für EventListener.BarOpen (max. F_PERIOD_H1)
string strMovingAverage;
string strBollingerBands;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parametervalidierung
   // (1.1) Sound.Alerts
   Sound.Alerts = GetConfigBool("EventTracker", "Sound.Alerts", Sound.Alerts);

   // (1.2) SMS.Alerts
   SMS.Alerts = GetConfigBool("EventTracker", "SMS.Alerts", SMS.Alerts);
   if (SMS.Alerts) {
      // SMS.Receiver
      SMS.Receiver = GetConfigString("SMS", "Receiver", SMS.Receiver);
      if (!StringIsDigit(SMS.Receiver))                SMS.Alerts = _false(catch("onInit(1)   invalid config value SMS.Receiver = \""+ SMS.Receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }

   // (1.3) Track.Positions
   Track.Positions = GetConfigBool("EventTracker", "Track.Positions", Track.Positions);

   // (1.4) Track.MovingAverage
   Track.MovingAverage = GetConfigBool("EventTracker."+ StdSymbol(), "MovingAverage", Track.MovingAverage);
   if (Track.MovingAverage) {
      // MovingAverage.Timeframe zuerst, da Gültigkeit von Periods davon abhängt
      string strValue = GetConfigString("EventTracker."+ StdSymbol(), "MovingAverage.Timeframe", MovingAverage.Timeframe);
      MovingAverage.Timeframe = StrToPeriod(strValue);
      if (MovingAverage.Timeframe == -1)               Track.MovingAverage = _false(catch("onInit(2)   invalid or missing config value [EventTracker."+ StdSymbol() +"] MovingAverage.Timeframe = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.MovingAverage) {
      if (MovingAverage.Timeframe >= PERIOD_MN1)       Track.MovingAverage = _false(catch("onInit(3)   unsupported config value [EventTracker."+ StdSymbol() +"] MovingAverage.Timeframe = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.MovingAverage) {
      // MovingAverage.Method
      strValue = GetConfigString("EventTracker."+ StdSymbol(), "MovingAverage.Method", MovingAverageMethodDescription(MovingAverage.Method));
      MovingAverage.Method = StrToMovAvgMethod(strValue);
      if (MovingAverage.Method == -1)                  Track.MovingAverage = _false(catch("onInit(4)   invalid config value [EventTracker."+ StdSymbol() +"] MovingAverage.Method = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }

   if (Track.MovingAverage) {
      // MovingAverage.Periods
      MovingAverage.Periods = GetConfigDouble("EventTracker."+ StdSymbol(), "MovingAverage.Periods", MovingAverage.Periods);
      if (LE(MovingAverage.Periods, 0))                Track.MovingAverage = _false(catch("onInit(5)   invalid or missing config value [EventTracker."+ StdSymbol() +"] MovingAverage.Periods = \""+ GetConfigString("EventTracker."+ StdSymbol(), "MovingAverage.Periods", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.MovingAverage) {
      if (MathModFix(MovingAverage.Periods, 0.5) != 0) Track.MovingAverage = _false(catch("onInit(6)   illegal config value [EventTracker."+ StdSymbol() +"] MovingAverage.Periods = \""+ GetConfigString("EventTracker."+ StdSymbol(), "MovingAverage.Periods", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.MovingAverage) {
      // max. Timeframe für EventListener.BarOpen soll H1 sein
      strValue         = NumberToStr(MovingAverage.Periods, ".+");
      strMovingAverage = MovingAverageMethodDescription(MovingAverage.Method) +"("+ strValue +"x"+ PeriodDescription(MovingAverage.Timeframe) +")";
      if (MovingAverage.Timeframe > PERIOD_H1) {
         switch (MovingAverage.Timeframe) {
            case PERIOD_H4: MovingAverage.Periods *=   4; break;
            case PERIOD_D1: MovingAverage.Periods *=  24; break;
            case PERIOD_W1: MovingAverage.Periods *= 120; break;
         }
         MovingAverage.Periods   = MathRound(MovingAverage.Periods);
         MovingAverage.Timeframe = PERIOD_H1;
      }
      movingAverage.TimeframeFlag = PeriodFlag(MovingAverage.Timeframe);
   }

   /*
   // (1.5) Track.BollingerBands
   Track.BollingerBands = GetConfigBool("EventTracker."+ StdSymbol(), "BollingerBands", Track.BollingerBands);
   if (Track.BollingerBands) {
      // BollingerBands.MA.Periods
      BollingerBands.MA.Periods = GetConfigInt("EventTracker."+ StdSymbol(), "BollingerBands.MA.Periods", BollingerBands.MA.Periods);
      if (BollingerBands.MA.Periods < 2)               Track.BollingerBands = _false(catch("onInit(7)   invalid or missing config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Periods = \""+ GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.MA.Periods", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.BollingerBands) {
      // BollingerBands.MA.Timeframe
      strValue = GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.MA.Timeframe", BollingerBands.MA.Timeframe);
      BollingerBands.MA.Timeframe = StrToPeriod(strValue);
      if (BollingerBands.MA.Timeframe == -1)           Track.BollingerBands = _false(catch("onInit(8)   invalid or missing config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Timeframe = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
      if (BollingerBands.MA.Timeframe >= PERIOD_MN1)   Track.BollingerBands = _false(catch("onInit(9)   unsupported config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Timeframe = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.BollingerBands) {
      // BollingerBands.MA.Method
      strValue = GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.MA.Method", MovingAverageMethodDescription(BollingerBands.MA.Method));
      BollingerBands.MA.Method = StrToMovAvgMethod(strValue);
      if (BollingerBands.MA.Method == -1)              Track.BollingerBands = _false(catch("onInit(10)   invalid config value [EventTracker."+ StdSymbol() +"] BollingerBands.MA.Method = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.BollingerBands) {
      // BollingerBands.Deviation
      BollingerBands.Deviation = GetConfigDouble("EventTracker."+ StdSymbol(), "BollingerBands.Deviation", BollingerBands.Deviation);
      if (LE(BollingerBands.Deviation, 0))             Track.BollingerBands = _false(catch("onInit(11)   invalid config value [EventTracker."+ StdSymbol() +"] BollingerBands.Deviation = \""+ GetConfigString("EventTracker."+ StdSymbol(), "BollingerBands.Deviation", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
   }
   if (Track.BollingerBands) {
      // max. Indikator-Timeframe soll H1 sein
      strBollingerBands = StringConcatenate("BollingerBands(", BollingerBands.MA.Periods, "x", PeriodDescription(BollingerBands.MA.Timeframe), ")");
      if (BollingerBands.MA.Timeframe > PERIOD_H1) {
         switch (BollingerBands.MA.Timeframe) {
            case PERIOD_H4: BollingerBands.MA.Periods *=   4; break;
            case PERIOD_D1: BollingerBands.MA.Periods *=  24; break;
            case PERIOD_W1: BollingerBands.MA.Periods *= 120; break;
         }
         BollingerBands.MA.Timeframe = PERIOD_H1;
      }
   }
   */


   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);
   return(catch("onInit(12)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   /*
   // unvollständige Accountinitialisierung abfangen (bei Start und Accountwechseln mit schnellen Prozessoren)
   if (!AccountNumber())
      return(SetLastError(ERR_NO_CONNECTION));

   // aktuelle Accountdaten holen und alte Ticks abfangen: sämtliche Events werden nur nach neuen Ticks überprüft
   static int loginData[3];                                          // { Login.PreviousAccount, Login.CurrentAccount, Login.Servertime }
   EventListener.AccountChange(loginData, 0);                        // Der Eventlistener schreibt unabhängig vom Egebnis immer die aktuellen Accountdaten ins Array.
   if (TimeCurrent() < loginData[2]) {
      //debug("onTick()   old tick=\""+ TimeToStr(TimeCurrent(), TIME_FULL) +"\"   login=\""+ TimeToStr(loginData[2], TIME_FULL) +"\"");
      return(catch("onTick()"));
   }
   */


   // (1) Track.Positions
   if (Track.Positions) {                                            // nur Pending-Orders des aktuellen Instruments tracken (manuelle jedoch nicht)
      HandleEvent(EVENT_POSITION_CLOSE, OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
      HandleEvent(EVENT_POSITION_OPEN,  OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
   }


   // (2) Track.MovingAverage                                        // Prüfung nur bei onBarOpen, nicht bei jedem Tick
   if (Track.MovingAverage) {
      int iNull[];
      if (EventListener.BarOpen(iNull, movingAverage.TimeframeFlag)) {
         debug("onTick()   BarOpen=true");

         int    timeframe   = MovingAverage.Timeframe;
         string maPeriods   = NumberToStr(MovingAverage.Periods, ".+");
         string maTimeframe = PeriodDescription(MovingAverage.Timeframe);
         string maMethod    = MovingAverage.Method;

         int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", MovingAverage.MODE_TREND, 1);
         if (!trend) {
            int error = stdlib.GetLastError();
            if (IsError(error))
               return(SetLastError(error));
         }
         if (trend==1 || trend==-1) {
            //onMovingAverageTrendChange();
            debug("onTick()->icMovingAverage() => trend change");
         }
      }

   }


   // (3) Track.BollingerBands
   if (Track.BollingerBands) {
      if (!CheckBollingerBands())
         return(last_error);
   }


   // (4) Track.NewHighLow
   if (Track.NewHighLow) {
      // aktuelle Range ermitteln
      while (true) {
         // Bruch der Range überwachen
         bool Bruch = false;
         if (Bruch) {
            // wenn seit letzten Bruch mind. Zeitspanne X verstrichen ist, Bruch signalisieren
            // Range aktualisieren
         }
      }
   }


   // (5) Track.BreakPreviousRange
   if (Track.BreakPreviousRange) {
      // letzte Range ermitteln
      // Bruch überwachen
   }

   return(last_error);
}


/**
 * Handler für PositionOpen-Events.
 *
 * @param  int tickets[] - Tickets der geöffneten Positionen
 *
 * @return int - Fehlerstatus
 */
int onPositionOpen(int tickets[]) {
   if (!Track.Positions)
      return(NO_ERROR);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onPositionOpen(1)"))
         return(last_error);

      string type    = OperationTypeDescription(OrderType());
      string lots    = NumberToStr(OrderLots(), ".+");
      string price   = NumberToStr(OrderOpenPrice(), PriceFormat);
      string message = "Position opened: "+ type +" "+ lots +" "+ GetSymbolName(GetStandardSymbol(OrderSymbol())) +" at "+ price;

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         if (!SendSMS(SMS.Receiver, TimeToStr(TimeLocal(), TIME_MINUTES) +" "+ message))
            return(SetLastError(stdlib.GetLastError()));
      }
      else if (__LOG) log("onPositionOpen(3)   "+ message);
   }

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Positions.SoundOnOpen);
   return(catch("onPositionOpen(4)"));
}


/**
 * Handler für PositionClose-Events.
 *
 * @param  int tickets[] - Tickets der geschlossenen Positionen
 *
 * @return int - Fehlerstatus
 */
int onPositionClose(int tickets[]) {
   if (!Track.Positions)
      return(NO_ERROR);

   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onPositionClose(1)"))
         continue;

      string type       = OperationTypeDescription(OrderType());
      string lots       = NumberToStr(OrderLots(), ".+");
      string openPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
      string closePrice = NumberToStr(OrderClosePrice(), PriceFormat);
      string message    = "Position closed: "+ type +" "+ lots +" "+ GetSymbolName(GetStandardSymbol(OrderSymbol())) +" at "+ openPrice +" -> "+ closePrice;

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         if (!SendSMS(SMS.Receiver, TimeToStr(TimeLocal(), TIME_MINUTES) +" "+ message))
            return(SetLastError(stdlib.GetLastError()));
      }
      else if (__LOG) log("onPositionClose(3)   "+ message);
   }

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Positions.SoundOnClose);
   return(catch("onPositionClose(4)"));
}


#include <bollingerbandCrossing.mqh>


/**
 * Prüft, ob das aktuelle BollingerBand verletzt wurde und benachrichtigt entsprechend.
 *
 * @return bool - Erfolgsstatus (nicht, ob ein Signal aufgetreten ist)
 */
bool CheckBollingerBands() {
   double event[3];

   // EventListener aufrufen und bei Erfolg Event signalisieren
   if (EventListener.BandsCrossing(BollingerBands.MA.Periods, BollingerBands.MA.Timeframe, BollingerBands.MA.Method, BollingerBands.Deviation, event, DeepSkyBlue)) {
      int    crossing = MathRound(event[CROSSING_TYPE]);
      double value    = ifDouble(crossing==CROSSING_LOW, event[CROSSING_LOW_VALUE], event[CROSSING_HIGH_VALUE]);
      debug("CheckBollingerBands(0.1)   new "+ ifString(crossing==CROSSING_LOW, "low", "high") +" bands crossing at "+ TimeToStr(TimeCurrent(), TIME_FULL) + ifString(crossing==CROSSING_LOW, "  <= ", "  => ") + NumberToStr(value, PriceFormat));

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         string message = GetSymbolName(StdSymbol()) + ifString(crossing==CROSSING_LOW, " lower", " upper") +" "+ strBollingerBands +" @ "+ NumberToStr(value, PriceFormat) +" crossed";
         if (!SendSMS(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message)))
            return(!SetLastError(stdlib.GetLastError()));
      }
      else if (__LOG) log("CheckBollingerBands(2)   "+ message);

      // ggf. Sound abspielen
      if (Sound.Alerts)
         PlaySound("Close order.wav");
   }

   return(!catch("CheckBollingerBands(3)"));
}


/**
 *
 */
int GetDailyStartEndBars(string symbol, int bar, int &lpStartBar, int &lpEndBar) {
   if (symbol == "0")                                                   // (string) NULL
      symbol = Symbol();
   int period = PERIOD_H1;

   // Ausgangspunkt ist die Startbar der aktuellen Session
   datetime startTime = iTime(symbol, period, 0);
   if (GetLastError() == ERS_HISTORY_UPDATE)
      return(SetLastError(ERS_HISTORY_UPDATE));

   startTime = GetSessionStartTime.srv(startTime);
   if (startTime == NaT)                                                // Wochenend-Candles
      startTime = GetPrevSessionEndTime.srv(iTime(symbol, period, 0));

   int endBar=0, startBar=iBarShiftNext(symbol, period, startTime);
   if (startBar == -1)
      return(catch("GetDailyStartEndBars(1:symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(startTime), ERR_RUNTIME_ERROR));

   // Bars durchlaufen und Bar-Range der gewünschten Periode ermitteln
   for (int i=1; i<=bar; i++) {
      endBar = startBar + 1;                                            // Endbar der nächsten Range ist die der letzten Startbar vorhergehende Bar
      if (endBar >= Bars) {                                             // Chart deckt die Session nicht ab => Abbruch
         catch("GetDailyStartEndBars(2)");
         return(ERR_NO_RESULT);
      }

      startTime = GetSessionStartTime.srv(iTime(symbol, period, endBar));
      while (startTime == NaT) {                                        // Endbar kann theoretisch wieder eine Wochenend-Candle sein
         startBar = iBarShiftNext(symbol, period, GetPrevSessionEndTime.srv(iTime(symbol, period, endBar)));
         if (startBar == -1)
            return(catch("GetDailyStartEndBars(3:symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(GetPrevSessionEndTime.srv(iTime(symbol, period, endBar))), ERR_RUNTIME_ERROR));

         endBar = startBar + 1;
         if (endBar >= Bars) {                                          // Chart deckt die Session nicht ab => Abbruch
            catch("GetDailyStartEndBars(4)");
            return(ERR_NO_RESULT);
         }
         startTime = GetSessionStartTime.srv(iTime(symbol, period, endBar));
      }

      startBar = iBarShiftNext(symbol, period, startTime);
      if (startBar == -1)
         return(catch("GetDailyStartEndBars(5)(symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(startTime), ERR_RUNTIME_ERROR));
   }

   lpStartBar = startBar;
   lpEndBar   = endBar;

   return(catch("GetDailyStartEndBars(6)"));
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für eine Bar-Range. Existieren die angegebene Startbar (from) bzw. die angegebene Endbar (to) nicht,
 * werden stattdessen die nächste bzw. die letzte existierende Bar verwendet.
 *
 * @param  double results[] - Ergebnisarray {Open, Low, High, Close}
 * @param  string symbol    - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int    period    - Periode (default: 0 = aktuelle Periode)
 * @param  int    from      - Offset der Startbar
 * @param  int    to        - Offset der Endbar
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Range nicht existiert, ggf. ERS_HISTORY_UPDATE
 *
 *
 * NOTE: Diese Funktion wertet die in der History gespeicherten Bars unabhängig davon aus, ob diese Bars realen Bars entsprechen.
 *       @see iOHLCTime(symbol, timeframe, time, results)
 */
int iOHLCBarRange(string symbol, int period, int from, int to, double &results[]) {
   // TODO: um ERS_HISTORY_UPDATE zu vermeiden, möglichst die aktuelle Periode benutzen

   if (symbol == "0")                                                // (string) NULL
      symbol = Symbol();

   if (from < 0) return(catch("iOHLCBarRange(1)   invalid parameter from = "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (to   < 0) return(catch("iOHLCBarRange(2)   invalid parameter to = "+ to, ERR_INVALID_FUNCTION_PARAMVALUE));

   if (from < to) {
      int tmp = from;
      from = to;
      to   = tmp;
   }

   int bars = iBars(symbol, period);

   int error = GetLastError();                                       // ERS_HISTORY_UPDATE ???
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE)
         catch("iOHLCBarRange(3)", error);
      return(error);
   }

   if (bars-1 < to) {                                                // History enthält zu wenig Daten in dieser Periode
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


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitpunkt einer Periode und schreibt sie in das angegebene Ergebnisarray.
 * Ergebnisse sind die Werte derjenigen Bar, die den angegebenen Zeitpunkt abdeckt.
 *
 * @param  string   symbol    - Symbol des Instruments (default: aktuelles Symbol)
 * @param  int      timeframe - Chartperiode           (default: aktuelle Periode)
 * @param  datetime time      - Zeitpunkt
 * @param  double   results[] - Array zur Aufnahme der Ergebnisse = {Open, Low, High, Close}
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn für den Zeitpunkt keine Kurse existieren,
 *                             ggf. ERS_HISTORY_UPDATE
 */
int iOHLCTime(string symbol, int timeframe, datetime time, double &results[]) {

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERS_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                                                // (string) NULL
      symbol = Symbol();

   int bar = iBarShift(symbol, timeframe, time, true);

   int error = GetLastError();                                       // ERS_HISTORY_UPDATE ???
   if (error != NO_ERROR) {
      if (error != ERS_HISTORY_UPDATE) catch("iOHLCTime(1)", error);
      return(error);
   }

   if (bar == -1) {                                                  // keine Kurse für diesen Zeitpunkt
      results[MODE_OPEN ] = 0;
      results[MODE_HIGH ] = 0;
      results[MODE_LOW  ] = 0;
      results[MODE_CLOSE] = 0;
      return(SetLastError(ERR_NO_RESULT));
   }

   error = iOHLCBar(symbol, timeframe, bar, results);
   if (error == ERR_NO_RESULT)
      catch("iOHLCTime(2)", error);
   return(error);
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitraum und schreibt sie in das angegebene Ergebnisarray.
 * Existieren in diesem Zeitraum keine Kurse, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  string   symbol    - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  datetime from      - Beginn des Zeitraumes
 * @param  datetime to        - Ende des Zeitraumes
 * @param  double   results[] - Array zur Aufnahme der Ergebnisse = {Open, Low, High, Close}
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn im Zeitraum keine Kurse existieren,
 *                             ggf. ERS_HISTORY_UPDATE
 */
int iOHLCTimeRange(string symbol, datetime from, datetime to, double &results[]) {

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERS_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                                                // (string) NULL
      symbol = Symbol();

   if (from < 0) return(catch("iOHLCTimeRange(1)   invalid parameter from: "+ from, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (to   < 0) return(catch("iOHLCTimeRange(2)   invalid parameter to: "  + to  , ERR_INVALID_FUNCTION_PARAMVALUE));

   if (from > to) {
      datetime tmp = from;
      from = to;
      to   = tmp;
   }

   // größtmögliche für from und to geeignete Periode bestimmen
   int pMinutes[60] = { PERIOD_H1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M15, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M30, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M15, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M5, PERIOD_M1, PERIOD_M1, PERIOD_M1, PERIOD_M1 };
   int pHours  [24] = { PERIOD_D1, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1, PERIOD_H4, PERIOD_H1, PERIOD_H1, PERIOD_H1 };

   int tSec = TimeSeconds(to);                                       // 'to' wird zur nächsten Minute aufgerundet
   if (tSec > 0)
      to += 60 - tSec;

   int period = Min(pMinutes[TimeMinute(from)], pMinutes[TimeMinute(to)]);

   if (period == PERIOD_H1) {
      period = Min(pHours[TimeHour(from)], pHours[TimeHour(to)]);

      if (period==PERIOD_D1) /*&&*/ if (TimeDayOfWeek(from)==MONDAY) /*&&*/ if (TimeDayOfWeek(to)==SATURDAY)
         period = PERIOD_W1;
      // die weitere Prüfung auf >= PERIOD_MN1 ist nicht sinnvoll
   }

   // from- und toBar ermitteln (to zeigt auf Beginn der nächsten Bar)
   int fromBar = iBarShiftNext(symbol, period, from);
   if (fromBar == EMPTY_VALUE)                                       // ERS_HISTORY_UPDATE ???
      return(stdlib.GetLastError());

   int toBar = iBarShiftPrevious(symbol, period, to-1);

   if (fromBar==-1 || toBar==-1) {                                   // Zeitraum ist zu alt oder zu jung für den Chart
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


/**
 * Ermittelt die OHLC-Werte eines Symbols für eine einzelne Bar einer Periode. Im Unterschied zu den eingebauten Funktionen iHigh(), iLow() etc.
 * ermittelt diese Funktion alle vier Werte mit einem einzigen Funktionsaufruf.
 *
 * @param  string symbol    - Symbol  (default: aktuelles Symbol)
 * @param  int    period    - Periode (default: aktuelle Periode)
 * @param  int    bar       - Bar-Offset
 * @param  double results[] - Array zur Aufnahme der Ergebnisse = {Open, Low, High, Close}
 *
 * @return int - Fehlerstatus; ERR_NO_RESULT, wenn die angegebene Bar nicht existiert (ggf. ERS_HISTORY_UPDATE)
 */
int iOHLCBar(string symbol, int period, int bar, double &results[]) {
   if (symbol == "0")                                                // (string) NULL
      symbol = Symbol();
   if (bar < 0)
      return(catch("iOHLCBar(1)   invalid parameter bar = "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (ArraySize(results) != 4)
      ArrayResize(results, 4);

   // TODO: um ERS_HISTORY_UPDATE zu vermeiden, möglichst die aktuelle Periode benutzen

   // Scheint für Bars größer als ChartBars Nonsens zurückzugeben

   results[MODE_OPEN ] = iOpen (symbol, period, bar);
   results[MODE_HIGH ] = iHigh (symbol, period, bar);
   results[MODE_LOW  ] = iLow  (symbol, period, bar);
   results[MODE_CLOSE] = iClose(symbol, period, bar);

   int error = GetLastError();

   if (!error) {
      if (!results[MODE_CLOSE])
         error = ERR_NO_RESULT;
   }
   else if (error != ERS_HISTORY_UPDATE) {
      catch("iOHLCBar(2)", error);
   }
   return(error);
}


/**
 * String-Repräsentation der Input-Parameter fürs Logging bei Aufruf durch iCustom().
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("init()   inputs: ",

                            "Sound.Alerts=",                BoolToStr(Sound.Alerts)                     , "; ",

                            "SMS.Alerts=",                  BoolToStr(SMS.Alerts)                       , "; ",
                    ifString(SMS.Alerts,
          StringConcatenate("SMS.Receiver=\"",              SMS.Receiver                                , "\"; "), ""),

                            "Track.Positions=",             BoolToStr(Track.Positions)                  , "; ",
                    ifString(Track.Positions,
          StringConcatenate("Positions.SoundOnOpen=\"",     Positions.SoundOnOpen                       , "\"; ",
                            "Positions.SoundOnClose=\"",    Positions.SoundOnClose                      , "\"; "), ""),

                            "Track.MovingAverage=",         BoolToStr(Track.MovingAverage)              , "; ",
                    ifString(Track.MovingAverage,
          StringConcatenate("MovingAverage.Periods=",       NumberToStr(MovingAverage.Periods, ".1+")   , "; ",
                            "MovingAverage.Timeframe=",     MovingAverage.Timeframe                     , "; ",
                            "MovingAverage.Method=",        MovingAverage.Method                        , "; "), ""),

                            "Track.BollingerBands=",        BoolToStr(Track.BollingerBands)             , "; ",
                    ifString(Track.BollingerBands,
          StringConcatenate("BollingerBands.MA.Periods=",   BollingerBands.MA.Periods                   , "; ",
                            "BollingerBands.MA.Timeframe=", BollingerBands.MA.Timeframe                 , "; ",
                            "BollingerBands.MA.Method=",    BollingerBands.MA.Method                    , "; ",
                            "BollingerBands.Deviation=",    NumberToStr(BollingerBands.Deviation, ".1+"), "; "), ""),

                            "Track.NewHighLow=",            BoolToStr(Track.NewHighLow)                 , "; ",

                            "Track.BreakPreviousRange=",    BoolToStr(Track.BreakPreviousRange)         , "; ")
   );
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int    iNull;
   double dNulls[];
   GetDailyStartEndBars(NULL, NULL, iNull, iNull);
   iOHLCBarRange(NULL, NULL, NULL, NULL, dNulls);
   iOHLCTime(NULL, NULL, NULL, dNulls);
   iOHLCTimeRange(NULL, NULL, NULL, dNulls);
}

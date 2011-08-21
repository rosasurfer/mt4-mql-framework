/**
 * EventTracker
 *
 * Überwacht ein Instrument auf verschiedene Signale und benachrichtigt akustisch und/oder per SMS.
 */
#include <stdlib.mqh>


#property indicator_chart_window


//////////////////////////////////////////////////////////////// Default-Konfiguration ////////////////////////////////////////////////////////////

bool   Sound.Alerts                 = false;
string Sound.File.PositionOpen      = "OrderFilled.wav";
string Sound.File.PositionClose     = "PositionClosed.wav";

bool   SMS.Alerts                   = false;
string SMS.Receiver                 = "";

bool   Track.Positions              = false;

bool   Track.PivotLevels            = false;
bool   PivotLevels.PreviousDayRange = false;

bool   Track.BollingerBands         = false;
int    BollingerBands.Periods       = 0;
int    BollingerBands.Timeframe     = 0;
int    BollingerBands.MA.Method     = MODE_EMA;
double BollingerBands.MA.Deviation  = 0;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

string symbol, symbolName, symbolSection;

double bbandLimits[3];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);

   PipDigits   = Digits & (~1);
   PipPoints   = MathPow(10, Digits-PipDigits) + 0.1;
   Pip         = 1/MathPow(10, PipDigits);
   PriceFormat = "."+ PipDigits + ifString(Digits==PipDigits, "", "'");

   // Datenanzeige ausschalten
   SetIndexLabel(0, NULL);

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      ArrayInitialize(bbandLimits, 0);
   }

   // Konfiguration auslesen
   symbol        = GetStandardSymbol(Symbol());
   symbolName    = GetSymbolName(symbol);
   symbolSection = "EventTracker."+ symbol;

   // Sound- und SMS-Einstellungen
   Sound.Alerts = GetConfigBool("EventTracker", "Sound.Alerts", Sound.Alerts);
   SMS.Alerts   = GetConfigBool("EventTracker", "SMS.Alerts"  , SMS.Alerts);
   if (SMS.Alerts) {
      SMS.Receiver = GetConfigString("SMS", "Receiver", SMS.Receiver);
      if (!StringIsDigit(SMS.Receiver)) {
         catch("init(2)  Invalid or missing configuration value SMS.Receiver \""+ SMS.Receiver +"\"", ERR_INVALID_INPUT_PARAMVALUE);
         SMS.Alerts = false;
      }
   }

   // Positionen
   Track.Positions = GetConfigBool("EventTracker", "Track.Positions", Track.Positions);

   /*
   // Pivot-Level
   Track.PivotLevels = GetConfigBool(symbolSection, "PivotLevels", Track.PivotLevels);
   if (Track.PivotLevels)
      PivotLevels.PreviousDayRange = GetConfigBool(symbolSection, "PivotLevels.PreviousDayRange", PivotLevels.PreviousDayRange);

   // Bollinger-Bänder
   Track.BollingerBands = GetConfigBool(symbolSection, "BollingerBands", Track.BollingerBands);
   if (Track.BollingerBands) {
      BollingerBands.Periods = GetConfigInt("BollingerBands."+ symbol, "Slow.Periods", BollingerBands.Periods);
      if (BollingerBands.Periods == 0)
         BollingerBands.Periods = GetConfigInt("BollingerBands", "Slow.Periods", BollingerBands.Periods);
      if (BollingerBands.Periods < 2) {
         catch("init(4)  Invalid or missing config value Slow.Periods \""+ GetConfigString("BollingerBands."+ symbol, "Slow.Periods", GetConfigString("BollingerBands", "Slow.Periods", "")) +"\"", ERR_INVALID_INPUT_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      string strValue = GetConfigString("BollingerBands."+ symbol, "Slow.Timeframe", "");
      if (StringLen(strValue) == 0)
         strValue = GetConfigString("BollingerBands", "Slow.Timeframe", strValue);
      BollingerBands.Timeframe = StringToPeriod(strValue);
      if (BollingerBands.Timeframe == 0) {
         catch("init(5)  Invalid config value value Slow.Timeframe \""+ strValue +"\"", ERR_INVALID_INPUT_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      BollingerBands.MA.Deviation = GetConfigDouble("BollingerBands."+ symbol, "Deviation.EMA", BollingerBands.MA.Deviation);
      if (EQ(BollingerBands.MA.Deviation, 0))
         BollingerBands.MA.Deviation = GetConfigDouble("BollingerBands", "Deviation.EMA", BollingerBands.MA.Deviation);
      if (BollingerBands.MA.Deviation <= 0) {
         catch("init(6)  Invalid or missing config value Deviation.EMA \""+ BollingerBands.MA.Deviation +"\"", ERR_INVALID_INPUT_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   */
   //debug("init()    Sound.Alerts="+ Sound.Alerts +"   SMS.Alerts="+ SMS.Alerts +"   Track.Positions="+ Track.Positions +"   Track.PivotLevels="+ Track.PivotLevels +"   Track.BollingerBands="+ Track.BollingerBands);

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(7)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   Tick++;
   if      (init_error != NO_ERROR)                   ValidBars = 0;
   else if (last_error == ERR_TERMINAL_NOT_YET_READY) ValidBars = 0;
   else if (last_error == ERR_HISTORY_UPDATE)         ValidBars = 0;
   else                                               ValidBars = IndicatorCounted();
   ChangedBars = Bars - ValidBars;
   stdlib_onTick(ValidBars);

   // init() ggf. nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // Abschluß der Chart-Initialisierung überprüfen
   if (Bars == 0) {                                   // tritt u.U. bei Terminal-Start auf
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = NO_ERROR;
   // -----------------------------------------------------------------------------


   // Accountinitialisierung abfangen (bei Start und Accountwechsel)
   if (AccountNumber() == 0)
      return(ERR_NO_CONNECTION);

   // aktuelle Accountdaten holen und alte Ticks abfangen: alle Events werden nur nach neuen Ticks überprüft
   static int accountData[3];                                  // { PreviousAccount.Number, CurrentAccount.Number, CurrentAccount.LoginServertime }
   EventListener.AccountChange(accountData, 0);                // der Eventlistener gibt unabhängig vom Event immer die aktuellen Accountdaten zurück
   if (TimeCurrent() < accountData[2])
      return(catch("start(1)"));

   // Positionen
   if (Track.Positions) {                                      // nur pending Orders des aktuellen Instruments tracken (manuelle nicht)
      HandleEvent(EVENT_POSITION_CLOSE, OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
      HandleEvent(EVENT_POSITION_OPEN , OFLAG_CURRENTSYMBOL|OFLAG_PENDINGORDER);
   }

   /*
   // Pivot-Level
   if (Track.PivotLevels) {
      if (CheckPivotLevels() == ERR_HISTORY_UPDATE) {
         last_error = ERR_HISTORY_UPDATE;
         debug("start()    CheckPivotLevels() => ERR_HISTORY_UPDATE");
         return(ERR_HISTORY_UPDATE);
      }
   }

   // Bollinger-Bänder
   if (false && Track.BollingerBands) {
      HandleEvent(EVENT_BAR_OPEN, PERIODFLAG_M1);              // einmal je Minute die Limite aktualisieren
      if (CheckBollingerBands() == ERR_HISTORY_UPDATE) {
         last_error = ERR_HISTORY_UPDATE;
         debug("start()    CheckBollingerBands() => ERR_HISTORY_UPDATE");
         return(ERR_HISTORY_UPDATE);
      }
   }
   */

   /* // TODO: ValidBars ist bei jedem Timeframe-Wechsel 0, wir wollen ValidBars==0 aber nur bei Chartänderungen detektieren
   if (ValidBars == 0) {
      ArrayInitialize(gridLimits, 0);
      EventTracker.SaveGridLimits(gridLimits);
      ArrayInitialize(bbandLimits, 0);
      EventTracker.SetBandLimits(bbandLimits);
   } */
   return(catch("start(2)"));

   double destination[4]; CheckPivotLevels(); CheckBollingerBands(); InitializeBandLimits(); iBollingerBands(0, 0, 0, 0, 0, 0, 0, destination); iOHLCBar(destination, 0, 0, 0); iOHLCBarRange(destination, 0, 0, 0, 0); iOHLCTime(destination, 0, 0, 0); iOHLCTimeRange(destination, 0, 0, 0);
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
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         return(catch("onPositionOpen(1)   error selecting opened position #"+ tickets[i], error));
      }

      // alle Positionen werden im aktuellen Instrument gehalten
      string type    = OperationTypeDescription(OrderType());
      string lots    = NumberToStr(OrderLots(), ".+");
      string price   = NumberToStr(OrderOpenPrice(), PriceFormat);
      string message = StringConcatenate("Position opened: ", type, " ", lots, " ", symbolName, " @ ", price);

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != NO_ERROR)
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
      if (!OrderSelect(tickets[i], SELECT_BY_TICKET)) {
         int error = GetLastError();
         if (error == NO_ERROR)
            error = ERR_INVALID_TICKET;
         catch("onPositionClose(1)  error selectiong closed position #"+ tickets[i], error);
         continue;
      }

      // alle Positionen wurden im aktuellen Instrument gehalten
      string type       = OperationTypeDescription(OrderType());
      string lots       = NumberToStr(OrderLots(), ".+");
      string openPrice  = NumberToStr(OrderOpenPrice(), PriceFormat);
      string closePrice = NumberToStr(OrderClosePrice(), PriceFormat);
      string message    = StringConcatenate("Position closed: ", type, " ", lots, " ", symbolName, " @ ", openPrice, " -> ", closePrice);

      // ggf. SMS verschicken
      if (SMS.Alerts) {
         error = SendTextMessage(SMS.Receiver, StringConcatenate(TimeToStr(TimeLocal(), TIME_MINUTES), " ", message));
         if (error != NO_ERROR)
            return(catch("onPositionClose(2)   error sending text message to "+ SMS.Receiver, error));
         Print("onPositionClose()   SMS sent to ", SMS.Receiver, ":  ", message);
      }
      else {
         Print("onPositionClose()   ", message);
      }
   }

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Sound.File.PositionClose);

   return(catch("onPositionClose(3)"));
}


/**
 * @return int - Fehlerstatus (ggf. ERR_HISTORY_UPDATE)
 */
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
      Print("CheckPivotLevels()    "+ PeriodToStr(period) +":range"+ bar +"   Open="+ NumberToStr(range[MODE_OPEN], ".4'") +"    High="+ NumberToStr(range[MODE_HIGH], ".4'") +"    Low="+ NumberToStr(range[MODE_LOW], ".4'") +"    Close="+ NumberToStr(range[MODE_CLOSE], ".4'"));

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


/**
 *
 */
int GetDailyStartEndBars(string symbol/*=NULL*/, int bar, int& lpStartBar, int& lpEndBar) {
   if (symbol == "0")                                                   // NULL ist ein Integer (0)
      symbol = Symbol();
   int period = PERIOD_H1;

   // Ausgangspunkt ist die Startbar der aktuellen Session
   datetime startTime = iTime(symbol, period, 0);
   if (GetLastError() == ERR_HISTORY_UPDATE)
      return(ERR_HISTORY_UPDATE);

   startTime = GetServerSessionStartTime(startTime);
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

      startTime = GetServerSessionStartTime(iTime(symbol, period, endBar));
      while (startTime == -1) {                                         // Endbar kann theoretisch wieder eine Wochenend-Candle sein
         startBar = iBarShiftNext(symbol, period, GetServerPrevSessionEndTime(iTime(symbol, period, endBar)));
         if (startBar == -1)
            return(catch("GetDailyStartEndBars(3)(symbol="+ symbol +", bar="+ bar +")    iBarShiftNext() => -1    no history bars for "+ TimeToStr(GetServerPrevSessionEndTime(iTime(symbol, period, endBar))), ERR_RUNTIME_ERROR));

         endBar = startBar + 1;
         if (endBar >= Bars) {                                          // Chart deckt die Session nicht ab => Abbruch
            catch("GetDailyStartEndBars(4)");
            return(ERR_NO_RESULT);
         }
         startTime = GetServerSessionStartTime(iTime(symbol, period, endBar));
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
 * Ermittelt die OHLC-Werte eines Instruments für eine einzelne Bar einer Periode und schreibt sie in das angegebene Zielarray.
 * Existiert die angegebene Bar nicht, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double& lpResults[4] - Zeiger auf Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string  symbol       - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     period       - Periode (default: 0 = aktuelle Periode)
 * @param  int     bar          - Bar-Offset
 * @param  bool    exact        - TRUE:  Berechnungsgrundlage für Bars sind tatsächliche Handelszeiten, entspricht der (virtuellen) Tradeserver-Zeitzone
 *                                       "EST+0700,EDT+0700"
 *                              - FALSE: Berechnungsgrundlage für Bars ist die Zeitzoneneinstellung des Tradeservers (default)
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Bar nicht existiert,
 *                             ggf. ERR_HISTORY_UPDATE
 */
int iOHLCBar(double& lpResults[4], string symbol/*=NULL*/, int period/*=0*/, int bar, bool exact=false) {
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                                       // NULL ist ein Integer (0)
      symbol = Symbol();
   if (bar < 0)
      return(catch("iOHLCBar(1)  invalid parameter bar: "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE));


   // schnelle Berechnung für exact=FALSE oder Perioden < H4
   if (!exact || period < PERIOD_H4) {
      lpResults[MODE_OPEN ] = iOpen (symbol, period, bar);
      lpResults[MODE_HIGH ] = iHigh (symbol, period, bar);
      lpResults[MODE_LOW  ] = iLow  (symbol, period, bar);
      lpResults[MODE_CLOSE] = iClose(symbol, period, bar);
      int error = GetLastError();                           // ERR_HISTORY_UPDATE ???
   }
   else {
      // exakte Berechnung, nur für Perioden > H1
      switch (period) {
         case PERIOD_D1:
            // Timeframe bestimmen und Beginn- und Endbar in diesem Timeframe ermitteln
            int startBar, endBar;
            error = GetDailyStartEndBars(symbol, bar, startBar, endBar);
            if (error == ERR_NO_RESULT) catch("iOHLCBar(2)    GetDailyStartEndBars() => ", error);
            if (error != NO_ERROR     ) return(error);

            // OHLC dieser Range ermitteln
            error = iOHLCBarRange(lpResults, symbol, PERIOD_H1, startBar, endBar);
            if (error == ERR_NO_RESULT) catch("iOHLCBar(3)    iOHLCBarRange() => ", error);
            if (error != NO_ERROR     ) return(error);
            break;

         case PERIOD_H4 :
         case PERIOD_W1 :
         case PERIOD_MN1:
         default:
            return(catch("iOHLCBar(4)   exact calculation for PERIOD_"+ PeriodToStr(period) +" not yet implemented", ERR_RUNTIME_ERROR));
      }
   }

   if (error != NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE) catch("iOHLCBar(5)", error);
   }
   else if (lpResults[MODE_OPEN] == 0) {
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
 * @param  double& lpResults[4] - Zeiger auf Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string  symbol       - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     period       - Periode (default: 0 = aktuelle Periode)
 * @param  int     from         - Offset der Startbar
 * @param  int     to           - Offset der Endbar
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Range nicht existiert,
 *                             ggf. ERR_HISTORY_UPDATE
 *
 * NOTE:    Diese Funktion wertet die in der History gespeicherten Bars unabhängig davon aus, ob diese Bars realen Bars entsprechen.
 * -----    Siehe: iOHLCTime(destination, symbol, timeframe, time, exact=TRUE)
 */
int iOHLCBarRange(double& lpResults[4], string symbol/*=NULL*/, int period/*=0*/, int from, int to) {
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                           // NULL ist ein Integer (0)
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
      lpResults[MODE_OPEN ] = 0;
      lpResults[MODE_HIGH ] = 0;
      lpResults[MODE_LOW  ] = 0;
      lpResults[MODE_CLOSE] = 0;
      last_error = ERR_NO_RESULT;
      return(ERR_NO_RESULT);
   }

   if (from > bars-1)
      from = bars-1;

   int high=from, low=from;

   if (from != to) {
      high = iHighest(symbol, period, MODE_HIGH, from-to+1, to);
      low  = iLowest (symbol, period, MODE_LOW , from-to+1, to);
   }

   lpResults[MODE_OPEN ] = iOpen (symbol, period, from);
   lpResults[MODE_HIGH ] = iHigh (symbol, period, high);
   lpResults[MODE_LOW  ] = iLow  (symbol, period, low );
   lpResults[MODE_CLOSE] = iClose(symbol, period, to  );

   return(catch("iOHLCBarRange(5)"));
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitpunkt einer Periode und schreibt sie in das angegebene Zielarray.
 * Ergebnis sind die Werte der Bar, die diesen Zeitpunkt abdeckt.
 *
 * @param  double&  lpResults[4] - Zeiger auf Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string   symbol       - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int      timeframe    - Periode (default: 0 = aktuelle Periode)
 * @param  datetime time         - Zeitpunkt
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn für den Zeitpunkt keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 */
int iOHLCTime(double& lpResults[4], string symbol/*=NULL*/, int timeframe/*=0*/, datetime time) {

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                           // NULL ist ein Integer (0)
      symbol = Symbol();

   int bar = iBarShift(symbol, timeframe, time, true);

   int error = GetLastError();                  // ERR_HISTORY_UPDATE ???
   if (error != NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE) catch("iOHLCTime(1)", error);
      return(error);
   }

   if (bar == -1) {                             // keine Kurse für diesen Zeitpunkt
      lpResults[MODE_OPEN ] = 0;
      lpResults[MODE_HIGH ] = 0;
      lpResults[MODE_LOW  ] = 0;
      lpResults[MODE_CLOSE] = 0;
      last_error = ERR_NO_RESULT;
      return(ERR_NO_RESULT);
   }

   error = iOHLCBar(lpResults, symbol, timeframe, bar);
   if (error == ERR_NO_RESULT)
      catch("iOHLCTime(2)", error);
   return(error);
}


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitraum und schreibt sie in das angegebene Zielarray.
 * Existieren in diesem Zeitraum keine Kurse, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double&  lpResults[4] - Zeiger auf Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string   symbol       - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  datetime from         - Beginn des Zeitraumes
 * @param  datetime to           - Ende des Zeitraumes
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn im Zeitraum keine Kurse existieren,
 *                             ggf. ERR_HISTORY_UPDATE
 */
int iOHLCTimeRange(double& lpResults[4], string symbol/*=NULL*/, datetime from, datetime to) {

   // TODO: Parameter bool exact=TRUE implementieren
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                           // NULL ist ein Integer (0)
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
      return(stdlib_GetLastError());

   int toBar = iBarShiftPrevious(symbol, period, to-1);

   if (fromBar==-1 || toBar==-1) {              // Zeitraum ist zu alt oder zu jung für den Chart
      lpResults[MODE_OPEN ] = 0;
      lpResults[MODE_HIGH ] = 0;
      lpResults[MODE_LOW  ] = 0;
      lpResults[MODE_CLOSE] = 0;
      last_error = ERR_NO_RESULT;
      return(ERR_NO_RESULT);
   }

   // high- und lowBar ermitteln (identisch zu iOHLCBarRange(), wir sparen hier aber alle zusätzlichen Checks)
   int highBar=fromBar, lowBar=fromBar;

   if (fromBar != toBar) {
      highBar = iHighest(symbol, period, MODE_HIGH, fromBar-toBar+1, toBar);
      lowBar  = iLowest (symbol, period, MODE_LOW , fromBar-toBar+1, toBar);
   }
   lpResults[MODE_OPEN ] = iOpen (symbol, period, fromBar);
   lpResults[MODE_HIGH ] = iHigh (symbol, period, highBar);
   lpResults[MODE_LOW  ] = iLow  (symbol, period, lowBar );
   lpResults[MODE_CLOSE] = iClose(symbol, period, toBar  );
   //Print("iOHLCTimeRange()    from="+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +" (bar="+ fromBar +")   to="+ TimeToStr(to, TIME_DATE|TIME_MINUTES) +" (bar="+ toBar +")   period="+ PeriodToStr(period));

   return(catch("iOHLCTimeRange(3)"));
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
      ArrayInitialize(bbandLimits, 0);
      EventTracker.SetBandLimits(bbandLimits);     // auch in Library
   }
   return(catch("onBarOpen()"));
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
   if (bbandLimits[0] == 0) if (!EventTracker.GetBandLimits(bbandLimits)) {
      if (InitializeBandLimits() == ERR_HISTORY_UPDATE)
         return(ERR_HISTORY_UPDATE);
      EventTracker.SetBandLimits(bbandLimits);                 // Limite in Library timeframe-übergreifend speichern
   }

   Print("CheckBollingerBands()   checking bands ...    ", NumberToStr(bbandLimits[2], PriceFormat), "  <=  ", NumberToStr(bbandLimits[1], PriceFormat), "  =>  ", NumberToStr(bbandLimits[0], PriceFormat));

   double upperBand = bbandLimits[0]-0.000001,                 // +- 1/100 pip, um Fehler beim Vergleich von Doubles zu vermeiden
          movingAvg = bbandLimits[1]+0.000001,
          lowerBand = bbandLimits[2]+0.000001;

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

   int error = iBollingerBands(Symbol(), timeframe, periods, BollingerBands.MA.Method, PRICE_MEDIAN, BollingerBands.MA.Deviation, 0, bbandLimits);

   if (error == ERR_HISTORY_UPDATE) return(error);
   if (error != NO_ERROR          ) return(catch("InitializeBandLimits()", error));

   Print("InitializeBandLimits()   Bollinger band limits calculated: ", NumberToStr(bbandLimits[2], PriceFormat), "  <=  ", NumberToStr(bbandLimits[1], PriceFormat), "  =>  ", NumberToStr(bbandLimits[0], PriceFormat));
   return(error);
}


/**
 * Berechnet die BollingerBand-Werte (UpperBand, MovingAverage, LowerBand) für eine Chart-Bar und speichert die Ergebnisse im angegebenen Array.
 *
 * @return int - Fehlerstatus (ERR_HISTORY_UPDATE, falls die Kursreihe gerade aktualisiert wird)
 */
int iBollingerBands(string symbol, int timeframe, int periods, int maMethod, int appliedPrice, double deviation, int bar, double& lpResults[]) {
   if (symbol == "0")         // NULL ist ein Integer (0)
      symbol = Symbol();

   double ma  = iMA    (symbol, timeframe, periods, 0, maMethod, appliedPrice, bar);
   double dev = iStdDev(symbol, timeframe, periods, 0, maMethod, appliedPrice, bar) * deviation;
   lpResults[0] = ma + dev;
   lpResults[1] = ma;
   lpResults[2] = ma - dev;

   int error = GetLastError();
   if (error == ERR_HISTORY_UPDATE) return(ERR_HISTORY_UPDATE);
   if (error != NO_ERROR          ) return(catch("iBollingerBands()", error));

   //Print("iBollingerBands(bar "+ bar +")   symbol: "+ symbol +"   timeframe: "+ timeframe +"   periods: "+ periods +"   maMethod: "+ maMethod +"   appliedPrice: "+ appliedPrice +"   deviation: "+ deviation +"   results: "+ NumberToStr(results[2], ".5") +"  <=  "+ NumberToStr(results[1], ".5") +"  =>  "+ NumberToStr(results[1], ".5"));
   return(error);
}


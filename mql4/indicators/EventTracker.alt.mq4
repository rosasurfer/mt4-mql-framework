/**
 * EventTracker
 *
 * Überwacht ein Instrument auf verschiedene Signale und benachrichtigt akustisch und/oder per SMS.
 */
#include <stdlib.mqh>


#property indicator_chart_window


////////////////////////////////////////////////// Default-Konfiguration (keine Input-Variablen) //////////////////////////////////////////////////

bool   Sound.Alerts                 = false;
string Sound.PositionOpen           = "OrderFilled.wav";
string Sound.PositionClose          = "PositionClosed.wav";

bool   SMS.Alerts                   = false;
string SMS.Receiver                 = "";

bool   Track.Positions              = false;

bool   Track.BollingerBands         = false;
int    BollingerBands.MA.Periods    = 0;
int    BollingerBands.MA.Timeframe  = 0;                 // M1, M5, M15 etc. (0 => aktueller Timeframe)
int    BollingerBands.MA.Method     = MODE_SMA;          // SMA | EMA | SMMA | LWMA | ALMA
double BollingerBands.Deviation     = 2.0;               // Std.-Abweichung

bool   Track.PivotLevels            = false;
bool   PivotLevels.PreviousDayRange = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


double Pip;
int    PipDigits;
int    PipPoints;
string PriceFormat;

string stdSymbol, symbolName;
string chartObjects[];
string stringTest[];


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

   // nach Recompilation statische Arrays zurücksetzen
   if (UninitializeReason() == REASON_RECOMPILE) {
      //ArrayInitialize(BollingerBand.Limits, 0);
      debug("init()   REASON_RECOMPILE, stringTest = "+ StringArrayToStr(stringTest, NULL));
   }


   // globale Variablen
   stdSymbol  = GetStandardSymbol(Symbol());
   symbolName = GetSymbolName(stdSymbol);


   // -- Beginn - Parametervalidierung
   // Sound.Alerts
   Sound.Alerts = GetConfigBool("EventTracker", "Sound.Alerts", Sound.Alerts);

   // SMS.Alerts
   SMS.Alerts = GetConfigBool("EventTracker", "SMS.Alerts", SMS.Alerts);
   if (SMS.Alerts) {
      SMS.Receiver = GetConfigString("SMS", "Receiver", SMS.Receiver);
      if (!StringIsDigit(SMS.Receiver)) {
         catch("init(1)  Invalid config value SMS.Receiver = \""+ SMS.Receiver +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         SMS.Alerts = false;
      }
   }

   /*
   // Track.Positions
   Track.Positions = GetConfigBool("EventTracker", "Track.Positions", Track.Positions);

   // Track.PivotLevels
   Track.PivotLevels = GetConfigBool(symbolSection, "PivotLevels", Track.PivotLevels);
   if (Track.PivotLevels)
      PivotLevels.PreviousDayRange = GetConfigBool(symbolSection, "PivotLevels.PreviousDayRange", PivotLevels.PreviousDayRange);
   */

   // Track.BollingerBands
   Track.BollingerBands = GetConfigBool("EventTracker."+ stdSymbol, "BollingerBands", Track.BollingerBands);
   if (Track.BollingerBands) {
      // BollingerBands.MA.Periods
      BollingerBands.MA.Periods = GetConfigInt("EventTracker."+ stdSymbol, "BollingerBands.MA.Periods", BollingerBands.MA.Periods);
      if (BollingerBands.MA.Periods < 2) {
         catch("init(2)  Invalid config value [EventTracker."+ stdSymbol +"] BollingerBands.MA.Periods = \""+ GetConfigString("EventTracker."+ stdSymbol, "BollingerBands.MA.Periods", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      // BollingerBands.MA.Timeframe
      string strValue = GetConfigString("EventTracker."+ stdSymbol, "BollingerBands.MA.Timeframe", BollingerBands.MA.Timeframe);
      BollingerBands.MA.Timeframe = PeriodToId(strValue);
      if (BollingerBands.MA.Timeframe == 0) {
         if (IsConfigKey("EventTracker."+ stdSymbol, "BollingerBands.MA.Timeframe")) {
            catch("init(3)  Invalid config value [EventTracker."+ stdSymbol +"] BollingerBands.MA.Timeframe = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
            Track.BollingerBands = false;
         }
         else {
            BollingerBands.MA.Timeframe = Period();
         }
      }
   }
   if (Track.BollingerBands) {
      // BollingerBands.MA.Method
      strValue = GetConfigString("EventTracker."+ stdSymbol, "BollingerBands.MA.Method", MovingAverageMethodDescription(BollingerBands.MA.Method));
      BollingerBands.MA.Method = MovingAverageMethodToId(strValue);
      if (BollingerBands.MA.Method == -1) {
         catch("init(4)  Invalid config value [EventTracker."+ stdSymbol +"] BollingerBands.MA.Method = \""+ strValue +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      // BollingerBands.Deviation
      BollingerBands.Deviation = GetConfigDouble("EventTracker."+ stdSymbol, "BollingerBands.Deviation", BollingerBands.Deviation);
      if (LE(BollingerBands.Deviation, 0)) {
         catch("init(5)  Invalid config value [EventTracker."+ stdSymbol +"] BollingerBands.Deviation = \""+ GetConfigString("EventTracker."+ stdSymbol, "BollingerBands.Deviation", "") +"\"", ERR_INVALID_CONFIG_PARAMVALUE);
         Track.BollingerBands = false;
      }
   }
   if (Track.BollingerBands) {
      // für konstante Werte bei Timeframe-Wechseln Timeframe möglichst nach M5 umrechnen
      if (BollingerBands.MA.Timeframe > PERIOD_M5) {
         BollingerBands.MA.Periods   = BollingerBands.MA.Timeframe * BollingerBands.MA.Periods / PERIOD_M5;
         BollingerBands.MA.Timeframe = PERIOD_M5;
      }
   }
   // -- Ende - Parametervalidierung
   //debug("init()    Sound.Alerts="+ Sound.Alerts +"   SMS.Alerts="+ SMS.Alerts +"   Track.Positions="+ Track.Positions +"   Track.PivotLevels="+ Track.PivotLevels +"   Track.BollingerBands="+ Track.BollingerBands + ifString(Track.BollingerBands, " ("+ BollingerBands.MA.Periods +"x"+ PeriodDescription(BollingerBands.MA.Timeframe) +"/"+ MovingAverageMethodDescription(BollingerBands.MA.Method) +"/"+ NumberToStr(BollingerBands.Deviation, ".1+") +")", ""));


   // Anzeigeoptionen
   SetIndexLabel(0, NULL);

   // nach Parameteränderung nicht auf den nächsten Tick warten (nur im "Indicators List" window notwendig)
   if (UninitializeReason() == REASON_PARAMETERS)
      SendTick(false);

   return(catch("init(6)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   ArrayPushString(stringTest, "test");
   //debug("deinit()   stringTest = "+ StringArrayToStr(stringTest, NULL));

   RemoveChartObjects(chartObjects);
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

   debug("start()   tick "+ Tick);

   // init() ggf. nochmal aufrufen oder abbrechen
   if (init_error == ERR_TERMINAL_NOT_YET_READY) /*&&*/ if (!init)
      init();
   init = false;
   if (init_error != NO_ERROR)
      return(init_error);

   // Abschluß der Chart-Initialisierung überprüfen
   if (Bars == 0) {                                            // tritt u.U. bei Terminal-Start auf
      last_error = ERR_TERMINAL_NOT_YET_READY;
      return(last_error);
   }
   last_error = NO_ERROR;
   // ------------------------------------------------------------------------------------


   // Accountinitialisierung abfangen (bei Start und Accountwechsel)
   if (AccountNumber() == 0) {
      debug("start()   ERR_NO_CONNECTION");
      //return(ERR_NO_CONNECTION);
   }

   // aktuelle Accountdaten holen und alte Ticks abfangen: sämtliche Events werden nur nach neuen Ticks überprüft
   static int loginData[3];                                    // { Login.PreviousAccount, Login.CurrentAccount, Login.Servertime }
   EventListener.AccountChange(loginData, 0);                  // der Eventlistener gibt unabhängig vom Event immer die aktuellen Accountdaten zurück
   if (TimeCurrent() < loginData[2]) {
      debug("start()   old tick, loginTime = "+ TimeToStr(loginData[2], TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"   serverTime="+ TimeToStr(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      //return(catch("start(1)"));
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

   /*
   // Pivot-Level
   if (Track.PivotLevels) {
      if (CheckPivotLevels() == ERR_HISTORY_UPDATE) {
         last_error = ERR_HISTORY_UPDATE;
         debug("start()    CheckPivotLevels() => ERR_HISTORY_UPDATE");
         return(ERR_HISTORY_UPDATE);
      }
   }
   */
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
      return(NO_ERROR);

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
         log(StringConcatenate("onPositionClose()   SMS sent to ", SMS.Receiver, ":  ", message));
      }
      else {
         log(StringConcatenate("onPositionClose()   ", message));
      }
   }

   // ggf. Sound abspielen
   if (Sound.Alerts)
      PlaySound(Sound.PositionClose);

   return(catch("onPositionClose(3)"));
}


/**
 * Prüft, ob die aktuellen BollingerBand-Limite verletzt wurden und benachrichtigt entsprechend.
 *
 * @return int - Fehlerstatus
 */
int CheckBollingerBands() {
   if (!Track.BollingerBands)
      return(NO_ERROR);

   // Parameteranzeige
   static bool done;
   if (!done) {
      debug("CheckBollingerBands()   "+ BollingerBands.MA.Periods +"x"+ PeriodDescription(BollingerBands.MA.Timeframe) +", "+ MovingAverageMethodDescription(BollingerBands.MA.Method) +", "+ NumberToStr(BollingerBands.Deviation, ".1+"));
      done = true;
   }

   #define CR_UNKNOWN 0
   #define CR_HIGH    1
   #define CR_LOW     2
   #define CR_BOTH    3


   // (1) Datenreihe aktualisieren
   static double   history[][6];                                     // Zeiger, verhält sich wie ein Integer
   static int      oldBars, crossing;                                // das letzte Crossing: CR_UNKNOWN | CR_HIGH | CR_LOW | CR_BOTH
   static datetime oldestBar, newestBar, crossingTime;

   int bars = ArrayCopyRates(history, NULL, BollingerBands.MA.Timeframe);
   if (bars < 1)
      return(catch("CheckBollingerBands(1)   ArrayCopyRates("+ Symbol() +","+ PeriodDescription(BollingerBands.MA.Timeframe) +") returned "+ bars +" bars", ERR_RUNTIME_ERROR));
   datetime last  = history[bars-1][RATE_TIME] +0.1;                 // (datetime) double
   datetime first = history[     0][RATE_TIME] +0.1;

   int error = GetLastError();
   if (error == ERR_HISTORY_UPDATE) {
      debug("CheckBollingerBands()   ArrayCopyRates("+ Symbol() +","+ PeriodDescription(BollingerBands.MA.Timeframe) +") from "+ TimeToStr(last) +" to "+ TimeToStr(first), error);
      oldBars = 0;
      return(processError(error));
   }


   // (2) IndicatorCounted() emulieren => ChangedBars, ValidBars
   int lChangedBars, lValidBars;
   if      (oldBars == 0)         lValidBars = 0;                    // erstes Laden der History
   else if (bars == oldBars)      lValidBars = oldBars - 1;          // Baranzahl unverändert (normaler Tick)
   else if (last  != oldestBar) { lValidBars = 0;           debug("CheckBollingerBands()   "+ (bars-oldBars) +" Bar"+ ifString(bars-oldBars==1, "", "s") +" hinten angefügt"   ); }
   else if (first != newestBar) { lValidBars = oldBars - 1; debug("CheckBollingerBands()   "+ (bars-oldBars) +" Bar"+ ifString(bars-oldBars==1, "", "s") +" vorn angefügt"     ); }
   else                         { lValidBars = 0;           debug("CheckBollingerBands()   "+ (bars-oldBars) +" Bar"+ ifString(bars-oldBars==1, "", "s") +" in Lücke eingefügt"); }
   oldBars      = bars;
   oldestBar    = last;
   newestBar    = first;
   lChangedBars = bars - lValidBars;
   debug("CheckBollingerBands()   "+ bars +" bars   ValidBars="+ lValidBars + "   ChangedBars="+ lChangedBars);


   double   ma, dev, lowerBB, upperBB, low, high, close;
   datetime barTime;
   int      bar, endBar=MathMin(lChangedBars-1, bars-BollingerBands.MA.Periods);


   // (3) Initialisierung: Bänder von neu nach alt nach erstem Crossing durchsuchen (zeitmäßig das jüngste)
   if (lValidBars == 0) {
      crossing = CR_UNKNOWN;

      for (bar=0; bar <= endBar; bar++) {
         ma      = iMA    (NULL, BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, 0, BollingerBands.MA.Method, PRICE_CLOSE, bar);
         dev     = iStdDev(NULL, BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, 0, BollingerBands.MA.Method, PRICE_CLOSE, bar) * BollingerBands.Deviation;
         upperBB = NormalizeDouble(ma + dev, Digits);
         lowerBB = NormalizeDouble(ma - dev, Digits);
         high    = history[bar][RATE_HIGH];
         low     = history[bar][RATE_LOW ];
         if (LE(low,  lowerBB)) { crossing = ifInt(GE(high, upperBB), CR_BOTH, CR_LOW); break; }
         if (GE(high, upperBB)) { crossing = CR_HIGH;                                   break; }
      }
      crossingTime = history[bar][RATE_TIME] +0.1;                   // (datetime) double
      MarkCrossing(crossing, crossingTime, lowerBB, upperBB);

      // bei Initialisierung (ValidBars==0) kann niemals Signal getriggert werden => Rückkehr
      return(catch("CheckBollingerBands(2)"));
   }


   // (4) ChangedBars > 1: ChangedBars von alt nach neu neuberechnen und dabei alle außer der ersten Bar auf neues Crossing prüfen
   if (lChangedBars > 1) {
      for (bar=endBar; bar > 0; bar--) {                             // Bar[0] wird hier nicht berechnet
         ma      = iMA    (NULL, BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, 0, BollingerBands.MA.Method, PRICE_CLOSE, bar);
         dev     = iStdDev(NULL, BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, 0, BollingerBands.MA.Method, PRICE_CLOSE, bar) * BollingerBands.Deviation;
         upperBB = NormalizeDouble(ma + dev, Digits);
         lowerBB = NormalizeDouble(ma - dev, Digits);
         high    = history[bar][RATE_HIGH];
         low     = history[bar][RATE_LOW ];
         barTime = history[bar][RATE_TIME] +0.1;                     // (datetime) double

         int lastCrossing = crossing;

         switch (crossing) {
            case CR_UNKNOWN: if      (LE(low,  lowerBB)) crossing = ifInt(GE(high, upperBB), CR_BOTH, CR_LOW);
                             else if (GE(high, upperBB)) crossing = CR_HIGH;
                             break;

            case CR_BOTH:    if (crossingTime < barTime || lChangedBars==2) {    // Bei BarOpen-Event (ChangedBars==2) kann mit dem letzten Tick der
                                if (LE(low, lowerBB)) {                          // alten Bar ein neues, zu signalisierendes Crossing auftreten.
                                   if (LT(high, upperBB))   crossing = CR_LOW;
                                }
                                else if (GE(high, upperBB)) crossing = CR_HIGH;
                             }
                             break;

            case CR_HIGH:    if (crossingTime < barTime || lChangedBars==2)
                                if (LE(low, lowerBB))  crossing = ifInt(GE(high, upperBB), CR_BOTH, CR_LOW);
                             break;

            case CR_LOW:     if (crossingTime < barTime || lChangedBars==2)
                                if (GE(high, upperBB)) crossing = ifInt(LE(low, lowerBB), CR_BOTH, CR_HIGH);
                             break;
         }

         // Crossing markieren und bei BarOpen-Event (ChangedBars==2) signalisieren
         if (crossing != lastCrossing) {
            crossingTime = barTime;
            if (lChangedBars == 2)
               crossingTime += BollingerBands.MA.Timeframe*MINUTES - 1;          // letzte Sekunde der alten Bar
            if (lastCrossing != CR_UNKNOWN)
               SignalCrossing(crossing, crossingTime, lowerBB, upperBB);
            MarkCrossing(crossing, crossingTime, lowerBB, upperBB);
         }
      }
   }


   // (5) aktuellen Tick in Bar[0] prüfen und ggf. Signal auslösen (hier können sich je Tick High/Low/UpperBB/LowerBB ändern)
   ma      = iMA    (NULL, BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, 0, BollingerBands.MA.Method, PRICE_CLOSE, 0);
   dev     = iStdDev(NULL, BollingerBands.MA.Timeframe, BollingerBands.MA.Periods, 0, BollingerBands.MA.Method, PRICE_CLOSE, 0) * BollingerBands.Deviation;
   upperBB = NormalizeDouble(ma + dev, Digits);
   lowerBB = NormalizeDouble(ma - dev, Digits);
   high    = history[0][RATE_HIGH ];
   low     = history[0][RATE_LOW  ];
   close   = history[0][RATE_CLOSE];
   barTime = history[0][RATE_TIME ] +0.1;                            // (datetime) double

   if      (lChangedBars == 1) {       // einzelner Tick innerhalb der Bar
   }
   else if (lChangedBars == 2) {       // erster Tick einer neuen Bar (BarOpen-Event)
   }
   else {                              // History-Update (kann/kann nicht mit normalem Tick zusammenfallen)
   }


   switch (lastCrossing) {
      case CR_UNKNOWN: break;
      case CR_BOTH:    break;
      case CR_HIGH:    break;
      case CR_LOW:     break;
   }

   return(catch("CheckBollingerBands(3)"));
}


/**
 * @return int - Fehlerstatus
 */
int MarkCrossing(int crossing, datetime crossingTime, double lowerBBValue, double upperBBValue) {
   string arrowLabel = "";
   color  arrowColor = DeepSkyBlue;

   switch (crossing) {
      // --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      case CR_LOW : arrowLabel = __SCRIPT__ +".bbCrossing.Low."+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"/"+ NumberToStr(lowerBBValue, PriceFormat);
                    if (ObjectFind(arrowLabel) > -1)
                       ObjectDelete(arrowLabel);
                    if (ObjectCreate(arrowLabel, OBJ_ARROW, 0, crossingTime, lowerBBValue)) {
                       ObjectSet(arrowLabel, OBJPROP_ARROWCODE, 1);
                       ObjectSet(arrowLabel, OBJPROP_COLOR, arrowColor);
                    }
                    else GetLastError();
                    ArrayPushString(chartObjects, arrowLabel);
                    debug("MarkCrossing()   low crossing at "+  TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"  <= "+ NumberToStr(lowerBBValue, PriceFormat));
                    break;
      // --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      case CR_HIGH: arrowLabel = __SCRIPT__ +".bbCrossing.High."+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"/"+ NumberToStr(upperBBValue, PriceFormat);
                    if (ObjectFind(arrowLabel) > -1)
                       ObjectDelete(arrowLabel);
                    if (ObjectCreate(arrowLabel, OBJ_ARROW, 0, crossingTime, upperBBValue)) {
                       ObjectSet(arrowLabel, OBJPROP_ARROWCODE, 1);
                       ObjectSet(arrowLabel, OBJPROP_COLOR, arrowColor);
                    }
                    else GetLastError();
                    ArrayPushString(chartObjects, arrowLabel);
                    debug("MarkCrossing()   high crossing at "+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"  => "+ NumberToStr(upperBBValue, PriceFormat));
                    break;
      // --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      case CR_BOTH: arrowLabel = __SCRIPT__ +".bbCrossing.Low."+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"/"+ NumberToStr(lowerBBValue, PriceFormat);
                    if (ObjectFind(arrowLabel) > -1)
                       ObjectDelete(arrowLabel);
                    if (ObjectCreate(arrowLabel, OBJ_ARROW, 0, crossingTime, lowerBBValue)) {
                       ObjectSet(arrowLabel, OBJPROP_ARROWCODE, 1);
                       ObjectSet(arrowLabel, OBJPROP_COLOR, arrowColor);
                    }
                    else GetLastError();
                    ArrayPushString(chartObjects, arrowLabel);

                    arrowLabel = __SCRIPT__ +".bbCrossing.High."+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"/"+ NumberToStr(upperBBValue, PriceFormat);
                    if (ObjectFind(arrowLabel) > -1)
                       ObjectDelete(arrowLabel);
                    if (ObjectCreate(arrowLabel, OBJ_ARROW, 0, crossingTime, upperBBValue)) {
                       ObjectSet(arrowLabel, OBJPROP_ARROWCODE, 1);
                       ObjectSet(arrowLabel, OBJPROP_COLOR, arrowColor);
                    }
                    else GetLastError();
                    ArrayPushString(chartObjects, arrowLabel);
                    debug("MarkCrossing()   two crossings at "+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"  <= "+ NumberToStr(lowerBBValue, PriceFormat)  +" && => "+ NumberToStr(upperBBValue, PriceFormat));
                    break;
      // --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      case CR_UNKNOWN:
                    debug("MarkCrossing()   unknown crossing");
                    break;
      // --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
      default:
         return(catch("MarkCrossing(1)   invalid parameter crossing = "+ crossing, ERR_INVALID_FUNCTION_PARAMVALUE));
   }
   return(catch("MarkCrossing(2)"));
}


/**
 * @return int - Fehlerstatus
 */
int SignalCrossing(int crossing, datetime crossingTime, double lowerValue, double upperValue) {
   switch (crossing) {
      case CR_LOW : debug("SignalCrossing()   new low crossing at "+  TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"  <= "+ NumberToStr(lowerValue, PriceFormat)); break;
      case CR_HIGH: debug("SignalCrossing()   new high crossing at "+ TimeToStr(crossingTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +"  => "+ NumberToStr(upperValue, PriceFormat)); break;
      default:
         return(catch("SignalCrossing(1)   invalid parameter crossing = "+ crossing, ERR_INVALID_FUNCTION_PARAMVALUE));
   }
   return(catch("SignalCrossing(2)"));
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
      Print("CheckPivotLevels()    "+ PeriodDescription(period) +":range"+ bar +"   Open="+ NumberToStr(range[MODE_OPEN], ".4'") +"    High="+ NumberToStr(range[MODE_HIGH], ".4'") +"    Low="+ NumberToStr(range[MODE_LOW], ".4'") +"    Close="+ NumberToStr(range[MODE_CLOSE], ".4'"));

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
 */


/**
 * Ermittelt die OHLC-Werte eines Instruments für eine einzelne Bar einer Periode und schreibt sie in das angegebene Zielarray.
 * Existiert die angegebene Bar nicht, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double& results[4] - Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string  symbol     - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     period     - Periode (default: 0 = aktuelle Periode)
 * @param  int     bar        - Bar-Offset
 * @param  bool    exact      - TRUE:  Berechnungsgrundlage für Bars sind tatsächliche Handelszeiten, entspricht der (virtuellen) Tradeserver-Zeitzone
 *                                     "EST+0700,EDT+0700"
 *                            - FALSE: Berechnungsgrundlage für Bars ist die Zeitzoneneinstellung des Tradeservers (default)
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Bar nicht existiert,
 *                             ggf. ERR_HISTORY_UPDATE
 *
int iOHLCBar(double& results[4], string symbol/*=NULL, int period/*=0, int bar, bool exact=false) {
   // TODO: möglichst aktuellen Chart benutzen, um ERR_HISTORY_UPDATE zu vermeiden

   if (symbol == "0")                                       // NULL ist ein Integer (0)
      symbol = Symbol();
   if (bar < 0)
      return(catch("iOHLCBar(1)  invalid parameter bar = "+ bar, ERR_INVALID_FUNCTION_PARAMVALUE));


   // schnelle Berechnung für exact=FALSE oder Perioden < H4
   if (!exact || period < PERIOD_H4) {
      results[MODE_OPEN ] = iOpen (symbol, period, bar);
      results[MODE_HIGH ] = iHigh (symbol, period, bar);
      results[MODE_LOW  ] = iLow  (symbol, period, bar);
      results[MODE_CLOSE] = iClose(symbol, period, bar);
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
            error = iOHLCBarRange(results, symbol, PERIOD_H1, startBar, endBar);
            if (error == ERR_NO_RESULT) catch("iOHLCBar(3)    iOHLCBarRange() => ", error);
            if (error != NO_ERROR     ) return(error);
            break;

         case PERIOD_H4 :
         case PERIOD_W1 :
         case PERIOD_MN1:
         default:
            return(catch("iOHLCBar(4)   exact calculation for "+ PeriodToStr(period) +" not yet implemented", ERR_RUNTIME_ERROR));
      }
   }

   if (error != NO_ERROR) {
      if (error != ERR_HISTORY_UPDATE) catch("iOHLCBar(5)", error);
   }
   else if (results[MODE_OPEN] == 0) {
      error = ERR_NO_RESULT;
   }
   return(error);
}
*/


/**
 * Ermittelt die OHLC-Werte eines Instruments für eine Bar-Range einer Periode und schreibt sie in das angegebene Zielarray.
 * Existiert die angegebene Startbar (from) nicht, wird die nächste existierende Bar verwendet.
 * Existiert die angegebene Endbar (to) nicht, wird die letzte existierende Bar verwendet.
 * Existiert die resultierende Bar-Range nicht, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double& results[4] - Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
 * @param  string  symbol     - Symbol des Instruments (default: NULL = aktuelles Symbol)
 * @param  int     period     - Periode (default: 0 = aktuelle Periode)
 * @param  int     from       - Offset der Startbar
 * @param  int     to         - Offset der Endbar
 *
 * @return int - Fehlerstatus: ERR_NO_RESULT, wenn die angegebene Range nicht existiert,
 *                             ggf. ERR_HISTORY_UPDATE
 *
 * NOTE:    Diese Funktion wertet die in der History gespeicherten Bars unabhängig davon aus, ob diese Bars realen Bars entsprechen.
 * -----    Siehe: iOHLCTime(destination, symbol, timeframe, time, exact=TRUE)
 *
int iOHLCBarRange(double& results[4], string symbol/*=NULL, int period/*=0, int from, int to) {
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
      results[MODE_OPEN ] = 0;
      results[MODE_HIGH ] = 0;
      results[MODE_LOW  ] = 0;
      results[MODE_CLOSE] = 0;
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

   results[MODE_OPEN ] = iOpen (symbol, period, from);
   results[MODE_HIGH ] = iHigh (symbol, period, high);
   results[MODE_LOW  ] = iLow  (symbol, period, low );
   results[MODE_CLOSE] = iClose(symbol, period, to  );

   return(catch("iOHLCBarRange(5)"));
}
*/


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitpunkt einer Periode und schreibt sie in das angegebene Zielarray.
 * Ergebnis sind die Werte der Bar, die diesen Zeitpunkt abdeckt.
 *
 * @param  double&  results[4] - Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
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

   if (symbol == "0")                           // NULL ist ein Integer (0)
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
      last_error = ERR_NO_RESULT;
      return(ERR_NO_RESULT);
   }

   error = iOHLCBar(results, symbol, timeframe, bar);
   if (error == ERR_NO_RESULT)
      catch("iOHLCTime(2)", error);
   return(error);
}
 */


/**
 * Ermittelt die OHLC-Werte eines Instruments für einen Zeitraum und schreibt sie in das angegebene Zielarray.
 * Existieren in diesem Zeitraum keine Kurse, werden die Werte 0 und der Fehlerstatus ERR_NO_RESULT zurückgegeben.
 *
 * @param  double&  results[4] - Array für die Ergebnisse { MODE_OPEN, MODE_LOW, MODE_HIGH, MODE_CLOSE }
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
      results[MODE_OPEN ] = 0;
      results[MODE_HIGH ] = 0;
      results[MODE_LOW  ] = 0;
      results[MODE_CLOSE] = 0;
      last_error = ERR_NO_RESULT;
      return(ERR_NO_RESULT);
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
   //Print("iOHLCTimeRange()    from="+ TimeToStr(from, TIME_DATE|TIME_MINUTES) +" (bar="+ fromBar +")   to="+ TimeToStr(to, TIME_DATE|TIME_MINUTES) +" (bar="+ toBar +")   period="+ PeriodDescription(period));

   return(catch("iOHLCTimeRange(3)"));
}
*/

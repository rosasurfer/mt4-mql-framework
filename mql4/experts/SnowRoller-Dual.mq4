/**
 * SnowRoller-Strategy: ein unabhängiger SnowRoller je Richtung
 */
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_CUSTOMLOG};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <win32api.mqh>

#include <core/expert.mqh>
#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern int    GridSize        = 20;
extern double LotSize         = 0.1;
extern string StartConditions = "@trend(ALMA:3.5xD1)";
extern string StopConditions  = "@profit(500)";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int      last.GridSize;                                                 // Input-Parameter sind nicht statisch. Extern geladene Parameter werden bei REASON_CHARTCHANGE
double   last.LotSize;                                                  // mit den Default-Werten überschrieben. Um dies zu verhindern und um geänderte Parameter mit
string   last.StartConditions = "";                                     // alten Werten vergleichen zu können, werden sie in deinit() in last.* zwischengespeichert und
string   last.StopConditions  = "";                                     // in init() daraus restauriert.

int      instance.id;                                                   // eine Instanz (mit eigener Statusdatei) verwaltet mehrere unabhängige Sequenzen
bool     instance.isTest;                                               // ob die Instanz eine Testinstanz ist und nur Testsequenzen verwaltet (im Tester oder im Online-Chart)

// ---------------------------------------------------------------
bool     start.trend.condition;
string   start.trend.condition.txt;
double   start.trend.periods;
int      start.trend.timeframe, start.trend.timeframeFlag;              // maximal PERIOD_H1
string   start.trend.method;
int      start.trend.lag;

// ---------------------------------------------------------------
bool     stop.profitAbs.condition;
string   stop.profitAbs.condition.txt;
double   stop.profitAbs.value;

// ---------------------------------------------------------------
datetime weekend.stop.condition   = D'1970.01.01 23:05';                // StopSequence()-Zeitpunkt vor Wochenend-Pause (Freitags abend)
datetime weekend.stop.time;

datetime weekend.resume.condition = D'1970.01.01 01:10';                // spätester ResumeSequence()-Zeitpunkt nach Wochenend-Pause (Montags morgen)
datetime weekend.resume.time;

// ---------------------------------------------------------------
int      sequence.id           [2];
bool     sequence.isTest       [2];
int      sequence.status       [2];
string   sequence.status.file  [2][2];                                  // [0]=>Verzeichnisname relativ zu ".\files\", [1]=>Dateiname

int      sequence.direction    [2];
int      sequence.gridSize     [2];
double   sequence.lotSize      [2];
double   sequence.commission   [2];                                     // Commission-Betrag je Level

int      sequence.level        [2];                                     // aktueller Grid-Level
int      sequence.maxLevel     [2];                                     // maximal erreichter Grid-Level
double   sequence.startEquity  [2];                                     // Equity bei Sequenzstart
bool     sequence.weStop.active[2];                                     // Weekend-Stop aktiv (unterscheidet vorübergehend und dauerhaft gestoppte Sequenzen)

int      sequence.stops        [2];                                     // Anzahl der bisher getriggerten Stops
double   sequence.stopsPL      [2];                                     // kumulierter P/L aller bisher ausgestoppten Positionen
double   sequence.closedPL     [2];                                     // kumulierter P/L aller bisher bei Sequencestop geschlossenen Positionen
double   sequence.floatingPL   [2];                                     // kumulierter P/L aller aktuell offenen Positionen
double   sequence.totalPL      [2];                                     // aktueller Gesamt-P/L der Sequenz: grid.stopsPL + grid.closedPL + grid.floatingPL
double   sequence.openRisk     [2];                                     // vorraussichtlicher kumulierter P/L aller aktuell offenen Level bei deren Stopout: sum(orders.openRisk)
double   sequence.valueAtRisk  [2];                                     // vorraussichtlicher Gesamt-P/L der Sequenz bei Stop in Level 0: grid.stopsPL + grid.openRisk
double   sequence.maxProfit    [2];                                     // maximaler bisheriger Gesamt-Profit der Sequenz   (>= 0)
double   sequence.maxDrawdown  [2];                                     // maximaler bisheriger Gesamt-Drawdown der Sequenz (<= 0)
double   sequence.breakeven    [2];

// ---------------------------------------------------------------
int      sequence.ss.events    [2][3];                                  // [0]=>from_index, [1]=>to_index, [2]=>size von Start- und Stopdaten (sind jeweils synchron)
int      sequenceStart.event   [];                                      // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime sequenceStart.time    [];
double   sequenceStart.price   [];
double   sequenceStart.profit  [];

int      sequenceStop.event    [];                                      // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime sequenceStop.time     [];
double   sequenceStop.price    [];
double   sequenceStop.profit   [];

// ---------------------------------------------------------------
int      gridbase.events       [2][3];                                  // [0]=>from_index, [1]=>to_index, [2]=>size
int      gridbase.event        [];                                      // Gridbasis-Daten
datetime gridbase.time         [];
double   gridbase.value        [];
double   gridbase              [];                                      // aktuelle Gridbasis

// ---------------------------------------------------------------
int      orders                [2][3];                                  // [0]=>from_index, [1]=>to_index, [2]=>size
int      orders.ticket         [];
int      orders.level          [];                                      // Gridlevel der Order
double   orders.gridBase       [];                                      // Gridbasis der Order

int      orders.pendingType    [];                                      // Pending-Orderdaten (falls zutreffend)
datetime orders.pendingTime    [];                                      // Zeitpunkt von OrderOpen() bzw. letztem OrderModify()
double   orders.pendingPrice   [];

int      orders.type           [];
int      orders.openEvent      [];
datetime orders.openTime       [];
double   orders.openPrice      [];
double   orders.openRisk       [];                                      // vorraussichtlicher P/L des Levels seit letztem Stopout bei erneutem Stopout

int      orders.closeEvent     [];
datetime orders.closeTime      [];
double   orders.closePrice     [];
double   orders.stopLoss       [];
bool     orders.clientSL       [];                                      // client- oder server-seitiger StopLoss
bool     orders.closedBySL     [];

double   orders.swap           [];
double   orders.commission     [];
double   orders.profit         [];

// ---------------------------------------------------------------
int      ignores               [2][3];                                  // [0]=>from_index, [1]=>to_index, [2]=>size
int      ignore.pendingOrders  [];                                      // orphaned tickets to ignore
int      ignore.openPositions  [];
int      ignore.closedPositions[];

// ---------------------------------------------------------------
string   str.sequence.stops    [2];                                     // Zwischenspeicher für schnelleres ShowStatus(): je Sequenz
string   str.sequence.stopsPL  [2];
string   str.sequence.totalPL  [2];
string   str.sequence.plStats  [2];

// ---------------------------------------------------------------
string   str.instance.lotSize;                                          // Zwischenspeicher für schnelleres ShowStatus(): gesamt
string   str.instance.totalPL;
string   str.instance.plStats;
// ---------------------------------------------------------------


#include <SnowRoller/init-dual.mqh>
#include <SnowRoller/deinit-dual.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   Strategy(D_LONG );
   Strategy(D_SHORT);
   return(last_error);
}


/**
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy(int direction) {
   if (__STATUS_ERROR)
      return(false);

   bool changes;                                                     // Gridbasis- oder -leveländerung
   int  status, stops[];                                             // getriggerte client-seitige Stops

   // (1) Strategie wartet auf Startsignal, ...
   if (sequence.status[direction] == STATUS_UNINITIALIZED) {
      if (IsStartSignal(direction))   StartSequence(direction);
   }

   // (2) ... oder auf ResumeSignal ...
   else if (sequence.status[direction] == STATUS_STOPPED) {
      if  (IsResumeSignal(direction)) ResumeSequence(direction);
      else return(!IsLastError());
   }

   // (3) ... oder läuft
   else if (UpdateStatus(direction, changes, stops)) {
      if (IsStopSignal(direction))    StopSequence(direction);
      else {
         if (ArraySize(stops) > 0)    ProcessClientStops(stops);
         if (changes)                 UpdatePendingOrders(direction);
      }
   }

   return(!IsLastError());
}


/**
 * Signalgeber für StartSequence().
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal(int direction) {
   if (__STATUS_ERROR)
      return(false);

   int iNull[];

   if (EventListener.BarOpen(iNull, start.trend.timeframeFlag)) {
      // Startbedingung wird nur bei onBarOpen geprüft, nicht bei jedem Tick
      int    timeframe   = start.trend.timeframe;
      string maPeriods   = NumberToStr(start.trend.periods, ".+");
      string maTimeframe = PeriodDescription(start.trend.timeframe);
      string maMethod    = start.trend.method;
      int    lag         = start.trend.lag;
      int    signal      = 0;

      if (CheckTrendChange(timeframe, maPeriods, maTimeframe, maMethod, lag, directionFlags[direction], signal)) {
         if (signal != 0) {
            if (__LOG) log(StringConcatenate("IsStartSignal()   start signal \"", start.trend.condition.txt, "\" ", ifString(signal>0, "up", "down")));
            return(true);
         }
      }
   }
   return(false);
}


/**
 * Signalgeber für ResumeSequence().
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool
 */
bool IsResumeSignal(int direction) {
   if (__STATUS_ERROR)
      return(false);
   return(IsWeekendResumeSignal());
}


/**
 * Signalgeber für ResumeSequence(). Prüft, ob die Weekend-Resume-Bedingung erfüllt ist.
 *
 * @return bool
 */
bool IsWeekendResumeSignal() {
   return(!catch("IsWeekendResumeSignal()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Signalgeber für StopSequence().
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStopSignal(int direction) {
   return(!catch("IsStopSignal()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Startet eine neue Trade-Sequenz.
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence(int direction) {
   if (__STATUS_ERROR)                                     return( false);
   if (sequence.status[direction] != STATUS_UNINITIALIZED) return(_false(catch("StartSequence(1)   cannot start "+ statusDescr[sequence.status[direction]] +" sequence", ERR_RUNTIME_ERROR)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("StartSequence()", "Do you really want to start a new "+ StringToLower(directionDescr[direction]) +" sequence now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   return(!catch("StartSequence(2)", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Schließt alle PendingOrders und offenen Positionen der Sequenz.
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus: ob die Sequenz erfolgreich gestoppt wurde
 */
bool StopSequence(int direction) {
   return(!catch("StopSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Setzt eine gestoppte Sequenz fort.
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool ResumeSequence(int direction) {
   return(!catch("ResumeSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @param  int  direction        - D_LONG | D_SHORT
 * @param  bool lpChanges        - Variable, die nach Rückkehr anzeigt, ob sich Gridbasis oder Gridlevel der Sequenz geändert haben
 * @param  int  triggeredStops[] - Array, das nach Rückkehr die Array-Indizes getriggerter client-seitiger Stops enthält (Pending- und SL-Orders)
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus(int direction, bool &lpChanges, int triggeredStops[]) {
   return(!catch("UpdateStatus()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Ordermanagement getriggerter client-seitiger Stops. Kann eine getriggerte Stop-Order oder ein getriggerter Stop-Loss sein.
 *
 * @param  int stops[] - Array-Indizes der Orders mit getriggerten Stops
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessClientStops(int stops[]) {
   return(!catch("ProcessClientStops()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Aktualisiert vorhandene, setzt fehlende und löscht unnötige PendingOrders.
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePendingOrders(int direction) {
   return(!catch("UpdatePendingOrders()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Speichert die aktuelle Konfiguration zwischen, um sie bei Fehleingaben nach Parameteränderungen restaurieren zu können.
 *
 * @return void
 */
void StoreConfiguration(bool save=true) {
   static int    _GridSize;
   static double _LotSize;
   static string _StartConditions;
   static string _StopConditions;

   static bool   _start.trend.condition;
   static string _start.trend.condition.txt;
   static double _start.trend.periods;
   static int    _start.trend.timeframe;
   static int    _start.trend.timeframeFlag;
   static string _start.trend.method;
   static int    _start.trend.lag;

   static bool   _stop.profitAbs.condition;
   static string _stop.profitAbs.condition.txt;
   static double _stop.profitAbs.value;

   if (save) {
      _GridSize                     = GridSize;
      _LotSize                      = LotSize;
      _StartConditions              = StringConcatenate(StartConditions, "");    // Pointer-Bug bei String-Inputvariablen (siehe MQL.doc)
      _StopConditions               = StringConcatenate(StopConditions,  "");

      _start.trend.condition        = start.trend.condition;
      _start.trend.condition.txt    = start.trend.condition.txt;
      _start.trend.periods          = start.trend.periods;
      _start.trend.timeframe        = start.trend.timeframe;
      _start.trend.timeframeFlag    = start.trend.timeframeFlag;
      _start.trend.method           = start.trend.method;
      _start.trend.lag              = start.trend.lag;

      _stop.profitAbs.condition     = stop.profitAbs.condition;
      _stop.profitAbs.condition.txt = stop.profitAbs.condition.txt;
      _stop.profitAbs.value         = stop.profitAbs.value;
   }
   else {
      GridSize                      = _GridSize;
      LotSize                       = _LotSize;
      StartConditions               = _StartConditions;
      StopConditions                = _StopConditions;

      start.trend.condition         = _start.trend.condition;
      start.trend.condition.txt     = _start.trend.condition.txt;
      start.trend.periods           = _start.trend.periods;
      start.trend.timeframe         = _start.trend.timeframe;
      start.trend.timeframeFlag     = _start.trend.timeframeFlag;
      start.trend.method            = _start.trend.method;
      start.trend.lag               = _start.trend.lag;

      stop.profitAbs.condition      = _stop.profitAbs.condition;
      stop.profitAbs.condition.txt  = _stop.profitAbs.condition.txt;
      stop.profitAbs.value          = _stop.profitAbs.value;
   }
}


/**
 * Restauriert eine zuvor gespeicherte Konfiguration.
 *
 * @return void
 */
void RestoreConfiguration() {
   StoreConfiguration(false);
}


/**
 * Validiert die aktuelle Konfiguration.
 *
 * @param  bool interactive - ob fehlerhafte Parameter interaktiv korrigiert werden können
 *
 * @return bool - ob die Konfiguration gültig ist
 */
bool ValidateConfiguration(bool interactive) {
   if (__STATUS_ERROR)
      return(false);

   bool reasonParameters = (UninitializeReason() == REASON_PARAMETERS);
   if (reasonParameters)
      interactive = true;


   // (1) GridSize
   if (reasonParameters) {
      if (GridSize != last.GridSize)             return(_false(ValidateConfig.HandleError("ValidateConfiguration(1)", "Cannot change GridSize of running strategy", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Sequenz gestartet wurde
   }
   if (GridSize < 1)                             return(_false(ValidateConfig.HandleError("ValidateConfiguration(2)", "Invalid GridSize = "+ GridSize, interactive)));


   // (2) LotSize
   if (reasonParameters) {
      if (NE(LotSize, last.LotSize))             return(_false(ValidateConfig.HandleError("ValidateConfiguration(3)", "Cannot change LotSize of running strategy", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Sequenz gestartet wurde
   }
   if (LE(LotSize, 0))                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(4)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+"), interactive)));
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT );
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT );
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int error = GetLastError();
   if (IsError(error))                           return(_false(catch("ValidateConfiguration(5)   symbol=\""+ Symbol() +"\"", error)));
   if (LT(LotSize, minLot))                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(6)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", interactive)));
   if (GT(LotSize, maxLot))                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(7)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", interactive)));
   if (NE(MathModFix(LotSize, lotStep), 0))      return(_false(ValidateConfig.HandleError("ValidateConfiguration(8)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", interactive)));
   SS.LotSize();


   // (3) StartConditions: "@trend(**MA:7xD1[+1])"
   // --------------------------------------------
   if (!reasonParameters || StartConditions!=last.StartConditions) {
      start.trend.condition = false;

      string expr, elems[], key, value;
      double dValue;

      expr = StringToLower(StringTrim(StartConditions));
      if (StringLen(expr) == 0)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(9)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));

      if (StringGetChar(expr, 0) != '@')         return(_false(ValidateConfig.HandleError("ValidateConfiguration(10)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      if (Explode(expr, "(", elems, NULL) != 2)  return(_false(ValidateConfig.HandleError("ValidateConfiguration(11)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      if (!StringEndsWith(elems[1], ")"))        return(_false(ValidateConfig.HandleError("ValidateConfiguration(12)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      key = StringTrim(elems[0]);
      if (key != "@trend")                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(13)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      value = StringTrim(StringLeft(elems[1], -1));
      if (StringLen(value) == 0)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(14)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));

      if (Explode(value, ":", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(15)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      key   = StringToUpper(StringTrim(elems[0]));
      value = StringToUpper(elems[1]);
      // key="ALMA"
      if      (key == "SMA" ) start.trend.method = key;
      else if (key == "EMA" ) start.trend.method = key;
      else if (key == "SMMA") start.trend.method = key;
      else if (key == "LWMA") start.trend.method = key;
      else if (key == "ALMA") start.trend.method = key;
      else                                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(16)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      // value="7XD1[+2]"
      if (Explode(value, "+", elems, NULL) == 1) {
         start.trend.lag = 0;
      }
      else {
         value = StringTrim(elems[1]);
         if (!StringIsDigit(value))              return(_false(ValidateConfig.HandleError("ValidateConfiguration(17)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         start.trend.lag = StrToInteger(value);
         if (start.trend.lag < 0)                return(_false(ValidateConfig.HandleError("ValidateConfiguration(18)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         value = elems[0];
      }
      // value="7XD1"
      if (Explode(value, "X", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(19)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      elems[1]              = StringTrim(elems[1]);
      start.trend.timeframe = PeriodToId(elems[1]);
      if (start.trend.timeframe == -1)           return(_false(ValidateConfig.HandleError("ValidateConfiguration(20)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      value = StringTrim(elems[0]);
      if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(21)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      dValue = StrToDouble(value);
      if (dValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(22)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      if (NE(MathModFix(dValue, 0.5), 0))        return(_false(ValidateConfig.HandleError("ValidateConfiguration(23)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      elems[0] = NumberToStr(dValue, ".+");
      switch (start.trend.timeframe) {           // Timeframes > H1 auf H1 umrechnen, iCustom() soll unabhängig vom MA mit maximal PERIOD_H1 laufen
         case PERIOD_MN1:                        return(_false(ValidateConfig.HandleError("ValidateConfiguration(24)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         case PERIOD_H4 : { dValue *=   4; start.trend.timeframe = PERIOD_H1; break; }
         case PERIOD_D1 : { dValue *=  24; start.trend.timeframe = PERIOD_H1; break; }
         case PERIOD_W1 : { dValue *= 120; start.trend.timeframe = PERIOD_H1; break; }
      }
      start.trend.periods       = NormalizeDouble(dValue, 1);
      start.trend.timeframeFlag = PeriodFlag(start.trend.timeframe);
      start.trend.condition.txt = "@trend("+ start.trend.method +":"+ elems[0] +"x"+ elems[1] + ifString(!start.trend.lag, "", "+"+ start.trend.lag) +")";
      start.trend.condition     = true;

      StartConditions           = start.trend.condition.txt;
   }


   // (4) StopConditions: "@profit(1234)"
   // -----------------------------------
   if (!reasonParameters || StopConditions!=last.StopConditions) {
      stop.profitAbs.condition = false;

      // StopConditions parsen und validieren
      expr = StringToLower(StringTrim(StopConditions));
      if (StringLen(expr) == 0)                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(25)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));

      if (StringGetChar(expr, 0) != '@')          return(_false(ValidateConfig.HandleError("ValidateConfiguration(26)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
      if (Explode(expr, "(", elems, NULL) != 2)   return(_false(ValidateConfig.HandleError("ValidateConfiguration(27)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
      if (!StringEndsWith(elems[1], ")"))         return(_false(ValidateConfig.HandleError("ValidateConfiguration(28)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
      key = StringTrim(elems[0]);
      if (key != "@profit")                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(29)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
      value = StringTrim(StringLeft(elems[1], -1));
      if (StringLen(value) == 0)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(30)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
      if (!StringIsNumeric(value))                return(_false(ValidateConfig.HandleError("ValidateConfiguration(31)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
      dValue = StrToDouble(value);

      stop.profitAbs.value         = NormalizeDouble(dValue, 2);
      stop.profitAbs.condition.txt = key +"("+ NumberToStr(dValue, ".2") +")";
      stop.profitAbs.condition     = true;

      StopConditions               = stop.profitAbs.condition.txt;
   }


   // (5) __STATUS_INVALID_INPUT zurücksetzen
   if (interactive)
      __STATUS_INVALID_INPUT = false;

   return(!last_error|catch("ValidateConfiguration(32)"));
}


/**
 * Exception-Handler für ungültige Input-Parameter. Je nach Situation wird der Fehler weitergereicht oder zur Korrektur aufgefordert.
 *
 * @param  string location    - Ort, an dem der Fehler auftrat
 * @param  string message     - Fehlermeldung
 * @param  bool   interactive - ob der Fehler interaktiv behandelt werden kann
 *
 * @return int - der resultierende Fehlerstatus
 */
int ValidateConfig.HandleError(string location, string message, bool interactive) {
   if (IsTesting())
      interactive = false;
   if (!interactive)
      return(catch(location +"   "+ message, ERR_INVALID_CONFIG_PARAMVALUE));

   if (__LOG) log(StringConcatenate(location, "   ", message), ERR_INVALID_INPUT);
   ForceSound("chord.wav");
   int button = ForceMessageBox(__NAME__ +" - "+ location, message, MB_ICONERROR|MB_RETRYCANCEL);

   __STATUS_INVALID_INPUT = true;

   if (button == IDRETRY)
      __STATUS_RELAUNCH_INPUT = true;

   return(NO_ERROR);
}


/**
 * Speichert Instanzdaten im Chart, sodaß die Instanz nach einem Recompile oder Terminal-Restart daraus wiederhergestellt werden kann.
 *
 * @return int - Fehlerstatus
 */
int StoreStickyStatus() {
   if (!instance.id)
      return(NO_ERROR);                                                       // Rückkehr, falls die Instanz nicht initialisiert ist

   string label = StringConcatenate(__NAME__, ".sticky.Instance.ID");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate(ifString(IsTest(), "T", ""), instance.id), 1);

   label = StringConcatenate(__NAME__, ".sticky.__STATUS_INVALID_INPUT");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", __STATUS_INVALID_INPUT), 1);

   label = StringConcatenate(__NAME__, ".sticky.CANCELLED_BY_USER");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", last_error==ERR_CANCELLED_BY_USER), 1);

   return(catch("StoreStickyStatus()"));
}


/**
 * Restauriert im Chart gespeicherte Instanzdaten.
 *
 * @return bool - ob Daten einer Instanz gefunden wurden
 */
bool RestoreStickyStatus() {
   string label, strValue;
   bool   idFound;

   label = StringConcatenate(__NAME__, ".sticky.Instance.ID");
   if (ObjectFind(label) == 0) {
      strValue = StringToUpper(StringTrim(ObjectDescription(label)));
      if (StringLeft(strValue, 1) == "T") {
         strValue        = StringRight(strValue, -1);
         instance.isTest = true;
      }
      if (!StringIsDigit(strValue))
         return(_false(catch("RestoreStickyStatus(1)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      int iValue = StrToInteger(strValue);
      if (iValue <= 0)
         return(_false(catch("RestoreStickyStatus(2)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));

      instance.id = iValue; SS.InstanceId();
      idFound     = true;
      SetCustomLog(instance.id, NULL);

      label = StringConcatenate(__NAME__, ".sticky.__STATUS_INVALID_INPUT");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(3)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         __STATUS_INVALID_INPUT = StrToInteger(strValue) != 0;
      }

      label = StringConcatenate(__NAME__, ".sticky.CANCELLED_BY_USER");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(4)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         if (StrToInteger(strValue) != 0)
            SetLastError(ERR_CANCELLED_BY_USER);
      }
   }

   return(idFound && !(last_error|catch("RestoreStickyStatus(13)")));
}


/**
 * Löscht alle im Chart gespeicherten Instanzdaten.
 *
 * @return int - Fehlerstatus
 */
int ClearStickyStatus() {
   string label, prefix=StringConcatenate(__NAME__, ".sticky.");

   for (int i=ObjectsTotal()-1; i>=0; i--) {
      label = ObjectName(i);
      if (StringStartsWith(label, prefix)) /*&&*/ if (ObjectFind(label) == 0)
         ObjectDelete(label);
   }
   return(catch("ClearStickyStatus()"));
}


/**
 * Zeigt den aktuellen Status der Sequenz an.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus() {
   if (!IsChart)
      return(NO_ERROR);

   string str.error, l.msg, s.msg;

   if      (__STATUS_INVALID_INPUT) str.error = StringConcatenate("  [", ErrorDescription(ERR_INVALID_INPUT), "]");
   else if (__STATUS_ERROR        ) str.error = StringConcatenate("  [", ErrorDescription(last_error       ), "]");

   switch (sequence.status[D_LONG]) {
      case STATUS_UNINITIALIZED:
      case STATUS_WAITING:       l.msg =                                              " waiting";                                                                                  break;
      case STATUS_STARTING:      l.msg = StringConcatenate("  ", sequence.id[D_LONG], " starting at level ",     sequence.level[D_LONG],  "  (", sequence.maxLevel[D_LONG],  ")"); break;
      case STATUS_PROGRESSING:   l.msg = StringConcatenate("  ", sequence.id[D_LONG], " progressing at level ",  sequence.level[D_LONG],  "  (", sequence.maxLevel[D_LONG],  ")"); break;
      case STATUS_STOPPING:      l.msg = StringConcatenate("  ", sequence.id[D_LONG], " stopping at level ",     sequence.level[D_LONG],  "  (", sequence.maxLevel[D_LONG],  ")"); break;
      case STATUS_STOPPED:       l.msg = StringConcatenate("  ", sequence.id[D_LONG], " stopped at level ",      sequence.level[D_LONG],  "  (", sequence.maxLevel[D_LONG],  ")"); break;
      default:
         return(catch("ShowStatus(1)   illegal long sequence status = "+ sequence.status[D_LONG], ERR_RUNTIME_ERROR));
   }

   switch (sequence.status[D_SHORT]) {
      case STATUS_UNINITIALIZED:
      case STATUS_WAITING:       s.msg =                                               " waiting";                                                                                 break;
      case STATUS_STARTING:      s.msg = StringConcatenate("  ", sequence.id[D_SHORT], " starting at level ",    sequence.level[D_SHORT], "  (", sequence.maxLevel[D_SHORT], ")"); break;
      case STATUS_PROGRESSING:   s.msg = StringConcatenate("  ", sequence.id[D_SHORT], " progressing at level ", sequence.level[D_SHORT], "  (", sequence.maxLevel[D_SHORT], ")"); break;
      case STATUS_STOPPING:      s.msg = StringConcatenate("  ", sequence.id[D_SHORT], " stopping at level ",    sequence.level[D_SHORT], "  (", sequence.maxLevel[D_SHORT], ")"); break;
      case STATUS_STOPPED:       s.msg = StringConcatenate("  ", sequence.id[D_SHORT], " stopped at level ",     sequence.level[D_SHORT], "  (", sequence.maxLevel[D_SHORT], ")"); break;
      default:
         return(catch("ShowStatus(2)   illegal short sequence status = "+ sequence.status[D_SHORT], ERR_RUNTIME_ERROR));
   }

   string msg = StringConcatenate(__NAME__, str.error,                                                              NL,
                                                                                                                    NL,
                                  "Grid:           ", GridSize, " pip",                                             NL,
                                  "LotSize:       ",  str.instance.lotSize,                                         NL,
                                  "Start:          ", StartConditions,                                              NL,
                                  "Stop:          ",  StopConditions,                                               NL,
                                  "Profit/Loss:   ",  str.instance.totalPL, str.instance.plStats,                   NL,
                                                                                                                    NL,
                                  "LONG:       ",     l.msg,                                                        NL,
                                  "Stops:         ",  str.sequence.stops[D_LONG], str.sequence.stopsPL[D_LONG],     NL,
                                  "Profit/Loss:   ",  str.sequence.totalPL[D_LONG], str.sequence.plStats[D_LONG],   NL,
                                                                                                                    NL,
                                  "SHORT:     ",      s.msg,                                                        NL,
                                  "Stops:         ",  str.sequence.stops[D_SHORT], str.sequence.stopsPL[D_SHORT],   NL,
                                  "Profit/Loss:   ",  str.sequence.totalPL[D_SHORT], str.sequence.plStats[D_SHORT], NL);

   // 3 Zeilen Abstand nach oben für Instrumentanzeige und ggf. vorhandene Legende
   Comment(StringConcatenate(NL, NL, NL, msg));
   if (__WHEREAMI__ == FUNC_INIT)
      WindowRedraw();

   return(catch("ShowStatus(3)"));
}


/**
 * ShowStatus(): Aktualisiert die Anzeige der Instanz-ID in der Titelzeile des Strategy Testers.
 */
void SS.InstanceId() {
   if (IsTesting()) {
      if (!SetWindowTextA(GetTesterWindow(), StringConcatenate("Tester - SR-Dual.", instance.id)))
         catch("SS.InstanceId()->user32::SetWindowTextA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von LotSize.
 */
void SS.LotSize() {
   if (!IsChart)
      return;
   str.instance.lotSize = StringConcatenate(NumberToStr(LotSize, ".+"), " lot = ", DoubleToStr(GridSize * PipValue(LotSize), 2), "/stop");
}


/**
 * Ob die Instanz im Tester erzeugt wurde, also eine Test-Instanz ist. Der Aufruf dieser Funktion in Online-Charts mit einer im Tester
 * erzeugten Instanz gibt daher ebenfalls TRUE zurück.
 *
 * @return bool
 */
bool IsTest() {
   return(instance.isTest || IsTesting());
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   CheckTrendChange(NULL, NULL, NULL, NULL, NULL, NULL, iNull);
   ConfirmTick1Trade(NULL, NULL);
   CreateEventId();
   CreateSequenceId();
   FindChartSequences(sNulls, iNulls);
   IsSequenceStatus(NULL);
   StatusToStr(NULL);
}

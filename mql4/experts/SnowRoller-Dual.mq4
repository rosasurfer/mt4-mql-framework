/**
 * SnowRoller-Strategy: 2 unabhängige SnowRoller in je einer Richtung
 */
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE, INIT_PIPVALUE, INIT_CUSTOMLOG};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>

#include <core/expert.mqh>
#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern int    GridSize        = 20;
extern double LotSize         = 0.1;
extern string StartConditions = "";
extern string StopConditions  = "";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int      last.GridSize;                                                 // Input-Parameter sind nicht statisch. Extern geladene Parameter werden bei REASON_CHARTCHANGE
double   last.LotSize;                                                  // mit den Default-Werten überschrieben. Um dies zu verhindern und um geänderte Parameter mit
string   last.StartConditions = "";                                     // alten Werten vergleichen zu können, werden sie in deinit() in last.* zwischengespeichert und
string   last.StopConditions  = "";                                     // in init() daraus restauriert.

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
int      l.sequence.id,                 s.sequence.id;
bool     l.sequence.test,               s.sequence.test;                // ob die Sequenz eine Testsequenz ist (im Tester oder im Online-Chart)
int      l.sequence.status,             s.sequence.status;
string   l.sequence.status.file[2],     s.sequence.status.file[2];      // [0] => Verzeichnis (relativ zu ".\files\"), [1] => Dateiname
double   l.sequence.startEquity,        s.sequence.startEquity;         // Equity bei Start der Sequenz
bool     l.sequence.weStop.active,      s.sequence.weStop.active;       // Weekend-Stop aktiv (unterscheidet zwischen vorübergehend und dauerhaft gestoppten Sequenzen)
bool     l.sequence.weResume.triggered, s.sequence.weResume.triggered;  // ???

// ---------------------------------------------------------------
int      l.sequenceStart.event [],      s.sequenceStart.event [];       // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime l.sequenceStart.time  [],      s.sequenceStart.time  [];
double   l.sequenceStart.price [],      s.sequenceStart.price [];
double   l.sequenceStart.profit[],      s.sequenceStart.profit[];

int      l.sequenceStop.event  [],      s.sequenceStop.event  [];       // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime l.sequenceStop.time   [],      s.sequenceStop.time   [];
double   l.sequenceStop.price  [],      s.sequenceStop.price  [];
double   l.sequenceStop.profit [],      s.sequenceStop.profit [];

// ---------------------------------------------------------------
int      l.grid.level,                  s.grid.level;                   // aktueller Grid-Level
int      l.grid.maxLevel,               s.grid.maxLevel;                // maximal erreichter Grid-Level
double   l.grid.commission,             s.grid.commission;              // Commission-Betrag je Level

int      l.grid.base.event[],           s.grid.base.event[];            // Gridbasis-Daten
datetime l.grid.base.time [],           s.grid.base.time [];
double   l.grid.base.value[],           s.grid.base.value[];
double   l.grid.base,                   s.grid.base;                    // aktuelle Gridbasis

int      l.grid.stops,                  s.grid.stops;                   // Anzahl der bisher getriggerten Stops
double   l.grid.stopsPL,                s.grid.stopsPL;                 // kumulierter P/L aller bisher ausgestoppten Positionen
double   l.grid.closedPL,               s.grid.closedPL;                // kumulierter P/L aller bisher bei Sequencestop geschlossenen Positionen
double   l.grid.floatingPL,             s.grid.floatingPL;              // kumulierter P/L aller aktuell offenen Positionen
double   l.grid.totalPL,                s.grid.totalPL;                 // aktueller Gesamt-P/L der Sequenz: grid.stopsPL + grid.closedPL + grid.floatingPL
double   l.grid.openRisk,               s.grid.openRisk;                // vorraussichtlicher kumulierter P/L aller aktuell offenen Level bei deren Stopout: sum(orders.openRisk)
double   l.grid.valueAtRisk,            s.grid.valueAtRisk;             // vorraussichtlicher Gesamt-P/L der Sequenz bei Stop in Level 0: grid.stopsPL + grid.openRisk
double   l.grid.breakeven,              s.grid.breakeven;

double   l.grid.maxProfit,              s.grid.maxProfit;               // maximaler bisheriger Gesamt-Profit   (>= 0)
double   l.grid.maxDrawdown,            s.grid.maxDrawdown;             // maximaler bisheriger Gesamt-Drawdown (<= 0)

// ---------------------------------------------------------------
int      l.orders.ticket        [],     s.orders.ticket        [];
int      l.orders.level         [],     s.orders.level         [];      // Gridlevel der Order
double   l.orders.gridBase      [],     s.orders.gridBase      [];      // Gridbasis der Order

int      l.orders.pendingType   [],     s.orders.pendingType   [];      // Pending-Orderdaten (falls zutreffend)
datetime l.orders.pendingTime   [],     s.orders.pendingTime   [];      // Zeitpunkt von OrderOpen() bzw. letztem OrderModify()
double   l.orders.pendingPrice  [],     s.orders.pendingPrice  [];

int      l.orders.type          [],     s.orders.type          [];
int      l.orders.openEvent     [],     s.orders.openEvent     [];
datetime l.orders.openTime      [],     s.orders.openTime      [];
double   l.orders.openPrice     [],     s.orders.openPrice     [];
double   l.orders.openRisk      [],     s.orders.openRisk      [];      // vorraussichtlicher P/L des Levels seit letztem Stopout bei erneutem Stopout

int      l.orders.closeEvent    [],     s.orders.closeEvent    [];
datetime l.orders.closeTime     [],     s.orders.closeTime     [];
double   l.orders.closePrice    [],     s.orders.closePrice    [];
double   l.orders.stopLoss      [],     s.orders.stopLoss      [];
bool     l.orders.clientSL      [],     s.orders.clientSL      [];      // client- oder server-seitiger StopLoss
bool     l.orders.closedBySL    [],     s.orders.closedBySL    [];

double   l.orders.swap          [],     s.orders.swap          [];
double   l.orders.commission    [],     s.orders.commission    [];
double   l.orders.profit        [],     s.orders.profit        [];

// ---------------------------------------------------------------
int      l.ignorePendingOrders  [],     s.ignorePendingOrders  [];      // orphaned tickets to ignore
int      l.ignoreOpenPositions  [],     s.ignoreOpenPositions  [];
int      l.ignoreClosedPositions[],     s.ignoreClosedPositions[];


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
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy(int direction) {
   if (__STATUS_ERROR)
      return(false);

   bool changes;                                                     // Gridbase or Gridlevel changed
   int  status, stops[];                                             // getriggerte client-side Stops

   if      (direction == D_LONG ) status = l.sequence.status;
   else if (direction == D_SHORT) status = s.sequence.status;
   else return(!catch("Strategy()   illegal parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE));


   // (1) Sequenz wartet entweder auf Startsignal, ...
   if (status == STATUS_WAITING) {
      if (IsStartSignal(direction))   StartSequence();
   }

   // (2) ...auf ResumeSignal...
   else if (status == STATUS_STOPPED) {
      if  (IsResumeSignal(direction)) ResumeSequence(direction);
      else return(!IsLastError());
   }

   // (3) ...oder läuft
   else if (UpdateStatus(changes, stops)) {
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
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal(int direction) {
   if (__STATUS_ERROR)
      return(false);

   int iNull[];

   if (EventListener.BarOpen(iNull, start.trend.timeframeFlag)) {
      int    timeframe   = start.trend.timeframe;
      string maPeriods   = NumberToStr(start.trend.periods, ".+");
      string maTimeframe = PeriodDescription(start.trend.timeframe);
      string maMethod    = start.trend.method;
      int    lag         = start.trend.lag;
      int    signal      = 0;

      if (CheckTrendChange(timeframe, maPeriods, maTimeframe, maMethod, lag, direction, signal)) {
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
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
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
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStopSignal(int direction) {
   return(!catch("IsStopSignal()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Startet eine neue Trade-Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence() {
   return(!catch("StartSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Schließt alle PendingOrders und offenen Positionen der Sequenz.
 *
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus: ob die Sequenz erfolgreich gestoppt wurde
 */
bool StopSequence(int direction) {
   return(!catch("StopSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Setzt eine gestoppte Sequenz fort.
 *
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool ResumeSequence(int direction) {
   return(!catch("ResumeSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @param  bool lpChanges        - Variable, die nach Rückkehr anzeigt, ob sich die Gridbasis oder der Gridlevel der Sequenz geändert haben
 * @param  int  triggeredStops[] - Array, das nach Rückkehr die Array-Indizes getriggerter client-seitiger Stops enthält (Pending- und SL-Orders)
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus(bool &lpChanges, int triggeredStops[]) {
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
 * @param  int direction - Sequenz-Identifier: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePendingOrders(int direction) {
   return(!catch("UpdatePendingOrders()", ERR_FUNCTION_NOT_IMPLEMENTED));
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
}

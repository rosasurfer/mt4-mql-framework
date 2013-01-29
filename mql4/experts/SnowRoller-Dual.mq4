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

// -------------------------------------------------------------------
bool     start.trend.condition;
string   start.trend.condition.txt;
double   start.trend.periods;
int      start.trend.timeframe, start.trend.timeframeFlag;              // maximal PERIOD_H1
string   start.trend.method;
int      start.trend.lag;

// -------------------------------------------------------------------
bool     stop.profitAbs.condition;
string   stop.profitAbs.condition.txt;
double   stop.profitAbs.value;

// -------------------------------------------------------------------
datetime weekend.stop.condition   = D'1970.01.01 23:05';                // StopSequence()-Zeitpunkt vor Wochenend-Pause (Freitags abend)
datetime weekend.stop.time;

datetime weekend.resume.condition = D'1970.01.01 01:10';                // spätester ResumeSequence()-Zeitpunkt nach Wochenend-Pause (Montags morgen)
datetime weekend.resume.time;

// -------------------------------------------------------------------
int      L.sequence.id,                 S.sequence.id;
bool     L.sequence.test,               S.sequence.test;                // ob die Sequenz eine Testsequenz ist (im Tester oder im Online-Chart)
int      L.sequence.status,             S.sequence.status;
string   L.sequence.status.file[2],     S.sequence.status.file[2];      // [0] => Verzeichnis (relativ zu ".\files\"), [1] => Dateiname
double   L.sequence.startEquity,        S.sequence.startEquity;         // Equity bei Start der Sequenz
bool     L.sequence.weStop.active,      S.sequence.weStop.active;       // Weekend-Stop aktiv (unterscheidet zwischen vorübergehend und dauerhaft gestoppten Sequenzen)
bool     L.sequence.weResume.triggered, S.sequence.weResume.triggered;  // ???

// -------------------------------------------------------------------
int      L.sequenceStart.event [],      S.sequenceStart.event [];       // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime L.sequenceStart.time  [],      S.sequenceStart.time  [];
double   L.sequenceStart.price [],      S.sequenceStart.price [];
double   L.sequenceStart.profit[],      S.sequenceStart.profit[];

int      L.sequenceStop.event  [],      S.sequenceStop.event  [];       // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime L.sequenceStop.time   [],      S.sequenceStop.time   [];
double   L.sequenceStop.price  [],      S.sequenceStop.price  [];
double   L.sequenceStop.profit [],      S.sequenceStop.profit [];

// -------------------------------------------------------------------
int      L.grid.level,                  S.grid.level;                   // aktueller Grid-Level
int      L.grid.maxLevel,               S.grid.maxLevel;                // maximal erreichter Grid-Level
double   L.grid.commission,             S.grid.commission;              // Commission-Betrag je Level

int      L.grid.base.event[],           S.grid.base.event[];            // Gridbasis-Daten
datetime L.grid.base.time [],           S.grid.base.time [];
double   L.grid.base.value[],           S.grid.base.value[];
double   L.grid.base,                   S.grid.base;                    // aktuelle Gridbasis

int      L.grid.stops,                  S.grid.stops;                   // Anzahl der bisher getriggerten Stops
double   L.grid.stopsPL,                S.grid.stopsPL;                 // kumulierter P/L aller bisher ausgestoppten Positionen
double   L.grid.closedPL,               S.grid.closedPL;                // kumulierter P/L aller bisher bei Sequencestop geschlossenen Positionen
double   L.grid.floatingPL,             S.grid.floatingPL;              // kumulierter P/L aller aktuell offenen Positionen
double   L.grid.totalPL,                S.grid.totalPL;                 // aktueller Gesamt-P/L der Sequenz: grid.stopsPL + grid.closedPL + grid.floatingPL
double   L.grid.openRisk,               S.grid.openRisk;                // vorraussichtlicher kumulierter P/L aller aktuell offenen Level bei deren Stopout: sum(orders.openRisk)
double   L.grid.valueAtRisk,            S.grid.valueAtRisk;             // vorraussichtlicher Gesamt-P/L der Sequenz bei Stop in Level 0: grid.stopsPL + grid.openRisk
double   L.grid.breakeven,              S.grid.breakeven;

double   L.grid.maxProfit,              S.grid.maxProfit;               // maximaler bisheriger Gesamt-Profit   (>= 0)
double   L.grid.maxDrawdown,            S.grid.maxDrawdown;             // maximaler bisheriger Gesamt-Drawdown (<= 0)

// -------------------------------------------------------------------
int      L.orders.ticket        [],     S.orders.ticket        [];
int      L.orders.level         [],     S.orders.level         [];      // Gridlevel der Order
double   L.orders.gridBase      [],     S.orders.gridBase      [];      // Gridbasis der Order

int      L.orders.pendingType   [],     S.orders.pendingType   [];      // Pending-Orderdaten (falls zutreffend)
datetime L.orders.pendingTime   [],     S.orders.pendingTime   [];      // Zeitpunkt von OrderOpen() bzw. letztem OrderModify()
double   L.orders.pendingPrice  [],     S.orders.pendingPrice  [];

int      L.orders.type          [],     S.orders.type          [];
int      L.orders.openEvent     [],     S.orders.openEvent     [];
datetime L.orders.openTime      [],     S.orders.openTime      [];
double   L.orders.openPrice     [],     S.orders.openPrice     [];
double   L.orders.openRisk      [],     S.orders.openRisk      [];      // vorraussichtlicher P/L des Levels seit letztem Stopout bei erneutem Stopout

int      L.orders.closeEvent    [],     S.orders.closeEvent    [];
datetime L.orders.closeTime     [],     S.orders.closeTime     [];
double   L.orders.closePrice    [],     S.orders.closePrice    [];
double   L.orders.stopLoss      [],     S.orders.stopLoss      [];
bool     L.orders.clientSL      [],     S.orders.clientSL      [];      // client- oder server-seitiger StopLoss
bool     L.orders.closedBySL    [],     S.orders.closedBySL    [];

double   L.orders.swap          [],     S.orders.swap          [];
double   L.orders.commission    [],     S.orders.commission    [];
double   L.orders.profit        [],     S.orders.profit        [];

// -------------------------------------------------------------------
int      L.ignorePendingOrders  [],     S.ignorePendingOrders  [];      // orphaned tickets to ignore
int      L.ignoreOpenPositions  [],     S.ignoreOpenPositions  [];
int      L.ignoreClosedPositions[],     S.ignoreClosedPositions[];


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   Strategy.Long();
   Strategy.Short();
   return(last_error);
}


/**
 * Long
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy.Long() {
   if (__STATUS_ERROR)
      return(false);
   return(true);
}


/**
 * Short
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy.Short() {
   if (__STATUS_ERROR)
      return(false);
   return(true);
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

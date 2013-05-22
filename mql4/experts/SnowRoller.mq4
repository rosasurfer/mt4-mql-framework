/**
 *  SnowRoller - Pyramiding Trade Manager
 *  -------------------------------------
 *
 *
 *  TODO:
 *  -----
 *  - Multi-Sequenz-Management implementieren                                                   *
 *  - Equity-Charts: Schreiben aus Online-Chart                                                 *
 *  - Laufzeitumgebung auf Server einrichten                                                    *
 *
 *  - Sequenz-IDs auf Eindeutigkeit prüfen
 *  - im Tester fortlaufende Sequenz-IDs generieren
 *  - Abbruch wegen geändertem Ticketstatus abfangen
 *  - Abbruch wegen IsStopped()=TRUE abfangen
 *  - Statusanzeige: Risikokennziffer zum Verlustpotential des Levels integrieren
 *  - PendingOrders nicht per Tick trailen
 *  - Möglichkeit, Wochenend-Stop zu (de-)aktivieren
 *  - Wochenend-Stop auf Feiertage ausweiten (Feiertagskalender)
 *
 *  - Validierung refaktorieren
 *  - Statusanzeige dynamisch an Zeilen anpassen
 *  - StopsPL reparieren
 *  - Bug: ChartMarker bei Stopouts
 *  - Bug: Crash, wenn Statusdatei der geladenen Testsequenz gelöscht wird
 *  - Logging aller MessageBoxen
 *
 *  - Build 419 silently crashes (1 mal)
 *  - Alpari: wiederholte Trade-Timeouts von exakt 200 sec. (Socket-Timeout ?)
 *  - Alpari: StopOrder-Slippage EUR/USD bis 4.1 pip, GBP/AUD bis 6 pip, GBP/JPY bis 21.4 pip
 *  - FxPro: zu viele Traderequests in zu kurzer Zeit => ERR_TRADE_TIMEOUT
 *
 *
 *  Übersicht der Aktionen und Statuswechsel:
 *  +-------------------+----------------------+---------------------+------------+---------------+--------------------+
 *  | Aktion            |        Status        |       Events        | Positionen |  BE-Berechn.  |     Erkennung      |
 *  +-------------------+----------------------+---------------------+------------+---------------+--------------------+
 *  | EA.init()         | STATUS_UNINITIALIZED |                     |            |               |                    |
 *  |                   |                      |                     |            |               |                    |
 *  | EA.start()        | STATUS_WAITING       |                     |            |               |                    |
 *  +-------------------+----------------------+---------------------+------------+---------------+--------------------+
 *  | StartSequence()   | STATUS_PROGRESSING   | EV_SEQUENCE_START   |     0      |       -       |                    | sequence.start.time = Wechsel zu STATUS_PROGRESSING
 *  |                   |                      |                     |            |               |                    |
 *  | Gridbase-Änderung | STATUS_PROGRESSING   | EV_GRIDBASE_CHANGE  |     0      |       -       |                    |
 *  |                   |                      |                     |            |               |                    |
 *  | OrderFilled       | STATUS_PROGRESSING   | EV_POSITION_OPEN    |    1..n    |  ja (Beginn)  |   maxLevel != 0    |
 *  |                   |                      |                     |            |               |                    |
 *  | OrderStoppedOut   | STATUS_PROGRESSING   | EV_POSITION_STOPOUT |    n..0    |      ja       |                    |
 *  |                   |                      |                     |            |               |                    |
 *  | Gridbase-Änderung | STATUS_PROGRESSING   | EV_GRIDBASE_CHANGE  |     0      |      ja       |                    |
 *  |                   |                      |                     |            |               |                    |
 *  | StopSequence()    | STATUS_STOPPING      |                     |     n      | nein (Redraw) | STATUS_STOPPING    |
 *  | PositionClose     | STATUS_STOPPING      | EV_POSITION_CLOSE   |    n..0    |       Redraw  | PositionClose      |
 *  |                   | STATUS_STOPPED       | EV_SEQUENCE_STOP    |     0      |  Ende Redraw  | STATUS_STOPPED     | sequence.stop.time = Wechsel zu STATUS_STOPPED
 *  +-------------------+----------------------+---------------------+------------+---------------+--------------------+
 *  | ResumeSequence()  | STATUS_STARTING      |                     |     0      |       -       |                    | Gridbasis ungültig
 *  | Gridbase-Änderung | STATUS_STARTING      | EV_GRIDBASE_CHANGE  |     0      |       -       |                    |
 *  | PositionOpen      | STATUS_STARTING      | EV_POSITION_OPEN    |    0..n    |               |                    |
 *  |                   | STATUS_PROGRESSING   | EV_SEQUENCE_START   |     n      |  ja (Beginn)  | STATUS_PROGRESSING | sequence.start.time = Wechsel zu STATUS_PROGRESSING
 *  |                   |                      |                     |            |               |                    |
 *  | OrderFilled       | STATUS_PROGRESSING   | EV_POSITION_OPEN    |    1..n    |      ja       |                    |
 *  |                   |                      |                     |            |               |                    |
 *  | OrderStoppedOut   | STATUS_PROGRESSING   | EV_POSITION_STOPOUT |    n..0    |      ja       |                    |
 *  |                   |                      |                     |            |               |                    |
 *  | Gridbase-Änderung | STATUS_PROGRESSING   | EV_GRIDBASE_CHANGE  |     0      |      ja       |                    |
 *  | ...               |                      |                     |            |               |                    |
 *  +-------------------+----------------------+---------------------+------------+---------------+--------------------+
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

extern /*sticky*/ string Sequence.ID             = "";
extern            string GridDirection           = "Long | Short";
extern            int    GridSize                = 20;
extern            double LotSize                 = 0.1;
extern            string StartConditions         = "";               // @trend(ALMA:7xD1) || @[bid|ask|price](double) && @time(datetime) && @level(int)
extern            string StopConditions          = "";               // @trend(ALMA:7xD1) || @[bid|ask|price](double) || @time(datetime) || @level(int) || @profit(double[%])
extern /*sticky*/ color  StartStop.Color         = Blue;
extern /*sticky*/ string Sequence.StatusLocation = "";               // Unterverzeichnis

       /*sticky*/ int    startStopDisplayMode    = SDM_PRICE;        // Sticky-Variablen werden im Chart zwischengespeichert, sie überleben dort
       /*sticky*/ int    orderDisplayMode        = ODM_NONE;         // Terminal-Restart, Profilwechsel und Recompilation.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string   last.Sequence.ID             = "";                          // Input-Parameter sind nicht statisch. Extern geladene Parameter werden bei REASON_CHARTCHANGE
string   last.Sequence.StatusLocation = "";                          // mit den Default-Werten überschrieben. Um dies zu verhindern und um geänderte Parameter mit
string   last.GridDirection           = "";                          // alten Werten vergleichen zu können, werden sie in deinit() in last.* zwischengespeichert und
int      last.GridSize;                                              // in init() daraus restauriert.
double   last.LotSize;
string   last.StartConditions         = "";
string   last.StopConditions          = "";
color    last.StartStop.Color;

// ------------------------------------
int      sequenceId;
bool     isTest;                                                     // ob die Sequenz eine Testsequenz ist (im Tester oder im Online-Chart)
int      status;
string   status.directory;                                           // Verzeichnisname der Statusdatei relativ zu ".\files\"
string   status.file;                                                // Dateiname der Statusdatei

// ------------------------------------
bool     start.conditions;                                           // ob die StartConditions aktiv sind

bool     start.trend.condition;
string   start.trend.condition.txt;
double   start.trend.periods;
int      start.trend.timeframe, start.trend.timeframeFlag;           // maximal PERIOD_H1
string   start.trend.method;
int      start.trend.lag;

bool     start.price.condition;
string   start.price.condition.txt;
int      start.price.type;                                           // SCP_BID | SCP_ASK | SCP_MEDIAN
double   start.price.value;

bool     start.time.condition;
string   start.time.condition.txt;
datetime start.time.value;

bool     start.level.condition;
string   start.level.condition.txt;
int      start.level.value;

// ------------------------------------
bool     stop.conditions;                                            // ob die StopConditions aktiv sind

bool     stop.trend.condition;
string   stop.trend.condition.txt;
double   stop.trend.periods;
int      stop.trend.timeframe, stop.trend.timeframeFlag;             // maximal PERIOD_H1
string   stop.trend.method;
int      stop.trend.lag;

bool     stop.price.condition;
string   stop.price.condition.txt;
int      stop.price.type;                                            // SCP_BID | SCP_ASK | SCP_MEDIAN
double   stop.price.value;

bool     stop.level.condition;
string   stop.level.condition.txt;
int      stop.level.value;

bool     stop.time.condition;
string   stop.time.condition.txt;
datetime stop.time.value;

bool     stop.profitAbs.condition;
string   stop.profitAbs.condition.txt;
double   stop.profitAbs.value;

bool     stop.profitPct.condition;
string   stop.profitPct.condition.txt;
double   stop.profitPct.value;

// ------------------------------------
datetime weekend.stop.condition   = D'1970.01.01 23:05';             // StopSequence()-Zeitpunkt vor Wochenend-Pause (Freitags abend)
datetime weekend.stop.time;
bool     weekend.stop.active;                                        // Sequenz-Eigenschaft (unterscheidet zwischen vorübergehend und dauerhaft gestoppter Sequenz)

datetime weekend.resume.condition = D'1970.01.01 01:10';             // spätester ResumeSequence()-Zeitpunkt nach Wochenend-Pause (Montags morgen)
datetime weekend.resume.time;
bool     weekend.resume.triggered;                                   // ???

// ------------------------------------
int      sequence.direction;
int      sequence.level;                                             // aktueller Grid-Level
int      sequence.maxLevel;                                          // maximal erreichter Grid-Level
double   sequence.startEquity;
int      sequence.stops;                                             // Anzahl der bisher getriggerten Stops
double   sequence.stopsPL;                                           // kumulierter P/L aller bisher ausgestoppten Positionen
double   sequence.closedPL;                                          // kumulierter P/L aller bisher bei Sequenzstop geschlossenen Positionen
double   sequence.floatingPL;                                        // kumulierter P/L aller aktuell offenen Positionen
double   sequence.totalPL;                                           // aktueller Gesamt-P/L der Sequenz: stopsPL + closedPL + floatingPL
double   sequence.maxProfit;                                         // maximaler bisheriger Gesamt-Profit   (>= 0)
double   sequence.maxDrawdown;                                       // maximaler bisheriger Gesamt-Drawdown (<= 0)
double   sequence.commission;                                        // Commission-Betrag je Level

// ------------------------------------
int      sequence.start.event [];                                    // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime sequence.start.time  [];
double   sequence.start.price [];
double   sequence.start.profit[];

int      sequence.stop.event [];                                     // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime sequence.stop.time  [];
double   sequence.stop.price [];
double   sequence.stop.profit[];

// ------------------------------------
int      grid.base.event[];                                          // Gridbasis-Daten
datetime grid.base.time [];
double   grid.base.value[];
double   grid.base;                                                  // aktuelle Gridbasis

// ------------------------------------
int      orders.ticket        [];
int      orders.level         [];                                    // Gridlevel der Order
double   orders.gridBase      [];                                    // Gridbasis der Order

int      orders.pendingType   [];                                    // Pending-Orderdaten (falls zutreffend)
datetime orders.pendingTime   [];                                    // Zeitpunkt von OrderOpen() bzw. letztem OrderModify()
double   orders.pendingPrice  [];

int      orders.type          [];
int      orders.openEvent     [];
datetime orders.openTime      [];
double   orders.openPrice     [];
int      orders.closeEvent    [];
datetime orders.closeTime     [];
double   orders.closePrice    [];
double   orders.stopLoss      [];
bool     orders.clientSL      [];                                    // client- oder server-seitiger StopLoss
bool     orders.closedBySL    [];

double   orders.swap          [];
double   orders.commission    [];
double   orders.profit        [];

// ------------------------------------
int      ignorePendingOrders  [];                                    // orphaned tickets to ignore
int      ignoreOpenPositions  [];
int      ignoreClosedPositions[];

// ------------------------------------
string   str.LotSize              = "";                              // Zwischenspeicher zur schnelleren Abarbeitung von ShowStatus()
string   str.startConditions      = "";
string   str.stopConditions       = "";
string   str.sequence.direction   = "";
string   str.grid.base            = "";
string   str.sequence.stops       = "";
string   str.sequence.stopsPL     = "";
string   str.sequence.totalPL     = "";
string   str.sequence.maxProfit   = "";
string   str.sequence.maxDrawdown = "";
string   str.sequence.plStats     = "";


#include <SnowRoller/init.mqh>
#include <SnowRoller/deinit.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (status == STATUS_UNINITIALIZED)
      return(NO_ERROR);

   // (1) Commands verarbeiten
   HandleEvent(EVENT_CHART_CMD);


   bool changes;                                                     // Gridbase or Gridlevel changed
   int  stops[];                                                     // getriggerte client-seitige Stops


   // (2) Sequenz wartet entweder auf Startsignal...
   if (status == STATUS_WAITING) {
      if (IsStartSignal())         StartSequence();
   }

   // (3) ...oder auf ResumeSignal...
   else if (status == STATUS_STOPPED) {
      if  (IsResumeSignal())       ResumeSequence();
      else return(last_error);
   }

   // (4) ...oder läuft
   else if (UpdateStatus(changes, stops)) {
      if (IsStopSignal())          StopSequence();
      else {
         if (ArraySize(stops) > 0) ProcessClientStops(stops);
         if (changes)              UpdatePendingOrders();
      }
   }

   // (5) Equity-Kurve aufzeichnen (erst nach allen Orderfunktionen, ab dem ersten ausgeführten Trade)
   if (status==STATUS_PROGRESSING) /*&&*/ if (sequence.maxLevel != 0) {
      RecordEquity(HST_CACHE_TICKS);
   }

   return(last_error);
}


/**
 * Handler für ChartCommand-Events.
 *
 * @param  string commands[] - die übermittelten Kommandos
 *
 * @return int - Fehlerstatus
 */
int onChartCommand(string commands[]) {
   if (ArraySize(commands) == 0)
      return(catch("onChartCommand(1)   illegal parameter commands = "+ StringsToStr(commands, NULL), ERR_INVALID_FUNCTION_PARAMVALUE));

   string cmd = commands[0];

   if (cmd == "start") {
      switch (status) {
         case STATUS_WAITING: StartSequence();  break;
         case STATUS_STOPPED: ResumeSequence(); break;
      }
      return(last_error);
   }

   else if (cmd == "stop") {
      switch (status) {
         case STATUS_WAITING    :
         case STATUS_PROGRESSING:
            bool bNull;
            int  iNull[];
            if (UpdateStatus(bNull, iNull))
               StopSequence();
      }
      return(last_error);
   }

   else if (cmd == "startstopdisplay") return(ToggleStartStopDisplayMode());
   else if (cmd ==     "orderdisplay") return(    ToggleOrderDisplayMode());

   // unbekannte Commands anzeigen, aber keinen Fehler setzen (EA soll weiterlaufen)
   warn(StringConcatenate("onChartCommand(2)   unknown command \"", cmd, "\""));
   return(NO_ERROR);
}


/**
 * Startet eine neue Trade-Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence() {
   if (__STATUS_ERROR)           return( false);
   if (status != STATUS_WAITING) return(_false(catch("StartSequence(1)   cannot start "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("StartSequence()", "Do you really want to start a new sequence now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   status = STATUS_STARTING;
   if (__LOG) log("StartSequence()   starting sequence");


   // (1) Startvariablen setzen
   datetime startTime  = TimeCurrent();
   double   startPrice = ifDouble(sequence.direction==D_SHORT, Bid, Ask);

   ArrayPushInt   (sequence.start.event,  CreateEventId());
   ArrayPushInt   (sequence.start.time,   startTime      );
   ArrayPushDouble(sequence.start.price,  startPrice     );
   ArrayPushDouble(sequence.start.profit, 0              );

   ArrayPushInt   (sequence.stop.event,   0              );          // Größe von sequence.starts/stops synchron halten
   ArrayPushInt   (sequence.stop.time,    0              );
   ArrayPushDouble(sequence.stop.price,   0              );
   ArrayPushDouble(sequence.stop.profit,  0              );

   sequence.startEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);


   // (2) Gridbasis setzen (zeitlich nach sequence.start.time)
   double gridBase = startPrice;
   if (start.conditions) /*&&*/ if (start.level.condition) {
      sequence.level    = start.level.value;
      sequence.maxLevel = start.level.value;
      gridBase          = NormalizeDouble(startPrice - sequence.level*GridSize*Pips, Digits);
   }
   GridBase.Reset(startTime, gridBase);


   // (3) ggf. Startpositionen in den Markt legen und SequenceStart-Price aktualisieren
   if (sequence.level != 0) {
      int iNull;
      if (!UpdateOpenPositions(iNull, startPrice))
         return(false);
      sequence.start.price[ArraySize(sequence.start.price)-1] = startPrice;
   }

   status = STATUS_PROGRESSING;


   // (4) Stop-Orders in den Markt legen
   if (!UpdatePendingOrders())
      return(false);


   // (5) StartConditions deaktivieren, Weekend-Stop aktualisieren
   start.conditions = false; SS.StartStopConditions();
   UpdateWeekendStop();
   RedrawStartStop();


   if (__LOG) log("StartSequence()   sequence started at "+ NumberToStr(startPrice, PriceFormat) + ifString(sequence.level, " and level "+ sequence.level, ""));
   return(!last_error|catch("StartSequence(2)"));
}


/**
 * Schließt alle PendingOrders und offenen Positionen der Sequenz.
 *
 * @return bool - Erfolgsstatus: ob die Sequenz erfolgreich gestoppt wurde
 */
bool StopSequence() {
   if (__STATUS_ERROR)                    return( false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(_false(catch("StopSequence(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_WAITING) /*&&*/ if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STOPPING)
      if (!IsTesting() || __WHEREAMI__!=FUNC_DEINIT || status!=STATUS_STOPPED)         // ggf. wird nach Testende nur aufgeräumt
         return(_false(catch("StopSequence(2)   cannot stop "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("StopSequence()", "Do you really want to stop the sequence now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));


   // (1) eine wartende Sequenz ist noch nicht gestartet und wird gecanceled
   if (status == STATUS_WAITING) {
      if (IsTesting())
         Tester.Pause();
      SetLastError(ERR_CANCELLED_BY_USER);
      return(_false(catch("StopSequence(3)")));
   }


   if (status != STATUS_STOPPED) {
      status = STATUS_STOPPING;
      if (__LOG) log(StringConcatenate("StopSequence()   stopping sequence at level ", sequence.level));
   }


   // (2) PendingOrders und OpenPositions einlesen
   int pendings[], positions[], sizeOfTickets=ArraySize(orders.ticket);
   ArrayResize(pendings,  0);
   ArrayResize(positions, 0);

   for (int i=sizeOfTickets-1; i >= 0; i--) {
      if (orders.closeTime[i] == 0) {                                                                 // Ticket prüfen, wenn es beim letzten Aufruf noch offen war
         if (orders.ticket[i] < 0) {
            if (!Grid.DropData(i))                                                                    // client-seitige Pending-Orders können intern gelöscht werden
               return(false);
            sizeOfTickets--;
            continue;
         }
         if (!SelectTicket(orders.ticket[i], "StopSequence(4)"))
            return(false);
         if (!OrderCloseTime()) {                                                                     // offene Tickets je nach Typ zwischenspeichern
            if (IsPendingTradeOperation(OrderType())) ArrayPushInt(pendings,                i);       // Grid.DeleteOrder() erwartet den Array-Index
            else                                      ArrayPushInt(positions, orders.ticket[i]);      // OrderMultiClose() erwartet das Orderticket
         }
      }
   }


   // (3) zuerst Pending-Orders streichen (ansonsten könnten sie während OrderClose() noch getriggert werden)
   int sizeOfPendings = ArraySize(pendings);

   for (i=0; i < sizeOfPendings; i++) {
      if (!Grid.DeleteOrder(pendings[i]))
         return(false);
   }


   // (4) dann offene Positionen schließen                           // TODO: Wurde eine PendingOrder inzwischen getriggert, muß sie hier mit verarbeitet werden.
   int      sizeOfPositions=ArraySize(positions), n=ArraySize(sequence.stop.event)-1;
   datetime closeTime;
   double   closePrice;

   if (sizeOfPositions > 0) {
      int oeFlags = NULL;
      /*ORDER_EXECUTION*/int oes[][ORDER_EXECUTION.intSize]; ArrayResize(oes, sizeOfPositions); InitializeByteBuffer(oes, ORDER_EXECUTION.size);

      if (!OrderMultiClose(positions, NULL, CLR_CLOSE, oeFlags, oes))
         return(_false(SetLastError(stdlib_GetLastError())));

      for (i=0; i < sizeOfPositions; i++) {
         int pos = SearchIntArray(orders.ticket, positions[i]);

         orders.closeEvent[pos] = CreateEventId();
         orders.closeTime [pos] = oes.CloseTime (oes, i);
         orders.closePrice[pos] = oes.ClosePrice(oes, i);
         orders.closedBySL[pos] = false;
         orders.swap      [pos] = oes.Swap      (oes, i);
         orders.commission[pos] = oes.Commission(oes, i);
         orders.profit    [pos] = oes.Profit    (oes, i);

         sequence.closedPL = NormalizeDouble(sequence.closedPL + orders.swap[pos] + orders.commission[pos] + orders.profit[pos], 2);

         closeTime   = Max(closeTime, orders.closeTime[pos]);        // u.U. können die Close-Werte unterschiedlich sein und müssen gemittelt werden
         closePrice += orders.closePrice[pos];                       // (i.d.R. sind sie überall gleich)
      }
      closePrice /= Abs(sequence.level);                             // avg(ClosePrice) TODO: falsch, wenn bereits ein Teil der Positionen geschlossen war
      /*
      sequence.floatingPL  = ...                                     // Solange unten UpdateStatus() aufgerufen wird, werden diese Werte dort automatisch aktualisiert.
      sequence.totalPL     = ...
      sequence.maxProfit   = ...
      sequence.maxDrawdown = ...
      */
      sequence.stop.event[n] = CreateEventId();
      sequence.stop.time [n] = closeTime;
      sequence.stop.price[n] = NormalizeDouble(closePrice, Digits);
   }

   // (4.1) keine offenen Positionen
   else if (status != STATUS_STOPPED) {
      sequence.stop.event[n] = CreateEventId();
      sequence.stop.time [n] = TimeCurrent();
      sequence.stop.price[n] = ifDouble(sequence.direction==D_LONG, Bid, Ask);
   }


   // (5) StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
   if (!StopSequence.LimitStopPrice())
      return(false);


   if (status != STATUS_STOPPED) {
      status = STATUS_STOPPED;
      if (__LOG) log(StringConcatenate("StopSequence()   sequence stopped at ", NumberToStr(sequence.stop.price[n], PriceFormat), ", level ", sequence.level));
   }


   // (6) ResumeConditions/StopConditions aktualisieren bzw. deaktivieren
   if (IsWeekendStopSignal()) {
      UpdateWeekendResumeTime();
   }
   else {
      stop.conditions = false; SS.StartStopConditions();
   }


   // (7) Daten aktualisieren und speichern
   bool bNull;
   int  iNull[];
   if (!UpdateStatus(bNull, iNull)) return(false);
   sequence.stop.profit[n] = sequence.totalPL;
   if (  !SaveStatus())             return(false);
   if (!RecordEquity(NULL))         return(false);
   RedrawStartStop();


   // (8) ggf. Tester stoppen
   if (IsTesting()) {
      if      (        IsVisualMode()) Tester.Pause();
      else if (!IsWeekendStopSignal()) Tester.Stop();
   }
   return(!last_error|catch("StopSequence(5)"));
}


/**
 * Der StopPrice darf nicht schon den nächsten Level triggern, da sonst bei ResumeSequence() Fehler auftreten.
 *
 * @return bool - Erfolgsstatus
 */
bool StopSequence.LimitStopPrice() {
   if (__STATUS_ERROR)                                             return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                          return(_false(catch("StopSequence.LimitStopPrice(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_STOPPING) /*&&*/ if (status!=STATUS_STOPPED) return(_false(catch("StopSequence.LimitStopPrice(2)   cannot limit stop price of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   double nextTrigger;
   int i = ArraySize(sequence.stop.price) - 1;

   if (sequence.direction == D_LONG) {
      nextTrigger = grid.base + (sequence.level+1)*GridSize*Pip;
      sequence.stop.price[i] = MathMin(nextTrigger-1*Pip, sequence.stop.price[i]);  // max. 1 Pip unterm Trigger des nächsten Levels
   }

   if (sequence.direction == D_SHORT) {
      nextTrigger = grid.base + (sequence.level-1)*GridSize*Pip;
      sequence.stop.price[i] = MathMax(nextTrigger+1*Pip, sequence.stop.price[i]);  // min. 1 Pip überm Trigger des nächsten Levels
   }
   sequence.stop.price[i] = NormalizeDouble(sequence.stop.price[i], Digits);

   return(!last_error|catch("StopSequence.LimitStopPrice(3)"));
}


/**
 * Setzt eine gestoppte Sequenz fort.
 *
 * @return bool - Erfolgsstatus
 */
bool ResumeSequence() {
   if (__STATUS_ERROR)                                             return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                          return(_false(catch("ResumeSequence(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_STOPPED) /*&&*/ if (status!=STATUS_STARTING) return(_false(catch("ResumeSequence(2)   cannot resume "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("ResumeSequence()", "Do you really want to resume the sequence now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));


   status = STATUS_STARTING;
   if (__LOG) log(StringConcatenate("ResumeSequence()   resuming sequence at level ", sequence.level));

   datetime startTime;
   double   startPrice, lastStopPrice, gridBase;


   // (1) Wird ResumeSequence() nach einem Fehler erneut aufgerufen, kann es sein, daß einige Level bereits offen sind und andere noch fehlen.
   if (sequence.level > 0) {
      for (int level=1; level <= sequence.level; level++) {
         int i = Grid.FindOpenPosition(level);
         if (i != -1) {
            gridBase = orders.gridBase[i];
            break;
         }
      }
   }
   else if (sequence.level < 0) {
      for (level=-1; level >= sequence.level; level--) {
         i = Grid.FindOpenPosition(level);
         if (i != -1) {
            gridBase = orders.gridBase[i];
            break;
         }
      }
   }


   // (2) Gridbasis neu setzen, wenn in (1) keine offenen Positionen gefunden wurden.
   if (EQ(gridBase, 0)) {
      startTime     = TimeCurrent();
      startPrice    = ifDouble(sequence.direction==D_SHORT, Bid, Ask);
      lastStopPrice = sequence.stop.price[ArraySize(sequence.stop.price)-1];
      GridBase.Change(startTime, grid.base + startPrice - lastStopPrice);
   }
   else {
      grid.base = NormalizeDouble(gridBase, Digits);                 // Gridbasis der vorhandenen Positionen übernehmen (sollte schon gesetzt sein, doch wer weiß...)
   }


   // (3) vorherige Positionen wieder in den Markt legen und letzte last(OrderOpenTime)/avg(OrderOpenPrice) abfragen
   if (!UpdateOpenPositions(startTime, startPrice))
      return(false);


   // (4) neuen Sequenzstart speichern
   ArrayPushInt   (sequence.start.event,  CreateEventId() );
   ArrayPushInt   (sequence.start.time,   startTime       );
   ArrayPushDouble(sequence.start.price,  startPrice      );
   ArrayPushDouble(sequence.start.profit, sequence.totalPL);         // entspricht dem letzten Stop-Wert
      int sizeOfStops = ArraySize(sequence.stop.profit);
      if (EQ(sequence.stop.profit[sizeOfStops-1], 0))                // Sequenz-Stops ohne PL aktualisieren (alte SnowRoller-Version)
         sequence.stop.profit[sizeOfStops-1] = sequence.totalPL;

   ArrayPushInt   (sequence.stop.event,  0);                         // sequence.starts/stops synchron halten
   ArrayPushInt   (sequence.stop.time,   0);
   ArrayPushDouble(sequence.stop.price,  0);
   ArrayPushDouble(sequence.stop.profit, 0);


   status = STATUS_PROGRESSING;


   // (5) StartConditions deaktivieren und Weekend-Stop aktualisieren
   start.conditions         = false; SS.StartStopConditions();
   weekend.resume.triggered = false;
   weekend.resume.time      = 0;
   UpdateWeekendStop();


   // (6) Stop-Orders vervollständigen
   if (!UpdatePendingOrders())
      return(false);


   // (7) Status aktualisieren und speichern
   bool blChanged;
   int  iNull[];
   if (!UpdateStatus(blChanged, iNull))                              // Wurde in UpdateOpenPositions() ein Pseudo-Ticket erstellt, wird es hier
      return(false);                                                 // in UpdateStatus() geschlossen. In diesem Fall müssen die Pending-Orders
   if (blChanged)                                                    // nochmal aktualisiert werden.
      UpdatePendingOrders();
   if (!SaveStatus())
      return(false);


   // (8) Anzeige aktualisieren
   RedrawStartStop();

   if (__LOG) log(StringConcatenate("ResumeSequence()   sequence resumed at ", NumberToStr(startPrice, PriceFormat), ", level ", sequence.level));
   return(!last_error|catch("ResumeSequence(3)"));
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @param  bool lpChange - Zeiger auf Variable, die nach Rückkehr anzeigt, ob sich Gridbasis oder Gridlevel der Sequenz geändert haben.
 * @param  int  stops[]  - Array, das nach Rückkehr die Order-Indizes getriggerter client-seitiger Stops enthält (Pending- und SL-Orders).
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus(bool &lpChange, int stops[]) {
   ArrayResize(stops, 0);
   if (__STATUS_ERROR)           return(false);
   if (status == STATUS_WAITING) return(true);

   sequence.floatingPL = 0;

   bool wasPending, isClosed, openPositions, updateStatusLocation;
   int  closed[][2], close[2], sizeOfTickets=ArraySize(orders.ticket); ArrayResize(closed, 0);


   // (1) Tickets aktualisieren
   for (int i=0; i < sizeOfTickets; i++) {
      if (orders.closeTime[i] == 0) {                                            // Ticket prüfen, wenn es beim letzten Aufruf offen war
         wasPending = (orders.type[i] == OP_UNDEFINED);

         // (1.1) client-seitige PendingOrders prüfen
         if (wasPending) /*&&*/ if (orders.ticket[i] == -1) {
            if (IsStopTriggered(orders.pendingType[i], orders.pendingPrice[i])) {
               if (__LOG) log(UpdateStatus.StopTriggerMsg(i));
               ArrayPushInt(stops, i);
            }
            continue;
         }

         // (1.2) Pseudo-SL-Tickets prüfen (werden sofort hier "geschlossen")
         if (orders.ticket[i] == -2) {
            orders.closeEvent[i] = CreateEventId();                              // Event-ID kann sofort vergeben werden.
            orders.closeTime [i] = TimeCurrent();
            orders.closePrice[i] = orders.openPrice[i];
            orders.closedBySL[i] = true;
            ChartMarker.PositionClosed(i);
            if (__LOG) log(UpdateStatus.SLExecuteMsg(i));

            sequence.level  -= Sign(orders.level[i]);
            sequence.stops++; SS.Stops();
          //sequence.stopsPL = ...                                               // unverändert, da P/L des Pseudo-Tickets immer 0.00
            lpChange         = true;
            continue;
         }

         // (1.3) reguläre server-seitige Tickets
         if (!SelectTicket(orders.ticket[i], "UpdateStatus(2)"))
            return(false);

         if (wasPending) {
            // beim letzten Aufruf Pending-Order
            if (OrderType() != orders.pendingType[i]) {                          // Order wurde ausgeführt
               orders.type      [i] = OrderType();
               orders.openEvent [i] = CreateEventId();
               orders.openTime  [i] = OrderOpenTime();
               orders.openPrice [i] = OrderOpenPrice();
               orders.swap      [i] = OrderSwap();
               orders.commission[i] = OrderCommission(); sequence.commission = OrderCommission(); SS.LotSize();
               orders.profit    [i] = OrderProfit();
               ChartMarker.OrderFilled(i);
               if (__LOG) log(UpdateStatus.OrderFillMsg(i));

               sequence.level   += Sign(orders.level[i]);
               sequence.maxLevel = Sign(orders.level[i]) * Max(Abs(sequence.level), Abs(sequence.maxLevel));
               lpChange          = true;
               updateStatusLocation = updateStatusLocation || !sequence.maxLevel;
            }
         }
         else {
            // beim letzten Aufruf offene Position
            orders.swap      [i] = OrderSwap();
            orders.commission[i] = OrderCommission();
            orders.profit    [i] = OrderProfit();
         }


         isClosed = OrderCloseTime() != 0;                                       // Bei Spikes kann eine Pending-Order ausgeführt *und* bereits geschlossen sein.

         if (!isClosed) {                                                        // weiterhin offenes Ticket
            if (orders.type[i] != OP_UNDEFINED) {
               openPositions = true;

               if (orders.clientSL[i]) /*&&*/ if (IsStopTriggered(orders.type[i], orders.stopLoss[i])) {
                  if (__LOG) log(UpdateStatus.StopTriggerMsg(i));
                  ArrayPushInt(stops, i);
               }
            }
            sequence.floatingPL = NormalizeDouble(sequence.floatingPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
         }
         else if (orders.type[i] == OP_UNDEFINED) {                              // jetzt geschlossenes Ticket: gestrichene Pending-Order im STATUS_MONITORING
            //ChartMarker.OrderDeleted(i);                                       // TODO: implementieren
            Grid.DropData(i);
            sizeOfTickets--; i--;
         }
         else {
            orders.closeTime [i] = OrderCloseTime();                             // jetzt geschlossenes Ticket: geschlossene Position
            orders.closePrice[i] = OrderClosePrice();
            orders.closedBySL[i] = IsOrderClosedBySL();
            ChartMarker.PositionClosed(i);

            if (orders.closedBySL[i]) {                                          // ausgestoppt
               orders.closeEvent[i] = CreateEventId();                           // Event-ID kann sofort vergeben werden.
               if (__LOG) log(UpdateStatus.SLExecuteMsg(i));
               sequence.level  -= Sign(orders.level[i]);
               sequence.stops++;
               sequence.stopsPL = NormalizeDouble(sequence.stopsPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2); SS.Stops();
               lpChange         = true;
            }
            else {                                                               // Sequenzstop im STATUS_MONITORING oder autom. Close bei Testende
               close[0] = OrderCloseTime();
               close[1] = OrderTicket();                                         // Geschlossene Positionen werden zwischengespeichert, deren Event-IDs werden erst
               ArrayPushIntArray(closed, close);                                 // *NACH* allen evt. vorher ausgestoppten Positionen vergeben.

               if (status != STATUS_STOPPED)
                  status = STATUS_STOPPING;
               if (__LOG) log(UpdateStatus.PositionCloseMsg(i));
               sequence.closedPL = NormalizeDouble(sequence.closedPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
            }
         }
      }
   }


   // (2) Event-IDs geschlossener Positionen setzen (erst nach evt. ausgestoppten Positionen)
   int sizeOfClosed = ArrayRange(closed, 0);
   if (sizeOfClosed > 0) {
      ArraySort(closed);
      for (i=0; i < sizeOfClosed; i++) {
         int n = SearchIntArray(orders.ticket, closed[i][1]);
         if (n == -1)
            return(_false(catch("UpdateStatus(3)   closed ticket #"+ closed[i][1] +" not found in order arrays", ERR_RUNTIME_ERROR)));
         orders.closeEvent[n] = CreateEventId();
      }
      ArrayResize(closed, 0);
   }


   // (3) P/L-Kennziffern  aktualisieren
   sequence.totalPL = NormalizeDouble(sequence.stopsPL + sequence.closedPL + sequence.floatingPL, 2); SS.TotalPL();

   if      (sequence.totalPL > sequence.maxProfit  ) { sequence.maxProfit   = sequence.totalPL; SS.MaxProfit();   }
   else if (sequence.totalPL < sequence.maxDrawdown) { sequence.maxDrawdown = sequence.totalPL; SS.MaxDrawdown(); }


   // (4) ggf. Status aktualisieren
   if (status == STATUS_STOPPING) {
      if (!openPositions) {                                                      // Sequenzstop im STATUS_MONITORING oder Auto-Close durch Tester bei Testende
         n = ArraySize(sequence.stop.event) - 1;
         sequence.stop.event [n] = CreateEventId();
         sequence.stop.time  [n] = UpdateStatus.CalculateStopTime();  if (!sequence.stop.time [n]) return(false);
         sequence.stop.price [n] = UpdateStatus.CalculateStopPrice(); if (!sequence.stop.price[n]) return(false);
         sequence.stop.profit[n] = sequence.totalPL;

         if (!StopSequence.LimitStopPrice())                                     //  StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
            return(false);

         status = STATUS_STOPPED;
         if (__LOG) log("UpdateStatus()   STATUS_STOPPED");
         RedrawStartStop();
      }
   }


   else if (status == STATUS_PROGRESSING) {
      // (5) ggf. Gridbasis trailen
      if (sequence.level == 0) {
         double tmp.grid.base = grid.base;

         if (sequence.direction == D_LONG) grid.base = MathMin(grid.base, NormalizeDouble((Bid + Ask)/2, Digits));
         else                              grid.base = MathMax(grid.base, NormalizeDouble((Bid + Ask)/2, Digits));

         if (NE(grid.base, tmp.grid.base)) {
            GridBase.Change(TimeCurrent(), grid.base);
            lpChange = true;
         }
      }
   }


   // (6) ggf. Ort der Statusdatei aktualisieren
   if (updateStatusLocation)
      UpdateStatusLocation();

   return(!last_error|catch("UpdateStatus(4)"));
}


/**
 * Logmessage für ausgeführte PendingOrder
 *
 * @param  int i - Orderindex
 *
 * @return string
 */
string UpdateStatus.OrderFillMsg(int i) {
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17") was filled[ at 1.5457'2 (0.3 pip [positive ]slippage)]

   string strType         = OperationTypeDescription(orders.pendingType[i]);
   string strPendingPrice = NumberToStr(orders.pendingPrice[i], PriceFormat);
   string comment         = StringConcatenate("SR.", sequenceId, ".", NumberToStr(orders.level[i], "+."));

   string message = StringConcatenate("UpdateStatus()   #", orders.ticket[i], " ", strType, " ", NumberToStr(LotSize, ".+"), " ", Symbol(), " at ", strPendingPrice, " (\"", comment, "\") was filled");

   if (NE(orders.pendingPrice[i], orders.openPrice[i])) {
      double slippage = (orders.openPrice[i] - orders.pendingPrice[i])/Pip;
         if (orders.type[i] == OP_SELL)
            slippage = -slippage;
      string strSlippage;
      if (slippage > 0) strSlippage = StringConcatenate(DoubleToStr( slippage, Digits<<31>>31), " pip slippage");
      else              strSlippage = StringConcatenate(DoubleToStr(-slippage, Digits<<31>>31), " pip positive slippage");
      message = StringConcatenate(message, " at ", NumberToStr(orders.openPrice[i], PriceFormat), " (", strSlippage, ")");
   }
   return(message);
}


/**
 * Logmessage für getriggerten client-seitigen StopLoss.
 *
 * @param  int i - Orderindex
 *
 * @return string
 */
string UpdateStatus.StopTriggerMsg(int i) {
   string comment = StringConcatenate("SR.", sequenceId, ".", NumberToStr(orders.level[i], "+."));

   if (orders.type[i] == OP_UNDEFINED) {
      // client-side Stop Buy at 1.5457'2 ("SR.8692.+17") was triggered
      return(StringConcatenate("UpdateStatus()   client-side ", OperationTypeDescription(orders.pendingType[i]), " at ", NumberToStr(orders.pendingPrice[i], PriceFormat), " (\"", comment, "\") was triggered"));
   }
   else {
      // #1 client-side stop-loss at 1.5457'2 ("SR.8692.+17") was triggered
      return(StringConcatenate("UpdateStatus()   #", orders.ticket[i], " client-side stop-loss at ", NumberToStr(orders.stopLoss[i], PriceFormat), " (\"", comment, "\") was triggered"));
   }
}


/**
 * Logmessage für ausgeführten StopLoss.
 *
 * @param  int i - Orderindex
 *
 * @return string
 */
string UpdateStatus.SLExecuteMsg(int i) {
   // [pseudo ticket ]#1 Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17"), [client-side ]stop-loss 1.5457'2 was executed[ at 1.5457'2 (0.3 pip [positive ]slippage)]

   string strPseudo    = ifString(orders.ticket[i]==-2, "pseudo ticket ", "");
   string strType      = OperationTypeDescription(orders.type[i]);
   string strOpenPrice = NumberToStr(orders.openPrice[i], PriceFormat);
   string strStopSide  = ifString(orders.clientSL[i], "client-side ", "");
   string strStopLoss  = NumberToStr(orders.stopLoss[i], PriceFormat);
   string comment      = StringConcatenate("SR.", sequenceId, ".", NumberToStr(orders.level[i], "+."));

   string message = StringConcatenate("UpdateStatus()   ", strPseudo, "#", orders.ticket[i], " ", strType, " ", NumberToStr(LotSize, ".+"), " ", Symbol(), " at ", strOpenPrice, " (\"", comment, "\"), ", strStopSide, "stop-loss ", strStopLoss, " was executed");

   if (NE(orders.closePrice[i], orders.stopLoss[i])) {
      double slippage = (orders.stopLoss[i] - orders.closePrice[i])/Pip;
         if (orders.type[i] == OP_SELL)
            slippage = -slippage;
      string strSlippage;
      if (slippage > 0) strSlippage = StringConcatenate(DoubleToStr( slippage, Digits<<31>>31), " pip slippage");
      else              strSlippage = StringConcatenate(DoubleToStr(-slippage, Digits<<31>>31), " pip positive slippage");
      message = StringConcatenate(message, " at ", NumberToStr(orders.closePrice[i], PriceFormat), " (", strSlippage, ")");
   }
   return(message);
}


/**
 * Logmessage für geschlossene Position.
 *
 * @param  int i - Orderindex
 *
 * @return string
 */
string UpdateStatus.PositionCloseMsg(int i) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17") was closed at 1.5457'2

   string strType       = OperationTypeDescription(orders.type[i]);
   string strOpenPrice  = NumberToStr(orders.openPrice[i], PriceFormat);
   string strClosePrice = NumberToStr(orders.closePrice[i], PriceFormat);
   string comment       = StringConcatenate("SR.", sequenceId, ".", NumberToStr(orders.level[i], "+."));

   return(StringConcatenate("UpdateStatus()   #", orders.ticket[i], " ", strType, " ", NumberToStr(LotSize, ".+"), " ", Symbol(), " at ", strOpenPrice, " (\"", comment, "\") was closed at ", strClosePrice));
}


/**
 * Ermittelt die StopTime der aktuell gestoppten Sequenz. Aufruf nur nach externem Sequencestop.
 *
 * @return datetime - Zeitpunkt oder NULL, falls ein Fehler auftrat
 */
datetime UpdateStatus.CalculateStopTime() {
   if (status != STATUS_STOPPING) return(_NULL(catch("UpdateStatus.CalculateStopTime(1)   cannot calculate stop time for "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));
   if (sequence.level == 0      ) return(_NULL(catch("UpdateStatus.CalculateStopTime(2)   cannot calculate stop time for sequence at level "+ sequence.level, ERR_RUNTIME_ERROR)));

   datetime stopTime;
   int n=sequence.level, sizeofTickets=ArraySize(orders.ticket);

   for (int i=sizeofTickets-1; n != 0; i--) {
      if (orders.closeTime[i] == 0) {
         if (IsTesting() && __WHEREAMI__==FUNC_DEINIT && orders.type[i]==OP_UNDEFINED)
            continue;                                                // offene Pending-Orders ignorieren
         return(_NULL(catch("UpdateStatus.CalculateStopTime(3)   #"+ orders.ticket[i] +" is not closed", ERR_RUNTIME_ERROR)));
      }
      if (orders.type[i] == OP_UNDEFINED)                            // gestrichene Pending-Orders ignorieren
         continue;
      if (orders.closedBySL[i])                                      // ausgestoppte Positionen ignorieren
         continue;

      if (orders.level[i] != n)
         return(_NULL(catch("UpdateStatus.CalculateStopTime(4)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n, ERR_RUNTIME_ERROR)));

      stopTime = Max(stopTime, orders.closeTime[i]);
      n -= Sign(n);
   }
   return(stopTime);
}


/**
 * Ermittelt den durchschnittlichen StopPrice der aktuell gestoppten Sequenz. Aufruf nur nach externem Sequencestop.
 *
 * @return double - Preis oder NULL, falls ein Fehler auftrat
 */
double UpdateStatus.CalculateStopPrice() {
   if (status != STATUS_STOPPING) return(_NULL(catch("UpdateStatus.CalculateStopPrice(1)   cannot calculate stop price for "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));
   if (sequence.level == 0      ) return(_NULL(catch("UpdateStatus.CalculateStopPrice(2)   cannot calculate stop price for sequence at level "+ sequence.level, ERR_RUNTIME_ERROR)));

   double stopPrice;
   int n=sequence.level, sizeofTickets=ArraySize(orders.ticket);

   for (int i=sizeofTickets-1; n != 0; i--) {
      if (orders.closeTime[i] == 0) {
         if (IsTesting() && __WHEREAMI__==FUNC_DEINIT && orders.type[i]==OP_UNDEFINED)
            continue;                                                // offene Pending-Orders ignorieren
         return(_NULL(catch("UpdateStatus.CalculateStopPrice(3)   #"+ orders.ticket[i] +" is not closed", ERR_RUNTIME_ERROR)));
      }
      if (orders.type[i] == OP_UNDEFINED)                            // gestrichene Pending-Orders ignorieren
         continue;
      if (orders.closedBySL[i])                                      // ausgestoppte Positionen ignorieren
         continue;

      if (orders.level[i] != n)
         return(_NULL(catch("UpdateStatus.CalculateStopPrice(4)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n, ERR_RUNTIME_ERROR)));

      stopPrice += orders.closePrice[i];
      n -= Sign(n);
   }

   return(NormalizeDouble(stopPrice/Abs(sequence.level), Digits));
}


/**
 * Prüft, ob seit dem letzten Aufruf ein ChartCommand-Event aufgetreten ist.
 *
 * @param  string commands[] - Array zur Aufnahme der aufgetretenen Kommandos
 * @param  int    flags      - zusätzliche eventspezifische Flags (default: keine)
 *
 * @return bool - Ergebnis
 */
bool EventListener.ChartCommand(string commands[], int flags=NULL) {
   if (!IsChart)
      return(false);

   if (ArraySize(commands) > 0)
      ArrayResize(commands, 0);

   static string label, mutex="mutex.ChartCommand";
   static int    sid;

   if (sequenceId != sid) {
      label = StringConcatenate("SnowRoller.", Sequence.ID, ".command");      // Label wird nur modifiziert, wenn es sich tatsächlich ändert
      sid   = sequenceId;
   }

   if (ObjectFind(label) == 0) {
      if (!AquireLock(mutex))
         return(_false(SetLastError(stdlib_GetLastError())));

      ArrayPushString(commands, ObjectDescription(label));
      ObjectDelete(label);

      if (!ReleaseLock(mutex))
         return(_false(SetLastError(stdlib_GetLastError())));

      return(true);
   }
   return(false);
}


/**
 * Ob die aktuell selektierte Order durch den StopLoss geschlossen wurde (client- oder server-seitig).
 *
 * @return bool
 */
bool IsOrderClosedBySL() {
   bool position   = OrderType()==OP_BUY || OrderType()==OP_SELL;
   bool closed     = OrderCloseTime() != 0;                          // geschlossene Position
   bool closedBySL = false;

   if (closed) /*&&*/ if (position) {
      if (StringIEndsWith(OrderComment(), "[sl]")) {
         closedBySL = true;
      }
      else {
         // StopLoss aus Orderdaten verwenden (ist bei client-seitiger Verwaltung nur dort gespeichert)
         int i = SearchIntArray(orders.ticket, OrderTicket());

         if (i == -1)                   return(_false(catch("IsOrderClosedBySL(1)   #"+ OrderTicket() +" not found in order arrays", ERR_RUNTIME_ERROR)));
         if (EQ(orders.stopLoss[i], 0)) return(_false(catch("IsOrderClosedBySL(2)   #"+ OrderTicket() +" no stop-loss found in order arrays", ERR_RUNTIME_ERROR)));

         if      (orders.closedBySL[i]  ) closedBySL = true;
         else if (OrderType() == OP_BUY ) closedBySL = LE(OrderClosePrice(), orders.stopLoss[i]);
         else if (OrderType() == OP_SELL) closedBySL = GE(OrderClosePrice(), orders.stopLoss[i]);
      }
   }
   return(closedBySL);
}


/**
 * Signalgeber für StartSequence(). Die einzelnen Bedingungen sind AND-verknüpft.
 *
 * @return bool - ob die konfigurierten Startbedingungen erfüllt sind
 */
bool IsStartSignal() {
   if (__STATUS_ERROR)                                            return(false);
   if (status!=STATUS_WAITING) /*&&*/ if (status!=STATUS_STOPPED) return(false);

   if (start.conditions) {

      // -- start.trend: bei Trendwechsel in die angegebene Richtung erfüllt --------------------------------------------
      if (start.trend.condition) {
         int iNull[];
         if (EventListener.BarOpen(iNull, start.trend.timeframeFlag)) { // Prüfung nur bei onBarOpen, nicht bei jedem Tick
            int    timeframe   = start.trend.timeframe;
            string maPeriods   = NumberToStr(start.trend.periods, ".+");
            string maTimeframe = PeriodDescription(start.trend.timeframe);
            string maMethod    = start.trend.method;
            int    maTrendLag  = start.trend.lag;

            int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", maTrendLag, MovingAverage.MODE_TREND_LAGGED, 1);
            if (!trend) {
               int error = stdlib_GetLastError();
               if (IsError(error))
                  SetLastError(error);
               return(false);
            }
            if ((sequence.direction==D_LONG && trend==1) || (sequence.direction==D_SHORT && trend==-1)) {
               if (__LOG) log(StringConcatenate("IsStartSignal()   start condition \"", start.trend.condition.txt, "\" met"));
               return(true);
            }
         }
         return(false);
      }

      // -- start.price: erfüllt, wenn der entsprechende Preis den Wert berührt oder kreuzt -----------------------------
      if (start.price.condition) {
         static double price, lastPrice;                             // price/result: nur wegen kürzerem Code static
         static bool   result, lastPrice_init=true;
         switch (start.price.type) {
            case SCP_BID:    price =  Bid;        break;
            case SCP_ASK:    price =  Ask;        break;
            case SCP_MEDIAN: price = (Bid+Ask)/2; break;
         }

         if (lastPrice_init) {
            lastPrice_init = false;
         }
         else if (lastPrice < start.price.value) {
            result = (price >= start.price.value);                   // price hat Bedingung von unten nach oben gekreuzt
         }
         else {
            result = (price <= start.price.value);                   // price hat Bedingung von oben nach unten gekreuzt
         }

         lastPrice = price;
         if (!result)
            return(false);
         if (__LOG) log(StringConcatenate("IsStartSignal()   start condition \"", start.price.condition.txt, "\" met"));
      }

      // -- start.time: zum angegebenen Zeitpunkt oder danach erfüllt ---------------------------------------------------
      if (start.time.condition) {
         if (TimeCurrent() < start.time.value)
            return(false);
         if (__LOG) log(StringConcatenate("IsStartSignal()   start condition \"", start.time.condition.txt, "\" met"));
      }

      // -- alle Bedingungen sind erfüllt (AND-Verknüpfung) -------------------------------------------------------------
   }
   else {
      // Keine Startbedingungen sind ebenfalls gültiges Startsignal
      if (__LOG) log("IsStartSignal()   no start conditions defined");
   }

   return(true);
}


/**
 * Signalgeber für ResumeSequence().
 *
 * @return bool
 */
bool IsResumeSignal() {
   if (__STATUS_ERROR || status!=STATUS_STOPPED)
      return(false);

   if (start.conditions)
      return(IsStartSignal());

   return(IsWeekendResumeSignal());
}


/**
 * Signalgeber für ResumeSequence(). Prüft, ob die Weekend-Resume-Bedingung erfüllt ist.
 *
 * @return bool
 */
bool IsWeekendResumeSignal() {
   if (__STATUS_ERROR)                                                                                    return(false);
   if (status!=STATUS_STOPPED) /*&&*/ if (status!=STATUS_STARTING) /*&&*/ if (status!=STATUS_PROGRESSING) return(false);

   if (weekend.resume.triggered) return( true);
   if (weekend.resume.time == 0) return(false);


   int now=TimeCurrent(), dayNow=now/DAYS, dayResume=weekend.resume.time/DAYS;


   // (1) Resume-Bedingung wird erst ab Resume-Session oder deren Premarket getestet (ist u.U. der vorherige Wochentag)
   if (dayNow < dayResume-1)
      return(false);


   // (2) Bedingung ist erfüllt, wenn der Marktpreis gleich dem oder günstiger als der Stop-Preis ist
   double stopPrice = sequence.stop.price[ArraySize(sequence.stop.price)-1];
   bool   result;

   if (sequence.direction == D_LONG) result = (Ask <= stopPrice);
   else                              result = (Bid >= stopPrice);
   if (result) {
      weekend.resume.triggered = true;
      if (__LOG) log(StringConcatenate("IsWeekendResumeSignal()   weekend stop price \"", NumberToStr(stopPrice, PriceFormat), "\" met"));
      return(true);
   }


   // (3) Bedingung ist spätestens zur konfigurierten Resume-Zeit erfüllt
   if (weekend.resume.time <= now) {
      if (__LOG) log(StringConcatenate("IsWeekendResumeSignal()   resume condition '", GetDayOfWeek(weekend.resume.time, false), ", ", TimeToStr(weekend.resume.time, TIME_FULL), "' met"));
      return(true);
   }
   return(false);
}


/**
 * Aktualisiert die Bedingungen für ResumeSequence() nach der Wochenend-Pause.
 */
void UpdateWeekendResumeTime() {
   if (__STATUS_ERROR)           return;
   if (status != STATUS_STOPPED) return(_NULL(catch("UpdateWeekendResumeTime(1)   cannot update weekend resume conditions of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));
   if (!IsWeekendStopSignal())   return(_NULL(catch("UpdateWeekendResumeTime(2)   cannot update weekend resume conditions without weekend stop", ERR_RUNTIME_ERROR)));

   weekend.resume.triggered = false;

   datetime monday, stop=ServerToFXT(sequence.stop.time[ArraySize(sequence.stop.time)-1]);

   switch (TimeDayOfWeek(stop)) {
      case SUNDAY   : monday = stop + 1*DAYS; break;
      case MONDAY   : monday = stop + 0*DAYS; break;
      case TUESDAY  : monday = stop + 6*DAYS; break;
      case WEDNESDAY: monday = stop + 5*DAYS; break;
      case THURSDAY : monday = stop + 4*DAY ; break;
      case FRIDAY   : monday = stop + 3*DAYS; break;
      case SATURDAY : monday = stop + 2*DAYS; break;
   }
   weekend.resume.time = FXTToServerTime((monday/DAYS)*DAYS + weekend.resume.condition%DAY);
}


/**
 * Signalgeber für StopSequence(). Die einzelnen Bedingungen sind OR-verknüpft.
 *
 * @return bool - ob die konfigurierten Stopbedingungen erfüllt sind
 */
bool IsStopSignal() {
   if (__STATUS_ERROR || status!=STATUS_PROGRESSING)
      return(false);

   // (1) User-definierte StopConditions prüfen
   if (stop.conditions) {

      // -- stop.trend: bei Trendwechsel in die angegebene Richtung erfüllt -----------------------------------------------
      if (stop.trend.condition) {
         int iNull[];
         if (EventListener.BarOpen(iNull, stop.trend.timeframeFlag)) {
            int    timeframe   = stop.trend.timeframe;
            string maPeriods   = NumberToStr(stop.trend.periods, ".+");
            string maTimeframe = PeriodDescription(stop.trend.timeframe);
            string maMethod    = stop.trend.method;
            int    maTrendLag  = stop.trend.lag;

            int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", maTrendLag, MovingAverage.MODE_TREND_LAGGED, 1);
            if (!trend) {
               int error = stdlib_GetLastError();
               if (IsError(error))
                  SetLastError(error);
               return(false);
            }
            if ((sequence.direction==D_LONG && trend==-1) || (sequence.direction==D_SHORT && trend==1)) {
               if (__LOG) log(StringConcatenate("IsStopSignal()   stop condition \"", stop.trend.condition.txt, "\" met"));
               return(true);
            }
         }
      }

      // -- stop.price: erfüllt, wenn der aktuelle Preis den Wert berührt oder kreuzt ------------------------------
      if (stop.price.condition) {
         static double price, lastPrice;                             // price/result: nur wegen kürzerem Code static
         static bool   result, lastPrice_init=true;
         switch (start.price.type) {
            case SCP_BID:    price =  Bid;        break;
            case SCP_ASK:    price =  Ask;        break;
            case SCP_MEDIAN: price = (Bid+Ask)/2; break;
         }

         if (lastPrice_init) {
            lastPrice_init = false;
         }
         else if (lastPrice < stop.price.value) {
            result = (price >= stop.price.value);                    // price hat Bedingung von unten nach oben gekreuzt
         }
         else if (lastPrice > stop.price.value) {
            result = (price <= stop.price.value);                    // Bid hat Bedingung von oben nach unten gekreuzt
         }

         lastPrice = price;
         if (result) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   stop condition \"", stop.price.condition.txt, "\" met"));
            return(true);
         }
      }

      // -- stop.level: erfüllt, wenn der angegebene Level erreicht ist -------------------------------------------------
      if (stop.level.condition) {
         if (stop.level.value == sequence.level) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   stop condition \"", stop.level.condition.txt, "\" met"));
            return(true);
         }
      }

      // -- stop.time: zum angegebenen Zeitpunkt oder danach erfüllt ----------------------------------------------------
      if (stop.time.condition) {
         if (stop.time.value <= TimeCurrent()) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   stop condition \"", stop.time.condition.txt, "\" met"));
            return(true);
         }
      }

      // -- stop.profitAbs: ---------------------------------------------------------------------------------------------
      if (stop.profitAbs.condition) {
         if (GE(sequence.totalPL, stop.profitAbs.value)) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   stop condition \"", stop.profitAbs.condition.txt, "\" met"));
            return(true);
         }
      }

      // -- stop.profitPct: ---------------------------------------------------------------------------------------------
      if (stop.profitPct.condition) {
         if (GE(sequence.totalPL, stop.profitPct.value/100 * sequence.startEquity)) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   stop condition \"", stop.profitPct.condition.txt, "\" met"));
            return(true);
         }
      }

      // -- keine der Bedingungen ist erfüllt (OR-Verknüpfung) ----------------------------------------------------------
   }


   // (2) interne WeekendStop-Bedingung prüfen
   return(IsWeekendStopSignal());
}


/**
 * Signalgeber für StopSequence(). Prüft, ob die WeekendStop-Bedingung erfüllt ist.
 *
 * @return bool
 */
bool IsWeekendStopSignal() {
   if (__STATUS_ERROR)                                                                                    return(false);
   if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STOPPING) /*&&*/ if (status!=STATUS_STOPPED) return(false);

   if (weekend.stop.active)    return( true);
   if (weekend.stop.time == 0) return(false);

   datetime now = TimeCurrent();

   if (weekend.stop.time <= now) {
      if (weekend.stop.time/DAYS == now/DAYS) {                               // stellt sicher, daß Signal nicht von altem Datum getriggert wird
         weekend.stop.active = true;
         if (__LOG) log(StringConcatenate("IsWeekendStopSignal()   stop condition '", GetDayOfWeek(weekend.stop.time, false), ", ", TimeToStr(weekend.stop.time, TIME_FULL), "' met"));
         return(true);
      }
   }
   return(false);
}


/**
 * Aktualisiert die Stopbedingung für die nächste Wochenend-Pause.
 */
void UpdateWeekendStop() {
   weekend.stop.active = false;

   datetime friday, now=ServerToFXT(TimeCurrent());

   switch (TimeDayOfWeek(now)) {
      case SUNDAY   : friday = now + 5*DAYS; break;
      case MONDAY   : friday = now + 4*DAYS; break;
      case TUESDAY  : friday = now + 3*DAYS; break;
      case WEDNESDAY: friday = now + 2*DAYS; break;
      case THURSDAY : friday = now + 1*DAY ; break;
      case FRIDAY   : friday = now + 0*DAYS; break;
      case SATURDAY : friday = now + 6*DAYS; break;
   }
   weekend.stop.time = (friday/DAYS)*DAYS + weekend.stop.condition%DAY;
   if (weekend.stop.time < now)
      weekend.stop.time = (friday/DAYS)*DAYS + D'1970.01.01 23:55'%DAY;    // wenn Aufruf nach Weekend-Stop, erfolgt neuer Stop 5 Minuten vor Handelsschluß
   weekend.stop.time = FXTToServerTime(weekend.stop.time);
}


/**
 * Ordermanagement getriggerter client-seitiger Stops. Kann eine getriggerte Stop-Order oder ein getriggerter Stop-Loss sein.
 * Aufruf nur aus onTick()
 *
 * @param  int stops[] - Array-Indizes der Orders mit getriggerten Stops
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessClientStops(int stops[]) {
   if (__STATUS_ERROR)                    return( false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(_false(catch("ProcessClientStops(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)      return(_false(catch("ProcessClientStops(2)   cannot process client-side stops of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   int sizeOfStops = ArraySize(stops);
   if (sizeOfStops == 0)
      return(true);

   int button, ticket;
   /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);


   // (1) der Stop kann eine getriggerte Pending-Order (OP_BUYSTOP, OP_SELLSTOP) oder ein getriggerter Stop-Loss sein
   for (int i, n=0; n < sizeOfStops; n++) {
      i = stops[n];
      if (i >= ArraySize(orders.ticket))     return(_false(catch("ProcessClientStops(3)   illegal value "+ i +" in parameter stops = "+ IntsToStr(stops, NULL), ERR_INVALID_FUNCTION_PARAMVALUE)));


      // (2) getriggerte Pending-Order (OP_BUYSTOP, OP_SELLSTOP)
      if (orders.ticket[i] == -1) {
         if (orders.type[i] != OP_UNDEFINED) return(_false(catch("ProcessClientStops(4)   client-side "+ OperationTypeDescription(orders.pendingType[i]) +" order at index "+ i +" already marked as open", ERR_ILLEGAL_STATE)));

         if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("ProcessClientStops()", "Do you really want to execute a triggered client-side "+ OperationTypeDescription(orders.pendingType[i]) +" order now?"))
            return(!SetLastError(ERR_CANCELLED_BY_USER));

         int  type     = orders.pendingType[i] - 4;
         int  level    = orders.level      [i];
         bool clientSL = false;                                               // zuerst versuchen, server-seitigen StopLoss zu setzen...

         ticket = SubmitMarketOrder(type, level, clientSL, oe);

         // (2.1) ab dem letzten Level ggf. client-seitige Stop-Verwaltung
         orders.clientSL[i] = (ticket <= 0);

         if (ticket <= 0) {
            if (level != sequence.level)          return( false);
            if (oe.Error(oe) != ERR_INVALID_STOP) return( false);
            if (ticket==0 || ticket < -2)         return(_false(catch("ProcessClientStops(5)", oe.Error(oe))));

            double stopLoss = oe.StopLoss(oe);

            // (2.2) Spread violated
            if (ticket == -1) {
               return(_false(catch("ProcessClientStops(6)   spread violated ("+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +") by "+ OperationTypeDescription(type) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +", sl="+ NumberToStr(stopLoss, PriceFormat) +" (level "+ level +")", oe.Error(oe))));
            }

            // (2.3) StopDistance violated
            else if (ticket == -2) {
               clientSL = true;
               ticket   = SubmitMarketOrder(type, level, clientSL, oe);       // danach client-seitige Stop-Verwaltung (ab dem letzten Level)
               if (ticket <= 0)
                  return(false);
               if (__LOG) log(StringConcatenate("ProcessClientStops()   #", ticket, " client-side stop-loss at ", NumberToStr(stopLoss, PriceFormat), " installed (level ", level, ")"));
            }
         }
         orders.ticket[i] = ticket;
         continue;
      }


      // (3) getriggerter StopLoss
      if (orders.clientSL[i]) {
         if (orders.ticket[i] == -2)         return(_false(catch("ProcessClientStops(7)   cannot process client-side stoploss of pseudo ticket #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
         if (orders.type[i] == OP_UNDEFINED) return(_false(catch("ProcessClientStops(8)   #"+ orders.ticket[i] +" with client-side stop-loss still marked as pending", ERR_ILLEGAL_STATE)));
         if (orders.closeTime[i] != 0)       return(_false(catch("ProcessClientStops(9)   #"+ orders.ticket[i] +" with client-side stop-loss already marked as closed", ERR_ILLEGAL_STATE)));

         if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("ProcessClientStops()", "Do you really want to execute a triggered client-side stop-loss now?"))
            return(!SetLastError(ERR_CANCELLED_BY_USER));

         double lots        = NULL;
         double price       = NULL;
         double slippage    = 0.1;
         color  markerColor = CLR_NONE;
         int    oeFlags     = NULL;
         if (!OrderCloseEx(orders.ticket[i], lots, price, slippage, markerColor, oeFlags, oe))
            return(_false(SetLastError(oe.Error(oe))));

         orders.closedBySL[i] = true;
      }
   }
   ArrayResize(oe, 0);


   // (4) Status aktualisieren und speichern
   bool bNull;
   int  iNull[];
   if (!UpdateStatus(bNull, iNull)) return(false);
   if (  !SaveStatus())             return(false);

   return(!last_error|catch("ProcessClientStops(10)"));
}


/**
 * Aktualisiert vorhandene, setzt fehlende und löscht unnötige PendingOrders.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePendingOrders() {
   if (__STATUS_ERROR)                    return( false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(_false(catch("UpdatePendingOrders(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)      return(_false(catch("UpdatePendingOrders(2)   cannot update orders of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   int  nextLevel = sequence.level + ifInt(sequence.direction==D_LONG, 1, -1);
   bool nextOrderExists, ordersChanged;

   for (int i=ArraySize(orders.ticket)-1; i >= 0; i--) {
      if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0) {     // if (isPending && !isClosed)
         if (orders.level[i] == nextLevel) {
            nextOrderExists = true;
            if (Abs(nextLevel)==1) /*&&*/ if (NE(orders.pendingPrice[i], grid.base + nextLevel*GridSize*Pips)) {
               if (!Grid.TrailPendingOrder(i))                                   // Order im ersten Level ggf. trailen
                  return(false);
               ordersChanged = true;
            }
            continue;
         }
         if (!Grid.DeleteOrder(i))                                               // unnötige Pending-Orders löschen
            return(false);
         ordersChanged = true;
      }
   }

   if (!nextOrderExists) {                                                       // nötige Pending-Order in den Markt legen
      if (!Grid.AddOrder(ifInt(sequence.direction==D_LONG, OP_BUYSTOP, OP_SELLSTOP), nextLevel))
         return(false);
      ordersChanged = true;
   }

   if (ordersChanged)                                                            // Status speichern
      if (!SaveStatus())
         return(false);
   return(!last_error|catch("UpdatePendingOrders(3)"));
}


/**
 * Öffnet neue bzw. vervollständigt fehlende offene Positionen einer Sequenz. Aufruf nur in StartSequence() und ResumeSequence().
 *
 * @param  datetime &lpOpenTime  - Zeiger auf Variable, die die OpenTime der zuletzt geöffneten Position aufnimmt
 * @param  double   &lpOpenPrice - Zeiger auf Variable, die den durchschnittlichen OpenPrice aufnimmt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Im Level 0 (keine Positionen zu öffnen) werden die Variablen, auf die die übergebenen Pointer zeigen, nicht modifiziert.
 */
bool UpdateOpenPositions(datetime &lpOpenTime, double &lpOpenPrice) {
   if (__STATUS_ERROR)                    return( false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(_false(catch("UpdateOpenPositions(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_STARTING)         return(_false(catch("UpdateOpenPositions(2)   cannot update positions of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   int i, level;
   datetime openTime;
   double   openPrice;


   // (1) Long
   if (sequence.level > 0) {
      for (level=1; level <= sequence.level; level++) {
         i = Grid.FindOpenPosition(level);
         if (i == -1) {
            if (!Grid.AddPosition(OP_BUY, level))
               return(false);
            if (!SaveStatus())                                                   // Status nach jeder Trade-Operation speichern, um das Ticket nicht zu verlieren,
               return(false);                                                    // falls in einer der folgenden Operationen ein Fehler auftritt.
            i = ArraySize(orders.ticket) - 1;
         }
         openTime   = Max(openTime, orders.openTime[i]);
         openPrice += orders.openPrice[i];
      }
      openPrice /= Abs(sequence.level);                                          // avg(OpenPrice)
   }


   // (2) Short
   else if (sequence.level < 0) {
      for (level=-1; level >= sequence.level; level--) {
         i = Grid.FindOpenPosition(level);
         if (i == -1) {
            if (!Grid.AddPosition(OP_SELL, level))
               return(false);
            if (!SaveStatus())                                                   // Status nach jeder Trade-Operation speichern, um das Ticket nicht zu verlieren,
               return(false);                                                    // falls in einer der folgenden Operationen ein Fehler auftritt.
            i = ArraySize(orders.ticket) - 1;
         }
         openTime   = Max(openTime, orders.openTime[i]);
         openPrice += orders.openPrice[i];
      }
      openPrice /= Abs(sequence.level);                                          // avg(OpenPrice)
   }


   // (3) Ergebnis setzen
   if (openTime != 0) {                                                          // sequence.level != 0
      lpOpenTime  = openTime;
      lpOpenPrice = NormalizeDouble(openPrice, Digits);
   }
   return(!last_error|catch("UpdateOpenPositions(3)"));
}


/**
 * Löscht alle gespeicherten Änderungen der Gridbasis und initialisiert sie mit dem angegebenen Wert.
 *
 * @param  datetime time  - Zeitpunkt
 * @param  double   value - neue Gridbasis
 *
 * @return double - neue Gridbasis (for chaining) oder 0, falls ein Fehler auftrat
 */
double GridBase.Reset(datetime time, double value) {
   if (__STATUS_ERROR)
      return(0);

   ArrayResize(grid.base.event, 0);
   ArrayResize(grid.base.time,  0);
   ArrayResize(grid.base.value, 0);

   return(GridBase.Change(time, value));
}


/**
 * Speichert eine Änderung der Gridbasis.
 *
 * @param  datetime time  - Zeitpunkt der Änderung
 * @param  double   value - neue Gridbasis
 *
 * @return double - die neue Gridbasis
 */
double GridBase.Change(datetime time, double value) {
   value = NormalizeDouble(value, Digits);

   if (sequence.maxLevel == 0) {                                     // vor dem ersten ausgeführten Trade werden vorhandene Werte überschrieben
      ArrayResize(grid.base.event, 0);
      ArrayResize(grid.base.time,  0);
      ArrayResize(grid.base.value, 0);
   }

   int size = ArraySize(grid.base.event);                            // ab dem ersten ausgeführten Trade werden neue Werte angefügt
   if (size == 0) {
      ArrayPushInt   (grid.base.event, CreateEventId());
      ArrayPushInt   (grid.base.time,  time           );
      ArrayPushDouble(grid.base.value, value          );
   }
   else {
      int minutes=time/MINUTE, lastMinutes=grid.base.time[size-1]/MINUTE;
      if (minutes == lastMinutes) {
         grid.base.event[size-1] = CreateEventId();                  // je Minute wird nur die letzte Änderung gespeichert
         grid.base.time [size-1] = time;
         grid.base.value[size-1] = value;
      }
      else {
         ArrayPushInt   (grid.base.event, CreateEventId());
         ArrayPushInt   (grid.base.time,  time           );
         ArrayPushDouble(grid.base.value, value          );
      }
   }

   grid.base = value; SS.GridBase();
   return(value);
}


/**
 * Legt eine Stop-Order in den Markt und fügt sie den Orderarrays hinzu.
 *
 * @param  int type  - Ordertyp: OP_BUYSTOP | OP_SELLSTOP
 * @param  int level - Gridlevel der Order
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.AddOrder(int type, int level) {
   if (__STATUS_ERROR)                    return(false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(!catch("Grid.AddOrder(1)", ERR_ILLEGAL_STATE));
   if (status != STATUS_PROGRESSING)      return(!catch("Grid.AddOrder(2)   cannot add order to "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("Grid.AddOrder()", "Do you really want to submit a new "+ OperationTypeDescription(type) +" order now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));


   // (1) Order in den Markt legen
   /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
   int ticket = SubmitStopOrder(type, level, oe);

   double pendingPrice = oe.OpenPrice(oe);

   if (ticket <= 0) {
      if (oe.Error(oe) != ERR_INVALID_STOP) return(false);
      if (ticket == 0)                      return(!catch("Grid.AddOrder(3)", oe.Error(oe)));

      // (2) Spread violated
      if (ticket == -1) {
         return(!catch("Grid.AddOrder(4)   spread violated ("+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +") by "+ OperationTypeDescription(type) +" at "+ NumberToStr(pendingPrice, PriceFormat) +" (level "+ level +")", oe.Error(oe)));
      }
      // (3) StopDistance violated => client-seitige Stop-Verwaltung
      else if (ticket == -2) {
         ticket = -1;
         if (__LOG) log(StringConcatenate("Grid.AddOrder()   client-side ", OperationTypeDescription(type), " at ", NumberToStr(pendingPrice, PriceFormat), " installed (level ", level, ")"));
      }
   }

   // (4) Daten speichern
   //int    ticket       = ...                                          // unverändert
   //int    level        = ...                                          // unverändert
   //double grid.base    = ...                                          // unverändert

   int      pendingType  = type;
   datetime pendingTime  = oe.OpenTime(oe);  if (ticket < 0) pendingTime = TimeCurrent();
   //double pendingPrice = ...                                          // unverändert

   /*int*/  type         = OP_UNDEFINED;
   int      openEvent    = NULL;
   datetime openTime     = NULL;
   double   openPrice    = NULL;
   int      closeEvent   = NULL;
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   double   stopLoss     = oe.StopLoss(oe);
   bool     clientSL     = (ticket <= 0);
   bool     closedBySL   = false;

   double   swap         = NULL;
   double   commission   = NULL;
   double   profit       = NULL;

   ArrayResize(oe, 0);

   if (!Grid.PushData(ticket, level, grid.base, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit))
      return(false);
   return(!last_error|catch("Grid.AddOrder(5)"));
}


/**
 * Legt eine Stop-Order in den Markt.
 *
 * @param  int type  - Ordertyp: OP_BUYSTOP | OP_SELLSTOP
 * @param  int level - Gridlevel der Order
 * @param  int oe[]  - Ausführungsdetails
 *
 * @return int - Orderticket (positiver Wert) oder ein anderer Wert, falls ein Fehler auftrat
 *
 *
 *  Spezielle Return-Codes:
 *  -----------------------
 *  -1: der StopPrice verletzt den aktuellen Spread
 *  -2: der StopPrice verletzt die StopDistance des Brokers
 */
int SubmitStopOrder(int type, int level, int oe[]) {
   if (__STATUS_ERROR)                                                 return(0);
   if (IsTest()) /*&&*/ if (!IsTesting())                              return(_ZERO(catch("SubmitStopOrder(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STARTING) return(_ZERO(catch("SubmitStopOrder(2)   cannot submit stop order for "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   if (type == OP_BUYSTOP) {
      if (level <= 0) return(_ZERO(catch("SubmitStopOrder(3)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else if (type == OP_SELLSTOP) {
      if (level >= 0) return(_ZERO(catch("SubmitStopOrder(4)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else               return(_ZERO(catch("SubmitStopOrder(5)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double   stopPrice   = grid.base + level*GridSize*Pips;
   double   slippage    = NULL;
   double   stopLoss    = stopPrice - Sign(level)*GridSize*Pips;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber(level);
   datetime expires     = NULL;
   string   comment     = StringConcatenate("SR.", sequenceId, ".", NumberToStr(level, "+."));
   color    markerColor = CLR_PENDING;
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   if (orderDisplayMode == ODM_NONE)
      markerColor = CLR_NONE;

   int oeFlags = OE_CATCH_INVALID_STOP;                              // ERR_INVALID_STOP abfangen

   int ticket = OrderSendEx(Symbol(), type, LotSize, stopPrice, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0)
      return(ticket);

   int error = oe.Error(oe);

   if (error == ERR_INVALID_STOP) {
      // Der StopPrice liegt entweder innerhalb des Spreads (-1) oder innerhalb der StopDistance (-2).
      bool insideSpread;
      if (type == OP_BUYSTOP) insideSpread = LE(oe.OpenPrice(oe), oe.Ask(oe));
      else                    insideSpread = GE(oe.OpenPrice(oe), oe.Bid(oe));
      if (insideSpread)
         return(-1);
      return(-2);
   }

   return(_ZERO(SetLastError(error)));
}


/**
 * Legt die angegebene Position in den Markt und fügt den Gridarrays deren Daten hinzu. Aufruf nur in UpdateOpenPositions()
 *
 * @param  int type  - Ordertyp: OP_BUY | OP_SELL
 * @param  int level - Gridlevel der Position
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.AddPosition(int type, int level) {
   if (__STATUS_ERROR)                    return( false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(_false(catch("Grid.AddPosition(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_STARTING)         return(_false(catch("Grid.AddPosition(2)   cannot add market position to "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));
   if (!level)                            return(_false(catch("Grid.AddPosition(3)   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("Grid.AddPosition()", "Do you really want to submit a Market "+ OperationTypeDescription(type) +" order now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));


   // (1) Position öffnen
   /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
   bool clientSL = false;
   int  ticket   = SubmitMarketOrder(type, level, clientSL, oe);     // zuerst versuchen, server-seitigen StopLoss zu setzen...

   double stopLoss = oe.StopLoss(oe);

   if (ticket <= 0) {
      // ab dem letzten Level ggf. client-seitige Stop-Verwaltung
      if (level != sequence.level)          return( false);
      if (oe.Error(oe) != ERR_INVALID_STOP) return( false);
      if (ticket==0 || ticket < -2)         return(_false(catch("Grid.AddPosition(4)", oe.Error(oe))));

      // (2) Spread violated
      if (ticket == -1) {
         ticket   = -2;                                              // Pseudo-Ticket "öffnen" (wird beim nächsten UpdateStatus() mit P/L=0.00 "geschlossen")
         clientSL = true;
         oe.setOpenTime(oe, TimeCurrent());
         if (__LOG) log(StringConcatenate("Grid.AddPosition()   pseudo ticket #", ticket, " opened for spread violation (", NumberToStr(oe.Bid(oe), PriceFormat), "/", NumberToStr(oe.Ask(oe), PriceFormat), ") by ", OperationTypeDescription(type), " at ", NumberToStr(oe.OpenPrice(oe), PriceFormat), ", sl=", NumberToStr(stopLoss, PriceFormat), " (level ", level, ")"));
      }

      // (3) StopDistance violated
      else if (ticket == -2) {
         clientSL = true;
         ticket   = SubmitMarketOrder(type, level, clientSL, oe);    // danach client-seitige Stop-Verwaltung
         if (ticket <= 0)
            return(false);
         if (__LOG) log(StringConcatenate("Grid.AddPosition()   #", ticket, " client-side stop-loss at ", NumberToStr(stopLoss, PriceFormat), " installed (level ", level, ")"));
      }
   }

   // (4) Daten speichern
   //int    ticket       = ...                                       // unverändert
   //int    level        = ...                                       // unverändert
   //double grid.base    = ...                                       // unverändert

   int      pendingType  = OP_UNDEFINED;
   datetime pendingTime  = NULL;
   double   pendingPrice = NULL;

   //int    type         = ...                                       // unverändert
   int      openEvent    = CreateEventId();
   datetime openTime     = oe.OpenTime (oe);
   double   openPrice    = oe.OpenPrice(oe);
   int      closeEvent   = NULL;
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   //double stopLoss     = ...                                       // unverändert
   //bool   clientSL     = ...                                       // unverändert
   bool     closedBySL   = false;

   double   swap         = oe.Swap      (oe);                        // falls Swap bereits bei OrderOpen gesetzt sein sollte
   double   commission   = oe.Commission(oe);
   double   profit       = NULL;

   if (!Grid.PushData(ticket, level, grid.base, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit))
      return(false);

   ArrayResize(oe, 0);
   return(!last_error|catch("Grid.AddPosition(5)"));
}


/**
 * Öffnet eine Position zum aktuellen Preis.
 *
 * @param  int  type     - Ordertyp: OP_BUY | OP_SELL
 * @param  int  level    - Gridlevel der Order
 * @param  bool clientSL - ob der StopLoss client-seitig verwaltet wird
 * @param  int  oe[]     - Ausführungsdetails (ORDER_EXECUTION)
 *
 * @return int - Orderticket (positiver Wert) oder ein anderer Wert, falls ein Fehler auftrat
 *
 *
 *  Return-Codes mit besonderer Bedeutung:
 *  --------------------------------------
 *  -1: der StopLoss verletzt den aktuellen Spread
 *  -2: der StopLoss verletzt die StopDistance des Brokers
 */
int SubmitMarketOrder(int type, int level, bool clientSL, /*ORDER_EXECUTION*/int oe[]) {
   if (__STATUS_ERROR)                                                 return(0);
   if (IsTest()) /*&&*/ if (!IsTesting())                              return(_ZERO(catch("SubmitMarketOrder(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_STARTING) /*&&*/ if (status!=STATUS_PROGRESSING) return(_ZERO(catch("SubmitMarketOrder(2)   cannot submit market order for "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

   if (type == OP_BUY) {
      if (level <= 0) return(_ZERO(catch("SubmitMarketOrder(3)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else if (type == OP_SELL) {
      if (level >= 0) return(_ZERO(catch("SubmitMarketOrder(4)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else               return(_ZERO(catch("SubmitMarketOrder(5)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double   price       = NULL;
   double   slippage    = 0.1;
   double   stopLoss    = ifDouble(clientSL, NULL, grid.base + (level-Sign(level))*GridSize*Pips);
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber(level);
   datetime expires     = NULL;
   string   comment     = StringConcatenate("SR.", sequenceId, ".", NumberToStr(level, "+."));
   color    markerColor = ifInt(level > 0, CLR_LONG, CLR_SHORT);
   int      oeFlags     = NULL;
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   if (orderDisplayMode == ODM_NONE)
      markerColor = CLR_NONE;

   if (!clientSL) /*&&*/ if (Abs(level) >= Abs(sequence.level))
      oeFlags |= OE_CATCH_INVALID_STOP;                                    // ab dem letzten Level bei server-seitigem StopLoss ERR_INVALID_STOP abfangen

   int ticket = OrderSendEx(Symbol(), type, LotSize, price, slippage, stopLoss, takeProfit, comment, magicNumber, expires, markerColor, oeFlags, oe);
   if (ticket > 0)
      return(ticket);

   int error = oe.Error(oe);

   if (_bool(oeFlags & OE_CATCH_INVALID_STOP)) {
      if (error == ERR_INVALID_STOP) {
         // Der StopLoss liegt entweder innerhalb des Spreads (-1) oder innerhalb der StopDistance (-2).
         bool insideSpread;
         if (type == OP_BUY) insideSpread = GE(oe.StopLoss(oe), oe.Bid(oe));
         else                insideSpread = LE(oe.StopLoss(oe), oe.Ask(oe));
         if (insideSpread)
            return(-1);
         return(-2);
      }
   }

   return(_ZERO(SetLastError(error)));
}


/**
 * Justiert PendingOpenPrice() und StopLoss() der angegebenen Order und aktualisiert die Orderarrays.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.TrailPendingOrder(int i) {
   if (__STATUS_ERROR)                    return( false);
   if (IsTest()) /*&&*/ if (!IsTesting()) return(_false(catch("Grid.TrailPendingOrder(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)      return(_false(catch("Grid.TrailPendingOrder(2)   cannot trail order of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));
   if (orders.type[i] != OP_UNDEFINED)    return(_false(catch("Grid.TrailPendingOrder(3)   cannot trail "+ OperationTypeDescription(orders.type[i]) +" position #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
   if (orders.closeTime[i] != 0)          return(_false(catch("Grid.TrailPendingOrder(4)   cannot trail cancelled "+ OperationTypeDescription(orders.type[i]) +" order #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("Grid.TrailPendingOrder()", "Do you really want to modify the "+ OperationTypeDescription(orders.pendingType[i]) +" order #"+ orders.ticket[i] +" now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   double stopPrice   = NormalizeDouble(grid.base +      orders.level[i]  * GridSize * Pips, Digits);
   double stopLoss    = NormalizeDouble(stopPrice - Sign(orders.level[i]) * GridSize * Pips, Digits);
   color  markerColor = CLR_PENDING;
   int    oeFlags     = NULL;

   if (EQ(orders.pendingPrice[i], stopPrice)) /*&&*/ if (EQ(orders.stopLoss[i], stopLoss))
      return(_false(catch("Grid.TrailPendingOrder(5)   nothing to modify for #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));

   if (orders.ticket[i] < 0) {                                       // client-seitige Orders
      // TODO: ChartMarker nachziehen
   }
   else {                                                            // server-seitige Orders
      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);
      if (!OrderModifyEx(orders.ticket[i], stopPrice, stopLoss, NULL, NULL, markerColor, oeFlags, oe))
         return(_false(SetLastError(oe.Error(oe))));
      ArrayResize(oe, 0);
   }

   orders.gridBase    [i] = grid.base;
   orders.pendingTime [i] = TimeCurrent();
   orders.pendingPrice[i] = stopPrice;
   orders.stopLoss    [i] = stopLoss;

   return(!last_error|catch("Grid.TrailPendingOrder(6)"));
}


/**
 * Streicht die angegebene Order und entfernt sie aus den Orderarrays.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.DeleteOrder(int i) {
   if (__STATUS_ERROR)                                                         return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                                      return(_false(catch("Grid.DeleteOrder(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STOPPING)
      if (!IsTesting() || __WHEREAMI__!=FUNC_DEINIT || status!=STATUS_STOPPED) return(_false(catch("Grid.DeleteOrder(2)   cannot delete order of "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));
   if (orders.type[i] != OP_UNDEFINED)                                         return(_false(catch("Grid.DeleteOrder(3)   cannot delete "+ ifString(orders.closeTime[i]==0, "open", "closed") +" "+ OperationTypeDescription(orders.type[i]) +" position", ERR_RUNTIME_ERROR)));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("Grid.DeleteOrder()", "Do you really want to cancel the "+ OperationTypeDescription(orders.pendingType[i]) +" order at level "+ orders.level[i] +" now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   if (orders.ticket[i] > 0) {
      int oeFlags = NULL;
      /*ORDER_EXECUTION*/int oe[]; InitializeByteBuffer(oe, ORDER_EXECUTION.size);

      if (!OrderDeleteEx(orders.ticket[i], CLR_NONE, oeFlags, oe))
         return(_false(SetLastError(oe.Error(oe))));
      ArrayResize(oe, 0);
   }

   if (!Grid.DropData(i))
      return(false);

   return(!last_error|catch("Grid.DeleteOrder(4)"));
}


/**
 * Fügt den Datenarrays der Sequenz die angegebenen Daten hinzu.
 *
 * @param  int      ticket
 * @param  int      level
 * @param  double   gridBase
 *
 * @param  int      pendingType
 * @param  datetime pendingTime
 * @param  double   pendingPrice
 *
 * @param  int      type
 * @param  int      openEvent
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  int      closeEvent
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   stopLoss
 * @param  bool     clientSL
 * @param  bool     closedBySL
 *
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.PushData(int ticket, int level, double gridBase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientSL, bool closedBySL, double swap, double commission, double profit) {
   return(Grid.SetData(-1, ticket, level, gridBase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit));
}


/**
 * Schreibt die angegebenen Daten an die angegebene Position der Gridarrays.
 *
 * @param  int      offset       - Arrayposition: Ist dieser Wert -1 oder sind die Gridarrays zu klein, werden sie vergrößert.
 *
 * @param  int      ticket
 * @param  int      level
 * @param  double   gridBase
 *
 * @param  int      pendingType
 * @param  datetime pendingTime
 * @param  double   pendingPrice
 *
 * @param  int      type
 * @param  int      openEvent
 * @param  datetime openTime
 * @param  double   openPrice
 * @param  int      closeEvent
 * @param  datetime closeTime
 * @param  double   closePrice
 * @param  double   stopLoss
 * @param  bool     clientSL
 * @param  bool     closedBySL
 *
 * @param  double   swap
 * @param  double   commission
 * @param  double   profit
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.SetData(int offset, int ticket, int level, double gridBase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientSL, bool closedBySL, double swap, double commission, double profit) {
   if (offset < -1)
      return(_false(catch("Grid.SetData(1)   illegal parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int i=offset, size=ArraySize(orders.ticket);

   if      (offset ==    -1) i = ResizeArrays(  size+1)-1;
   else if (offset > size-1) i = ResizeArrays(offset+1)-1;

   orders.ticket      [i] = ticket;
   orders.level       [i] = level;
   orders.gridBase    [i] = NormalizeDouble(gridBase, Digits);

   orders.pendingType [i] = pendingType;
   orders.pendingTime [i] = pendingTime;
   orders.pendingPrice[i] = NormalizeDouble(pendingPrice, Digits);

   orders.type        [i] = type;
   orders.openEvent   [i] = openEvent;
   orders.openTime    [i] = openTime;
   orders.openPrice   [i] = NormalizeDouble(openPrice, Digits);
   orders.closeEvent  [i] = closeEvent;
   orders.closeTime   [i] = closeTime;
   orders.closePrice  [i] = NormalizeDouble(closePrice, Digits);
   orders.stopLoss    [i] = NormalizeDouble(stopLoss, Digits);
   orders.clientSL    [i] = clientSL;
   orders.closedBySL  [i] = closedBySL;

   orders.swap        [i] = NormalizeDouble(swap,       2);
   orders.commission  [i] = NormalizeDouble(commission, 2); if (type != OP_UNDEFINED) { sequence.commission = orders.commission[i]; SS.LotSize(); }
   orders.profit      [i] = NormalizeDouble(profit,     2);

   return(!catch("Grid.SetData(2)"));
}


/**
 * Entfernt den Datensatz der angegebenen Order aus den Datenarrays.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.DropData(int i) {
   if (i < 0 || i >= ArraySize(orders.ticket)) return(_false(catch("Grid.DropData(1)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // Einträge entfernen
   ArraySpliceInts   (orders.ticket,       i, 1);
   ArraySpliceInts   (orders.level,        i, 1);
   ArraySpliceDoubles(orders.gridBase,     i, 1);

   ArraySpliceInts   (orders.pendingType,  i, 1);
   ArraySpliceInts   (orders.pendingTime,  i, 1);
   ArraySpliceDoubles(orders.pendingPrice, i, 1);

   ArraySpliceInts   (orders.type,         i, 1);
   ArraySpliceInts   (orders.openEvent,    i, 1);
   ArraySpliceInts   (orders.openTime,     i, 1);
   ArraySpliceDoubles(orders.openPrice,    i, 1);
   ArraySpliceInts   (orders.closeEvent,   i, 1);
   ArraySpliceInts   (orders.closeTime,    i, 1);
   ArraySpliceDoubles(orders.closePrice,   i, 1);
   ArraySpliceDoubles(orders.stopLoss,     i, 1);
   ArraySpliceBools  (orders.clientSL,     i, 1);
   ArraySpliceBools  (orders.closedBySL,   i, 1);

   ArraySpliceDoubles(orders.swap,         i, 1);
   ArraySpliceDoubles(orders.commission,   i, 1);
   ArraySpliceDoubles(orders.profit,       i, 1);

   return(!last_error|catch("Grid.DropData(2)"));
}


/**
 * Sucht eine offene Position des angegebenen Levels und gibt Orderindex zurück. Je Level kann es maximal eine offene Position geben.
 *
 * @param  int level - Level der zu suchenden Position
 *
 * @return int - Index der gefundenen Position oder -1, wenn keine offene Position des angegebenen Levels gefunden wurde
 */
int Grid.FindOpenPosition(int level) {
   if (!level) return(_int(-1, catch("Grid.FindOpenPosition()   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int size = ArraySize(orders.ticket);

   for (int i=size-1; i >= 0; i--) {                                 // rückwärts iterieren, um Zeit zu sparen
      if (orders.level[i] != level)
         continue;                                                   // Order muß zum Level gehören
      if (orders.type[i] == OP_UNDEFINED)
         continue;                                                   // Order darf nicht pending sein
      if (orders.closeTime[i] != 0)
         continue;                                                   // Position darf nicht geschlossen sein
      return(i);
   }
   return(-1);
}


/**
 * Generiert für den angegebenen Gridlevel eine MagicNumber.
 *
 * @param  int level - Gridlevel
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int level) {
   if (sequenceId < SID_MIN) return(_int(-1, catch("CreateMagicNumber(1)   illegal sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));
   if (!level)               return(_int(-1, catch("CreateMagicNumber(2)   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // Für bessere Obfuscation ist die Reihenfolge der Werte [ea,level,sequence] und nicht [ea,sequence,level], was aufeinander folgende Werte wären.
   int ea       = STRATEGY_ID & 0x3FF << 22;                         // 10 bit (Bits größer 10 löschen und auf 32 Bit erweitern)  | Position in MagicNumber: Bits 23-32
       level    = Abs(level);                                        // der Level in MagicNumber ist immer positiv                |
       level    = level & 0xFF << 14;                                //  8 bit (Bits größer 8 löschen und auf 22 Bit erweitern)   | Position in MagicNumber: Bits 15-22
   int sequence = sequenceId  & 0x3FFF;                              // 14 bit (Bits größer 14 löschen                            | Position in MagicNumber: Bits  1-14

   return(ea + level + sequence);
}


/**
 * Zeigt den aktuellen Status der Sequenz an.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus() {
   if (!IsChart)
      return(NO_ERROR);

   string msg, str.error;

   if      (__STATUS_INVALID_INPUT) str.error = StringConcatenate("  [", ErrorDescription(ERR_INVALID_INPUT_PARAMVALUE), "]");
   else if (__STATUS_ERROR        ) str.error = StringConcatenate("  [", ErrorDescription(last_error                  ), "]");

   switch (status) {
      case STATUS_UNINITIALIZED: msg =                                      " not initialized";                                                       break;
      case STATUS_WAITING:       msg = StringConcatenate("  ", Sequence.ID, " waiting"                                                             ); break;
      case STATUS_STARTING:      msg = StringConcatenate("  ", Sequence.ID, " starting at level ",    sequence.level, "  (", sequence.maxLevel, ")"); break;
      case STATUS_PROGRESSING:   msg = StringConcatenate("  ", Sequence.ID, " progressing at level ", sequence.level, "  (", sequence.maxLevel, ")"); break;
      case STATUS_STOPPING:      msg = StringConcatenate("  ", Sequence.ID, " stopping at level ",    sequence.level, "  (", sequence.maxLevel, ")"); break;
      case STATUS_STOPPED:       msg = StringConcatenate("  ", Sequence.ID, " stopped at level ",     sequence.level, "  (", sequence.maxLevel, ")"); break;
      default:
         return(catch("ShowStatus(1)   illegal sequence status = "+ status, ERR_RUNTIME_ERROR));
   }

   msg = StringConcatenate(__NAME__, msg, str.error,                                                      NL,
                                                                                                          NL,
                           "Grid:             ", GridSize, " pip", str.grid.base, str.sequence.direction, NL,
                           "LotSize:         ",  str.LotSize,                                             NL,
                           "Stops:           ",  str.sequence.stops, str.sequence.stopsPL,                NL,
                           "Profit/Loss:    ",   str.sequence.totalPL, str.sequence.plStats,              NL,
                           str.startConditions,                                        // enthält bereits NL, wenn gesetzt
                           str.stopConditions);                                        // enthält bereits NL, wenn gesetzt

   // 3 Zeilen Abstand nach oben für Instrumentanzeige und ggf. vorhandene Legende
   Comment(StringConcatenate(NL, NL, NL, msg));
   if (__WHEREAMI__ == FUNC_INIT)
      WindowRedraw();


   // für Fernbedienung: versteckten Status im Chart speichern
   string label = "SnowRoller.status";
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
         return(catch("ShowStatus(2)"));
      ObjectSet(label, OBJPROP_TIMEFRAMES, EMPTY);                   // hidden on all timeframes
   }
   if (status == STATUS_UNINITIALIZED) ObjectDelete(label);
   else                                ObjectSetText(label, StringConcatenate(Sequence.ID, "|", status), 1);

   return(catch("ShowStatus(3)"));
}


/**
 * ShowStatus(): Aktualisiert alle in ShowStatus() verwendeten String-Repräsentationen.
 */
void SS.All() {
   if (!IsChart) return;

   SS.Sequence.Id();
   SS.GridBase();
   SS.GridDirection();
   SS.LotSize();
   SS.StartStopConditions();
   SS.Stops();
   SS.TotalPL();
   SS.MaxProfit();
   SS.MaxDrawdown();
}


/**
 * ShowStatus(): Aktualisiert die Anzeige der Sequenz-ID in der Titelzeile des Strategy Testers.
 */
void SS.Sequence.Id() {
   if (IsTesting()) {
      if (!SetWindowTextA(GetTesterWindow(), StringConcatenate("Tester - SR.", sequenceId)))
         catch("SS.Sequence.Id()->user32::SetWindowTextA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.base.
 */
void SS.GridBase() {
   if (!IsChart) return;

   if (ArraySize(grid.base.event) > 0)
      str.grid.base = StringConcatenate(" @ ", NumberToStr(grid.base, PriceFormat));
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.direction.
 */
void SS.GridDirection() {
   if (!IsChart) return;

   str.sequence.direction = StringConcatenate("  (", StringToLower(directionDescr[sequence.direction]), ")");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von LotSize.
 */
void SS.LotSize() {
   if (!IsChart) return;

   str.LotSize = StringConcatenate(NumberToStr(LotSize, ".+"), " lot = ", DoubleToStr(GridSize * PipValue(LotSize) - sequence.commission, 2), "/stop");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von start/stopConditions.
 */
void SS.StartStopConditions() {
   if (!IsChart) return;

   str.startConditions = "";
   str.stopConditions  = "";

   if (StartConditions != "") str.startConditions = StringConcatenate("Start:           ", StartConditions, NL);
   if (StopConditions  != "") str.stopConditions  = StringConcatenate("Stop:           ",  StopConditions,  NL);
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentationen von sequence.stops und sequence.stopsPL.
 */
void SS.Stops() {
   if (!IsChart) return;

   str.sequence.stops = StringConcatenate(sequence.stops, " stop", ifString(sequence.stops==1, "", "s"));

   // Anzeige wird nicht vor der ersten ausgestoppten Position gesetzt
   if (sequence.stops > 0)
      str.sequence.stopsPL = StringConcatenate(" = ", DoubleToStr(sequence.stopsPL, 2));
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.totalPL.
 */
void SS.TotalPL() {
   if (!IsChart) return;

   if (sequence.maxLevel == 0) str.sequence.totalPL = "-";           // Anzeige wird nicht vor der ersten offenen Position gesetzt
   else                        str.sequence.totalPL = NumberToStr(sequence.totalPL, "+.2");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.maxProfit.
 */
void SS.MaxProfit() {
   if (!IsChart) return;

   str.sequence.maxProfit = NumberToStr(sequence.maxProfit, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.maxDrawdown.
 */
void SS.MaxDrawdown() {
   if (!IsChart) return;

   str.sequence.maxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus(): Aktualisiert die kombinierte String-Repräsentation der P/L-Statistik.
 */
void SS.PLStats() {
   if (!IsChart) return;

   // Anzeige wird nicht vor der ersten offenen Position gesetzt
   if (sequence.maxLevel != 0)
      str.sequence.plStats = StringConcatenate("  (", str.sequence.maxProfit, "/", str.sequence.maxDrawdown, ")");
}


/**
 * Speichert temporäre Werte des Sequenzstatus im Chart, sodaß der volle Status nach einem Recompile oder Terminal-Restart daraus wiederhergestellt werden kann.
 * Die temporären Werte umfassen die Parameter, die zur Ermittlung des vollen Dateinamens der Statusdatei erforderlich sind und jene User-Eingaben, die nicht
 * in der Statusdatei gespeichert sind (aktuelle Display-Modes, Farben und Strichstärken), das Flag __STATUS_INVALID_INPUT und den Fehler ERR_CANCELLED_BY_USER.
 *
 * @return int - Fehlerstatus
 */
int StoreStickyStatus() {
   string label = StringConcatenate(__NAME__, ".sticky.Sequence.ID");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, ifString(!sequenceId, "0", Sequence.ID), 1);          // String: "0" (STATUS_UNINITIALIZED) oder Sequence.ID (enthält ggf. "T")

   if (StringLen(StringTrim(Sequence.StatusLocation)) > 0) {
      label = StringConcatenate(__NAME__, ".sticky.Sequence.StatusLocation");
      if (ObjectFind(label) == 0)
         ObjectDelete(label);
      ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
      ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                        // hidden on all timeframes
      ObjectSetText(label, Sequence.StatusLocation, 1);
   }

   label = StringConcatenate(__NAME__, ".sticky.startStopDisplayMode");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", startStopDisplayMode), 1);

   label = StringConcatenate(__NAME__, ".sticky.orderDisplayMode");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", orderDisplayMode), 1);

   label = StringConcatenate(__NAME__, ".sticky.StartStop.Color");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", StartStop.Color), 1);

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
 * Restauriert die im Chart gespeicherten Sequenzdaten.
 *
 * @return bool - ob die ID einer initialisierten Sequenz gefunden wurde (gespeicherte Sequenz kann im STATUS_UNINITIALIZED sein)
 */
bool RestoreStickyStatus() {
   string label, strValue;
   bool   idFound;

   label = StringConcatenate(__NAME__, ".sticky.Sequence.ID");
   if (ObjectFind(label) == 0) {
      strValue = StringToUpper(StringTrim(ObjectDescription(label)));
      if (StringLeft(strValue, 1) == "T") {
         isTest   = true;
         strValue = StringRight(strValue, -1);
      }
      if (!StringIsDigit(strValue))
         return(_false(catch("RestoreStickyStatus(1)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      int iValue = StrToInteger(strValue);
      if (iValue == 0) {
         status  = STATUS_UNINITIALIZED;
         idFound = false;
      }
      else if (iValue < SID_MIN || iValue > SID_MAX) {
         return(_false(catch("RestoreStickyStatus(2)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      }
      else {
         sequenceId  = iValue; SS.Sequence.Id();
         Sequence.ID = ifString(IsTest(), "T", "") + sequenceId;
         status      = STATUS_WAITING;
         idFound     = true;
         SetCustomLog(sequenceId, NULL);
      }

      label = StringConcatenate(__NAME__, ".sticky.Sequence.StatusLocation");
      if (ObjectFind(label) == 0) {
         Sequence.StatusLocation = StringTrim(ObjectDescription(label));
      }

      label = StringConcatenate(__NAME__, ".sticky.startStopDisplayMode");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsInteger(strValue))
            return(_false(catch("RestoreStickyStatus(3)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         iValue = StrToInteger(strValue);
         if (!IntInArray(startStopDisplayModes, iValue))
            return(_false(catch("RestoreStickyStatus(4)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         startStopDisplayMode = iValue;
      }

      label = StringConcatenate(__NAME__, ".sticky.orderDisplayMode");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsInteger(strValue))
            return(_false(catch("RestoreStickyStatus(5)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         iValue = StrToInteger(strValue);
         if (!IntInArray(orderDisplayModes, iValue))
            return(_false(catch("RestoreStickyStatus(6)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         orderDisplayMode = iValue;
      }

      label = StringConcatenate(__NAME__, ".sticky.StartStop.Color");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsInteger(strValue))
            return(_false(catch("RestoreStickyStatus(7)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         iValue = StrToInteger(strValue);
         if (iValue < CLR_NONE || iValue > C'255,255,255')
            return(_false(catch("RestoreStickyStatus(8)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE)));
         StartStop.Color = iValue;
      }

      label = StringConcatenate(__NAME__, ".sticky.__STATUS_INVALID_INPUT");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(11)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         __STATUS_INVALID_INPUT = StrToInteger(strValue) != 0;
      }

      label = StringConcatenate(__NAME__, ".sticky.CANCELLED_BY_USER");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(12)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         if (StrToInteger(strValue) != 0)
            SetLastError(ERR_CANCELLED_BY_USER);
      }
   }

   return(idFound && !(last_error|catch("RestoreStickyStatus(13)")));
}


/**
 * Löscht alle im Chart gespeicherten Sequenzdaten.
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
 * Ermittelt die aktuell laufenden Sequenzen.
 *
 * @param  int ids[] - Array zur Aufnahme der gefundenen Sequenz-IDs
 *
 * @return bool - ob mindestens eine laufende Sequenz gefunden wurde
 */
bool GetRunningSequences(int ids[]) {
   ArrayResize(ids, 0);
   int id;

   for (int i=OrdersTotal()-1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))               // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
         continue;

      if (IsMyOrder()) {
         id = OrderMagicNumber() & 0x3FFF;                           // 14 Bits (Bits 1-14) => sequenceId
         if (!IntInArray(ids, id))
            ArrayPushInt(ids, id);
      }
   }

   if (ArraySize(ids) != 0)
      return(ArraySort(ids));
   return(false);
}


/**
 * Ob die aktuell selektierte Order zu dieser Strategie gehört. Wird eine Sequenz-ID angegeben, wird zusätzlich überprüft,
 * ob die Order zur angegebenen Sequenz gehört.
 *
 * @param  int sequenceId - ID einer Sequenz (default: NULL)
 *
 * @return bool
 */
bool IsMyOrder(int sequenceId = NULL) {
   if (OrderSymbol() == Symbol()) {
      if (OrderMagicNumber() >> 22 == STRATEGY_ID) {
         if (sequenceId == NULL)
            return(true);
         return(sequenceId == OrderMagicNumber() & 0x3FFF);          // 14 Bits (Bits 1-14) => sequenceId
      }
   }
   return(false);
}


/**
 * Validiert und setzt nur die in der Konfiguration angegebene Sequenz-ID.
 *
 * @param  bool interactive - ob fehlerhafte Parameter interaktiv korrigiert werden können
 *
 * @return bool - ob eine gültige Sequenz-ID gefunden und restauriert wurde
 */
bool ValidateConfiguration.ID(bool interactive) {
   bool parameterChange = (UninitializeReason() == REASON_PARAMETERS);
   if (parameterChange)
      interactive = true;

   string strValue = StringToUpper(StringTrim(Sequence.ID));

   if (StringLen(strValue) == 0)
      return(false);

   if (StringLeft(strValue, 1) == "T") {
      isTest   = true;
      strValue = StringRight(strValue, -1);
   }
   if (!StringIsDigit(strValue))
      return(_false(ValidateConfig.HandleError("ValidateConfiguration.ID(1)", "Illegal input parameter Sequence.ID = \""+ Sequence.ID +"\"", interactive)));

   int iValue = StrToInteger(strValue);
   if (iValue < SID_MIN || iValue > SID_MAX)
      return(_false(ValidateConfig.HandleError("ValidateConfiguration.ID(2)", "Illegal input parameter Sequence.ID = \""+ Sequence.ID +"\"", interactive)));

   sequenceId  = iValue; SS.Sequence.Id();
   Sequence.ID = ifString(IsTest(), "T", "") + sequenceId;
   SetCustomLog(sequenceId, NULL);

   return(true);
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


   // (1) Sequence.ID
   if (reasonParameters) {
      if (status == STATUS_UNINITIALIZED) {
         if (Sequence.ID != last.Sequence.ID) {  return(_false(ValidateConfig.HandleError("ValidateConfiguration(1)", "Loading of another sequence not yet implemented!", interactive)));
            if (ValidateConfiguration.ID(interactive)) {
               // TODO: neue Sequenz laden
            }
         }
      }
      else {
         if (Sequence.ID == "")                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(2)", "Sequence.ID missing!", interactive)));
         if (Sequence.ID != last.Sequence.ID) {  return(_false(ValidateConfig.HandleError("ValidateConfiguration(3)", "Loading of another sequence not yet implemented!", interactive)));
            if (ValidateConfiguration.ID(interactive)) {
               // TODO: neue Sequenz laden
            }
         }
      }
   }
   else if (StringLen(Sequence.ID) == 0) {       // wir müssen im STATUS_UNINITIALIZED sein (sequenceId = 0)
      if (sequenceId != 0)                       return(_false(catch("ValidateConfiguration(4)   illegal Sequence.ID = \""+ Sequence.ID +"\" (sequenceId="+ sequenceId +")", ERR_RUNTIME_ERROR)));
   }
   else {}     // wenn gesetzt, ist die ID schon validiert und die Sequenz geladen (sonst landen wir hier nicht)


   // (2) GridDirection
   if (reasonParameters) {
      if (GridDirection != last.GridDirection)
         if (status != STATUS_UNINITIALIZED)     return(_false(ValidateConfig.HandleError("ValidateConfiguration(5)", "Cannot change GridDirection of "+ sequenceStatusDescr[status] +" sequence", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Position eröffnet wurde
   }
   string strValue = StringToLower(StringTrim(GridDirection));
   if (strValue == "long | short | alternative") return(_false(ValidateConfig.HandleError("ValidateConfiguration(6)", "Invalid GridDirection = \""+ GridDirection +"\"", interactive)));
   switch (StringGetChar(strValue, 0)) {
      case 'l': sequence.direction = D_LONG;  break;
      case 's': sequence.direction = D_SHORT; break;
      default:                                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(7)", "Invalid GridDirection = \""+ GridDirection +"\"", interactive)));
   }
   GridDirection = directionDescr[sequence.direction]; SS.GridDirection();


   // (3) GridSize
   if (reasonParameters) {
      if (GridSize != last.GridSize)
         if (status != STATUS_UNINITIALIZED)     return(_false(ValidateConfig.HandleError("ValidateConfiguration(8)", "Cannot change GridSize of "+ sequenceStatusDescr[status] +" sequence", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Position eröffnet wurde
   }
   if (GridSize < 1)                             return(_false(ValidateConfig.HandleError("ValidateConfiguration(9)", "Invalid GridSize = "+ GridSize, interactive)));


   // (4) LotSize
   if (reasonParameters) {
      if (NE(LotSize, last.LotSize))
         if (status != STATUS_UNINITIALIZED)     return(_false(ValidateConfig.HandleError("ValidateConfiguration(10)", "Cannot change LotSize of "+ sequenceStatusDescr[status] +" sequence", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Position eröffnet wurde
   }
   if (LE(LotSize, 0))                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(11)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+"), interactive)));
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT );
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT );
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int error = GetLastError();
   if (IsError(error))                           return(_false(catch("ValidateConfiguration(12)   symbol=\""+ Symbol() +"\"", error)));
   if (LT(LotSize, minLot))                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(13)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", interactive)));
   if (GT(LotSize, maxLot))                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(14)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", interactive)));
   if (MathModFix(LotSize, lotStep) != 0)        return(_false(ValidateConfig.HandleError("ValidateConfiguration(15)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", interactive)));
   SS.LotSize();


   // (5) StartConditions, AND-verknüpft: "(@trend(xxMA:7xD1[+1]) || (@[bid|ask|price](1.33) && @time(12:00))) && @level(3)"
   // ----------------------------------------------------------------------------------------------------------------------
   if (!reasonParameters || StartConditions!=last.StartConditions) {
      // Bei Parameteränderung Werte nur übernehmen, wenn sie sich tatsächlich geändert haben, sodaß StartConditions nur bei Änderung (re-)aktiviert werden.
      start.conditions      = false;
      start.trend.condition = false;
      start.price.condition = false;
      start.time.condition  = false;
      start.level.condition = false;

      // (5.1) StartConditions in einzelne Ausdrücke zerlegen
      string exprs[], expr, elems[], key, value;
      int    iValue, time, sizeOfElems, sizeOfExprs=Explode(StartConditions, "&&", exprs, NULL);
      double dValue;

      // (5.2) jeden Ausdruck parsen und validieren
      for (int i=0; i < sizeOfExprs; i++) {
         start.conditions = false;                     // im Fehlerfall ist start.conditions deaktiviert
         expr = StringToLower(StringTrim(exprs[i]));
         if (StringLen(expr) == 0) {
            if (sizeOfExprs > 1)                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(16)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')            return(_false(ValidateConfig.HandleError("ValidateConfiguration(17)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         if (Explode(expr, "(", elems, NULL) != 2)     return(_false(ValidateConfig.HandleError("ValidateConfiguration(18)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         if (!StringEndsWith(elems[1], ")"))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(19)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         key   = StringTrim(elems[0]);
         value = StringTrim(StringLeft(elems[1], -1));
         if (StringLen(value) == 0)                    return(_false(ValidateConfig.HandleError("ValidateConfiguration(20)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));

         if (key == "@trend") {
            if (start.trend.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(21)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple trend conditions)", interactive)));
            if (start.price.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(22)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            if (start.time.condition)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(23)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            if (Explode(value, ":", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(24)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            key   = StringToUpper(StringTrim(elems[0]));
            value = StringToUpper(elems[1]);
            // key="ALMA"
            if      (key == "SMA" ) start.trend.method = key;
            else if (key == "EMA" ) start.trend.method = key;
            else if (key == "SMMA") start.trend.method = key;
            else if (key == "LWMA") start.trend.method = key;
            else if (key == "ALMA") start.trend.method = key;
            else                                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(25)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            // value="7XD1[+2]"
            if (Explode(value, "+", elems, NULL) == 1) {
               start.trend.lag = 0;
            }
            else {
               value = StringTrim(elems[1]);
               if (!StringIsDigit(value))              return(_false(ValidateConfig.HandleError("ValidateConfiguration(26)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
               start.trend.lag = StrToInteger(value);
               if (start.trend.lag < 0)                return(_false(ValidateConfig.HandleError("ValidateConfiguration(27)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
               value = elems[0];
            }
            // value="7XD1"
            if (Explode(value, "X", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(28)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            elems[1]              = StringTrim(elems[1]);
            start.trend.timeframe = PeriodToId(elems[1]);
            if (start.trend.timeframe == -1)           return(_false(ValidateConfig.HandleError("ValidateConfiguration(29)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            value = StringTrim(elems[0]);
            if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(30)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(31)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            if (MathModFix(dValue, 0.5) != 0)          return(_false(ValidateConfig.HandleError("ValidateConfiguration(32)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            elems[0] = NumberToStr(dValue, ".+");
            switch (start.trend.timeframe) {           // Timeframes > H1 auf H1 umrechnen, iCustom() soll maximal unter PERIOD_H1 laufen
               case PERIOD_MN1:                        return(_false(ValidateConfig.HandleError("ValidateConfiguration(33)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
               case PERIOD_H4 : dValue *=   4; start.trend.timeframe = PERIOD_H1; break;
               case PERIOD_D1 : dValue *=  24; start.trend.timeframe = PERIOD_H1; break;
               case PERIOD_W1 : dValue *= 120; start.trend.timeframe = PERIOD_H1; break;
            }
            start.trend.periods       = NormalizeDouble(dValue, 1);
            start.trend.timeframeFlag = PeriodFlag(start.trend.timeframe);
            start.trend.condition     = true;
            start.trend.condition.txt = "@trend("+ start.trend.method +":"+ elems[0] +"x"+ elems[1] + ifString(!start.trend.lag, "", "+"+ start.trend.lag) +")";
            exprs[i]                  = start.trend.condition.txt;
         }

         else if (key=="@bid" || key=="@ask" || key=="@price") {
            if (start.price.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(34)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple price conditions)", interactive)));
            if (start.trend.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(35)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            value = StringReplace(value, "'", "");
            if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(36)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(37)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            start.price.condition = true;
            start.price.value     = NormalizeDouble(dValue, Digits);
            if      (key == "@bid"  ) start.price.type = SCP_BID;
            else if (key == "@ask"  ) start.price.type = SCP_ASK;
            else if (key == "@price") start.price.type = SCP_MEDIAN;
            exprs[i] = NumberToStr(start.price.value, PriceFormat);
            if (StringEndsWith(exprs[i], "'0"))        // 0-Subpips "'0" für bessere Lesbarkeit entfernen
               exprs[i] = StringLeft(exprs[i], -2);
            start.price.condition.txt = key +"("+ exprs[i] +")";
            exprs[i]                  = start.price.condition.txt;
         }

         else if (key == "@time") {
            if (start.time.condition)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(38)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple time conditions)", interactive)));
            if (start.trend.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(39)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            time = StrToTime(value);
            if (IsError(GetLastError()))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(40)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            // TODO: Validierung von @time unzureichend
            start.time.condition     = true;
            start.time.value         = time;
            start.time.condition.txt = key +"("+ TimeToStr(time) +")";
            exprs[i]                 = start.time.condition.txt;
         }

         else if (key == "@level") {
            if (start.level.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(41)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple level conditions)", interactive)));
            if (!StringIsInteger(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(42)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            iValue = StrToInteger(value);
            if (sequence.direction == D_LONG) {
               if (iValue < 0)                         return(_false(ValidateConfig.HandleError("ValidateConfiguration(43)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            }
            else if (iValue > 0)
               iValue = -iValue;
            if (ArraySize(sequence.start.event) != 0)  return(_false(ValidateConfig.HandleError("ValidateConfiguration(44)", "Invalid StartConditions = \""+ StartConditions +"\" (illegal level statement)", interactive)));
            start.level.condition     = true;
            start.level.value         = iValue;
            start.level.condition.txt = key +"("+ iValue +")";
            exprs[i]                  = start.level.condition.txt;
         }
         else                                          return(_false(ValidateConfig.HandleError("ValidateConfiguration(45)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         start.conditions = true;
      }
      if (start.conditions) StartConditions = JoinStrings(exprs, " && ");
      else                  StartConditions = "";
   }


   // (6) StopConditions, OR-verknüpft: "@trend(ALMA:7xD1) || @[bid|ask|price](1.33) || @level(5) || @time(12:00) || @profit(1234[%])"
   // --------------------------------------------------------------------------------------------------------------------------------
   if (!reasonParameters || StopConditions!=last.StopConditions) {
      // Bei Parameteränderung Werte nur übernehmen, wenn sie sich tatsächlich geändert haben, sodaß StopConditions nur bei Änderung (re-)aktiviert werden.
      stop.conditions          = false;
      stop.trend.condition     = false;
      stop.price.condition     = false;
      stop.level.condition     = false;
      stop.time.condition      = false;
      stop.profitAbs.condition = false;
      stop.profitPct.condition = false;

      // (6.1) StopConditions in einzelne Ausdrücke zerlegen
      sizeOfExprs = Explode(StopConditions, "||", exprs, NULL);

      // (6.2) jeden Ausdruck parsen und validieren
      for (i=0; i < sizeOfExprs; i++) {
         stop.conditions = false;                  // im Fehlerfall ist stop.conditions deaktiviert
         expr = StringToLower(StringTrim(exprs[i]));
         if (StringLen(expr) == 0) {
            if (sizeOfExprs > 1)                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(46)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')            return(_false(ValidateConfig.HandleError("ValidateConfiguration(47)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         if (Explode(expr, "(", elems, NULL) != 2)     return(_false(ValidateConfig.HandleError("ValidateConfiguration(48)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         if (!StringEndsWith(elems[1], ")"))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(49)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         key   = StringTrim(elems[0]);
         value = StringTrim(StringLeft(elems[1], -1));
         if (StringLen(value) == 0)                    return(_false(ValidateConfig.HandleError("ValidateConfiguration(50)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         //debug("()   key="+ StringRightPad("\""+ key +"\"", 9, " ") +"   value=\""+ value +"\"");

         if (key == "@trend") {
            if (stop.trend.condition)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(51)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple trend conditions)", interactive)));
            if (Explode(value, ":", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(52)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            key   = StringToUpper(StringTrim(elems[0]));
            value = StringToUpper(elems[1]);
            // key="ALMA"
            if      (key == "SMA" ) stop.trend.method = key;
            else if (key == "EMA" ) stop.trend.method = key;
            else if (key == "SMMA") stop.trend.method = key;
            else if (key == "LWMA") stop.trend.method = key;
            else if (key == "ALMA") stop.trend.method = key;
            else                                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(53)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            // value="7XD1[+2]"
            if (Explode(value, "+", elems, NULL) == 1) {
               stop.trend.lag = 0;
            }
            else {
               value = StringTrim(elems[1]);
               if (!StringIsDigit(value))              return(_false(ValidateConfig.HandleError("ValidateConfiguration(54)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
               stop.trend.lag = StrToInteger(value);
               if (stop.trend.lag < 0)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(55)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
               value = elems[0];
            }
            // value="7XD1"
            if (Explode(value, "X", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(56)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            elems[1]             = StringTrim(elems[1]);
            stop.trend.timeframe = PeriodToId(elems[1]);
            if (stop.trend.timeframe == -1)            return(_false(ValidateConfig.HandleError("ValidateConfiguration(57)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            value = StringTrim(elems[0]);
            if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(58)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(59)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            if (MathModFix(dValue, 0.5) != 0)          return(_false(ValidateConfig.HandleError("ValidateConfiguration(60)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            elems[0] = NumberToStr(dValue, ".+");
            switch (stop.trend.timeframe) {            // Timeframes > H1 auf H1 umrechnen, iCustom() soll unabhängig vom MA mit maximal PERIOD_H1 laufen
               case PERIOD_MN1:                        return(_false(ValidateConfig.HandleError("ValidateConfiguration(61)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
               case PERIOD_H4 : dValue *=   4; stop.trend.timeframe = PERIOD_H1; break;
               case PERIOD_D1 : dValue *=  24; stop.trend.timeframe = PERIOD_H1; break;
               case PERIOD_W1 : dValue *= 120; stop.trend.timeframe = PERIOD_H1; break;
            }
            stop.trend.periods       = NormalizeDouble(dValue, 1);
            stop.trend.timeframeFlag = PeriodFlag(stop.trend.timeframe);
            stop.trend.condition     = true;
            stop.trend.condition.txt = "@trend("+ stop.trend.method +":"+ elems[0] +"x"+ elems[1] + ifString(!stop.trend.lag, "", "+"+ stop.trend.lag) +")";
            exprs[i]                 = stop.trend.condition.txt;
         }

         else if (key=="@bid" || key=="@ask" || key=="@price") {
            if (stop.price.condition)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(62)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple price conditions)", interactive)));
            value = StringReplace(value, "'", "");
            if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(63)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(64)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            stop.price.condition = true;
            stop.price.value     = NormalizeDouble(dValue, Digits);
            if      (key == "@bid"  ) stop.price.type = SCP_BID;
            else if (key == "@ask"  ) stop.price.type = SCP_ASK;
            else if (key == "@price") stop.price.type = SCP_MEDIAN;
            exprs[i] = NumberToStr(stop.price.value, PriceFormat);
            if (StringEndsWith(exprs[i], "'0"))        // 0-Subpips "'0" für bessere Lesbarkeit entfernen
               exprs[i] = StringLeft(exprs[i], -2);
            stop.price.condition.txt = key +"("+ exprs[i] +")";
            exprs[i]                 = stop.price.condition.txt;
         }

         else if (key == "@level") {
            if (stop.level.condition)                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(65)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple level conditions)", interactive)));
            if (!StringIsInteger(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(66)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            iValue = StrToInteger(value);
            if (sequence.direction == D_LONG) {
               if (iValue < 0)                         return(_false(ValidateConfig.HandleError("ValidateConfiguration(67)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            }
            else if (iValue > 0)
               iValue = -iValue;
            stop.level.condition     = true;
            stop.level.value         = iValue;
            stop.level.condition.txt = key +"("+ iValue +")";
            exprs[i]                 = stop.level.condition.txt;
         }

         else if (key == "@time") {
            if (stop.time.condition)                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(68)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple time conditions)", interactive)));
            time = StrToTime(value);
            if (IsError(GetLastError()))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(69)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            // TODO: Validierung von @time unzureichend
            stop.time.condition     = true;
            stop.time.value         = time;
            stop.time.condition.txt = key +"("+ TimeToStr(time) +")";
            exprs[i]                = stop.time.condition.txt;
         }

         else if (key == "@profit") {
            if (stop.profitAbs.condition || stop.profitPct.condition)
                                                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(70)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple profit conditions)", interactive)));
            sizeOfElems = Explode(value, "%", elems, NULL);
            if (sizeOfElems > 2)                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(71)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            value = StringTrim(elems[0]);
            if (StringLen(value) == 0)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(72)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(73)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (sizeOfElems == 1) {
               stop.profitAbs.condition     = true;
               stop.profitAbs.value         = NormalizeDouble(dValue, 2);
               stop.profitAbs.condition.txt = key +"("+ NumberToStr(dValue, ".2") +")";
               exprs[i]                     = stop.profitAbs.condition.txt;
            }
            else {
               if (dValue <= 0)                        return(_false(ValidateConfig.HandleError("ValidateConfiguration(74)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
               stop.profitPct.condition     = true;
               stop.profitPct.value         = dValue;
               stop.profitPct.condition.txt = key +"("+ NumberToStr(dValue, ".+") +"%)";
               exprs[i]                     = stop.profitPct.condition.txt;
            }
         }
         else                                          return(_false(ValidateConfig.HandleError("ValidateConfiguration(75)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         stop.conditions = true;
      }
      if (stop.conditions) StopConditions = JoinStrings(exprs, " || ");
      else                 StopConditions = "";
   }


   // (7) StartStop.Color
   if (StartStop.Color == 0xFF000000)                                   // kann vom Terminal falsch gesetzt worden sein
      StartStop.Color = CLR_NONE;
   if (StartStop.Color < CLR_NONE || StartStop.Color > C'255,255,255')  // kann nur nicht-interaktiv falsch reinkommen
                                                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(76)", "Invalid StartStop.Color = 0x"+ IntToHexStr(StartStop.Color), interactive)));

   // (8) __STATUS_INVALID_INPUT zurücksetzen
   if (interactive)
      __STATUS_INVALID_INPUT = false;

   return(!last_error|catch("ValidateConfiguration(77)"));
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

   if (__LOG) log(StringConcatenate(location, "   ", message), ERR_INVALID_INPUT_PARAMVALUE);
   ForceSound("chord.wav");
   int button = ForceMessageBox(__NAME__ +" - "+ location, message, MB_ICONERROR|MB_RETRYCANCEL);

   __STATUS_INVALID_INPUT = true;

   if (button == IDRETRY)
      __STATUS_RELAUNCH_INPUT = true;

   return(NO_ERROR);
}


/**
 * Speichert die aktuelle Konfiguration zwischen, um sie bei Fehleingaben nach Parameteränderungen restaurieren zu können.
 */
void StoreConfiguration(bool save=true) {
   static string   _Sequence.ID;
   static string   _GridDirection;
   static int      _GridSize;
   static double   _LotSize;
   static string   _StartConditions;
   static string   _StopConditions;
   static color    _StartStop.Color;
   static string   _Sequence.StatusLocation;

   static int      _sequence.direction;

   static bool     _start.conditions;

   static bool     _start.trend.condition;
   static string   _start.trend.condition.txt;
   static double   _start.trend.periods;
   static int      _start.trend.timeframe;
   static int      _start.trend.timeframeFlag;
   static string   _start.trend.method;
   static int      _start.trend.lag;

   static bool     _start.price.condition;
   static string   _start.price.condition.txt;
   static int      _start.price.type;
   static double   _start.price.value;

   static bool     _start.time.condition;
   static string   _start.time.condition.txt;
   static datetime _start.time.value;

   static bool     _start.level.condition;
   static string   _start.level.condition.txt;
   static int      _start.level.value;

   static bool     _stop.conditions;

   static bool     _stop.trend.condition;
   static string   _stop.trend.condition.txt;
   static double   _stop.trend.periods;
   static int      _stop.trend.timeframe;
   static int      _stop.trend.timeframeFlag;
   static string   _stop.trend.method;
   static int      _stop.trend.lag;

   static bool     _stop.price.condition;
   static string   _stop.price.condition.txt;
   static int      _stop.price.type;
   static double   _stop.price.value;

   static bool     _stop.level.condition;
   static string   _stop.level.condition.txt;
   static int      _stop.level.value;

   static bool     _stop.time.condition;
   static string   _stop.time.condition.txt;
   static datetime _stop.time.value;

   static bool     _stop.profitAbs.condition;
   static string   _stop.profitAbs.condition.txt;
   static double   _stop.profitAbs.value;

   static bool     _stop.profitPct.condition;
   static string   _stop.profitPct.condition.txt;
   static double   _stop.profitPct.value;

   if (save) {
      _Sequence.ID                  = StringConcatenate(Sequence.ID,             "");  // Pointer-Bug bei String-Inputvariablen (siehe MQL.doc)
      _GridDirection                = StringConcatenate(GridDirection,           "");
      _GridSize                     = GridSize;
      _LotSize                      = LotSize;
      _StartConditions              = StringConcatenate(StartConditions,         "");
      _StopConditions               = StringConcatenate(StopConditions,          "");
      _StartStop.Color              = StartStop.Color;
      _Sequence.StatusLocation      = StringConcatenate(Sequence.StatusLocation, "");

      _sequence.direction           = sequence.direction;

      _start.conditions             = start.conditions;

      _start.trend.condition        = start.trend.condition;
      _start.trend.condition.txt    = start.trend.condition.txt;
      _start.trend.periods          = start.trend.periods;
      _start.trend.timeframe        = start.trend.timeframe;
      _start.trend.timeframeFlag    = start.trend.timeframeFlag;
      _start.trend.method           = start.trend.method;
      _start.trend.lag              = start.trend.lag;

      _start.price.condition        = start.price.condition;
      _start.price.condition.txt    = start.price.condition.txt;
      _start.price.type             = start.price.type;
      _start.price.value            = start.price.value;

      _start.time.condition         = start.time.condition;
      _start.time.condition.txt     = start.time.condition.txt;
      _start.time.value             = start.time.value;

      _start.level.condition        = start.level.condition;
      _start.level.condition.txt    = start.level.condition.txt;
      _start.level.value            = start.level.value;

      _stop.conditions              = stop.conditions;

      _stop.trend.condition         = stop.trend.condition;
      _stop.trend.condition.txt     = stop.trend.condition.txt;
      _stop.trend.periods           = stop.trend.periods;
      _stop.trend.timeframe         = stop.trend.timeframe;
      _stop.trend.timeframeFlag     = stop.trend.timeframeFlag;
      _stop.trend.method            = stop.trend.method;
      _stop.trend.lag               = stop.trend.lag;

      _stop.price.condition         = stop.price.condition;
      _stop.price.condition.txt     = stop.price.condition.txt;
      _stop.price.type              = stop.price.type;
      _stop.price.value             = stop.price.value;

      _stop.level.condition         = stop.level.condition;
      _stop.level.condition.txt     = stop.level.condition.txt;
      _stop.level.value             = stop.level.value;

      _stop.time.condition          = stop.time.condition;
      _stop.time.condition.txt      = stop.time.condition.txt;
      _stop.time.value              = stop.time.value;

      _stop.profitAbs.condition     = stop.profitAbs.condition;
      _stop.profitAbs.condition.txt = stop.profitAbs.condition.txt;
      _stop.profitAbs.value         = stop.profitAbs.value;

      _stop.profitPct.condition     = stop.profitPct.condition;
      _stop.profitPct.condition.txt = stop.profitPct.condition.txt;
      _stop.profitPct.value         = stop.profitPct.value;
   }
   else {
      Sequence.ID                   = _Sequence.ID;
      GridDirection                 = _GridDirection;
      GridSize                      = _GridSize;
      LotSize                       = _LotSize;
      StartConditions               = _StartConditions;
      StopConditions                = _StopConditions;
      StartStop.Color               = _StartStop.Color;
      Sequence.StatusLocation       = _Sequence.StatusLocation;

      sequence.direction            = _sequence.direction;

      start.conditions              = _start.conditions;

      start.trend.condition         = _start.trend.condition;
      start.trend.condition.txt     = _start.trend.condition.txt;
      start.trend.periods           = _start.trend.periods;
      start.trend.timeframe         = _start.trend.timeframe;
      start.trend.timeframeFlag     = _start.trend.timeframeFlag;
      start.trend.method            = _start.trend.method;
      start.trend.lag               = _start.trend.lag;

      start.price.condition         = _start.price.condition;
      start.price.condition.txt     = _start.price.condition.txt;
      start.price.type              = _start.price.type;
      start.price.value             = _start.price.value;

      start.time.condition          = _start.time.condition;
      start.time.condition.txt      = _start.time.condition.txt;
      start.time.value              = _start.time.value;

      start.level.condition         = _start.level.condition;
      start.level.condition.txt     = _start.level.condition.txt;
      start.level.value             = _start.level.value;

      stop.conditions               = _stop.conditions;

      stop.trend.condition          = _stop.trend.condition;
      stop.trend.condition.txt      = _stop.trend.condition.txt;
      stop.trend.periods            = _stop.trend.periods;
      stop.trend.timeframe          = _stop.trend.timeframe;
      stop.trend.timeframeFlag      = _stop.trend.timeframeFlag;
      stop.trend.method             = _stop.trend.method;
      stop.trend.lag                = _stop.trend.lag;

      stop.price.condition          = _stop.price.condition;
      stop.price.condition.txt      = _stop.price.condition.txt;
      stop.price.type               = _stop.price.type;
      stop.price.value              = _stop.price.value;

      stop.level.condition          = _stop.level.condition;
      stop.level.condition.txt      = _stop.level.condition.txt;
      stop.level.value              = _stop.level.value;

      stop.time.condition           = _stop.time.condition;
      stop.time.condition.txt       = _stop.time.condition.txt;
      stop.time.value               = _stop.time.value;

      stop.profitAbs.condition      = _stop.profitAbs.condition;
      stop.profitAbs.condition.txt  = _stop.profitAbs.condition.txt;
      stop.profitAbs.value          = _stop.profitAbs.value;

      stop.profitPct.condition      = _stop.profitPct.condition;
      stop.profitPct.condition.txt  = _stop.profitPct.condition.txt;
      stop.profitPct.value          = _stop.profitPct.value;
   }
}


/**
 * Restauriert eine zuvor gespeicherte Konfiguration.
 */
void RestoreConfiguration() {
   StoreConfiguration(false);
}


/**
 * Initialisiert die Dateinamensvariablen der Statusdatei mit den Ausgangswerten einer neuen Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool InitStatusLocation() {
   if (__STATUS_ERROR) return( false);
   if (!sequenceId)    return(_false(catch("InitStatusLocation(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   if      (IsTesting()) status.directory = "presets\\";
   else if (IsTest())    status.directory = "presets\\tester\\";
   else                  status.directory = "presets\\"+ ShortAccountCompany() +"\\";

   status.file = StringConcatenate(StringToLower(StdSymbol()), ".SR.", sequenceId, ".set");

   Sequence.StatusLocation = "";
   return(true);
}


/**
 * Aktualisiert die Dateinamensvariablen der Statusdatei.  SaveStatus() erkennt die Änderung und verschiebt die Datei automatisch.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatusLocation() {
   if (__STATUS_ERROR) return( false);
   if (!sequenceId)    return(_false(catch("UpdateStatusLocation(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   // TODO: Prüfen, ob status.file existiert und ggf. aktualisieren

   string startDate = "";

   if      (IsTesting()) status.directory = "presets\\";
   else if (IsTest())    status.directory = "presets\\tester\\";
   else {
      status.directory = "presets\\"+ ShortAccountCompany() +"\\";

      if (sequence.maxLevel != 0) {
         startDate        = TimeToStr(orders.openTime[0], TIME_DATE);
         status.directory = status.directory + startDate +"\\";
      }
   }

   Sequence.StatusLocation = startDate;
   return(true);
}


/**
 * Restauriert anhand der verfügbaren Informationen Ort und Namen der Statusdatei, wird nur aus RestoreStatus() heraus aufgerufen.
 *
 * @return bool - Erfolgsstatus
 */
bool ResolveStatusLocation() {
   if (__STATUS_ERROR)
      return(false);


   // (1) Location-Variablen zurücksetzen
   string location = StringTrim(Sequence.StatusLocation);
   InitStatusLocation();

   string filesDirectory  = StringConcatenate(TerminalPath(), ifString(IsTesting(), "\\tester", "\\experts"), "\\files\\");
   string statusDirectory = GetMqlStatusDirectory();
   string directory, subdirs[], subdir, file="";


   while (true) {
      // (2.1) mit StatusLocation: das angegebene Unterverzeichnis durchsuchen
      if (location != "") {
         directory = StringConcatenate(filesDirectory, statusDirectory, StdSymbol(), "\\", location, "\\");
         if (ResolveStatusLocation.FindFile(directory, file))
            break;
         if (__STATUS_ERROR) return( false);
                             return(_false(catch("ResolveStatusLocation(1)   invalid Sequence.StatusLocation = \""+ location +"\" (status file not found)", ERR_FILE_NOT_FOUND)));
      }

      // (2.2) ohne StatusLocation: zuerst Basisverzeichnis durchsuchen...
      directory = StringConcatenate(filesDirectory, statusDirectory);
      if (ResolveStatusLocation.FindFile(directory, file))
         break;
      if (__STATUS_ERROR) return(false);


      // (2.3) ohne StatusLocation: ...dann Unterverzeichnisse des jeweiligen Symbols durchsuchen
      directory = StringConcatenate(directory, StdSymbol(), "\\");
      int size = FindFileNames(directory +"*", subdirs, FF_DIRSONLY);
      if (size == -1)
         return(_false(SetLastError(stdlib_GetLastError())));
      //debug("ResolveStatusLocation()   subdirs="+ StringsToStr(subdirs, NULL));

      for (int i=0; i < size; i++) {
         subdir = StringConcatenate(directory, subdirs[i], "\\");
         if (ResolveStatusLocation.FindFile(subdir, file)) {
            directory = subdir;
            location  = subdirs[i];
            break;
         }
         if (__STATUS_ERROR) return(false);
      }
      if (StringLen(file) > 0)
         break;
      return(_false(catch("ResolveStatusLocation(2)   status file not found", ERR_FILE_NOT_FOUND)));
   }
   //debug("ResolveStatusLocation()   directory=\""+ directory +"\"  location=\""+ location +"\"  file=\""+ file +"\"");

   status.directory        = StringRight(directory, -StringLen(filesDirectory));
   status.file             = file;
   Sequence.StatusLocation = location;
   //debug("ResolveStatusLocation()   status.directory=\""+ status.directory +"\"  Sequence.StatusLocation=\""+ Sequence.StatusLocation +"\"  status.file=\""+ status.file +"\"");
   return(true);
}


/**
 * Durchsucht das angegebene Verzeichnis nach einer passenden Statusdatei und schreibt das Ergebnis in die übergebene Variable.
 *
 * @param  string directory - vollständiger Name des zu durchsuchenden Verzeichnisses
 * @param  string lpFile    - Zeiger auf Variable zur Aufnahme des gefundenen Dateinamens
 *
 * @return bool - Erfolgsstatus
 */
bool ResolveStatusLocation.FindFile(string directory, string &lpFile) {
   if (__STATUS_ERROR) return( false);
   if (!sequenceId)    return(_false(catch("ResolveStatusLocation.FindFile(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   if (!StringEndsWith(directory, "\\"))
      directory = StringConcatenate(directory, "\\");

   string sequencePattern = StringConcatenate("SR*", sequenceId);                // * steht für [._-] (? für ein einzelnes Zeichen funktioniert nicht)
   string sequenceNames[4];
          sequenceNames[0]= StringConcatenate("SR.", sequenceId, ".");
          sequenceNames[1]= StringConcatenate("SR.", sequenceId, "_");
          sequenceNames[2]= StringConcatenate("SR-", sequenceId, ".");
          sequenceNames[3]= StringConcatenate("SR-", sequenceId, "_");

   string filePattern = StringConcatenate(directory, "*", sequencePattern, "*set");
   string files[];

   int size = FindFileNames(filePattern, files, FF_FILESONLY);                   // Dateien suchen, die den Sequenznamen enthalten und mit "set" enden
   if (size == -1)
      return(_false(SetLastError(stdlib_GetLastError())));

   //debug("ResolveStatusLocation.FindFile()   "+ size +" results for \""+ filePattern +"\"");

   for (int i=0; i < size; i++) {
      if (!StringIStartsWith(files[i], sequenceNames[0])) /*&&*/ if (!StringIStartsWith(files[i], sequenceNames[1])) /*&&*/ if (!StringIStartsWith(files[i], sequenceNames[2])) /*&&*/ if (!StringIStartsWith(files[i], sequenceNames[3]))
         if (!StringIContains(files[i], "."+ sequenceNames[0])) /*&&*/ if (!StringIContains(files[i], "."+ sequenceNames[1])) /*&&*/ if (!StringIContains(files[i], "."+ sequenceNames[2])) /*&&*/ if (!StringIContains(files[i], "."+ sequenceNames[3]))
            continue;
      if (StringIEndsWith(files[i], ".set")) {
         lpFile = files[i];                                                      // Abbruch nach Fund der ersten .set-Datei
         return(true);
      }
   }

   lpFile = "";
   return(false);
}


/**
 * Gibt den MQL-Namen der Statusdatei der Sequenz zurück (relativ zu ".\files\").
 *
 * @return string
 */
string GetMqlStatusFileName() {
   return(StringConcatenate(status.directory, status.file));
}


/**
 * Gibt den vollständigen Namen der Statusdatei der Sequenz zurück (für Windows-Dateifunktionen).
 *
 * @return string
 */
string GetFullStatusFileName() {
   if (IsTesting()) return(StringConcatenate(TerminalPath(), "\\tester\\files\\",  GetMqlStatusFileName()));
   else             return(StringConcatenate(TerminalPath(), "\\experts\\files\\", GetMqlStatusFileName()));
}


/**
 * Gibt den MQL-Namen des Statusverzeichnisses der Sequenz zurück (relativ zu ".\files\").
 *
 * @return string - Verzeichnisname (mit einem Back-Slash endend)
 */
string GetMqlStatusDirectory() {
   return(status.directory);
}


/**
 * Gibt den vollständigen Namen des Statusverzeichnisses der Sequenz zurück (für Windows-Dateifunktionen).
 *
 * @return string - Verzeichnisname (mit einem Back-Slash endend)
 */
string GetFullStatusDirectory() {
   if (IsTesting()) return(StringConcatenate(TerminalPath(), "\\tester\\files\\",  GetMqlStatusDirectory()));
   else             return(StringConcatenate(TerminalPath(), "\\experts\\files\\", GetMqlStatusDirectory()));
}


/**
 * Speichert den aktuellen Sequenzstatus, um später die nahtlose Re-Initialisierung im selben oder einem anderen Terminal
 * zu ermöglichen.
 *
 * @return bool - Erfolgsstatus
 */
bool SaveStatus() {
   if (__STATUS_ERROR)                    return( false);
   if (!sequenceId)                       return(_false(catch("SaveStatus(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));
   if (IsTest()) /*&&*/ if (!IsTesting()) return(true);

   // Im Tester wird der Status zur Performancesteigerung nur beim ersten und letzten Aufruf gespeichert, es sei denn,
   // das Logging ist aktiviert oder die Sequenz wurde bereits gestoppt.
   if (IsTesting()) /*&&*/ if (!__LOG) {
      static bool firstCall = true;
      if (!firstCall) /*&&*/ if (status!=STATUS_STOPPED) /*&&*/ if (__WHEREAMI__!=FUNC_DEINIT)
         return(true);                                               // Speichern überspringen
      firstCall = false;
   }

   /*
   Speichernotwendigkeit der einzelnen Variablen
   ---------------------------------------------
   int      status;                    // nein: kann aus Orderdaten und offenen Positionen restauriert werden
   bool     isTest;                    // nein: wird aus Statusdatei ermittelt

   double   sequence.startEquity;      // ja

   int      sequence.start.event [];   // ja
   datetime sequence.start.time  [];   // ja
   double   sequence.start.price [];   // ja
   double   sequence.start.profit[];   // ja

   int      sequence.stop.event [];    // ja
   datetime sequence.stop.time  [];    // ja
   double   sequence.stop.price [];    // ja
   double   sequence.stop.profit[];    // ja

   bool     start.*.condition;         // nein: wird aus StartConditions abgeleitet
   bool     stop.*.condition;          // nein: wird aus StopConditions abgeleitet

   bool     weekend.stop.active;       // ja

   int      ignorePendingOrders  [];   // optional (wenn belegt)
   int      ignoreOpenPositions  [];   // optional (wenn belegt)
   int      ignoreClosedPositions[];   // optional (wenn belegt)

   int      grid.base.event[];         // ja
   datetime grid.base.time [];         // ja
   double   grid.base.value[];         // ja
   double   grid.base;                 // nein: wird aus Gridbase-History restauriert

   int      sequence.level;            // nein: kann aus Orderdaten restauriert werden
   int      sequence.maxLevel;         // nein: kann aus Orderdaten restauriert werden

   int      sequence.stops;            // nein: kann aus Orderdaten restauriert werden
   double   sequence.stopsPL;          // nein: kann aus Orderdaten restauriert werden
   double   sequence.closedPL;         // nein: kann aus Orderdaten restauriert werden
   double   sequence.floatingPL;       // nein: kann aus offenen Positionen restauriert werden
   double   sequence.totalPL;          // nein: kann aus stopsPL, closedPL und floatingPL restauriert werden

   double   sequence.maxProfit;        // ja
   double   sequence.maxDrawdown;      // ja

   int      orders.ticket      [];     // ja:  0
   int      orders.level       [];     // ja:  1
   double   orders.gridBase    [];     // ja:  2
   int      orders.pendingType [];     // ja:  3
   datetime orders.pendingTime [];     // ja:  4 (kein Event)
   double   orders.pendingPrice[];     // ja:  5
   int      orders.type        [];     // ja:  6
   int      orders.openEvent   [];     // ja:  7
   datetime orders.openTime    [];     // ja:  8 (EV_POSITION_OPEN)
   double   orders.openPrice   [];     // ja:  9
   int      orders.closeEvent  [];     // ja: 10
   datetime orders.closeTime   [];     // ja: 11 (EV_POSITION_STOPOUT | EV_POSITION_CLOSE)
   double   orders.closePrice  [];     // ja: 12
   double   orders.stopLoss    [];     // ja: 13
   bool     orders.clientSL    [];     // ja: 14
   bool     orders.closedBySL  [];     // ja: 15
   double   orders.swap        [];     // ja: 16
   double   orders.commission  [];     // ja: 17
   double   orders.profit      [];     // ja: 18
   */

   // (1) Dateiinhalt zusammenstellen
   string lines[]; ArrayResize(lines, 0);

   // (1.1) Konfiguration
   ArrayPushString(lines, /*string*/   "Account="+          ShortAccountCompany() +":"+ GetAccountNumber());
   ArrayPushString(lines, /*string*/   "Symbol="                 +             Symbol()                   );
   ArrayPushString(lines, /*string*/   "Sequence.ID="            +             Sequence.ID                );
      if (StringLen(Sequence.StatusLocation) > 0)
   ArrayPushString(lines, /*string*/   "Sequence.StatusLocation="+             Sequence.StatusLocation    );
   ArrayPushString(lines, /*string*/   "GridDirection="          +             GridDirection              );
   ArrayPushString(lines, /*int   */   "GridSize="               +             GridSize                   );
   ArrayPushString(lines, /*double*/   "LotSize="                + NumberToStr(LotSize, ".+")             );
      if (start.conditions)
   ArrayPushString(lines, /*string*/   "StartConditions="        +             StartConditions            );
      if (stop.conditions)
   ArrayPushString(lines, /*string*/   "StopConditions="         +             StopConditions             );

   // (1.2) Laufzeit-Variablen
   ArrayPushString(lines, /*double*/   "rt.sequence.startEquity="+ NumberToStr(sequence.startEquity, ".+"));
      string values[]; ArrayResize(values, 0);
      int size = ArraySize(sequence.start.event);
      for (int i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(sequence.start.event[i], "|", sequence.start.time[i], "|", NumberToStr(sequence.start.price[i], ".+"), "|", NumberToStr(sequence.start.profit[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0|0");
   ArrayPushString(lines, /*string*/   "rt.sequence.starts="      + JoinStrings(values, ","));
      ArrayResize(values, 0);
      size = ArraySize(sequence.stop.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(sequence.stop.event[i], "|", sequence.stop.time[i], "|", NumberToStr(sequence.stop.price[i], ".+"), "|", NumberToStr(sequence.stop.profit[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0|0");
   ArrayPushString(lines, /*string*/   "rt.sequence.stops="       + JoinStrings(values, ","));
      if (status==STATUS_STOPPED) /*&&*/ if (IsWeekendStopSignal())
   ArrayPushString(lines, /*int*/      "rt.weekendStop="          +             1);
      if (ArraySize(ignorePendingOrders) > 0)
   ArrayPushString(lines, /*string*/   "rt.ignorePendingOrders="  +    JoinInts(ignorePendingOrders, ",")  );
      if (ArraySize(ignoreOpenPositions) > 0)
   ArrayPushString(lines, /*string*/   "rt.ignoreOpenPositions="  +    JoinInts(ignoreOpenPositions, ",")  );
      if (ArraySize(ignoreClosedPositions) > 0)
   ArrayPushString(lines, /*string*/   "rt.ignoreClosedPositions="+    JoinInts(ignoreClosedPositions, ","));

   ArrayPushString(lines, /*double*/   "rt.sequence.maxProfit="   + NumberToStr(sequence.maxProfit, ".+")  );
   ArrayPushString(lines, /*double*/   "rt.sequence.maxDrawdown=" + NumberToStr(sequence.maxDrawdown, ".+"));

      ArrayResize(values, 0);
      size = ArraySize(grid.base.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(grid.base.event[i], "|", grid.base.time[i], "|", NumberToStr(grid.base.value[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0");
   ArrayPushString(lines, /*string*/   "rt.grid.base="            + JoinStrings(values, ","));

   size = ArraySize(orders.ticket);
   for (i=0; i < size; i++) {
      int      ticket       = orders.ticket      [i];    //  0
      int      level        = orders.level       [i];    //  1
      double   gridBase     = orders.gridBase    [i];    //  2
      int      pendingType  = orders.pendingType [i];    //  3
      datetime pendingTime  = orders.pendingTime [i];    //  4
      double   pendingPrice = orders.pendingPrice[i];    //  5
      int      type         = orders.type        [i];    //  6
      int      openEvent    = orders.openEvent   [i];    //  7
      datetime openTime     = orders.openTime    [i];    //  8
      double   openPrice    = orders.openPrice   [i];    //  9
      int      closeEvent   = orders.closeEvent  [i];    // 10
      datetime closeTime    = orders.closeTime   [i];    // 11
      double   closePrice   = orders.closePrice  [i];    // 12
      double   stopLoss     = orders.stopLoss    [i];    // 13
      bool     clientSL     = orders.clientSL    [i];    // 14
      bool     closedBySL   = orders.closedBySL  [i];    // 15
      double   swap         = orders.swap        [i];    // 16
      double   commission   = orders.commission  [i];    // 17
      double   profit       = orders.profit      [i];    // 18
      ArrayPushString(lines, StringConcatenate("rt.order.", i, "=", ticket, ",", level, ",", NumberToStr(NormalizeDouble(gridBase, Digits), ".+"), ",", pendingType, ",", pendingTime, ",", NumberToStr(NormalizeDouble(pendingPrice, Digits), ".+"), ",", type, ",", openEvent, ",", openTime, ",", NumberToStr(NormalizeDouble(openPrice, Digits), ".+"), ",", closeEvent, ",", closeTime, ",", NumberToStr(NormalizeDouble(closePrice, Digits), ".+"), ",", NumberToStr(NormalizeDouble(stopLoss, Digits), ".+"), ",", clientSL, ",", closedBySL, ",", NumberToStr(swap, ".+"), ",", NumberToStr(commission, ".+"), ",", NumberToStr(profit, ".+")));
      //rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
   }


   // (2) Daten speichern
   int hFile = FileOpen(GetMqlStatusFileName(), FILE_CSV|FILE_WRITE);
   if (hFile < 0)
      return(_false(catch("SaveStatus(2)->FileOpen(\""+ GetMqlStatusFileName() +"\")")));

   for (i=0; i < ArraySize(lines); i++) {
      if (FileWrite(hFile, lines[i]) < 0) {
         catch("SaveStatus(3)->FileWrite(line #"+ (i+1) +")");
         FileClose(hFile);
         return(false);
      }
   }
   FileClose(hFile);

   /*
   // (3) Datei auf Server laden
   int error = UploadStatus(ShortAccountCompany(), AccountNumber(), StdSymbol(), fileName);
   if (IsError(error))
      return(false);
   */

   ArrayResize(lines,  0);
   ArrayResize(values, 0);
   return(!last_error|catch("SaveStatus(4)"));
}


/**
 * Lädt die angegebene Statusdatei auf den Server.
 *
 * @param  string company  - Account-Company
 * @param  int    account  - Account-Number
 * @param  string symbol   - Symbol der Sequenz
 * @param  string filename - Dateiname, relativ zu ".\experts\"
 *
 * @return int - Fehlerstatus
 */
int UploadStatus(string company, int account, string symbol, string filename) {
   if (__STATUS_ERROR) return(last_error);
   if (IsTest())       return(NO_ERROR);

   // TODO: Existenz von wget.exe prüfen

   string parts[]; Explode(filename, "\\", parts, NULL);
   string baseName = ArrayPopString(parts);                          // einfacher Dateiname ohne Verzeichnisse

   // Befehlszeile für Shellaufruf zusammensetzen
          filename     = TerminalPath() +"\\experts\\"+ filename;    // Dateinamen mit vollständigen Pfaden
   string responseFile = filename +".response";
   string logFile      = filename +".log";
   string url          = "http://sub.domain.tld/uploadSRStatus.php?company="+ UrlEncode(company) +"&account="+ account +"&symbol="+ UrlEncode(symbol) +"&name="+ UrlEncode(baseName);
   string cmdLine      = "wget.exe -b \""+ url +"\" --post-file=\""+ filename +"\" --header=\"Content-Type: text/plain\" -O \""+ responseFile +"\" -a \""+ logFile +"\"";

   // Existenz der Datei prüfen
   if (!IsFile(filename))
      return(catch("UploadStatus(1)   file not found \""+ filename +"\"", ERR_FILE_NOT_FOUND));

   // Datei hochladen, WinExec() kehrt ohne zu warten zurück, wget -b beschleunigt zusätzlich
   int error = WinExec(cmdLine, SW_HIDE);                            // SW_SHOWNORMAL|SW_HIDE
   if (error < 32)
      return(catch("UploadStatus(2)->kernel32::WinExec(cmdLine=\""+ cmdLine +"\"), error="+ error +" ("+ ShellExecuteErrorToStr(error) +")", ERR_WIN32_ERROR));

   ArrayResize(parts, 0);
   return(catch("UploadStatus(3)"));
}


/**
 * Liest den Status einer Sequenz ein und restauriert die internen Variablen. Bei fehlender lokaler Statusdatei wird versucht,
 * die Datei vom Server zu laden.
 *
 * @return bool - ob der Status erfolgreich restauriert wurde
 */
bool RestoreStatus() {
   if (__STATUS_ERROR) return( false);
   if (!sequenceId)    return(_false(catch("RestoreStatus(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));


   // (1) Pfade und Dateinamen bestimmen
   string fileName = GetMqlStatusFileName();
   if (!IsMqlFile(fileName))
      if (!ResolveStatusLocation())
         return(false);
   fileName = GetMqlStatusFileName();

   /*
   // (2) bei nicht existierender Datei die Datei vom Server laden
   if (!IsMqlFile(fileName)) {
      if (IsTest())
         return(_false(catch("RestoreStatus(2)   status file \""+ subDir + fileName +"\" for test sequence T"+ sequenceId +" not found", ERR_FILE_NOT_FOUND)));

      // TODO: Existenz von wget.exe prüfen

      // Befehlszeile für Shellaufruf zusammensetzen
      string url        = "http://sub.domain.tld/downloadSRStatus.php?company="+ UrlEncode(ShortAccountCompany()) +"&account="+ AccountNumber() +"&symbol="+ UrlEncode(StdSymbol()) +"&sequence="+ sequenceId;
      string targetFile = fullFileName;
      string logFile    = fullFileName +".log";
      string cmd        = "wget.exe \""+ url +"\" -O \""+ targetFile +"\" -o \""+ logFile +"\"";

      debug("RestoreStatus()   downloading status file for sequence "+ ifString(IsTest(), "T", "") + sequenceId);

      int error = WinExecAndWait(cmd, SW_HIDE);                         // SW_SHOWNORMAL|SW_HIDE
      if (IsError(error))
         return(_false(SetLastError(error)));

      debug("RestoreStatus()   status file for sequence "+ ifString(IsTest(), "T", "") + sequenceId +" successfully downloaded");
      FileDelete(subDir + fileName +".log");
   }
   */
   if (!IsMqlFile(fileName))
      return(_false(catch("RestoreStatus(3)   status file \""+ fileName +"\" not found", ERR_FILE_NOT_FOUND)));


   // (3) Datei einlesen
   string lines[];
   int size = FileReadLines(fileName, lines, true);
   if (size < 0)
      return(_false(SetLastError(stdlib_GetLastError())));
   if (size == 0) {
      FileDelete(fileName);
      return(_false(catch("RestoreStatus(4)   no status for sequence "+ ifString(IsTest(), "T", "") + sequenceId +" not found", ERR_RUNTIME_ERROR)));
   }

   // notwendige Schlüssel definieren
   string keys[] = { "Account", "Symbol", "Sequence.ID", "GridDirection", "GridSize", "LotSize", "rt.sequence.startEquity", "rt.sequence.starts", "rt.sequence.stops", "rt.sequence.maxProfit", "rt.sequence.maxDrawdown", "rt.grid.base" };
   /*                "Account"                 ,                        // Der Compiler kommt mit den Zeilennummern durcheinander,
                     "Symbol"                  ,                        // wenn der Initializer nicht komplett in einer Zeile steht.
                     "Sequence.ID"             ,
                   //"Sequence.Status.Location",                        // optional
                     "GridDirection"           ,
                     "GridSize"                ,
                     "LotSize"                 ,
                   //"StartConditions"         ,                        // optional
                   //"StopConditions"          ,                        // optional
                     ---------------------------
                     "rt.sequence.startEquity" ,
                     "rt.sequence.starts"      ,
                     "rt.sequence.stops"       ,
                   //"rt.weekendStop"          ,                        // optional
                   //"rt.ignorePendingOrders"  ,                        // optional
                   //"rt.ignoreOpenPositions"  ,                        // optional
                   //"rt.ignoreClosedPositions",                        // optional
                     "rt.sequence.maxProfit"   ,
                     "rt.sequence.maxDrawdown" ,
                     "rt.grid.base"            ,
   */


   // (4.1) Nicht-Runtime-Settings auslesen, validieren und übernehmen
   string parts[], key, value, accountValue;
   int    accountLine;

   for (int i=0; i < size; i++) {
      if (StringStartsWith(StringTrim(lines[i]), "#"))                    // Kommentare überspringen
         continue;

      if (Explode(lines[i], "=", parts, 2) < 2)                           return(_false(catch("RestoreStatus(5)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
      key   = StringTrim(parts[0]);
      value = StringTrim(parts[1]);

      if (key == "Account") {
         accountValue = value;
         accountLine  = i;
         ArrayDropString(keys, key);                                      // Abhängigkeit Account <=> Sequence.ID (siehe 4.2)
      }
      else if (key == "Symbol") {
         if (value != Symbol())                                           return(_false(catch("RestoreStatus(6)   symbol mis-match \""+ value +"\"/\""+ Symbol() +"\" in status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         ArrayDropString(keys, key);
      }
      else if (key == "Sequence.ID") {
         value = StringToUpper(value);
         if (StringLeft(value, 1) == "T") {
            isTest = true;
            value  = StringRight(value, -1);
         }
         if (value != StringConcatenate("", sequenceId))                  return(_false(catch("RestoreStatus(7)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         Sequence.ID = ifString(IsTest(), "T", "") + sequenceId;
         ArrayDropString(keys, key);
      }
      else if (key == "Sequence.StatusLocation") {
         Sequence.StatusLocation = value;
      }
      else if (key == "GridDirection") {
         if (value == "")                                                 return(_false(catch("RestoreStatus(8)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         GridDirection = value;
         ArrayDropString(keys, key);
      }
      else if (key == "GridSize") {
         if (!StringIsDigit(value))                                       return(_false(catch("RestoreStatus(9)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         GridSize = StrToInteger(value);
         ArrayDropString(keys, key);
      }
      else if (key == "LotSize") {
         if (!StringIsNumeric(value))                                     return(_false(catch("RestoreStatus(10)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         LotSize = StrToDouble(value);
         ArrayDropString(keys, key);
      }
      else if (key == "StartConditions") {
         StartConditions = value;
      }
      else if (key == "StopConditions") {
         StopConditions = value;
      }
   }

   // (4.2) Abhängigkeiten validieren
   // Account: Eine Testsequenz kann in einem anderen Account visualisiert werden, solange die Zeitzonen beider Accounts übereinstimmen.
   if (accountValue != ShortAccountCompany()+":"+GetAccountNumber()) {
      if (IsTesting() || !IsTest() || !StringIStartsWith(accountValue, ShortAccountCompany()+":"))
                                                                          return(_false(catch("RestoreStatus(11)   account mis-match \""+ ShortAccountCompany() +":"+ GetAccountNumber() +"\"/\""+ accountValue +"\" in status file \""+ fileName +"\" (line \""+ lines[accountLine] +"\")", ERR_RUNTIME_ERROR)));
   }

   // (5.1) Runtime-Settings auslesen, validieren und übernehmen
   ArrayResize(sequence.start.event,  0);
   ArrayResize(sequence.start.time,   0);
   ArrayResize(sequence.start.price,  0);
   ArrayResize(sequence.start.profit, 0);
   ArrayResize(sequence.stop.event,   0);
   ArrayResize(sequence.stop.time,    0);
   ArrayResize(sequence.stop.price,   0);
   ArrayResize(sequence.stop.profit,  0);
   ArrayResize(ignorePendingOrders,   0);
   ArrayResize(ignoreOpenPositions,   0);
   ArrayResize(ignoreClosedPositions, 0);
   ArrayResize(grid.base.event,       0);
   ArrayResize(grid.base.time,        0);
   ArrayResize(grid.base.value,       0);
   lastEventId = 0;

   for (i=0; i < size; i++) {
      if (Explode(lines[i], "=", parts, 2) < 2)                           return(_false(catch("RestoreStatus(12)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
      key   = StringTrim(parts[0]);
      value = StringTrim(parts[1]);

      if (StringStartsWith(key, "rt."))
         if (!RestoreStatus.Runtime(fileName, lines[i], key, value, keys))
            return(false);
   }
   if (ArraySize(keys) > 0)                                               return(_false(catch("RestoreStatus(13)   "+ ifString(ArraySize(keys)==1, "entry", "entries") +" \""+ JoinStrings(keys, "\", \"") +"\" missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));

   // (5.2) Abhängigkeiten validieren
   if (ArraySize(sequence.start.event) != ArraySize(sequence.stop.event)) return(_false(catch("RestoreStatus(14)   sequence.starts("+ ArraySize(sequence.start.event) +") / sequence.stops("+ ArraySize(sequence.stop.event) +") mis-match in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));
   if (IntInArray(orders.ticket, 0))                                      return(_false(catch("RestoreStatus(15)   one or more order entries missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));


   ArrayResize(lines, 0);
   ArrayResize(keys,  0);
   ArrayResize(parts, 0);
   return(!last_error|catch("RestoreStatus(16)"));
}


/**
 * Restauriert eine oder mehrere Laufzeitvariablen.
 *
 * @param  string file   - Name der Statusdatei, aus der die Einstellung stammt (für evt. Fehlermeldung)
 * @param  string line   - Statuszeile der Einstellung                          (für evt. Fehlermeldung)
 * @param  string key    - Schlüssel der Einstellung
 * @param  string value  - Wert der Einstellung
 * @param  string keys[] - Array für Rückmeldung des restaurierten Schlüssels
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreStatus.Runtime(string file, string line, string key, string value, string keys[]) {
   if (__STATUS_ERROR)
      return(false);
   /*
   double   rt.sequence.startEquity=7801.13
   string   rt.sequence.starts=1|1328701713|1.32677|1000,2|1329999999|1.33215|1200
   string   rt.sequence.stops=3|1328701999|1.32734|1200,0|0|0|0
   int      rt.weekendStop=1
   string   rt.ignorePendingOrders=66064890,66064891,66064892
   string   rt.ignoreOpenPositions=66064890,66064891,66064892
   string   rt.ignoreClosedPositions=66064890,66064891,66064892
   double   rt.sequence.maxProfit=200.13
   double   rt.sequence.maxDrawdown=-127.80
   string   rt.grid.base=4|1331710960|1.56743,5|1331711010|1.56714
   string   rt.order.0=62544847,1,1.32067,4,1330932525,1.32067,1,100,1330936196,1.32067,0,101,1330938698,1.31897,1.31897,0,1,0,0,-17
            rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}

      int      ticket       = values[ 0];
      int      level        = values[ 1];
      double   gridBase     = values[ 2];
      int      pendingType  = values[ 3];
      datetime pendingTime  = values[ 4];
      double   pendingPrice = values[ 5];
      int      type         = values[ 6];
      int      openEvent    = values[ 7];
      datetime openTime     = values[ 8];
      double   openPrice    = values[ 9];
      int      closeEvent   = values[10];
      datetime closeTime    = values[11];
      double   closePrice   = values[12];
      double   stopLoss     = values[13];
      bool     clientSL     = values[14];
      bool     closedBySL   = values[15];
      double   swap         = values[16];
      double   commission   = values[17];
      double   profit       = values[18];
   */
   string values[], data[];


   if (key == "rt.sequence.startEquity") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(5)   illegal sequence.startEquity \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequence.startEquity = StrToDouble(value);
      if (LT(sequence.startEquity, 0))                                      return(_false(catch("RestoreStatus.Runtime(6)   illegal sequence.startEquity "+ DoubleToStr(sequence.startEquity, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.starts") {
      // rt.sequence.starts=1|1331710960|1.56743|1000,2|1331711010|1.56714|1200
      int sizeOfValues = Explode(value, ",", values, NULL);
      for (int i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 4)                      return(_false(catch("RestoreStatus.Runtime(7)   illegal number of sequence.starts["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[0];                          // sequence.start.event
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(8)   illegal sequence.start.event["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int startEvent = StrToInteger(value);
         if (startEvent == 0) {
            if (sizeOfValues==1 && values[i]=="0|0|0|0") {
               if (NE(sequence.startEquity, 0))                             return(_false(catch("RestoreStatus.Runtime(9)   sequence.startEquity/sequence.start["+ i +"] mis-match "+ NumberToStr(sequence.startEquity, ".2") +"/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
               break;
            }
            return(_false(catch("RestoreStatus.Runtime(10)   illegal sequence.start.event["+ i +"] "+ startEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         }
         if (EQ(sequence.startEquity, 0))                                   return(_false(catch("RestoreStatus.Runtime(11)   sequence.startEquity/sequence.start["+ i +"] mis-match "+ NumberToStr(sequence.startEquity, ".2") +"/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[1];                          // sequence.start.time
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(12)   illegal sequence.start.time["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime startTime = StrToInteger(value);
         if (!startTime)                                                    return(_false(catch("RestoreStatus.Runtime(13)   illegal sequence.start.time["+ i +"] "+ startTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[2];                          // sequence.start.price
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(15)   illegal sequence.start.price["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double startPrice = StrToDouble(value);
         if (LE(startPrice, 0))                                             return(_false(catch("RestoreStatus.Runtime(16)   illegal sequence.start.price["+ i +"] "+ NumberToStr(startPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[3];                          // sequence.start.profit
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(17)   illegal sequence.start.profit["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double startProfit = StrToDouble(value);

         ArrayPushInt   (sequence.start.event,  startEvent );
         ArrayPushInt   (sequence.start.time,   startTime  );
         ArrayPushDouble(sequence.start.price,  startPrice );
         ArrayPushDouble(sequence.start.profit, startProfit);
         lastEventId = Max(lastEventId, startEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.stops") {
      // rt.sequence.stops=1|1331710960|1.56743|1200,0|0|0|0
      sizeOfValues = Explode(value, ",", values, NULL);
      for (i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 4)                      return(_false(catch("RestoreStatus.Runtime(18)   illegal number of sequence.stops["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[0];                          // sequence.stop.event
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(19)   illegal sequence.stop.event["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int stopEvent = StrToInteger(value);
         if (stopEvent == 0) {
            if (i < sizeOfValues-1)                                         return(_false(catch("RestoreStatus.Runtime(20)   illegal sequence.stop["+ i +"] \""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            if (values[i] != "0|0|0|0")                                     return(_false(catch("RestoreStatus.Runtime(21)   illegal sequence.stop["+ i +"] \""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            if (i==0 && ArraySize(sequence.start.event)==0)
               break;
         }

         value = data[1];                          // sequence.stop.time
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(22)   illegal sequence.stop.time["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime stopTime = StrToInteger(value);
         if (!stopTime && stopEvent!=0)                                     return(_false(catch("RestoreStatus.Runtime(23)   illegal sequence.stop.time["+ i +"] "+ stopTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (i >= ArraySize(sequence.start.event))                          return(_false(catch("RestoreStatus.Runtime(24)   sequence.starts("+ ArraySize(sequence.start.event) +") / sequence.stops("+ sizeOfValues +") mis-match in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (stopTime!=0 && stopTime < sequence.start.time[i])              return(_false(catch("RestoreStatus.Runtime(25)   sequence.start.time["+ i +"]/sequence.stop.time["+ i +"] mis-match '"+ TimeToStr(sequence.start.time[i], TIME_FULL) +"'/'"+ TimeToStr(stopTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[2];                          // sequence.stop.price
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(26)   illegal sequence.stop.price["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double stopPrice = StrToDouble(value);
         if (LT(stopPrice, 0))                                              return(_false(catch("RestoreStatus.Runtime(27)   illegal sequence.stop.price["+ i +"] "+ NumberToStr(stopPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (EQ(stopPrice, 0) && stopEvent!=0)                              return(_false(catch("RestoreStatus.Runtime(28)   sequence.stop.time["+ i +"]/sequence.stop.price["+ i +"] mis-match '"+ TimeToStr(stopTime, TIME_FULL) +"'/"+ NumberToStr(stopPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[3];                          // sequence.stop.profit
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(29)   illegal sequence.stop.profit["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double stopProfit = StrToDouble(value);

         ArrayPushInt   (sequence.stop.event,  stopEvent );
         ArrayPushInt   (sequence.stop.time,   stopTime  );
         ArrayPushDouble(sequence.stop.price,  stopPrice );
         ArrayPushDouble(sequence.stop.profit, stopProfit);
         lastEventId = Max(lastEventId, stopEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (key == "rt.weekendStop") {
      if (!StringIsDigit(value))                                            return(_false(catch("RestoreStatus.Runtime(30)   illegal weekendStop \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      weekend.stop.active = (StrToInteger(value));
   }
   else if (key == "rt.ignorePendingOrders") {
      // rt.ignorePendingOrders=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            string strTicket = StringTrim(values[i]);
            if (!StringIsDigit(strTicket))                                  return(_false(catch("RestoreStatus.Runtime(31)   illegal ticket \""+ strTicket +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            int ticket = StrToInteger(strTicket);
            if (!ticket)                                                    return(_false(catch("RestoreStatus.Runtime(32)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignorePendingOrders, ticket);
         }
      }
   }
   else if (key == "rt.ignoreOpenPositions") {
      // rt.ignoreOpenPositions=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            strTicket = StringTrim(values[i]);
            if (!StringIsDigit(strTicket))                                  return(_false(catch("RestoreStatus.Runtime(33)   illegal ticket \""+ strTicket +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ticket = StrToInteger(strTicket);
            if (!ticket)                                                    return(_false(catch("RestoreStatus.Runtime(34)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignoreOpenPositions, ticket);
         }
      }
   }
   else if (key == "rt.ignoreClosedPositions") {
      // rt.ignoreClosedPositions=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            strTicket = StringTrim(values[i]);
            if (!StringIsDigit(strTicket))                                  return(_false(catch("RestoreStatus.Runtime(35)   illegal ticket \""+ strTicket +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ticket = StrToInteger(strTicket);
            if (!ticket)                                                    return(_false(catch("RestoreStatus.Runtime(36)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignoreClosedPositions, ticket);
         }
      }
   }
   else if (key == "rt.sequence.maxProfit") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(37)   illegal sequence.maxProfit \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequence.maxProfit = StrToDouble(value); SS.MaxProfit();
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequence.maxDrawdown") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(38)   illegal sequence.maxDrawdown \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequence.maxDrawdown = StrToDouble(value); SS.MaxDrawdown();
      ArrayDropString(keys, key);
   }
   else if (key == "rt.grid.base") {
      // rt.grid.base=1|1331710960|1.56743,2|1331711010|1.56714
      sizeOfValues = Explode(value, ",", values, NULL);
      for (i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 3)                      return(_false(catch("RestoreStatus.Runtime(40)   illegal number of grid.base["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[0];                          // GridBase-Event
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(41)   illegal grid.base.event["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int gridBaseEvent = StrToInteger(value);
         int starts = ArraySize(sequence.start.event);
         if (gridBaseEvent == 0) {
            if (sizeOfValues==1 && values[0]=="0|0|0") {
               if (starts > 0)                                              return(_false(catch("RestoreStatus.Runtime(42)   sequence.start/grid.base["+ i +"] mis-match '"+ TimeToStr(sequence.start.time[0], TIME_FULL) +"'/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
               break;
            }                                                               return(_false(catch("RestoreStatus.Runtime(43)   illegal grid.base.event["+ i +"] "+ gridBaseEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         }
         else if (!starts)                                                  return(_false(catch("RestoreStatus.Runtime(44)   sequence.start/grid.base["+ i +"] mis-match "+ starts +"/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[1];                          // GridBase-Zeitpunkt
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(45)   illegal grid.base.time["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime gridBaseTime = StrToInteger(value);
         if (!gridBaseTime)                                                 return(_false(catch("RestoreStatus.Runtime(46)   illegal grid.base.time["+ i +"] "+ gridBaseTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[2];                          // GridBase-Wert
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(47)   illegal grid.base.value["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double gridBaseValue = StrToDouble(value);
         if (LE(gridBaseValue, 0))                                          return(_false(catch("RestoreStatus.Runtime(48)   illegal grid.base.value["+ i +"] "+ NumberToStr(gridBaseValue, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         ArrayPushInt   (grid.base.event, gridBaseEvent);
         ArrayPushInt   (grid.base.time,  gridBaseTime );
         ArrayPushDouble(grid.base.value, gridBaseValue);
         lastEventId = Max(lastEventId, gridBaseEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (StringStartsWith(key, "rt.order.")) {
      // rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
      // Orderindex
      string strIndex = StringRight(key, -9);
      if (!StringIsDigit(strIndex))                                         return(_false(catch("RestoreStatus.Runtime(49)   illegal order index \""+ key +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      i = StrToInteger(strIndex);
      if (ArraySize(orders.ticket) > i) /*&&*/ if (orders.ticket[i]!=0)     return(_false(catch("RestoreStatus.Runtime(50)   duplicate order index "+ key +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // Orderdaten
      if (Explode(value, ",", values, NULL) != 19)                          return(_false(catch("RestoreStatus.Runtime(51)   illegal number of order details ("+ ArraySize(values) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // ticket
      strTicket = StringTrim(values[0]);
      if (!StringIsInteger(strTicket))                                      return(_false(catch("RestoreStatus.Runtime(52)   illegal ticket \""+ strTicket +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ticket = StrToInteger(strTicket);
      if (ticket > 0) {
         if (IntInArray(orders.ticket, ticket))                             return(_false(catch("RestoreStatus.Runtime(53)   duplicate ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      else if (ticket!=-1 && ticket!=-2)                                    return(_false(catch("RestoreStatus.Runtime(54)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // level
      string strLevel = StringTrim(values[1]);
      if (!StringIsInteger(strLevel))                                       return(_false(catch("RestoreStatus.Runtime(55)   illegal order level \""+ strLevel +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int level = StrToInteger(strLevel);
      if (level == 0)                                                       return(_false(catch("RestoreStatus.Runtime(56)   illegal order level "+ level +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // gridBase
      string strGridBase = StringTrim(values[2]);
      if (!StringIsNumeric(strGridBase))                                    return(_false(catch("RestoreStatus.Runtime(57)   illegal order grid base \""+ strGridBase +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double gridBase = StrToDouble(strGridBase);
      if (LE(gridBase, 0))                                                  return(_false(catch("RestoreStatus.Runtime(58)   illegal order grid base "+ NumberToStr(gridBase, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // pendingType
      string strPendingType = StringTrim(values[3]);
      if (!StringIsInteger(strPendingType))                                 return(_false(catch("RestoreStatus.Runtime(59)   illegal pending order type \""+ strPendingType +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int pendingType = StrToInteger(strPendingType);
      if (pendingType!=OP_UNDEFINED && !IsTradeOperation(pendingType))      return(_false(catch("RestoreStatus.Runtime(60)   illegal pending order type \""+ strPendingType +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // pendingTime
      string strPendingTime = StringTrim(values[4]);
      if (!StringIsDigit(strPendingTime))                                   return(_false(catch("RestoreStatus.Runtime(61)   illegal pending order time \""+ strPendingTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime pendingTime = StrToInteger(strPendingTime);
      if (pendingType==OP_UNDEFINED && pendingTime!=0)                      return(_false(catch("RestoreStatus.Runtime(62)   pending order type/time mis-match "+ OperationTypeToStr(pendingType) +"/'"+ TimeToStr(pendingTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType!=OP_UNDEFINED && !pendingTime)                        return(_false(catch("RestoreStatus.Runtime(63)   pending order type/time mis-match "+ OperationTypeToStr(pendingType) +"/"+ pendingTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // pendingPrice
      string strPendingPrice = StringTrim(values[5]);
      if (!StringIsNumeric(strPendingPrice))                                return(_false(catch("RestoreStatus.Runtime(64)   illegal pending order price \""+ strPendingPrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double pendingPrice = StrToDouble(strPendingPrice);
      if (LT(pendingPrice, 0))                                              return(_false(catch("RestoreStatus.Runtime(65)   illegal pending order price "+ NumberToStr(pendingPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType==OP_UNDEFINED && NE(pendingPrice, 0))                 return(_false(catch("RestoreStatus.Runtime(66)   pending order type/price mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType!=OP_UNDEFINED) {
         if (EQ(pendingPrice, 0))                                           return(_false(catch("RestoreStatus.Runtime(67)   pending order type/price mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (NE(pendingPrice, gridBase+level*GridSize*Pips, Digits))        return(_false(catch("RestoreStatus.Runtime(68)   grid base/pending order price mis-match "+ NumberToStr(gridBase, PriceFormat) +"/"+ NumberToStr(pendingPrice, PriceFormat) +" (level "+ level +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }

      // type
      string strType = StringTrim(values[6]);
      if (!StringIsInteger(strType))                                        return(_false(catch("RestoreStatus.Runtime(69)   illegal order type \""+ strType +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int type = StrToInteger(strType);
      if (type!=OP_UNDEFINED && !IsTradeOperation(type))                    return(_false(catch("RestoreStatus.Runtime(70)   illegal order type \""+ strType +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (pendingType == OP_UNDEFINED) {
         if (type == OP_UNDEFINED)                                          return(_false(catch("RestoreStatus.Runtime(71)   pending order type/open order type mis-match "+ OperationTypeToStr(pendingType) +"/"+ OperationTypeToStr(type) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      else if (type != OP_UNDEFINED) {
         if (IsLongTradeOperation(pendingType)!=IsLongTradeOperation(type)) return(_false(catch("RestoreStatus.Runtime(72)   pending order type/open order type mis-match "+ OperationTypeToStr(pendingType) +"/"+ OperationTypeToStr(type) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }

      // openEvent
      string strOpenEvent = StringTrim(values[7]);
      if (!StringIsDigit(strOpenEvent))                                     return(_false(catch("RestoreStatus.Runtime(73)   illegal order open event \""+ strOpenEvent +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int openEvent = StrToInteger(strOpenEvent);
      if (type!=OP_UNDEFINED && !openEvent)                                 return(_false(catch("RestoreStatus.Runtime(74)   illegal order open event "+ openEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openTime
      string strOpenTime = StringTrim(values[8]);
      if (!StringIsDigit(strOpenTime))                                      return(_false(catch("RestoreStatus.Runtime(75)   illegal order open time \""+ strOpenTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime openTime = StrToInteger(strOpenTime);
      if (type==OP_UNDEFINED && openTime!=0)                                return(_false(catch("RestoreStatus.Runtime(76)   order type/time mis-match "+ OperationTypeToStr(type) +"/'"+ TimeToStr(openTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type!=OP_UNDEFINED && !openTime)                                  return(_false(catch("RestoreStatus.Runtime(77)   order type/time mis-match "+ OperationTypeToStr(type) +"/"+ openTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openPrice
      string strOpenPrice = StringTrim(values[9]);
      if (!StringIsNumeric(strOpenPrice))                                   return(_false(catch("RestoreStatus.Runtime(78)   illegal order open price \""+ strOpenPrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double openPrice = StrToDouble(strOpenPrice);
      if (LT(openPrice, 0))                                                 return(_false(catch("RestoreStatus.Runtime(79)   illegal order open price "+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type==OP_UNDEFINED && NE(openPrice, 0))                           return(_false(catch("RestoreStatus.Runtime(80)   order type/price mis-match "+ OperationTypeToStr(type) +"/"+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type!=OP_UNDEFINED && EQ(openPrice, 0))                           return(_false(catch("RestoreStatus.Runtime(81)   order type/price mis-match "+ OperationTypeToStr(type) +"/"+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // closeEvent
      string strCloseEvent = StringTrim(values[10]);
      if (!StringIsDigit(strCloseEvent))                                    return(_false(catch("RestoreStatus.Runtime(84)   illegal order close event \""+ strCloseEvent +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int closeEvent = StrToInteger(strCloseEvent);

      // closeTime
      string strCloseTime = StringTrim(values[11]);
      if (!StringIsDigit(strCloseTime))                                     return(_false(catch("RestoreStatus.Runtime(85)   illegal order close time \""+ strCloseTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime closeTime = StrToInteger(strCloseTime);
      if (closeTime != 0) {
         if (closeTime < pendingTime)                                       return(_false(catch("RestoreStatus.Runtime(86)   pending order time/delete time mis-match '"+ TimeToStr(pendingTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (closeTime < openTime)                                          return(_false(catch("RestoreStatus.Runtime(87)   order open/close time mis-match '"+ TimeToStr(openTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      if (closeTime!=0 && !closeEvent)                                      return(_false(catch("RestoreStatus.Runtime(88)   illegal order close event "+ closeEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // closePrice
      string strClosePrice = StringTrim(values[12]);
      if (!StringIsNumeric(strClosePrice))                                  return(_false(catch("RestoreStatus.Runtime(89)   illegal order close price \""+ strClosePrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double closePrice = StrToDouble(strClosePrice);
      if (LT(closePrice, 0))                                                return(_false(catch("RestoreStatus.Runtime(90)   illegal order close price "+ NumberToStr(closePrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // stopLoss
      string strStopLoss = StringTrim(values[13]);
      if (!StringIsNumeric(strStopLoss))                                    return(_false(catch("RestoreStatus.Runtime(91)   illegal order stop-loss \""+ strStopLoss +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double stopLoss = StrToDouble(strStopLoss);
      if (LE(stopLoss, 0))                                                  return(_false(catch("RestoreStatus.Runtime(92)   illegal order stop-loss "+ NumberToStr(stopLoss, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (NE(stopLoss, gridBase+(level-Sign(level))*GridSize*Pips, Digits)) return(_false(catch("RestoreStatus.Runtime(93)   grid base/stop-loss mis-match "+ NumberToStr(gridBase, PriceFormat) +"/"+ NumberToStr(stopLoss, PriceFormat) +" (level "+ level +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // clientSL
      string strClientSL = StringTrim(values[14]);
      if (!StringIsDigit(strClientSL))                                      return(_false(catch("RestoreStatus.Runtime(94)   illegal clientSL value \""+ strClientSL +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      bool clientSL = _bool(StrToInteger(strClientSL));

      // closedBySL
      string strClosedBySL = StringTrim(values[15]);
      if (!StringIsDigit(strClosedBySL))                                    return(_false(catch("RestoreStatus.Runtime(95)   illegal closedBySL value \""+ strClosedBySL +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      bool closedBySL = _bool(StrToInteger(strClosedBySL));

      // swap
      string strSwap = StringTrim(values[16]);
      if (!StringIsNumeric(strSwap))                                        return(_false(catch("RestoreStatus.Runtime(96)   illegal order swap \""+ strSwap +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double swap = StrToDouble(strSwap);
      if (type==OP_UNDEFINED && NE(swap, 0))                                return(_false(catch("RestoreStatus.Runtime(97)   pending order/swap mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(swap, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // commission
      string strCommission = StringTrim(values[17]);
      if (!StringIsNumeric(strCommission))                                  return(_false(catch("RestoreStatus.Runtime(98)   illegal order commission \""+ strCommission +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double commission = StrToDouble(strCommission);
      if (type==OP_UNDEFINED && NE(commission, 0))                          return(_false(catch("RestoreStatus.Runtime(99)   pending order/commission mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(commission, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // profit
      string strProfit = StringTrim(values[18]);
      if (!StringIsNumeric(strProfit))                                      return(_false(catch("RestoreStatus.Runtime(100)   illegal order profit \""+ strProfit +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double profit = StrToDouble(strProfit);
      if (type==OP_UNDEFINED && NE(profit, 0))                              return(_false(catch("RestoreStatus.Runtime(101)   pending order/profit mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(profit, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));


      // Daten speichern
      Grid.SetData(i, ticket, level, gridBase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit);
      lastEventId = Max(lastEventId, Max(openEvent, closeEvent));
      //debug("RestoreStatus.Runtime()   #"+ ticket +"  level="+ level +"  gridBase="+ NumberToStr(gridBase, PriceFormat) +"  pendingType="+ OperationTypeToStr(pendingType) +"  pendingTime="+ ifString(!pendingTime, 0, "'"+ TimeToStr(pendingTime, TIME_FULL) +"'") +"  pendingPrice="+ NumberToStr(pendingPrice, PriceFormat) +"  type="+ OperationTypeToStr(type) +"  openEvent="+ openEvent +"  openTime="+ ifString(!openTime, 0, "'"+ TimeToStr(openTime, TIME_FULL) +"'") +"  openPrice="+ NumberToStr(openPrice, PriceFormat) +"  closeEvent="+ closeEvent +"  closeTime="+ ifString(!closeTime, 0, "'"+ TimeToStr(closeTime, TIME_FULL) +"'") +"  closePrice="+ NumberToStr(closePrice, PriceFormat) +"  stopLoss="+ NumberToStr(stopLoss, PriceFormat) +"  clientSL="+ BoolToStr(clientSL) +"  closedBySL="+ BoolToStr(closedBySL) +"  swap="+ DoubleToStr(swap, 2) +"  commission="+ DoubleToStr(commission, 2) +"  profit="+ DoubleToStr(profit, 2));
      // rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
   }

   ArrayResize(values, 0);
   ArrayResize(data,   0);
   return(!last_error|catch("RestoreStatus.Runtime(102)"));
}


/**
 * Gleicht den in der Instanz gespeicherten Laufzeitstatus mit den Online-Daten der laufenden Sequenz ab.
 * Aufruf nur direkt nach ValidateConfiguration()
 *
 * @return bool - Erfolgsstatus
 */
bool SynchronizeStatus() {
   if (__STATUS_ERROR)
      return(false);

   bool permanentStatusChange, permanentTicketChange, pendingOrder, openPosition;

   int orphanedPendingOrders  []; ArrayResize(orphanedPendingOrders,   0);
   int orphanedOpenPositions  []; ArrayResize(orphanedOpenPositions,   0);
   int orphanedClosedPositions[]; ArrayResize(orphanedClosedPositions, 0);

   int closed[][2], close[2], sizeOfTickets=ArraySize(orders.ticket); ArrayResize(closed, 0);


   // (1.1) alle offenen Tickets in Datenarrays synchronisieren, gestrichene PendingOrders löschen
   for (int i=0; i < sizeOfTickets; i++) {
      if (orders.ticket[i] < 0)                                            // client-seitige PendingOrders überspringen
         continue;

      if (!IsTest() || !IsTesting()) {                                     // keine Synchronization für abgeschlossene Tests
         if (orders.closeTime[i] == 0) {
            if (!IsTicket(orders.ticket[i])) {                             // bei fehlender History zur Erweiterung auffordern
               ForceSound("notify.wav");
               int button = ForceMessageBox(__NAME__ +" - SynchronizeStatus()", "Ticket #"+ orders.ticket[i] +" not found.\nPlease expand the available trade history.", MB_ICONERROR|MB_RETRYCANCEL);
               if (button != IDRETRY)
                  return(!SetLastError(ERR_CANCELLED_BY_USER));
               return(SynchronizeStatus());
            }
            if (!SelectTicket(orders.ticket[i], "SynchronizeStatus(1)   cannot synchronize "+ OperationTypeDescription(ifInt(orders.type[i]==OP_UNDEFINED, orders.pendingType[i], orders.type[i])) +" order (#"+ orders.ticket[i] +" not found)"))
               return(false);
            if (!Sync.UpdateOrder(i, permanentTicketChange))
               return(false);
            permanentStatusChange = permanentStatusChange || permanentTicketChange;
         }
      }

      if (orders.closeTime[i] != 0) {
         if (orders.type[i] == OP_UNDEFINED) {
            if (!Grid.DropData(i))                                      // geschlossene PendingOrders löschen
               return(false);
            sizeOfTickets--; i--;
            permanentStatusChange = true;
         }
         else if (!orders.closedBySL[i]) /*&&*/ if (orders.closeEvent[i]==0) {
            close[0] = orders.closeTime[i];                             // bei StopSequence() geschlossene Position: Ticket zur späteren Vergabe der Event-ID zwichenspeichern
            close[1] = orders.ticket   [i];
            ArrayPushIntArray(closed, close);
         }
      }
   }

   // (1.2) Event-IDs geschlossener Positionen setzen (erst nach evt. ausgestoppten Positionen)
   int sizeOfClosed = ArrayRange(closed, 0);
   if (sizeOfClosed > 0) {
      ArraySort(closed);
      for (i=0; i < sizeOfClosed; i++) {
         int n = SearchIntArray(orders.ticket, closed[i][1]);
         if (n == -1)
            return(_false(catch("SynchronizeStatus(2)   closed ticket #"+ closed[i][1] +" not found in grid arrays", ERR_RUNTIME_ERROR)));
         orders.closeEvent[n] = CreateEventId();
      }
      ArrayResize(closed, 0);
      ArrayResize(close,  0);
   }

   // (1.3) alle erreichbaren Tickets der Sequenz auf lokale Referenz überprüfen (außer für abgeschlossene Tests)
   if (!IsTest() || IsTesting()) {
      for (i=OrdersTotal()-1; i >= 0; i--) {                               // offene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))                  // FALSE: während des Auslesens wurde in einem anderen Thread eine offene Order entfernt
            continue;
         if (IsMyOrder(sequenceId)) /*&&*/ if (!IntInArray(orders.ticket, OrderTicket())) {
            pendingOrder = IsPendingTradeOperation(OrderType());           // kann PendingOrder oder offene Position sein
            openPosition = !pendingOrder;
            if (pendingOrder) /*&&*/ if (!IntInArray(ignorePendingOrders, OrderTicket())) ArrayPushInt(orphanedPendingOrders, OrderTicket());
            if (openPosition) /*&&*/ if (!IntInArray(ignoreOpenPositions, OrderTicket())) ArrayPushInt(orphanedOpenPositions, OrderTicket());
         }
      }

      for (i=OrdersHistoryTotal()-1; i >= 0; i--) {                        // geschlossene Tickets
         if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))                 // FALSE: während des Auslesens wurde der Anzeigezeitraum der History verändert
            continue;
         if (IsPendingTradeOperation(OrderType()))                         // gestrichene PendingOrders ignorieren
            continue;
         if (IsMyOrder(sequenceId)) /*&&*/ if (!IntInArray(orders.ticket, OrderTicket())) {
            if (!IntInArray(ignoreClosedPositions, OrderTicket()))         // kann nur geschlossene Position sein
               ArrayPushInt(orphanedClosedPositions, OrderTicket());
         }
      }
   }

   // (1.4) Vorgehensweise für verwaiste Tickets erfragen
   int size = ArraySize(orphanedPendingOrders);                         // TODO: Ignorieren nicht möglich; wenn die Tickets übernommen werden sollen,
   if (size > 0) {                                                      //       müssen sie richtig einsortiert werden.
      return(_false(catch("SynchronizeStatus(3)   unknown pending orders found: #"+ JoinInts(orphanedPendingOrders, ", #"), ERR_RUNTIME_ERROR)));
      //ArraySort(orphanedPendingOrders);
      //ForceSound("notify.wav");
      //int button = ForceMessageBox(__NAME__ +" - SynchronizeStatus()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Orphaned pending order"+ ifString(size==1, "", "s") +" found: #"+ JoinInts(orphanedPendingOrders, ", #") +"\nDo you want to ignore "+ ifString(size==1, "it", "them") +"?", MB_ICONWARNING|MB_OKCANCEL);
      //if (button != IDOK) {
      //   SetLastError(ERR_CANCELLED_BY_USER);
      //   return(_false(catch("SynchronizeStatus(4)")));
      //}
      ArrayResize(orphanedPendingOrders, 0);
   }
   size = ArraySize(orphanedOpenPositions);                             // TODO: Ignorieren nicht möglich; wenn die Tickets übernommen werden sollen,
   if (size > 0) {                                                      //       müssen sie richtig einsortiert werden.
      return(_false(catch("SynchronizeStatus(5)   unknown open positions found: #"+ JoinInts(orphanedOpenPositions, ", #"), ERR_RUNTIME_ERROR)));
      //ArraySort(orphanedOpenPositions);
      //ForceSound("notify.wav");
      //button = ForceMessageBox(__NAME__ +" - SynchronizeStatus()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Orphaned open position"+ ifString(size==1, "", "s") +" found: #"+ JoinInts(orphanedOpenPositions, ", #") +"\nDo you want to ignore "+ ifString(size==1, "it", "them") +"?", MB_ICONWARNING|MB_OKCANCEL);
      //if (button != IDOK) {
      //   SetLastError(ERR_CANCELLED_BY_USER);
      //   return(_false(catch("SynchronizeStatus(6)")));
      //}
      ArrayResize(orphanedOpenPositions, 0);
   }
   size = ArraySize(orphanedClosedPositions);
   if (size > 0) {
      ArraySort(orphanedClosedPositions);
      ForceSound("notify.wav");
      button = ForceMessageBox(__NAME__ +" - SynchronizeStatus()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Orphaned closed position"+ ifString(size==1, "", "s") +" found: #"+ JoinInts(orphanedClosedPositions, ", #") +"\nDo you want to ignore "+ ifString(size==1, "it", "them") +"?", MB_ICONWARNING|MB_OKCANCEL);
      if (button != IDOK) {
         SetLastError(ERR_CANCELLED_BY_USER);
         return(_false(catch("SynchronizeStatus(7)")));
      }
      MergeIntArrays(ignoreClosedPositions, orphanedClosedPositions, ignoreClosedPositions);
      ArraySort(ignoreClosedPositions);
      permanentStatusChange = true;
      ArrayResize(orphanedClosedPositions, 0);
   }

   if (ArraySize(sequence.start.event) > 0) /*&&*/ if (ArraySize(grid.base.event)==0)
      return(_false(catch("SynchronizeStatus(8)   illegal number of grid.base events = "+ 0, ERR_RUNTIME_ERROR)));


   // (2) Status und Variablen synchronisieren
   /*int   */ status              = STATUS_WAITING;
   /*int   */ lastEventId         = 0;
   /*int   */ sequence.level      = 0;
   /*int   */ sequence.maxLevel   = 0;
   /*int   */ sequence.stops      = 0;
   /*double*/ sequence.stopsPL    = 0;
   /*double*/ sequence.closedPL   = 0;
   /*double*/ sequence.floatingPL = 0;
   /*double*/ sequence.totalPL    = 0;

   datetime   stopTime;
   double     stopPrice;

   // (2.1)
   if (!Sync.ProcessEvents(stopTime, stopPrice))
      return(false);

   // (2.2) Wurde die Sequenz außerhalb gestoppt, EV_SEQUENCE_STOP erzeugen
   if (status == STATUS_STOPPING) {
      i = ArraySize(sequence.stop.event) - 1;
      if (sequence.stop.time[i] != 0)
         return(_false(catch("SynchronizeStatus(9)   unexpected sequence.stop.time = "+ IntsToStr(sequence.stop.time, NULL), ERR_RUNTIME_ERROR)));

      sequence.stop.event [i] = CreateEventId();
      sequence.stop.time  [i] = stopTime;
      sequence.stop.price [i] = NormalizeDouble(stopPrice, Digits);
      sequence.stop.profit[i] = sequence.totalPL;

      if (!StopSequence.LimitStopPrice())                            //  StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
         return(false);

      status                = STATUS_STOPPED;
      permanentStatusChange = true;
   }


   // (3) Daten für Wochenend-Pause aktualisieren
   if (weekend.stop.active) /*&&*/ if (status!=STATUS_STOPPED)
      return(_false(catch("SynchronizeStatus(10)   weekend.stop.active="+ weekend.stop.active +" / status="+ StatusToStr(status)+ " mis-match", ERR_RUNTIME_ERROR)));

   if      (status == STATUS_PROGRESSING) UpdateWeekendStop();
   else if (status == STATUS_STOPPED)
      if (weekend.stop.active)            UpdateWeekendResumeTime();


   // (4) permanente Statusänderungen speichern
   if (permanentStatusChange)
      if (!SaveStatus())
         return(false);


   // (5) Anzeigen aktualisieren, ShowStatus() folgt nach Funktionsende
   SS.All();
   RedrawStartStop();
   RedrawOrders();

   return(!last_error|catch("SynchronizeStatus(11)"));
}


/**
 * Aktualisiert die Daten des lokal als offen markierten Tickets mit dem Online-Status. Wird nur in SynchronizeStatus() verwendet.
 *
 * @param  int   i                 - Ticketindex
 * @param  bool &lpPermanentChange - Zeiger auf Variable, die anzeigt, ob dauerhafte Ticketänderungen vorliegen
 *
 * @return bool - Erfolgsstatus
 */
bool Sync.UpdateOrder(int i, bool &lpPermanentChange) {
   if (i < 0 || i > ArraySize(orders.ticket)-1) return(_false(catch("Sync.UpdateOrder(1)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (orders.closeTime[i] != 0)                return(_false(catch("Sync.UpdateOrder(2)   cannot update ticket #"+ orders.ticket[i] +" (marked as closed in grid arrays)", ERR_RUNTIME_ERROR)));

   // das Ticket ist selektiert
   bool   wasPending = orders.type[i] == OP_UNDEFINED;               // vormals PendingOrder
   bool   wasOpen    = !wasPending;                                  // vormals offene Position
   bool   isPending  = IsPendingTradeOperation(OrderType());         // jetzt PendingOrder
   bool   isClosed   = OrderCloseTime() != 0;                        // jetzt geschlossen oder gestrichen
   bool   isOpen     = !isPending && !isClosed;                      // jetzt offene Position
   double lastSwap   = orders.swap[i];


   // (1) Ticketdaten aktualisieren
    //orders.ticket      [i]                                         // unverändert
    //orders.level       [i]                                         // unverändert
    //orders.gridBase    [i]                                         // unverändert

   if (isPending) {
    //orders.pendingType [i]                                         // unverändert
    //orders.pendingTime [i]                                         // unverändert
      orders.pendingPrice[i] = OrderOpenPrice();
   }
   else if (wasPending) {
      orders.type        [i] = OrderType();
      orders.openEvent   [i] = CreateEventId();
      orders.openTime    [i] = OrderOpenTime();
      orders.openPrice   [i] = OrderOpenPrice();
   }

   if (EQ(OrderStopLoss(), 0)) {
      if (!orders.clientSL[i]) {
         orders.stopLoss [i] = NormalizeDouble(grid.base + (orders.level[i]-Sign(orders.level[i]))*GridSize*Pips, Digits);
         orders.clientSL [i] = true;
         lpPermanentChange   = true;
      }
   }
   else {
      orders.stopLoss    [i] = OrderStopLoss();
      if (orders.clientSL[i]) {
         orders.clientSL [i] = false;
         lpPermanentChange   = true;
      }
   }

   if (isClosed) {
      orders.closeTime   [i] = OrderCloseTime();
      orders.closePrice  [i] = OrderClosePrice();
      orders.closedBySL  [i] = IsOrderClosedBySL();
      if (orders.closedBySL[i])
         orders.closeEvent[i] = CreateEventId();                     // Event-IDs für ausgestoppte Positionen werden sofort, für geschlossene Positionen erst später vergeben.
   }

   if (!isPending) {
      orders.swap        [i] = OrderSwap();
      orders.commission  [i] = OrderCommission(); sequence.commission = OrderCommission(); SS.LotSize();
      orders.profit      [i] = OrderProfit();
   }

   // (2) lpPermanentChange aktualisieren
   if      (wasPending) lpPermanentChange = lpPermanentChange || isOpen || isClosed;
   else if (  isClosed) lpPermanentChange = true;
   else                 lpPermanentChange = lpPermanentChange || NE(lastSwap, OrderSwap());

   return(!last_error|catch("Sync.UpdateOrder(3)"));
}


/**
 * Fügt den breakeven-relevanten Events ein weiteres hinzu.
 *
 * @param  double   events[]   - Event-Array
 * @param  int      id         - Event-ID
 * @param  datetime time       - Zeitpunkt des Events
 * @param  int      type       - Event-Typ
 * @param  double   gridBase   - Gridbasis des Events
 * @param  int      index      - Index des originären Datensatzes innerhalb des entsprechenden Arrays
 */
void Sync.PushEvent(double &events[][], int id, datetime time, int type, double gridBase, int index) {
   if (type==EV_SEQUENCE_STOP) /*&&*/ if (!time)
      return;                                                        // nicht initialisierte Sequenz-Stops ignorieren (ggf. immer der letzte Stop)

   int size = ArrayRange(events, 0);
   ArrayResize(events, size+1);

   events[size][0] = id;
   events[size][1] = time;
   events[size][2] = type;
   events[size][3] = gridBase;
   events[size][4] = index;
}


/**
 * Aktualisiert die Daten des lokal als offen markierten Tickets mit dem Online-Status. Wird nur in SynchronizeStatus() verwendet.
 *
 * @param  datetime &sequenceStopTime  - Variable, die die Sequenz-StopTime aufnimmt (falls die Stopdaten fehlen)
 * @param  double   &sequenceStopPrice - Variable, die den Sequenz-StopPrice aufnimmt (falls die Stopdaten fehlen)
 *
 * @return bool - Erfolgsstatus
 */
bool Sync.ProcessEvents(datetime &sequenceStopTime, double &sequenceStopPrice) {
   int    sizeOfTickets = ArraySize(orders.ticket);
   int    openLevels[]; ArrayResize(openLevels, 0);
   double events[][5];  ArrayResize(events,     0);
   bool   pendingOrder, openPosition, closedPosition, closedBySL;


   // (1) Breakeven-relevante Events zusammenstellen
   // (1.1) Sequenzstarts und -stops
   int sizeOfStarts = ArraySize(sequence.start.event);
   for (int i=0; i < sizeOfStarts; i++) {
    //Sync.PushEvent(events, id, time, type, gridBase, index);
      Sync.PushEvent(events, sequence.start.event[i], sequence.start.time[i], EV_SEQUENCE_START, NULL, i);
      Sync.PushEvent(events, sequence.stop.event [i], sequence.stop.time [i], EV_SEQUENCE_STOP,  NULL, i);
   }

   // (1.2) GridBase-Änderungen
   int sizeOfGridBase = ArraySize(grid.base.event);
   for (i=0; i < sizeOfGridBase; i++) {
      Sync.PushEvent(events, grid.base.event[i], grid.base.time[i], EV_GRIDBASE_CHANGE, grid.base.value[i], i);
   }

   // (1.3) Tickets
   for (i=0; i < sizeOfTickets; i++) {
      pendingOrder   = orders.type[i]  == OP_UNDEFINED;
      openPosition   = !pendingOrder   && orders.closeTime[i]==0;
      closedPosition = !pendingOrder   && !openPosition;
      closedBySL     =  closedPosition && orders.closedBySL[i];

      // nach offenen Levels darf keine geschlossene Position folgen
      if (closedPosition && !closedBySL)
         if (ArraySize(openLevels) > 0)                  return(_false(catch("Sync.ProcessEvents(1)   illegal sequence status, both open (#?) and closed (#"+ orders.ticket[i] +") positions found", ERR_RUNTIME_ERROR)));

      if (!pendingOrder) {
         Sync.PushEvent(events, orders.openEvent[i], orders.openTime[i], EV_POSITION_OPEN, NULL, i);

         if (openPosition) {
            if (IntInArray(openLevels, orders.level[i])) return(_false(catch("Sync.ProcessEvents(2)   duplicate order level "+ orders.level[i] +" of open position #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
            ArrayPushInt(openLevels, orders.level[i]);
            sequence.floatingPL = NormalizeDouble(sequence.floatingPL + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
         }
         else if (closedBySL) {
            Sync.PushEvent(events, orders.closeEvent[i], orders.closeTime[i], EV_POSITION_STOPOUT, NULL, i);
         }
         else /*(closed)*/ {
            Sync.PushEvent(events, orders.closeEvent[i], orders.closeTime[i], EV_POSITION_CLOSE, NULL, i);
         }
      }
      if (__STATUS_ERROR) return(false);
   }
   if (ArraySize(openLevels) != 0) {
      int min = openLevels[ArrayMinimum(openLevels)];
      int max = openLevels[ArrayMaximum(openLevels)];
      int maxLevel = Max(Abs(min), Abs(max));
      if (ArraySize(openLevels) != maxLevel) return(_false(catch("Sync.ProcessEvents(3)   illegal sequence status, missing one or more open positions", ERR_RUNTIME_ERROR)));
      ArrayResize(openLevels, 0);
   }


   // (2) Laufzeitvariablen restaurieren
   int      id, lastId, nextId, minute, lastMinute, type, lastType, nextType, index, nextIndex, iPositionMax, ticket, lastTicket, nextTicket, closedPositions, reopenedPositions;
   datetime time, lastTime, nextTime;
   double   gridBase;
   int      orderEvents[] = {EV_POSITION_OPEN, EV_POSITION_STOPOUT, EV_POSITION_CLOSE};
   int      sizeOfEvents = ArrayRange(events, 0);

   // (2.1) Events sortieren
   if (sizeOfEvents > 0) {
      ArraySort(events);
      int firstType = MathRound(events[0][2]);
      if (firstType != EV_SEQUENCE_START) return(_false(catch("Sync.ProcessEvents(4)   illegal first break-even event "+ BreakevenEventToStr(firstType) +" (id="+ Round(events[0][0]) +"   time='"+ TimeToStr(events[0][1], TIME_FULL) +"')", ERR_RUNTIME_ERROR)));
   }

   for (i=0; i < sizeOfEvents; i++) {
      id       = events[i][0];
      time     = events[i][1];
      type     = events[i][2];
      gridBase = events[i][3];
      index    = events[i][4];

      ticket     = 0; if (IntInArray(orderEvents, type)) { ticket = orders.ticket[index]; iPositionMax = Max(iPositionMax, index); }
      nextTicket = 0;
      if (i < sizeOfEvents-1) { nextId = events[i+1][0]; nextTime = events[i+1][1]; nextType = events[i+1][2]; nextIndex = events[i+1][4]; if (IntInArray(orderEvents, nextType)) nextTicket = orders.ticket[nextIndex]; }
      else                    { nextId = 0;              nextTime = 0;              nextType = 0;                                                                                               nextTicket = 0;                        }

      // (2.2) Events auswerten
      // -- EV_SEQUENCE_START --------------
      if (type == EV_SEQUENCE_START) {
         if (i!=0 && status!=STATUS_STOPPED && status!=STATUS_STARTING)         return(_false(catch("Sync.ProcessEvents(5)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         if (status==STATUS_STARTING && reopenedPositions!=Abs(sequence.level)) return(_false(catch("Sync.ProcessEvents(6)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") and before "+ BreakevenEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         reopenedPositions = 0;
         status            = STATUS_PROGRESSING;
         sequence.start.event[index] = id;
      }
      // -- EV_GRIDBASE_CHANGE -------------
      else if (type == EV_GRIDBASE_CHANGE) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STOPPED)              return(_false(catch("Sync.ProcessEvents(7)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         grid.base = gridBase;
         if (status == STATUS_PROGRESSING) {
            if (sequence.level != 0)                                            return(_false(catch("Sync.ProcessEvents(8)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         }
         else { // STATUS_STOPPED
            reopenedPositions = 0;
            status            = STATUS_STARTING;
         }
         grid.base.event[index] = id;
      }
      // -- EV_POSITION_OPEN ---------------
      else if (type == EV_POSITION_OPEN) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STARTING)             return(_false(catch("Sync.ProcessEvents(9)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         if (status == STATUS_PROGRESSING) {                                    // nicht bei PositionReopen
            sequence.level   += Sign(orders.level[index]);
            sequence.maxLevel = ifInt(sequence.direction==D_LONG, Max(sequence.level, sequence.maxLevel), Min(sequence.level, sequence.maxLevel));
         }
         else {
            reopenedPositions++;
         }
         orders.openEvent[index] = id;
      }
      // -- EV_POSITION_STOPOUT ------------
      else if (type == EV_POSITION_STOPOUT) {
         if (status != STATUS_PROGRESSING)                                      return(_false(catch("Sync.ProcessEvents(10)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         sequence.level  -= Sign(orders.level[index]);
         sequence.stops++;
         sequence.stopsPL = NormalizeDouble(sequence.stopsPL + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
         orders.closeEvent[index] = id;
      }
      // -- EV_POSITION_CLOSE --------------
      else if (type == EV_POSITION_CLOSE) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STOPPING)             return(_false(catch("Sync.ProcessEvents(11)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         sequence.closedPL = NormalizeDouble(sequence.closedPL + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
         if (status == STATUS_PROGRESSING)
            closedPositions = 0;
         closedPositions++;
         status = STATUS_STOPPING;
         orders.closeEvent[index] = id;
      }
      // -- EV_SEQUENCE_STOP ---------------
      else if (type == EV_SEQUENCE_STOP) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STOPPING)             return(_false(catch("Sync.ProcessEvents(12)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         if (closedPositions != Abs(sequence.level))                            return(_false(catch("Sync.ProcessEvents(13)   illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") and before "+ BreakevenEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ sequence.level, ERR_RUNTIME_ERROR)));
         closedPositions = 0;
         status = STATUS_STOPPED;
         sequence.stop.event[index] = id;
      }
      // -----------------------------------
      sequence.totalPL = NormalizeDouble(sequence.stopsPL + sequence.closedPL + sequence.floatingPL, 2);
      //debug("Sync.ProcessEvents()   "+ id +"  "+ ifString(ticket, "#"+ ticket, "") +"  "+ TimeToStr(time, TIME_FULL) +" ("+ time +")  "+ StringRightPad(StatusToStr(status), 20, " ") + StringRightPad(BreakevenEventToStr(type), 19, " ") +"  sequence.level="+ ifInt(direction==D_LONG, sequence.level.L, sequence.level.S) +"  index="+ index +"  closed="+ closedPositions +"  reopened="+ reopenedPositions +"  recalcBE="+recalcBreakeven +"  visibleBE="+ breakevenVisible);

      lastId     = id;
      lastTime   = time;
      lastType   = type;
      lastTicket = ticket;
   }
   lastEventId = id;


   // (4) Wurde die Sequenz außerhalb gestoppt, fehlende Stop-Daten ermitteln
   if (status == STATUS_STOPPING) {
      if (closedPositions != Abs(sequence.level)) return(_false(catch("Sync.ProcessEvents(14)   unexpected number of closed positions in "+ sequenceStatusDescr[status] +" sequence", ERR_RUNTIME_ERROR)));

      // (4.1) Stopdaten ermitteln
      int    level = Abs(sequence.level);
      double stopPrice;
      for (i=sizeOfEvents-level; i < sizeOfEvents; i++) {
         time  = events[i][1];
         type  = events[i][2];
         index = events[i][4];
         if (type != EV_POSITION_CLOSE)
            return(_false(catch("Sync.ProcessEvents(15)   unexpected "+ BreakevenEventToStr(type) +" at index "+ i, ERR_RUNTIME_ERROR)));
         stopPrice += orders.closePrice[index];
      }
      stopPrice /= level;

      // (4.2) Stopdaten zurückgeben
      sequenceStopTime  = time;
      sequenceStopPrice = NormalizeDouble(stopPrice, Digits);
   }

   ArrayResize(events,      0);
   ArrayResize(orderEvents, 0);
   return(!last_error|catch("Sync.ProcessEvents(16)"));
}


/**
 * Zeichnet die Start-/Stop-Marker der Sequenz neu.
 */
void RedrawStartStop() {
   if (!IsChart)
      return;

   static color last.StartStop.Color = DodgerBlue;
   if (StartStop.Color != CLR_NONE)
      last.StartStop.Color = StartStop.Color;

   datetime time;
   double   price;
   double   profit;
   string   label;

   int starts = ArraySize(sequence.start.event);


   // (1) Start-Marker
   for (int i=0; i < starts; i++) {
      time   = sequence.start.time  [i];
      price  = sequence.start.price [i];
      profit = sequence.start.profit[i];

      label = StringConcatenate("SR.", sequenceId, ".start.", i+1);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);

      if (startStopDisplayMode != SDM_NONE) {
         ObjectCreate (label, OBJ_ARROW, 0, time, price);
         ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
         ObjectSet    (label, OBJPROP_BACK,      false               );
         ObjectSet    (label, OBJPROP_COLOR,     last.StartStop.Color);
         ObjectSetText(label, StringConcatenate("Profit: ", DoubleToStr(profit, 2)));
      }
   }


   // (2) Stop-Marker
   for (i=0; i < starts; i++) {
      if (sequence.stop.time[i] > 0) {
         time   = sequence.stop.time [i];
         price  = sequence.stop.price[i];
         profit = sequence.stop.profit[i];

         label = StringConcatenate("SR.", sequenceId, ".stop.", i+1);
         if (ObjectFind(label) == 0)
            ObjectDelete(label);

         if (startStopDisplayMode != SDM_NONE) {
            ObjectCreate (label, OBJ_ARROW, 0, time, price);
            ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
            ObjectSet    (label, OBJPROP_BACK,      false               );
            ObjectSet    (label, OBJPROP_COLOR,     last.StartStop.Color);
            ObjectSetText(label, StringConcatenate("Profit: ", DoubleToStr(profit, 2)));
         }
      }
   }

   catch("RedrawStartStop()");
}


/**
 * Zeichnet die ChartMarker aller Orders neu.
 */
void RedrawOrders() {
   if (!IsChart)
      return;

   bool wasPending, isPending, closedPosition;
   int  size = ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      wasPending     = orders.pendingType[i] != OP_UNDEFINED;
      isPending      = orders.type[i] == OP_UNDEFINED;
      closedPosition = !isPending && orders.closeTime[i]!=0;

      if    (isPending)                         ChartMarker.OrderSent(i);
      else /*openPosition || closedPosition*/ {                                     // openPosition ist Folge einer
         if (wasPending)                        ChartMarker.OrderFilled(i);         // ...ausgeführten Pending-Order
         else                                   ChartMarker.OrderSent(i);           // ...oder Market-Order
         if (closedPosition)                    ChartMarker.PositionClosed(i);
      }
   }
}


/**
 * Wechselt den Modus der Start/Stopanzeige.
 *
 * @return int - Fehlerstatus
 */
int ToggleStartStopDisplayMode() {
   // Mode wechseln
   int i = SearchIntArray(startStopDisplayModes, startStopDisplayMode);    // #define SDM_NONE        - keine Anzeige -
   if (i == -1) {                                                          // #define SDM_PRICE       Markierung mit Preisangabe
      startStopDisplayMode = SDM_PRICE;           // default
   }
   else {
      int size = ArraySize(startStopDisplayModes);
      startStopDisplayMode = startStopDisplayModes[(i+1) % size];
   }

   // Anzeige aktualisieren
   RedrawStartStop();

   return(catch("ToggleStartStopDisplayMode()"));
}


/**
 * Wechselt den Modus der Orderanzeige.
 *
 * @return int - Fehlerstatus
 */
int ToggleOrderDisplayMode() {
   int pendings   = CountPendingOrders();
   int open       = CountOpenPositions();
   int stoppedOut = CountStoppedOutPositions();
   int closed     = CountClosedPositions();


   // Modus wechseln, dabei Modes ohne entsprechende Orders überspringen
   int oldMode      = orderDisplayMode;
   int size         = ArraySize(orderDisplayModes);
   orderDisplayMode = (orderDisplayMode+1) % size;

   while (orderDisplayMode != oldMode) {                                   // #define ODM_NONE        - keine Anzeige -
      if (orderDisplayMode == ODM_NONE) {                                  // #define ODM_STOPS       Pending,       StoppedOut
         break;                                                            // #define ODM_PYRAMID     Pending, Open,             Closed
      }                                                                    // #define ODM_ALL         Pending, Open, StoppedOut, Closed
      else if (orderDisplayMode == ODM_STOPS) {
         if (pendings+stoppedOut > 0)
            break;
      }
      else if (orderDisplayMode == ODM_PYRAMID) {
         if (pendings+open+closed > 0)
            if (open+stoppedOut+closed > 0)                                // ansonsten ist Anzeige identisch zu vorherigem Mode
               break;
      }
      else if (orderDisplayMode == ODM_ALL) {
         if (pendings+open+stoppedOut+closed > 0)
            if (stoppedOut > 0)                                            // ansonsten ist Anzeige identisch zu vorherigem Mode
               break;
      }
      orderDisplayMode = (orderDisplayMode+1) % size;
   }


   // Anzeige aktualisieren
   if (orderDisplayMode != oldMode) {
      RedrawOrders();
   }
   else {
      // nothing to change, Anzeige bleibt unverändert
      ForceSound("Windows XP-Batterie niedrig.wav");
   }
   return(catch("ToggleOrderDisplayMode()"));
}


/**
 * Gibt die Anzahl der Pending-Orders der Sequenz zurück.
 *
 * @return int
 */
int CountPendingOrders() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0)
         count++;
   }
   return(count);
}


/**
 * Gibt die Anzahl der offenen Positionen der Sequenz zurück.
 *
 * @return int
 */
int CountOpenPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]!=OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0)
         count++;
   }
   return(count);
}


/**
 * Gibt die Anzahl der ausgestoppten Positionen der Sequenz zurück.
 *
 * @return int
 */
int CountStoppedOutPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.closedBySL[i])
         count++;
   }
   return(count);
}


/**
 * Gibt die Anzahl der durch StopSequence() geschlossenen Positionen der Sequenz zurück.
 *
 * @return int
 */
int CountClosedPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]!=OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]!=0) /*&&*/ if (!orders.closedBySL[i])
         count++;
   }
   return(count);
}


/**
 * Korrigiert die vom Terminal beim Abschicken einer Pending- oder Market-Order gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.OrderSent(int i) {
   if (!IsChart) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   bool pending = orders.pendingType[i] != OP_UNDEFINED;

   int      type        =    ifInt(pending, orders.pendingType [i], orders.type     [i]);
   datetime openTime    =    ifInt(pending, orders.pendingTime [i], orders.openTime [i]);
   double   openPrice   = ifDouble(pending, orders.pendingPrice[i], orders.openPrice[i]);
   string   comment     = StringConcatenate("SR.", sequenceId, ".", NumberToStr(orders.level[i], "+."));
   color    markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if      (pending)                         markerColor = CLR_PENDING;
      else if (orderDisplayMode >= ODM_PYRAMID) markerColor = ifInt(IsLongTradeOperation(type), CLR_LONG, CLR_SHORT);
   }

   if (!ChartMarker.OrderSent_B(orders.ticket[i], Digits, markerColor, type, LotSize, Symbol(), openTime, openPrice, orders.stopLoss[i], 0, comment))
      return(_false(SetLastError(stdlib_GetLastError())));
   return(true);
}


/**
 * Korrigiert die vom Terminal beim Ausführen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.OrderFilled(int i) {
   if (!IsChart) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   string comment     = StringConcatenate("SR.", sequenceId, ".", NumberToStr(orders.level[i], "+."));
   color  markerColor = CLR_NONE;

   if (orderDisplayMode >= ODM_PYRAMID)
      markerColor = ifInt(orders.type[i]==OP_BUY, CLR_LONG, CLR_SHORT);

   if (!ChartMarker.OrderFilled_B(orders.ticket[i], orders.pendingType[i], orders.pendingPrice[i], Digits, markerColor, LotSize, Symbol(), orders.openTime[i], orders.openPrice[i], comment))
      return(_false(SetLastError(stdlib_GetLastError())));
   return(true);
}


/**
 * Korrigiert den vom Terminal beim Schließen einer Position gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.PositionClosed(int i) {
   if (!IsChart) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   color markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if ( orders.closedBySL[i]) /*&&*/ if (orderDisplayMode != ODM_PYRAMID) markerColor = CLR_CLOSE;
      if (!orders.closedBySL[i]) /*&&*/ if (orderDisplayMode >= ODM_PYRAMID) markerColor = CLR_CLOSE;
   }

   if (!ChartMarker.PositionClosed_B(orders.ticket[i], Digits, markerColor, orders.type[i], LotSize, Symbol(), orders.openTime[i], orders.openPrice[i], orders.closeTime[i], orders.closePrice[i]))
      return(_false(SetLastError(stdlib_GetLastError())));
   return(true);
}


/**
 * Ob die Sequenz im Tester erzeugt wurde, also ein Test ist. Der Aufruf dieser Funktion in Online-Charts mit einer im Tester
 * erzeugten Sequenz gibt daher ebenfalls TRUE zurück.
 *
 * @return bool
 */
bool IsTest() {
   return(isTest || IsTesting());
}


/**
 * Setzt die Größe der Datenarrays auf den angegebenen Wert.
 *
 * @param  int  size  - neue Größe
 * @param  bool reset - ob die Arrays komplett zurückgesetzt werden sollen
 *                      (default: nur neu hinzugefügte Felder werden initialisiert)
 *
 * @return int - neue Größe der Arrays
 */
int ResizeArrays(int size, bool reset=false) {
   int oldSize = ArraySize(orders.ticket);

   if (size != oldSize) {
      ArrayResize(orders.ticket,       size);
      ArrayResize(orders.level,        size);
      ArrayResize(orders.gridBase,     size);
      ArrayResize(orders.pendingType,  size);
      ArrayResize(orders.pendingTime,  size);
      ArrayResize(orders.pendingPrice, size);
      ArrayResize(orders.type,         size);
      ArrayResize(orders.openEvent,    size);
      ArrayResize(orders.openTime,     size);
      ArrayResize(orders.openPrice,    size);
      ArrayResize(orders.closeEvent,   size);
      ArrayResize(orders.closeTime,    size);
      ArrayResize(orders.closePrice,   size);
      ArrayResize(orders.stopLoss,     size);
      ArrayResize(orders.clientSL,     size);
      ArrayResize(orders.closedBySL,   size);
      ArrayResize(orders.swap,         size);
      ArrayResize(orders.commission,   size);
      ArrayResize(orders.profit,       size);
   }

   if (reset) {                                                      // alle Felder zurücksetzen
      if (size != 0) {
         ArrayInitialize(orders.ticket,                  0);
         ArrayInitialize(orders.level,                   0);
         ArrayInitialize(orders.gridBase,                0);
         ArrayInitialize(orders.pendingType,  OP_UNDEFINED);
         ArrayInitialize(orders.pendingTime,             0);
         ArrayInitialize(orders.pendingPrice,            0);
         ArrayInitialize(orders.type,         OP_UNDEFINED);
         ArrayInitialize(orders.openEvent,               0);
         ArrayInitialize(orders.openTime,                0);
         ArrayInitialize(orders.openPrice,               0);
         ArrayInitialize(orders.closeEvent,              0);
         ArrayInitialize(orders.closeTime,               0);
         ArrayInitialize(orders.closePrice,              0);
         ArrayInitialize(orders.stopLoss,                0);
         ArrayInitialize(orders.clientSL,            false);
         ArrayInitialize(orders.closedBySL,          false);
         ArrayInitialize(orders.swap,                    0);
         ArrayInitialize(orders.commission,              0);
         ArrayInitialize(orders.profit,                  0);
      }
   }
   else {
      for (int i=oldSize; i < size; i++) {
         orders.pendingType[i] = OP_UNDEFINED;                       // Hinzugefügte pendingType- und type-Felder immer re-initialisieren,
         orders.type       [i] = OP_UNDEFINED;                       // 0 ist ein gültiger Wert und daher als Default unzulässig.
      }
   }
   return(size);
}


/**
 * Gibt die lesbare Konstante eines OrderDisplay-Modes zurück.
 *
 * @param  int mode - OrderDisplay-Mode
 *
 * @return string
 */
string OrderDisplayModeToStr(int mode) {
   switch (mode) {
      case ODM_NONE   : return("ODM_NONE"   );
      case ODM_STOPS  : return("ODM_STOPS"  );
      case ODM_PYRAMID: return("ODM_PYRAMID");
      case ODM_ALL    : return("ODM_ALL"    );
   }
   return(_empty(catch("OrderDisplayModeToStr()   invalid parameter mode = "+ mode, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt die lesbare Konstante eines Breakeven-Events zurück.
 *
 * @param  int type - Event-Type
 *
 * @return string
 */
string BreakevenEventToStr(int type) {
   switch (type) {
      case EV_SEQUENCE_START  : return("EV_SEQUENCE_START"  );
      case EV_SEQUENCE_STOP   : return("EV_SEQUENCE_STOP"   );
      case EV_GRIDBASE_CHANGE : return("EV_GRIDBASE_CHANGE" );
      case EV_POSITION_OPEN   : return("EV_POSITION_OPEN"   );
      case EV_POSITION_STOPOUT: return("EV_POSITION_STOPOUT");
      case EV_POSITION_CLOSE  : return("EV_POSITION_CLOSE"  );
   }
   return(_empty(catch("BreakevenEventToStr()   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt die lesbare Konstante eines GridDirection-Codes zurück.
 *
 * @param  int direction - GridDirection
 *
 * @return string
 */
string GridDirectionToStr(int direction) {
   switch (direction) {
      case D_LONG : return("D_LONG" );
      case D_SHORT: return("D_SHORT");
   }
   return(_empty(catch("GridDirectionToStr()   illegal parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


static int ticks;
static int time1;


/**
 * Zeichnet die Equity-Kurve der Sequenz auf.
 *
 * @param  int flags - zusätzliche, das Schreiben steuernde Flags (default: keine)
 *                     HST_CACHE_TICKS: speichert aufeinanderfolgende Ticks zwischen und schreibt die Daten beim jeweils nächsten BarOpen-Event
 *                     HST_FILL_GAPS:   füllt entstehende Gaps mit dem letzten Schlußkurs vor dem Gap
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity(int flags=NULL) {
   /* Speedtest EUR/USD 04.10.2012, nur M15, ,long, GridSize 18
   +-------------------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   |                                     |     alt      | optimiert | FindBar opt. | Arrays opt. |  Read opt.  |  Write opt.  |  Valid. opt. |  in Library  |
   +-------------------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | Laptop v419 - ohne RecordEquity()   | 17.613 t/sec |           |              |             |             |              |              |              |
   | Laptop v225 - Schreiben jedes Ticks |  6.426 t/sec |           |              |             |             |              |              |              |
   | Laptop v419 - Schreiben jedes Ticks |  5.871 t/sec | 6.877 t/s |   7.381 t/s  |  7.870 t/s  |  9.097 t/s  |   9.966 t/s  |  11.332 t/s  |              |
   | Laptop v419 - mit Tick-Collector    |              |           |              |             |             |              |  15.486 t/s  |  14.286 t/s  |
   +-------------------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   */
   if (__STATUS_ERROR) return(false);
   if (!IsTesting())   return( true);

   static int hHst;
   if (!hHst) {
      string symbol = StringConcatenate(ifString(IsTesting(), "_", ""), "SR", sequenceId);

      hHst = FindHistory(symbol);
      if (hHst > 0) {
         if (!ResetHistory(hHst))
            return(!SetLastError(history_GetLastError()));
      }
      else {
         int error = history_GetLastError();
         if (IsError(error))
            return(!SetLastError(error));
         hHst = CreateHistory(symbol, "Equity SR."+ sequenceId, 2);
         if (hHst <= 0)
            return(!SetLastError(history_GetLastError()));
      }
   }
   double value = sequence.startEquity + sequence.totalPL;

   if (History.AddTick(hHst, Tick.Time, value, flags))
      return(true);
   return(!SetLastError(history_GetLastError()));
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int    iNull, iNulls[];
   double dNull, dNulls[];
   string sNull, sNulls[];
   BreakevenEventToStr(NULL);
   FindChartSequences(sNulls, iNulls);
   GetFullStatusDirectory();
   GetFullStatusFileName();
   GetMqlStatusDirectory();
   GetMqlStatusFileName();
   GridDirectionToStr(NULL);
   IsSequenceStatus(NULL);
   OrderDisplayModeToStr(NULL);
   StatusToStr(NULL);
   Sync.ProcessEvents(iNull, dNull);
   Sync.PushEvent(dNulls, NULL, NULL, NULL, NULL, NULL);
   UploadStatus(NULL, NULL, NULL, NULL);
}


/**
 * @return int - Fehlerstatus
 */
int afterDeinit() {
   History.CloseFiles(false);
   return(NO_ERROR);
}

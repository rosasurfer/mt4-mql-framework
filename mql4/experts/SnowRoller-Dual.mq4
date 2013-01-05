/**
 * SnowRoller-Strategy (2-Sequence-SnowRoller: maximal eine jeweils unabhängige Sequence je Richtung)
 */
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE, INIT_PIPVALUE, LOG_CUSTOM};
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <history.mqh>
#include <win32api.mqh>

#include <core/expert.mqh>
#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern /*sticky*/ string Sequence.ID             = "";
extern            string GridDirection           = "Bidirectional* | Long | Short";
extern            int    GridSize                = 20;
extern            double LotSize                 = 0.1;
extern            string StartConditions         = "";               // @bid(double) && @ask(double) && @price(double) && @time(datetime)
extern            string StopConditions          = "";               // @bid(double) || @ask(double) || @price(double) || @time(datetime) || @profit(double) || @profit(double%)
extern /*sticky*/ color  Breakeven.Color         = Blue;
extern /*sticky*/ string Sequence.StatusLocation = "";               // Unterverzeichnis

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

       /*sticky*/ int    startStopDisplayMode    = SDM_PRICE;        // Sticky-Variablen werden im Chart zwischengespeichert, sie überleben
       /*sticky*/ int    orderDisplayMode        = ODM_NONE;         // dort Terminal-Restart, Profile-Wechsel oder Recompilation.
       /*sticky*/ int    breakeven.Width         = 0;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


string   last.Sequence.ID             = "";                          // Input-Parameter sind nicht statisch. Extern geladene Parameter werden bei REASON_CHARTCHANGE
string   last.Sequence.StatusLocation = "";                          // mit den Default-Werten überschrieben. Um dies zu verhindern und um geänderte Parameter mit
string   last.GridDirection           = "";                          // alten Werten vergleichen zu können, werden sie in deinit() in last.* zwischengespeichert und
int      last.GridSize;                                              // in init() daraus restauriert.
double   last.LotSize;
string   last.StartConditions         = "";
string   last.StopConditions          = "";
color    last.Breakeven.Color;

int      sequenceId;
bool     test;                                                       // ob dies eine Testsequenz ist (im Tester oder im Online-Chart)

int      status = STATUS_UNINITIALIZED;
string   status.directory;                                           // MQL-Verzeichnis der Statusdatei (unterhalb ".\files\")
string   status.fileName;                                            // einfacher Dateiname der Statusdatei

datetime instanceStartTime;                                          // Start des EA's
double   instanceStartPrice;
double   sequenceStartEquity;                                        // Equity bei Start der Sequenz

int      sequenceStart.event [];                                     // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime sequenceStart.time  [];
double   sequenceStart.price [];
double   sequenceStart.profit[];

int      sequenceStop.event [];                                      // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime sequenceStop.time  [];
double   sequenceStop.price [];
double   sequenceStop.profit[];

bool     start.conditions;                                           // ob die StartConditions aktiv sind und getriggert wurden
bool     start.conditions.triggered;
bool     start.price.condition;
int      start.price.type;                                           // SCP_BID | SCP_ASK | SCP_MEDIAN
double   start.price.value;
bool     start.time.condition;
datetime start.time.value;

bool     stop.conditions;                                            // ob die StopConditions aktiv sind und getriggert wurden
bool     stop.conditions.triggered;
bool     stop.price.condition;
int      stop.price.type;                                            // SCP_BID | SCP_ASK | SCP_MEDIAN
double   stop.price.value;
bool     stop.time.condition;
datetime stop.time.value;
bool     stop.profitAbs.condition;
double   stop.profitAbs.value;
bool     stop.profitPercent.condition;
double   stop.profitPercent.value;

datetime weekend.stop.condition   = D'1970.01.01 23:05';             // StopSequence()-Zeitpunkt vor Wochenend-Pause (Freitags abend)
datetime weekend.stop.time;
bool     weekend.stop.triggered;

datetime weekend.resume.condition = D'1970.01.01 01:10';             // spätester ResumeSequence()-Zeitpunkt nach Wochenend-Pause (Montags morgen)
datetime weekend.resume.time;
bool     weekend.resume.triggered;

int      grid.direction = D_BIDIR;
double   grid.commission;                                            // Commission-Betrag je Level (falls zutreffend)

int      grid.level.L,    grid.level.S;                              // aktueller Grid-Level
int      grid.maxLevel.L, grid.maxLevel.S;                           // maximal erreichter Grid-Level

double   grid.base.L,         grid.base.S;                           // aktuelle Gridbasis
int      grid.base.L.event[], grid.base.S.event[];                   // Gridbasis-Daten
datetime grid.base.L.time [], grid.base.S.time [];
double   grid.base.L.value[], grid.base.S.value[];

int      grid.stops.L,       grid.stops.S;                           // Anzahl der bisher getriggerten Stops
double   grid.stopsPL.L,     grid.stopsPL.S;                         // kumulierter P/L aller bisher ausgestoppten Positionen
double   grid.closedPL.L,    grid.closedPL.S;                        // kumulierter P/L aller bisher bei Sequencestop geschlossenen Positionen
double   grid.floatingPL.L,  grid.floatingPL.S;                      // kumulierter P/L aller aktuell offenen Positionen
double   grid.totalPL.L,     grid.totalPL.S,     grid.totalPL;       // aktueller Gesamt-P/L der Sequenz: grid.stopsPL + grid.closedPL + grid.floatingPL
double   grid.openRisk.L,    grid.openRisk.S;                        // vorraussichtlicher kumulierter P/L aller aktuell offenen Level bei deren Stopout: sum(orders.openRisk)
double   grid.valueAtRisk.L, grid.valueAtRisk.S;                     // vorraussichtlicher Gesamt-P/L der Sequenz bei Stop in Level 0: grid.stopsPL + grid.openRisk

double   grid.maxProfit.L,   grid.maxProfit.S,   grid.maxProfit;     // maximaler bisheriger Gesamt-Profit   (>= 0)
double   grid.maxDrawdown.L, grid.maxDrawdown.S, grid.maxDrawdown;   // maximaler bisheriger Gesamt-Drawdown (<= 0)
double   grid.breakeven.L,   grid.breakeven.S;

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
double   orders.openRisk      [];                                    // vorraussichtlicher P/L des Levels seit letztem Stopout bei erneutem Stopout

int      orders.closeEvent    [];
datetime orders.closeTime     [];
double   orders.closePrice    [];
double   orders.stopLoss      [];
bool     orders.clientSL      [];                                    // client- oder server-seitiger StopLoss
bool     orders.closedBySL    [];

double   orders.swap          [];
double   orders.commission    [];
double   orders.profit        [];

int      ignorePendingOrders  [];                                    // orphaned tickets to ignore
int      ignoreOpenPositions  [];
int      ignoreClosedPositions[];

string   str.LotSize             = "";                              // Zwischenspeicher für schnellere Abarbeitung von ShowStatus()
string   str.startConditions     = "";
string   str.stopConditions      = "";
string   str.grid.direction      = "";
string   str.grid.level.L        = "",        str.grid.level.S        = "", str.grid.level.LS    = "";
string   str.grid.maxLevel.L     = "",        str.grid.maxLevel.S     = "", str.grid.maxLevel.LS = "";
string   str.grid.base.L         = "",        str.grid.base.S         = "", str.grid.base.LS     = "";
string   str.grid.stops.L        = "",        str.grid.stops.S        = "", str.grid.stops.Sep   = "";
string   str.grid.stopsPL.L      = "",        str.grid.stopsPL.S      = "";
string   str.grid.totalPL.L      = "-",       str.grid.totalPL.S      = "-";
string   str.grid.maxProfit.L    = "0.00",    str.grid.maxProfit.S    = "0.00";
string   str.grid.maxDrawdown.L  = "0.00",    str.grid.maxDrawdown.S  = "0.00";
string   str.grid.valueAtRisk.L  = "0.00",    str.grid.valueAtRisk.S  = "0.00";
string   str.grid.plStatistics.L = "",        str.grid.plStatistics.S = "";

bool     firstTick          = true;
bool     firstTickConfirmed = false;
int      lastEventId;


#include <SnowRoller/init.mqh>
#include <SnowRoller/deinit.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   if (status==STATUS_UNINITIALIZED || status==STATUS_DISABLED) {
      firstTick = false;
      return(NO_ERROR);
   }

   // (1) Commands verarbeiten
   HandleEvent(EVENT_CHART_CMD);

   static int    last.grid.level.L, last.grid.level.S, limits[], stops[];
   static double last.grid.base.L,  last.grid.base.S;


   // (2) Sequenz wartet entweder auf Startsignal...
   if (status == STATUS_WAITING) {
      if (IsStartSignal())                           StartSequence();
   }

   // (3) ...oder auf ResumeSignal...
   else if (status == STATUS_STOPPED) {
      if (IsResumeSignal())                          ResumeSequence();
      else {
         firstTick = false;
         return(last_error);
      }
   }

   // (4) ...oder läuft
   else if (UpdateStatus(limits, stops)) {
      if         (IsStopSignal())                    StopSequence();
      else {
         if      (ArraySize(limits) > 0)             ProcessClientLimits(limits);
         if      (ArraySize(stops ) > 0)             ProcessClientStops(stops);
         if      (grid.level.L != last.grid.level.L) UpdatePendingOrders();
         else if (grid.level.S != last.grid.level.S) UpdatePendingOrders();
         else if (NE(grid.base.L, last.grid.base.L)) UpdatePendingOrders();
         else if (NE(grid.base.S, last.grid.base.S)) UpdatePendingOrders();
      }
   }

   // (5) Equity-Kurve aufzeichnen (erst nach allen Orderfunktionen, ab dem ersten ausgeführten Trade)
   if (status==STATUS_PROGRESSING) /*&&*/ if (grid.maxLevel.L-grid.maxLevel.S != 0) {
      RecordEquity(true);
   }

   // (6) Status anzeigen
   ShowStatus();

   last.grid.level.L = grid.level.L;
   last.grid.level.S = grid.level.S;
   last.grid.base.L  = grid.base.L;
   last.grid.base.S  = grid.base.S;
   firstTick = false;
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
         case STATUS_WAITING:
            StartSequence();
            break;
         case STATUS_STOPPED:
            ResumeSequence();
            break;
      }
      return(last_error);
   }

   if (cmd == "stop") {
      switch (status) {
         case STATUS_WAITING    :
         case STATUS_PROGRESSING:
            int iNull[];
            if (UpdateStatus(iNull, iNull))
               StopSequence();
            ShowStatus();
      }
      return(last_error);
   }

   if (cmd == "startstopdisplay") return(ToggleStartStopDisplayMode());
   if (cmd ==     "orderdisplay") return(    ToggleOrderDisplayMode());
   if (cmd == "breakevendisplay") return(ToggleBreakevenDisplayMode());

   // unbekannte Commands anzeigen, aber keinen Fehler setzen (EA soll weiterlaufen)
   warn(StringConcatenate("onChartCommand(2)   unknown command \"", cmd, "\""));
   return(NO_ERROR);
}


/**
 * Handler für BarOpen-Events.
 *
 * @param int timeframes[] - IDs der Timeframes, in denen das BarOpen-Event aufgetreten ist
 *
 * @return int - Fehlerstatus
 */
int onBarOpen(int timeframes[]) {
   if (Grid.DrawBreakeven())
      return(NO_ERROR);
   return(last_error);
}


/**
 * Startet eine neue Trade-Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence() {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("StartSequence(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_WAITING)             return(_false(catch("StartSequence(2)   cannot start "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                  // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - StartSequence()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to start a new sequence now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("StartSequence(3)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;


   status = STATUS_STARTING;
   if (__LOG) log("StartSequence()   starting sequence");


   // (1) Startvariablen setzen
   datetime startTime  = TimeCurrent();
   double   startPrice = NormalizeDouble((Bid + Ask)/2, Digits);

   ArrayPushInt   (sequenceStart.event,  CreateEventId()                                    );
   ArrayPushInt   (sequenceStart.time,   startTime                                          );
   ArrayPushDouble(sequenceStart.price,  startPrice                                         );
   ArrayPushDouble(sequenceStart.profit, NormalizeDouble(grid.totalPL.L + grid.totalPL.S, 2));

   ArrayPushInt   (sequenceStop.event,  0);                          // Größe von sequenceStarts/Stops synchron halten
   ArrayPushInt   (sequenceStop.time,   0);
   ArrayPushDouble(sequenceStop.price,  0);
   ArrayPushDouble(sequenceStop.profit, 0);

   sequenceStartEquity = NormalizeDouble(AccountEquity()-AccountCredit(), 2);


   status = STATUS_PROGRESSING;


   // (2) StartConditions deaktivieren und Weekend-Stop aktualisieren
   start.conditions = false; SS.StartStopConditions();
   UpdateWeekendStop();


   // (3) Gridbasis setzen (event-mäßig nach sequenceStartTime)
   if (grid.direction != D_SHORT) Grid.BaseReset(D_LONG,  startTime, startPrice);
   if (grid.direction != D_LONG ) Grid.BaseReset(D_SHORT, startTime, startPrice);


   // (4) Stop-Orders in den Markt legen
   if (!UpdatePendingOrders())
      return(false);

   RedrawStartStop();

   if (__LOG) log(StringConcatenate("StartSequence()   sequence started at ", NumberToStr(startPrice, PriceFormat)));
   return(IsNoError(last_error|catch("StartSequence(4)")));
}


/**
 * Schließt alle PendingOrders und offenen Positionen der Sequenz.
 *
 * @return bool - Erfolgsstatus: ob die Sequenz erfolgreich gestoppt wurde
 */
bool StopSequence() {
   if (__STATUS__CANCELLED || IsLastError())                                                              return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                                                                 return(_false(catch("StopSequence(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_WAITING) /*&&*/ if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STOPPING)
      if (!IsTesting() || __WHEREAMI__!=FUNC_DEINIT || status!=STATUS_STOPPED)         // ggf. wird nach Testende nur aufgeräumt
         return(_false(catch("StopSequence(2)   cannot stop "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));


   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                                    // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - StopSequence()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to stop the sequence now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("StopSequence(3)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;


   // (1) eine wartende Sequenz ist noch nicht gestartet und wird gecanceled
   if (status == STATUS_WAITING) {
      __STATUS__CANCELLED = true;
      if (IsTesting())
         Tester.Pause();
      return(_false(catch("StopSequence(4)")));
   }


   if (status != STATUS_STOPPED) {
      status = STATUS_STOPPING;
      if (__LOG) log(StringConcatenate("StopSequence()   stopping sequence at level ", str.grid.level.LS));
   }


   // (2) PendingOrders und OpenPositions einlesen
   int pendings[], positions.L[], positions.S[], sizeOfTickets=ArraySize(orders.ticket);
   ArrayResize(pendings,    0);
   ArrayResize(positions.L, 0);
   ArrayResize(positions.S, 0);

   for (int i=sizeOfTickets-1; i >= 0; i--) {
      if (orders.closeTime[i] == 0) {                                                                 // Ticket prüfen, wenn es beim letzten Aufruf noch offen war
         if (orders.ticket[i] < 0) {
            if (!Grid.DropData(i))                                                                    // client-seitige Pending-Orders können intern gelöscht werden
               return(false);
            sizeOfTickets--;
            continue;
         }
         if (!SelectTicket(orders.ticket[i], "StopSequence(5)"))
            return(false);
         if (OrderCloseTime() == 0) {                                                                 // offene Tickets je nach Typ zwischenspeichern
            if (IsPendingTradeOperation(OrderType())) ArrayPushInt(pendings, i);                      // Grid.DeleteOrder() erwartet den Array-Index
            else if (orders.level[i] > 0)             ArrayPushInt(positions.L, orders.ticket[i]);    // OrderMultiClose() erwartet das Orderticket
            else                                      ArrayPushInt(positions.S, orders.ticket[i]);
         }
      }
   }


   // (3) zuerst Pending-Orders streichen (ansonsten können sie während OrderClose() noch getriggert werden)
   int sizeOfPendings = ArraySize(pendings);

   for (i=0; i < sizeOfPendings; i++) {
      if (!Grid.DeleteOrder(pendings[i]))
         return(false);
   }


   // (4) dann offene Positionen schließen                           // TODO: Wurde eine PendingOrder inzwischen getriggert, muß sie hier mit verarbeitet werden.
   int      sizeOfPositions.L=ArraySize(positions.L), sizeOfPositions.S=ArraySize(positions.S), n=ArraySize(sequenceStop.event)-1;
   datetime closeTime.L,  closeTime.S;
   double   closePrice.L, closePrice.S, nextLevel;
   int      oeFlags, /*ORDER_EXECUTION*/oes[][ORDER_EXECUTION.intSize];

   // (4.1) Long-Positionen
   if (sizeOfPositions.L > 0) {
      oeFlags = NULL;
      ArrayResize(oes, sizeOfPositions.L); InitializeBuffer(oes, ORDER_EXECUTION.size);

      if (!OrderMultiClose(positions.L, NULL, CLR_CLOSE, oeFlags, oes))
         return(_false(SetLastError(stdlib_PeekLastError())));

      for (i=0; i < sizeOfPositions.L; i++) {
         int pos = SearchIntArray(orders.ticket, positions.L[i]);

         orders.closeEvent[pos] = CreateEventId();
         orders.closeTime [pos] = oes.CloseTime (oes, i);
         orders.closePrice[pos] = oes.ClosePrice(oes, i);
         orders.closedBySL[pos] = false;

         orders.swap      [pos] = oes.Swap      (oes, i);
         orders.commission[pos] = oes.Commission(oes, i);
         orders.profit    [pos] = oes.Profit    (oes, i);

         grid.closedPL.L  = NormalizeDouble(grid.closedPL.L + orders.swap[pos] + orders.commission[pos] + orders.profit[pos], 2);
       //grid.openRisk    = ...                                      // unverändert bei StopSequence()
       //grid.valueAtRisk = ...                                      // unverändert bei StopSequence()

         closeTime.L   = Max(closeTime.L, orders.closeTime[pos]);    // u.U. können die Close-Werte unterschiedlich sein und müssen gemittelt werden
         closePrice.L += orders.closePrice[pos];                     // (i.d.R. sind sie überall gleich)
      }
      closePrice.L /= Abs(grid.level.L);                             // avg(ClosePrice) TODO: falsch, wenn bereits ein Teil der Positionen geschlossen war
      /*
      grid.floatingPL  = ...                                         // Solange unten UpdateStatus() aufgerufen wird, werden diese Werte dort automatisch aktualisiert.
      grid.totalPL     = ...
      grid.maxProfit   = ...
      grid.maxDrawdown = ...
      */
      sequenceStop.event[n] = CreateEventId();
      sequenceStop.time [n] = closeTime.L;
      sequenceStop.price[n] = NormalizeDouble(closePrice.L, Digits);
   }

   // (4.2) Short-Positionen
   if (sizeOfPositions.S > 0) {
      oeFlags = NULL;
      ArrayResize(oes, sizeOfPositions.S); InitializeBuffer(oes, ORDER_EXECUTION.size);

      if (!OrderMultiClose(positions.S, NULL, CLR_CLOSE, oeFlags, oes))
         return(_false(SetLastError(stdlib_PeekLastError())));

      for (i=0; i < sizeOfPositions.S; i++) {
         pos = SearchIntArray(orders.ticket, positions.S[i]);

         orders.closeEvent[pos] = CreateEventId();
         orders.closeTime [pos] = oes.CloseTime (oes, i);
         orders.closePrice[pos] = oes.ClosePrice(oes, i);
         orders.closedBySL[pos] = false;

         orders.swap      [pos] = oes.Swap      (oes, i);
         orders.commission[pos] = oes.Commission(oes, i);
         orders.profit    [pos] = oes.Profit    (oes, i);

         grid.closedPL.S  = NormalizeDouble(grid.closedPL.S + orders.swap[pos] + orders.commission[pos] + orders.profit[pos], 2);
       //grid.openRisk    = ...                                      // unverändert bei StopSequence()
       //grid.valueAtRisk = ...                                      // unverändert bei StopSequence()

         closeTime.S   = Max(closeTime.S, orders.closeTime[pos]);    // u.U. können die Close-Werte unterschiedlich sein und müssen gemittelt werden
         closePrice.S += orders.closePrice[pos];                     // (i.d.R. sind sie überall gleich)
      }
      closePrice.S /= Abs(grid.level.S);                             // avg(ClosePrice) TODO: falsch, wenn bereits ein Teil der Positionen geschlossen war
      /*
      grid.floatingPL  = ...                                         // Solange unten UpdateStatus() aufgerufen wird, werden diese Werte dort automatisch aktualisiert.
      grid.totalPL     = ...
      grid.maxProfit   = ...
      grid.maxDrawdown = ...
      */
      sequenceStop.event[n] = CreateEventId();
      sequenceStop.time [n] = closeTime.S;

      if (sizeOfPositions.L == 0) sequenceStop.price[n] = NormalizeDouble(closePrice.S, Digits);
      else                        sequenceStop.price[n] = NormalizeDouble((closePrice.L + closePrice.S)/2, Digits);
   }

   // (4.3) keine offenen Positionen
   if (sizeOfPositions.L + sizeOfPositions.S == 0) {
      if (status != STATUS_STOPPED) {
         sequenceStop.event[n] = CreateEventId();
         sequenceStop.time [n] = TimeCurrent();

         if (grid.direction == D_LONG ) sequenceStop.price[n] = Bid;
         if (grid.direction == D_SHORT) sequenceStop.price[n] = Ask;
         if (grid.direction == D_BIDIR) sequenceStop.price[n] = NormalizeDouble((Bid + Ask)/2, Digits);
      }
   }


   // (5) StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
   if (grid.direction != D_BIDIR)
      if (!StopSequence.LimitStopPrice())
         return(false);


   if (status != STATUS_STOPPED) {
      status = STATUS_STOPPED;
      if (__LOG) log(StringConcatenate("StopSequence()   sequence stopped at ", NumberToStr(sequenceStop.price[n], PriceFormat), ", level ", str.grid.level.LS));
   }


   // (6) ResumeConditions/StopConditions aktualisieren bzw. deaktivieren
   if (IsWeekendStopSignal()) {
      UpdateWeekendResume();
   }
   else {
      stop.conditions = false; SS.StartStopConditions();
   }


   // (7) Daten aktualisieren und speichern
   int iNull[];
   if (!UpdateStatus(iNull, iNull)) return(false);
   sequenceStop.profit[n] = grid.totalPL;
   if (  !SaveStatus())             return(false);
   if (!RecordEquity(false))        return(false);
   RedrawStartStop();


   // (8) ggf. Tester stoppen
   if (IsTesting()) {
      if      (        IsVisualMode()) Tester.Pause();
      else if (!IsWeekendStopSignal()) Tester.Stop();
   }

   /*
   debug("StopSequence()      level="      + grid.level
                          +"  stops="      + grid.stops
                          +"  stopsPL="    + DoubleToStr(grid.stopsPL,     2)
                          +"  closedPL="   + DoubleToStr(grid.closedPL,    2)
                          +"  floatingPL=" + DoubleToStr(grid.floatingPL,  2)
                          +"  totalPL="    + DoubleToStr(grid.totalPL,     2)
                          +"  openRisk="   + DoubleToStr(grid.openRisk,    2)
                          +"  valueAtRisk="+ DoubleToStr(grid.valueAtRisk, 2));
   */
   return(IsNoError(last_error|catch("StopSequence(6)")));
}


/**
 * Der StopPrice darf nicht schon den nächsten Level triggern, da sonst bei ResumeSequence() Fehler auftreten.
 *
 * @return bool - Erfolgsstatus
 */
bool StopSequence.LimitStopPrice() {
   if (__STATUS__CANCELLED || IsLastError())                       return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                          return(_false(catch("StopSequence.LimitStopPrice(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_STOPPING) /*&&*/ if (status!=STATUS_STOPPED) return(_false(catch("StopSequence.LimitStopPrice(2)   cannot limit stop price of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   if (grid.direction == D_BIDIR)
      return(true);

   double nextTrigger;
   int i = ArraySize(sequenceStop.price) - 1;

   if (grid.direction == D_LONG) {
      nextTrigger = grid.base.L + (grid.level.L+1)*GridSize*Pip;
      sequenceStop.price[i] = MathMin(nextTrigger-1*Pip, sequenceStop.price[i]);    // max. 1 Pip unterm Trigger des nächsten Levels
   }

   if (grid.direction == D_SHORT) {
      nextTrigger = grid.base.S + (grid.level.S-1)*GridSize*Pip;
      sequenceStop.price[i] = MathMax(nextTrigger+1*Pip, sequenceStop.price[i]);    // min. 1 Pip überm Trigger des nächsten Levels
   }
   sequenceStop.price[i] = NormalizeDouble(sequenceStop.price[i], Digits);

   return(IsNoError(last_error|catch("StopSequence.LimitStopPrice(3)")));
}


/**
 * Setzt eine gestoppte Sequenz fort.
 *
 * @return bool - Erfolgsstatus
 */
bool ResumeSequence() {
   if (__STATUS__CANCELLED || IsLastError())                       return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                          return(_false(catch("ResumeSequence(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_STOPPED) /*&&*/ if (status!=STATUS_STARTING) return(_false(catch("ResumeSequence(2)   cannot resume "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                           // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - ResumeSequence()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to resume the sequence now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("ResumeSequence(3)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;


   status = STATUS_STARTING;
   if (__LOG) log(StringConcatenate("ResumeSequence()   resuming sequence at level ", str.grid.level.LS));

   datetime startTime,  startTime.L,  startTime.S;
   double   startPrice, startPrice.L, startPrice.S, lastStopPrice, gridBase.L, gridBase.S;


   // (1) Wird ResumeSequence() nach einem Fehler erneut aufgerufen, kann es sein, daß einige Level bereits offen sind und andere noch fehlen.
   if (grid.level.L > 0) {
      for (int level=1; level <= grid.level.L; level++) {
         int i = Grid.FindOpenPosition(level);
         if (i != -1) {
            gridBase.L = orders.gridBase[i];
            break;
         }
      }
   }
   if (grid.level.S < 0) {
      for (level=-1; level >= grid.level.S; level--) {
         i = Grid.FindOpenPosition(level);
         if (i != -1) {
            gridBase.S = orders.gridBase[i];
            break;
         }
      }
   }


   // (2) Neue Gridbasis setzen, wenn noch keine offenen Positionen existieren.
   if (EQ(gridBase.L, 0)) {
      if (grid.direction != D_SHORT) {
         startTime.L   = TimeCurrent();
         startPrice.L  = Ask;
         lastStopPrice = sequenceStop.price[ArraySize(sequenceStop.price)-1];
         Grid.BaseChange(D_LONG, startTime.L, grid.base.L + startPrice.L - lastStopPrice);
      }
   }
   else {
      grid.base.L = NormalizeDouble(gridBase.L, Digits);                      // Gridbasis der vorhandenen Positionen übernehmen (sollte schon gesetzt sein, doch wer weiß...)
   }

   if (EQ(gridBase.S, 0)) {
      if (grid.direction != D_LONG) {
         startTime.S   = TimeCurrent();
         startPrice.S  = Bid;
         lastStopPrice = sequenceStop.price[ArraySize(sequenceStop.price)-1];
         Grid.BaseChange(D_SHORT, startTime.S, grid.base.S + startPrice.S - lastStopPrice);
      }
   }
   else {
      grid.base.S = NormalizeDouble(gridBase.S, Digits);                      // Gridbasis der vorhandenen Positionen übernehmen (sollte schon gesetzt sein, doch wer weiß...)
   }


   // (3) vorherige Positionen wieder in den Markt legen und letzte OrderOpenTime abfragen
   if (grid.direction != D_SHORT) {
      if (!UpdateOpenPositions(D_LONG, startTime.L, startPrice.L))
         return(false);
      startPrice = startPrice.L;
   }
   if (grid.direction != D_LONG) {
      if (!UpdateOpenPositions(D_SHORT, startTime.S, startPrice.S))
         return(false);
      if (grid.direction == D_SHORT) startPrice = startPrice.S;
      else                           startPrice = NormalizeDouble((startPrice.L + startPrice.S)/2, Digits);
   }
   startTime = Max(startTime.L, startTime.S);


   // (4) neuen Sequenzstart speichern
   ArrayPushInt   (sequenceStart.event,  CreateEventId());
   ArrayPushInt   (sequenceStart.time,   startTime      );
   ArrayPushDouble(sequenceStart.price,  startPrice     );
   ArrayPushDouble(sequenceStart.profit, grid.totalPL.L + grid.totalPL.S);    // wird nach UpdateStatus() mit aktuellem Wert überschrieben

   ArrayPushInt   (sequenceStop.event,  0);                                   // sequenceStart/Stop-Größe synchron halten
   ArrayPushInt   (sequenceStop.time,   0);
   ArrayPushDouble(sequenceStop.price,  0);
   ArrayPushDouble(sequenceStop.profit, 0);


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
   int iNull[], last.grid.level.L=grid.level.L, last.grid.level.S=grid.level.S;
   if (!UpdateStatus(iNull, iNull))                                           // Wurde in UpdateOpenPositions() ein Pseudo-Ticket erstellt, wird es hier
      return(false);                                                          // in UpdateStatus() geschlossen. In diesem Fall müssen die Pending-Orders
   if      (grid.level.L != last.grid.level.L) UpdatePendingOrders();         // nochmal aktualisiert werden.
   else if (grid.level.S != last.grid.level.S) UpdatePendingOrders();

   sequenceStart.profit[ArraySize(sequenceStart.profit)-1] = grid.totalPL;    // aktuellen Wert speichern

   if (!SaveStatus())
      return(false);


   // (8) Breakeven neu berechnen und Anzeigen aktualisieren
   if (!Grid.CalculateBreakeven())
      return(false);
   RedrawStartStop();

   /*
   debug("ResumeSequence()    level="      + grid.level
                          +"  stops="      + grid.stops
                          +"  stopsPL="    + DoubleToStr(grid.stopsPL,     2)
                          +"  closedPL="   + DoubleToStr(grid.closedPL,    2)
                          +"  floatingPL=" + DoubleToStr(grid.floatingPL,  2)
                          +"  totalPL="    + DoubleToStr(grid.totalPL,     2)
                          +"  openRisk="   + DoubleToStr(grid.openRisk,    2)
                          +"  valueAtRisk="+ DoubleToStr(grid.valueAtRisk, 2));
   */
   if (__LOG) log(StringConcatenate("ResumeSequence()   sequence resumed at ", NumberToStr(startPrice, PriceFormat), ", level ", str.grid.level.LS));
   return(IsNoError(last_error|catch("ResumeSequence(4)")));
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @param int limits[] - Array-Indizes der Orders mit getriggerten client-seitigen Limits
 * @param int stops[]  - Array-Indizes der Orders mit getriggerten client-seitigen Stops
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus(int limits[], int stops[]) {
   ArrayResize(limits, 0);
   ArrayResize(stops,  0);

   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("UpdateStatus(1)", ERR_ILLEGAL_STATE)));
   if (status == STATUS_WAITING)             return( true);

   grid.floatingPL.L = 0;
   grid.floatingPL.S = 0;

   bool wasPending, isClosed, openPositions, recalcBreakeven.L, recalcBreakeven.S, updateStatusLocation;
   int  closed[][2], close[2], sizeOfTickets=ArraySize(orders.ticket); ArrayResize(closed, 0);


   // (1) Tickets aktualisieren
   for (int i=0; i < sizeOfTickets; i++) {
      if (orders.closeTime[i] == 0) {                                            // Ticket prüfen, wenn es beim letzten Aufruf noch offen war
         wasPending = orders.type[i] == OP_UNDEFINED;

         // (1.1) getriggerte client-seitige PendingOrders
         if (wasPending) /*&&*/ if (orders.ticket[i] == -1) {
            if (IsStopTriggered(orders.pendingType[i], orders.pendingPrice[i])) {
               if (__LOG) log(UpdateStatus.StopTriggerMsg(i));
               ArrayPushInt(stops, i);
            }
            continue;
         }

         // (1.2) Pseudo-Tickets werden intern geschlossen
         if (orders.ticket[i] == -2) {
            orders.closeEvent[i] = CreateEventId();                              // Event-ID kann sofort vergeben werden.
            orders.closeTime [i] = TimeCurrent();
            orders.closePrice[i] = orders.openPrice[i];
            orders.closedBySL[i] = true;
            ChartMarker.PositionClosed(i);
            if (__LOG) log(UpdateStatus.SLExecuteMsg(i));

            if (orders.level[i] > 0) {
               grid.level.L--;
               grid.stops.L++;
             //grid.stopsPL.L     = ...                                          // unverändert, da P/L des Pseudo-Tickets immer 0.00
               grid.openRisk.L    = NormalizeDouble(grid.openRisk.L - orders.openRisk[i], 2);
               grid.valueAtRisk.L = NormalizeDouble(grid.openRisk.L + grid.stopsPL.L, 2); SS.Grid.ValueAtRisk();
               recalcBreakeven.L  = true;
            }
            else {
               grid.level.S++;
               grid.stops.S++;
             //grid.stopsPL.S     = ...                                          // unverändert, da P/L des Pseudo-Tickets immer 0.00
               grid.openRisk.S    = NormalizeDouble(grid.openRisk.S - orders.openRisk[i], 2);
               grid.valueAtRisk.S = NormalizeDouble(grid.openRisk.S + grid.stopsPL.S, 2); SS.Grid.ValueAtRisk();
               recalcBreakeven.S  = true;
            }
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
               orders.commission[i] = OrderCommission(); grid.commission = OrderCommission(); SS.LotSize();
               orders.profit    [i] = OrderProfit();
               orders.openRisk  [i] = CalculateOpenRisk(i);
               ChartMarker.OrderFilled(i);
               if (__LOG) log(UpdateStatus.OrderFillMsg(i));

               if (orders.level[i] > 0) {
                  grid.level.L++;
                  updateStatusLocation = updateStatusLocation || (grid.maxLevel.L-grid.maxLevel.S==0);
                  grid.maxLevel.L      = Max(grid.level.L, grid.maxLevel.L); SS.Grid.Level();
                  grid.openRisk.L      = NormalizeDouble(grid.openRisk.L    + orders.openRisk[i], 2);
                  grid.valueAtRisk.L   = NormalizeDouble(grid.valueAtRisk.L + orders.openRisk[i], 2); SS.Grid.ValueAtRisk();  // valueAtRisk = stopsPL + openRisk
                  recalcBreakeven.L    = true;
               }
               else {
                  grid.level.S--;
                  updateStatusLocation = updateStatusLocation || (grid.maxLevel.L-grid.maxLevel.S==0);
                  grid.maxLevel.S      = Min(grid.level.S, grid.maxLevel.S); SS.Grid.Level();
                  grid.openRisk.S      = NormalizeDouble(grid.openRisk.S    + orders.openRisk[i], 2);
                  grid.valueAtRisk.S   = NormalizeDouble(grid.valueAtRisk.S + orders.openRisk[i], 2); SS.Grid.ValueAtRisk();  // valueAtRisk = stopsPL + openRisk
                  recalcBreakeven.S    = true;
               }
            }
         }
         else {
            // beim letzten Aufruf offene Position
            if (NE(orders.swap[i], OrderSwap())) {                               // bei Swap-Änderung openRisk und valueAtRisk justieren
               orders.openRisk[i] = NormalizeDouble(orders.openRisk[i] + orders.swap[i] - OrderSwap(), 2);
               if (orders.level[i] > 0) {
                  grid.openRisk.L    = NormalizeDouble(grid.openRisk.L    + orders.swap[i] - OrderSwap(), 2);
                  grid.valueAtRisk.L = NormalizeDouble(grid.valueAtRisk.L + orders.swap[i] - OrderSwap(), 2); SS.Grid.ValueAtRisk();
                  recalcBreakeven.L  = true;
               }
               else {
                  grid.openRisk.S    = NormalizeDouble(grid.openRisk.S    + orders.swap[i] - OrderSwap(), 2);
                  grid.valueAtRisk.S = NormalizeDouble(grid.valueAtRisk.S + orders.swap[i] - OrderSwap(), 2); SS.Grid.ValueAtRisk();
                  recalcBreakeven.S  = true;
               }
            }
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
            if (orders.level[i] > 0) grid.floatingPL.L = NormalizeDouble(grid.floatingPL.L + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
            else                     grid.floatingPL.S = NormalizeDouble(grid.floatingPL.S + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
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
               if (orders.level[i] > 0) {
                  grid.level.L--;
                  grid.stops.L++;
                  grid.stopsPL.L     = NormalizeDouble(grid.stopsPL.L + orders.swap[i] + orders.commission[i] + orders.profit[i], 2); SS.Grid.Stops();
                  grid.openRisk.L    = NormalizeDouble(grid.openRisk.L - orders.openRisk[i], 2);
                  grid.valueAtRisk.L = NormalizeDouble(grid.openRisk.L + grid.stopsPL.L, 2); SS.Grid.ValueAtRisk();
                  recalcBreakeven.L  = true;
               }
               else {
                  grid.level.S++;
                  grid.stops.S++;
                  grid.stopsPL.S     = NormalizeDouble(grid.stopsPL.S + orders.swap[i] + orders.commission[i] + orders.profit[i], 2); SS.Grid.Stops();
                  grid.openRisk.S    = NormalizeDouble(grid.openRisk.S - orders.openRisk[i], 2);
                  grid.valueAtRisk.S = NormalizeDouble(grid.openRisk.S + grid.stopsPL.S, 2); SS.Grid.ValueAtRisk();
                  recalcBreakeven.S  = true;
               }
            }
            else {                                                               // Sequenzstop im STATUS_MONITORING oder autom. Close bei Testende
               close[0] = OrderCloseTime();
               close[1] = OrderTicket();                                         // Geschlossene Positionen werden zwischengespeichert, deren Event-IDs werden erst
               ArrayPushIntArray(closed, close);                                 // *NACH* allen evt. vorher ausgestoppten Positionen vergeben.

               if (status != STATUS_STOPPED)
                  status = STATUS_STOPPING;
               if (__LOG) log(UpdateStatus.PositionCloseMsg(i));
               if (orders.level[i] > 0) grid.closedPL.L = NormalizeDouble(grid.closedPL.L + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
               else                     grid.closedPL.S = NormalizeDouble(grid.closedPL.S + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
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
            return(_false(catch("UpdateStatus(3)   closed ticket #"+ closed[i][1] +" not found in grid arrays", ERR_RUNTIME_ERROR)));
         orders.closeEvent[n] = CreateEventId();
      }
      ArrayResize(closed, 0);
   }


   // (3) P/L-Kennziffern  aktualisieren
   grid.totalPL.L = NormalizeDouble(grid.stopsPL.L + grid.closedPL.L + grid.floatingPL.L, 2);
   grid.totalPL.S = NormalizeDouble(grid.stopsPL.S + grid.closedPL.S + grid.floatingPL.S, 2);
   grid.totalPL   = NormalizeDouble(grid.totalPL.L + grid.totalPL.S, 2); SS.Grid.TotalPL();

   bool newMax;
   if      (grid.totalPL.L > grid.maxProfit.L  ) { grid.maxProfit.L   = grid.totalPL.L; newMax = true; }
   else if (grid.totalPL.L < grid.maxDrawdown.L) { grid.maxDrawdown.L = grid.totalPL.L; newMax = true; }
   if      (grid.totalPL.S > grid.maxProfit.S  ) { grid.maxProfit.S   = grid.totalPL.S; newMax = true; }
   else if (grid.totalPL.S < grid.maxDrawdown.S) { grid.maxDrawdown.S = grid.totalPL.S; newMax = true; }
   if      (grid.totalPL   > grid.maxProfit    ) { grid.maxProfit     = grid.totalPL;   newMax = true; }
   else if (grid.totalPL   < grid.maxDrawdown  ) { grid.maxDrawdown   = grid.totalPL;   newMax = true; }
   if (newMax) SS.Grid.MaxProfit();


   // (4) ggf. Status aktualisieren
   if (status == STATUS_STOPPING) {
      if (!openPositions) {                                                      // Sequenzstop im STATUS_MONITORING oder Auto-Close durch Tester bei Testende
         n = ArraySize(sequenceStop.event) - 1;
         sequenceStop.event [n] = CreateEventId();
         sequenceStop.time  [n] = UpdateStatus.CalculateStopTime();  if (!sequenceStop.time [n]) return(false);
         sequenceStop.price [n] = UpdateStatus.CalculateStopPrice(); if (!sequenceStop.price[n]) return(false);
         sequenceStop.profit[n] = grid.totalPL;

         if (grid.direction != D_BIDIR)
            if (!StopSequence.LimitStopPrice())                                  //  StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
               return(false);

         status = STATUS_STOPPED;
         if (__LOG) log("UpdateStatus()   STATUS_STOPPED");
         RedrawStartStop();
      }
   }


   else if (status == STATUS_PROGRESSING) {
      // (5) ggf. Gridbasis trailen
      if (grid.level.L==0) /*&&*/ if (grid.direction!=D_SHORT) {
         double last.grid.base.L = grid.base.L;
         grid.base.L = MathMin(grid.base.L, NormalizeDouble((Bid + Ask)/2, Digits));
         if (NE(grid.base.L, last.grid.base.L)) {
            Grid.BaseChange(D_LONG, TimeCurrent(), grid.base.L);
            recalcBreakeven.L = true;
         }
      }

      if (grid.level.S==0) /*&&*/ if (grid.direction!=D_LONG) {
         double last.grid.base.S = grid.base.S;
         grid.base.S = MathMax(grid.base.S, NormalizeDouble((Bid + Ask)/2, Digits));
         if (NE(grid.base.S, last.grid.base.S)) {
            Grid.BaseChange(D_SHORT, TimeCurrent(), grid.base.S);
            recalcBreakeven.S = true;
         }
      }


      // (6) ggf. Breakeven neu berechnen oder (ab dem ersten ausgeführten Trade) Anzeige aktualisieren
      if (recalcBreakeven.L || recalcBreakeven.S) {
         Grid.CalculateBreakeven();
      }
      else if (grid.maxLevel.L-grid.maxLevel.S != 0) {
         if      (  !IsTesting()) HandleEvent(EVENT_BAR_OPEN/*, F_PERIOD_M1*/);  // jede Minute    TODO: EventListener muß Event auch ohne permanenten Aufruf erkennen
         else if (IsVisualMode()) HandleEvent(EVENT_BAR_OPEN);                   // nur onBarOpen        (langlaufendes UpdateStatus() überspringt evt. Event)
      }
   }


   // (7) ggf. Ort der Statusdatei aktualisieren
   if (updateStatusLocation)
      UpdateStatusLocation();

   return(IsNoError(last_error|catch("UpdateStatus(4)")));
}


/**
 * Logmessage für ausgeführte PendingOrder
 *
 * @param  int i - Index der Order in den Grid-Arrays
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
 * @param  int i - Index der Order in den Grid-Arrays
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
 * @param  int i - Index der Order in den Grid-Arrays
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
 * @param  int i - Index der Order in den Grid-Arrays
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
   if (status != STATUS_STOPPING)      return(_NULL(catch("UpdateStatus.CalculateStopTime(1)   cannot calculate stop time for "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
   if (grid.level.L-grid.level.S == 0) return(_NULL(catch("UpdateStatus.CalculateStopTime(2)   cannot calculate stop time for sequence at level "+ str.grid.level.LS, ERR_RUNTIME_ERROR)));

   datetime stopTime;
   int n.L=grid.level.L, n.S=grid.level.S, sizeofTickets=ArraySize(orders.ticket);

   for (int i=sizeofTickets-1; n.L-n.S > 0; i--) {
      if (orders.closeTime[i] == 0) {
         if (IsTesting() && __WHEREAMI__==FUNC_DEINIT && orders.type[i]==OP_UNDEFINED)
            continue;                                                // offene Pending-Orders ignorieren
         return(_NULL(catch("UpdateStatus.CalculateStopTime(3)   #"+ orders.ticket[i] +" is not closed", ERR_RUNTIME_ERROR)));
      }
      if (orders.type[i] == OP_UNDEFINED)                            // gestrichene Pending-Orders ignorieren
         continue;
      if (orders.closedBySL[i])                                      // ausgestoppte Positionen ignorieren
         continue;

      if (orders.level[i] > 0) {
         if (orders.level[i] != n.L) return(_NULL(catch("UpdateStatus.CalculateStopTime(4)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n.L, ERR_RUNTIME_ERROR)));
         n.L--;
      }
      else {
         if (orders.level[i] != n.S) return(_NULL(catch("UpdateStatus.CalculateStopTime(5)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n.S, ERR_RUNTIME_ERROR)));
         n.S++;
      }
      stopTime = Max(stopTime, orders.closeTime[i]);
   }
   return(stopTime);
}


/**
 * Ermittelt den durchschnittlichen StopPrice der aktuell gestoppten Sequenz. Aufruf nur nach externem Sequencestop.
 *
 * @return double - Preis oder NULL, falls ein Fehler auftrat
 */
double UpdateStatus.CalculateStopPrice() {
   if (status != STATUS_STOPPING)      return(_NULL(catch("UpdateStatus.CalculateStopPrice(1)   cannot calculate stop price for "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
   if (grid.level.L-grid.level.S == 0) return(_NULL(catch("UpdateStatus.CalculateStopPrice(2)   cannot calculate stop price for sequence at level "+ str.grid.level.LS, ERR_RUNTIME_ERROR)));

   double stopPrice.L, stopPrice.S, stopPrice;
   int n.L=grid.level.L, n.S=grid.level.S, sizeofTickets=ArraySize(orders.ticket);

   for (int i=sizeofTickets-1; n.L-n.S > 0; i--) {
      if (orders.closeTime[i] == 0) {
         if (IsTesting() && __WHEREAMI__==FUNC_DEINIT && orders.type[i]==OP_UNDEFINED)
            continue;                                                // offene Pending-Orders ignorieren
         return(_NULL(catch("UpdateStatus.CalculateStopPrice(3)   #"+ orders.ticket[i] +" is not closed", ERR_RUNTIME_ERROR)));
      }
      if (orders.type[i] == OP_UNDEFINED)                            // gestrichene Pending-Orders ignorieren
         continue;
      if (orders.closedBySL[i])                                      // ausgestoppte Positionen ignorieren
         continue;

      if (orders.level[i] > 0) {
         if (orders.level[i] != n.L) return(_NULL(catch("UpdateStatus.CalculateStopPrice(4)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n.L, ERR_RUNTIME_ERROR)));
         stopPrice.L += orders.closePrice[i];
         n.L--;
      }
      else {
         if (orders.level[i] != n.S) return(_NULL(catch("UpdateStatus.CalculateStopPrice(5)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n.S, ERR_RUNTIME_ERROR)));
         stopPrice.S += orders.closePrice[i];
         n.S++;
      }
   }

   if      (grid.level.L && grid.level.S) stopPrice = (stopPrice.L/grid.level.L - stopPrice.S/grid.level.S)/2;
   else if (grid.level.L > 0)             stopPrice =  stopPrice.L/grid.level.L;
   else                                   stopPrice = -stopPrice.S/grid.level.S;

   return(NormalizeDouble(stopPrice, Digits));
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
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
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
         return(_false(SetLastError(stdlib_PeekLastError())));

      ArrayPushString(commands, ObjectDescription(label));
      ObjectDelete(label);

      if (!ReleaseLock(mutex))
         return(_false(SetLastError(stdlib_PeekLastError())));

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
         // StopLoss aus Griddaten verwenden (bei client-seitiger Verwaltung nur dort gespeichert)
         int i = SearchIntArray(orders.ticket, OrderTicket());

         if (i == -1)                   return(_false(catch("IsOrderClosedBySL(1)   #"+ OrderTicket() +" not found in grid arrays", ERR_RUNTIME_ERROR)));
         if (EQ(orders.stopLoss[i], 0)) return(_false(catch("IsOrderClosedBySL(2)   #"+ OrderTicket() +" no stop-loss found in grid arrays", ERR_RUNTIME_ERROR)));

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
 * @return bool - ob alle konfigurierten Startbedingungen erfüllt sind
 */
bool IsStartSignal() {
   if (__STATUS__CANCELLED)                                       return(false);
   if (status!=STATUS_WAITING) /*&&*/ if (status!=STATUS_STOPPED) return(false);

   if (start.conditions) {
      if (start.conditions.triggered) {
         warn("IsStartSignal(1)   repeated triggered state call");   // Einmal getriggert, immer getriggert. Falls der Start beim aktuellen Tick nicht ausgeführt
         return(true);                                               // werden konnte, könnten die Bedingungen beim nächsten Tick schon nicht mehr erfüllt sein.
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
         if (__LOG) log(StringConcatenate("IsStartSignal()   price condition \"", scpDescr[start.price.type], " = ", NumberToStr(start.price.value, PriceFormat), "\" met"));
      }

      // -- start.time: zum angegebenen Zeitpunkt oder danach erfüllt ---------------------------------------------------
      if (start.time.condition) {
         if (TimeCurrent() < start.time.value)
            return(false);
         if (__LOG) log(StringConcatenate("IsStartSignal()   time condition \"", TimeToStr(start.time.value, TIME_FULL), "\" met"));
      }

      // -- alle Bedingungen sind erfüllt (AND-Verknüpfung) -------------------------------------------------------------
   }
   else {
      // Keine Startbedingungen sind ebenfalls gültiges Startsignal
      if (__LOG) log("IsStartSignal()   no start conditions defined");
   }

   start.conditions.triggered = true;
   return(true);
}


/**
 * Signalgeber für ResumeSequence().
 *
 * @return bool
 */
bool IsResumeSignal() {
   if (__STATUS__CANCELLED || status!=STATUS_STOPPED)
      return(false);

   if (start.conditions)
      return(IsStartSignal());

   return(IsWeekendResumeSignal());
}


/**
 * Signalgeber für ResumeSequence(). Prüft, ob die Weekend-Stop-Bedingung erfüllt ist.
 *
 * @return bool
 */
bool IsWeekendResumeSignal() {
   if (__STATUS__CANCELLED)                                                                               return(false);
   if (status!=STATUS_STOPPED) /*&&*/ if (status!=STATUS_STARTING) /*&&*/ if (status!=STATUS_PROGRESSING) return(false);

   if (weekend.resume.triggered) return( true);
   if (weekend.resume.time == 0) return(false);

   static datetime sessionStartTime, last.weekend.resume.time;
   static double   lastPrice;
   static bool     lastPrice_init = true;


   // (1) für jeden neuen Resume-Wert sessionstartTime re-initialisieren
   if (weekend.resume.time != last.weekend.resume.time) {
      sessionStartTime = GetServerSessionStartTime(weekend.resume.time);         // throws ERR_INVALID_TIMEZONE_CONFIG, ERR_MARKET_CLOSED
      if (sessionStartTime == -1) {
         if (SetLastError(stdlib_GetLastError()) == ERR_MARKET_CLOSED)
            catch("IsWeekendResumeSignal(1)   cannot resolve session start time for illegal weekend.resume.time '"+ TimeToStr(weekend.resume.time, TIME_FULL) +"'", ERR_RUNTIME_ERROR);
         return(false);
      }
      last.weekend.resume.time = weekend.resume.time;
      lastPrice_init           = true;
   }


   // (2) Resume-Bedingung wird erst ab Beginn der Resume-Session geprüft (i.d.R. Montag 00:00)
   if (TimeCurrent() < sessionStartTime)
      return(false);


   // (3) Bedingung ist erfüllt, wenn der Stop-Preis erreicht oder gekreuzt wird
   double price, stopPrice=sequenceStop.price[ArraySize(sequenceStop.price)-1];
   bool   result;

   if (grid.level.L > 0) {
      if (grid.level.S < 0)   price = NormalizeDouble((Bid + Ask)/2, Digits);
      else                    price = Ask;
   }
   else if (grid.level.S < 0) price = Bid;
   else                       price = NormalizeDouble((Bid + Ask)/2, Digits);

   if (lastPrice_init) {
      lastPrice_init = false;
   }
   else if (lastPrice < stopPrice) {
      result = (price >= stopPrice);                                             // Preis hat Stop-Preis von unten nach oben gekreuzt
   }
   else {
      result = (price <= stopPrice);                                             // Preis hat Stop-Preis von oben nach unten gekreuzt
   }
   lastPrice = price;

   if (result) {
      weekend.resume.triggered = true;
      if (__LOG) log(StringConcatenate("IsWeekendResumeSignal()   weekend stop price \"", NumberToStr(stopPrice, PriceFormat), "\" met"));
      return(true);
   }


   // (4) Bedingung ist spätestens zur konfigurierten Resume-Zeit erfüllt
   datetime now = TimeCurrent();
   if (weekend.resume.time <= now) {
      if (weekend.resume.time/DAYS == now/DAYS) {                                // stellt sicher, daß Signal nicht von altem Datum getriggert wird
         weekend.resume.triggered = true;
         if (__LOG) log(StringConcatenate("IsWeekendResumeSignal()   time condition '", GetDayOfWeek(weekend.resume.time, false), ", ", TimeToStr(weekend.resume.time, TIME_FULL), "' met"));
         return(true);
      }
   }
   return(false);
}


/**
 * Aktualisiert die Bedingungen für ResumeSequence() nach der Wochenend-Pause.
 */
void UpdateWeekendResume() {
   if (__STATUS__CANCELLED)      return;
   if (status != STATUS_STOPPED) return(_NULL(catch("UpdateWeekendResume(1)   cannot update weekend resume conditions of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
   if (!IsWeekendStopSignal())   return(_NULL(catch("UpdateWeekendResume(2)   cannot update weekend resume conditions without weekend stop", ERR_RUNTIME_ERROR)));

   weekend.resume.triggered = false;

   datetime monday, stop=ServerToFXT(sequenceStop.time[ArraySize(sequenceStop.time)-1]);

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
   //debug("UpdateWeekendResume()   '"+ TimeToStr(TimeCurrent(), TIME_FULL) +"': resume condition updated to '"+ GetDayOfWeek(weekend.resume.time, false) +", "+ TimeToStr(weekend.resume.time, TIME_FULL) +"'");
}


/**
 * Signalgeber für StopSequence(). Die einzelnen Bedingungen sind OR-verknüpft.
 *
 * @param bool checkWeekendStop - ob auch auf das Wochenend-Stopsignal geprüft werden soll (default: ja)
 *
 * @return bool - ob mindestens eine Stopbedingung erfüllt ist
 */
bool IsStopSignal(bool checkWeekendStop=true) {
   if (__STATUS__CANCELLED || status!=STATUS_PROGRESSING)
      return(false);

   // (1) User-definierte StopConditions prüfen
   if (stop.conditions) {
      if (stop.conditions.triggered) {
         warn("IsStopSignal(1)   repeated triggered state call");    // Einmal getriggert, immer getriggert. Falls der Stop beim aktuellen Tick nicht ausgeführt
         return(true);                                               // werden konnte, könnten die Bedingungen beim nächsten Tick schon nicht mehr erfüllt sein.
      }

      // -- stop.price: erfüllt, wenn der entsprechende Preis den Wert berührt oder kreuzt ------------------------------
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
            if (__LOG) log(StringConcatenate("IsStopSignal()   price condition \"", scpDescr[stop.price.type], " = ", NumberToStr(stop.price.value, PriceFormat), "\" met"));
            stop.conditions.triggered = true;
            return(true);
         }
      }

      // -- stop.time: zum angegebenen Zeitpunkt oder danach erfüllt ----------------------------------------------------
      if (stop.time.condition) {
         if (stop.time.value <= TimeCurrent()) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   time condition \"", TimeToStr(stop.time.value, TIME_FULL), "\" met"));
            stop.conditions.triggered = true;
            return(true);
         }
      }

      // -- stop.profitAbs: ---------------------------------------------------------------------------------------------
      if (stop.profitAbs.condition) {
         if (GE(grid.totalPL, stop.profitAbs.value)) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   profit condition \"", DoubleToStr(stop.profitAbs.value, 2), "\" met"));
            stop.conditions.triggered = true;
            return(true);
         }
      }

      // -- stop.profitPercent: -----------------------------------------------------------------------------------------
      if (stop.profitPercent.condition) {
         if (GE(grid.totalPL, stop.profitPercent.value/100 * sequenceStartEquity)) {
            if (__LOG) log(StringConcatenate("IsStopSignal()   profit condition \"", NumberToStr(stop.profitPercent.value, ".+"), "%\" met"));
            stop.conditions.triggered = true;
            return(true);
         }
      }

      // -- keine der Bedingungen ist erfüllt (OR-Verknüpfung) ----------------------------------------------------------
   }
   stop.conditions.triggered = false;


   // (2) je nach Aufruf zusätzlich interne WeekendStop-Bedingung prüfen
   if (checkWeekendStop)
      return(IsWeekendStopSignal());

   return(false);
}


/**
 * Signalgeber für StopSequence(). Prüft, ob die WeekendStop-Bedingung erfüllt ist.
 *
 * @return bool
 */
bool IsWeekendStopSignal() {
   if (__STATUS__CANCELLED)                                                                               return(false);
   if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STOPPING) /*&&*/ if (status!=STATUS_STOPPED) return(false);

   if (weekend.stop.triggered) return( true);
   if (weekend.stop.time == 0) return(false);

   datetime now = TimeCurrent();

   if (weekend.stop.time <= now) {
      if (weekend.stop.time/DAYS == now/DAYS) {                               // stellt sicher, daß Signal nicht von altem Datum getriggert wird
         weekend.stop.triggered = true;
         if (__LOG) log(StringConcatenate("IsWeekendStopSignal()   time condition '", GetDayOfWeek(weekend.stop.time, false), ", ", TimeToStr(weekend.stop.time, TIME_FULL), "' met"));
         return(true);
      }
   }
   return(false);
}


/**
 * Aktualisiert die Bedingungen für StopSequence() vor der Wochenend-Pause.
 */
void UpdateWeekendStop() {
   weekend.stop.triggered = false;

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
      weekend.stop.time = (friday/DAYS)*DAYS + D'1970.01.01 23:55'%DAY;    // wenn Aufruf nach regulärem Stop, erfolgt neuer Stop 5 Minuten vor Handelsschluß
   weekend.stop.time = FXTToServerTime(weekend.stop.time);
   //debug("UpdateWeekendStop()   '"+ TimeToStr(TimeCurrent(), TIME_FULL) +"': stop condition updated to '"+ GetDayOfWeek(weekend.stop.time, false) +", "+ TimeToStr(weekend.stop.time, TIME_FULL) +"'");
}


/**
 * Ob der angegebene client-seitige Stop-Wert erreicht wurde.
 *
 * @param  int    type - Stop-Typ: OP_BUYSTOP|OP_SELLSTOP|OP_BUY|OP_SELL
 * @param  double stop - Stop-Wert
 *
 * @return bool
 */
bool IsStopTriggered(int type, double stop) {
   if (type == OP_BUYSTOP ) return(Ask >= stop);                         // pending Buy-Stop
   if (type == OP_SELLSTOP) return(Bid <= stop);                         // pending Sell-Stop

   if (type == OP_BUY     ) return(Bid <= stop);                         // Long-StopLoss
   if (type == OP_SELL    ) return(Ask >= stop);                         // Short-StopLoss

   return(_false(catch("IsStopTriggered()   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Ordermanagement getriggerter client-seitiger Limits. Kann eine getriggerte Limit-Order oder ein getriggerter Take-Profit sein.
 * Aufruf nur aus onTick()
 *
 * @param int limits[] - Array-Indizes der Orders mit getriggerten Limits
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessClientLimits(int limits[]) {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("ProcessClientLimits(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)         return(_false(catch("ProcessClientLimits(2)   cannot process client-side limits of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   int size = ArraySize(limits);
   if (size == 0)
      return(true);

   return(_false(catch("ProcessClientLimits(3)", ERR_FUNCTION_NOT_IMPLEMENTED)));
}


/**
 * Ordermanagement getriggerter client-seitiger Stops. Kann eine getriggerte Stop-Order oder ein getriggerter Stop-Loss sein.
 * Aufruf nur aus onTick()
 *
 * @param int stops[] - Array-Indizes der Orders mit getriggerten Stops
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessClientStops(int stops[]) {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("ProcessClientStops(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)         return(_false(catch("ProcessClientStops(2)   cannot process client-side stops of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   int sizeOfStops = ArraySize(stops);
   if (sizeOfStops == 0)
      return(true);

   int button, ticket;
   /*ORDER_EXECUTION*/int oe[]; InitializeBuffer(oe, ORDER_EXECUTION.size);


   // (1) der Stop kann eine getriggerte Pending-Order (OP_BUYSTOP, OP_SELLSTOP) oder ein getriggerter Stop-Loss sein
   for (int i, n=0; n < sizeOfStops; n++) {
      i = stops[n];
      if (i > ArraySize(orders.ticket))      return(_false(catch("ProcessClientStops(3)   illegal value "+ i +" in parameter stops = "+ IntsToStr(stops, NULL), ERR_INVALID_FUNCTION_PARAMVALUE)));


      // (2) getriggerte Pending-Order (OP_BUYSTOP, OP_SELLSTOP)
      if (orders.ticket[i] == -1) {
         if (orders.type[i] != OP_UNDEFINED) return(_false(catch("ProcessClientStops(4)   client-side "+ OperationTypeDescription(orders.pendingType[i]) +" order at index "+ i +" already marked as open", ERR_ILLEGAL_STATE)));

         if (firstTick) /*&&*/ if (!firstTickConfirmed) {                     // Bestätigungsprompt bei Traderequest beim ersten Tick
            if (!IsTesting()) {
               ForceSound("notify.wav");
               button = ForceMessageBox(__NAME__ +" - ProcessClientStops()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to execute a triggered "+ OperationTypeDescription(orders.pendingType[i]) +" order now?", MB_ICONQUESTION|MB_OKCANCEL);
               if (button != IDOK) {
                  __STATUS__CANCELLED = true;
                  return(_false(catch("ProcessClientStops(5)")));
               }
               RefreshRates();
            }
         }
         firstTickConfirmed = true;

         int  type     = orders.pendingType[i] - 4;
         int  level    = orders.level      [i];
         bool clientSL = false;                                               // zuerst versuchen, server-seitigen StopLoss zu setzen...

         ticket = SubmitMarketOrder(type, level, clientSL, oe);

         // (2.1) ab dem letzten Level ggf. client-seitige Stop-Verwaltung
         orders.clientSL[i] = ticket <= 0;

         if (ticket <= 0) {
            if (level!=grid.level.L) /*&&*/ if (level!=grid.level.S) return( false);
            if (oe.Error(oe) != ERR_INVALID_STOP)                    return( false);
            if (ticket==0 || ticket < -2)                            return(_false(catch("ProcessClientStops(6)", oe.Error(oe))));

            double stopLoss = oe.StopLoss(oe);

            // (2.2) Spread violated
            if (ticket == -1) {
               return(_false(catch("ProcessClientStops(7)   spread violated ("+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +") by "+ OperationTypeDescription(type) +" at "+ NumberToStr(oe.OpenPrice(oe), PriceFormat) +", sl="+ NumberToStr(stopLoss, PriceFormat) +" (level "+ level +")", oe.Error(oe))));
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
         if (orders.ticket[i] == -2)         return(_false(catch("ProcessClientStops(8)   cannot process client-side stoploss of pseudo ticket #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
         if (orders.type[i] == OP_UNDEFINED) return(_false(catch("ProcessClientStops(9)   #"+ orders.ticket[i] +" with client-side stop-loss still marked as pending", ERR_ILLEGAL_STATE)));
         if (orders.closeTime[i] != 0)       return(_false(catch("ProcessClientStops(10)   #"+ orders.ticket[i] +" with client-side stop-loss already marked as closed", ERR_ILLEGAL_STATE)));

         if (firstTick) /*&&*/ if (!firstTickConfirmed) {                              // Bestätigungsprompt bei Traderequest beim ersten Tick
            if (!IsTesting()) {
               ForceSound("notify.wav");
               button = ForceMessageBox(__NAME__ +" - ProcessClientStops()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to execute a triggered stop-loss now?", MB_ICONQUESTION|MB_OKCANCEL);
               if (button != IDOK) {
                  __STATUS__CANCELLED = true;
                  return(_false(catch("ProcessClientStops(11)")));
               }
               RefreshRates();
            }
         }
         firstTickConfirmed = true;

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
   int iNull[];
   if (!UpdateStatus(iNull, iNull)) return(false);
   if (  !SaveStatus())             return(false);

   return(IsNoError(last_error|catch("ProcessClientStops(12)")));
}


/**
 * Aktualisiert vorhandene, setzt fehlende und löscht unnötige PendingOrders.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePendingOrders() {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("UpdatePendingOrders(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)         return(_false(catch("UpdatePendingOrders(2)   cannot update orders of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   int  nextLevel;
   bool nextOrderExists, ordersChanged;


   // (1) Long
   if (grid.direction != D_SHORT) {
      nextLevel       = grid.level.L + 1;
      nextOrderExists = false;
      for (int i=ArraySize(orders.ticket)-1; i >= 0; i--) {
         if (orders.level[i] > 0) {
            if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0) {  // if (isPending && !isClosed)
               if (orders.level[i] == nextLevel) {
                  nextOrderExists = true;
                  if (nextLevel==1) /*&&*/ if (NE(orders.pendingPrice[i], grid.base.L + GridSize*Pips)) {
                     if (!Grid.TrailPendingOrder(i))                                // Order im ersten Level ggf. trailen
                        return(false);
                     ordersChanged = true;
                  }
                  continue;
               }
               if (!Grid.DeleteOrder(i))                                            // unnötige Long-Orders löschen
                  return(false);
               ordersChanged = true;
            }
         }
      }
      if (!nextOrderExists) {
         if (!Grid.AddOrder(OP_BUYSTOP, nextLevel))                                 // nötige Long-Order in den Markt legen
            return(false);
         ordersChanged = true;
      }
   }


   // (2) Short
   if (grid.direction != D_LONG) {
      nextLevel       = grid.level.S - 1;
      nextOrderExists = false;
      for (i=ArraySize(orders.ticket)-1; i >= 0; i--) {
         if (orders.level[i] < 0) {
            if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0) {  // if (isPending && !isClosed)
               if (orders.level[i] == nextLevel) {
                  nextOrderExists = true;
                  if (nextLevel==-1) /*&&*/ if (NE(orders.pendingPrice[i], grid.base.S - GridSize*Pips)) {
                     if (!Grid.TrailPendingOrder(i))                                // Order im ersten Level ggf. trailen
                        return(false);
                     ordersChanged = true;
                  }
                  continue;
               }
               if (!Grid.DeleteOrder(i))                                            // unnötige Short-Orders löschen
                  return(false);
               ordersChanged = true;
            }
         }
      }
      if (!nextOrderExists) {
         if (!Grid.AddOrder(OP_SELLSTOP, nextLevel))                                // nötige Short-Order in den Markt legen
            return(false);
         ordersChanged = true;
      }
   }


   if (ordersChanged)                                                               // Status speichern
      if (!SaveStatus())
         return(false);

   return(IsNoError(last_error|catch("UpdatePendingOrders(3)")));
}


/**
 * Öffnet neue bzw. vervollständigt fehlende der zuletzt offenen Positionen der Sequenz. Aufruf nur in ResumeSequence()
 *
 * @param  int       direction   - Richtung des Grids, dessen offene Positionen aktualisiert werden sollen
 * @param  datetime &lpOpenTime  - Zeiger auf Variable, die die OpenTime der zuletzt geöffneten Position aufnimmt
 * @param  double   &lpOpenPrice - Zeiger auf Variable, die den durchschnittlichen OpenPrice aufnimmt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Im Level 0 (keine Positionen zu öffnen) werden die Variablen, auf die die übergebenen Pointer zeigen, nicht modifiziert.
 */
bool UpdateOpenPositions(int direction, datetime &lpOpenTime, double &lpOpenPrice) {
   if (__STATUS__CANCELLED || IsLastError())             return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                return(_false(catch("UpdateOpenPositions(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_STARTING)                        return(_false(catch("UpdateOpenPositions(2)   cannot update positions of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
   if (direction!=D_LONG) /*&&*/ if (direction!=D_SHORT) return(_false(catch("UpdateOpenPositions(3)   invalid parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int i, level;
   datetime openTime;
   double   openPrice, openRisk;


   // (1) Long
   if (direction == D_LONG) {
      if (grid.level.L > 0) {
         for (level=1; level <= grid.level.L; level++) {
            i = Grid.FindOpenPosition(level);
            if (i == -1) {
               if (!Grid.AddPosition(OP_BUY, level))
                  return(false);
               if (!SaveStatus())                                                   // Status nach jeder Trade-Operation speichern, um das Ticket nicht zu verlieren,
                  return(false);                                                    // wenn in einer der folgenden Operationen ein Fehler auftritt.
               i = ArraySize(orders.ticket) - 1;
            }
            openTime   = Max(openTime, orders.openTime[i]);
            openPrice += orders.openPrice[i];
            openRisk  += orders.openRisk [i];
         }
         openPrice /= grid.level.L;                                                 // avg(OpenPrice)
      }
      grid.openRisk.L    = NormalizeDouble(openRisk, 2);                            // grid.openRisk und grid.valueAtRisk neuberechnen
      grid.valueAtRisk.L = NormalizeDouble(grid.stopsPL.L + grid.openRisk.L, 2); SS.Grid.ValueAtRisk();
   }


   // (2) Short
   if (direction == D_SHORT) {
      if (grid.level.S < 0) {
         for (level=-1; level >= grid.level.S; level--) {
            i = Grid.FindOpenPosition(level);
            if (i == -1) {
               if (!Grid.AddPosition(OP_SELL, level))
                  return(false);
               if (!SaveStatus())                                                   // Status nach jeder Trade-Operation speichern, um das Ticket nicht zu verlieren,
                  return(false);                                                    // wenn in einer der folgenden Operationen ein Fehler auftritt.
               i = ArraySize(orders.ticket) - 1;
            }
            openTime   = Max(openTime, orders.openTime[i]);
            openPrice += orders.openPrice[i];
            openRisk  += orders.openRisk [i];
         }
         openPrice /= -grid.level.S;                                                // avg(OpenPrice)
      }
      grid.openRisk.S    = NormalizeDouble(openRisk, 2);                            // grid.openRisk und grid.valueAtRisk neuberechnen
      grid.valueAtRisk.S = NormalizeDouble(grid.stopsPL.S + grid.openRisk.S, 2); SS.Grid.ValueAtRisk();
   }


   // (3) Ergebnis setzen
   if (openTime != 0) {                                                             // grid.level != 0
      lpOpenTime  = openTime;
      lpOpenPrice = NormalizeDouble(openPrice, Digits);
   }

   return(IsNoError(last_error|catch("UpdateOpenPositions(4)")));
}


/**
 * Löscht alle gespeicherten Änderungen der Gridbasis und initialisiert sie mit dem angegebenen Wert.
 *
 * @param  int      direction - Richtung des Grids, dessen Gridbasis geändert wird
 * @param  datetime time      - Zeitpunkt
 * @param  double   value     - neue Gridbasis
 *
 * @return double - die neue Gridbasis oder 0, falls ein Fehler auftrat
 */
double Grid.BaseReset(int direction, datetime time, double value) {
   // (1) Long
   if (direction == D_LONG) {
      ArrayResize(grid.base.L.event, 0);
      ArrayResize(grid.base.L.time,  0);
      ArrayResize(grid.base.L.value, 0);
      return(Grid.BaseChange(direction, time, value));
   }

   // (2) Short
   if (direction == D_SHORT) {
      ArrayResize(grid.base.S.event, 0);
      ArrayResize(grid.base.S.time,  0);
      ArrayResize(grid.base.S.value, 0);
      return(Grid.BaseChange(direction, time, value));
   }

   return(_NULL(catch("Grid.BaseReset()   invalid parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Speichert eine Änderung der Gridbasis.
 *
 * @param  int      direction - Richtung des Grids, dessen Gridbasis sich ändert
 * @param  datetime time      - Zeitpunkt der Änderung
 * @param  double   value     - neue Gridbasis
 *
 * @return double - die neue Gridbasis oder 0, falls ein Fehler auftrat
 */
double Grid.BaseChange(int direction, datetime time, double value) {
   int size, minutes, lastMinutes;
   value = NormalizeDouble(value, Digits);

   // (1) Long
   if (direction == D_LONG) {
      if (grid.maxLevel.L == 0) {                                    // vor dem ersten ausgeführten Trade werden vorhandene Werte überschrieben
         ArrayResize(grid.base.L.event, 0);
         ArrayResize(grid.base.L.time,  0);
         ArrayResize(grid.base.L.value, 0);
      }

      size = ArraySize(grid.base.L.event);                           // ab dem ersten ausgeführten Trade werden neue Werte angefügt
      if (size == 0) {
         ArrayPushInt   (grid.base.L.event, CreateEventId());
         ArrayPushInt   (grid.base.L.time,  time           );
         ArrayPushDouble(grid.base.L.value, value          );
      }
      else {
         minutes=time/MINUTE; lastMinutes=grid.base.L.time[size-1]/MINUTE;
         if (minutes == lastMinutes) {
            grid.base.L.event[size-1] = CreateEventId();             // Änderungen der aktuellen Minute werden mit neuem Wert überschrieben
            grid.base.L.time [size-1] = time;
            grid.base.L.value[size-1] = value;
         }
         else {
            ArrayPushInt   (grid.base.L.event, CreateEventId());
            ArrayPushInt   (grid.base.L.time,  time           );
            ArrayPushDouble(grid.base.L.value, value          );
         }
      }
      grid.base.L = value; SS.Grid.Base();
      return(value);
   }


   // (2) Short
   if (direction == D_SHORT) {
      if (grid.maxLevel.S == 0) {                                    // vor dem ersten ausgeführten Trade werden vorhandene Werte überschrieben
         ArrayResize(grid.base.S.event, 0);
         ArrayResize(grid.base.S.time,  0);
         ArrayResize(grid.base.S.value, 0);
      }

      size = ArraySize(grid.base.S.event);                           // ab dem ersten ausgeführten Trade werden neue Werte angefügt
      if (size == 0) {
         ArrayPushInt   (grid.base.S.event, CreateEventId());
         ArrayPushInt   (grid.base.S.time,  time           );
         ArrayPushDouble(grid.base.S.value, value          );
      }
      else {
         minutes=time/MINUTE; lastMinutes=grid.base.S.time[size-1]/MINUTE;
         if (minutes == lastMinutes) {
            grid.base.S.event[size-1] = CreateEventId();             // Änderungen der aktuellen Minute werden mit neuem Wert überschrieben
            grid.base.S.time [size-1] = time;
            grid.base.S.value[size-1] = value;
         }
         else {
            ArrayPushInt   (grid.base.S.event, CreateEventId());
            ArrayPushInt   (grid.base.S.time,  time           );
            ArrayPushDouble(grid.base.S.value, value          );
         }
      }
      grid.base.S = value; SS.Grid.Base();
      return(value);
   }

   return(_NULL(catch("Grid.BaseChange()   invalid parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Legt die angegebene Stop-Order in den Markt und fügt den Gridarrays deren Daten hinzu.
 *
 * @param  int type  - Ordertyp: OP_BUYSTOP | OP_SELLSTOP
 * @param  int level - Gridlevel der Order
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.AddOrder(int type, int level) {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("Grid.AddOrder(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)         return(_false(catch("Grid.AddOrder(2)   cannot add order for "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));


   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                  // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - Grid.AddOrder()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to submit a new "+ OperationTypeDescription(type) +" order now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("Grid.AddOrder(3)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;


   // (1) Order in den Markt legen
   /*ORDER_EXECUTION*/int oe[]; InitializeBuffer(oe, ORDER_EXECUTION.size);
   int ticket = SubmitStopOrder(type, level, oe);

   double pendingPrice = oe.OpenPrice(oe);

   if (ticket <= 0) {
      if (oe.Error(oe) != ERR_INVALID_STOP) return( false);
      if (ticket == 0)                      return(_false(catch("Grid.AddOrder(4)", oe.Error(oe))));

      // (2) Spread violated
      if (ticket == -1) {
         return(_false(catch("Grid.AddOrder(5)   spread violated ("+ NumberToStr(oe.Bid(oe), PriceFormat) +"/"+ NumberToStr(oe.Ask(oe), PriceFormat) +") by "+ OperationTypeDescription(type) +" at "+ NumberToStr(pendingPrice, PriceFormat) +" (level "+ level +")", oe.Error(oe))));
      }

      // (3) StopDistance violated (client-seitige Stop-Verwaltung)
      else if (ticket == -2) {
         ticket = -1;
         if (__LOG) log(StringConcatenate("Grid.AddOrder()   client-side ", OperationTypeDescription(type), " at ", NumberToStr(pendingPrice, PriceFormat), " installed (level ", level, ")"));
      }
   }

   // (4) Daten speichern
   //int    ticket       = ...                                          // unverändert
   //int    level        = ...                                          // unverändert
   double   grid.base    = ifDouble(level>0, grid.base.L, grid.base.S);

   int      pendingType  = type;
   datetime pendingTime  = oe.OpenTime(oe);  if (ticket < 0) pendingTime = TimeCurrent();
   //double pendingPrice = ...                                          // unverändert

   /*int*/  type         = OP_UNDEFINED;
   int      openEvent    = NULL;
   datetime openTime     = NULL;
   double   openPrice    = NULL;
   double   openRisk     = NULL;

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

   if (!Grid.PushData(ticket, level, grid.base, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, openRisk, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit))
      return(false);
   return(IsNoError(last_error|catch("Grid.AddOrder(6)")));
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
 *  Return-Codes mit besonderer Bedeutung:
 *  --------------------------------------
 *  -1: der StopPrice verletzt den aktuellen Spread
 *  -2: der StopPrice verletzt die StopDistance des Brokers
 */
int SubmitStopOrder(int type, int level, int oe[]) {
   if (__STATUS__CANCELLED || IsLastError())                           return(-1);
   if (IsTest()) /*&&*/ if (!IsTesting())                              return(_int(-1, catch("SubmitStopOrder(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STARTING) return(_int(-1, catch("SubmitStopOrder(2)   cannot submit stop order for "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   if (type == OP_BUYSTOP) {
      if (level <= 0) return(_int(-1, catch("SubmitStopOrder(3)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else if (type == OP_SELLSTOP) {
      if (level >= 0) return(_int(-1, catch("SubmitStopOrder(4)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else               return(_int(-1, catch("SubmitStopOrder(5)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double   stopPrice   = ifDouble(level>0, grid.base.L, grid.base.S) + level*GridSize*Pips;
   double   slippage    = NULL;
   double   stopLoss    = stopPrice - Sign(level) * GridSize * Pips;
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
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())    return(_false(catch("Grid.AddPosition(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_STARTING)            return(_false(catch("Grid.AddPosition(2)   cannot add market position to "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   if (level == 0)                           return(_false(catch("Grid.AddPosition(3)   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                                          // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - Grid.AddPosition()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to submit a Market "+ OperationTypeDescription(type) +" order now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("Grid.AddPosition(4)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;


   // (1) Position öffnen
   /*ORDER_EXECUTION*/int oe[]; InitializeBuffer(oe, ORDER_EXECUTION.size);
   bool clientSL = false;
   int  ticket   = SubmitMarketOrder(type, level, clientSL, oe);        // zuerst versuchen, server-seitigen StopLoss zu setzen...

   double stopLoss = oe.StopLoss(oe);

   if (ticket <= 0) {
      // ab dem letzten Level ggf. client-seitige Stop-Verwaltung
      if (level!=grid.level.L) /*&&*/ if (level!=grid.level.S) return( false);
      if (oe.Error(oe) != ERR_INVALID_STOP)                    return( false);
      if (ticket==0 || ticket < -2)                            return(_false(catch("Grid.AddPosition(5)", oe.Error(oe))));

      // (2) Spread violated
      if (ticket == -1) {
         ticket   = -2;                                                 // Pseudo-Ticket "öffnen" (wird beim nächsten UpdateStatus() mit P/L=0.00 "geschlossen")
         clientSL = true;
         oe.setOpenTime(oe, TimeCurrent());
         if (__LOG) log(StringConcatenate("Grid.AddPosition()   pseudo ticket #", ticket, " opened for spread violation (", NumberToStr(oe.Bid(oe), PriceFormat), "/", NumberToStr(oe.Ask(oe), PriceFormat), ") by ", OperationTypeDescription(type), " at ", NumberToStr(oe.OpenPrice(oe), PriceFormat), ", sl=", NumberToStr(stopLoss, PriceFormat), " (level ", level, ")"));
      }

      // (3) StopDistance violated
      else if (ticket == -2) {
         clientSL = true;
         ticket   = SubmitMarketOrder(type, level, clientSL, oe);       // danach client-seitige Stop-Verwaltung
         if (ticket <= 0)
            return(false);
         if (__LOG) log(StringConcatenate("Grid.AddPosition()   #", ticket, " client-side stop-loss at ", NumberToStr(stopLoss, PriceFormat), " installed (level ", level, ")"));
      }
   }

   // (4) Daten speichern
   //int    ticket       = ...                                          // unverändert
   //int    level        = ...                                          // unverändert
   double   grid.base    = ifDouble(level>0, grid.base.L, grid.base.S);

   int      pendingType  = OP_UNDEFINED;
   datetime pendingTime  = NULL;
   double   pendingPrice = NULL;

   //int    type         = ...                                          // unverändert
   int      openEvent    = CreateEventId();
   datetime openTime     = oe.OpenTime (oe);
   double   openPrice    = oe.OpenPrice(oe);

   int      closeEvent   = NULL;
   datetime closeTime    = NULL;
   double   closePrice   = NULL;
   //double stopLoss     = ...                                          // unverändert
   //bool   clientSL     = ...                                          // unverändert
   bool     closedBySL   = false;

   double   swap         = oe.Swap      (oe);                           // falls Swap bereits bei OrderOpen gesetzt sein sollte
   double   commission   = oe.Commission(oe);
   double   profit       = NULL;
   double   openRisk     = NULL;                                        // wird nach Grid.PushData() gesetzt

   if (!Grid.PushData(ticket, level, grid.base, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, openRisk, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit))
      return(false);

   int i = ArraySize(orders.ticket) - 1;
   orders.openRisk[i] = CalculateOpenRisk(i);

   ArrayResize(oe, 0);
   return(IsNoError(last_error|catch("Grid.AddPosition(6)")));
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
   if (__STATUS__CANCELLED || IsLastError())                           return(0);
   if (IsTest()) /*&&*/ if (!IsTesting())                              return(_ZERO(catch("SubmitMarketOrder(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_STARTING) /*&&*/ if (status!=STATUS_PROGRESSING) return(_ZERO(catch("SubmitMarketOrder(2)   cannot submit market order for "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

   if (type == OP_BUY) {
      if (level <= 0) return(_ZERO(catch("SubmitMarketOrder(3)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else if (type == OP_SELL) {
      if (level >= 0) return(_ZERO(catch("SubmitMarketOrder(4)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else               return(_ZERO(catch("SubmitMarketOrder(5)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double   price       = NULL;
   double   slippage    = 0.1;
   double   stopLoss    = ifDouble(clientSL, NULL, ifDouble(level>0, grid.base.L, grid.base.S) + (level-Sign(level))*GridSize*Pips);
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

   if (!clientSL) /*&&*/ if (level>=grid.level.L || level<=grid.level.S)
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
 * Justiert PendingOpenPrice() und StopLoss() der angegebenen Order und aktualisiert die Gridarrays.
 *
 * @param  int i - Index der Order in den Datenarrays
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.TrailPendingOrder(int i) {
   if (__STATUS__CANCELLED || IsLastError())   return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())      return(_false(catch("Grid.TrailPendingOrder(1)", ERR_ILLEGAL_STATE)));
   if (status != STATUS_PROGRESSING)           return(_false(catch("Grid.TrailPendingOrder(2)   cannot trail order of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
   if (i < 0 || i >= ArraySize(orders.ticket)) return(_false(catch("Grid.TrailPendingOrder(3)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (orders.type[i] != OP_UNDEFINED)         return(_false(catch("Grid.TrailPendingOrder(4)   cannot trail "+ OperationTypeDescription(orders.type[i]) +" position #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
   if (orders.closeTime[i] != 0)               return(_false(catch("Grid.TrailPendingOrder(5)   cannot trail cancelled "+ OperationTypeDescription(orders.type[i]) +" order #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));

   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                  // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - Grid.TrailPendingOrder()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to modify the "+ OperationTypeDescription(orders.pendingType[i]) +" order #"+ orders.ticket[i] +" now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("Grid.TrailPendingOrder(6)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;

   double grid.base   = ifDouble(orders.level[i]>0, grid.base.L, grid.base.S);
   double stopPrice   = NormalizeDouble(grid.base +      orders.level[i]  * GridSize * Pips, Digits);
   double stopLoss    = NormalizeDouble(stopPrice - Sign(orders.level[i]) * GridSize * Pips, Digits);
   color  markerColor = CLR_PENDING;
   int    oeFlags     = NULL;

   if (EQ(orders.pendingPrice[i], stopPrice)) /*&&*/ if (EQ(orders.stopLoss[i], stopLoss))
      return(_false(catch("Grid.TrailPendingOrder(7)   nothing to modify for #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));

   if (orders.ticket[i] < 0) {                                       // client-seitige Orders
      // TODO: ChartMarker nachziehen
   }
   else {                                                            // server-seitige Orders
      /*ORDER_EXECUTION*/int oe[]; InitializeBuffer(oe, ORDER_EXECUTION.size);
      if (!OrderModifyEx(orders.ticket[i], stopPrice, stopLoss, NULL, NULL, markerColor, oeFlags, oe))
         return(_false(SetLastError(oe.Error(oe))));
      ArrayResize(oe, 0);
   }

   orders.gridBase    [i] = grid.base;
   orders.pendingTime [i] = TimeCurrent();
   orders.pendingPrice[i] = stopPrice;
   orders.stopLoss    [i] = stopLoss;

   return(IsNoError(last_error|catch("Grid.TrailPendingOrder(8)")));
}


/**
 * Streicht die angegebene Order und entfernt sie aus den Datenarrays des Grids.
 *
 * @param  int i - Index der Order in den Datenarrays
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.DeleteOrder(int i) {
   if (__STATUS__CANCELLED || IsLastError())                                   return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                                      return(_false(catch("Grid.DeleteOrder(1)", ERR_ILLEGAL_STATE)));
   if (status!=STATUS_PROGRESSING) /*&&*/ if (status!=STATUS_STOPPING)
      if (!IsTesting() || __WHEREAMI__!=FUNC_DEINIT || status!=STATUS_STOPPED) return(_false(catch("Grid.DeleteOrder(2)   cannot delete order of "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
   if (i < 0 || i >= ArraySize(orders.ticket))                                 return(_false(catch("Grid.DeleteOrder(3)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (orders.type[i] != OP_UNDEFINED)                                         return(_false(catch("Grid.DeleteOrder(4)   cannot delete "+ ifString(orders.closeTime[i]==0, "open", "closed") +" "+ OperationTypeDescription(orders.type[i]) +" position", ERR_RUNTIME_ERROR)));

   if (firstTick) /*&&*/ if (!firstTickConfirmed) {                  // Bestätigungsprompt bei Traderequest beim ersten Tick
      if (!IsTesting()) {
         ForceSound("notify.wav");
         int button = ForceMessageBox(__NAME__ +" - Grid.DeleteOrder()", ifString(!IsDemo(), "- Live Account -\n\n", "") +"Do you really want to cancel the "+ OperationTypeDescription(orders.pendingType[i]) +" order at level "+ orders.level[i] +" now?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) {
            __STATUS__CANCELLED = true;
            return(_false(catch("Grid.DeleteOrder(5)")));
         }
         RefreshRates();
      }
   }
   firstTickConfirmed = true;

   if (orders.ticket[i] > 0) {
      int oeFlags = NULL;
      /*ORDER_EXECUTION*/int oe[]; InitializeBuffer(oe, ORDER_EXECUTION.size);

      if (!OrderDeleteEx(orders.ticket[i], CLR_NONE, oeFlags, oe))
         return(_false(SetLastError(oe.Error(oe))));
      ArrayResize(oe, 0);
   }

   if (!Grid.DropData(i))
      return(false);

   return(IsNoError(last_error|catch("Grid.DeleteOrder(6)")));
}


/**
 * Fügt die angegebenen Daten den Datenarrays des Grids hinzu.
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
 * @param  double   openRisk
 *
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
bool Grid.PushData(int ticket, int level, double gridBase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, double openRisk, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientSL, bool closedBySL, double swap, double commission, double profit) {
   return(Grid.SetData(-1, ticket, level, gridBase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, openRisk, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit));
}


/**
 * Schreibt die angegebenen Daten an die angegebene Position der Gridarrays.
 *
 * @param  int      position - Gridposition: Ist dieser Wert -1 oder sind die Gridarrays zu klein, werden sie vergrößert.
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
 * @param  double   openRisk
 *
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
bool Grid.SetData(int position, int ticket, int level, double gridBase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, double openRisk, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientSL, bool closedBySL, double swap, double commission, double profit) {
   if (position < -1)
      return(_false(catch("Grid.SetData(1)   illegal parameter position = "+ position, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int i=position, size=ArraySize(orders.ticket);

   if      (position ==     -1) i = ResizeArrays(    size+1) - 1;
   else if (position  > size-1) i = ResizeArrays(position+1) - 1;

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
   orders.openRisk    [i] = NormalizeDouble(openRisk, 2);

   orders.closeEvent  [i] = closeEvent;
   orders.closeTime   [i] = closeTime;
   orders.closePrice  [i] = NormalizeDouble(closePrice, Digits);
   orders.stopLoss    [i] = NormalizeDouble(stopLoss, Digits);
   orders.clientSL    [i] = clientSL;
   orders.closedBySL  [i] = closedBySL;

   orders.swap        [i] = NormalizeDouble(swap,       2);
   orders.commission  [i] = NormalizeDouble(commission, 2); if (type != OP_UNDEFINED) { grid.commission = orders.commission[i]; SS.LotSize(); }
   orders.profit      [i] = NormalizeDouble(profit,     2);

   return(!IsError(catch("Grid.SetData(2)")));
}


/**
 * Entfernt den Datensatz der angegebenen Order aus den Datenarrays.
 *
 * @param  int i - Index der Order in den Datenarrays
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
   ArraySpliceDoubles(orders.openRisk,     i, 1);

   ArraySpliceInts   (orders.closeEvent,   i, 1);
   ArraySpliceInts   (orders.closeTime,    i, 1);
   ArraySpliceDoubles(orders.closePrice,   i, 1);
   ArraySpliceDoubles(orders.stopLoss,     i, 1);
   ArraySpliceBools  (orders.clientSL,     i, 1);
   ArraySpliceBools  (orders.closedBySL,   i, 1);

   ArraySpliceDoubles(orders.swap,         i, 1);
   ArraySpliceDoubles(orders.commission,   i, 1);
   ArraySpliceDoubles(orders.profit,       i, 1);

   return(IsNoError(last_error|catch("Grid.DropData(2)")));
}


/**
 * Sucht eine offene Position des angegebenen Levels und gibt deren Index in den Datenarrays des Grids zurück.
 * Je Level kann es maximal eine offene Position geben.
 *
 * @param  int level - Level der zu suchenden Position
 *
 * @return int - Index der gefundenen Position oder -1, wenn keine offene Position des angegebenen Levels gefunden wurde
 */
int Grid.FindOpenPosition(int level) {
   if (level == 0) return(_int(-1, catch("Grid.FindOpenPosition()   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

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
 * Generiert eine neue Sequenz-ID.
 *
 * @return int - Sequenz-ID im Bereich 1000-16383 (14 bit)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount());
   int id;
   while (id < 2000) {                                               // Das abschließende Shiften halbiert den Wert und wir brauchen eine mindestens 4-stellige ID.
      id = MathRand();
   }
   return(id >> 1);
}


/**
 * Generiert für den angegebenen Gridlevel eine MagicNumber.
 *
 * @param  int level - Gridlevel
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int level) {
   if (sequenceId < 1000) return(_int(-1, catch("CreateMagicNumber(1)   illegal sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));
   if (level == 0)        return(_int(-1, catch("CreateMagicNumber(2)   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // Für bessere Obfuscation ist die Reihenfolge der Werte [ea,level,sequence] und nicht [ea,sequence,level], was aufeinander folgende Werte wären.
   int ea       = STRATEGY_ID & 0x3FF << 22;                         // 10 bit (Bits größer 10 löschen und auf 32 Bit erweitern)  | Position in MagicNumber: Bits 23-32
       level    = Abs(level);                                        // der Level in MagicNumber ist immer positiv                |
       level    = level & 0xFF << 14;                                //  8 bit (Bits größer 8 löschen und auf 22 Bit erweitern)   | Position in MagicNumber: Bits 15-22
   int sequence = sequenceId  & 0x3FFF;                              // 14 bit (Bits größer 14 löschen                            | Position in MagicNumber: Bits  1-14

   return(ea + level + sequence);
}


/**
 * Generiert eine neue Event-ID.
 *
 * @return int
 */
int CreateEventId() {
   lastEventId++;
   return(lastEventId);
}


/**
 * Zeigt den aktuellen Status der Sequenz an.
 *
 * @return int - Fehlerstatus
 */
int ShowStatus() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode()) {
      if (IsLastError()) {
         status = STATUS_DISABLED;
         if (__LOG) log(StringConcatenate("ShowStatus()   last_error=", last_error, " (STATUS_DISABLED)"));
      }
      return(NO_ERROR);
   }

   string msg, str.error;

   if (__STATUS__CANCELLED) {
      str.error = StringConcatenate("  [", ErrorDescription(ERR_CANCELLED_BY_USER), "]");
   }
   else if (IsLastError()) {
      status    = STATUS_DISABLED;
      str.error = StringConcatenate("  [", ErrorDescription(last_error), "]");
      if (__LOG) log(StringConcatenate("ShowStatus()   last_error=", last_error, " (STATUS_DISABLED)"));
   }
   else if (__STATUS__INVALID_INPUT) {
      str.error = StringConcatenate("  [", ErrorDescription(ERR_INVALID_INPUT), "]");
   }

   switch (status) {
      case STATUS_UNINITIALIZED: msg = " not initialized";                                                                                            break;
      case STATUS_WAITING:       msg = StringConcatenate("  ", Sequence.ID, " waiting"                                                             ); break;
      case STATUS_STARTING:      msg = StringConcatenate("  ", Sequence.ID, " starting at level ",    str.grid.level.LS, "  ", str.grid.maxLevel.LS); break;
      case STATUS_PROGRESSING:   msg = StringConcatenate("  ", Sequence.ID, " progressing at level ", str.grid.level.LS, "  ", str.grid.maxLevel.LS); break;
      case STATUS_STOPPING:      msg = StringConcatenate("  ", Sequence.ID, " stopping at level ",    str.grid.level.LS, "  ", str.grid.maxLevel.LS); break;
      case STATUS_STOPPED:       msg = StringConcatenate("  ", Sequence.ID, " stopped at level ",     str.grid.level.LS, "  ", str.grid.maxLevel.LS); break;
      case STATUS_DISABLED:      msg = StringConcatenate("  ", Sequence.ID, " disabled"                                                            ); break;
      default:
         return(catch("ShowStatus(1)   illegal sequence status = "+ status, ERR_RUNTIME_ERROR));
   }

   msg = StringConcatenate(__NAME__, msg, str.error,                                                                                                         NL,
                                                                                                                                                             NL,
                           "Grid:            ", GridSize, " pip", str.grid.base.LS, str.grid.direction,                                                      NL,
                           "LotSize:         ", str.LotSize,                                                                                                 NL,
                           "Stops:           ", str.grid.stops.L, str.grid.stopsPL.L, str.grid.stops.Sep, str.grid.stops.S, str.grid.stopsPL.S,              NL,
                           "Profit/Loss:    ",  str.grid.totalPL.L, "  ", str.grid.plStatistics.L, " / ", str.grid.totalPL.S, "  ", str.grid.plStatistics.S, NL,
                           str.startConditions,                                                                                                   // enthält NL, wenn gesetzt
                           str.stopConditions);                                                                                                   // enthält NL, wenn gesetzt

   // 2 Zeilen Abstand nach oben für Instrumentanzeige und ggf. vorhandene Legende
   Comment(StringConcatenate(NL, NL, msg));
   if (__WHEREAMI__ == FUNC_INIT)
      WindowRedraw();


   // für Fernbedienung unsichtbaren Status im Chart speichern
   string label = "SnowRoller.status";
   if (ObjectFind(label) != 0) {
      if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))
         return(catch("ShowStatus(2)"));
      ObjectSet(label, OBJPROP_TIMEFRAMES, EMPTY);                   // hidden on all timeframes
   }
   ObjectSetText(label, StringConcatenate(Sequence.ID, "|", status), 1);


   if (IsError(catch("ShowStatus(3)"))) {
      status = STATUS_DISABLED;
      if (__LOG) log(StringConcatenate("ShowStatus()   last_error=", last_error, " (STATUS_DISABLED)"));
      return(last_error);
   }
   return(NO_ERROR);
}


/**
 * ShowStatus(): Aktualisiert alle in ShowStatus() verwendeten String-Repräsentationen.
 */
void SS.All() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   SS.SequenceId();
   SS.Grid.Base();
   SS.Grid.Direction();
   SS.LotSize();
   SS.StartStopConditions();
   SS.Grid.Level();
   SS.Grid.Stops();
   SS.Grid.TotalPL();
   SS.Grid.MaxProfit();
   SS.Grid.MaxDrawdown();
   SS.Grid.ValueAtRisk();
}


/**
 * ShowStatus(): Aktualisiert die Anzeige der Sequenz-ID in der Titelzeile des Strategy Testers.
 */
void SS.SequenceId() {
   if (IsTesting()) {
      if (!SetWindowTextA(GetTesterWindow(), StringConcatenate("Tester - SR.", sequenceId)))
         catch("SS.SequenceId()->user32::SetWindowTextA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.base.
 */
void SS.Grid.Base() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   int sizeOfEvents.L = ArraySize(grid.base.L.event);
   int sizeOfEvents.S = ArraySize(grid.base.S.event);

   if (sizeOfEvents.L > 0) str.grid.base.L = NumberToStr(grid.base.L, PriceFormat);
   if (sizeOfEvents.S > 0) str.grid.base.S = NumberToStr(grid.base.S, PriceFormat);

   if (grid.direction == D_LONG) {
      if (sizeOfEvents.L > 0) str.grid.base.L = StringConcatenate(" @ ", str.grid.base.L);
      str.grid.base.LS = str.grid.base.L;
   }
   else if (grid.direction == D_SHORT) {
      if (sizeOfEvents.S > 0) str.grid.base.S = StringConcatenate(" @ ", str.grid.base.S);
      str.grid.base.LS = str.grid.base.S;
   }
   else if (sizeOfEvents.L > 0 || sizeOfEvents.S > 0) {              // (grid.direction == D_BIDIR)
      str.grid.base.LS = StringConcatenate(" @ ", str.grid.base.L, " / ", str.grid.base.S);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.direction.
 */
void SS.Grid.Direction() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;
   str.grid.direction = StringConcatenate("  (", StringToLower(directionDescr[grid.direction]), ")");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von LotSize.
 */
void SS.LotSize() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   str.LotSize = StringConcatenate(NumberToStr(LotSize, ".+"), " lot = ", DoubleToStr(GridSize * PipValue(LotSize) - grid.commission, 2), "/stop");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von start/stopConditions.
 */
void SS.StartStopConditions() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   str.startConditions = "";
   str.stopConditions  = "";

   if (StartConditions != "") str.startConditions = StringConcatenate("Start:           ", StartConditions, ifString(start.conditions, "", " (inactive)"), NL);
   if (StopConditions  != "") str.stopConditions  = StringConcatenate("Stop:           ", StopConditions,  ifString(stop.conditions,  "", " (inactive)"), NL);
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentationen von grid.level und grid.maxLevel.
 */
void SS.Grid.Level() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   if (grid.direction == D_LONG) {
      str.grid.level.L     = grid.level.L;
      str.grid.level.LS    = str.grid.level.L;
      str.grid.maxLevel.L  = StringConcatenate("(", grid.maxLevel.L, ")");
      str.grid.maxLevel.LS = str.grid.maxLevel.L;
   }
   else if (grid.direction == D_SHORT) {
      str.grid.level.S     = grid.level.S;
      str.grid.level.LS    = str.grid.level.S;
      str.grid.maxLevel.S  = StringConcatenate("(", grid.maxLevel.S, ")");
      str.grid.maxLevel.LS = str.grid.maxLevel.S;
   }
   else /*(grid.direction == D_BIDIR)*/ {
      str.grid.level.L     = grid.level.L;                                                                                                               // "2"
      str.grid.level.S     = grid.level.S;                                                                                                               // "-1"
      str.grid.level.LS    = StringConcatenate(ifString(grid.level.L && grid.level.S, "+", ""), str.grid.level.L, "/", str.grid.level.S);                // "2/0"|"+2/-1"

      str.grid.maxLevel.L  = StringConcatenate("(", grid.maxLevel.L, ")");                                                                               // "(2)"
      str.grid.maxLevel.S  = StringConcatenate("(", grid.maxLevel.S, ")");                                                                               // "(-1)"
      str.grid.maxLevel.LS = StringConcatenate("(", ifString(grid.maxLevel.L && grid.maxLevel.S, "+", ""), grid.maxLevel.L, "/", grid.maxLevel.S, ")");  // "(2/0)"|"(+2/-1)"
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentationen von grid.stops und grid.stopsPL.
 */
void SS.Grid.Stops() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   if (grid.direction == D_LONG) {
      str.grid.stops.L = StringConcatenate(grid.stops.L, " stop", ifString(grid.stops.L==1, "", "s"));
   }
   else if (grid.direction == D_SHORT) {
      str.grid.stops.S = StringConcatenate(grid.stops.S, " stop", ifString(grid.stops.S==1, "", "s"));
   }
   else /*(grid.direction == D_BIDIR)*/ {
      str.grid.stops.L   = StringConcatenate(grid.stops.L, " stop", ifString(grid.stops.L==1, "", "s"));
      str.grid.stops.S   = StringConcatenate(grid.stops.S, " stop", ifString(grid.stops.S==1, "", "s"));
      str.grid.stops.Sep = " / ";
   }

   // Anzeige wird nicht vor der ersten ausgestoppten Position gesetzt
   if (grid.stops.L > 0) str.grid.stopsPL.L = StringConcatenate(" = ", DoubleToStr(grid.stopsPL.L, 2));
   if (grid.stops.S > 0) str.grid.stopsPL.S = StringConcatenate(" = ", DoubleToStr(grid.stopsPL.S, 2));
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.totalPL.
 */
void SS.Grid.TotalPL() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   // Anzeige wird nicht vor der ersten offenen Position gesetzt
   if (grid.maxLevel.L != 0) str.grid.totalPL.L = NumberToStr(grid.totalPL.L, "+.2");
   if (grid.maxLevel.S != 0) str.grid.totalPL.S = NumberToStr(grid.totalPL.S, "+.2");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.maxProfit.
 */
void SS.Grid.MaxProfit() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   str.grid.maxProfit.L = NumberToStr(grid.maxProfit.L, "+.2");
   str.grid.maxProfit.S = NumberToStr(grid.maxProfit.S, "+.2");
   SS.Grid.ProfitLossStatistics();
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.maxDrawdown.
 */
void SS.Grid.MaxDrawdown() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   str.grid.maxDrawdown.L = NumberToStr(grid.maxDrawdown.L, "+.2");
   str.grid.maxDrawdown.S = NumberToStr(grid.maxDrawdown.S, "+.2");
   SS.Grid.ProfitLossStatistics();
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von grid.valueAtRisk.
 */
void SS.Grid.ValueAtRisk() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   str.grid.valueAtRisk.L = NumberToStr(grid.valueAtRisk.L, "+.2");
   str.grid.valueAtRisk.S = NumberToStr(grid.valueAtRisk.S, "+.2");
   SS.Grid.ProfitLossStatistics();
}


/**
 * ShowStatus(): Aktualisiert die kombinierte String-Repräsentation der P/L-Statistik.
 */
void SS.Grid.ProfitLossStatistics() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   // Anzeige wird nicht vor der ersten offenen Position gesetzt
   if (grid.maxLevel.L != 0) str.grid.plStatistics.L = StringConcatenate("(", str.grid.maxProfit.L, "/", str.grid.maxDrawdown.L, "/", str.grid.valueAtRisk.L, ")");
   if (grid.maxLevel.S != 0) str.grid.plStatistics.S = StringConcatenate("(", str.grid.maxProfit.S, "/", str.grid.maxDrawdown.S, "/", str.grid.valueAtRisk.S, ")");
}


/**
 * Berechnet die aktuellen Breakeven-Werte und aktualisiert den Indikator.
 *
 * @param  datetime time - Zeitpunkt innerhalb der Sequenz                    (default: aktueller Zeitpunkt)
 * @param  int      i    - Index innerhalb der Gridarrays zu diesem Zeitpunkt (default: letztes Element    )
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.CalculateBreakeven(datetime time=0, int i=-1) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode()) return(true);
   int sizeOfTickets = ArraySize(orders.ticket);
   if (i >= sizeOfTickets)                      return(_false(catch("Grid.CalculateBreakeven(1)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // vorläufig deaktiviert
   return(true);

   //if (grid.maxLevel.L==0) /*&&*/ if (grid.maxLevel.S==0)                     // nicht vorm ersten ausgeführten Trade
   //   return(true);

   //if (time == 0) time = TimeCurrent();
   //if (i < 0)     i    = sizeOfTickets - 1;

   //double distance1, distance2;

   ///*
   //(1) Breakeven-Punkt auf aktueller Seite:
   //----------------------------------------
   //     totalPL = realizedPL + floatingPL                                     // realizedPL = stopsPL + closedPL

   //=>         0 = realizedPL + floatingPL                                     // Soll: totalPL = 0.00, also floatingPL = -realizedPL

   //=>         0 = stopsPL + closedPL + floatingPL                             //

   //=>  -stopsPL = closedPL + floatingPL                                       // closedPL muß nach PositionReopen wieder als 0 angenommen werden
   //*/
   //distance1 = ProfitToDistance(-grid.stopsPL, grid.level, true, time, i);    // stopsPL reicht zur Berechnung aus
   //if (EQ(distance1, 0))
   //   return(false);


   //if (grid.level == 0) {
   //   grid.breakevenLong  = grid.base + distance1*Pips;                       // openRisk = 0, valueAtRisk = stopsPL (siehe 2)
   //   grid.breakevenShort = grid.base - distance1*Pips;                       // Abstand der Breakeven-Punkte ist gleich, eine Berechnung reicht
   //}
   //else {
   //   /*
   //   (2) Breakeven-Punkt auf gegenüberliegender Seite:
   //   -------------------------------------------------
   //           stopsPL =  valueAtRisk                                          // wenn die Sequenz Level 0 triggert, entspricht valueAtRisk = stopsPL

   //   =>  valueAtRisk =  stopsPL                                              // analog zu (1)
   //   */
   //   if (grid.direction == D_BIDIR) {
   //      distance2 = ProfitToDistance(-grid.valueAtRisk, 0, false, time, i);  // Level 0
   //      if (EQ(distance2, 0))
   //         return(false);
   //   }

   //   if (grid.level > 0) {
   //      grid.breakevenLong  = grid.base + distance1*Pips;
   //      grid.breakevenShort = grid.base - distance2*Pips;
   //   }
   //   else /*grid.level < 0*/ {
   //      grid.breakevenLong  = grid.base + distance2*Pips;
   //      grid.breakevenShort = grid.base - distance1*Pips;
   //   }
   //}

   //if (!Grid.DrawBreakeven(time))
   //   return(false);

   //return(IsNoError(last_error|catch("Grid.CalculateBreakeven()")));
}


/**
 * Aktualisiert den Breakeven-Indikator.
 *
 * @param  datetime time   - Zeitpunkt der zu zeichnenden Werte (default: aktueller Zeitpunkt)
 * @param  int      status - Status zu diesem Zeitpunkt (default: aktueller Status)
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.DrawBreakeven(datetime time=NULL, int timeStatus=NULL) {

   // vorläufig deaktiviert
   return(true);

   //if (IsTesting()) /*&&*/ if (!IsVisualMode())
   //   return(true);
   //if (EQ(grid.breakevenLong, 0))                                                // ohne initialisiertes Breakeven sofortige Rückkehr
   //   return(true);

   //static double   last.grid.breakevenLong, last.grid.breakevenShort;            // Daten der zuletzt gezeichneten Indikatorwerte
   //static datetime last.startTimeLong, last.startTimeShort, last.drawingTime;
   //static int      last.status;


   //if (time == NULL)
   //   time = TimeCurrent();
   //datetime now = time;

   //if (timeStatus == NULL)
   //   timeStatus = status;
   //int nowStatus = timeStatus;

   //int breakeven.Color      = Breakeven.Color;
   //int breakeven.Background = false;

   //if (last.status == STATUS_STOPPED) {
   //   breakeven.Color      = Aqua;
   //   breakeven.Background = true;
   //}


   //if (last.drawingTime != 0) {
   //   // (1) Long
   //   if (grid.direction != D_SHORT) {                                           // "SR.5609.L 1.53024 -> 1.52904 (2012.01.23 10:19:35)"
   //      string labelL = StringConcatenate("SR.", sequenceId, ".beL ", DoubleToStr(last.grid.breakevenLong, Digits), " -> ", DoubleToStr(grid.breakevenLong, Digits), " (", TimeToStr(last.startTimeLong, TIME_FULL), ")");
   //      if (ObjectCreate(labelL, OBJ_TREND, 0, last.drawingTime, last.grid.breakevenLong, now, grid.breakevenLong)) {
   //         ObjectSet(labelL, OBJPROP_RAY,   false               );
   //         ObjectSet(labelL, OBJPROP_WIDTH, breakeven.Width     );
   //         ObjectSet(labelL, OBJPROP_COLOR, breakeven.Color     );
   //         ObjectSet(labelL, OBJPROP_BACK,  breakeven.Background);

   //         if (EQ(last.grid.breakevenLong, grid.breakevenLong)) last.startTimeLong = last.drawingTime;
   //         else                                                 last.startTimeLong = now;
   //      }
   //      else {
   //         GetLastError();                                                      // ERR_OBJECT_ALREADY_EXISTS
   //         ObjectSet(labelL, OBJPROP_TIME2, now);                               // vorhandene Trendlinien werden möglichst verlängert (verhindert Erzeugung unzähliger gleicher Objekte)
   //      }
   //   }

   //   // (2) Short
   //   if (grid.direction != D_LONG) {
   //      string labelS = StringConcatenate("SR.", sequenceId, ".beS ", DoubleToStr(last.grid.breakevenShort, Digits), " -> ", DoubleToStr(grid.breakevenShort, Digits), " (", TimeToStr(last.startTimeShort, TIME_FULL), ")");
   //      if (ObjectCreate(labelS, OBJ_TREND, 0, last.drawingTime, last.grid.breakevenShort, now, grid.breakevenShort)) {
   //         ObjectSet(labelS, OBJPROP_RAY,   false               );
   //         ObjectSet(labelS, OBJPROP_WIDTH, breakeven.Width     );
   //         ObjectSet(labelS, OBJPROP_COLOR, breakeven.Color     );
   //         ObjectSet(labelS, OBJPROP_BACK,  breakeven.Background);

   //         if (EQ(last.grid.breakevenLong, grid.breakevenLong)) last.startTimeLong = last.drawingTime;
   //         else                                                 last.startTimeLong = now;
   //      }
   //      else {
   //         GetLastError();                                                      // ERR_OBJECT_ALREADY_EXISTS
   //         ObjectSet(labelS, OBJPROP_TIME2, now);                               // vorhandene Trendlinien werden möglichst verlängert (verhindert Erzeugung unzähliger gleicher Objekte)
   //      }
   //   }
   //}
   //else {
   //   last.startTimeLong  = now;
   //   last.startTimeShort = now;
   //}

   //last.grid.breakevenLong  = grid.breakevenLong;
   //last.grid.breakevenShort = grid.breakevenShort;
   //last.drawingTime         = now;
   //last.status              = nowStatus;

   //return(IsNoError(last_error|catch("Grid.DrawBreakeven()")));
}


/**
 * Färbt den Breakeven-Indikator neu ein.
 */
void RecolorBreakeven() {

   // vorläufig deaktiviert
   return;

   //if (IsTesting()) /*&&*/ if (!IsVisualMode())
   //   return;

   //if (ObjectsTotal(OBJ_TREND) > 0) {
   //   string label, labelBe=StringConcatenate("SR.", sequenceId, ".be");

   //   for (int i=ObjectsTotal()-1; i>=0; i--) {
   //      label = ObjectName(i);
   //      if (ObjectType(label)==OBJ_TREND) /*&&*/ if (StringStartsWith(label, labelBe)) {
   //         if (breakeven.Width == 0) ObjectSet(label, OBJPROP_TIMEFRAMES, EMPTY          );    // hidden on all timeframes
   //         else                      ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);    // visible on all timeframes
   //      }
   //   }
   //}
   //catch("RecolorBreakeven()");
}


/**
 * Berechnet den notwendigen Abstand von der Gridbasis, um im angegebenen Level den angegebenen Gewinn zu erzielen (bzw. Verlust auszugleichen).
 * Aufruf nur aus Grid.CalculateBreakeven()
 *
 * @param  double   profit             - zu erzielender Gewinn
 * @param  int      level              - Gridlevel
 * @param  bool     checkOpenPositions - ob die Entry-Preise offener Positionen berücksichtigen werden sollen (bezieht Slippage ins Ergebnis ein)
 * @param  datetime time               - wenn checkOpenPositions=TRUE: Zeitpunkt innerhalb der Sequenz
 * @param  int      i                  - wenn checkOpenPositions=TRUE: Index innerhalb der Gridarrays
 *
 * @return double - Abstand in Pips oder 0, falls ein Fehler auftrat
 *
 *
 * NOTE: Eine direkte Berechnung anhand der zugrunde liegenden quadratischen Gleichung ist praktisch nicht ausreichend,
 *       denn sie unterschlägt auftretende Slippage. Für ein korrektes Ergebnis wird statt dessen der notwendige Abstand
 *       vom tatsächlichen Durchschnittspreis der Positionen ermittelt und in einen Abstand von der Gridbasis umgerechnet.
 */
double ProfitToDistance(double profit, int level, bool checkOpenPositions, datetime time, int i) {

   // vorläufig deaktiviert, da Verwendung nur in Grid.CalculateBreakeven()
   return(0);

   //profit = NormalizeDouble(MathAbs(profit), 2);

   //double gridBaseDistance, avgPrice, openRisk, bePrice, beDistance, nextStop, nextEntry;
   //bool   entryStop, exitStop;


   //// (1) Level == 0: Um einen Verlust auszugleichen, muß mindestens der nächste Entry-Stop (Level +1/-1) getriggert werden.
   //if (level == 0) {
   //   if (EQ(profit, 0))
   //      return(0);
   //   //debug("ProfitToDistance.0(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  entryStop=1 ->");
   //   gridBaseDistance = ProfitToDistance(profit, 1, false, time, i);                                    // Sollte die Grid-Direction hier falsch sein, ändert das nichts
   //                                                                                                      // am Abstand des Ergebnisses von der Gridbasis.
   //   //debug("ProfitToDistance.0(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  -> distance="+ NumberToStr(gridBaseDistance, ".1") +" pip");
   //}


   //// (2) Level != 0: Je nach Durchschnitts- und Breakeven-Preis das Triggern weiterer Stops berücksichtigen
   //else {
   //   avgPrice   = CalculateAverageOpenPrice(level, checkOpenPositions, time, i, openRisk);
   //      if (EQ(avgPrice, 0)) return(0);
   //   beDistance = profit/PipValue(Abs(level) * LotSize);                                                // für profit benötigter Abstand von avgPrice in Pip
   //   bePrice    = NormalizeDouble(avgPrice + Sign(level)*beDistance*Pip, Digits);                       // Breakeven-Preis

   //   // Testen, ob der Breakeven-Preis innerhalb des Levels liegt.
   //   nextEntry  = NormalizeDouble(grid.base + (level+Sign(level))*GridSize*Pips, Digits);
   //   nextStop   = NormalizeDouble(nextEntry       -2*Sign(level) *GridSize*Pips, Digits);

   //   if    (level > 0)  { entryStop = GT(bePrice, nextEntry); exitStop = LT(bePrice, nextStop); }
   //   else /*level < 0*/ { entryStop = LT(bePrice, nextEntry); exitStop = GT(bePrice, nextStop); }

   //   if (entryStop) {                                                                                   // Level vergrößert sich, Verlust bleibt konstant
   //      //debug("ProfitToDistance.1(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  avgPrice="+ NumberToStr(avgPrice, PriceFormat) +"  beDistance="+ NumberToStr(beDistance, ".1") +" pip" +"  entryStop="+ entryStop +" ->");
   //      level           += Sign(level);
   //      gridBaseDistance = ProfitToDistance(profit, level, checkOpenPositions, time, i);
   //      //debug("ProfitToDistance.1(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  -> distance="+ NumberToStr(gridBaseDistance, ".1") +" pip");
   //   }
   //   else if (exitStop) {                                                                               // Level verringert und Verlust vergrößert sich
   //      if (Abs(level) == 1)
   //         return(_NULL(catch("ProfitToDistance()   illegal calculation of exit stop in level 1", ERR_RUNTIME_ERROR)));

   //      //debug("ProfitToDistance.2(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  avgPrice="+ NumberToStr(avgPrice, PriceFormat) +"  beDistance="+ NumberToStr(beDistance, ".1") +" pip" +"  exitStop="+ exitStop +" ->");
   //      level           -= Sign(level);
   //      profit          += openRisk;
   //      gridBaseDistance = ProfitToDistance(profit, level, checkOpenPositions, time, i);
   //      //debug("ProfitToDistance.2(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  -> distance="+ NumberToStr(gridBaseDistance, ".1") +" pip");
   //   }
   //   else {
   //      gridBaseDistance = MathAbs(bePrice - grid.base)/Pip;
   //      //debug("ProfitToDistance.3(profit="+ DoubleToStr(profit, 2) +", level="+ level +")  avgPrice="+ NumberToStr(avgPrice, PriceFormat) +"  distance="+ NumberToStr(gridBaseDistance, ".1") +" pip");
   //   }
   //}

   //return(NormalizeDouble(gridBaseDistance, 1));
}


/**
 * Berechnet den theoretischen Profit im angegebenen Abstand von der Gridbasis.
 *
 * @param  double distance - Abstand in Pips von der Gridbasis
 *
 * @return double - Profit oder 0, falls ein Fehler auftrat
 *
 *
 * NOTE: Benötigt *nicht* die Gridbasis, die GridSize ist ausreichend.
 */
double DistanceToProfit(double distance) {
   if (LE(distance, GridSize)) {
      if (LT(distance, 0))
         return(_ZERO(catch("DistanceToProfit()   invalid parameter distance = "+ NumberToStr(distance, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
      return(0);
   }
   /*
   d         = Distanz in Pip
   gs        = GridSize
   n         = Level
   pipV(n)   = PipValue von Level n
   profit(d) = profit(exp) + profit(lin)                             // Summe aus exponentiellem (ganzer Level) und linearem Anteil (partieller nächster Level)

   Für Sequenzstart an der Gridbasis gilt:
   ---------------------------------------
   Ganzer Level:      expProfit(n.0) = n * (n+1)/2 * gs * pipV(1)    // am Ende des Levels
   Partieller Level:  linProfit(n.x) =         0.x * gs * pipV(n+1)
   PipValue:          pipV(n)        = n * pipV(LotSize)

   profit(d) = expProfit((int) d) + linProfit(d % gs)
   */
   int    gs   = GridSize;
   double d    = distance - gs;                                      // GridSize abziehen, da Sequenzstart erst bei Gridbase + GridSize erfolgt
   int    n    = (d+0.000000001) / gs;
   double pipV = PipValue(LotSize);

   double expProfit = n * (n+1)/2 * gs * pipV;
   double linProfit = MathModFix(d, gs) * (n+1) * pipV;
   double profit    = expProfit + linProfit;

   //debug("DistanceToProfit()   gs="+ gs +"  d="+ d +"  n="+ n +"  exp="+ DoubleToStr(expProfit, 2) +"  lin="+ DoubleToStr(linProfit, 2) +"  profit="+ NumberToStr(profit, ".+"));
   return(profit);
}


/**
 * Speichert temporäre Werte des Sequenzstatus im Chart, sodaß der volle Status nach einem Recompile oder Terminal-Restart daraus wiederhergestellt werden kann.
 * Die temporären Werte umfassen die Parameter, die zur Ermittlung des vollen Dateinamens der Statusdatei erforderlich sind und jene User-Eingaben, die nicht
 * in der Statusdatei gespeichert sind (aktuelle Display-Modes, Farben und Strichstärken) sowie die Flags __STATUS__CANCELLED und __STATUS__INVALID_INPUT.
 *
 * @return int - Fehlerstatus
 */
int StoreStickyStatus() {
   string label = StringConcatenate(__NAME__, ".sticky.Sequence.ID");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, ifString(sequenceId==0, "0", Sequence.ID), 1);        // String: "0" (STATUS_UNINITIALIZED) oder Sequence.ID (enthält ggf. "T")

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

   label = StringConcatenate(__NAME__, ".sticky.Breakeven.Color");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", Breakeven.Color), 1);

   label = StringConcatenate(__NAME__, ".sticky.breakeven.Width");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", breakeven.Width), 1);

   label = StringConcatenate(__NAME__, ".sticky.__STATUS__CANCELLED");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", __STATUS__CANCELLED), 1);

   label = StringConcatenate(__NAME__, ".sticky.__STATUS__INVALID_INPUT");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StringConcatenate("", __STATUS__INVALID_INPUT), 1);

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
         test     = true;
         strValue = StringRight(strValue, -1);
      }
      if (!StringIsDigit(strValue))
         return(_false(catch("RestoreStickyStatus(1)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      int iValue = StrToInteger(strValue);
      if (iValue == 0) {
         status  = STATUS_UNINITIALIZED;
         idFound = false;
      }
      else if (iValue < 1000 || iValue > 16383) {
         return(_false(catch("RestoreStickyStatus(2)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
      }
      else {
         sequenceId  = InstanceId(iValue); SS.SequenceId();
         Sequence.ID = ifString(IsTest(), "T", "") + sequenceId;
         status      = STATUS_WAITING;
         idFound     = true;
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

      label = StringConcatenate(__NAME__, ".sticky.Breakeven.Color");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsInteger(strValue))
            return(_false(catch("RestoreStickyStatus(7)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         iValue = StrToInteger(strValue);
         if (iValue < CLR_NONE || iValue > C'255,255,255')
            return(_false(catch("RestoreStickyStatus(8)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\" (0x"+ IntToHexStr(iValue) +")", ERR_INVALID_CONFIG_PARAMVALUE)));
         Breakeven.Color = iValue;
      }

      label = StringConcatenate(__NAME__, ".sticky.breakeven.Width");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsInteger(strValue))
            return(_false(catch("RestoreStickyStatus(9)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         iValue = StrToInteger(strValue);
         if (iValue < 0 || iValue > 5)
            return(_false(catch("RestoreStickyStatus(10)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         breakeven.Width = iValue;
      }

      label = StringConcatenate(__NAME__, ".sticky.__STATUS__CANCELLED");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(11)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         __STATUS__CANCELLED = StrToInteger(strValue) != 0;
      }

      label = StringConcatenate(__NAME__, ".sticky.__STATUS__INVALID_INPUT");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(12)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         __STATUS__INVALID_INPUT = StrToInteger(strValue) != 0;
      }
   }

   return(idFound && IsNoError(last_error|catch("RestoreStickyStatus(13)")));
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
 * @param bool interactive - ob fehlerhafte Parameter interaktiv korrigiert werden können
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
      test     = true;
      strValue = StringRight(strValue, -1);
   }
   if (!StringIsDigit(strValue))
      return(_false(ValidateConfig.HandleError("ValidateConfiguration.ID(1)", "Illegal input parameter Sequence.ID = \""+ Sequence.ID +"\"", interactive)));

   int iValue = StrToInteger(strValue);
   if (iValue < 1000 || iValue > 16383)
      return(_false(ValidateConfig.HandleError("ValidateConfiguration.ID(2)", "Illegal input parameter Sequence.ID = \""+ Sequence.ID +"\"", interactive)));

   sequenceId  = InstanceId(iValue); SS.SequenceId();
   Sequence.ID = ifString(IsTest(), "T", "") + sequenceId;

   return(true);
}


/**
 * Validiert die aktuelle Konfiguration.
 *
 * @param bool interactive - ob fehlerhafte Parameter interaktiv korrigiert werden können
 *
 * @return bool - ob die Konfiguration gültig ist
 */
bool ValidateConfiguration(bool interactive) {
   if (IsLastError() || status==STATUS_DISABLED)
      return(false);

   bool parameterChange = (UninitializeReason() == REASON_PARAMETERS);
   if (parameterChange)
      interactive = true;


   // (1) Sequence.ID
   if (parameterChange) {
      if (status == STATUS_UNINITIALIZED) {
         if (Sequence.ID != last.Sequence.ID) { return(_false(ValidateConfig.HandleError("ValidateConfiguration(1)", "Loading of another sequence not yet implemented!", interactive)));
            if (ValidateConfiguration.ID(interactive)) {
               // TODO: neue Sequenz laden
            }
         }
      }
      else {
         if (Sequence.ID == "")                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(2)", "Sequence.ID missing!", interactive)));
         if (Sequence.ID != last.Sequence.ID) { return(_false(ValidateConfig.HandleError("ValidateConfiguration(3)", "Loading of another sequence not yet implemented!", interactive)));
            if (ValidateConfiguration.ID(interactive)) {
               // TODO: neue Sequenz laden
            }
         }
      }
   }
   else if (StringLen(Sequence.ID) == 0) {      // wir müssen im STATUS_UNINITIALIZED sein (sequenceId = 0)
      if (sequenceId != 0)                      return(_false(catch("ValidateConfiguration(4)   illegal Sequence.ID = \""+ Sequence.ID +"\" (sequenceId="+ sequenceId +")", ERR_RUNTIME_ERROR)));
   }
   else {} // wenn gesetzt, ist sie schon validiert und die Sequenz geladen (sonst landen wir hier nicht)


   // (2) GridDirection
   if (parameterChange) {
      if (GridDirection != last.GridDirection)
         if (status != STATUS_UNINITIALIZED)    return(_false(ValidateConfig.HandleError("ValidateConfiguration(5)", "Cannot change GridDirection of "+ StatusDescription(status) +" sequence", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Position eröffnet wurde
   }
   string strValue = StringToLower(StringTrim(GridDirection) +"b");  // b = default
   switch (StringGetChar(strValue, 0)) {
      case 'b': grid.direction = D_BIDIR; break;
      case 'l': grid.direction = D_LONG;  break;
      case 's': grid.direction = D_SHORT; break;
      default:                                  return(_false(ValidateConfig.HandleError("ValidateConfiguration(6)", "Invalid GridDirection = \""+ GridDirection +"\"", interactive)));
   }
   GridDirection = directionDescr[grid.direction]; SS.Grid.Direction();


   // (3) GridSize
   if (parameterChange) {
      if (GridSize != last.GridSize)
         if (status != STATUS_UNINITIALIZED)    return(_false(ValidateConfig.HandleError("ValidateConfiguration(7)", "Cannot change GridSize of "+ StatusDescription(status) +" sequence", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Position eröffnet wurde
   }
   if (GridSize < 1)                            return(_false(ValidateConfig.HandleError("ValidateConfiguration(8)", "Invalid GridSize = "+ GridSize, interactive)));


   // (4) LotSize
   if (parameterChange) {
      if (NE(LotSize, last.LotSize))
         if (status != STATUS_UNINITIALIZED)    return(_false(ValidateConfig.HandleError("ValidateConfiguration(9)", "Cannot change LotSize of "+ StatusDescription(status) +" sequence", interactive)));
      // TODO: Modify ist erlaubt, solange nicht die erste Position eröffnet wurde
   }
   if (LE(LotSize, 0))                          return(_false(ValidateConfig.HandleError("ValidateConfiguration(10)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+"), interactive)));
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT );
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT );
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int error = GetLastError();
   if (IsError(error))                          return(_false(catch("ValidateConfiguration(11)   symbol=\""+ Symbol() +"\"", error)));
   if (LT(LotSize, minLot))                     return(_false(ValidateConfig.HandleError("ValidateConfiguration(12)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", interactive)));
   if (GT(LotSize, maxLot))                     return(_false(ValidateConfig.HandleError("ValidateConfiguration(13)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", interactive)));
   if (NE(MathModFix(LotSize, lotStep), 0))     return(_false(ValidateConfig.HandleError("ValidateConfiguration(14)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", interactive)));
   SS.LotSize();


   // (5) StartConditions, AND-verknüpft: "@price(1.33) && @time(12:00)"
   // ------------------------------------------------------------------
   //  @bid(double) | @ask(double) | @price(double)
   //  @time(12:00)                                // Validierung unzureichend
   if (!parameterChange || StartConditions!=last.StartConditions) {
      // Bei Parameteränderung Werte nur übernehmen, wenn sie sich tatsächlich geändert haben, sodaß StartConditions nur bei Änderung (re-)aktiviert werden.
      start.conditions           = false;
      start.conditions.triggered = false;
      start.price.condition      = false;
      start.time.condition       = false;

      // (5.1) StartConditions in einzelne Ausdrücke zerlegen
      string exprs[], expr, elems[], key, value;
      double dValue;
      int    time, sizeOfElems, sizeOfExprs=Explode(StartConditions, "&&", exprs, NULL);

      // (5.2) jeden Ausdruck parsen und validieren
      for (int i=0; i < sizeOfExprs; i++) {
         start.conditions = false;                 // im Fehlerfall ist start.conditions deaktiviert
         expr = StringToLower(StringTrim(exprs[i]));
         if (StringLen(expr) == 0) {
            if (sizeOfExprs > 1)                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(15)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')        return(_false(ValidateConfig.HandleError("ValidateConfiguration(16)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         if (Explode(expr, "(", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(17)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         if (!StringEndsWith(elems[1], ")"))       return(_false(ValidateConfig.HandleError("ValidateConfiguration(18)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         key   = StringTrim(elems[0]);
         value = StringTrim(StringLeft(elems[1], -1));
         if (StringLen(value) == 0)                return(_false(ValidateConfig.HandleError("ValidateConfiguration(19)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         //debug("()   key="+ StringRightPad("\""+ key +"\"", 9, " ") +"   value=\""+ value +"\"");

         if (key=="@bid" || key=="@ask" || key=="@price") {
            if (start.price.condition)             return(_false(ValidateConfig.HandleError("ValidateConfiguration(20)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple price conditions)", interactive)));
            if (!StringIsNumeric(value))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(21)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(22)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            start.price.condition = true;
            start.price.value     = NormalizeDouble(dValue, PipDigits);
            if      (key == "@bid"  ) start.price.type = SCP_BID;
            else if (key == "@ask"  ) start.price.type = SCP_ASK;
            else if (key == "@price") start.price.type = SCP_MEDIAN;
            exprs[i] = key +"("+ DoubleToStr(start.price.value, PipDigits) +")";
         }
         else if (key == "@time") {
            if (start.time.condition)              return(_false(ValidateConfig.HandleError("ValidateConfiguration(23)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple time conditions)", interactive)));
            time = StrToTime(value);
            if (IsError(GetLastError()))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(24)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            // TODO: Validierung von @time unzureichend
            start.time.condition = true;
            start.time.value     = time;
            exprs[i] = key +"("+ TimeToStr(time) +")";
         }
         else                                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(25)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         start.conditions = true;
      }
      if (start.conditions) StartConditions = JoinStrings(exprs, " && ");
      else                  StartConditions = "";
   }


   // (6) StopConditions, OR-verknüpft: "@price(1.33) || @time(12:00) || @profit(1234.00) || @profit(20%)"
   // ----------------------------------------------------------------------------------------------------
   //  @price(1.33)
   //  @time(12:00)                                // Validierung unzureichend
   //  @profit(1234.00)
   //  @profit(20%)
   if (!parameterChange || StopConditions!=last.StopConditions) {
      // Bei Parameteränderung Werte nur übernehmen, wenn sie sich tatsächlich geändert haben, sodaß StopConditions nur bei Änderung (re-)aktiviert werden.
      stop.conditions              = false;
      stop.conditions.triggered    = false;
      stop.price.condition         = false;
      stop.time.condition          = false;
      stop.profitAbs.condition     = false;
      stop.profitPercent.condition = false;

      // (6.1) StopConditions in einzelne Ausdrücke zerlegen
      sizeOfExprs = Explode(StopConditions, "||", exprs, NULL);

      // (6.2) jeden Ausdruck parsen und validieren
      for (i=0; i < sizeOfExprs; i++) {
         stop.conditions = false;                  // im Fehlerfall ist stop.conditions deaktiviert
         expr = StringToLower(StringTrim(exprs[i]));
         if (StringLen(expr) == 0) {
            if (sizeOfExprs > 1)                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(26)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')        return(_false(ValidateConfig.HandleError("ValidateConfiguration(27)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         if (Explode(expr, "(", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(28)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         if (!StringEndsWith(elems[1], ")"))       return(_false(ValidateConfig.HandleError("ValidateConfiguration(29)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         key   = StringTrim(elems[0]);
         value = StringTrim(StringLeft(elems[1], -1));
         if (StringLen(value) == 0)                return(_false(ValidateConfig.HandleError("ValidateConfiguration(30)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         //debug("()   key="+ StringRightPad("\""+ key +"\"", 9, " ") +"   value=\""+ value +"\"");

         if (key=="@bid" || key=="@ask" || key=="@price") {
            if (stop.price.condition)              return(_false(ValidateConfig.HandleError("ValidateConfiguration(31)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple price conditions)", interactive)));
            if (!StringIsNumeric(value))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(32)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(33)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            stop.price.condition = true;
            stop.price.value     = NormalizeDouble(dValue, PipDigits);
            if      (key == "@bid"  ) stop.price.type = SCP_BID;
            else if (key == "@ask"  ) stop.price.type = SCP_ASK;
            else if (key == "@price") stop.price.type = SCP_MEDIAN;
            exprs[i] = key +"("+ DoubleToStr(stop.price.value, PipDigits) +")";
         }
         else if (key == "@time") {
            if (stop.time.condition)               return(_false(ValidateConfig.HandleError("ValidateConfiguration(34)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple time conditions)", interactive)));
            time = StrToTime(value);
            if (IsError(GetLastError()))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(35)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            // TODO: Validierung von @time unzureichend
            stop.time.condition = true;
            stop.time.value     = time;
            exprs[i] = key +"("+ TimeToStr(time) +")";
         }
         else if (key == "@profit") {
            if (stop.profitAbs.condition || stop.profitPercent.condition)
                                                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(36)", "Invalid StopConditions = \""+ StopConditions +"\" (multiple profit conditions)", interactive)));
            sizeOfElems = Explode(value, "%", elems, NULL);
            if (sizeOfElems > 2)                   return(_false(ValidateConfig.HandleError("ValidateConfiguration(37)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            value = StringTrim(elems[0]);
            if (StringLen(value) == 0)             return(_false(ValidateConfig.HandleError("ValidateConfiguration(38)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            if (!StringIsNumeric(value))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(39)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (sizeOfElems == 1) {
               stop.profitAbs.condition = true;
               stop.profitAbs.value     = NormalizeDouble(dValue, 2);
               exprs[i] = key +"("+ NumberToStr(dValue, ".2") +")";
            }
            else {
               if (dValue <= 0)                    return(_false(ValidateConfig.HandleError("ValidateConfiguration(40)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
               stop.profitPercent.condition = true;
               stop.profitPercent.value     = dValue;
               exprs[i] = key +"("+ NumberToStr(dValue, ".+") +"%)";
            }
         }
         else                                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(41)", "Invalid StopConditions = \""+ StopConditions +"\"", interactive)));
         stop.conditions = true;
      }
      if (stop.conditions) StopConditions = JoinStrings(exprs, " || ");
      else                 StopConditions = "";
   }


   // (7) Breakeven.Color
   if (Breakeven.Color == 0xFF000000)                                   // kann vom Terminal falsch gesetzt worden sein
      Breakeven.Color = CLR_NONE;
   if (Breakeven.Color < CLR_NONE || Breakeven.Color > C'255,255,255')  // kann nur nicht-interaktiv falsch reinkommen
                                                return(_false(ValidateConfig.HandleError("ValidateConfiguration(42)", "Invalid Breakeven.Color = 0x"+ IntToHexStr(Breakeven.Color), interactive)));

   // (8) __STATUS__INVALID_INPUT zurücksetzen
   if (interactive)
      __STATUS__INVALID_INPUT = false;

   return(IsNoError(last_error|catch("ValidateConfiguration(43)")));
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
   int button = ForceMessageBox(__NAME__ +" - ValidateConfiguration()", message, MB_ICONERROR|MB_RETRYCANCEL);

   __STATUS__INVALID_INPUT = true;

   if (button == IDRETRY)
      __STATUS__RELAUNCH_INPUT = true;

   return(NO_ERROR);
}


/**
 * Speichert die aktuelle Konfiguration zwischen, um sie bei Fehleingaben nach Parameteränderungen restaurieren zu können.
 *
 * @return void
 */
void StoreConfiguration(bool save=true) {
   static string   _Sequence.ID;
   static string   _Sequence.StatusLocation;
   static string   _GridDirection;
   static int      _GridSize;
   static double   _LotSize;
   static string   _StartConditions;
   static string   _StopConditions;
   static color    _Breakeven.Color;

   static int      _grid.direction;

   static bool     _start.conditions;
   static bool     _start.conditions.triggered;
   static bool     _start.price.condition;
   static int      _start.price.type;
   static double   _start.price.value;
   static bool     _start.time.condition;
   static datetime _start.time.value;

   static bool     _stop.conditions;
   static bool     _stop.conditions.triggered;
   static bool     _stop.price.condition;
   static int      _stop.price.type;
   static double   _stop.price.value;
   static bool     _stop.time.condition;
   static datetime _stop.time.value;
   static bool     _stop.profitAbs.condition;
   static double   _stop.profitAbs.value;
   static bool     _stop.profitPercent.condition;
   static double   _stop.profitPercent.value;

   if (save) {
      _Sequence.ID                  = StringConcatenate(Sequence.ID,             "");  // Pointer-Bug bei String-Inputvariablen (siehe MQL.doc)
      _Sequence.StatusLocation      = StringConcatenate(Sequence.StatusLocation, "");
      _GridDirection                = StringConcatenate(GridDirection,           "");
      _GridSize                     = GridSize;
      _LotSize                      = LotSize;
      _StartConditions              = StringConcatenate(StartConditions,         "");
      _StopConditions               = StringConcatenate(StopConditions,          "");
      _Breakeven.Color              = Breakeven.Color;

      _grid.direction               = grid.direction;

      _start.conditions             = start.conditions;
      _start.conditions.triggered   = start.conditions.triggered;
      _start.price.condition        = start.price.condition;
      _start.price.type             = start.price.type;
      _start.price.value            = start.price.value;
      _start.time.condition         = start.time.condition;
      _start.time.value             = start.time.value;

      _stop.conditions              = stop.conditions;
      _stop.conditions.triggered    = stop.conditions.triggered;
      _stop.price.condition         = stop.price.condition;
      _stop.price.type              = stop.price.type;
      _stop.price.value             = stop.price.value;
      _stop.time.condition          = stop.time.condition;
      _stop.time.value              = stop.time.value;
      _stop.profitAbs.condition     = stop.profitAbs.condition;
      _stop.profitAbs.value         = stop.profitAbs.value;
      _stop.profitPercent.condition = stop.profitPercent.condition;
      _stop.profitPercent.value     = stop.profitPercent.value;
   }
   else {
      Sequence.ID                   = _Sequence.ID;
      Sequence.StatusLocation       = _Sequence.StatusLocation;
      GridDirection                 = _GridDirection;
      GridSize                      = _GridSize;
      LotSize                       = _LotSize;
      StartConditions               = _StartConditions;
      StopConditions                = _StopConditions;
      Breakeven.Color               = _Breakeven.Color;

      grid.direction                = _grid.direction;

      start.conditions              = _start.conditions;
      start.conditions.triggered    = _start.conditions.triggered;
      start.price.condition         = _start.price.condition;
      start.price.type              = _start.price.type;
      start.price.value             = _start.price.value;
      start.time.condition          = _start.time.condition;
      start.time.value              = _start.time.value;

      stop.conditions               = _stop.conditions;
      stop.conditions.triggered     = _stop.conditions.triggered;
      stop.price.condition          = _stop.price.condition;
      stop.price.type               = _stop.price.type;
      stop.price.value              = _stop.price.value;
      stop.time.condition           = _stop.time.condition;
      stop.time.value               = _stop.time.value;
      stop.profitAbs.condition      = _stop.profitAbs.condition;
      stop.profitAbs.value          = _stop.profitAbs.value;
      stop.profitPercent.condition  = _stop.profitPercent.condition;
      stop.profitPercent.value      = _stop.profitPercent.value;
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
 * Initialisiert die Dateinamensvariablen der Statusdatei mit den Ausgangswerten einer neuen Sequenz.
 *
 * @return bool - Erfolgsstatus
 */
bool InitStatusLocation() {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (sequenceId == 0)                      return(_false(catch("InitStatusLocation(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   if      (IsTesting()) status.directory = "presets\\";
   else if (IsTest())    status.directory = "presets\\tester\\";
   else                  status.directory = "presets\\"+ ShortAccountCompany() +"\\";

   status.fileName = StringConcatenate(StringToLower(StdSymbol()), ".SR.", sequenceId, ".set");

   Sequence.StatusLocation = "";
   return(true);
}


/**
 * Aktualisiert die Dateinamensvariablen der Statusdatei.  Nur die Variablen werden modifiziert, nicht die Datei.
 * SaveStatus() erkennt die Änderung selbst und verschiebt die Datei automatisch.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatusLocation() {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (sequenceId == 0)                      return(_false(catch("UpdateStatusLocation(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   // TODO: Prüfen, ob status.fileName existiert und ggf. aktualisieren

   string startDate = "";

   if      (IsTesting()) status.directory = "presets\\";
   else if (IsTest())    status.directory = "presets\\tester\\";
   else {
      status.directory = "presets\\"+ ShortAccountCompany() +"\\";

      if (grid.maxLevel.L-grid.maxLevel.S > 0) {
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
   if (__STATUS__CANCELLED || IsLastError()) return( false);


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
         if (IsLastError()) return( false);
                            return(_false(catch("ResolveStatusLocation(1)   invalid Sequence.StatusLocation = \""+ location +"\" (status file not found)", ERR_FILE_NOT_FOUND)));
      }

      // (2.2) ohne StatusLocation: zuerst Basisverzeichnis durchsuchen...
      directory = StringConcatenate(filesDirectory, statusDirectory);
      if (ResolveStatusLocation.FindFile(directory, file))
         break;
      if (IsLastError()) return(false);


      // (2.3) ohne StatusLocation: ...dann Unterverzeichnisse des jeweiligen Symbols durchsuchen
      directory = StringConcatenate(directory, StdSymbol(), "\\");
      int size = FindFileNames(directory +"*", subdirs, FF_DIRSONLY);
      if (size == -1)
         return(_false(SetLastError(stdlib_PeekLastError())));
      //debug("ResolveStatusLocation()   subdirs="+ StringsToStr(subdirs, NULL));

      for (int i=0; i < size; i++) {
         subdir = StringConcatenate(directory, subdirs[i], "\\");
         if (ResolveStatusLocation.FindFile(subdir, file)) {
            directory = subdir;
            location  = subdirs[i];
            break;
         }
         if (IsLastError()) return(false);
      }
      if (StringLen(file) > 0)
         break;
      return(_false(catch("ResolveStatusLocation(2)   status file not found", ERR_FILE_NOT_FOUND)));
   }
   //debug("ResolveStatusLocation()   directory=\""+ directory +"\"  location=\""+ location +"\"  file=\""+ file +"\"");

   status.directory        = StringRight(directory, -StringLen(filesDirectory));
   status.fileName         = file;
   Sequence.StatusLocation = location;
   //debug("ResolveStatusLocation()   status.directory=\""+ status.directory +"\"  Sequence.StatusLocation=\""+ Sequence.StatusLocation +"\"  status.fileName=\""+ status.fileName +"\"");
   return(true);
}


/**
 * Durchsucht das angegebene Verzeichnis nach einer passenden Statusdatei und schreibt das Ergebnis in die angegebene Variable.
 *
 * @param  string directory - vollständiger Name des zu durchsuchenden Verzeichnisses
 * @param  string lpFile    - Zeiger auf Variable zur Aufnahme des gefundenen Dateinamens
 *
 * @return bool - Erfolgsstatus
 */
bool ResolveStatusLocation.FindFile(string directory, string &lpFile) {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (sequenceId == 0)                      return(_false(catch("ResolveStatusLocation.FindFile(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));

   if (!StringEndsWith(directory, "\\"))
      directory = StringConcatenate(directory, "\\");

   string sequenceName = StringConcatenate("SR.", sequenceId, ".");
   string pattern      = StringConcatenate(directory, "*", sequenceName, "*set");
   string files[];

   int size = FindFileNames(pattern, files, FF_FILESONLY);                       // Dateien suchen, die den Sequenznamen enthalten und mit "set" enden
   if (size == -1)
      return(_false(SetLastError(stdlib_PeekLastError())));

   for (int i=0; i < size; i++) {
      if (!StringIStartsWith(files[i], sequenceName))
         if (!StringIContains(files[i], StringConcatenate(".", sequenceName)))
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
 * Gibt den MQL-Namen der Statusdatei der Sequenz zurück (unterhalb ".\files\").
 *
 * @return string
 */
string GetMqlStatusFileName() {
   return(StringConcatenate(status.directory, status.fileName));
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
 * Gibt den MQL-Namen des Statusverzeichnisses der Sequenz zurück (unterhalb ".\files\").
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
 * Speichert den aktuellen Status der Instanz, um später die nahtlose Re-Initialisierung im selben oder einem anderen Terminal
 * zu ermöglichen.
 *
 * @return bool - Erfolgsstatus
 */
bool SaveStatus() {
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (sequenceId == 0)                      return(_false(catch("SaveStatus(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));
   if (IsTest()) /*&&*/ if (!IsTesting())    return(true);

   // Im Tester wird der Status zur Performancesteigerung nur beim ersten und letzten Aufruf gespeichert, es sei denn,
   // das Logging ist aktiviert oder die Sequenz wurde gestoppt.
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
   bool     test;                      // nein: wird aus Statusdatei ermittelt

   datetime instanceStartTime;         // ja
   double   instanceStartPrice;        // ja
   double   sequenceStartEquity;       // ja

   int      sequenceStart.event [];    // ja
   datetime sequenceStart.time  [];    // ja
   double   sequenceStart.price [];    // ja
   double   sequenceStart.profit[];    // ja

   int      sequenceStop.event [];     // ja
   datetime sequenceStop.time  [];     // ja
   double   sequenceStop.price [];     // ja
   double   sequenceStop.profit[];     // ja

   bool     start.*.condition;         // nein: wird aus StartConditions abgeleitet
   bool     stop.*.condition;          // nein: wird aus StopConditions abgeleitet

   bool     weekend.stop.triggered;    // ja

   int      ignorePendingOrders  [];   // optional (wenn belegt)
   int      ignoreOpenPositions  [];   // optional (wenn belegt)
   int      ignoreClosedPositions[];   // optional (wenn belegt)

   int      grid.base.event[];         // ja
   datetime grid.base.time [];         // ja
   double   grid.base.value[];         // ja
   double   grid.base;                 // nein: wird aus Gridbase-History restauriert

   int      grid.level;                // nein: kann aus Orderdaten restauriert werden
   int      grid.maxLevel.L/S;         // nein: kann aus Orderdaten restauriert werden

   int      grid.stops;                // nein: kann aus Orderdaten restauriert werden
   double   grid.stopsPL;              // nein: kann aus Orderdaten restauriert werden
   double   grid.closedPL;             // nein: kann aus Orderdaten restauriert werden
   double   grid.floatingPL;           // nein: kann aus offenen Positionen restauriert werden
   double   grid.totalPL;              // nein: kann aus stopsPL, closedPL und floatingPL restauriert werden
   double   grid.openRisk;             // nein: kann aus Orderdaten restauriert werden
   double   grid.valueAtRisk;          // nein: kann aus Orderdaten restauriert werden

   double   grid.maxProfit;            // ja
   double   grid.maxDrawdown;          // ja

   double   grid.breakevenLong;        // nein: wird mit dem aktuellen TickValue als Näherung neu berechnet
   double   grid.breakevenShort;       // nein: wird mit dem aktuellen TickValue als Näherung neu berechnet

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
   double   orders.openRisk    [];     // ja: 10
   int      orders.closeEvent  [];     // ja: 11
   datetime orders.closeTime   [];     // ja: 12 (EV_POSITION_STOPOUT | EV_POSITION_CLOSE)
   double   orders.closePrice  [];     // ja: 13
   double   orders.stopLoss    [];     // ja: 14
   bool     orders.clientSL    [];     // ja: 15
   bool     orders.closedBySL  [];     // ja: 16
   double   orders.swap        [];     // ja: 17
   double   orders.commission  [];     // ja: 18
   double   orders.profit      [];     // ja: 19
   */

   // (1) Dateiinhalt zusammenstellen
   string lines[]; ArrayResize(lines, 0);

   // (1.1) Input-Parameter
   ArrayPushString(lines, /*string*/   "Account="+         ShortAccountCompany() +":"+ GetAccountNumber());
   ArrayPushString(lines, /*string*/   "Symbol="                 +             Symbol()                  );
   ArrayPushString(lines, /*string*/   "Sequence.ID="            +             Sequence.ID               );
      if (StringLen(Sequence.StatusLocation) > 0)
   ArrayPushString(lines, /*string*/   "Sequence.StatusLocation="+             Sequence.StatusLocation   );
   ArrayPushString(lines, /*string*/   "GridDirection="          +             GridDirection             );
   ArrayPushString(lines, /*int   */   "GridSize="               +             GridSize                  );
   ArrayPushString(lines, /*double*/   "LotSize="                + NumberToStr(LotSize, ".+")            );
      if (start.conditions)
   ArrayPushString(lines, /*string*/   "StartConditions="        +             StartConditions           );
      if (stop.conditions)
   ArrayPushString(lines, /*string*/   "StopConditions="         +             StopConditions            );

   // (1.2) Laufzeit-Variablen
   ArrayPushString(lines, /*datetime*/ "rt.instanceStartTime="   +             instanceStartTime         );
   ArrayPushString(lines, /*double*/   "rt.instanceStartPrice="  + NumberToStr(instanceStartPrice, ".+") );
   ArrayPushString(lines, /*double*/   "rt.sequenceStartEquity=" + NumberToStr(sequenceStartEquity, ".+"));

      string values[]; ArrayResize(values, 0);
      int size = ArraySize(sequenceStart.event);
      for (int i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(sequenceStart.event[i], "|", sequenceStart.time[i], "|", NumberToStr(sequenceStart.price[i], ".+"), "|", NumberToStr(sequenceStart.profit[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0");
   ArrayPushString(lines, /*string*/   "rt.sequenceStarts="       + JoinStrings(values, ","));

      ArrayResize(values, 0);
      size = ArraySize(sequenceStop.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(sequenceStop.event[i], "|", sequenceStop.time[i], "|", NumberToStr(sequenceStop.price[i], ".+"), "|", NumberToStr(sequenceStop.profit[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0");
   ArrayPushString(lines, /*string*/   "rt.sequenceStops="        + JoinStrings(values, ","));
      if (status==STATUS_STOPPED) /*&&*/ if (IsWeekendStopSignal())
   ArrayPushString(lines, /*int*/      "rt.weekendStop="          +             1);
      if (ArraySize(ignorePendingOrders) > 0)
   ArrayPushString(lines, /*string*/   "rt.ignorePendingOrders="  +    JoinInts(ignorePendingOrders, ",")  );
      if (ArraySize(ignoreOpenPositions) > 0)
   ArrayPushString(lines, /*string*/   "rt.ignoreOpenPositions="  +    JoinInts(ignoreOpenPositions, ",")  );
      if (ArraySize(ignoreClosedPositions) > 0)
   ArrayPushString(lines, /*string*/   "rt.ignoreClosedPositions="+    JoinInts(ignoreClosedPositions, ","));

   ArrayPushString(lines, /*double*/   "rt.grid.maxProfit="       + NumberToStr(grid.maxProfit, ".+")      );
   ArrayPushString(lines, /*double*/   "rt.grid.maxDrawdown="     + NumberToStr(grid.maxDrawdown, ".+")    );

      ArrayResize(values, 0);
      size = ArraySize(grid.base.L.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(grid.base.L.event[i], "|", grid.base.L.time[i], "|", NumberToStr(grid.base.L.value[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0");
   ArrayPushString(lines, /*string*/   "rt.grid.base.L="           + JoinStrings(values, ","));

      ArrayResize(values, 0);
      size = ArraySize(grid.base.S.event);
      for (i=0; i < size; i++)
         ArrayPushString(values, StringConcatenate(grid.base.S.event[i], "|", grid.base.S.time[i], "|", NumberToStr(grid.base.S.value[i], ".+")));
      if (size == 0)
         ArrayPushString(values, "0|0|0");
   ArrayPushString(lines, /*string*/   "rt.grid.base.S="           + JoinStrings(values, ","));

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
      double   openRisk     = orders.openRisk    [i];    // 10
      int      closeEvent   = orders.closeEvent  [i];    // 11
      datetime closeTime    = orders.closeTime   [i];    // 12
      double   closePrice   = orders.closePrice  [i];    // 13
      double   stopLoss     = orders.stopLoss    [i];    // 14
      bool     clientSL     = orders.clientSL    [i];    // 15
      bool     closedBySL   = orders.closedBySL  [i];    // 16
      double   swap         = orders.swap        [i];    // 17
      double   commission   = orders.commission  [i];    // 18
      double   profit       = orders.profit      [i];    // 19
      ArrayPushString(lines, StringConcatenate("rt.order.", i, "=", ticket, ",", level, ",", NumberToStr(NormalizeDouble(gridBase, Digits), ".+"), ",", pendingType, ",", pendingTime, ",", NumberToStr(NormalizeDouble(pendingPrice, Digits), ".+"), ",", type, ",", openEvent, ",", openTime, ",", NumberToStr(NormalizeDouble(openPrice, Digits), ".+"), ",", NumberToStr(NormalizeDouble(openRisk, 2), ".+"), ",", closeEvent, ",", closeTime, ",", NumberToStr(NormalizeDouble(closePrice, Digits), ".+"), ",", NumberToStr(NormalizeDouble(stopLoss, Digits), ".+"), ",", clientSL, ",", closedBySL, ",", NumberToStr(swap, ".+"), ",", NumberToStr(commission, ".+"), ",", NumberToStr(profit, ".+")));
      //rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{openRisk},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
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
   return(IsNoError(last_error|catch("SaveStatus(4)")));
}


/**
 * Lädt die angegebene Statusdatei auf den Server.
 *
 * @param  string company  - Account-Company
 * @param  int    account  - Account-Number
 * @param  string symbol   - Symbol der Sequenz
 * @param  string filename - Dateiname, relativ zu "{terminal-directory}\experts"
 *
 * @return int - Fehlerstatus
 */
int UploadStatus(string company, int account, string symbol, string filename) {
   if (__STATUS__CANCELLED || IsLastError()) return(last_error);
   if (IsTest())                             return(NO_ERROR);

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
   if (__STATUS__CANCELLED || IsLastError()) return( false);
   if (sequenceId == 0)                      return(_false(catch("RestoreStatus(1)   illegal value of sequenceId = "+ sequenceId, ERR_RUNTIME_ERROR)));


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
      return(_false(SetLastError(stdlib_PeekLastError())));
   if (size == 0) {
      FileDelete(fileName);
      return(_false(catch("RestoreStatus(4)   no status for sequence "+ ifString(IsTest(), "T", "") + sequenceId +" not found", ERR_RUNTIME_ERROR)));
   }

   // notwendige Schlüssel definieren
   string keys[] = { "Account", "Symbol", "Sequence.ID", "GridDirection", "GridSize", "LotSize", "rt.instanceStartTime", "rt.instanceStartPrice", "rt.sequenceStartEquity", "rt.sequenceStarts", "rt.sequenceStops", "rt.grid.maxProfit", "rt.grid.maxDrawdown", "rt.grid.base", "rt.grid.base.L", "rt.grid.base.S" };
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
                     "rt.instanceStartTime"    ,
                     "rt.instanceStartPrice"   ,
                     "rt.sequenceStartEquity"  ,
                     "rt.sequenceStarts"       ,
                     "rt.sequenceStops"        ,
                   //"rt.weekendStop"          ,                        // optional
                   //"rt.ignorePendingOrders"  ,                        // optional
                   //"rt.ignoreOpenPositions"  ,                        // optional
                   //"rt.ignoreClosedPositions",                        // optional
                     "rt.grid.maxProfit"       ,
                     "rt.grid.maxDrawdown"     ,
                     "rt.grid.base"            ,                        // altes Format
                     "rt.grid.base.L"          ,                        // neues Format
                     "rt.grid.base.S"          ,
   */


   // (4.1) Nicht-Runtime-Settings auslesen, validieren und übernehmen
   string parts[], key, value, accountValue;
   int    accountLine;

   for (int i=0; i < size; i++) {
      if (StringStartsWith(StringTrim(lines[i]), "#"))                  // Kommentare überspringen
         continue;

      if (Explode(lines[i], "=", parts, 2) < 2)                         return(_false(catch("RestoreStatus(5)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
      key   = StringTrim(parts[0]);
      value = StringTrim(parts[1]);

      if (key == "Account") {
         accountValue = value;
         accountLine  = i;
         ArrayDropString(keys, key);                                    // Abhängigkeit Account <=> Sequence.ID (siehe 4.2)
      }
      else if (key == "Symbol") {
         if (value != Symbol())                                         return(_false(catch("RestoreStatus(6)   symbol mis-match \""+ value +"\"/\""+ Symbol() +"\" in status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         ArrayDropString(keys, key);
      }
      else if (key == "Sequence.ID") {
         value = StringToUpper(value);
         if (StringLeft(value, 1) == "T") {
            test  = true;
            value = StringRight(value, -1);
         }
         if (value != StringConcatenate("", sequenceId))                return(_false(catch("RestoreStatus(7)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         Sequence.ID = ifString(IsTest(), "T", "") + sequenceId;
         ArrayDropString(keys, key);
      }
      else if (key == "Sequence.StatusLocation") {
         Sequence.StatusLocation = value;
      }
      else if (key == "GridDirection") {
         // GridDirection für Runtime-Settings sofort validieren: analog zu ValidateConfiguration()
         if (value == "")                                               return(_false(catch("RestoreStatus(8)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         value = StringToLower(value);
         switch (StringGetChar(value, 0)) {
            case 'b': grid.direction = D_BIDIR; break;
            case 'l': grid.direction = D_LONG;  break;
            case 's': grid.direction = D_SHORT; break;
            default:                                                    return(_false(catch("RestoreStatus(9)   illegal GridDirection \""+ parts[1] +"\" in status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         }
         GridDirection = directionDescr[grid.direction];
         ArrayDropString(keys, key);
      }
      else if (key == "GridSize") {
         if (!StringIsDigit(value))                                     return(_false(catch("RestoreStatus(10)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
         GridSize = StrToInteger(value);
         ArrayDropString(keys, key);
      }
      else if (key == "LotSize") {
         if (!StringIsNumeric(value))                                   return(_false(catch("RestoreStatus(11)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
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
                                                                        return(_false(catch("RestoreStatus(12)   account mis-match \""+ ShortAccountCompany() +":"+ GetAccountNumber() +"\"/\""+ accountValue +"\" in status file \""+ fileName +"\" (line \""+ lines[accountLine] +"\")", ERR_RUNTIME_ERROR)));
   }

   // (5.1) Runtime-Settings auslesen, validieren und übernehmen
   ArrayResize(sequenceStart.event,   0);
   ArrayResize(sequenceStart.time,    0);
   ArrayResize(sequenceStart.price,   0);
   ArrayResize(sequenceStart.profit,  0);
   ArrayResize(sequenceStop.event,    0);
   ArrayResize(sequenceStop.time,     0);
   ArrayResize(sequenceStop.price,    0);
   ArrayResize(sequenceStop.profit,   0);
   ArrayResize(ignorePendingOrders,   0);
   ArrayResize(ignoreOpenPositions,   0);
   ArrayResize(ignoreClosedPositions, 0);
   ArrayResize(grid.base.L.event,     0);
   ArrayResize(grid.base.L.time,      0);
   ArrayResize(grid.base.L.value,     0);
   ArrayResize(grid.base.S.event,     0);
   ArrayResize(grid.base.S.time,      0);
   ArrayResize(grid.base.S.value,     0);
   lastEventId = 0;

   for (i=0; i < size; i++) {
      if (Explode(lines[i], "=", parts, 2) < 2)                         return(_false(catch("RestoreStatus(13)   invalid status file \""+ fileName +"\" (line \""+ lines[i] +"\")", ERR_RUNTIME_ERROR)));
      key   = StringTrim(parts[0]);
      value = StringTrim(parts[1]);

      if (StringStartsWith(key, "rt."))
         if (!RestoreStatus.Runtime(fileName, lines[i], key, value, keys))
            return(false);
   }
   if (ArraySize(keys) > 0)                                             return(_false(catch("RestoreStatus(14)   "+ ifString(ArraySize(keys)==1, "entry", "entries") +" \""+ JoinStrings(keys, "\", \"") +"\" missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));

   // (5.2) Abhängigkeiten validieren
   if (ArraySize(sequenceStart.event) != ArraySize(sequenceStop.event)) return(_false(catch("RestoreStatus(15)   sequenceStarts("+ ArraySize(sequenceStart.event) +") / sequenceStops("+ ArraySize(sequenceStop.event) +") mis-match in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));
   if (IntInArray(orders.ticket, 0))                                    return(_false(catch("RestoreStatus(16)   one or more order entries missing in file \""+ fileName +"\"", ERR_RUNTIME_ERROR)));


   ArrayResize(lines, 0);
   ArrayResize(keys,  0);
   ArrayResize(parts, 0);
   return(IsNoError(last_error|catch("RestoreStatus(17)")));
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
   if (__STATUS__CANCELLED || IsLastError())
      return(false);
   /*
   datetime rt.instanceStartTime=1328701713
   double   rt.instanceStartPrice=1.32677
   double   rt.sequenceStartEquity=7801.13
   string   rt.sequenceStarts=1|1328701713|1.32677|1000,2|1329999999|1.33215|1200
   string   rt.sequenceStops=3|1328701999|1.32734|1200,0|0|0|0
   int      rt.weekendStop=1
   string   rt.ignorePendingOrders=66064890,66064891,66064892
   string   rt.ignoreOpenPositions=66064890,66064891,66064892
   string   rt.ignoreClosedPositions=66064890,66064891,66064892
   double   rt.grid.maxProfit=200.13
   double   rt.grid.maxDrawdown=-127.80
   string   rt.grid.base=4|1331710960|1.56743,5|1331711010|1.56714
            oder
   string   rt.grid.base.L=4|1331710960|1.56743,5|1331711010|1.56714
   string   rt.grid.base.S=4|1331710960|1.56743,5|1331711010|1.56714
   string   rt.order.0=62544847,1,1.32067,4,1330932525,1.32067,1,100,1330936196,1.32067,0,101,1330938698,1.31897,1.31897,0,1,0,0,-17
            rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{openRisk},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}

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
      double   openRisk     = values[10];
      int      closeEvent   = values[11];
      datetime closeTime    = values[12];
      double   closePrice   = values[13];
      double   stopLoss     = values[14];
      bool     clientSL     = values[15];
      bool     closedBySL   = values[16];
      double   swap         = values[17];
      double   commission   = values[18];
      double   profit       = values[19];
   */
   string values[], data[];


   if (key == "rt.instanceStartTime") {
      Explode(value, "(", values, 2);
      value = StringTrim(values[0]);
      if (!StringIsDigit(value))                                            return(_false(catch("RestoreStatus.Runtime(1)   illegal instanceStartTime \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      instanceStartTime = StrToInteger(value);
      if (instanceStartTime == 0)                                           return(_false(catch("RestoreStatus.Runtime(2)   illegal instanceStartTime "+ instanceStartTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ArrayDropString(keys, key);
   }
   else if (key == "rt.instanceStartPrice") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(3)   illegal instanceStartPrice \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      instanceStartPrice = StrToDouble(value);
      if (LE(instanceStartPrice, 0))                                        return(_false(catch("RestoreStatus.Runtime(4)   illegal instanceStartPrice "+ NumberToStr(instanceStartPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequenceStartEquity") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(5)   illegal sequenceStartEquity \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      sequenceStartEquity = StrToDouble(value);
      if (LT(sequenceStartEquity, 0))                                       return(_false(catch("RestoreStatus.Runtime(6)   illegal sequenceStartEquity "+ DoubleToStr(sequenceStartEquity, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequenceStarts") {
      // rt.sequenceStarts=1|1331710960|1.56743|1000,2|1331711010|1.56714|1200
      int sizeOfValues = Explode(value, ",", values, NULL);
      for (int i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 4)                      return(_false(catch("RestoreStatus.Runtime(7)   illegal number of sequenceStarts["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[0];                          // sequenceStart.event
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(8)   illegal sequenceStart.event["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int startEvent = StrToInteger(value);
         if (startEvent == 0) {
            if (sizeOfValues==1 && values[i]=="0|0|0|0") {
               if (NE(sequenceStartEquity, 0))                              return(_false(catch("RestoreStatus.Runtime(9)   sequenceStartEquity/sequenceStart["+ i +"] mis-match "+ NumberToStr(sequenceStartEquity, ".2") +"/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
               break;
            }
            return(_false(catch("RestoreStatus.Runtime(10)   illegal sequenceStart.event["+ i +"] "+ startEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         }
         if (EQ(sequenceStartEquity, 0))                                    return(_false(catch("RestoreStatus.Runtime(11)   sequenceStartEquity/sequenceStart["+ i +"] mis-match "+ NumberToStr(sequenceStartEquity, ".2") +"/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[1];                          // sequenceStart.time
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(12)   illegal sequenceStart.time["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime startTime = StrToInteger(value);
         if (startTime == 0)                                                return(_false(catch("RestoreStatus.Runtime(13)   illegal sequenceStart.time["+ i +"] "+ startTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         else if (startTime < instanceStartTime)                            return(_false(catch("RestoreStatus.Runtime(14)   instanceStartTime/sequenceStart.time["+ i +"] mis-match '"+ TimeToStr(instanceStartTime, TIME_FULL) +"'/'"+ TimeToStr(startTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[2];                          // sequenceStart.price
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(15)   illegal sequenceStart.price["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double startPrice = StrToDouble(value);
         if (LE(startPrice, 0))                                             return(_false(catch("RestoreStatus.Runtime(16)   illegal sequenceStart.price["+ i +"] "+ NumberToStr(startPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[3];                          // sequenceStart.profit
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(17)   illegal sequenceStart.profit["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double startProfit = StrToDouble(value);

         ArrayPushInt   (sequenceStart.event,  startEvent );
         ArrayPushInt   (sequenceStart.time,   startTime  );
         ArrayPushDouble(sequenceStart.price,  startPrice );
         ArrayPushDouble(sequenceStart.profit, startProfit);
         lastEventId = Max(lastEventId, startEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (key == "rt.sequenceStops") {
      // rt.sequenceStops=1|1331710960|1.56743|1200,0|0|0|0
      sizeOfValues = Explode(value, ",", values, NULL);
      for (i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 4)                      return(_false(catch("RestoreStatus.Runtime(18)   illegal number of sequenceStops["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[0];                          // sequenceStop.event
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(19)   illegal sequenceStop.event["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int stopEvent = StrToInteger(value);
         if (stopEvent == 0) {
            if (i < sizeOfValues-1)                                         return(_false(catch("RestoreStatus.Runtime(20)   illegal sequenceStop["+ i +"] \""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            if (values[i] != "0|0|0|0")                                     return(_false(catch("RestoreStatus.Runtime(21)   illegal sequenceStop["+ i +"] \""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            if (i==0 && ArraySize(sequenceStart.event)==0)
               break;
         }

         value = data[1];                          // sequenceStop.time
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(22)   illegal sequenceStop.time["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime stopTime = StrToInteger(value);
         if (stopTime==0 && stopEvent!=0)                                   return(_false(catch("RestoreStatus.Runtime(23)   illegal sequenceStop.time["+ i +"] "+ stopTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (i >= ArraySize(sequenceStart.event))                           return(_false(catch("RestoreStatus.Runtime(24)   sequenceStarts("+ ArraySize(sequenceStart.event) +") / sequenceStops("+ sizeOfValues +") mis-match in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (stopTime!=0 && stopTime < sequenceStart.time[i])               return(_false(catch("RestoreStatus.Runtime(25)   sequenceStart.time["+ i +"]/sequenceStop.time["+ i +"] mis-match '"+ TimeToStr(sequenceStart.time[i], TIME_FULL) +"'/'"+ TimeToStr(stopTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[2];                          // sequenceStop.price
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(26)   illegal sequenceStop.price["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double stopPrice = StrToDouble(value);
         if (LT(stopPrice, 0))                                              return(_false(catch("RestoreStatus.Runtime(27)   illegal sequenceStop.price["+ i +"] "+ NumberToStr(stopPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (EQ(stopPrice, 0) && stopEvent!=0)                              return(_false(catch("RestoreStatus.Runtime(28)   sequenceStop.time["+ i +"]/sequenceStop.price["+ i +"] mis-match '"+ TimeToStr(stopTime, TIME_FULL) +"'/"+ NumberToStr(stopPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[3];                          // sequenceStop.profit
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(29)   illegal sequenceStop.profit["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double stopProfit = StrToDouble(value);

         ArrayPushInt   (sequenceStop.event,  stopEvent );
         ArrayPushInt   (sequenceStop.time,   stopTime  );
         ArrayPushDouble(sequenceStop.price,  stopPrice );
         ArrayPushDouble(sequenceStop.profit, stopProfit);
         lastEventId = Max(lastEventId, stopEvent);
      }
      ArrayDropString(keys, key);
   }
   else if (key == "rt.weekendStop") {
      if (!StringIsDigit(value))                                            return(_false(catch("RestoreStatus.Runtime(30)   illegal weekendStop \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      weekend.stop.triggered = (StrToInteger(value));
   }
   else if (key == "rt.ignorePendingOrders") {
      // rt.ignorePendingOrders=66064890,66064891,66064892
      if (StringLen(value) > 0) {
         sizeOfValues = Explode(value, ",", values, NULL);
         for (i=0; i < sizeOfValues; i++) {
            string strTicket = StringTrim(values[i]);
            if (!StringIsDigit(strTicket))                                  return(_false(catch("RestoreStatus.Runtime(31)   illegal ticket \""+ strTicket +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            int ticket = StrToInteger(strTicket);
            if (ticket == 0)                                                return(_false(catch("RestoreStatus.Runtime(32)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
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
            if (ticket == 0)                                                return(_false(catch("RestoreStatus.Runtime(34)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
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
            if (ticket == 0)                                                return(_false(catch("RestoreStatus.Runtime(36)   illegal ticket #"+ ticket +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
            ArrayPushInt(ignoreClosedPositions, ticket);
         }
      }
   }
   else if (key == "rt.grid.maxProfit") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(37)   illegal grid.maxProfit \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      grid.maxProfit = StrToDouble(value); SS.Grid.MaxProfit();
      ArrayDropString(keys, key);
   }
   else if (key == "rt.grid.maxDrawdown") {
      if (!StringIsNumeric(value))                                          return(_false(catch("RestoreStatus.Runtime(38)   illegal grid.maxDrawdown \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      grid.maxDrawdown = StrToDouble(value); SS.Grid.MaxDrawdown();
      ArrayDropString(keys, key);
   }
   else if (key=="rt.grid.base" || key=="rt.grid.base.L" || key=="rt.grid.base.S") {
      // rt.grid.base[.{L|S}]=1|1331710960|1.56743,2|1331711010|1.56714
      string direction;
      if (key == "rt.grid.base") {
         if (grid.direction == D_BIDIR)                                     return(_false(catch("RestoreStatus.Runtime(39)   old/unsupported file format for bidirectional sequences in status file \""+ file +"\"", ERR_RUNTIME_ERROR)));
         if (grid.direction == D_LONG ) direction = ".L";
         if (grid.direction == D_SHORT) direction = ".S";
      }
      else {
         direction = StringRight(key, 2);
      }
      sizeOfValues = Explode(value, ",", values, NULL);
      for (i=0; i < sizeOfValues; i++) {
         if (Explode(values[i], "|", data, NULL) != 3)                      return(_false(catch("RestoreStatus.Runtime(40)   illegal number of grid.base"+ direction +"["+ i +"] details (\""+ values[i] +"\" = "+ ArraySize(data) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[0];                          // GridBase-Event
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(41)   illegal grid.base.event"+ direction +"["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         int gridBaseEvent = StrToInteger(value);
         int starts = ArraySize(sequenceStart.event);
         if (gridBaseEvent == 0) {
            if (sizeOfValues==1 && values[0]=="0|0|0") {
               if (starts > 0) {
                  if (grid.direction==D_LONG  && direction==".S") break;
                  if (grid.direction==D_SHORT && direction==".L") break;    return(_false(catch("RestoreStatus.Runtime(42)   sequenceStart/grid.base"+ direction +"["+ i +"] mis-match '"+ TimeToStr(sequenceStart.time[0], TIME_FULL) +"'/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
               }
               break;
            }                                                               return(_false(catch("RestoreStatus.Runtime(43)   illegal grid.base.event"+ direction +"["+ i +"] "+ gridBaseEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         }
         else if (starts == 0)                                              return(_false(catch("RestoreStatus.Runtime(44)   sequenceStart/grid.base"+ direction +"["+ i +"] mis-match "+ starts +"/\""+ values[i] +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[1];                          // GridBase-Zeitpunkt
         if (!StringIsDigit(value))                                         return(_false(catch("RestoreStatus.Runtime(45)   illegal grid.base.time"+ direction +"["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         datetime gridBaseTime = StrToInteger(value);
         if (gridBaseTime == 0)                                             return(_false(catch("RestoreStatus.Runtime(46)   illegal grid.base.time"+ direction +"["+ i +"] "+ gridBaseTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         value = data[2];                          // GridBase-Wert
         if (!StringIsNumeric(value))                                       return(_false(catch("RestoreStatus.Runtime(47)   illegal grid.base.value"+ direction +"["+ i +"] \""+ value +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         double gridBaseValue = StrToDouble(value);
         if (LE(gridBaseValue, 0))                                          return(_false(catch("RestoreStatus.Runtime(48)   illegal grid.base.value"+ direction +"["+ i +"] "+ NumberToStr(gridBaseValue, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

         if (direction == ".L") {
            ArrayPushInt   (grid.base.L.event, gridBaseEvent);
            ArrayPushInt   (grid.base.L.time,  gridBaseTime );
            ArrayPushDouble(grid.base.L.value, gridBaseValue);
         }
         if (direction == ".S") {
            ArrayPushInt   (grid.base.S.event, gridBaseEvent);
            ArrayPushInt   (grid.base.S.time,  gridBaseTime );
            ArrayPushDouble(grid.base.S.value, gridBaseValue);
         }
         lastEventId = Max(lastEventId, gridBaseEvent);
      }
      if (key == "rt.grid.base") {
         ArrayDropString(keys, key);
         ArrayDropString(keys, "rt.grid.base.L");
         ArrayDropString(keys, "rt.grid.base.S");
      }
      else {
         ArrayDropString(keys, "rt.grid.base");
         ArrayDropString(keys, key);
      }
   }
   else if (StringStartsWith(key, "rt.order.")) {
      // rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{openRisk},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
      // Orderindex
      string strIndex = StringRight(key, -9);
      if (!StringIsDigit(strIndex))                                         return(_false(catch("RestoreStatus.Runtime(49)   illegal order index \""+ key +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      i = StrToInteger(strIndex);
      if (ArraySize(orders.ticket) > i) /*&&*/ if (orders.ticket[i]!=0)     return(_false(catch("RestoreStatus.Runtime(50)   duplicate order index "+ key +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // Orderdaten
      if (Explode(value, ",", values, NULL) != 20)                          return(_false(catch("RestoreStatus.Runtime(51)   illegal number of order details ("+ ArraySize(values) +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

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
      if (pendingType!=OP_UNDEFINED && pendingTime==0)                      return(_false(catch("RestoreStatus.Runtime(63)   pending order type/time mis-match "+ OperationTypeToStr(pendingType) +"/"+ pendingTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

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
      if (type!=OP_UNDEFINED && openEvent==0)                               return(_false(catch("RestoreStatus.Runtime(74)   illegal order open event "+ openEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openTime
      string strOpenTime = StringTrim(values[8]);
      if (!StringIsDigit(strOpenTime))                                      return(_false(catch("RestoreStatus.Runtime(75)   illegal order open time \""+ strOpenTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime openTime = StrToInteger(strOpenTime);
      if (type==OP_UNDEFINED && openTime!=0)                                return(_false(catch("RestoreStatus.Runtime(76)   order type/time mis-match "+ OperationTypeToStr(type) +"/'"+ TimeToStr(openTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type!=OP_UNDEFINED && openTime==0)                                return(_false(catch("RestoreStatus.Runtime(77)   order type/time mis-match "+ OperationTypeToStr(type) +"/"+ openTime +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openPrice
      string strOpenPrice = StringTrim(values[9]);
      if (!StringIsNumeric(strOpenPrice))                                   return(_false(catch("RestoreStatus.Runtime(78)   illegal order open price \""+ strOpenPrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double openPrice = StrToDouble(strOpenPrice);
      if (LT(openPrice, 0))                                                 return(_false(catch("RestoreStatus.Runtime(79)   illegal order open price "+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type==OP_UNDEFINED && NE(openPrice, 0))                           return(_false(catch("RestoreStatus.Runtime(80)   order type/price mis-match "+ OperationTypeToStr(type) +"/"+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (type!=OP_UNDEFINED && EQ(openPrice, 0))                           return(_false(catch("RestoreStatus.Runtime(81)   order type/price mis-match "+ OperationTypeToStr(type) +"/"+ NumberToStr(openPrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // openRisk
      string strOpenRisk = StringTrim(values[10]);
      if (!StringIsNumeric(strOpenRisk))                                    return(_false(catch("RestoreStatus.Runtime(82)   illegal order open risk \""+ strOpenRisk +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double openRisk = StrToDouble(strOpenRisk);
      if (type==OP_UNDEFINED && NE(openRisk, 0))                            return(_false(catch("RestoreStatus.Runtime(83)   pending order/openRisk mis-match "+ OperationTypeToStr(pendingType) +"/"+ NumberToStr(openRisk, ".2+") +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // closeEvent
      string strCloseEvent = StringTrim(values[11]);
      if (!StringIsDigit(strCloseEvent))                                    return(_false(catch("RestoreStatus.Runtime(84)   illegal order close event \""+ strCloseEvent +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      int closeEvent = StrToInteger(strCloseEvent);

      // closeTime
      string strCloseTime = StringTrim(values[12]);
      if (!StringIsDigit(strCloseTime))                                     return(_false(catch("RestoreStatus.Runtime(85)   illegal order close time \""+ strCloseTime +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      datetime closeTime = StrToInteger(strCloseTime);
      if (closeTime != 0) {
         if (closeTime < pendingTime)                                       return(_false(catch("RestoreStatus.Runtime(86)   pending order time/delete time mis-match '"+ TimeToStr(pendingTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
         if (closeTime < openTime)                                          return(_false(catch("RestoreStatus.Runtime(87)   order open/close time mis-match '"+ TimeToStr(openTime, TIME_FULL) +"'/'"+ TimeToStr(closeTime, TIME_FULL) +"' in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      }
      if (closeTime!=0 && closeEvent==0)                                    return(_false(catch("RestoreStatus.Runtime(88)   illegal order close event "+ closeEvent +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // closePrice
      string strClosePrice = StringTrim(values[13]);
      if (!StringIsNumeric(strClosePrice))                                  return(_false(catch("RestoreStatus.Runtime(89)   illegal order close price \""+ strClosePrice +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double closePrice = StrToDouble(strClosePrice);
      if (LT(closePrice, 0))                                                return(_false(catch("RestoreStatus.Runtime(90)   illegal order close price "+ NumberToStr(closePrice, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // stopLoss
      string strStopLoss = StringTrim(values[14]);
      if (!StringIsNumeric(strStopLoss))                                    return(_false(catch("RestoreStatus.Runtime(91)   illegal order stop-loss \""+ strStopLoss +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double stopLoss = StrToDouble(strStopLoss);
      if (LE(stopLoss, 0))                                                  return(_false(catch("RestoreStatus.Runtime(92)   illegal order stop-loss "+ NumberToStr(stopLoss, PriceFormat) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      if (NE(stopLoss, gridBase+(level-Sign(level))*GridSize*Pips, Digits)) return(_false(catch("RestoreStatus.Runtime(93)   grid base/stop-loss mis-match "+ NumberToStr(gridBase, PriceFormat) +"/"+ NumberToStr(stopLoss, PriceFormat) +" (level "+ level +") in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // clientSL
      string strClientSL = StringTrim(values[15]);
      if (!StringIsDigit(strClientSL))                                      return(_false(catch("RestoreStatus.Runtime(94)   illegal clientSL value \""+ strClientSL +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      bool clientSL = _bool(StrToInteger(strClientSL));

      // closedBySL
      string strClosedBySL = StringTrim(values[16]);
      if (!StringIsDigit(strClosedBySL))                                    return(_false(catch("RestoreStatus.Runtime(95)   illegal closedBySL value \""+ strClosedBySL +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      bool closedBySL = _bool(StrToInteger(strClosedBySL));

      // swap
      string strSwap = StringTrim(values[17]);
      if (!StringIsNumeric(strSwap))                                        return(_false(catch("RestoreStatus.Runtime(96)   illegal order swap \""+ strSwap +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double swap = StrToDouble(strSwap);
      if (type==OP_UNDEFINED && NE(swap, 0))                                return(_false(catch("RestoreStatus.Runtime(97)   pending order/swap mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(swap, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // commission
      string strCommission = StringTrim(values[18]);
      if (!StringIsNumeric(strCommission))                                  return(_false(catch("RestoreStatus.Runtime(98)   illegal order commission \""+ strCommission +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double commission = StrToDouble(strCommission);
      if (type==OP_UNDEFINED && NE(commission, 0))                          return(_false(catch("RestoreStatus.Runtime(99)   pending order/commission mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(commission, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));

      // profit
      string strProfit = StringTrim(values[19]);
      if (!StringIsNumeric(strProfit))                                      return(_false(catch("RestoreStatus.Runtime(100)   illegal order profit \""+ strProfit +"\" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));
      double profit = StrToDouble(strProfit);
      if (type==OP_UNDEFINED && NE(profit, 0))                              return(_false(catch("RestoreStatus.Runtime(101)   pending order/profit mis-match "+ OperationTypeToStr(pendingType) +"/"+ DoubleToStr(profit, 2) +" in status file \""+ file +"\" (line \""+ line +"\")", ERR_RUNTIME_ERROR)));


      // Daten speichern
      Grid.SetData(i, ticket, level, gridBase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, openRisk, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit);
      lastEventId = Max(lastEventId, Max(openEvent, closeEvent));
      //debug("RestoreStatus.Runtime()   #"+ ticket +"  level="+ level +"  gridBase="+ NumberToStr(gridBase, PriceFormat) +"  pendingType="+ OperationTypeToStr(pendingType) +"  pendingTime="+ ifString(pendingTime==0, 0, "'"+ TimeToStr(pendingTime, TIME_FULL) +"'") +"  pendingPrice="+ NumberToStr(pendingPrice, PriceFormat) +"  type="+ OperationTypeToStr(type) +"  openEvent="+ openEvent +"  openTime="+ ifString(openTime==0, 0, "'"+ TimeToStr(openTime, TIME_FULL) +"'") +"  openPrice="+ NumberToStr(openPrice, PriceFormat) +"  openRisk="+ DoubleToStr(openRisk, 2) +"  closeEvent="+ closeEvent +"  closeTime="+ ifString(closeTime==0, 0, "'"+ TimeToStr(closeTime, TIME_FULL) +"'") +"  closePrice="+ NumberToStr(closePrice, PriceFormat) +"  stopLoss="+ NumberToStr(stopLoss, PriceFormat) +"  clientSL="+ BoolToStr(clientSL) +"  closedBySL="+ BoolToStr(closedBySL) +"  swap="+ DoubleToStr(swap, 2) +"  commission="+ DoubleToStr(commission, 2) +"  profit="+ DoubleToStr(profit, 2));
      // rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{openRisk},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
   }

   ArrayResize(values, 0);
   ArrayResize(data,   0);
   return(IsNoError(last_error|catch("RestoreStatus.Runtime(102)")));
}


/**
 * Gleicht den in der Instanz gespeicherten Laufzeitstatus mit den Online-Daten der laufenden Sequenz ab.
 * Aufruf nur direkt nach ValidateConfiguration()
 *
 * @return bool - Erfolgsstatus
 */
bool SynchronizeStatus() {
   if (__STATUS__CANCELLED || IsLastError())
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
               __STATUS__CANCELLED = true;                                 // Flag vor Aufruf setzen, falls der Dialog gewaltsam beendet wird
               ForceSound("notify.wav");
               int button = ForceMessageBox(__NAME__ +" - SynchronizeStatus()", "Ticket #"+ orders.ticket[i] +" not found.\nPlease expand the available trade history.", MB_ICONERROR|MB_RETRYCANCEL);
               if (button == IDRETRY) {
                  __STATUS__CANCELLED = false;
                  return(SynchronizeStatus());
               }
               return(false);
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
      //   __STATUS__CANCELLED = true;
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
      //   __STATUS__CANCELLED = true;
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
         __STATUS__CANCELLED = true;
         return(_false(catch("SynchronizeStatus(7)")));
      }
      MergeIntArrays(ignoreClosedPositions, orphanedClosedPositions, ignoreClosedPositions);
      ArraySort(ignoreClosedPositions);
      permanentStatusChange = true;
      ArrayResize(orphanedClosedPositions, 0);
   }

   if (ArraySize(sequenceStart.event) > 0) {
      if (grid.direction!=D_SHORT && !ArraySize(grid.base.L.event)) return(_false(catch("SynchronizeStatus(8)   illegal number of grid.base.L events = "+ 0, ERR_RUNTIME_ERROR)));
      if (grid.direction!=D_LONG  && !ArraySize(grid.base.S.event)) return(_false(catch("SynchronizeStatus(9)   illegal number of grid.base.S events = "+ 0, ERR_RUNTIME_ERROR)));
   }


   // (2) Status und Variablen synchronisieren
   int        status.L,               status.S;
   int        lastEventId.L,          lastEventId.S;
   datetime   stopTime.L,             stopTime.S;
   double     stopPrice.L,            stopPrice.S;

   /*int   */ grid.level.L       = 0; grid.level.S       = 0;
   /*int   */ grid.maxLevel.L    = 0; grid.maxLevel.S    = 0;
   /*int   */ grid.stops.L       = 0; grid.stops.S       = 0;
   /*double*/ grid.stopsPL.L     = 0; grid.stopsPL.S     = 0;
   /*double*/ grid.closedPL.L    = 0; grid.closedPL.S    = 0;
   /*double*/ grid.floatingPL.L  = 0; grid.floatingPL.S  = 0;
   /*double*/ grid.totalPL.L     = 0; grid.totalPL.S     = 0;
   /*double*/ grid.openRisk.L    = 0; grid.openRisk.S    = 0;
   /*double*/ grid.valueAtRisk.L = 0; grid.valueAtRisk.S = 0;
   /*double*/ grid.breakeven.L   = 0; grid.breakeven.S   = 0;

   // (2.1) Long
   if (grid.direction != D_SHORT) {
      status      = STATUS_WAITING;
      lastEventId = 0;
      if (!Sync.ProcessEvents(D_LONG, stopTime.L, stopPrice.L))
         return(false);
      status.L      = status;
      lastEventId.L = lastEventId;
   }

   // (2.2) Short
   if (grid.direction != D_LONG) {
      status      = STATUS_WAITING;
      lastEventId = 0;
      if (!Sync.ProcessEvents(D_SHORT, stopTime.S, stopPrice.S))
         return(false);
      status.S      = status;
      lastEventId.S = lastEventId;
   }
   lastEventId    = Max(lastEventId.L, lastEventId.S);

   grid.totalPL.L = NormalizeDouble(grid.stopsPL.L + grid.closedPL.L + grid.floatingPL.L, 2);
   grid.totalPL.S = NormalizeDouble(grid.stopsPL.S + grid.closedPL.S + grid.floatingPL.S, 2);
   grid.totalPL   = NormalizeDouble(grid.totalPL.L + grid.totalPL.S, 2);


   // (2.3) Wurde die Sequenz außerhalb gestoppt, EV_SEQUENCE_STOP erzeugen
   if (status.L==STATUS_STOPPING || status.S==STATUS_STOPPING) {
      status = STATUS_STOPPING;
      i = ArraySize(sequenceStop.event) - 1;
      if (sequenceStop.time[i] != 0)
         return(_false(catch("SynchronizeStatus(10)   unexpected sequenceStop.time="+ IntsToStr(sequenceStop.time, NULL), ERR_RUNTIME_ERROR)));

      sequenceStop.event[i] = CreateEventId();
      sequenceStop.time [i] = Max(stopTime.L, stopTime.S);
         int level = grid.level.L + grid.level.S;
         if      (level > 0)                 sequenceStop.price[i] =  stopPrice.L;
         else if (level < 0)                 sequenceStop.price[i] =  stopPrice.S;
         else if (grid.direction == D_BIDIR) sequenceStop.price[i] = (stopPrice.L + stopPrice.S)/2;
         else                                sequenceStop.price[i] = MathMax(stopPrice.L, stopPrice.S);
                                             sequenceStop.price[i] = NormalizeDouble(sequenceStop.price[i], Digits);
      sequenceStop.profit[i] = grid.totalPL;

      if (!StopSequence.LimitStopPrice())                            //  StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
         return(false);

      status                = STATUS_STOPPED;
      permanentStatusChange = true;
      if (!Grid.DrawBreakeven(sequenceStop.time[i]))
         return(false);
   }
   else if (grid.direction == D_BIDIR)
      if (status.L != status.S) return(_false(catch("SynchronizeStatus(11)   sequence status.L/status.S mis-match = "+ status.L +"/"+ status.S, ERR_RUNTIME_ERROR)));


   // (3) Daten für Wochenend-Pause aktualisieren
   if (weekend.stop.triggered) /*&&*/ if (status!=STATUS_STOPPED)
      return(_false(catch("SynchronizeStatus(12)   weekend.stop.triggered="+ weekend.stop.triggered +" / status="+ StatusToStr(status)+ " mis-match", ERR_RUNTIME_ERROR)));

   if      (status == STATUS_PROGRESSING) UpdateWeekendStop();
   else if (status == STATUS_STOPPED)
      if (IsWeekendStopSignal())          UpdateWeekendResume();


   // (4) permanente Statusänderungen speichern
   if (permanentStatusChange)
      if (!SaveStatus())
         return(false);


   // (5) Anzeigen aktualisieren, ShowStatus() folgt nach SynchronizeStatus()
   SS.All();
   RedrawStartStop();
   RedrawOrders();

   /*
   debug("SynchronizeStatus() level="      + grid.level
                          +"  stops="      + grid.stops
                          +"  stopsPL="    + DoubleToStr(grid.stopsPL,     2)
                          +"  closedPL="   + DoubleToStr(grid.closedPL,    2)
                          +"  floatingPL=" + DoubleToStr(grid.floatingPL,  2)
                          +"  totalPL="    + DoubleToStr(grid.totalPL,     2)
                          +"  openRisk="   + DoubleToStr(grid.openRisk,    2)
                          +"  valueAtRisk="+ DoubleToStr(grid.valueAtRisk, 2));
   */
   return(IsNoError(last_error|catch("SynchronizeStatus(13)")));
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
      orders.swap        [i] = OrderSwap();                          // Swap und Commission werden hier schon für CalculateOpenRisk() benötigt
      orders.commission  [i] = OrderCommission();
      orders.openRisk    [i] = CalculateOpenRisk(i);
   }

   if (EQ(OrderStopLoss(), 0)) {
      if (!orders.clientSL[i]) {
         orders.stopLoss [i] = NormalizeDouble(ifDouble(orders.level[i]>0, grid.base.L, grid.base.S) + (orders.level[i]-Sign(orders.level[i]))*GridSize*Pips, Digits);
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
      orders.commission  [i] = OrderCommission(); grid.commission = OrderCommission(); SS.LotSize();
      orders.profit      [i] = OrderProfit();
   }

   // (2) lpPermanentChange aktualisieren
   if      (wasPending) lpPermanentChange = lpPermanentChange || isOpen || isClosed;
   else if (  isClosed) lpPermanentChange = true;
   else                 lpPermanentChange = lpPermanentChange || NE(lastSwap, OrderSwap());

   return(IsNoError(last_error|catch("Sync.UpdateOrder(3)")));
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
   if (type==EV_SEQUENCE_STOP) /*&&*/ if (time==0)
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
 * @param  int       direction         - Richtung des Grids, dessen Events verarbeitet werden sollen
 * @param  datetime &sequenceStopTime  - Variable, die die sequenceStopTime aufnimmt (falls die Stop-Daten fehlen)
 * @param  double   &sequenceStopPrice - Variable, die den sequenceStopPrice aufnimmt (falls die Stop-Daten fehlen)
 *
 * @return bool - Erfolgsstatus
 */
bool Sync.ProcessEvents(int direction, datetime &sequenceStopTime, double &sequenceStopPrice) {
   if (direction!=D_LONG) /*&&*/ if (direction!=D_SHORT) return(_false(catch("Sync.ProcessEvents(1)   invalid parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));

   string strDirection  = StringToLower(directionDescr[direction]);
   int    sizeOfTickets = ArraySize(orders.ticket);
   int    openLevels[]; ArrayResize(openLevels, 0);
   double events[][5];  ArrayResize(events,     0);
   bool   pendingOrder, openPosition, closedPosition, closedBySL;


   // (1) Breakeven-relevante Events zusammenstellen
   // (1.1) Sequenzstarts und -stops
   int sizeOfStarts = ArraySize(sequenceStart.event);
   for (int i=0; i < sizeOfStarts; i++) {
    //Sync.PushEvent(events, id, time, type, gridBase, index);
      Sync.PushEvent(events, sequenceStart.event[i], sequenceStart.time[i], EV_SEQUENCE_START, NULL, i);
      Sync.PushEvent(events, sequenceStop.event [i], sequenceStop.time [i], EV_SEQUENCE_STOP,  NULL, i);
   }

   // (1.2) GridBase-Änderungen
   int sizeOfGridBase;
   if (direction == D_LONG) sizeOfGridBase = ArraySize(grid.base.L.event);
   else                     sizeOfGridBase = ArraySize(grid.base.S.event);
   for (i=0; i < sizeOfGridBase; i++) {
      if (direction == D_LONG) Sync.PushEvent(events, grid.base.L.event[i], grid.base.L.time[i], EV_GRIDBASE_CHANGE, grid.base.L.value[i], i);
      else                     Sync.PushEvent(events, grid.base.S.event[i], grid.base.S.time[i], EV_GRIDBASE_CHANGE, grid.base.S.value[i], i);
   }

   // (1.3) Tickets
   for (i=0; i < sizeOfTickets; i++) {
      if (direction == D_LONG) { if (orders.level[i] < 0) continue; }
      else                     { if (orders.level[i] > 0) continue; }

      pendingOrder   = orders.type[i]  == OP_UNDEFINED;
      openPosition   = !pendingOrder   && orders.closeTime[i]==0;
      closedPosition = !pendingOrder   && !openPosition;
      closedBySL     =  closedPosition && orders.closedBySL[i];

      // nach offenen Levels darf keine geschlossene Position folgen
      if (closedPosition && !closedBySL)
         if (ArraySize(openLevels) != 0)                 return(_false(catch("Sync.ProcessEvents(2)   "+ strDirection +": illegal sequence status, both open (#?) and closed (#"+ orders.ticket[i] +") positions found", ERR_RUNTIME_ERROR)));

      if (!pendingOrder) {
         Sync.PushEvent(events, orders.openEvent[i], orders.openTime[i], EV_POSITION_OPEN, NULL, i);

         if (openPosition) {
            if (IntInArray(openLevels, orders.level[i])) return(_false(catch("Sync.ProcessEvents(3)   "+ strDirection +": duplicate order level "+ orders.level[i] +" of open position #"+ orders.ticket[i], ERR_RUNTIME_ERROR)));
            ArrayPushInt(openLevels, orders.level[i]);
            if (direction == D_LONG) grid.floatingPL.L = NormalizeDouble(grid.floatingPL.L + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
            else                     grid.floatingPL.S = NormalizeDouble(grid.floatingPL.S + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
         }
         else if (closedBySL) {
            Sync.PushEvent(events, orders.closeEvent[i], orders.closeTime[i], EV_POSITION_STOPOUT, NULL, i);
         }
         else /*(closed)*/ {
            Sync.PushEvent(events, orders.closeEvent[i], orders.closeTime[i], EV_POSITION_CLOSE, NULL, i);
         }
      }
      if (IsLastError()) return(false);
   }
   if (ArraySize(openLevels) != 0) {
      int min = openLevels[ArrayMinimum(openLevels)];
      int max = openLevels[ArrayMaximum(openLevels)];
      int maxLevel = Max(Abs(min), Abs(max));
      if (ArraySize(openLevels) != maxLevel) return(_false(catch("Sync.ProcessEvents(4)   "+ strDirection +": illegal sequence status, missing one or more open "+ ifString(direction==D_LONG, "long", "short") +" positions", ERR_RUNTIME_ERROR)));
      ArrayResize(openLevels, 0);
   }


   // (2) Breakeven-Verlauf und Laufzeitvariablen restaurieren
   double   gridBase, profitLoss, pipValue=PipValue(LotSize);
   datetime time, lastTime, nextTime;
   int      id, lastId, nextId, minute, lastMinute, type, lastType, nextType, index, nextIndex, iPositionMax, ticket, lastTicket, nextTicket, closedPositions, reopenedPositions;
   bool     recalcBreakeven, breakevenVisible;
   int      orderEvents[] = {EV_POSITION_OPEN, EV_POSITION_STOPOUT, EV_POSITION_CLOSE};
   int      sizeOfEvents = ArrayRange(events, 0);

   // (2.1) Events sortieren
   if (sizeOfEvents > 0) {
      ArraySort(events);
      int firstType = Round(events[0][2]);
      if (firstType != EV_SEQUENCE_START) return(_false(catch("Sync.ProcessEvents(5)   "+ strDirection +": illegal first break-even event "+ BreakevenEventToStr(firstType) +" (id="+ Round(events[0][0]) +"   time='"+ TimeToStr(Round(events[0][1]), TIME_FULL) +"')", ERR_RUNTIME_ERROR)));
   }

   for (i=0; i < sizeOfEvents; i++) {
      id       = Round(events[i][0]);
      time     = Round(events[i][1]);
      type     = Round(events[i][2]);
      gridBase =       events[i][3];
      index    = Round(events[i][4]);

      ticket     = 0; if (IntInArray(orderEvents, type)) { ticket = orders.ticket[index]; iPositionMax = Max(iPositionMax, index); }
      nextTicket = 0;
      if (i < sizeOfEvents-1) { nextId = Round(events[i+1][0]); nextTime = Round(events[i+1][1]); nextType = Round(events[i+1][2]); nextIndex = Round(events[i+1][4]); if (IntInArray(orderEvents, nextType)) nextTicket = orders.ticket[nextIndex]; }
      else                    { nextId = 0;                     nextTime = 0;                     nextType = 0;                                                                                               nextTicket = 0;                        }

      // (2.2) zwischen den Breakeven-Events liegende BarOpen(M1)-Events simulieren
      if (breakevenVisible) {
         lastMinute = lastTime/60; minute = time/60;
         while (lastMinute < minute-1) {                                // TODO: Wochenenden überspringen
            lastMinute++;
            if (!Grid.DrawBreakeven(lastMinute * MINUTES))
               return(false);
         }
      }

      // (2.3) Events auswerten
      // -- EV_SEQUENCE_START --------------
      if (type == EV_SEQUENCE_START) {
         if (i!=0 && status!=STATUS_STOPPED && status!=STATUS_STARTING)                                           return(_false(catch("Sync.ProcessEvents(6)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (status==STATUS_STARTING && reopenedPositions!=ifInt(direction==D_LONG, grid.level.L, -grid.level.S)) return(_false(catch("Sync.ProcessEvents(7)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") and before "+ BreakevenEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         reopenedPositions = 0;
         status            = STATUS_PROGRESSING;
         recalcBreakeven   = (i != 0);
         sequenceStart.event[index] = id;
      }
      // -- EV_GRIDBASE_CHANGE -------------
      else if (type == EV_GRIDBASE_CHANGE) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STOPPED)                                                return(_false(catch("Sync.ProcessEvents(8)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (direction == D_LONG) grid.base.L = gridBase;
         else                     grid.base.S = gridBase;
         if (status == STATUS_PROGRESSING) {
            if (ifInt(direction==D_LONG, grid.level.L, grid.level.S) != 0)                                        return(_false(catch("Sync.ProcessEvents(9)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
            recalcBreakeven = (grid.maxLevel.L-grid.maxLevel.S > 0);
         }
         else { // STATUS_STOPPED
            if (direction == D_LONG) grid.openRisk.L = 0;
            else                     grid.openRisk.S = 0;
            reopenedPositions = 0;
            status            = STATUS_STARTING;
            recalcBreakeven   = false;
         }
         if (direction == D_LONG) grid.base.L.event[index] = id;
         else                     grid.base.S.event[index] = id;
      }
      // -- EV_POSITION_OPEN ---------------
      else if (type == EV_POSITION_OPEN) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STARTING)                                               return(_false(catch("Sync.ProcessEvents(10)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (status == STATUS_PROGRESSING) {                            // nicht bei PositionReopen
            if (direction == D_LONG) { grid.level.L++; grid.maxLevel.L = Max(grid.level.L, grid.maxLevel.L); }
            else                     { grid.level.S--; grid.maxLevel.S = Min(grid.level.S, grid.maxLevel.S); }
         }
         else {
            reopenedPositions++;
         }
         if (direction == D_LONG) grid.openRisk.L = NormalizeDouble(grid.openRisk.L + orders.openRisk[index], 2);
         else                     grid.openRisk.S = NormalizeDouble(grid.openRisk.S + orders.openRisk[index], 2);
         recalcBreakeven = (status==STATUS_PROGRESSING);                // nicht bei PositionReopen
         orders.openEvent[index] = id;
      }
      // -- EV_POSITION_STOPOUT ------------
      else if (type == EV_POSITION_STOPOUT) {
         if (status != STATUS_PROGRESSING)                                                                        return(_false(catch("Sync.ProcessEvents(11)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (direction == D_LONG) {
            grid.level.L--;
            grid.stops.L++;
            grid.stopsPL.L  = NormalizeDouble(grid.stopsPL.L + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
            grid.openRisk.L = NormalizeDouble(grid.openRisk.L - orders.openRisk[index], 2);
         }
         else {
            grid.level.S++;
            grid.stops.S++;
            grid.stopsPL.S  = NormalizeDouble(grid.stopsPL.S + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
            grid.openRisk.S = NormalizeDouble(grid.openRisk.S - orders.openRisk[index], 2);
         }
         recalcBreakeven = true;
         orders.closeEvent[index] = id;
      }
      // -- EV_POSITION_CLOSE --------------
      else if (type == EV_POSITION_CLOSE) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STOPPING)                                               return(_false(catch("Sync.ProcessEvents(12)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (direction == D_LONG) grid.closedPL.L = NormalizeDouble(grid.closedPL.L + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
         else                     grid.closedPL.S = NormalizeDouble(grid.closedPL.S + orders.swap[index] + orders.commission[index] + orders.profit[index], 2);
         if (status == STATUS_PROGRESSING)
            closedPositions = 0;
         closedPositions++;
         status          = STATUS_STOPPING;
         recalcBreakeven = false;
         orders.closeEvent[index] = id;
      }
      // -- EV_SEQUENCE_STOP ---------------
      else if (type == EV_SEQUENCE_STOP) {
         if (status!=STATUS_PROGRESSING && status!=STATUS_STOPPING)                                               return(_false(catch("Sync.ProcessEvents(13)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (direction==D_LONG  && closedPositions!= grid.level.L)                                                return(_false(catch("Sync.ProcessEvents(14)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") and before "+ BreakevenEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         if (direction==D_SHORT && closedPositions!=-grid.level.S)                                                return(_false(catch("Sync.ProcessEvents(15)   "+ strDirection +": illegal break-even event "+ BreakevenEventToStr(type) +" ("+ id +", "+ ifString(ticket, "#"+ ticket +", ", "") +"time="+ time +", "+ TimeToStr(time, TIME_FULL) +") after "+ BreakevenEventToStr(lastType) +" ("+ lastId +", "+ ifString(lastTicket, "#"+ lastTicket +", ", "") +"time="+ lastTime +", "+ TimeToStr(lastTime, TIME_FULL) +") and before "+ BreakevenEventToStr(nextType) +" ("+ nextId +", "+ ifString(nextTicket, "#"+ nextTicket +", ", "") +"time="+ nextTime +", "+ TimeToStr(nextTime, TIME_FULL) +") in "+ StatusToStr(status) +" at level "+ ifInt(direction==D_LONG, grid.level.L, grid.level.S), ERR_RUNTIME_ERROR)));
         closedPositions = 0;
         status          = STATUS_STOPPED;
         recalcBreakeven = false;
         sequenceStop.event[index] = id;
      }
      // -----------------------------------
      if (direction == D_LONG) grid.valueAtRisk.L = NormalizeDouble(grid.stopsPL.L + grid.openRisk.L, 2);
      else                     grid.valueAtRisk.S = NormalizeDouble(grid.stopsPL.S + grid.openRisk.S, 2);
      //debug("Sync.ProcessEvents()   "+ strDirection +": "+ id +"  "+ ifString(ticket, "#"+ ticket, "") +"  "+ TimeToStr(time, TIME_FULL) +" ("+ time +")  "+ StringRightPad(StatusToStr(status), 20, " ") + StringRightPad(BreakevenEventToStr(type), 19, " ") +"  grid.level="+ ifInt(direction==D_LONG, grid.level.L, grid.level.S) +"  index="+ index +"  closed="+ closedPositions +"  reopened="+ reopenedPositions +"  recalcBE="+recalcBreakeven +"  visibleBE="+ breakevenVisible);

      // (2.4) ggf. Breakeven neuberechnen und zeichnen
      if (recalcBreakeven) {
         if (!Grid.CalculateBreakeven(time, iPositionMax))
            return(false);
         breakevenVisible = true;
      }
      else if (breakevenVisible) {
         if (!Grid.DrawBreakeven(time))
            return(false);
         breakevenVisible = (status != STATUS_STOPPED);
      }

      lastId     = id;
      lastTime   = time;
      lastType   = type;
      lastTicket = ticket;
   }
   lastEventId = id;


   // (4) Wurde die Sequenz außerhalb gestoppt, fehlende Stop-Daten ermitteln
   if (status == STATUS_STOPPING) {
      if (direction==D_LONG  && closedPositions!= grid.level.L) return(_false(catch("Sync.ProcessEvents(16)   "+ strDirection +": unexpected number of closed positions in "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));
      if (direction==D_SHORT && closedPositions!=-grid.level.S) return(_false(catch("Sync.ProcessEvents(17)   "+ strDirection +": unexpected number of closed positions in "+ StatusDescription(status) +" sequence", ERR_RUNTIME_ERROR)));

      // (4.1) Stopdaten ermitteln
      int    level = ifInt(direction==D_LONG, grid.level.L, -grid.level.S);
      double stopPrice;
      for (i=sizeOfEvents-level; i < sizeOfEvents; i++) {
         time  = Round(events[i][1]);
         type  = Round(events[i][2]);
         index = Round(events[i][4]);
         if (type != EV_POSITION_CLOSE)
            return(_false(catch("Sync.ProcessEvents(18)   "+ strDirection +": unexpected "+ BreakevenEventToStr(type) +" at index "+ i, ERR_RUNTIME_ERROR)));
         stopPrice += orders.closePrice[index];
      }
      stopPrice /= level;

      // (4.2) Stopdaten zurückgeben
      sequenceStopTime  = time;
      sequenceStopPrice = NormalizeDouble(stopPrice, Digits);
   }

   ArrayResize(events,      0);
   ArrayResize(orderEvents, 0);
   return(IsNoError(last_error|catch("Sync.ProcessEvents(19) "+ strDirection)));
}


/**
 * Ermittelt das Verlustrisiko der angegebenen offenen Position, inkl. Slippage.
 * Eine geschlossene Position hat ggf. einen realisierten Verlust, sie trägt kein offenes Risiko mehr.
 *
 * @param  int i - Index der Position in den Grid-Arrays
 *
 * @return double - Verlustrisiko
 */
double CalculateOpenRisk(int i) {
   if (i < 0 || i >= ArraySize(orders.ticket)) return(_NULL(catch("CalculateOpenRisk(1)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double realized;

   for (int n=i-1; n >= 0; n--) {
      if (orders.level[n] != orders.level[i])                        // Order muß zum Level gehören
         continue;
      if (orders.type[n] == OP_UNDEFINED)                            // Order darf nicht pending sein
         continue;
      if (orders.closedBySL[n])                                      // Abbruch vor erster durch StopLoss geschlossenen Position desselben Levels (wir iterieren rückwärts)
         break;

      realized += orders.swap[n] + orders.commission[n] + orders.profit[n];
   }

   double stopLossValue = -MathAbs(orders.openPrice[i]-orders.stopLoss[i])/Pips * PipValue(LotSize);
   double openRisk      =  realized + stopLossValue + orders.swap[i] + orders.commission[i];
   return(NormalizeDouble(openRisk, 2));
}


/**
 * Berechnet den durchschnittlichen OpenPrice einer Gesamtposition im angegebenen Level.
 * Aufruf nur in ProfitToDistance()
 *
 * @param  int      level              - Level
 * @param  bool     checkOpenPositions - ob die Open-Preise schon offener Positionen berücksichtigt werden sollen (um aufgetretene Slippage mit einzukalkulieren)
 * @param  datetime time               - wenn checkOpenPositions=TRUE: Zeitpunkt innerhalb der Sequenz (nur zu diesem Zeitpunkt offene Positionen werden berücksichtigt)
 * @param  int      i                  - wenn checkOpenPositions=TRUE: Orderindex innerhalb der Gridarrays (offene Positionen bis zu diesem Index werden berücksichtigt)
 * @param  double   lpOpenRisk         - wenn checkOpenPositions=TRUE: Zeiger auf Variable, die das Risiko derjeniger offenen Position aufnimmt, deren Stoploss als
 *                                       erster getriggert werden würde
 *
 * @return double - Durchschnittspreis oder NULL, falls ein Fehler auftrat
 */
double CalculateAverageOpenPrice(int level, bool checkOpenPositions, datetime time, int i, double &lpOpenRisk) {

   // vorläufig deaktiviert, da Verwendung nur in ProfitToDistance()
   return(NULL);

   //if (level == 0)
   //   return(_NULL(catch("CalculateAverageOpenPrice(1)   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   //int    foundLevels, absLevel=Abs(level), absOrdersLevel, lastOpenPosition=-1;
   //double sumOpenPrices;


   //// (1) ggf. offene Positionen berücksichtigen
   //if (checkOpenPositions) {
   //   if (i < 0 || i >= ArraySize(orders.ticket))
   //      return(_NULL(catch("CalculateAverageOpenPrice(1)   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));

   //   for (; i >= 0; i--) {
   //      if (orders.type[i] == OP_UNDEFINED)                               // Order darf nicht pending sein
   //         continue;
   //      if (orders.closeTime[i]!=0 && orders.closeTime[i] <= time)        // Position darf zum Zeitpunkt 'time' nicht geschlossen sein
   //         continue;
   //      if (Sign(level) != Sign(orders.level[i]))                         // offene Position: Grid-Directions müssen übereinstimmen
   //         return(_NULL(catch("CalculateAverageOpenPrice(2, level="+level+", cop="+ checkOpenPositions +", time="+ ifString(time, "'"+ TimeToStr(time, TIME_FULL) +"'", 0) +", i="+ i +", &lpRisk)   parameter level/orders.level["+ i +"] mis-match: "+ level +"/"+ orders.level[i], ERR_INVALID_FUNCTION_PARAMVALUE)));
   //      absOrdersLevel = Abs(orders.level[i]);

   //      if (lastOpenPosition != -1)
   //         if (absOrdersLevel != Abs(orders.level[lastOpenPosition])-1)
   //            return(_NULL(catch("CalculateAverageOpenPrice(3, level="+level+", cop="+ checkOpenPositions +", time="+ ifString(time, "'"+ TimeToStr(time, TIME_FULL) +"'", 0) +", i="+ i +", &lpRisk)   open positions mis-match (found position at orders.level["+ i +"] = "+ orders.level[i] +", next position at orders.level["+ lastOpenPosition +"] = "+ orders.level[lastOpenPosition] +")", ERR_INVALID_FUNCTION_PARAMVALUE)));
   //      lastOpenPosition = i;

   //      if (absOrdersLevel <= absLevel) {                                 // Positionen oberhalb des angegebenen Levels werden ignoriert
   //         sumOpenPrices += orders.openPrice[i];
   //         if (foundLevels == 0)
   //            lpOpenRisk = orders.openRisk[i];
   //         foundLevels++;
   //      }
   //      if (absOrdersLevel == 1)
   //         break;
   //   }
   //   if (lastOpenPosition != -1)
   //      if (Abs(orders.level[lastOpenPosition]) != 1)
   //         return(_NULL(catch("CalculateAverageOpenPrice(4)   open position at level "+ Sign(level) +" missing", ERR_INVALID_FUNCTION_PARAMVALUE)));
   //}


   //// (2) für fehlende Positionen den Soll-OpenPrice verwenden
   //if (foundLevels < absLevel) {
   //   for (i=absLevel; i > foundLevels; i--) {
   //      sumOpenPrices += grid.base + i*Sign(level) * GridSize * Pips;
   //   }
   //   if (foundLevels == 0)
   //      lpOpenRisk = 0;
   //}

   ////debug("CalculateAverageOpenPrice(0.2)   level="+ level +"   sum="+ NumberToStr(sumOpenPrices, ".+"));
   //return(sumOpenPrices / absLevel);
}


/**
 * Zeichnet die Start-/Stop-Marker der Sequenz neu.
 */
void RedrawStartStop() {
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
      return;

   static color last.MarkerColor = DodgerBlue;
   if (Breakeven.Color != CLR_NONE)
      last.MarkerColor = Breakeven.Color;

   datetime time;
   double   price;
   double   profit;
   string   label;

   int starts = ArraySize(sequenceStart.event);


   // (1) Start-Marker
   for (int i=0; i <= starts; i++) {
      if (starts == 0) {
         time   = instanceStartTime;
         price  = instanceStartPrice;
         profit = 0;
      }
      else if (i == starts) {
         break;
      }
      else {
         time   = sequenceStart.time  [i];
         price  = sequenceStart.price [i];
         profit = sequenceStart.profit[i];
      }

      label = StringConcatenate("SR.", sequenceId, ".start.", i+1);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);

      if (startStopDisplayMode != SDM_NONE) {
         ObjectCreate (label, OBJ_ARROW, 0, time, price);
         ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
         ObjectSet    (label, OBJPROP_BACK,      false               );
         ObjectSet    (label, OBJPROP_COLOR,     last.MarkerColor    );
         ObjectSetText(label, StringConcatenate("Profit: ", DoubleToStr(profit, 2)));
      }
   }


   // (2) Stop-Marker
   for (i=0; i < starts; i++) {
      if (sequenceStop.time[i] > 0) {
         time   = sequenceStop.time [i];
         price  = sequenceStop.price[i];
         profit = sequenceStop.profit[i];

         label = StringConcatenate("SR.", sequenceId, ".stop.", i+1);
         if (ObjectFind(label) == 0)
            ObjectDelete(label);

         if (startStopDisplayMode != SDM_NONE) {
            ObjectCreate (label, OBJ_ARROW, 0, time, price);
            ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
            ObjectSet    (label, OBJPROP_BACK,      false               );
            ObjectSet    (label, OBJPROP_COLOR,     last.MarkerColor    );
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
   if (IsTesting()) /*&&*/ if (!IsVisualMode())
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
   if (i == -1) {                                                          // #define SDM_MARKER      einfache Markierung
      startStopDisplayMode = SDM_PRICE;           // default               // #define SDM_PRICE       Markierung mit Preisangabe
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
 * Wechselt den Modus der Breakeven-Anzeige.
 *
 * @return int - Fehlerstatus
 */
int ToggleBreakevenDisplayMode() {
   if (breakeven.Width == 0) breakeven.Width = 1;
   else                      breakeven.Width = 0;

   RecolorBreakeven();
   return(catch("ToggleBreakevenDisplayMode()"));
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
 * @param  int i - Index des Ordertickets in den Datenarrays
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.OrderSent(int i) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode()) return(true);
   if (i < 0 || i >= ArraySize(orders.ticket))  return(_false(catch("ChartMarker.OrderSent()   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
      return(_false(SetLastError(stdlib_PeekLastError())));
   return(true);
}


/**
 * Korrigiert die vom Terminal beim Ausführen einer Pending-Order gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Index des Ordertickets in den Datenarrays
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.OrderFilled(int i) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode()) return(true);
   if (i < 0 || i >= ArraySize(orders.ticket))  return(_false(catch("ChartMarker.OrderFilled()   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
      return(_false(SetLastError(stdlib_PeekLastError())));
   return(true);
}


/**
 * Korrigiert die vom Terminal beim Schließen einer Position gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int i - Index des Ordertickets in den Datenarrays
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.PositionClosed(int i) {
   if (IsTesting()) /*&&*/ if (!IsVisualMode()) return(true);
   if (i < 0 || i >= ArraySize(orders.ticket))  return(_false(catch("ChartMarker.PositionClosed()   illegal parameter i = "+ i, ERR_INVALID_FUNCTION_PARAMVALUE)));
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   color markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if ( orders.closedBySL[i]) /*&&*/ if (orderDisplayMode!=ODM_PYRAMID) markerColor = CLR_CLOSE;
      if (!orders.closedBySL[i]) /*&&*/ if (orderDisplayMode>=ODM_PYRAMID) markerColor = CLR_CLOSE;
   }

   if (!ChartMarker.PositionClosed_B(orders.ticket[i], Digits, markerColor, orders.type[i], LotSize, Symbol(), orders.openTime[i], orders.openPrice[i], orders.closeTime[i], orders.closePrice[i]))
      return(_false(SetLastError(stdlib_PeekLastError())));
   return(true);
}


/**
 * Ob die Sequenz im Tester erzeugt wurde, also ein Test ist. Der Aufruf dieser Funktion in Online-Charts mit einer im Tester
 * erzeugten Sequenz gibt daher ebenfalls TRUE zurück.
 *
 * @return bool
 */
bool IsTest() {
   return(test || IsTesting());
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
      ArrayResize(orders.openRisk,     size);
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
         ArrayInitialize(orders.openRisk,                0);
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

   catch("ResizeArrays()");
   return(size);

   // Compilerwarnungen unterdrücken
   int    iNull;
   double dNull, dNulls[];
   BreakevenEventToStr(NULL);
   CalculateAverageOpenPrice(NULL, NULL, NULL, NULL, dNull);
   DistanceToProfit(NULL);
   GetFullStatusDirectory();
   GetFullStatusFileName();
   GetMqlStatusDirectory();
   GetMqlStatusFileName();
   GridDirectionToStr(NULL);
   OrderDisplayModeToStr(NULL);
   ProfitToDistance(NULL, NULL, NULL, NULL, NULL);
   StatusToStr(NULL);
   Sync.ProcessEvents(NULL, iNull, dNull);
   Sync.PushEvent(dNulls, NULL, NULL, NULL, NULL, NULL);
   UploadStatus(NULL, NULL, NULL, NULL);
}


/**
 * Gibt die lesbare Konstante eines Status-Codes zurück.
 *
 * @param  int status - Status-Code
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case STATUS_UNINITIALIZED: return("STATUS_UNINITIALIZED");
      case STATUS_WAITING      : return("STATUS_WAITING"      );
      case STATUS_STARTING     : return("STATUS_STARTING"     );
      case STATUS_PROGRESSING  : return("STATUS_PROGRESSING"  );
      case STATUS_STOPPING     : return("STATUS_STOPPING"     );
      case STATUS_STOPPED      : return("STATUS_STOPPED"      );
      case STATUS_DISABLED     : return("STATUS_DISABLED"     );
   }
   return(_empty(catch("StatusToStr()   invalid parameter status = "+ status, ERR_INVALID_FUNCTION_PARAMVALUE)));
}


/**
 * Gibt die Beschreibung eines Status-Codes zurück.
 *
 * @param  int status - Status-Code
 *
 * @return string
 */
string StatusDescription(int status) {
   switch (status) {
      case STATUS_UNINITIALIZED: return("not initialized");
      case STATUS_WAITING      : return("waiting"        );
      case STATUS_STARTING     : return("starting"       );
      case STATUS_PROGRESSING  : return("progressing"    );
      case STATUS_STOPPING     : return("stopping"       );
      case STATUS_STOPPED      : return("stopped"        );
      case STATUS_DISABLED     : return("disabled"       );
   }
   return(_empty(catch("StatusDescription()   invalid parameter status = "+ status, ERR_INVALID_FUNCTION_PARAMVALUE)));
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
      case D_BIDIR: return("D_BIDIR");
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
 * @param  bool collectTicks - TRUE:  nur komplette Bars werden geschrieben (Ticks einer Bar werden gesammelt und zwischengespeichert)
 *                             FALSE: jeder einzelne Tick wird geschrieben
 *
 * @return bool - Erfolgsstatus
 */
bool RecordEquity(bool collectTicks) {
   /* Speedtest EUR/USD 04.10.2012, M15, long, GridSize 18
   +-------------------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   |                                     |     alt      | optimiert | FindBar opt. | Arrays opt. |  Read opt.  |  Write opt.  |  Valid. opt. |  in Library  |
   +-------------------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   | Laptop v419 - ohne RecordEquity()   | 17.613 t/sec |           |              |             |             |              |              |              |
   | Laptop v225 - Schreiben jedes Ticks |  6.426 t/sec |           |              |             |             |              |              |              |
   | Laptop v419 - Schreiben jedes Ticks |  5.871 t/sec | 6.877 t/s |   7.381 t/s  |  7.870 t/s  |  9.097 t/s  |   9.966 t/s  |  11.332 t/s  |              |
   | Laptop v419 - mit Tick-Collector    |              |           |              |             |             |              |  15.486 t/s  |  14.286 t/s  |
   +-------------------------------------+--------------+-----------+--------------+-------------+-------------+--------------+--------------+--------------+
   */
   if (!IsTesting())
      return(true);

   if (ticks == 0)
      time1 = GetTickCount();
   ticks++;


   // (1) Filehandle holen
   static int hFile, hFileM1, hFileM5, hFileM15, hFileM30, hFileH1, hFileH4, hFileD1, digits=2;
   if (hFile == 0) {
      string symbol      = StringConcatenate(ifString(IsTesting(), "_", ""), "SR", sequenceId);
      string description = StringConcatenate("Equity SR.", sequenceId);
      hFile = History.OpenFile(symbol, description, digits, PERIOD_M15, FILE_READ|FILE_WRITE);
      if (hFile <= 0)
         return(false);
   }

   // (2) Daten zusammenstellen
   datetime time  = MarketInfo(Symbol(), MODE_TIME);
   double   value = sequenceStartEquity + grid.totalPL;


   static datetime barTime, nextBarTime, period;
   bool   barExists [1];
   int    bar, iNull[1];
   double data[5];


   // (3) Ticks sammeln: nur komplette Bars schreiben
   if (collectTicks) {
      if (time >= nextBarTime) {
         bar = History.FindBar(hFile, time, barExists);                       // bei bereits gesammelten Ticks (nextBarTime != 0) immer 1 zu klein, da die noch ungeschriebene
                                                                              // letzte Bar für FindBar() nicht sichtbar ist
         if (nextBarTime == 0) {
            if (barExists[0]) {                                               // erste Initialisierung
               if (!History.ReadBar(hFile, bar, iNull, data))                 // ggf. vorhandene Bar einlesen (von vorherigem Abbruch)
                  return(false);
               data[BAR_H] = MathMax(data[BAR_H], value);                     // Open bleibt unverändert
               data[BAR_L] = MathMin(data[BAR_L], value);
               data[BAR_C] = value;
               data[BAR_V]++;
            }
            else {
               data[BAR_O] = value;
               data[BAR_H] = value;
               data[BAR_L] = value;
               data[BAR_C] = value;
               data[BAR_V] = 1;
            }
            period = History.FilePeriod(hFile)*MINUTES;
         }
         else {                                                               // letzte Bar komplett, muß an den Offset 'bar' geschrieben werden (nicht bar-1),
            if (!History.WriteBar(hFile, bar, barTime, data, HST_FILL_GAPS))  // da die ungeschriebene letzte Bar für FindBar() nicht sichtbar ist
               return(false);
            data[BAR_O] = value;                                              // Re-Initialisierung
            data[BAR_H] = value;
            data[BAR_L] = value;
            data[BAR_C] = value;
            data[BAR_V] = 1;
         }
         barTime     = time - time % period;
         nextBarTime = barTime + period;
      }
      else {
         data[BAR_H] = MathMax(data[BAR_H], value);                           // Open bleibt unverändert
         data[BAR_L] = MathMin(data[BAR_L], value);
         data[BAR_C] = value;
         data[BAR_V]++;
      }
      return(true);
   }


   // (4) Ticks nicht sammeln: keine ungeschriebenen Ticks => nur den aktuellen Tick schreiben
   if (barTime == 0)
      return(History.AddTick(hFile, time, value, NULL));


   // (5) ungeschriebene und aktuellen Tick schreiben
   bar = History.FindBar(hFile, barTime, barExists);

   if (time-time%period == barTime) {                                      // aktueller Tick gehört zur ungeschriebenen Bar und wird integriert
      data[BAR_H] = MathMax(data[BAR_H], value);                           // Open bleibt unverändert
      data[BAR_L] = MathMin(data[BAR_L], value);
      data[BAR_C] = value;
      data[BAR_V]++;
      if (!History.WriteBar(hFile, bar, barTime, data, HST_FILL_GAPS))
         return(false);
   }
   else if (History.WriteBar(hFile, bar, barTime, data, HST_FILL_GAPS)) {  // ungeschriebene Bar und aktueller Tick werden getrennt geschrieben
      if (!History.AddTick(hFile, time, value, NULL)) return(false);
   }
   else return(false);

   barTime     = 0;                                                        // für Wechsel von collectTicks (TRUE|FALSE) immer zurücksetzen
   nextBarTime = 0;
   return(true);
}


/**
 * @return int - Fehlerstatus
 */
int onDeinit() {
   if (time1 != 0) {
      double secs = (GetTickCount()-time1)/1000.0;
      debug("onDeinit()   writing of "+ ticks +" ticks took "+ DoubleToStr(secs, 3) +" secs ("+ Round(ticks/secs) +" ticks/sec)");
   }
   return(NO_ERROR);
}


/**
 * @return int - Fehlerstatus
 */
int afterDeinit() {
   CloseFiles(false);
   return(NO_ERROR);
}

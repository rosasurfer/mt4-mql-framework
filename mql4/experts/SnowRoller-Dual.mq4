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

extern            int    GridSize             = 20;
extern            double LotSize              = 0.1;
extern            string StartConditions      = "@trend(ALMA:3.5xD1)";
extern            string StopConditions       = "@profit(500)";

       /*sticky*/ int    startStopDisplayMode = SDM_PRICE;           // Sticky-Variablen werden im Chart zwischengespeichert, sie überleben dort
       /*sticky*/ int    orderDisplayMode     = ODM_NONE;            // Terminal-Restart, Profilwechsel und Recompilation.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int      last.GridSize;                                              // Input-Parameter sind nicht statisch. Extern geladene Parameter werden bei REASON_CHARTCHANGE
double   last.LotSize;                                               // mit den Default-Werten überschrieben. Um dies zu verhindern und um geänderte Parameter mit
string   last.StartConditions = "";                                  // alten Werten vergleichen zu können, werden sie in deinit() in last.* zwischengespeichert und
string   last.StopConditions  = "";                                  // in init() daraus restauriert.

int      instance.id;                                                // eine Instanz (mit eigener Statusdatei) verwaltet mehrere unabhängige Sequenzen
bool     instance.isTest;                                            // ob die Instanz eine Testinstanz ist und nur Testsequenzen verwaltet (im Tester oder im Online-Chart)

// -------------------------------------------------------
bool     start.trend.condition;
string   start.trend.condition.txt;
double   start.trend.periods;
int      start.trend.timeframe, start.trend.timeframeFlag;           // maximal PERIOD_H1
string   start.trend.method;
int      start.trend.lag;

// -------------------------------------------------------
bool     stop.profitAbs.condition;
string   stop.profitAbs.condition.txt;
double   stop.profitAbs.value;

// -------------------------------------------------------
datetime weekend.stop.condition   = D'1970.01.01 23:05';             // StopSequence()-Zeitpunkt vor Wochenend-Pause (Freitags abend)
datetime weekend.stop.time;

datetime weekend.resume.condition = D'1970.01.01 01:10';             // spätester ResumeSequence()-Zeitpunkt nach Wochenend-Pause (Montags morgen)
datetime weekend.resume.time;

// -------------------------------------------------------
int      sequence.id           [2];
bool     sequence.isTest       [2];
int      sequence.direction    [2];
int      sequence.gridSize     [2];
double   sequence.lotSize      [2];
int      sequence.status       [2];
string   sequence.statusFile   [2][2];                               // [0]=>Verzeichnisname relativ zu ".\files\", [1]=>Dateiname

int      sequence.level        [2];                                  // aktueller Gridlevel
int      sequence.maxLevel     [2];                                  // maximal erreichter Gridlevel
double   sequence.startEquity  [2];                                  // Equity bei Sequenzstart
bool     sequence.weStop.active[2];                                  // Weekend-Stop aktiv? (unterscheidet vorübergehend von dauerhaft gestoppter Sequenz)

int      sequence.stops        [2];                                  // Anzahl der bisher getriggerten Stops
double   sequence.stopsPL      [2];                                  // kumulierter P/L aller bisher ausgestoppten Positionen
double   sequence.closedPL     [2];                                  // kumulierter P/L aller bisher bei Sequencestop geschlossenen Positionen
double   sequence.floatingPL   [2];                                  // kumulierter P/L aller aktuell offenen Positionen
double   sequence.totalPL      [2];                                  // aktueller Gesamt-P/L der Sequenz: stopsPL + closedPL + floatingPL
double   sequence.maxProfit    [2];                                  // maximaler bisheriger Gesamt-Profit der Sequenz   (>= 0)
double   sequence.maxDrawdown  [2];                                  // maximaler bisheriger Gesamt-Drawdown der Sequenz (<= 0)
double   sequence.commission   [2];                                  // aktueller Commission-Betrag je Level

// -------------------------------------------------------
int      sequence.ss.events    [2][3];                               // {I_FROM, I_TO, I_SIZE}: Start- und Stopdaten sind synchron

int      sequence.start.event   [];                                  // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime sequence.start.time    [];
double   sequence.start.price   [];
double   sequence.start.profit  [];

int      sequence.stop.event    [];                                  // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime sequence.stop.time     [];
double   sequence.stop.price    [];
double   sequence.stop.profit   [];

// -------------------------------------------------------
int      gridbase.events       [2][3];                               // {I_FROM, I_TO, I_SIZE}

int      gridbase.event        [];                                   // Gridbasis-Daten
datetime gridbase.time         [];
double   gridbase.value        [];
double   gridbase              [2];                                  // aktuelle Gridbasis

// -------------------------------------------------------
int      orders                [2][3];                               // {I_FROM, I_TO, I_SIZE}
int      orders.ticket         [];
int      orders.level          [];                                   // Gridlevel der Order
double   orders.gridBase       [];                                   // Gridbasis der Order

int      orders.pendingType    [];                                   // Pending-Orderdaten (falls zutreffend)
datetime orders.pendingTime    [];                                   // Zeitpunkt von OrderOpen() bzw. letztem OrderModify()
double   orders.pendingPrice   [];

int      orders.type           [];
int      orders.openEvent      [];
datetime orders.openTime       [];
double   orders.openPrice      [];
int      orders.closeEvent     [];
datetime orders.closeTime      [];
double   orders.closePrice     [];
double   orders.stopLoss       [];
bool     orders.clientSL       [];                                   // client- oder server-seitiger StopLoss
bool     orders.closedBySL     [];

double   orders.swap           [];
double   orders.commission     [];
double   orders.profit         [];

// -------------------------------------------------------
int      ignore.pending        [2][3];                               // {I_FROM, I_TO, I_SIZE}
int      ignore.pendingOrders  [];                                   // orphaned tickets to ignore

int      ignore.open           [2][3];
int      ignore.openPositions  [];

int      ignore.closed         [2][3];
int      ignore.closedPositions[];

// -------------------------------------------------------
string   str.instance.lotSize;                                       // Zwischenspeicher für schnelleres ShowStatus(): gesamt
string   str.instance.totalPL;
string   str.instance.plStats;

string   str.sequence.id         [2];                                // Zwischenspeicher für schnelleres ShowStatus(): je Sequenz
string   str.sequence.stops      [2];
string   str.sequence.stopsPL    [2];
string   str.sequence.totalPL    [2];
string   str.sequence.maxProfit  [2];
string   str.sequence.maxDrawdown[2];
string   str.sequence.plStats    [2];
// -------------------------------------------------------


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
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool Strategy(int hSeq) {
   if (__STATUS_ERROR)
      return(false);

   bool changes;                                                     // Gridbasis- oder -leveländerung
   int  stops[];                                                     // getriggerte client-seitige Stops

   // (1) Strategie wartet auf Startsignal ...
   if (sequence.status[hSeq] == STATUS_UNINITIALIZED) {
      if (IsStartSignal(hSeq))     StartSequence(hSeq);
   }

   // (2) ... oder auf ResumeSignal ...
   else if (sequence.status[hSeq] == STATUS_STOPPED) {
      if (IsResumeSignal(hSeq))    ResumeSequence(hSeq);
   }

   // (3) ... oder läuft.
   else if (UpdateStatus(hSeq, changes, stops)) {
      if (IsStopSignal(hSeq))      StopSequence(hSeq);
      else {
         if (ArraySize(stops) > 0) ProcessClientStops(stops);
         if (changes)              UpdatePendingOrders(hSeq);
      }
   }
   return(!__STATUS_ERROR);
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
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool
 */
bool IsResumeSignal(int hSeq) {
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
 * @param  int  hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStopSignal(int hSeq) {
   if (__STATUS_ERROR || sequence.status[hSeq]!=STATUS_PROGRESSING)
      return(false);

   // (1) User-definierte StopConditions prüfen
   if (stop.conditions.triggered) {
      warn("IsStopSignal(1)   repeated triggered state call");    // Einmal getriggert, immer getriggert. Falls der Stop beim aktuellen Tick nicht ausgeführt
      return(true);                                               // werden konnte, könnten die Bedingungen beim nächsten Tick schon nicht mehr erfüllt sein.
   }

   // -- stop.profitAbs: ---------------------------------------------------------------------------------------------
   if (stop.profitAbs.condition) {
      if (GE(sequence.totalPL[hSeq], stop.profitAbs.value)) {
         if (__LOG) log(StringConcatenate("IsStopSignal()   sequence "+ sequence.id[hSeq] +" stop condition \"", stop.profitAbs.condition.txt, "\" met"));
         stop.conditions.triggered = true;
         return(true);
      }
   }

   // (2) zusätzlich interne WeekendStop-Bedingung prüfen
   return(IsWeekendStopSignal());
}


/**
 * Startet eine neue Trade-Sequenz.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence(int hSeq) {
   if (__STATUS_ERROR)      return(false);
   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("StartSequence()", "Do you really want to start a new "+ StringToLower(directionDescr[hSeq]) +" sequence now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));
   if (!InitSequence(hSeq)) return(false);


   sequence.status[hSeq] = STATUS_STARTING;                          // TODO: Logeintrag in globalem und Sequenz-Log
   if (__LOG) log("StartSequence()   starting "+ StringToLower(directionDescr[sequence.direction[hSeq]]) +" sequence "+ sequence.id[hSeq]);


   // (1) Startvariablen setzen
   sequence.startEquity[hSeq] = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   datetime startTime   = TimeCurrent();
   double   startPrice  = ifDouble(hSeq==D_SHORT, Bid, Ask);
   double   startProfit = 0;
   AddStartEvent(hSeq, startTime, startPrice, startProfit);


   // (2) Gridbasis setzen (zeitlich nach startTime)
   GridBase.Reset(hSeq, startTime, startPrice);
   sequence.status[hSeq] = STATUS_PROGRESSING;


   // (3) Stop-Orders in den Markt legen
   if (!UpdatePendingOrders(hSeq))
      return(false);


   // (4) Weekend-Stop aktualisieren
   UpdateWeekendStop(hSeq);
   RedrawStartStop(hSeq);

   if (__LOG) log("StartSequence()   sequence started at "+ NumberToStr(startPrice, PriceFormat) + ifString(sequence.level[hSeq], " and level "+ sequence.level[hSeq], ""));
   return(!last_error|catch("StartSequence()"));
}


/**
 * Zeichnet die Start-/Stop-Marker der Sequenz neu.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void RedrawStartStop(int hSeq) {
   if (!IsChart)
      return;

   static color markerColor = DodgerBlue;

   int from = sequence.ss.events[hSeq][I_FROM];
   int to   = sequence.ss.events[hSeq][I_TO  ];
   int size = sequence.ss.events[hSeq][I_SIZE];

   datetime time;
   double   price;
   double   profit;
   string   label;


   if (size > 0) {
      // (1) Start-Marker
      for (int i=from; i <= to; i++) {
         time   = sequence.start.time  [i];
         price  = sequence.start.price [i];
         profit = sequence.start.profit[i];

         label = StringConcatenate("SR.", sequence.id[hSeq], ".start.", i-from+1);
         if (ObjectFind(label) == 0)
            ObjectDelete(label);

         if (startStopDisplayMode != SDM_NONE) {
            ObjectCreate (label, OBJ_ARROW, 0, time, price);
            ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
            ObjectSet    (label, OBJPROP_BACK,      false               );
            ObjectSet    (label, OBJPROP_COLOR,     markerColor         );
            ObjectSetText(label, StringConcatenate("Profit: ", DoubleToStr(profit, 2)));
         }
      }

      // (2) Stop-Marker
      for (i=from; i <= to; i++) {
         time   = sequence.stop.time  [i];
         price  = sequence.stop.price [i];
         profit = sequence.stop.profit[i];
         if (time > 0) {
            label = StringConcatenate("SR.", sequence.id[hSeq], ".stop.", i-from+1);
            if (ObjectFind(label) == 0)
               ObjectDelete(label);

            if (startStopDisplayMode != SDM_NONE) {
               ObjectCreate (label, OBJ_ARROW, 0, time, price);
               ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
               ObjectSet    (label, OBJPROP_BACK,      false               );
               ObjectSet    (label, OBJPROP_COLOR,     markerColor         );
               ObjectSetText(label, StringConcatenate("Profit: ", DoubleToStr(profit, 2)));
            }
         }
      }
   }
   catch("RedrawStartStop()");
}


/**
 * Aktualisiert die Stopbedingung für die nächste Wochenend-Pause.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void UpdateWeekendStop(int hSeq) {
   sequence.weStop.active[hSeq] = false;

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
 * Löscht alle gespeicherten Änderungen der Gridbasis einer Sequenz und initialisiert sie mit dem angegebenen Wert.
 *
 * @param  int      hSeq  - Sequenz: D_LONG | D_SHORT
 * @param  datetime time  - Zeitpunkt
 * @param  double   value - neue Gridbasis
 *
 * @return double - neue Gridbasis (for chaining) oder 0, falls ein Fehler auftrat
 */
double GridBase.Reset(int hSeq, datetime time, double value) {
   if (__STATUS_ERROR)
      return(0);

   int from=gridbase.events[hSeq][I_FROM], size=gridbase.events[hSeq][I_SIZE];

   if (size > 0) {
      for (int i=0; i < 2; i++) {                                    // Indizes "hinter" der zurückzusetzenden Sequenz anpassen
         if (gridbase.events[i][I_FROM] > from) {
            gridbase.events[i][I_FROM] -= size;
            gridbase.events[i][I_TO  ] -= size;                      // I_SIZE unverändert
         }
      }
      gridbase.events[hSeq][I_FROM] = 0;                             // Indizes der zurückzusetzenden Sequenz anpassen
      gridbase.events[hSeq][I_TO  ] = 0;
      gridbase.events[hSeq][I_SIZE] = 0;

      ArraySpliceInts   (gridbase.event, from, size);                // Elemente löschen
      ArraySpliceInts   (gridbase.time,  from, size);
      ArraySpliceDoubles(gridbase.value, from, size);

      gridbase[hSeq] = 0;
   }
   return(GridBase.Change(hSeq, time, value));
}


/**
 * Speichert eine Änderung der Gridbasis einer Sequenz.
 *
 * @param  int      hSeq  - Sequenz: D_LONG | D_SHORT
 * @param  datetime time  - Zeitpunkt der Änderung
 * @param  double   value - neue Gridbasis
 *
 * @return double - neue Gridbasis (for chaining)
 */
double GridBase.Change(int hSeq, datetime time, double value) {
   value = NormalizeDouble(value, Digits);

   int from=gridbase.events[hSeq][I_FROM], to=gridbase.events[hSeq][I_TO], size=gridbase.events[hSeq][I_SIZE];

   if (size == 0) {
      // insert                                                      // Änderung hinten anfügen
      int newSize = ArrayPushInt   (gridbase.event, CreateEventId());
                    ArrayPushInt   (gridbase.time,  time           );
                    ArrayPushDouble(gridbase.value, value          );
      gridbase.events[hSeq][I_FROM] = newSize-1;                     // Indizes der neuen Sequenz setzen
      gridbase.events[hSeq][I_TO  ] = newSize-1;
      gridbase.events[hSeq][I_SIZE] = 1;
   }
   else {
      int MM=time/MINUTE, lastMM=gridbase.time[to]/MINUTE;
      if (sequence.maxLevel[hSeq]!=0 && MM!=lastMM) {
         // insert                                                   // Änderung an Offset einfügen
         ArrayInsertInt   (gridbase.event, to+1, CreateEventId());
         ArrayInsertInt   (gridbase.time,  to+1, time           );
         ArrayInsertDouble(gridbase.value, to+1, value          );

         for (int i=0; i < 2; i++) {                                 // Indizes "hinter" der vergrößerten Sequenz anpassen
            if (gridbase.events[i][I_FROM] > from) {
               gridbase.events[i][I_FROM]++;
               gridbase.events[i][I_TO  ]++;                         // I_SIZE unverändert
            }
         }
         gridbase.events[hSeq][I_TO  ]++;                            // Indizes der vergrößerten Sequenz anpassen
         gridbase.events[hSeq][I_SIZE]++;                            // I_FROM unverändert
      }
      else {
         // replace                                                  // noch kein ausgeführter Trade oder mehrere Änderungen je Minute
         gridbase.event[to] = CreateEventId();
         gridbase.time [to] = time;
         gridbase.value[to] = value;                                 // alle Indizes unverändert
      }
   }

   gridbase[hSeq] = value;
   return(value);
}


/**
 * Fügt den Startdaten einer Sequenz ein Startevent hinzu.
 *
 * @param  int      hSeq   - Sequenz: D_LONG | D_SHORT
 * @param  datetime time   - Start-Time
 * @param  double   price  - Start-Price
 * @param  double   profit - Start-Profit
 *
 * @return int - Event-ID oder 0, falls ein Fehler auftrat
 */
int AddStartEvent(int hSeq, datetime time, double price, double profit) {
   if (__STATUS_ERROR)
      return(0);

   int offset, event=CreateEventId();

   if (sequence.ss.events[hSeq][I_SIZE] == 0) {
      offset = ArraySize(sequence.start.event);

      sequence.ss.events[hSeq][I_FROM] = offset;
      sequence.ss.events[hSeq][I_TO  ] = offset;
      sequence.ss.events[hSeq][I_SIZE] = 1;
   }
   else {
      // Indizes "hinter" der zu vergrößernden Sequenz entsprechend anpassen.
      for (int i=0; i < 2; i++) {
         if (sequence.ss.events[i][I_FROM] > sequence.ss.events[hSeq][I_FROM]) {
            sequence.ss.events[i][I_FROM]++;
            sequence.ss.events[i][I_TO  ]++;                         // I_SIZE unverändert
         }
      }
      offset = sequence.ss.events[hSeq][I_TO] + 1;

      sequence.ss.events[hSeq][I_TO  ]++;                            // I_FROM unverändert
      sequence.ss.events[hSeq][I_SIZE]++;
   }

   // Eventdaten an Offset einfügen
   ArrayInsertInt   (sequence.start.event,  offset, event );
   ArrayInsertInt   (sequence.start.time,   offset, time  );
   ArrayInsertDouble(sequence.start.price,  offset, price );
   ArrayInsertDouble(sequence.start.profit, offset, profit);

   ArrayInsertInt   (sequence.stop.event,   offset, 0     );         // Größe von sequence.starts/stops synchron halten
   ArrayInsertInt   (sequence.stop.time,    offset, 0     );
   ArrayInsertDouble(sequence.stop.price,   offset, 0     );
   ArrayInsertDouble(sequence.stop.profit,  offset, 0     );

   if (!catch("AddStartEvent()"))
      return(event);
   return(0);
}


/**
 * Initialisiert eine neue Sequenz. Aufruf nur aus StartSequence().
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool InitSequence(int hSeq) {
   if (__STATUS_ERROR)                                return( false);
   if (sequence.status[hSeq] != STATUS_UNINITIALIZED) return(_false(catch("InitSequence(1)   cannot initialize "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR)));
   if (!ResetSequence(hSeq))                          return( false);

   sequence.id       [hSeq] = CreateSequenceId();
   sequence.isTest   [hSeq] = IsTest(); SS.Sequence.Id(hSeq);
   sequence.direction[hSeq] = hSeq;
   sequence.gridSize [hSeq] = GridSize;
   sequence.lotSize  [hSeq] = LotSize;
   sequence.status   [hSeq] = STATUS_WAITING;

   if      (IsTesting()) sequence.statusFile[hSeq][I_DIR ] = "presets\\";
   else if (IsTest())    sequence.statusFile[hSeq][I_DIR ] = "presets\\tester\\";
   else                  sequence.statusFile[hSeq][I_DIR ] = "presets\\"+ ShortAccountCompany() +"\\";
                         sequence.statusFile[hSeq][I_FILE] = StringToLower(StdSymbol()) +".SR."+ sequence.id[hSeq] +".set";

   return(!catch("InitSequence(2)"));
}


/**
 * Setzt alle Variablen einer Sequenz zurück.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool ResetSequence(int hSeq) {
   int from, size;

   sequence.id           [hSeq]         = 0;
   sequence.isTest       [hSeq]         = false;
   sequence.direction    [hSeq]         = 0;
   sequence.gridSize     [hSeq]         = 0;
   sequence.lotSize      [hSeq]         = 0;
   sequence.status       [hSeq]         = STATUS_UNINITIALIZED;
   sequence.statusFile   [hSeq][I_DIR ] = "";
   sequence.statusFile   [hSeq][I_FILE] = "";

   sequence.level        [hSeq]         = 0;
   sequence.maxLevel     [hSeq]         = 0;
   sequence.startEquity  [hSeq]         = 0;
   sequence.weStop.active[hSeq]         = false;

   sequence.stops        [hSeq]         = 0;
   sequence.stopsPL      [hSeq]         = 0;
   sequence.closedPL     [hSeq]         = 0;
   sequence.floatingPL   [hSeq]         = 0;
   sequence.totalPL      [hSeq]         = 0;
   sequence.maxProfit    [hSeq]         = 0;
   sequence.maxDrawdown  [hSeq]         = 0;
   sequence.commission   [hSeq]         = 0;

   // ---------------------------------------------------------------
   from = sequence.ss.events[hSeq][I_FROM];
   size = sequence.ss.events[hSeq][I_SIZE];
   if (size > 0) {
      ArraySpliceInts   (sequence.start.event,  from, size);
      ArraySpliceInts   (sequence.start.time,   from, size);
      ArraySpliceDoubles(sequence.start.price,  from, size);
      ArraySpliceDoubles(sequence.start.profit, from, size);

      ArraySpliceInts   (sequence.stop.event,  from, size);
      ArraySpliceInts   (sequence.stop.time,   from, size);
      ArraySpliceDoubles(sequence.stop.price,  from, size);
      ArraySpliceDoubles(sequence.stop.profit, from, size);

      for (int i=0; i < 2; i++) {
         if (sequence.ss.events[i][I_FROM] > from) {
            sequence.ss.events[i][I_FROM] -= size;
            sequence.ss.events[i][I_TO  ] -= size;                   // I_SIZE unverändert
         }
      }
      sequence.ss.events[hSeq][I_FROM] = 0;
      sequence.ss.events[hSeq][I_TO  ] = 0;
      sequence.ss.events[hSeq][I_SIZE] = 0;
   }

   // ---------------------------------------------------------------
   from = gridbase.events[hSeq][I_FROM];
   size = gridbase.events[hSeq][I_SIZE];
   if (size > 0) {
      ArraySpliceInts   (gridbase.event, from, size);
      ArraySpliceInts   (gridbase.time,  from, size);
      ArraySpliceDoubles(gridbase.value, from, size);

      for (i=0; i < 2; i++) {
         if (gridbase.events[i][I_FROM] > from) {
            gridbase.events[i][I_FROM] -= size;
            gridbase.events[i][I_TO  ] -= size;                      // I_SIZE unverändert
         }
      }
      gridbase.events[hSeq][I_FROM] = 0;
      gridbase.events[hSeq][I_TO  ] = 0;
      gridbase.events[hSeq][I_SIZE] = 0;
   }
   gridbase[hSeq] = 0;

   // ---------------------------------------------------------------
   from = orders[hSeq][I_FROM];
   size = orders[hSeq][I_SIZE];
   if (size > 0) {
      ArraySpliceInts   (orders.ticket,       from, size);
      ArraySpliceInts   (orders.level,        from, size);
      ArraySpliceDoubles(orders.gridBase,     from, size);

      ArraySpliceInts   (orders.pendingType,  from, size);
      ArraySpliceInts   (orders.pendingTime,  from, size);
      ArraySpliceDoubles(orders.pendingPrice, from, size);

      ArraySpliceInts   (orders.type,         from, size);
      ArraySpliceInts   (orders.openEvent,    from, size);
      ArraySpliceInts   (orders.openTime,     from, size);
      ArraySpliceDoubles(orders.openPrice,    from, size);
      ArraySpliceInts   (orders.closeEvent,   from, size);
      ArraySpliceInts   (orders.closeTime,    from, size);
      ArraySpliceDoubles(orders.closePrice,   from, size);
      ArraySpliceDoubles(orders.stopLoss,     from, size);
      ArraySpliceBools  (orders.clientSL,     from, size);
      ArraySpliceBools  (orders.closedBySL,   from, size);

      ArraySpliceDoubles(orders.swap,         from, size);
      ArraySpliceDoubles(orders.commission,   from, size);
      ArraySpliceDoubles(orders.profit,       from, size);

      for (i=0; i < 2; i++) {
         if (orders[i][I_FROM] > from) {
            orders[i][I_FROM] -= size;
            orders[i][I_TO  ] -= size;                               // I_SIZE unverändert
         }
      }
      orders[hSeq][I_FROM] = 0;
      orders[hSeq][I_TO  ] = 0;
      orders[hSeq][I_SIZE] = 0;
   }

   // ---------------------------------------------------------------
   from = ignore.pending[hSeq][I_FROM];
   size = ignore.pending[hSeq][I_SIZE];
   if (size > 0) {
      ArraySpliceInts(ignore.pendingOrders, from, size);
      for (i=0; i < 2; i++) {
         if (ignore.pending[i][I_FROM] > from) {
            ignore.pending[i][I_FROM] -= size;
            ignore.pending[i][I_TO  ] -= size;                       // I_SIZE unverändert
         }
      }
      ignore.pending[hSeq][I_FROM] = 0;
      ignore.pending[hSeq][I_TO  ] = 0;
      ignore.pending[hSeq][I_SIZE] = 0;
   }

   // ---------------------------------------------------------------
   from = ignore.open[hSeq][I_FROM];
   size = ignore.open[hSeq][I_SIZE];
   if (size > 0) {
      ArraySpliceInts(ignore.openPositions, from, size);
      for (i=0; i < 2; i++) {
         if (ignore.open[i][I_FROM] > from) {
            ignore.open[i][I_FROM] -= size;
            ignore.open[i][I_TO  ] -= size;                          // I_SIZE unverändert
         }
      }
      ignore.open[hSeq][I_FROM] = 0;
      ignore.open[hSeq][I_TO  ] = 0;
      ignore.open[hSeq][I_SIZE] = 0;
   }

   // ---------------------------------------------------------------
   from = ignore.closed[hSeq][I_FROM];
   size = ignore.closed[hSeq][I_SIZE];
   if (size > 0) {
      ArraySpliceInts(ignore.closedPositions, from, size);
      for (i=0; i < 2; i++) {
         if (ignore.closed[i][I_FROM] > from) {
            ignore.closed[i][I_FROM] -= size;
            ignore.closed[i][I_TO  ] -= size;                        // I_SIZE unverändert
         }
      }
      ignore.closed[hSeq][I_FROM] = 0;
      ignore.closed[hSeq][I_TO  ] = 0;
      ignore.closed[hSeq][I_SIZE] = 0;
   }

   // ---------------------------------------------------------------
   str.sequence.id         [hSeq] = "";
   str.sequence.stops      [hSeq] = "";
   str.sequence.stopsPL    [hSeq] = "";
   str.sequence.totalPL    [hSeq] = "";
   str.sequence.maxProfit  [hSeq] = "";
   str.sequence.maxDrawdown[hSeq] = "";
   str.sequence.plStats    [hSeq] = "";

   return(!catch("ResetSequence()"));
}


/**
 * Schließt alle PendingOrders und offenen Positionen der Sequenz.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus: ob die Sequenz erfolgreich gestoppt wurde
 */
bool StopSequence(int hSeq) {
   return(!catch("StopSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Der StopPrice darf nicht schon den nächsten Level triggern, da sonst bei ResumeSequence() Fehler auftreten.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool StopSequence.LimitStopPrice(int hSeq) {
   if (__STATUS_ERROR)                                                                           return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())                                                        return(_false(catch("StopSequence.LimitStopPrice(1)", ERR_ILLEGAL_STATE)));
   if (sequence.status[hSeq]!=STATUS_STOPPING) /*&&*/ if (sequence.status[hSeq]!=STATUS_STOPPED) return(_false(catch("StopSequence.LimitStopPrice(2)   cannot limit stop price of "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR)));

   double nextTrigger;
   int i = sequence.ss.events[hSeq][I_TO];

   if (sequence.direction[hSeq] == D_LONG) {
      nextTrigger = gridbase[hSeq] + (sequence.level[hSeq]+1)*GridSize*Pip;
      sequence.stop.price[i] = MathMin(nextTrigger-1*Pip, sequence.stop.price[i]);  // max. 1 Pip unterm Trigger des nächsten Levels
   }

   if (sequence.direction[hSeq] == D_SHORT) {
      nextTrigger = gridbase[hSeq] + (sequence.level[hSeq]-1)*GridSize*Pip;
      sequence.stop.price[i] = MathMax(nextTrigger+1*Pip, sequence.stop.price[i]);  // min. 1 Pip überm Trigger des nächsten Levels
   }
   sequence.stop.price[i] = NormalizeDouble(sequence.stop.price[i], Digits);

   return(!last_error|catch("StopSequence.LimitStopPrice(3)"));
}


/**
 * Setzt eine gestoppte Sequenz fort.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool ResumeSequence(int hSeq) {
   return(!catch("ResumeSequence()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Prüft und synchronisiert die im EA gespeicherten mit den aktuellen Laufzeitdaten.
 *
 * @param  int  hSeq     - Sequenz: D_LONG | D_SHORT
 * @param  bool lpChange - Variable, die nach Rückkehr anzeigt, ob sich Gridbasis oder Gridlevel der Sequenz geändert haben
 * @param  int  stops[]  - Array, das nach Rückkehr die Order-Indizes getriggerter client-seitiger Stops enthält (Pending- und SL-Orders)
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatus(int hSeq, bool &lpChange, int stops[]) {
   ArrayResize(stops, 0);
   if (__STATUS_ERROR)                          return(false);
   if (sequence.status[hSeq] == STATUS_WAITING) return(true);

   sequence.floatingPL[hSeq] = 0;

   bool wasPending, isClosed, openPositions, updateStatusLocation;
   int  closed[][2], close[2], ticketFrom=orders[hSeq][I_FROM], ticketTo=orders[hSeq][I_TO], ticketSize=orders[hSeq][I_SIZE]; ArrayResize(closed, 0);


   // (1) Tickets aktualisieren
   if (ticketSize > 0) {
      for (int i=ticketFrom; i <= ticketTo; i++) {
         if (orders.closeTime[i] == 0) {                                            // Ticket prüfen, wenn es beim letzten Aufruf offen war
            wasPending = (orders.type[i] == OP_UNDEFINED);

            // (1.1) client-seitige PendingOrders prüfen
            if (wasPending) /*&&*/ if (orders.ticket[i] == -1) {
               if (IsStopTriggered(orders.pendingType[i], orders.pendingPrice[i])) {
                  if (__LOG) log(UpdateStatus.StopTriggerMsg(hSeq, i));
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
               if (__LOG) log(UpdateStatus.SLExecuteMsg(hSeq, i));

               sequence.level[hSeq]  -= Sign(orders.level[i]);
               sequence.stops[hSeq]++; SS.Sequence.Stops(hSeq);
             //sequence.stopsPL[hSeq] = ...                                         // unverändert, da P/L des Pseudo-Tickets immer 0.00
               lpChange               = true;
               continue;
            }

            // (1.3) reguläre server-seitige Tickets
            if (!SelectTicket(orders.ticket[i], "UpdateStatus(1)"))
               return(false);

            if (wasPending) {
               // beim letzten Aufruf Pending-Order
               if (OrderType() != orders.pendingType[i]) {                          // Order wurde ausgeführt
                  orders.type      [i] = OrderType();
                  orders.openEvent [i] = CreateEventId();
                  orders.openTime  [i] = OrderOpenTime();
                  orders.openPrice [i] = OrderOpenPrice();
                  orders.swap      [i] = OrderSwap();
                  orders.commission[i] = OrderCommission(); sequence.commission[hSeq] = OrderCommission(); SS.LotSize();
                  orders.profit    [i] = OrderProfit();
                  ChartMarker.OrderFilled(hSeq, i);
                  if (__LOG) log(UpdateStatus.OrderFillMsg(hSeq, i));

                  sequence.level   [hSeq] += Sign(orders.level[i]);
                  sequence.maxLevel[hSeq]  = Sign(orders.level[i]) * Max(Abs(sequence.level[hSeq]), Abs(sequence.maxLevel[hSeq]));
                  lpChange                 = true;
                  updateStatusLocation     = updateStatusLocation || !sequence.maxLevel[hSeq];
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
                     if (__LOG) log(UpdateStatus.StopTriggerMsg(hSeq, i));
                     ArrayPushInt(stops, i);
                  }
               }
               sequence.floatingPL[hSeq] = NormalizeDouble(sequence.floatingPL[hSeq] + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
            }
            else if (orders.type[i] == OP_UNDEFINED) {                              // jetzt geschlossenes Ticket: gestrichene Pending-Order im STATUS_MONITORING
               //ChartMarker.OrderDeleted(i);                                       // TODO: implementieren
               Grid.DropData(i);
               ticketFrom = orders[hSeq][I_FROM];
               ticketTo   = orders[hSeq][I_TO  ];
               ticketSize = orders[hSeq][I_SIZE];
               i--;
            }
            else {
               orders.closeTime [i] = OrderCloseTime();                             // jetzt geschlossenes Ticket: geschlossene Position
               orders.closePrice[i] = OrderClosePrice();
               orders.closedBySL[i] = IsOrderClosedBySL();
               ChartMarker.PositionClosed(i);

               if (orders.closedBySL[i]) {                                          // ausgestoppt
                  orders.closeEvent[i] = CreateEventId();                           // Event-ID kann sofort vergeben werden.
                  if (__LOG) log(UpdateStatus.SLExecuteMsg(hSeq, i));
                  sequence.level  [hSeq] -= Sign(orders.level[i]);
                  sequence.stops  [hSeq]++;
                  sequence.stopsPL[hSeq]  = NormalizeDouble(sequence.stopsPL[hSeq] + orders.swap[i] + orders.commission[i] + orders.profit[i], 2); SS.Sequence.Stops(hSeq);
                  lpChange                = true;
               }
               else {                                                               // Sequenzstop im STATUS_MONITORING oder autom. Close bei Testende
                  close[0] = OrderCloseTime();
                  close[1] = OrderTicket();                                         // Geschlossene Positionen werden zwischengespeichert, deren Event-IDs werden erst
                  ArrayPushIntArray(closed, close);                                 // *NACH* allen evt. vorher ausgestoppten Positionen vergeben.

                  if (sequence.status[hSeq] != STATUS_STOPPED)
                     sequence.status[hSeq] = STATUS_STOPPING;
                  if (__LOG) log(UpdateStatus.PositionCloseMsg(hSeq, i));
                  sequence.closedPL[hSeq] = NormalizeDouble(sequence.closedPL[hSeq] + orders.swap[i] + orders.commission[i] + orders.profit[i], 2);
               }
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
            return(_false(catch("UpdateStatus(2)   closed ticket #"+ closed[i][1] +" not found in order arrays", ERR_RUNTIME_ERROR)));
         orders.closeEvent[n] = CreateEventId();
      }
      ArrayResize(closed, 0);
   }


   // (3) P/L-Kennziffern  aktualisieren
   sequence.totalPL[hSeq] = NormalizeDouble(sequence.stopsPL[hSeq] + sequence.closedPL[hSeq] + sequence.floatingPL[hSeq], 2); SS.Sequence.TotalPL(hSeq);

   if      (sequence.totalPL[hSeq] > sequence.maxProfit  [hSeq]) { sequence.maxProfit  [hSeq] = sequence.totalPL[hSeq]; SS.Sequence.MaxProfit(hSeq);   }
   else if (sequence.totalPL[hSeq] < sequence.maxDrawdown[hSeq]) { sequence.maxDrawdown[hSeq] = sequence.totalPL[hSeq]; SS.Sequence.MaxDrawdown(hSeq); }


   // (4) ggf. Status aktualisieren
   if (sequence.status[hSeq] == STATUS_STOPPING) {
      if (!openPositions) {                                                         // Sequenzstop im STATUS_MONITORING oder Auto-Close durch Tester bei Testende
         n = sequence.ss.events[hSeq][I_TO];
         sequence.stop.event [n] = CreateEventId();
         sequence.stop.time  [n] = UpdateStatus.CalculateStopTime(hSeq);  if (!sequence.stop.time [n]) return(false);
         sequence.stop.price [n] = UpdateStatus.CalculateStopPrice(hSeq); if (!sequence.stop.price[n]) return(false);
         sequence.stop.profit[n] = sequence.totalPL[hSeq];

         if (!StopSequence.LimitStopPrice(hSeq))                                    //  StopPrice begrenzen (darf nicht schon den nächsten Level triggern)
            return(false);

         sequence.status[hSeq] = STATUS_STOPPED;
         if (__LOG) log("UpdateStatus()   STATUS_STOPPED");
         RedrawStartStop(hSeq);
      }
   }


   else if (sequence.status[hSeq] == STATUS_PROGRESSING) {
      // (5) ggf. Gridbasis trailen
      if (sequence.level[hSeq] == 0) {
         double tmp.gridbase = gridbase[hSeq];

         if (sequence.direction[hSeq] == D_LONG) gridbase[hSeq] = MathMin(gridbase[hSeq], NormalizeDouble((Bid + Ask)/2, Digits));
         else                                    gridbase[hSeq] = MathMax(gridbase[hSeq], NormalizeDouble((Bid + Ask)/2, Digits));

         if (NE(gridbase[hSeq], tmp.gridbase)) {
            GridBase.Change(hSeq, TimeCurrent(), gridbase[hSeq]);
            lpChange = true;
         }
      }
   }


   // (6) ggf. Ort der Statusdatei aktualisieren
   if (updateStatusLocation)
      UpdateStatusLocation(hSeq);

   return(!last_error|catch("UpdateStatus(4)"));
}


/**
 * Ermittelt die StopTime der aktuell gestoppten Sequenz. Aufruf nur nach externem Sequencestop.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return datetime - Zeitpunkt oder NULL, falls ein Fehler auftrat
 */
datetime UpdateStatus.CalculateStopTime(int hSeq) {
   if (sequence.status[hSeq] != STATUS_STOPPING) return(_NULL(catch("UpdateStatus.CalculateStopTime(1)   cannot calculate stop time for "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR)));
   if (sequence.level [hSeq] == 0              ) return(_NULL(catch("UpdateStatus.CalculateStopTime(2)   cannot calculate stop time for sequence at level "+ sequence.level[hSeq], ERR_RUNTIME_ERROR)));

   datetime stopTime;
   int n = sequence.level[hSeq];

   if (orders[hSeq][I_SIZE] > 0) {
      for (int i=orders[hSeq][I_TO]; n != 0; i--) {
         if (orders.closeTime[i] == 0) {
            if (IsTesting() && __WHEREAMI__==FUNC_DEINIT && orders.type[i]==OP_UNDEFINED)
               continue;                                             // offene Pending-Orders ignorieren
            return(_NULL(catch("UpdateStatus.CalculateStopTime(3)   #"+ orders.ticket[i] +" is not closed", ERR_RUNTIME_ERROR)));
         }
         if (orders.type[i] == OP_UNDEFINED)                         // gestrichene Pending-Orders ignorieren
            continue;
         if (orders.closedBySL[i])                                   // ausgestoppte Positionen ignorieren
            continue;

         if (orders.level[i] != n)
            return(_NULL(catch("UpdateStatus.CalculateStopTime(4)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n, ERR_RUNTIME_ERROR)));

         stopTime = Max(stopTime, orders.closeTime[i]);
         n -= Sign(n);
      }
   }
   return(stopTime);
}


/**
 * Ermittelt den durchschnittlichen StopPrice der aktuell gestoppten Sequenz. Aufruf nur nach externem Sequencestop.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return double - Preis oder NULL, falls ein Fehler auftrat
 */
double UpdateStatus.CalculateStopPrice(int hSeq) {
   if (sequence.status[hSeq] != STATUS_STOPPING) return(_NULL(catch("UpdateStatus.CalculateStopPrice(1)   cannot calculate stop price for "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR)));
   if (sequence.level [hSeq] == 0              ) return(_NULL(catch("UpdateStatus.CalculateStopPrice(2)   cannot calculate stop price for sequence at level "+ sequence.level[hSeq], ERR_RUNTIME_ERROR)));

   double stopPrice;
   int n = sequence.level[hSeq];

   if (orders[hSeq][I_SIZE] > 0) {
      for (int i=orders[hSeq][I_TO]; n != 0; i--) {
         if (orders.closeTime[i] == 0) {
            if (IsTesting() && __WHEREAMI__==FUNC_DEINIT && orders.type[i]==OP_UNDEFINED)
               continue;                                             // offene Pending-Orders ignorieren
            return(_NULL(catch("UpdateStatus.CalculateStopPrice(3)   #"+ orders.ticket[i] +" is not closed", ERR_RUNTIME_ERROR)));
         }
         if (orders.type[i] == OP_UNDEFINED)                         // gestrichene Pending-Orders ignorieren
            continue;
         if (orders.closedBySL[i])                                   // ausgestoppte Positionen ignorieren
            continue;

         if (orders.level[i] != n)
            return(_NULL(catch("UpdateStatus.CalculateStopPrice(4)   #"+ orders.ticket[i] +" (level "+ orders.level[i] +") doesn't match the expected level "+ n, ERR_RUNTIME_ERROR)));

         stopPrice += orders.closePrice[i];
         n -= Sign(n);
      }
   }
   return(NormalizeDouble(stopPrice/Abs(sequence.level[hSeq]), Digits));
}


/**
 * Logmessage für getriggerten client-seitigen StopLoss.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 * @param  int i    - Orderindex
 *
 * @return string
 */
string UpdateStatus.StopTriggerMsg(int hSeq, int i) {
   string comment = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(orders.level[i], "+."));

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
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 * @param  int i    - Orderindex
 *
 * @return string
 */
string UpdateStatus.SLExecuteMsg(int hSeq, int i) {
   // [pseudo ticket ]#1 Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17"), [client-side ]stop-loss 1.5457'2 was executed[ at 1.5457'2 (0.3 pip [positive ]slippage)]

   string strPseudo    = ifString(orders.ticket[i]==-2, "pseudo ticket ", "");
   string strType      = OperationTypeDescription(orders.type[i]);
   string strOpenPrice = NumberToStr(orders.openPrice[i], PriceFormat);
   string strStopSide  = ifString(orders.clientSL[i], "client-side ", "");
   string strStopLoss  = NumberToStr(orders.stopLoss[i], PriceFormat);
   string comment      = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(orders.level[i], "+."));

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
 * Logmessage für ausgeführte PendingOrder
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 * @param  int i    - Orderindex
 *
 * @return string
 */
string UpdateStatus.OrderFillMsg(int hSeq, int i) {
   // #1 Stop Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17") was filled[ at 1.5457'2 (0.3 pip [positive ]slippage)]

   string strType         = OperationTypeDescription(orders.pendingType[i]);
   string strPendingPrice = NumberToStr(orders.pendingPrice[i], PriceFormat);
   string comment         = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(orders.level[i], "+."));

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
 * Logmessage für geschlossene Position.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 * @param  int i    - Orderindex
 *
 * @return string
 */
string UpdateStatus.PositionCloseMsg(int hSeq, int i) {
   // #1 Sell 0.1 GBPUSD at 1.5457'2 ("SR.8692.+17") was closed at 1.5457'2

   string strType       = OperationTypeDescription(orders.type[i]);
   string strOpenPrice  = NumberToStr(orders.openPrice[i], PriceFormat);
   string strClosePrice = NumberToStr(orders.closePrice[i], PriceFormat);
   string comment       = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(orders.level[i], "+."));

   return(StringConcatenate("UpdateStatus()   #", orders.ticket[i], " ", strType, " ", NumberToStr(LotSize, ".+"), " ", Symbol(), " at ", strOpenPrice, " (\"", comment, "\") was closed at ", strClosePrice));
}


/**
 * Aktualisiert die Dateinamensvariablen der Statusdatei.  SaveStatus() erkennt die Änderung und verschiebt die Datei automatisch.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateStatusLocation(int hSeq) {
   if (__STATUS_ERROR)     return( false);
   if (!sequence.id[hSeq]) return(_false(catch("UpdateStatusLocation(1)   illegal value of sequence.id = "+ sequence.id[hSeq], ERR_RUNTIME_ERROR)));

   // TODO: Prüfen, ob status.file existiert und ggf. aktualisieren

   string startDate = "";

   if      (IsTesting()) sequence.statusFile[hSeq][I_DIR] = "presets\\";
   else if (IsTest())    sequence.statusFile[hSeq][I_DIR] = "presets\\tester\\";
   else {
      sequence.statusFile[hSeq][I_DIR] = "presets\\"+ ShortAccountCompany() +"\\";

      if (sequence.maxLevel[hSeq] != 0) {
         startDate                        = TimeToStr(orders.openTime[orders[hSeq][I_FROM]], TIME_DATE);
         sequence.statusFile[hSeq][I_DIR] = sequence.statusFile[hSeq][I_DIR] + startDate +"\\";
      }
   }
   return(true);
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
 * Korrigiert die vom Terminal beim Abschicken einer Pending- oder Market-Order gesetzten oder nicht gesetzten Chart-Marker.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 * @param  int i    - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.OrderSent(int hSeq, int i) {
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
   string   comment     = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(orders.level[i], "+."));
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
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 * @param  int i    - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool ChartMarker.OrderFilled(int hSeq, int i) {
   if (!IsChart) return(true);
   /*
   #define ODM_NONE     0     // - keine Anzeige -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   string comment     = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(orders.level[i], "+."));
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
 * Ordermanagement getriggerter client-seitiger Stops. Kann eine getriggerte Stop-Order oder ein getriggerter Stop-Loss sein.
 *
 * @param  int stops[] - Order-Indizes getriggerter client-seitiger Stops
 *
 * @return bool - Erfolgsstatus
 */
bool ProcessClientStops(int stops[]) {
   return(!catch("ProcessClientStops()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Aktualisiert vorhandene, setzt fehlende und löscht unnötige PendingOrders einer Sequenz.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePendingOrders(int hSeq) {
   if (__STATUS_ERROR)                              return( false);
   if (IsTest()) /*&&*/ if (!IsTesting())           return(_false(catch("UpdatePendingOrders(1)", ERR_ILLEGAL_STATE)));
   if (sequence.status[hSeq] != STATUS_PROGRESSING) return(_false(catch("UpdatePendingOrders(2)   cannot update orders of "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR)));

   int from = orders[hSeq][I_FROM];
   int size = orders[hSeq][I_SIZE];

   int  nextLevel = sequence.level[hSeq] + ifInt(hSeq==D_LONG, 1, -1);
   bool nextOrderExists, ordersChanged;

   for (int i=from+size-1; i >= from; i--) {
      if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (orders.closeTime[i]==0) {     // if (isPending && !isClosed)
         if (orders.level[i] == nextLevel) {
            nextOrderExists = true;
            if (Abs(nextLevel)==1) /*&&*/ if (NE(orders.pendingPrice[i], gridbase[hSeq] + nextLevel*GridSize*Pips)) {
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
      if (!Grid.AddOrder(hSeq, ifInt(hSeq==D_LONG, OP_BUYSTOP, OP_SELLSTOP), nextLevel))
         return(false);
      ordersChanged = true;
   }

   if (ordersChanged)                                                            // Status speichern
      if (!SaveStatus(hSeq))
         return(false);
   return(!last_error|catch("UpdatePendingOrders(3)"));
}


/**
 * Justiert PendingOpenPrice() und StopLoss() der angegebenen Order und aktualisiert die Orderarrays.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.TrailPendingOrder(int i) {
   return(!catch("Grid.TrailPendingOrder()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Streicht die angegebene Order und entfernt sie aus den Orderarrays.
 *
 * @param  int i - Orderindex
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.DeleteOrder(int i) {
   return(!catch("Grid.DeleteOrder()", ERR_FUNCTION_NOT_IMPLEMENTED));
}


/**
 * Legt eine Stop-Order in den Markt und fügt sie den Orderarrays hinzu.
 *
 * @param  int hSeq  - Sequenz: D_LONG | D_SHORT
 * @param  int type  - Ordertyp: OP_BUYSTOP | OP_SELLSTOP
 * @param  int level - Gridlevel der Order
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.AddOrder(int hSeq, int type, int level) {
   if (__STATUS_ERROR)                              return(false);
   if (IsTest()) /*&&*/ if (!IsTesting())           return(!catch("Grid.AddOrder(1)", ERR_ILLEGAL_STATE));
   if (sequence.status[hSeq] != STATUS_PROGRESSING) return(!catch("Grid.AddOrder(2)   cannot add order to "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("Grid.AddOrder()", "Do you really want to submit a new "+ OperationTypeDescription(type) +" order now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));


   // (1) Order in den Markt legen
   /*ORDER_EXECUTION*/int oe[]; InitializeBuffer(oe, ORDER_EXECUTION.size);
   int ticket = SubmitStopOrder(hSeq, type, level, oe);

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
   //double gridbase     = ...                                          // unverändert

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

   if (!Grid.PushData(hSeq, ticket, level, gridbase[hSeq], pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit))
      return(false);
   return(!last_error|catch("Grid.AddOrder(5)"));
}


/**
 * Fügt den Datenarrays der Sequenz die angegebenen Daten hinzu.
 *
 * @param  int      hSeq         - Sequenz: D_LONG | D_SHORT
 *
 * @param  int      ticket
 * @param  int      level
 * @param  double   gridbase
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
bool Grid.PushData(int hSeq, int ticket, int level, double gridbase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientSL, bool closedBySL, double swap, double commission, double profit) {
   return(Grid.SetData(hSeq, -1, ticket, level, gridbase, pendingType, pendingTime, pendingPrice, type, openEvent, openTime, openPrice, closeEvent, closeTime, closePrice, stopLoss, clientSL, closedBySL, swap, commission, profit));
}


/**
 * Schreibt die angegebenen Daten an die angegebene Position der Gridarrays.
 *
 * @param  int      hSeq         - Sequenz: D_LONG | D_SHORT
 * @param  int      offset       - Arrayposition: Ist dieser Wert -1 oder sind die Gridarrays zu klein, werden sie vergrößert.
 *
 * @param  int      ticket
 * @param  int      level
 * @param  double   gridbase
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
bool Grid.SetData(int hSeq, int offset, int ticket, int level, double gridbase, int pendingType, datetime pendingTime, double pendingPrice, int type, int openEvent, datetime openTime, double openPrice, int closeEvent, datetime closeTime, double closePrice, double stopLoss, bool clientSL, bool closedBySL, double swap, double commission, double profit) {
   if (offset < -1)
      return(_false(catch("Grid.SetData(1)   illegal parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int from = orders[hSeq][I_FROM];
   int to   = orders[hSeq][I_TO  ];
   int size = orders[hSeq][I_SIZE], sizeOfTickets=ArraySize(orders.ticket), i, n;

   if (0 <= offset && offset < size) {
      // replace at offset i
      i = from + offset;
   }
   else {
      // insert at offset i
      if (offset < 0) {
         if (size == 0) {
            orders[hSeq][I_FROM] = sizeOfTickets;
            orders[hSeq][I_TO  ] = sizeOfTickets;
            orders[hSeq][I_SIZE] = 1;
            i = sizeOfTickets;
         }
         else {
            for (n=0; n < 2; n++) {                                  // Indizes der folgenden Sequenzen um 1 anpassen
               if (orders[n][I_FROM] > from) {
                  orders[n][I_FROM]++;
                  orders[n][I_TO  ]++;
               }
            }
            orders[hSeq][I_TO  ]++;
            orders[hSeq][I_SIZE]++;
            i = to + 1;
         }
      }
      else {
         for (n=0; n < 2; n++) {                                     // Indizes der folgenden Sequenzen entsprechend anpassen
            if (orders[n][I_FROM] > from) {
               orders[n][I_FROM] += 1 + offset-size;
               orders[n][I_TO  ] += 1 + offset-size;
            }
         }
         orders[hSeq][I_TO  ] += 1 + offset-size;
         orders[hSeq][I_SIZE] += 1 + offset-size;
         // Arrays ggf. um mehrere Elemente vergrößern
         for (n=offset-size; n > 0; n--) {
            Grid.InsertElement(to+1);
         }
         i = from + offset;
      }
      Grid.InsertElement(i);
   }

   // Daten an Offset i (er-)setzen
   orders.ticket      [i] = ticket;
   orders.level       [i] = level;
   orders.gridBase    [i] = NormalizeDouble(gridbase, Digits);

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
   orders.commission  [i] = NormalizeDouble(commission, 2); if (type != OP_UNDEFINED) sequence.commission[hSeq] = orders.commission[i];
   orders.profit      [i] = NormalizeDouble(profit,     2);

   return(!catch("Grid.SetData(2)"));
}


/**
 * Fügt am angegebenen Offset der Orderarrays ein weiteres (leeres) Element ein. Die Arrayindizes der Sequenzen bleiben unverändert.
 *
 * @param  int offset
 *
 * @return bool - Erfolgsstatus
 */
bool Grid.InsertElement(int offset) {
   int sizeOfTickets = ArraySize(orders.ticket);

   if (offset < 0 || offset > sizeOfTickets) return(_false(catch("Grid.InsertElement(1)   illegal parameter offset = "+ offset, ERR_INVALID_FUNCTION_PARAMVALUE)));

   ArrayInsertInt   (orders.ticket,       offset, 0    );
   ArrayInsertInt   (orders.level,        offset, 0    );
   ArrayInsertDouble(orders.gridBase,     offset, 0    );

   ArrayInsertInt   (orders.pendingType,  offset, 0    );
   ArrayInsertInt   (orders.pendingTime,  offset, 0    );
   ArrayInsertDouble(orders.pendingPrice, offset, 0    );

   ArrayInsertInt   (orders.type,         offset, 0    );
   ArrayInsertInt   (orders.openEvent,    offset, 0    );
   ArrayInsertInt   (orders.openTime,     offset, 0    );
   ArrayInsertDouble(orders.openPrice,    offset, 0    );
   ArrayInsertInt   (orders.closeEvent,   offset, 0    );
   ArrayInsertInt   (orders.closeTime,    offset, 0    );
   ArrayInsertDouble(orders.closePrice,   offset, 0    );
   ArrayInsertDouble(orders.stopLoss,     offset, 0    );
   ArrayInsertBool  (orders.clientSL,     offset, false);
   ArrayInsertBool  (orders.closedBySL,   offset, false);

   ArrayInsertDouble(orders.swap,         offset, 0    );
   ArrayInsertDouble(orders.commission,   offset, 0    );
   ArrayInsertDouble(orders.profit,       offset, 0    );

   return(!catch("Grid.InsertElement(2)"));
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

   // Indizes aktualisieren
   for (int n=0; n < 2; n++) {
      if (orders[n][I_SIZE] > 0) {
         if (orders[n][I_FROM]<=i && i<=orders[n][I_TO]) {
            orders[n][I_TO  ]--;
            orders[n][I_SIZE]--;
         }
      }
   }
   return(!last_error|catch("Grid.DropData(2)"));
}


/**
 * Legt eine Stop-Order in den Markt.
 *
 * @param  int hSeq  - Sequenz: D_LONG | D_SHORT
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
int SubmitStopOrder(int hSeq, int type, int level, int oe[]) {
   if (__STATUS_ERROR)                                                                               return(0);
   if (IsTest()) /*&&*/ if (!IsTesting())                                                            return(_ZERO(catch("SubmitStopOrder(1)", ERR_ILLEGAL_STATE)));
   if (sequence.status[hSeq]!=STATUS_PROGRESSING) /*&&*/ if (sequence.status[hSeq]!=STATUS_STARTING) return(_ZERO(catch("SubmitStopOrder(2)   cannot submit stop order for "+ statusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR)));

   if (type == OP_BUYSTOP) {
      if (level <= 0) return(_ZERO(catch("SubmitStopOrder(3)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else if (type == OP_SELLSTOP) {
      if (level >= 0) return(_ZERO(catch("SubmitStopOrder(4)   illegal parameter level = "+ level +" for "+ OperationTypeDescription(type), ERR_INVALID_FUNCTION_PARAMVALUE)));
   }
   else               return(_ZERO(catch("SubmitStopOrder(5)   illegal parameter type = "+ type, ERR_INVALID_FUNCTION_PARAMVALUE)));

   double   stopPrice   = gridbase[hSeq] + level*GridSize*Pips;
   double   slippage    = NULL;
   double   stopLoss    = stopPrice - Sign(level)*GridSize*Pips;
   double   takeProfit  = NULL;
   int      magicNumber = CreateMagicNumber(hSeq, level);
   datetime expires     = NULL;
   string   comment     = StringConcatenate("SR.", sequence.id[hSeq], ".", NumberToStr(level, "+."));
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
 * Generiert für den angegebenen Gridlevel eine MagicNumber.
 *
 * @param  int hSeq  - Sequenz: D_LONG | D_SHORT
 * @param  int level - Gridlevel
 *
 * @return int - MagicNumber oder -1, falls ein Fehler auftrat
 */
int CreateMagicNumber(int hSeq, int level) {
   if (sequence.id[hSeq] < SID_MIN) return(_int(-1, catch("CreateMagicNumber(1)   illegal sequence.id = "+ sequence.id[hSeq], ERR_RUNTIME_ERROR)));
   if (!level)                      return(_int(-1, catch("CreateMagicNumber(2)   illegal parameter level = "+ level, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // Für bessere Obfuscation ist die Reihenfolge der Werte [ea,level,sequence] und nicht [ea,sequence,level], was aufeinander folgende Werte wären.
   int ea       = STRATEGY_ID & 0x3FF << 22;                         // 10 bit (Bits größer 10 löschen und auf 32 Bit erweitern)  | Position in MagicNumber: Bits 23-32
       level    = Abs(level);                                        // der Level in MagicNumber ist immer positiv                |
       level    = level & 0xFF << 14;                                //  8 bit (Bits größer 8 löschen und auf 22 Bit erweitern)   | Position in MagicNumber: Bits 15-22
   int sequence = sequence.id[hSeq] & 0x3FFF;                        // 14 bit (Bits größer 14 löschen                            | Position in MagicNumber: Bits  1-14

   return(ea + level + sequence);
}


/**
 * Speichert den Status der angegeben Sequenz, um später die nahtlose Re-Initialisierung im selben oder einem anderen Terminal
 * zu ermöglichen.
 *
 * @param  int hSeq  - Sequenz: D_LONG | D_SHORT
 *
 * @return bool - Erfolgsstatus
 */
bool SaveStatus(int hSeq) {
   if (__STATUS_ERROR)                    return( false);
   if (!sequence.id[hSeq])                return(_false(catch("SaveStatus(1)   illegal value of sequence.id = "+ sequence.id[hSeq], ERR_RUNTIME_ERROR)));
   if (IsTest()) /*&&*/ if (!IsTesting()) return(true);

   // Im Tester wird der Status zur Performancesteigerung nur beim ersten und letzten Aufruf gespeichert, es sei denn,
   // das Logging ist aktiviert oder die Sequenz wurde bereits gestoppt.
   if (IsTesting()) /*&&*/ if (!__LOG) {
      static bool firstCall = true;
      if (!firstCall) /*&&*/ if (sequence.status[hSeq]!=STATUS_STOPPED) /*&&*/ if (__WHEREAMI__!=FUNC_DEINIT)
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
   ArrayPushString(lines, /*string*/   "Account="+                   ShortAccountCompany() +":"+ GetAccountNumber());
   ArrayPushString(lines, /*string*/   "Symbol="                 +                Symbol()                         );
   ArrayPushString(lines, /*string*/   "Sequence.ID="            +                str.sequence.id     [hSeq]       );
      if (StringLen(sequence.statusFile[hSeq][I_DIR]) > 0)
   ArrayPushString(lines, /*string*/   "Sequence.StatusLocation="+                sequence.statusFile [hSeq][I_DIR]);
   ArrayPushString(lines, /*string*/   "GridDirection="          + directionDescr[sequence.direction  [hSeq]]      );
   ArrayPushString(lines, /*int   */   "GridSize="               +                sequence.gridSize   [hSeq]       );
   ArrayPushString(lines, /*double*/   "LotSize="                +    NumberToStr(sequence.lotSize    [hSeq], ".+"));
      if (start.trend.condition)
   ArrayPushString(lines, /*string*/   "StartConditions="        +                StartConditions                  );
      if (stop.profitAbs.condition)
   ArrayPushString(lines, /*string*/   "StopConditions="         +                StopConditions                   );

   // (1.2) Laufzeit-Variablen
   ArrayPushString(lines, /*double*/   "rt.sequence.startEquity="+    NumberToStr(sequence.startEquity[hSeq], ".+"));
      string sValues[]; ArrayResize(sValues, 0);
      if (sequence.ss.events[hSeq][I_SIZE] > 0)
         for (int i=sequence.ss.events[hSeq][I_FROM]; i <= sequence.ss.events[hSeq][I_TO]; i++)
            ArrayPushString(sValues, StringConcatenate(sequence.start.event[i], "|", sequence.start.time[i], "|", NumberToStr(sequence.start.price[i], ".+"), "|", NumberToStr(sequence.start.profit[i], ".+")));
      else  ArrayPushString(sValues, "0|0|0|0");
   ArrayPushString(lines, /*string*/   "rt.sequence.starts="      +   JoinStrings(sValues, ","));

      ArrayResize(sValues, 0);
      if (sequence.ss.events[hSeq][I_SIZE] > 0)
         for (i=sequence.ss.events[hSeq][I_FROM]; i <= sequence.ss.events[hSeq][I_TO]; i++)
            ArrayPushString(sValues, StringConcatenate(sequence.stop.event[i], "|", sequence.stop.time[i], "|", NumberToStr(sequence.stop.price[i], ".+"), "|", NumberToStr(sequence.stop.profit[i], ".+")));
      else  ArrayPushString(sValues, "0|0|0|0");
   ArrayPushString(lines, /*string*/   "rt.sequence.stops="       +   JoinStrings(sValues, ","));

      if (sequence.weStop.active[hSeq])
   ArrayPushString(lines, /*int*/      "rt.weekendStop="          +               1);

   if (ignore.pending[hSeq][I_SIZE] > 0) {
      int iValues[]; ArrayResize(iValues, 0);
      ArrayCopy(iValues, ignore.pendingOrders, 0, ignore.pending[hSeq][I_FROM], ignore.pending[hSeq][I_SIZE]);
      ArrayPushString(lines, /*string*/"rt.ignorePendingOrders="  +      JoinInts(iValues, ","));
   }
   if (ignore.open[hSeq][I_SIZE] > 0) {
      ArrayResize(iValues, 0);
      ArrayCopy(iValues, ignore.openPositions, 0, ignore.open[hSeq][I_FROM], ignore.open[hSeq][I_SIZE]);
      ArrayPushString(lines, /*string*/"rt.ignoreOpenPositions="  +      JoinInts(iValues, ","));
   }
   if (ignore.closed[hSeq][I_SIZE] > 0) {
      ArrayResize(iValues, 0);
      ArrayCopy(iValues, ignore.closedPositions, 0, ignore.closed[hSeq][I_FROM], ignore.closed[hSeq][I_SIZE]);
      ArrayPushString(lines, /*string*/"rt.ignoreClosedPositions="+      JoinInts(iValues, ","));
   }
   ArrayPushString(lines, /*double*/   "rt.sequence.maxProfit="   +   NumberToStr(sequence.maxProfit  [hSeq], ".+"));
   ArrayPushString(lines, /*double*/   "rt.sequence.maxDrawdown=" +   NumberToStr(sequence.maxDrawdown[hSeq], ".+"));

      ArrayResize(sValues, 0);
      if (gridbase.events[hSeq][I_SIZE] > 0)
         for (i=gridbase.events[hSeq][I_FROM]; i <= gridbase.events[hSeq][I_TO]; i++)
            ArrayPushString(sValues, StringConcatenate(gridbase.event[i], "|", gridbase.time[i], "|", NumberToStr(gridbase.value[i], ".+")));
      else  ArrayPushString(sValues, "0|0|0");
   ArrayPushString(lines, /*string*/   "rt.grid.base="            +   JoinStrings(sValues, ","));

   if (orders[hSeq][I_SIZE] > 0) {
      for (i=orders[hSeq][I_FROM]; i <= orders[hSeq][I_TO]; i++) {
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
         ArrayPushString(lines, StringConcatenate("rt.order.", i-orders[hSeq][I_FROM], "=", ticket, ",", level, ",", NumberToStr(NormalizeDouble(gridBase, Digits), ".+"), ",", pendingType, ",", pendingTime, ",", NumberToStr(NormalizeDouble(pendingPrice, Digits), ".+"), ",", type, ",", openEvent, ",", openTime, ",", NumberToStr(NormalizeDouble(openPrice, Digits), ".+"), ",", closeEvent, ",", closeTime, ",", NumberToStr(NormalizeDouble(closePrice, Digits), ".+"), ",", NumberToStr(NormalizeDouble(stopLoss, Digits), ".+"), ",", clientSL, ",", closedBySL, ",", NumberToStr(swap, ".+"), ",", NumberToStr(commission, ".+"), ",", NumberToStr(profit, ".+")));
         //rt.order.{i}={ticket},{level},{gridBase},{pendingType},{pendingTime},{pendingPrice},{type},{openEvent},{openTime},{openPrice},{closeEvent},{closeTime},{closePrice},{stopLoss},{clientSL},{closedBySL},{swap},{commission},{profit}
      }
   }

   // (2) Daten speichern
   int hFile = FileOpen(GetMqlStatusFileName(hSeq), FILE_CSV|FILE_WRITE);
   if (hFile < 0)
      return(_false(catch("SaveStatus(2)->FileOpen(\""+ GetMqlStatusFileName(hSeq) +"\")")));

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

   ArrayResize(lines,   0);
   ArrayResize(sValues, 0);
   ArrayResize(iValues, 0);
   return(!last_error|catch("SaveStatus(4)"));
}


/**
 * Gibt den MQL-Namen der Statusdatei einer Sequenz zurück (relativ zu ".\files\").
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return string
 */
string GetMqlStatusFileName(int hSeq) {
   return(StringConcatenate(sequence.statusFile[hSeq][I_DIR], sequence.statusFile[hSeq][I_FILE]));
}


/**
 * Gibt den vollständigen Namen der Statusdatei einer Sequenz zurück (für Windows-Dateifunktionen).
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 *
 * @return string
 */
string GetFullStatusFileName(int hSeq) {
   if (IsTesting()) return(StringConcatenate(TerminalPath(), "\\tester\\files\\",  GetMqlStatusFileName(hSeq)));
   else             return(StringConcatenate(TerminalPath(), "\\experts\\files\\", GetMqlStatusFileName(hSeq)));
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
      instance.id = iValue; SS.Instance.Id();
      idFound     = true;
      SetCustomLog(instance.id, NULL);

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

      label = StringConcatenate(__NAME__, ".sticky.__STATUS_INVALID_INPUT");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(7)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         __STATUS_INVALID_INPUT = StrToInteger(strValue) != 0;
      }

      label = StringConcatenate(__NAME__, ".sticky.CANCELLED_BY_USER");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(_false(catch("RestoreStickyStatus(8)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE)));
         if (StrToInteger(strValue) != 0)
            SetLastError(ERR_CANCELLED_BY_USER);
      }
   }

   return(idFound && !(last_error|catch("RestoreStickyStatus(9)")));
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
                                  "Stops:         ",  str.sequence.stops  [D_LONG],  str.sequence.stopsPL[D_LONG],  NL,
                                  "Profit/Loss:   ",  str.sequence.totalPL[D_LONG],  str.sequence.plStats[D_LONG],  NL,
                                                                                                                    NL,
                                  "SHORT:     ",      s.msg,                                                        NL,
                                  "Stops:         ",  str.sequence.stops  [D_SHORT], str.sequence.stopsPL[D_SHORT], NL,
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
void SS.Instance.Id() {
   if (IsTesting()) {
      if (!SetWindowTextA(GetTesterWindow(), "Tester - SR-Dual."+ instance.id))
         catch("SS.Instance.Id()->user32::SetWindowTextA()   error="+ RtlGetLastWin32Error(), ERR_WIN32_ERROR);
   }
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von LotSize.
 */
void SS.LotSize() {
   if (!IsChart) return;

   str.instance.lotSize = NumberToStr(LotSize, ".+") +" lot = "+ DoubleToStr(GridSize * PipValue(LotSize), 2) +"/stop";
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.id
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void SS.Sequence.Id(int hSeq) {
   if (!IsChart) return;

   str.sequence.id[hSeq] = ifString(sequence.isTest[hSeq], "T", "") + sequence.id[hSeq];
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentationen von sequence.stops und sequence.stopsPL.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void SS.Sequence.Stops(int hSeq) {
   if (!IsChart) return;

   str.sequence.stops[hSeq] = StringConcatenate(sequence.stops[hSeq], " stop", ifString(sequence.stops[hSeq]==1, "", "s"));

   // Anzeige wird nicht vor der ersten ausgestoppten Position gesetzt
   if (sequence.stops[hSeq] > 0)
      str.sequence.stopsPL[hSeq] = StringConcatenate(" = ", DoubleToStr(sequence.stopsPL[hSeq], 2));
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.totalPL.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void SS.Sequence.TotalPL(int hSeq) {
   if (!IsChart) return;

   if (sequence.maxLevel[hSeq] == 0) str.sequence.totalPL[hSeq] = "-";        // Anzeige wird nicht vor der ersten offenen Position gesetzt
   else                              str.sequence.totalPL[hSeq] = NumberToStr(sequence.totalPL[hSeq], "+.2");
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.maxProfit.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void SS.Sequence.MaxProfit(int hSeq) {
   if (!IsChart) return;

   str.sequence.maxProfit[hSeq] = NumberToStr(sequence.maxProfit[hSeq], "+.2");
   SS.Sequence.PLStats(hSeq);
}


/**
 * ShowStatus(): Aktualisiert die String-Repräsentation von sequence.maxDrawdown.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void SS.Sequence.MaxDrawdown(int hSeq) {
   if (!IsChart) return;

   str.sequence.maxDrawdown[hSeq] = NumberToStr(sequence.maxDrawdown[hSeq], "+.2");
   SS.Sequence.PLStats(hSeq);
}


/**
 * ShowStatus(): Aktualisiert die kombinierte String-Repräsentation der P/L-Statistik.
 *
 * @param  int hSeq - Sequenz: D_LONG | D_SHORT
 */
void SS.Sequence.PLStats(int hSeq) {
   if (!IsChart) return;

   // Anzeige wird nicht vor der ersten offenen Position gesetzt
   if (sequence.maxLevel[hSeq] != 0)
      str.sequence.plStats[hSeq] = StringConcatenate("  (", str.sequence.maxProfit[hSeq], "/", str.sequence.maxDrawdown[hSeq], ")");
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
   ChartMarker.OrderSent(NULL, NULL);
   CheckTrendChange(NULL, NULL, NULL, NULL, NULL, NULL, iNull);
   ConfirmTick1Trade(NULL, NULL);
   CreateEventId();
   CreateSequenceId();
   FindChartSequences(sNulls, iNulls);
   GetFullStatusFileName(NULL);
   IsSequenceStatus(NULL);
   StatusToStr(NULL);
}

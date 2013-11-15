/**
 * SnowRoller-Strategy: mehrere voneinander unabhängige Sequenzen, auch je Richtung
 *
 *
 *  TODO:
 *  -----
 *  - Sequenz-IDs auf Eindeutigkeit prüfen
 *  - im Tester fortlaufende Sequenz-IDs generieren
 */
#property stacksize 32768

#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>

#include <SnowRoller/define.mqh>
#include <SnowRoller/functions.mqh>
#include <iCustom/icMovingAverage.mqh>


///////////////////////////////////////////////////////////////////// Konfiguration /////////////////////////////////////////////////////////////////////

extern            int    GridSize        = 20;
extern            double LotSize         = 0.1;
extern /*sticky*/ string StartConditions = "@trend(ALMA:3.5xD1)";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

int      last.GridSize;                                              // Input-Parameter sind nicht statisch. Extern geladene Parameter werden bei REASON_CHARTCHANGE
double   last.LotSize;                                               // mit den Default-Werten überschrieben. Um dies zu verhindern und um neue mit vorherigen Werten
string   last.StartConditions = "";                                  // vergleichen zu können, werden sie in deinit() in diesen Variablen zwischengespeichert und in
                                                                     // init() wieder daraus restauriert.
// ----------------------------------
bool     start.trend.condition;
string   start.trend.condition.txt;
double   start.trend.periods;
int      start.trend.timeframe, start.trend.timeframeFlag;           // maximal PERIOD_H1
string   start.trend.method;

bool     start.level.condition;
string   start.level.condition.txt;
int      start.level.value;

// ----------------------------------
datetime weekend.stop.condition = D'1970.01.01 23:05';               // StopSequence()-Zeitpunkt vor Wochenend-Pause (Freitags abend)
datetime weekend.stop.time;

// ----------------------------------
int      sequence.id           [];
bool     sequence.test         [];                                   // ob die Sequenz eine Testsequenz ist (im Tester oder im Online-Chart)
int      sequence.status       [];
string   sequence.statusFile   [][2];                                // [0]=>Verzeichnisname relativ zu ".\files\", [1]=>Dateiname
double   sequence.lotSize      [];
double   sequence.startEquity  [];                                   // Equity bei Start der Sequenz
bool     sequence.weStop.active[];                                   // Weekend-Stop aktiv (unterscheidet zwischen vorübergehend und dauerhaft gestoppten Sequenzen)

// ----------------------------------
int      sequence.ss.events  [][3];                                  // [0]=>from_index, [1]=>to_index, [2]=>size (Start-/Stopdaten sind synchron)

int      sequence.start.event [];                                    // Start-Daten (Moment von Statuswechsel zu STATUS_PROGRESSING)
datetime sequence.start.time  [];
double   sequence.start.price [];
double   sequence.start.profit[];

int      sequence.stop.event  [];                                    // Stop-Daten (Moment von Statuswechsel zu STATUS_STOPPED)
datetime sequence.stop.time   [];
double   sequence.stop.price  [];
double   sequence.stop.profit [];

// ----------------------------------
int      sequence.direction [];
int      grid.size          [];
int      sequence.level     [];                                      // aktueller Grid-Level
int      sequence.maxLevel  [];                                      // maximal erreichter Grid-Level
double   sequence.commission[];                                      // Commission-Betrag je Level

// ----------------------------------
int      grid.base.events[][3];                                      // [0]=>from_index, [1]=>to_index, [2]=>size

int      grid.base.event [];                                         // Gridbasis-Daten
datetime grid.base.time  [];
double   grid.base.value [];


#include <SnowRoller/init-multi.mqh>
#include <SnowRoller/deinit-multi.mqh>


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   int signal;

   if (IsStartSignal(signal)) {
      //debug("IsStartSignal()   "+ TimeToStr(TimeCurrent()) +"   signal "+ ifString(signal>0, "up", "down"));
      Strategy.CreateSequence(ifInt(signal>0, D_LONG, D_SHORT));
   }
   return(last_error);
}


/**
 * Erzeugt und startet eine neue Sequenz.
 *
 * @param  int direction - D_LONG | D_SHORT
 *
 * @return int - ID der erzeugten Sequenz (>= SID_MIN) oder Sequenz-Management-Code (< SID_MIN);
 *               0, falls ein Fehler auftrat
 */
int Strategy.CreateSequence(int direction) {
   if (__STATUS_ERROR)                                   return(0);
   if (direction!=D_LONG) /*&&*/ if (direction!=D_SHORT) return(_NULL(catch("Strategy.CreateSequence(1)   illegal parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));

   // (1) Sequenz erzeugen
   int    sid      = CreateSequenceId();
   bool   test     = IsTesting();
   int    gridSize = GridSize;
   double lotSize  = LotSize;
   int    status   = STATUS_WAITING;


   // TODO: Sequence-Management einbauen
   if (sid < SID_MIN) {
      if (sid == 0)
         return(0);
      return(_int(sid, debug("Strategy.CreateSequence()   "+ directionDescr[direction] +" sequence denied")));
   }

   int hSeq = Strategy.AddSequence(sid, test, direction, gridSize, lotSize, status);
   if (hSeq < 0)
      return(0);
   debug("Strategy.CreateSequence()   "+ directionDescr[direction] +" sequence created: "+ sid);


   // (2) Sequenz starten
   if (!StartSequence(hSeq))
      return(0);

   return(sid);
}


/**
 * Startet eine noch neue Trade-Sequenz.
 *
 * @param  int hSeq - Sequenz-Handle (Verwaltungsindex der Sequenz)
 *
 * @return bool - Erfolgsstatus
 */
bool StartSequence(int hSeq) {
   if (__STATUS_ERROR)                             return(false);
   if (hSeq < 0 || hSeq >= ArraySize(sequence.id)) return(!catch("StartSequence(1)   invalid parameter hSeq = "+ hSeq, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (sequence.status[hSeq] != STATUS_WAITING)    return(!catch("StartSequence(2)   cannot start "+ sequenceStatusDescr[sequence.status[hSeq]] +" sequence "+ sequence.id[hSeq], ERR_RUNTIME_ERROR));

   if (Tick==1) /*&&*/ if (!ConfirmTick1Trade("StartSequence()", "Do you really want to start the new sequence "+ sequence.id[hSeq] +" now?"))
      return(!SetLastError(ERR_CANCELLED_BY_USER));

   if (__LOG) log("StartSequence()   starting sequence "+ sequence.id[hSeq]);
   SetCustomLog(sequence.id[hSeq], NULL);                            // TODO: statt Sequenz-ID Log-Handle verwenden
   if (__LOG) log("StartSequence()   starting sequence");


   sequence.status[hSeq] = STATUS_STARTING;


   // (1) Startvariablen setzen
   datetime startTime  = TimeCurrent();
   double   startPrice = ifDouble(sequence.direction[hSeq]==D_SHORT, Bid, Ask);

   ArrayPushInt   (sequence.start.event,  CreateEventId());
   ArrayPushInt   (sequence.start.time,   startTime      );
   ArrayPushDouble(sequence.start.price,  startPrice     );
   ArrayPushDouble(sequence.start.profit, 0              );

   ArrayPushInt   (sequence.stop.event,   0);                        // Größe von sequence.starts/stops synchron halten
   ArrayPushInt   (sequence.stop.time,    0);
   ArrayPushDouble(sequence.stop.price,   0);
   ArrayPushDouble(sequence.stop.profit,  0);

   sequence.startEquity[hSeq] = NormalizeDouble(AccountEquity()-AccountCredit(), 2);


   // (2) Gridbasis setzen (zeitlich nach sequence.start.time)
   double gridBase = startPrice;
   if (start.level.condition) {
      sequence.level   [hSeq] = ifInt(sequence.direction[hSeq]==D_LONG, start.level.value, -start.level.value);
      sequence.maxLevel[hSeq] = sequence.level[hSeq];
      gridBase            = NormalizeDouble(startPrice - sequence.level[hSeq]*grid.size[hSeq]*Pips, Digits);
   }
   GridBase.Reset(hSeq, startTime, gridBase);


   // (3) ggf. Startpositionen in den Markt legen und Sequenzstart-Price aktualisieren
   if (sequence.level[hSeq] != 0) {
      int iNull;
      if (!UpdateOpenPositions(hSeq, iNull, startPrice))
         return(false);
      return(!catch("StartSequence(3.1)", ERR_NOT_IMPLEMENTED));
      sequence.start.price[ArraySize(sequence.start.price)-1] = startPrice;
   }


   sequence.status[hSeq] = STATUS_PROGRESSING;


   // (4) Stop-Orders in den Markt legen
   if (!UpdatePendingOrders(hSeq))
      return(false);


   // (5) Weekend-Stop aktualisieren
   UpdateWeekendStop();
   sequence.weStop.active[hSeq] = false;


   RedrawStartStop(hSeq);
   if (__LOG) log(StringConcatenate("StartSequence()   sequence started at ", NumberToStr(startPrice, PriceFormat), ifString(sequence.level[hSeq], " and level "+ sequence.level[hSeq], "")));
   return(!last_error|catch("StartSequence(3)"));
}


/**
 * Zeichnet die Start-/Stop-Marker der Sequenz neu.
 *
 * @param  int hSeq - Sequenz-Handle
 */
void RedrawStartStop(int hSeq) {
   if (__STATUS_ERROR)                             return;
   if (!IsChart)                                   return;
   if (hSeq < 0 || hSeq >= ArraySize(sequence.id)) return(_NULL(catch("RedrawStartStop(1)   invalid parameter hSeq = "+ hSeq, ERR_INVALID_FUNCTION_PARAMVALUE)));

   return(_NULL(catch("RedrawStartStop(2)", ERR_NOT_IMPLEMENTED)));
}


/**
 * Aktualisiert die Stopbedingung für die nächste Wochenend-Pause.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateWeekendStop() {
   if (__STATUS_ERROR)
      return(false);

   datetime friday, now=ServerToFST(TimeCurrent());

   switch (TimeDayOfWeek(now)) {
      case SUNDAY   : friday = now + 5*DAYS; break;
      case MONDAY   : friday = now + 4*DAYS; break;
      case TUESDAY  : friday = now + 3*DAYS; break;
      case WEDNESDAY: friday = now + 2*DAYS; break;
      case THURSDAY : friday = now + 1*DAY ; break;
      case FRIDAY   : friday = now + 0*DAYS; break;
      case SATURDAY : friday = now + 6*DAYS; break;
   }
   weekend.stop.time = FSTToServerTime((friday/DAYS)*DAYS + weekend.stop.condition%DAY);

   return(!last_error|catch("UpdateWeekendStop()"));
}


/**
 * Erzeugt und startet eine neue Sequenz.
 *
 * @param  int    sid       - Sequenz-ID
 * @param  bool   test      - Teststatus der Sequenz
 * @param  int    direction - D_LONG | D_SHORT
 * @param  int    gridSize  - Gridsize der Sequenz
 * @param  double lotSize   - Lotsize der Sequenz
 * @param  int    status    - Laufzeit-Status der Sequenz
 *
 * @return int - Sequenz-Handle (Verwaltungsindex) oder -1, falls ein Fehler auftrat;
 */
int Strategy.AddSequence(int sid, bool test, int direction, int gridSize, double lotSize, int status) {
   if (__STATUS_ERROR)                                   return(-1);
   if (sid < SID_MIN || sid > SID_MAX)                   return(_int(-1, catch("Strategy.AddSequence(1)   invalid parameter sid = "+ sid, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (IntInArray(sequence.id, sid))                     return(_int(-1, catch("Strategy.AddSequence(2)   sequence "+ sid +" already exists", ERR_RUNTIME_ERROR)));
   if (BoolInArray(sequence.test, !test))                return(_int(-1, catch("Strategy.AddSequence(3)   illegal mix of test/non-test sequences: tried to add "+ sid +" (test="+ test +"), found "+ sequence.id[SearchBoolArray(sequence.test, !test)] +" (test="+ (!test) +")", ERR_RUNTIME_ERROR)));
   if (direction!=D_LONG) /*&&*/ if (direction!=D_SHORT) return(_int(-1, catch("Strategy.AddSequence(4)   invalid parameter direction = "+ direction, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (gridSize <= 0)                                    return(_int(-1, catch("Strategy.AddSequence(5)   invalid parameter gridSize = "+ gridSize, ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (lotSize <= 0)                                     return(_int(-1, catch("Strategy.AddSequence(6)   invalid parameter lotSize = "+ NumberToStr(lotSize, ".+"), ERR_INVALID_FUNCTION_PARAMVALUE)));
   if (!IsValidSequenceStatus(status))                   return(_int(-1, catch("Strategy.AddSequence(7)   invalid parameter status = "+ status, ERR_INVALID_FUNCTION_PARAMVALUE)));

   int size=ArraySize(sequence.id), hSeq=size;
   Strategy.ResizeArrays(size+1);

   sequence.id       [hSeq] = sid;
   sequence.test     [hSeq] = test;
   sequence.status   [hSeq] = status;
   sequence.lotSize  [hSeq] = lotSize;
   sequence.direction[hSeq] = direction;
   grid.size         [hSeq] = gridSize;

   InitStatusLocation(hSeq);

   return(hSeq);
}


/**
 * Löscht alle gespeicherten Änderungen der Gridbasis und initialisiert sie mit dem angegebenen Wert.
 *
 * @param  int      hSeq  - Sequenz-Handle
 * @param  datetime time  - Zeitpunkt
 * @param  double   value - neue Gridbasis
 *
 * @return double - neue Gridbasis (for chaining) oder 0, falls ein Fehler auftrat
 */
double GridBase.Reset(int hSeq, datetime time, double value) {
   if (__STATUS_ERROR)                             return(0);
   if (hSeq < 0 || hSeq >= ArraySize(sequence.id)) return(_ZERO(catch("GridBase.Reset(1)   invalid parameter hSeq = "+ hSeq, ERR_INVALID_FUNCTION_PARAMVALUE)));

   return(_ZERO(catch("GridBase.Reset(2)", ERR_NOT_IMPLEMENTED)));
}


/**
 * Öffnet neue bzw. vervollständigt fehlende offene Positionen einer Sequenz. Aufruf nur in StartSequence() und ResumeSequence().
 *
 * @param  int       hSeq        - Sequenz-Handle (Verwaltungsindex)
 * @param  datetime &lpOpenTime  - Zeiger auf Variable, die die OpenTime der zuletzt geöffneten Position aufnimmt
 * @param  double   &lpOpenPrice - Zeiger auf Variable, die den durchschnittlichen OpenPrice aufnimmt
 *
 * @return bool - Erfolgsstatus
 *
 *
 * NOTE: Im Level 0 (keine Positionen zu öffnen) werden die Variablen, auf die die übergebenen Pointer zeigen, nicht modifiziert.
 */
bool UpdateOpenPositions(int hSeq, datetime &lpOpenTime, double &lpOpenPrice) {
   if (__STATUS_ERROR)                               return(false);
   if (hSeq < 0 || hSeq >= ArraySize(sequence.id))   return(!catch("UpdateOpenPositions(1)   invalid parameter hSeq = "+ hSeq, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (sequence.status[hSeq] != STATUS_STARTING)     return(!catch("UpdateOpenPositions(2)   cannot update positions of "+ sequenceStatusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR));
   if (sequence.test[hSeq]) /*&&*/ if (!IsTesting()) return(!catch("UpdateOpenPositions(3)", ERR_ILLEGAL_STATE));

   return(!catch("UpdateOpenPositions(4)", ERR_NOT_IMPLEMENTED));
}


/**
 * Aktualisiert vorhandene, setzt fehlende und löscht unnötige PendingOrders.
 *
 * @param  int hSeq - Sequenz-Handle (Verwaltungsindex)
 *
 * @return bool - Erfolgsstatus
 */
bool UpdatePendingOrders(int hSeq) {
   if (__STATUS_ERROR)                               return(false);
   if (hSeq < 0 || hSeq >= ArraySize(sequence.id))   return(!catch("UpdatePendingOrders(1)   invalid parameter hSeq = "+ hSeq, ERR_INVALID_FUNCTION_PARAMVALUE));
   if (sequence.status[hSeq] != STATUS_PROGRESSING)  return(!catch("UpdatePendingOrders(2)   cannot update orders of "+ sequenceStatusDescr[sequence.status[hSeq]] +" sequence", ERR_RUNTIME_ERROR));
   if (sequence.test[hSeq]) /*&&*/ if (!IsTesting()) return(!catch("UpdatePendingOrders(3)", ERR_ILLEGAL_STATE));

   return(!catch("UpdatePendingOrders(4)", ERR_NOT_IMPLEMENTED));
}


/**
 * Initialisiert die Dateinamensvariablen der Statusdatei mit den Ausgangswerten einer neuen Sequenz.
 *
 * @param  int hSeq - Sequenz-Handle
 *
 * @return bool - Erfolgsstatus
 */
bool InitStatusLocation(int hSeq) {
   if (__STATUS_ERROR)                             return(false);
   if (hSeq < 0 || hSeq >= ArraySize(sequence.id)) return(!catch("InitStatusLocation(1)   invalid parameter hSeq = "+ hSeq, ERR_INVALID_FUNCTION_PARAMVALUE));

   if      (IsTesting())         sequence.statusFile[hSeq][0] = "presets\\";
   else if (sequence.test[hSeq]) sequence.statusFile[hSeq][0] = "presets\\tester\\";
   else                          sequence.statusFile[hSeq][0] = "presets\\"+ ShortAccountCompany() +"\\";

   sequence.statusFile[hSeq][1] = StringConcatenate(StringToLower(StdSymbol()), ".SR.", sequence.id[hSeq], ".set");

   return(!catch("InitStatusLocation(2)"));
}


/**
 * Setzt die Größe der Arrays für die Sequenzverwaltung auf den angegebenen Wert.
 *
 * @param  int size - neue Größe
 *
 * @return int - neue Größe der Arrays
 */
int Strategy.ResizeArrays(int size) {
   int oldSize = ArraySize(sequence.id);

   if (size != oldSize) {
      ArrayResize(sequence.id,            size);
      ArrayResize(sequence.test,          size);
      ArrayResize(sequence.status,        size);
      ArrayResize(sequence.statusFile,    size);
      ArrayResize(sequence.lotSize,       size);
      ArrayResize(sequence.startEquity,   size);
      ArrayResize(sequence.ss.events,     size);
      ArrayResize(sequence.weStop.active, size);

      ArrayResize(sequence.direction,     size);
      ArrayResize(grid.size,              size);
      ArrayResize(sequence.level,         size);
      ArrayResize(sequence.maxLevel,      size);
      ArrayResize(sequence.commission,    size);
      ArrayResize(grid.base.events,       size);
   }
   return(size);
}


/**
 * Signalgeber für Start einer neuen Sequence
 *
 * @param  int lpSignal - Zeiger auf Variable zur Signalaufnahme (+: Buy-Signal, -: Sell-Signal)
 *
 * @return bool - ob ein Signal aufgetreten ist
 */
bool IsStartSignal(int &lpSignal) {
   if (__STATUS_ERROR)
      return(false);

   lpSignal = 0;

   // -- start.trend: bei Trendwechsel erfüllt -----------------------------------------------------------------------
   if (start.trend.condition) {
      int iNull[];
      if (EventListener.BarOpen(iNull, start.trend.timeframeFlag)) {
         int    timeframe   = start.trend.timeframe;
         string maPeriods   = NumberToStr(start.trend.periods, ".+");
         string maTimeframe = PeriodDescription(start.trend.timeframe);
         string maMethod    = start.trend.method;

         int trend = icMovingAverage(timeframe, maPeriods, maTimeframe, maMethod, "Close", MovingAverage.MODE_TREND, 1);
         if (!trend) {
            int error = stdlib_GetLastError();
            if (IsError(error))
               SetLastError(error);
            return(false);
         }

         if (trend==1 || trend==-1) {
            lpSignal = trend;
            if (__LOG) log(StringConcatenate("IsStartSignal()   start signal \"", start.trend.condition.txt, "\" ", ifString(trend > 0, "up", "down")));
                     debug(StringConcatenate("IsStartSignal()   start signal \"", start.trend.condition.txt, "\" ", ifString(trend > 0, "up", "down")));
            return(true);
         }
      }
   }
   return(false);
}


/**
 * Speichert die aktuelle Konfiguration zwischen, um sie bei Fehleingaben nach Parameteränderungen restaurieren zu können.
 */
void StoreConfiguration(bool save=true) {
   static int    _GridSize;
   static double _LotSize;
   static string _StartConditions;

   static bool   _start.trend.condition;
   static string _start.trend.condition.txt;
   static double _start.trend.periods;
   static int    _start.trend.timeframe;
   static int    _start.trend.timeframeFlag;
   static string _start.trend.method;

   static bool   _start.level.condition;
   static string _start.level.condition.txt;
   static int    _start.level.value;

   if (save) {
      _GridSize                  = GridSize;
      _LotSize                   = LotSize;
      _StartConditions           = StringConcatenate(StartConditions, "");  // Pointer-Bug bei String-Inputvariablen (siehe MQL.doc)

      _start.trend.condition     = start.trend.condition;
      _start.trend.condition.txt = start.trend.condition.txt;
      _start.trend.periods       = start.trend.periods;
      _start.trend.timeframe     = start.trend.timeframe;
      _start.trend.timeframeFlag = start.trend.timeframeFlag;
      _start.trend.method        = start.trend.method;

      _start.level.condition     = start.level.condition;
      _start.level.condition.txt = start.level.condition.txt;
      _start.level.value         = start.level.value;
   }
   else {
      GridSize                   = _GridSize;
      LotSize                    = _LotSize;
      StartConditions            = _StartConditions;

      start.trend.condition      = _start.trend.condition;
      start.trend.condition.txt  = _start.trend.condition.txt;
      start.trend.periods        = _start.trend.periods;
      start.trend.timeframe      = _start.trend.timeframe;
      start.trend.timeframeFlag  = _start.trend.timeframeFlag;
      start.trend.method         = _start.trend.method;

      start.level.condition      = _start.level.condition;
      start.level.condition.txt  = _start.level.condition.txt;
      start.level.value          = _start.level.value;
   }
}


/**
 * Restauriert eine zuvor gespeicherte Konfiguration.
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


   // (3) GridSize
   if (GridSize < 1)                             return(_false(ValidateConfig.HandleError("ValidateConfiguration(1)", "Invalid GridSize = "+ GridSize, interactive)));


   // (4) LotSize
   if (LE(LotSize, 0))                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(2)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+"), interactive)));
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT );
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT );
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int error = GetLastError();
   if (IsError(error))                           return(_false(catch("ValidateConfiguration(3)   symbol=\""+ Symbol() +"\"", error)));
   if (LT(LotSize, minLot))                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(4)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", interactive)));
   if (GT(LotSize, maxLot))                      return(_false(ValidateConfig.HandleError("ValidateConfiguration(5)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", interactive)));
   if (MathModFix(LotSize, lotStep) != 0)        return(_false(ValidateConfig.HandleError("ValidateConfiguration(6)", "Invalid LotSize = "+ NumberToStr(LotSize, ".+") +" (LotStep="+ NumberToStr(lotStep, ".+") +")", interactive)));


   // (5) StartConditions, AND-verknüpft: "(@trend(xxMA:7xD1[+1] && @level(3)"
   // ----------------------------------------------------------------------------------------------------------------------
   if (!reasonParameters || StartConditions!=last.StartConditions) {
      start.trend.condition = false;
      start.level.condition = false;

      // (5.1) StartConditions in einzelne Ausdrücke zerlegen
      string exprs[], expr, elems[], key, value;
      int    iValue, time, sizeOfElems, sizeOfExprs=Explode(StartConditions, "&&", exprs, NULL);
      double dValue;

      // (5.2) jeden Ausdruck parsen und validieren
      for (int i=0; i < sizeOfExprs; i++) {
         expr = StringToLower(StringTrim(exprs[i]));
         if (StringLen(expr) == 0) {
            if (sizeOfExprs > 1)                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(7)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')            return(_false(ValidateConfig.HandleError("ValidateConfiguration(8)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         if (Explode(expr, "(", elems, NULL) != 2)     return(_false(ValidateConfig.HandleError("ValidateConfiguration(9)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         if (!StringEndsWith(elems[1], ")"))           return(_false(ValidateConfig.HandleError("ValidateConfiguration(10)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
         key   = StringTrim(elems[0]);
         value = StringTrim(StringLeft(elems[1], -1));
         if (StringLen(value) == 0)                    return(_false(ValidateConfig.HandleError("ValidateConfiguration(11)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));

         if (key == "@trend") {
            if (start.trend.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(12)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple trend conditions)", interactive)));
            if (Explode(value, ":", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(13)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            key   = StringToUpper(StringTrim(elems[0]));
            value = StringToUpper(elems[1]);
            // key="ALMA"
            if      (key == "SMA" ) start.trend.method = key;
            else if (key == "EMA" ) start.trend.method = key;
            else if (key == "SMMA") start.trend.method = key;
            else if (key == "LWMA") start.trend.method = key;
            else if (key == "ALMA") start.trend.method = key;
            else                                       return(_false(ValidateConfig.HandleError("ValidateConfiguration(14)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            // value="7XD1"
            if (Explode(value, "X", elems, NULL) != 2) return(_false(ValidateConfig.HandleError("ValidateConfiguration(15)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            elems[1]              = StringTrim(elems[1]);
            start.trend.timeframe = StrToPeriod(elems[1]);
            if (start.trend.timeframe == -1)           return(_false(ValidateConfig.HandleError("ValidateConfiguration(16)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            value = StringTrim(elems[0]);
            if (!StringIsNumeric(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(17)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            dValue = StrToDouble(value);
            if (dValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(18)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            if (MathModFix(dValue, 0.5) != 0)          return(_false(ValidateConfig.HandleError("ValidateConfiguration(19)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            elems[0] = NumberToStr(dValue, ".+");
            switch (start.trend.timeframe) {           // Timeframes > H1 auf H1 umrechnen, iCustom() soll unabhängig vom MA mit maximal PERIOD_H1 laufen
               case PERIOD_MN1:                        return(_false(ValidateConfig.HandleError("ValidateConfiguration(20)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
               case PERIOD_H4 : dValue *=   4; start.trend.timeframe = PERIOD_H1; break;
               case PERIOD_D1 : dValue *=  24; start.trend.timeframe = PERIOD_H1; break;
               case PERIOD_W1 : dValue *= 120; start.trend.timeframe = PERIOD_H1; break;
            }
            start.trend.periods       = NormalizeDouble(dValue, 1);
            start.trend.timeframeFlag = PeriodFlag(start.trend.timeframe);
            start.trend.condition     = true;
            start.trend.condition.txt = "@trend("+ start.trend.method +":"+ elems[0] +"x"+ elems[1] +")";
            exprs[i]                  = start.trend.condition.txt;
         }

         else if (key == "@level") {
            if (start.level.condition)                 return(_false(ValidateConfig.HandleError("ValidateConfiguration(21)", "Invalid StartConditions = \""+ StartConditions +"\" (multiple level conditions)", interactive)));
            if (!StringIsInteger(value))               return(_false(ValidateConfig.HandleError("ValidateConfiguration(22)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            iValue = StrToInteger(value);
            if (iValue <= 0)                           return(_false(ValidateConfig.HandleError("ValidateConfiguration(23)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
            if (ArraySize(sequence.start.event) != 0)  return(_false(ValidateConfig.HandleError("ValidateConfiguration(24)", "Invalid StartConditions = \""+ StartConditions +"\" (illegal level statement)", interactive)));
            start.level.condition     = true;
            start.level.value         = iValue;
            start.level.condition.txt = key +"("+ iValue +")";
            exprs[i]                  = start.level.condition.txt;
         }
         else                                          return(_false(ValidateConfig.HandleError("ValidateConfiguration(25)", "Invalid StartConditions = \""+ StartConditions +"\"", interactive)));
      }
      StartConditions = JoinStrings(exprs, " && ");
   }


   // (8) __STATUS_INVALID_INPUT zurücksetzen
   if (interactive)
      __STATUS_INVALID_INPUT = false;

   return(!last_error|catch("ValidateConfiguration(26)"));
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
 * Speichert die Konfiguartionsdaten des EA's im Chart, sodaß der Status nach einem Recompile oder Terminal-Restart daraus wiederhergestellt werden kann.
 * Diese Werte umfassen die Input-Parameter, das Flag __STATUS_INVALID_INPUT und den Fehler ERR_CANCELLED_BY_USER.
 *
 * @return int - Fehlerstatus
 */
int StoreStickyStatus() {
   string label = StringConcatenate(__NAME__, ".sticky.StartConditions");
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, EMPTY);                           // hidden on all timeframes
   ObjectSetText(label, StartConditions, 1);

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
   ObjectSetText(label, StringConcatenate("", (last_error==ERR_CANCELLED_BY_USER)), 1);

   return(catch("StoreStickyStatus()"));
}


/**
 * Restauriert die im Chart gespeicherten Konfigurationsdaten.
 *
 * @return bool - ob gespeicherte Daten gefunden wurden
 */
bool RestoreStickyStatus() {
   string label, strValue;
   bool   statusFound;

   label = StringConcatenate(__NAME__, ".sticky.StartConditions");
   if (ObjectFind(label) == 0) {
      StartConditions = StringTrim(ObjectDescription(label));
      statusFound     = true;

      label = StringConcatenate(__NAME__, ".sticky.__STATUS_INVALID_INPUT");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(!catch("RestoreStickyStatus(1)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
         __STATUS_INVALID_INPUT = StrToInteger(strValue) != 0;
      }

      label = StringConcatenate(__NAME__, ".sticky.CANCELLED_BY_USER");
      if (ObjectFind(label) == 0) {
         strValue = StringTrim(ObjectDescription(label));
         if (!StringIsDigit(strValue))
            return(!catch("RestoreStickyStatus(2)   illegal chart value "+ label +" = \""+ ObjectDescription(label) +"\"", ERR_INVALID_CONFIG_PARAMVALUE));
         if (StrToInteger(strValue) != 0)
            SetLastError(ERR_CANCELLED_BY_USER);
      }
   }

   return(statusFound && !(last_error|catch("RestoreStickyStatus(3)")));
}


/**
 * Löscht alle im Chart gespeicherten Konfigurationsdaten.
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
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int    iNulls[];
   string sNulls[];
   FindChartSequences(sNulls, iNulls);
   IsSequenceStatus(NULL);
   IsStopTriggered(NULL, NULL);
   StatusToStr(NULL);
}

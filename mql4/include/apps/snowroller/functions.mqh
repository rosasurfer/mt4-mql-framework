/**
 * Shared functions used by SnowRoller and Sisyphus
 */


/**
 * Handle incoming commands.
 *
 * @param  string commands[] - received commands
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string commands[]) {
   if (!ArraySize(commands)) return(!logWarn("onCommand(1)  "+ sequence.longName +" empty parameter commands: {}"));

   string cmd = commands[0];

   // wait
   if (cmd == "wait") {
      if (IsTestSequence() && !IsTesting())
         return(true);

      switch (sequence.status) {
         case STATUS_STOPPED:
            if (!start.conditions)                       // whether any start condition is active
               return(!logWarn("onCommand(2)  "+ sequence.longName +" cannot execute \"wait\" command for sequence "+ sequence.name +"."+ NumberToStr(sequence.level, "+.") +" (no active start conditions found)"));
            sequence.status = STATUS_WAITING;
      }
      return(true);
   }

   // start
   if (cmd == "start") {
      if (IsTestSequence() && !IsTesting())
         return(true);

      switch (sequence.status) {
         case STATUS_WAITING:
         case STATUS_STOPPED:
            bool neverStarted = !ArraySize(sequence.start.event);
            if (neverStarted) return(StartSequence(NULL));
            else              return(ResumeSequence(NULL));

      }
      return(true);
   }

   // stop
   if (cmd == "stop") {
      if (IsTestSequence() && !IsTesting())
         return(true);

      switch (sequence.status) {
         case STATUS_PROGRESSING:
            bool bNull;
            if (!UpdateStatus(bNull)) return(false);     // fall-through to STATUS_WAITING
         case STATUS_WAITING:
            return(StopSequence(NULL));
      }
      return(true);
   }

   if (cmd ==     "orderdisplay") return(ToggleOrderDisplayMode());
   if (cmd == "startstopdisplay") return(ToggleStartStopDisplayMode());

   // log unknown commands and let the EA continue
   return(!logWarn("onCommand(3)  "+ sequence.longName +" unknown command: "+ DoubleQuoteStr(cmd)));
}


string   last.Sequence.ID = "";
string   last.GridDirection = "";
int      last.GridSize;
string   last.UnitSize;
int      last.StartLevel;
string   last.StartConditions = "";
string   last.StopConditions = "";
string   last.AutoRestart;
bool     last.ShowProfitInPercent;
datetime last.Sessionbreak.StartTime;
datetime last.Sessionbreak.EndTime;


/**
 * Input parameters changed by the code don't survive init cycles. Therefore inputs are backed-up in deinit() and can be
 * restored in init(). Called only from onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
   // backed-up inputs are also accessed from ValidateInputs()
   last.Sequence.ID            = StringConcatenate(Sequence.ID,   "");     // string inputs are references to internal C literals
   last.GridDirection          = StringConcatenate(GridDirection, "");     // and must be copied to break the reference
   last.GridSize               = GridSize;
   last.UnitSize               = UnitSize;
   last.StartLevel             = StartLevel;
   last.StartConditions        = StringConcatenate(StartConditions, "");
   last.StopConditions         = StringConcatenate(StopConditions,  "");
   last.AutoRestart            = AutoRestart;
   last.ShowProfitInPercent    = ShowProfitInPercent;
   last.Sessionbreak.StartTime = Sessionbreak.StartTime;
   last.Sessionbreak.EndTime   = Sessionbreak.EndTime;
}


/**
 * Restore backed-up input parameters. Called only from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
   Sequence.ID            = last.Sequence.ID;
   GridDirection          = last.GridDirection;
   GridSize               = last.GridSize;
   UnitSize               = last.UnitSize;
   StartLevel             = last.StartLevel;
   StartConditions        = last.StartConditions;
   StopConditions         = last.StopConditions;
   AutoRestart            = last.AutoRestart;
   ShowProfitInPercent    = last.ShowProfitInPercent;
   Sessionbreak.StartTime = last.Sessionbreak.StartTime;
   Sessionbreak.EndTime   = last.Sessionbreak.EndTime;
}


/**
 * Backup status variables which may change due to modified input parameters. This way status can be restored in case of input
 * errors. Called only from onInitParameters().
 */
void BackupInputStatus() {
   CopyInputStatus(true);
}


/**
 * Restore status variables from the backup. Called only from onInitParameters().
 */
void RestoreInputStatus() {
   CopyInputStatus(false);
}


/**
 * Backup or restore status variables related to input parameter changes. Called only from BackupInputStatus() and
 * RestoreInputStatus() in onInitParameters().
 *
 * @param  bool store - TRUE:  copy status to internal storage (backup)
 *                      FALSE: copy internal storage to status (restore)
 */
void CopyInputStatus(bool store) {
   store = store!=0;

   static int      _sequence.id;
   static int      _sequence.cycle;
   static string   _sequence.name     = "";
   static string   _sequence.longName = "";
   static datetime _sequence.created;
   static bool     _sequence.isTest;
   static int      _sequence.direction;
   static int      _sequence.status;

   static bool     _start.conditions;
   static bool     _start.trend.condition;
   static string   _start.trend.indicator   = "";
   static int      _start.trend.timeframe;
   static string   _start.trend.params      = "";
   static string   _start.trend.description = "";
   static bool     _start.price.condition;
   static int      _start.price.type;
   static double   _start.price.value;
   static string   _start.price.description = "";
   static bool     _start.time.condition;
   static datetime _start.time.value;
   static string   _start.time.description  = "";

   static bool     _stop.trend.condition;
   static string   _stop.trend.indicator    = "";
   static int      _stop.trend.timeframe;
   static string   _stop.trend.params       = "";
   static string   _stop.trend.description  = "";
   static bool     _stop.price.condition;
   static int      _stop.price.type;
   static double   _stop.price.value;
   static string   _stop.price.description  = "";
   static bool     _stop.time.condition;
   static datetime _stop.time.value;
   static string   _stop.time.description   = "";
   static bool     _stop.profitAbs.condition;
   static double   _stop.profitAbs.value;
   static string   _stop.profitAbs.description = "";
   static bool     _stop.profitPct.condition;
   static double   _stop.profitPct.value;
   static double   _stop.profitPct.absValue;
   static string   _stop.profitPct.description = "";
   static bool     _stop.lossAbs.condition;
   static double   _stop.lossAbs.value;
   static string   _stop.lossAbs.description = "";
   static bool     _stop.lossPct.condition;
   static double   _stop.lossPct.value;
   static double   _stop.lossPct.absValue;
   static string   _stop.lossPct.description = "";

   static datetime _sessionbreak.starttime;
   static datetime _sessionbreak.endtime;

   if (store) {
      _sequence.id                = sequence.id;
      _sequence.cycle             = sequence.cycle;
      _sequence.name              = sequence.name;
      _sequence.longName          = sequence.longName;
      _sequence.created           = sequence.created;
      _sequence.isTest            = sequence.isTest;
      _sequence.direction         = sequence.direction;
      _sequence.status            = sequence.status;

      _start.conditions           = start.conditions;
      _start.trend.condition      = start.trend.condition;
      _start.trend.indicator      = start.trend.indicator;
      _start.trend.timeframe      = start.trend.timeframe;
      _start.trend.params         = start.trend.params;
      _start.trend.description    = start.trend.description;
      _start.price.condition      = start.price.condition;
      _start.price.type           = start.price.type;
      _start.price.value          = start.price.value;
      _start.price.description    = start.price.description;
      _start.time.condition       = start.time.condition;
      _start.time.value           = start.time.value;
      _start.time.description     = start.time.description;

      _stop.trend.condition       = stop.trend.condition;
      _stop.trend.indicator       = stop.trend.indicator;
      _stop.trend.timeframe       = stop.trend.timeframe;
      _stop.trend.params          = stop.trend.params;
      _stop.trend.description     = stop.trend.description;
      _stop.price.condition       = stop.price.condition;
      _stop.price.type            = stop.price.type;
      _stop.price.value           = stop.price.value;
      _stop.price.description     = stop.price.description;
      _stop.time.condition        = stop.time.condition;
      _stop.time.value            = stop.time.value;
      _stop.time.description      = stop.time.description;
      _stop.profitAbs.condition   = stop.profitAbs.condition;
      _stop.profitAbs.value       = stop.profitAbs.value;
      _stop.profitAbs.description = stop.profitAbs.description;
      _stop.profitPct.condition   = stop.profitPct.condition;
      _stop.profitPct.value       = stop.profitPct.value;
      _stop.profitPct.absValue    = stop.profitPct.absValue;
      _stop.profitPct.description = stop.profitPct.description;
      _stop.lossAbs.condition     = stop.lossAbs.condition;
      _stop.lossAbs.value         = stop.lossAbs.value;
      _stop.lossAbs.description   = stop.lossAbs.description;
      _stop.lossPct.condition     = stop.lossPct.condition;
      _stop.lossPct.value         = stop.lossPct.value;
      _stop.lossPct.absValue      = stop.lossPct.absValue;
      _stop.lossPct.description   = stop.lossPct.description;

      _sessionbreak.starttime     = sessionbreak.starttime;
      _sessionbreak.endtime       = sessionbreak.endtime;
   }
   else {
      sequence.id                = _sequence.id;
      sequence.cycle             = _sequence.cycle;
      sequence.name              = _sequence.name;
      sequence.longName          = _sequence.longName;
      sequence.created           = _sequence.created;
      sequence.isTest            = _sequence.isTest;
      sequence.direction         = _sequence.direction;
      sequence.status            = _sequence.status;

      start.conditions           = _start.conditions;
      start.trend.condition      = _start.trend.condition;
      start.trend.indicator      = _start.trend.indicator;
      start.trend.timeframe      = _start.trend.timeframe;
      start.trend.params         = _start.trend.params;
      start.trend.description    = _start.trend.description;
      start.price.condition      = _start.price.condition;
      start.price.type           = _start.price.type;
      start.price.value          = _start.price.value;
      start.price.description    = _start.price.description;
      start.time.condition       = _start.time.condition;
      start.time.value           = _start.time.value;
      start.time.description     = _start.time.description;

      stop.trend.condition       = _stop.trend.condition;
      stop.trend.indicator       = _stop.trend.indicator;
      stop.trend.timeframe       = _stop.trend.timeframe;
      stop.trend.params          = _stop.trend.params;
      stop.trend.description     = _stop.trend.description;
      stop.price.condition       = _stop.price.condition;
      stop.price.type            = _stop.price.type;
      stop.price.value           = _stop.price.value;
      stop.price.description     = _stop.price.description;
      stop.time.condition        = _stop.time.condition;
      stop.time.value            = _stop.time.value;
      stop.time.description      = _stop.time.description;
      stop.profitAbs.condition   = _stop.profitAbs.condition;
      stop.profitAbs.value       = _stop.profitAbs.value;
      stop.profitAbs.description = _stop.profitAbs.description;
      stop.profitPct.condition   = _stop.profitPct.condition;
      stop.profitPct.value       = _stop.profitPct.value;
      stop.profitPct.absValue    = _stop.profitPct.absValue;
      stop.profitPct.description = _stop.profitPct.description;
      stop.lossAbs.condition     = _stop.lossAbs.condition;
      stop.lossAbs.value         = _stop.lossAbs.value;
      stop.lossAbs.description   = _stop.lossAbs.description;
      stop.lossPct.condition     = _stop.lossPct.condition;
      stop.lossPct.value         = _stop.lossPct.value;
      stop.lossPct.absValue      = _stop.lossPct.absValue;
      stop.lossPct.description   = _stop.lossPct.description;

      sessionbreak.starttime     = _sessionbreak.starttime;
      sessionbreak.endtime       = _sessionbreak.endtime;
   }
}


/**
 * Calculate and return the reference equity value for a new sequence.
 *
 * @return double - equity value or NULL in case of errors
 */
double CalculateStartEquity() {
   double result;

   if (!IsTesting() || !StrIsNumeric(UnitSize) || !tester.startEquity) {
      result = NormalizeDouble(AccountEquity()-AccountCredit(), 2);
   }
   else {
      result = tester.startEquity;
   }

   if (!catch("CalculateStartEquity(1)"))
      return(result);
   return(NULL);
}


/**
 * Calculate and return the unitsize to use for the given equity value. If the sequence was already started the returned
 * value is equal to the initially calculated unitsize, no matter the equity value passed.
 *
 * @param  double equity - equity value
 *
 * @return double - unitsize or NULL in case of errors
 */
double CalculateUnitSize(double equity) {
   if (LE(equity, 0))         return(!catch("CalculateUnitSize(1)  "+ sequence.longName +" invalid parameter equity: "+ NumberToStr(equity, ".2+"), ERR_INVALID_PARAMETER));

   if (ArraySize(orders.ticket) > 0) {
      if (!sequence.unitsize) return(!catch("CalculateUnitSize(2)  "+ sequence.longName +" illegal stored value of sequence.unitsize: 0", ERR_ILLEGAL_STATE));
      return(sequence.unitsize);
   }

   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE );
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double minLot    = MarketInfo(Symbol(), MODE_MINLOT   );
   double maxLot    = MarketInfo(Symbol(), MODE_MAXLOT   );
   double lotStep   = MarketInfo(Symbol(), MODE_LOTSTEP  );
   int    error     = GetLastError();
   if (IsError(error)) return(!catch("CalculateUnitSize(3)", error));

   if (!tickSize || !tickValue || !minLot || !maxLot || !lotStep) {
      string sDetail = ifString(tickSize!=0, "", "tickSize=0, ") + ifString(tickValue!=0, "", "tickValue=0, ") + ifString(minLot!=0, "", "minLot=0, ") + ifString(maxLot!=0, "", "maxLot=0, ") + ifString(lotStep!=0, "", "lotStep=0, ");
      return(!catch("CalculateUnitSize(4)  "+ sequence.longName +" market data not (yet) available: "+ StrLeft(sDetail, -2), ERS_TERMINAL_NOT_YET_READY));
   }

   string sValue;
   bool   calculated = false;
   double result;

   if (UnitSize == "auto") {
      calculated = true;
      // read and parse configuration: Unitsize.{symbol} = L[everage]{double}
      string section="SnowRoller", key="Unitsize."+ StdSymbol(), sUnitSize=GetConfigString(section, key);
      if      (StrStartsWithI(sUnitSize, "Leverage")) sValue = StrTrim(StrSubstr(sUnitSize, 8));
      else if (StrStartsWithI(sUnitSize, "L"       )) sValue = StrTrim(StrSubstr(sUnitSize, 1));
      else                                            sValue = sUnitSize;
      if (!StrIsNumeric(sValue))               return(!catch("CalculateUnitSize(5)  "+ sequence.longName +" invalid configuration ["+ section +"]->"+ key +": "+ DoubleQuoteStr(sUnitSize), ERR_INVALID_CONFIG_VALUE));
      double leverage = StrToDouble(sValue);
      if (LE(leverage, 0))                     return(!catch("CalculateUnitSize(6)  "+ sequence.longName +" invalid leverage value in configuration ["+ section +"]->"+ key +": "+ DoubleQuoteStr(sUnitSize), ERR_INVALID_CONFIG_VALUE));
   }
   else {
      if      (StrStartsWithI(UnitSize, "Leverage")) { sValue = StrTrim(StrSubstr(UnitSize, 8)); calculated = true; }
      else if (StrStartsWithI(UnitSize, "L"       )) { sValue = StrTrim(StrSubstr(UnitSize, 1)); calculated = true; }
      else                                             sValue = UnitSize;
      if (!StrIsNumeric(sValue))               return(!catch("CalculateUnitSize(7)  "+ sequence.longName +" invalid input parameter UnitSize: "+ DoubleQuoteStr(UnitSize), ERR_INVALID_INPUT_PARAMETER));

      if (calculated) {
         leverage = StrToDouble(sValue);
         if (LE(leverage, 0))                  return(!catch("CalculateUnitSize(8)  "+ sequence.longName +" invalid leverage value in input parameter UnitSize: "+ DoubleQuoteStr(UnitSize), ERR_INVALID_INPUT_PARAMETER));
      }
      else {
         result = StrToDouble(sValue);
         if (LE(result, 0))                    return(!catch("CalculateUnitSize(9)  "+ sequence.longName +" invalid input parameter UnitSize: "+ DoubleQuoteStr(UnitSize), ERR_INVALID_INPUT_PARAMETER));
      }
   }

   if (calculated) {
      double price   = (Bid+Ask)/2;
      double lotSize = price * tickValue/tickSize;    // lotsize in account currency
      double margin  = equity * leverage;             // available leveraged margin
      result         = margin / lotSize;
      int steps      = result / lotStep;
      result         = NormalizeDouble(steps * lotStep, 2);

      if (LT(result, minLot))               return(!catch("CalculateUnitSize(10)  "+ sequence.longName +" too low parameter equity = "+ NumberToStr(equity, ".2") +", calculated unitsize: "+ NumberToStr(result, ".+") +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_PARAMETER));
      if (GT(result, maxLot))               return(!catch("CalculateUnitSize(11)  "+ sequence.longName +" too high parameter equity = "+ NumberToStr(equity, ".2") +", calculated unitsize: "+ NumberToStr(result, ".+") +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_PARAMETER));
   }
   else {
      if (LT(result, minLot))               return(!catch("CalculateUnitSize(12)  "+ sequence.longName +" invalid input parameter UnitSize: "+ DoubleQuoteStr(UnitSize) +" (MinLot="+ NumberToStr(minLot, ".+") +")", ERR_INVALID_INPUT_PARAMETER));
      if (GT(result, maxLot))               return(!catch("CalculateUnitSize(13)  "+ sequence.longName +" invalid input parameter UnitSize: "+ DoubleQuoteStr(UnitSize) +" (MaxLot="+ NumberToStr(maxLot, ".+") +")", ERR_INVALID_INPUT_PARAMETER));
      if (MathModFix(result, lotStep) != 0) return(!catch("CalculateUnitSize(14)  "+ sequence.longName +" invalid input parameter UnitSize: "+ DoubleQuoteStr(UnitSize) +" (LotStep="+ NumberToStr(lotStep, ".+") +")", ERR_INVALID_INPUT_PARAMETER));
   }

   if (!catch("CalculateUnitSize(15)"))
      return(result);
   return(NULL);
}


/**
 * Adjust the order markers created or omitted by the terminal for a filled pending order.
 *
 * @param  int i - index in the order arrays
 *
 * @return bool - success status
 */
bool Chart.MarkOrderFilled(int i) {
   if (!__isChart) return(true);
   /*
   #define ODM_NONE     0     // - no display -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   static string sPrefix = "";
   if (!StringLen(sPrefix)) {
      if      (SNOWROLLER) sPrefix = "SR.";
      else if (SISYPHUS)   sPrefix = "SPH.";
      else                 sPrefix = "??.";
   }
   string comment     = sPrefix + sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   color  markerColor = CLR_NONE;

   if (orderDisplayMode >= ODM_PYRAMID)
      markerColor = ifInt(orders.type[i]==OP_BUY, CLR_LONG, CLR_SHORT);

   return(ChartMarker.OrderFilled_B(orders.ticket[i], orders.pendingType[i], orders.pendingPrice[i], Digits, markerColor, sequence.unitsize, Symbol(), orders.openTime[i], orders.openPrice[i], comment));
}


/**
 * Adjust the order markers created or omitted by the terminal for a sent pending or market order.
 *
 * @param  int i - index in the order arrays
 *
 * @return bool - success status
 */
bool Chart.MarkOrderSent(int i) {
   if (!__isChart) return(true);
   /*
   #define ODM_NONE     0     // - no display -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   static string sPrefix = "";
   if (!StringLen(sPrefix)) {
      if      (SNOWROLLER) sPrefix = "SR.";
      else if (SISYPHUS)   sPrefix = "SPH.";
      else                 sPrefix = "??.";
   }
   bool pending = orders.pendingType[i] != OP_UNDEFINED;

   int      type        =    ifInt(pending, orders.pendingType [i], orders.type     [i]);
   datetime openTime    =    ifInt(pending, orders.pendingTime [i], orders.openTime [i]);
   double   openPrice   = ifDouble(pending, orders.pendingPrice[i], orders.openPrice[i]);
   string   comment     = sPrefix + sequence.id +"."+ NumberToStr(orders.level[i], "+.");
   color    markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if      (pending)                         markerColor = CLR_PENDING;
      else if (orderDisplayMode >= ODM_PYRAMID) markerColor = ifInt(IsLongOrderType(type), CLR_LONG, CLR_SHORT);
   }
   return(ChartMarker.OrderSent_B(orders.ticket[i], Digits, markerColor, type, sequence.unitsize, Symbol(), openTime, openPrice, orders.stopLoss[i], 0, comment));
}


/**
 * Adjust the order markers created or omitted by the terminal for a closed position.
 *
 * @param  int i - index in the order arrays
 *
 * @return bool - success status
 */
bool Chart.MarkPositionClosed(int i) {
   if (!__isChart) return(true);
   /*
   #define ODM_NONE     0     // - no display -
   #define ODM_STOPS    1     // Pending,       ClosedBySL
   #define ODM_PYRAMID  2     // Pending, Open,             Closed
   #define ODM_ALL      3     // Pending, Open, ClosedBySL, Closed
   */
   color markerColor = CLR_NONE;

   if (orderDisplayMode != ODM_NONE) {
      if ( orders.closedBySL[i]) /*&&*/ if (orderDisplayMode != ODM_PYRAMID) markerColor = CLR_CLOSE;
      if (!orders.closedBySL[i]) /*&&*/ if (orderDisplayMode >= ODM_PYRAMID) markerColor = CLR_CLOSE;
   }
   return(ChartMarker.PositionClosed_B(orders.ticket[i], Digits, markerColor, orders.type[i], sequence.unitsize, Symbol(), orders.openTime[i], orders.openPrice[i], orders.closeTime[i], orders.closePrice[i]));
}


/**
 * Get a user confirmation for a trade request at the first tick. Safety measure against runtime errors.
 *
 * @param  string location - location identifier of the confirmation
 * @param  string message  - confirmation message
 *
 * @return bool - confirmation result
 */
bool ConfirmFirstTickTrade(string location, string message) {
   static bool confirmed;
   if (confirmed)                         // On nested calls behave like a no-op, don't return the former result. Trade requests
      return(true);                       // will differ and the calling logic must correctly interprete the first result.

   bool result;
   if (Tick > 1 || IsTesting()) {
      result = true;
   }
   else {
      PlaySoundEx("Windows Notify.wav");
      result = (IDOK == MessageBoxEx(ProgramName() + ifString(StringLen(location), " - "+ location, ""), ifString(IsDemoFix(), "", "- Real Account -\n\n") + message, MB_ICONQUESTION|MB_OKCANCEL));
      RefreshRates();
   }
   confirmed = true;

   return(result);
}


/**
 * Return the number of known open positions of the sequence.
 *
 * @return int
 */
int CountOpenPositions() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]!=OP_UNDEFINED) /*&&*/ if (!orders.closeTime[i])
         count++;
   }
   return(count);
}


/**
 * Return the number of known open pending orders of the sequence.
 *
 * @return int
 */
int CountPendingOrders() {
   int count, size=ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      if (orders.type[i]==OP_UNDEFINED) /*&&*/ if (!orders.closeTime[i])
         count++;
   }
   return(count);
}


/**
 * Generate a new sequence id. As strategy ids differ multiple strategies may use the same sequence id at the same time.
 *
 * @return int - sequence id between SID_MAX and SID_MAX (1000-9999)
 */
int CreateSequenceId() {
   MathSrand(GetTickCount()-__ExecutionContext[EC.hChartWindow]);
   int id;
   while (id < SID_MIN || id > SID_MAX) {
      id = MathRand();                                         // TODO: in tester generate consecutive ids
   }                                                           // TODO: test id for uniqueness
   return(id);
}


/**
 * Create the status display box. It consists of overlapping rectangles made of char "g" font "Webdings". Called only from
 * afterInit().
 *
 * @return int - error status
 */
int CreateStatusBox() {
   if (!__isChart) return(NO_ERROR);

   int x[]={2, 101, 165}, y=62, fontSize=75, rectangles=ArraySize(x);
   color  bgColor = C'248,248,248';                            // that's chart background color
   string label;

   for (int i=0; i < rectangles; i++) {
      label = ProgramName() +".statusbox."+ (i+1);
      if (ObjectFind(label) != 0) {
         ObjectCreate(label, OBJ_LABEL, 0, 0, 0);
         RegisterObject(label);
      }
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, x[i]);
      ObjectSet    (label, OBJPROP_YDISTANCE, y   );
      ObjectSetText(label, "g", fontSize, "Webdings", bgColor);
   }
   return(catch("CreateStatusBox(1)"));
}


/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFilename() {
   string name = GetStatusFilename();
   if (!StringLen(name)) return("");
   return(StrLeft(name, -3) +"log");
}


/**
 * Return the full name of the instance status file.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename() {
   if (!sequence.id) return(_EMPTY_STR(catch("GetStatusFilename(1)  "+ sequence.longName +" illegal value of sequence.id: "+ sequence.id, ERR_ILLEGAL_STATE)));

   string subdirectory = "\\presets\\";
   if (!IsTestSequence()) subdirectory = subdirectory + GetAccountCompany() +"\\";

   string strategy = "";
   if (SNOWROLLER) strategy = "SR";
   if (SISYPHUS)   strategy = "SPH";

   string baseName=StrToLower(Symbol()) +"."+ strategy +"."+ sequence.id +".set";

   return(GetMqlFilesPath() + subdirectory + baseName);
}


/**
 * Return the currently active gridbase value.
 *
 * @return double - gridbase value or NULL if the gridbase is not yet set
 */
double GetGridbase() {
   int size = ArraySize(gridbase.event);
   if (size > 0)
      return(gridbase.price[size-1]);
   return(NULL);
}


/**
 * Handle occurred network errors. Disables regular processing of the EA until the retry condition for the next trade request
 * is fulfilled.
 *
 * @return bool - whether regular processing should continue (i.e. the trade request should be repeated)
 */
bool HandleNetworkErrors() {
   // TODO: Regular processing must continue, only further trade requests must be disabled.
   switch (lastNetworkError) {
      case NO_ERROR:
         return(true);

      case ERR_NO_CONNECTION:
      case ERR_TRADESERVER_GONE:
      case ERR_TRADE_DISABLED:
      case ERR_MARKET_CLOSED:
         if (sequence.status==STATUS_STARTING || sequence.status==STATUS_STOPPING)
            return(!catch("HandleNetworkErrors(1)  "+ sequence.longName +" in status "+ StatusToStr(sequence.status) +" not yet implemented", ERR_NOT_IMPLEMENTED));

         if (sequence.status == STATUS_PROGRESSING) {
            if (Tick.Time >= nextRetry) {
               retries++;
               return(true);
            }
            else {
               return(false);
            }
         }
         return(!catch("HandleNetworkErrors(2)  "+ sequence.longName +" unsupported sequence status "+ StatusToStr(sequence.status), ERR_ILLEGAL_STATE));
   }
   return(!catch("HandleNetworkErrors(3)  "+ sequence.longName +" unsupported error ", lastNetworkError));
}


/**
 * Whether the current sequence was created in the tester. Considers the fact that a test sequence may be loaded into an
 * online chart after the test (for visualization).
 *
 * @return bool
 */
bool IsTestSequence() {
   return(sequence.isTest || IsTesting());
}


/**
 * Redraw order markers of the active sequence. Markers of finished sequence cycles will no be redrawn.
 */
void RedrawOrders() {
   if (!__isChart) return;

   bool wasPending, isPending, closedPosition;
   int  size = ArraySize(orders.ticket);

   for (int i=0; i < size; i++) {
      wasPending     = orders.pendingType[i] != OP_UNDEFINED;
      isPending      = orders.type[i] == OP_UNDEFINED;
      closedPosition = !isPending && orders.closeTime[i]!=0;

      if    (isPending)                         Chart.MarkOrderSent(i);
      else /*openPosition || closedPosition*/ {                                  // openPosition is result of...
         if (wasPending)                        Chart.MarkOrderFilled(i);        // a filled pending order or...
         else                                   Chart.MarkOrderSent(i);          // a market order
         if (closedPosition)                    Chart.MarkPositionClosed(i);
      }
   }
   catch("RedrawOrders(1)");
}


/**
 * Redraw the start/stop markers of the active sequence. Markers of finished sequence cycles will no be redrawn.
 */
void RedrawStartStop() {
   if (!__isChart) return;

   string   label, sCycle = StrPadLeft(sequence.cycle, 3, "0");
   datetime time;
   double   price;
   double   profit;
   int starts = ArraySize(sequence.start.event);

   // start markers
   for (int i=0; i < starts; i++) {
      time   = sequence.start.time  [i];
      price  = sequence.start.price [i];
      profit = sequence.start.profit[i];

      label = "SR."+ sequence.id +"."+ sCycle +".start."+ (i+1);
      if (ObjectFind(label) == 0)
         ObjectDelete(label);

      if (startStopDisplayMode != SDM_NONE) {
         ObjectCreate (label, OBJ_ARROW, 0, time, price);
         ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
         ObjectSet    (label, OBJPROP_BACK,      false               );
         ObjectSet    (label, OBJPROP_COLOR,     Blue                );
         ObjectSetText(label, "Profit: "+ DoubleToStr(profit, 2));
      }
   }

   // stop markers
   for (i=0; i < starts; i++) {
      if (sequence.stop.time[i] > 0) {
         time   = sequence.stop.time [i];
         price  = sequence.stop.price[i];
         profit = sequence.stop.profit[i];

         label = "SR."+ sequence.id +"."+ sCycle +".stop."+ (i+1);
         if (ObjectFind(label) == 0)
            ObjectDelete(label);

         if (startStopDisplayMode != SDM_NONE) {
            ObjectCreate (label, OBJ_ARROW, 0, time, price);
            ObjectSet    (label, OBJPROP_ARROWCODE, startStopDisplayMode);
            ObjectSet    (label, OBJPROP_BACK,      false               );
            ObjectSet    (label, OBJPROP_COLOR,     Blue                );
            ObjectSetText(label, "Profit: "+ DoubleToStr(profit, 2));
         }
      }
   }
   catch("RedrawStartStop(1)");
}


/**
 * Restore sequence id and transient status found in the chart after recompilation or terminal restart.
 *
 * @return bool - whether a sequence id was found and restored
 */
bool RestoreChartStatus() {
   string name=ProgramName(), key=name +".runtime.Sequence.ID", sValue="";

   if (ObjectFind(key) == 0) {
      Chart.RestoreString(key, sValue);

      if (StrStartsWith(sValue, "T")) {
         sequence.isTest = true;
         sValue = StrSubstr(sValue, 1);
      }
      int iValue = StrToInteger(sValue);
      if (!iValue) {
         sequence.status = STATUS_UNDEFINED;
      }
      else {
         sequence.id     = iValue;
         Sequence.ID     = ifString(IsTestSequence(), "T", "") + sequence.id;
         sequence.status = STATUS_WAITING;
      }
      bool bValue;
      Chart.RestoreInt (name +".runtime.startStopDisplayMode", startStopDisplayMode);
      Chart.RestoreInt (name +".runtime.orderDisplayMode",     orderDisplayMode    );
      Chart.RestoreBool(name +".runtime.CANCELLED_BY_USER",    bValue              ); if (bValue) SetLastError(ERR_CANCELLED_BY_USER);
      catch("RestoreChartStatus(1)");
      return(iValue != 0);
   }
   return(false);
}


/**
 * Delete all sequence data stored in the chart.
 *
 * @return int - error status
 */
int DeleteChartStatus() {
   string label, prefix=ProgramName() +".runtime.";

   for (int i=ObjectsTotal()-1; i>=0; i--) {
      label = ObjectName(i);
      if (StrStartsWith(label, prefix)) /*&&*/ if (ObjectFind(label) == 0)
         ObjectDelete(label);
   }
   return(catch("DeleteChartStatus(1)"));
}


/**
 * ShowStatus: Update all string representations.
 */
void SS.All() {
   if (!__isChart) return;

   SS.SequenceName();
   SS.GridBase();
   SS.GridDirection();
   SS.MissedLevels();
   SS.UnitSize();
   SS.ProfitPerLevel();
   SS.StartStopConditions();
   SS.AutoRestart();
   SS.Stops();
   SS.TotalPL();
   SS.MaxProfit();
   SS.MaxDrawdown();
   SS.StartStopStats();
}


/**
 * ShowStatus: Update the string representation of the "AutoRestart" option.
 */
void SS.AutoRestart() {
   if (!__isChart) return;

   if (AutoRestart=="Off") sAutoRestart = "AutoRestart:  "+ AutoRestart + NL;
   else                    sAutoRestart = "AutoRestart:  "+ AutoRestart +" ("+ (sequence.cycle-1) +")" + NL;
}


/**
 * ShowStatus: Update the string representation of the gridbase.
 */
void SS.GridBase() {
   if (!__isChart) return;

   double gridbase = GetGridbase();
   if (!gridbase) return;

   sGridBase = " @ "+ NumberToStr(gridbase, PriceFormat);
}


/**
 * ShowStatus: Update the string representation of the sequence direction.
 */
void SS.GridDirection() {
   if (!__isChart) return;

   if (sequence.direction != 0) {
      sSequenceDirection = TradeDirectionDescription(sequence.direction) +" ";
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.maxDrawdown".
 */
void SS.MaxDrawdown() {
   if (!__isChart) return;

   if (ShowProfitInPercent) sSequenceMaxDrawdown = NumberToStr(MathDiv(sequence.maxDrawdown, sequence.startEquity) * 100, "+.2") +"%";
   else                     sSequenceMaxDrawdown = NumberToStr(sequence.maxDrawdown, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus: Update the string representation of "sequence.maxProfit".
 */
void SS.MaxProfit() {
   if (!__isChart) return;

   if (ShowProfitInPercent) sSequenceMaxProfit = NumberToStr(MathDiv(sequence.maxProfit, sequence.startEquity) * 100, "+.2") +"%";
   else                     sSequenceMaxProfit = NumberToStr(sequence.maxProfit, "+.2");
   SS.PLStats();
}


/**
 * ShowStatus: Update the string representation of the missed gridlevels.
 */
void SS.MissedLevels() {
   if (!__isChart) return;

   int size = ArraySize(sequence.missedLevels);
   if (!size) sSequenceMissedLevels = "";
   else       sSequenceMissedLevels = ", missed: "+ JoinInts(sequence.missedLevels);
}


/**
 * ShowStatus: Update the string representaton of the P/L statistics.
 */
void SS.PLStats() {
   if (!__isChart) return;

   if (sequence.maxLevel != 0) {             // not before a positions was opened
      sSequencePlStats = "  ("+ sSequenceMaxProfit +"/"+ sSequenceMaxDrawdown +")";
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.profitPerLevel".
 */
void SS.ProfitPerLevel() {
   if (!__isChart) return;

   if (!sequence.level) {
      sSequenceProfitPerLevel = "";          // not before a positions was opened
   }
   else {
      double stopSize = GridSize * PipValue(sequence.unitsize);
      int    levels   = Abs(sequence.level) - ArraySize(sequence.missedLevels);
      double profit   = levels * stopSize;

      if (ShowProfitInPercent) sSequenceProfitPerLevel = " = "+ DoubleToStr(MathDiv(profit, sequence.startEquity) * 100, 1) +"%/level";
      else                     sSequenceProfitPerLevel = " = "+ DoubleToStr(profit, 2) +"/level";
   }
}


/**
 * ShowStatus: Update the string representations of standard and long sequence name.
 */
void SS.SequenceName() {
   sequence.name = "";

   if      (sequence.direction == D_LONG)  sequence.name = "L";
   else if (sequence.direction == D_SHORT) sequence.name = "S";

   sequence.name     = sequence.name +"."+ sequence.id;
   sequence.longName = sequence.name +"."+ NumberToStr(sequence.level, "+.");
}


/**
 * ShowStatus: Update the string representation of the configured start/stop conditions.
 */
void SS.StartStopConditions() {
   if (!__isChart) return;

   // start conditions, order: [sessionbreak >>] trend, time, price
   string sValue = "";
   if (start.time.description!="" || start.price.description!="") {
      if (start.time.description != "") {
         sValue = sValue + ifString(start.time.condition, "@", "!") + start.time.description;
      }
      if (start.price.description != "") {
         sValue = sValue + ifString(sValue=="", "", " && ") + ifString(start.price.condition, "@", "!") + start.price.description;
      }
   }
   if (start.trend.description != "") {
      string sTrend = ifString(start.trend.condition, "@", "!") + start.trend.description;

      if (start.time.description!="" && start.price.description!="") {
         sValue = "("+ sValue +")";
      }
      if (start.time.description=="" && start.price.description=="") {
         sValue = sTrend;
      }
      else {
         sValue = sTrend +" || "+ sValue;
      }
   }
   if (sessionbreak.waiting) {
      if (sValue != "") sValue = " >> "+ sValue;
      sValue = "sessionbreak"+ sValue;
   }
   if (sValue == "") sStartConditions = "-";
   else              sStartConditions = sValue;

   // stop conditions, order: trend, profit, loss, time, price
   sValue = "";
   if (stop.trend.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.trend.condition, "@", "!") + stop.trend.description;
   }
   if (stop.profitAbs.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.profitAbs.condition, "@", "!") + stop.profitAbs.description;
   }
   if (stop.profitPct.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.profitPct.condition, "@", "!") + stop.profitPct.description;
   }
   if (stop.lossAbs.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.lossAbs.condition, "@", "!") + stop.lossAbs.description;
   }
   if (stop.lossPct.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.lossPct.condition, "@", "!") + stop.lossPct.description;
   }
   if (stop.time.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.time.condition, "@", "!") + stop.time.description;
   }
   if (stop.price.description != "") {
      sValue = sValue + ifString(sValue=="", "", " || ") + ifString(stop.price.condition, "@", "!") + stop.price.description;
   }
   if (sValue == "") sStopConditions = "-";
   else              sStopConditions = sValue;
}


/**
 * ShowStatus: Update the string representation of the start/stop statistics.
 */
void SS.StartStopStats() {
   if (!__isChart) return;

   sStartStopStats = "";

   int size = ArraySize(sequence.start.event);
   string sStartPL, sStopPL;

   for (int i=0; i < size-1; i++) {
      if (ShowProfitInPercent) {
         sStartPL = NumberToStr(MathDiv(sequence.start.profit[i], sequence.startEquity) * 100, "+.2") +"%";
         sStopPL  = NumberToStr(MathDiv(sequence.stop.profit [i], sequence.startEquity) * 100, "+.2") +"%";
      }
      else {
         sStartPL = NumberToStr(sequence.start.profit[i], "+.2");
         sStopPL  = NumberToStr(sequence.stop.profit [i], "+.2");
      }
      sStartStopStats = "-------------------------------------------------------"+ NL
                       +" "+ (i+1) +":   Start: "+ sStartPL +"   Stop: "+ sStopPL + StrRightFrom(sStartStopStats, "--", -1);
   }
   if (StringLen(sStartStopStats) > 0)
      sStartStopStats = sStartStopStats + NL;
}


/**
 * ShowStatus: Update the string representation of "sequence.stops" and "sequence.stopsPL".
 */
void SS.Stops() {
   if (!__isChart) return;
   sSequenceStops = sequence.stops +" stop"+ Pluralize(sequence.stops);

   // not set before the first stopped-out position
   if (sequence.stops > 0) {
      if (ShowProfitInPercent) sSequenceStopsPL = " = "+ DoubleToStr(MathDiv(sequence.stopsPL, sequence.startEquity) * 100, 2) +"%";
      else                     sSequenceStopsPL = " = "+ DoubleToStr(sequence.stopsPL, 2);
   }
}


/**
 * ShowStatus: Update the string representation of "sequence.totalPL".
 */
void SS.TotalPL() {
   if (!__isChart) return;

   // not set before the first open position
   if (sequence.maxLevel == 0)   sSequenceTotalPL = "-";
   else if (ShowProfitInPercent) sSequenceTotalPL = NumberToStr(MathDiv(sequence.totalPL, sequence.startEquity) * 100, "+.2") +"%";
   else                          sSequenceTotalPL = NumberToStr(sequence.totalPL, "+.2");
}


/**
 * ShowStatus: Update the string representation of the unitsize.
 */
void SS.UnitSize() {
   if (!__isChart) return;

   double equity = sequence.startEquity;

   if (!sequence.unitsize) {
      if (!equity) equity = CalculateStartEquity();
      sequence.unitsize = CalculateUnitSize(equity);
   }
   string sCompounding = ifString(StrIsNumeric(UnitSize), "", " (compounding)");
   double stopSize     = GridSize * PipValue(sequence.unitsize) - sequence.commission;

   if (ShowProfitInPercent) sLotSize = NumberToStr(sequence.unitsize, ".+") +" lot"+ sCompounding +" = "+ DoubleToStr(MathDiv(stopSize, equity) * 100, 2) +"%/stop";
   else                     sLotSize = NumberToStr(sequence.unitsize, ".+") +" lot"+ sCompounding +" = "+ DoubleToStr(stopSize, 2) +"/stop";
}


/**
 * Return a description of a sequence status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusDescription(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("undefined"  );
      case STATUS_WAITING    : return("waiting"    );
      case STATUS_STARTING   : return("starting"   );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPING   : return("stopping"   );
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ sequence.longName +" invalid parameter status = "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a readable version of a sequence status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case STATUS_UNDEFINED  : return("STATUS_UNDEFINED"  );
      case STATUS_WAITING    : return("STATUS_WAITING"    );
      case STATUS_STARTING   : return("STATUS_STARTING"   );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPING   : return("STATUS_STOPPING"   );
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ sequence.longName +" invalid parameter status = "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Store sequence id and transient status in the chart before recompilation or terminal restart.
 *
 * @return int - error status
 */
int StoreChartStatus() {
   string name = ProgramName();
   Chart.StoreString(name +".runtime.Sequence.ID",          Sequence.ID                      );
   Chart.StoreInt   (name +".runtime.startStopDisplayMode", startStopDisplayMode             );
   Chart.StoreInt   (name +".runtime.orderDisplayMode",     orderDisplayMode                 );
   Chart.StoreBool  (name +".runtime.CANCELLED_BY_USER",    last_error==ERR_CANCELLED_BY_USER);
   return(catch("StoreChartStatus(1)"));
}


/**
 * Toggle order markers.
 *
 * @return bool - success status
 */
bool ToggleOrderDisplayMode() {
   int pendings   = CountPendingOrders();
   int open       = CountOpenPositions();
   int stoppedOut = CountStoppedOutPositions();
   int closed     = CountClosedPositions();

   // change mode, skip modes without orders
   int oldMode      = orderDisplayMode;
   int size         = ArraySize(orderDisplayModes);
   orderDisplayMode = (orderDisplayMode+1) % size;

   while (orderDisplayMode != oldMode) {                                // #define ODM_NONE     - no display -
      if (orderDisplayMode == ODM_NONE) {                               // #define ODM_STOPS    Pending,       StoppedOut
         break;                                                         // #define ODM_PYRAMID  Pending, Open,             Closed
      }                                                                 // #define ODM_ALL      Pending, Open, StoppedOut, Closed
      else if (orderDisplayMode == ODM_STOPS) {
         if (pendings+stoppedOut > 0)
            break;
      }
      else if (orderDisplayMode == ODM_PYRAMID) {
         if (pendings+open+closed > 0)
            if (open+stoppedOut+closed > 0)                             // otherwise the mode is identical to the previous one
               break;
      }
      else if (orderDisplayMode == ODM_ALL) {
         if (pendings+open+stoppedOut+closed > 0)
            if (stoppedOut > 0)                                         // otherwise the mode is identical to the previous one
               break;
      }
      orderDisplayMode = (orderDisplayMode+1) % size;
   }

   // update display
   if (orderDisplayMode != oldMode) RedrawOrders();
   else                             PlaySoundEx("Plonk.wav");           // nothing to change

   return(!catch("ToggleOrderDisplayMode(1)"));
}


/**
 * Toggle sequence start/stop markers.
 *
 * @return bool - success status of the executed command
 */
bool ToggleStartStopDisplayMode() {
   // change mode
   int i = SearchIntArray(startStopDisplayModes, startStopDisplayMode); // #define SDM_NONE     - no display -
   if (i == -1) {                                                       // #define SDM_PRICE    price markers
      startStopDisplayMode = SDM_PRICE;                                 // default
   }
   else {
      int size = ArraySize(startStopDisplayModes);
      startStopDisplayMode = startStopDisplayModes[(i+1) % size];
   }

   // update display
   RedrawStartStop();
   return(!catch("ToggleStartStopDisplayMode(1)"));
}


/**
 * Syntactically validate and restore a specified sequence id (format: /T?[0-9]{4,}/i). Called only from onInitUser().
 *
 * @param  bool interactive - whether parameters have been entered through the input dialog
 *
 * @return bool - whether the input sequence id is was valid and restored (the status file is not checked)
 */
bool ValidateInputs.SID(bool interactive) {
   interactive = interactive!=0;
   string sValue = StrToUpper(StrTrim(Sequence.ID));

   if (!StringLen(sValue))
      return(false);

   if (StrLeft(sValue, 1) == "T") {
      sequence.isTest = true;
      sValue = StrSubstr(sValue, 1);
   }
   if (!StrIsDigit(sValue))
      return(_false(onInputError("ValidateInputs.SID(1)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (must be digits only)", interactive)));

   int iValue = StrToInteger(sValue);
   if (iValue < SID_MIN || iValue > SID_MAX)
      return(_false(onInputError("ValidateInputs.SID(2)  invalid input parameter Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (range error)", interactive)));

   sequence.id = iValue;
   Sequence.ID = ifString(IsTestSequence(), "T", "") + sequence.id;
   return(true);
}


/**
 * Validate all input parameters. Parameters may have been entered through the input dialog, may have been read and applied
 * from a status file or may have been deserialized and applied programmatically by the terminal (e.g. at terminal restart).
 *
 * @param  bool interactive - whether parameters have been entered through the input dialog
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs(bool interactive) {
   interactive = interactive!=0;
   if (IsLastError()) return(false);

   bool isParameterChange = (ProgramInitReason()==IR_PARAMETERS); // otherwise inputs have been applied programmatically
   if (isParameterChange)
      interactive = true;

   // Sequence.ID
   if (isParameterChange) {
      if (sequence.status == STATUS_UNDEFINED) {
         if (Sequence.ID != last.Sequence.ID)                     return(_false(onInputError("ValidateInputs(1)  switching the sequence at runtime is not supported. Unload the EA first.", interactive)));
      }
      else if (!StringLen(StrTrim(Sequence.ID))) {
         Sequence.ID = last.Sequence.ID;                          // apply the existing internal id
      }
      else if (StrTrim(Sequence.ID) != StrTrim(last.Sequence.ID)) return(_false(onInputError("ValidateInputs(2)  switching the sequence at runtime is not supported. Unload the EA first.", interactive)));
   }
   else if (!StringLen(Sequence.ID)) {                            // status must be STATUS_UNDEFINED (sequence.id = 0)
      if (sequence.id != 0)                                       return(_false(catch("ValidateInputs(3)  illegal Sequence.ID: "+ DoubleQuoteStr(Sequence.ID) +" (sequence.id="+ sequence.id +")", ERR_RUNTIME_ERROR)));
   }
   else {}                                                        // if sequence.id is set it's valid and the sequence is loaded (otherwise this is not reachable)

   // GridDirection
   string sValues[], sValue=StrToLower(StrTrim(GridDirection));
   if      (StrStartsWith("long",  sValue)) sValue = "Long";
   else if (StrStartsWith("short", sValue)) sValue = "Short";
   else                                                           return(_false(onInputError("ValidateInputs(4)  invalid GridDirection "+ DoubleQuoteStr(GridDirection), interactive)));
   if (isParameterChange && !StrCompareI(sValue, last.GridDirection)) {
      if (ArraySize(sequence.start.event) > 0)                    return(_false(onInputError("ValidateInputs(5)  cannot change GridDirection of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   sequence.direction = StrToTradeDirection(sValue);
   GridDirection      = sValue; SS.GridDirection();
   SS.SequenceName();

   // GridSize
   if (isParameterChange) {
      if (GridSize != last.GridSize)
         if (ArraySize(sequence.start.event) > 0)                 return(_false(onInputError("ValidateInputs(6)  cannot change GridSize of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (GridSize < 1)                                              return(_false(onInputError("ValidateInputs(7)  invalid GridSize: "+ GridSize, interactive)));

   // UnitSize
   if (isParameterChange) {
      if (UnitSize != last.UnitSize)
         if (ArraySize(sequence.start.event) > 0)                 return(_false(onInputError("ValidateInputs(8)  cannot change UnitSize of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   sValue = StrToLower(UnitSize);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "auto") {
      UnitSize = sValue;
   }
   else {
      bool fixedSize = true;
      if      (StrStartsWithI(sValue, "Leverage")) { sValue = StrTrim(StrSubstr(sValue, 8)); fixedSize = false; }
      else if (StrStartsWithI(sValue, "L"       )) { sValue = StrTrim(StrSubstr(sValue, 1)); fixedSize = false; }
      if (!StrIsNumeric(sValue))                                  return(_false(onInputError("ValidateInputs(9)  invalid UnitSize: "+ DoubleQuoteStr(UnitSize), interactive)));
      double dValue = StrToDouble(sValue);
      if (fixedSize) {
         double minLot  = MarketInfo(Symbol(), MODE_MINLOT );
         double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT );
         double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
         int    error   = GetLastError();
         if (IsError(error))                                      return(_false(onInputError("ValidateInputs(10)", interactive)));
         if (LE(dValue, 0))                                       return(_false(onInputError("ValidateInputs(11)  invalid UnitSize: "+ DoubleQuoteStr(sValue), interactive)));
         if (LT(dValue, minLot))                                  return(_false(onInputError("ValidateInputs(12)  invalid UnitSize: "+ DoubleQuoteStr(sValue) +" (MinLot="+  NumberToStr(minLot, ".+" ) +")", interactive)));
         if (GT(dValue, maxLot))                                  return(_false(onInputError("ValidateInputs(13)  invalid UnitSize: "+ DoubleQuoteStr(sValue) +" (MaxLot="+  NumberToStr(maxLot, ".+" ) +")", interactive)));
         if (MathModFix(dValue, lotStep) != 0)                    return(_false(onInputError("ValidateInputs(14)  invalid UnitSize: "+ DoubleQuoteStr(sValue) +" (LotStep="+ NumberToStr(lotStep, ".+") +")", interactive)));
      }
      else {
         if (LE(dValue, 0))                                       return(_false(onInputError("ValidateInputs(15)  invalid UnitSize: "+ DoubleQuoteStr(sValue), interactive)));
      }
      UnitSize = ifString(fixedSize, "", "L") + sValue;
   }

   string trendIndicators[] = {"ALMA", "EMA", "HalfTrend", "JMA", "LWMA", "NonLagMA", "SATL", "SMA", "SuperSmoother", "SuperTrend", "TriEMA"};

   // StartConditions, "AND" combined: @trend(<indicator>:<timeframe>:<params>) | @[bid|ask|median|price](double) | @time(datetime)
   // -----------------------------------------------------------------------------------------------------------------------------
   // values are re-applied and StartConditions are re-activated on change only
   if (!isParameterChange || StartConditions!=last.StartConditions) {
      start.conditions      = false;
      start.trend.condition = false;
      start.price.condition = false;
      start.time.condition  = false;

      // split StartConditions
      string exprs[], expr, key;
      int    iValue, time, sizeOfElems, sizeOfExprs = Explode(StartConditions, "&&", exprs, NULL);

      // parse and validate each expression
      for (int i=0; i < sizeOfExprs; i++) {
         start.conditions = false;                                // make sure in case of errors start.conditions is disabled

         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) {
            if (sizeOfExprs > 1)                                  return(_false(onInputError("ValidateInputs(16)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')                       return(_false(onInputError("ValidateInputs(17)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
         if (Explode(expr, "(", sValues, NULL) != 2)              return(_false(onInputError("ValidateInputs(18)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
         if (!StrEndsWith(sValues[1], ")"))                       return(_false(onInputError("ValidateInputs(19)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                                  return(_false(onInputError("ValidateInputs(20)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));

         if (key == "@trend") {
            if (start.trend.condition)                            return(_false(onInputError("ValidateInputs(21)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (multiple trend conditions)", interactive)));
            if (start.price.condition)                            return(_false(onInputError("ValidateInputs(22)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (trend and price conditions)", interactive)));
            if (start.time.condition)                             return(_false(onInputError("ValidateInputs(23)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (trend and time conditions)", interactive)));
            size = Explode(sValue, ":", sValues, NULL);
            if (size < 2 || size > 3)                             return(_false(onInputError("ValidateInputs(24)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
            sValue = StrTrim(sValues[0]);
            int idx = SearchStringArrayI(trendIndicators, sValue);
            if (idx == -1)                                        return(_false(onInputError("ValidateInputs(25)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (unsupported trend indicator "+ DoubleQuoteStr(sValue) +")", interactive)));
            start.trend.indicator = StrToLower(sValue);
            start.trend.timeframe = StrToPeriod(sValues[1], F_ERR_INVALID_PARAMETER);
            if (start.trend.timeframe == -1)                      return(_false(onInputError("ValidateInputs(26)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (trend indicator timeframe)", interactive)));
            if (size == 2) {
               start.trend.params = "";
            }
            else {
               start.trend.params = StrTrim(sValues[2]);
               if (!StringLen(start.trend.params))                return(_false(onInputError("ValidateInputs(27)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (trend indicator parameters)", interactive)));
            }
            exprs[i] = "trend("+ trendIndicators[idx] +":"+ TimeframeDescription(start.trend.timeframe) + ifString(size==2, "", ":") + start.trend.params +")";
            start.trend.description = exprs[i];
            start.trend.condition   = true;
         }

         else if (key=="@bid" || key=="@ask" || key=="@median" || key=="@price") {
            if (start.price.condition)                            return(_false(onInputError("ValidateInputs(28)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (multiple price conditions)", interactive)));
            sValue = StrReplace(sValue, "'", "");
            if (!StrIsNumeric(sValue))                            return(_false(onInputError("ValidateInputs(29)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (dValue <= 0)                                      return(_false(onInputError("ValidateInputs(30)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
            start.price.value     = NormalizeDouble(dValue, Digits);
            start.price.lastValue = NULL;
            if      (key == "@bid") start.price.type = PRICE_BID;
            else if (key == "@ask") start.price.type = PRICE_ASK;
            else                    start.price.type = PRICE_MEDIAN;
            exprs[i] = NumberToStr(start.price.value, PriceFormat);
            exprs[i] = StrSubstr(key, 1) +"("+ StrLeftTo(exprs[i], "'0") +")";   // cut "'0" for improved readability
            start.price.description = exprs[i];
            start.price.condition   = true;
         }

         else if (key == "@time") {
            if (start.time.condition)                             return(_false(onInputError("ValidateInputs(31)  invalid StartConditions "+ DoubleQuoteStr(StartConditions) +" (multiple time conditions)", interactive)));
            time = StrToTime(sValue);
            if (IsError(GetLastError()))                          return(_false(onInputError("ValidateInputs(32)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));
            // TODO: validation of @time is not sufficient
            start.time.value = time;
            exprs[i]         = "time("+ TimeToStr(time) +")";
            start.time.description = exprs[i];
            start.time.condition   = true;
         }
         else                                                     return(_false(onInputError("ValidateInputs(33)  invalid StartConditions "+ DoubleQuoteStr(StartConditions), interactive)));

         start.conditions = true;                                 // on success enable start.conditions
      }
   }

   // StopConditions, "OR" combined: @trend(<indicator>:<timeframe>:<params>) | @[bid|ask|median|price](1.33) | @time(12:00) | @[tp|profit](1234[%]) | @[sl|loss](1234[%])
   // --------------------------------------------------------------------------------------------------------------------------------------------------------------------
   // values are re-applied and StopConditions are re-activated on change only
   if (!isParameterChange || StopConditions!=last.StopConditions) {
      stop.trend.condition     = false;
      stop.price.condition     = false;
      stop.time.condition      = false;
      stop.profitAbs.condition = false;
      stop.profitPct.condition = false;
      stop.lossAbs.condition   = false;
      stop.lossPct.condition   = false;

      // split StopConditions
      sizeOfExprs = Explode(StrTrim(StopConditions), "||", exprs, NULL);

      // parse and validate each expression
      for (i=0; i < sizeOfExprs; i++) {
         expr = StrTrim(exprs[i]);
         if (!StringLen(expr)) {
            if (sizeOfExprs > 1)                                  return(_false(onInputError("ValidateInputs(34)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            break;
         }
         if (StringGetChar(expr, 0) != '@')                       return(_false(onInputError("ValidateInputs(35)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
         if (Explode(expr, "(", sValues, NULL) != 2)              return(_false(onInputError("ValidateInputs(36)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
         if (!StrEndsWith(sValues[1], ")"))                       return(_false(onInputError("ValidateInputs(37)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
         key = StrTrim(sValues[0]);
         sValue = StrTrim(StrLeft(sValues[1], -1));
         if (!StringLen(sValue))                                  return(_false(onInputError("ValidateInputs(38)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));

         if (key == "@trend") {
            if (stop.trend.condition)                             return(_false(onInputError("ValidateInputs(39)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (multiple trend conditions)", interactive)));
            size = Explode(sValue, ":", sValues, NULL);
            if (size < 2 || size > 3)                             return(_false(onInputError("ValidateInputs(40)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));


            sValue = StrTrim(sValues[0]);
            idx = SearchStringArrayI(trendIndicators, sValue);
            if (idx == -1)                                        return(_false(onInputError("ValidateInputs(41)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (unsupported trend indicator "+ DoubleQuoteStr(sValue) +")", interactive)));
            stop.trend.indicator = StrToLower(sValue);
            stop.trend.timeframe = StrToPeriod(sValues[1], F_ERR_INVALID_PARAMETER);
            if (stop.trend.timeframe == -1)                       return(_false(onInputError("ValidateInputs(42)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (trend indicator timeframe)", interactive)));
            if (size == 2) {
               stop.trend.params = "";
            }
            else {
               stop.trend.params = StrTrim(sValues[2]);
               if (!StringLen(stop.trend.params))                 return(_false(onInputError("ValidateInputs(43)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (trend indicator parameters)", interactive)));
            }
            exprs[i] = "trend("+ trendIndicators[idx] +":"+ TimeframeDescription(stop.trend.timeframe) + ifString(size==2, "", ":") + stop.trend.params +")";
            stop.trend.description = exprs[i];
            stop.trend.condition   = true;
         }

         else if (key=="@bid" || key=="@ask" || key=="@median" || key=="@price") {
            if (stop.price.condition)                             return(_false(onInputError("ValidateInputs(44)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (multiple price conditions)", interactive)));
            sValue = StrReplace(sValue, "'", "");
            if (!StrIsNumeric(sValue))                            return(_false(onInputError("ValidateInputs(45)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (dValue <= 0)                                      return(_false(onInputError("ValidateInputs(46)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            stop.price.value     = NormalizeDouble(dValue, Digits);
            stop.price.lastValue = NULL;
            if      (key == "@bid") stop.price.type = PRICE_BID;
            else if (key == "@ask") stop.price.type = PRICE_ASK;
            else                    stop.price.type = PRICE_MEDIAN;
            exprs[i] = NumberToStr(stop.price.value, PriceFormat);
            exprs[i] = StrSubstr(key, 1) +"("+ StrLeftTo(exprs[i], "'0") +")";   // cut "'0" for improved readability
            stop.price.description = exprs[i];
            stop.price.condition   = true;
         }

         else if (key == "@time") {
            if (stop.time.condition)                              return(_false(onInputError("ValidateInputs(47)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (multiple time conditions)", interactive)));
            time = StrToTime(sValue);
            if (IsError(GetLastError()))                          return(_false(onInputError("ValidateInputs(48)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            // TODO: validation of @time is not sufficient
            stop.time.value       = time;
            exprs[i]              = "time("+ TimeToStr(time) +")";
            stop.time.description = exprs[i];
            stop.time.condition   = true;
         }

         else if (key=="@tp" || key=="@profit") {
            if (stop.profitAbs.condition || stop.profitPct.condition)
                                                                  return(_false(onInputError("ValidateInputs(49)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (multiple takeprofit conditions)", interactive)));
            sizeOfElems = Explode(sValue, "%", sValues, NULL);
            if (sizeOfElems > 2)                                  return(_false(onInputError("ValidateInputs(50)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            sValue = StrTrim(sValues[0]);
            if (!StrIsNumeric(sValue))                            return(_false(onInputError("ValidateInputs(51)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (sizeOfElems == 1) {
               stop.profitAbs.value       = NormalizeDouble(dValue, 2);
               exprs[i]                   = "profit("+ DoubleToStr(dValue, 2) +")";
               stop.profitAbs.description = exprs[i];
               stop.profitAbs.condition   = true;
            }
            else {
               stop.profitPct.value       = dValue;
               stop.profitPct.absValue    = INT_MAX;
               exprs[i]                   = "profit("+ NumberToStr(dValue, ".+") +"%)";
               stop.profitPct.description = exprs[i];
               stop.profitPct.condition   = true;
            }
         }

         else if (key=="@sl" || key=="@loss") {
            if (stop.lossAbs.condition || stop.lossPct.condition)
                                                                  return(_false(onInputError("ValidateInputs(52)  invalid StopConditions "+ DoubleQuoteStr(StopConditions) +" (multiple stoploss conditions)", interactive)));
            sizeOfElems = Explode(sValue, "%", sValues, NULL);
            if (sizeOfElems > 2)                                  return(_false(onInputError("ValidateInputs(53)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            sValue = StrTrim(sValues[0]);
            if (!StrIsNumeric(sValue))                            return(_false(onInputError("ValidateInputs(54)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
            dValue = StrToDouble(sValue);
            if (sizeOfElems == 1) {
               stop.lossAbs.value       = NormalizeDouble(dValue, 2);
               exprs[i]                 = "loss("+ DoubleToStr(dValue, 2) +")";
               stop.lossAbs.description = exprs[i];
               stop.lossAbs.condition   = true;
            }
            else {
               stop.lossPct.value       = dValue;
               stop.lossPct.absValue    = INT_MIN;
               exprs[i]                 = "loss("+ NumberToStr(dValue, ".+") +"%)";
               stop.lossPct.description = exprs[i];
               stop.lossPct.condition   = true;
            }
         }
         else                                                     return(_false(onInputError("ValidateInputs(55)  invalid StopConditions "+ DoubleQuoteStr(StopConditions), interactive)));
      }
   }

   // AutoRestart
   sValue = StrToLower(AutoRestart);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (sValue == "")                      sValue = "off";
   else if (StrStartsWith("off",      sValue)) sValue = "off";
   else if (StrStartsWith("continue", sValue)) sValue = "continue";
   else if (StrStartsWith("reset",    sValue)) sValue = "reset";
   else                                                           return(_false(onInputError("ValidateInputs(56)  invalid AutoRestart option "+ DoubleQuoteStr(AutoRestart), interactive)));
   AutoRestart = StrCapitalize(sValue);

   // StartLevel
   if (isParameterChange) {
      if (StartLevel != last.StartLevel)
         if (ArraySize(sequence.start.event) > 0)                 return(_false(onInputError("ValidateInputs(57)  cannot change StartLevel of "+ StatusDescription(sequence.status) +" sequence", interactive)));
   }
   if (sequence.direction == D_LONG) {
      if (StartLevel < 0)                                         return(_false(onInputError("ValidateInputs(58)  invalid StartLevel: "+ StartLevel, interactive)));
   }
   StartLevel = Abs(StartLevel);

   // ShowProfitInPercent: nothing to validate

   // Sessionbreak.StartTime/EndTime
   if (Sessionbreak.StartTime!=last.Sessionbreak.StartTime || Sessionbreak.EndTime!=last.Sessionbreak.EndTime) {
      sessionbreak.starttime = NULL;
      sessionbreak.endtime   = NULL;                              // real times are updated automatically on next use
   }
   return(!catch("ValidateInputs(59)"));
}


/**
 * Error handler for invalid input parameters. Depending on the execution context the functions sets a terminating error.
 *
 * @param  string message     - error message
 * @param  bool   interactive - whether the error occurred in an interactive or non-interactive context
 *
 * @return int - resulting error status
 */
int onInputError(string message, bool interactive) {
   interactive = interactive!=0;
   int error = ERR_INVALID_PARAMETER;

   if (IsTesting() || !interactive)
      return(catch(message, error));

   logNotice(message, error);

   string location = StrLeftTo(message, " ");
   message = StrCapitalize(StrTrim(StrSubstr(message, StringLen(location))));

   PlaySoundEx("Windows Chord.wav");
   MessageBoxEx(ProgramName() +" - "+ location, message, MB_ICONERROR|MB_OK);
   return(error);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Sequence.ID=",            DoubleQuoteStr(Sequence.ID),                  ";", NL,
                            "GridDirection=",          DoubleQuoteStr(GridDirection),                ";", NL,
                            "GridSize=",               GridSize,                                     ";", NL,
                            "UnitSize=",               DoubleQuoteStr(UnitSize),                     ";", NL,
                            "StartConditions=",        DoubleQuoteStr(StartConditions),              ";", NL,
                            "StopConditions=",         DoubleQuoteStr(StopConditions),               ";", NL,
                            "AutoRestart=",            DoubleQuoteStr(AutoRestart),                  ";", NL,
                            "StartLevel=",             StartLevel,                                   ";", NL,
                            "ShowProfitInPercent=",    BoolToStr(ShowProfitInPercent),               ";", NL,
                            "Sessionbreak.StartTime=", TimeToStr(Sessionbreak.StartTime, TIME_FULL), ";", NL,
                            "Sessionbreak.EndTime=",   TimeToStr(Sessionbreak.EndTime, TIME_FULL),   ";")
   );
}

/**
 * TradeCommand
 *
 * An EA monitoring an indicator and/or an order, waiting for a condition to execute a predefined trade command.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string __a___________________________ = "=== Compare(Indicator @condition Value) ===";

extern string Compare.Time                   = "onTick* | onBarOpen";
extern string Compare.Condition              = "GT* | GE | EQ | NE | LE | LT";                     // TODO: no default

extern string __b___________________________;
extern string Indicator.Name                 = "SMA | LWMA | EMA* | SMMA | ALMA | JMA";            // TODO: no default
extern string Indicator.Timeframe            = "M1 | M15 | M30* | ...";                            // TODO: no default
extern string Indicator.Params               = "<params>";
extern int    Indicator.Buffer               = 0;
extern int    Indicator.Offset               = 0;

extern string __c___________________________;
extern string CompareWith                    = "Bid* | Ask | Median | {number} | Entry | Exit";    // TODO: no default

extern string __d___________________________;
extern string TradeCmd.Type                  = "Buy* | Sell | Trail";                              // TODO: no default
extern double TradeCmd.Lots                  = 0.1;                                                // TODO: 0
extern string TradeCmd.Tickets               = "";
extern string TradeCmd.TrailStep             = "{pip}";
extern string TradeCmd.TrailPause            = "{seconds}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>

#define COMPARATER_GT   1
#define COMPARATER_GE   2
#define COMPARATER_EQ   3
#define COMPARATER_NE   4
#define COMPARATER_LE   5
#define COMPARATER_LT   6

// supported indicators
string indicators[] = {"SMA", "LWMA", "EMA", "SMMA", "ALMA", "JMA"};


/**
 * Called after the expert was manually loaded by the user. Also in tester with both "VisualMode=On|Off".
 * There was an input dialog.
 *
 * @return int - error status
 */
int onInitUser() {
   ValidateInputs();
   return(last_error);
}


/**
 * Called after the input parameters were changed through the input dialog.
 *
 * @return int - error status
 */
int onInitParameters() {
   if (!ValidateInputs()) RestoreInputs();
   return(last_error);
}


/**
 * Called after the current chart period has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTimeframeChange() {
   RestoreInputs();
   return(last_error);
}


/**
 * Called after the chart symbol has changed. There was no input dialog.
 *
 * @return int - error status
 */
int onInitSymbolChange() {
   return(catch("onInitSymbolChange(1)", ERR_ILLEGAL_STATE));
}


/**
 * Called after the expert was loaded by a chart template. Also at terminal start. There was no input dialog.
 *
 * @return int - error status
 */
int onInitTemplate() {
   return(catch("onInitTemplate(1)", ERR_NOT_IMPLEMENTED));
}


/**
 * Called before input parameters change.
 *
 * @return int - error status
 */
int onDeinitParameters() {
   BackupInputs();
   return(-1);                                              // -1: skip all other deinit tasks
}


/**
 * Called before the current chart symbol or timeframe change.
 *
 * @return int - error status
 */
int onDeinitChartChange() {
   BackupInputs();
   return(-1);                                              // -1: skip all other deinit tasks
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // TODO: observe session break times
   return(catch("onTick(1)"));
}


/**
 * Validate input parameters. Parameters may have been entered through the input dialog or deserialized and applied
 * programmatically by the terminal (e.g. at terminal restart). Called from onInitUser() and onInitParameters().
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   if (IsLastError()) return(false);
   bool isParameterChange = (ProgramInitReason()==IR_PARAMETERS);

   // Compare.Time
   string sValues[], sValue = Compare.Time;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   int _compareTime;
   if      (sValue == "ontick"   ) _compareTime = BARMODEL_EVERYTICK;
   else if (sValue == "onbaropen") _compareTime = BARMODEL_BAROPEN;
   else return(!onInputError("ValidateInputs(1)  invalid input parameter Compare.Time: "+ DoubleQuoteStr(Compare.Time)));

   // Compare.Condition
   sValue = Compare.Condition;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   int _comparator;
   if      (sValue == "gt") _comparator = COMPARATER_GT;
   else if (sValue == "ge") _comparator = COMPARATER_GE;
   else if (sValue == "eq") _comparator = COMPARATER_EQ;
   else if (sValue == "ne") _comparator = COMPARATER_NE;
   else if (sValue == "le") _comparator = COMPARATER_LE;
   else if (sValue == "lt") _comparator = COMPARATER_LT;
   else return(!onInputError("ValidateInputs(2)  invalid input parameter Compare.Condition: "+ DoubleQuoteStr(Compare.Condition)));

   // Indicator.Name
   sValue = Indicator.Name;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   int index = SearchStringArrayI(indicators, sValue);
   if (index == -1) return(!onInputError("ValidateInputs(3)  invalid input parameter Indicator.Name: "+ DoubleQuoteStr(Indicator.Name) +" (unsupported)"));
   string _indicatorName = sValue;

   // Indicator.Timeframe
   sValue = Indicator.Timeframe;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   int _indicatorTimeframe = StrToPeriod(sValue, F_ERR_INVALID_PARAMETER);
   if (_indicatorTimeframe == -1) return(!onInputError("ValidateInputs(4)  invalid input parameter Indicator.Timeframe: "+ DoubleQuoteStr(Indicator.Timeframe)));

   // Indicator.Params
   string _indicatorParams = StrTrim(Indicator.Params);

   // Indicator.Buffer;
   if (Indicator.Buffer < 0) return(!onInputError("ValidateInputs(5)  invalid input parameter Indicator.Buffer: "+ Indicator.Buffer +" (negative)"));
   int _indicatorBuffer = Indicator.Buffer;

   // Indicator.Offset
   if (Indicator.Offset < 0) return(!onInputError("ValidateInputs(6)  invalid input parameter Indicator.Offset: "+ Indicator.Offset +" (negative)"));
   int _indicatorOffset = Indicator.Offset;

   // CompareWith
   sValue = CompareWith;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   string _compareWith = "";
   double _compareValue = 0;
   if      (sValue == "bid"     )   _compareWith = sValue;
   else if (sValue == "ask"     )   _compareWith = sValue;
   else if (sValue == "median"  )   _compareWith = sValue;
   else if (sValue == "entry"   )   _compareWith = sValue;
   else if (sValue == "exit"    )   _compareWith = sValue;
   else if (StrIsNumeric(sValue)) { _compareWith = "value"; _compareValue = StrToDouble(sValue); }
   else return(!onInputError("ValidateInputs(7)  invalid input parameter CompareWith: "+ DoubleQuoteStr(CompareWith)));

   // TradeCmd.Type
   sValue = TradeCmd.Type;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   string _tradeCmdType = "";
   if      (sValue == "buy"  ) _tradeCmdType = sValue;
   else if (sValue == "sell" ) _tradeCmdType = sValue;
   else if (sValue == "trail") _tradeCmdType = sValue;
   else return(!onInputError("ValidateInputs(8)  invalid input parameter TradeCmd.Type: "+ DoubleQuoteStr(TradeCmd.Type)));
   if (_compareWith=="entry" || _compareWith=="exit") {
      if (_tradeCmdType != "trail")                      return(!onInputError("ValidateInputs(9)  input parameter mis-match CompareWith/TradeCmd.Type: "+ DoubleQuoteStr(CompareWith) +"/"+ DoubleQuoteStr(TradeCmd.Type)));
   }
   else {
      if (_tradeCmdType!="buy" && _tradeCmdType!="sell") return(!onInputError("ValidateInputs(10)  input parameter mis-match CompareWith/TradeCmd.Type: "+ DoubleQuoteStr(CompareWith) +"/"+ DoubleQuoteStr(TradeCmd.Type)));
   }

   // TradeCmd.Lots
   double _tradeCmdLots = 0;
   if (_tradeCmdType=="buy" || _tradeCmdType=="sell") {
      if (TradeCmd.Lots < 0)                               return(!onInputError("ValidateInputs(11)  invalid input parameter TradeCmd.Lots: "+ NumberToStr(TradeCmd.Lots, ".1+") +" (negative)"));
      if (NE(TradeCmd.Lots, NormalizeLots(TradeCmd.Lots))) return(!onInputError("ValidateInputs(12)  illegal input parameter TradeCmd.Lots: "+ NumberToStr(TradeCmd.Lots, ".1+") +" (lot step error)"));
      _tradeCmdLots = TradeCmd.Lots;
   }

   // TradeCmd.Tickets
   int _tradeCmdTickets[]; ArrayResize(_tradeCmdTickets, 0);
   if (_tradeCmdType == "trail") {
      OrderPush("ValidateInputs(13)");
      sValue = TradeCmd.Tickets;
      size = Explode(sValue, ",", sValues, NULL);
      if (size != 1)                                      return(!onInputError("ValidateInputs(14)  invalid input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (not a single ticket id)"));
      ArrayResize(_tradeCmdTickets, size);
      for (int i=0; i < size; i++) {
         sValue = StrTrim(sValues[i]);
         if (!StrIsDigit(sValue))                         return(!onInputError("ValidateInputs(15)  invalid field in input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (not a ticket id)"));
         int iValue = StrToInteger(sValue);
         if (!SelectTicket(iValue, "ValidateInputs(16)")) return(!onInputError("ValidateInputs(17)  invalid field in input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (invalid ticket)"));
         if (OrderCloseTime() > 0)                        return(!onInputError("ValidateInputs(18)  invalid field in input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (not an open ticket)"));
         _tradeCmdTickets[i] = iValue;
      }
      OrderPop("ValidateInputs(19)");
   }

   // TradeCmd.TrailStep
   int _tradeCmdTrailStep = 0;
   if (_tradeCmdType == "trail") {
      sValue = StrTrim(TradeCmd.TrailStep);
      if (!StrIsDigit(sValue)) return(!onInputError("ValidateInputs(20)  invalid input parameter TradeCmd.TrailStep: "+ DoubleQuoteStr(TradeCmd.TrailStep) +" (not an integer >= 0)"));
      _tradeCmdTrailStep = StrToInteger(sValue);
   }

   // TradeCmd.TrailPause
   int _tradeCmdTrailPause = 0;
   if (_tradeCmdType == "trail") {
      sValue = StrTrim(TradeCmd.TrailPause);
      if (!StrIsDigit(sValue)) return(!onInputError("ValidateInputs(21)  invalid input parameter TradeCmd.TrailPause: "+ DoubleQuoteStr(TradeCmd.TrailPause) +" (not an integer >= 0)"));
      _tradeCmdTrailPause = StrToInteger(sValue);
   }

   return(true);
}


/**
 * Programatically changed input parameters don't survive init cycles. Therefore inputs are backed-up in deinit() and may be
 * restored in init(). Called from onDeinitParameters() and onDeinitChartChange().
 */
void BackupInputs() {
}


/**
 * Restore backed-up input parameters. Called from onInitParameters() and onInitTimeframeChange().
 */
void RestoreInputs() {
}


/**
 * Error handler for invalid input parameters. Depending on the execution context a non-/terminating error is set.
 *
 * @param  string message - error message
 *
 * @return int - error status
 */
int onInputError(string message) {
   int error = ERR_INVALID_PARAMETER;

   if (ProgramInitReason() == IR_PARAMETERS)
      return(logError(message, error));                      // non-terminating
   return(catch(message, error));
}

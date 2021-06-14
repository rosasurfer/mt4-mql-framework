/**
 * TradeCommand
 *
 * An EA monitoring an indicator and/or an order, waiting for a condition to execute a predefined trade command.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string __a___________________________ = "=== When(Indicator @comparator WithValue) ===";

extern string CompareWhen                    = "onTick* | onBarOpen";
extern string Comparator                     = "GT* | GE | EQ | NE | LE | LT";                     // TODO: no default

extern string __b___________________________;
extern string Indicator.Name                 = "SMA | LWMA | EMA* | SMMA | ALMA | JMA";            // TODO: no default
extern string Indicator.Timeframe            = "M1 | M15 | M30* | ...";                            // TODO: no default
extern string Indicator.Params               = "<params>";
extern int    Indicator.Buffer               = 0;
extern int    Indicator.Offset               = 0;

extern string __c___________________________;
extern string CompareWithValue               = "Bid* | Ask | Median | {number} | Entry | Exit";    // TODO: no default

extern string __d___________________________;
extern string TradeCmd.Type                  = "Buy* | Sell | Trail";                              // TODO: no default
extern double TradeCmd.Lots                  = 0.1;                                                // TODO: 0
extern string TradeCmd.Tickets               = "#";
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

string indicatorName;
int    indicatorTimeframe;
string indicatorParams;
int    indicatorBuffer;
int    indicatorOffset;

int    comparator;
int    compareWhen;
string compareWith;
double compareValue;

string tradeCmdType;
double tradeCmdLots;
int    tradeCmdTickets[];
int    tradeCmdTrailStep;
int    tradeCmdTrailPause;

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

   // CompareWhen
   string sValues[], sValue = CompareWhen;
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   int _compareWhen;
   if      (sValue == "ontick"   ) _compareWhen = BARMODEL_EVERYTICK;
   else if (sValue == "onbaropen") _compareWhen = BARMODEL_BAROPEN;
   else return(!onInputError("ValidateInputs(1)  invalid input parameter CompareWhen: "+ DoubleQuoteStr(CompareWhen)));

   // Comparator
   sValue = Comparator;
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
   else return(!onInputError("ValidateInputs(2)  invalid input parameter Comparator: "+ DoubleQuoteStr(Comparator)));

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

   // CompareWithValue
   sValue = CompareWithValue;
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
   else return(!onInputError("ValidateInputs(7)  invalid input parameter CompareWithValue: "+ DoubleQuoteStr(CompareWithValue)));

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
      if (_tradeCmdType != "trail")                        return(!onInputError("ValidateInputs(9)  input parameter mis-match CompareWithValue/TradeCmd.Type: "+ DoubleQuoteStr(CompareWithValue) +"/"+ DoubleQuoteStr(TradeCmd.Type)));
   }
   else {
      if (_tradeCmdType!="buy" && _tradeCmdType!="sell")   return(!onInputError("ValidateInputs(10)  input parameter mis-match CompareWithValue/TradeCmd.Type: "+ DoubleQuoteStr(CompareWithValue) +"/"+ DoubleQuoteStr(TradeCmd.Type)));
   }

   // TradeCmd.Lots
   double _tradeCmdLots = 0;
   if (_tradeCmdType=="buy" || _tradeCmdType=="sell") {
      if (TradeCmd.Lots <= 0)                              return(!onInputError("ValidateInputs(11)  invalid input parameter TradeCmd.Lots: "+ NumberToStr(TradeCmd.Lots, ".1+") +" (negative)"));
      if (NE(TradeCmd.Lots, NormalizeLots(TradeCmd.Lots))) return(!onInputError("ValidateInputs(12)  illegal input parameter TradeCmd.Lots: "+ NumberToStr(TradeCmd.Lots, ".1+") +" (lot step error)"));
      _tradeCmdLots = TradeCmd.Lots;
   }
   else if (TradeCmd.Lots != 0)                            return(!onInputError("ValidateInputs(13)  input parameter mis-match TradeCmd.Type/TradeCmd.Lots: "+ DoubleQuoteStr(TradeCmd.Type) +"/"+ NumberToStr(TradeCmd.Lots, ".1+")));

   // TradeCmd.Tickets
   int _tradeCmdTickets[]; ArrayResize(_tradeCmdTickets, 0);
   sValue = StrTrim(TradeCmd.Tickets);
   if (sValue == "#") sValue = "";
   if (_tradeCmdType == "trail") {
      OrderPush("ValidateInputs(14)");
      size = Explode(sValue, ",", sValues, NULL);
      if (size != 1)                                       return(!onInputError("ValidateInputs(15)  invalid input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (not a single ticket id)"));
      ArrayResize(_tradeCmdTickets, size);
      for (int i=0; i < size; i++) {
         sValue = StrTrim(sValues[i]);
         if (!StrIsDigit(sValue))                          return(!onInputError("ValidateInputs(16)  invalid field in input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (not a ticket id)"));
         int iValue = StrToInteger(sValue);
         if (!SelectTicket(iValue, "ValidateInputs(17)"))  return(!onInputError("ValidateInputs(18)  invalid field in input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (invalid ticket)"));
         if (OrderCloseTime() > 0)                         return(!onInputError("ValidateInputs(19)  invalid field in input parameter TradeCmd.Tickets: "+ DoubleQuoteStr(sValue) +" (not an open ticket)"));
         _tradeCmdTickets[i] = iValue;
      }
      OrderPop("ValidateInputs(20)");
   }
   else if (sValue != "")                                  return(!onInputError("ValidateInputs(21)  input parameter mis-match TradeCmd.Type/TradeCmd.Tickets: "+ DoubleQuoteStr(TradeCmd.Type) +"/"+ DoubleQuoteStr(TradeCmd.Tickets)));

   // TradeCmd.TrailStep
   int _tradeCmdTrailStep = 0;
   if (_tradeCmdType == "trail") {
      sValue = StrTrim(TradeCmd.TrailStep);
      if (!StrIsDigit(sValue))                             return(!onInputError("ValidateInputs(22)  invalid input parameter TradeCmd.TrailStep: "+ DoubleQuoteStr(TradeCmd.TrailStep) +" (not an integer >= 0)"));
      _tradeCmdTrailStep = StrToInteger(sValue);
   }
   else if (StrTrim(TradeCmd.TrailStep) != "{pip}")        return(!onInputError("ValidateInputs(23)  input parameter mis-match TradeCmd.Type/TradeCmd.TrailStep: "+ DoubleQuoteStr(TradeCmd.Type) +"/"+ DoubleQuoteStr(TradeCmd.TrailStep)));

   // TradeCmd.TrailPause
   int _tradeCmdTrailPause = 0;
   if (_tradeCmdType == "trail") {
      sValue = StrTrim(TradeCmd.TrailPause);
      if (!StrIsDigit(sValue))                             return(!onInputError("ValidateInputs(24)  invalid input parameter TradeCmd.TrailPause: "+ DoubleQuoteStr(TradeCmd.TrailPause) +" (not an integer >= 0)"));
      _tradeCmdTrailPause = StrToInteger(sValue);
   }
   else if (StrTrim(TradeCmd.TrailPause) != "{seconds}")   return(!onInputError("ValidateInputs(25)  input parameter mis-match TradeCmd.Type/TradeCmd.TrailPause: "+ DoubleQuoteStr(TradeCmd.Type) +"/"+ DoubleQuoteStr(TradeCmd.TrailPause)));

   // success: apply inputs
   compareWhen        = _compareWhen;
   comparator         = _comparator;

   indicatorName      = _indicatorName;
   indicatorTimeframe = _indicatorTimeframe;
   indicatorParams    = _indicatorParams;
   indicatorBuffer    = _indicatorBuffer;
   indicatorOffset    = _indicatorOffset;

   compareWith        = _compareWith;
   compareValue       = _compareValue;

   tradeCmdType       = _tradeCmdType;
   tradeCmdLots       = _tradeCmdLots;
   tradeCmdTrailStep  = _tradeCmdTrailStep;
   tradeCmdTrailPause = _tradeCmdTrailPause;

   ArrayResize(tradeCmdTickets, 0);
   if (ArraySize(_tradeCmdTickets) > 0) ArrayCopy(tradeCmdTickets, _tradeCmdTickets);

   return(!catch("ValidateInputs(26)"));
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

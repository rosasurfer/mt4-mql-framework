/**
 * TradeCommand
 *
 * An EA monitoring an indicator or existing order, waiting for a condition to execute a predefined trade command.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string __a___________________________ = "=== Compare(Indicator @condition Value) ===";

extern string Compare.Time                   = "onTick* | onBarOpen";
extern string Compare.Condition              = "GT* | GE | EQ | NE | LE | LT";                     // TODO: no default

extern string __b___________________________;
extern string Indicator.Name                 = "EMA";                                              // TODO: no default
extern string Indicator.Timeframe            = "current* | M1 | M15 | M30...";
extern string Indicator.Params               = "<params>";
extern int    Indicator.Buffer               = 0;
extern int    Indicator.Offset               = 0;

extern string __c___________________________;
extern string CompareWith.Value              = "Bid* | Ask | Median | {number} | Entry | Exit";    // TODO: no default

extern string __d___________________________;
extern string TradeCmd.Type                  = "Buy* | Sell | Trail";                              // TODO: no default
extern double TradeCmd.Lots                  = 0.1;                                                // TODO: 0
extern int    TradeCmd.Ticket                = 0;
extern string TradeCmd.TrailStep             = "{pip}";
extern string TradeCmd.TrailPause            = "{seconds}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>


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
   return(catch("onTick(1)"));
}


/**
 * Validate input parameters. Parameters may have been entered through the input dialog or have been deserialized and applied
 * programmatically by the terminal (e.g. at terminal restart).
 *
 * @return bool - whether input parameters are valid
 */
bool ValidateInputs() {
   return(false);
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

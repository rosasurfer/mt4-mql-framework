/**
 * Vegas EA (don't use, work-in-progress)
 *
 * A hybrid strategy using ideas of the "Vegas H1 Tunnel" system, the system of the "Turtle Traders" and a regular grid.
 *
 *
 *  @see  https://www.forexfactory.com/thread/4365-all-vegas-documents-located-here#                 [Vegas H1 Tunnel Method]
 *  @see  https://analyzingalpha.com/turtle-trading#                                                         [Turtle Trading]
 *  @see  https://github.com/rosasurfer/mt4-mql/blob/master/mql4/experts/Duel.mq4#                             [Duel Grid EA]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_PIPVALUE, INIT_BUFFERED_LOG};
int __DeinitFlags[];
int __virtualTicks = 0;

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Instance.ID = "";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/HandleCommands.mqh>
#include <functions/iCustom/MaTunnel.mqh>

#define STRATEGY_ID         108                    // unique strategy id (10 bit, between 100-999)

#define STATUS_PROGRESSING    1                    // instance status values
#define STATUS_STOPPED        2

// instance data
int      instance.id;                              // instance id between 100-999
datetime instance.created;
string   instance.name = "";
int      instance.status;
bool     instance.isTest;


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!instance.status) return(ERR_ILLEGAL_STATE);

   if (__isChart) HandleCommands();                // process incoming commands

   switch (instance.status) {
      case STATUS_PROGRESSING: break;
      case STATUS_STOPPED:     break;
   }
   return(catch("onTick(1)"));

   double value = icMaTunnel(NULL, "EMA(36)", 0, 0);
   debug("onTick(0.1)  Tick="+ Ticks +"  MaTunnel[0]="+ NumberToStr(value, PriceFormat));
}


/**
 * Process an incoming command.
 *
 * @param  string cmd    - command name
 * @param  string params - command parameters
 * @param  int    keys   - pressed modifier keys
 *
 * @return bool - success status of the executed command
 */
bool onCommand(string cmd, string params, int keys) {
   string fullCmd = cmd +":"+ params +":"+ keys;

   if (cmd == "start") {
      if (instance.status == STATUS_STOPPED) {
         logInfo("onCommand(1)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
         return(StartInstance(NULL));
      }
   }
   else if (cmd == "stop") {
      if (instance.status == STATUS_PROGRESSING) {
         logInfo("onCommand(2)  "+ instance.name +" "+ DoubleQuoteStr(fullCmd));
         return(StopInstance(NULL));
      }
   }
   else return(!logNotice("onCommand(3)  "+ instance.name +" unsupported command: "+ DoubleQuoteStr(fullCmd)));

   return(!logWarn("onCommand(4)  "+ instance.name +" cannot execute command "+ DoubleQuoteStr(fullCmd) +" in status "+ StatusToStr(instance.status)));
}


/**
 * Restart a stopped instance.
 *
 * @param  int signal - trade signal causing the call or NULL on explicit start (i.e. manual)
 *
 * @return bool - success status
 */
bool StartInstance(int signal) {
   if (last_error != NULL)                return(false);
   if (instance.status != STATUS_STOPPED) return(!catch("StartInstance(1)  "+ instance.name +" cannot start "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   return(true);
}


/**
 * Stop a progressing instance and close open positions (if any).
 *
 * @param  int signal - trade signal causing the call or NULL on explicit stop (i.e. manual)
 *
 * @return bool - success status
 */
bool StopInstance(int signal) {
   if (last_error != NULL)                    return(false);
   if (instance.status != STATUS_PROGRESSING) return(!catch("StopInstance(1)  "+ instance.name +" cannot stop "+ StatusDescription(instance.status) +" instance", ERR_ILLEGAL_STATE));
   return(true);
}


/**
 * Return a readable presentation of an instance status code.
 *
 * @param  int status
 *
 * @return string
 */
string StatusToStr(int status) {
   switch (status) {
      case NULL              : return("(NULL)"            );
      case STATUS_PROGRESSING: return("STATUS_PROGRESSING");
      case STATUS_STOPPED    : return("STATUS_STOPPED"    );
   }
   return(_EMPTY_STR(catch("StatusToStr(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a description of an instance status code.
 *
 * @param  int status
 *
 * @return string - description or an empty string in case of errors
 */
string StatusDescription(int status) {
   switch (status) {
      case NULL              : return("undefined"  );
      case STATUS_PROGRESSING: return("progressing");
      case STATUS_STOPPED    : return("stopped"    );
   }
   return(_EMPTY_STR(catch("StatusDescription(1)  "+ instance.name +" invalid parameter status: "+ status, ERR_INVALID_PARAMETER)));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Instance.ID=", DoubleQuoteStr(Instance.ID), ";"));
}

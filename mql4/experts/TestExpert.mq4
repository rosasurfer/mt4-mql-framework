/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
//#include <core/expert.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#include <timezones.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   datetime time = D'2011.01.03 05:59:59';
   int lastTransition[], nextTransition[];

   if (GetServerTimezoneTransitions(time, lastTransition, nextTransition)) {
      debug("init()   time="+ DateToStr(time, "w, D.M.Y H:I"));

      if (lastTransition[I_TRANSITION_TIME] >= 0) debug("init()   lastTransition="+ DateToStr(lastTransition[I_TRANSITION_TIME], "w, D.M.Y H:I") +" ("+ ifString(lastTransition[I_TRANSITION_OFFSET]>=0, "+", "") + (lastTransition[I_TRANSITION_OFFSET]/HOURS) +"), DST="+ lastTransition[I_TRANSITION_DST]);
      else                                        debug("init()   lastTransition="+ lastTransition[I_TRANSITION_TIME]);

      if (nextTransition[I_TRANSITION_TIME] >= 0) debug("init()   nextTransition="+ DateToStr(nextTransition[I_TRANSITION_TIME], "w, D.M.Y H:I") +" ("+ ifString(nextTransition[I_TRANSITION_OFFSET]>=0, "+", "") + (nextTransition[I_TRANSITION_OFFSET]/HOURS) +"), DST="+ nextTransition[I_TRANSITION_DST]);
      else                                        debug("init()   nextTransition="+ nextTransition[I_TRANSITION_TIME]);
   }
   return(0);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   return(last_error);
   catch(NULL);
}

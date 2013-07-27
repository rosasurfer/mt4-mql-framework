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

      if (lastTransition[TR_TIME] >= 0) debug("init()   lastTransition="+ DateToStr(lastTransition[TR_TIME], "w, D.M.Y H:I") +" ("+ ifString(lastTransition[TR_OFFSET]>=0, "+", "") + (lastTransition[TR_OFFSET]/HOURS) +"), DST="+ lastTransition[TR_DST]);
      else                              debug("init()   lastTransition="+ lastTransition[TR_TIME]);

      if (nextTransition[TR_TIME] >= 0) debug("init()   nextTransition="+ DateToStr(nextTransition[TR_TIME], "w, D.M.Y H:I") +" ("+ ifString(nextTransition[TR_OFFSET]>=0, "+", "") + (nextTransition[TR_OFFSET]/HOURS) +"), DST="+ nextTransition[TR_DST]);
      else                              debug("init()   nextTransition="+ nextTransition[TR_TIME]);
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

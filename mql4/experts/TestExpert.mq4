/**
 * TestExpert
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/expert.mqh>


//////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////

extern string sParameter = "dummy";
extern int    iParameter = 12345;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#include <iCustom/icEventTracker.mqh>
#include <timezones.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   /*
   datetime time = D'2011.01.03 05:59:59';
   int lastTransition[], nextTransition[];

   if (GetServerTimezoneTransitions(time, lastTransition, nextTransition)) {
      debug("onInit()   time="+ DateToStr(time, "w, D.M.Y H:I"));

      if (lastTransition[I_TRANSITION_TIME] >= 0) debug("onInit()   lastTransition="+ DateToStr(lastTransition[I_TRANSITION_TIME], "w, D.M.Y H:I") +" ("+ ifString(lastTransition[I_TRANSITION_OFFSET]>=0, "+", "") + (lastTransition[I_TRANSITION_OFFSET]/HOURS) +"), DST="+ lastTransition[I_TRANSITION_DST]);
      else                                        debug("onInit()   lastTransition="+ lastTransition[I_TRANSITION_TIME]);

      if (nextTransition[I_TRANSITION_TIME] >= 0) debug("onInit()   nextTransition="+ DateToStr(nextTransition[I_TRANSITION_TIME], "w, D.M.Y H:I") +" ("+ ifString(nextTransition[I_TRANSITION_OFFSET]>=0, "+", "") + (nextTransition[I_TRANSITION_OFFSET]/HOURS) +"), DST="+ nextTransition[I_TRANSITION_DST]);
      else                                        debug("onInit()   nextTransition="+ nextTransition[I_TRANSITION_TIME]);
   }
   */
   return(0);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {

   if (!icEventTracker(PERIOD_H1))
      return(last_error);

   return(last_error);
   catch(NULL);
}


/**
 * Zeigt den aktuellen Laufzeitstatus an.
 *
 * @param  int error - anzuzeigender Fehler
 *
 * @return int - derselbe Fehler oder der aktuelle Fehlerstatus, falls kein Fehler übergeben wurde
 */
int ShowStatus(int error=NO_ERROR) {
   if (!IsChart)
      return(error);

   string str.error;

   if      (__STATUS_INVALID_INPUT) str.error = StringConcatenate("  [", ErrorDescription(ERR_INVALID_INPUT_PARAMVALUE), "]");
   else if (__STATUS_ERROR        ) str.error = StringConcatenate("  [", ErrorDescription(last_error                  ), "]");


   // 3 Zeilen Abstand nach oben für Instrumentanzeige und ggf. vorhandene Legende
   Comment(StringConcatenate(NL, NL, NL, __NAME__, str.error));
   if (__WHEREAMI__ == FUNC_INIT)
      WindowRedraw();

   if (!catch("ShowStatus()"))
      return(error);
   return(last_error);
}

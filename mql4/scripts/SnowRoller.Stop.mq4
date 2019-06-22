/**
 * SnowRoller.Stop
 *
 * Send a chart command to SnowRoller to stop the current sequence.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <app/SnowRoller/defines.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string label = "SnowRoller.command";
   string mutex = "mutex."+ label;
   string sid = "";
   int status;

   // check chart for a SnowRoller ready to start
   if (ObjectFind("SnowRoller.status") == 0) {
      string text = StrToUpper(StrTrim(ObjectDescription(label)));   // [T]{iSid}|{iStatus}
      sid = StrLeftTo(text, "|");

      status = StrToInteger(StrRightFrom(text, "|"));
      switch (status) {
         case STATUS_WAITING:
         case STATUS_STARTING:
         case STATUS_PROGRESSING:                                    // those are OK if not a test outside of tester
            if (StringGetChar(sid, 0)!='T' || This.IsTesting())
               break;
         default:
            status = 0;
      }
   }

   if (status != 0) {
      // confirm sending the command
      PlaySoundEx("Windows Notify.wav");
      int button = MessageBoxEx(__NAME(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to stop sequence "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) return(ERR_CANCELLED_BY_USER);

      // aquire write-lock
      if (!AquireLock(mutex, true)) return(ERR_RUNTIME_ERROR);

      // set command
      if (ObjectFind(label) != 0) {
         if (!ObjectCreate(label, OBJ_LABEL, 0, 0, 0))                return(_int(catch("onStart(1)"), ReleaseLock(mutex)));
         if (!ObjectSet(label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE)) return(_int(catch("onStart(2)"), ReleaseLock(mutex)));
      }
      ObjectSetText(label, "stop");

      // release lock and notify the chart
      if (!ReleaseLock(mutex)) return(ERR_RUNTIME_ERROR);
      Chart.SendTick();
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(__NAME(), "No running sequence found.", MB_ICONEXCLAMATION|MB_OK);
   }

   return(catch("onStart(3)"));
}

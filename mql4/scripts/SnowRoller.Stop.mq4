/**
 * SnowRoller.Stop
 *
 * Send a chart command to SnowRoller to stop the current sequence.
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <apps/snowroller/defines.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // Each SnowRoller instance maintains a chart object holding the sequence id and the current sequence status.
   string sid="", statusLabel="SnowRoller.status";
   int status;
   bool isStoppable = false;

   // check chart for a stoppable SnowRoller instance
   if (ObjectFind(statusLabel) == 0) {
      string text = StrToUpper(StrTrim(ObjectDescription(statusLabel)));   // [T]{iSid}|{iStatus}
      sid    = StrLeftTo(text, "|");
      status = StrToInteger(StrRightFrom(text, "|"));

      switch (status) {
         case STATUS_WAITING:
         case STATUS_STARTING:
         case STATUS_PROGRESSING:
            bool isTestSequence = StrStartsWith(sid, "T");
            isStoppable = (This.IsTesting() || !isTestSequence);           // a finished test loaded into an online chart can't be managed
      }
   }

   if (isStoppable) {
      if (!This.IsTesting()) {
         PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
         int button = MessageBoxEx(NAME(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to stop sequence "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(catch("onStart(1)"));
      }
      SendChartCommand("SnowRoller.command", "stop");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(NAME(), "No stoppable sequence found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}

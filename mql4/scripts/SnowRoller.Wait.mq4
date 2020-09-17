/**
 * SnowRoller.Wait
 *
 * Send a chart command to a stopped but active SnowRoller to wait for the next start signal.
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
   bool isWaitable = false;

   // check chart for a stopped SnowRoller instance
   if (ObjectFind(statusLabel) == 0) {
      string text = StrToUpper(StrTrim(ObjectDescription(statusLabel)));   // [T]{iSid}|{iStatus}
      sid    = StrLeftTo(text, "|");
      status = StrToInteger(StrRightFrom(text, "|"));

      switch (status) {
         case STATUS_STOPPED:
            bool isTestSequence = StrStartsWith(sid, "T");
            isWaitable = (This.IsTesting() || !isTestSequence);            // a finished test loaded into an online chart can't be managed
      }
   }

   if (isWaitable) {
      if (!This.IsTesting()) {
         PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
         int button = MessageBoxEx(ProgramName(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to activate sequence "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(catch("onStart(1)"));
      }
      SendChartCommand("SnowRoller.command", "wait");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No sequence to activate found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}

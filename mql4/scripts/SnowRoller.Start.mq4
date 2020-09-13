/**
 * SnowRoller.Start
 *
 * Send a chart command to SnowRoller to start or resume the current sequence.
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
   bool isStartable = false;

   // check chart for a SnowRoller instance which is ready to start
   if (ObjectFind(statusLabel) == 0) {
      string text = StrToUpper(StrTrim(ObjectDescription(statusLabel)));   // [T]{iSid}|{iStatus}
      sid    = StrLeftTo(text, "|");
      status = StrToInteger(StrRightFrom(text, "|"));

      switch (status) {
         case STATUS_WAITING:
         case STATUS_STOPPED:
            bool isTestSequence = StrStartsWith(sid, "T");
            isStartable = (This.IsTesting() || !isTestSequence);           // a finished test loaded into an online chart can't be managed
      }
   }

   if (isStartable) {
      if (!This.IsTesting()) {
         PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
         int button = MessageBoxEx(NAME(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to "+ ifString(status==STATUS_WAITING, "start", "resume") +" sequence "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(catch("onStart(1)"));
      }
      SendChartCommand("SnowRoller.command", "start");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(NAME(), "No sequence to start or resume found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}








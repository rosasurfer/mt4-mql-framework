/**
 * SnowRoller.Start
 *
 * Send a chart command to SnowRoller to start or resume the current sequence.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <app/SnowRoller/defines.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string statusObject = "SnowRoller.status";
   string sid = "";
   int status;

   // check chart for a SnowRoller ready to start
   if (ObjectFind(statusObject) == 0) {
      string text = StrToUpper(StrTrim(ObjectDescription(statusObject)));  // [T]{iSid}|{iStatus}
      sid = StrLeftTo(text, "|");

      status = StrToInteger(StrRightFrom(text, "|"));
      switch (status) {
         case STATUS_WAITING:
         case STATUS_STOPPED:                                              // all OK if not a test outside of tester
            if (StringGetChar(sid, 0)!='T' || This.IsTesting())
               break;
         default:
            status = 0;
      }
   }

   if (status != 0) {
      // confirm sending the command
      PlaySoundEx("Windows Notify.wav");
      int button = MessageBoxEx(__NAME(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to "+ ifString(status==STATUS_WAITING, "start", "resume") +" sequence "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) return(ERR_CANCELLED_BY_USER);

      SendChartCommand("SnowRoller.command", "start");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(__NAME(), "No sequence ready to start found.", MB_ICONEXCLAMATION|MB_OK);
   }

   return(catch("onStart(3)"));
}








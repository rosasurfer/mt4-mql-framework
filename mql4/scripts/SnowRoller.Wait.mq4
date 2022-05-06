/**
 * SnowRoller.Wait
 *
 * Send a chart command to a stopped but active SnowRoller to wait for the next start signal.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
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
   // each SnowRoller instance maintain a chart object holding the instance id and the instance status
   string sid="", status="", label="EA.status";
   bool isActive = false;

   // check chart for a stopped SnowRoller instance
   if (ObjectFind(label) == 0) {
      string text = StrTrim(ObjectDescription(label));                  // format: {sid}|{status}
      sid    = StrLeftTo(text, "|");
      status = StrRightFrom(text, "|");
      isActive = (status!="" && status!="undefined");
   }

   if (isActive) {
      if (!This.IsTesting()) {
         PlaySoundEx("Windows Notify.wav");                             // confirm sending the command
         int button = MessageBoxEx(ProgramName(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to activate sequence "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
         if (button != IDOK) return(catch("onStart(1)"));
      }
      SendChartCommand("EA.command", "wait");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No sequence to activate found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}

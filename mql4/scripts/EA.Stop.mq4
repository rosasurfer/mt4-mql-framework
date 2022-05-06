/**
 * EA.Stop
 *
 * Send a "stop" command to a supporting EA.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_NO_BARS_REQUIRED};
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // supporting EAs maintain a chart object holding the instance id and the instance status
   string sid="", status="", label="EA.status";
   bool isActive = false;

   // check chart for an active EA
   if (ObjectFind(label) == 0) {
      string text = StrTrim(ObjectDescription(label));                  // format: {sid}|{status}
      sid      = StrLeftTo(text, "|");
      status   = StrRightFrom(text, "|");
      isActive = (status!="" && status!="undefined");
   }

   if (isActive) {
      if (This.IsTesting()) Tester.Pause();

      PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
      int button = MessageBoxEx(ProgramName(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to resume EA instance "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) return(catch("onStart(1)"));
      SendChartCommand("EA.command", "stop");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No active EA instance found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}








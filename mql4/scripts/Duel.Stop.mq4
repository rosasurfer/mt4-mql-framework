/**
 * Duel.Stop
 *
 * Send a command to an active Duel instance to stop the current sequence.
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
   // active Duel instances maintain a chart object holding the instance id and the current instance status
   string sid="", status="", label="Duel.status";
   bool isStoppable = false;

   // check chart for a matching Duel instance
   if (ObjectFind(label) == 0) {
      string text = StrTrim(ObjectDescription(label));                  // format: {sid}|{status}
      sid    = StrLeftTo(text, "|");
      status = StrToLower(StrLeftTo(StrRightFrom(text, "|"), "|"));
      if      (status == "waiting")     isStoppable = true;
      else if (status == "progressing") isStoppable = true;
   }

   if (isStoppable) {
      if (This.IsTesting()) Tester.Pause();

      PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
      int button = MessageBoxEx(ProgramName(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to stop Duel instance "+ sid +"?", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) return(catch("onStart(1)"));
      SendChartCommand("Duel.command", "stop");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No stoppable Duel instance found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}








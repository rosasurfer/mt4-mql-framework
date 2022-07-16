/**
 * XMT.StopTrading
 *
 * Send a command to a virtual XMT-Scalper to stop the trade copier or mirror.
 *
 * @see  mql4/experts/.attic/XMT-Scalper.mq4
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];
#include <core/script.mqh>
#include <stdfunctions.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   // A running XMT-Scalper maintains a chart object holding the instance id and the trading mode.
   string sid="", mode="", label="XMT-Scalper.status";
   bool isStoppable = false;

   // check chart for a matching XMT-Scalper instance
   if (ObjectFind(label) == 0) {
      string text = StrTrim(ObjectDescription(label));                  // format: {sid}|{trading-mode}
      sid  = StrLeftTo(text, "|");
      mode = StrToLower(StrLeftTo(StrRightFrom(text, "|"), "|"));

      if (mode == "virtual-copier") isStoppable = true;
      if (mode == "virtual-mirror") isStoppable = true;
   }

   if (isStoppable) {
      if (__isTesting) Tester.Pause();

      PlaySoundEx("Windows Notify.wav");                                // confirm sending the command
      int button = MessageBoxEx(ProgramName(), ifString(IsDemoFix(), "", "- Real Account -\n\n") +"Do you really want to stop the XMT trade "+ ifString(mode=="virtual-copier", "copier", "mirror") +" (sid "+ sid +")?", MB_ICONQUESTION|MB_OKCANCEL);
      if (button != IDOK) return(catch("onStart(1)"));
      SendChartCommand("EA.command", "virtual");
   }
   else {
      PlaySoundEx("Windows Chord.wav");
      MessageBoxEx(ProgramName(), "No active XMT copier or mirror found.", MB_ICONEXCLAMATION|MB_OK);
   }
   return(catch("onStart(2)"));
}








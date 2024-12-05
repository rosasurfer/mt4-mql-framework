/**
 * Read the test configuration.
 *
 * @return bool - success status
 */
bool ReadTestConfiguration() {
   if (__isTesting) {
      string section = "Tester."+ ProgramName();
      test.disableTickValueWarning = GetConfigBool(section, "DisableTickValueWarning", test.disableTickValueWarning);
      test.reduceStatusWrites      = GetConfigBool(section, "ReduceStatusWrites",      test.reduceStatusWrites);

      if (IsVisualMode()) {
         test.onPositionOpenPause  = GetConfigBool(section, "OnPositionOpenPause",  test.onPositionOpenPause);
         test.onPositionClosePause = GetConfigBool(section, "OnPositionClosePause", test.onPositionClosePause);
         test.onPartialClosePause  = GetConfigBool(section, "OnPartialClosePause",  test.onPartialClosePause);
         test.onSessionBreakPause  = GetConfigBool(section, "OnSessionBreakPause",  test.onSessionBreakPause);
         test.onStopPause          = GetConfigBool(section, "OnStopPause",          test.onStopPause);
      }
   }
   return(!catch("ReadTestConfiguration(1)"));
}

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
         test.onEntrySignalPause  = GetConfigBool(section, "OnEntrySignalPause",  test.onEntrySignalPause);
         test.onSessionBreakPause = GetConfigBool(section, "OnSessionBreakPause", test.onSessionBreakPause);
         test.onStopPause         = GetConfigBool(section, "OnStopPause",         test.onStopPause);
      }
   }
   return(!catch("ReadTestConfiguration(1)"));
}

/**
 * Read the test configuration.
 *
 * @return bool - success status
 */
bool ReadTestConfiguration() {
   if (__isTesting) {
      string section = "Tester."+ ProgramName();
      test.disableTickValueWarning = GetConfigBool(section, "DisableTickValueWarning", test.disableTickValueWarning);
      test.onStopPause             = GetConfigBool(section, "OnStopPause",             test.onStopPause);
      test.reduceStatusWrites      = GetConfigBool(section, "ReduceStatusWrites",      test.reduceStatusWrites);
   }
   return(!catch("ReadTestConfiguration(1)"));
}

/**
 * Event handler for an unexpectedly closed position.
 *
 * @param  string message - error message
 * @param  int    error   - error code
 *
 * @return int - error status (if set the program will be terminated)
 */
int onPositionClose(string message, int error) {
   if (!error) return(logInfo(message));              // no error

   if (__isTesting) return(catch(message, error));    // tester: terminate on every error

   // online
   if (error == ERR_CONCURRENT_MODIFICATION) {
      logWarn(message, error);                        // continue, it seems the position was closed manually
      return(NO_ERROR);
   }
   return(catch(message, error));                     // termination
}

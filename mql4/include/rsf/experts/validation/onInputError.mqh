/**
 * Error handler for invalid input parameters. Depending on the execution context a terminating/non-terminating error is set.
 *
 * @param  string message - error message
 *
 * @return int - error status
 */
int onInputError(string message) {
   int error = ERR_INVALID_PARAMETER;

   if (ProgramInitReason() == IR_PARAMETERS)
      return(logError(message, error));            // non-terminating error
   return(catch(message, error));                  // terminating error
}

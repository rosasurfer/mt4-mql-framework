/**
 * Restore the internal state of the EA from a status file.
 *
 * @return bool - success status
 */
bool RestoreInstance() {
   if (IsLastError())        return(false);
   if (!ReadStatus())        return(false);        // read and apply the status file
   if (!ValidateInputs())    return(false);        // validate restored input parameters
   if (!SynchronizeStatus()) return(false);        // synchronize restored order state with current server state
   return(true);
}

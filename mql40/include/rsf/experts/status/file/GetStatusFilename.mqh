/**
 * Return the name of the status file. If the name is not yet set, an attempt is made to find an existing status file.
 *
 * @param  bool relative [optional] - whether to return the absolute path or the path relative to the MQL "files" directory
 *                                    (default: absolute path)
 *
 * @return string - filename or an empty string in case of errors
 */
string GetStatusFilename(bool relative = false) {
   relative = relative!=0;

   if (status.filename == "") {
      status.filename = FindStatusFile(instance.id, instance.isTest);   // intentionally trigger an error if instance.id is not set
      if (status.filename == "") return("");
   }

   if (relative)
      return(status.filename);
   return(GetMqlSandboxPath() +"\\"+ status.filename);
}

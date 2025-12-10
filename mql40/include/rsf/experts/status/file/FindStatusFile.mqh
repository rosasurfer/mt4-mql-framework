/**
 * Find an existing status file for the specified instance id. Finds any file matching
 *
 *   "<program-name>, <symbol>,* id=<instance-id>.set" (no matter what the custom name is)
 *
 * but doesn't scan subdirectories. The EA will use whatever was found for status and logfile.
 * A more strict pattern is used for name generation in SetStatusFileName().
 *
 * @param  int  instanceId - instance id
 * @param  bool isTest     - whether the instance is a test instance
 *
 * @return string - file path relative to the MQL "files" directory;
 *                  an empty string if no file was found or in case of errors
 */
string FindStatusFile(int instanceId, bool isTest) {
   isTest = isTest!=0;
   if (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) return(_EMPTY_STR(catch("FindStatusFile(1)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER)));

   string sandboxDir  = GetMqlSandboxPath() +"\\";
   string statusDir   = "presets\\"+ ifString(isTest, "Tester", GetAccountCompanyId()) +"\\";
   string basePattern = ProgramName() +", "+ Symbol() +",* id="+ StrPadLeft(""+ instanceId, 3, "0") +".set";   // matches files with custom names
   string pathPattern = sandboxDir + statusDir + basePattern;

   string result[];
   int size = FindFileNames(pathPattern, result, FF_FILESONLY);
   if (size > 1) return(_EMPTY_STR(catch("FindStatusFile(2)  "+ instance.name +" multiple files found matching pattern \""+ pathPattern +"\"", ERR_RUNTIME_ERROR)));
   if (size < 1) return("");

   return(statusDir + result[0]);
}

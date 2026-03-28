/**
 * Find an existing status file for the specified instance id. Finds all files matching pattern:
 *
 *   "{program-name}, {symbol},* id={instance-id}.set"
 *
 * located in "{sandbox-dir}/presets/{account-company}/". The search doesn't scan subdirectories.
 * If multiple matching files are found, only the last found (i.e. most recent one) is returned.
 *
 * @param  int  instanceId       - instance id
 * @param  bool isTest           - whether the instance is a test instance
 * @param  int  flags [optional] - execution control flags (default: none)
 *                                 F_ERR_ILLEGAL_STATE: silently handle multiple found status files for one instance id
 *
 * @return string - file path relative to the MQL "files" (sandbox) directory;
 *                  or an empty string if no file was found or in case of errors
 */
string FindStatusFile(int instanceId, bool isTest, int flags = NULL) {
   isTest = isTest!=0;
   if (instanceId < INSTANCE_ID_MIN || instanceId > INSTANCE_ID_MAX) return(_EMPTY_STR(catch("FindStatusFile(1)  "+ instance.name +" invalid parameter instanceId: "+ instanceId, ERR_INVALID_PARAMETER)));

   string sandboxDir  = GetMqlSandboxPath() +"\\";
   string companyDir  = "presets\\"+ ifString(isTest, "Tester", GetAccountCompanyId()) +"\\";
   string filePattern = ProgramName() +", "+ Symbol() +",* id="+ StrPadLeft(""+ instanceId, 3, "0") +".set";   // matches files with custom names
   string pattern     = sandboxDir + companyDir + filePattern;

   string result[];
   int size = FindFileNames(pattern, result, FF_FILESONLY|FF_SORT);
   if (size < 1) return("");
   if (size > 1) {
      if (!(flags & F_ERR_ILLEGAL_STATE)) {
         for (int i=0; i < size; i++) {
            logNotice("FindStatusFile(2)  "+ instance.name +" found status file: \""+ companyDir + result[i] +"\"");
         }
         logWarn("FindStatusFile(3)  "+ instance.name +" multiple files found for instance id "+ instanceId +" (returning last one)", ERR_ILLEGAL_STATE);
      }
   }
   return(companyDir + result[size-1]);
}

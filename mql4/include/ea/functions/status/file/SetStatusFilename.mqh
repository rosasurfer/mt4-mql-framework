/**
 * Initializes the name of the used status file. Requires 'instance.id' and 'instance.created' to be set.
 *
 * If the strategy implements the function GetStatusFilenameData() the returned string will be inserted into the resulting
 * filename. This can be used to insert distinctive runtime parameters into the name (e.g. SL/TP vars or trading modes).
 *
 * @return bool - success status
 */
bool SetStatusFilename() {
   if (status.filename != "") return(!catch("SetStatusFilename(1)  "+ instance.name +" cannot modify an already set status filename: \""+ status.filename +"\"", ERR_ILLEGAL_STATE));
   if (!instance.id)          return(!catch("SetStatusFilename(2)  "+ instance.name +" illegal value of instance.id: 0", ERR_ILLEGAL_STATE));
   if (!instance.created)     return(!catch("SetStatusFilename(3)  "+ instance.name +" cannot create status filename (instance.created not set)", ERR_ILLEGAL_STATE));

   string userData = StrTrim(GetStatusFilenameData());
   if (userData != "") userData = userData +", ";

   string directory = "presets\\"+ ifString(IsTestInstance(), "Tester", GetAccountCompanyId()) +"\\";
   string baseName  = ProgramName() +", "+ Symbol() +","+ PeriodDescription() +" "+ userData + GmtTimeFormat(instance.created, "%Y-%m-%d %H.%M") +", id="+ StrPadLeft(instance.id, 3, "0") +".set";
   status.filename = directory + baseName;

   return(!catch("SetStatusFilename(4)"));
}

/**
 * Generates and initializes the name of the status file. Requires 'instance.id' and 'instance.created' to be set.
 *
 * If the expert implements GetStatusFileNameData() the returned string will be inserted into the resulting
 * filename. This can be used to insert custom data into the name (e.g. SL/TP vars or trading modes).
 *
 * @return bool - success status
 */
bool SetStatusFileName() {
   if (status.filename != "") return(!catch("SetStatusFileName(1)  "+ instance.name +" cannot modify an already set status filename: \""+ status.filename +"\"", ERR_ILLEGAL_STATE));
   if (!instance.id)          return(!catch("SetStatusFileName(2)  "+ instance.name +" illegal value of instance.id: 0", ERR_ILLEGAL_STATE));
   if (!instance.created)     return(!catch("SetStatusFileName(3)  "+ instance.name +" cannot create status filename (instance.created not set)", ERR_ILLEGAL_STATE));

   string userData = StrTrim(GetStatusFileNameData());
   if (userData != "") userData = userData +", ";

   string directory = "presets\\"+ ifString(IsTestInstance(), "Tester", GetAccountCompanyId()) +"\\";
   string baseName  = ProgramName() +", "+ Symbol() +","+ PeriodDescription() +" "+ userData + GmtTimeFormat(instance.created, "%Y.%m.%d %H.%M") +", id="+ StrPadLeft(instance.id, 3, "0") +".set";
   status.filename = directory + baseName;

   return(!catch("SetStatusFileName(4)"));
}


#import "rsfMT4Expander.dll"
   string GetStatusFileNameData();                 // a no-op in the Expander allows optional override in MQL
#import

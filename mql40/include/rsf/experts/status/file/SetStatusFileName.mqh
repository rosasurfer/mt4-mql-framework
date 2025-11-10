/**
 * Generates and initializes the name of the status file. Requires 'instance.id' and 'instance.created' to be set.
 *
 * @return bool - success status
 */
bool SetStatusFileName() {
   if (status.filename != "") return(!catch("SetStatusFileName(1)  "+ instance.name +" cannot modify an already set status filename: \""+ status.filename +"\"", ERR_ILLEGAL_STATE));
   if (!instance.id)          return(!catch("SetStatusFileName(2)  "+ instance.name +" illegal value of instance.id: 0", ERR_ILLEGAL_STATE));
   if (!instance.created)     return(!catch("SetStatusFileName(3)  "+ instance.name +" cannot create status filename (instance.created not set)", ERR_ILLEGAL_STATE));

   string directory = "presets\\"+ ifString(IsTestInstance(), "Tester", GetAccountCompanyId()) +"\\";
   string baseName  = ProgramName() +", "+ Symbol() +","+ PeriodDescription() +" "+ GmtTimeFormat(instance.created, "%Y.%m.%d %H.%M") +", id="+ StrPadLeft(instance.id, 3, "0") +".set";
   status.filename = directory + baseName;

   return(!catch("SetStatusFileName(4)"));
}

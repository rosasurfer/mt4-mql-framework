/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFileName() {
   string name = GetStatusFileName();
   if (name == "") return("");
   return(StrLeftTo(name, ".", -1) +".log");
}

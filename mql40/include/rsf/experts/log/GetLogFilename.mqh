/**
 * Return the full name of the instance logfile.
 *
 * @return string - filename or an empty string in case of errors
 */
string GetLogFilename() {
   string name = GetStatusFilename();
   if (name == "") return("");
   return(StrLeftTo(name, ".", -1) +".log");
}

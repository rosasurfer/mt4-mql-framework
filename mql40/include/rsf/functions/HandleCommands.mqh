/**
 * Retrieve received commands and pass them to the command handler. Command format: "cmd[:params[:flags]]"
 *
 *  cmd:    command identifier (required)
 *  params: one or more command parameters separated by comma (optional)
 *  flags:  an integer describing flags of pressed modifier keys (optional)
 *
 * @param  string channel [optional] - channel to check for commands (default: the program's standard command channel)
 *
 * @return bool - success status
 */
bool HandleCommands(string channel = "") {
   if (__isSuperContext) return(true);

   string commands[];
   ArrayResize(commands, 0);

   if (GetChartCommand(channel, commands)) {
      int size = ArraySize(commands);

      for (int i=0; i < size && !last_error; i++) {
         string cmd="", params="", sFlags="", sValues[];

         int parts = Explode(commands[i], ":", sValues, NULL), iFlags=0;
         if (parts > 0) cmd    = StrTrim(sValues[0]);
         if (parts > 1) params = StrTrim(sValues[1]);
         if (parts > 2) {
            sFlags = StrTrim(sValues[2]);
            if (StrIsDigits(sFlags)) {
               iFlags = StrToInteger(sFlags);
            }
            else if (sFlags != "") {
               logNotice("HandleCommands(1)  skipping invalid command flags: \""+ sFlags +"\"");
            }
         }

         if (cmd == "") {
            logNotice("HandleCommands(2)  skipping empty command: \""+ commands[i] +"\"");
            continue;
         }
         onCommand(cmd, params, iFlags);
      }
   }
   return(!last_error);
}


/**
 * Retrieve a chart command sent to the specified channel.
 *
 * @param  _In_    string channel    - channel to check for commands
 * @param  _InOut_ string commands[] - array the command is appended to
 *
 * @return bool - whether a command was found and successfully retrieved
 */
bool GetChartCommand(string channel, string &commands[]) {
   if (!__isChart) return(false);

   static string stdChannel = "";
   if (stdChannel == "") stdChannel = MqlProgramName();

   if (channel == "") {
      if (IsExpert()) channel = "EA";
      else            channel = stdChannel;
   }
   string label = channel +".command";
   string mutex = "mutex."+ label;

   if (ObjectFind(label) != -1) {            // check non-synchronized (read-only access) to prevent locking on every tick
      if (AquireLock(mutex)) {               // aquire the lock and process command synchronized (read-write access)
         ArrayPushString(commands, ObjectDescription(label));
         ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}

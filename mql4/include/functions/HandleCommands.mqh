/**
 * Retrieve received commands and pass them to the command handler. Command format: "cmd[:params[:modifiers]]"
 *
 *  - cmd:       command identifier (required)
 *  - params:    one or more command parameters separated by comma "," (optional)
 *  - modifiers: one or more virtual key modifiers separated by a pipe "|" symbol (optional)
 *
 * @param  string channel [optional] - id of the channel to check for commands (default: the program's standard channel id)
 * @param  bool   remove  [optional] - Whether to remove received commands from the channel (default: yes). If this parameter
 *                                     is FALSE a command may be processed multiple times and/or by multiple receivers.
 * @return bool - success status
 */
bool HandleCommands(string channel="", bool remove=true) {
   if (__isSuperContext) return(true);

   string commands[];
   ArrayResize(commands, 0);

   IsChartCommand(channel, remove, commands);
   int size = ArraySize(commands);

   for (int i=0; i<size && !last_error; i++) {
      string cmd="", params="", modifiers="", values[];

      int elems = Explode(commands[i], ":", values, NULL);
      if (elems > 0) cmd       = StrTrim(values[0]);
      if (elems > 1) params    = StrTrim(values[1]);
      if (elems > 2) modifiers = StrTrim(values[2]);

      if (cmd == "") {
         if (IsLogNotice()) logNotice("HandleCommands(1)  skipping empty command: \""+ commands[i] +"\"");
         continue;
      }
      onCommand(cmd, params, modifiers);
   }
   return(!last_error);
}


/**
 * Checks for and retrieves commands sent to the chart.
 *
 * @param  _In_    string channel     - channel id to check for incoming commands
 * @param  _In_    bool   remove      - whether to remove received commands from the channel
 * @param  _InOut_ string &commands[] - target array received commands are appended to
 *
 * @return bool - whether a command was successfully retrieved
 */
bool IsChartCommand(string channel, bool remove, string &commands[]) {
   if (!__isChart) return(false);

   static string stdChannel = ""; if (stdChannel == "") {
      stdChannel = ProgramName(MODE_NICE);
   }
   if (channel == "") {
      if (IsExpert()) channel = "EA";
      else            channel = stdChannel;
   }
   string label = channel +".command";
   string mutex = "mutex."+ label;

   if (ObjectFind(label) == 0) {                               // check non-synchronized (read-only access) to prevent locking on every tick
      if (AquireLock(mutex, true)) {                           // aquire the lock and process command synchronized (read-write access)
         ArrayPushString(commands, ObjectDescription(label));
         if (remove) ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}

/**
 * Retrieve received commands and pass them to the command handler. Command format: "cmd[:params[:modifiers]]"
 *
 *  cmd:       command identifier (required)
 *  params:    one or more command parameters separated by comma (optional)
 *  modifiers: one or more virtual key modifiers separated by comma (optional)
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
         string cmd="", params="", modifiers="", sValue="", sValues[];

         int parts = Explode(commands[i], ":", sValues, NULL), iValue=0, keys=0;
         if (parts > 0) cmd    = StrTrim(sValues[0]);
         if (parts > 1) params = StrTrim(sValues[1]);
         if (parts > 2) {
            modifiers = StrTrim(sValues[2]);
            if (StrIsDigits(modifiers)) {
               iValue = StrToInteger(modifiers);
               if (iValue & F_VK_ESCAPE  && 1) keys |= F_VK_ESCAPE;
               if (iValue & F_VK_TAB     && 1) keys |= F_VK_TAB;
               if (iValue & F_VK_CAPITAL && 1) keys |= F_VK_CAPITAL;    // CAPSLOCK key
               if (iValue & F_VK_SHIFT   && 1) keys |= F_VK_SHIFT;
               if (iValue & F_VK_CONTROL && 1) keys |= F_VK_CONTROL;
               if (iValue & F_VK_MENU    && 1) keys |= F_VK_MENU;       // ALT key
               if (iValue & F_VK_LWIN    && 1) keys |= F_VK_LWIN;
               if (iValue & F_VK_RWIN    && 1) keys |= F_VK_RWIN;
            }
            else {
               parts = Explode(modifiers, ",", sValues, NULL);
               for (int n=0; n < parts; n++) {
                  sValue = StrTrim(sValues[n]);
                  if      (sValue == "VK_ESCAPE")  keys |= F_VK_ESCAPE;
                  else if (sValue == "VK_TAB")     keys |= F_VK_TAB;
                  else if (sValue == "VK_CAPITAL") keys |= F_VK_CAPITAL;
                  else if (sValue == "VK_SHIFT")   keys |= F_VK_SHIFT;
                  else if (sValue == "VK_CONTROL") keys |= F_VK_CONTROL;
                  else if (sValue == "VK_MENU")    keys |= F_VK_MENU;
                  else if (sValue == "VK_LWIN")    keys |= F_VK_LWIN;
                  else if (sValue == "VK_RWIN")    keys |= F_VK_RWIN;
                  else if (sValue != "") logNotice("HandleCommands(1)  skipping unsupported key modifier: "+ sValue);
               }
            }
         }

         if (cmd == "") {
            logNotice("HandleCommands(2)  skipping empty command: \""+ commands[i] +"\"");
            continue;
         }
         onCommand(cmd, params, keys);
      }
   }
   return(!last_error);
}


/**
 * Retrieve a chart command sent to the specified channel.
 *
 * @param  _In_    string channel     - channel to check for commands
 * @param  _InOut_ string &commands[] - array the command is appended to
 *
 * @return bool - whether a command was found and successfully retrieved
 */
bool GetChartCommand(string channel, string &commands[]) {
   if (!__isChart) return(false);

   static string stdChannel = ""; if (stdChannel == "") {
      stdChannel = ProgramName();
   }
   if (channel == "") {
      if (IsExpert()) channel = "EA";
      else            channel = stdChannel;
   }
   string label = channel +".command";
   string mutex = "mutex."+ label;

   if (ObjectFind(label) != -1) {                              // check non-synchronized (read-only access) to prevent locking on every tick
      if (AquireLock(mutex)) {                                 // aquire the lock and process command synchronized (read-write access)
         ArrayPushString(commands, ObjectDescription(label));
         ObjectDelete(label);
         return(ReleaseLock(mutex));
      }
   }
   return(false);
}

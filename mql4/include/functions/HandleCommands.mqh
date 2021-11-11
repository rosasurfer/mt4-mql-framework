/**
 * Check for received commands and pass them to the command handler.
 *
 * @return bool - success status
 */
bool HandleCommands() {
   string commands[];
   ArrayResize(commands, 0);

   if (EventListener_ChartCommand(commands))
      return(onCommand(commands));
   return(true);
}

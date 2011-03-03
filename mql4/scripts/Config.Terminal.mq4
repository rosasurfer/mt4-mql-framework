/**
 * Config.mq4
 *
 * Lädt die Konfigurationsdateien der MetaTrader-Instanz in den Editor.
 */
#include <stdlib.mqh>
#include <win32api.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);
   return(catch("init()"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   string files[0], names[2], name;
   int size;

   names[0] = TerminalPath() +"\\..\\metatrader-global-config.ini";
   names[1] = TerminalPath() +"\\metatrader-local-config.ini";

   for (int i=0; i < 2; i++) {
      name = names[i];
      if (IsFile(name)) {
         size = ArrayPushString(files, name);
      }
      else {
         name = name +".lnk";
         if (IsFile(name)) {
            name = GetShortcutTarget(name);
            if (IsFile(name))
               size = ArrayPushString(files, name);
         }
      }
   }

   for (i=0; i < size; i++) {
      int hInstance = ShellExecuteA(0, "open", files[i], "", "", SW_SHOWNORMAL);
      if (hInstance < 33)
         return(catch("start(1)  ShellExecute() failed to open \""+ files[i] +"\",    error="+ hInstance +" ("+ ShellExecuteErrorToStr(hInstance) +")", ERR_WINDOWS_ERROR));
   }

   return(catch("start(2)"));
}
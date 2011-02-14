/**
 * SendFakeTick.mq4
 *
 * Schickt einen einzelnen Fake-Tick an den aktuellen Chart.
 */
#include <stdlib.mqh>
#include <win32api.mqh>




/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {

   string directory = FindTradeServerDirectory();


   SendFakeTick(true);
   return(catch("start()"));
}

/**
 * Ermittelt das History-Verzeichnis des aktuellen Tradeservers.
 *
 * @return string
 */
string FindTradeServerDirectory() {
   string serverDirectory = "";

   // eindeutigen Dateinamen erzeugen und temporäre Datei anlegen
   string fileName = StringConcatenate("_t", GetCurrentThreadId(), ".tmp");

   int hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);
   if (hFile < 0) {
      catch("FindTradeServerDirectory(1)  FileOpenHistory(\""+ fileName +"\")");
      return("");
   }
   FileClose(hFile);


   // Datei suchen und Tradeserver-Pfad auslesen
   string pattern = StringConcatenate(TerminalPath(), "\\history\\*");
   int /*WIN32_FIND_DATA*/ wfd[80];

   int hFindDir=FindFirstFileA(pattern, wfd), result=hFindDir;
   while (result > 0) {
      if (wfd.FileAttribute.Directory(wfd)) {
         string name = wfd.FileName(wfd);
         if (name != ".") /*&&*/ if (name != "..") {
            pattern = StringConcatenate(TerminalPath(), "\\history\\", name, "\\", fileName);
            int hFindFile=FindFirstFileA(pattern, wfd);
            if (hFindFile != INVALID_HANDLE_VALUE) {     // hier müßte eigentlich auf ERR_FILE_NOT_FOUND geprüft werden, doch MQL kann es nicht
               //debug("FindTradeServerDirectory()   file = "+ pattern +"   found");

               FindClose(hFindFile);
               serverDirectory = name;
               if (!DeleteFileA(pattern))                // tmp. Datei per Win-API löschen (MQL kann es im History-Verzeichnis nicht)
                  return(catch("FindTradeServerDirectory(2)   kernel32.DeleteFile(\""+ pattern +"\") => FALSE", ERR_WINDOWS_ERROR));
               break;
            }
         }
      }
      result = FindNextFileA(hFindDir, wfd);
   }
   if (result == INVALID_HANDLE_VALUE) {
      catch("FindTradeServerDirectory(3)  kernel32.FindFirstFile(\""+ pattern +"\") => INVALID_HANDLE_VALUE", ERR_WINDOWS_ERROR);
      return("");
   }
   FindClose(hFindDir);

   //debug("FindTradeServerDirectory()   serverDirectory = "+ serverDirectory);

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("FindTradeServerDirectory(4)", error);
      return("");
   }
   return(serverDirectory);
}

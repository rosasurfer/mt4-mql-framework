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
   // eindeutigen Dateinamen erzeugen und temporäre Datei anlegen
   string fileName = StringConcatenate("_t", GetCurrentThreadId(), ".tmp");

   int hFile = FileOpenHistory(fileName, FILE_BIN|FILE_WRITE);
   if (hFile < 0) {
      catch("FindTradeServerDirectory(1)  FileOpenHistory(\""+ fileName +"\")");
      return("");
   }
   FileClose(hFile);

   // Datei suchen und Tradeserver-Pfad auslesen
   string findPattern = StringConcatenate(TerminalPath(), "\\history\\*");
   int /*WIN32_FIND_DATA*/ wfd[80];

   int hFindFile = FindFirstFileA(findPattern, wfd);
   if (hFindFile == INVALID_HANDLE_VALUE) {
      catch("FindTradeServerDirectory(2)  kernel32.FindFirstFile(\""+ findPattern +"\") => INVALID_HANDLE_VALUE", ERR_WINDOWS_ERROR);
      return("");
   }
   debug("FindTradeServerDirectory()   fileName = "+ wfd.FileName(wfd));

   while (FindNextFileA(hFindFile, wfd)) {
      debug("FindTradeServerDirectory()   fileName = "+ wfd.FileName(wfd));
   }

   if (!FindClose(hFindFile)) {
      catch("FindTradeServerDirectory(3)  kernel32.FindClose() => FALSE", ERR_WINDOWS_ERROR);
      return("");
   }


   // Datei per Win-API löschen (MQL kann im History-Verzeichnis nicht löschen)
   //if (!DeleteFileA(filename)) return(catch("FindTradeServerDirectory(2)   kernel32.DeleteFile(\""+ filename +"\") => FALSE", ERR_WINDOWS_ERROR));

   int error = GetLastError();
   if (error != NO_ERROR) {
      catch("FindTradeServerDirectory(4)", error);
      return("");
   }
   return("directoryName");
}

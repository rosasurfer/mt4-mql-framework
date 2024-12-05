/**
 * MT4Expander import declarations
 */
#import "rsfMT4Expander.dll"

   // terminal status, terminal interaction
   int    GetTerminalMainWindow();

   // date/time
   string GmtTimeFormatW(datetime time, string format);

   // conversion functions
   string ErrorToStrW(int error);
   string LoglevelToStrW(int level);
   string MessageBoxButtonToStrW(int id);

   // other helpers
   int    GetLastWin32Error();
   int    PlaySoundW(string soundfile);
#import

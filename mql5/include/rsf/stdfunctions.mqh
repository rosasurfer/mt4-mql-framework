/**
 * Commonly used framework functions
 */
#include <rsf/common/Abs.mqh>
#include <rsf/common/LoglevelDescription.mqh>
#include <rsf/common/Max.mqh>
#include <rsf/common/PeriodDescription.mqh>
#include <rsf/common/StrContains.mqh>
#include <rsf/common/StrLeft.mqh>
#include <rsf/common/StrPadRight.mqh>
#include <rsf/common/StrSubstr.mqh>
#include <rsf/common/StrTrim.mqh>

//#include <functions/configuration.mqh>
#include <rsf/v45/log.mqh>

#include <rsf/MT4Expander.mqh>


/**
 * Return a readable version of an MQL error code.
 *
 * @param  int error - MQL error code or mapped Win32 error code
 *
 * @return string
 */
string ErrorToStr(int error) {
   return(ErrorToStrW(error));
}


/**
 * Format a timestamp as a string representing GMT time.
 *
 * @param  datetime timestamp - Unix timestamp (GMT)
 * @param  string   format    - format control string supported by C++ strftime()
 *
 * @return string - GMT time string or an empty string in case of errors
 *
 * @link  http://www.cplusplus.com/reference/ctime/strftime/
 * @link  ms-help://MS.VSCC.v90/MS.MSDNQTR.v90.en/dv_vccrt/html/6330ff20-4729-4c4a-82af-932915d893ea.htm
 */
string GmtTimeFormat(datetime timestamp, string format) {
   return(GmtTimeFormatW(timestamp, format));
}


/**
 * Replacement for the MQL function MessageBox().
 *
 * Displays a modal messagebox even if not supported by the terminal in the current context (e.g. in tester or in indicators).
 *
 * @param  string caption
 * @param  string message
 * @param  int    flags
 *
 * @return int - key code of the pressed button
 */
int MessageBoxEx(string caption, string message, int flags = MB_OK) {
   string prefix = Symbol() +","+ PeriodDescription();
   if (!StrContains(caption, prefix)) caption = prefix +" - "+ caption;

   bool useWin32 = false;
   if (IsTesting() || MQLInfoInteger(MQL_PROGRAM_TYPE)==PROGRAM_INDICATOR) {
      useWin32 = true;
   }
   else {
      // TODO
      //useWin32 = (__ExecutionContext[EC.programCoreFunction]==CF_INIT && UninitializeReason()==REASON_RECOMPILE);
   }

   // the default flag MB_APPLMODAL may block the UI thread from processing messages (happens *sometimes* in test::deinit())
   int button;
   if (useWin32) button = MessageBoxW(GetTerminalMainWindow(), message, caption, flags|MB_TASKMODAL|MB_TOPMOST|MB_SETFOREGROUND);
   else          button = MessageBox(message, caption, flags);

   // TODO: restore logging
   return(button);
}


/**
 * Return the current MQL module's name.
 *
 * @param  bool fullName [optional] - whether to return the full module name (default: simple name)
 *
 * @return string
 */
string ModuleName(bool fullName = false) {
   fullName = fullName!=0;
   if (fullName) {
      return(MQLInfoString(MQL_PROGRAM_NAME));     // TODO: add name of parent module (if any)
   }
   return(WindowExpertName());
}


/**
 * Replacement for the built-in MQL function PlaySound().
 *
 * Queues a soundfile for playing and immediately returns (non-blocking). Plays all sound types currently supported on the
 * system. Allows mixing of sounds (except MIDI files). Also plays sounds if the terminal doesn't support it in the current
 * context (e.g. in tester).
 *
 * @param  string soundfile - an absolute filename or a filename relative to directory "sounds" of the terminal directory or
 *                            the data directory (both are searched)
 *
 * @return int - error status
 */
int PlaySoundEx(string soundfile) {
   return(PlaySoundW(soundfile));
}


/**
 * Set the last error code of the MQL module. If called in a library the error will bubble up to the program's main module.
 * If called in an indicator loaded by iCustom() the error will bubble up to the caller of iCustom(). The error code NO_ERROR
 * will not bubble up.
 *
 * @param  int error            - error code
 * @param  int param [optional] - any value (ignored)
 *
 * @return int - the same error
 */
int SetLastError(int error, int param = NULL) {
   last_error = error;
   return(error);
}


/**
 * Replace all occurences of a substring in a string by another string.
 *
 * @param  string str     - string to process
 * @param  string search  - search string
 * @param  string replace - replacement string
 *
 * @return string - resulting string or an empty string in case of errors
 */
string StrReplace(string str, string search, string replace) {
   if (!StringLen(str))    return(str);
   if (!StringLen(search)) return(str);
   if (search == replace)  return(str);

   StringReplace(str, search, replace);
   return(str);
}


#import "kernel32.dll"
   void OutputDebugStringW(string message);

#import "user32.dll"
   int  MessageBoxW(int hWnd, string text, string caption, int style);
#import

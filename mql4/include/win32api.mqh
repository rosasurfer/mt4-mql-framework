/**
 *
 */
#import "gdi32.dll"
   int  GetClipBox(int hDC, int lpRect[]);

#import "kernel32.dll"
   int  _lclose(int hFile);
   int  _lcreat(string lpPathName, int attributes);
   int  _llseek(int hFile, int offset, int origin);
   int  _lopen(string lpPathName, int accessModes);
   int  _lread(int hFile, int lpBuffer[], int bytes);
   int  _lwrite(int hFile, int lpBuffer[], int bytes);
   bool CloseHandle(int hObject);
   int  CreateFileA(string lpFileName, int dwDesiredAccess, int dwShareMode, int lpSecurityAttributes, int dwCreationDisposition, int dwFlagsAndAttributes, int hTemplateFile);
   bool CreateProcessA(string lpApplicationName, string lpCmdLine, int lpProcessAttributes[], int lpThreadAttributes[], int bInheritHandles, int creationFlags, int lpEnvironment[], string lpCurrentDirectory, int lpStartupInfo[], int lpProcessInformation[]);
   bool DeleteFileA(string lpFileName);
   bool FileTimeToSystemTime(int lpFileTime[], int lpSystemTime[]);
   bool FindClose(int hFindFile);
   int  FindFirstFileA(string lpFileName, int lpFindFileData[]);
   bool FindNextFileA(int hFindFile, int lpFindFileData[]);
   bool GetComputerNameA(string lpBuffer, int lpBufferSize[]);
   int  GetCurrentProcess();
   int  GetCurrentProcessId();
   int  GetCurrentThread();
   int  GetCurrentThreadId();
   int  GetEnvironmentStringsA();
   int  GetFileSize(int hFile, int lpFileSizeHiWord[]);
   int  GetFullPathNameA(string lpFileName, int bufferSize, string lpBuffer, int lpFilePart[]);
   int  GetLongPathNameA(string lpShortPath, string lpLongPath, int bufferSize);
   int  GetModuleFileNameA(int hModule, string lpBuffer, int bufferSize);
   int  GetModuleHandleA(string lpModuleName);
   int  GetPrivateProfileIntA(string lpSection, string lpKey, int nDefault, string lpFileName);
   int  GetPrivateProfileStringA(string lpSection, string lpKey, string lpDefault, string lpBuffer, int bufferSize, string lpFileName);
   int  GetProcAddress(int hModule, string lpProcedureName);
   bool GetProcessTimes(int hProcess, int lpCreationTime[], int lpExitTime[], int lpKernelTime[], int lpUserTime[]);
   void GetStartupInfoA(int lpStartupInfo[]);
   void GetSystemTime(int lpSystemTime[]);
   int  GetTempFileNameA(string lpPathName, string lpPrefix, int unique, string lpTempFileName);
   int  GetTempPathA(int bufferSize, string lpBuffer);
   int  GetTimeZoneInformation(int lpTimeZoneInformation[]);
   /*
   bool SystemTimeToTzSpecificLocalTime(
      LPTIME_ZONE_INFORMATION lpTimeZoneInformation,  // pointer to time zone of interest
      LPSYSTEMTIME lpUniversalTime,                   // pointer to universal time of interest
      LPSYSTEMTIME lpLocalTime                        // pointer to structure to receive local time
   );
   */
   int  LoadLibraryA(string lpLibFileName);
   bool MoveFileA(string lpOldFileName, string lpNewFileName);
   void OutputDebugStringA(string lpMessage);         // funktioniert nur für Admins zuverlässig
   bool ReadProcessMemory(int hProcess, int baseAddress, int lpBuffer[], int bytes, int lpNumberOfBytesRead[]);
   void RtlMoveMemory(int destAddress, int srcAddress, int bytes);
   int  SleepEx(int milliseconds, int alertable);
   bool SystemTimeToFileTime(int lpSystemTime[], int lpFileTime[]);
   int  VirtualAlloc(int lpAddress[], int size, int flAllocationType, int flProtect);
   int  WaitForSingleObject(int hObject, int milliseconds);
   int  WinExec(string lpCmdLine, int cmdShow);
   bool WritePrivateProfileStringA(string lpSection, string lpKey, string lpValue, string lpFileName);
   bool WriteProcessMemory(int hProcess, int destAddress, int srcBuffer[], int bytes, int lpNumberOfBytesWritten[]);

#import "ntdll.dll"
   bool RtlTimeToSecondsSince1970(int lpTime[], int lpElapsedSeconds[]);

#import "shell32.dll"
   int  ShellExecuteA(int hWnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);

#import "user32.dll"
   bool DestroyWindow(int hWnd);
   int  FindWindowExA(int hWndParent, int hWndChildAfter, string lpClass, string lpWindow);
   int  GetActiveWindow();
   int  GetAncestor(int hWnd, int cmd);
   int  GetAsyncKeyState(int vKey);
   int  GetClassNameA(int hWnd, string lpBuffer, int bufferSize);
   int  GetDC(int hWnd);
   int  GetDesktopWindow();
   int  GetDlgCtrlID(int hWndCtl);
   int  GetDlgItem(int hDlg, int nIDDlgItem);
   int  GetKeyState(int vKey);
   int  GetParent(int hWnd);
   int  GetPropA(int hWnd, string lpString);
   int  GetTopWindow(int hWnd);
   int  GetWindow(int hWnd, int cmd);
   int  GetWindowThreadProcessId(int hWnd, int lpProcessId[]);
   bool IsIconic(int hWnd);
   bool IsWindow(int hWnd);
   bool IsWindowVisible(int hWnd);
   int  MessageBoxA(int hWnd, string lpText, string lpCaption, int style);
   int  MessageBoxExA(int hWnd, string lpText, string lpCaption, int style, int wLanguageId);
   bool PostMessageA(int hWnd, int msg, int wParam, int lParam);
   bool RedrawWindow(int hWnd, int lpRectUpdate, int hRgnUpdate, int flags);
   int  RegisterWindowMessageA(string lpString);
   int  ReleaseDC(int hWnd, int hDC);
   int  RemovePropA(int hWnd, string lpString);
   int  SendMessageA(int hWnd, int msg, int wParam, int lParam);
   int  SetActiveWindow(int hWnd);
   bool SetPropA(int hWnd, string lpString, int hData);
   bool SetWindowTextA(int hWnd, string lpString);
   bool ShowWindow(int hWnd, int nCmdShow);

#import "version.dll"
   bool GetFileVersionInfoA(string lpFilename, int handle, int bufferSize, int lpBuffer[]);
   int  GetFileVersionInfoSizeA(string lpFilename, int lpHandle[]);

#import "winmm.dll"
   bool PlaySoundA(string lpSound, int hMod, int fSound);
#import

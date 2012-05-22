/**
 *
 */
#import "kernel32.dll"

   int  _lclose(int hFile);
   int  _lcreat(string lpPathName, int attributes);
   int  _llseek(int hFile, int offset, int origin);
   int  _lopen(string lpPathName, int accessModes);
   int  _lread(int hFile, int lpBuffer[], int bytes);
   int  _lwrite(int hFile, int lpBuffer[], int bytes);
   bool CloseHandle(int hObject);
   bool CreateProcessA(string lpApplicationName, string lpCmdLine, int lpProcessAttributes[], int lpThreadAttributes[], int bInheritHandles, int creationFlags, int lpEnvironment[], string lpCurrentDirectory, int lpStartupInfo[], int lpProcessInformation[]);
   bool DeleteFileA(string lpFileName);
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
   void GetLocalTime(int lpSystemTime[]);
   int  GetLongPathNameA(string lpShortPath, string lpLongPath, int bufferSize);
   int  GetModuleFileNameA(int hModule, string lpBuffer, int bufferSize);
   int  GetModuleHandleA(string lpModuleName);
   int  GetPrivateProfileIntA(string lpSection, string lpKey, int nDefault, string lpFileName);
   int  GetPrivateProfileSectionNamesA(int lpBuffer[], int bufferSize, string lpFileName);                        // @see  stdlib::GetPrivateProfileSectionNames()
   int  GetPrivateProfileStringA(string lpSection, string lpKey, string lpDefault, string lpBuffer, int bufferSize, string lpFileName);
   int  GetProcAddress(int hModule, string lpProcedureName);
   void GetStartupInfoA(int lpStartupInfo[]);
   void GetSystemTime(int lpSystemTime[]);
   int  GetTimeZoneInformation(int lpTimeZoneInformation[]);
   int  LoadLibraryA(string lpLibFileName);
   void OutputDebugStringA(string lpMessage);
   bool ReadProcessMemory(int hProcess, int lpBaseAddress, int lpBuffer[], int bytes, int lpNumberOfBytesRead[]);
   int  VirtualAlloc(int lpAddress[], int size, int flAllocationType, int flProtect);
   int  WaitForSingleObject(int hObject, int milliseconds);
   int  WinExec(string lpCmdLine, int cmdShow);                                                                   //         +-- stdlib::DeletePrivateProfileSection()
   bool WritePrivateProfileStringA(string lpSection, string lpKey, string lpValue, string lpFileName);            // @see  --+-- stdlib::DeletePrivateProfileKey()
   bool WriteProcessMemory(int hProcess, int lpAddress, int lpBuffer[], int bytes, int lpNumberOfBytesWritten[]); //         +-- stdlib::FlushPrivateProfileCache()

#import "ntdll.dll"

   int  RtlGetLastWin32Error();

#import "shell32.dll"

   int  ShellExecuteA(int hWnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);

#import "user32.dll"

   int  GetActiveWindow();
   int  GetAncestor(int hWnd, int cmd);
   int  GetClassNameA(int hWnd, string lpBuffer, int bufferSize);                            // @see stdlib::GetClassName()
   int  GetDesktopWindow();
   int  GetDlgItem(int hDlg, int nIDDlgItem);
   int  GetParent(int hWnd);
   int  GetTopWindow(int hWnd);
   int  GetWindow(int hWnd, int cmd);
   int  GetWindowTextA(int hWnd, string lpBuffer, int bufferSize);                           // @see stdlib::GetWindowText()
   int  GetWindowThreadProcessId(int hWnd, int lpProcessId[]);
   int  LoadCursorA(int hInstance, string lpCursorName);
   int  LoadCursorW(int hInstance, int resourceId);
   int  MessageBoxA(int hWnd, string lpText, string lpCaption, int style);
   int  MessageBoxExA(int hWnd, string lpText, string lpCaption, int style, int wLanguageId);
   bool PostMessageA(int hWnd, int msg, int wParam, int lParam);
   int  RegisterWindowMessageA(string lpString);
   int  SendMessageA(int hWnd, int msg, int wParam, int lParam);
   bool SetWindowTextA(int hWnd, string lpString);

#import "version.dll"

   bool GetFileVersionInfoA(string lpFilename, int handle, int bufferSize, int lpBuffer[]);
   int  GetFileVersionInfoSizeA(string lpFilename, int lpHandle[]);

#import "winmm.dll"

   bool PlaySoundA(string lpSound, int hMod, int fSound);

#import


// AnimateWindow() commands
#define AW_HOR_POSITIVE                      0x00000001
#define AW_HOR_NEGATIVE                      0x00000002
#define AW_VER_POSITIVE                      0x00000004
#define AW_VER_NEGATIVE                      0x00000008
#define AW_CENTER                            0x00000010
#define AW_HIDE                              0x00010000
#define AW_ACTIVATE                          0x00020000
#define AW_SLIDE                             0x00040000
#define AW_BLEND                             0x00080000


// Standard Cursor IDs
#define IDC_APPSTARTING                           32650  // standard arrow and small hourglass (not in win3.1)
#define IDC_ARROW                                 32512  // standard arrow
#define IDC_CROSS                                 32515  // crosshair
#define IDC_IBEAM                                 32513  // text I-beam
#define IDC_ICON                                  32641  // Windows NT only: empty icon
#define IDC_NO                                    32648  // slashed circle (not in win3.1)
#define IDC_SIZE                                  32640  // Windows NT only: four-pointed arrow
#define IDC_SIZEALL                               32646  // same as IDC_SIZE
#define IDC_SIZENESW                              32643  // double-pointed arrow pointing northeast and southwest
#define IDC_SIZENS                                32645  // double-pointed arrow pointing north and south
#define IDC_SIZENWSE                              32642  // double-pointed arrow pointing northwest and southeast
#define IDC_SIZEWE                                32644  // double-pointed arrow pointing west and east
#define IDC_UPARROW                               32516  // vertical arrow
#define IDC_WAIT                                  32514  // hourglass
#define IDC_HAND                                  32649  // WINVER >= 0x0500
#define IDC_HELP                                  32651  // WINVER >= 0x0400


// Dialog flags
#define MB_OK                                0x00000000  // buttons
#define MB_OKCANCEL                          0x00000001
#define MB_ABORTRETRYIGNORE                  0x00000002
#define MB_CANCELTRYCONTINUE                 0x00000006
#define MB_RETRYCANCEL                       0x00000005
#define MB_YESNO                             0x00000004
#define MB_YESNOCANCEL                       0x00000003
#define MB_HELP                              0x00004000  // additional help button

#define MB_DEFBUTTON1                        0x00000000  // default button
#define MB_DEFBUTTON2                        0x00000100
#define MB_DEFBUTTON3                        0x00000200
#define MB_DEFBUTTON4                        0x00000300

#define MB_ICONEXCLAMATION                   0x00000030  // icons
#define MB_ICONWARNING               MB_ICONEXCLAMATION
#define MB_ICONINFORMATION                   0x00000040
#define MB_ICONASTERISK              MB_ICONINFORMATION
#define MB_ICONQUESTION                      0x00000020
#define MB_ICONSTOP                          0x00000010
#define MB_ICONERROR                        MB_ICONSTOP
#define MB_ICONHAND                         MB_ICONSTOP
#define MB_USERICON                          0x00000080

#define MB_APPLMODAL                         0x00000000  // modality
#define MB_SYSTEMMODAL                       0x00001000
#define MB_TASKMODAL                         0x00002000

#define MB_DEFAULT_DESKTOP_ONLY              0x00020000  // other
#define MB_RIGHT                             0x00080000
#define MB_RTLREADING                        0x00100000
#define MB_SETFOREGROUND                     0x00010000
#define MB_TOPMOST                           0x00040000
#define MB_NOFOCUS                           0x00008000
#define MB_SERVICE_NOTIFICATION              0x00200000


// Dialog return codes
#define IDOK                                          1
#define IDCANCEL                                      2
#define IDABORT                                       3
#define IDRETRY                                       4
#define IDIGNORE                                      5
#define IDYES                                         6
#define IDNO                                          7
#define IDCLOSE                                       8
#define IDHELP                                        9
#define IDTRYAGAIN                                   10
#define IDCONTINUE                                   11


// File & I/O constants
#define MAX_PATH                                    260     // for example the maximum path on drive D is "D:\some-256-character-path-string<NUL>"

#define AT_NORMAL                                  0x00     // DOS file attributes
#define AT_READONLY                                0x01
#define AT_HIDDEN                                  0x02
#define AT_SYSTEM                                  0x04
#define AT_ARCHIVE                                 0x20

#define FILE_ATTRIBUTE_READONLY                       1
#define FILE_ATTRIBUTE_HIDDEN                         2
#define FILE_ATTRIBUTE_SYSTEM                         4
#define FILE_ATTRIBUTE_DIRECTORY                     16
#define FILE_ATTRIBUTE_ARCHIVE                       32
#define FILE_ATTRIBUTE_DEVICE                        64
#define FILE_ATTRIBUTE_NORMAL                       128
#define FILE_ATTRIBUTE_TEMPORARY                    256
#define FILE_ATTRIBUTE_SPARSE_FILE                  512
#define FILE_ATTRIBUTE_REPARSE_POINT               1024
#define FILE_ATTRIBUTE_COMPRESSED                  2048
#define FILE_ATTRIBUTE_OFFLINE                     4096
#define FILE_ATTRIBUTE_NOT_INDEXED                 8192     // FILE_ATTRIBUTE_NOT_CONTENT_INDEXED ist zu lang für MQL
#define FILE_ATTRIBUTE_ENCRYPTED                  16384
#define FILE_ATTRIBUTE_VIRTUAL                    65536

#define OF_READ                                    0x00
#define OF_WRITE                                   0x01
#define OF_READWRITE                               0x02
#define OF_SHARE_COMPAT                            0x00
#define OF_SHARE_EXCLUSIVE                         0x10
#define OF_SHARE_DENY_WRITE                        0x20
#define OF_SHARE_DENY_READ                         0x30
#define OF_SHARE_DENY_NONE                         0x40

#define HFILE_ERROR                          0xFFFFFFFF     // -1


// GetAncestor() constants
#define GA_PARENT                                     1
#define GA_ROOT                                       2
#define GA_ROOTOWNER                                  3


// GetSystemMetrics() codes
#define SM_CXSCREEN                                   0
#define SM_CYSCREEN                                   1
#define SM_CXVSCROLL                                  2
#define SM_CYHSCROLL                                  3
#define SM_CYCAPTION                                  4
#define SM_CXBORDER                                   5
#define SM_CYBORDER                                   6
#define SM_CXDLGFRAME                                 7
#define SM_CYDLGFRAME                                 8
#define SM_CYVTHUMB                                   9
#define SM_CXHTHUMB                                  10
#define SM_CXICON                                    11
#define SM_CYICON                                    12
#define SM_CXCURSOR                                  13
#define SM_CYCURSOR                                  14
#define SM_CYMENU                                    15
#define SM_CXFULLSCREEN                              16
#define SM_CYFULLSCREEN                              17
#define SM_CYKANJIWINDOW                             18
#define SM_MOUSEPRESENT                              19
#define SM_CYVSCROLL                                 20
#define SM_CXHSCROLL                                 21
#define SM_DEBUG                                     22
#define SM_SWAPBUTTON                                23
#define SM_RESERVED1                                 24
#define SM_RESERVED2                                 25
#define SM_RESERVED3                                 26
#define SM_RESERVED4                                 27
#define SM_CXMIN                                     28
#define SM_CYMIN                                     29
#define SM_CXSIZE                                    30
#define SM_CYSIZE                                    31
#define SM_CXFRAME                                   32
#define SM_CYFRAME                                   33
#define SM_CXMINTRACK                                34
#define SM_CYMINTRACK                                35
#define SM_CXDOUBLECLK                               36
#define SM_CYDOUBLECLK                               37
#define SM_CXICONSPACING                             38
#define SM_CYICONSPACING                             39
#define SM_MENUDROPALIGNMENT                         40
#define SM_PENWINDOWS                                41
#define SM_DBCSENABLED                               42
#define SM_CMOUSEBUTTONS                             43
#define SM_SECURE                                    44
#define SM_CXEDGE                                    45
#define SM_CYEDGE                                    46
#define SM_CXMINSPACING                              47
#define SM_CYMINSPACING                              48
#define SM_CXSMICON                                  49
#define SM_CYSMICON                                  50
#define SM_CYSMCAPTION                               51
#define SM_CXSMSIZE                                  52
#define SM_CYSMSIZE                                  53
#define SM_CXMENUSIZE                                54
#define SM_CYMENUSIZE                                55
#define SM_ARRANGE                                   56
#define SM_CXMINIMIZED                               57
#define SM_CYMINIMIZED                               58
#define SM_CXMAXTRACK                                59
#define SM_CYMAXTRACK                                60
#define SM_CXMAXIMIZED                               61
#define SM_CYMAXIMIZED                               62
#define SM_NETWORK                                   63
#define SM_CLEANBOOT                                 67
#define SM_CXDRAG                                    68
#define SM_CYDRAG                                    69
#define SM_SHOWSOUNDS                                70
#define SM_CXMENUCHECK                               71     // use instead of GetMenuCheckMarkDimensions()
#define SM_CYMENUCHECK                               72
#define SM_SLOWMACHINE                               73
#define SM_MIDEASTENABLED                            74
#define SM_MOUSEWHEELPRESENT                         75
#define SM_XVIRTUALSCREEN                            76
#define SM_YVIRTUALSCREEN                            77
#define SM_CXVIRTUALSCREEN                           78
#define SM_CYVIRTUALSCREEN                           79
#define SM_CMONITORS                                 80
#define SM_SAMEDISPLAYFORMAT                         81


// GetTimeZoneInformation() constants
#define TIME_ZONE_ID_UNKNOWN                          0
#define TIME_ZONE_ID_STANDARD                         1
#define TIME_ZONE_ID_DAYLIGHT                         2


// GetWindow() constants
#define GW_HWNDFIRST                                  0
#define GW_HWNDLAST                                   1
#define GW_HWNDNEXT                                   2
#define GW_HWNDPREV                                   3
#define GW_OWNER                                      4
#define GW_CHILD                                      5
#define GW_ENABLEDPOPUP                               6


// Handles
#define INVALID_HANDLE_VALUE                 0xFFFFFFFF     // -1


// Keyboard events
#define KEYEVENTF_EXTENDEDKEY                      0x01
#define KEYEVENTF_KEYUP                            0x02


// Memory protection constants, see VirtualAlloc()
#define PAGE_EXECUTE                               0x10     // options
#define PAGE_EXECUTE_READ                          0x20
#define PAGE_EXECUTE_READWRITE                     0x40
#define PAGE_EXECUTE_WRITECOPY                     0x80
#define PAGE_NOACCESS                              0x01
#define PAGE_READONLY                              0x02
#define PAGE_READWRITE                             0x04
#define PAGE_WRITECOPY                             0x08

#define PAGE_GUARD                                0x100     // modifier
#define PAGE_NOCACHE                              0x200
#define PAGE_WRITECOMBINE                         0x400


// Messages
#define WM_NULL                                  0x0000
#define WM_CREATE                                0x0001
#define WM_DESTROY                               0x0002
#define WM_MOVE                                  0x0003
#define WM_SIZE                                  0x0005
#define WM_ACTIVATE                              0x0006
#define WM_SETFOCUS                              0x0007
#define WM_KILLFOCUS                             0x0008
#define WM_ENABLE                                0x000A
#define WM_SETREDRAW                             0x000B
#define WM_SETTEXT                               0x000C
#define WM_GETTEXT                               0x000D
#define WM_GETTEXTLENGTH                         0x000E
#define WM_PAINT                                 0x000F
#define WM_CLOSE                                 0x0010
#define WM_QUERYENDSESSION                       0x0011
#define WM_QUIT                                  0x0012
#define WM_QUERYOPEN                             0x0013
#define WM_ERASEBKGND                            0x0014
#define WM_SYSCOLORCHANGE                        0x0015
#define WM_ENDSESSION                            0x0016
#define WM_SHOWWINDOW                            0x0018
#define WM_WININICHANGE                          0x001A
#define WM_SETTINGCHANGE                         0x001A     // WM_WININICHANGE
#define WM_DEVMODECHANGE                         0x001B
#define WM_ACTIVATEAPP                           0x001C
#define WM_FONTCHANGE                            0x001D
#define WM_TIMECHANGE                            0x001E
#define WM_CANCELMODE                            0x001F
#define WM_SETCURSOR                             0x0020
#define WM_MOUSEACTIVATE                         0x0021
#define WM_CHILDACTIVATE                         0x0022
#define WM_QUEUESYNC                             0x0023
#define WM_GETMINMAXINFO                         0x0024
#define WM_PAINTICON                             0x0026
#define WM_ICONERASEBKGND                        0x0027
#define WM_NEXTDLGCTL                            0x0028
#define WM_SPOOLERSTATUS                         0x002A
#define WM_DRAWITEM                              0x002B
#define WM_MEASUREITEM                           0x002C
#define WM_DELETEITEM                            0x002D
#define WM_VKEYTOITEM                            0x002E
#define WM_CHARTOITEM                            0x002F
#define WM_SETFONT                               0x0030
#define WM_GETFONT                               0x0031
#define WM_SETHOTKEY                             0x0032
#define WM_GETHOTKEY                             0x0033
#define WM_QUERYDRAGICON                         0x0037
#define WM_COMPAREITEM                           0x0039
#define WM_GETOBJECT                             0x003D
#define WM_COMPACTING                            0x0041
#define WM_WINDOWPOSCHANGING                     0x0046
#define WM_WINDOWPOSCHANGED                      0x0047
#define WM_COPYDATA                              0x004A
#define WM_CANCELJOURNAL                         0x004B
#define WM_NOTIFY                                0x004E
#define WM_INPUTLANGCHANGEREQUEST                0x0050
#define WM_INPUTLANGCHANGE                       0x0051
#define WM_TCARD                                 0x0052
#define WM_HELP                                  0x0053
#define WM_USERCHANGED                           0x0054
#define WM_NOTIFYFORMAT                          0x0055
#define WM_CONTEXTMENU                           0x007B
#define WM_STYLECHANGING                         0x007C
#define WM_STYLECHANGED                          0x007D
#define WM_DISPLAYCHANGE                         0x007E
#define WM_GETICON                               0x007F
#define WM_SETICON                               0x0080
#define WM_NCCREATE                              0x0081
#define WM_NCDESTROY                             0x0082
#define WM_NCCALCSIZE                            0x0083
#define WM_NCHITTEST                             0x0084
#define WM_NCPAINT                               0x0085
#define WM_NCACTIVATE                            0x0086
#define WM_GETDLGCODE                            0x0087
#define WM_SYNCPAINT                             0x0088
#define WM_NCMOUSEMOVE                           0x00A0
#define WM_NCLBUTTONDOWN                         0x00A1
#define WM_NCLBUTTONUP                           0x00A2
#define WM_NCLBUTTONDBLCLK                       0x00A3
#define WM_NCRBUTTONDOWN                         0x00A4
#define WM_NCRBUTTONUP                           0x00A5
#define WM_NCRBUTTONDBLCLK                       0x00A6
#define WM_NCMBUTTONDOWN                         0x00A7
#define WM_NCMBUTTONUP                           0x00A8
#define WM_NCMBUTTONDBLCLK                       0x00A9
#define WM_KEYFIRST                              0x0100
#define WM_KEYDOWN                               0x0100
#define WM_KEYUP                                 0x0101
#define WM_CHAR                                  0x0102
#define WM_DEADCHAR                              0x0103
#define WM_SYSKEYDOWN                            0x0104
#define WM_SYSKEYUP                              0x0105
#define WM_SYSCHAR                               0x0106
#define WM_SYSDEADCHAR                           0x0107
#define WM_KEYLAST                               0x0108
#define WM_INITDIALOG                            0x0110
#define WM_COMMAND                               0x0111
#define WM_SYSCOMMAND                            0x0112
#define WM_TIMER                                 0x0113
#define WM_HSCROLL                               0x0114
#define WM_VSCROLL                               0x0115
#define WM_INITMENU                              0x0116
#define WM_INITMENUPOPUP                         0x0117
#define WM_MENUSELECT                            0x011F
#define WM_MENUCHAR                              0x0120
#define WM_ENTERIDLE                             0x0121
#define WM_MENURBUTTONUP                         0x0122
#define WM_MENUDRAG                              0x0123
#define WM_MENUGETOBJECT                         0x0124
#define WM_UNINITMENUPOPUP                       0x0125
#define WM_MENUCOMMAND                           0x0126
#define WM_CTLCOLORMSGBOX                        0x0132
#define WM_CTLCOLOREDIT                          0x0133
#define WM_CTLCOLORLISTBOX                       0x0134
#define WM_CTLCOLORBTN                           0x0135
#define WM_CTLCOLORDLG                           0x0136
#define WM_CTLCOLORSCROLLBAR                     0x0137
#define WM_CTLCOLORSTATIC                        0x0138
#define WM_MOUSEFIRST                            0x0200
#define WM_MOUSEMOVE                             0x0200
#define WM_LBUTTONDOWN                           0x0201
#define WM_LBUTTONUP                             0x0202
#define WM_LBUTTONDBLCLK                         0x0203
#define WM_RBUTTONDOWN                           0x0204
#define WM_RBUTTONUP                             0x0205
#define WM_RBUTTONDBLCLK                         0x0206
#define WM_MBUTTONDOWN                           0x0207
#define WM_MBUTTONUP                             0x0208
#define WM_MBUTTONDBLCLK                         0x0209
#define WM_PARENTNOTIFY                          0x0210
#define WM_ENTERMENULOOP                         0x0211
#define WM_EXITMENULOOP                          0x0212
#define WM_NEXTMENU                              0x0213
#define WM_SIZING                                0x0214
#define WM_CAPTURECHANGED                        0x0215
#define WM_MOVING                                0x0216
#define WM_DEVICECHANGE                          0x0219
#define WM_MDICREATE                             0x0220
#define WM_MDIDESTROY                            0x0221
#define WM_MDIACTIVATE                           0x0222
#define WM_MDIRESTORE                            0x0223
#define WM_MDINEXT                               0x0224
#define WM_MDIMAXIMIZE                           0x0225
#define WM_MDITILE                               0x0226
#define WM_MDICASCADE                            0x0227
#define WM_MDIICONARRANGE                        0x0228
#define WM_MDIGETACTIVE                          0x0229
#define WM_MDISETMENU                            0x0230
#define WM_ENTERSIZEMOVE                         0x0231
#define WM_EXITSIZEMOVE                          0x0232
#define WM_DROPFILES                             0x0233
#define WM_MDIREFRESHMENU                        0x0234
#define WM_MOUSEHOVER                            0x02A1
#define WM_MOUSELEAVE                            0x02A3
#define WM_CUT                                   0x0300
#define WM_COPY                                  0x0301
#define WM_PASTE                                 0x0302
#define WM_CLEAR                                 0x0303
#define WM_UNDO                                  0x0304
#define WM_RENDERFORMAT                          0x0305
#define WM_RENDERALLFORMATS                      0x0306
#define WM_DESTROYCLIPBOARD                      0x0307
#define WM_DRAWCLIPBOARD                         0x0308
#define WM_PAINTCLIPBOARD                        0x0309
#define WM_VSCROLLCLIPBOARD                      0x030A
#define WM_SIZECLIPBOARD                         0x030B
#define WM_ASKCBFORMATNAME                       0x030C
#define WM_CHANGECBCHAIN                         0x030D
#define WM_HSCROLLCLIPBOARD                      0x030E
#define WM_QUERYNEWPALETTE                       0x030F
#define WM_PALETTEISCHANGING                     0x0310
#define WM_PALETTECHANGED                        0x0311
#define WM_HOTKEY                                0x0312
#define WM_PRINT                                 0x0317
#define WM_PRINTCLIENT                           0x0318
#define WM_HANDHELDFIRST                         0x0358
#define WM_HANDHELDLAST                          0x035F
#define WM_AFXFIRST                              0x0360
#define WM_AFXLAST                               0x037F
#define WM_PENWINFIRST                           0x0380
#define WM_PENWINLAST                            0x038F
#define WM_APP                                   0x8000


// Mouse events
#define MOUSEEVENTF_MOVE                         0x0001     // mouse move
#define MOUSEEVENTF_LEFTDOWN                     0x0002     // left button down
#define MOUSEEVENTF_LEFTUP                       0x0004     // left button up
#define MOUSEEVENTF_RIGHTDOWN                    0x0008     // right button down
#define MOUSEEVENTF_RIGHTUP                      0x0010     // right button up
#define MOUSEEVENTF_MIDDLEDOWN                   0x0020     // middle button down
#define MOUSEEVENTF_MIDDLEUP                     0x0040     // middle button up
#define MOUSEEVENTF_WHEEL                        0x0800     // wheel button rolled
#define MOUSEEVENTF_ABSOLUTE                     0x8000     // absolute move


// PlaySound() flags
#define SND_SYNC                                   0x00     // play synchronously (default)
#define SND_ASYNC                                  0x01     // play asynchronously
#define SND_NODEFAULT                              0x02     // silence (!default) if sound not found
#define SND_MEMORY                                 0x04     // lpSound points to a memory file
#define SND_LOOP                                   0x08     // loop the sound until next sndPlaySound
#define SND_NOSTOP                                 0x10     // don't stop any currently playing sound

#define SND_NOWAIT                           0x00002000     // don't wait if the driver is busy
#define SND_ALIAS                            0x00010000     // name is a registry alias
#define SND_ALIAS_ID                         0x00110000     // alias is a predefined ID
#define SND_FILENAME                         0x00020000     // name is file name
#define SND_RESOURCE                         0x00040004     // name is resource name or atom

#define SND_PURGE                                0x0040     // purge non-static events for task
#define SND_APPLICATION                          0x0080     // look for application specific association
#define SND_SENTRY                           0x00080000     // generate a SoundSentry event with this sound
#define SND_SYSTEM                           0x00200000     // treat this as a system sound


// Process creation flags, see CreateProcess()
#define DEBUG_PROCESS                        0x00000001
#define DEBUG_ONLY_THIS_PROCESS              0x00000002
#define CREATE_SUSPENDED                     0x00000004
#define DETACHED_PROCESS                     0x00000008
#define CREATE_NEW_CONSOLE                   0x00000010
#define CREATE_NEW_PROCESS_GROUP             0x00000200
#define CREATE_UNICODE_ENVIRONMENT           0x00000400
#define CREATE_SEPARATE_WOW_VDM              0x00000800
#define CREATE_SHARED_WOW_VDM                0x00001000
#define INHERIT_PARENT_AFFINITY              0x00010000
#define CREATE_PROTECTED_PROCESS             0x00040000
#define EXTENDED_STARTUPINFO_PRESENT         0x00080000
#define CREATE_BREAKAWAY_FROM_JOB            0x01000000
#define CREATE_PRESERVE_CODE_AUTHZ_LEVEL     0x02000000
#define CREATE_DEFAULT_ERROR_MODE            0x04000000
#define CREATE_NO_WINDOW                     0x08000000


// Process priority flags, see CreateProcess()
#define IDLE_PRIORITY_CLASS                      0x0040
#define BELOW_NORMAL_PRIORITY_CLASS              0x4000
#define NORMAL_PRIORITY_CLASS                    0x0020
#define ABOVE_NORMAL_PRIORITY_CLASS              0x8000
#define HIGH_PRIORITY_CLASS                      0x0080
#define REALTIME_PRIORITY_CLASS                  0x0100


// ShowWindow() command ids
#define SW_SHOW                           5  // Activates the window and displays it in its current size and position.
#define SW_SHOWNA                         8  // Displays the window in its current size and position. Similar to SW_SHOW, except that the window is not activated.
#define SW_HIDE                           0  // Hides the window and activates another window.

#define SW_SHOWMAXIMIZED                  3  // Activates the window and displays it as a maximized window.
#define SW_MAXIMIZE        SW_SHOWMAXIMIZED

#define SW_SHOWMINIMIZED                  2  // Activates the window and displays it as a minimized window.
#define SW_SHOWMINNOACTIVE                7  // Displays the window as a minimized window. Similar to SW_SHOWMINIMIZED, except the window is not activated.
#define SW_MINIMIZE                       6  // Minimizes the specified window and activates the next top-level window in the Z order.
#define SW_FORCEMINIMIZE                 11  // Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when
#define SW_MAX             SW_FORCEMINIMIZE  // minimizing windows from a different thread.

#define SW_SHOWNORMAL                     1  // Activates and displays a window. If the window is minimized or maximized, Windows restores it to its original size and
#define SW_NORMAL             SW_SHOWNORMAL  // position. An application should specify this flag when displaying the window for the first time.
#define SW_SHOWNOACTIVATE                 4  // Displays a window in its most recent size and position. Similar to SW_SHOWNORMAL, except that the window is not activated.
#define SW_RESTORE                        9  // Activates and displays the window. If the window is minimized or maximized, Windows restores it to its original size and
                                             // position. An application should specify this flag when restoring a minimized window.

#define SW_SHOWDEFAULT                   10  // Sets the show state based on the SW_ flag specified in the STARTUPINFO structure passed to the CreateProcess() function by
                                             // the program that started the application.

// ShellExecute() error codes
#define SE_ERR_FNF                                    2     // file not found
#define SE_ERR_PNF                                    3     // path not found
#define SE_ERR_ACCESSDENIED                           5     // access denied
#define SE_ERR_OOM                                    8     // out of memory
#define SE_ERR_SHARE                                 26     // a sharing violation occurred
#define SE_ERR_ASSOCINCOMPLETE                       27     // file association information incomplete or invalid
#define SE_ERR_DDETIMEOUT                            28     // DDE operation timed out
#define SE_ERR_DDEFAIL                               29     // DDE operation failed
#define SE_ERR_DDEBUSY                               30     // DDE operation is busy
#define SE_ERR_NOASSOC                               31     // file association not available
#define SE_ERR_DLLNOTFOUND                           32     // dynamic-link library not found


// STARTUPINFO structure flags
#define STARTF_FORCEONFEEDBACK                   0x0040
#define STARTF_FORCEOFFFEEDBACK                  0x0080
#define STARTF_PREVENTPINNING                    0x2000
#define STARTF_RUNFULLSCREEN                     0x0020
#define STARTF_TITLEISAPPID                      0x1000
#define STARTF_TITLEISLINKNAME                   0x0800
#define STARTF_USECOUNTCHARS                     0x0008
#define STARTF_USEFILLATTRIBUTE                  0x0010
#define STARTF_USEHOTKEY                         0x0200
#define STARTF_USEPOSITION                       0x0004
#define STARTF_USESHOWWINDOW                     0x0001
#define STARTF_USESIZE                           0x0002
#define STARTF_USESTDHANDLES                     0x0100


// Struct sizes
#define PROCESS_INFORMATION.size                     16
#define SECURITY_ATTRIBUTES.size                     12
#define STARTUPINFO.size                             68
#define SYSTEMTIME.size                              16
#define TIME_ZONE_INFORMATION.size                  172
#define WIN32_FIND_DATA.size                        318


// VirtualAlloc() allocation type flags
#define MEM_COMMIT                           0x00001000
#define MEM_RESERVE                          0x00002000
#define MEM_RESET                            0x00080000
#define MEM_TOP_DOWN                         0x00100000
#define MEM_WRITE_WATCH                      0x00200000
#define MEM_PHYSICAL                         0x00400000
#define MEM_LARGE_PAGES                      0x20000000


// Wait function constants, see WaitForSingleObject()
#define WAIT_ABANDONED                       0x00000080
#define WAIT_OBJECT_0                        0x00000000
#define WAIT_TIMEOUT                         0x00000102
#define WAIT_FAILED                          0xFFFFFFFF
#define INFINITE                             0xFFFFFFFF     // infinite timeout


// Window class styles, see WNDCLASS structure
#define CS_VREDRAW                               0x0001
#define CS_HREDRAW                               0x0002
#define CS_DBLCLKS                               0x0008
#define CS_OWNDC                                 0x0020
#define CS_CLASSDC                               0x0040
#define CS_PARENTDC                              0x0080
#define CS_NOCLOSE                               0x0200
#define CS_SAVEBITS                              0x0800
#define CS_BYTEALIGNCLIENT                       0x1000
#define CS_BYTEALIGNWINDOW                       0x2000
#define CS_GLOBALCLASS                           0x4000


// Windows error codes (nur in MQL tatsächlich verwendete, für alle anderen @see FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, NULL, RtlGetLastWin32Error(), ...))
#define ERROR_SUCCESS                                 0
#define ERROR_BAD_FORMAT                             11

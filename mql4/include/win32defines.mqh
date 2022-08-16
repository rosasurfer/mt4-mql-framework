/**
 * Windows constants
 */


// AnimateWindow() commands
#define AW_HOR_POSITIVE                   0x00000001
#define AW_HOR_NEGATIVE                   0x00000002
#define AW_VER_POSITIVE                   0x00000004
#define AW_VER_NEGATIVE                   0x00000008
#define AW_CENTER                         0x00000010
#define AW_HIDE                           0x00010000
#define AW_ACTIVATE                       0x00020000
#define AW_SLIDE                          0x00040000
#define AW_BLEND                          0x00080000


// Standard Cursor IDs
#define IDC_APPSTARTING                        32650  // standard arrow and small hourglass (not in win3.1)
#define IDC_ARROW                              32512  // standard arrow
#define IDC_CROSS                              32515  // crosshair
#define IDC_IBEAM                              32513  // text I-beam
#define IDC_ICON                               32641  // Windows NT only: empty icon
#define IDC_NO                                 32648  // slashed circle (not in win3.1)
#define IDC_SIZE                               32640  // Windows NT only: four-pointed arrow
#define IDC_SIZEALL                            32646  // same as IDC_SIZE
#define IDC_SIZENESW                           32643  // double-pointed arrow pointing northeast and southwest
#define IDC_SIZENS                             32645  // double-pointed arrow pointing north and south
#define IDC_SIZENWSE                           32642  // double-pointed arrow pointing northwest and southeast
#define IDC_SIZEWE                             32644  // double-pointed arrow pointing west and east
#define IDC_UPARROW                            32516  // vertical arrow
#define IDC_WAIT                               32514  // hourglass
#define IDC_HAND                               32649  // WINVER >= 0x0500
#define IDC_HELP                               32651  // WINVER >= 0x0400


// Dialog flags
#define MB_OK                             0x00000000  // buttons
#define MB_OKCANCEL                       0x00000001
#define MB_ABORTRETRYIGNORE               0x00000002
#define MB_CANCELTRYCONTINUE              0x00000006
#define MB_RETRYCANCEL                    0x00000005
#define MB_YESNO                          0x00000004
#define MB_YESNOCANCEL                    0x00000003
#define MB_HELP                           0x00004000  // additional help button

#define MB_DEFBUTTON1                     0x00000000  // default button
#define MB_DEFBUTTON2                     0x00000100
#define MB_DEFBUTTON3                     0x00000200
#define MB_DEFBUTTON4                     0x00000300

#define MB_ICONEXCLAMATION                0x00000030  // icons
#define MB_ICONWARNING            MB_ICONEXCLAMATION
#define MB_ICONINFORMATION                0x00000040
#define MB_ICONASTERISK           MB_ICONINFORMATION
#define MB_ICONQUESTION                   0x00000020
#define MB_ICONSTOP                       0x00000010
#define MB_ICONERROR                     MB_ICONSTOP
#define MB_ICONHAND                      MB_ICONSTOP
#define MB_USERICON                       0x00000080

#define MB_APPLMODAL                      0x00000000  // modality
#define MB_SYSTEMMODAL                    0x00001000
#define MB_TASKMODAL                      0x00002000

#define MB_DEFAULT_DESKTOP_ONLY           0x00020000  // other
#define MB_RIGHT                          0x00080000
#define MB_RTLREADING                     0x00100000
#define MB_SETFOREGROUND                  0x00010000
#define MB_TOPMOST                        0x00040000
#define MB_NOFOCUS                        0x00008000
#define MB_SERVICE_NOTIFICATION           0x00200000


// Dialog return codes
#define IDOK                                       1
#define IDCANCEL                                   2
#define IDABORT                                    3
#define IDRETRY                                    4
#define IDIGNORE                                   5
#define IDYES                                      6
#define IDNO                                       7
#define IDCLOSE                                    8
#define IDHELP                                     9
#define IDTRYAGAIN                                10
#define IDCONTINUE                                11


// File & I/O constants
#define MAX_PATH                                 260     // e.g. the max. path on drive D is "D:\some-256-chars-path-string<NUL>"
#define MAX_DRIVE                                  3     // max. length of drive component
#define MAX_DIR                                  256     // max. length of path component
#define MAX_FNAME                                256     // max. length of file name component
#define MAX_EXT                                  256     // max. length of extension component

#define AT_NORMAL                               0x00     // DOS file attributes
#define AT_READONLY                             0x01
#define AT_HIDDEN                               0x02
#define AT_SYSTEM                               0x04
#define AT_ARCHIVE                              0x20


// Generic access rights
#define GENERIC_ALL                       0x10000000
#define GENERIC_EXECUTE                   0x20000000
#define GENERIC_WRITE                     0x40000000
#define GENERIC_READ                      0x80000000

// File sharing modes
#define FILE_SHARE_READ                            1
#define FILE_SHARE_WRITE                           2
#define FILE_SHARE_DELETE                          4

// File attribute flags
#define FILE_ATTRIBUTE_READONLY                    1
#define FILE_ATTRIBUTE_HIDDEN                      2
#define FILE_ATTRIBUTE_SYSTEM                      4
#define FILE_ATTRIBUTE_DIRECTORY                  16
#define FILE_ATTRIBUTE_ARCHIVE                    32
#define FILE_ATTRIBUTE_DEVICE                     64
#define FILE_ATTRIBUTE_NORMAL                    128
#define FILE_ATTRIBUTE_TEMPORARY                 256
#define FILE_ATTRIBUTE_SPARSE_FILE               512
#define FILE_ATTRIBUTE_REPARSE_POINT            1024
#define FILE_ATTRIBUTE_COMPRESSED               2048
#define FILE_ATTRIBUTE_OFFLINE                  4096
#define FILE_ATTRIBUTE_NOT_INDEXED              8192     // FILE_ATTRIBUTE_NOT_CONTENT_INDEXED is too long for MQL4
#define FILE_ATTRIBUTE_ENCRYPTED               16384
#define FILE_ATTRIBUTE_VIRTUAL                 65536

#define OF_READ                                 0x00
#define OF_WRITE                                0x01
#define OF_READWRITE                            0x02
#define OF_SHARE_COMPAT                         0x00
#define OF_SHARE_EXCLUSIVE                      0x10
#define OF_SHARE_DENY_WRITE                     0x20
#define OF_SHARE_DENY_READ                      0x30
#define OF_SHARE_DENY_NONE                      0x40

// File open/creation options
#define CREATE_NEW                                 1
#define CREATE_ALWAYS                              2
#define OPEN_EXISTING                              3
#define OPEN_ALWAYS                                4
#define TRUNCATE_EXISTING                          5


// Invalid handle/value
#define INVALID_FILE_SIZE                 0xFFFFFFFF     // -1
#define INVALID_FILE_ATTRIBUTES           0xFFFFFFFF     // -1
#define INVALID_SET_FILE_POINTER          0xFFFFFFFF     // -1
#define INVALID_HANDLE_VALUE              0xFFFFFFFF     // -1
#define INVALID_HWND                      0xFFFFFFFF     // -1
#define HFILE_ERROR                       0xFFFFFFFF     // -1


// GDI region codes, see GetClipBox()
#define ERROR                                      0
#define NULLREGION                                 1
#define SIMPLEREGION                               2
#define COMPLEXREGION                              3
#define RGN_ERROR                              ERROR


// GetAncestor() constants
#define GA_PARENT                                  1
#define GA_ROOT                                    2
#define GA_ROOTOWNER                               3


// GetSystemMetrics() codes
#define SM_CXSCREEN                                0
#define SM_CYSCREEN                                1
#define SM_CXVSCROLL                               2
#define SM_CYHSCROLL                               3
#define SM_CYCAPTION                               4
#define SM_CXBORDER                                5
#define SM_CYBORDER                                6
#define SM_CXDLGFRAME                              7
#define SM_CYDLGFRAME                              8
#define SM_CYVTHUMB                                9
#define SM_CXHTHUMB                               10
#define SM_CXICON                                 11
#define SM_CYICON                                 12
#define SM_CXCURSOR                               13
#define SM_CYCURSOR                               14
#define SM_CYMENU                                 15
#define SM_CXFULLSCREEN                           16
#define SM_CYFULLSCREEN                           17
#define SM_CYKANJIWINDOW                          18
#define SM_MOUSEPRESENT                           19
#define SM_CYVSCROLL                              20
#define SM_CXHSCROLL                              21
#define SM_DEBUG                                  22
#define SM_SWAPBUTTON                             23
#define SM_RESERVED1                              24
#define SM_RESERVED2                              25
#define SM_RESERVED3                              26
#define SM_RESERVED4                              27
#define SM_CXMIN                                  28
#define SM_CYMIN                                  29
#define SM_CXSIZE                                 30
#define SM_CYSIZE                                 31
#define SM_CXFRAME                                32
#define SM_CYFRAME                                33
#define SM_CXMINTRACK                             34
#define SM_CYMINTRACK                             35
#define SM_CXDOUBLECLK                            36
#define SM_CYDOUBLECLK                            37
#define SM_CXICONSPACING                          38
#define SM_CYICONSPACING                          39
#define SM_MENUDROPALIGNMENT                      40
#define SM_PENWINDOWS                             41
#define SM_DBCSENABLED                            42
#define SM_CMOUSEBUTTONS                          43
#define SM_SECURE                                 44
#define SM_CXEDGE                                 45
#define SM_CYEDGE                                 46
#define SM_CXMINSPACING                           47
#define SM_CYMINSPACING                           48
#define SM_CXSMICON                               49
#define SM_CYSMICON                               50
#define SM_CYSMCAPTION                            51
#define SM_CXSMSIZE                               52
#define SM_CYSMSIZE                               53
#define SM_CXMENUSIZE                             54
#define SM_CYMENUSIZE                             55
#define SM_ARRANGE                                56
#define SM_CXMINIMIZED                            57
#define SM_CYMINIMIZED                            58
#define SM_CXMAXTRACK                             59
#define SM_CYMAXTRACK                             60
#define SM_CXMAXIMIZED                            61
#define SM_CYMAXIMIZED                            62
#define SM_NETWORK                                63
#define SM_CLEANBOOT                              67
#define SM_CXDRAG                                 68
#define SM_CYDRAG                                 69
#define SM_SHOWSOUNDS                             70
#define SM_CXMENUCHECK                            71     // use instead of GetMenuCheckMarkDimensions()
#define SM_CYMENUCHECK                            72
#define SM_SLOWMACHINE                            73
#define SM_MIDEASTENABLED                         74
#define SM_MOUSEWHEELPRESENT                      75
#define SM_XVIRTUALSCREEN                         76
#define SM_YVIRTUALSCREEN                         77
#define SM_CXVIRTUALSCREEN                        78
#define SM_CYVIRTUALSCREEN                        79
#define SM_CMONITORS                              80
#define SM_SAMEDISPLAYFORMAT                      81


// GetTimeZoneInformation() constants
#define TIME_ZONE_ID_UNKNOWN                       0
#define TIME_ZONE_ID_STANDARD                      1
#define TIME_ZONE_ID_DAYLIGHT                      2


// GetWindow() constants
#define GW_HWNDFIRST                               0
#define GW_HWNDLAST                                1
#define GW_HWNDNEXT                                2
#define GW_HWNDPREV                                3
#define GW_OWNER                                   4
#define GW_CHILD                                   5
#define GW_ENABLEDPOPUP                            6


// RedrawWindow() flags
#define RDW_INVALIDATE                        0x0001
#define RDW_INTERNALPAINT                     0x0002
#define RDW_ERASE                             0x0004

#define RDW_VALIDATE                          0x0008
#define RDW_NOINTERNALPAINT                   0x0010
#define RDW_NOERASE                           0x0020

#define RDW_NOCHILDREN                        0x0040
#define RDW_ALLCHILDREN                       0x0080

#define RDW_UPDATENOW                         0x0100
#define RDW_ERASENOW                          0x0200

#define RDW_FRAME                             0x0400
#define RDW_NOFRAME                           0x0800


// Memory protection constants, see VirtualAlloc()
#define PAGE_EXECUTE                            0x10     // options
#define PAGE_EXECUTE_READ                       0x20
#define PAGE_EXECUTE_READWRITE                  0x40
#define PAGE_EXECUTE_WRITECOPY                  0x80
#define PAGE_NOACCESS                           0x01
#define PAGE_READONLY                           0x02
#define PAGE_READWRITE                          0x04
#define PAGE_WRITECOPY                          0x08

#define PAGE_GUARD                             0x100     // modifier
#define PAGE_NOCACHE                           0x200
#define PAGE_WRITECOMBINE                      0x400


// Keyboard events
#define KEYEVENTF_EXTENDEDKEY                   0x01
#define KEYEVENTF_KEYUP                         0x02


// Virtual-Key codes, @see https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
#define VK_LBUTTON               0x01     // Left mouse button
#define VK_RBUTTON               0x02     // Right mouse button
#define VK_CANCEL                0x03     // Control-break processing
#define VK_MBUTTON               0x04     // Middle mouse button (three-button mouse)
#define VK_XBUTTON1              0x05     // X1 mouse button
#define VK_XBUTTON2              0x06     // X2 mouse button
//      -                        0x07     // undefined
#define VK_BACK                  0x08     // BACKSPACE key
#define VK_TAB                   0x09     // TAB key
//      -                        0x0A-0B  // reserved
#define VK_CLEAR                 0x0C     // CLEAR key
#define VK_RETURN                0x0D     // ENTER key
//      -                        0x0E-0F  // undefined
#define VK_SHIFT                 0x10     // SHIFT key
#define VK_CONTROL               0x11     // CTRL key
#define VK_MENU                  0x12     // ALT key
#define VK_PAUSE                 0x13     // PAUSE key
#define VK_CAPITAL               0x14     // CAPS LOCK key
#define VK_KANA                  0x15     // IME Kana mode
#define VK_HANGUEL               0x15     // IME Hanguel mode (maintained for compatibility, use VK_HANGUL)
#define VK_HANGUL                0x15     // IME Hangul mode
#define VK_IME_ON                0x16     // IME On
#define VK_JUNJA                 0x17     // IME Junja mode
#define VK_FINAL                 0x18     // IME final mode
#define VK_HANJA                 0x19     // IME Hanja mode
#define VK_KANJI                 0x19     // IME Kanji mode
#define VK_IME_OFF               0x1A     // IME Off
#define VK_ESCAPE                0x1B     // ESC key
#define VK_CONVERT               0x1C     // IME convert
#define VK_NONCONVERT            0x1D     // IME nonconvert
#define VK_ACCEPT                0x1E     // IME accept
#define VK_MODECHANGE            0x1F     // IME mode change request
#define VK_SPACE                 0x20     // SPACEBAR
#define VK_PRIOR                 0x21     // PAGE UP key
#define VK_NEXT                  0x22     // PAGE DOWN key
#define VK_END                   0x23     // END key
#define VK_HOME                  0x24     // HOME key
#define VK_LEFT                  0x25     // LEFT ARROW key
#define VK_UP                    0x26     // UP ARROW key
#define VK_RIGHT                 0x27     // RIGHT ARROW key
#define VK_DOWN                  0x28     // DOWN ARROW key
#define VK_SELECT                0x29     // SELECT key
#define VK_PRINT                 0x2A     // PRINT key
#define VK_EXECUTE               0x2B     // EXECUTE key
#define VK_SNAPSHOT              0x2C     // PRINT SCREEN key
#define VK_INSERT                0x2D     // INS key
#define VK_DELETE                0x2E     // DEL key
#define VK_HELP                  0x2F     // HELP key
//                               0x30     // 0 key
//                               0x31     // 1 key
//                               0x32     // 2 key
//                               0x33     // 3 key
//                               0x34     // 4 key
//                               0x35     // 5 key
//                               0x36     // 6 key
//                               0x37     // 7 key
//                               0x38     // 8 key
//                               0x39     // 9 key
//      -                        0x3A-40  // undefined
//                               0x41     // A key
//                               0x42     // B key
//                               0x43     // C key
//                               0x44     // D key
//                               0x45     // E key
//                               0x46     // F key
//                               0x47     // G key
//                               0x48     // H key
//                               0x49     // I key
//                               0x4A     // J key
//                               0x4B     // K key
//                               0x4C     // L key
//                               0x4D     // M key
//                               0x4E     // N key
//                               0x4F     // O key
//                               0x50     // P key
//                               0x51     // Q key
//                               0x52     // R key
//                               0x53     // S key
//                               0x54     // T key
//                               0x55     // U key
//                               0x56     // V key
//                               0x57     // W key
//                               0x58     // X key
//                               0x59     // Y key
//                               0x5A     // Z key
#define VK_LWIN                  0x5B     // Left Windows key (natural keyboard)
#define VK_RWIN                  0x5C     // Right Windows key (natural keyboard)
#define VK_APPS                  0x5D     // Applications key (natural keyboard)
//      -                        0x5E     // reserved
#define VK_SLEEP                 0x5F     // Computer Sleep key
#define VK_NUMPAD0               0x60     // Numeric keypad 0 key
#define VK_NUMPAD1               0x61     // Numeric keypad 1 key
#define VK_NUMPAD2               0x62     // Numeric keypad 2 key
#define VK_NUMPAD3               0x63     // Numeric keypad 3 key
#define VK_NUMPAD4               0x64     // Numeric keypad 4 key
#define VK_NUMPAD5               0x65     // Numeric keypad 5 key
#define VK_NUMPAD6               0x66     // Numeric keypad 6 key
#define VK_NUMPAD7               0x67     // Numeric keypad 7 key
#define VK_NUMPAD8               0x68     // Numeric keypad 8 key
#define VK_NUMPAD9               0x69     // Numeric keypad 9 key
#define VK_MULTIPLY              0x6A     // Multiply key
#define VK_ADD                   0x6B     // Add key
#define VK_SEPARATOR             0x6C     // Separator key
#define VK_SUBTRACT              0x6D     // Subtract key
#define VK_DECIMAL               0x6E     // Decimal key
#define VK_DIVIDE                0x6F     // Divide key
#define VK_F1                    0x70     // F1 key
#define VK_F2                    0x71     // F2 key
#define VK_F3                    0x72     // F3 key
#define VK_F4                    0x73     // F4 key
#define VK_F5                    0x74     // F5 key
#define VK_F6                    0x75     // F6 key
#define VK_F7                    0x76     // F7 key
#define VK_F8                    0x77     // F8 key
#define VK_F9                    0x78     // F9 key
#define VK_F10                   0x79     // F10 key
#define VK_F11                   0x7A     // F11 key
#define VK_F12                   0x7B     // F12 key
#define VK_F13                   0x7C     // F13 key
#define VK_F14                   0x7D     // F14 key
#define VK_F15                   0x7E     // F15 key
#define VK_F16                   0x7F     // F16 key
#define VK_F17                   0x80     // F17 key
#define VK_F18                   0x81     // F18 key
#define VK_F19                   0x82     // F19 key
#define VK_F20                   0x83     // F20 key
#define VK_F21                   0x84     // F21 key
#define VK_F22                   0x85     // F22 key
#define VK_F23                   0x86     // F23 key
#define VK_F24                   0x87     // F24 key
//      -                        0x88-8F  // unassigned
#define VK_NUMLOCK               0x90     // NUM LOCK key
#define VK_SCROLL                0x91     // SCROLL LOCK key
//                               0x92-96  // OEM specific
//      -                        0x97-9F  // unassigned
#define VK_LSHIFT                0xA0     // Left SHIFT key
#define VK_RSHIFT                0xA1     // Right SHIFT key
#define VK_LCONTROL              0xA2     // Left CONTROL key
#define VK_RCONTROL              0xA3     // Right CONTROL key
#define VK_LMENU                 0xA4     // Left MENU key
#define VK_RMENU                 0xA5     // Right MENU key
#define VK_BROWSER_BACK          0xA6     // Browser Back key
#define VK_BROWSER_FORWARD       0xA7     // Browser Forward key
#define VK_BROWSER_REFRESH       0xA8     // Browser Refresh key
#define VK_BROWSER_STOP          0xA9     // Browser Stop key
#define VK_BROWSER_SEARCH        0xAA     // Browser Search key
#define VK_BROWSER_FAVORITES     0xAB     // Browser Favorites key
#define VK_BROWSER_HOME          0xAC     // Browser Start and Home key
#define VK_VOLUME_MUTE           0xAD     // Volume Mute key
#define VK_VOLUME_DOWN           0xAE     // Volume Down key
#define VK_VOLUME_UP             0xAF     // Volume Up key
#define VK_MEDIA_NEXT_TRACK      0xB0     // Next Track key
#define VK_MEDIA_PREV_TRACK      0xB1     // Previous Track key
#define VK_MEDIA_STOP            0xB2     // Stop Media key
#define VK_MEDIA_PLAY_PAUSE      0xB3     // Play/Pause Media key
#define VK_LAUNCH_MAIL           0xB4     // Start Mail key
#define VK_LAUNCH_MEDIA_SELECT   0xB5     // Select Media key
#define VK_LAUNCH_APP1           0xB6     // Start Application 1 key
#define VK_LAUNCH_APP2           0xB7     // Start Application 2 key
//      -                        0xB8-B9  // reserved
#define VK_OEM_1                 0xBA     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the ';:' key
#define VK_OEM_PLUS              0xBB     // For any country/region, the '+' key
#define VK_OEM_COMMA             0xBC     // For any country/region, the ',' key
#define VK_OEM_MINUS             0xBD     // For any country/region, the '-' key
#define VK_OEM_PERIOD            0xBE     // For any country/region, the '.' key
#define VK_OEM_2                 0xBF     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the '/?' key
#define VK_OEM_3                 0xC0     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the '`~' key
//      -                        0xC1-D7  // reserved
//      -                        0xD8-DA  // unassigned
#define VK_OEM_4                 0xDB     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the '[{' key
#define VK_OEM_5                 0xDC     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the '\|' key
#define VK_OEM_6                 0xDD     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the ']}' key
#define VK_OEM_7                 0xDE     // Used for miscellaneous characters and can vary by keyboard. For the US standard keyboard, the 'single-quote/double-quote' key
#define VK_OEM_8                 0xDF     // Used for miscellaneous characters and can vary by keyboard.
//      -                        0xE0     // reserved
//                               0xE1     // OEM specific
#define VK_OEM_102               0xE2     // The <> keys on the US standard keyboard, or the \\| key on the non-US 102-key keyboard
//                               0xE3-E4  // OEM specific
#define VK_PROCESSKEY            0xE5     // IME PROCESS key
//                               0xE6     // OEM specific
#define VK_PACKET                0xE7     // Used to pass Unicode characters as if they were keystrokes; @see remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
//      -                        0xE8     // unassigned
//                               0xE9-F5  // OEM specific
#define VK_ATTN                  0xF6     // Attn key
#define VK_CRSEL                 0xF7     // CrSel key
#define VK_EXSEL                 0xF8     // ExSel key
#define VK_EREOF                 0xF9     // Erase EOF key
#define VK_PLAY                  0xFA     // Play key
#define VK_ZOOM                  0xFB     // Zoom key
#define VK_NONAME                0xFC     // reserved
#define VK_PA1                   0xFD     // PA1 key
#define VK_OEM_CLEAR             0xFE     // Clear key


// Windows messages
#define WM_NULL                               0x0000
#define WM_CREATE                             0x0001
#define WM_DESTROY                            0x0002
#define WM_MOVE                               0x0003
#define WM_SIZE                               0x0005
#define WM_ACTIVATE                           0x0006
#define WM_SETFOCUS                           0x0007
#define WM_KILLFOCUS                          0x0008
#define WM_ENABLE                             0x000A
#define WM_SETREDRAW                          0x000B
#define WM_SETTEXT                            0x000C
#define WM_GETTEXT                            0x000D
#define WM_GETTEXTLENGTH                      0x000E
#define WM_PAINT                              0x000F
#define WM_CLOSE                              0x0010
#define WM_QUERYENDSESSION                    0x0011
#define WM_QUIT                               0x0012
#define WM_QUERYOPEN                          0x0013
#define WM_ERASEBKGND                         0x0014
#define WM_SYSCOLORCHANGE                     0x0015
#define WM_ENDSESSION                         0x0016
#define WM_SHOWWINDOW                         0x0018
#define WM_WININICHANGE                       0x001A
#define WM_SETTINGCHANGE                      0x001A     // WM_WININICHANGE
#define WM_DEVMODECHANGE                      0x001B
#define WM_ACTIVATEAPP                        0x001C
#define WM_FONTCHANGE                         0x001D
#define WM_TIMECHANGE                         0x001E
#define WM_CANCELMODE                         0x001F
#define WM_SETCURSOR                          0x0020
#define WM_MOUSEACTIVATE                      0x0021
#define WM_CHILDACTIVATE                      0x0022
#define WM_QUEUESYNC                          0x0023
#define WM_GETMINMAXINFO                      0x0024
#define WM_PAINTICON                          0x0026
#define WM_ICONERASEBKGND                     0x0027
#define WM_NEXTDLGCTL                         0x0028
#define WM_SPOOLERSTATUS                      0x002A
#define WM_DRAWITEM                           0x002B
#define WM_MEASUREITEM                        0x002C
#define WM_DELETEITEM                         0x002D
#define WM_VKEYTOITEM                         0x002E
#define WM_CHARTOITEM                         0x002F
#define WM_SETFONT                            0x0030
#define WM_GETFONT                            0x0031
#define WM_SETHOTKEY                          0x0032
#define WM_GETHOTKEY                          0x0033
#define WM_QUERYDRAGICON                      0x0037
#define WM_COMPAREITEM                        0x0039
#define WM_GETOBJECT                          0x003D
#define WM_COMPACTING                         0x0041
#define WM_WINDOWPOSCHANGING                  0x0046
#define WM_WINDOWPOSCHANGED                   0x0047
#define WM_COPYDATA                           0x004A
#define WM_CANCELJOURNAL                      0x004B
#define WM_NOTIFY                             0x004E
#define WM_INPUTLANGCHANGEREQUEST             0x0050
#define WM_INPUTLANGCHANGE                    0x0051
#define WM_TCARD                              0x0052
#define WM_HELP                               0x0053
#define WM_USERCHANGED                        0x0054
#define WM_NOTIFYFORMAT                       0x0055
#define WM_CONTEXTMENU                        0x007B
#define WM_STYLECHANGING                      0x007C
#define WM_STYLECHANGED                       0x007D
#define WM_DISPLAYCHANGE                      0x007E
#define WM_GETICON                            0x007F
#define WM_SETICON                            0x0080
#define WM_NCCREATE                           0x0081
#define WM_NCDESTROY                          0x0082
#define WM_NCCALCSIZE                         0x0083
#define WM_NCHITTEST                          0x0084
#define WM_NCPAINT                            0x0085
#define WM_NCACTIVATE                         0x0086
#define WM_GETDLGCODE                         0x0087
#define WM_SYNCPAINT                          0x0088
#define WM_NCMOUSEMOVE                        0x00A0
#define WM_NCLBUTTONDOWN                      0x00A1
#define WM_NCLBUTTONUP                        0x00A2
#define WM_NCLBUTTONDBLCLK                    0x00A3
#define WM_NCRBUTTONDOWN                      0x00A4
#define WM_NCRBUTTONUP                        0x00A5
#define WM_NCRBUTTONDBLCLK                    0x00A6
#define WM_NCMBUTTONDOWN                      0x00A7
#define WM_NCMBUTTONUP                        0x00A8
#define WM_NCMBUTTONDBLCLK                    0x00A9
#define WM_KEYFIRST                           0x0100
#define WM_KEYDOWN                            0x0100
#define WM_KEYUP                              0x0101
#define WM_CHAR                               0x0102
#define WM_DEADCHAR                           0x0103
#define WM_SYSKEYDOWN                         0x0104
#define WM_SYSKEYUP                           0x0105
#define WM_SYSCHAR                            0x0106
#define WM_SYSDEADCHAR                        0x0107
#define WM_KEYLAST                            0x0108
#define WM_INITDIALOG                         0x0110
#define WM_COMMAND                            0x0111
#define WM_SYSCOMMAND                         0x0112
#define WM_TIMER                              0x0113
#define WM_HSCROLL                            0x0114
#define WM_VSCROLL                            0x0115
#define WM_INITMENU                           0x0116
#define WM_INITMENUPOPUP                      0x0117
#define WM_MENUSELECT                         0x011F
#define WM_MENUCHAR                           0x0120
#define WM_ENTERIDLE                          0x0121
#define WM_MENURBUTTONUP                      0x0122
#define WM_MENUDRAG                           0x0123
#define WM_MENUGETOBJECT                      0x0124
#define WM_UNINITMENUPOPUP                    0x0125
#define WM_MENUCOMMAND                        0x0126
#define WM_CTLCOLORMSGBOX                     0x0132
#define WM_CTLCOLOREDIT                       0x0133
#define WM_CTLCOLORLISTBOX                    0x0134
#define WM_CTLCOLORBTN                        0x0135
#define WM_CTLCOLORDLG                        0x0136
#define WM_CTLCOLORSCROLLBAR                  0x0137
#define WM_CTLCOLORSTATIC                     0x0138
#define WM_MOUSEFIRST                         0x0200
#define WM_MOUSEMOVE                          0x0200
#define WM_LBUTTONDOWN                        0x0201
#define WM_LBUTTONUP                          0x0202
#define WM_LBUTTONDBLCLK                      0x0203
#define WM_RBUTTONDOWN                        0x0204
#define WM_RBUTTONUP                          0x0205
#define WM_RBUTTONDBLCLK                      0x0206
#define WM_MBUTTONDOWN                        0x0207
#define WM_MBUTTONUP                          0x0208
#define WM_MBUTTONDBLCLK                      0x0209
#define WM_PARENTNOTIFY                       0x0210
#define WM_ENTERMENULOOP                      0x0211
#define WM_EXITMENULOOP                       0x0212
#define WM_NEXTMENU                           0x0213
#define WM_SIZING                             0x0214
#define WM_CAPTURECHANGED                     0x0215
#define WM_MOVING                             0x0216
#define WM_DEVICECHANGE                       0x0219
#define WM_MDICREATE                          0x0220
#define WM_MDIDESTROY                         0x0221
#define WM_MDIACTIVATE                        0x0222
#define WM_MDIRESTORE                         0x0223
#define WM_MDINEXT                            0x0224
#define WM_MDIMAXIMIZE                        0x0225
#define WM_MDITILE                            0x0226
#define WM_MDICASCADE                         0x0227
#define WM_MDIICONARRANGE                     0x0228
#define WM_MDIGETACTIVE                       0x0229
#define WM_MDISETMENU                         0x0230
#define WM_ENTERSIZEMOVE                      0x0231
#define WM_EXITSIZEMOVE                       0x0232
#define WM_DROPFILES                          0x0233
#define WM_MDIREFRESHMENU                     0x0234
#define WM_MOUSEHOVER                         0x02A1
#define WM_MOUSELEAVE                         0x02A3
#define WM_CUT                                0x0300
#define WM_COPY                               0x0301
#define WM_PASTE                              0x0302
#define WM_CLEAR                              0x0303
#define WM_UNDO                               0x0304
#define WM_RENDERFORMAT                       0x0305
#define WM_RENDERALLFORMATS                   0x0306
#define WM_DESTROYCLIPBOARD                   0x0307
#define WM_DRAWCLIPBOARD                      0x0308
#define WM_PAINTCLIPBOARD                     0x0309
#define WM_VSCROLLCLIPBOARD                   0x030A
#define WM_SIZECLIPBOARD                      0x030B
#define WM_ASKCBFORMATNAME                    0x030C
#define WM_CHANGECBCHAIN                      0x030D
#define WM_HSCROLLCLIPBOARD                   0x030E
#define WM_QUERYNEWPALETTE                    0x030F
#define WM_PALETTEISCHANGING                  0x0310
#define WM_PALETTECHANGED                     0x0311
#define WM_HOTKEY                             0x0312
#define WM_PRINT                              0x0317
#define WM_PRINTCLIENT                        0x0318
#define WM_HANDHELDFIRST                      0x0358
#define WM_HANDHELDLAST                       0x035F
#define WM_AFXFIRST                           0x0360
#define WM_AFXLAST                            0x037F
#define WM_PENWINFIRST                        0x0380
#define WM_PENWINLAST                         0x038F
#define WM_APP                                0x8000

#define BM_CLICK                              0x00F5


// Mouse events
#define MOUSEEVENTF_MOVE                      0x0001     // mouse move
#define MOUSEEVENTF_LEFTDOWN                  0x0002     // left button down
#define MOUSEEVENTF_LEFTUP                    0x0004     // left button up
#define MOUSEEVENTF_RIGHTDOWN                 0x0008     // right button down
#define MOUSEEVENTF_RIGHTUP                   0x0010     // right button up
#define MOUSEEVENTF_MIDDLEDOWN                0x0020     // middle button down
#define MOUSEEVENTF_MIDDLEUP                  0x0040     // middle button up
#define MOUSEEVENTF_WHEEL                     0x0800     // wheel button rolled
#define MOUSEEVENTF_ABSOLUTE                  0x8000     // absolute move


// PlaySound() flags
#define SND_SYNC                                0x00     // play synchronously (default)
#define SND_ASYNC                               0x01     // play asynchronously in another thread and immediately return (doesn't mix sounds)
#define SND_NODEFAULT                           0x02     // silence (!default) if sound not found
#define SND_MEMORY                              0x04     // lpSound points to a memory file
#define SND_LOOP                                0x08     // loop the sound until next sndPlaySound
#define SND_NOSTOP                              0x10     // don't stop any currently playing sound

#define SND_NOWAIT                        0x00002000     // don't wait if the driver is busy
#define SND_ALIAS                         0x00010000     // name is a registry alias
#define SND_ALIAS_ID                      0x00110000     // alias is a predefined ID
#define SND_FILENAME                      0x00020000     // name is file name
#define SND_RESOURCE                      0x00040004     // name is resource name or atom

#define SND_PURGE                             0x0040     // purge non-static events for task
#define SND_APPLICATION                       0x0080     // look for application specific association
#define SND_SENTRY                        0x00080000     // generate a SoundSentry event with this sound
#define SND_SYSTEM                        0x00200000     // treat this as a system sound


// Process creation flags, see CreateProcess()
#define DEBUG_PROCESS                    0x00000001
#define DEBUG_ONLY_THIS_PROCESS          0x00000002
#define CREATE_SUSPENDED                 0x00000004
#define DETACHED_PROCESS                 0x00000008
#define CREATE_NEW_CONSOLE               0x00000010
#define CREATE_NEW_PROCESS_GROUP         0x00000200
#define CREATE_UNICODE_ENVIRONMENT       0x00000400
#define CREATE_SEPARATE_WOW_VDM          0x00000800
#define CREATE_SHARED_WOW_VDM            0x00001000
#define INHERIT_PARENT_AFFINITY          0x00010000
#define CREATE_PROTECTED_PROCESS         0x00040000
#define EXTENDED_STARTUPINFO_PRESENT     0x00080000
#define CREATE_BREAKAWAY_FROM_JOB        0x01000000
#define CREATE_PRESERVE_CODE_AUTHZ_LEVEL 0x02000000
#define CREATE_DEFAULT_ERROR_MODE        0x04000000
#define CREATE_NO_WINDOW                 0x08000000


// Process priority flags, see CreateProcess()
#define IDLE_PRIORITY_CLASS                   0x0040
#define BELOW_NORMAL_PRIORITY_CLASS           0x4000
#define NORMAL_PRIORITY_CLASS                 0x0020
#define ABOVE_NORMAL_PRIORITY_CLASS           0x8000
#define HIGH_PRIORITY_CLASS                   0x0080
#define REALTIME_PRIORITY_CLASS               0x0100


// ShowWindow() constants
#define SW_SHOW               5  // Activates the window and displays it in its current size and position.
#define SW_SHOWNA             8  // Displays the window in its current size and position. Similar to SW_SHOW, except that the window is not activated.
#define SW_HIDE               0  // Hides the window and activates another window.

#define SW_SHOWMAXIMIZED      3  // Activates the window and displays it as a maximized window.

#define SW_SHOWMINIMIZED      2  // Activates the window and displays it as a minimized window.
#define SW_SHOWMINNOACTIVE    7  // Displays the window as a minimized window. Similar to SW_SHOWMINIMIZED, except the window is not activated.
#define SW_MINIMIZE           6  // Minimizes the specified window and activates the next top-level window in the Z order.
#define SW_FORCEMINIMIZE     11  // Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when
                                 // minimizing windows from a different thread.

#define SW_SHOWNORMAL         1  // Activates and displays a window. If the window is minimized or maximized, Windows restores it to its original size and
                                 // position. An application should specify this flag when displaying the window for the first time.
#define SW_SHOWNOACTIVATE     4  // Displays a window in its most recent size and position. Similar to SW_SHOWNORMAL, except that the window is not activated.
#define SW_RESTORE            9  // Activates and displays the window. If the window is minimized or maximized, Windows restores it to its original size and
                                 // position. An application should specify this flag when restoring a minimized window.

#define SW_SHOWDEFAULT       10  // Sets the show state based on the SW_ flag specified in the STARTUPINFO structure passed to the CreateProcess() function by
                                 // the program that started the application.

// ShellExecute() error codes
#define SE_ERR_FNF                                 2     // file not found
#define SE_ERR_PNF                                 3     // path not found
#define SE_ERR_ACCESSDENIED                        5     // access denied
#define SE_ERR_OOM                                 8     // out of memory
#define SE_ERR_SHARE                              26     // a sharing violation occurred
#define SE_ERR_ASSOCINCOMPLETE                    27     // file association information incomplete or invalid
#define SE_ERR_DDETIMEOUT                         28     // DDE operation timed out
#define SE_ERR_DDEFAIL                            29     // DDE operation failed
#define SE_ERR_DDEBUSY                            30     // DDE operation is busy
#define SE_ERR_NOASSOC                            31     // file association not available
#define SE_ERR_DLLNOTFOUND                        32     // DLL not found


// struct STARTUPINFO flags
#define STARTF_FORCEONFEEDBACK                0x0040
#define STARTF_FORCEOFFFEEDBACK               0x0080
#define STARTF_PREVENTPINNING                 0x2000
#define STARTF_RUNFULLSCREEN                  0x0020
#define STARTF_TITLEISAPPID                   0x1000
#define STARTF_TITLEISLINKNAME                0x0800
#define STARTF_USECOUNTCHARS                  0x0008
#define STARTF_USEFILLATTRIBUTE               0x0010
#define STARTF_USEHOTKEY                      0x0200
#define STARTF_USEPOSITION                    0x0004
#define STARTF_USESHOWWINDOW                  0x0001
#define STARTF_USESIZE                        0x0002
#define STARTF_USESTDHANDLES                  0x0100


// VirtualAlloc() allocation type flags
#define MEM_COMMIT                        0x00001000
#define MEM_RESERVE                       0x00002000
#define MEM_RESET                         0x00080000
#define MEM_TOP_DOWN                      0x00100000
#define MEM_WRITE_WATCH                   0x00200000
#define MEM_PHYSICAL                      0x00400000
#define MEM_LARGE_PAGES                   0x20000000


// Wait function constants, see WaitForSingleObject()
#define WAIT_ABANDONED                    0x00000080
#define WAIT_OBJECT_0                     0x00000000
#define WAIT_TIMEOUT                      0x00000102
#define WAIT_FAILED                       0xFFFFFFFF
#define INFINITE                          0xFFFFFFFF     // infinite timeout


// Window class styles, see WNDCLASS structure
#define CS_VREDRAW                            0x0001
#define CS_HREDRAW                            0x0002
#define CS_DBLCLKS                            0x0008
#define CS_OWNDC                              0x0020
#define CS_CLASSDC                            0x0040
#define CS_PARENTDC                           0x0080
#define CS_NOCLOSE                            0x0200
#define CS_SAVEBITS                           0x0800
#define CS_BYTEALIGNCLIENT                    0x1000
#define CS_BYTEALIGNWINDOW                    0x2000
#define CS_GLOBALCLASS                        0x4000


// GetComputerName() constants
#define MAX_COMPUTERNAME_LENGTH                   15


// Win32 error codes (for error descriptions see FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, NULL, GetLastWin32Error(), ...))
//
// @link  https://docs.microsoft.com/en-us/windows/desktop/debug/system-error-codes
//
#define ERROR_SUCCESS                              0     // The operation completed successfully.
#define ERROR_INVALID_FUNCTION                     1     // Incorrect function.
#define ERROR_FILE_NOT_FOUND                       2     // The system cannot find the file specified.
#define ERROR_PATH_NOT_FOUND                       3     // The system cannot find the path specified.
#define ERROR_TOO_MANY_OPEN_FILES                  4     // The system cannot open the file.
#define ERROR_ACCESS_DENIED                        5     // Access is denied.
#define ERROR_INVALID_HANDLE                       6     // The handle is invalid.
#define ERROR_ARENA_TRASHED                        7     // The storage control blocks were destroyed.
#define ERROR_NOT_ENOUGH_MEMORY                    8     // Not enough storage is available to process this command.
#define ERROR_INVALID_BLOCK                        9     // The storage control block address is invalid.
#define ERROR_BAD_ENVIRONMENT                     10     // The environment is incorrect.
#define ERROR_BAD_FORMAT                          11     // An attempt was made to load a program with an incorrect format.
#define ERROR_INVALID_ACCESS                      12     // The access code is invalid.
#define ERROR_INVALID_DATA                        13     // The data is invalid.
#define ERROR_OUTOFMEMORY                         14     // Not enough storage is available to complete this operation.
#define ERROR_INVALID_DRIVE                       15     // The system cannot find the drive specified.
#define ERROR_CURRENT_DIRECTORY                   16     // The directory cannot be removed.
#define ERROR_NOT_SAME_DEVICE                     17     // The system cannot move the file to a different disk drive.
#define ERROR_NO_MORE_FILES                       18     // There are no more files.
#define ERROR_WRITE_PROTECT                       19     // The media is write protected.
#define ERROR_BAD_UNIT                            20     // The system cannot find the device specified.
#define ERROR_NOT_READY                           21     // The device is not ready.
#define ERROR_BAD_COMMAND                         22     // The device does not recognize the command.
#define ERROR_CRC                                 23     // Data error (cyclic redundancy check).
#define ERROR_BAD_LENGTH                          24     // The program issued a command but the command length is incorrect.
#define ERROR_SEEK                                25     // The drive cannot locate a specific area or track on the disk.
#define ERROR_NOT_DOS_DISK                        26     // The specified disk or diskette cannot be accessed.
#define ERROR_SECTOR_NOT_FOUND                    27     // The drive cannot find the sector requested.
#define ERROR_OUT_OF_PAPER                        28     // The printer is out of paper.
#define ERROR_WRITE_FAULT                         29     // The system cannot write to the specified device.
#define ERROR_READ_FAULT                          30     // The system cannot read from the specified device.
#define ERROR_GEN_FAILURE                         31     // A device attached to the system is not functioning.
#define ERROR_SHARING_VIOLATION                   32     // The process cannot access the file because it is being used by another process.
#define ERROR_LOCK_VIOLATION                      33     // The process cannot access the file because another process has locked a portion of the file.
#define ERROR_WRONG_DISK                          34     // The wrong diskette is in the drive. Insert %2 (Volume Serial Number: %3 ) into drive %1.
#define ERROR_SHARING_BUFFER_EXCEEDED             36     // Too many files opened for sharing.
#define ERROR_HANDLE_EOF                          38     // Reached the end of the file.
#define ERROR_HANDLE_DISK_FULL                    39     // The disk is full.
#define ERROR_NOT_SUPPORTED                       50     // The request is not supported.
#define ERROR_REM_NOT_LIST                        51     // Windows cannot find the network path.
#define ERROR_DUP_NAME                            52     // You were not connected because a duplicate name exists on the network.
#define ERROR_BAD_NETPATH                         53     // The network path was not found.
#define ERROR_NETWORK_BUSY                        54     // The network is busy.
#define ERROR_DEV_NOT_EXIST                       55     // The specified network resource or device is no longer available.
#define ERROR_TOO_MANY_CMDS                       56     // The network BIOS command limit has been reached.
#define ERROR_ADAP_HDW_ERR                        57     // A network adapter hardware error occurred.
#define ERROR_BAD_NET_RESP                        58     // The specified server cannot perform the requested operation.
#define ERROR_UNEXP_NET_ERR                       59     // An unexpected network error occurred.
#define ERROR_BAD_REM_ADAP                        60     // The remote adapter is not compatible.
#define ERROR_PRINTQ_FULL                         61     // The printer queue is full.
#define ERROR_NO_SPOOL_SPACE                      62     // Space to store the file waiting to be printed is not available on the server.
#define ERROR_PRINT_CANCELLED                     63     // Your file waiting to be printed was deleted.
#define ERROR_NETNAME_DELETED                     64     // The specified network name is no longer available.
#define ERROR_NETWORK_ACCESS_DENIED               65     // Network access is denied.
#define ERROR_BAD_DEV_TYPE                        66     // The network resource type is not correct.
#define ERROR_BAD_NET_NAME                        67     // The network name cannot be found.
#define ERROR_TOO_MANY_NAMES                      68     // The name limit for the local computer network adapter card was exceeded.
#define ERROR_TOO_MANY_SESS                       69     // The network BIOS session limit was exceeded.
#define ERROR_SHARING_PAUSED                      70     // The remote server has been paused or is in the process of being started.
#define ERROR_REQ_NOT_ACCEP                       71     // No more connections can be made to this remote computer at this time because there are already as many connections as the computer can accept.
#define ERROR_REDIR_PAUSED                        72     // The specified printer or disk device has been paused.
#define ERROR_FILE_EXISTS                         80     // The file exists.
#define ERROR_CANNOT_MAKE                         82     // The directory or file cannot be created.
#define ERROR_FAIL_I24                            83     // Fail on INT 24.
#define ERROR_OUT_OF_STRUCTURES                   84     // Storage to process this request is not available.
#define ERROR_ALREADY_ASSIGNED                    85     // The local device name is already in use.
#define ERROR_INVALID_PASSWORD                    86     // The specified network password is not correct.
#define ERROR_INVALID_PARAMETER                   87     // The parameter is incorrect (DDE).
#define ERROR_NET_WRITE_FAULT                     88     // A write fault occurred on the network.
#define ERROR_NO_PROC_SLOTS                       89     // The system cannot start another process at this time.
#define ERROR_TOO_MANY_SEMAPHORES                100     // Cannot create another system semaphore.
#define ERROR_EXCL_SEM_ALREADY_OWNED             101     // The exclusive semaphore is owned by another process.
#define ERROR_SEM_IS_SET                         102     // The semaphore is set and cannot be closed.
#define ERROR_TOO_MANY_SEM_REQUESTS              103     // The semaphore cannot be set again.
#define ERROR_INVALID_AT_INTERRUPT_TIME          104     // Cannot request exclusive semaphores at interrupt time.
#define ERROR_SEM_OWNER_DIED                     105     // The previous ownership of this semaphore has ended.
#define ERROR_SEM_USER_LIMIT                     106     // Insert the diskette for drive %1.
#define ERROR_DISK_CHANGE                        107     // The program stopped because an alternate diskette was not inserted.
#define ERROR_DRIVE_LOCKED                       108     // The disk is in use or locked by another process.
#define ERROR_BROKEN_PIPE                        109     // The pipe has been ended.
#define ERROR_OPEN_FAILED                        110     // The system cannot open the device or file specified.
#define ERROR_BUFFER_OVERFLOW                    111     // The file name is too long.
#define ERROR_DISK_FULL                          112     // There is not enough space on the disk.
#define ERROR_NO_MORE_SEARCH_HANDLES             113     // No more internal file identifiers available.
#define ERROR_INVALID_TARGET_HANDLE              114     // The target internal file identifier is incorrect.
#define ERROR_INVALID_CATEGORY                   117     // The IOCTL call made by the application program is not correct.
#define ERROR_INVALID_VERIFY_SWITCH              118     // The verify-on-write switch parameter value is not correct.
#define ERROR_BAD_DRIVER_LEVEL                   119     // The system does not support the command requested.
#define ERROR_CALL_NOT_IMPLEMENTED               120     // This function is not supported on this system.
#define ERROR_SEM_TIMEOUT                        121     // The semaphore timeout period has expired.
#define ERROR_INSUFFICIENT_BUFFER                122     // The data area passed to a system call is too small (DDE).
#define ERROR_INVALID_NAME                       123     // The filename, directory name, or volume label syntax is incorrect (DDE).
#define ERROR_INVALID_LEVEL                      124     // The system call level is not correct.
#define ERROR_NO_VOLUME_LABEL                    125     // The disk has no volume label.
#define ERROR_MOD_NOT_FOUND                      126     // The specified module could not be found.
#define ERROR_PROC_NOT_FOUND                     127     // The specified procedure could not be found.
// ...
#define ERROR_CONTROL_ID_NOT_FOUND              1421     // Control ID not found.
#define ERROR_NOT_A_REPARSE_POINT               4390     // The file or directory is not a reparse point.

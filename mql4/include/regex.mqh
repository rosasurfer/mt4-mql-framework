/**
 *
 */
#import "regex2.dll"

   int  _lclose(int hFile);
   int  _lcreat(string lpPathName, int attributes);
   int  _llseek(int hFile, int offset, int origin);
   int  _lopen(string lpPathName, int accessModes);
   bool GetComputerNameA(string lpBuffer, int lpBufferSize[]);
   int  GetCurrentProcess();

#import


// Pattern syntax flags, siehe "experts/include/header/regex.h"
#define RE_BACKSLASH_ESCAPE_IN_LISTS   0x00000001
#define RE_BK_PLUS_QM                  0x00000002
#define RE_CHAR_CLASSES                0x00000004
#define RE_CONTEXT_INDEP_ANCHORS       0x00000008
#define RE_CONTEXT_INDEP_OPS           0x00000010
#define RE_CONTEXT_INVALID_OPS         0x00000020
#define RE_DOT_NEWLINE                 0x00000040
#define RE_DOT_NOT_NULL                0x00000080
#define RE_HAT_LISTS_NOT_NEWLINE       0x00000100
#define RE_INTERVALS                   0x00000200
#define RE_LIMITED_OPS                 0x00000400
#define RE_NEWLINE_ALT                 0x00000800
#define RE_NO_BK_BRACES                0x00001000
#define RE_NO_BK_PARENS                0x00002000
#define RE_NO_BK_REFS                  0x00004000
#define RE_NO_BK_VBAR                  0x00008000
#define RE_NO_EMPTY_RANGES             0x00010000
#define RE_UNMATCHED_RIGHT_PAREN_ORD   0x00020000
#define RE_NO_POSIX_BACKTRACKING       0x00040000
#define RE_NO_GNU_OPS                  0x00080000
#define RE_DEBUG                       0x00100000
#define RE_INVALID_INTERVAL_ORD        0x00200000
#define RE_ICASE                       0x00400000
#define RE_CARET_ANCHORS_HERE          0x00800000
#define RE_CONTEXT_INVALID_DUP         0x01000000
#define RE_NO_SUB                      0x02000000

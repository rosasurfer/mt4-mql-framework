/**
 * Es gilt:
 *
 *  STRUCT.intSize    = ceil(STRUCT.size/4)           // sizeof(int)    = 4
 *  STRUCT.doubleSize = ceil(STRUCT.size/8)           // sizeof(double) = 8
 */

// MT4 structs
#define FXT_HEADER.size                 728
#define FXT_HEADER.intSize              182

#define FXT_TICK.size                    52
#define FXT_TICK.intSize                 13

#define HISTORY_HEADER.size             148
#define HISTORY_HEADER.intSize           37

#define HISTORY_BAR_400.size             44
#define HISTORY_BAR_400.intSize          11

#define HISTORY_BAR_401.size             60
#define HISTORY_BAR_401.intSize          15

#define SYMBOL.size                    1936
#define SYMBOL.intSize                  484

#define SYMBOL_GROUP.size                80
#define SYMBOL_GROUP.intSize             20

#define SYMBOL_SELECTED.size            128
#define SYMBOL_SELECTED.intSize          32

#define TICK.size                        40
#define TICK.intSize                     10


// XTrade structs
#define BAR.size                         48
#define BAR.doubleSize                    6

#define EXECUTION_CONTEXT.size          880
#define EXECUTION_CONTEXT.intSize       220

#define LFX_ORDER.size                  120
#define LFX_ORDER.intSize                30

#define ORDER_EXECUTION.size            136
#define ORDER_EXECUTION.intSize          34


// Win32 structs
#define FILETIME.size                     8
#define FILETIME.intSize                  2

#define PROCESS_INFORMATION.size         16
#define PROCESS_INFORMATION.intSize       4

#define SECURITY_ATTRIBUTES.size         12
#define SECURITY_ATTRIBUTES.intSize       3

#define STARTUPINFO.size                 68
#define STARTUPINFO.intSize              17

#define SYSTEMTIME.size                  16
#define SYSTEMTIME.intSize                4

#define TIME_ZONE_INFORMATION.size      172
#define TIME_ZONE_INFORMATION.intSize    43

#define WIN32_FIND_DATA.size            318              // Ende liegt nicht an einem Integer-Boundary
#define WIN32_FIND_DATA.intSize          80

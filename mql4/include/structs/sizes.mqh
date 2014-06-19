/**
 * Es gilt:
 *
 *  STRUCT.intSize    = ceil(STRUCT.size / 4)         // sizeof(int)    = 4
 *  STRUCT.doubleSize = ceil(STRUCT.size / 8)         // sizeof(double) = 8
 */

// Win32 structs
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

#define WIN32_FIND_DATA.size            318
#define WIN32_FIND_DATA.intSize          80


// MT4 structs
#define HISTORY_HEADER.size             148
#define HISTORY_HEADER.intSize           37

#define RATE_INFO.size                   44
#define RATE_INFO.intSize                11

#define SUBSCRIBED_SYMBOL.size          128
#define SUBSCRIBED_SYMBOL.intSize        32

#define SYMBOL_GROUP.size                80
#define SYMBOL_GROUP.intSize             20

#define TICK.size                        40
#define TICK.intSize                     10


// pewa: selbst definierte Structs
#define BAR.size                         48
#define BAR.doubleSize                    6

#define EXECUTION_CONTEXT.size           48
#define EXECUTION_CONTEXT.intSize        12

#define LFX_ORDER.size                  100
#define LFX_ORDER.intSize                25

#define ORDER_EXECUTION.size            136
#define ORDER_EXECUTION.intSize          34

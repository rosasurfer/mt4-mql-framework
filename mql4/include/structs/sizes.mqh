// MQL structs
#define EXECUTION_CONTEXT.size         48
#define EXECUTION_CONTEXT.intSize      12    // ceil(EXECUTION_CONTEXT.size/4)

#define LFX_ORDER.size                 100
#define LFX_ORDER.intSize              25    // ceil(LFX_ORDER.size/4)

#define ORDER_EXECUTION.size           136
#define ORDER_EXECUTION.intSize        34    // ceil(ORDER_EXECUTION.size/4)


// MT4 structs
#define BAR.size                       44
#define BAR.intSize                    11    // ceil(BAR.size/4)

#define HISTORY_HEADER.size            148
#define HISTORY_HEADER.intSize         37    // ceil(HISTORY_HEADER.size/4)

#define SUBSCRIBED_SYMBOL.size         128
#define SUBSCRIBED_SYMBOL.intSize      32    // ceil(SUBSCRIBED_SYMBOL.size/4)

#define SYMBOL_GROUP.size              80
#define SYMBOL_GROUP.intSize           20    // ceil(SYMBOL_GROUP.size/4)

#define TICK.size                      40
#define TICK.intSize                   10    // ceil(TICK.size/4)


// WIN32 structs
#define PROCESS_INFORMATION.size       16
#define SECURITY_ATTRIBUTES.size       12
#define STARTUPINFO.size               68
#define SYSTEMTIME.size                16
#define TIME_ZONE_INFORMATION.size     172
#define WIN32_FIND_DATA.size           318

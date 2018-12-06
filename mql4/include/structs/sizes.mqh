/**
 * STRUCT.intSize    = ceil(sizeof(STRUCT)/sizeof(int))    => 4
 * STRUCT.doubleSize = ceil(sizeof(STRUCT)/sizeof(double)) => 8
 */

// MT4 structs
#define FXT_HEADER.size                    728
#define FXT_HEADER.intSize                 182

#define FXT_TICK.size                       52
#define FXT_TICK.intSize                    13

#define HISTORY_HEADER.size                148
#define HISTORY_HEADER.intSize              37

#define PRICE_BAR_400.size                  44
#define PRICE_BAR_400.intSize               11

#define PRICE_BAR_401.size                  60
#define PRICE_BAR_401.intSize               15

#define SYMBOL.size                       1936
#define SYMBOL.intSize                     484

#define SYMBOL_GROUP.size                   80
#define SYMBOL_GROUP.intSize                20

#define SYMBOL_SELECTED.size               128
#define SYMBOL_SELECTED.intSize             32

#define TICK.size                           40
#define TICK.intSize                        10


// XTrade structs
#define BAR.size                            48
#define BAR.doubleSize                       6

#define EXECUTION_CONTEXT.size            1004
#define EXECUTION_CONTEXT.intSize          251     // The following EXECUTION_CONTEXT offsets must always be updated, too.

#define I_EC.pid                             0
#define I_EC.previousPid                     1
#define I_EC.programType                     2
#define I_EC.programCoreFunction            67
#define I_EC.programInitReason              68
#define I_EC.programUninitReason            69
#define I_EC.programInitFlags               70
#define I_EC.programDeinitFlags             71
#define I_EC.moduleType                     72
#define I_EC.moduleCoreFunction            137
#define I_EC.moduleUninitReason            138
#define I_EC.moduleInitFlags               139
#define I_EC.moduleDeinitFlags             140
#define I_EC.timeframe                     144
#define I_EC.rates                         145
#define I_EC.bars                          146
#define I_EC.changedBars                   147
#define I_EC.unchangedBars                 148
#define I_EC.ticks                         149
#define I_EC.cycleTicks                    150
#define I_EC.lastTickTime                  151
#define I_EC.prevTickTime                  152
#define I_EC.digits                        158
#define I_EC.pipDigits                     159
#define I_EC.subPipDigits                  160
#define I_EC.pipPoints                     166
#define I_EC.superContext                  170
#define I_EC.threadId                      171
#define I_EC.hChart                        172
#define I_EC.hChartWindow                  173
#define I_EC.test                          174
#define I_EC.testing                       175
#define I_EC.visualMode                    176
#define I_EC.optimization                  177
#define I_EC.extReporting                  178
#define I_EC.recordEquity                  179
#define I_EC.mqlError                      180
#define I_EC.dllError                      181
#define I_EC.dllWarning                    183
#define I_EC.logging                       185

#define LFX_ORDER.size                     120
#define LFX_ORDER.intSize                   30

#define ORDER_EXECUTION.size               136
#define ORDER_EXECUTION.intSize             34


// Win32 structs
#define FILETIME.size                        8
#define FILETIME.intSize                     2

#define PROCESS_INFORMATION.size            16
#define PROCESS_INFORMATION.intSize          4

#define SECURITY_ATTRIBUTES.size            12
#define SECURITY_ATTRIBUTES.intSize          3

#define STARTUPINFO.size                    68
#define STARTUPINFO.intSize                 17

#define SYSTEMTIME.size                     16
#define SYSTEMTIME.intSize                   4

#define TIME_ZONE_INFORMATION.size         172
#define TIME_ZONE_INFORMATION.intSize       43

#define WIN32_FIND_DATA.size               318     // doesn't end on an int boundary
#define WIN32_FIND_DATA.intSize             80

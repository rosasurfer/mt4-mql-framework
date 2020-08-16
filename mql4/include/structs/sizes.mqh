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

#define HISTORY_BAR_400.size                44
#define HISTORY_BAR_400.intSize             11

#define HISTORY_BAR_401.size                60
#define HISTORY_BAR_401.intSize             15

#define SYMBOL.size                       1936
#define SYMBOL.intSize                     484

#define SYMBOL_GROUP.size                   80
#define SYMBOL_GROUP.intSize                20

#define SYMBOL_SELECTED.size               128
#define SYMBOL_SELECTED.intSize             32

#define TICK.size                           40
#define TICK.intSize                        10


// Framework structs
#define BAR.size                            48
#define BAR.doubleSize                       6

#define EXECUTION_CONTEXT.size            1036
#define EXECUTION_CONTEXT.intSize          259

#define EC.pid                               0     // All offsets must be in sync with the MT4Expander.
#define EC.previousPid                       1
#define EC.programType                       2
#define EC.programCoreFunction              67
#define EC.programInitReason                68
#define EC.programUninitReason              69
#define EC.programInitFlags                 70
#define EC.programDeinitFlags               71
#define EC.moduleType                       72
#define EC.moduleCoreFunction              137
#define EC.moduleUninitReason              138
#define EC.moduleInitFlags                 139
#define EC.moduleDeinitFlags               140
#define EC.timeframe                       144
#define EC.rates                           149
#define EC.bars                            150
#define EC.changedBars                     151
#define EC.unchangedBars                   152
#define EC.ticks                           153
#define EC.cycleTicks                      154
#define EC.prevTickTime                    155
#define EC.currTickTime                    156
#define EC.digits                          162
#define EC.pipDigits                       163
#define EC.subPipDigits                    164
#define EC.pipPoints                       170
#define EC.superContext                    174
#define EC.threadId                        175
#define EC.hChart                          176
#define EC.hChartWindow                    177
#define EC.test                            178
#define EC.testing                         179
#define EC.visualMode                      180
#define EC.optimization                    181
#define EC.extReporting                    182
#define EC.recordEquity                    183
#define EC.mqlError                        184
#define EC.dllError                        185
#define EC.dllWarning                      187
#define EC.logEnabled                      189
#define EC.logToDebugEnabled               190
#define EC.logToTerminalEnabled            191
#define EC.logToCustomEnabled              192




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

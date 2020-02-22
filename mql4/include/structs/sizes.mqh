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

#define EXECUTION_CONTEXT.size            1020
#define EXECUTION_CONTEXT.intSize          255

#define EC.pid                               0     // The following EXECUTION_CONTEXT offsets must be in sync with the Expander.
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
#define EC.rates                           145
#define EC.bars                            146
#define EC.changedBars                     147
#define EC.unchangedBars                   148
#define EC.ticks                           149
#define EC.cycleTicks                      150
#define EC.lastTickTime                    151
#define EC.prevTickTime                    152
#define EC.digits                          158
#define EC.pipDigits                       159
#define EC.subPipDigits                    160
#define EC.pipPoints                       166
#define EC.superContext                    170
#define EC.threadId                        171
#define EC.hChart                          172
#define EC.hChartWindow                    173
#define EC.test                            174
#define EC.testing                         175
#define EC.visualMode                      176
#define EC.optimization                    177
#define EC.extReporting                    178
#define EC.recordEquity                    179
#define EC.mqlError                        180
#define EC.dllError                        181
#define EC.dllWarning                      183
#define EC.logEnabled                      185
#define EC.logToDebugEnabled               186
#define EC.logToTerminalEnabled            187
#define EC.logToCustomEnabled              188

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

/**
 * STRUCT_intSize    = ceil(sizeof(STRUCT)/sizeof(int))    => 4
 * STRUCT_doubleSize = ceil(sizeof(STRUCT)/sizeof(double)) => 8
 */

// MT4 structs
#define FXT_HEADER_size                    728
#define FXT_HEADER_intSize                 182

#define FXT_TICK_size                       52
#define FXT_TICK_intSize                    13

#define HISTORY_HEADER_size                148
#define HISTORY_HEADER_intSize              37

#define HISTORY_BAR_400_size                44
#define HISTORY_BAR_400_intSize             11

#define HISTORY_BAR_401_size                60
#define HISTORY_BAR_401_intSize             15

#define SYMBOL_size                       1936
#define SYMBOL_intSize                     484

#define SYMBOL_GROUP_size                   80
#define SYMBOL_GROUP_intSize                20

#define SYMBOL_SELECTED_size               128
#define SYMBOL_SELECTED_intSize             32

#define TICK_size                           40
#define TICK_intSize                        10


// Framework structs
#define BAR_size                            48
#define BAR_doubleSize                       6

#define EXECUTION_CONTEXT_size            1040
#define EXECUTION_CONTEXT_intSize          260

#define EC.pid                               0     // All offsets must be in sync with the MT4Expander.
#define EC.previousPid                       1
#define EC.started                           2
#define EC.programType                       3
#define EC.programCoreFunction              68
#define EC.programInitReason                69
#define EC.programUninitReason              70
#define EC.programInitFlags                 71
#define EC.programDeinitFlags               72
#define EC.moduleType                       73
#define EC.moduleCoreFunction              138
#define EC.moduleUninitReason              139
#define EC.moduleInitFlags                 140
#define EC.moduleDeinitFlags               141
#define EC.timeframe                       145
#define EC.rates                           150
#define EC.bars                            151
#define EC.validBars                       152
#define EC.changedBars                     153
#define EC.ticks                           154
#define EC.cycleTicks                      155
#define EC.currTickTime                    156
#define EC.prevTickTime                    157
#define EC.digits                          162
#define EC.pipDigits                       163
#define EC.pipPoints                       168
#define EC.superContext                    171
#define EC.threadId                        172
#define EC.hChart                          173
#define EC.hChartWindow                    174
#define EC.recordMode                      175
#define EC.test                            176
#define EC.testing                         177
#define EC.visualMode                      178
#define EC.optimization                    179
#define EC.externalReporting               180
#define EC.mqlError                        181
#define EC.dllError                        182
#define EC.dllWarning                      184
#define EC.loglevel                        186
#define EC.loglevelTerminal                187
#define EC.loglevelAlert                   188
#define EC.loglevelDebugger                189
#define EC.loglevelFile                    190
#define EC.loglevelMail                    191
#define EC.loglevelSMS                     192

#define LFX_ORDER_size                     120
#define LFX_ORDER_intSize                   30

#define ORDER_EXECUTION_size               136
#define ORDER_EXECUTION_intSize             34


// Win32 structs
#define PROCESS_INFORMATION_size            16
#define PROCESS_INFORMATION_intSize          4

#define SECURITY_ATTRIBUTES_size            12
#define SECURITY_ATTRIBUTES_intSize          3

#define STARTUPINFO_size                    68
#define STARTUPINFO_intSize                 17

#define SYSTEMTIME_size                     16
#define SYSTEMTIME_intSize                   4

#define TIME_ZONE_INFORMATION_size         172
#define TIME_ZONE_INFORMATION_intSize       43

#define WIN32_FIND_DATA_size               318     // doesn't end on an int boundary
#define WIN32_FIND_DATA_intSize             80

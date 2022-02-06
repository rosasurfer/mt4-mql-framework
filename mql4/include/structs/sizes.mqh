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

#define EXECUTION_CONTEXT_size            1052
#define EXECUTION_CONTEXT_intSize          263

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
#define EC.changedBars                     152
#define EC.unchangedBars                   153
#define EC.ticks                           154
#define EC.cycleTicks                      155
#define EC.prevTickTime                    156
#define EC.currTickTime                    157
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
#define EC.eaExternalReporting             182
#define EC.eaRecordEquity                  183
#define EC.mqlError                        184
#define EC.dllError                        185
#define EC.dllWarning                      187
#define EC.loglevel                        189
#define EC.loglevelTerminal                190
#define EC.loglevelAlert                   191
#define EC.loglevelDebugger                192
#define EC.loglevelFile                    193
#define EC.loglevelMail                    194
#define EC.loglevelSMS                     195

#define LFX_ORDER_size                     120
#define LFX_ORDER_intSize                   30

#define ORDER_EXECUTION_size               136
#define ORDER_EXECUTION_intSize             34


// Win32 structs
#define FILETIME_size                        8
#define FILETIME_intSize                     2

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

/**
 * Win32 struct PROCESS_INFORMATION
 *
 * struct PROCESS_INFORMATION {
 *    HANDLE hProcess;              //  4
 *    HANDLE hThread;               //  4
 *    DWORD  dwProcessId;           //  4
 *    DWORD  dwThreadId;            //  4
 * };                               // 16 byte
 */
#import "rsfMT4Expander.dll"
   int pi_hProcess (/*PROCESS_INFORMATION*/int pi[]);
   int pi_hThread  (/*PROCESS_INFORMATION*/int pi[]);
   int pi_ProcessId(/*PROCESS_INFORMATION*/int pi[]);
   int pi_ThreadId (/*PROCESS_INFORMATION*/int pi[]);
#import

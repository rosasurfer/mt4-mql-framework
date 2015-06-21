/**
 * Win32 structure PROCESS_INFORMATION
 *
 *
 * struct PROCESS_INFORMATION {
 *    HANDLE hProcess;           //  4
 *    HANDLE hThread;            //  4
 *    DWORD  dwProcessId;        //  4
 *    DWORD  dwThreadId;         //  4
 * } pi;                         // 16 byte = int[4]
 */
int pi.hProcess (/*PROCESS_INFORMATION*/int pi[]) { return(pi[0]); }
int pi.hThread  (/*PROCESS_INFORMATION*/int pi[]) { return(pi[1]); }
int pi.ProcessId(/*PROCESS_INFORMATION*/int pi[]) { return(pi[2]); }
int pi.ThreadId (/*PROCESS_INFORMATION*/int pi[]) { return(pi[3]); }


#import "Expander.dll"
   int pi_hProcess (/*PROCESS_INFORMATION*/int pi[]);
   int pi_hThread  (/*PROCESS_INFORMATION*/int pi[]);
   int pi_ProcessId(/*PROCESS_INFORMATION*/int pi[]);
   int pi_ThreadId (/*PROCESS_INFORMATION*/int pi[]);
#import

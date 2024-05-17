/**
 * Struct EXECUTION_CONTEXT
 *
 * A storage context for runtime variables, data exchange and communication between MQL modules and MT4Expander DLL.
 *
 *  @see  https://github.com/rosasurfer/mt4-expander/blob/master/header/struct/rsf/ExecutionContext.h
 *
 *
 * TODO: integrate __STATUS_OFF, __STATUS_OFF.reason
 */
#import "rsfMT4Expander.dll"

   // available MQL getters
   string ec_ProgramName          (int ec[]);
   string ec_SuperProgramName     (int pid);
   int    ec_SuperLoglevel        (int pid);
   int    ec_SuperLoglevelDebug   (int pid);
   int    ec_SuperLoglevelTerminal(int pid);
   int    ec_SuperLoglevelAlert   (int pid);
   int    ec_SuperLoglevelFile    (int pid);
   int    ec_SuperLoglevelMail    (int pid);
   int    ec_SuperLoglevelSMS     (int pid);

   // available MQL setters
   int    ec_SetProgramCoreFunction(int ec[], int id);
   int    ec_SetRecorder           (int ec[], int mode);
   string ec_SetAccountServer      (int ec[], string server);
   int    ec_SetDllError           (int ec[], int error);
   int    ec_SetMqlError           (int ec[], int error);
   int    ec_SetLoglevel           (int ec[], int level);
   int    ec_SetLoglevelDebug      (int ec[], int level);
   int    ec_SetLoglevelTerminal   (int ec[], int level);
   int    ec_SetLoglevelAlert      (int ec[], int level);
   int    ec_SetLoglevelFile       (int ec[], int level);
   int    ec_SetLoglevelMail       (int ec[], int level);
   int    ec_SetLoglevelSMS        (int ec[], int level);

   // helpers
   string EXECUTION_CONTEXT_toStr  (int ec[]);
   string lpEXECUTION_CONTEXT_toStr(int lpEc);
#import

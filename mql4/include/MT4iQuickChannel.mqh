/**
 * MT4i QuickChannel
 *
 *  - Je Channel kann es mehrere Sender, jedoch max. einen Receiver geben.
 *  - QuickChannel benachrichtigt den Receiver per Windows-Message (z.B. Tick ans Chartfenster) über neue Messages.
 *  - Der Receiver kann diese Messages aus dem Channel abholen.
 *  - Da in MQL nicht zwischen regulären und QuickChannel-Ticks unterschieden werden kann, muß bei jedem Tick zusätzlich
 *    geprüft werden, ob neue Messages eingetroffen sind.
 *
 *
 * TODO: - Prüfen, ob der QuickChannel-Tick die start()-Funktion auch in Offline- und Online-Charts ohne Connection triggert.
 *       - Prüfen, ob der QuickChannel-Tick die start()-Funktion sowohl für Indikatoren als auch für EA's triggert.
 *
 *
 * API as of version 4.0.0
 */
#import "MT4iQuickChannel.dll"

   int  QC_StartSender  (string lpChannelName);                              int QC_StartSenderW(string lpChannelName);
   int  QC_SendMessage  (int hChannel, string lpMessage, int flags);         int QC_SendMessageW(int hChannel, string lpMessage, int flags);
   bool QC_ReleaseSender(int hChannel);

   int  QC_StartReceiver  (string lpChannelName, int hWndChart);             int QC_StartReceiverW(string lpChannelName, int hWndChart);
   int  QC_GetMessages2   (int hChannel, string lpFileName);                 int QC_GetMessages2W (int hChannel, string lpFileName);
   int  QC_GetMessages3   (int hChannel, string lpBuffer[], int bufferSize); int QC_GetMessages5W (int hChannel, int lpBuffer[], int bufferSize);
   bool QC_ReleaseReceiver(int hChannel);

   int  QC_CheckChannel      (string lpChannelName);
   int  QC_ChannelHasReceiver(string lpChannelName);


   /*
   undocumented:
   -------------
   int  timerId = SetupTimedTicks(int hWnd, int millis);             // Fehlerhaft: Der Parameter 'millis' muß durch 1.56 geteilt werden, die Ticks funktionieren
   bool success = RemoveTimedTicks(int timerId);                     //             nicht in Offline-Charts.
                                                                     // stattdessen MT4Expander::SetupTickTimer() und MT4Expander::ReleaseTickTimer() verwenden
   CreateHelper2();
   RemoveHelper();

   QC_GetMessages();
   QC_GetMessages4();                                                BSTR QC_GetMessages4(int hChannel);
   QC_ClearMessages();

   QC_StartSendInternetMessages();
   QC_SendInternetMessage();
   QC_EndSendInternetMessages();

   QC_StartReceiveInternetMessages();
   QC_QueryInternetMessages();
   QC_EndReceiveInternetMessages();

   QC_IsInternetSendSessionTerminated();
   QC_IsInternetReceiverActive();

   QC_GetLastInternetSendError();
   QC_GetLastInternetReceiveError();

   QC_FreeString();

   TimeUTC();
   */
#import


// QuickChannel-Konstanten
#define QC_CHECK_CHANNEL_ERROR           -2
#define QC_CHECK_CHANNEL_NONE            -1
#define QC_CHECK_CHANNEL_EMPTY            0

#define QC_CHECK_RECEIVER_NONE            0
#define QC_CHECK_RECEIVER_OK              1

#define QC_FLAG_SEND_MSG_REPLACE          1
#define QC_FLAG_SEND_MSG_IF_RECEIVER      2

#define QC_SEND_MSG_ADDED                 1
#define QC_SEND_MSG_IGNORED              -1        // nur möglich bei gesetztem QC_FLAG_SEND_MSG_IF_RECEIVER
#define QC_SEND_MSG_ERROR                 0

#define QC_GET_MSG2_SUCCESS               0
#define QC_GET_MSG2_CHANNEL_EMPTY         1
#define QC_GET_MSG2_FS_ERROR              2
#define QC_GET_MSG2_IO_ERROR              3

#define QC_GET_MSG3_SUCCESS               0
#define QC_GET_MSG3_CHANNEL_EMPTY         1
#define QC_GET_MSG3_INSUF_BUFFER          2

#define QC_GET_MSG5W_ERROR               -1

#define QC_MAX_BUFFER_SIZE            65532        // 64KB - 4 bytes

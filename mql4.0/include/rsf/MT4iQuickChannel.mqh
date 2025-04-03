/**
 * MT4i QuickChannel API v4.0.0
 *
 *
 *  - A channel may have multiple senders but only one receiver.
 *  - On new messages the receiver is notified via Windows message (e.g. a virtual tick message to a chart window).
 *  - The receiver collects messages by polling the channel.
 *  - The receiver cannot distinguish between virtual ticks sent by QuickChannel and regular ticks. So he has to poll the
 *    channel for new messages on every tick.
 *
 *
 * TODO:
 *  - Test whether QuickChannel ticks work in offline charts and without server connection.
 *  - Test whether QuickChannel ticks trigger EA::start().
 */
#import "MT4iQuickChannel.dll"

   int  QC_StartSenderA(string channelName);
   int  QC_StartSenderW(string channelName);

   int  QC_StartReceiverA(string channelName, int hWndChart);
   int  QC_StartReceiverW(string channelName, int hWndChart);

   int  QC_SendMessageA(int hChannel, string message, int flags);
   int  QC_SendMessageW(int hChannel, string message, int flags);

   int  QC_GetMessages2A(int hChannel, string fileName);
   int  QC_GetMessages2W(int hChannel, string fileName);

   int  QC_GetMessages3A(int hChannel, string buffer[], int bufferSize);
   int  QC_GetMessages5W(int hChannel, int    buffer[], int bufferSize);

   bool QC_ReleaseSender(int hChannel);
   bool QC_ReleaseReceiver(int hChannel);

   int  QC_CheckChannelA(string channelName);
   int  QC_CheckChannelW(string channelName);

   int  QC_ChannelHasReceiverA(string channelName);
   int  QC_ChannelHasReceiverW(string channelName);

   /*
   undocumented:
   -------------
   CreateHelper2();
   RemoveHelper();

   QC_GetMessages();
   QC_GetMessages4();
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
   */
#import


// constants
#define QC_CHECK_CHANNEL_ERROR           -2
#define QC_CHECK_CHANNEL_NONE            -1
#define QC_CHECK_CHANNEL_EMPTY            0

#define QC_CHECK_RECEIVER_NONE            0
#define QC_CHECK_RECEIVER_OK              1

#define QC_FLAG_SEND_MSG_REPLACE          1
#define QC_FLAG_SEND_MSG_IF_RECEIVER      2

#define QC_SEND_MSG_ADDED                 1
#define QC_SEND_MSG_IGNORED              -1        // only with flag QC_FLAG_SEND_MSG_IF_RECEIVER
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

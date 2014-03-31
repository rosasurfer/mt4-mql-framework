/**
 *
 */
#import "MT4iQuickChannel.dll"

   int QC_StartSender  (string lpChannelName);
   int QC_SendMessage  (int hChannel, string lpMessage, int flags);
   int QC_ReleaseSender(int hChannel);

   int QC_StartReceiver  (string lpChannelName, int hWndChart);
   int QC_GetMessages2   (int hChannel, string lpFileName);
   int QC_GetMessages3   (int hChannel, string lpBuffer, int bufferSize);
   int QC_ReleaseReceiver(int hChannel);

   int QC_CheckChannel      (string lpChannelName);
   int QC_ChannelHasReceiver(string lpChannelName);

#import

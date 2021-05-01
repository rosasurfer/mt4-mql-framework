/**
 * Win32 struct TIME_ZONE_INFORMATION
 *
 * struct TIME_ZONE_INFORMATION {
 *    LONG       Bias;                 //   4         in Minuten
 *    WCHAR      StandardName[32];     //  64         z.B. "G…T…B… …N…o…r…m…a…l…z…e…i…t", <NUL><NUL>-terminiert
 *    SYSTEMTIME StandardDate;         //  16
 *    LONG       StandardBias;         //   4         in Minuten
 *    WCHAR      DaylightName[32];     //  64         z.B. "G…T…B… …S…o…m…m…e…r…z…e…i…t", <NUL><NUL>-terminiert
 *    SYSTEMTIME DaylightDate;         //  16
 *    LONG       DaylightBias;         //   4         in Minuten
 * };                                  // 172 byte
 *
 *
 * Es gelten folgende Formeln:
 * ---------------------------
 *  Bias             = -Offset
 *  LocalTime + Bias = GMT
 *  GMT + Offset     = LocalTime
 */
#import "rsfMT4Expander.dll"
   int    tzi_Bias        (/*TIME_ZONE_INFORMATION*/int tzi[]);
   string tzi_StandardName(/*TIME_ZONE_INFORMATION*/int tzi[]);
   void   tzi_StandardDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]);
   int    tzi_StandardBias(/*TIME_ZONE_INFORMATION*/int tzi[]);
   string tzi_DaylightName(/*TIME_ZONE_INFORMATION*/int tzi[]);
   void   tzi_DaylightDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]);
   int    tzi_DaylightBias(/*TIME_ZONE_INFORMATION*/int tzi[]);
#import

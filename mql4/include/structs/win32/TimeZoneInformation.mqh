/**
 * Win32 structure TIME_ZONE_INFORMATION
 *
 *
 * struct TIME_ZONE_INFORMATION {
 *    LONG       Bias;                    //   4     => tzi[ 0]         in Minuten
 *    WCHAR      StandardName[32];        //  64     => tzi[ 1]         z.B. "G…T…B… …N…o…r…m…a…l…z…e…i…t"
 *    SYSTEMTIME StandardDate;            //  16     => tzi[17]
 *    LONG       StandardBias;            //   4     => tzi[21]
 *    WCHAR      DaylightName[32];        //  64     => tzi[22]         z.B. "G…T…B… …S…o…m…m…e…r…z…e…i…t"
 *    SYSTEMTIME DaylightDate;            //  16     => tzi[38]
 *    LONG       DaylightBias;            //   4     => tzi[42]
 * } tzi;                                 // 172 byte = int[43]
 *
 *
 * Es gelten folgende Formeln:
 * ---------------------------
 *  Bias             = -Offset
 *  LocalTime + Bias = GMT
 *  GMT + Offset     = LocalTime
 */
int    tzi.Bias        (/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[0]); }                          // in Minuten
string tzi.StandardName(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(BufferWCharsToStr(tzi, 1, 16)); }
void   tzi.StandardDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]) { ArrayCopy(st, tzi, 0, 17, 4); }
int    tzi.StandardBias(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[21]); }                         // in Minuten
string tzi.DaylightName(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(BufferWCharsToStr(tzi, 22, 16)); }
void   tzi.DaylightDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]) { ArrayCopy(st, tzi, 0, 38, 4); }
int    tzi.DaylightBias(/*TIME_ZONE_INFORMATION*/int tzi[])                         { return(tzi[42]); }                         // in Minuten


#import "Expander.dll"
   int    tzi_Bias        (/*TIME_ZONE_INFORMATION*/int tzi[]);
   string tzi_StandardName(/*TIME_ZONE_INFORMATION*/int tzi[]);
   void   tzi_StandardDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]);
   int    tzi_StandardBias(/*TIME_ZONE_INFORMATION*/int tzi[]);
   string tzi_DaylightName(/*TIME_ZONE_INFORMATION*/int tzi[]);
   void   tzi_DaylightDate(/*TIME_ZONE_INFORMATION*/int tzi[], /*SYSTEMTIME*/int st[]);
   int    tzi_DaylightBias(/*TIME_ZONE_INFORMATION*/int tzi[]);
#import

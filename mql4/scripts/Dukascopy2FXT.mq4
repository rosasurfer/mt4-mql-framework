/*
    Copyright (C) 2009-2011 Cristi Dumitrescu <birt@eareview.net>

    version 2011.09.11
*/
#property copyright "birt"
#property link      "http://eareview.net/"
#property show_inputs

#define FILE_ATTRIBUTE_READONLY 1

#import "kernel32.dll"
   int  SetFileAttributesA(string file, int attributes);
#import

#include <FXTHeader.mqh>

extern string CsvFile        = "";
extern bool   CreateHst      = true;
extern double Spread         = 0;                     // Spreads & commissions are in pips regardless of the number of digits.
extern string StartDate      = "";                    // Use YYYY.MM.DD as start and end date format.
extern string EndDate        = "";                    // Leave empty to process the whole CSV file.
extern string __1___________ = "The real spread will only work if you enable the patch option.";
extern bool   UseRealSpread  = false;
extern double SpreadPadding  = 0;
extern double PipsCommission = 0;
extern int    Leverage       = 100;
extern string __2___________ = "Specify the target GMT Offset.";
extern int    GMTOffset      = 0;
extern string __3___________ = "0-no DST, 1-US DST, 2-Europe DST";
extern int    DST            = 0;

//extern string VolumeInfo1="Only enable this if you actually need it.";   // not extern anymore because mostly nobody needs it
bool     UseRealVolume = false;

string   ExtDelimiter = ",";

int      ExtPeriods[9] = { 1, 5, 15, 30, 60, 240, 1440, 10080, 43200 };
int      ExtPeriodCount = 9;
int      ExtPeriodSeconds[9];
int      ExtHstHandle[9];

datetime start_date=0;
datetime end_date=0;

int      ExtTicks;
int      ExtBars[9];
int      ExtCsvHandle=-1;
int      ExtHandle=-1;
string   ExtFileName;
datetime ExtLastTime;
datetime ExtLastBarTime[9];
double   ExtLastOpen   [9];
double   ExtLastLow    [9];
double   ExtLastHigh   [9];
double   ExtLastClose  [9];
double   ExtLastVolume [9];
double   ExtSpread;

int      ExtPeriodId = 0;

int      ExtStartTick = 0;
int      ExtEndTick   = 0;
int      ExtLastYear  = 0;


/**
 *
 */
int start() {
   for (int try=0; try<5; try++) {
      if (IsConnected()) break;
      else               Sleep(3000);
   }
   if (!IsConnected()) { Alert("This script requires a connection to the broker."); return; }

   if (Digits%2 == 1) { Spread *= 10;                         SpreadPadding *= 10;                                }
   else               { Spread  = NormalizeDouble(Spread, 0); SpreadPadding  = NormalizeDouble(SpreadPadding, 0); }

   if (UseRealSpread)            UseRealVolume = false;
   if (CsvFile == "")            CsvFile       = StringSubstr(Symbol(), 0, 6) + ".csv";
   if (StringLen(StartDate) > 0) start_date    = StrToTime(StartDate);
   if (StringLen(EndDate  ) > 0) end_date      = StrToTime(EndDate);

   datetime cur_time, cur_open;
   double   tick_price;
   double   tick_volume;
   int      delimiter=';';

   ExtTicks    = 0;
   ExtLastTime = 0;

   // open input csv-file
   if (StringLen(ExtDelimiter) > 0) delimiter = StringGetChar(ExtDelimiter, 0);
   if      (delimiter == ' ' ) delimiter = ';';
   else if (delimiter == '\\') delimiter = '\t';

   ExtCsvHandle = FileOpen(CsvFile, FILE_CSV|FILE_READ, delimiter);
   if (ExtCsvHandle < 0) { Alert("Can\'t open input file"); return(-1); }

   // open output fxt-file
   ExtFileName = Symbol() + Period() +"_0.fxt";
   ExtHandle   = FileOpen(ExtFileName, FILE_BIN|FILE_WRITE);
   if (ExtHandle < 0) return(-1);

   for (int i=0; i < ExtPeriodCount; i++) {
      ExtPeriodSeconds[i] = ExtPeriods[i] * 60;
      ExtBars         [i] = 0;
      ExtLastBarTime  [i] = 0;
      if (Period() == ExtPeriods[i])
         ExtPeriodId = i;
   }
   if (Digits%2 == 1) PipsCommission *= 10;
   WriteHeader(ExtHandle, Symbol(), Period(), 0, Spread, PipsCommission, Leverage);

   // open hst-files and write it's header
   if (CreateHst) WriteHstHeaders();

   // csv read loop
   while (!IsStopped()) {
      // if end of file reached exit from loop
      if (!ReadNextTick(cur_time, tick_price, tick_volume)) break;
      if (TimeYear(cur_time) != ExtLastYear) {
         ExtLastYear = TimeYear(cur_time);
         Print("Starting to process "+ Symbol() +" "+ ExtLastYear +".");
      }
      for (i=0; i < ExtPeriodCount; i++) {
         // calculate bar open time from tick time
         cur_open  = cur_time/ExtPeriodSeconds[i];
         cur_open *= ExtPeriodSeconds[i];

         // new bar?
         bool newBar = false;
         if (i < 7) {
            if (ExtLastBarTime[i] != cur_open)
               newBar = true;
         }
         else if (i == 7) {
            // weekly timeframe
            if (cur_time-ExtLastBarTime[i] >= ExtPeriodSeconds[i]) {
               newBar = true;
            }
            if (newBar) {
               cur_open  = cur_time;
               cur_open -= cur_open % (1440 * 60);
               while (TimeDayOfWeek(cur_open) != 0) {
                  cur_open -= 1440 * 60;
               }
            }
         }
         else if (i == 8) {
            // monthly timeframe
            if (ExtLastBarTime[i] == 0) {
               newBar = true;
            }
            if (TimeDay(cur_time)<5 && cur_time-ExtLastBarTime[i]>10*1440*60) {
               newBar = true;
            }
            if (newBar) {
               cur_open  = cur_time;
               cur_open -= cur_open % (1440 * 60);
               while (TimeDay(cur_open) != 1) {
                  cur_open -= 1440 * 60;
               }
            }
         }
         if (newBar) {
            if (ExtBars[i] > 0) WriteBar(i);
            ExtLastBarTime[i] = cur_open;
            ExtLastOpen   [i] = tick_price;
            ExtLastLow    [i] = tick_price;
            ExtLastHigh   [i] = tick_price;
            ExtLastClose  [i] = tick_price;
            if (tick_volume > 0) ExtLastVolume[i] = tick_volume;
            else                 ExtLastVolume[i] = 1;
            ExtBars[i]++;
         }
         else {
            // check for minimum and maximum
            if (ExtLastLow [i] > tick_price) ExtLastLow   [i] = tick_price;
            if (ExtLastHigh[i] < tick_price) ExtLastHigh  [i] = tick_price;
                                             ExtLastClose [i]  = tick_price;
                                             ExtLastVolume[i] += tick_volume;
         }
      }

      if (start_date > 0 && cur_time < start_date)
         continue;
      if (end_date > 0 && cur_time >= end_date) {
         if (!CreateHst) break;
         continue;
      }
      if (ExtStartTick == 0) ExtStartTick = cur_time;
      ExtEndTick = cur_time;
      WriteTick();
   }

   // finalize
   for (i=0; i < ExtPeriodCount; i++) {
      WriteBar(i);
      if (ExtHstHandle[i] > 0) FileClose(ExtHstHandle[i]);
   }
   FileClose(ExtCsvHandle);

   // store processed bars amount
   FileFlush(ExtHandle);
   FileSeek(ExtHandle, 216, SEEK_SET);
   FileWriteInteger(ExtHandle, ExtBars[ExtPeriodId], LONG_VALUE);
   FileWriteInteger(ExtHandle, ExtStartTick,         LONG_VALUE);
   FileWriteInteger(ExtHandle, ExtEndTick,           LONG_VALUE);
   FileClose(ExtHandle);

   Print(ExtTicks, " ticks added. ", ExtBars[ExtPeriodId], " bars finalized in the header");
   Alert("Processing for "+ Symbol() +" has finished.");
   SetFileAttributesA("experts/files/"+ ExtFileName, FILE_ATTRIBUTE_READONLY);
   return(0);
}


int    lastTickTimeMin = -1;
double lastTickBid     =  0;
double lastTickAsk     =  0;


/**
 * Dukascopy custom exported data format:
 * yyyy.mm.dd hh:mm:ss,bid,ask,bid_volume,ask_volume
 */
bool ReadNextTick(datetime& cur_time, double& tick_price, double& tick_volume) {
   tick_volume = 0;

   while(!IsStopped())
   {
      // yyyy.mm.dd hh:mm:ss
      string date_time = FileReadString(ExtCsvHandle);
      if(FileIsEnding(ExtCsvHandle)) return(false);
      cur_time=StrToTime(date_time) + GMTOffset * 3600;
      cur_time+=DSTOffset(cur_time);
      //---- read tick price (bid)
      tick_price=NormalizeDouble(FileReadNumber(ExtCsvHandle), Digits);
      // discard Ask
      double dblAsk = NormalizeDouble(FileReadNumber(ExtCsvHandle), Digits);

      if (UseRealSpread) {
         ExtSpread = dblAsk - tick_price + SpreadPadding * Point;
      }
      // add bid volume (divided by standard lotsize)
      tick_volume += MathAbs(FileReadNumber(ExtCsvHandle) / 100000);
      // add ask volume (divided by standard lotsize)
      tick_volume += MathAbs(FileReadNumber(ExtCsvHandle) / 100000);
      if (tick_volume <= 0) {
         tick_volume = 1;
      }
      if (!UseRealVolume) {
         tick_volume = 1;
      }
      if(FileIsEnding(ExtCsvHandle)) return(false);

      if (TimeMinute(cur_time) == lastTickTimeMin && dblAsk == lastTickAsk && tick_price == lastTickBid) continue;
      lastTickTimeMin = TimeMinute(cur_time);
      lastTickAsk = dblAsk;
      lastTickBid = tick_price;

      //---- time must go forward. if no then read further
      if(cur_time>=ExtLastTime) break;
   }
   ExtLastTime=cur_time;
   return(true);
}


/**
 *
 */
void WriteTick() {
   // current bar state
   FileWriteInteger(ExtHandle, ExtLastBarTime[ExtPeriodId], LONG_VALUE);
   FileWriteDouble(ExtHandle, ExtLastOpen[ExtPeriodId], DOUBLE_VALUE);
   FileWriteDouble(ExtHandle, ExtLastLow[ExtPeriodId], DOUBLE_VALUE);
   FileWriteDouble(ExtHandle, ExtLastHigh[ExtPeriodId], DOUBLE_VALUE);
   FileWriteDouble(ExtHandle, ExtLastClose[ExtPeriodId], DOUBLE_VALUE);
   if (UseRealSpread) {
      FileWriteDouble(ExtHandle, ExtSpread, DOUBLE_VALUE);
   }
   else {
      FileWriteDouble(ExtHandle, ExtLastVolume[ExtPeriodId], DOUBLE_VALUE);
   }
//---- incoming tick time
   FileWriteInteger(ExtHandle, ExtLastTime, LONG_VALUE);
//---- flag 4 (it must be not equal to 0)
   FileWriteInteger(ExtHandle, 4, LONG_VALUE);
//---- ticks counter
   ExtTicks++;
}


/**
 *
 */
void WriteHstHeaders() {
   // History header
   for (int i = 0; i < ExtPeriodCount; i++) {
      int    i_version=400;
      string c_copyright;
      string c_symbol=Symbol();
      int    i_period=ExtPeriods[i];
      int    i_digits=Digits;
      int    i_unused[15];
//----
      ExtHstHandle[i]=FileOpen(c_symbol+i_period+".hst", FILE_BIN|FILE_WRITE);
      if(ExtHstHandle[i] < 0) Print("Error opening " + c_symbol + i_period);
//---- write history file header
      c_copyright="(C)opyright 2003, MetaQuotes Software Corp.";
      FileWriteInteger(ExtHstHandle[i], i_version, LONG_VALUE);
      FileWriteString(ExtHstHandle[i], c_copyright, 64);
      FileWriteString(ExtHstHandle[i], c_symbol, 12);
      FileWriteInteger(ExtHstHandle[i], i_period, LONG_VALUE);
      FileWriteInteger(ExtHstHandle[i], i_digits, LONG_VALUE);
      FileWriteArray(ExtHstHandle[i], i_unused, 0, 15);
   }
}


/**
 * write corresponding hst-file
 */
void WriteBar(int i) {
   if(ExtHstHandle[i]>0)
     {
      FileWriteInteger(ExtHstHandle[i], ExtLastBarTime[i], LONG_VALUE);
      FileWriteDouble(ExtHstHandle[i], ExtLastOpen[i], DOUBLE_VALUE);
      FileWriteDouble(ExtHstHandle[i], ExtLastLow[i], DOUBLE_VALUE);
      FileWriteDouble(ExtHstHandle[i], ExtLastHigh[i], DOUBLE_VALUE);
      FileWriteDouble(ExtHstHandle[i], ExtLastClose[i], DOUBLE_VALUE);
      FileWriteDouble(ExtHstHandle[i], ExtLastVolume[i], DOUBLE_VALUE);
     }
}


/**
 *
 */
int DSTOffset(int t) {
   if (isDST(t, DST)) {
      return (3600);
   }
   return (0);
}


/**
 *
 */
bool isDST(int t, int zone = 0) {
   if (zone == 2) { // Europe
      datetime dstStart = StrToTime(TimeYear(t) + ".03.31 01:00");
      while (TimeDayOfWeek(dstStart) != 0) { // last Sunday of March
         dstStart -= 3600 * 24;
      }
      datetime dstEnd = StrToTime(TimeYear(t) + ".10.31 01:00");
      while (TimeDayOfWeek(dstEnd) != 0) { // last Sunday of October
         dstEnd -= 3600 * 24;
      }
      if (t >= dstStart && t < dstEnd) {
         return (true);
      }
      else {
         return (false);
      }
   }
   else if (zone == 1) { // US
      dstStart = StrToTime(TimeYear(t) + ".03.01 00:00"); // should be Saturday 21:00 GMT (New York is at GMT-5 and it changes at 2AM) but it doesn't really matter since we have no market during the weekend
      int sundayCount = 0;
      while (true) { // second Sunday of March
         if (TimeDayOfWeek(dstStart) == 0) {
            sundayCount++;
            if (sundayCount == 2) break;
         }
         dstStart += 3600 * 24;
      }
      dstEnd = StrToTime(TimeYear(t) + ".11.01 00:00");
      while (TimeDayOfWeek(dstEnd) != 0) { // first Sunday of November
         dstEnd += 3600 * 24;
      }
      if (t >= dstStart && t < dstEnd) {
         return (true);
      }
      else {
         return (false);
      }
   }
   return (false);
}

/**
 * derived from version 2011.09.11  Cristi Dumitrescu <birt@eareview.net>
 */
 #include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

#property show_inputs
////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string CSV.File       = "";
extern double Spread         = 0;                     // Spreads & commissions are in pips regardless of the number of digits.
extern double PipsCommission = 0;
extern int    Leverage       = 100;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <structs/mt4/FxtHeader.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!IsConnected()) return(catch("onStart(1)  This script requires a connection to the broker.", ERR_NO_CONNECTION));

   if (Digits%2 == 1) Spread *= 10;
   Spread = NormalizeDouble(Spread, 0);

   if (Digits%2 == 1) PipsCommission *= 10;
   PipsCommission = NormalizeDouble(PipsCommission, 2);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   // open input csv-file
   string csv.fileName = CSV.File;
   if (csv.fileName == "")
      csv.fileName = StringSubstr(Symbol(), 0, 6) +".csv";
   int csv.hFile = FileOpen(csv.fileName, FILE_CSV|FILE_READ, ','); if (csv.hFile < 0) return(catch("onStart(2)  Can\'t open input file: "+ csv.fileName, ERR_CANNOT_OPEN_FILE));


   // open output fxt-file
   string fxt.fileName = Symbol() + Period() +"_0.fxt";
   int    fxt.hFile    = FileOpen(fxt.fileName, FILE_BIN|FILE_WRITE); if (fxt.hFile < 0) return(catch("onStart(3)  Can\'t open output file: "+ fxt.fileName, ERR_CANNOT_OPEN_FILE));
   WriteHeader(fxt.hFile, Symbol(), Period(), 0, Spread, PipsCommission, Leverage);

   int      ticks, tick.volume;
   datetime tick.time, openTime, time.firstTick, time.lastTick;
   double   tick.price;

   datetime bar.openTime;
   double   bar.open, bar.high, bar.low, bar.close;
   int      bars, bar.volume, periodSecs=Period()*MINUTES;


   // CSV read loop
   while (!IsStopped()) {
      if (!ReadNextTick(csv.hFile, tick.time, tick.price, tick.volume)) break;

      openTime = tick.time - tick.time%periodSecs;                      // calculate bar open time

      if (openTime != bar.openTime) {                                   // new bar
         bar.openTime = openTime;
         bar.open     = tick.price;
         bar.low      = tick.price;
         bar.high     = tick.price;
         bar.close    = tick.price;
         bar.volume   = tick.volume;
         bars++;
      }
      else {
         if (bar.high < tick.price) bar.high    = tick.price;           // update high/low
         if (bar.low  > tick.price) bar.low     = tick.price;
                                    bar.close   = tick.price;
                                    bar.volume += tick.volume;
      }
      WriteFxtTick(fxt.hFile, tick.time, bar.openTime, bar.open, bar.high, bar.low, bar.close, bar.volume);

      ticks++;
      if (!time.firstTick) time.firstTick = tick.time;
                           time.lastTick  = tick.time;
   }

   // close CSV file
   FileClose(csv.hFile);

   // store processed bars and close FXT file
   FileFlush       (fxt.hFile);
   FileSeek        (fxt.hFile, 216, SEEK_SET);
   FileWriteInteger(fxt.hFile, bars,           LONG_VALUE);
   FileWriteInteger(fxt.hFile, time.firstTick, LONG_VALUE);
   FileWriteInteger(fxt.hFile, time.lastTick,  LONG_VALUE);
   FileClose       (fxt.hFile);
   log("onStart(4)  "+ ticks +" ticks written, processing done.");

   return(catch("onStart(5)"));
}


/**
 * Dukascopy CSV tick data format:
 * yyyy.mm.dd hh:mm:ss,bid,ask,bid_volume,ask_volume
 */
bool ReadNextTick(int hFile, datetime &time, double &bid, int &volume) {
   static int    lastMinute = -1;
   static double lastBid=0, lastAsk=0;
   double ask;

   volume = 0;

   while (!IsStopped()) {
      time     = StrToTime(FileReadString(hFile));                         // yyyy.mm.dd hh:mm:ss
      bid      = NormalizeDouble(FileReadNumber(hFile), Digits);           // Bid
      ask      = NormalizeDouble(FileReadNumber(hFile), Digits);           // Ask
      volume  += FileReadNumber(hFile);
      volume  += FileReadNumber(hFile);                                    // add bid and ask volume
      if (volume <= 0)
         volume = 1;
      if (FileIsEnding(hFile)) return(false);

      if (TimeMinute(time)==lastMinute && bid==lastBid && ask==lastAsk)
         continue;
      lastMinute = TimeMinute(time);
      lastBid    = bid;
      lastAsk    = ask;
   }
   return(true);
}


/**
 *
 */
void WriteFxtTick(int hFile, datetime tickTime, datetime barTime, double open, double high, double low, double close, int volume) {
   FileWriteInteger(hFile, barTime,  LONG_VALUE  );
   FileWriteDouble (hFile, open,     DOUBLE_VALUE);
   FileWriteDouble (hFile, low,      DOUBLE_VALUE);
   FileWriteDouble (hFile, high,     DOUBLE_VALUE);
   FileWriteDouble (hFile, close,    DOUBLE_VALUE);
   FileWriteDouble (hFile, volume,   DOUBLE_VALUE);
   FileWriteInteger(hFile, tickTime, LONG_VALUE  );
   FileWriteInteger(hFile, 4,        LONG_VALUE  );   // always 4       // 0: kein Tick (1000 Bars aus History vorladen, 1 Tick je Bar, Ticktime ist laufender Zähler)
}                                                                       // 1: Open- oder Close-Tick der Bar
                                                                        // 2: ???
                                                                        // 3: ???

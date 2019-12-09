/**
 * History Data Checker
 *
 * Wochenend- und Feiertags-Gaps werden immer ignoriert, Pre/PostMarket-Gaps nur bei SkipEarlyLateHours=ON.
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string ___Skip.Early.Late.Hours___ = "(skips bars from Fri, 23:00 - Mon, 01:00)";
extern bool   SkipEarlyLateHours          = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/expert.mqh>
#include <stdfunctions.mqh>
#include <functions/JoinStrings.mqh>
#include <rsfLibs.mqh>
#include <structs/mt4/HistoryHeader.mqh>


int weekStarts;                                                      // Handelsstartzeit der Woche in Sekunden seit Mon, 00:00
int weekendStarts;                                                   // Handelsstopzeit der Woche in Sekunden seit Mon, 00:00


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   static bool done;
   if (!done) {
      string report = CreateReport();

      return(last_error);

      if (StringLen(report) > 0) {
         if (!EditFile(report)) return(ERR_RUNTIME_ERROR);
      }
      done = true;

      if (IsTesting())
         Tester.Stop();
   }
   return(last_error);
}



/**
 * Erstellt den Report.
 *
 * @return string - vollständiger Name der Reportdatei oder Leerstring, falls ein Fehler auftrat
 */
string CreateReport() {
   string timezone = GetServerTimezone(), lTimezone = StrToLower(timezone);
   if (!StringLen(timezone)) return("");

   int tzOffset = GetServerToFxtTimeOffset(TimeCurrentEx("CreateReport(0)"));
   if (tzOffset == EMPTY_VALUE) return("");


   // (1) Historydatei öffnen
   string hstFileName = StringConcatenate(Symbol(), Period(), ".hst");
   int hHstFile = FileOpenHistory(hstFileName, FILE_READ|FILE_BIN);
   if (hHstFile < 0)
      return(_EMPTY_STR(catch("CreateReport(1)->FileOpenHistory(\""+ hstFileName +"\")")));

   int hstFileSize = FileSize(hHstFile);
   if (hstFileSize < HISTORY_HEADER.size) {
      FileClose(hHstFile);
      return(_EMPTY_STR(catch("CreateReport(2)  corrupted history file \""+ hstFileName +"\" (size = "+ hstFileSize +")", ERR_RUNTIME_ERROR)));
   }


   // (2) Headerdaten auslesen
   int    hstBars, hstFrom, hstTo, missingBars, barSize;
   double firstPrice, highPrice, lowPrice, closePrice;

   /*HISTORY_HEADER*/int hh[]; InitializeByteBuffer(hh, HISTORY_HEADER.size);
   FileReadArray(hHstFile, hh, 0, HISTORY_HEADER.intSize);
   int hstFormat=hh_BarFormat(hh), hstDigits=hh_Digits(hh);

   if      (hstFormat == 400) barSize = HISTORY_BAR_400.size;
   else if (hstFormat == 401) barSize = HISTORY_BAR_400.size;
   else {
      catch("CreateReport(3)  unknown history file format \""+ hstFileName +"\" (format = "+ hstFormat +")", ERR_RUNTIME_ERROR);
      FileClose(hHstFile);
      return("");
   }

   if (hstFileSize > HISTORY_HEADER.size) {
      hstBars = (hstFileSize-HISTORY_HEADER.size) / barSize;
      if (hstBars > 0) {
         if (hstFormat == 400) {
            hstFrom    = FileReadInteger(hHstFile);
            firstPrice = FileReadDouble (hHstFile);
            lowPrice   = FileReadDouble (hHstFile);
            highPrice  = FileReadDouble (hHstFile);
         }
         else {        // 401
            hstFrom    = FileReadInteger(hHstFile);
                         FileReadInteger(hHstFile);
            firstPrice = FileReadDouble (hHstFile);
            highPrice  = FileReadDouble (hHstFile);
            lowPrice   = FileReadDouble (hHstFile);
         }
         closePrice = firstPrice;                                    // Open, damit maxTickGap beim ersten Test 0 ist
         FileSeek(hHstFile, HISTORY_HEADER.size + (hstBars-1)*barSize, SEEK_SET);
         hstTo      = FileReadInteger(hHstFile);
      }
   }


   // (3) Report öffnen
   string reportFileName = "History data report.txt";
   int hReport = FileOpen(reportFileName, FILE_CSV|FILE_WRITE);
   if (hReport < 0) {
      catch("CreateReport(4)->FileOpen(\""+ reportFileName +"\")");
      FileClose(hHstFile);
      return("");
   }


   // Speicher für Offsets und Längen der später zu aktualisierenden Zeilen
   int offsets[11][2];           // {Offset, Zeilenlänge}
   #define OS_MISSING_BARS        0
   #define OS_FIRST_PRICE         1
   #define OS_HIGH_PRICE          2
   #define OS_LOW_PRICE           3
   #define OS_CLOSE_PRICE         4
   #define OS_MAX_BAR_RANGE       5
   #define OS_MAX_TICK_GAP        6
   #define OS_MAX_TOTAL_GAP       7
   #define OS_MAX_HOLE            8
   #define OS_NO_OF_GAPS          9
   #define OS_NO_OF_GAPS_LINE    10


   // (4) Report-Summary schreiben und dabei später zu modifizierende Offsets merken
   int chars, chars1, chars2, chars3;
   chars1 = FileWrite(hReport, "History data analysis for "+ Symbol() +", "+ PeriodDescription(Period()) +" at "+ LocalTimeFormat(GetGmtTime(), "%a, %d.%m.%Y %H:%M:%S"));
   chars2 = FileWrite(hReport, "Server:   "+ GetServerName()                                                                   );
      string strOffset = ifString(tzOffset >= 0, "+", "-") + StrRight("0"+ Abs(tzOffset/HOURS), 2) + StrRight("0"+ tzOffset%HOURS, 2);
   chars3 = FileWrite(hReport, "Timezone: "+ timezone + ifString(lTimezone=="fxt", "", " (FXT"+ strOffset +")")                        );
            FileWrite(hReport, "Session:  "+ ifString(!tzOffset, "00:00-24:00", GmtTimeFormat(D'1970.01.02' + tzOffset, "%H:%M-%H:%M")));
            FileWrite(hReport, StrRepeat("=", Max(chars1, Max(chars2, chars3))-1)                                                      );
            FileWrite(hReport, "Parameters: SkipEarlyLateHours="+ SkipEarlyLateHours                                                   );
            FileWrite(hReport, ""                                                                                                      );
            FileWrite(hReport, ""                                                                                                      );
            FileWrite(hReport, "Summary"                                                                                               );
            FileWrite(hReport, "-------"                                                                                               );
            FileWrite(hReport, "File:              "+ hstFileName +"  ("+ NumberToStr(hstFileSize/1024., "R.0,") +" kB)"               );
            FileWrite(hReport, "First bar:         "+ GmtTimeFormat(hstFrom, "%a, %d.%m.%Y %H:%M")                                     );
            FileWrite(hReport, "Last bar:          "+ GmtTimeFormat(hstTo,   "%a, %d.%m.%Y %H:%M")                                     );
            FileWrite(hReport, "Total bars:        "+ NumberToStr(hstBars, ".0,")                                                      );

   offsets[OS_MISSING_BARS ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Missing bars:      ?,???,???,??? (???.?%)"                                                             );    // Offset und Zeilenlänge merken
   offsets[OS_MISSING_BARS ][1] = chars-1;

            FileWrite(hReport, ""                                                                                                      );
            FileWrite(hReport, "Digits:            "+ hstDigits                                                                        );

   offsets[OS_FIRST_PRICE  ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "First price:       ???,???.????'?"                                                                     );    // Offset und Zeilenlänge merken
   offsets[OS_FIRST_PRICE  ][1] = chars-1;

   offsets[OS_HIGH_PRICE   ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "High price:        ???,???.????'?  (???, ??.??.???? ??:??)"                                            );    // Offset und Zeilenlänge merken
   offsets[OS_HIGH_PRICE   ][1] = chars-1;

   offsets[OS_LOW_PRICE    ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Low price:         ???,???.????'?  (???, ??.??.???? ??:??)"                                            );    // Offset und Zeilenlänge merken
   offsets[OS_LOW_PRICE    ][1] = chars-1;

   offsets[OS_CLOSE_PRICE  ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Last price:        ???,???.????'?"                                                                     );    // Offset und Zeilenlänge merken
   offsets[OS_CLOSE_PRICE  ][1] = chars-1;

   offsets[OS_MAX_BAR_RANGE][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Max bar range:     ???.? pip       (???, ??.??.???? ??:??)"                                            );    // Offset und Zeilenlänge merken
   offsets[OS_MAX_BAR_RANGE][1] = chars-1;

            FileWrite(hReport, ""                                                                                                      );

   offsets[OS_MAX_TICK_GAP ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Max tick gap:      ???.? pip       (???, ??.??.???? ??:??)"                                            );    // Offset und Zeilenlänge merken
   offsets[OS_MAX_TICK_GAP ][1] = chars-1;

   offsets[OS_MAX_TOTAL_GAP][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Max total gap:     ???.? pip       (???, ??.??.???? ??:??  ->  ???, ??.??.???? ??:??)"                 );    // Offset und Zeilenlänge merken
   offsets[OS_MAX_TOTAL_GAP][1] = chars-1;

   offsets[OS_MAX_HOLE     ][0] = FileTell(hReport);
   chars  = FileWrite(hReport, "Largest time hole: ???:?:??:?? w   (???, ??.??.???? ??:??  ->  ???, ??.??.???? ??:??)"                 );    // Offset und Zeilenlänge merken
   offsets[OS_MAX_HOLE     ][1] = chars-1;


   // (5) Daten verarbeiten
   datetime bar.time, openTime, alignedOpenTime, closeTime=ServerToFxtTime(hstFrom), alignedCloseTime=closeTime, next24.12.Break, next31.12.Break, startTime;
   datetime highPriceTime, lowPriceTime, maxBarRangeTime, maxTickGapTime, maxTotalGapFromTime, maxTotalGapToTime;
   datetime maxHoleFromTime, maxHoleToTime, period=Period()*MINUTES;
   string   strCloseTime, strOpenTime, strHoleLen, strMaxHoleLen;
   double   maxBarRange, maxTotalGap, maxTickGap, bar.open, bar.high, bar.low, bar.close;
   int      holes, holeLen, maxHoleLen, closeDay, lastCloseDay, openDay;
   bool     closeAfterHours, openAfterHours, midnight;

   weekStarts    =          ifInt(SkipEarlyLateHours,  1,  0)*HOURS;    // Montags früh
   weekendStarts = 4*DAYS + ifInt(SkipEarlyLateHours, 23, 24)*HOURS;    // Freitags abend


   for (int i=0; i < hstBars; i++) {
      if (!FileSeek(hHstFile, HISTORY_HEADER.size + i*barSize, SEEK_SET))
         break;
      bar.time = FileReadInteger(hHstFile);
      openTime = ServerToFxtTime(bar.time);

      if (hstFormat == 400) {
         bar.open  = FileReadDouble(hHstFile);
         bar.low   = FileReadDouble(hHstFile);
         bar.high  = FileReadDouble(hHstFile);
         bar.close = FileReadDouble(hHstFile);
      }
      else {        // 401
             FileReadInteger(hHstFile);
         bar.open  = FileReadDouble(hHstFile);
         bar.high  = FileReadDouble(hHstFile);
         bar.low   = FileReadDouble(hHstFile);
         bar.close = FileReadDouble(hHstFile);
      }

      static bool done;
      if (!done) {
         int last[], next[];
         GetTimezoneTransitions(bar.time, last, next);

         debug("CreateReport()  time="+ GmtTimeFormat(bar.time, "%a, %d.%m.%Y %H:%M"));

         if (last[TRANSITION_TIME] >= 0) debug("CreateReport()  last="+ GmtTimeFormat(last[TRANSITION_TIME], "%a, %d.%m.%Y %H:%M") +" ("+ ifString(last[TRANSITION_OFFSET]>=0, "+", "") + (last[TRANSITION_OFFSET]/HOURS) +"), DST="+ last[TRANSITION_DST]);
         else                            debug("CreateReport()  last="+ last[TRANSITION_TIME]);

         if (next[TRANSITION_TIME] >= 0) debug("CreateReport()  next="+ GmtTimeFormat(next[TRANSITION_TIME], "%a, %d.%m.%Y %H:%M") +" ("+ ifString(next[TRANSITION_OFFSET]>=0, "+", "") + (next[TRANSITION_OFFSET]/HOURS) +"), DST="+ next[TRANSITION_DST]);
         else                            debug("CreateReport()  next="+ next[TRANSITION_TIME]);

         done = true;
      }

      // (5.1) Gaps je nach Szenario behandeln
      if (closeTime < openTime) {
         /*
         Szenarien: innerhalb=InHours, außerhalb=AfterHours
         +-----+--------------------------+-----------+
         |     | Beschreibung             |    Gap    |
         +-----+--------------------------+-----------+
         | (1) | C+O innerhalb            |   normal  |
         +-----+--------------------------+-----------+
         | (2) | C innerhalb, O außerhalb |    skip   |
         +-----+--------------------------+-----------+
         | (3) | C+O außerhalb            |    skip   |
         +-----+--------------------------+-----------+
         | (4) | C außerhalb, O innerhalb | verkürzen |
         +-----+--------------------------+-----------+
         */
         closeAfterHours = IsAfterHours(closeTime);
         openAfterHours  = IsAfterHours(openTime );

         if (!closeAfterHours) {
            if (!openAfterHours) {                                      // Fall 1: C+O innerhalb:            normales Gap
            }
            else {
               continue;                                                // Fall 2: C innerhalb, O außerhalb: überspringen
            }
         }
         else if (openAfterHours) {
            continue;                                                   // Fall 3: C+O außerhalb:            überspringen
         }
         else {
            alignedCloseTime = NextTradeStart(closeTime);               // Fall 4: C außerhalb, O innerhalb: Close vorziehen
         }

         // (5.2) Gaps bei Handelsende vor Feiertagen überspringen
         if (alignedCloseTime < openTime) {
            next24.12.Break = Next24.12.Break(alignedCloseTime);
            if (next24.12.Break < openTime) {
               alignedCloseTime = NextTradeStart(next24.12.Break);
            }
            else {
               next31.12.Break = Next31.12.Break(alignedCloseTime);
               if (next31.12.Break < openTime)
                  alignedCloseTime = NextTradeStart(next31.12.Break);
            }
         }

         // (5.3) Gaps bei Handelsbeginn nach Feiertagen überspringen
         if (alignedCloseTime < openTime) {
            if (PreviousTradeStart(alignedCloseTime) == alignedCloseTime) {
               if (IsHoliday(alignedCloseTime-1*DAY))
                  alignedCloseTime = openTime;
            }
         }

         // (5.4) Gap reportieren
         if (alignedCloseTime < openTime) {
            alignedOpenTime = openTime;
            if (NextTradeStart(alignedCloseTime) == openTime)
               alignedOpenTime = NextTradeBreak(alignedCloseTime);

            holes++;
            if (holes == 1) {
                       FileWrite(hReport, ""                                                                                                  );
                       FileWrite(hReport, ""                                                                                                  );
               offsets[OS_NO_OF_GAPS][0] = FileTell(hReport);
               chars = FileWrite(hReport, "?,???,???,??? time holes ("+ ifString(SkipEarlyLateHours, "skipping", "inc.") +" early/late hours)");   // Offset und Zeilenlänge merken
               offsets[OS_NO_OF_GAPS][1] = chars-1;

               offsets[OS_NO_OF_GAPS_LINE][0] = FileTell(hReport);
               chars = FileWrite(hReport, StrRepeat("-", chars-1)                                                                             );   // Offset und Zeilenlänge merken
               offsets[OS_NO_OF_GAPS_LINE][1] = chars-1;
            }
            closeDay =  FxtToServerTime(alignedCloseTime)/DAYS;
            openDay  =  FxtToServerTime(alignedOpenTime )/DAYS;
            midnight = (FxtToServerTime(alignedOpenTime )%DAYS == 0);

            if (closeDay == lastCloseDay)             strCloseTime = GmtTimeFormat(FxtToServerTime(alignedCloseTime), "                %H:%M");    // einfaches Format, wenn das Gap am
            else                                      strCloseTime = GmtTimeFormat(FxtToServerTime(alignedCloseTime), "%a, %d.%m.%Y %H:%M");       // selben Tag wie das letzte auftritt

            if      (closeDay  ==openDay            ) strOpenTime  = GmtTimeFormat(FxtToServerTime(alignedOpenTime),  "                %H:%M");    // einfaches Format, wenn das Gap
            else if (closeDay+1==openDay && midnight) strOpenTime  = GmtTimeFormat(FxtToServerTime(alignedOpenTime),  "                %H:%M");    // bis um Mitternacht endet
            else                                      strOpenTime  = GmtTimeFormat(FxtToServerTime(alignedOpenTime),  "%a, %d.%m.%Y %H:%M");

            holeLen   = 0;
            startTime = alignedCloseTime;
            while (ContainsTradeBreak(startTime, alignedOpenTime)) {
               holeLen     += NextTradeBreak(startTime) - startTime;
               missingBars += holeLen/period;
               startTime    = NextTradeStart(startTime);
            }
            holeLen     += alignedOpenTime - startTime;
            missingBars += holeLen/period;
            strHoleLen   = TimeSpanToStr(alignedCloseTime, alignedOpenTime, holeLen);

            FileWrite(hReport, strCloseTime +"  ->  "+ strOpenTime +"  ("+ strHoleLen +")");

            if (holeLen >= maxHoleLen) {
               maxHoleLen      = holeLen;
               maxHoleFromTime = alignedCloseTime;
               maxHoleToTime   = alignedOpenTime;
               strMaxHoleLen   = strHoleLen;
            }
            lastCloseDay = closeDay;
         }
      }

      // (5.5) Statistiken aktualisieren (jeweils das letzte Extrem speichern)
      if (bar.high         >= highPrice  ) /*&&*/ if (!IsAfterHours(openTime)) { highPrice   = bar.high;         highPriceTime   = openTime; }
      if (bar.low          <= lowPrice   ) /*&&*/ if (!IsAfterHours(openTime)) { lowPrice    = bar.low;          lowPriceTime    = openTime; }
      if (bar.high-bar.low >= maxBarRange) /*&&*/ if (!IsAfterHours(openTime)) { maxBarRange = bar.high-bar.low; maxBarRangeTime = openTime; }

      double diff = MathAbs(closePrice-bar.open);

      // maxTickGap: wenn die Bars aufeinanderfolgen
      if (closeTime == openTime) {
         if (diff >= maxTickGap) {
            if (!IsAfterHours(openTime)) /*&&*/ if (PreviousTradeStart(openTime) < openTime) {
               maxTickGap     = diff;
               maxTickGapTime = openTime;
            }
         }
      }

      // maxTotalGap
      if (diff >= maxTotalGap) {
         if (!IsAfterHours(closeTime)) /*&&*/ if (!IsAfterHours(openTime)) {
            maxTotalGap         = diff;
            maxTotalGapFromTime = closeTime;
            maxTotalGapToTime   = openTime;

            if (closeTime == openTime) {
               maxTotalGapFromTime = closeTime - period;
               if (IsAfterHours(maxTotalGapFromTime))
                  maxTotalGapFromTime = PreviousTradeBreak(maxTotalGapFromTime);
            }
         }
      }

      closeTime  = openTime + period; alignedCloseTime = closeTime;
      closePrice = bar.close;
   }


   // (6) Report-Summary aktualisieren
   string strHighPrice   =            NumberToStr(highPrice,  PriceFormat); int len = StringLen(strHighPrice);
   string strFirstPrice  = StrPadLeft(NumberToStr(firstPrice, PriceFormat), len, " ");
   string strLowPrice    = StrPadLeft(NumberToStr(lowPrice,   PriceFormat), len, " ");
   string strClosePrice  = StrPadLeft(NumberToStr(closePrice, PriceFormat), len, " ");

   string strMaxBarRange = DoubleToStr(maxBarRange/Pip, 1) +" pip"; len = Max(len, StringLen(strMaxBarRange));
   string strMaxTickGap  = DoubleToStr(maxTickGap /Pip, 1) +" pip"; len = Max(len, StringLen(strMaxTickGap ));
   string strMaxTotalGap = DoubleToStr(maxTotalGap/Pip, 1) +" pip"; len = Max(len, StringLen(strMaxTotalGap));
                                                                    len = Max(len, StringLen(strMaxHoleLen ));
          strHighPrice   = StrPadRight(strHighPrice,   len, " ");
          strLowPrice    = StrPadRight(strLowPrice,    len, " ");
          strMaxBarRange = StrPadRight(strMaxBarRange, len, " ");
          strMaxTickGap  = StrPadRight(strMaxTickGap,  len, " ");
          strMaxTotalGap = StrPadRight(strMaxTotalGap, len, " ");
          strMaxHoleLen  = StrPadRight(strMaxHoleLen,  len, " ");

   string line, strMaxTotalGapToTime, strMaxHoleToTime;

   line = "Missing bars:      "+ NumberToStr(missingBars, ".0,") + ifString(!missingBars, "", " ("+ NumberToStr(100. * missingBars/(hstBars+missingBars), "R.1") +"%)");
   FileSeek(hReport, offsets[OS_MISSING_BARS      ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_MISSING_BARS   ][1], " "));

   line = "First price:       "+ strFirstPrice;
   FileSeek(hReport, offsets[OS_FIRST_PRICE       ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_FIRST_PRICE    ][1], " "));

   line = "High price:        "+ strHighPrice +"  ("+ GmtTimeFormat(FxtToServerTime(highPriceTime), "%a, %d.%m.%Y %H:%M") +")";
   FileSeek(hReport, offsets[OS_HIGH_PRICE        ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_HIGH_PRICE     ][1], " "));

   line = "Low price:         "+ strLowPrice +"  ("+ GmtTimeFormat(FxtToServerTime(lowPriceTime), "%a, %d.%m.%Y %H:%M") +")";
   FileSeek(hReport, offsets[OS_LOW_PRICE         ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_LOW_PRICE      ][1], " "));

   line = "Last price:        "+ strClosePrice;
   FileSeek(hReport, offsets[OS_CLOSE_PRICE       ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_CLOSE_PRICE    ][1], " "));

   line = "Max bar range:     "+ strMaxBarRange +"  ("+ GmtTimeFormat(FxtToServerTime(maxBarRangeTime), "%a, %d.%m.%Y %H:%M") +")";
   FileSeek(hReport, offsets[OS_MAX_BAR_RANGE     ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_MAX_BAR_RANGE  ][1], " "));

   line = "Max tick gap:      "+ strMaxTickGap +"  ("+ GmtTimeFormat(FxtToServerTime(maxTickGapTime), "%a, %d.%m.%Y %H:%M") +")";
   FileSeek(hReport, offsets[OS_MAX_TICK_GAP      ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_MAX_TICK_GAP   ][1], " "));

      int fromDay  =  FxtToServerTime(maxTotalGapFromTime)/DAYS;
      int toDay    =  FxtToServerTime(maxTotalGapToTime  )/DAYS;
          midnight = (FxtToServerTime(maxTotalGapToTime  )%DAYS == 0);
      if      (fromDay  ==toDay            ) strMaxTotalGapToTime = GmtTimeFormat(FxtToServerTime(maxTotalGapToTime), "                %H:%M");    // einfaches Format, wenn das Gap
      else if (fromDay+1==toDay && midnight) strMaxTotalGapToTime = GmtTimeFormat(FxtToServerTime(maxTotalGapToTime), "                %H:%M");    // bis um Mitternacht endet
      else                                   strMaxTotalGapToTime = GmtTimeFormat(FxtToServerTime(maxTotalGapToTime), "%a, %d.%m.%Y %H:%M");
      bool shortMaxTotalTime = StrStartsWith(strMaxTotalGapToTime, " ");

      if (holes > 0) {
         fromDay  =  FxtToServerTime(maxHoleFromTime)/DAYS;
         toDay    =  FxtToServerTime(maxHoleToTime  )/DAYS;
         midnight = (FxtToServerTime(maxHoleToTime  )%DAYS == 0);
         if      (fromDay  ==toDay            ) strMaxHoleToTime = GmtTimeFormat(FxtToServerTime(maxHoleToTime), "                %H:%M");         // einfaches Format, wenn das Gap
         else if (fromDay+1==toDay && midnight) strMaxHoleToTime = GmtTimeFormat(FxtToServerTime(maxHoleToTime), "                %H:%M");         // bis um Mitternacht endet
         else                                   strMaxHoleToTime = GmtTimeFormat(FxtToServerTime(maxHoleToTime), "%a, %d.%m.%Y %H:%M");
         bool shortMaxHoleTime = StrStartsWith(strMaxHoleToTime, " ");
         if (shortMaxTotalTime && shortMaxHoleTime) {
            strMaxTotalGapToTime = StrTrim(strMaxTotalGapToTime);       // wenn beide einfaches Format, dann beide kürzen
            strMaxHoleToTime     = StrTrim(strMaxHoleToTime);
         }
      }
      else if (shortMaxTotalTime) {
         strMaxTotalGapToTime = StrTrim(strMaxTotalGapToTime);
      }

   line = "Max total gap:     "+ strMaxTotalGap +"  ("+ GmtTimeFormat(FxtToServerTime(maxTotalGapFromTime), "%a, %d.%m.%Y %H:%M") +"  ->  "+ strMaxTotalGapToTime +")";
   FileSeek(hReport, offsets[OS_MAX_TOTAL_GAP     ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_MAX_TOTAL_GAP  ][1], " "));

   if (holes > 0) {
      line = "Largest time hole: "+ strMaxHoleLen +"  ("+ GmtTimeFormat(FxtToServerTime(maxHoleFromTime), "%a, %d.%m.%Y %H:%M") +"  ->  "+ strMaxHoleToTime +")";
      FileSeek(hReport, offsets[OS_MAX_HOLE       ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_MAX_HOLE       ][1], " "));

      line = NumberToStr(holes, ".0,") +" time holes ("+ ifString(SkipEarlyLateHours, "skipping", "inc.") +" early/late hours)";
      FileSeek(hReport, offsets[OS_NO_OF_GAPS     ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_NO_OF_GAPS     ][1], " "));

      line = StrRepeat("-", StringLen(line));
      FileSeek(hReport, offsets[OS_NO_OF_GAPS_LINE][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_NO_OF_GAPS_LINE][1], " "));
   }
   else {
      line = "";
      FileSeek(hReport, offsets[OS_MAX_HOLE       ][0], SEEK_SET); FileWrite(hReport, StrPadRight(line, offsets[OS_MAX_HOLE       ][1], " "));
      FileSeek(hReport, offsets[OS_MAX_HOLE       ][0], SEEK_SET);

      FileWrite(hReport, ""                                                                                      );
      FileWrite(hReport, "No time holes ("+ ifString(SkipEarlyLateHours, "skipped", "inc.") +" early/late hours)");
   }


   // (7) Dateien schließen
   catch("CreateReport(5)");
   FileClose(hHstFile);
   FileClose(hReport);


   // (8) vollen Namen der Reportdatei zurückgeben
   if (IsLastError())
      return("");

   return(GetMqlFilesPath() +"\\"+ reportFileName);
}


/**
 * Ob ein Zeitpunkt außerhalb der regulären Handelszeiten liegt.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return bool
 */
bool IsAfterHours(datetime time) {
   int dow = TimeDayOfWeekFix(time);
   switch (dow) {
      case SATURDAY: return(true);
      case SUNDAY  : return(true);
   }

   int mm = TimeMonth (time);
   int dd = TimeDayFix(time);

   if (mm==12) {
      if (dd==25)                                                       // 25. Dezember (Feiertag)
         return(true);
      if (dd==26) {                                                     // 26. Dezember: wie Montag früh
         if (time%DAYS < weekStarts)
            return(true);
      }
      else if (dd==24 || dd==31) {                                      // 24. oder 31. Dezember: wie Freitag abend
         datetime thisBreak = time - time%DAYS + weekendStarts-4*DAYS;
         if (time >= thisBreak)
            return(true);
      }
   }
   else if (mm==1) {
      if (dd==1)                                                        // 1. Januar (Feiertag)
         return(true);
      if (dd==2)                                                        // 2. Januar: wie Montag früh
         if (time%DAYS < weekStarts)
            return(true);
   }

   switch (dow) {
      case MONDAY: return(time%DAYS           <  weekStarts);
      case FRIDAY: return(time%WEEKS + 3*DAYS >= weekendStarts);        // Thu, 01.01.1970
   }
   return(false);
}


/**
 * Ob der angegebene Zeitpunkt auf einen Forex-Feiertag fällt (1. Januar oder 25. Dezember).
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return bool
 */
bool IsHoliday(datetime time) {
   int dd = TimeDayFix(time);
   if (dd ==  1) return(TimeMonth(time) ==  1);                         //  1. Januar
   if (dd == 25) return(TimeMonth(time) == 12);                         // 25. Dezember
   return(false);
}


/**
 * Ob die Lücke zwischen zwei Bars mit den angegebenen Open-Zeitpunkten mindestens eine vollständige Handelsspanne enthält
 * (beide Bars müssen außerhalb dieser Handelsspanne liegen).
 *
 * @param  datetime time1 - Open-Zeitpunkt der ersten Bar  (FXT)
 * @param  datetime time2 - Open-Zeitpunkt der zweiten Bar (FXT)
 *
 * @return bool
 */
bool ContainsTradePeriod(datetime time1, datetime time2) {
   datetime tradeStart = NextTradeStart(time1);                         // nächster Handelsbeginn nach time1
   datetime breakStart = NextTradeBreak(tradeStart);                    // darauf folgendes Handelsende mit time2 vergleichen
   return(breakStart <= time2);
}


/**
 * Ob die Lücke zwischen zwei Bars mit den angegebenen Open-Zeitpunkten mindestens eine vollständige Handelspause enthält
 * (beide Bars müssen außerhalb dieser Handelspause liegen).
 *
 * @param  datetime time1 - Open-Zeitpunkt der ersten Bar  (FXT)
 * @param  datetime time2 - Open-Zeitpunkt der zweiten Bar (FXT)
 *
 * @return bool
 */
bool ContainsTradeBreak(datetime time1, datetime time2) {
   datetime breakStart = NextTradeBreak(time1);                         // nächstes Handelsende nach time1
   datetime tradeStart = NextTradeStart(breakStart);                    // darauf folgenden Handelsbeginn mit time2 vergleichen
   return(tradeStart <= time2);
}


/**
 * Gibt den letzten Beginn einer Handelsperiode zurück, der vor oder gleich einem Zeitpunkt ist.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime PreviousTradeStart(datetime time) {
   datetime breakStart = PreviousTradeBreak(time);                      // letztes Handelsende vor time
   datetime nextStart  = NextTradeStart(breakStart);
   if (nextStart > time) {                                              // darauf folgenden Handelsbeginn mit time vergleichen
      breakStart = PreviousTradeBreak(breakStart - 1);
      nextStart  = NextTradeStart(breakStart);
   }
   return(nextStart);
}


/**
 * Gibt den nächsten auf einen Zeitpunkt folgenden Handelsbeginn zurück.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime NextTradeStart(datetime time) {
   datetime nextStart = time - time%WEEKS - 3*DAYS + weekStarts;        // Handelsbeginn der Vor-/Woche von time (Montag)
   while (nextStart <= time) {
      nextStart += 1*WEEK;                                              // nächster Handelsbeginn in der Folgewoche (Montag)
   }
   if (IsHoliday(nextStart))
      nextStart += 1*DAY;

   int mm = TimeMonth(time);

   // ggf. Handelsbeginn des nächsten 26. Dezembers vorziehen
   if (mm==12) {
      datetime start26.12 = Next26.12.Start(time);
      if (start26.12 < nextStart) {
         switch (TimeDayOfWeekFix(start26.12)) {
            case SATURDAY:
            case SUNDAY  : break;
            default:
               return(start26.12);
         }
      }
   }

   // ggf. Handelsbeginn des nächsten 2. Januars vorziehen
   if (mm==12 || mm==1) {
      datetime start02.01 = Next02.01.Start(time);
      if (start02.01 < nextStart) {
         switch (TimeDayOfWeekFix(start02.01)) {
            case SATURDAY:
            case SUNDAY  : break;
            default:
               return(start02.01);
         }
      }
   }
   return(nextStart);
}


/**
 * Gibt den letzten Beginn einer Handelspause zurück, der vor oder gleich einem Zeitpunkt ist.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime PreviousTradeBreak(datetime time) {
   datetime previousBreak = time - time%WEEKS - 3*DAYS + weekendStarts; // Handelsende der Vor-/Woche von time
   while (previousBreak > time) {
      previousBreak -= 1*WEEK;                                          // letztes Handelsende in der Vorwoche
   }
   if (previousBreak == time)
      return(previousBreak);

   int mm = TimeMonth(time);

   if (mm==12 || mm==1) {
      // ggf. Handelsende des letzten 31. Dezembers vorziehen
      datetime break31.12 = Previous31.12.Break(time);
      if (previousBreak < break31.12) {
         switch (TimeDayOfWeekFix(break31.12)) {
            case SATURDAY:
            case SUNDAY  : break;
            default:
               return(break31.12);
         }
      }
      if (mm==12) {
         // ggf. Handelsende des letzten 24. Dezembers vorziehen
         datetime break24.12 = Previous24.12.Break(time);
         if (previousBreak < break24.12) {
            switch (TimeDayOfWeekFix(break24.12)) {
               case SATURDAY:
               case SUNDAY  : break;
               default:
                  return(break24.12);
            }
         }
      }
   }
   return(previousBreak);
}


/**
 * Gibt den Beginn der nächsten auf einen Zeitpunkt folgenden Handelspause zurück.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime NextTradeBreak(datetime time) {
   datetime nextBreak = time - time%WEEKS - 3*DAYS + weekendStarts;     // Handelsende der Vor-/Woche von time
   while (nextBreak <= time) {
      nextBreak += 1*WEEK;                                              // nächstes Handelsende in der Folgewoche
   }

   int mm = TimeMonth(time);

   if (mm == 12) {
      // ggf. Handelsende des nächsten 24. Dezembers vorziehen
      datetime break24.12 = Next24.12.Break(time);
      if (break24.12 < nextBreak) {
         switch (TimeDayOfWeekFix(break24.12)) {
            case SATURDAY:
            case SUNDAY  : break;
            default:
               return(break24.12);
         }
      }

      // ggf. Handelsende des nächsten 31. Dezembers vorziehen
      datetime break31.12 = Next31.12.Break(time);
      if (break31.12 < nextBreak) {
         switch (TimeDayOfWeekFix(break31.12)) {
            case SATURDAY:
            case SUNDAY  : break;
            default:
               return(break31.12);
         }
      }
   }
   return(nextBreak);
}


/**
 * Gibt den letzten Beginn eines Handelsendes eines 24. Dezembers zurück, der vor oder auf einem Zeitpunkt liegt.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime Previous24.12.Break(datetime time) {
   datetime d01.01 = time - (TimeDayOfYear(time)-1)*DAYS - time%DAYS;   // 01.01. 00:00 desselben Jahres
   datetime d24.12 = d01.01 + 357*DAYS;                                 // 24.12. 00:00 desselben Jahres
   if (TimeYearFix(time)%4 == 0)
      d24.12 += 1*DAY;                                                  // Schaltjahr berücksichtigen

   datetime previousBreak = d24.12 + (weekendStarts-4*DAYS);            // 24.12. Handelsende
   if (previousBreak > time) {
      previousBreak -= 365*DAYS;                                        // 24.12. Handelsende des Folgejahres
      if (TimeYearFix(time)%4 == 0)
         previousBreak -= 1*DAY;                                        // Schaltjahr berücksichtigen
   }
   return(previousBreak);
}


/**
 * Gibt das nächste auf einen Zeitpunkt folgende Handelsende eines 24. Dezembers zurück.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime Next24.12.Break(datetime time) {
   datetime d01.01 = time - (TimeDayOfYear(time)-1)*DAYS - time%DAYS;   // 01.01. 00:00 desselben Jahres
   datetime d24.12 = d01.01 + 357*DAYS;                                 // 24.12. 00:00 desselben Jahres
   if (TimeYearFix(time)%4 == 0)
      d24.12 += 1*DAY;                                                  // Schaltjahr berücksichtigen

   datetime nextBreak = d24.12 + (weekendStarts-4*DAYS);                // 24.12. Handelsende
   if (nextBreak <= time) {
      nextBreak += 365*DAYS;                                            // 24.12. Handelsende des Folgejahres
      if (TimeYearFix(nextBreak)%4 == 0)
         nextBreak += 1*DAY;                                            // Schaltjahr berücksichtigen
   }
   return(nextBreak);
}


/**
 * Gibt den nächsten auf einen Zeitpunkt folgenden Handelsbeginn eines 26. Dezembers zurück.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime Next26.12.Start(datetime time) {
   datetime d01.01 = time - (TimeDayOfYear(time)-1)*DAYS - time%DAYS;   // 01.01. 00:00 desselben Jahres
   datetime d26.12 = d01.01 + 359*DAYS;                                 // 26.12. 00:00 desselben Jahres
   if (TimeYearFix(time)%4 == 0)
      d26.12 += 1*DAY;                                                  // Schaltjahr berücksichtigen

   datetime nextStart = d26.12 + weekStarts;                            // 26.12. Handelsbeginn
   if (nextStart <= time) {
      nextStart += 365*DAYS;                                            // 26.12. Handelsbeginn des Folgejahres
      if (TimeYearFix(nextStart)%4 == 0)
         nextStart += 1*DAY;                                            // Schaltjahr berücksichtigen
   }
   return(nextStart);
}


/**
 * Gibt den letzten Beginn eines Handelsendes eines 31. Dezembers zurück, der vor oder auf einem Zeitpunkt liegt.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime Previous31.12.Break(datetime time) {
   datetime d01.01 = time - (TimeDayOfYear(time)-1)*DAYS - time%DAYS;   // 01.01. 00:00 desselben Jahres
   datetime d31.12 = d01.01 + 364*DAYS;                                 // 31.12. 00:00 desselben Jahres
   if (TimeYearFix(time)%4 == 0)
      d31.12 += 1*DAY;                                                  // Schaltjahr berücksichtigen

   datetime previousBreak = d31.12 + (weekendStarts-4*DAYS);            // 31.12. Handelsende
   if (previousBreak > time) {
      previousBreak -= 365*DAYS;                                        // 31.12. Handelsende des Vorjahres
      if (TimeYearFix(time)%4 == 0)
         previousBreak -= 1*DAY;                                        // Schaltjahr berücksichtigen
   }
   return(previousBreak);
}


/**
 * Gibt das nächste auf einen Zeitpunkt folgende Handelsende eines 31. Dezembers zurück.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime Next31.12.Break(datetime time) {
   datetime d01.01 = time - (TimeDayOfYear(time)-1)*DAYS - time%DAYS;   // 01.01. 00:00 desselben Jahres
   datetime d31.12 = d01.01 + 364*DAYS;                                 // 31.12. 00:00 desselben Jahres
   if (TimeYearFix(time)%4 == 0)
      d31.12 += 1*DAY;                                                  // Schaltjahr berücksichtigen

   datetime nextBreak = d31.12 + (weekendStarts-4*DAYS);                // 31.12. Handelsende
   if (nextBreak <= time) {
      nextBreak += 365*DAYS;                                            // 31.12. Handelsende des Folgejahres
      if (TimeYearFix(nextBreak)%4 == 0)
         nextBreak += 1*DAY;                                            // Schaltjahr berücksichtigen
   }
   return(nextBreak);
}


/**
 * Gibt den nächsten auf einen Zeitpunkt folgenden Handelsbeginn eines 2. Januars zurück.
 *
 * @param  datetime time - Zeitpunkt (FXT)
 *
 * @return datetime
 */
datetime Next02.01.Start(datetime time) {
   datetime d01.01 = time - (TimeDayOfYear(time)-1)*DAYS - time%DAYS;   // 01.01. 00:00 desselben Jahres
   datetime d02.01 = d01.01 + 1*DAYS;                                   // 02.01. 00:00 desselben Jahres

   datetime nextStart = d02.01 + weekStarts;                            // 02.01. Handelsbeginn
   if (nextStart <= time) {
      nextStart += 365*DAYS;                                            // 02.01. Handelsbeginn des Folgejahres
      if (TimeYearFix(time)%4 == 0)
         nextStart += 1*DAY;                                            // Schaltjahr berücksichtigen
   }
   return(nextStart);
}


/**
 * Gibt die lesbare Repräsentation einer Zeitspanne zurück.
 *
 * @param  datetime time1  - Beginn der Zeitspanne (FXT)
 * @param  datetime time2  - Ende der Zeitspanne   (FXT)
 * @param  int      length - relevante Länge der Zeitspanne innerhalb von time1 und time2
 *
 * @return string - String im Format "w:d:hh:mm [w|d|h|min]"
 */
string TimeSpanToStr(datetime time1, datetime time2, int length) {
   if (IsAfterHours(time1)) time1 = NextTradeStart(time1);
   if (IsAfterHours(time2)) time2 = PreviousTradeBreak(time2);

   int days, hours, mins, span=time2-time1;
   int weeks = span / WEEKS;

   if (weeks > 0) {
      days  = span   % WEEKS / DAYS;
      hours = span   % DAYS  / HOURS;
      mins  = span   % HOURS / MINUTES;
   }
   else {
      days  = length % WEEKS / DAYS;
      hours = length % DAYS  / HOURS;
      mins  = length % HOURS / MINUTES;
   }

   string result;
   if      (weeks > 0) result = weeks +":"+ days +":"+ StrRight("0"+hours, 2) +":"+ StrRight("0"+mins, 2) +" w";
   else if (days  > 0) result =             days +":"+ StrRight("0"+hours, 2) +":"+ StrRight("0"+mins, 2) +" d";
   else if (hours > 0) result =                                     hours     +":"+ StrRight("0"+mins, 2) +" h";
   else                result =                                                                  mins     +" min";
   return(result);
}


/**
 * Unterdrückt unnütze Compilerwarnungen.
 */
void DummyCalls() {
   int iNull[];
   ContainsTradePeriod(NULL, NULL);
   HISTORY_HEADER.toStr(iNull);
}


/*
History data analysis for EURUSDi, H1 at Fri, 12.07.2013 11:40:06
Server:   CMAP-Demo
Timezone: Europe/London (FXT-0200)
Session:  22:00-22:00
=================================================================
Parameters: SkipEarlyLateHours=1


Summary
-------
File:              EURUSD1.hst  (3,164 kB)
First bar:         Thu, 28.03.2013 18:04
Last bar:          Fri, 07.06.2013 23:38
Total bars:        73,623
Missing bars:      90 (0.1%)

Digits:            5
First price:       1.2831'4
High price:        1.3305'5   (Thu, 06.06.2013 19:25)
Low price:         1.2745'0   (Thu, 04.04.2013 15:45)
Last price:        1.3222'5
Max bar range:     169.2 pip  (Fri, 03.05.2013 15:30)

Max tick gap:      11.9 pip   (Fri, 29.03.2013 20:38  ->                  20:39)
Max total gap:     211.9 pip  (Fri, 28.09.2012 20:00  ->  Mon, 01.10.2012 04:00)
Largest time hole: 0:09 h     (Fri, 28.09.2012 20:00  ->  Mon, 01.10.2012 04:00)


32 time holes between bars (skipping early/late hours)
------------------------------------------------------
Fri, 29.03.2013 20:38  ->  Thu, 16.05.2013 20:39  (0:01 h)
Mon, 01.04.2013 02:27  ->                  02:28  (0:01 h)
Mon, 01.04.2013 16:47  ->                  16:48  (0:01 h)
Thu, 04.04.2013 08:53  ->                  08:57  (0:04 h)
Fri, 05.04.2013 10:48  ->                  10:54  (0:06 h)
Thu, 18.04.2013 00:22  ->                  00:23  (0:01 h)
Fri, 19.04.2013 01:49  ->                  01:51  (0:02 h)
Fri, 19.04.2013 02:00  ->                  02:06  (0:06 h)
Tue, 23.04.2013 00:30  ->                  00:31  (0:01 h)
Tue, 23.04.2013 00:45  ->                  00:48  (0:03 h)
*/

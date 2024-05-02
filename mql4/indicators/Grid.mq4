/**
 * Chart grid
 *
 *
 * Notes:
 *  @see  https://stackoverflow.com/questions/68375674/how-to-get-scaling-aware-window-size-using-winapi#                              [Get scaling-aware window size]
 *  @see  https://gist.github.com/marler8997/9f39458d26e2d8521d48e36530fbb459#                                                          [Win32DPI and monitor scaling]
 *  @see  https://cplusplus.com/forum/windows/285609/#                                                           [Get desktop dimensions while DPI scaling is enabled]
 *  @see  https://stackoverflow.com/questions/5977445/how-to-get-windows-display-settings#                                              [How to get Win7 scale factor]
 *  @see  https://www.reddit.com/r/Windows10/comments/3lolnr/why_is_dpi_scaling_on_windows_7_better_than_on/?rdt=56415#  [Why is DPI scaling on W7 better than on W10]
 *  @see  https://forums.mydigitallife.net/threads/solved-windows-10-higher-dpi-win8dpiscaling-problem.62528/
 *  @see  https://www.reddit.com/r/buildapc/comments/5v8pcd/rwindows10_wasnt_very_friendly_but_does_anyone/#              [Disable W10 DPI scaling for an application]
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern bool  DrawPriceGrid               = false;
extern int   PriceGrid.MinDistance.Pixel = 30;
extern bool  DoDebug                     = false;

extern color Color.RegularGrid           = Gainsboro;      // C'220,220,220'
extern color Color.SuperGrid             = LightGray;      // C'211,211,211' (slightly darker)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/ObjectCreateRegister.mqh>
#include <win32api.mqh>

#property indicator_chart_window
#property indicator_buffers      1
#property indicator_color1       CLR_NONE

double lastChartHeight;
double lastMinPrice;
double lastMaxPrice;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.RegularGrid = GetConfigColor(indicator, "Color.RegularGrid", Color.RegularGrid);
   if (AutoConfiguration) Color.SuperGrid   = GetConfigColor(indicator, "Color.SuperGrid",   Color.SuperGrid);

   if (Color.RegularGrid == 0xFF000000) Color.RegularGrid = CLR_NONE;
   if (Color.SuperGrid   == 0xFF000000) Color.SuperGrid   = CLR_NONE;

   SetIndicatorOptions();
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (!ValidBars) SetIndicatorOptions();

   if (__isChart) {
      UpdateHorizontalGrid();
      if (ChangedBars > 2) UpdateVerticalGrid();
   }
   return(last_error);
}


/**
 * Update the horizontal grid (price separators).
 *
 * @return bool - success status
 */
bool UpdateHorizontalGrid() {
   if (!DrawPriceGrid) return(true);

   int hChartWnd = __ExecutionContext[EC.hChartWindow];
   if (!IsWindowVisible(hChartWnd)) {
      if (DoDebug) debug("UpdateHorizontalGrid(0.1)  Tick="+ Ticks +"  skip => IsVisible=0");
      return(true);
   }

   if (IsIconic(hChartWnd)) {
      if (DoDebug) debug("UpdateHorizontalGrid(0.2)  Tick="+ Ticks +"  skip => IsIconic=1");
      return(true);
   }

   int hChart = __ExecutionContext[EC.hChart], rect[RECT_size];
   if (!GetWindowRect(hChart, rect)) return(!catch("UpdateHorizontalGrid(1)->GetWindowRect()", ERR_WIN32_ERROR+GetLastWin32Error()));
   int chartHeight = rect[RECT.bottom]-rect[RECT.top];
   if (!chartHeight) {                                         // view port resized to zero height
      if (DoDebug) debug("UpdateHorizontalGrid(0.3)  Tick="+ Ticks +"  skip => chartHeight=0");
      return(true);
   }

   double minPrice = WindowPriceMin();
   double maxPrice = WindowPriceMax();
   if (!minPrice || !maxPrice) {                               // chart not yet ready
      if (DoDebug) debug("UpdateHorizontalGrid(0.4)  Tick="+ Ticks +"  skip => minPrice=0  maxPrice=0");
      return(true);
   }

   double chartRange = NormalizeDouble(maxPrice-minPrice, Digits);
   if (chartRange <= 0) {                                      // chart with ScaleFix=1 after resizing to zero height
      if (DoDebug) debug("UpdateHorizontalGrid(0.5)  Tick="+ Ticks +"  skip => chartRange="+ NumberToStr(chartRange, ".+") +"  (min="+ NumberToStr(minPrice, PriceFormat) +"  max="+ NumberToStr(maxPrice, PriceFormat) +")");
      return(true);
   }

   if (chartHeight!=lastChartHeight || minPrice!=lastMinPrice || maxPrice!=lastMaxPrice) {
      double separators = 1.*chartHeight/PriceGrid.MinDistance.Pixel;
      double separatorRange = chartRange/separators;
      double gridBase = MathPow(10, MathFloor(MathLog10(separatorRange))), gridSize;

      static int multiples[] = {2, 5, 10};
      for (int i, size=ArraySize(multiples); i < size; i++) {
         gridSize = multiples[i] * gridBase;
         if (gridSize > separatorRange) break;
      }
      gridSize = NormalizeDouble(gridSize, Digits);

      debug("UpdateHorizontalGrid(0.6)  Tick="+ Ticks +"  height="+ chartHeight +"  range="+ DoubleToStr(chartRange/pUnit, pDigits) +" "+ spUnit
                                                      +" => "+ Round(separators) +" seps"
                                                      +" => gridSize: "+ DoubleToStr(gridSize/pUnit, pDigits) +" "+ spUnit);
      // calculate and draw grid levels
      double fromPrice = minPrice - gridSize;
      double toPrice   = maxPrice + gridSize;
      double gridLevel = fromPrice - MathMod(fromPrice, gridSize);

      while (gridLevel < toPrice) {
         if (DoDebug) debug("UpdateHorizontalGrid(0.7)  gridLevel="+ NumberToStr(gridLevel, PriceFormat));

         string label = NumberToStr(gridLevel, ",'R.+");
         if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_HLINE, 0, 0, 0, 0, 0, 0, 0)) return(false);
         ObjectSet(label, OBJPROP_STYLE,  STYLE_DOT);
         ObjectSet(label, OBJPROP_COLOR,  Color.RegularGrid);
         ObjectSet(label, OBJPROP_PRICE1, gridLevel);
         ObjectSet(label, OBJPROP_BACK,   true);

         gridLevel += gridSize;
      }

      lastChartHeight = chartHeight;
      lastMinPrice    = minPrice;
      lastMaxPrice    = maxPrice;
   }
   return(!catch("UpdateHorizontalGrid(2)"));

   // a separator every multiple of 1, 2, 5...
   // ----------------------------------------
   // a separator every 0.0001 units   1 * 10 ^ -4     1 pip
   // a separator every 0.001 units    1 * 10 ^ -3
   // a separator every 0.01 units     1 * 10 ^ -2
   // a separator every 0.1 units      1 * 10 ^ -1
   // a separator every 1 unit         1 * 10 ^  0
   // a separator every 10 units       1 * 10 ^ +1
   // a separator every 100 units      1 * 10 ^ +2
   // a separator every 1000 units     1 * 10 ^ +3
   // a separator every 10000 units    1 * 10 ^ +4
}


/**
 * Update the vertical grid (date/time separators).
 *
 * @return bool - success status
 */
bool UpdateVerticalGrid() {
   datetime firstWeekDay, separatorTime, chartTime, lastChartTime;
   int      dow, dd, mm, yyyy, bar, sepColor, sepStyle;
   string   label="", lastLabel="";

   // Zeitpunkte des ältesten und jüngsten Separators berechen
   datetime fromFXT = GetNextSessionStartTime(ServerToFxtTime(Time[Bars-1]) - 1*SECOND, TZ_FXT);
   datetime toFXT   = GetNextSessionStartTime(ServerToFxtTime(Time[0]),                 TZ_FXT);

   // Tagesseparatoren
   if (Period() < PERIOD_H4) {
      //fromFXT = ...                                                         // fromFXT bleibt unverändert
      //toFXT   = ...                                                         // toFXT bleibt unverändert
   }

   // Wochenseparatoren
   else if (Period() == PERIOD_H4) {
      fromFXT += (8-TimeDayOfWeekEx(fromFXT))%7 * DAYS;                       // fromFXT ist der erste Montag
      toFXT   += (8-TimeDayOfWeekEx(toFXT))%7 * DAYS;                         // toFXT ist der nächste Montag
   }

   // Monatsseparatoren
   else if (Period() == PERIOD_D1) {
      yyyy = TimeYearEx(fromFXT);                                             // fromFXT ist der erste Wochentag des ersten vollen Monats
      mm   = TimeMonth(fromFXT);
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm);

      if (firstWeekDay < fromFXT) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm+1);
      }
      fromFXT = firstWeekDay;
      // ------------------------------------------------------
      yyyy = TimeYearEx(toFXT);                                               // toFXT ist der erste Wochentag des nächsten Monats
      mm   = TimeMonth(toFXT);
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm);

      if (firstWeekDay < toFXT) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy, mm+1);
      }
      toFXT = firstWeekDay;
   }

   // Jahresseparatoren
   else if (Period() > PERIOD_D1) {
      yyyy = TimeYearEx(fromFXT);                                             // fromFXT ist der erste Wochentag des ersten vollen Jahres
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, 1);
      if (firstWeekDay < fromFXT)
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy+1, 1);
      fromFXT = firstWeekDay;
      // ------------------------------------------------------
      yyyy = TimeYearEx(toFXT);                                               // toFXT ist der erste Wochentag des nächsten Jahres
      firstWeekDay = GetFirstWeekdayOfMonth(yyyy, 1);
      if (firstWeekDay < toFXT)
         firstWeekDay = GetFirstWeekdayOfMonth(yyyy+1, 1);
      toFXT = firstWeekDay;
   }

   // Separatoren zeichnen
   for (datetime time=fromFXT; time <= toFXT; time+=1*DAY) {
      separatorTime = FxtToServerTime(time);
      dow           = TimeDayOfWeekEx(time);

      // Bar und Chart-Time des Separators ermitteln
      if (Time[0] < separatorTime) {                                          // keine entsprechende Bar: aktuelle Session oder noch laufendes ERS_HISTORY_UPDATE
         bar = -1;
         chartTime = separatorTime;                                           // ursprüngliche Zeit verwenden
         if (dow == MONDAY)
            chartTime -= 2*DAYS;                                              // bei zukünftigen Separatoren Wochenenden von Hand "kollabieren" TODO: Bug bei Periode > H4
      }
      else {                                                                  // Separator liegt innerhalb der Bar-Range, Zeit der ersten existierenden Bar verwenden
         bar = iBarShiftNext(NULL, NULL, separatorTime);
         if (bar == EMPTY_VALUE) return(false);
         chartTime = Time[bar];
      }

      // Label des Separators zusammenstellen (ie. "Fri 23.12.2011")
      label = TimeToStr(time);
      label = StringConcatenate(GmtTimeFormat(time, "%a"), " ", StringSubstr(label, 8, 2), ".", StringSubstr(label, 5, 2), ".", StringSubstr(label, 0, 4));

      if (lastChartTime == chartTime) ObjectDelete(lastLabel);                // Bars der vorherigen Periode fehlen (noch laufendes ERS_HISTORY_UPDATE oder Kurslücke)
                                                                              // Separator für die fehlende Periode wieder löschen
      // Separator zeichnen
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_VLINE, 0, chartTime, 0, 0, 0, 0, 0)) return(false);
      sepStyle = STYLE_DOT;
      sepColor = Color.RegularGrid;
      if (Period() < PERIOD_H4) {
         if (dow == MONDAY) {
            sepStyle = STYLE_DASHDOTDOT;
            sepColor = Color.SuperGrid;
         }
      }
      else if (Period() == PERIOD_H4) {
         sepStyle = STYLE_DASHDOTDOT;
         sepColor = Color.SuperGrid;
      }
      ObjectSet(label, OBJPROP_STYLE, sepStyle);
      ObjectSet(label, OBJPROP_COLOR, sepColor);
      ObjectSet(label, OBJPROP_BACK,  true);
      lastChartTime = chartTime;
      lastLabel     = label;                                                  // Daten des letzten Separators für Lückenerkennung merken

      // je nach Periode einen Tag *vor* den nächsten Separator springen
      // Tagesseparatoren
      if (Period() < PERIOD_H4) {
         if (dow == FRIDAY)                                                   // Wochenenden überspringen
            time += 2*DAYS;
      }
      // Wochenseparatoren
      else if (Period() == PERIOD_H4) {
         time += 6*DAYS;                                                      // TimeDayOfWeek(time) == MONDAY
      }
      // Monatsseparatoren
      else if (Period() == PERIOD_D1) {                                       // erster Wochentag des Monats
         yyyy = TimeYearEx(time);
         mm   = TimeMonth(time);
         if (mm == 12) { yyyy++; mm = 0; }
         time = GetFirstWeekdayOfMonth(yyyy, mm+1) - 1*DAY;
      }
      // Jahresseparatoren
      else if (Period() > PERIOD_D1) {                                        // erster Wochentag des Jahres
         yyyy = TimeYearEx(time);
         time = GetFirstWeekdayOfMonth(yyyy+1, 1) - 1*DAY;
      }
   }
   return(!catch("UpdateVerticalGrid(2)"));
}


/**
 * Ermittelt den ersten Wochentag eines Monats.
 *
 * @param  int year  - Jahr (1970 bis 2037)
 * @param  int month - Monat
 *
 * @return datetime - erster Wochentag des Monats oder EMPTY (-1), falls ein Fehler auftrat
 */
datetime GetFirstWeekdayOfMonth(int year, int month) {
   if (year  < 1970 || 2037 < year ) return(_EMPTY(catch("GetFirstWeekdayOfMonth(1)  illegal parameter year: "+ year +" (not between 1970 and 2037)", ERR_INVALID_PARAMETER)));
   if (month <    1 ||   12 < month) return(_EMPTY(catch("GetFirstWeekdayOfMonth(2)  invalid parameter month: "+ month, ERR_INVALID_PARAMETER)));

   datetime firstDayOfMonth = StrToTime(StringConcatenate(year, ".", StrRight("0"+month, 2), ".01 00:00:00"));

   int dow = TimeDayOfWeekEx(firstDayOfMonth);
   if (dow == SATURDAY) return(firstDayOfMonth + 2*DAYS);
   if (dow == SUNDAY  ) return(firstDayOfMonth + 1*DAY );

   return(firstDayOfMonth);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);
   SetIndexStyle(0, DRAW_NONE);
   SetIndexLabel(0, NULL);
   IndicatorShortName("");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("DrawPriceGrid=",               BoolToStr(DrawPriceGrid),      ";", NL,
                            "PriceGrid.MinDistance.Pixel=", PriceGrid.MinDistance.Pixel,   ";", NL,
                            "Color.RegularGrid=",           ColorToStr(Color.RegularGrid), ";", NL,
                            "Color.SuperGrid=",             ColorToStr(Color.SuperGrid),   ";")
   );
}

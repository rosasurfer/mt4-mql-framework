/**
 * Chart grid
 *
 * Dynamically maintains horizontal (price) and vertical (date/time) chart separators.
 */
#include <stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int   PriceGrid.MinDistance.Pixel     = 40;
extern bool  EnableGridBase_20               = true;           // FALSE=multiples(10, 50); TRUE=multiples(10, 20, 50)

extern string ___a__________________________ = "";
extern color Color.RegularGrid               = Gainsboro;      // C'220,220,220'
extern color Color.SuperGrid                 = LightGray;      // C'211,211,211' (slightly darker)

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

int    lastChartHeight;
double lastChartMinPrice;
double lastChartMaxPrice;
double lastGridSize;
int    lastGridBase;

string hSeparatorLabels[];       // horizontal separator labels
double hSeparatorLevels[];       // horizontal separator levels


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // validate inputs
   string indicator = WindowExpertName();

   // PriceGrid.MinDistance.Pixel
   if (AutoConfiguration) PriceGrid.MinDistance.Pixel = GetConfigInt(indicator, "PriceGrid.MinDistance.Pixel", PriceGrid.MinDistance.Pixel);
   if (PriceGrid.MinDistance.Pixel < 1) return(catch("onInit(1)  invalid input parameter PriceGrid.MinDistance.Pixel: "+ PriceGrid.MinDistance.Pixel, ERR_INVALID_INPUT_PARAMETER));
   // EnableGridBase_20
   if (AutoConfiguration) EnableGridBase_20 = GetConfigBool(indicator, "EnableGridBase_20", EnableGridBase_20);

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.RegularGrid = GetConfigColor(indicator, "Color.RegularGrid", Color.RegularGrid);
   if (AutoConfiguration) Color.SuperGrid   = GetConfigColor(indicator, "Color.SuperGrid",   Color.SuperGrid);
   if (Color.RegularGrid == 0xFF000000) Color.RegularGrid = CLR_NONE;
   if (Color.SuperGrid   == 0xFF000000) Color.SuperGrid   = CLR_NONE;

   SetIndicatorOptions();
   return(catch("onInit(2)"));
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
   int chartHeight;
   double minPrice, maxPrice;
   if (!GetHorizontalDimensions(chartHeight, minPrice, maxPrice)) return(!last_error);

   // nothing to do if chart dimensions unchanged
   if (chartHeight==lastChartHeight && minPrice==lastChartMinPrice && maxPrice==lastChartMaxPrice) return(true);

   // recalculate grid size
   double gridSize = ComputeGridSize(chartHeight, minPrice, maxPrice);
   if (!gridSize) return(false);

   // update the grid
   if (gridSize != lastGridSize) {                       // this includes first use (!lastGridSize)
      if (!RemovePriceSeparators()) return(false);

      double priceRange = maxPrice - minPrice;
      double fromPrice  = minPrice - 4*priceRange;       // cover 3 times of the view port to both sides (for fast chart moves)
      double toPrice    = maxPrice + 4*priceRange;
      if (!CreatePriceSeparators(fromPrice, toPrice, gridSize)) return(false);
   }
   else /*gridSize == lastGridSize*/ {
      // TODO: check whether existing price separators cover the view port
   }

   lastChartHeight   = chartHeight;
   lastChartMinPrice = minPrice;
   lastChartMaxPrice = maxPrice;
   lastGridSize      = gridSize;
   lastGridBase      = MathRound(gridSize / MathPow(10, MathFloor(MathLog10(gridSize))));    // 1 | 2 | 5
   return(!catch("UpdateHorizontalGrid(1)"));
}


/**
 * Compute horizontal chart dimensions.
 *
 * @param  _Out_ int    chartHeight   - variable receiving the chart height in pixel
 * @param  _Out_ double chartMinPrice - variable receiving the min chart price
 * @param  _Out_ double chartMaxPrice - variable receiving the max chart price
 *
 * @return bool - success status; FALSE if there's no visible chart
 */
bool GetHorizontalDimensions(int &chartHeight, double &chartMinPrice, double &chartMaxPrice) {
   chartHeight   = 0;
   chartMinPrice = 0;
   chartMaxPrice = 0;

   static bool lastIsWindowVisible=true, lastIsIconic=false, lastIsWindowAreaVisible=true, lastIsHeight=true, lastIsPrice=true, lastIsPriceRange=true;
   bool isLogDebug = IsLogDebug();

   int hChartWnd = __ExecutionContext[EC.hChartWindow];
   if (!IsWindowVisible(hChartWnd)) {
      if (lastIsWindowVisible && isLogDebug) logDebug("GetHorizontalDimensions(1)  Tick="+ Ticks +"  skip (IsWindowVisible=0)");
      lastIsWindowVisible = false;
      return(false);
   }
   lastIsWindowVisible = true;

   if (IsIconic(hChartWnd)) {
      if (!lastIsIconic && isLogDebug) logDebug("GetHorizontalDimensions(2)  Tick="+ Ticks +"  skip (IsIconic=1)");
      lastIsIconic = true;
      return(false);
   }
   lastIsIconic = false;

   if (!IsWindowAreaVisible(hChartWnd)) {
      if (lastIsWindowAreaVisible && isLogDebug) logDebug("GetHorizontalDimensions(3)  Tick="+ Ticks +"  skip (IsWindowAreaVisible=0)");
      lastIsWindowAreaVisible = false;
      return(false);
   }
   lastIsWindowAreaVisible = true;

   int hChart = __ExecutionContext[EC.hChart], rect[RECT_size];
   if (!GetWindowRect(hChart, rect)) return(!catch("GetHorizontalDimensions(4)->GetWindowRect()", ERR_WIN32_ERROR+GetLastWin32Error()));
   int height = rect[RECT.bottom]-rect[RECT.top];
   if (!height) {                                              // view port resized to zero height
      if (lastIsHeight && isLogDebug) logDebug("GetHorizontalDimensions(5)  Tick="+ Ticks +"  skip (chartHeight=0)");
      lastIsHeight = false;
      return(false);
   }
   lastIsHeight = true;

   double minPrice = NormalizeDouble(WindowPriceMin(), Digits);
   double maxPrice = NormalizeDouble(WindowPriceMax(), Digits);
   if (!minPrice || !maxPrice) {                               // chart not yet ready
      if (lastIsPrice && isLogDebug) logDebug("GetHorizontalDimensions(6)  Tick="+ Ticks +"  skip (minPrice=0, maxPrice=0)");
      lastIsPrice = false;
      return(false);
   }
   lastIsPrice = true;

   double priceRange = NormalizeDouble(maxPrice - minPrice, Digits);
   if (priceRange <= 0) {                                      // chart with ScaleFix=1 after resizing to zero height
      if (lastIsPriceRange && isLogDebug) logDebug("GetHorizontalDimensions(7)  Tick="+ Ticks +"  skip (priceRange="+ NumberToStr(priceRange, ".+") +", min="+ NumberToStr(minPrice, PriceFormat) +", max="+ NumberToStr(maxPrice, PriceFormat) +")");
      lastIsPriceRange = false;
      return(false);
   }
   lastIsPriceRange = true;

   chartHeight   = height;
   chartMinPrice = minPrice;
   chartMaxPrice = maxPrice;
   return(true);
}


/**
 * Compute the horizontal grid size (distance between price separators).
 *
 * @param  int    chartHeight   - chart height in pixel
 * @param  double chartMinPrice - min chart price
 * @param  double chartMaxPrice - max chart price
 *
 * @return double - distance between price separators or NULL in case of errors
 */
double ComputeGridSize(int chartHeight, double chartMinPrice, double chartMaxPrice) {
   double separators     = 1.*chartHeight / PriceGrid.MinDistance.Pixel;
   double priceRange     = chartMaxPrice - chartMinPrice;
   double separatorRange = priceRange / separators;
   double baseSize       = MathPow(10, MathFloor(MathLog10(separatorRange))), gridSize;

   static int multiples[] = {2, 5, 10};
   int size = ArraySize(multiples);
   int startAt = ifInt(EnableGridBase_20, 0, 1);

   for (int i=startAt; i < size; i++) {
      gridSize = multiples[i] * baseSize;
      if (gridSize > separatorRange) break;
   }
   gridSize = NormalizeDouble(gridSize, Digits);
   if (IsLogDebug()) logDebug("ComputeGridSize(0.1)  Tick="+ Ticks +"  height="+ chartHeight +"  range="+ DoubleToStr(priceRange/pUnit, pDigits) +" => grid("+ (multiples[i] % 9) +") = "+ DoubleToStr(gridSize/pUnit, pDigits));

   return(gridSize);

   // a separator every multiple of 1 * 10^n
   // --------------------------------------
   // a separator every 0.0001 units   1 * 10 ^ -4     1 pip
   // a separator every 0.001 units    1 * 10 ^ -3
   // a separator every 0.01 units     1 * 10 ^ -2
   // a separator every 0.1 units      1 * 10 ^ -1
   // a separator every 1 unit         1 * 10 ^  0
   // a separator every 10 units       1 * 10 ^ +1
   // a separator every 100 units      1 * 10 ^ +2
   // a separator every 1000 units     1 * 10 ^ +3
   // a separator every 10000 units    1 * 10 ^ +4


   // a separator every multiple of 2 * 10^n
   // --------------------------------------
   // a separator every 0.0002 units   2 * 10 ^ -4     2 pip
   // a separator every 0.002 units    2 * 10 ^ -3
   // a separator every 0.02 units     2 * 10 ^ -2
   // a separator every 0.2 units      2 * 10 ^ -1
   // a separator every 2 units        2 * 10 ^  0
   // a separator every 20 units       2 * 10 ^ +1
   // a separator every 200 units      2 * 10 ^ +2
   // a separator every 2000 units     2 * 10 ^ +3
   // a separator every 20000 units    2 * 10 ^ +4


   // a separator every multiple of 5 * 10^n
   // --------------------------------------
   // a separator every 0.0005 units   5 * 10 ^ -4     5 pip
   // a separator every 0.005 units    5 * 10 ^ -3
   // a separator every 0.05 units     5 * 10 ^ -2
   // a separator every 0.5 units      5 * 10 ^ -1
   // a separator every 5 units        5 * 10 ^  0
   // a separator every 50 units       5 * 10 ^ +1
   // a separator every 500 units      5 * 10 ^ +2
   // a separator every 5000 units     5 * 10 ^ +3
   // a separator every 50000 units    5 * 10 ^ +4
}


/**
 * Remove all existing price separators (horizontal grid).
 *
 * @return bool - success status
 */
bool RemovePriceSeparators() {
   int size = ArraySize(hSeparatorLabels);

   for (int i=0; i < size; i++) {
      if (ObjectFind(hSeparatorLabels[i]) != -1) {
         if (!ObjectDelete(hSeparatorLabels[i])) {
            return(!catch("RemovePriceSeparators(1)->ObjectDelete(name=\""+ hSeparatorLabels[i] +"\")", intOr(GetLastError(), ERR_RUNTIME_ERROR)));
         }
      }
   }
   ArrayResize(hSeparatorLabels, 0);
   ArrayResize(hSeparatorLevels, 0);

   return(!catch("RemovePriceSeparators(2)"));
}


/**
 * Create price separators for the specified horizontal grid paramters.
 *
 * @param  double fromPrice - start price to create separators from
 * @param  double toPrice   - end price to create separators to
 * @param  double gridSize  - distance between separators
 *
 * @return bool - success status
 */
bool CreatePriceSeparators(double fromPrice, double toPrice, double gridSize) {
   double gridLevel = NormalizeDouble(fromPrice - MathMod(fromPrice, gridSize), Digits);
   int numberOfSeparators = (toPrice-gridLevel)/gridSize + 1;

   ArrayResize(hSeparatorLabels, numberOfSeparators);
   ArrayResize(hSeparatorLevels, numberOfSeparators);

   for (int i=0; gridLevel < toPrice; i++) {
      string label = NumberToStr(gridLevel, ",'R.+");
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_HLINE)) return(false);
      ObjectSet(label, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR,  Color.RegularGrid);
      ObjectSet(label, OBJPROP_PRICE1, gridLevel);
      ObjectSet(label, OBJPROP_BACK,   true);

      hSeparatorLabels[i] = label;
      hSeparatorLevels[i] = gridLevel;

      gridLevel = NormalizeDouble(gridLevel + gridSize, Digits);
   }
   if (i < numberOfSeparators) {
      ArrayResize(hSeparatorLabels, i);
      ArrayResize(hSeparatorLevels, i);
   }
   //debug("CreatePriceSeparators(0.1)  created "+ i +" separators (gridSize="+ NumberToStr(gridSize, PriceFormat) +")");

   return(!catch("CreatePriceSeparators(1)"));
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
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_VLINE, 0, chartTime, 0)) return(false);
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
   SetIndexStyle(0, DRAW_NONE, EMPTY, EMPTY, CLR_NONE);
   SetIndexLabel(0, NULL);
   IndicatorShortName("");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("PriceGrid.MinDistance.Pixel=", PriceGrid.MinDistance.Pixel,   ";", NL,
                            "EnableGridBase_20=",           BoolToStr(EnableGridBase_20),  ";", NL,

                            "Color.RegularGrid=",           ColorToStr(Color.RegularGrid), ";", NL,
                            "Color.SuperGrid=",             ColorToStr(Color.SuperGrid),   ";")
   );
}

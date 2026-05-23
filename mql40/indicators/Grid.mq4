/**
 * Chart grid
 *
 * Maintains horizontal and vertical chart separators.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    PriceGrid.MinDistance.Pixel = 40;          // adjust to your screen and DPI scaling
extern color  Color.RegularGrid           = Gainsboro;   //
extern color  Color.SuperGrid             = LightGray;   // slightly darker

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/iBarShiftNext.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/win32api.mqh>

#property indicator_chart_window

// vertical grid properties (time)
bool dailySeparators;
bool weeklySeparators;
bool monthlySeparators;
bool yearlySeparators;

// horizontal grid properties (price)
int    lastChartHeight;
double lastChartMinPrice;
double lastChartMaxPrice;
double lastGridSize;
string hSeparatorLabels[];       // labels of price separators


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   string indicator = WindowExpertName();

   // validate inputs
   // PriceGrid.MinDistance.Pixel
   if (AutoConfiguration) PriceGrid.MinDistance.Pixel = GetConfigInt(indicator, "PriceGrid.MinDistance.Pixel", PriceGrid.MinDistance.Pixel);
   if (PriceGrid.MinDistance.Pixel < 1) return(catch("onInit(1)  invalid input parameter PriceGrid.MinDistance.Pixel: "+ PriceGrid.MinDistance.Pixel, ERR_INVALID_INPUT_PARAMETER));
   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.RegularGrid = GetConfigColor(indicator, "Color.RegularGrid", Color.RegularGrid);
   if (AutoConfiguration) Color.SuperGrid   = GetConfigColor(indicator, "Color.SuperGrid",   Color.SuperGrid);
   if (Color.RegularGrid == 0xFF000000) Color.RegularGrid = CLR_NONE;
   if (Color.SuperGrid   == 0xFF000000) Color.SuperGrid   = CLR_NONE;

   // initialize the time interval for the vertical grid
   dailySeparators = false;
   weeklySeparators = false;
   monthlySeparators = false;
   yearlySeparators = false;

   if      (Period() <  PERIOD_H4) dailySeparators = true;
   else if (Period() == PERIOD_H4) weeklySeparators = true;
   else if (Period() == PERIOD_D1) monthlySeparators = true;
   else                            yearlySeparators = true;

   return(catch("onInit(2)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeletePriceSeparators();
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   if (__isChart) {
      UpdateHorizontalGrid();
      if (ChangedBars > 2) {
         UpdateVerticalGrid();
      }
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

   if (!GetHorizontalChartDimensions(chartHeight, minPrice, maxPrice)) return(!last_error);

   // nothing to do if chart dimensions are unchanged
   if (chartHeight==lastChartHeight && minPrice==lastChartMinPrice && maxPrice==lastChartMaxPrice) return(true);

   // recalculate grid size
   double gridSize = ComputeHorizontalGridSize(chartHeight, minPrice, maxPrice);
   if (!gridSize) return(false);

   // update the grid
   if (gridSize != lastGridSize) {                       // this includes first use: !lastGridSize
      if (!DeletePriceSeparators()) return(false);

      double priceRange = maxPrice - minPrice;
      double fromPrice  = minPrice - 4*priceRange;       // cover 4 times of the view port on both sides (for fast chart moves)
      double toPrice    = maxPrice + 4*priceRange;
      if (!CreatePriceSeparators(fromPrice, toPrice, gridSize)) return(false);
   }
   else /*gridSize == lastGridSize*/ {
      // TODO: check whether existing separators cover the view port
   }

   lastChartHeight   = chartHeight;
   lastChartMinPrice = minPrice;
   lastChartMaxPrice = maxPrice;
   lastGridSize      = gridSize;
   return(!catch("UpdateHorizontalGrid(1)"));
}


/**
 * Get current horizontal chart dimensions.
 *
 * @param  _Out_ int    chartHeight   - variable receiving the current chart height in pixel
 * @param  _Out_ double chartMinPrice - variable receiving the current minimum chart price
 * @param  _Out_ double chartMaxPrice - variable receiving the current maximum chart price
 *
 * @return bool - success status; FALSE if there's currently no visible chart
 */
bool GetHorizontalChartDimensions(int &chartHeight, double &chartMinPrice, double &chartMaxPrice) {
   chartHeight   = 0;
   chartMinPrice = 0;
   chartMaxPrice = 0;

   int height = Grid_GetChartHeight(__ExecutionContext[EC.chart], lastChartHeight);
   if (!height) return(false);                                 // no visible chart

   double minPrice = NormalizeDouble(WindowPriceMin(), Digits);
   double maxPrice = NormalizeDouble(WindowPriceMax(), Digits);
   if (!minPrice || !maxPrice) return(false);                  // chart not yet ready

   if (maxPrice-minPrice < HalfPoint) return(false);           // chart with ScaleFix=1 after resizing to zero height

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
double ComputeHorizontalGridSize(int chartHeight, double chartMinPrice, double chartMaxPrice) {
   double separators     = 1.*chartHeight / PriceGrid.MinDistance.Pixel;
   double priceRange     = chartMaxPrice - chartMinPrice;
   double separatorRange = priceRange / separators;
   double baseSize       = MathPow(10, MathFloor(MathLog10(separatorRange)));

   double gridSize = 5 * baseSize;
   if (gridSize < separatorRange) {
      gridSize *= 2;
   }
   gridSize = NormalizeDouble(gridSize, Digits);

   if (IsLogDebug()) logDebug("ComputeHorizontalGridSize(0.1)  Tick="+ Ticks +"  height="+ chartHeight +"  range="+ DoubleToStr(priceRange/pUnit, pDigits) +" => grid = "+ DoubleToStr(gridSize/pUnit, pDigits));
   return(gridSize);

   // a separator every multiple of 1 * 10^n
   // --------------------------------------
   // a separator every 0.0001 units   1 * 10 ^ -4    1 pip
   // a separator every 0.001 units    1 * 10 ^ -3
   // a separator every 0.01 units     1 * 10 ^ -2
   // a separator every 0.1 units      1 * 10 ^ -1
   // a separator every 1 unit         1 * 10 ^  0
   // a separator every 10 units       1 * 10 ^ +1
   // a separator every 100 units      1 * 10 ^ +2
   // a separator every 1000 units     1 * 10 ^ +3
   // a separator every 10000 units    1 * 10 ^ +4


   // a separator every multiple of 2 * 10^n (not used anymore)
   // ---------------------------------------------------------
   // a separator every 0.0002 units   2 * 10 ^ -4    2 pip
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
   // a separator every 0.0005 units   5 * 10 ^ -4    5 pip
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
 * Create price separators for the specified parameters.
 *
 * @param  double fromPrice - start price to create separators from
 * @param  double toPrice   - end price to create separators to
 * @param  double gridSize  - distance between separators
 *
 * @return bool - success status
 */
bool CreatePriceSeparators(double fromPrice, double toPrice, double gridSize) {
   double gridLevel = NormalizeDouble(fromPrice - MathMod(fromPrice, gridSize), Digits);

   int separators = (toPrice-gridLevel)/gridSize + 1;
   ArrayResize(hSeparatorLabels, separators);

   for (int i=0; i < separators; i++) {                     // no ObjectCreateRegister(): price separators change dynamically
      string label = NumberToStr(gridLevel, ",'R.+");       // and are handled better by the indicator itself
      if (ObjectFind(label) == -1) if (!ObjectCreate(label, OBJ_HLINE, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR,  Color.RegularGrid);
      ObjectSet(label, OBJPROP_PRICE1, gridLevel);
      ObjectSet(label, OBJPROP_BACK,   true);

      hSeparatorLabels[i] = label;

      gridLevel = NormalizeDouble(gridLevel + gridSize, Digits);
   }
   return(!catch("CreatePriceSeparators(1)"));
}


/**
 * Delete all price separators.
 *
 * @return bool - success status
 */
bool DeletePriceSeparators() {
   int size = ArraySize(hSeparatorLabels);

   for (int i=0; i < size; i++) {
      if (ObjectFind(hSeparatorLabels[i]) != -1) {
         ObjectDelete(hSeparatorLabels[i]);
      }
   }
   ArrayResize(hSeparatorLabels, 0);
   return(!catch("DeletePriceSeparators(1)"));
}


/**
 * Update the vertical grid (time separators). Draws separators from the first visible (oldest) separator location
 * in the chart to the first separator location in the future. The future separator aids as a guide for the end of
 * the most recent grid period.
 *
 * @return bool - success status
 */
bool UpdateVerticalGrid() {
   // compute the time range to cover: from oldest visible to first future separator
   datetime fromSepTime = GetNextSessionStartTime(ServerToFxtTime(Time[Bars-1]) - 1*SECOND, TZ_FXT);
   datetime toSepTime   = GetNextSessionStartTime(ServerToFxtTime(Time[0]), TZ_FXT), firstWeekday;
   if (fromSepTime==NaT || toSepTime==NaT) return(false);

   int yyyy, mm;

   if (dailySeparators) {
      // nothing to do
   }
   else if (weeklySeparators) {
      fromSepTime += (8 - TimeDayOfWeekEx(fromSepTime)) % 7 * DAYS;  // first Monday in the chart
      toSepTime   += (8 - TimeDayOfWeekEx(toSepTime  )) % 7 * DAYS;  // next Monday in the future
   }
   else if (monthlySeparators) {
      yyyy = TimeYearEx(fromSepTime);
      mm   = TimeMonth(fromSepTime);
      firstWeekDay = ComputeFirstWeekDay(yyyy, mm);
      if (firstWeekDay < fromSepTime) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = ComputeFirstWeekDay(yyyy, mm+1);
      }
      fromSepTime = firstWeekDay;                           // first "first weekday of a month" in the chart

      yyyy = TimeYearEx(toSepTime);
      mm   = TimeMonth(toSepTime);
      firstWeekDay = ComputeFirstWeekDay(yyyy, mm);
      if (firstWeekDay < toSepTime) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstWeekDay = ComputeFirstWeekDay(yyyy, mm+1);
      }
      toSepTime = firstWeekDay;                             // next "first weekday of a month" in the future
   }
   else if (yearlySeparators) {
      yyyy = TimeYearEx(fromSepTime);
      firstWeekDay = ComputeFirstWeekDay(yyyy, 1);
      if (firstWeekDay < fromSepTime) {
         firstWeekDay = ComputeFirstWeekDay(yyyy+1, 1);
      }
      fromSepTime = firstWeekDay;                           // first "first weekday of a year" in the chart

      yyyy = TimeYearEx(toSepTime);
      firstWeekDay = ComputeFirstWeekDay(yyyy, 1);
      if (firstWeekDay < toSepTime) {
         firstWeekDay = ComputeFirstWeekDay(yyyy+1, 1);
      }
      toSepTime = firstWeekDay;                             // next "first weekday of a year" in the future
   }
   else return(!catch("UpdateVerticalGrid(1)  illegal vertical grid state (no enabled grid interval)", ERR_ILLEGAL_STATE));

   datetime sepTime, sepChartTime, lastSepChartTime;
   int dow, bar;
   string label = "", lastSepLabel = "";

   // create all separators
   for (datetime time=fromSepTime; time <= toSepTime; time = ComputeNextSeparatorTime(time, dow)) {
      sepTime = FxtToServerTime(time);
      dow     = TimeDayOfWeekEx(time);

      // resolve bar and chart time of the separator
      if (Time[0] < sepTime) {                              // no such bar yet: current session or in ERS_HISTORY_UPDATE
         sepChartTime = sepTime;                            // use original time
         if (dow == MONDAY) {
            sepChartTime -= 2*DAYS;                         // on future separator: "collaps" weekends
         }                                                  // TODO: bug with monthlySeparators/yearlySeparators
      }
      else {
         bar = iBarShiftNext(NULL, NULL, sepTime);          // use time of first existing bar
         if (bar == EMPTY_VALUE) return(false);
         sepChartTime = Time[bar];
      }
      if (sepChartTime == lastSepChartTime) {               // bar gap or in ERS_HISTORY_UPDATE
         ObjectDelete(lastSepLabel);                        // keep the most recent separator only
      }

      // create new separator
      label = GmtTimeFormat(time, "%a %d.%m.%Y");           // e.g. "Fri 23.12.2011"
      if (ObjectFind(label) == -1) if (!ObjectCreateRegister(label, OBJ_VLINE, 0, sepChartTime, 0)) return(false);
      int   sepStyle = STYLE_DOT;
      color sepColor = Color.RegularGrid;
      if (dailySeparators) {
         if (dow == MONDAY) {
            sepStyle = STYLE_DASHDOTDOT;                    // a slightly different style for the start of week
            sepColor = Color.SuperGrid;
         }
      }
      else if (weeklySeparators) {
         sepStyle = STYLE_DASHDOTDOT;                       // same different style for every week
         sepColor = Color.SuperGrid;
      }
      ObjectSet(label, OBJPROP_STYLE, sepStyle);
      ObjectSet(label, OBJPROP_COLOR, sepColor);
      ObjectSet(label, OBJPROP_BACK,  true);
      lastSepLabel     = label;
      lastSepChartTime = sepChartTime;                      // store last separator location for gap detection
   }
   return(!catch("UpdateVerticalGrid(2)"));
}


/**
 * Computes the first weekday of a month.
 *
 * @param  int year  - supported values: 1970-2037
 * @param  int month - supported values: 1-12
 *
 * @return datetime - 00:00 (Midnight) of the first weekday of a month or EMPTY (-1) in case of errors
 */
datetime ComputeFirstWeekDay(int year, int month) {
   if (year < 1970 || year > 2037) return(_EMPTY(catch("ComputeFirstWeekDay(1)  illegal parameter year: "+ year +" (out of range)", ERR_INVALID_PARAMETER)));
   if (month < 1 || month > 12)    return(_EMPTY(catch("ComputeFirstWeekDay(2)  invalid parameter month: "+ month +" (out of range)", ERR_INVALID_PARAMETER)));

   datetime firstDayOfMonth = StrToTime(StringConcatenate(year, ".", StrRight("0"+month, 2), ".01 00:00:00"));

   int dow = TimeDayOfWeekEx(firstDayOfMonth);
   if (dow == SATURDAY) return(firstDayOfMonth + 2 * DAYS);
   if (dow == SUNDAY  ) return(firstDayOfMonth + 1 * DAY );

   return(firstDayOfMonth);
}


/**
 * Computes the time of the next vertical grid separator.
 *
 * @param  int time           - time of the current separator
 * @param  int dow [optional] - day-of-week of the separator, for performance (default: self-computed)
 *
 * @return datetime - vertical separator time or NaT in case of errors
 */
datetime ComputeNextSeparatorTime(datetime time, int dow = -1) {
   if (dow == -1) {
      dow = TimeDayOfWeekEx(time);
   }

   if (dailySeparators) {
      if (dow == FRIDAY) time += 3*DAYS;     // skip weekends
      else               time += 1*DAY;
   }
   else if (weeklySeparators) {
      time += 1*WEEK;
   }
   else if (monthlySeparators) {
      int yyyy = TimeYearEx(time);
      int mm = TimeMonth(time);
      if (mm == 12) { yyyy++; mm = 0; }
      time = ComputeFirstWeekDay(yyyy, mm + 1);
   }
   else if (yearlySeparators) {
      yyyy = TimeYearEx(time);
      time = ComputeFirstWeekDay(yyyy + 1, 1);
   }
   else return(_NaT(catch("ComputeNextSeparatorTime(1)  illegal vertical grid state (no enabled grid interval)", ERR_ILLEGAL_STATE)));

   return(time);
}



/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("PriceGrid.MinDistance.Pixel=", PriceGrid.MinDistance.Pixel,   ";", NL,
                            "Color.RegularGrid=",           ColorToStr(Color.RegularGrid), ";", NL,
                            "Color.SuperGrid=",             ColorToStr(Color.SuperGrid),   ";")
   );
}


#import "rsfMT4Expander.dll"
   int Grid_GetChartHeight(int hChart, int lastHeight);
#import

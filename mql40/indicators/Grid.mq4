/**
 * Chart grid
 *
 * Maintains horizontal and vertical chart separators.
 *
 *
 * TODO:
 *  - replace input "WeekendSessions.Symbols" by actual symbol properties
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    PriceGrid.MinDistance.Pixel = 40;          // adjust to your screen and DPI scaling
extern color  Color.RegularGrid           = Gainsboro;   //
extern color  Color.SuperGrid             = LightGray;   // slightly darker
extern string WeekendSessions.Symbols     = "";          // comma-separated list of symbols with weekend sessions

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
bool weekendSessions;            // whether the symbol has weekend sessions

// horizontal grid properties (price)
int    lastChartHeight;
double lastChartMinPrice;
double lastChartMaxPrice;
double lastGridSize;
string priceSepLabels[];         // labels of price separators


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

   // colors: after deserialization the terminal may turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.RegularGrid = GetConfigColor(indicator, "Color.RegularGrid", Color.RegularGrid);
   if (AutoConfiguration) Color.SuperGrid   = GetConfigColor(indicator, "Color.SuperGrid",   Color.SuperGrid);
   if (Color.RegularGrid == 0xFF000000) Color.RegularGrid = CLR_NONE;
   if (Color.SuperGrid   == 0xFF000000) Color.SuperGrid   = CLR_NONE;

   // WeekendSessions.Symbols
   if (AutoConfiguration) WeekendSessions.Symbols = GetConfigString(indicator, "WeekendSessions.Symbols", WeekendSessions.Symbols);
   string sValues[], sValue=StrToLower(WeekendSessions.Symbols), symbol=StrToLower(Symbol()), stdSymbol=StrToLower(StdSymbol());
   int size = Explode(sValue, ",", sValues, NULL);
   for (int i=0; i < size; i++) {
      sValues[i] = StrTrim(sValues[i]);
   }
   weekendSessions = (StringInArray(sValues, symbol) || StringInArray(sValues, stdSymbol));

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
   ArrayResize(priceSepLabels, separators);

   for (int i=0; i < separators; i++) {                     // no ObjectCreateRegister(): price separators change dynamically
      string label = NumberToStr(gridLevel, ",'R.+");       // and are handled better by the indicator itself
      if (ObjectFind(label) == -1) if (!ObjectCreate(label, OBJ_HLINE, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR,  Color.RegularGrid);
      ObjectSet(label, OBJPROP_PRICE1, gridLevel);
      ObjectSet(label, OBJPROP_BACK,   true);
      priceSepLabels[i] = label;

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
   for (int i=ArraySize(priceSepLabels)-1; i >= 0; i--) {
      if (ObjectFind(priceSepLabels[i]) != -1) {
         ObjectDelete(priceSepLabels[i]);
      }
   }
   ArrayResize(priceSepLabels, 0);
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
   datetime fromSepTime, toSepTime;                      // FXT times
   if (!ComputeVerticalSeparatorRange(fromSepTime, toSepTime)) return(false);

   datetime sepTime, sepChartTime, lastSepChartTime;
   string label = "", lastSepLabel = "";

   // create all time separators
   for (datetime time = fromSepTime; time <= toSepTime; time = ComputeNextSeparatorTime(time)) {
      sepTime = FxtToServerTime(time);

      // resolve bar and chart time of the separator
      if (Time[0] < sepTime) {                           // no such bar yet: current session or in ERS_HISTORY_UPDATE
         sepChartTime = sepTime;                         // use original time
         if (!weekendSessions) {                         // the terminal will display future weekend times even w/o sessions
            if (dailySeparators && TimeDayOfWeek(time)==MONDAY) {
               sepChartTime -= 2*DAYS;                   // move-back the separator to the next 24h boundary
            }
            else if (weeklySeparators) {
               sepChartTime -= 2*DAYS;                   // move-back the separator to the next 24h boundary
            }
            //else if (monthlySeparators)                // needless: move-back separator by number of remaining weekend days
            //else if (yearlySeparators)                 // needless: move-back separator by number of remaining non-trading days
         }
      }
      else {
         int bar = iBarShiftNext(NULL, NULL, sepTime);   // use time of first existing bar
         if (bar == EMPTY_VALUE) return(false);
         sepChartTime = Time[bar];
      }
      if (sepChartTime == lastSepChartTime) {            // bar gap or in ERS_HISTORY_UPDATE
         ObjectDelete(lastSepLabel);                     // keep the most recent separator only
      }

      // create new separator
      label = GmtTimeFormat(time, "%a %d.%m.%Y");        // e.g. "Fri 23.12.2011"
      if (ObjectFind(label) == -1) ObjectCreateRegister(label, OBJ_VLINE, 0, sepChartTime, 0);

      int   sepStyle = STYLE_DOT;
      color sepColor = Color.RegularGrid;
      if (dailySeparators) {
         if (TimeDayOfWeek(time) == MONDAY) {
            sepStyle = STYLE_DASHDOTDOT;                 // a slightly different style for the end of the week
            sepColor = Color.SuperGrid;
         }
      }
      else if (weeklySeparators) {
         sepStyle = STYLE_DASHDOTDOT;                    // same different style for weekly separators
         sepColor = Color.SuperGrid;
      }
      ObjectSet(label, OBJPROP_TIME1, sepChartTime);
      ObjectSet(label, OBJPROP_STYLE, sepStyle);
      ObjectSet(label, OBJPROP_COLOR, sepColor);
      ObjectSet(label, OBJPROP_BACK,  true);
      lastSepLabel     = label;
      lastSepChartTime = sepChartTime;                   // store last separator location for gap detection
   }
   return(!catch("UpdateVerticalGrid(1)"));
}


/**
 * Compute the times of the first and the last vertical separator to display.
 *
 * @param  _Out_ datetime fromTime - first (oldest) separator time in FXT
 * @param  _Out_ datetime toTime   - last (youngest) separator time in FXT
 *
 * @return bool - success status
 */
bool ComputeVerticalSeparatorRange(datetime &fromTime, datetime &toTime) {
   // the first separator may appear on the oldest bar
   datetime first = GetNextSessionStartTime(ServerToFxtTime(Time[Bars-1]) - 1*SECOND, TZ_FXT, weekendSessions);
   datetime last  = GetNextSessionStartTime(ServerToFxtTime(Time[0]), TZ_FXT, weekendSessions), firstTradingDay;
   if (first==NaT || last==NaT) return(false);

   int yyyy, mm;

   if (dailySeparators) {
      // nothing to do
   }
   else if (weeklySeparators) {
      first += (8 - TimeDayOfWeek(first)) % 7 * DAYS;    // first Monday in the chart
      last  += (8 - TimeDayOfWeek(last))  % 7 * DAYS;    // next Monday in the future
   }
   else if (monthlySeparators) {
      yyyy = TimeYear(first);
      mm   = TimeMonth(first);
      firstTradingDay = ComputeFirstTradingDay(yyyy, mm);
      if (firstTradingDay < first) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstTradingDay = ComputeFirstTradingDay(yyyy, mm+1);
      }
      first = firstTradingDay;                           // first "1st trading day of the month" in the chart

      yyyy = TimeYear(last);
      mm   = TimeMonth(last);
      firstTradingDay = ComputeFirstTradingDay(yyyy, mm);
      if (firstTradingDay < last) {
         if (mm == 12) { yyyy++; mm = 0; }
         firstTradingDay = ComputeFirstTradingDay(yyyy, mm+1);
      }
      last = firstTradingDay;                            // next "1st trading day of the month" in the future
   }
   else if (yearlySeparators) {
      yyyy = TimeYear(first);
      firstTradingDay = ComputeFirstTradingDay(yyyy, 1);
      if (firstTradingDay < first) {
         firstTradingDay = ComputeFirstTradingDay(yyyy+1, 1);
      }
      first= firstTradingDay;                            // first "1st trading day of the year" in the chart

      yyyy = TimeYear(last);
      firstTradingDay = ComputeFirstTradingDay(yyyy, 1);
      if (firstTradingDay < last) {
         firstTradingDay = ComputeFirstTradingDay(yyyy+1, 1);
      }
      last = firstTradingDay;                            // next "1st trading day of the year" in the future
   }
   else return(!catch("ComputeVerticalSeparatorRange(1)  illegal grid configuration (unknown interval)", ERR_ILLEGAL_STATE));

   fromTime = first;
   toTime   = last;
   return(true);
}


/**
 * Computes the time of the next vertical grid separator.
 *
 * @param  int time - time of the current separator
 *
 * @return datetime - time of the next separator or NaT in case of errors
 */
datetime ComputeNextSeparatorTime(datetime time) {
   if (dailySeparators) {
      time += 1*DAY;
      if (!weekendSessions) {                      // skip weekends
         int dow = TimeDayOfWeek(time);
         if      (dow == SATURDAY) time += 2*DAYS;
         else if (dow == SUNDAY)   time += 1*DAY;
      }
   }
   else if (weeklySeparators) {
      time += 1*WEEK;
   }
   else if (monthlySeparators) {
      int yyyy = TimeYear(time);
      int mm = TimeMonth(time);
      if (mm == 12) { yyyy++; mm = 0; }
      time = ComputeFirstTradingDay(yyyy, mm + 1);
   }
   else if (yearlySeparators) {
      yyyy = TimeYear(time);
      time = ComputeFirstTradingDay(yyyy + 1, 1);
   }
   else return(_NaT(catch("ComputeNextSeparatorTime(1)  illegal grid configuration (unknown interval)", ERR_ILLEGAL_STATE)));

   return(time);
}


/**
 * Computes the first trading day of a month.
 *
 * @param  int year  - supported values: 1970-2037
 * @param  int month - supported values: 1-12
 *
 * @return datetime - 00:00 (Midnight) of the first weekday of a month or EMPTY (-1) in case of errors
 */
datetime ComputeFirstTradingDay(int year, int month) {
   if (year < 1970 || year > 2037) return(_EMPTY(catch("ComputeFirstTradingDay(1)  illegal parameter year: "+ year +" (out of range)", ERR_INVALID_PARAMETER)));
   if (month < 1 || month > 12)    return(_EMPTY(catch("ComputeFirstTradingDay(2)  invalid parameter month: "+ month +" (out of range)", ERR_INVALID_PARAMETER)));

   datetime firstTradingDay = StrToTime(StringConcatenate(year, ".", StrRight("0"+month, 2), ".01 00:00:00"));

   if (!weekendSessions) {                      // skip weekends
      int dow = TimeDayOfWeek(firstTradingDay);
      if      (dow == SATURDAY) firstTradingDay += 2*DAYS;
      else if (dow == SUNDAY  ) firstTradingDay += 1*DAY;
   }
   return(firstTradingDay);
}


/**
 * Return a string representation of all input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("PriceGrid.MinDistance.Pixel=", PriceGrid.MinDistance.Pixel,             ";", NL,
                            "Color.RegularGrid=",           ColorToStr(Color.RegularGrid),           ";", NL,
                            "Color.SuperGrid=",             ColorToStr(Color.SuperGrid),             ";", NL,
                            "WeekendSessions.Symbols=",     DoubleQuoteStr(WeekendSessions.Symbols), ";")
   );
}


#import "rsfMT4Expander.dll"
   int Grid_GetChartHeight(int hChart, int lastHeight);
#import

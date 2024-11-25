/**
 * Chart grid
 *
 * Dynamically maintains horizontal (price) and vertical (date/time) chart separators.
 */
#include <rsf/stddefines.mqh>
int   __InitFlags[] = {INIT_TIMEZONE};
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    PriceGrid.MinDistance.Pixel    = 40;             // adjust to your screen and DPI scaling

extern string ___a__________________________ = "";
extern color  Color.RegularGrid              = Gainsboro;      // C'220,220,220'
extern color  Color.SuperGrid                = LightGray;      // C'211,211,211' (slightly darker)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <rsf/core/indicator.mqh>
#include <rsf/stdfunctions.mqh>
#include <rsf/stdlib.mqh>
#include <rsf/functions/iBarShiftNext.mqh>
#include <rsf/functions/ObjectCreateRegister.mqh>
#include <rsf/win32api.mqh>

#property indicator_chart_window

int    lastChartHeight;
double lastChartMinPrice;
double lastChartMaxPrice;
double lastGridSize;

string hSeparatorLabels[];       // horizontal price separator labels


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

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (AutoConfiguration) Color.RegularGrid = GetConfigColor(indicator, "Color.RegularGrid", Color.RegularGrid);
   if (AutoConfiguration) Color.SuperGrid   = GetConfigColor(indicator, "Color.SuperGrid",   Color.SuperGrid);
   if (Color.RegularGrid == 0xFF000000) Color.RegularGrid = CLR_NONE;
   if (Color.SuperGrid   == 0xFF000000) Color.SuperGrid   = CLR_NONE;

   return(catch("onInit(2)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   RemovePriceSeparators();
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

   if (!GetHorizontalChartDimensions(chartHeight, minPrice, maxPrice)) return(!last_error);

   // nothing to do if chart dimensions are unchanged
   if (chartHeight==lastChartHeight && minPrice==lastChartMinPrice && maxPrice==lastChartMaxPrice) return(true);

   // recalculate grid size
   double gridSize = ComputeGridSize(chartHeight, minPrice, maxPrice);
   if (!gridSize) return(false);

   // update the grid
   if (gridSize != lastGridSize) {                       // this includes first use: !lastGridSize
      if (!RemovePriceSeparators()) return(false);

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
double ComputeGridSize(int chartHeight, double chartMinPrice, double chartMaxPrice) {
   double separators     = 1.*chartHeight / PriceGrid.MinDistance.Pixel;
   double priceRange     = chartMaxPrice - chartMinPrice;
   double separatorRange = priceRange / separators;
   double baseSize       = MathPow(10, MathFloor(MathLog10(separatorRange)));

   double gridSize = 5 * baseSize;
   if (gridSize < separatorRange) {
      gridSize *= 2;
   }
   gridSize = NormalizeDouble(gridSize, Digits);
   if (IsLogDebug()) logDebug("ComputeGridSize(0.1)  Tick="+ Ticks +"  height="+ chartHeight +"  range="+ DoubleToStr(priceRange/pUnit, pDigits) +" => grid = "+ DoubleToStr(gridSize/pUnit, pDigits));

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


   // a separator every multiple of 2 * 10^n          // not used anymore
   // --------------------------------------
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
 * Remove all existing price separators (horizontal grid).
 *
 * @return bool - success status
 */
bool RemovePriceSeparators() {
   int size = ArraySize(hSeparatorLabels);

   for (int i=0; i < size; i++) {
      if (ObjectFind(hSeparatorLabels[i]) != -1) {
         ObjectDelete(hSeparatorLabels[i]);
      }
   }
   ArrayResize(hSeparatorLabels, 0);

   return(!catch("RemovePriceSeparators(1)"));
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

   int separators = (toPrice-gridLevel)/gridSize + 1;
   ArrayResize(hSeparatorLabels, separators);

   for (int i=0; i < separators; i++) {                     // no ObjectCreateRegister(), price separators change constantly
      string label = NumberToStr(gridLevel, ",'R.+");       // and are handled more efficiently by the indicator itself
      if (ObjectFind(label) == -1) if (!ObjectCreate(label, OBJ_HLINE, 0, 0, 0)) return(false);
      ObjectSet(label, OBJPROP_STYLE,  STYLE_DOT);
      ObjectSet(label, OBJPROP_COLOR,  Color.RegularGrid);
      ObjectSet(label, OBJPROP_PRICE1, gridLevel);
      ObjectSet(label, OBJPROP_BACK,   true);

      hSeparatorLabels[i] = label;

      gridLevel = NormalizeDouble(gridLevel + gridSize, Digits);
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

/**
 * One side of a Keltner Channel (an ATR channel) which is calculated around High and Low of the current bar, rather than around the usual Moving
 * Average. Depending on a SMA cross-over signal the upper or the lower channel band is used as indicator line. Additional criterias must be defined
 * to avoid chop (e.g. the Keltner channel), however no such information is given. Originally the calculation is done with a CCI but the CCI is not
 * used. Instead the CCI also uses a SMA(Typical).
 *
 *   SMA:          SMA(50, TypicalPrice)
 *   TypicalPrice: (H+L+C)/3
 *
 * @source http://www.forexfactory.com/showthread.php?t=214635 (Andrew Forex Trading System)
 * @see    http://www.forexfactory.com/showthread.php?t=268038 (Plateman's CCI aka SuperTrend)
 * @see    http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:keltner_channels
 *
 *
 *
 *
 *
 *
 * TODO: - Keltner-Channel komplett zeichnen (muﬂ als Filter benutzt werden)
 *       - verwendeten PriceType im SMA konfigurierbar machen
 *       - LineType konfigurierbar machen: Non-repainting only with LINE_DOT
 *       - Kl‰ren: Die Werte des Channels sind bis zum CCI-Wechsel auf das jeweils aufgetretene Channel-Minimum/-Maximum fixiert, die
 *         resultierende Linie kann im Aufw‰rtstrend nur steigen und im Abw‰rtstrend nur fallen.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

/////////////////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////////////////

extern int    CCI.Periods           = 50;
extern int    ATR.Periods           = 5;
extern double ATR.Multiplier        = 1;

extern color  Color.UpTrend         = RoyalBlue;                     // color management here to allow access by the code
extern color  Color.DownTrend       = Red;
extern color  Color.UpperBand       = RoyalBlue;
extern color  Color.LowerBand       = Red;

extern int    Max.Values            = 3000;                          // maximum indicator values to draw: -1 = all
extern int    Shift.Vertical.Pips   = 0;                             // vertical shift in pips
extern int    Shift.Horizontal.Bars = 0;                             // horizontal shift in bars

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>

#define ATR.MODE_UPPER      0                                        // upper ATR channel band index
#define ATR.MODE_LOWER      1                                        // lower ATR channel band index

#property indicator_chart_window

#property indicator_buffers 3

#property indicator_color1  RoyalBlue
#property indicator_color2  Red
#property indicator_width1  3
#property indicator_width2  3

double bufferUpperBand[];                                            // upper ATR channel band
double bufferLowerBand[];                                            // lower ATR channel band

string indicator.shortName;                                          // name for chart, chart context menu and "Data Window"
string chart.legendLabel;
double shift.vertical;



// bis hier ok

double TrendUp  [];
double TrendDown[];


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validation
   // CCI
   if (CCI.Periods < 1)    return(catch("onInit(1)  Invalid input parameter CCI.Periods = "+ CCI.Periods, ERR_INVALID_INPUT_PARAMETER));

   // ATR
   if (ATR.Periods    < 1) return(catch("onInit(2)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));
   if (ATR.Multiplier < 0) return(catch("onInit(3)  Invalid input parameter ATR.Multiplier = "+ NumberToStr(ATR.Multiplier, ".+"), ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.UpperBand == 0xFF000000) Color.UpperBand = CLR_NONE;    // at times after re-compilation or re-start the terminal convertes
   if (Color.LowerBand == 0xFF000000) Color.LowerBand = CLR_NONE;    // CLR_NONE (0xFFFFFFFF) to 0xFF000000 (which appears Black)

   // Max.Values
   if (Max.Values < -1)    return(catch("onInit(4)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) Chart legend
   indicator.shortName = __NAME__ +"("+ CCI.Periods +")";
   chart.legendLabel   = CreateLegendLabel(indicator.shortName);
   ObjectRegister(chart.legendLabel);


   // (3) Buffer management
   SetIndexBuffer(ATR.MODE_UPPER, bufferUpperBand);
   SetIndexBuffer(ATR.MODE_LOWER, bufferLowerBand);

   // Display options
   IndicatorShortName(indicator.shortName);                          // chart context menu
   SetIndexLabel(ATR.MODE_UPPER, indicator.shortName);               // chart tooltip and "Data Window"
   SetIndexLabel(ATR.MODE_LOWER, indicator.shortName);
   IndicatorDigits(SubPipDigits);

   // Drawing options
   int startDraw = Max(CCI.Periods-1, Bars-ifInt(Max.Values < 0, Bars, Max.Values)) + Shift.Horizontal.Bars;
   SetIndexDrawBegin(ATR.MODE_UPPER, startDraw); SetIndexShift(ATR.MODE_UPPER, Shift.Horizontal.Bars);
   SetIndexDrawBegin(ATR.MODE_LOWER, startDraw); SetIndexShift(ATR.MODE_LOWER, Shift.Horizontal.Bars);

   shift.vertical = Shift.Vertical.Pips * Pips;                      // TODO: Digits/Point-Fehler abfangen








   SetIndexBuffer(0, TrendUp);
   SetIndexBuffer(1, TrendDown);

   //SetIndexStyle(0, DRAW_LINE, STYLE_SOLID, 2);
   //SetIndexStyle(1, DRAW_LINE, STYLE_SOLID, 2);

   return(catch("onInit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) IndicatorBuffer entsprechend ShiftedBars synchronisieren
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(TrendUp,   Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(TrendDown, Bars, ShiftedBars, EMPTY_VALUE);
   }


   int counted_bars = IndicatorCounted();
   if (counted_bars < 0) return(-1);
   if (counted_bars > 0) counted_bars--;

   int limit = Bars-counted_bars;

   for (int i=limit; i >= 0; i--) {
      double currentCCI  = iCCI(NULL, NULL, CCI.Periods, PRICE_TYPICAL, i  );
      double previousCCI = iCCI(NULL, NULL, CCI.Periods, PRICE_TYPICAL, i+1);

      if (currentCCI > 0) {
         TrendUp[i] = Low[i] - iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI < 0           ) TrendUp[i+1] = TrendDown[i+1];          // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
         if (TrendUp[i]  < TrendUp[i+1]) TrendUp[i  ] = TrendUp  [i+1];          // Werte auf das bisherige Maximum begrenzen
      }
      else {
         TrendDown[i] = High[i] + iATR(NULL, NULL, ATR.Periods, i);
         if (previousCCI  > 0             ) TrendDown[i+1] = TrendUp  [i+1];     // Farbe sofort wechseln (MetaTrader braucht min. zwei Datenpunkte)
         if (TrendDown[i] > TrendDown[i+1]) TrendDown[i  ] = TrendDown[i+1];     // Werte auf das bisherige Minimum begrenzen
      }
   }

   return(catch("onTick(1)"));
}




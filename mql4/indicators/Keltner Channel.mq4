/**
 * Keltner Channel (ATR channel)
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods      = 200;
extern string MA.Method       = "SMA* | LWMA | EMA | ALMA";
extern string MA.AppliedPrice = "Open | High | Low | Close* | Median | Typical | Weighted";

extern int    ATR.Periods     = 100;
extern string ATR.Timeframe   = "current";                           // Timeframe: M1 | M5 | M15 | ...
extern double ATR.Multiplier  = 1;

extern color  Color.Bands     = Blue;                                // Farbverwaltung hier, damit Code Zugriff hat
extern color  Color.MA        = CLR_NONE;

extern int    Max.Bars        = 5000;                                // max. number of bars to display (-1: all available)

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/@Bands.mqh>

#define MODE_MA               Bands.MODE_MA                          // MA
#define MODE_UPPER            Bands.MODE_UPPER                       // oberes Band
#define MODE_LOWER            Bands.MODE_LOWER                       // unteres Band

#property indicator_chart_window
#property indicator_buffers   3

#property indicator_style1    STYLE_DOT
#property indicator_style2    STYLE_SOLID
#property indicator_style3    STYLE_SOLID


double bufferMA       [];                                            // sichtbar
double bufferUpperBand[];                                            // sichtbar
double bufferLowerBand[];                                            // sichtbar

int    ma.periods;
int    ma.method;
int    ma.appliedPrice;

int    atr.timeframe;

double alma.weights[];                                               // Gewichtungen der einzelnen Bars eines ALMA

string legendLabel, iDescription;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Validierung
   // MA.Periods
   if (MA.Periods < 2)      return(catch("onInit(1)  Invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));
   ma.periods = MA.Periods;

   // MA.Method
   string values[], sValue;
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   else sValue = MA.Method;
   ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)        return(catch("onInit(2)  Invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   if (ma.method == MODE_SMMA) return(catch("onInit(3)  Unsupported MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   // MA.AppliedPrice
   sValue = StrToLower(MA.AppliedPrice);
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                      // default price type
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (IsEmpty(ma.appliedPrice)) {
      if      (StrStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
      else if (StrStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
      else if (StrStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
      else if (StrStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
      else if (StrStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
      else if (StrStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
      else if (StrStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
      else                  return(catch("onInit(4)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // ATR.Periods
   if (ATR.Periods < 1)     return(catch("onInit(5)  Invalid input parameter ATR.Periods = "+ ATR.Periods, ERR_INVALID_INPUT_PARAMETER));

   // ATR.Timeframe
   ATR.Timeframe = StrToUpper(StrTrim(ATR.Timeframe));
   if (ATR.Timeframe == "CURRENT") ATR.Timeframe = "";
   if (ATR.Timeframe == ""       ) atr.timeframe = Period();
   else                            atr.timeframe = StrToPeriod(ATR.Timeframe, F_ERR_INVALID_PARAMETER);
   if (atr.timeframe == -1) return(catch("onInit(6)  Invalid input parameter ATR.Timeframe = "+ DoubleQuoteStr(ATR.Timeframe), ERR_INVALID_INPUT_PARAMETER));

   // ATR.Multiplier
   if (ATR.Multiplier < 0)  return(catch("onInit(7)  Invalid input parameter ATR.Multiplier = "+ NumberToStr(ATR.Multiplier, ".+"), ERR_INVALID_INPUT_PARAMETER));

   // Colors
   if (Color.Bands == 0xFF000000) Color.Bands = CLR_NONE;            // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompilation oder Deserialisierung
   if (Color.MA    == 0xFF000000) Color.MA    = CLR_NONE;            // u.U. 0xFF000000 (entspricht Schwarz)

   // Max.Bars
   if (Max.Bars < -1)       return(catch("onInit(8)  Invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));


   // (2) Chart-Legende erzeugen
   if (!IsSuperContext()) {
       legendLabel  = CreateLegendLabel();
       RegisterObject(legendLabel);
   }


   // (3) ggf. ALMA-Gewichtungen berechnen
   if (ma.method==MODE_ALMA) /*&&*/ if (ma.periods > 1)                 // ma.periods < 2 ist möglich bei Umschalten auf zu großen Timeframe
      @ALMA.CalculateWeights(alma.weights, ma.periods);


   // (4.1) Bufferverwaltung
   SetIndexBuffer(Bands.MODE_MA,    bufferMA       );                   // sichtbar
   SetIndexBuffer(Bands.MODE_UPPER, bufferUpperBand);                   // sichtbar
   SetIndexBuffer(Bands.MODE_LOWER, bufferLowerBand);                   // sichtbar

   // (4.2) Anzeigeoptionen
   string strAtrTimeframe = ""; if (ATR.Timeframe != "") strAtrTimeframe = "x"+ ATR.Timeframe;
   iDescription = "Keltner Channel "+ NumberToStr(ATR.Multiplier, ".+") +"*ATR("+ ATR.Periods + strAtrTimeframe +")  "+ MA.Method +"("+ MA.Periods +")";
   string atrDescription = NumberToStr(ATR.Multiplier, ".+") +"*ATR("+ ATR.Periods + strAtrTimeframe +")";
   IndicatorShortName("Keltner Channel "+ atrDescription);              // chart context menu
   SetIndexLabel(Bands.MODE_UPPER, "Keltner Upper "+ atrDescription);   // Tooltip und Data window
   SetIndexLabel(Bands.MODE_LOWER, "Keltner Lower "+ atrDescription);
   if (Color.MA == CLR_NONE) SetIndexLabel(Bands.MODE_MA, NULL);
   else                      SetIndexLabel(Bands.MODE_MA, "Keltner Channel "+ MA.Method +"("+ MA.Periods +")");
   IndicatorDigits(SubPipDigits);

   // (4.3) Zeichenoptionen
   int startDraw = 0;
   if (Max.Bars >= 0) startDraw = Bars - Max.Bars;
   if (startDraw < 0) startDraw = 0;
   SetIndexDrawBegin(Bands.MODE_MA,    startDraw);
   SetIndexDrawBegin(Bands.MODE_UPPER, startDraw);
   SetIndexDrawBegin(Bands.MODE_LOWER, startDraw);
   SetIndicatorOptions();

   return(catch("onInit(9)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // Abschluß der Buffer-Initialisierung überprüfen
   if (!ArraySize(bufferMA))                                         // kann bei Terminal-Start auftreten
      return(log("onTick(1)  size(bufferMA) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // vor kompletter Neuberechnung Buffer zurücksetzen (löscht Garbage hinter MaxValues)
   if (!UnchangedBars) {
      ArrayInitialize(bufferMA,        EMPTY_VALUE);
      ArrayInitialize(bufferUpperBand, EMPTY_VALUE);
      ArrayInitialize(bufferLowerBand, EMPTY_VALUE);
      SetIndicatorOptions();
   }


   // (1) synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMA,        Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpperBand, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLowerBand, Bars, ShiftedBars, EMPTY_VALUE);
   }


   if (ma.periods < 2)                                               // Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);


   // (2) Startbar der Berechnung ermitteln
   if (ChangedBars > Max.Bars) /*&&*/ if (Max.Bars >= 0)
      ChangedBars = Max.Bars;
   int startBar = Min(ChangedBars-1, Bars-ma.periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // (3) ungültige Bars neuberechnen
   if (ma.method <= MODE_LWMA) {
      double atr;
      for (int bar=startBar; bar >= 0; bar--) {
         bufferMA       [bar] = iMA(NULL, NULL, ma.periods, 0, ma.method, ma.appliedPrice, bar);
         atr                  = iATR(NULL, atr.timeframe, ATR.Periods, bar) * ATR.Multiplier;
         bufferUpperBand[bar] = bufferMA[bar] + atr;
         bufferLowerBand[bar] = bufferMA[bar] - atr;
      }
   }
   else if (ma.method == MODE_ALMA) {
      RecalcALMAChannel(startBar);
   }


   // (4) Legende aktualisieren
   @Bands.UpdateLegend(legendLabel, iDescription, "", Color.Bands, bufferUpperBand[0], bufferLowerBand[0], Digits, Time[0]);

   return(last_error);
}


/**
 * Berechnet die ungültigen Bars eines ALMA-basierten Keltner Channels neu.
 *
 * @param  int startBar
 *
 * @return bool - Erfolgsstatus
 */
bool RecalcALMAChannel(int startBar) {
   double atr;

   for (int i, j, bar=startBar; bar >= 0; bar--) {
      bufferMA[bar] = 0;
      for (i=0; i < ma.periods; i++) {
         bufferMA[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
      }
      atr                  = iATR(NULL, atr.timeframe, ATR.Periods, bar) * ATR.Multiplier;
      bufferUpperBand[bar] = bufferMA[bar] + atr;
      bufferLowerBand[bar] = bufferMA[bar] - atr;
   }
   return(!catch("RecalcALMAChannel()"));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int drawType = ifInt(Color.MA==CLR_NONE, DRAW_NONE, DRAW_LINE);

   SetIndexStyle(Bands.MODE_MA,    drawType,  EMPTY, EMPTY, Color.MA   );
   SetIndexStyle(Bands.MODE_UPPER, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
   SetIndexStyle(Bands.MODE_LOWER, DRAW_LINE, EMPTY, EMPTY, Color.Bands);
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",      DoubleQuoteStr(MA.Periods),                         ";", NL,
                            "MA.Method=",       DoubleQuoteStr(MA.Method),                          ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice),                    ";", NL,
                            "ATR.Periods=",     ATR.Periods,                                        ";", NL,
                            "ATR.Timeframe=",   DoubleQuoteStr(ATR.Timeframe),                      ";", NL,
                            "ATR.Multiplier=",  DoubleQuoteStr(NumberToStr(ATR.Multiplier, ".1+")), ";", NL,
                            "Color.Bands=",     ColorToStr(Color.Bands),                            ";", NL,
                            "Color.MA=",        ColorToStr(Color.MA),                               ";", NL,
                            "Max.Bars=",        Max.Bars,                                           ";")
   );
}

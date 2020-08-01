/**
 * Bollinger Bands
 *
 *
 * Indicator buffers for iCustom():
 *  • Bands.MODE_MA:    MA values
 *  • Bands.MODE_UPPER: upper band values
 *  • Bands.MODE_LOWER: lower band value
 *
 * TODO:
 *  - replace manual calculation of StdDev(ALMA) with correct syntax for iStdDevOnArray()
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;
extern string MA.Method         = "SMA | LWMA | EMA | ALMA*";
extern string MA.AppliedPrice   = "Open | High | Low | Close* | Median | Typical | Weighted";
extern color  MA.Color          = LimeGreen;
extern int    MA.LineWidth      = 0;

extern double Bands.StdDevs     = 2;
extern color  Bands.Color       = RoyalBlue;
extern int    Bands.LineWidth   = 1;

extern int    Max.Bars          = 10000;              // max. number of bars to display (-1: all available)

extern string __________________________;

extern string Signal.onTouchBand   = "on | off | auto*";
extern string Signal.Sound         = "on | off | auto*";
extern string Signal.Mail.Receiver = "on | off | auto* | {email-address}";
extern string Signal.SMS.Receiver  = "on | off | auto* | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@ALMA.mqh>
#include <functions/@Bands.mqh>
#include <functions/ConfigureSignal.mqh>
#include <functions/ConfigureSignalMail.mqh>
#include <functions/ConfigureSignalSMS.mqh>
#include <functions/ConfigureSignalSound.mqh>

#define MODE_MA               Bands.MODE_MA           // indicator buffer ids
#define MODE_UPPER            Bands.MODE_UPPER
#define MODE_LOWER            Bands.MODE_LOWER

#property indicator_chart_window
#property indicator_buffers   3

#property indicator_style1    STYLE_DOT
#property indicator_style2    STYLE_SOLID
#property indicator_style3    STYLE_SOLID

double bufferMa   [];                                 // MA values:         visible if configured
double bufferUpper[];                                 // upper band values: visible, displayed in "Data" window
double bufferLower[];                                 // lower band values: visible, displayed in "Data" window

int    ma.method;
int    ma.appliedPrice;
double alma.weights[];

string ind.longName;                                  // name for chart legend
string ind.shortName;                                 // name for "Data" window and context menues
string ind.legendLabel;

bool   signals;
string signal.info = "";                              // info text in chart legend
bool   signal.sound;
string signal.sound.touchBand = "Signal-Up.wav";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";
bool   signal.sms;
string signal.sms.receiver = "";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   if (ProgramInitReason() == IR_RECOMPILE) {
      if (!RestoreInputParameters()) return(last_error);
   }

   // validate inputs
   // MA.Periods
   if (MA.Periods < 1)      return(catch("onInit(1)  Invalid input parameter MA.Periods = "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.Method
   string values[], sValue = MA.Method;
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   ma.method = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (ma.method == -1)     return(catch("onInit(2)  Invalid input parameter MA.Method = "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(ma.method);

   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if (sValue == "") sValue = "close";                                  // default price type
   ma.appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (IsEmpty(ma.appliedPrice)) {
      if      (StrStartsWith("open",     sValue)) ma.appliedPrice = PRICE_OPEN;
      else if (StrStartsWith("high",     sValue)) ma.appliedPrice = PRICE_HIGH;
      else if (StrStartsWith("low",      sValue)) ma.appliedPrice = PRICE_LOW;
      else if (StrStartsWith("close",    sValue)) ma.appliedPrice = PRICE_CLOSE;
      else if (StrStartsWith("median",   sValue)) ma.appliedPrice = PRICE_MEDIAN;
      else if (StrStartsWith("typical",  sValue)) ma.appliedPrice = PRICE_TYPICAL;
      else if (StrStartsWith("weighted", sValue)) ma.appliedPrice = PRICE_WEIGHTED;
      else                  return(catch("onInit(3)  Invalid input parameter MA.AppliedPrice = "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   MA.AppliedPrice = PriceTypeDescription(ma.appliedPrice);

   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MA.Color == 0xFF000000) MA.Color = CLR_NONE;

   // MA.LineWidth
   if (MA.LineWidth < 0)    return(catch("onInit(4)  Invalid input parameter MA.LineWidth = "+ MA.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (MA.LineWidth > 5)    return(catch("onInit(5)  Invalid input parameter MA.LineWidth = "+ MA.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Bands.StdDevs
   if (Bands.StdDevs < 0)   return(catch("onInit(6)  Invalid input parameter Bands.StdDevs = "+ NumberToStr(Bands.StdDevs, ".1+"), ERR_INVALID_INPUT_PARAMETER));

   // Bands.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;

   // Bands.LineWidth
   if (Bands.LineWidth < 0) return(catch("onInit(7)  Invalid input parameter Bands.LineWidth = "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Bands.LineWidth > 5) return(catch("onInit(8)  Invalid input parameter Bands.LineWidth = "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)       return(catch("onInit(9)  Invalid input parameter Max.Bars = "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));

   // Signals
   if (!ConfigureSignal("BollingerBand", Signal.onTouchBand, signals))                                        return(last_error);
   if (signals) {
      if (!ConfigureSignalSound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!ConfigureSignalMail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!ConfigureSignalSMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         signal.info = "TouchBand="+ StrLeft(ifString(signal.sound, "Sound+", "") + ifString(signal.mail, "Mail+", "") + ifString(signal.sms, "SMS+", ""), -1);
      }
      else signals = false;
   }

   // setup buffer management
   SetIndexBuffer(MODE_MA,    bufferMa   );                    // MA values:         visible if configured
   SetIndexBuffer(MODE_UPPER, bufferUpper);                    // upper band values: visible, displayed in "Data" window
   SetIndexBuffer(MODE_LOWER, bufferLower);                    // lower band values: visible, displayed in "Data" window

   if (!IsSuperContext()) {
       ind.legendLabel = CreateLegendLabel();                   // no chart legend if called by iCustom()
       RegisterObject(ind.legendLabel);
   }

   // data display configuration, names and labels
   string sMaAppliedPrice = ifString(ma.appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(ma.appliedPrice));
   ind.shortName = __NAME() +"("+ MA.Periods +")";
   ind.longName  = __NAME() +"("+ MA.Method +"("+ MA.Periods + sMaAppliedPrice +") ± "+ NumberToStr(Bands.StdDevs, ".1+") +")";
   IndicatorShortName(ind.shortName);                          // context menu
   if (!MA.LineWidth || MA.Color==CLR_NONE) SetIndexLabel(MODE_MA, NULL);
   else                                     SetIndexLabel(MODE_MA, MA.Method +"("+ MA.Periods + sMaAppliedPrice +")");
   SetIndexLabel(MODE_UPPER, "UpperBand("+ MA.Periods +")");   // "Data" window and tooltips
   SetIndexLabel(MODE_LOWER, "LowerBand("+ MA.Periods +")");
   IndicatorDigits(SubPipDigits);

   // drawing options and styles
   int startDraw = MA.Periods;
   if (Max.Bars >= 0)
      startDraw = Max(startDraw, Bars-Max.Bars);
   SetIndexDrawBegin(MODE_MA,    startDraw);
   SetIndexDrawBegin(MODE_UPPER, startDraw);
   SetIndexDrawBegin(MODE_LOWER, startDraw);
   SetIndicatorOptions();

   // initialize indicator calculation
   if (ma.method==MODE_ALMA && MA.Periods > 1) {
      @ALMA.CalculateWeights(alma.weights, MA.Periods);
   }
   return(catch("onInit(10)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   RepositionLegend();
   return(catch("onDeinit(1)"));
}


/**
 * Called before recompilation.
 *
 * @return int - error status
 */
int onDeinitRecompile() {
   StoreInputParameters();
   return(catch("onDeinitRecompile(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // under undefined conditions on the first tick after terminal start buffers may not yet be initialized
   if (!ArraySize(bufferMa)) return(log("onTick(1)  size(buffeMa) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Bars before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(bufferMa,    EMPTY_VALUE);
      ArrayInitialize(bufferUpper, EMPTY_VALUE);
      ArrayInitialize(bufferLower, EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(bufferMa,    Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferUpper, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(bufferLower, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // calculate start bar
   int changedBars = ChangedBars;
   if (Max.Bars >= 0) /*&&*/ if (changedBars > Max.Bars)
      changedBars = Max.Bars;
   int startBar = Min(changedBars-1, Bars-MA.Periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));


   // recalculate changed bars
   double deviation, price, sum;

   for (int bar=startBar; bar >= 0; bar--) {
      if (ma.method == MODE_ALMA) {
         bufferMa[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {
            bufferMa[bar] += alma.weights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+i);
         }
         // calculate deviation manually (for some reason iStdDevOnArray() fails)
         //deviation = iStdDevOnArray(bufferMa, WHOLE_ARRAY, MA.Periods, 0, MODE_SMA, bar) * StdDev.Multiplier;
         sum = 0;
         for (int j=0; j < MA.Periods; j++) {
            price = iMA(NULL, NULL, 1, 0, MODE_SMA, ma.appliedPrice, bar+j);
            sum  += (price-bufferMa[bar]) * (price-bufferMa[bar]);
         }
         deviation = MathSqrt(sum/MA.Periods) * Bands.StdDevs;
      }
      else {
         bufferMa[bar] = iMA    (NULL, NULL, MA.Periods, 0, ma.method, ma.appliedPrice, bar);
         deviation     = iStdDev(NULL, NULL, MA.Periods, 0, ma.method, ma.appliedPrice, bar) * Bands.StdDevs;
      }
      bufferUpper[bar] = bufferMa[bar] + deviation;
      bufferLower[bar] = bufferMa[bar] - deviation;
   }


   // update chart legend
   if (!IsSuperContext()) {
      @Bands.UpdateLegend(ind.legendLabel, ind.longName, signal.info, Bands.Color, bufferUpper[0], bufferLower[0], Digits, Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   if (!MA.LineWidth)    { int ma.drawType    = DRAW_NONE, ma.width    = EMPTY;           }
   else                  {     ma.drawType    = DRAW_LINE; ma.width    = MA.LineWidth;    }

   if (!Bands.LineWidth) { int bands.drawType = DRAW_NONE, bands.width = EMPTY;           }
   else                  {     bands.drawType = DRAW_LINE; bands.width = Bands.LineWidth; }

   SetIndexStyle(MODE_MA,    ma.drawType,    EMPTY, ma.width,    MA.Color   );
   SetIndexStyle(MODE_UPPER, bands.drawType, EMPTY, bands.width, Bands.Color);
   SetIndexStyle(MODE_LOWER, bands.drawType, EMPTY, bands.width, Bands.Color);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = __NAME();
   Chart.StoreInt   (name +".input.MA.Periods",      MA.Periods     );
   Chart.StoreString(name +".input.MA.Method",       MA.Method      );
   Chart.StoreString(name +".input.MA.AppliedPrice", MA.AppliedPrice);
   Chart.StoreColor (name +".input.MA.Color",        MA.Color       );
   Chart.StoreInt   (name +".input.MA.LineWidth",    MA.LineWidth   );
   Chart.StoreDouble(name +".input.Bands.StdDevs",   Bands.StdDevs  );
   Chart.StoreColor (name +".input.Bands.Color",     Bands.Color    );
   Chart.StoreInt   (name +".input.Bands.LineWidth", Bands.LineWidth);
   Chart.StoreInt   (name +".input.Max.Bars",        Max.Bars       );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = __NAME();
   Chart.RestoreInt   (name +".input.MA.Periods",      MA.Periods     );
   Chart.RestoreString(name +".input.MA.Method",       MA.Method      );
   Chart.RestoreString(name +".input.MA.AppliedPrice", MA.AppliedPrice);
   Chart.RestoreColor (name +".input.MA.Color",        MA.Color       );
   Chart.RestoreInt   (name +".input.MA.LineWidth",    MA.LineWidth   );
   Chart.RestoreDouble(name +".input.Bands.StdDevs",   Bands.StdDevs  );
   Chart.RestoreColor (name +".input.Bands.Color",     Bands.Color    );
   Chart.RestoreInt   (name +".input.Bands.LineWidth", Bands.LineWidth);
   Chart.RestoreInt   (name +".input.Max.Bars",        Max.Bars       );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("MA.Periods=",      MA.Periods,                        ";", NL,
                            "MA.Method=",       DoubleQuoteStr(MA.Method),         ";", NL,
                            "MA.AppliedPrice=", DoubleQuoteStr(MA.AppliedPrice),   ";", NL,
                            "MA.Color=",        ColorToStr(MA.Color),              ";", NL,
                            "MA.LineWidth=",    MA.LineWidth,                      ";", NL,
                            "Bands.StdDevs=",   NumberToStr(Bands.StdDevs, ".1+"), ";", NL,
                            "Bands.Color=",     ColorToStr(Bands.Color),           ";", NL,
                            "Bands.LineWidth=", Bands.LineWidth,                   ";", NL,
                            "Max.Bars=",        Max.Bars,                          ";")
   );
}

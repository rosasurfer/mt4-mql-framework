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
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    MA.Periods        = 200;
extern string MA.Method         = "SMA | LWMA | EMA | ALMA*";
extern string MA.AppliedPrice   = "Open | High | Low | Close* | Median | Typical | Weighted";
extern color  MA.Color          = LimeGreen;
extern int    MA.LineWidth      = 0;

extern double Bands.StdDevs     = 2;
extern color  Bands.Color       = RoyalBlue;
extern int    Bands.LineWidth   = 1;

extern int    Max.Bars          = 10000;              // max. values to calculate (-1: all available)

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

int    maMethod;
int    maAppliedPrice;
double almaWeights[];

string indicatorName;                                 // name for chart legend
string legendLabel;

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
   // validate inputs
   // MA.Periods
   if (MA.Periods < 1)        return(catch("onInit(1)  invalid input parameter MA.Periods: "+ MA.Periods, ERR_INVALID_INPUT_PARAMETER));

   // MA.Method
   string values[], sValue = MA.Method;
   if (Explode(MA.Method, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);
   maMethod = StrToMaMethod(sValue, F_ERR_INVALID_PARAMETER);
   if (maMethod == -1)        return(catch("onInit(2)  invalid input parameter MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   if (maMethod == MODE_SMMA) return(catch("onInit(3)  unsupported MA.Method: "+ DoubleQuoteStr(MA.Method), ERR_INVALID_INPUT_PARAMETER));
   MA.Method = MaMethodDescription(maMethod);

   // MA.AppliedPrice
   sValue = MA.AppliedPrice;
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrToLower(StrTrim(sValue));
   if (sValue == "") sValue = "close";                                  // default price type
   maAppliedPrice = StrToPriceType(sValue, F_PARTIAL_ID|F_ERR_INVALID_PARAMETER);
   if (maAppliedPrice==-1 || maAppliedPrice > PRICE_WEIGHTED)
                              return(catch("onInit(4)  invalid input parameter MA.AppliedPrice: "+ DoubleQuoteStr(MA.AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   MA.AppliedPrice = PriceTypeDescription(maAppliedPrice);

   // MA.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (MA.Color == 0xFF000000) MA.Color = CLR_NONE;

   // MA.LineWidth
   if (MA.LineWidth < 0)      return(catch("onInit(5)  invalid input parameter MA.LineWidth: "+ MA.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (MA.LineWidth > 5)      return(catch("onInit(6)  invalid input parameter MA.LineWidth: "+ MA.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Bands.StdDevs
   if (Bands.StdDevs < 0)     return(catch("onInit(7)  invalid input parameter Bands.StdDevs: "+ NumberToStr(Bands.StdDevs, ".1+"), ERR_INVALID_INPUT_PARAMETER));

   // Bands.Color: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Bands.Color == 0xFF000000) Bands.Color = CLR_NONE;

   // Bands.LineWidth
   if (Bands.LineWidth < 0)   return(catch("onInit(8)  invalid input parameter Bands.LineWidth: "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));
   if (Bands.LineWidth > 5)   return(catch("onInit(9)  invalid input parameter Bands.LineWidth: "+ Bands.LineWidth, ERR_INVALID_INPUT_PARAMETER));

   // Max.Bars
   if (Max.Bars < -1)         return(catch("onInit(10)  invalid input parameter Max.Bars: "+ Max.Bars, ERR_INVALID_INPUT_PARAMETER));

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
       legendLabel = CreateLegendLabel();
       RegisterObject(legendLabel);
   }

   // data display configuration, names and labels
   string sMaAppliedPrice = ifString(maAppliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(maAppliedPrice));
   indicatorName = ProgramName() +"("+ MA.Method +"("+ MA.Periods + sMaAppliedPrice +") ± "+ NumberToStr(Bands.StdDevs, ".1+") +")";
   IndicatorShortName(ProgramName() +"("+ MA.Periods +")");    // chart tooltips and context menu
   if (!MA.LineWidth || MA.Color==CLR_NONE) SetIndexLabel(MODE_MA, NULL);
   else                                     SetIndexLabel(MODE_MA, MA.Method +"("+ MA.Periods + sMaAppliedPrice +")");
   SetIndexLabel(MODE_UPPER, "UpperBand("+ MA.Periods +")");   // chart tooltips and "Data" window
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
   if (maMethod==MODE_ALMA && MA.Periods > 1) {
      @ALMA.CalculateWeights(almaWeights, MA.Periods);
   }
   return(catch("onInit(11)"));
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
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // on the first tick after terminal start buffers may not yet be initialized (spurious issue)
   if (!ArraySize(bufferMa)) return(logDebug("onTick(1)  size(buffeMa) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers before performing a full recalculation
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
   if (startBar < 0) return(logDebug("onTick(2)  Tick="+ Tick, ERR_HISTORY_INSUFFICIENT));


   // recalculate changed bars
   double deviation, price, sum;

   for (int bar=startBar; bar >= 0; bar--) {
      if (maMethod == MODE_ALMA) {
         bufferMa[bar] = 0;
         for (int i=0; i < MA.Periods; i++) {
            bufferMa[bar] += almaWeights[i] * iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+i);
         }
         // calculate deviation manually (for some reason iStdDevOnArray() fails)
         //deviation = iStdDevOnArray(bufferMa, WHOLE_ARRAY, MA.Periods, 0, MODE_SMA, bar) * StdDev.Multiplier;
         sum = 0;
         for (int j=0; j < MA.Periods; j++) {
            price = iMA(NULL, NULL, 1, 0, MODE_SMA, maAppliedPrice, bar+j);
            sum  += (price-bufferMa[bar]) * (price-bufferMa[bar]);
         }
         deviation = MathSqrt(sum/MA.Periods) * Bands.StdDevs;
      }
      else {
         bufferMa[bar] = iMA    (NULL, NULL, MA.Periods, 0, maMethod, maAppliedPrice, bar);
         deviation     = iStdDev(NULL, NULL, MA.Periods, 0, maMethod, maAppliedPrice, bar) * Bands.StdDevs;
      }
      bufferUpper[bar] = bufferMa[bar] + deviation;
      bufferLower[bar] = bufferMa[bar] - deviation;
   }


   // update chart legend
   if (!IsSuperContext()) {
      @Bands.UpdateLegend(legendLabel, indicatorName, signal.info, Bands.Color, bufferUpper[0], bufferLower[0], Digits, Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not be ignored.
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

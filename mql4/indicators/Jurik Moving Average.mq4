/**
 * JMA - Jurik Moving Average
 *
 *
 * Opposite to its name this indicator is a filter and not a moving average. Source is an MQL4 port of the JMA in TradeStation
 * of 1998 by Nikolay Kositsin. This implementation fixes some code conversion issues and does not repaint like the original.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 * @see     http://www.jurikres.com/catalog1/ms_ama.htm
 *
 * @source  https://www.mql5.com/en/articles/1450
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods              = 14;
extern int    Phase                = 0;                  // indicator overshooting: -100 (none)...+100 (max)
extern string AppliedPrice         = "Open | High | Low | Close* | Median | Typical | Weighted";

extern color  Color.UpTrend        = Blue;
extern color  Color.DownTrend      = Red;
extern string Draw.Type            = "Line* | Dot";
extern int    Draw.Width           = 3;
extern int    Max.Values           = 5000;               // max. amount of values to calculate (-1: all)
extern string __________________________;

extern string Signal.onTrendChange = "on | off | auto*";
extern string Signal.Sound         = "on | off | auto*";
extern string Signal.Mail.Receiver = "on | off | auto* | {email-address}";
extern string Signal.SMS.Receiver  = "on | off | auto* | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/@Trend.mqh>
#include <functions/BarOpenEvent.mqh>
#include <functions/Configure.Signal.mqh>
#include <functions/Configure.Signal.Mail.mqh>
#include <functions/Configure.Signal.SMS.mqh>
#include <functions/Configure.Signal.Sound.mqh>

#define MODE_MA               MovingAverage.MODE_MA      // indicator buffer ids
#define MODE_TREND            MovingAverage.MODE_TREND
#define MODE_UPTREND          2
#define MODE_DOWNTREND        3
#define MODE_UPTREND1         MODE_UPTREND
#define MODE_UPTREND2         4

#property indicator_chart_window
#property indicator_buffers   5

#property indicator_color1    CLR_NONE
#property indicator_color2    CLR_NONE
#property indicator_color3    CLR_NONE
#property indicator_color4    CLR_NONE
#property indicator_color5    CLR_NONE

double main     [];                                      // MA main values:      invisible, displayed in legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed in "Data" window
double uptrend1 [];                                      // uptrend values:      visible
double downtrend[];                                      // downtrend values:    visible
double uptrend2 [];                                      // single-bar uptrends: visible

double dLengthDivider, dPhaseParam, dLogParam, dSqrtParam, dSqrtDivider;

int    appliedPrice;

int    maxValues;
int    drawType      = DRAW_LINE;                        // DRAW_LINE | DRAW_ARROW
int    drawArrowSize = 1;                                // default symbol size for Draw.Type="dot"

string indicatorName;
string chartLegendLabel;
int    chartLegendDigits;

bool   signals;

bool   signal.sound;
string signal.sound.trendChange_up   = "Signal-Up.wav";
string signal.sound.trendChange_down = "Signal-Down.wav";

bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";

bool   signal.sms;
string signal.sms.receiver = "";

string signal.info = "";                                 // additional chart legend info


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
   // Periods
   if (Periods < 1)     return(catch("onInit(1)  Invalid input parameter Periods = "+ Periods, ERR_INVALID_INPUT_PARAMETER));

   // Phase
   if (Phase < -100)    return(catch("onInit(2)  Invalid input parameter Phase = "+ Phase +" (-100..+100)", ERR_INVALID_INPUT_PARAMETER));
   if (Phase > +100)    return(catch("onInit(3)  Invalid input parameter Phase = "+ Phase +" (-100..+100)", ERR_INVALID_INPUT_PARAMETER));

   // AppliedPrice
   string sValues[], sValue = StrToLower(AppliedPrice);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      int size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if (sValue == "") sValue = "close";                // default price type
   appliedPrice = StrToPriceType(sValue, F_ERR_INVALID_PARAMETER);
   if (IsEmpty(appliedPrice)) {
      if      (StrStartsWith("open",     sValue)) appliedPrice = PRICE_OPEN;
      else if (StrStartsWith("high",     sValue)) appliedPrice = PRICE_HIGH;
      else if (StrStartsWith("low",      sValue)) appliedPrice = PRICE_LOW;
      else if (StrStartsWith("close",    sValue)) appliedPrice = PRICE_CLOSE;
      else if (StrStartsWith("median",   sValue)) appliedPrice = PRICE_MEDIAN;
      else if (StrStartsWith("typical",  sValue)) appliedPrice = PRICE_TYPICAL;
      else if (StrStartsWith("weighted", sValue)) appliedPrice = PRICE_WEIGHTED;
      else              return(catch("onInit(4)  Invalid input parameter AppliedPrice = "+ DoubleQuoteStr(AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   AppliedPrice = PriceTypeDescription(appliedPrice);

   // colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.UpTrend   == 0xFF000000) Color.UpTrend   = CLR_NONE;
   if (Color.DownTrend == 0xFF000000) Color.DownTrend = CLR_NONE;

   // Draw.Type
   sValue = StrToLower(Draw.Type);
   if (Explode(sValue, "*", sValues, 2) > 1) {
      size = Explode(sValues[0], "|", sValues, NULL);
      sValue = sValues[size-1];
   }
   sValue = StrTrim(sValue);
   if      (StrStartsWith("line", sValue)) { drawType = DRAW_LINE;  Draw.Type = "Line"; }
   else if (StrStartsWith("dot",  sValue)) { drawType = DRAW_ARROW; Draw.Type = "Dot";  }
   else                 return(catch("onInit(5)  Invalid input parameter Draw.Type = "+ DoubleQuoteStr(Draw.Type), ERR_INVALID_INPUT_PARAMETER));

   // Draw.Width
   if (Draw.Width < 0)  return(catch("onInit(6)  Invalid input parameter Draw.Width = "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Draw.Width > 5)  return(catch("onInit(7)  Invalid input parameter Draw.Width = "+ Draw.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1) return(catch("onInit(8)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));
   maxValues = ifInt(Max.Values==-1, INT_MAX, Max.Values);

   // signals
   if (!Configure.Signal(__NAME(), Signal.onTrendChange, signals))                                              return(last_error);
   if (signals) {
      if (!Configure.Signal.Sound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!Configure.Signal.Mail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
      if (!Configure.Signal.SMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (signal.sound || signal.mail || signal.sms) {
         signal.info = "TrendChange="+ StrLeft(ifString(signal.sound, "Sound,", "") + ifString(signal.mail, "Mail,", "") + ifString(signal.sms, "SMS,", ""), -1);
      }
      else signals = false;
   }

   // buffer management
   SetIndexBuffer(MODE_MA,        main     );            // MA main values:   invisible, displayed in legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:  invisible, displayed in "Data" window
   SetIndexBuffer(MODE_UPTREND1,  uptrend1 );            // uptrend values:   visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values: visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // on-bar uptrends:  visible

   // chart legend
   string sAppliedPrice = ifString(appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(appliedPrice));
   indicatorName = "JMA"+ ifString(StrEndsWithI(__NAME(), "spiggy"), ".spiggy", "") +"("+ Periods + sAppliedPrice +")";
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel(indicatorName);
       ObjectRegister(chartLegendLabel);
      chartLegendDigits = ifInt(StrEndsWithI(__NAME(), "spiggy"), SubPipDigits+1, Digits);
   }

   // names, labels, styles and display options
   string shortName = "JMA("+ Periods +")";
   IndicatorShortName(shortName);
   SetIndexLabel(MODE_MA,        shortName);             // chart tooltips and "Data" window
   SetIndexLabel(MODE_TREND,     shortName +" trend");
   SetIndexLabel(MODE_UPTREND1,  NULL);
   SetIndexLabel(MODE_DOWNTREND, NULL);
   SetIndexLabel(MODE_UPTREND2,  NULL);
   IndicatorDigits(Digits);
   SetIndicatorOptions();

   // initialize JMA calculation
   double dLengthParam = MathMax(0.0000000001, (Periods-1)/2.);
   dLengthDivider = dLengthParam*0.9 / (dLengthParam*0.9 + 2);
   dPhaseParam    = Phase/100. + 1.5;
   dLogParam      = MathMax(0, MathLog(MathSqrt(dLengthParam))/MathLog(2) + 2);
   dSqrtParam     = MathSqrt(dLengthParam) * dLogParam;
   dSqrtDivider   = dSqrtParam/(dSqrtParam + 1);

   return(catch("onInit(9)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);
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
   // a not initialized buffer can happen on terminal start under specific circumstances
   if (!ArraySize(main))
      return(log("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(main,      EMPTY_VALUE);
      ArrayInitialize(trend,               0);
      ArrayInitialize(uptrend1,  EMPTY_VALUE);
      ArrayInitialize(downtrend, EMPTY_VALUE);
      ArrayInitialize(uptrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(main,      Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(uptrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(downtrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(uptrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }


   // TODO: Fix me ----------------------------------------------------------------------------------------------------------
   if (Periods < 2)              // MTF: Abbruch bei ma.periods < 2 (möglich bei Umschalten auf zu großen Timeframe)
      return(NO_ERROR);
   if (ChangedBars < 2)          // !!! repainting bug: vorübergehender Workaround bei Realtime-Update,
      return(NO_ERROR);          //                     JMA wird jetzt nur bei onBarOpen aktualisiert
   if (ChangedBars == 2)
      ChangedBars = Bars;        // !!! WE MUST NOT MODIFY var ChangedBars !!!
   // TODO: Fix me ----------------------------------------------------------------------------------------------------------



   // calculate start bar
   int bars     = Min(ChangedBars, maxValues);
   int startBar = Min(bars-1, Bars-Periods);
   if (startBar < 0) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));



   // TODO: Fix me ----------------------------------------------------------------------------------------------------------
   // JMA initialization
   double dValue, dCycleDelta, dLowValue, dHighValue, dSValue, dParamA, dParamB, dSDiffParamA, dSDiffParamB, dAbsValue, dPowerValue, dSquareValue;
   int    iCounterA, iCounterB, iCycleLimit, iLoopParam, iHighLimit, iLoopCriteria;
   int    i1, i2, i3, i4, i5;
   double dPrice, dJMATmp1, dJMATmp2, dJMATmp3, dJMATmp4, dJMA;

   double dList128 [128];
   double dRing128 [128];
   double dRing11  [ 11];
   double dPrices62[ 62];

   int iLimitValue = 63;
   int iStartValue = 64;

   ArrayInitialize(dList128, -1000000); for (int i=iStartValue; i < 127; i++) dList128[i] = 1000000;
   ArrayInitialize(dRing128,        0);
   ArrayInitialize(dRing11,         0);
   ArrayInitialize(dPrices62,       0);

   bool bInitFlag = true;
   // TODO: Fix me ----------------------------------------------------------------------------------------------------------



   // recalculate changed bars
   for (int bar=startBar; bar >= 0; bar--) {
      dPrice = iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar);

      if (iLoopParam < 61) {
         dPrices62[iLoopParam] = dPrice;
         iLoopParam++;
      }

      if (iLoopParam > 30) {
         iHighLimit = 0;

         if (bInitFlag) {
            dParamB = dPrice;

            for (i=0; i < 30; i++) {
               if (NE(dPrices62[i], dPrices62[i+1], Digits)) {
                  iHighLimit = 29;
                  dParamB = dPrices62[1];
                  break;
               }
            }
            dParamA = dParamB;
            bInitFlag = false;
         }

         // big cycle
         for (i=iHighLimit; i >= 0; i--) {
            if (i == 0) dSValue = dPrice;
            else        dSValue = dPrices62[31-i];

            dSDiffParamA = dSValue - dParamA;
            dSDiffParamB = dSValue - dParamB;
            if (MathAbs(dSDiffParamA) > MathAbs(dSDiffParamB)) dAbsValue = MathAbs(dSDiffParamA);
            else                                               dAbsValue = MathAbs(dSDiffParamB);
            dValue = dAbsValue + 0.0000000001;

            if (iCounterA <= 1) iCounterA = 127;
            else                iCounterA--;
            if (iCounterB <= 1) iCounterB = 10;
            else                iCounterB--;
            if (iCycleLimit < 128)
               iCycleLimit++;

            dCycleDelta       += dValue - dRing11[iCounterB];
            dRing11[iCounterB] = dValue;

            if (iCycleLimit > 10) dHighValue = dCycleDelta / 10;
            else                  dHighValue = dCycleDelta / iCycleLimit;

            if (iCycleLimit > 127) {
               dValue              = dRing128[iCounterA];
               dRing128[iCounterA] = dHighValue;
               i1 = 64;
               i2 = 64;

               while (i1 > 1) {
                  if (dList128[i2] < dValue) {
                     i1 >>= 1;
                     i2 += i1;
                  }
                  else if (dList128[i2] > dValue) {
                     i1 >>= 1;
                     i2 -= i1;
                  }
                  else {
                     i1 = 1;
                  }
               }
            }
            else {
               dRing128[iCounterA] = dHighValue;
               if (iLimitValue + iStartValue > 127) {
                  iStartValue--;
                  i2 = iStartValue;
               }
               else {
                  iLimitValue++;
                  i2 = iLimitValue;
               }
               if (iLimitValue > 96) i4 = 96;
               else                  i4 = iLimitValue;
               if (iStartValue < 32) i5 = 32;
               else                  i5 = iStartValue;
            }

            i1 = 64;
            i3 = 64;

            while (i1 > 1) {
               if (dList128[i3] < dHighValue) {
                  i1 >>= 1;
                  i3 += i1;
               }
               else if (dList128[i3-1] > dHighValue) {
                  i1 >>= 1;
                  i3 -= i1;
               }
               else {
                  i1 = 1;
               }
               if (i3==127 && dHighValue > dList128[127])
                  i3 = 128;
            }

            if (iCycleLimit > 127) {
               if (i2 >= i3) {
                  if      (i4+1 > i3 && i5-1 < i3) dLowValue += dHighValue;
                  else if (i5   > i3 && i5-1 < i2) dLowValue += dList128[i5-1];
               }
               else if (i5 >= i3) {
                  if      (i4+1 < i3 && i4+1 > i2) dLowValue += dList128[i4+1];
               }
               else if    (i4+2 > i3             ) dLowValue += dHighValue;
               else if    (i4+1 < i3 && i4+1 > i2) dLowValue += dList128[i4+1];

               if (i2 > i3) {
                  if      (i5-1 < i2 && i4+1 > i2) dLowValue -= dList128[i2];
                  else if (i4   < i2 && i4+1 > i3) dLowValue -= dList128[i4];
               }
               else if    (i4+1 > i2 && i5-1 < i2) dLowValue -= dList128[i2];
               else if    (i5   > i2 && i5   < i3) dLowValue -= dList128[i5];
            }

            if      (i2 > i3) { for (int j=i2-1; j >= i3;   j--) dList128[j+1] = dList128[j]; dList128[i3]   = dHighValue; }
            else if (i2 < i3) { for (    j=i2+1; j <= i3-1; j++) dList128[j-1] = dList128[j]; dList128[i3-1] = dHighValue; }
            else              {                                                               dList128[i3]   = dHighValue; }

            if (iCycleLimit <= 127) {
               dLowValue = 0;
               for (j=i5; j <= i4; j++) {
                  dLowValue += dList128[j];
               }
            }

            iLoopCriteria++;
            if (iLoopCriteria > 31) iLoopCriteria = 31;

            if (iLoopCriteria <= 30) {
               if (dSDiffParamA > 0) dParamA = dSValue;
               else                  dParamA = dSValue - dSDiffParamA * dSqrtDivider;
               if (dSDiffParamB < 0) dParamB = dSValue;
               else                  dParamB = dSValue - dSDiffParamB * dSqrtDivider;

               dJMATmp4 = dPrice;
               if (iLoopCriteria != 30)
                  continue;

               dJMATmp1 = dPrice;

               int iLeftInt=1, iRightPart=1;
               if (dSqrtParam >  0) iLeftInt   = dSqrtParam + 1;
               if (dSqrtParam >= 1) iRightPart = dSqrtParam;

               dValue = MathDiv(dSqrtParam-iRightPart, iLeftInt-iRightPart, 1);

               int iUpShift=29, iDnShift=29;
               if (iRightPart <= 29) iUpShift = iRightPart;
               if (iLeftInt   <= 29) iDnShift = iLeftInt;

               dJMATmp3 = (dPrice-dPrices62[iLoopParam-iUpShift]) * (1-dValue)/iRightPart + (dPrice-dPrices62[iLoopParam-iDnShift]) * dValue/iLeftInt;
            }
            else {
               dValue = dLowValue/(i4 - i5 + 1);

               dPowerValue = dLogParam - 2;
               if (dPowerValue < 0.5) dPowerValue = 0.5;

               dValue = MathPow(dAbsValue/dValue, dPowerValue);
               if (dValue > dLogParam) dValue = dLogParam;
               if (dValue < 1)         dValue = 1;

               dPowerValue = MathPow(dSqrtDivider, MathSqrt(dValue));

               if (dSDiffParamA > 0) dParamA = dSValue;
               else                  dParamA = dSValue - dSDiffParamA * dPowerValue;
               if (dSDiffParamB < 0) dParamB = dSValue;
               else                  dParamB = dSValue - dSDiffParamB * dPowerValue;
            }
         }

         if (iLoopCriteria > 30) {
            dPowerValue  = MathPow(dLengthDivider, dValue);
            dSquareValue = MathPow(dPowerValue, 2);

            dJMATmp1  = (1-dPowerValue) * dPrice + dPowerValue * dJMATmp1;
            dJMATmp2  = (dPrice-dJMATmp1) * (1-dLengthDivider) + dLengthDivider * dJMATmp2;
            dJMATmp3  = (dPhaseParam * dJMATmp2 + dJMATmp1 - dJMATmp4) * (-dPowerValue * 2 + dSquareValue + 1) + dSquareValue * dJMATmp3;
            dJMATmp4 += dJMATmp3;
         }
         dJMA = dJMATmp4;
      }
      else {
         dJMA = EMPTY_VALUE;
      }
      main[bar] = dJMA;

      @Trend.UpdateDirection(main, bar, trend, uptrend1, downtrend, uptrend2, drawType, true, true, Digits);
   }

   if (!IsSuperContext()) {
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, signal.info, Color.UpTrend, Color.DownTrend, main[0], chartLegendDigits, trend[0], Time[0]);

      if (signals) /*&&*/ if (IsBarOpenEvent()) {
         if      (trend[1] ==  1) onTrendChange(MODE_UPTREND);
         else if (trend[1] == -1) onTrendChange(MODE_DOWNTREND);
      }
   }
   return(last_error);
}


/**
 * Event handler for trend changes.
 *
 * @param  int trend - direction
 *
 * @return bool - success status
 */
bool onTrendChange(int trend) {
   string message="", accountTime="("+ TimeToStr(TimeLocal(), TIME_MINUTES|TIME_SECONDS) +", "+ AccountAlias(ShortAccountCompany(), GetAccountNumber()) +")";
   int error = 0;

   if (trend == MODE_UPTREND) {
      message = indicatorName +" turned up (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (__LOG()) log("onTrendChange(1)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_up);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   if (trend == MODE_DOWNTREND) {
      message = indicatorName +" turned down (market: "+ NumberToStr((Bid+Ask)/2, PriceFormat) +")";
      if (__LOG()) log("onTrendChange(2)  "+ message);
      message = Symbol() +","+ PeriodDescription(Period()) +": "+ message;

      if (signal.sound) error |= !PlaySoundEx(signal.sound.trendChange_down);
      if (signal.mail)  error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message +NL+ accountTime);
      if (signal.sms)   error |= !SendSMS(signal.sms.receiver, message +NL+ accountTime);
      return(!error);
   }

   return(!catch("onTrendChange(3)  invalid parameter trend = "+ trend, ERR_INVALID_PARAMETER));
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set in init(). However after
 * recompilation options must be set in start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int draw_type  = ifInt(Draw.Width, drawType, DRAW_NONE);
   int draw_width = ifInt(drawType==DRAW_ARROW, drawArrowSize, Draw.Width);

   if (StrEndsWithI(__NAME(), "spiggy")) {
      draw_width      = 2;
      Color.UpTrend   = Gold;
      Color.DownTrend = Gold;
   }

   SetIndexStyle(MODE_MA,        DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  draw_type, EMPTY, draw_width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, draw_width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, draw_width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Store input parameters in the chart before recompilation.
 *
 * @return bool - success status
 */
bool StoreInputParameters() {
   string name = __NAME();
   Chart.StoreInt   (name +".input.Periods",              Periods              );
   Chart.StoreInt   (name +".input.Phase",                Phase                );
   Chart.StoreString(name +".input.AppliedPrice",         AppliedPrice         );
   Chart.StoreColor (name +".input.Color.UpTrend",        Color.UpTrend        );
   Chart.StoreColor (name +".input.Color.DownTrend",      Color.DownTrend      );
   Chart.StoreString(name +".input.Draw.Type",            Draw.Type            );
   Chart.StoreInt   (name +".input.Draw.Width",           Draw.Width           );
   Chart.StoreInt   (name +".input.Max.Values",           Max.Values           );
   Chart.StoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange );
   Chart.StoreString(name +".input.Signal.Sound",         Signal.Sound         );
   Chart.StoreString(name +".input.Signal.Mail.Receiver", Signal.Mail.Receiver );
   Chart.StoreString(name +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver  );
   return(!catch("StoreInputParameters(1)"));
}


/**
 * Restore input parameters found in the chart after recompilation.
 *
 * @return bool - success status
 */
bool RestoreInputParameters() {
   string name = __NAME();
   Chart.RestoreInt   (name +".input.Periods",              Periods              );
   Chart.RestoreInt   (name +".input.Phase",                Phase                );
   Chart.RestoreString(name +".input.AppliedPrice",         AppliedPrice         );
   Chart.RestoreColor (name +".input.Color.UpTrend",        Color.UpTrend        );
   Chart.RestoreColor (name +".input.Color.DownTrend",      Color.DownTrend      );
   Chart.RestoreString(name +".input.Draw.Type",            Draw.Type            );
   Chart.RestoreInt   (name +".input.Draw.Width",           Draw.Width           );
   Chart.RestoreInt   (name +".input.Max.Values",           Max.Values           );
   Chart.RestoreString(name +".input.Signal.onTrendChange", Signal.onTrendChange );
   Chart.RestoreString(name +".input.Signal.Sound",         Signal.Sound         );
   Chart.RestoreString(name +".input.Signal.Mail.Receiver", Signal.Mail.Receiver );
   Chart.RestoreString(name +".input.Signal.SMS.Receiver",  Signal.SMS.Receiver  );
   return(!catch("RestoreInputParameters(1)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Periods=",              Periods,                              ";", NL,
                            "Phase=",                Phase,                                ";", NL,
                            "AppliedPrice=",         DoubleQuoteStr(AppliedPrice),         ";", NL,
                            "Color.UpTrend=",        ColorToStr(Color.UpTrend),            ";", NL,
                            "Color.DownTrend=",      ColorToStr(Color.DownTrend),          ";", NL,
                            "Draw.Type=",            DoubleQuoteStr(Draw.Type),            ";", NL,
                            "Draw.Width=",           Draw.Width,                           ";", NL,
                            "Max.Values=",           Max.Values,                           ";", NL,
                            "Signal.onTrendChange=", DoubleQuoteStr(Signal.onTrendChange), ";", NL,
                            "Signal.Sound=",         DoubleQuoteStr(Signal.Sound),         ";", NL,
                            "Signal.Mail.Receiver=", DoubleQuoteStr(Signal.Mail.Receiver), ";", NL,
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(Signal.SMS.Receiver),  ";")
   );
}

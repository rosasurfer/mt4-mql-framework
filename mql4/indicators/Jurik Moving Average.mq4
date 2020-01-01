/**
 * JMA - Adaptive Jurik Moving Average
 *
 *
 * Opposite to its name this indicator is an adaptive filter and not a moving average. Source is an MQL4 port of the JMA as
 * found in TradeStation of 1998, authored under the synonym "Spiggy". It did not account for the lack of tick support in
 * that TradeStation version which made the resulting indicator repaint. This implementation uses the original algorythm but
 * fixes the code conversion issues. It does not repaint.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend in bars since the last reversal
 *
 * @source  Spiggy: https://www.mql5.com/ru/code/7307
 * @see     http://www.jurikres.com/catalog1/ms_ama.htm
 * @see     "/etc/doc/jurik/Jurik Research Product Guide [2015.09].pdf"
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int    Periods              = 14;
extern string AppliedPrice         = "Open | High | Low | Close* | Median | Typical | Weighted";
extern int    Phase                = 0;                  // indicator overshooting: -100 (none)...+100 (max)

extern color  Color.UpTrend        = DodgerBlue;
extern color  Color.DownTrend      = Orange;
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
      else              return(catch("onInit(2)  Invalid input parameter AppliedPrice = "+ DoubleQuoteStr(AppliedPrice), ERR_INVALID_INPUT_PARAMETER));
   }
   AppliedPrice = PriceTypeDescription(appliedPrice);

   // Phase
   if (Phase < -100)    return(catch("onInit(3)  Invalid input parameter Phase = "+ Phase +" (-100..+100)", ERR_INVALID_INPUT_PARAMETER));
   if (Phase > +100)    return(catch("onInit(4)  Invalid input parameter Phase = "+ Phase +" (-100..+100)", ERR_INVALID_INPUT_PARAMETER));

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
   int    i01, i02, i03, i04, i05, i06, i07, i08, i09, i10, iLoopParam, iHighLimit, iLoopCriteria;
   double d02, d03, d04, d05, d06, d07, d08, dHighValue, dSValue, dParamA, dParamB, d13, d14, d15, d17, d18, dLengthDivider, d20, d21, d22, d24, d26, dSqrtDivider, d28, dAbsValue, d30, d31, d32, d33, d34;
   double dJMA, dPrice;

   double dList127 [127];
   double dRing127 [127];
   double dRing10  [ 10];
   double dPrices61[ 61];

   ArrayInitialize(dList127, -1000000);
   ArrayInitialize(dRing127,        0);
   ArrayInitialize(dRing10,         0);
   ArrayInitialize(dPrices61,       0);

   int iLimitValue = 63;
   int iStartValue = 64;

   for (int i=iLimitValue; i < 127; i++) {
      dList127[i] = 1000000;
   }

   double dLengthParam = (Periods-1) / 2.;
   double dPhaseParam  = Phase/100. + 1.5;
   bool   bInitFlag    = true;
   // TODO: Fix me ----------------------------------------------------------------------------------------------------------



   // recalculate changed bars
   // main cycle
   for (int bar=startBar; bar >= 0; bar--) {
      dPrice = iMA(NULL, NULL, 1, 0, MODE_SMA, appliedPrice, bar);

      if (iLoopParam < 61) {
         dPrices61[iLoopParam] = dPrice;
         iLoopParam++;
      }

      if (iLoopParam > 30) {
         d02 = MathLog(MathSqrt(dLengthParam));
         d03 = d02;
         d04 = d02/MathLog(2) + 2;
         if (d04 < 0)
            d04 = 0;
         d28 = d04;
         d26 = d28 - 2;
         if (d26 < 0.5)
            d26 = 0.5;

         d24            = MathSqrt(dLengthParam) * d28;
         dSqrtDivider   = d24/(d24 + 1);
         dLengthDivider = dLengthParam*0.9 / (dLengthParam*0.9 + 2);

         if (bInitFlag) {
            bInitFlag = false;
            i01        = 0;
            iHighLimit = 0;
            dParamB = dPrice;
            for (i=0; i < 30; i++) {
               if (!EQ(dPrices61[i], dPrices61[i+1], Digits)) {
                  i01        = 1;
                  iHighLimit = 29;
                  dParamB = dPrices61[0];
                  break;
               }
            }
            dParamA = dParamB;
         }
         else {
            iHighLimit = 0;
         }

         // big cycle
         for (i=iHighLimit; i >= 0; i--) {
            if (i == 0) dSValue = dPrice;
            else        dSValue = dPrices61[30-i];

            d14 = dSValue - dParamA;
            d18 = dSValue - dParamB;
            if (MathAbs(d14) > MathAbs(d18)) d03 = MathAbs(d14);
            else                             d03 = MathAbs(d18);
            dAbsValue     = d03;
            double dValue = dAbsValue + 0.0000000001;

            if (i05 <= 1) i05 = 127;
            else          i05--;
            if (i06 <= 1) i06 = 10;
            else          i06--;
            if (i10 < 128)
               i10++;

            d06           += dValue - dRing10[i06-1];
            dRing10[i06-1] = dValue;

            if (i10 > 10) dHighValue = d06/10;
            else          dHighValue = d06/i10;

            if (i10 > 127) {
               d07             = dRing127[i05-1];
               dRing127[i05-1] = dHighValue;
               i09 = 64;
               i07 = i09;
               while (i09 > 1) {
                  if (dList127[i07-1] < d07) {
                     i09 >>= 1;
                     i07  += i09;
                  }
                  else if (dList127[i07-1] > d07) {
                     i09 >>= 1;
                     i07  -= i09;
                  }
                  else {
                     i09 = 1;
                  }
               }
            }
            else {
               dRing127[i05-1] = dHighValue;
               if (iLimitValue + iStartValue > 127) {
                  iStartValue--;
                  i07 = iStartValue;
               }
               else {
                  iLimitValue++;
                  i07 = iLimitValue;
               }
               if (iLimitValue > 96) i03 = 96;
               else                  i03 = iLimitValue;
               if (iStartValue < 32) i04 = 32;
               else                  i04 = iStartValue;
            }

            i09 = 64;
            i08 = i09;

            while (i09 > 1) {
               if (dList127[i08-1] < dHighValue) {
                  i09 >>= 1;
                  i08  += i09;
               }
               else if (dList127[i08-2] > dHighValue) {
                  i09 >>= 1;
                  i08  -= i09;
               }
               else {
                  i09 = 1;
               }
               if (i08==127 && dHighValue > dList127[126])
                  i08 = 128;
            }

            if (i10 > 127) {
               if (i07 >= i08) {
                  if      (i03+1 > i08 && i04-1 < i08) d08 += dHighValue;
                  else if (i04   > i08 && i04-1 < i07) d08 += dList127[i04-2];
               }
               else if (i04 >= i08) {
                  if      (i03+1 < i08 && i03+1 > i07) d08 += dList127[i03];
               }
               else if    (i03+2 > i08               ) d08 += dHighValue;
               else if    (i03+1 < i08 && i03+1 > i07) d08 += dList127[i03];

               if (i07 > i08) {
                  if      (i04-1 < i07 && i03+1 > i07) d08 -= dList127[i07-1];
                  else if (i03   < i07 && i03+1 > i08) d08 -= dList127[i03-1];
               }
               else if    (i03+1 > i07 && i04-1 < i07) d08 -= dList127[i07-1];
               else if    (i04   > i07 && i04   < i08) d08 -= dList127[i04-1];
            }

            if      (i07 > i08) { for (int j=i07-1; j >= i08;   j--) dList127[j  ] = dList127[j-1]; dList127[i08-1] = dHighValue; }
            else if (i07 < i08) { for (    j=i07+1; j <= i08-1; j++) dList127[j-2] = dList127[j-1]; dList127[i08-2] = dHighValue; }
            else                {                                                                   dList127[i08-1] = dHighValue; }

            if (i10 <= 127) {
               d08 = 0;
               for (j=i04; j <= i03; j++) {
                  d08 += dList127[j-1];
               }
            }
            d21 = d08/(i03 - i04 + 1);

            iLoopCriteria++;
            if (iLoopCriteria > 31) iLoopCriteria = 31;

            if (iLoopCriteria <= 30) {
               if (d14 > 0) dParamA = dSValue;
               else         dParamA = dSValue - d14 * dSqrtDivider;
               if (d18 < 0) dParamB = dSValue;
               else         dParamB = dSValue - d18 * dSqrtDivider;

               d32 = dPrice;

               if (iLoopCriteria == 30) {
                  d33 = dPrice;
                  if (d24 > 0)  d05 = MathCeil(d24);
                  else          d05 = 1;
                  if (d24 >= 1) d03 = MathFloor(d24);
                  else          d03 = 1;

                  if (d03 == d05) d22 = 1;
                  else            d22 = (d24-d03) / (d05-d03);

                  if (d03 <= 29) i01 = d03;
                  else           i01 = 29;
                  if (d05 <= 29) i02 = d05;
                  else           i02 = 29;

                  d30 = (dPrice-dPrices61[iLoopParam-i01-1]) * (1-d22)/d03 + (dPrice-dPrices61[iLoopParam-i02-1]) * d22/d05;
               }
            }
            else {
               d02 = MathPow(dAbsValue/d21, d26);
               if (d02 > d28)
                  d02 = d28;

               if (d02 < 1) {
                  d03 = 1;
               }
               else {
                  d03 = d02;
                  d04 = d02;
               }
               d20 = d03;
               double dPowerValue1 = MathPow(dSqrtDivider, MathSqrt(d20));

               if (d14 > 0) dParamA = dSValue;
               else         dParamA = dSValue - d14 * dPowerValue1;
               if (d18 < 0) dParamB = dSValue;
               else         dParamB = dSValue - d18 * dPowerValue1;
            }
         }

         if (iLoopCriteria > 30) {
            d15  = MathPow(dLengthDivider, d20);
            d33  = (1-d15) * dPrice + d15 * d33;
            d34  = (dPrice-d33) * (1-dLengthDivider) + dLengthDivider * d34;
            d13  = -d15 * 2;
            d17  = d15 * d15;
            d31  = d13 + d17 + 1;
            d30  = (dPhaseParam * d34 + d33 - d32) * d31 + d17 * d30;
            d32 += d30;
         }
         dJMA = d32;
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
   Chart.StoreString(name +".input.AppliedPrice",         AppliedPrice         );
   Chart.StoreInt   (name +".input.Phase",                Phase                );
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
   Chart.RestoreString(name +".input.AppliedPrice",         AppliedPrice         );
   Chart.RestoreInt   (name +".input.Phase",                Phase                );
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
                            "AppliedPrice=",         DoubleQuoteStr(AppliedPrice),         ";", NL,
                            "Phase=",                Phase,                                ";", NL,
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

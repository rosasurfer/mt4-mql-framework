/**
 * JMA - Jurik Moving Average
 *
 *
 * This indicator is a rewritten version of the MQL4 port of the TradeStation JMA of 1998 by Nikolay Kositsin.
 *
 * Indicator buffers for iCustom():
 *  • MovingAverage.MODE_MA:    MA values
 *  • MovingAverage.MODE_TREND: trend direction and length
 *    - trend direction:        positive values denote an uptrend (+1...+n), negative values a downtrend (-1...-n)
 *    - trend length:           the absolute direction value is the length of the trend iN bars since the last reversal
 *
 * @see     http://www.jurikres.com/catalog1/ms_ama.htm
 * @see     "/etc/doc/jurik/Jurik Research Product Guide [2015.09].pdf"
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

double main     [];                                      // MA main values:      invisible, displayed iN legend and "Data" window
double trend    [];                                      // trend direction:     invisible, displayed iN "Data" window
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

bool   signals;                                          // whether any signal is enabled
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
   SetIndexBuffer(MODE_MA,        main     );            // MA main values:   invisible, displayed iN legend and "Data" window
   SetIndexBuffer(MODE_TREND,     trend    );            // trend direction:  invisible, displayed iN "Data" window
   SetIndexBuffer(MODE_UPTREND1,  uptrend1 );            // uptrend values:   visible
   SetIndexBuffer(MODE_DOWNTREND, downtrend);            // downtrend values: visible
   SetIndexBuffer(MODE_UPTREND2,  uptrend2 );            // on-bar uptrends:  visible

   // chart legend
   string sAppliedPrice = ifString(appliedPrice==PRICE_CLOSE, "", ", "+ PriceTypeDescription(appliedPrice));
   indicatorName = "JMA("+ Periods + sAppliedPrice +")";
   if (!IsSuperContext()) {
       chartLegendLabel = CreateLegendLabel(indicatorName);
       ObjectRegister(chartLegendLabel);
      chartLegendDigits = ifInt(Color.UpTrend==Color.DownTrend, 4, Digits);
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
   if (JJMASeriesResize(1) != 1)
      return(catch("onInit(9)", ERR_RUNTIME_ERROR));

   return(catch("onInit(10)"));
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
   if (!ArraySize(main)) return(log("onTick(1)  size(main) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!UnchangedBars) {
      ArrayInitialize(main,                0);
      ArrayInitialize(trend,               0);
      ArrayInitialize(uptrend1,  EMPTY_VALUE);
      ArrayInitialize(downtrend, EMPTY_VALUE);
      ArrayInitialize(uptrend2,  EMPTY_VALUE);
      SetIndicatorOptions();
   }

   // synchronize buffers with a shifted offline chart
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(main,      Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(trend,     Bars, ShiftedBars,           0);
      ShiftIndicatorBuffer(uptrend1,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(downtrend, Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(uptrend2,  Bars, ShiftedBars, EMPTY_VALUE);
   }

   // calculate start bar
   if (Bars < 32) return(catch("onTick(2)", ERR_HISTORY_INSUFFICIENT));
   int validBars = IndicatorCounted(), error;
   if (validBars > 0) validBars--;
   int oldestBar = Bars-1;
   int startBar  = oldestBar - validBars;          // TODO: startBar is 1 (one) too big

   // recalculate changed bars
   for (int bar=startBar; bar >= 0; bar--) {
       main[bar] = JJMASeries(0, 0, oldestBar, startBar, Periods, Phase, Close[bar], bar, error);
       if (IsError(error)) return(catch("onTick(2)", error));
   }

   if (!IsSuperContext()) {
      @Trend.UpdateLegend(chartLegendLabel, indicatorName, signal.info, Color.UpTrend, Color.DownTrend, main[0], 4, NULL, Time[0]);
   }
   return(last_error);
}


/**
 * Workaround for various terminal bugs when setting indicator options. Usually options are set iN init(). However after
 * recompilation options must be set iN start() to not get ignored.
 */
void SetIndicatorOptions() {
   IndicatorBuffers(indicator_buffers);

   int draw_type  = ifInt(Draw.Width, drawType, DRAW_NONE);
   int draw_width = ifInt(drawType==DRAW_ARROW, drawArrowSize, Draw.Width);

   SetIndexStyle(MODE_MA,        DRAW_LINE, EMPTY, 2,          Blue           );
   SetIndexStyle(MODE_TREND,     DRAW_NONE, EMPTY, EMPTY,      CLR_NONE       );
   SetIndexStyle(MODE_UPTREND1,  draw_type, EMPTY, draw_width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND1,  159);
   SetIndexStyle(MODE_DOWNTREND, draw_type, EMPTY, draw_width, Color.DownTrend); SetIndexArrow(MODE_DOWNTREND, 159);
   SetIndexStyle(MODE_UPTREND2,  draw_type, EMPTY, draw_width, Color.UpTrend  ); SetIndexArrow(MODE_UPTREND2,  159);
}


/**
 * Store input parameters iN the chart before recompilation.
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
 * Restore input parameters found iN the chart after recompilation.
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


double dList128A[1][128], dList128B[1][128], dList128C[1][128], dList128D[1][128], dList128E[1][128];
double dRing11A[1][11], dRing11B[1][11];
double dBuffer62[1][62];
double dMem8[1][8];

double dF18[1], dF38[1], dFa8[1], dFc0[1], dFc8[1], dS8[1], dS18[1], dV1[1], dV2[1], dV3[1];
double dF90[1], dF78[1], dF88[1], dF98[1], dJma[1], dKg[1], dPf[1];

double dFa0, dVv, dV4, dF70, dS20, dS10, dFb0, dFd0, dF8, dF60, dF20, dF28, dF30, dF40, dF48, dF58, dF68;

int    iMem7[1][7], iMem11[1][11];

int    iS28[1], iS30[1], iS38[1], iS40[1], iS48[1], iF0[1], iS50[1], iS70[1], iLp1[1], iLp2[1], iDatetime[1];

int    iV5, iV6, iFe0, iFd8, iFe8, iVal, iS58, iS60, iS68, iAa, iSize, iIi, iJj, iM, iN, iTnew, iTold, iError, iResize;


/**
 * The function does not work if the parameter nJMA.limit takes a value of zero.
 *
 * If nJMA.bar is larger than nJMA.MaxBar, then the function returns a value of zero on this bar. And therefore, such a
 * meaning cannot be present in the denominator of any fraction in the calculation of the indicator.
 *
 *
 *
 *
 *
 * @param  _In_  int    iNumber - The sequence number of the function call (0, 1, 2, 3, etc. ...)
 * @param  _In_  int    iDin    - allows to change the iPeriods and iPhase parameters on each bar. 0 - change prohibition parameters,
 *                                any other value is resolution.
 * @param  _In_  int    MaxBar  - The maximum value that the calculated bar number (iBar) can take. Usually equals Bars-1-periods
 *                                where "period" is the number of bars on which the dJMA.series is not calculated.
 * @param  _In_  int    limit   - The number of bars not yet counted plus one or the number of the last uncounted bar. Must be
 *                                equal to Bars-IndicatorCounted()-1.
 * @param  _In_  int    Length  - smoothing length
 * @param  _In_  int    Phase   - varies between -100 ... +100 and affects the quality of the transition process
 * @param  _In_  double dPrice  - price for which the indicator value is calculated
 * @param  _In_  int    iBar    - Number of the bar to calculate counting downwards to zero. Its maximum value should always be
 *                                equal to the value of the parameter limit.
 * @param  _Out_ int    error   - variable receiving any errors occurred during the calculation
 *
 * @return double - JMA value or NULL if iBar is greater than nJMA.MaxBar-30
 */
double JJMASeries(int iNumber, int iDin, int iOldestBar, int iStartBar, int iPeriods, int iPhase, double dPrice, int iBar, int &error) {
   iN = iNumber;
   error = 1;

   // Проверки на ошибки
   if (iBar == iStartBar) {
      // проверка на инициализацию функции JJMASeries()
      if (iResize < 1) {
         Print("JJMASeries number ="+ iN +". Не было сделано изменение размеров буферных переменных функцией JJMASeriesResize()");
         if (iResize == 0) Print("JJMASeries number ="+ iN +". Следует дописать обращение к функции JJMASeriesResize() в блок инициализации");
         return(0);
      }

      // проверка на ошибку в исполнении программного кода, предшествовавшего функции JJMASeries()
      iError = GetLastError();
      if (iError > 4000) {
         Print("JJMASeries number ="+ iN +". В коде, предшествующем обращению к функции JJMASeries() number = "+ iN +" ошибка!!!");
         Print("JJMASeries number ="+ iN + ". ", ErrorToStr(iError));
      }

      // проверка на ошибку в задании переменных iNumber и nJMAResize.Number
      iSize = ArraySize(dJma);
      if (iSize < iN) {
         Print("JJMASeries number ="+ iN +". Ошибка!!! Неправильно задано значение переменной iNumber="+ iN +" функции JJMASeries()");
         Print("JJMASeries number ="+ iN +". Или неправильно задано значение  переменной nJJMAResize.Size="+ iSize +" функции JJMASeriesResize()");
         return(0);
      }
   }

   // проверка на ошибку в последовательности изменения переменной iBar
   if (iStartBar>=iOldestBar && !iBar && iOldestBar>30 && !iDatetime[iN]) {
      Print("JJMASeries number ="+ iN +". Ошибка!!! Нарушена правильная последовательность изменения параметра iBar внешним оператором цикла!!!");
   }

   if (iBar > iOldestBar){
      error = NO_ERROR;
      return(0);
   }

   if (iBar==iOldestBar || iDin) {
      // Расчёт коэффициентов
      double dS, dL;

      if (iPeriods < 1.0000000002) double dR = 0.0000000001;
      else                                dR = (iPeriods-1)/2.;

      if (iPhase>=-100 && iPhase<=100) dPf[iN] = iPhase/100. + 1.5;

      if (iPhase > +100) dPf[iN] = 2.5;
      if (iPhase < -100) dPf[iN] = 0.5;

      dR = dR * 0.9;
      dKg[iN] = dR/(dR + 2.0);
      dS = MathSqrt(dR);
      dL = MathLog(dS);
      dV1[iN] = dL;
      dV2[iN] = dV1[iN];

      if (dV1[iN]/MathLog(2) + 2 < 0) dV3[iN] = 0;
      else                            dV3[iN] = dV2[iN]/MathLog(2) + 2;

      dF98[iN] = dV3[iN];

      if (dF98[iN] >= 2.5) dF88[iN] = dF98[iN] - 2;
      else                 dF88[iN] = 0.5;

      dF78[iN] = dS * dF98[iN];
      dF90[iN] = dF78[iN] / (dF78[iN] + 1);
   }
// formatted


   if (iBar==iStartBar && iStartBar < iOldestBar) {
      // Восстановление значений переменных
      iTnew = Time[iStartBar+1];
      iTold = iDatetime[iN];

      if (iTnew == iTold) {
         for(iAa=127; iAa >= 0; iAa--) dList128A[iN][iAa] = dList128E[iN][iAa];
         for(iAa=127; iAa >= 0; iAa--) dList128B[iN][iAa] = dList128D[iN][iAa];
         for(iAa=10;  iAa >= 0; iAa--) dRing11A [iN][iAa] = dRing11B [iN][iAa];

         dFc0[iN] = dMem8[iN][0]; dFc8[iN] = dMem8[iN][1]; dFa8[iN] = dMem8[iN][2];
         dS8 [iN] = dMem8[iN][3]; dF18[iN] = dMem8[iN][4]; dF38[iN] = dMem8[iN][5];
         dS18[iN] = dMem8[iN][6]; dJma[iN] = dMem8[iN][7]; iS38[iN] = iMem7[iN][0];
         iS48[iN] = iMem7[iN][1]; iS50[iN] = iMem7[iN][2]; iLp1[iN] = iMem7[iN][3];
         iLp2[iN] = iMem7[iN][4]; iS40[iN] = iMem7[iN][5]; iS70[iN] = iMem7[iN][6];
      }
      //--+ проверка на ошибки
      if(iTnew!=iTold)
      {
      error=-1;
      //--+ индикация ошибки в расчёте входного параметра iStartBar функции JJMASeries()
      if (iTnew>iTold)
      {
      Print("JJMASeries number ="+iN+
      ". Ошибка!!! Параметр iStartBar функции JJMASeries() меньше, чем необходимо");
      }
      else
      {
      int iLimitERROR=iStartBar+1-iBarShift(NULL,0,iTold,TRUE);
      Print("JMASerries number ="+iN+
      ". Ошибка!!! Параметр iStartBar функции JJMASeries() больше, чем необходимо на "
      +iLimitERROR+"");
      }
      //--+ Возврат через error=-1; ошибки в расчёте функции JJMASeries
      return(0);
      }
   }

if (iBar==1)
if (( iStartBar!=1)||(Time[iStartBar+2]==iDatetime[iN]))
  {
   //--+ <<< Сохранение значений переменных >>> +SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS+
   for(iAa=127;iAa>=0;iAa--)dList128E [iN][iAa]=dList128A [iN][iAa];
   for(iAa=127;iAa>=0;iAa--)dList128D[iN][iAa]=dList128B[iN][iAa];
   for(iAa=10; iAa>=0;iAa--)dRing11B[iN][iAa]=dRing11A[iN][iAa];

   dMem8[iN][00]=dFc0[iN];dMem8[iN][01]=dFc8[iN];dMem8[iN][02]=dFa8[iN];
   dMem8[iN][03]=dS8 [iN];dMem8[iN][04]=dF18[iN];dMem8[iN][05]=dF38[iN];
   dMem8[iN][06]=dS18[iN];dMem8[iN][07]=dJma[iN];iMem7[iN][00]=iS38[iN];
   iMem7[iN][01]=iS48[iN];iMem7[iN][02]=iS50[iN];iMem7[iN][03]=iLp1[iN];
   iMem7[iN][04]=iLp2[iN];iMem7[iN][05]=iS40[iN];iMem7[iN][06]=iS70[iN];
   iDatetime[iN]=Time[2];
  }

if (iLp1[iN]<61){iLp1[iN]++; dBuffer62[iN][iLp1[iN]]=dPrice;}
if (iLp1[iN]>30)
{

if (iF0[iN] != 0)
{
iF0[iN] = 0;
iV5 = 1;
iFd8 = iV5*30;
if (iFd8 == 0) dF38[iN] = dPrice; else dF38[iN] = dBuffer62[iN][1];
dF18[iN] = dF38[iN];
if (iFd8 > 29) iFd8 = 29;
}
else iFd8 = 0;
for(iIi=iFd8; iIi>=0; iIi--)
{
iVal=31-iIi;
if (iIi == 0) dF8 = dPrice; else dF8 = dBuffer62[iN][iVal];
dF28 = dF8 - dF18[iN]; dF48 = dF8 - dF38[iN];
if (MathAbs(dF28) > MathAbs(dF48)) dV2[iN] = MathAbs(dF28); else dV2[iN] = MathAbs(dF48);
dFa0 = dV2[iN]; dVv = dFa0 + 0.0000000001; //{1.0e-10;}
if (iS48[iN] <= 1) iS48[iN] = 127; else iS48[iN] = iS48[iN] - 1;
if (iS50[iN] <= 1) iS50[iN] = 10;  else iS50[iN] = iS50[iN] - 1;
if (iS70[iN] < 128) iS70[iN] = iS70[iN] + 1;
dS8[iN] = dS8[iN] + dVv - dRing11A[iN][iS50[iN]];
dRing11A[iN][iS50[iN]] = dVv;
if (iS70[iN] > 10) dS20 = dS8[iN] / 10.0; else dS20 = dS8[iN] / iS70[iN];
if (iS70[iN] > 127)
{
dS10 = dList128B[iN][iS48[iN]];
dList128B[iN][iS48[iN]] = dS20; iS68 = 64; iS58 = iS68;
while (iS68 > 1)
{
if (dList128A[iN][iS58] < dS10){iS68 = iS68 *0.5; iS58 = iS58 + iS68;}
else
if (dList128A[iN][iS58]<= dS10) iS68 = 1; else{iS68 = iS68 *0.5; iS58 = iS58 - iS68;}
}
}
else
{
dList128B[iN][iS48[iN]] = dS20;
if  (iS28[iN] + iS30[iN] > 127){iS30[iN] = iS30[iN] - 1; iS58 = iS30[iN];}
else{iS28[iN] = iS28[iN] + 1; iS58 = iS28[iN];}
if  (iS28[iN] > 96) iS38[iN] = 96; else iS38[iN] = iS28[iN];
if  (iS30[iN] < 32) iS40[iN] = 32; else iS40[iN] = iS30[iN];
}
iS68 = 64; iS60 = iS68;
while (iS68 > 1)
{
if (dList128A[iN][iS60] >= dS20)
{
if (dList128A[iN][iS60 - 1] <= dS20) iS68 = 1; else {iS68 = iS68 *0.5; iS60 = iS60 - iS68; }
}
else{iS68 = iS68 *0.5; iS60 = iS60 + iS68;}
if ((iS60 == 127) && (dS20 > dList128A[iN][127])) iS60 = 128;
}
if (iS70[iN] > 127)
{
if (iS58 >= iS60)
{
if ((iS38[iN] + 1 > iS60) && (iS40[iN] - 1 < iS60)) dS18[iN] = dS18[iN] + dS20;
else
if ((iS40[iN] + 0 > iS60) && (iS40[iN] - 1 < iS58)) dS18[iN]
= dS18[iN] + dList128A[iN][iS40[iN] - 1];
}
else
if (iS40[iN] >= iS60) {if ((iS38[iN] + 1 < iS60) && (iS38[iN] + 1 > iS58)) dS18[iN]
= dS18[iN] + dList128A[iN][iS38[iN] + 1]; }
else if  (iS38[iN] + 2 > iS60) dS18[iN] = dS18[iN] + dS20;
else if ((iS38[iN] + 1 < iS60) && (iS38[iN] + 1 > iS58)) dS18[iN]
= dS18[iN] + dList128A[iN][iS38[iN] + 1];
if (iS58 > iS60)
{
if ((iS40[iN] - 1 < iS58) && (iS38[iN] + 1 > iS58)) dS18[iN] = dS18[iN] - dList128A[iN][iS58];
else
if ((iS38[iN]     < iS58) && (iS38[iN] + 1 > iS60)) dS18[iN] = dS18[iN] - dList128A[iN][iS38[iN]];
}
else
{
if ((iS38[iN] + 1 > iS58) && (iS40[iN] - 1 < iS58)) dS18[iN] = dS18[iN] - dList128A[iN][iS58];
else
if ((iS40[iN] + 0 > iS58) && (iS40[iN] - 0 < iS60)) dS18[iN] = dS18[iN] - dList128A[iN][iS40[iN]];
}
}
if (iS58 <= iS60)
{
if (iS58 >= iS60)
{
dList128A[iN][iS60] = dS20;
}
else
{
for( iJj = iS58 + 1; iJj<=iS60 - 1 ;iJj++)dList128A[iN][iJj - 1] = dList128A[iN][iJj];
dList128A[iN][iS60 - 1] = dS20;
}
}
else
{
for( iJj = iS58 - 1; iJj>=iS60 ;iJj--) dList128A[iN][iJj + 1] = dList128A[iN][iJj];
dList128A[iN][iS60] = dS20;
}
if (iS70[iN] <= 127)
{
dS18[iN] = 0;
for( iJj = iS40[iN] ; iJj<=iS38[iN] ;iJj++) dS18[iN] = dS18[iN] + dList128A[iN][iJj];
}
dF60 = dS18[iN] / (iS38[iN] - iS40[iN] + 1.0);
if (iLp2[iN] + 1 > 31) iLp2[iN] = 31; else iLp2[iN] = iLp2[iN] + 1;
if (iLp2[iN] <= 30)
{
if (dF28 > 0.0) dF18[iN] = dF8; else dF18[iN] = dF8 - dF28 * dF90[iN];
if (dF48 < 0.0) dF38[iN] = dF8; else dF38[iN] = dF8 - dF48 * dF90[iN];
dJma[iN] = dPrice;
if (iLp2[iN]!=30) continue;
if (iLp2[iN]==30)
{
dFc0[iN] = dPrice;
if ( MathCeil(dF78[iN]) >= 1) dV4 = MathCeil(dF78[iN]); else dV4 = 1.0;

if(dV4>0)iFe8 = MathFloor(dV4);else{if(dV4<0)iFe8 = MathCeil (dV4);else iFe8 = 0.0;}

if (MathFloor(dF78[iN]) >= 1) dV2[iN] = MathFloor(dF78[iN]); else dV2[iN] = 1.0;

if(dV2[iN]>0)iFe0 = MathFloor(dV2[iN]);else{if(dV2[iN]<0)iFe0 = MathCeil (dV2[iN]);else iFe0 = 0.0;}

if (iFe8== iFe0) dF68 = 1.0; else {dV4 = iFe8 - iFe0; dF68 = (dF78[iN] - iFe0) / dV4;}
if (iFe0 <= 29) iV5 = iFe0; else iV5 = 29;
if (iFe8 <= 29) iV6 = iFe8; else iV6 = 29;
dFa8[iN] = (dPrice - dBuffer62[iN][iLp1[iN] - iV5]) * (1.0 - dF68) / iFe0 + (dPrice
- dBuffer62[iN][iLp1[iN] - iV6]) * dF68 / iFe8;
}
}
else
{
if (dF98[iN] >= MathPow(dFa0/dF60, dF88[iN])) dV1[iN] = MathPow(dFa0/dF60, dF88[iN]);
else dV1[iN] = dF98[iN];
if (dV1[iN] < 1.0) dV2[iN] = 1.0;
else
{if(dF98[iN] >= MathPow(dFa0/dF60, dF88[iN])) dV3[iN] = MathPow(dFa0/dF60, dF88[iN]);
else dV3[iN] = dF98[iN]; dV2[iN] = dV3[iN];}
dF58 = dV2[iN]; dF70 = MathPow(dF90[iN], MathSqrt(dF58));
if (dF28 > 0.0) dF18[iN] = dF8; else dF18[iN] = dF8 - dF28 * dF70;
if (dF48 < 0.0) dF38[iN] = dF8; else dF38[iN] = dF8 - dF48 * dF70;
}
}
if (iLp2[iN] >30)
{
dF30 = MathPow(dKg[iN], dF58);
dFc0[iN] =(1.0 - dF30) * dPrice + dF30 * dFc0[iN];
dFc8[iN] =(dPrice - dFc0[iN]) * (1.0 - dKg[iN]) + dKg[iN] * dFc8[iN];
dFd0 = dPf[iN] * dFc8[iN] + dFc0[iN];
dF20 = dF30 *(-2.0);
dF40 = dF30 * dF30;
dFb0 = dF20 + dF40 + 1.0;
dFa8[iN] =(dFd0 - dJma[iN]) * dFb0 + dF40 * dFa8[iN];
dJma[iN] = dJma[iN] + dFa8[iN];
}
}

if (iLp1[iN] <=30)dJma[iN]=0.0;

//----++ проверка на ошибку в исполнении программного кода функции JJMASeries()
iError=GetLastError();
if(iError>4000)
  {
    Print("JJMASeries number ="+iN+". При исполнении функции JJMASeries() произошла ошибка!!!");
    Print("JJMASeries number ="+iN+ ". ", ErrorToStr(iError));
    return(0.0);
  }

error=0;
return(dJma[iN]);
}


/**
 * JJMASeriesResize - Это дополнительная функция для изменения размеров буферных переменных
 * функции JJMASeries. Пример обращения: JJMASeriesResize(5); где 5 - это количество обращений к
 * JJMASeries()в тексте индикатора. Это обращение к функции  JJMASeriesResize следует поместить
 * в блок инициализации пользовательского индикатора или эксперта
 */
int JJMASeriesResize(int nJJMAResize.Size) {
   if (nJJMAResize.Size < 1) {
      Print("JJMASeriesResize: Ошибка!!! Параметр nJJMAResize.Size не может быть меньше единицы!!!");
      iResize=-1;
      return(0);
   }
   int nJJMAResize.reset, nJJMAResize.cycle;

   while (nJJMAResize.cycle == 0) {
      // изменение размеров буферных переменных
      if (!ArrayResize(dList128A,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dList128B, nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dRing11A, nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dBuffer62,nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dMem8,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iMem7,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iMem11,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dList128C,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dList128E,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dList128D, nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dRing11B, nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dKg,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dPf,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dF18,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dF38,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dFa8,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dFc0,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dFc8,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dS8,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dS18,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dJma,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS50,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS70,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iLp2,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iLp1,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS38,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS40,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS48,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dV1,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dV2,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dV3,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dF90,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dF78,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dF88,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(dF98,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS28,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iS30,   nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iF0,    nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }
      if (!ArrayResize(iDatetime,  nJJMAResize.Size)) { nJJMAResize.reset = -1; break; }

      nJJMAResize.cycle=1;
   }

  if(nJJMAResize.reset==-1)
   {
    Print("JJMASeriesResize: Ошибка!!! Не удалось изменить размеры буферных переменных функции JJMASeries().");
    int nJJMAResize.Error=GetLastError();
    if(nJJMAResize.Error>4000)Print("JJMASeriesResize(): ", ErrorToStr(nJJMAResize.Error));
    iResize=-2;
    return(0);
   }
  else
   {
    Print("JJMASeriesResize: JJMASeries()size = "+nJJMAResize.Size+"");

    ArrayInitialize(iF0,  1);
    ArrayInitialize(iS28,63);
    ArrayInitialize(iS30,64);
    for(int rrr=0;rrr<nJJMAResize.Size;rrr++)
     {
       for(int kkk=0;kkk<=iS28[rrr];kkk++)dList128A[rrr][kkk]=-1000000.0;
       for(kkk=iS30[rrr]; kkk<=127; kkk++)dList128A[rrr][kkk]= 1000000.0;
     }
    iResize=nJJMAResize.Size;
    return(nJJMAResize.Size);
   }
}

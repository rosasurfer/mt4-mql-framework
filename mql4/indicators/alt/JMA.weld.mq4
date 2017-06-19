//+------------------------------------------------------------------+
//|                                                          JMA.mq4 |
//|                                             Weld, Jurik Research |
//|                                          http://weld.torguem.net |
//+------------------------------------------------------------------+
#property copyright "Weld"
#property link      "http://weld.torguem.net"

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Aqua
//---- input parameters
extern int       Length = 14;
extern int       Phase  = 0;
//---- buffers
double JMAValueBuffer [];
double fC0Buffer [];
double fA8Buffer [];
double fC8Buffer [];
//---- temporary buffers
double list[128], ring1[128], ring2[11], buffer[62];
//---- bool flag
bool   initFlag;
//---- integer vars
int    limitValue, startValue, loopParam, loopCriteria;
int    cycleLimit, highLimit, counterA, counterB;
//---- double vars
double cycleDelta, lowDValue, highDValue, absValue, paramA, paramB;
double phaseParam, logParam, JMAValue, series, sValue, sqrtParam, lengthDivider;
//---- temporary int variables
int   s58, s60, s40, s38, s68;
//+------------------------------------------------------------------+
//| JMA initFlagization function                                     |
//+------------------------------------------------------------------+
int init()
  {
   double   lengthParam;
//---- 3 additional buffers are used for counting.
   IndicatorBuffers(4);
//---- drawing settings
   SetIndexStyle  (0, DRAW_LINE);
   SetIndexDrawBegin(0, 30);
//---- 4 indicator buffers mapping
   SetIndexBuffer (0, JMAValueBuffer);
   SetIndexBuffer (1, fC0Buffer);
   SetIndexBuffer (2, fA8Buffer);
   SetIndexBuffer (3, fC8Buffer);
//---- initialize one buffer (neccessary)
   ArrayInitialize (ring2, 0);
   ArrayInitialize (ring1, 0);
   ArrayInitialize (buffer, 0);
//---- name for DataWindow and indicator subwindow label
   IndicatorShortName ("JMAValue(" + Length + "," + Phase + ")");
   SetIndexLabel (0, "JMAValue");
//---- initial part
   limitValue = 63;
   startValue = 64;
//----
   for (int i = 0; i <= limitValue; i++) list [i] = -1000000;
   for (i = startValue; i <= 127; i++)   list [i] = 1000000;
//----
   initFlag  = true;
   if (Length < 1.0000000002) lengthParam = 0.0000000001;
   else lengthParam = (Length - 1) / 2.;
//----
   if (Phase < -100) phaseParam = 0.5;
   else if (Phase > 100) phaseParam = 2.5;
   else phaseParam = Phase / 100. + 1.5;
//----
   logParam = MathLog (MathSqrt (lengthParam)) / MathLog(2.);
//----
   if (logParam + 2.0 < 0) logParam = 0;
   else logParam = logParam + 2.0;
//----
   sqrtParam     = MathSqrt(lengthParam) * logParam;
   lengthParam   = lengthParam * 0.9;
   lengthDivider = lengthParam / (lengthParam + 2.0);
//----
   return;
}
//+------------------------------------------------------------------+
//| JMA iteration function                                           |
//+------------------------------------------------------------------+
int start()
  {

//---- get already counted bars
   int counted_bars = IndicatorCounted();
//---- check for possible errors
   if (counted_bars < 0) return (-1);
   int limit = Bars - counted_bars - 1;
//---- main cycle
   for (int shift = limit; shift >= 0; shift--) {
      series = Close [shift];

      if (loopParam < 61) {
         loopParam++;
         buffer [loopParam] = series;
      }
      if (loopParam > 30) {
         if (initFlag) {
            initFlag = false;

            int diffFlag = 0;
            for (int i = 1; i <= 29; i++) {
               if (buffer [i + 1] != buffer [i]) diffFlag = 1;
            }
            highLimit = diffFlag * 30;

            if (highLimit == 0) paramB = series;
            else paramB = buffer[1];

            paramA = paramB;
            if (highLimit > 29) highLimit = 29;
         } else
            highLimit = 0;
//---- big cycle
         for (i = highLimit; i >= 0; i--) {
            if (i == 0) sValue = series; else sValue = buffer [31 - i];

            if (MathAbs (sValue - paramA) > MathAbs (sValue - paramB)) absValue = MathAbs(sValue - paramA); else absValue = MathAbs(sValue - paramB);
            double dValue = absValue + 0.0000000001; //1.0e-10;

            if (counterA <= 1) counterA = 127; else counterA--;
            if (counterB <= 1) counterB = 10;  else counterB--;
            if (cycleLimit < 128) cycleLimit++;
            cycleDelta += (dValue - ring2 [counterB]);
            ring2 [counterB] = dValue;
            if (cycleLimit > 10) highDValue = cycleDelta / 10.0; else highDValue = cycleDelta / cycleLimit;

            if (cycleLimit > 127) {
               dValue = ring1 [counterA];
               ring1 [counterA] = highDValue;
               s68 = 64; s58 = s68;
               while (s68 > 1) {
                  if (list [s58] < dValue) {
                     s68 = s68 / 2.0;
                     s58 += s68;
                  } else
                  if (list [s58] <= dValue) {
                     s68 = 1;
                  } else {
                     s68 = s68 / 2.0;
                     s58 -= s68;
                  }
               }
            } else {
               ring1 [counterA] = highDValue;
               if ((limitValue + startValue) > 127) {
                  startValue--;
                  s58 = startValue;
               } else {
                  limitValue++;
                  s58 = limitValue;
               }
               if (limitValue > 96) s38 = 96; else s38 = limitValue;
               if (startValue < 32) s40 = 32; else s40 = startValue;
            }
//----
            s68 = 64;
            s60 = s68;
            while (s68 > 1) {
               if (list [s60] >= highDValue) {
                  if (list [s60 - 1] <= highDValue) {
                     s68 = 1;
                  }
                  else {
                     s68 = s68 / 2.0;
                     s60 -= s68;
                  }
               }
               else {
                  s68 = s68 / 2.0;
                  s60 += s68;
               }
               if ((s60 == 127) && (highDValue > list[127])) s60 = 128;
            }
            if (cycleLimit > 127) {
               if (s58 >= s60) {
                  if (((s38 + 1) > s60) && ((s40 - 1) < s60))
                      lowDValue += highDValue;
                  else if ((s40 > s60) && ((s40 - 1) < s58))
                      lowDValue += list [s40 - 1];
               }
               else if (s40 >= s60) {
                  if (((s38 + 1) < s60) && ((s38 + 1) > s58))
                         lowDValue += list[s38 + 1];
               }
               else if ((s38 + 2) > s60)
                     lowDValue += highDValue;
               else if (((s38 + 1) < s60) && ((s38 + 1) > s58))
                     lowDValue += list[s38 + 1];

               if (s58 > s60) {
                  if (((s40 - 1) < s58) && ((s38 + 1) > s58))
                     lowDValue -= list [s58];
                  else if ((s38 < s58) && ((s38 + 1) > s60))
                     lowDValue -= list [s38];
               }
               else {
                  if (((s38 + 1) > s58) && ((s40 - 1) < s58))
                     lowDValue -= list [s58];
                  else if ((s40 > s58) && (s40 < s60))
                     lowDValue -= list [s40];
               }
            }
            if (s58 <= s60) {
               if (s58 >= s60) list[s60] = highDValue; else {
                  for (int j = s58 + 1; j <= (s60 - 1); j++) {
                     list [j - 1] = list[j];
                  }
                  list [s60 - 1] = highDValue;
               }
            } else {
               for (j = s58 - 1; j >= s60; j--) {
                  list [j + 1] = list [j];
               }
               list [s60] = highDValue;
            }

            if (cycleLimit <= 127) {
               lowDValue = 0;
               for (j = s40; j <= s38; j++) {
                  lowDValue += list[j];
               }
            }
//----
            if ((loopCriteria + 1) > 31) loopCriteria = 31; else loopCriteria++;
            double JMATempValue, sqrtDivider = sqrtParam / (sqrtParam + 1.0);

            if (loopCriteria <= 30) {
               if (sValue - paramA > 0) paramA = sValue; else paramA = sValue - (sValue - paramA) * sqrtDivider;
               if (sValue - paramB < 0) paramB = sValue; else paramB = sValue - (sValue - paramB) * sqrtDivider;
               JMATempValue = series;

               if (loopCriteria == 30) {
                 fC0Buffer [shift] = series;
                 int intPart;

                 if (MathCeil(sqrtParam) >= 1) intPart = MathCeil(sqrtParam); else intPart = 1;
                 int leftInt = IntPortion (intPart);
                 if (MathFloor(sqrtParam) >= 1) intPart = MathFloor(sqrtParam); else intPart = 1;
                 int rightPart = IntPortion (intPart);

                 if (leftInt == rightPart) dValue = 1.0;
                 else
                    dValue = (sqrtParam - rightPart) / (leftInt - rightPart);

                 if (rightPart <= 29) int upShift = rightPart; else upShift = 29;
                 if (leftInt <= 29) int dnShift = leftInt; else dnShift = 29;
                 fA8Buffer [shift] = (series - buffer [loopParam - upShift]) * (1 - dValue) / rightPart + (series - buffer[loopParam - dnShift]) * dValue / leftInt;
               }
            } else {
               double powerValue, squareValue;

               dValue = lowDValue / (s38 - s40 + 1);
               if (0.5 <= logParam - 2.0) powerValue = logParam - 2.0;
               else powerValue = 0.5;

               if (logParam >= MathPow(absValue/dValue, powerValue)) dValue = MathPow (absValue/dValue, powerValue); else dValue = logParam;
               if (dValue < 1) dValue = 1;

               powerValue = MathPow (sqrtDivider, MathSqrt (dValue));
               if (sValue - paramA > 0) paramA = sValue; else paramA = sValue - (sValue - paramA) * powerValue;
               if (sValue - paramB < 0) paramB = sValue; else paramB = sValue - (sValue - paramB) * powerValue;
            }
         }
// ---- end of big cycle
         if (loopCriteria > 30) {
            JMATempValue = JMAValueBuffer [shift + 1];
            powerValue   = MathPow (lengthDivider, dValue);
            squareValue  = MathPow (powerValue, 2);

            fC0Buffer [shift] = (1 - powerValue) * series + powerValue * fC0Buffer [shift + 1];
            fC8Buffer [shift] = (series - fC0Buffer [shift]) * (1 - lengthDivider) + lengthDivider * fC8Buffer [shift + 1];

            fA8Buffer [shift] = (phaseParam * fC8Buffer [shift] + fC0Buffer [shift] - JMATempValue) *
                                 (powerValue * (-2.0) + squareValue + 1) + squareValue * fA8Buffer [shift + 1];
            JMATempValue += fA8Buffer [shift];
         }
         JMAValue = JMATempValue;
      }
      if (loopParam <= 30) JMAValue = 0;
      JMAValueBuffer [shift] = JMAValue;
//---- End of main cycle
   }
   return;
}

//+------------------------------------------------------------------+
int IntPortion (double param) {
   if (param > 0) return (MathFloor (param));
   if (param < 0) return (MathCeil (param));
   return (0.0);
}
//+------------------------------------------------------------------+

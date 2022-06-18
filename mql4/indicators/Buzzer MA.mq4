/**
 * Buzzer MA
 *
 * @link  https://www.mql5.com/en/code/12152#   [Buzzer]
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern int  Price   = 0;
extern int  Length  = 20;
extern bool AlertON = true;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLib.mqh>

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 Yellow
#property indicator_width1 2
#property indicator_color2 Lime
#property indicator_width2 2
#property indicator_color3 Red
#property indicator_width3 2

double MABuffer[];
double UpBuffer[];
double DnBuffer[];
double trend[];
double Del[];
double AvgDel[];

double PctFilter    = 1.36;
int    ColorBarBack = 1;
double Deviation    = 0;

double alpha[];
int    iLen, iCycle = 4;
double dWeight;
bool   UpTrendAlert;
bool   DownTrendAlert;


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   IndicatorBuffers(6);
   SetIndexBuffer(0, MABuffer); SetIndexDrawBegin(0, Length*iCycle + Length + 1); SetIndexStyle(0, DRAW_LINE); SetIndexLabel(0, "Buzzer");
   SetIndexBuffer(1, UpBuffer); SetIndexDrawBegin(1, Length*iCycle + Length + 1); SetIndexStyle(1, DRAW_LINE); SetIndexLabel(1, "Buzzer_UP");
   SetIndexBuffer(2, DnBuffer); SetIndexDrawBegin(2, Length*iCycle + Length + 1); SetIndexStyle(2, DRAW_LINE); SetIndexLabel(2, "Buzzer_DN");
   SetIndexBuffer(3, trend   );
   SetIndexBuffer(4, Del     );
   SetIndexBuffer(5, AvgDel  );

   IndicatorDigits(Digits);
   IndicatorShortName("Buzzer("+ Length +")");

   double coeff = 3 * Math.PI;
   int iPhase  = Length-1;
   iLen   = Length*4 + iPhase;
   dWeight = 0;

   ArrayResize(alpha, iLen);

   for (int i=0; i < iLen-1; i++) {
      if (i <= iPhase-1) double t = 1.0*i/(iPhase-1);
      else                      t = 1.0 + (i-iPhase+1) * (2.*iCycle-1)/(iCycle*Length-1);
      double beta = MathCos(Math.PI*t);
      double g = 1.0/(coeff*t+1);
      if (t <= 0.5 ) g = 1;
      alpha[i] = g * beta;
      dWeight += alpha[i];
   }
   return(catch("onInit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   int limit;
   double price;

   if (ValidBars > 0 ) {
      limit = ChangedBars;
   }
   else {
      limit = Bars-iLen-1;

      for (int i=1; i < Length*iCycle+Length; i++) {
         MABuffer[Bars-i] = 0;
         UpBuffer[Bars-i] = 0;
         DnBuffer[Bars-i] = 0;
      }
   }

   for (int bar=limit; bar >=0 ; bar--) {
      double sum = 0;
      for (i=0; i <= iLen-1; i++) {
         price = iMA(NULL, NULL, 1, 0, 3, Price, bar+i);
         sum += alpha[i]*price;
      }

	   if (dWeight > 0) MABuffer[bar] = (1.+Deviation/100)*sum/dWeight;

      if (PctFilter > 0) {
         Del[bar] = MathAbs(MABuffer[bar] - MABuffer[bar+1]);

         double sumdel=0;
         for (i=0;i<=Length-1;i++) sumdel = sumdel+Del[bar+i];
         AvgDel[bar] = sumdel/Length;

         double sumpow = 0;
         for (i=0;i<=Length-1;i++) sumpow+=MathPow(Del[bar+i]-AvgDel[bar+i],2);
         double StdDev = MathSqrt(sumpow/Length);

         double Filter = PctFilter * StdDev;

         if( MathAbs(MABuffer[bar]-MABuffer[bar+1]) < Filter ) MABuffer[bar]=MABuffer[bar+1];
      }
      else {
         Filter = 0;
      }

      trend[bar] = trend[bar+1];
      if (MABuffer[bar  ]-MABuffer[bar+1] > Filter) trend[bar] =  1;
      if (MABuffer[bar+1]-MABuffer[bar  ] > Filter) trend[bar] = -1;

      if (trend[bar] > 0) {
         UpBuffer[bar] = MABuffer[bar];
         if (trend[bar+ColorBarBack] < 0) UpBuffer[bar+ColorBarBack] = MABuffer[bar+ColorBarBack];
         DnBuffer[bar] = EMPTY_VALUE;
      }
      if (trend[bar] < 0) {
         DnBuffer[bar] = MABuffer[bar];
         if (trend[bar+ColorBarBack]>0) DnBuffer[bar+ColorBarBack] = MABuffer[bar+ColorBarBack];
         UpBuffer[bar] = EMPTY_VALUE;
      }
   }

   if (trend[2] < 0 && trend[1] > 0 && Volume[0] > 1 && !UpTrendAlert) {
   	if (AlertON) Alert(Symbol() +" M"+ Period() +": Signal for BUY");
   	UpTrendAlert   = true;
   	DownTrendAlert = false;
	}

	if (trend[2] > 0 && trend[1] < 0 && Volume[0] > 1 && !DownTrendAlert) {
   	if (AlertON) Alert(Symbol() +" M"+ Period() +": Signal for SELL");
   	UpTrendAlert   = false;
   	DownTrendAlert = true;
	}

   return(catch("onTick(1)"));
}

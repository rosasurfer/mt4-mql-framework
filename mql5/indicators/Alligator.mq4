//+------------------------------------------------------------------+
//|                                                    Alligator.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Bill Williams' Aligator"
#property strict

//---- indicator settings
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1  Blue
#property indicator_color2  Red
#property indicator_color3  Lime
//---- input parameters
input int InpJawsPeriod=13; // Jaws Period
input int InpJawsShift=8;   // Jaws Shift
input int InpTeethPeriod=8; // Teeth Period
input int InpTeethShift=5;  // Teeth Shift
input int InpLipsPeriod=5;  // Lips Period
input int InpLipsShift=3;   // Lips Shift
//---- indicator buffers
double ExtBlueBuffer[];
double ExtRedBuffer[];
double ExtLimeBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit(void)
  {
   IndicatorDigits(Digits);
//---- line shifts when drawing
   SetIndexShift(0,InpJawsShift);
   SetIndexShift(1,InpTeethShift);
   SetIndexShift(2,InpLipsShift);
//---- first positions skipped when drawing
   SetIndexDrawBegin(0,InpJawsShift+InpJawsPeriod);
   SetIndexDrawBegin(1,InpTeethShift+InpTeethPeriod);
   SetIndexDrawBegin(2,InpLipsShift+InpLipsPeriod);
//---- 3 indicator buffers mapping
   SetIndexBuffer(0,ExtBlueBuffer);
   SetIndexBuffer(1,ExtRedBuffer);
   SetIndexBuffer(2,ExtLimeBuffer);
//---- drawing settings
   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexStyle(2,DRAW_LINE);
//---- index labels
   SetIndexLabel(0,"Gator Jaws");
   SetIndexLabel(1,"Gator Teeth");
   SetIndexLabel(2,"Gator Lips");
  }
//+------------------------------------------------------------------+
//| Bill Williams' Alligator                                         |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int limit=rates_total-prev_calculated;
//---- main loop
   for(int i=0; i<limit; i++)
     {
      //---- ma_shift set to 0 because SetIndexShift called abowe
      ExtBlueBuffer[i]=iMA(NULL,0,InpJawsPeriod,0,MODE_SMMA,PRICE_MEDIAN,i);
      ExtRedBuffer[i]=iMA(NULL,0,InpTeethPeriod,0,MODE_SMMA,PRICE_MEDIAN,i);
      ExtLimeBuffer[i]=iMA(NULL,0,InpLipsPeriod,0,MODE_SMMA,PRICE_MEDIAN,i);
     }
//---- done
   return(rates_total);
  }
//+------------------------------------------------------------------+

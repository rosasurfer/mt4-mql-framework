//+-------------------------------------------------------------------------------------------------+
//|                                                                        GWTriDiffMetatrader4.mq4 |
//|                                                                                Copyleft removed |
//|                                                                       http://www.metaquotes.net/|
//| The GWTriDiffNT7 . Original Author: Glennw - bigmiketrading.com forum - for ThinkorSwim Platform|
//| http://www.bigmiketrading.com/download/vip_elite_circle/862-download.html?view                  |
//| Then ported by me, jabeztrading for Ninjatrader 7.                                              |
//| http://www.bigmiketrading.com/download/vip_elite_circle/884-download.html?view                  |
//|                                                                                                 |
//| Now ported by me, jabeztrading, for Metatrader 4.   10/24/2012                                  |                                                |
//|+------------------------------------------------------------------------------------------------+
#property  copyright "Copyleft removed"
#property  link      "http://www.metaquotes.net/"

///---- Properties
#property indicator_separate_window
#property indicator_buffers 5  //7
#property indicator_color1 LimeGreen //GW_TriDiffslowU
#property indicator_color2 Red       //GW_TriDiffslowD
#property indicator_color3 Gold      //GW_TriDiff
#property indicator_color4 DarkSlateGray   //Signal
#property indicator_color5 DodgerBlue      //GW_TriDiffSlow
//#property  indicator_color6  Yellow
//#property  indicator_color7  Aqua

#property indicator_width1 2
#property indicator_width2 2
#property indicator_width3 1
#property indicator_width4 1
#property indicator_width5 1
#property indicator_style3 STYLE_SOLID
#property indicator_style4 STYLE_SOLID
#property indicator_style5 STYLE_DOT

//---- input parameters
extern int        Length               = 6;
extern int        SlowLength           = 30;
extern int        smooth               = 3;
extern int        fastwmalength        = 3;
//----  External variables

// ---- Variables
int        effectiveLength;
int        effectiveLengthslow;
double     fastwma;
double     AvgTrislow;
double     AvgTri;


//---- Buffers
double GW_TriDiffslowU[];
double GW_TriDiffslowD[];
double GW_TriDiff[];
double Signal[];
double GW_TriDiffSlow[];
double EffectiveLengthMA[];
double EffectiveLengthSlowMA[];

//double     TriggerUP[];
//double     TriggerDN[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//|------------------------------------------------------------------|
int init()
{
   // Total buffers
   IndicatorBuffers(7);

   // drawing settings
   SetIndexStyle(0,DRAW_HISTOGRAM);
   SetIndexBuffer(0, GW_TriDiffslowU);
   SetIndexStyle(1,DRAW_HISTOGRAM);
   SetIndexBuffer(1, GW_TriDiffslowD);
   SetIndexStyle(2,DRAW_LINE);
   SetIndexBuffer(2,GW_TriDiff);
   SetIndexStyle(3,DRAW_LINE);
   SetIndexBuffer(3,Signal);
   SetIndexStyle(4,DRAW_LINE);
   SetIndexBuffer(4,GW_TriDiffSlow);

    //---- drawing settings
  //SetIndexStyle(6, DRAW_ARROW);
 // SetIndexArrow(6, 233);   // Up arrow
  //SetIndexBuffer(6,TriggerUP);

 // SetIndexStyle(7, DRAW_ARROW);
  //SetIndexArrow(7, 234);   //Down arrow
  //SetIndexBuffer(7,TriggerDN);



   // 2 indicator buffers mapping
   SetIndexBuffer(5,EffectiveLengthMA);
   SetIndexBuffer(6,EffectiveLengthSlowMA);





   // name for Data Window
   IndicatorShortName("GWTriDiff  ("+ Length +","+ SlowLength +","+ smooth +","+ fastwmalength +")");

   return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
{
   return(0);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{

   int limit;
   int counted_bars = IndicatorCounted();

   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars;


   effectiveLength = MathCeil((Length + 1)/2);
	effectiveLengthslow = MathCeil((SlowLength + 1) / 2);


   for(int i=0; i<limit; i++)
   {
      EffectiveLengthMA[i] = iMA(NULL,0,effectiveLength,0,MODE_SMA,PRICE_CLOSE,i);
      EffectiveLengthSlowMA[i] = iMA(NULL,0,effectiveLengthslow,0,MODE_SMA,PRICE_CLOSE,i);
   }



   for(int p=0; p<limit; p++)
   {

				fastwma = iMA(NULL,0,fastwmalength,0,MODE_LWMA,PRICE_CLOSE,p);

				AvgTri = iMAOnArray(EffectiveLengthMA, Bars, effectiveLength, 0, MODE_SMA, p);

				GW_TriDiff[p] = fastwma - AvgTri;

				AvgTrislow = iMAOnArray(EffectiveLengthSlowMA, Bars, effectiveLengthslow, 0, MODE_SMA, p);

				GW_TriDiffSlow[p] = fastwma - AvgTrislow;

   }

    for(int j=0; j<limit; j++)
    {
				Signal[j] = iMAOnArray(GW_TriDiffSlow, Bars, smooth, 0, MODE_SMA, j);
    }


    for(int n=0; n<limit; n++)
    {

				if( GW_TriDiffSlow[n] > 0)
				{
					GW_TriDiffslowU[n] = GW_TriDiffSlow[n];
				}
				else
				{
					GW_TriDiffslowD[n] = GW_TriDiffSlow[n];
				}

			//val1 =
        //TriggerUP[i] = val1;
       // TriggerDN[i] = val2;




    }

   return(0);
}
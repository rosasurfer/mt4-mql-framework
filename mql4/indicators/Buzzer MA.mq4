//+------------------------------------------------------------------+
//|                                                    Buzzer.mq4    |
//|                                                      samimaps    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "modify by samimaps"
#property link      "https://login.mql5.com/en/users/samimaps"

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_color1 Yellow
#property indicator_width1 2
#property indicator_color2 Lime
#property indicator_width2 2
#property indicator_color3 Red
#property indicator_width3 2


//---- input parameters
extern int     Price          = 0;
extern int     Length         = 20;

input ENUM_TIMEFRAMES TIME_FRAMES=0;


extern bool AlertON=true;
extern bool EmailON=true;
//---- indicator buffers
double MABuffer[];
double UpBuffer[];
double DnBuffer[];
double trend[];
double Del[];
double AvgDel[];
 int     Displace       = 0;
 double  PctFilter      = 1.36;
 string note1 ="turn on Color = 1; turn off = 0";
 int     Color          = 1;
 int     ColorBarBack   = 1;
 double  Deviation      = 0;

double alfa[];
int i, Phase, Len,Cycle=4;
double Coeff, beta, t, Sum, Weight, g;
double pi = 3.1415926535;
bool   UpTrendAlert=false, DownTrendAlert=false;

  int init()
  {
   IndicatorBuffers(6);
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,MABuffer);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1,UpBuffer);
   SetIndexStyle(2,DRAW_LINE);
   SetIndexBuffer(2,DnBuffer);
   SetIndexBuffer(3,trend);
   SetIndexBuffer(4,Del);
   SetIndexBuffer(5,AvgDel);
   string short_name;
//---- indicator line

   IndicatorDigits(MarketInfo(Symbol(),MODE_DIGITS));
//---- name for DataWindow and indicator subwindow label
   short_name="Buzzer("+Length+")";
   IndicatorShortName(short_name);
   SetIndexLabel(0,"Buzzer");
   SetIndexLabel(1,"Buzzer_UP");
   SetIndexLabel(2,"Buzzer_DN");
//----
   SetIndexShift(0,Displace);
   SetIndexShift(1,Displace);
   SetIndexShift(2,Displace);

   SetIndexEmptyValue(0,EMPTY_VALUE);
   SetIndexEmptyValue(1,EMPTY_VALUE);
   SetIndexEmptyValue(2,EMPTY_VALUE);

   SetIndexDrawBegin(0,Length*Cycle+Length+1);
   SetIndexDrawBegin(1,Length*Cycle+Length+1);
   SetIndexDrawBegin(2,Length*Cycle+Length+1);
//----

   Coeff =  3*pi;
   Phase = Length-1;
   Len = Length*4 + Phase;
   ArrayResize(alfa,Len);
   Weight=0;

      for (i=0;i<Len-1;i++)
      {
      if (i<=Phase-1) t = 1.0*i/(Phase-1);
      else t = 1.0 + (i-Phase+1)*(2.0*Cycle-1.0)/(Cycle*Length-1.0);
      beta = MathCos(pi*t);
      g = 1.0/(Coeff*t+1);
      if (t <= 0.5 ) g = 1;
      alfa[i] = g * beta;
      Weight += alfa[i];
      }

   return(0);
  }


int start()
{
   int    shift, counted_bars=IndicatorCounted(),limit;
   double price;

   if ( counted_bars > 0 )  limit=Bars-counted_bars;
   if ( counted_bars < 0 )  return(0);
   if ( counted_bars ==0 )  limit=Bars-Len-1;
   if ( counted_bars < 1 )

   for(i=1;i<Length*Cycle+Length;i++)
   {
   MABuffer[Bars-i]=0;
   UpBuffer[Bars-i]=0;
   DnBuffer[Bars-i]=0;
   }

   for(shift=limit;shift>=0;shift--)
   {
      Sum = 0;
      for (i=0;i<=Len-1;i++)
	   {
      price = iMA(Symbol(),TIME_FRAMES,1,0,3,Price,i+shift);
      Sum += alfa[i]*price;

      }

	if (Weight > 0) MABuffer[shift] = (1.0+Deviation/100)*Sum/Weight;


      if (PctFilter>0)
      {
      Del[shift] = MathAbs(MABuffer[shift] - MABuffer[shift+1]);

      double sumdel=0;
      for (i=0;i<=Length-1;i++) sumdel = sumdel+Del[shift+i];
      AvgDel[shift] = sumdel/Length;

      double sumpow = 0;
      for (i=0;i<=Length-1;i++) sumpow+=MathPow(Del[shift+i]-AvgDel[shift+i],2);
      double StdDev = MathSqrt(sumpow/Length);

      double Filter = PctFilter * StdDev;

      if( MathAbs(MABuffer[shift]-MABuffer[shift+1]) < Filter ) MABuffer[shift]=MABuffer[shift+1];
      }
      else
      Filter=0;

      if (Color>0)
      {
      trend[shift]=trend[shift+1];
      if (MABuffer[shift]-MABuffer[shift+1] > Filter) trend[shift]= 1;
      if (MABuffer[shift+1]-MABuffer[shift] > Filter) trend[shift]=-1;
         if (trend[shift]>0)
         {
         UpBuffer[shift] = MABuffer[shift];
         if (trend[shift+ColorBarBack]<0) UpBuffer[shift+ColorBarBack]=MABuffer[shift+ColorBarBack];
         DnBuffer[shift] = EMPTY_VALUE;
         if (EmailON && trend[shift+1]<0 && shift==0) SendMail("Buzzer", "DownTrendAlert");
         }
         if (trend[shift]<0)
         {
         DnBuffer[shift] = MABuffer[shift];
         if (trend[shift+ColorBarBack]>0) DnBuffer[shift+ColorBarBack]=MABuffer[shift+ColorBarBack];
         UpBuffer[shift] = EMPTY_VALUE;
         if (EmailON && trend[shift+1]>0 && shift==0) SendMail("Buzzer", "UpTrendAlert");
         }
      }
   }
//----------
   string Message;

   if ( trend[2]<0 && trend[1]>0 && Volume[0]>1 && !UpTrendAlert)
	{
	Message = " "+Symbol()+" M"+Period()+": Signal for BUY";
	if ( AlertON ) Alert (Message);
	UpTrendAlert=true; DownTrendAlert=false;
	if(EmailON) SendMail("Buzzer", "UpTrendAlert");
	}

	if ( trend[2]>0 && trend[1]<0 && Volume[0]>1 && !DownTrendAlert)
	{
	Message = " "+Symbol()+" M"+Period()+": Signal for SELL";
	if ( AlertON ) Alert (Message);
	DownTrendAlert=true; UpTrendAlert=false;
	if(EmailON) SendMail("Buzzer", "DownTrendAlert");
	}
//----
	return(0);
}

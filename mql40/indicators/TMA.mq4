//+------------------------------------------------------------------+
//|                                  TriangularMA centered bands.mq4 |
//|                                                           mladen |
//| forex-tsd elite section only                                     |
//+------------------------------------------------------------------+
#property copyright "mladen"
#property link      "mladenfx@gmail.com"

#property indicator_chart_window
#property indicator_buffers    3
#property indicator_color1     LimeGreen
#property indicator_color2     Red
#property indicator_color3     Green
#property indicator_style1     STYLE_DOT
#property indicator_style2     STYLE_SOLID
#property indicator_style3     STYLE_SOLID

//
//
//
//
//

extern string TimeFrame       = "current time frame";
extern int    HalfLength      = 20;
extern int    Price           = PRICE_CLOSE;
extern double ATRMultiplier   = 2.0;
extern int    ATRPeriod       = 100;
extern bool   Interpolate     = true;

extern bool   alertsOn        = false;
extern bool   alertsOnCurrent = false;
extern bool   alertsOnHighLow = false;
extern bool   alertsMessage   = false;
extern bool   alertsSound     = false;
extern bool   alertsEmail     = false;

//
//
//
//
//

double buffer1[];
double buffer2[];
double buffer3[];
double trend[];

//
//
//
//
//

string indicatorFileName;
bool   calculateValue;
bool   returnBars;
int    timeFrame;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//

int init()
{
   IndicatorBuffers(4);
   HalfLength=MathMax(HalfLength,1);
      SetIndexBuffer(0,buffer1); SetIndexDrawBegin(0,HalfLength);
      SetIndexBuffer(1,buffer2); SetIndexDrawBegin(1,HalfLength);
      SetIndexBuffer(2,buffer3); SetIndexDrawBegin(2,HalfLength);
      SetIndexBuffer(3,trend);

      //
      //
      //
      //
      //

      indicatorFileName = WindowExpertName();
      returnBars        = TimeFrame=="returnBars";     if (returnBars)     return(0);
      calculateValue    = TimeFrame=="calculateValue"; if (calculateValue) return(0);
      timeFrame         = stringToTimeFrame(TimeFrame);

      //
      //
      //
      //
      //

   IndicatorShortName(timeFrameToString(timeFrame)+" TMA bands )"+HalfLength+")");
   return(0);
}
int deinit() { return(0); }




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

int start()
{
   int counted_bars=IndicatorCounted();
   int i,j,k,limit;

   if(counted_bars<0) return(-1);
   if(counted_bars>0) counted_bars--;
           limit=MathMin(Bars-1,Bars-counted_bars+HalfLength);
            if (returnBars)  { buffer1[0] = limit+1; return(0); }

   //
   //
   //
   //
   //

   if (calculateValue || timeFrame==Period())
   {
      for (i=limit; i>=0; i--)
      {
         double sum  = (HalfLength+1)*iMA(NULL,0,1,0,MODE_SMA,Price,i);
         double sumw = (HalfLength+1);

         for(j=1, k=HalfLength; j<=HalfLength; j++, k--)
         {
            sum  += k*iMA(NULL,0,1,0,MODE_SMA,Price,i+j);
            sumw += k;

            if (j<=i)
            {
               sum  += k*iMA(NULL,0,1,0,MODE_SMA,Price,i-j);
               sumw += k;
            }
         }

         //
         //
         //
         //
         //

         double range = iATR(NULL,0,ATRPeriod,i+10)*ATRMultiplier;
            buffer1[i] = sum/sumw;
            buffer2[i] = buffer1[i]+range;
            buffer3[i] = buffer1[i]-range;

         //
         //
         //
         //
         //

         trend[i] = 0;
            if (alertsOnHighLow)
            {
               if (High[i] > buffer2[i]) trend[i] =  1;
               if (Low[i]  < buffer3[i]) trend[i] = -1;
            }
            else
            {
               if (Close[i] > buffer2[i]) trend[i] =  1;
               if (Close[i] < buffer3[i]) trend[i] = -1;
            }
      }
      if (!calculateValue) manageAlerts();
      return(0);
   }

   //
   //
   //
   //
   //

   limit = MathMax(limit,MathMin(Bars-1,iCustom(NULL,timeFrame,indicatorFileName,"returnBars",0,0)*timeFrame/Period()));
   for(i=limit; i>=0; i--)
   {
      int y = iBarShift(NULL,timeFrame,Time[i]);
      buffer1[i] = iCustom(NULL,timeFrame,indicatorFileName,"calculateTma",HalfLength,Price,ATRMultiplier,ATRPeriod,0,y);
      buffer2[i] = iCustom(NULL,timeFrame,indicatorFileName,"calculateTma",HalfLength,Price,ATRMultiplier,ATRPeriod,1,y);
      buffer3[i] = iCustom(NULL,timeFrame,indicatorFileName,"calculateTma",HalfLength,Price,ATRMultiplier,ATRPeriod,2,y);
      trend[i]   = iCustom(NULL,timeFrame,indicatorFileName,"calculateTma",HalfLength,Price,ATRMultiplier,ATRPeriod,3,y);

      //
      //
      //
      //
      //

      if (timeFrame <= Period() || y==iBarShift(NULL,timeFrame,Time[i-1])) continue;
      if (!Interpolate) continue;

      //
      //
      //
      //
      //

      datetime time = iTime(NULL,timeFrame,y);
         for(int n = 1; i+n < Bars && Time[i+n] >= time; n++) continue;
         for(k = 1; k < n; k++)
         {
            buffer1[i+k] = buffer1[i]  +(buffer1[i+n]-buffer1[i])*k/n;
            buffer2[i+k] = buffer2[i]  +(buffer2[i+n]-buffer2[i])*k/n;
            buffer3[i+k] = buffer3[i]  +(buffer3[i+n]-buffer3[i])*k/n;
         }
   }

   //
   //
   //
   //
   //

   manageAlerts();
   return(0);
}

//+-------------------------------------------------------------------
//|
//+-------------------------------------------------------------------
//
//
//
//
//

void manageAlerts()
{
   if (alertsOn)
   {
      if (alertsOnCurrent)
           int whichBar = 0;
      else     whichBar = 1; whichBar = iBarShift(NULL,0,iTime(NULL,timeFrame,whichBar));
      if (trend[whichBar] != trend[whichBar+1])
      {
         if (trend[whichBar] == 1) doAlert(whichBar,"up");
         if (trend[whichBar] ==-1) doAlert(whichBar,"down");
      }
   }
}

//
//
//
//
//

void doAlert(int forBar, string doWhat)
{
   static string   previousAlert="nothing";
   static datetime previousTime;
   string message;

   if (previousAlert != doWhat || previousTime != Time[forBar]) {
       previousAlert  = doWhat;
       previousTime   = Time[forBar];

       //
       //
       //
       //
       //

       message =  StringConcatenate(Symbol()," at ",TimeToStr(TimeLocal(),TIME_SECONDS)," "+timeFrameToString(timeFrame)+" TMA bands price penetrated ",doWhat," band");
          if (alertsMessage) Alert(message);
          if (alertsEmail)   SendMail(StringConcatenate(Symbol(),"TMA bands "),message);
          if (alertsSound)   PlaySound("alert2.wav");
   }
}

//+-------------------------------------------------------------------
//|
//+-------------------------------------------------------------------
//
//
//
//
//

string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200};

//
//
//
//
//

int stringToTimeFrame(string tfs)
{
   tfs = StringUpperCase(tfs);
   for (int i=ArraySize(iTfTable)-1; i>=0; i--)
         if (tfs==sTfTable[i] || tfs==""+iTfTable[i]) return(MathMax(iTfTable[i],Period()));
                                                      return(Period());
}
string timeFrameToString(int tf)
{
   for (int i=ArraySize(iTfTable)-1; i>=0; i--)
         if (tf==iTfTable[i]) return(sTfTable[i]);
                              return("");
}

//
//
//
//
//

string StringUpperCase(string str)
{
   string   s = str;

   for (int length=StringLen(str)-1; length>=0; length--)
   {
      int char = StringGetChar(s, length);
         if((char > 96 && char < 123) || (char > 223 && char < 256))
                     s = StringSetChar(s, length, char - 32);
         else if(char > -33 && char < 0)
                     s = StringSetChar(s, length, char + 224);
   }
   return(s);
}

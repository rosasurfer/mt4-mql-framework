/**
 * SATL - Slow Adaptive Trendline
 *
 *
 * At the moment this indicator serves for demonstration purposes only. Its filter coefficients are long expired and it must
 * not be used for real trade decisions.
 *
 * @see  http://www.finware.com/
 */
#property copyright "Copyright 2002, Finware.ru Ltd."
#property link "http://www.finware.ru/"
//----
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Red
//---- buffers
double SATLBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   string short_name;
//---- indicator line
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,SATLBuffer);
   SetIndexDrawBegin(0,64);
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| SATL                                                             |
//+------------------------------------------------------------------+
int start()
  {
   int i,counted_bars=IndicatorCounted();
//----
   if(Bars<=64) return(0);
//---- initial zero
   if(counted_bars<64)
      for(i=1;i<=0;i++) SATLBuffer[Bars-i]=0.0;
//----
   i=Bars-64-1;
   if(counted_bars>=64) i=Bars-counted_bars-1;
   while(i>=0)
     {
      SATLBuffer[i]=
      0.0982862174*Close[i+0]
      +0.0975682269*Close[i+1]
      +0.0961401078*Close[i+2]
      +0.0940230544*Close[i+3]
      +0.0912437090*Close[i+4]
      +0.0878391006*Close[i+5]
      +0.0838544303*Close[i+6]
      +0.0793406350*Close[i+7]
      +0.0743569346*Close[i+8]
      +0.0689666682*Close[i+9]
      +0.0632381578*Close[i+10]
      +0.0572428925*Close[i+11]
      +0.0510534242*Close[i+12]
      +0.0447468229*Close[i+13]
      +0.0383959950*Close[i+14]
      +0.0320735368*Close[i+15]
      +0.0258537721*Close[i+16]
      +0.0198005183*Close[i+17]
      +0.0139807863*Close[i+18]
      +0.0084512448*Close[i+19]
      +0.0032639979*Close[i+20]
      -0.0015350359*Close[i+21]
      -0.0059060082*Close[i+22]
      -0.0098190256*Close[i+23]
      -0.0132507215*Close[i+24]
      -0.0161875265*Close[i+25]
      -0.0186164872*Close[i+26]
      -0.0205446727*Close[i+27]
      -0.0219739146*Close[i+28]
      -0.0229204861*Close[i+29]
      -0.0234080863*Close[i+30]
      -0.0234566315*Close[i+31]
      -0.0231017777*Close[i+32]
      -0.0223796900*Close[i+33]
      -0.0213300463*Close[i+34]
      -0.0199924534*Close[i+35]
      -0.0184126992*Close[i+36]
      -0.0166377699*Close[i+37]
      -0.0147139428*Close[i+38]
      -0.0126796776*Close[i+39]
      -0.0105938331*Close[i+40]
      -0.0084736770*Close[i+41]
      -0.0063841850*Close[i+42]
      -0.0043466731*Close[i+43]
      -0.0023956944*Close[i+44]
      -0.0005535180*Close[i+45]
      +0.0011421469*Close[i+46]
      +0.0026845693*Close[i+47]
      +0.0040471369*Close[i+48]
      +0.0052380201*Close[i+49]
      +0.0062194591*Close[i+50]
      +0.0070340085*Close[i+51]
      +0.0076266453*Close[i+52]
      +0.0080376628*Close[i+53]
      +0.0083037666*Close[i+54]
      +0.0083694798*Close[i+55]
      +0.0082901022*Close[i+56]
      +0.0080741359*Close[i+57]
      +0.0077543820*Close[i+58]
      +0.0073260526*Close[i+59]
      +0.0068163569*Close[i+60]
      +0.0062325477*Close[i+61]
      +0.0056078229*Close[i+62]
      +0.0049516078*Close[i+63]
      +0.0161380976*Close[i+64];
      i--;
     }
   return(0);
  }
//+------------------------------------------------------------------+

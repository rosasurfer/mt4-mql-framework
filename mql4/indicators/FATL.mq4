/**
 * FATL - Fast Adaptive Trendline
 *
 *
 * At the moment this indicator serves for demonstration purposes only. Its filter coefficients are long expired and it must
 * not be used for real trade decisions.
 *
 * @see  http://www.finware.com/
 */
#property copyright "Copyright 2002, Finware.ru Ltd."
#property link "http://www.finware.ru/"

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Blue


//---- buffers
double FATLBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function |
//+------------------------------------------------------------------+
int init()
{
string short_name;
//---- indicator line
SetIndexStyle(0,DRAW_LINE);
SetIndexBuffer(0,FATLBuffer);
SetIndexDrawBegin(0,38);
//----
return(0);
}
//+------------------------------------------------------------------+
//| FATL |
//+------------------------------------------------------------------+
int start()
{
int i,counted_bars=IndicatorCounted();
//----
if(Bars<=38) return(0);
//---- initial zero
if(counted_bars<38)
for(i=1;i<=0;i++) FATLBuffer[Bars-i]=0.0;
//----
i=Bars-38-1;
if(counted_bars>=38) i=Bars-counted_bars-1;
while(i>=0)
{
FATLBuffer[i]=
0.4360409450*Close[i+0]
+0.3658689069*Close[i+1]
+0.2460452079*Close[i+2]
+0.1104506886*Close[i+3]
-0.0054034585*Close[i+4]
-0.0760367731*Close[i+5]
-0.0933058722*Close[i+6]
-0.0670110374*Close[i+7]
-0.0190795053*Close[i+8]
+0.0259609206*Close[i+9]
+0.0502044896*Close[i+10]
+0.0477818607*Close[i+11]
+0.0249252327*Close[i+12]
-0.0047706151*Close[i+13]
-0.0272432537*Close[i+14]
-0.0338917071*Close[i+15]
-0.0244141482*Close[i+16]
-0.0055774838*Close[i+17]
+0.0128149838*Close[i+18]
+0.0226522218*Close[i+19]
+0.0208778257*Close[i+20]
+0.0100299086*Close[i+21]
-0.0036771622*Close[i+22]
-0.0136744850*Close[i+23]
-0.0160483392*Close[i+24]
-0.0108597376*Close[i+25]
-0.0016060704*Close[i+26]
+0.0069480557*Close[i+27]
+0.0110573605*Close[i+28]
+0.0095711419*Close[i+29]
+0.0040444064*Close[i+30]
-0.0023824623*Close[i+31]
-0.0067093714*Close[i+32]
-0.0072003400*Close[i+33]
-0.0047717710*Close[i+34]
+0.0005541115*Close[i+35]
+0.0007860160*Close[i+36]
+0.0130129076*Close[i+37]
+0.0040364019*Close[i+38];


i--;
}
return(0);
}
//+------------------------------------------------------------------+

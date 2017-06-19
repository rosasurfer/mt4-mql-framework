//+--------------------------------------------------+
//|                                          JMA.mq4 |
//|                      Flat Eric's Monkey business |
//+--------------------------------------------------+
#property copyright "Copyright © 2006, Flat Eric's Monkey business"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1 Aqua
#property indicator_color2 Yellow
//---- input parameters
extern double    Len1 = 13;
extern double    phase1 = 0;
extern int    BarCount = 300;

//---- buffers
double ExtMapBuffer1[];
double ExtMapBuffer2[];
//---- Globals
datetime  prevtime;
int handle;
bool lng=false;
bool shrt=false;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicators
   SetIndexStyle(0,DRAW_LINE);
   SetIndexBuffer(0,ExtMapBuffer1);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexBuffer(1,ExtMapBuffer2);
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//---- 
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int i;
   int    counted_bars=IndicatorCounted();
//---- 
bool firstTime=True;
int AccountedBars=0;
double avv=0;
double av1=0;
double av2=0;
double av3=0;
double av4=0;
double as8=0;
double as10=0;
double as18=0;
double as20=0;

int av5=0;
int av6=0;
int as28=0;
int as30=0;
int as38=0;
int as40=0;
int as48=0;
int as50=0;
int as58=0;
int as60=0;

double as68=0;
double as70=0;
double af8=0;
double af10=0;
double af18=0;
double af20=0;
double af28=0;
double af30=0;
double af38=0;
double af40=0;
double af48=0;
double af50=0;
double af58=0;
double af60=0;
double af68=0;
double af70=0;
double af78=0;
double af80=0;
double af88=0;
double af90=0;
double af98=0;
double afA0=0;
double afA8=0;
double afB0=0;
double afB8=0;
double afC0=0;
double afC8=0;
double afD0=0;
double af0=0;
double afD8=0;
double afE0=0;
double afE8=0;
int afF0=0;
double afF8=0;
int avalue2=0;
double jmaold=0;
double bug;

int ii=0;
int jj=0;
int shift=0;
double Series=0;
double alist[127];
double aring1[127];
double aring2[10];
double abuffer[61];
double jma1=0;
int samples;
int result;

   int fshift=0,fcnt=0;
   double fvalue1=0,fAccountedBars=0;
   int    fcounted_bars=IndicatorCounted();

ArrayInitialize(alist,0);
ArrayInitialize(aring1,0);
ArrayInitialize(aring2,0);
ArrayInitialize(abuffer,0);

/*
fAccountedBars = MathRound(MathMax(Bars-fcounted_bars,5));

for( fcnt = fAccountedBars; fcnt< Bars; fcnt++){
fshift = Bars - 1 - fcnt;


fAccountedBars=fAccountedBars+1;

}*/


if (firstTime)
{
  AccountedBars = Bars-BarCount;
  firstTime=False;
}
//if ((CurTime()-prevtime)<15) 
//  return(-1); 

//prevtime=CurTime(); 
if (Time[0]-prevtime<30) return(0); 
prevtime=Time[0];
//---- check for possible errors
//   if(counted_bars<0) return(-1);
//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;

//Public Sub CalcJMA(cmcbid)

for (shift=BarCount; shift>=0; shift--){

fvalue1 = 
0.4360409450*Close[shift+0]
+0.3658689069*Close[shift+1]
+0.2460452079*Close[shift+2]
+0.1104506886*Close[shift+3]
-0.0054034585*Close[shift+4]
-0.0760367731*Close[shift+5]
-0.0933058722*Close[shift+6]
-0.0670110374*Close[shift+7]
-0.0190795053*Close[shift+8]
+0.0259609206*Close[shift+9]
+0.0502044896*Close[shift+10]
+0.0477818607*Close[shift+11]
+0.0249252327*Close[shift+12]
-0.0047706151*Close[shift+13]
-0.0272432537*Close[shift+14]
-0.0338917071*Close[shift+15]
-0.0244141482*Close[shift+16]
-0.0055774838*Close[shift+17]
+0.0128149838*Close[shift+18]
+0.0226522218*Close[shift+19]
+0.0208778257*Close[shift+20]
+0.0100299086*Close[shift+21]
-0.0036771622*Close[shift+22]
-0.0136744850*Close[shift+23]
-0.0160483392*Close[shift+24]
-0.0108597376*Close[shift+25]
-0.0016060704*Close[shift+26]
+0.0069480557*Close[shift+27]
+0.0110573605*Close[shift+28]
+0.0095711419*Close[shift+29]
+0.0040444064*Close[shift+30]
-0.0023824623*Close[shift+31]
-0.0067093714*Close[shift+32]
-0.0072003400*Close[shift+33]
-0.0047717710*Close[shift+34]
+0.0005541115*Close[shift+35]
+0.0007860160*Close[shift+36]
+0.0130129076*Close[shift+37]
+0.0040364019*Close[shift+38];

ExtMapBuffer2[shift]= fvalue1;


as28 = 63;
as30 = 64;
for (ii=1; ii<=as28; ii++)
alist[ii] = -1000000;
for (ii=as30; ii<=127; ii++)
alist[ii] = 1000000;
af0 = 1;

Series = Close[shift];
if (afF0 < 61) {
        afF0 = afF0 + 1;
        abuffer[afF0] = Series;
}
//{--------------------------------------------------------------------}
// { main cycle }
if (afF0 > 30) {
        if (Len1 < 1.0000000002) { af80 = 0.0000000001; } else{ af80 = (Len1 - 1) / 2;}

        if (phase1 < -100) { af10 = 0.5; } else if (phase1 > 100) { af10 = 2.5; } else{ af10 = phase1 / 100 + 1.5;}

        av1 = MathLog(MathSqrt(af80));
        av2 = av1;
        if (av1 / MathLog(2) + 2 < 0) { av3 = 0; } else{ av3 = av2 / MathLog(2) + 2;}
        af98 = av3;

        if (0.5 <= af98 - 2) { af88 = af98 - 2; } else{ af88 = 0.5;}
        af78 = MathSqrt(af80) * af98;
        af90 = af78 / (af78 + 1);
        af80 = af80 * 0.9;
        af50 = af80 / (af80 + 2);

        if (af0 != 0) {
                af0 = 0;
                av5 = 0;
                for (ii=1; ii<=29; ii++)
                        if (abuffer[ii + 1] != abuffer[ii]) { av5 = 1;}

                afD8 = av5 * 30;
                if (afD8 == 0) { af38 = Series; } else {af38 = abuffer[1];}
                af18 = af38;
                if (afD8 > 29) { afD8 = 29;}
        } else{
            afD8 = 0;
        }

        for (ii=afD8; ii>=0; ii--){                                                         //{ another bigcycle...}
                avalue2 = 31 - ii;
                if (ii == 0) { af8 = Series; } else{ af8 = abuffer[avalue2];}
                af28 = af8 - af18;
                af48 = af8 - af38;
                if (MathAbs(af28) > MathAbs(af48)) { av2 = MathAbs(af28); } else {av2 = MathAbs(af48);}
                afA0 = av2;
                avv = afA0 + 0.0000000001;                       //{1.0e-10}

                if (as48 <= 1) { as48 = 127; } else{ as48 = as48 - 1;}
                if (as50 <= 1) { as50 = 10; } else{ as50 = as50 - 1;}
                if (as70 < 128) { as70 = as70 + 1;}
                as8 = as8 + avv - aring2[as50];
                aring2[as50] = avv;
                if (as70 > 10) { as20 = as8 / 10; } else{ as20 = as8 / as70;}

                if (as70 > 127) {
                        as10 = aring1[as48];
                        aring1[as48] = as20;
                        as68 = 64;
                        as58 = as68;
                        while (as68 > 1){
                                if (alist[as58] < as10) {
                                        as68 = as68 * 0.5;
                                        as58 = as58 + as68;
                                } else{
                                    if (alist[as58] <= as10) {
                                        as68 = 1;
                                 
                                    } else{
                                         as68 = as68 * 0.5;
                                         as58 = as58 - as68;
                                    }
                                }
                        }        //Wend
                } else{
                        aring1[as48] = as20;
                        if (as28 + as30 > 127) {
                                as30 = as30 - 1;
                                as58 = as30;
                         
                        } else{
                                as28 = as28 + 1;
                                as58 = as28;
                        }
                        if (as28 > 96) { as38 = 96; } else{ as38 = as28;}
                        if (as30 < 32) { as40 = 32; } else{ as40 = as30;}
                }

                as68 = 64;
                as60 = as68;
                while (as68 > 1){
                    if (alist[as60] >= as20) {
                        if (alist[as60 - 1] <= as20) {
                             as68 = 1;
                        } else{
                             as68 = as68 * 0.5;
                             as60 = as60 - as68;
                        }
                    } else{
                        as68 = as68 * 0.5;
                        as60 = as60 + as68;
                    }
                    if ((as60 == 127) && (as20 > alist[127])) { as60 = 128;}
                }          //Wend

        if (as70 > 127) {
            if (as58 >= as60) {
                if ((as38 + 1 > as60) && (as40 - 1 < as60)) {
                    as18 = as18 + as20;
                } else{
                    if ((as40 > as60) && (as40 - 1 < as58)) {
                        as18 = as18 + alist[as40 - 1];
                    } else{
                       if (as40 >= as60) {
                            if ((as38 + 1 < as60) && (as38 + 1 > as58)) {
                                as18 = as18 + alist[as38 + 1];
                            } else{
                               if (as38 + 2 > as60) {
                                    as18 = as18 + as20;
                               } else{
                                  if ((as38 + 1 < as60) && (as38 + 1 > as58)) {
                                        as18 = as18 + alist[as38 + 1];
                                  }
                                  if (as58 > as60) {
                                      if ((as40 - 1 < as58) && (as38 + 1 > as58)) {
                                            as18 = as18 - alist[as58];
                                      } else{
                                         if ((as38 < as58) && (as38 + 1 > as60)) {
                                                as18 = as18 - alist[as38];
                                         } else{
                                            if ((as38 + 1 > as58) && (as40 - 1 < as58)) {
                                                    as18 = as18 - alist[as58];
                                            } else{
                                               if ((as40 > as58) && (as40 < as60)) {
                                                        as18 = as18 - alist[as40];
                                               }
                                            }
                                         }
                                     }
                                 }
                             }
                       }
                   }
               }
           }
         }
        }
        if (as58 <= as60) {
            if (as58 >= as60) {
                alist[as60] = as20;
            } else{
                for (jj=as58+1; jj<=as60-1; jj++)
                    alist[jj - 1] = alist[jj];
                alist[as60 - 1] = as20;
            }
        } else{
            for (jj=as58-1; jj>=as60; jj--)
                alist[jj + 1] = alist[jj];
            alist[as60] = as20;
        }

        if (as70 <= 127) {
            as18 = 0;
            for (jj=as40; jj<=as38; jj++)
                as18 = as18 + alist[jj];
        }
        af60 = as18 / (as38 - as40 + 1);
        if (afF8 + 1 > 31) { afF8 = 31; } else{ afF8 = afF8 + 1;}

        if (afF8 <= 30) {
                if (af28 > 0) { af18 = af8; } else{ af18 = af8 - af28 * af90;}
                if (af48 < 0) { af38 = af8; } else{ af38 = af8 - af48 * af90;}
                afB8 = Series;
                                                //{EasyLanguage does not have "continue" statement}
                if (afF8 != 30)  continue;     //GoTo eola
                if (afF8 == 30) {
                        afC0 = Series;
                        if ((af78 + 0.5) >= 1) { av4 = (af78 + 0.5); } else{ av4 = 1;}
                        afE8 = (av4 + 0.5);
                        if ((af78 - 0.5) >= 1) { av2 = (af78 - 0.5); } else{ av2 = 1;}
                        afE0 = (av2 + 0.5);
                        if (afE8 == afE0) {
                            af68 = 1;
                        } else{
                            av4 = afE8 - afE0;
                            af68 = (af78 - afE0) / av4;
                        }
                        if (afE0 <= 29) { av5 = afE0; } else{ av5 = 29;}
                        if (afE8 <= 29) { av6 = afE8; } else{ av6 = 29;}
                        afA8 = (Series - abuffer[afF0 - av5]) * (1 - af68) / afE0 + (Series - abuffer[afF0 - av6]) * af68 / afE8;
                }
} else{
        if (af98 >= MathPow((afA0 / af60), af88)) { av1 =MathPow((afA0 / af60), af88); } else{ av1 = af98;}
        if (av1 < 1) {
            av2 = 1;
        } else{
           if (af98 >= MathPow((afA0 / af60) ,af88)) { av3 = MathPow((afA0 / af60) ,af88); } else{ av3 = af98;}
           av2 = av3;
        }
        af58 = av2;
        af70 = MathPow(af90 ,MathSqrt(af58));
        if (af28 > 0) { af18 = af8 ;} else{ af18 = af8 - af28 * af70;}
        if (af48 < 0) { af38 = af8 ;} else{ af38 = af8 - af48 * af70;}
}

//eola:
}        //Next ii

if (afF8 > 30) {
        af30 = MathPow(af50 ,af58);
        afC0 = (1 - af30) * Series + af30 * afC0;
        afC8 = (Series - afC0) * (1 - af50) + af50 * afC8;
        afD0 = af10 * afC8 + afC0;
        af20 = af30 * (-2);
        af40 = af30 * af30;
        afB0 = af20 + af40 + 1;
        afA8 = (afD0 - afB8) * afB0 + af40 * afA8;
        afB8 = afB8 + afA8;
}
jma1 = afB8;
}
if (afF0 <= 30) { jma1 = 0;}

//}                 //Next shift
ExtMapBuffer1[shift]=jma1;
//}     // End of JMA1

  if (shift>0)
  { 
    AccountedBars=AccountedBars+1;
  }

}     // End of JMA

//Comment("FatL= ",fvalue1,"   ","JMA= ",jma1);

if (ExtMapBuffer2[0]<ExtMapBuffer1[0] && lng){
   lng=false;
}
if (ExtMapBuffer2[0]>ExtMapBuffer1[0] && shrt){
   shrt=false;
}
   
//----
   return(0);
  }
//+------------------------------------------------------------------+

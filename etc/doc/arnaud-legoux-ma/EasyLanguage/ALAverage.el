{*******************************************************************
required by ALMA.el
********************************************************************}


inputs:
   Price (numericseries),
   Bars  (numericsimple),
   Sigma (numericsimple),
   Offset(numericsimple);


vars:
   m     (0),
   s     (0),
   Wtd   (0),
   WtdSum(0),
   CumWt (0),
   i     (0);


   m = Floor(Offset * (Bars - 1));
   s = Bars/Sigma;

   WtdSum = 0;
   CumWt  = 0;

   for i = 0 to Bars - 1 begin
      Wtd    = ExpValue(-((i-m)*(i-m))/(2*s*s));
      WtdSum = WtdSum + Wtd * Price[Bars - 1 - i] ;
      CumWt  = CumWt + Wtd;
   end;

   ALAverage = WtdSum / CumWt;

{*******************************************************************
Description : This Indicator plots ALMA(Arnaud Legoux Moving Average)
Provided By : TrendLaboratory(c) Copyright 2010
Author      : IgorAD E-mail: igorad2003@yahoo.co.uk
            : http://finance.groups.yahoo.com/group/TrendLaboratory/
********************************************************************}

inputs:
   Price        (Close),
   WindowSize   (9),
   Sigma        (6),
   Offset       (0.85),
   Displace     (0),
   ColorMode    (0),
   ColorBarsBack(0);


vars:
   ALMA (0),
   trend(0);


if Displace >= 0 or CurrentBar > AbsValue(Displace) then begin
   ALMA = ALAverage(Price, WindowSize, Sigma, Offset);

   Plot1[Displace](ALMA, "ALMA");

   if ColorMode > 0 then begin
      if ALMA > ALMA[1] then trend =  1;
      if ALMA < ALMA[1] then trend = -1;

      if trend > 0 then SetPlotColor[ColorBarsBack](1, Blue);
      if trend < 0 then SetPlotColor[ColorBarsBack](1, Red );
   end;

   // Alert criteria
   if Displace <= 0 then begin
      if      Price > ALMA and ALMA > ALMA[1] and ALMA[1] <= ALMA[2] then Alert("Indicator turning up"  )
      else if Price < ALMA and ALMA < ALMA[1] and ALMA[1] >= ALMA[2] then Alert("Indicator turning down");
   end;
end;

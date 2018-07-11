/**
 * ALMA: Arnaud Legoux Moving Average
 * 
 * @copyright Arnaud Legoux/Dimitris Kouzis-Loukas/Anthony Cascino
 * @version   NinjaTrader 6.5
 */
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Xml.Serialization;
using NinjaTrader.Cbi;
using NinjaTrader.Data;
using NinjaTrader.Gui.Chart;


namespace NinjaTrader.Indicator {

   [Description("ALMA (Arnaud Legoux MA)")]
   public class ALMA : Indicator {

      private int      iWindowSize = 9;
      private double   dSigma      = 6.0;
      private double   dSample     = 0.5;
      private double[] daALMA;


      /**
       * Used to configure the indicator and called once before any bar data is loaded.
       */
      protected override void Initialize() {
         Add(new Plot(Color.FromKnownColor(KnownColor.LightSkyBlue), PlotStyle.Line, "ALMA_Plot"));
         CalculateOnBarClose = true;
         Overlay             = true;
         PriceTypeSupported  = false;
         BarsRequired        = 3;
         alma                = new double[iWindowSize];
         ResetWindow();
      }


      /**
       * Called on each incoming tick.
       */
      protected override void OnBarUpdate() {
         if (CurrentBar < iWindowSize)
            return;
         int    pt   = 0;
         double agr  = 0;
         double norm = 0;

         for (int i=0; i < iWindowSize; i++) {
            if (i < iWindowSize - pt) {
               agr  += daALMA[i] * Close[iWindowSize - pt - 1 - i];
               norm += daALMA[i];
            }
         }
         if (norm != 0)
            agr /= norm;            // normalize the result
         ALMA_Plot.Set(agr);        // set the appropriate bar
      }


      /**
       * 
       */
      private void ResetWindow() {
         double m = (int) Math.Floor(dSample * (double)(iWindowSize - 1));
         double s = iWindowSize / dSigma;

         for (int i=0; i < iWindowSize; i++) {
            daALMA[i] = Math.Exp(-((((double)i)-m) * (((double)i)-m)) / (2*s*s));
         }
      }


      // Getter / Setter
      [Category("Parameters")][Description("ALMA period. Must be an odd number.")]
      public int WindowSize {
         get { return iWindowSize; }
         set {
            iWindowSize = Math.Min(Math.Max(1, value), 50);
            // Only odd sizes
            if ((iWindowSize & 1) == 0)
               iWindowSize++;
         }
      }


      [Category("Parameters")][Description("Precision / Smoothing")]
      public double Sigma {
         get { return dSigma; }
         set { dSigma = Math.Min(Math.Max(0.01, value), 50.0); }
      }


      [Category("Parameters")][Description("Sample point. Where in terms of the window should we take the current value (0-1)")]
      public double SamplePoint {
         get { return dSample; }
         set { dSample = Math.Min(Math.Max(0.0, value), 1.0); }
      }


      [Browsable(false)][XmlIgnore()]
      public DataSeries ALMA_Plot {
         get { return Values[0]; }
      }
    }
}


#region NinjaScript generated code

// This namespace holds all indicators and is required. Do not change it.
namespace NinjaTrader.Indicator {
    public partial class Indicator : IndicatorBase {
        private ALMA[] cacheALMA = null;

        private static ALMA checkALMA = new ALMA();

        /// <summary>
        /// ALMA (contact@arnaudlegoux.com) by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino
        /// </summary>
        public ALMA ALMA(double samplePoint, double sigma, int windowSize) {
            return ALMA(Input, samplePoint, sigma, windowSize);
        }


        /**
         * ALMA (contact@arnaudlegoux.com) by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino
         */
        public ALMA ALMA(Data.IDataSeries input, double samplePoint, double sigma, int windowSize) {
            checkALMA.SamplePoint = samplePoint;
            samplePoint           = checkALMA.SamplePoint;
            checkALMA.Sigma       = sigma;
            sigma                 = checkALMA.Sigma;
            checkALMA.WindowSize  = windowSize;
            windowSize            = checkALMA.WindowSize;

            if (cacheALMA != null)
                for (int idx = 0; idx < cacheALMA.Length; idx++)
                    if (Math.Abs(cacheALMA[idx].SamplePoint - samplePoint) <= double.Epsilon && Math.Abs(cacheALMA[idx].Sigma - sigma) <= double.Epsilon && cacheALMA[idx].WindowSize == windowSize && cacheALMA[idx].EqualsInput(input))
                        return cacheALMA[idx];

            ALMA indicator = new ALMA();
            indicator.BarsRequired = BarsRequired;
            indicator.CalculateOnBarClose = CalculateOnBarClose;
            indicator.Input = input;
            indicator.SamplePoint = samplePoint;
            indicator.Sigma = sigma;
            indicator.WindowSize = windowSize;
            indicator.SetUp();

            ALMA[] tmp = new ALMA[cacheALMA == null ? 1 : cacheALMA.Length + 1];
            if (cacheALMA != null)
                cacheALMA.CopyTo(tmp, 0);
            tmp[tmp.Length - 1] = indicator;
            cacheALMA = tmp;
            Indicators.Add(indicator);

            return indicator;
        }
    }
}

// This namespace holds all market analyzer column definitions and is required. Do not change it.
namespace NinjaTrader.MarketAnalyzer
{
    public partial class Column : ColumnBase
    {
        /// <summary>
        /// ALMA (contact@arnaudlegoux.com) by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino
        /// </summary>
        /// <returns></returns>
        [Gui.Design.WizardCondition("Indicator")]
        public Indicator.ALMA ALMA(double samplePoint, double sigma, int windowSize)
        {
            return _indicator.ALMA(Input, samplePoint, sigma, windowSize);
        }

        /// <summary>
        /// ALMA (contact@arnaudlegoux.com) by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino
        /// </summary>
        /// <returns></returns>
        public Indicator.ALMA ALMA(Data.IDataSeries input, double samplePoint, double sigma, int windowSize)
        {
            return _indicator.ALMA(input, samplePoint, sigma, windowSize);
        }

    }
}

// This namespace holds all strategies and is required. Do not change it.
namespace NinjaTrader.Strategy
{
    public partial class Strategy : StrategyBase
    {
        /// <summary>
        /// ALMA (contact@arnaudlegoux.com) by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino
        /// </summary>
        /// <returns></returns>
        [Gui.Design.WizardCondition("Indicator")]
        public Indicator.ALMA ALMA(double samplePoint, double sigma, int windowSize)
        {
            return _indicator.ALMA(Input, samplePoint, sigma, windowSize);
        }

        /// <summary>
        /// ALMA (contact@arnaudlegoux.com) by Arnaud Legoux / Dimitris Kouzis-Loukas / Anthony Cascino
        /// </summary>
        /// <returns></returns>
        public Indicator.ALMA ALMA(Data.IDataSeries input, double samplePoint, double sigma, int windowSize)
        {
            if (InInitialize && input == null)
                throw new ArgumentException("You only can access an indicator with the default input/bar series from within the 'Initialize()' method");

            return _indicator.ALMA(input, samplePoint, sigma, windowSize);
        }

    }
}
#endregion

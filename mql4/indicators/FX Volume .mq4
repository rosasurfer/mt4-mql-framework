/**
 * FX Volume
 *
 * Displays real FX volume from the BankersFX data feed.
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern color Histogram.Color.Long  = LimeGreen;
extern color Histogram.Color.Short = Red;
extern int   Histogram.Style.Width = 2;

extern int   Max.Values            = 3000;            // max. number of values to display: -1 = all

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>

#define MODE_VOLUME_LONG    0                         // indicator buffer ids
#define MODE_VOLUME_SHORT   1

#property indicator_separate_window
#property indicator_level1  20

#property indicator_buffers 2

#property indicator_width1  2
#property indicator_width2  2

double longVolume [];                                 // long histogram values:  visible, displayed in "Data" window
double shortVolume[];                                 // short histogram values: visible, displayed in "Data" window

string bonkersIndicator = "BFX Core Volumes";


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) input validation
   // Colors                                          // after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Histogram.Color.Long  == 0xFF000000) Histogram.Color.Long  = CLR_NONE;
   if (Histogram.Color.Short == 0xFF000000) Histogram.Color.Short = CLR_NONE;

   // Styles
   if (Histogram.Style.Width < 1) return(catch("onInit(1)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));
   if (Histogram.Style.Width > 5) return(catch("onInit(2)  Invalid input parameter Histogram.Style.Width = "+ Histogram.Style.Width, ERR_INVALID_INPUT_PARAMETER));

   // Max.Values
   if (Max.Values < -1)           return(catch("onInit(3)  Invalid input parameter Max.Values = "+ Max.Values, ERR_INVALID_INPUT_PARAMETER));


   // (2) check existence of BankersFX indicator
   string mqlDir = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
   string indicatorFile = TerminalPath() + mqlDir +"\\indicators\\"+ bonkersIndicator +".ex4";
   if (!IsFile(indicatorFile))    return(catch("onInit(4)  Bonkers indicator not found: "+ DoubleQuoteStr(indicatorFile), ERR_FILE_NOT_FOUND));


   // (3) indicator buffer management
   IndicatorBuffers(2);
   SetIndexBuffer(MODE_VOLUME_LONG,  longVolume );    // long volume values:  visible, displayed in "Data" window
   SetIndexBuffer(MODE_VOLUME_SHORT, shortVolume);    // short volume values: visible, displayed in "Data" window

   return(catch("onInit(5)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for initialized account number (needed for Bonkers license validation)
   if (!AccountNumber())
      return(debug("onInit(1)  waiting for account number initialization (still 0)", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // check for finished buffer initialization (may be needed on terminal start)
   if (!ArraySize(longVolume))
      return(debug("onTick(2)  size(longVolume) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

   // reset all buffers and delete garbage behind Max.Values before doing a full recalculation
   if (!ValidBars) {
      ArrayInitialize(longVolume,  EMPTY_VALUE);
      ArrayInitialize(shortVolume, EMPTY_VALUE);
      SetIndicatorStyles();                           // fix for various terminal bugs
   }

   // synchronize buffers with a shifted offline chart (if applicable)
   if (ShiftedBars > 0) {
      ShiftIndicatorBuffer(longVolume,  Bars, ShiftedBars, EMPTY_VALUE);
      ShiftIndicatorBuffer(shortVolume, Bars, ShiftedBars, EMPTY_VALUE);
   }


   // (1) calculate start bar
   int changedBars = ChangedBars;
   if (Max.Values >= 0) /*&&*/ if (changedBars > Max.Values)
      changedBars = Max.Values;
   int startBar = changedBars-1;


   // (2) recalculate invalid bars
   for (int bar=startBar; bar >= 0; bar--) {
      longVolume [bar] = GetBonkersVolume(bar, Bonkers.MODE_VOLUME_LONG);
      shortVolume[bar] = GetBonkersVolume(bar, Bonkers.MODE_VOLUME_SHORT);
  }
   return(catch("onTick(3)"));
}


/**
 * Return a "BFX Core Volume" value.
 *
 * @param  int bar    - bar index of the value to return
 * @param  int buffer - buffer index of the value to return
 *
 * @return double - indicator value or NULL in case of errors
 */
double GetBonkersVolume(int bar, int buffer) {
   if (bar < 0)                                                               return(!catch("GetBonkersVolume(1)  invalid parameter bar: "+ bar, ERR_INVALID_PARAMETER));
   if (buffer!=Bonkers.MODE_VOLUME_LONG && buffer!=Bonkers.MODE_VOLUME_SHORT) return(!catch("GetBonkersVolume(2)  invalid parameter buffer: "+ buffer, ERR_INVALID_PARAMETER));

   static string license; if (!StringLen(license)) {
      string section = "bankersfx.com", key = "CoreVolumes.License";
      license = GetConfigString(section, key);
      if (!StringLen(license))                                                return(!catch("GetBonkersVolume(3)  missing configuration value ["+ section +"]->"+ key, ERR_INVALID_CONFIG_PARAMVALUE));
   }

   string separator      = "•••••••••••••••••••••••••••••••••••";    // init() error if this is an empty string
   int    serverId       = 0;
   int    loginTries     = 1;                                        // minimum 1 (that's in fact tries, not retries)
   string symbolPrefix   = "";
   string symbolSuffix   = "";
   color  colorLong      = Red;
   color  colorShort     = Green;
   color  colorLevel     = Gray;
   int    histogramWidth = 2;
   bool   signalAlert    = false;
   bool   signalPopup    = false;
   bool   signalSound    = false;
   bool   signalMobile   = false;
   bool   signalEmail    = false;

   double value = iCustom(NULL, NULL, bonkersIndicator,
                          separator, license, serverId, loginTries, symbolPrefix, symbolSuffix, colorLong, colorShort, colorLevel, histogramWidth, signalAlert, signalPopup, signalSound, signalMobile, signalEmail,
                          buffer, bar);

   int error = GetLastError();
   if (error != NO_ERROR) return(!catch("GetBonkersVolume(4)", error));

   return(value);
}


/**
 * Set indicator styles. Workaround for various terminal bugs when setting styles. Usually styles are applied in init().
 * However after recompilation styles must be applied in start() to not get lost.
 */
void SetIndicatorStyles() {
   SetIndexStyle(MODE_VOLUME_LONG,  DRAW_HISTOGRAM, EMPTY, Histogram.Style.Width, Histogram.Color.Long );
   SetIndexStyle(MODE_VOLUME_SHORT, DRAW_HISTOGRAM, EMPTY, Histogram.Style.Width, Histogram.Color.Short);
}


/**
 * Return a string representation of the input parameters. Used when logging iCustom() calls.
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("input: ",

                            "Histogram.Color.Long=",  ColorToStr(Histogram.Color.Long),  "; ",
                            "Histogram.Color.Short=", ColorToStr(Histogram.Color.Short), "; ",
                            "Histogram.Style.Width=", Histogram.Style.Width,             "; ",

                            "Max.Values=",            Max.Values,                        "; ")
   );
}

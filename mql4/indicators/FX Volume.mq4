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


   // (2) indicator buffer management
   IndicatorBuffers(2);
   SetIndexBuffer(MODE_VOLUME_LONG,  longVolume );    // long volume values:  visible, displayed in "Data" window
   SetIndexBuffer(MODE_VOLUME_SHORT, shortVolume);    // short volume values: visible, displayed in "Data" window

   return(catch("onInit(4)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   // check for finished buffer initialization (may be needed on terminal start)
   if (!ArraySize(longVolume))
      return(debug("onTick(1)  size(longVolume) = 0", SetLastError(ERS_TERMINAL_NOT_YET_READY)));

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
      if (false) {
         double longVolume  = GetBonkersVolume(bar, Bonkers.MODE_VOLUME_LONG);
         double shortVolume = GetBonkersVolume(bar, Bonkers.MODE_VOLUME_SHORT);
      }
   }

   return(catch("onTick(1)"));
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
   if (bar < 0) return(!catch("GetBonkersVolume(1)  invalid parameter bar: "+ bar, ERR_INVALID_PARAMETER));
   if (buffer!=Bonkers.MODE_VOLUME_LONG) /*&&*/ if (buffer!=Bonkers.MODE_VOLUME_SHORT)
      return(!catch("GetBonkersVolume(2)  invalid parameter buffer: "+ buffer, ERR_INVALID_PARAMETER));

   string bfx.title    = "•••••••••••••••••••••••••••••••••••";
   string bfx.user     = GetConfigString("bankersfx.com", "CoreVolumes.License");
   int    bfx.server   = 0;
   int    bfx.retries  = 5;
   string bfx.prefix   = "";
   string bfx.suffix   = "";
   color  bfx.positive = Lime;
   color  bfx.negative = Red;
   color  bfx.level    = Green;
   int    bfx.barWidth = 2;
   bool   bfx.alerts   = false;
   bool   bfx.popup    = false;
   bool   bfx.sound    = false;
   bool   bfx.mobile   = false;
   bool   bfx.email    = false;

   double value = iCustom(NULL, NULL, "BFX Core Volumes",
                          bfx.title, bfx.user, bfx.server, bfx.retries, bfx.prefix, bfx.suffix, bfx.positive, bfx.negative, bfx.level, bfx.barWidth, bfx.alerts, bfx.popup, bfx.sound, bfx.mobile, bfx.email,
                          buffer, bar);

   int error = GetLastError();
   if (!error)
      return(value);
   return(!catch("GetBonkersVolume(3)", error));
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
 * Return a string representation of the input parameters (logging).
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

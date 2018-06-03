/**
 *
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlibs.mqh>


/**
 * Main function
 *
 * @return int - error status
 */
int onStart() {
   string separator      = "•••••••••••••••••••••••••••••••••••";                   // indicator init() error if empty string
   string UserID         = GetConfigString("bankersfx.com", "CoreVolumes.License");
   int    ServerURL      = 0;
   int    loginTries     = 1;                                                       // minimum 1 (in fact tries, not retries)
   string Prefix         = "";
   string Suffix         = "";
   color  PositiveState  = Lime;
   color  NegativeState  = Red;
   color  Level          = Green;
   int    WidthStateBars = 2;
   bool   Alerts         = false;
   bool   PopUp          = false;
   bool   Sound          = false;
   bool   Mobile         = false;
   bool   Email          = false;

   int iBuffer = 0;
   int bars    = 10;

   double longVolume, shortVolume, signalLevel;

   for (int bar=0; bar < bars; bar++) {
      longVolume  = iCustom(NULL, NULL, "BFX Core Volumes",
                            separator, UserID, ServerURL, loginTries, Prefix, Suffix, PositiveState, NegativeState, Level, WidthStateBars, Alerts,
                            Bonkers.MODE_VOLUME_LONG, bar);

      shortVolume = iCustom(NULL, NULL, "BFX Core Volumes",
                            separator, UserID, ServerURL, loginTries, Prefix, Suffix, PositiveState, NegativeState, Level, WidthStateBars, Alerts,
                            Bonkers.MODE_VOLUME_SHORT, bar);

      signalLevel = iCustom(NULL, NULL, "BFX Core Volumes",
                            separator, UserID, ServerURL, loginTries, Prefix, Suffix, PositiveState, NegativeState, Level, WidthStateBars, Alerts,
                            Bonkers.MODE_VOLUME_LEVEL, bar);

      debug("onStart()  BFXVolume["+ bar +"]: "+ ifString(IsEmptyValue(longVolume),  "          -", StringPadLeft(longVolume,  11))
                                         +" / "+ ifString(IsEmptyValue(shortVolume), "-          ", StringPadLeft(shortVolume, 11))
                                         +" / "+ ifString(EQ(signalLevel, _int(signalLevel)), _int(signalLevel), signalLevel));
   }

   return(catch("onStart(1)"));
}

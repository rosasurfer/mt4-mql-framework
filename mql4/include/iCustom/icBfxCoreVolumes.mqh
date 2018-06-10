/**
 * Load the BankersFX "Core Volumes" indicator and return an indicator value.
 *
 * @param  int timeframe - timeframe to load the indicator (NULL: the current timeframe)
 * @param  int iBuffer   - buffer index of the value to return
 * @param  int iBar      - bar index of the value to return
 *
 * @return double - Indicator value or NULL in case of errors. Short volumes are returned as negative values.
 */
double icBfxCoreVolumes(int timeframe, int iBuffer, int iBar) {
   if (iBar < 0) return(!catch("icBfxCoreVolumes(1)  invalid parameter iBar: "+ iBar, ERR_INVALID_PARAMETER));

   string separator      = "•••••••••••••••••••••••••••••••••••";    // indicator init() error if an empty string
   int    serverId       = 0;
   int    loginTries     = 1;                                        // minimum is 1 (in fact tries, not retries)
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

   // check indicator existence
   static string indicatorName; if (!StringLen(indicatorName)) {
      string mqlDir = ifString(GetTerminalBuild()<=509, "\\experts", "\\mql4");
      string name = "BFX Core Volumes";
      string indicatorFile = TerminalPath() + mqlDir +"\\indicators\\"+ name +".ex4";
      if (!IsFile(indicatorFile)) return(catch("icBfxCoreVolumes(2)  BankersFX indicator not found: "+ DoubleQuoteStr(indicatorFile), ERR_FILE_NOT_FOUND));
      indicatorName = name;
   }

   // check license key existence
   static string indicatorLicense; if (!StringLen(indicatorLicense)) {
      string section = "bankersfx.com", key = "CoreVolumes.License";
      indicatorLicense = GetConfigString(section, key);
      if (!StringLen(indicatorLicense)) return(!catch("icBfxCoreVolumes(3)  missing configuration value ["+ section +"]->"+ key, ERR_INVALID_CONFIG_PARAMVALUE));
   }
   int error;

   // check indicator initialization with signal level on bar 0
   static bool indicatorInitialized = false; if (!indicatorInitialized) {
      double level = iCustom(NULL, timeframe, indicatorName,
                             separator, indicatorLicense, serverId, loginTries, symbolPrefix, symbolSuffix, colorLong, colorShort, colorLevel, histogramWidth, signalAlert, signalPopup, signalSound, signalMobile, signalEmail,
                             BankersFX.MODE_SIGNAL_LEVEL, 0);
      if (level == EMPTY_VALUE) {
         error = GetLastError();
         return(!catch("icBfxCoreVolumes(4)  initialization of indicator "+ DoubleQuoteStr(indicatorName) +" failed", ifInt(error, error, ERR_CUSTOM_INDICATOR_ERROR)));
      }
      indicatorInitialized = true;
   }

   // get the requested value
   double value = iCustom(NULL, timeframe, indicatorName,
                          separator, indicatorLicense, serverId, loginTries, symbolPrefix, symbolSuffix, colorLong, colorShort, colorLevel, histogramWidth, signalAlert, signalPopup, signalSound, signalMobile, signalEmail,
                          iBuffer, iBar);

   if (iBuffer == BankersFX.MODE_VOLUME_SHORT) {
      if (value != EMPTY_VALUE)
         value = -value;                              // convert short volumes to negaive values
   }

   error = GetLastError();
   if (error != NO_ERROR)
      return(!catch("icBfxCoreVolumes(5)", error));
   return(value);
}

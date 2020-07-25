/**
 * SuperBars
 *
 * Draws bars of higher timeframes on the chart. The currently active timeframe can be changed via chart commands sent by the
 * two accompanying scripts "SuperBars.TimeframeUp" and "SuperBars.TimeframeDown" (should be called with keyboard hotkeys).
 */
#include <stddefines.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string _1_________________________ = "Without values settings are read from the config.";

extern color  Color.BarUp                 = CLR_NONE;          // up bars (bullish)
extern color  Color.BarDown               = CLR_NONE;          // down bars (bearish)
extern color  Color.BarUnchanged          = CLR_NONE;          // unchanged bars
extern color  Color.ETH                   = CLR_NONE;          // ETH session
extern color  Color.CloseMarker           = CLR_NONE;          // bar close marker
extern string _2_________________________ = "";

extern string ETH.Symbols                 = "";                // symbols with ETH/RTH separation

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iChangedBars.mqh>
#include <functions/iPreviousPeriodTimes.mqh>
#include <win32api.mqh>

#property indicator_chart_window


int    superBars.timeframe;                                    // the currently active superbar period
bool   eth.enabled;                                            // whether 24 hours are split into ETH/RTH
string label.description = "PeriodDescription";


#define STF_UP             1
#define STF_DOWN          -1
#define PERIOD_D1_ETH   1439                                   // that's PERIOD_D1 - 1


/**
 * Initialization
 *
 * @return int - error status
 */
int onInit() {
   // (1) validate inputs
   // Colors: after deserialization the terminal might turn CLR_NONE (0xFFFFFFFF) into Black (0xFF000000)
   if (Color.BarUp        == 0xFF000000) Color.BarUp        = CLR_NONE;
   if (Color.BarDown      == 0xFF000000) Color.BarDown      = CLR_NONE;
   if (Color.BarUnchanged == 0xFF000000) Color.BarUnchanged = CLR_NONE;
   if (Color.ETH          == 0xFF000000) Color.ETH          = CLR_NONE;
   if (Color.CloseMarker  == 0xFF000000) Color.CloseMarker  = CLR_NONE;

   if (Color.BarUp        == CLR_NONE) Color.BarUp        = GetConfigColor("SuperBars", "Color.BarUp"       );
   if (Color.BarDown      == CLR_NONE) Color.BarDown      = GetConfigColor("SuperBars", "Color.BarDown"     );
   if (Color.BarUnchanged == CLR_NONE) Color.BarUnchanged = GetConfigColor("SuperBars", "Color.BarUnchanged");
   if (Color.ETH          == CLR_NONE) Color.ETH          = GetConfigColor("SuperBars", "Color.ETH"         );
   if (Color.CloseMarker  == CLR_NONE) Color.CloseMarker  = GetConfigColor("SuperBars", "Color.CloseMarker" );

   // ETH.Symbols
   string symbols = StrTrim(ETH.Symbols);
   if (!StringLen(symbols)) symbols = GetGlobalConfigString("SuperBars", "ETH.Symbols");
   if (StringLen(symbols) > 0) {
      string sValues[];
      int size = Explode(StrToLower(symbols), ",", sValues, NULL);
      for (int i=0; i < size; i++) {
         sValues[i] = StrTrim(sValues[i]);
      }
      eth.enabled = StringInArray(sValues, StrToLower(StdSymbol()));
   }


   // (2) display configuration, names, labels
   SetIndexLabel(0, NULL);                                     // disable "Data" window display
   CreateDescriptionLabel();                                   // create label for superbar period description


   // (3) restore and validate stored runtime values
   if (!RestoreRuntimeStatus()) return(last_error);
   CheckSuperTimeframeAvailability();
   return(catch("onInit(1)"));
}


/**
 * Deinitialization
 *
 * @return int - error status
 */
int onDeinit() {
   DeleteRegisteredObjects();
   if (!StoreRuntimeStatus())                                  // store runtime status in all deinit scenarios
      return(last_error);
   return(catch("onDeinit(1)"));
}


/**
 * Main function
 *
 * @return int - error status
 */
int onTick() {
   HandleCommands();                                           // process chart commands
   UpdateSuperBars();                                          // update superbars
   return(last_error);
}


/**
 * Handle incoming commands.
 *
 * @param  string commands[] - received external commands
 *
 * @return bool - success status
 */
bool onCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onCommand(1)  empty parameter commands = {}"));

   for (int i=0; i < size; i++) {
      if      (commands[i] == "Timeframe=Up"  ) { if (!SwitchSuperTimeframe(STF_UP  )) return(false); }
      else if (commands[i] == "Timeframe=Down") { if (!SwitchSuperTimeframe(STF_DOWN)) return(false); }
      else warn("onCommand(2)  unknown command \""+ commands[i] +"\"");
   }
   return(!catch("onCommand(3)"));
}


/**
 * Change the currently active superbars period.
 *
 * @param  int direction - direction to change: STF_UP | STF_DOWN
 *
 * @return bool - success status
 */
bool SwitchSuperTimeframe(int direction) {
   bool reset = false;

   if (direction == STF_DOWN) {
      switch (superBars.timeframe) {
         case  INT_MIN      : PlaySoundEx("Plonk.wav");          break;    // we hit a wall

         case  PERIOD_H1    :
         case -PERIOD_H1    : superBars.timeframe =  INT_MIN;    break;

         case  PERIOD_D1_ETH: superBars.timeframe =  PERIOD_H1;  break;
         case -PERIOD_D1_ETH: superBars.timeframe = -PERIOD_H1;  break;

         case  PERIOD_D1    : superBars.timeframe =  ifInt(eth.enabled, PERIOD_D1_ETH, PERIOD_H1); break;
         case -PERIOD_D1    : superBars.timeframe = -ifInt(eth.enabled, PERIOD_D1_ETH, PERIOD_H1); break;

         case  PERIOD_W1    : superBars.timeframe =  PERIOD_D1;  break;
         case -PERIOD_W1    : superBars.timeframe = -PERIOD_D1;  break;

         case  PERIOD_MN1   : superBars.timeframe =  PERIOD_W1;  break;
         case -PERIOD_MN1   : superBars.timeframe = -PERIOD_W1;  break;

         case  PERIOD_Q1    : superBars.timeframe =  PERIOD_MN1; break;
         case -PERIOD_Q1    : superBars.timeframe = -PERIOD_MN1; break;

         case  INT_MAX      : superBars.timeframe =  PERIOD_Q1;  break;
      }
   }
   else if (direction == STF_UP) {
      switch (superBars.timeframe) {
         case  INT_MIN      : superBars.timeframe =  PERIOD_H1;  break;

         case  PERIOD_H1    : superBars.timeframe =  ifInt(eth.enabled, PERIOD_D1_ETH, PERIOD_D1); break;
         case -PERIOD_H1    : superBars.timeframe = -ifInt(eth.enabled, PERIOD_D1_ETH, PERIOD_D1); break;

         case  PERIOD_D1_ETH: superBars.timeframe =  PERIOD_D1;  break;
         case -PERIOD_D1_ETH: superBars.timeframe = -PERIOD_D1;  break;

         case  PERIOD_D1    : superBars.timeframe =  PERIOD_W1;  break;
         case -PERIOD_D1    : superBars.timeframe = -PERIOD_W1;  break;

         case  PERIOD_W1    : superBars.timeframe =  PERIOD_MN1; break;
         case -PERIOD_W1    : superBars.timeframe = -PERIOD_MN1; break;

         case  PERIOD_MN1   : superBars.timeframe =  PERIOD_Q1;  break;
         case -PERIOD_MN1   : superBars.timeframe = -PERIOD_Q1;  break;

         case  PERIOD_Q1    : superBars.timeframe =  INT_MAX;    break;

         case  INT_MAX      : PlaySoundEx("Plonk.wav");          break;    // we hit a wall
      }
   }
   else warn("SwitchSuperTimeframe(1)  unknown parameter direction = "+ direction);

   CheckSuperTimeframeAvailability();                                      // check availability of the new setting
   return(true);
}


/**
 * Whether the selected superbar period can be displayed on the current chart. For example a superbar period of PERIOD_H1
 * can't be displayed on a chart of PERIOD_H4. If the superbar period can't be displayed superbars are disabled for that
 * chart period.
 *
 * @return bool - success status
 */
bool CheckSuperTimeframeAvailability() {

   // check timeframes
   switch (superBars.timeframe) {
      // off: to be activated manually only
      case  INT_MIN      :
      case  INT_MAX      : break;

      // positive value = active: automatically deactivated if display on the current doesn't make sense
      case  PERIOD_H1    : if (Period() >  PERIOD_M15) superBars.timeframe *= -1; break;
      case  PERIOD_D1_ETH:
         if (!eth.enabled) superBars.timeframe = PERIOD_D1;
      case  PERIOD_D1    : if (Period() >  PERIOD_H4 ) superBars.timeframe *= -1; break;
      case  PERIOD_W1    : if (Period() >  PERIOD_D1 ) superBars.timeframe *= -1; break;
      case  PERIOD_MN1   : if (Period() >  PERIOD_D1 ) superBars.timeframe *= -1; break;
      case  PERIOD_Q1    : if (Period() >  PERIOD_W1 ) superBars.timeframe *= -1; break;

      // negative value = inactive: automatically activated if display on the current chart makes sense
      case -PERIOD_H1    : if (Period() <= PERIOD_M15) superBars.timeframe *= -1; break;
      case -PERIOD_D1_ETH:
         if (!eth.enabled) superBars.timeframe = -PERIOD_H1;
      case -PERIOD_D1    : if (Period() <= PERIOD_H4 ) superBars.timeframe *= -1; break;
      case -PERIOD_W1    : if (Period() <= PERIOD_D1 ) superBars.timeframe *= -1; break;
      case -PERIOD_MN1   : if (Period() <= PERIOD_D1 ) superBars.timeframe *= -1; break;
      case -PERIOD_Q1    : if (Period() <= PERIOD_W1 ) superBars.timeframe *= -1; break;

      // not initialized or invalid value: reset to default value
      default:
         switch (Period()) {
            case PERIOD_M1 :
            case PERIOD_M5 :
            case PERIOD_M15:
            case PERIOD_M30:
            case PERIOD_H1 : superBars.timeframe =  PERIOD_D1;  break;
            case PERIOD_H4 : superBars.timeframe =  PERIOD_W1;  break;
            case PERIOD_D1 : superBars.timeframe =  PERIOD_MN1; break;
            case PERIOD_W1 :
            case PERIOD_MN1: superBars.timeframe = -PERIOD_MN1; break;
         }
   }
   return(true);
}


/**
 * Update the superbars display.
 *
 * @return bool - success status
 */
bool UpdateSuperBars() {
   // (1) on superbars period change delete superbars of the previously active display
   static int static.lastTimeframe;
   bool timeframeChanged = (superBars.timeframe != static.lastTimeframe);  // for simplicity interpret the first comparison (lastTimeframe==0) as a change, too

   if (timeframeChanged) {
      if (PERIOD_M1 <= static.lastTimeframe) /*&&*/ if (static.lastTimeframe <= PERIOD_Q1) {
         DeleteRegisteredObjects();                                        // in all other cases previous suberbars are already deleted
         CreateDescriptionLabel();
      }
      UpdateDescription();
   }


   // (2) limit the amount of superbars to draw (performance)
   int maxBars = INT_MAX;
   switch (superBars.timeframe) {
      // immediate return if deactivated
      case  INT_MIN      :                                                 // manually deactivated
      case  INT_MAX      :
      case -PERIOD_H1    :                                                 // automatically deactivated
      case -PERIOD_D1_ETH:
      case -PERIOD_D1    :
      case -PERIOD_W1    :
      case -PERIOD_MN1   :
      case -PERIOD_Q1    : static.lastTimeframe = superBars.timeframe;
                           return(true);

      // limit amount of superbars to draw                                 // TODO: make this configurable
      case  PERIOD_H1    : maxBars = 60 * DAYS/HOURS; break;               // maximum 60 days
      case  PERIOD_D1_ETH:
      case  PERIOD_D1    :
      case  PERIOD_W1    :
      case  PERIOD_MN1   :
      case  PERIOD_Q1    : break;                                          // no limit for everything else
   }


   // (3) Sollen Extended-Hours angezeigt werden, muß der Bereich von ChangedBars immer auch iChangedBars(PERIOD_M15) einschließen
   int  changedBars=ChangedBars, superTimeframe=superBars.timeframe;
   bool drawETH;
   if (timeframeChanged)
      changedBars = Bars;                                                  // bei Superbar-Timeframe-Wechsel müssen alle Bars neugezeichnet werden

   if (eth.enabled) /*&&*/ if (superBars.timeframe==PERIOD_D1_ETH) {
      superTimeframe = PERIOD_D1;

      // TODO: Wenn timeframeChanged=TRUE läßt sich der gesamte folgende Block sparen, es gilt immer: changedBars = Bars
      //       Allerdings müssen dann in DrawSuperBar() nochmal ERS_HISTORY_UPDATE und ERR_SERIES_NOT_AVAILABLE behandelt werden.

      int changedBars.M15 = iChangedBars(NULL, PERIOD_M15);
      if (changedBars.M15 == -1) return(false);

      if (changedBars.M15 > 0) {
         datetime lastBarTime.M15 = iTime(NULL, PERIOD_M15, changedBars.M15-1);

         if (Time[changedBars-1] > lastBarTime.M15) {
            int bar = iBarShiftPrevious(NULL, NULL, lastBarTime.M15); if (bar == EMPTY_VALUE) return(false);
            if (bar == -1) changedBars = Bars;                             // M15-Zeitpunkt ist zu alt für den aktuellen Chart
            else           changedBars = bar + 1;
         }
         drawETH = true;
      }
   }


   // (4) Superbars aktualisieren
   //   - Zeichenbereich ist der Bereich von ChangedBars (jedoch keine for-Schleife über alle ChangedBars).
   //   - Die jüngste Superbar reicht nach rechts nur bis Bar[0], was Fortschritt und Relevanz der wachsenden Superbar veranschaulicht.
   //   - Die älteste Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (zur Laufzeit Normalfall).
   //   - "Session" meint in der Folge keine 24-h-Session, sondern eine Periode des jeweiligen Super-Timeframes.
   //
   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int      openBar, closeBar, lastChartBar=Bars-1;

   // Schleife über alle Superbars von jung nach alt
   for (int i=0; i < maxBars; i++) {
      if (!iPreviousPeriodTimes(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(false);

      // Ab Chartperiode PERIOD_D1 wird der Bar-Timestamp vom Broker nur noch in vollen Tagen gesetzt und der Timezone-Offset kann einen Monatsbeginn
      // fälschlicherweise in den vorherigen oder nächsten Monat setzen. Dies muß nur in der Woche, nicht jedoch am Wochenende korrigiert werden.
      if (Period()==PERIOD_D1) /*&&*/ if (superTimeframe >= PERIOD_MN1) {
         if (openTime.srv  < openTime.fxt ) /*&&*/ if (TimeDayOfWeekEx(openTime.srv )!=SUNDAY  ) openTime.srv  = openTime.fxt;      // Sonntagsbar: Server-Timezone westlich von FXT
         if (closeTime.srv > closeTime.fxt) /*&&*/ if (TimeDayOfWeekEx(closeTime.srv)!=SATURDAY) closeTime.srv = closeTime.fxt;     // Samstagsbar: Server-Timezone östlich von FXT
      }

      openBar  = iBarShiftNext    (NULL, NULL, openTime.srv);           if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1)                                                  // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              { if (!DrawSuperBar(openBar, closeBar, openTime.fxt, openTime.srv, drawETH)) return(false); }
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) { if (!DrawSuperBar(openBar, closeBar, openTime.fxt, openTime.srv, drawETH)) return(false); }
      }                                                                    // Die Supersession auf der letzten Chartbar ist selten genau vollständig, trotzdem mit (exact=TRUE) prüfen.
      else {
         i--;                                                              // keine Bars für diese Supersession vorhanden
      }
      if (openBar >= changedBars-1)
         break;                                                            // Superbars bis max. changedBars aktualisieren
   }

   static.lastTimeframe = superBars.timeframe;
   return(true);
}


/**
 * Zeichnet eine einzelne Superbar.
 *
 * @param  int      openBar      - Chartoffset der Open-Bar der Superbar
 * @param  int      closeBar     - Chartoffset der Close-Bar der Superbar
 * @param  datetime openTime.fxt - FXT-Startzeit der Supersession
 * @param  datetime openTime.srv - Server-Startzeit der Supersession
 * @param  bool    &drawETH      - Variable, die anzeigt, ob die ETH-Session der D1-Superbar gezeichnet werden kann. Sind alle verfügbaren
 *                                 M15-Daten verarbeitet, wechselt diese Variable auf OFF, auch wenn noch weitere D1-Superbars gezeichnet werden.
 * @return bool - Erfolgsstatus
 */
bool DrawSuperBar(int openBar, int closeBar, datetime openTime.fxt, datetime openTime.srv, bool &drawETH) {
   // (1.1) High- und Low-Bar ermitteln
   int highBar = iHighest(NULL, NULL, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, NULL, MODE_LOW , openBar-closeBar+1, closeBar);

   // (1.2) Farbe bestimmen
   color barColor = Color.BarUnchanged;
   if (openBar < Bars-1) double openPrice = Close[openBar+1];                          // Als OpenPrice wird nach Möglichkeit das Close der vorherigen Bar verwendet.
   else                         openPrice = Open [openBar];
   double ratio = openPrice/Close[closeBar]; if (ratio < 1) ratio = 1/ratio;
   if (ratio > 1.0005) {                                                               // Ab ca. 5-10 pip Preisunterschied werden Color.BarUp bzw. Color.BarDown verwendet.
      if      (openPrice < Close[closeBar]) barColor = Color.BarUp;
      else if (openPrice > Close[closeBar]) barColor = Color.BarDown;
   }

   // (1.3) Label definieren
   string label;
   switch (superBars.timeframe) {
      case PERIOD_H1    : label =          GmtTimeFormat(openTime.fxt, "%d.%m.%Y %H:%M");                    break;
      case PERIOD_D1_ETH:
      case PERIOD_D1    : label =          GmtTimeFormat(openTime.fxt, "%a %d.%m.%Y ");                      break;  // "aaa dd.mm.YYYY" wird bereits vom Grid verwendet
      case PERIOD_W1    : label = "Week "+ GmtTimeFormat(openTime.fxt,    "%d.%m.%Y");                       break;
      case PERIOD_MN1   : label =          GmtTimeFormat(openTime.fxt,       "%B %Y");                       break;
      case PERIOD_Q1    : label = ((TimeMonth(openTime.fxt)-1)/3+1) +". Quarter "+ TimeYearEx(openTime.fxt); break;
   }

   // (1.4) Superbar zeichnen
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
      int closeBar_j = closeBar; /*j: justified*/                                      // Rechtecke um eine Chartbar nach rechts verbreitern, damit sie sich gegenseitig berühren.
      if (closeBar > 0) closeBar_j--;                                                  // jedoch nicht bei der jüngsten Bar[0]
   if (ObjectCreate (label, OBJ_RECTANGLE, 0, Time[openBar], High[highBar], Time[closeBar_j], Low[lowBar])) {
      ObjectSet     (label, OBJPROP_COLOR, barColor);
      ObjectSet     (label, OBJPROP_BACK , true    );
      RegisterObject(label);
   }
   else GetLastError();

   // (1.5) Close-Marker zeichnen
   if (closeBar > 0) {                                                                 // jedoch nicht bei der jüngsten Bar[0], die Session ist noch nicht beendet
      int centerBar = (openBar+closeBar)/2;                                            // TODO: nach Market-Close Marker auch bei der jüngsten Session zeichnen

      if (centerBar > closeBar) {
         string labelWithPrice, labelWithoutPrice=label +" Close";

         if (ObjectFind(labelWithoutPrice) == 0) {                                     // Jeder Marker besteht aus zwei Objekten: Ein unsichtbares Label (erstes Objekt) mit
            labelWithPrice = ObjectDescription(labelWithoutPrice);                     // festem Namen, das in der Beschreibung den veränderlichen Namen des sichtbaren Markers
            if (ObjectFind(labelWithPrice) == 0)                                       // (zweites Objekt) enthält. So kann ein bereits vorhandener Marker einer Superbar im
               ObjectDelete(labelWithPrice);                                           // Chart gefunden und durch einen neuen ersetzt werden, obwohl sich sein dynamischer Name
            ObjectDelete(labelWithoutPrice);                                           // geändert hat.
         }
         labelWithPrice = labelWithoutPrice +" "+ NumberToStr(Close[closeBar], PriceFormat);

         if (ObjectCreate (labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet     (labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText (labelWithoutPrice, labelWithPrice);
            RegisterObject(labelWithoutPrice);
         } else GetLastError();

         if (ObjectCreate (labelWithPrice, OBJ_TREND, 0, Time[centerBar], Close[closeBar], Time[closeBar], Close[closeBar])) {
            ObjectSet     (labelWithPrice, OBJPROP_RAY  , false);
            ObjectSet     (labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet     (labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
            ObjectSet     (labelWithPrice, OBJPROP_BACK , true);
            RegisterObject(labelWithPrice);
         } else GetLastError();
      }
   }


   // (2) Extended-Hours markieren (falls M15-Daten vorhanden)
   while (drawETH) {                                                                   // die Schleife ersetzt ein if() und dient nur dem einfacheren Verlassen des Blocks
      // (2.1) High und Low ermitteln
      datetime eth.openTime.srv  = openTime.srv;                                       // wie reguläre Starttime der 24h-Session (00:00 FXT)
      datetime eth.closeTime.srv = openTime.srv + 16*HOURS + 30*MINUTES;               // Handelsbeginn Globex Chicago           (16:30 FXT)

      int eth.openBar  = openBar;                                                      // reguläre OpenBar der 24h-Session
      int eth.closeBar = iBarShiftPrevious(NULL, NULL, eth.closeTime.srv-1*SECOND);    // openBar ist hier immer >= closeBar (Prüfung oben)
         if (eth.closeBar == EMPTY_VALUE) return(false);
         if (eth.openBar <= eth.closeBar) break;                                       // Abbruch, wenn openBar nicht größer als closeBar (kein Platz zum Zeichnen)

      int eth.M15.openBar = iBarShiftNext(NULL, PERIOD_M15, eth.openTime.srv);
         if (eth.M15.openBar == EMPTY_VALUE) return(false);
         if (eth.M15.openBar == -1)          break;                                    // Daten sind noch nicht da (HISTORY_UPDATE sollte laufen)

      int eth.M15.closeBar = iBarShiftPrevious(NULL, PERIOD_M15, eth.closeTime.srv-1*SECOND);
         if (eth.M15.closeBar == EMPTY_VALUE)    return(false);
         if (eth.M15.closeBar == -1) { drawETH = false; break; }                       // die vorhandenen Daten reichen nicht soweit zurück, Abbruch aller weiteren ETH's
         if (eth.M15.openBar < eth.M15.closeBar) break;                                // die vorhandenen Daten weisen eine Lücke auf

      int eth.M15.highBar = iHighest(NULL, PERIOD_M15, MODE_HIGH, eth.M15.openBar-eth.M15.closeBar+1, eth.M15.closeBar);
      int eth.M15.lowBar  = iLowest (NULL, PERIOD_M15, MODE_LOW , eth.M15.openBar-eth.M15.closeBar+1, eth.M15.closeBar);

      double eth.open     = iOpen (NULL, PERIOD_M15, eth.M15.openBar );
      double eth.high     = iHigh (NULL, PERIOD_M15, eth.M15.highBar );
      double eth.low      = iLow  (NULL, PERIOD_M15, eth.M15.lowBar  );
      double eth.close    = iClose(NULL, PERIOD_M15, eth.M15.closeBar);

      // (2.2) Label definieren
      string eth.label    = label +" ETH";
      string eth.bg.label = label +" ETH background";

      // (2.3) ETH-Background zeichnen (erzeugt ein optisches Loch in der Superbar)
      if (ObjectFind(eth.bg.label) == 0)
         ObjectDelete(eth.bg.label);
      if (ObjectCreate(eth.bg.label, OBJ_RECTANGLE, 0, Time[eth.openBar], eth.high, Time[eth.closeBar], eth.low)) {
         ObjectSet     (eth.bg.label, OBJPROP_COLOR, barColor);                        // NOTE: Die Farben sich überlappender Shape-Bereiche werden mit der Charthintergrundfarbe
         ObjectSet     (eth.bg.label, OBJPROP_BACK , true);                            //       gemäß gdi32::SetROP2(HDC hdc, R2_NOTXORPEN) gemischt (siehe Beispiel am Funktionsende).
         RegisterObject(eth.bg.label);                                                 //       Da wir die Charthintergrundfarbe im Moment noch nicht ermitteln können, benutzen wir
      }                                                                                //       einen Trick: Eine Farbe mit sich selbst gemischt ergibt immer Weiß, Weiß mit einer
                                                                                       //       anderen Farbe gemischt ergibt wieder die andere Farbe.
      // (2.4) ETH-Bar zeichnen (füllt das Loch mit der ETH-Farbe)                     //       Damit erzeugen wir ein "Loch" in der Farbe des Charthintergrunds in der Superbar.
      if (ObjectFind(eth.label) == 0)                                                  //       In dieses Loch zeichnen wir die ETH-Bar. Ihre Farbe wird NICHT mit der Farbe des "Lochs"
         ObjectDelete(eth.label);                                                      //       gemischt (warum auch immer), vermutlich setzt das Terminal einen anderen Drawing-Mode.
      if (ObjectCreate(eth.label, OBJ_RECTANGLE, 0, Time[eth.openBar], eth.high, Time[eth.closeBar], eth.low)) {
         ObjectSet     (eth.label, OBJPROP_COLOR, Color.ETH);
         ObjectSet     (eth.label, OBJPROP_BACK , true     );
         RegisterObject(eth.label);
      }

      // (2.5) ETH-Rahmen zeichnen

      // (2.6) ETH-Close-Marker zeichnen, wenn die Extended-Hours beendet sind
      if (TimeServer() >= eth.closeTime.srv) {
         int eth.centerBar = (eth.openBar+eth.closeBar)/2;

         if (eth.centerBar > eth.closeBar) {
            string eth.labelWithPrice, eth.labelWithoutPrice=eth.label +" Close";

            if (ObjectFind(eth.labelWithoutPrice) == 0) {                              // Jeder Marker besteht aus zwei Objekten: Ein unsichtbares Label (erstes Objekt) mit
               eth.labelWithPrice = ObjectDescription(eth.labelWithoutPrice);          // festem Namen, das in der Beschreibung den veränderlichen Namen des sichtbaren Markers
               if (ObjectFind(eth.labelWithPrice) == 0)                                // (zweites Objekt) enthält. So kann ein bereits vorhandener Marker einer ETH-Bar im
                  ObjectDelete(eth.labelWithPrice);                                    // Chart gefunden und durch einen neuen ersetzt werden, obwohl sich sein dynamischer Name
               ObjectDelete(eth.labelWithoutPrice);                                    // geändert hat.
            }
            eth.labelWithPrice = eth.labelWithoutPrice +" "+ NumberToStr(eth.close, PriceFormat);

            if (ObjectCreate(eth.labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
               ObjectSet    (eth.labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
               ObjectSetText(eth.labelWithoutPrice, eth.labelWithPrice);
               RegisterObject(eth.labelWithoutPrice);
            } else GetLastError();

            if (ObjectCreate(eth.labelWithPrice, OBJ_TREND, 0, Time[eth.centerBar], eth.close, Time[eth.closeBar], eth.close)) {
               ObjectSet    (eth.labelWithPrice, OBJPROP_RAY  , false);
               ObjectSet    (eth.labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSet    (eth.labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
               ObjectSet    (eth.labelWithPrice, OBJPROP_BACK , true);
               RegisterObject(eth.labelWithPrice);
            } else GetLastError();
         }
      }
      break;
   }
   /*
   Beispiel zum Mischen von Farben gemäß gdi32::SetROP2(HDC hdc, R2_NOTXORPEN):
   ----------------------------------------------------------------------------
   Welche Farbe muß ein Shape haben, damit es nach dem Mischen mit der Chartfarbe {248,248,248} und einem rosa-farbenen Shape {255,213,213} grün {0,255,0} erscheint?

      Chart R: 11111000  G: 11111000  B: 11111000 = rgb(248,248,248)
    + Rosa     11111111     11010101     11010101 = rgb(255,213,213)
      -------------------------------------------
      NOT-XOR: 11111000     11010010     11010010 = chart + rosa        NOT-XOR: Bit wird gesetzt, wenn die Bits in OP1 und OP2 gleich sind.
    +          00000111     11010010     00101101 = rgb(7,210,45)    -> Farbe, die gemischt mit dem Zwischenergebnis (chart + rosa) die gewünschte Farbe ergibt.
      ===========================================
      NOT-XOR: 00000000     11111111     00000000 = rgb(0,255,0) = grün

   Die für das Shape zu verwendende Farbe ist rgb(7,210,45).
   */
   return(!catch("DrawSuperBar(2)"));
}


/**
 * Aktualisiert die Superbar-Textanzeige.
 *
 * @return bool - Ergebnis
 */
bool UpdateDescription() {
   string description;

   switch (superBars.timeframe) {
      case  PERIOD_M1    : description = "Superbars: 1 Minute";         break;
      case  PERIOD_M5    : description = "Superbars: 5 Minutes";        break;
      case  PERIOD_M15   : description = "Superbars: 15 Minutes";       break;
      case  PERIOD_M30   : description = "Superbars: 30 Minutes";       break;
      case  PERIOD_H1    : description = "Superbars: 1 Hour";           break;
      case  PERIOD_H4    : description = "Superbars: 4 Hours";          break;
      case  PERIOD_D1    : description = "Superbars: Days";             break;
      case  PERIOD_D1_ETH: description = "Superbars: Days + ETH";       break;
      case  PERIOD_W1    : description = "Superbars: Weeks";            break;
      case  PERIOD_MN1   : description = "Superbars: Months";           break;
      case  PERIOD_Q1    : description = "Superbars: Quarters";         break;

      case -PERIOD_M1    : description = "Superbars: 1 Minute (n/a)";   break;
      case -PERIOD_M5    : description = "Superbars: 5 Minutes (n/a)";  break;
      case -PERIOD_M15   : description = "Superbars: 15 Minutes (n/a)"; break;
      case -PERIOD_M30   : description = "Superbars: 30 Minutes (n/a)"; break;
      case -PERIOD_H1    : description = "Superbars: 1 Hour (n/a)";     break;
      case -PERIOD_H4    : description = "Superbars: 4 Hours (n/a)";    break;
      case -PERIOD_D1    : description = "Superbars: Days (n/a)";       break;
      case -PERIOD_D1_ETH: description = "Superbars: Days + ETH (n/a)"; break;
      case -PERIOD_W1    : description = "Superbars: Weeks (n/a)";      break;
      case -PERIOD_MN1   : description = "Superbars: Months (n/a)";     break;
      case -PERIOD_Q1    : description = "Superbars: Quarters (n/a)";   break;

      case  INT_MIN:
      case  INT_MAX:       description = "Superbars: off";              break;   // manuell abgeschaltet

      default:             description = "Superbars: n/a";                       // automatisch abgeschaltet
   }
   //sRange = StringConcatenate(sRange, "   O: ", NumberToStr(Open[openBar], PriceFormat), "   H: ", NumberToStr(High[highBar], PriceFormat), "   L: ", NumberToStr(Low[lowBar], PriceFormat));
   string label    = __NAME() +"."+ label.description;
   string fontName = "";
   int    fontSize = 8;                                                          // "MS Sans Serif"-8 entspricht in allen Builds der Menüschrift
   ObjectSetText(label, description, fontSize, fontName, Black);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)              // on Object::onDrag() or opened "Properties" dialog
      return(!catch("UpdateDescription(1)", error));
   return(true);
}


/**
 * Erzeugt das Textlabel für die Superbars-Beschreibung.
 *
 * @return int - Fehlerstatus
 */
int CreateDescriptionLabel() {
   string label = __NAME() +"."+ label.description;

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 280);
      ObjectSet    (label, OBJPROP_YDISTANCE,   4);
      ObjectSetText(label, " ", 1);
      RegisterObject(label);
   }

   return(catch("CreateDescriptionLabel(1)"));
}


/**
 * Speichert die SuperBars-Konfiguration im Chartfenster (für Init-Cycle und Laden eines neuen Templates) und im Chart selbst (für Restart
 * des Terminals).
 *
 * @return bool - Erfolgsstatus
 */
bool StoreRuntimeStatus() {
   // Die Konfiguration wird nur gespeichert, wenn sie gültig ist.
   if (!superBars.timeframe)
      return(true);

   // Konfiguration im Chartfenster speichern
   int hWnd = __ExecutionContext[EC.hChart];
   SetWindowIntegerA(hWnd, "rsf.SuperBars.Timeframe", superBars.timeframe);   // TODO: Schlüssel muß global verwaltet werden und Instanz-ID des Indikators enthalten

   // Konfiguration im Chart speichern                                        // TODO: nur bei Terminal-Shutdown
   string label = __NAME() +".runtime.timeframe";
   string value = superBars.timeframe;                                        // (string) int
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, value);

   return(catch("StoreRuntimeStatus(1)"));
}


/**
 * Restauriert die SuperBars-Konfiguration aus dem Chartfenster oder dem Chart.
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreRuntimeStatus() {
   // Konfiguration im Chartfenster suchen
   int hWnd   = __ExecutionContext[EC.hChart];
   int result = RemoveWindowIntegerA(hWnd, "rsf.SuperBars.Timeframe");        // TODO: Schlüssel muß global verwaltet werden und Instanz-ID des Indikators enthalten

   if (!result) {
      // Konfiguration im Chart suchen
      string label = __NAME() +".runtime.timeframe";
      if (ObjectFind(label) == 0) {
         string value = ObjectDescription(label);
         if (StrIsInteger(value))
            result = StrToInteger(value);
         ObjectDelete(label);
      }
   }

   if (result != 0) {
      superBars.timeframe = result;
      //debug("RestoreRuntimeStatus(1)  restored superBars.timeframe: "+ superBars.timeframe);
   }
   return(!catch("RestoreRuntimeStatus(2)"));
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Color.BarUp=",        ColorToStr(Color.BarUp),        ";", NL,
                            "Color.BarDown=",      ColorToStr(Color.BarDown),      ";", NL,
                            "Color.BarUnchanged=", ColorToStr(Color.BarUnchanged), ";", NL,
                            "Color.ETH=",          ColorToStr(Color.ETH),          ";", NL,
                            "Color.CloseMarker=",  ColorToStr(Color.CloseMarker),  ";")
   );
}

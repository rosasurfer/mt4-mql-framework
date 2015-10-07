/**
 * Hinterlegt den Chart mit Bars übergeordneter Timeframes. Die Änderung des Timeframes erfolgt per Hotkey.
 */
#property indicator_chart_window

#include <stddefine.mqh>
int   __INIT_FLAGS__[] = {INIT_TIMEZONE};
int __DEINIT_FLAGS__[];

////////////////////////////////////////////////////////////////////////////////// Konfiguration ////////////////////////////////////////////////////////////////////////////////////

extern color Color.BarUp        = C'193,255,193';                    // Up-Bars
extern color Color.BarDown      = C'255,213,213';                    // Down-Bars
extern color Color.BarUnchanged = C'232,232,232';                    // nahezu unveränderte Bars
extern color Color.ETH          = C'255,255,176';                    // Extended-Hours
extern color Color.CloseMarker  = C'164,164,164';                    // Close-Marker

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <win32api.mqh>

#include <iFunctions/iBarShiftNext.mqh>
#include <iFunctions/iBarShiftPrevious.mqh>
#include <iFunctions/iChangedBars.mqh>
#include <iFunctions/iPreviousPeriodTimes.mqh>


int    superBars.timeframe;
bool   eth.likeFuture;                                               // ob die Handelssession des Instruments nach RTH und ETH getrennt werden kann (wie Globex-Derivate)
bool   showOHLData;                                                  // ob die aktuellen OHL-Daten angezeigt werden sollen

string label.description = "Description";                            // Label für Chartanzeige


#define STF_UP             1
#define STF_DOWN          -1
#define PERIOD_D1_ETH   1439                                         // PERIOD_D1 - 1


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   // (1) Parametervalidierung
   // Colors
   if (Color.BarUp        == 0xFF000000) Color.BarUp       = CLR_NONE;  // aus CLR_NONE = 0xFFFFFFFF macht das Terminal nach Recompilation oder Deserialisierung
   if (Color.BarDown      == 0xFF000000) Color.BarDown     = CLR_NONE;  // u.U. 0xFF000000 (entspricht Schwarz)
   if (Color.BarUnchanged == 0xFF000000) Color.BarDown     = CLR_NONE;
   if (Color.ETH          == 0xFF000000) Color.ETH         = CLR_NONE;
   if (Color.CloseMarker  == 0xFF000000) Color.CloseMarker = CLR_NONE;

   // (2) ETH/Future-Status ermitteln
   string futures[] = {
      "BRENT"  , "WTI"    ,
      "DJIA"   , "DJTA"   ,
      "NAS100" , "NASCOMP",
      "RUS2000",
      "SP500"  ,
      "EURX"   , "USDX"   ,
    //"AUDLFX" , "CADLFX" , "CHFLFX", "EURLFX", "GBPLFX", "LFXJPY", "NZDLFX", "USDLFX",   // ERROR: EURLFX,M1  SuperBars::TimeCurrentFix(1)->TimeCurrent() => 0  [ERR_RUNTIME_ERROR]
      "XAGEUR" , "XAGJPY" , "XAGUSD",
      "XAUEUR" , "XAUJPY" , "XAUUSD"
   };
   eth.likeFuture = StringInArray(futures, StdSymbol());

   // (3) Label für Superbar-Beschreibung erzeugen
   CreateDescriptionLabel();

   // (4) Status restaurieren
   if (!RestoreWindowStatus())
      return(last_error);

   // (5) Verfügbarkeit des eingestellten Superbar-Timeframes prüfen bzw. Default festlegen
   CheckSuperTimeframeAvailability();

   SetIndexLabel(0, NULL);                                              // Datenanzeige ausschalten
   return(catch("onInit(1)"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   DeleteRegisteredObjects(NULL);

   // in allen deinit()-Szenarien Fensterstatus  speichern
   if (!StoreWindowStatus())
      return(last_error);
   return(catch("onDeinit(1)"));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   HandleEvent(EVENT_CHART_CMD);                                     // ChartCommands verarbeiten
   UpdateSuperBars();                                                // Superbars aktualisieren
   return(last_error);
}


/**
 * Handler für ChartCommands.
 *
 * @param  string commands[] - die eingetroffenen Commands
 *
 * @return bool - Erfolgsstatus
 */
bool onChartCommand(string commands[]) {
   int size = ArraySize(commands);
   if (!size) return(!warn("onChartCommand(1)  empty parameter commands = {}"));

   for (int i=0; i < size; i++) {
      if      (commands[i] == "Timeframe=Up"  ) { if (!SwitchSuperTimeframe(STF_UP  )) return(false); }
      else if (commands[i] == "Timeframe=Down") { if (!SwitchSuperTimeframe(STF_DOWN)) return(false); }
      else
         warn("onChartCommand(2)  unknown chart command \""+ commands[i] +"\"");
   }
   return(!catch("onChartCommand(3)"));
}


/**
 * Schaltet den Parameter superBars.timeframe des Indikators um.
 *
 * @param  int direction - Richtungs-ID: STF_UP|STF_DOWN
 *
 * @return bool - Erfolgsstatus
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

         case  PERIOD_D1    : superBars.timeframe =  ifInt(eth.likeFuture, PERIOD_D1_ETH, PERIOD_H1); break;
         case -PERIOD_D1    : superBars.timeframe = -ifInt(eth.likeFuture, PERIOD_D1_ETH, PERIOD_H1); break;

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

         case  PERIOD_H1    : superBars.timeframe =  ifInt(eth.likeFuture, PERIOD_D1_ETH, PERIOD_D1); break;
         case -PERIOD_H1    : superBars.timeframe = -ifInt(eth.likeFuture, PERIOD_D1_ETH, PERIOD_D1); break;

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

   CheckSuperTimeframeAvailability();                                      // Verfügbarkeit der Einstellung prüfen
   return(true);
}


/**
 * Prüft, ob der gewählte Superbar-Timeframe in der aktuellen Chartperiode angezeigt werden kann und
 * aktiviert/deaktiviert ihn entsprechend.
 *
 * @return bool - Erfolgsstatus
 */
bool CheckSuperTimeframeAvailability() {

   // Timeframes prüfen und ggf. aktivieren/deaktivieren
   switch (superBars.timeframe) {
      // off: kann nur manuell aktiviert werden
      case  INT_MIN      :
      case  INT_MAX      : break;

      // aktiviert: wird automatisch deaktiviert, wenn Anzeige in aktueller Chartperiode unsinnig ist
      case  PERIOD_H1    : if (Period() >  PERIOD_M15) superBars.timeframe *= -1; break;
      case  PERIOD_D1_ETH:
      case  PERIOD_D1    : if (Period() >  PERIOD_H1 ) superBars.timeframe *= -1; break;
      case  PERIOD_W1    : if (Period() >  PERIOD_D1 ) superBars.timeframe *= -1; break;
      case  PERIOD_MN1   : if (Period() >  PERIOD_D1 ) superBars.timeframe *= -1; break;
      case  PERIOD_Q1    : if (Period() >  PERIOD_W1 ) superBars.timeframe *= -1; break;

      // deaktiviert: wird automatisch aktiviert, wenn Anzeige in aktueller Chartperiode Sinn macht
      case -PERIOD_H1    : if (Period() <= PERIOD_M15) superBars.timeframe *= -1; break;
      case -PERIOD_D1_ETH:
      case -PERIOD_D1    : if (Period() <= PERIOD_H1 ) superBars.timeframe *= -1; break;
      case -PERIOD_W1    : if (Period() <= PERIOD_D1 ) superBars.timeframe *= -1; break;
      case -PERIOD_MN1   : if (Period() <= PERIOD_D1 ) superBars.timeframe *= -1; break;
      case -PERIOD_Q1    : if (Period() <= PERIOD_W1 ) superBars.timeframe *= -1; break;

      // nicht initialisierter bzw. ungültiger Timeframe: Default festlegen
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
 * Aktualisiert die Superbar-Anzeige.
 *
 * @return bool - Erfolgsstatus
 */
bool UpdateSuperBars() {
   // (1) bei Superbar-Timeframe-Wechsel vorm Aktualisieren die vorhandenen Superbars löschen
   static int static.lastTimeframe;
   bool timeframeChanged = (superBars.timeframe != static.lastTimeframe);  // der erste Aufruf (lastTimeframe==0) wird auch als Wechsel interpretiert

   if (timeframeChanged) {
      if (PERIOD_M1 <= static.lastTimeframe) /*&&*/ if (static.lastTimeframe <= PERIOD_Q1) {
         DeleteRegisteredObjects(NULL);                                    // in allen anderen Fällen wurden vorhandene Superbars bereits vorher gelöscht
         CreateDescriptionLabel();
      }
      UpdateDescription();
   }


   // (2) bei deaktivierten Superbars sofortige Rückkehr, bei aktivierten Superbars zu zeichnende Anzahl ggf. begrenzen
   int maxBars = INT_MAX;
   switch (superBars.timeframe) {
      case  INT_MIN      :                                                 // manuell abgeschaltet
      case  INT_MAX      :
      case -PERIOD_H1    :                                                 // automatisch abgeschaltet
      case -PERIOD_D1_ETH:
      case -PERIOD_D1    :
      case -PERIOD_W1    :
      case -PERIOD_MN1   :
      case -PERIOD_Q1    : static.lastTimeframe = superBars.timeframe;
                           return(true);

      case  PERIOD_H1    : maxBars = 30 * DAYS/HOURS; break;               // bei PERIOD_H1 maximal 30 Tage
      case  PERIOD_D1_ETH:
      case  PERIOD_D1    :
      case  PERIOD_W1    :
      case  PERIOD_MN1   :
      case  PERIOD_Q1    : break;                                          // alle anderen ohne Begrenzung
   }


   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int      openBar, closeBar, lastChartBar=Bars-1, changedBars=ChangedBars, superTimeframe=superBars.timeframe;
   bool     drawETH;
   if (timeframeChanged)
      changedBars = Bars;                                                  // bei Superbar-Timeframe-Wechsel müssen alle Bars neugezeichnet werden


   // (3) Sollen Extended-Hours angezeigt werden, muß der Bereich von ChangedBars immer auch iChangedBars(PERIOD_M15) einschließen
   if (eth.likeFuture) /*&&*/ if (superBars.timeframe==PERIOD_D1_ETH) {
      superTimeframe = PERIOD_D1;

      // TODO: Wenn timeframeChanged=TRUE läßt sich der gesamte folgende Block sparen, es gilt immer: changedBars = Bars
      //       Allerdings müssen dann in DrawSuperBar() nochmal ERS_HISTORY_UPDATE und ERR_SERIES_NOT_AVAILABLE behandelt werden.

      int oldError        = last_error;
      int changedBars.M15 = iChangedBars(NULL, PERIOD_M15, MUTE_ERR_SERIES_NOT_AVAILABLE);
      if (changedBars.M15 == -1) {
         if (last_error != ERR_SERIES_NOT_AVAILABLE) return(false);
         SetLastError(oldError);                                           // ERR_SERIES_NOT_AVAILABLE unterdrücken
      }

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
   //   - Zeichenbereich bei jedem Tick ist der Bereich von ChangedBars (jedoch keine for-Schleife über alle ChangedBars).
   //   - Die jüngste Superbar reicht nach rechts nur bis Bar[0], was Fortschritt und Relevanz der wachsenden Superbar veranschaulicht.
   //   - Die älteste Superbar reicht nach links über ChangedBars hinaus, wenn Bars > ChangedBars (zur Laufzeit Normalfall).
   //   - Mit "Session" ist in der Folge keine 24-h-Session, sondern eine Periode des jeweiligen Super-Timeframes gemeint,
   //     z.B. ein Tag, eine Woche oder ein Monat.
   //
   // Schleife über alle Superbars von "jung" nach "alt"
   for (int i=maxBars; i > 0; i--) {
      if (!iPreviousPeriodTimes(superTimeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))
         return(false);

      // Ab Chartperiode PERIOD_D1 wird der Bar-Timestamp vom Broker nur noch in vollen Tagen gesetzt und der Timezone-Offset kann einen Monatsbeginn
      // fälschlicherweise in den vorherigen oder nächsten Monat setzen. Dies muß nur in der Woche, nicht jedoch am Wochenende korrigiert werden.
      if (Period()==PERIOD_D1) /*&&*/ if (superTimeframe>=PERIOD_MN1) {
         if (openTime.srv  < openTime.fxt ) /*&&*/ if (TimeDayOfWeekFix(openTime.srv )!=SUNDAY  ) openTime.srv  = openTime.fxt;  // Sonntagsbar: Server-Timezone westlich von FXT
         if (closeTime.srv > closeTime.fxt) /*&&*/ if (TimeDayOfWeekFix(closeTime.srv)!=SATURDAY) closeTime.srv = closeTime.fxt; // Samstagsbar: Server-Timezone östlich von FXT
      }

      openBar  = iBarShiftNext    (NULL, NULL, openTime.srv);           if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, NULL, closeTime.srv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1)                                                  // closeTime ist zu alt für den Chart => Abbruch
         break;

      if (openBar >= closeBar) {
         if      (openBar != lastChartBar)                              { if (!DrawSuperBar(openBar, closeBar, openTime.fxt, openTime.srv, drawETH)) return(false); }
         else if (openBar == iBarShift(NULL, NULL, openTime.srv, true)) { if (!DrawSuperBar(openBar, closeBar, openTime.fxt, openTime.srv, drawETH)) return(false); }
      }                                                                    // Die Supersession auf der letzten Chartbar ist selten genau vollständig, trotzdem mit (exact=TRUE) prüfen.
      if (openBar >= changedBars-1)
         break;                                                            // Superbars bis max. changedBars aktualisieren
   }


   // (5) OHL-Anzeige aktualisieren (falls zutreffend)
   if (showOHLData)
      UpdateDescription();

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
 * @param  bool    &drawETH      - Variable, die anzeigt, ob die ETH-Session der aktuellen D1-Superbar gezeichnet werden kann. Sind alle verfügbaren
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
   if (MathMax(openPrice,  Close[closeBar])/MathMin(openPrice, Close[closeBar]) > 1.0005) {
      if      (openPrice < Close[closeBar]) barColor = Color.BarUp;                    // Ab ca. 5-10 pip Preisunterschied werden Color.BarUp bzw. Color.BarDown verwendet.
      else if (openPrice > Close[closeBar]) barColor = Color.BarDown;
   }

   // (1.3) Label definieren
   string label;
   switch (superBars.timeframe) {
      case PERIOD_H1    : label =          DateToStr(openTime.fxt, "D.M.Y H:I");                              break;
      case PERIOD_D1_ETH:
      case PERIOD_D1    : label =          DateToStr(openTime.fxt, "w D.M.Y ");                               break; // "w D.M.Y" wird bereits vom Grid verwendet
      case PERIOD_W1    : label = "Week "+ DateToStr(openTime.fxt,   "D.M.Y" );                               break;
      case PERIOD_MN1   : label =          DateToStr(openTime.fxt,     "N Y" );                               break;
      case PERIOD_Q1    : label = ((TimeMonth(openTime.fxt)-1)/3+1) +". Quarter "+ TimeYearFix(openTime.fxt); break;
   }

   // (1.4) Superbar zeichnen
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
      int closeBar_j = closeBar; /*j: justified*/                                      // Rechtecke um eine Chartbar nach rechts verbreitern, damit sie sich gegenseitig berühren.
      if (closeBar > 0) closeBar_j--;                                                  // jedoch nicht bei der jüngsten Bar[0]
   if (ObjectCreate (label, OBJ_RECTANGLE, 0, Time[openBar], High[highBar], Time[closeBar_j], Low[lowBar])) {
      ObjectSet     (label, OBJPROP_COLOR, barColor);
      ObjectSet     (label, OBJPROP_BACK , true    );
      ObjectRegister(label);
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
         labelWithPrice = labelWithoutPrice +" "+ DoubleToStr(Close[closeBar], PipDigits);

         if (ObjectCreate (labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
            ObjectSet     (labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
            ObjectSetText (labelWithoutPrice, labelWithPrice);
            ObjectRegister(labelWithoutPrice);
         } else GetLastError();

         if (ObjectCreate (labelWithPrice, OBJ_TREND, 0, Time[centerBar], Close[closeBar], Time[closeBar], Close[closeBar])) {
            ObjectSet     (labelWithPrice, OBJPROP_RAY  , false);
            ObjectSet     (labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSet     (labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
            ObjectSet     (labelWithPrice, OBJPROP_BACK , true);
            ObjectRegister(labelWithPrice);
         } else GetLastError();
      }
   }


   // (2) Extended-Hours markieren (falls M15-Daten vorhanden)
   while (drawETH) {                                                                   // die Schleife dient nur dem einfacheren Verlassen des ETH-Blocks
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
         ObjectRegister(eth.bg.label);                                                 //       Da wir die Charthintergrundfarbe im Moment noch nicht ermitteln können, benutzen wir
      }                                                                                //       einen Trick: Eine Farbe mit sich selbst gemischt ergibt immer Weiß, Weiß mit einer
                                                                                       //       anderen Farbe gemischt ergibt wieder die andere Farbe.
      // (2.4) ETH-Bar zeichnen (füllt das Loch mit der ETH-Farbe)                     //       Damit erzeugen wir ein "Loch" in der Farbe des Charthintergrunds in der Superbar.
      if (ObjectFind(eth.label) == 0)                                                  //       In dieses Loch zeichnen wir die ETH-Bar. Ihre Farbe wird NICHT mit der Farbe des "Lochs"
         ObjectDelete(eth.label);                                                      //       gemischt (warum auch immer), vermutlich setzt das Terminal einen anderen Drawing-Mode.
      if (ObjectCreate(eth.label, OBJ_RECTANGLE, 0, Time[eth.openBar], eth.high, Time[eth.closeBar], eth.low)) {
         ObjectSet     (eth.label, OBJPROP_COLOR, Color.ETH);
         ObjectSet     (eth.label, OBJPROP_BACK , true     );
         ObjectRegister(eth.label);
      }

      // (2.5) ETH-Rahmen zeichnen

      // (2.6) ETH-Close-Marker zeichnen, wenn die Extended-Hours beendet sind
      if (TimeCurrentFix() > eth.closeTime.srv) {
         int eth.centerBar = (eth.openBar+eth.closeBar)/2;

         if (eth.centerBar > eth.closeBar) {
            string eth.labelWithPrice, eth.labelWithoutPrice=eth.label +" Close";

            if (ObjectFind(eth.labelWithoutPrice) == 0) {                              // Jeder Marker besteht aus zwei Objekten: Ein unsichtbares Label (erstes Objekt) mit
               eth.labelWithPrice = ObjectDescription(eth.labelWithoutPrice);          // festem Namen, das in der Beschreibung den veränderlichen Namen des sichtbaren Markers
               if (ObjectFind(eth.labelWithPrice) == 0)                                // (zweites Objekt) enthält. So kann ein bereits vorhandener Marker einer ETH-Bar im
                  ObjectDelete(eth.labelWithPrice);                                    // Chart gefunden und durch einen neuen ersetzt werden, obwohl sich sein dynamischer Name
               ObjectDelete(eth.labelWithoutPrice);                                    // geändert hat.
            }
            eth.labelWithPrice = eth.labelWithoutPrice +" "+ DoubleToStr(eth.close, PipDigits);

            if (ObjectCreate(eth.labelWithoutPrice, OBJ_LABEL, 0, 0, 0)) {
               ObjectSet    (eth.labelWithoutPrice, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
               ObjectSetText(eth.labelWithoutPrice, eth.labelWithPrice);
               ObjectRegister(eth.labelWithoutPrice);
            } else GetLastError();

            if (ObjectCreate(eth.labelWithPrice, OBJ_TREND, 0, Time[eth.centerBar], eth.close, Time[eth.closeBar], eth.close)) {
               ObjectSet    (eth.labelWithPrice, OBJPROP_RAY  , false);
               ObjectSet    (eth.labelWithPrice, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSet    (eth.labelWithPrice, OBJPROP_COLOR, Color.CloseMarker);
               ObjectSet    (eth.labelWithPrice, OBJPROP_BACK , true);
               ObjectRegister(eth.labelWithPrice);
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
   return(!catch("DrawSuperBar(3)"));
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
   string label    = __NAME__ +"."+ label.description;
   string fontName = "";
   int    fontSize = 8;                                                          // "MS Sans Serif"-8 entspricht in allen Builds der Menüschrift
   ObjectSetText(label, description, fontSize, fontName, Black);

   int error = GetLastError();
   if (IsError(error)) /*&&*/ if (error!=ERR_OBJECT_DOES_NOT_EXIST)              // bei offenem Properties-Dialog oder Object::onDrag()
      return(!catch("UpdateDescription(1)", error));
   return(true);
}


/**
 * Erzeugt das Textlabel für die Superbars-Beschreibung.
 *
 * @return int - Fehlerstatus
 */
int CreateDescriptionLabel() {
   string label = __NAME__ +"."+ label.description;

   if (ObjectFind(label) == 0)
      ObjectDelete(label);

   if (ObjectCreate(label, OBJ_LABEL, 0, 0, 0)) {
      ObjectSet    (label, OBJPROP_CORNER, CORNER_TOP_LEFT);
      ObjectSet    (label, OBJPROP_XDISTANCE, 183);                  // min. Distance für Platzierung neben One-Click-Trading-Widget ist 180
      ObjectSet    (label, OBJPROP_YDISTANCE, 4  );
      ObjectSetText(label, " ", 1);
      ObjectRegister(label);
   }

   return(catch("CreateDescriptionLabel(1)"));
}


/**
 * Speichert die Fenster-relevanten Konfigurationsdaten im Chart und in der lokalen Terminalkonfiguration.
 * Dadurch gehen sie auch beim Laden eines neuen Chart-Templates nicht verloren.
 *
 * @return bool - Erfolgsstatus
 */
bool StoreWindowStatus() {
   // Die Konfiguration wird nur gespeichert, wenn sie gültig ist.
   if (!superBars.timeframe)
      return(true);

   // Konfiguration im Chart speichern
   string label = __NAME__ +".sticky.timeframe";
   string value = superBars.timeframe;                               // (string) int
   if (ObjectFind(label) == 0)
      ObjectDelete(label);
   ObjectCreate (label, OBJ_LABEL, 0, 0, 0);
   ObjectSet    (label, OBJPROP_TIMEFRAMES, OBJ_PERIODS_NONE);
   ObjectSetText(label, value);

   // Konfiguration in Terminalkonfiguration speichern
   string file    = GetLocalConfigPath();
   string section = "WindowStatus";
      int hWnd    = WindowHandleEx(NULL); if (!hWnd) return(false);
   string key     = "SuperBars.Timeframe.0x"+ IntToHexStr(hWnd);
   if (!WritePrivateProfileStringA(section, key, value, file)) return(!catch("StoreWindowStatus(1)->kernel32::WritePrivateProfileStringA(section=\""+ section +"\", key=\""+ key +"\", value=\""+ value +"\", fileName=\""+ file +"\")", ERR_WIN32_ERROR));

   return(catch("StoreWindowStatus(2)"));
}


/**
 * Restauriert die Fenster-relevanten Konfigurationsdaten aus dem Chart oder der Terminalkonfiguration.
 *
 *  - Superbar-Timeframe
 *
 * @return bool - Erfolgsstatus
 */
bool RestoreWindowStatus() {
   bool success = false;
   int  timeframe;

   // Versuchen, die Konfiguration aus dem Chart zu restaurieren (ist dort nach Laden eines neuen Templates nicht vorhanden).
   string label = __NAME__ +".sticky.timeframe", empty="";
   if (ObjectFind(label) == 0) {
      string sValue = ObjectDescription(label);
      success       = StringIsInteger(sValue);
      timeframe     = StrToInteger(sValue);
   }

   // Bei Mißerfolg Konfiguration aus der Terminalkonfiguration restaurieren.
   if (!success) {
      int    hWnd    = WindowHandleEx(NULL); if (!hWnd) return(false);
      string section = "WindowStatus";
      string key     = "SuperBars.Timeframe.0x"+ IntToHexStr(hWnd);
      sValue         = GetLocalConfigString(section, key, "");
      success        = StringIsInteger(sValue);
      timeframe      = StrToInteger(sValue);
   }

   if (success)
      superBars.timeframe = timeframe;
   return(!catch("RestoreWindowStatus(1)"));
}

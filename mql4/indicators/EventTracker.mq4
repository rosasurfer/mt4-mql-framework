/**
 * EventTracker für verschiedene Ereignisse. Kann akustisch, optisch per SMS und per E-Mail benachrichtigen.
 * Die Art der Benachrichtigung kann konfiguriert werden.
 *
 *
 * (1) Order-Events (Trading)
 *     Ein aktiver OrderEvent-Tracker überwacht alle Symbole eines Accounts, nicht nur das des aktuellen Charts. Es liegt in
 *     der Verantwortung des Benutzers, nur einen aller laufenden EventTracker für die Orderüberwachung zu aktivieren.
 *     Folgende Events werden überwacht:
 *
 *      • eine Limit-Order wurde getriggert und als Folge eine Position geöffnet
 *      • eine Limit-Order wurde getriggert und als Folge eine Position geschlossen
 *      • eine Limit-Order wurde getriggert, es erfolgte jedoch keine Ausführung
 *      • das Stopout-Limit des Brokers wurde getriggert und als Folge eine Position geschlossen
 *
 *
 * (2) Preis-Events (Signale)
 *     Ein aktiver PreisEvent-Tracker überwacht die in der Account-Konfiguration konfigurierten Signale des Instruments des
 *     aktuellen Charts. Es liegt in der Verantwortung des Benutzers, nur einen EventTracker je Instrument für Preis-Events
 *     zu aktivieren. Folgende Events können überwacht werden:
 *
 *     Konfiguration: {Lookback}.{Signal}               = {value}       ; notwendig (Aktivierung)
 *                    {Lookback}.{Signal}[.{Parameter}] = {value}       ; optional je nach Signal-Typ
 *
 *      • Lookback:   {This|Last|Integer}[-]{Timeframe}
 *                    This                                              ; Synonym für 0-{Timeframe}-Ago
 *                    Last                                              ; Synonym für 1-{Timeframe}-Ago
 *                    Today                                             ; Synonym für 0-Days-Ago
 *                    Yesterday                                         ; Synonym für 1-Day-Ago
 *
 *      • Signale:    BarClose            = {Boolean}                   ; Erreichen des Close-Preises einer Bar
 *
 *                    BarRange            = [{Number}%|{Boolean}]       ; Erreichen der prozentualen Range einer Bar (On = 100% = neues High/Low)
 *                    BarRange.OnTouch    = {Boolean}                   ; TODO: ob das Signal bereits bei Erreichen der Grenzen ausgelöst wird
 *                    BarRange.ResetAfter = {Integer}[-]{Time[frame]}   ; TODO: Zeit, nachdem die Prüfung eines getriggerten Signals reaktiviert wird
 *
 *     - Unterschiede bei Groß-/Kleinschreibung und White-Space zwischen Werten und/oder Keywords werden ignoriert.
 *     - Singular und Plural eines Timeframe-Bezeichners sind austauschbar: Hour=Hours, Day=Days, Week=Weeks etc.
 *
 *
 * TODO:
 * -----
 *  - PositionOpen-/Close-Events während Timeframe- oder Symbolwechsel werden nicht erkannt
 *  - Candle-Pattern: neues Inside-Range-Pattern und Auflösung desselben auf Timeframe-Basis
 *  - bei Accountwechsel auftretende Fehler werden nicht abgefangen
 */
#include <stddefines.mqh>
int   __InitFlags[];
int __DeinitFlags[];

////////////////////////////////////////////////////// Configuration ////////////////////////////////////////////////////////

extern string Track.Orders         = "on | off | auto*";
extern string Track.Signals        = "on | off | auto*";

extern string __________________________;

extern string Signal.Sound         = "on | off | auto*";
extern string Signal.Mail.Receiver = "on | off | auto* | {email-address}";
extern string Signal.SMS.Receiver  = "on | off | auto* | {phone-number}";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include <core/indicator.mqh>
#include <stdfunctions.mqh>
#include <rsfLibs.mqh>
#include <functions/ConfigureSignalMail.mqh>
#include <functions/ConfigureSignalSMS.mqh>
#include <functions/ConfigureSignalSound.mqh>
#include <functions/iBarShiftNext.mqh>
#include <functions/iBarShiftPrevious.mqh>
#include <functions/iChangedBars.mqh>
#include <functions/iPreviousPeriodTimes.mqh>

#property indicator_chart_window


// Order-Events
bool   track.orders;
int    orders.knownOrders.ticket[];                                  // vom letzten Aufruf bekannte offene Orders
int    orders.knownOrders.type  [];
string orders.accountAlias;                                          // Verwendung in ausgehenden Messages

#define CLOSE_TYPE_TP               1                                // TakeProfit
#define CLOSE_TYPE_SL               2                                // StopLoss
#define CLOSE_TYPE_SO               3                                // StopOut (Margin-Call)


// Price-Events
bool   track.signals;
int    signal.config[][7];                                           // Konfiguration: Indizes @see SIGNAL_CONFIG_*
double signal.data  [][8];                                           // Laufzeitdaten: je nach Signal-Typ unterschiedlich, Indizes siehe *Signal.Init()
string signal.status[];                                              // Signalstatus:  aktuelle Textbeschreibung für Statusanzeige des Indikators

#define SIGNAL_BAR_CLOSE            1                                // Signaltypen
#define SIGNAL_BAR_RANGE            2

#define SIGNAL_CONFIG_ENABLED       0                                // Signal-Enabled:   int 0|1
#define SIGNAL_CONFIG_TYPE          1                                // Signal-Type:      int
#define SIGNAL_CONFIG_TIMEFRAME     2                                // Signal-Timeframe: int PERIOD_{xx}
#define SIGNAL_CONFIG_BAR           3                                // Signal-Bar:       int 0..x (lookback)
#define SIGNAL_CONFIG_PARAM1        4                                // Signal-Param1:    int ...
#define SIGNAL_CONFIG_PARAM2        5                                // Signal-Param2:    int ...
#define SIGNAL_CONFIG_PARAM3        6                                // Signal-Param3:    int ...

#define SIGNAL_UP                   0                                // Richtungen eines ausgelösten Signals
#define SIGNAL_DOWN                 1


// Arten der Benachrichtigung
bool   signal.sound;
string signal.sound.orderFailed      = "speech/OrderCancelled.wav";
string signal.sound.positionOpened   = "speech/OrderFilled.wav";
string signal.sound.positionClosed   = "speech/PositionClosed.wav";
string signal.sound.priceSignal_up   = "Signal-Up.wav";
string signal.sound.priceSignal_down = "Signal-Down.wav";

bool   signal.sms;
string signal.sms.receiver = "";
bool   signal.mail;
string signal.mail.sender   = "";
string signal.mail.receiver = "";


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   if (!Configure())                                                 // Konfiguration einlesen, ruft zum Schluß ShowStatus() auf
      return(last_error);

   SetIndexLabel(0, NULL);                                           // Datenanzeige ausschalten
   return(catch("onInit(1)"));
}


/**
 * Validiert und speichert die Konfiguration des EventTrackers.
 *
 * @return bool - Erfolgsstatus
 */
bool Configure() {
   int iValue, subKeysSize, sLen, signal, signal.bar, signal.timeframe, signal.param1, signal.param2, signal.param3, account = GetAccountNumber();
   if (!account) return(false);
   bool signal.enabled;
   double dValue, dValue1, dValue2, dValue3;
   string keys[], subKeys[], section, key, subKey, sDigits, sParam, iniValue, accountConfig = GetAccountConfigPath();
   if (!StringLen(accountConfig)) return(false);

   // Track.Orders
   track.orders = false;
   string sValue = StrToLower(Track.Orders), values[];         // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      int size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
      track.signals = true;
   }
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
      track.signals = false;
   }
   else if (sValue == "auto") {
      track.orders = GetConfigBool("EventTracker", "Track.Orders");
   }
   else return(!catch("Configure(1)  Invalid input parameter Track.Orders = \""+ Track.Orders +"\"", ERR_INVALID_INPUT_PARAMETER));

   if (track.orders) {
      section = "Accounts";
      key     = account +".alias";
      orders.accountAlias = GetConfigString(section, key);
      if (!StringLen(orders.accountAlias)) return(!catch("Configure(2)  Missing account configuration ["+ section +"]->"+ key, ERR_RUNTIME_ERROR));
   }

   // Track.Signals
   track.signals = false;
   sValue = StrToLower(Track.Signals);                         // default: "on | off | auto*"
   if (Explode(sValue, "*", values, 2) > 1) {
      size = Explode(values[0], "|", values, NULL);
      sValue = values[size-1];
   }
   sValue = StrTrim(sValue);

   if (sValue=="on" || sValue=="1" || sValue=="yes" || sValue=="true") {
      track.signals = true;
   }
   else if (sValue=="off" || sValue=="0" || sValue=="no" || sValue=="false") {
      track.signals = false;
   }
   else if (sValue == "auto") {
      track.signals = GetConfigBool("EventTracker", "Track.Signals");
   }
   else return(!catch("Configure(3)  Invalid input parameter Track.Signals = \""+ Track.Signals +"\"", ERR_INVALID_INPUT_PARAMETER));

   if (track.signals) {
      // (2.1) Signalkonfigurationen einlesen
      section = "EventTracker."+ StdSymbol();
      int keysSize = GetIniKeys(accountConfig, section, keys);

      for (int i=0; i < keysSize; i++) {
         // (2.2) Schlüssel zerlegen und parsen
         subKeysSize = Explode(StrToUpper(keys[i]), ".", subKeys, NULL);
         if (subKeysSize < 2 || subKeysSize > 3) return(!catch("Configure(4)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));

         // subKeys[0]: LookBack-Periode
         sValue = StrTrim(subKeys[0]);
         sLen   = StringLen(sValue); if (!sLen) return(!catch("Configure(5)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));

         if (sValue == "TODAY") {
            signal.bar       = 0;
            signal.timeframe = PERIOD_D1;
         }
         else if (sValue == "YESTERDAY") {
            signal.bar       = 1;
            signal.timeframe = PERIOD_D1;
         }
         else if (StrStartsWith(sValue, "THIS")) {
            signal.bar = 0;
            sValue     = StrTrim(StrSubstr(sValue, 4));

            if (StrStartsWith(sValue, "-")) sValue = StrTrim(StrSubstr(sValue, 1));       // ein "-" vorn abschneiden
            if (StrEndsWith  (sValue, "S")) sValue = StrTrim(StrLeft(sValue, -1));        // ein "s" hinten abschneiden

            if      (sValue == "MINUTE") signal.timeframe = PERIOD_M1;
            else if (sValue == "HOUR"  ) signal.timeframe = PERIOD_H1;
            else if (sValue == "DAY"   ) signal.timeframe = PERIOD_D1;
            else if (sValue == "WEEK"  ) signal.timeframe = PERIOD_W1;
            else if (sValue == "MONTH" ) signal.timeframe = PERIOD_MN1;
            else if (sValue == "M1"    ) signal.timeframe = PERIOD_M1;
            else if (sValue == "M5"    ) signal.timeframe = PERIOD_M5;
            else if (sValue == "M15"   ) signal.timeframe = PERIOD_M15;
            else if (sValue == "M30"   ) signal.timeframe = PERIOD_M30;
            else if (sValue == "H1"    ) signal.timeframe = PERIOD_H1;
            else if (sValue == "H4"    ) signal.timeframe = PERIOD_H4;
            else if (sValue == "D1"    ) signal.timeframe = PERIOD_D1;
            else if (sValue == "W1"    ) signal.timeframe = PERIOD_W1;
            else if (sValue == "MN1"   ) signal.timeframe = PERIOD_MN1;
            else return(!catch("Configure(6)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));
         }
         else if (StrStartsWith(sValue, "LAST")) {
            signal.bar = 1;
            sValue     = StrTrim(StrSubstr(sValue, 4));

            if (StrStartsWith(sValue, "-")) sValue = StrTrim(StrSubstr(sValue, 1));       // ein "-" vorn abschneiden
            if (StrEndsWith  (sValue, "S")) sValue = StrTrim(StrLeft (sValue, -1));       // ein "s" hinten abschneiden

            if      (sValue == "MINUTE") signal.timeframe = PERIOD_M1;
            else if (sValue == "HOUR"  ) signal.timeframe = PERIOD_H1;
            else if (sValue == "DAY"   ) signal.timeframe = PERIOD_D1;
            else if (sValue == "WEEK"  ) signal.timeframe = PERIOD_W1;
            else if (sValue == "MONTH" ) signal.timeframe = PERIOD_MN1;
            else if (sValue == "M1"    ) signal.timeframe = PERIOD_M1;
            else if (sValue == "M5"    ) signal.timeframe = PERIOD_M5;
            else if (sValue == "M15"   ) signal.timeframe = PERIOD_M15;
            else if (sValue == "M30"   ) signal.timeframe = PERIOD_M30;
            else if (sValue == "H1"    ) signal.timeframe = PERIOD_H1;
            else if (sValue == "H4"    ) signal.timeframe = PERIOD_H4;
            else if (sValue == "D1"    ) signal.timeframe = PERIOD_D1;
            else if (sValue == "W1"    ) signal.timeframe = PERIOD_W1;
            else if (sValue == "MN1"   ) signal.timeframe = PERIOD_MN1;
            else return(!catch("Configure(7)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));
         }
         else if (StrIsDigit(StrLeft(sValue, 1))) {                                             // z.B. "96-M15.BarRange"
            sDigits = StrLeft(sValue, 1);                                                       // Zahl vorn parsen
            for (int char, j=1; j < sLen; j++) {
               char = StringGetChar(sValue, j);
               if ('0'<=char && char<='9') sDigits = StrLeft(sValue, j+1);
               else                        break;
            }
            sValue     = StrTrim(StrSubstr(sValue, j));                                         // Zahl vorn abschneiden
            signal.bar = StrToInteger(sDigits);

            if (StrStartsWith(sValue, "-")) sValue = StrTrim(StrSubstr(sValue, 1));             // ein "-" vorn abschneiden
            if (StrEndsWith  (sValue, "S")) sValue = StrTrim(StrLeft (sValue, -1));             // ein "s" hinten abschneiden

            // Timeframe des Strings parsen
            if      (sValue == "MINUTE") signal.timeframe = PERIOD_M1;
            else if (sValue == "HOUR"  ) signal.timeframe = PERIOD_H1;
            else if (sValue == "DAY"   ) signal.timeframe = PERIOD_D1;
            else if (sValue == "WEEK"  ) signal.timeframe = PERIOD_W1;
            else if (sValue == "MONTH" ) signal.timeframe = PERIOD_MN1;
            else if (sValue == "M1"    ) signal.timeframe = PERIOD_M1;
            else if (sValue == "M5"    ) signal.timeframe = PERIOD_M5;
            else if (sValue == "M15"   ) signal.timeframe = PERIOD_M15;
            else if (sValue == "M30"   ) signal.timeframe = PERIOD_M30;
            else if (sValue == "H1"    ) signal.timeframe = PERIOD_H1;
            else if (sValue == "H4"    ) signal.timeframe = PERIOD_H4;
            else if (sValue == "D1"    ) signal.timeframe = PERIOD_D1;
            else if (sValue == "W1"    ) signal.timeframe = PERIOD_W1;
            else if (sValue == "MN1"   ) signal.timeframe = PERIOD_MN1;
            else return(!catch("Configure(8)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));
         }
         else return(!catch("Configure(9)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));

         // subKeys[1]: Signal-Typ
         subKey = StrTrim(subKeys[1]);
         if      (subKey == "BARCLOSE") signal = SIGNAL_BAR_CLOSE;
         else if (subKey == "BARRANGE") signal = SIGNAL_BAR_RANGE;
         else return(!catch("Configure(10)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));

         // subKeys[2]: zusätzlicher Parameter
         if (subKeysSize == 3) {
            sParam = StrTrim(subKeys[2]);
            sValue = GetIniStringA(accountConfig, section, keys[i], "");
            if (!Configure.SetParameter(signal, signal.timeframe, signal.bar, sParam, sValue))
               return(!catch("Configure(11)  invalid or unknown price signal ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));
            continue;
         }

         // (2.3) ini-Value parsen
         iniValue = GetIniStringA(accountConfig, section, keys[i], "");
         if (signal == SIGNAL_BAR_CLOSE) {
            signal.enabled = GetIniBool(accountConfig, section, keys[i]);     // Default-Values für BarClose
            signal.param1  = NULL;                                            // (unbenutzt)
            signal.param2  = true;                                            // signal.onTouch = true
            signal.param3  = NULL;                                            // (unbenutzt)
         }
         else if (signal == SIGNAL_BAR_RANGE) {
            sValue = iniValue;
            if (StrEndsWith(sValue, "%")) {                                   // z.B. BarRange = {90}%
               sValue = StrTrim(StrLeft(sValue, -1));
               if (!StrIsDigit(sValue))         return(!catch("Configure(12)  invalid or unknown signal configuration ["+ section +"]->"+ keys[i] +" in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));
               iValue = StrToInteger(sValue);
               if (iValue <= 0 || iValue > 100) return(!catch("Configure(13)  invalid signal configuration ["+ section +"]->"+ keys[i] +"=\""+ iniValue +"\" (not between 0 and 100) in \""+ accountConfig +"\"", ERR_INVALID_CONFIG_VALUE));
               if (iValue < 50)
                  iValue = 100 - iValue;
            }
            else {                                                            // BarRange = {Boolean}    ; On = 100%
               iValue = ifInt(GetIniBool(accountConfig, section, keys[i]), 100, 0);
            }
            signal.enabled = (iValue != 0);                                   // Default-Values für BarRange
            signal.param1  = iValue;                                          // signal.barRange   = {percent}
            signal.param2  = false;                                           // signal.onTouch    = false
            signal.param3  = 0;                                               // signal.resetAfter = {seconds}
         }

         // (2.4) Signal zur Konfiguration hinzufügen
         size = ArrayRange(signal.config, 0);
         ArrayResize(signal.config, size+1);
         ArrayResize(signal.data,   size+1);
         ArrayResize(signal.status, size+1);
         signal.config[size][SIGNAL_CONFIG_ENABLED  ] = signal.enabled;       // (int) bool
         signal.config[size][SIGNAL_CONFIG_TYPE     ] = signal;
         signal.config[size][SIGNAL_CONFIG_TIMEFRAME] = signal.timeframe;
         signal.config[size][SIGNAL_CONFIG_BAR      ] = signal.bar;
         signal.config[size][SIGNAL_CONFIG_PARAM1   ] = signal.param1;
         signal.config[size][SIGNAL_CONFIG_PARAM2   ] = signal.param2;
         signal.config[size][SIGNAL_CONFIG_PARAM3   ] = signal.param3;
      }

      // (2.5) Signale initialisieren
      bool success = false;
      size = ArrayRange(signal.config, 0);

      for (i=0; i < size; i++) {
         if (signal.config[i][SIGNAL_CONFIG_ENABLED] != 0) {
            switch (signal.config[i][SIGNAL_CONFIG_TYPE]) {
               case SIGNAL_BAR_CLOSE: success = BarCloseSignal.Init(i); break;
               case SIGNAL_BAR_RANGE: success = BarRangeSignal.Init(i); break;
               default:
                  success = false;
                  catch("Configure(14)  unknown signal["+ i +"] = "+ signal.config[i][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR);
            }
         }
         if (!success) return(false);
      }
   }


   // (3) Signalisierungs-Methoden einlesen
   if (track.orders || track.signals) {
      if (!ConfigureSignalSound(Signal.Sound,         signal.sound                                         )) return(last_error);
      if (!ConfigureSignalSMS  (Signal.SMS.Receiver,  signal.sms,                      signal.sms.receiver )) return(last_error);
      if (!ConfigureSignalMail (Signal.Mail.Receiver, signal.mail, signal.mail.sender, signal.mail.receiver)) return(last_error);
   }

   return(!ShowStatus(catch("Configure(15)")));
}


/**
 * Setzt einen Signal-Parameter. Innerhalb der konfigurierten Signale wird ein Signal durch die Kombination "SignalType-Lookback-Timeframe"
 * eindeutig identifiziert. Wurde ein Parameter mehrfach angegeben, überschreibt der später auftretende den vorherigen Wert. Die Funktion
 * setzt keine Default-Values für nicht angegebene Parameter.
 *
 * @param  int    signal    - Type des Signals
 * @param  int    timeframe - Timeframe des Signals
 * @param  int    lookback  - Bar-Offset des Signals
 * @param  string param     - Name des zu setzenden Parameters
 * @param  string value     - Wert des zu setzenden Parameters
 *
 * @return bool - Erfolgsstatus
 */
bool Configure.SetParameter(int signal, int timeframe, int lookback, string param, string value) {
   int lenValue  = StringLen(value); if (!lenValue) return(false);
   string lParam = StrToLower(param);


   // (1) zu modifizierendes Signal suchen
   int size = ArrayRange(signal.config, 0);
   for (int i=0; i < size; i++) {
      if (signal.config[i][SIGNAL_CONFIG_TYPE] == signal)
         if (signal.config[i][SIGNAL_CONFIG_TIMEFRAME] == timeframe)
            if (signal.config[i][SIGNAL_CONFIG_BAR] == lookback)
               break;
   }
   if (i == size) {
      if (IsLogDebug()) logDebug("Configure.SetParameter(1)  main configuration for signal parameter "+ SignalToStr(signal) +"."+ param +"="+ DoubleQuoteStr(value) +" not found");
      return(true);
   }
   // i zeigt hier immer auf das zu modifizierende Signal


   // (2) BarClose-Signal
   if (signal == SIGNAL_BAR_CLOSE) {
      if (lParam == "ontouch") {
         signal.config[i][SIGNAL_CONFIG_PARAM2] = StrToBool(value);
      }
      else if (IsLogDebug()) logDebug("Configure.SetParameter(2)  BarClose signal: unknown parameter "+ param +"="+ DoubleQuoteStr(value));
      return(true);
   }


   // (3) BarRange-Signal
   if (signal == SIGNAL_BAR_RANGE) {
      if (lParam == "ontouch") {
         signal.config[i][SIGNAL_CONFIG_PARAM2] = StrToBool(value);
      }
      else if (lParam == "resetafter") {                                                  // {Integer}[-]{Time[frame]}
         if (!StrIsDigit(StrLeft(value, 1)))
            return(false);

         string sDigits = StrLeft(value, 1);                                              // Zahl vorn parsen
         for (int j=1; j < lenValue; j++) {
            int char = StringGetChar(value, j);
            if ('0'<=char && char<='9') sDigits = StrLeft(value, j+1);
            else                        break;
         }
         int iValue = StrToInteger(sDigits);
         value = StrToUpper(StrTrim(StrSubstr(value, j)));                                // Zahl vorn abschneiden

         if (StrStartsWith(value, "-")) value = StrTrim(StrSubstr(value, 1));             // ein "-" vorn abschneiden
         if (StrEndsWith  (value, "S")) value = StrTrim(StrLeft (value, -1));             // ein "s" hinten abschneiden

         if      (value == "MINUTE") iValue *=    MINUTES;
         else if (value == "HOUR"  ) iValue *=    HOURS;
         else if (value == "DAY"   ) iValue *=    DAYS;
         else if (value == "WEEK"  ) iValue *=    WEEKS;
         else if (value == "M1"    ) iValue *=    MINUTES;
         else if (value == "M5"    ) iValue *=  5*MINUTES;
         else if (value == "M15"   ) iValue *= 15*MINUTES;
         else if (value == "M30"   ) iValue *= 30*MINUTES;
         else if (value == "H1"    ) iValue *=    HOURS;
         else if (value == "H4"    ) iValue *=  4*HOURS;
         else if (value == "D1"    ) iValue *=    DAYS;
         else if (value == "W1"    ) iValue *=    WEEKS;
         else return(false);

         signal.config[i][SIGNAL_CONFIG_PARAM3] = iValue;
      }
      else if (IsLogDebug()) logDebug("Configure.SetParameter(3)  BarRange signal: unknown parameter "+ param +"="+ DoubleQuoteStr(value));
      return(true);
   }

   return(!catch("Configure.SetParameter(4)  unreachable code reached", ERR_RUNTIME_ERROR));
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onTick() {
   // (1) Orders überwachen
   if (track.orders) {
      int failedOrders      []; ArrayResize(failedOrders,    0);
      int openedPositions   []; ArrayResize(openedPositions, 0);
      int closedPositions[][2]; ArrayResize(closedPositions, 0);     // { Ticket, CloseType=[CLOSE_TYPE_TP | CLOSE_TYPE_SL | CLOSE_TYPE_SO] }

      if (!CheckPositions(failedOrders, openedPositions, closedPositions))
         return(last_error);

      if (ArraySize(failedOrders   ) > 0) onOrderFail    (failedOrders   );
      if (ArraySize(openedPositions) > 0) onPositionOpen (openedPositions);
      if (ArraySize(closedPositions) > 0) onPositionClose(closedPositions);
   }


   // (2) Signale überwachen
   if (track.signals) {
      int  size    = ArrayRange(signal.config, 0);
      bool success = false;
      //debug("onTick(1)  Tick="+ Tick);

      for (int i=0; i < size; i++) {
         if (signal.config[i][SIGNAL_CONFIG_ENABLED] != 0) {
            switch (signal.config[i][SIGNAL_CONFIG_TYPE]) {
               case SIGNAL_BAR_CLOSE: success = BarCloseSignal.Check(i); break;
               case SIGNAL_BAR_RANGE: success = BarRangeSignal.Check(i); break;
               default:
                  success = false;
                  catch("onTick(2)  unknown signal["+ i +"] = "+ signal.config[i][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR);
            }
         }
         if (!success) break;
      }
   }

   if (IsError(last_error))
      ShowStatus(last_error);
   return(last_error);
}


/**
 * Prüft, ob seit dem letzten Aufruf eine Pending-Order oder ein Close-Limit ausgeführt wurden.
 *
 * @param  int failedOrders   []    - Array zur Aufnahme der Tickets fehlgeschlagener Pening-Orders
 * @param  int openedPositions[]    - Array zur Aufnahme der Tickets neuer offener Positionen
 * @param  int closedPositions[][2] - Array zur Aufnahme der Tickets neuer geschlossener Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool CheckPositions(int failedOrders[], int openedPositions[], int closedPositions[][]) {
   /*
   PositionOpen
   ------------
   - ist Ausführung einer Pending-Order
   - Pending-Order muß vorher bekannt sein
     (1) alle bekannten Pending-Orders auf Statusänderung prüfen:              über bekannte Orders iterieren
     (2) alle unbekannten Pending-Orders registrieren:                         über alle Tickets(MODE_TRADES) iterieren

   PositionClose
   -------------
   - ist Schließung einer Position
   - Position muß vorher bekannt sein
     (1) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen:   über bekannte Orders iterieren
     (2) alle unbekannten Positionen mit und ohne Exit-Limit registrieren:     über alle Tickets(MODE_TRADES) iterieren
         (limitlose Positionen können durch Stopout geschlossen werden/worden sein)

   beides zusammen
   ---------------
     (1.1) alle bekannten Pending-Orders auf Statusänderung prüfen:            über bekannte Orders iterieren
     (1.2) alle bekannten Pending-Orders und Positionen auf OrderClose prüfen: über bekannte Orders iterieren
     (2)   alle unbekannten Pending-Orders und Positionen registrieren:        über alle Tickets(MODE_TRADES) iterieren
           - nach (1), um neue Orders nicht sofort zu prüfen (unsinnig)
   */

   int type, knownSize=ArraySize(orders.knownOrders.ticket);


   // (1) über alle bekannten Orders iterieren (rückwärts, um beim Entfernen von Elementen die Schleife einfacher managen zu können)
   for (int i=knownSize-1; i >= 0; i--) {
      if (!SelectTicket(orders.knownOrders.ticket[i], "CheckPositions(1)"))
         return(false);
      type = OrderType();

      if (orders.knownOrders.type[i] > OP_SELL) {
         // (1.1) beim letzten Aufruf Pending-Order
         if (type == orders.knownOrders.type[i]) {
            // immer noch Pending-Order
            if (OrderCloseTime() != 0) {
               if (OrderComment() != "cancelled")
                  ArrayPushInt(failedOrders, orders.knownOrders.ticket[i]);      // keine regulär gestrichene Pending-Order: "deleted [no money]" etc.

               // geschlossene Pending-Order aus der Überwachung entfernen
               ArraySpliceInts(orders.knownOrders.ticket, i, 1);
               ArraySpliceInts(orders.knownOrders.type,   i, 1);
               knownSize--;
            }
         }
         else {
            // jetzt offene oder bereits geschlossene Position
            ArrayPushInt(openedPositions, orders.knownOrders.ticket[i]);         // Pending-Order wurde ausgeführt
            orders.knownOrders.type[i] = type;
            i++;
            continue;                                                            // ausgeführte Order in Zweig (1.2) nochmal prüfen (anstatt hier die Logik zu duplizieren)
         }
      }
      else {
         // (1.2) beim letzten Aufruf offene Position
         if (!OrderCloseTime()) {
            // immer noch offene Position
         }
         else {
            // jetzt geschlossene Position
            // prüfen, ob die Position manuell oder automatisch geschlossen wurde (durch ein Close-Limit oder durch Stopout)
            bool   closedByLimit=false, autoClosed=false;
            int    closeType, closeData[2];
            string comment = StrToLower(StrTrim(OrderComment()));

            if      (StrStartsWith(comment, "so:" )) { autoClosed=true; closeType=CLOSE_TYPE_SO; }    // Margin Stopout erkennen
            else if (StrEndsWith  (comment, "[tp]")) { autoClosed=true; closeType=CLOSE_TYPE_TP; }
            else if (StrEndsWith  (comment, "[sl]")) { autoClosed=true; closeType=CLOSE_TYPE_SL; }
            else {
               if (!EQ(OrderTakeProfit(), 0)) {                                                       // manche Broker setzen den OrderComment bei getriggertem Limit nicht
                  closedByLimit = false;                                                              // gemäß MT4-Standard
                  if (type == OP_BUY ) { closedByLimit = (OrderClosePrice() >= OrderTakeProfit()); }
                  else                 { closedByLimit = (OrderClosePrice() <= OrderTakeProfit()); }
                  if (closedByLimit) {
                     autoClosed = true;
                     closeType  = CLOSE_TYPE_TP;
                  }
               }
               if (!EQ(OrderStopLoss(), 0)) {
                  closedByLimit = false;
                  if (type == OP_BUY ) { closedByLimit = (OrderClosePrice() <= OrderStopLoss()); }
                  else                 { closedByLimit = (OrderClosePrice() >= OrderStopLoss()); }
                  if (closedByLimit) {
                     autoClosed = true;
                     closeType  = CLOSE_TYPE_SL;
                  }
               }
            }
            if (autoClosed) {
               closeData[0] = orders.knownOrders.ticket[i];
               closeData[1] = closeType;
               ArrayPushInts(closedPositions, closeData);            // Position wurde automatisch geschlossen
            }
            ArraySpliceInts(orders.knownOrders.ticket, i, 1);        // geschlossene Position aus der Überwachung entfernen
            ArraySpliceInts(orders.knownOrders.type,   i, 1);
            knownSize--;
         }
      }
   }


   // (2) über Tickets(MODE_TRADES) iterieren und alle unbekannten Tickets registrieren (immer Pending-Order oder offene Position)
   while (true) {
      int ordersTotal = OrdersTotal();

      for (i=0; i < ordersTotal; i++) {
         if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {                      // FALSE: während des Auslesens wurde von dritter Seite eine Order geschlossen oder gelöscht
            ordersTotal = -1;                                                    // Abbruch und via while-Schleife alles nochmal verarbeiten, bis for() fehlerfrei durchläuft
            break;
         }
         for (int n=0; n < knownSize; n++) {
            if (orders.knownOrders.ticket[n] == OrderTicket())                   // Order bereits bekannt
               break;
         }
         if (n >= knownSize) {                                                   // Order unbekannt: in Überwachung aufnehmen
            ArrayPushInt(orders.knownOrders.ticket, OrderTicket());
            ArrayPushInt(orders.knownOrders.type,   OrderType()  );
            knownSize++;
         }
      }

      if (ordersTotal == OrdersTotal())
         break;
   }

   return(!catch("CheckPositions(2)"));
}


/**
 * Handler für OrderFail-Events.
 *
 * @param  int tickets[] - Tickets der fehlgeschlagenen Orders (immer Pending-Orders)
 *
 * @return bool - Erfolgsstatus
 */
bool onOrderFail(int tickets[]) {
   if (!track.orders)
      return(true);

   int error = 0;
   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onOrderFail(1)"))
         return(false);

      string type        = OperationTypeDescription(OrderType() & 1);      // Buy-Limit -> Buy, Sell-Stop -> Sell, etc.
      string lots        = DoubleToStr(OrderLots(), 2);
      int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
      int    pipDigits   = digits & (~1);
      string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      string price       = NumberToStr(OrderOpenPrice(), priceFormat);
      string message     = "Order failed: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" at "+ price + NL +"with error: \""+ OrderComment() +"\""+ NL +"("+ TimeToStr(GetLocalTime(), TIME_MINUTES|TIME_SECONDS) +", "+ orders.accountAlias +")";

      if (IsLogDebug()) logDebug("onOrderFail(2)  "+ message);

      // Signale für jede Order einzeln verschicken
      if (signal.mail) error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)  error |= !SendSMS(signal.sms.receiver, message);
   }

   // Sound für alle Orders gemeinsam abspielen
   if (signal.sound) error |= !PlaySoundEx(signal.sound.orderFailed);

   return(!error);
}


/**
 * Handler für PositionOpen-Events.
 *
 * @param  int tickets[] - Tickets der neu geöffneten Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool onPositionOpen(int tickets[]) {
   if (!track.orders)
      return(true);

   int error = 0;
   int positions = ArraySize(tickets);

   for (int i=0; i < positions; i++) {
      if (!SelectTicket(tickets[i], "onPositionOpen(1)"))
         return(false);

      string type        = OperationTypeDescription(OrderType());
      string lots        = DoubleToStr(OrderLots(), 2);
      int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
      int    pipDigits   = digits & (~1);
      string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      string price       = NumberToStr(OrderOpenPrice(), priceFormat);
      string message     = "Position opened: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" at "+ price + NL +"("+ TimeToStr(GetLocalTime(), TIME_MINUTES|TIME_SECONDS) +", "+ orders.accountAlias +")";

      if (IsLogDebug()) logDebug("onPositionOpen(2)  "+ message);

      // Signale für jede Position einzeln verschicken
      if (signal.mail) error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)  error |= !SendSMS(signal.sms.receiver, message);
   }

   // Sound für alle Positionen gemeinsam abspielen
   if (signal.sound) error |= !PlaySoundEx(signal.sound.positionOpened);

   return(!error);
}


/**
 * Handler für PositionClose-Events.
 *
 * @param  int tickets[] - Tickets der geschlossenen Positionen
 *
 * @return bool - Erfolgsstatus
 */
bool onPositionClose(int tickets[][]) {
   if (!track.orders)
      return(true);

   string closeTypeDescr[] = {"", " (TakeProfit)", " (StopLoss)", " (StopOut)"};

   int error = 0;
   int positions = ArrayRange(tickets, 0);

   for (int i=0; i < positions; i++) {
      int ticket    = tickets[i][0];
      int closeType = tickets[i][1];
      if (!SelectTicket(ticket, "onPositionClose(1)"))
         continue;

      string type        = OperationTypeDescription(OrderType());
      string lots        = DoubleToStr(OrderLots(), 2);
      int    digits      = MarketInfo(OrderSymbol(), MODE_DIGITS);
      int    pipDigits   = digits & (~1);
      string priceFormat = StringConcatenate(".", pipDigits, ifString(digits==pipDigits, "", "'"));
      string openPrice   = NumberToStr(OrderOpenPrice(), priceFormat);
      string closePrice  = NumberToStr(OrderClosePrice(), priceFormat);
      string message     = "Position closed: "+ type +" "+ lots +" "+ GetStandardSymbol(OrderSymbol()) +" open="+ openPrice +" close="+ closePrice + closeTypeDescr[closeType] + NL +"("+ TimeToStr(GetLocalTime(), TIME_MINUTES|TIME_SECONDS) +", "+ orders.accountAlias +")";

      if (IsLogDebug()) logDebug("onPositionClose(2)  "+ message);

      // Signale für jede Position einzeln verschicken
      if (signal.mail) error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);
      if (signal.sms)  error |= !SendSMS(signal.sms.receiver, message);
   }

   // Sound für alle Positionen gemeinsam abspielen
   if (signal.sound) error |= !PlaySoundEx(signal.sound.positionClosed);

   return(!error);
}


/**
 * Initialisiert die Laufzeitdaten zur Verwaltung eines BarClose-Signals.
 *
 * @param  int  index   - Index in den zur Überwachung konfigurierten Signalen
 * @param  bool barOpen - ob der Aufruf von einem BarOpen-Event zum Zweck des Signal-Resets ausgelöst wurde (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool BarCloseSignal.Init(int index, bool barOpen = false) {
   barOpen = barOpen!=0;

   if ( signal.config[index][SIGNAL_CONFIG_TYPE   ] != SIGNAL_BAR_CLOSE) return(!catch("BarCloseSignal.Init(1)  signal "+ index +" is not a BarClose signal = "+ signal.config[index][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR));
   if (!signal.config[index][SIGNAL_CONFIG_ENABLED])                     return(true);

   static bool noticed = false;
   if (!noticed) {
      debug("BarCloseSignal.Init(2)  sidx="+ index +"  barOpen="+ barOpen +" (not yet implemented)");
      noticed = true;
   }

   signal.status[index] = BarCloseSignal.Status(index);
   return(!ShowStatus(catch("BarCloseSignal.Init(3)")));
}


/**
 * Prüft auf ein BarClose-Event.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus
 */
bool BarCloseSignal.Check(int index) {
   if ( signal.config[index][SIGNAL_CONFIG_TYPE   ] != SIGNAL_BAR_CLOSE) return(!catch("BarCloseSignal.Check(1)  signal "+ index +" is not a BarClose signal = "+ signal.config[index][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR));
   if (!signal.config[index][SIGNAL_CONFIG_ENABLED])                     return(true);

   static bool noticed = false;
   if (!noticed) {
      debug("BarCloseSignal.Check(2)  sidx="+ index +"  (not yet implemented)");
      noticed = true;
   }

   return(!catch("BarCloseSignal.Check(3)"));
   onBarCloseSignal(index, NULL);   // dummy
}


/**
 * Gibt den Statustext eines BarClose-Signals zurück.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return string
 */
string BarCloseSignal.Status(int index) {
   if (signal.config[index][SIGNAL_CONFIG_TYPE] != SIGNAL_BAR_CLOSE) return(_EMPTY_STR(catch("BarCloseSignal.Status(1)  signal "+ index +" is not a BarClose signal = "+ signal.config[index][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR)));

   bool signal.enabled   = signal.config[index][SIGNAL_CONFIG_ENABLED  ] != 0;
   int  signal.timeframe = signal.config[index][SIGNAL_CONFIG_TIMEFRAME];
   int  signal.bar       = signal.config[index][SIGNAL_CONFIG_BAR      ];
   bool signal.onTouch   = signal.config[index][SIGNAL_CONFIG_PARAM1   ] != 0;
   int  signal.reset     = signal.config[index][SIGNAL_CONFIG_PARAM2   ];

   string description = "Signal at BarClose of "+ PeriodDescription(signal.timeframe) +"["+ signal.bar +"] "+ ifString(signal.enabled, "enabled", "disabled") +"    onTouch: "+ ifString(signal.onTouch, "On", "Off");
   return(description);
}


/**
 * Handler für BarClose-Signale.
 *
 * @param  int index     - Index in den zur Überwachung konfigurierten Signalen
 * @param  int direction - Richtung des Signals: SD_UP|SD_DOWN
 *
 * @return bool - Erfolgsstatus
 */
bool onBarCloseSignal(int index, int direction) {
   if (!track.signals)                                 return(true);
   if (direction!=SIGNAL_UP && direction!=SIGNAL_DOWN) return(!catch("onBarCloseSignal(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER));

   string message = "";
   if (IsLogDebug()) logDebug("onBarCloseSignal(2)  "+ message);


   // (1) Sound abspielen
   if (signal.sound) {
      if (direction == SIGNAL_UP) PlaySoundEx(signal.sound.priceSignal_up  );
      else                        PlaySoundEx(signal.sound.priceSignal_down);
   }

   // (2) SMS-Versand
   if (signal.sms) {
      if (!SendSMS(signal.sms.receiver, message)) return(false);
   }

   // (3) Mailversand
   if (signal.mail) {
   }

   return(!catch("onBarCloseSignal(3)"));
}


// Indizes von: double signal.data[][9]
#define I_BRS_TEST_TIMEFRAME           0        // Periode der zur Prüfung verwendeten Datenreihe = Testdatenreihe (Signal-Timeframe, jedoch max. PERIOD_H1)
#define I_BRS_TEST_SESSION_H           1        // High der Testsession
#define I_BRS_TEST_SESSION_L           2        // Low der Testsession
#define I_BRS_SIGNAL_LEVEL_H           3        // oberer Signal-Level innerhalb der Testsession (bei 100% = High)
#define I_BRS_SIGNAL_LEVEL_L           4        // unterer Signal-Level innerhalb der Testsession (bei 100% = Low)
#define I_BRS_TEST_SESSION_CLOSEBAR    5        // Bar-Offset der Close-Bar der Testsession innerhalb der Testdatenreihe (zur Erkennung von History-Backfills)
#define I_BRS_CURRENT_SESSION_ENDTIME  6        // Ende der jüngsten Session-Periode innerhalb der Testdatenreihe (zur Erkennung von onBarOpen)
#define I_BRS_LAST_CHANGED_BARS        7        // ChangedBars der Testdatenreihe beim letzten Check


/**
 * Initialisiert die Laufzeitdaten zur Verwaltung eines BarRange-Signals.
 *
 * @param  int index    - Index in den zur Überwachung konfigurierten Signalen
 * @param  bool barOpen - ob der Aufruf von einem BarOpen-Event zum Zweck des Signal-Resets ausgelöst wurde (default: nein)
 *
 * @return bool - Erfolgsstatus
 */
bool BarRangeSignal.Init(int index, bool barOpen = false) {
   barOpen = barOpen!=0;

   if ( signal.config[index][SIGNAL_CONFIG_TYPE   ] != SIGNAL_BAR_RANGE) return(!catch("BarRangeSignal.Init(1)  signal "+ index +" is not a BarRange signal = "+ signal.config[index][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR));
   if (!signal.config[index][SIGNAL_CONFIG_ENABLED])                     return(true);

   if (barOpen) debug("BarRangeSignal.Init(2)  barOpen="+ barOpen);

   int      signal.timeframe  = signal.config[index][SIGNAL_CONFIG_TIMEFRAME];
   int      signal.bar        = signal.config[index][SIGNAL_CONFIG_BAR      ];
   int      signal.barRange   = signal.config[index][SIGNAL_CONFIG_PARAM1   ];
   bool     signal.onTouch    = signal.config[index][SIGNAL_CONFIG_PARAM2   ] != 0;
   int      signal.resetAfter = signal.config[index][SIGNAL_CONFIG_PARAM3   ]; if (signal.bar != 0) signal.resetAfter = NULL;

   int      testTimeframe     = Min(signal.timeframe, PERIOD_H1);                      // Periode der Testdatenreihe (Signal-Timeframe, jedoch max. PERIOD_H1)
   datetime lastSessionEndTime;                                                        // Ende der jüngsten vorhandenen Session (covered Bar[0]): danach onBarOpen und Signal-Reset
                                                                                       // Ende der jüngsten Session von Signal- und Testdatenreihe sind identisch

   // (1) Anfangs- und Endzeitpunkt der Testsession und ihre Bar-Offsets in der Testdatenreihe bestimmen
   datetime openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv;
   int openBar, closeBar;

   for (int i=0; i<=signal.bar; i++) {
      if (!iPreviousPeriodTimes(signal.timeframe, openTime.fxt, closeTime.fxt, openTime.srv, closeTime.srv))  return(false);
      //debug("BarRangeSignal.Init(3)  bar="+ i +"  open="+ GmtTimeFormat(openTime.fxt, "%a, %d.%m.%Y %H:%M") +"  close="+ GmtTimeFormat(closeTime.fxt, "%a, %d.%m.%Y %H:%M"));
      openBar  = iBarShiftNext    (NULL, testTimeframe, openTime.srv          ); if (openBar  == EMPTY_VALUE) return(false);
      closeBar = iBarShiftPrevious(NULL, testTimeframe, closeTime.srv-1*SECOND); if (closeBar == EMPTY_VALUE) return(false);
      if (closeBar == -1) {                                                            // nicht ausreichende Daten zum Tracking: Signal deaktivieren
         signal.config[index][SIGNAL_CONFIG_ENABLED] = false;
         return(!logWarn("BarRangeSignal.Init(4)  signal "+ index, ERR_HISTORY_INSUFFICIENT));
      }
      if (openBar < closeBar) {                                                        // Datenlücke, i zurücksetzen und weiter zu den nächsten verfügbaren Daten
         i--;
      }
      else if (i == 0) {                                                               // openTime/closeTime enthalten die Zeiten der jüngsten Session des Signal-Timeframes
         lastSessionEndTime = closeTime.srv - 1*SECOND;                                // closeTime ist identisch zum Ende der Session der Testdatenreihe
      }
   }
   //debug("BarRangeSignal.Init(5)  bar="+ signal.bar +"  open="+ GmtTimeFormat(openTime.fxt, "%a, %d.%m.%Y %H:%M") +"  close="+ GmtTimeFormat(closeTime.fxt, "%a, %d.%m.%Y %H:%M"));


   // (2) High/Low bestimmen (openBar ist hier immer >= closeBar und Timeseries-Fehler können nicht mehr auftreten)
   int highBar = iHighest(NULL, testTimeframe, MODE_HIGH, openBar-closeBar+1, closeBar);
   int lowBar  = iLowest (NULL, testTimeframe, MODE_LOW , openBar-closeBar+1, closeBar);
   double H    = iHigh   (NULL, testTimeframe, highBar);
   double L    = iLow    (NULL, testTimeframe, lowBar );


   // (3) Signallevel berechnen
   int    upperPctLevel =       signal.barRange;
   int    lowerPctLevel = 100 - signal.barRange;
   double dist          = (H-L) * lowerPctLevel/100;
   double signalLevelH  = H - dist;
   double signalLevelL  = L + dist;


   // (4) prüfen, ob die Level bereits gebrochen wurden                                         // TODO: diese Prüfung ist nur bei barRange = 100% korrekt
   if (highBar != iHighest(NULL, testTimeframe, MODE_HIGH, highBar+1, 0)) signalLevelH = NULL;  // High ist bereits gebrochen
   if (lowBar  != iLowest (NULL, testTimeframe, MODE_LOW,  lowBar +1, 0)) signalLevelL = NULL;  // Low ist bereits gebrochen

   string msg = PeriodDescription(signal.timeframe) +"["+ signal.bar +"]  H="+ NumberToStr(H, PriceFormat) +"  L="+ NumberToStr(L, PriceFormat);
   if (upperPctLevel != 100)
      msg = msg +"  "+ NumberToStr(upperPctLevel, ".+") +"%="+ NumberToStr(signalLevelH, PriceFormat) +"  "+ NumberToStr(lowerPctLevel, ".+") +"%="+ NumberToStr(signalLevelL, PriceFormat);
   //debug("BarRangeSignal.Init(6)  "+ msg);


   // (5) Daten speichern
   signal.data  [index][I_BRS_TEST_TIMEFRAME         ] = testTimeframe;
   signal.data  [index][I_BRS_TEST_SESSION_H         ] = NormalizeDouble(H, Digits);
   signal.data  [index][I_BRS_TEST_SESSION_L         ] = NormalizeDouble(L, Digits);
   signal.data  [index][I_BRS_SIGNAL_LEVEL_H         ] = NormalizeDouble(signalLevelH, Digits);
   signal.data  [index][I_BRS_SIGNAL_LEVEL_L         ] = NormalizeDouble(signalLevelL, Digits);
   signal.data  [index][I_BRS_TEST_SESSION_CLOSEBAR  ] = closeBar;
   signal.data  [index][I_BRS_CURRENT_SESSION_ENDTIME] = lastSessionEndTime;
   signal.data  [index][I_BRS_LAST_CHANGED_BARS      ] = 0;
   signal.status[index]                                = BarRangeSignal.Status(index);

   return(!ShowStatus(catch("BarRangeSignal.Init(7)")));
}


/**
 * Prüft auf ein BarRange-Signalevent.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return bool - Erfolgsstatus (nicht, ob ein neues Signal getriggert wurde)
 */
bool BarRangeSignal.Check(int index) {
   if ( signal.config[index][SIGNAL_CONFIG_TYPE   ] != SIGNAL_BAR_RANGE) return(!catch("BarRangeSignal.Check(1)  signal "+ index +" is not a BarRange signal = "+ signal.config[index][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR));
   if (!signal.config[index][SIGNAL_CONFIG_ENABLED])                     return(true);

   int      signal.timeframe    = signal.config[index][SIGNAL_CONFIG_TIMEFRAME    ];
   int      signal.bar          = signal.config[index][SIGNAL_CONFIG_BAR          ];
   int      signal.barRange     = signal.config[index][SIGNAL_CONFIG_PARAM1       ];
   bool     signal.onTouch      = signal.config[index][SIGNAL_CONFIG_PARAM2       ] != 0;    // noch nicht implementiert
   int      signal.resetAfter   = signal.config[index][SIGNAL_CONFIG_PARAM3       ];         // noch nicht implementiert

   int      testTimeframe       = signal.data  [index][I_BRS_TEST_TIMEFRAME         ];
   double   signalLevelH        = signal.data  [index][I_BRS_SIGNAL_LEVEL_H         ];
   double   signalLevelL        = signal.data  [index][I_BRS_SIGNAL_LEVEL_L         ];
   int      testSessionCloseBar = signal.data  [index][I_BRS_TEST_SESSION_CLOSEBAR  ];
   datetime lastSessionEndTime  = signal.data  [index][I_BRS_CURRENT_SESSION_ENDTIME];
   int      lastChangedBars     = signal.data  [index][I_BRS_LAST_CHANGED_BARS      ];


   // (1) aktuellen Tick klassifizieren
   static int  lastTick;
   static bool lastTick.new, tick.new;

   if (Tick != lastTick) {
      lastTick = Tick;
      if (tick.new) lastTick.new = true;
      tick.new = EventListener.NewTick();
   }


   // (2) changedBars(testTimeframe) für die Testdatenreihe ermitteln
   int changedBars = iChangedBars(NULL, testTimeframe);
   if (changedBars == -1) return(false);

   if (!changedBars)                                                                      // z.B. bei Aufruf in init() oder deinit()
      return(true);
   //debug("BarRangeSignal.Check(2)       changedBars="+ changedBars +"  tick.new="+ tick.new);


   // (3) Prüflevel reinitialisieren, wenn:
   //     - der Bereich der changedBars(testTimeframe) die Testsession überlappt (History-Backfill) oder wenn
   //     - eine neue Testsession begonnen hat (autom. Signal-Reset bei onBarOpen)
   bool reinitialized;
   if (changedBars > testSessionCloseBar) {
      // Ist testSessionCloseBar=0 und nur sie verändert, wird nur reinitialisiert, wenn der Tick synthetisch ist. Das deshalb, weil changedBars=0 in anderen als dem aktuellem
      if (changedBars > 1 || !tick.new) {                                                 // Timeframe nicht zuverlässig detektiert werden kann.
         //debug("BarRangeSignal.Check(3)       changedBars="+ changedBars +"  tick.new="+ tick.new);
         if (!BarRangeSignal.Init(index)) return(false);
         reinitialized = true;
      }
   }
   if (!reinitialized) /*&&*/ if (iTime(NULL, testTimeframe, 0) > lastSessionEndTime) {   // autom. Signal-Reset bei Beginn neuer Testsession
      //debug("BarRangeSignal.Check(4)       changedBars="+ changedBars +"  tick.new="+ tick.new);
      if (!BarRangeSignal.Init(index, true)) return(false);                               // barOpen = true
      reinitialized = true;
   }

   if (reinitialized) {
      testTimeframe       = signal.data[index][I_BRS_TEST_TIMEFRAME         ];            // Werte ggf. neueinlesen
      signalLevelH        = signal.data[index][I_BRS_SIGNAL_LEVEL_H         ];
      signalLevelL        = signal.data[index][I_BRS_SIGNAL_LEVEL_L         ];
      testSessionCloseBar = signal.data[index][I_BRS_TEST_SESSION_CLOSEBAR  ];
      lastSessionEndTime  = signal.data[index][I_BRS_CURRENT_SESSION_ENDTIME];
      lastChangedBars     = signal.data[index][I_BRS_LAST_CHANGED_BARS      ];
   }
   //debug("BarRangeSignal.Check(5)       lastChangedBars="+ lastChangedBars +"  changedBars="+ changedBars);


   // (4) Signallevel prüfen, wenn die Bars der Testdatenreihe komplett scheinen und der zweite echte Tick eintrifft.
   if (lastChangedBars<=2 && changedBars<=2 && lastTick.new && tick.new) {                // Optimierung unnötig, da im Normalfall immer alle Bedingungen zutreffen
      //debug("BarRangeSignal.Check(6)       checking tick "+ Tick);

      double price = NormalizeDouble(Bid, Digits);

      if (signalLevelH != NULL) {
         if (GE(price, signalLevelH)) {
            if (GT(price, signalLevelH)) {
               onBarRangeSignal(index, SIGNAL_UP, signalLevelH, price, TimeCurrentEx("BarRangeSignal.Check(7)"));
               signalLevelH                               = NULL;
               signal.data  [index][I_BRS_SIGNAL_LEVEL_H] = NULL;
               signal.status[index]                       = BarRangeSignal.Status(index);
               ShowStatus();
            }
            //else if (signal.onTouch) debug("BarRangeSignal.Check(8)       touch signal: current price "+ NumberToStr(price, PriceFormat) +" = High["+ PeriodDescription(signal.timeframe) +","+ signal.bar +"]="+ NumberToStr(signalLevelH, PriceFormat));
         }
      }
      if (signalLevelL != NULL) {
         if (LE(price, signalLevelL)) {
            if (LT(price, signalLevelL)) {
               onBarRangeSignal(index, SIGNAL_DOWN, signalLevelL, price, TimeCurrentEx("BarRangeSignal.Check(9)"));
               signalLevelL                               = NULL;
               signal.data  [index][I_BRS_SIGNAL_LEVEL_L] = NULL;
               signal.status[index]                       = BarRangeSignal.Status(index);
               ShowStatus();
            }
            //else if (signal.onTouch) debug("BarRangeSignal.Check(10)       touch signal: current price "+ NumberToStr(price, PriceFormat) +" = Low["+ PeriodDescription(signal.timeframe) +","+ signal.bar +"]="+ NumberToStr(signalLevelL, PriceFormat));
         }
      }
   }
   else {
      //debug("BarRangeSignal.Check(11)       not checking tick "+ Tick +", lastChangedBars="+ lastChangedBars +"  changedBars="+ changedBars +"  lastTick.new="+ lastTick.new +"  tick.isNew="+ tick.isNew);
   }

   signal.data[index][I_BRS_LAST_CHANGED_BARS] = changedBars;
   return(!catch("BarRangeSignal.Check(12)"));
}


/**
 * Gibt den Statustext eines BarRange-Signals zurück.
 *
 * @param  int index - Index in den zur Überwachung konfigurierten Signalen
 *
 * @return string
 */
string BarRangeSignal.Status(int index) {
   if (signal.config[index][SIGNAL_CONFIG_TYPE] != SIGNAL_BAR_RANGE) return(_EMPTY_STR(catch("BarRangeSignal.Status(1)  signal "+ index +" is not a BarRange signal = "+ signal.config[index][SIGNAL_CONFIG_TYPE], ERR_RUNTIME_ERROR)));

   bool   signal.enabled    = signal.config[index][SIGNAL_CONFIG_ENABLED  ] != 0;
   int    signal.timeframe  = signal.config[index][SIGNAL_CONFIG_TIMEFRAME];
   int    signal.bar        = signal.config[index][SIGNAL_CONFIG_BAR      ];
   int    signal.barRange   = signal.config[index][SIGNAL_CONFIG_PARAM1   ];
   bool   signal.onTouch    = signal.config[index][SIGNAL_CONFIG_PARAM2   ] != 0;
   int    signal.resetAfter = signal.config[index][SIGNAL_CONFIG_PARAM3   ];

   double signalLevelH      = signal.data  [index][I_BRS_SIGNAL_LEVEL_H   ];
   double signalLevelL      = signal.data  [index][I_BRS_SIGNAL_LEVEL_L   ];

   string description = "Signal at break of "+ BarRangeDescription(signal.timeframe, signal.bar) +"      High"+ ifString(signal.barRange==100, "", "-"+ NumberToStr(100-signal.barRange, ".+") +"%") +": "+ ifString(signalLevelH!=0, NumberToStr(signalLevelH, PriceFormat), "broken") +"    Low"+ ifString(signal.barRange==100, "", "+"+ NumberToStr(100-signal.barRange, ".+") +"%") +": "+ ifString(signalLevelL!=0, NumberToStr(signalLevelL, PriceFormat), "broken") +"      onTouch: "+ ifString(signal.onTouch, "On", "Off");
   return(description);
}


/**
 * Gibt die lesbare Beschreibung einer Bar-Range eines Timeframes zurück.
 *
 * @param  int timeframe - Timeframe
 * @param  int bar       - Bar-Offset
 *
 * @return string
 */
string BarRangeDescription(int timeframe, int bar) {
   string description = PeriodDescription(timeframe) +"["+ bar +"]";

   if      (description == "M1[0]" ) description = "this minute's range";
   else if (description == "M1[1]" ) description = "last minute's range";
   else if (description == "H1[0]" ) description = "this hour's range  ";
   else if (description == "H1[1]" ) description = "last hour's range  ";
   else if (description == "D1[0]" ) description = "today's range      ";
   else if (description == "D1[1]" ) description = "yesterday's range ";
   else if (description == "W1[0]" ) description = "this week's range ";
   else if (description == "W1[1]" ) description = "last week's range ";
   else if (description == "MN1[0]") description = "this month's range ";
   else if (description == "MN1[1]") description = "last month's range ";
   else                              description = description +"'s range       ";

   return(description);
}


/**
 * Handler für BarRange-Signale.
 *
 * @param  int      index     - Index in den zur Überwachung konfigurierten Signalen
 * @param  int      direction - Richtung des Signals: SD_UP|SD_DOWN
 * @param  double   level     - Signallevel, der berührt oder gebrochen wurde
 * @param  double   price     - Preis, der den Signallevel berührt oder gebrochen hat
 * @param  datetime time.srv  - Zeitpunkt des Signals (Serverzeit)
 *
 * @return bool - Erfolgsstatus
 */
bool onBarRangeSignal(int index, int direction, double level, double price, datetime time.srv) {
   if (!track.signals)                                 return(true);
   if (direction!=SIGNAL_UP && direction!=SIGNAL_DOWN) return(!catch("onBarRangeSignal(1)  invalid parameter direction = "+ direction, ERR_INVALID_PARAMETER));

   int signal.timeframe = signal.config[index][SIGNAL_CONFIG_TIMEFRAME];
   int signal.bar       = signal.config[index][SIGNAL_CONFIG_BAR      ];

   string message = StdSymbol() +" broke "+ BarDescription(signal.timeframe, signal.bar) +"'s "+ ifString(direction==SIGNAL_UP, "high", "low") +" of "+ NumberToStr(level, PriceFormat) + NL +" ("+ TimeToStr(GetLocalTime(), TIME_MINUTES|TIME_SECONDS) +")";
   if (IsLogDebug()) logDebug("onBarRangeSignal(2)  "+ message);

   int error = 0;

   // (1) Sound abspielen
   if (signal.sound) {
      if (direction == SIGNAL_UP) error |= !PlaySoundEx(signal.sound.priceSignal_up  );
      else                        error |= !PlaySoundEx(signal.sound.priceSignal_down);
   }

   // (2) Benachrichtigungen verschicken
   if (signal.sms)  error |= !SendSMS(signal.sms.receiver, message);
   if (signal.mail) error |= !SendEmail(signal.mail.sender, signal.mail.receiver, message, message);

   return(!error);
}


/**
 * Gibt die lesbare Beschreibung einer Bar eines Timeframes zurück.
 *
 * @param  int timeframe - Timeframe
 * @param  int bar       - Bar-Offset
 *
 * @return string
 */
string BarDescription(int timeframe, int bar) {
   string description = PeriodDescription(timeframe) +"["+ bar +"]";

   if      (description == "M1[0]" ) description = "this minute";
   else if (description == "M1[1]" ) description = "last minute";
   else if (description == "H1[0]" ) description = "this hour";
   else if (description == "H1[1]" ) description = "last hour";
   else if (description == "D1[0]" ) description = "today";
   else if (description == "D1[1]" ) description = "yesterday";
   else if (description == "W1[0]" ) description = "this week";
   else if (description == "W1[1]" ) description = "last week";
   else if (description == "MN1[0]") description = "this month";
   else if (description == "MN1[1]") description = "last month";

   return(description);
}


/**
 * Zeigt den aktuellen Laufzeitstatus an.
 *
 * @param  int error - anzuzeigender Fehler (default: keiner)
 *
 * @return int - der übergebene Fehler
 */
int ShowStatus(int error=NULL) {
   if (__STATUS_OFF)
      error = __STATUS_OFF.reason;

   string sSettings, sError;

   if (track.orders || track.signals) sSettings = "    Sound="+ ifString(signal.sound, "On", "Off") + ifString(signal.sms, "    SMS="+ signal.sms.receiver, "") + ifString(signal.mail, "    Mail="+ signal.mail.receiver, "");
   else                               sSettings = ":  Off";

   if (!error)                        sError    = "";
   else                               sError    = "  ["+ ErrorDescription(error) +"]";

   string msg = StringConcatenate(ProgramName(), sSettings, sError, NL);

   if (track.orders || track.signals) {
      msg    = StringConcatenate(msg, "-------------------",   NL);

      if (track.orders) {
         msg = StringConcatenate(msg,
                                "Track.Orders = 1",            NL);
      }
      if (track.signals) {
         msg = StringConcatenate(msg,
                                 GetSignalStatus(),            NL);
      }
   }

   Comment(NL, NL, NL, msg);
   if (__CoreFunction == CF_INIT)
      WindowRedraw();
   return(error);
}


/**
 * Gibt den Signalstatus aller aktiven Signale zurück.
 *
 * @return string
 */
string GetSignalStatus() {
   string status = "";
   bool   first  = true;
   int    size   = ArrayRange(signal.config, 0);

   for (int i=0; i < size; i++) {
      if (signal.config[i][SIGNAL_CONFIG_ENABLED] != 0) {
         if (first) {
            status = signal.status[i];
            first  = false;
         }
         else {
            status = StringConcatenate(status, NL, signal.status[i]);
         }
      }
   }
   return(status);
}


/**
 * Gibt die lesbare Repräsentation einer Signal-ID zurück (der Signalname).
 *
 * @param  int id - Signal-ID
 *
 * @return string
 */
string SignalToStr(int id) {
   switch (id) {
      case SIGNAL_BAR_CLOSE: return("BarClose");
      case SIGNAL_BAR_RANGE: return("BarRange");
   }
   return(id +" (unknown)");
}


/**
 * Return a string representation of the input parameters (for logging purposes).
 *
 * @return string
 */
string InputsToStr() {
   return(StringConcatenate("Track.Orders=",         track.orders,                         ";", NL,
                            "Track.Signals=",        track.signals,                        ";", NL,

                            "Signal.Sound=",         signal.sound,                         ";", NL,
                            "Signal.SMS.Receiver=",  DoubleQuoteStr(signal.sms.receiver),  ";", NL,
                            "Signal.Mail.Receiver=", DoubleQuoteStr(signal.mail.receiver), ";")
   );
}

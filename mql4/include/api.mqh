/**
 * Nach Funktionalität gruppierter Überblick aller in MQL zusätzlich zur Verfügung stehenden globalen Funktionen und der jeweils benötigten Library.
 *
 * @note  Diese Datei soll und kann nicht inkludiert werden.
 */

                        // Konfiguration
/*stdlib1.ex4     */    string   GetLocalConfigPath();
/*stdlib1.ex4     */    string   GetGlobalConfigPath();
  TODO                  string   GetAccountConfigPath();

/*stdfunctions.mqh*/    bool     IsConfigKey             (string section, string key);
/*stdfunctions.mqh*/    bool     IsLocalConfigKey        (string section, string key);
/*stdfunctions.mqh*/    bool     IsGlobalConfigKey       (string section, string key);

/*stdfunctions.mqh*/    bool     GetConfigBool           (string section, string key, bool   defaultValue);
/*stdfunctions.mqh*/    int      GetConfigInt            (string section, string key, int    defaultValue);
/*stdfunctions.mqh*/    double   GetConfigDouble         (string section, string key, double defaultValue);
/*stdfunctions.mqh*/    string   GetConfigString         (string section, string key, string defaultValue);
/*stdfunctions.mqh*/    string   GetRawConfigString      (string section, string key, string defaultValue);

/*stdfunctions.mqh*/    bool     GetLocalConfigBool      (string section, string key, bool   defaultValue);
/*stdfunctions.mqh*/    int      GetLocalConfigInt       (string section, string key, int    defaultValue);
/*stdfunctions.mqh*/    double   GetLocalConfigDouble    (string section, string key, double defaultValue);
/*stdfunctions.mqh*/    string   GetLocalConfigString    (string section, string key, string defaultValue);
/*stdfunctions.mqh*/    string   GetRawLocalConfigString (string section, string key, string defaultValue);

/*stdfunctions.mqh*/    bool     GetGlobalConfigBool     (string section, string key, bool   defaultValue);
/*stdfunctions.mqh*/    int      GetGlobalConfigInt      (string section, string key, int    defaultValue);
/*stdfunctions.mqh*/    double   GetGlobalConfigDouble   (string section, string key, double defaultValue);
/*stdfunctions.mqh*/    string   GetGlobalConfigString   (string section, string key, string defaultValue);
/*stdfunctions.mqh*/    string   GetRawGlobalConfigString(string section, string key, string defaultValue);

/*stdfunctions.mqh*/    bool     GetIniBool     (string fileName, string section, string key, bool   defaultValue);
/*stdfunctions.mqh*/    int      GetIniInt      (string fileName, string section, string key, int    defaultValue);
/*stdfunctions.mqh*/    double   GetIniDouble   (string fileName, string section, string key, double defaultValue);
/*stdfunctions.mqh*/    string   GetIniString   (string fileName, string section, string key, string defaultValue);
/*stdlib1.ex4     */    string   GetRawIniString(string fileName, string section, string key, string defaultValue);

/*stdlib1.ex4     */    int      GetIniSections (string fileName, string sections[]);
/*stdlib2.ex4     */    int      GetIniKeys     (string fileName, string section, string keys[]);

/*stdlib1.ex4     */    bool     IsIniSection   (string fileName, string section);
/*stdlib1.ex4     */    bool     IsIniKey       (string fileName, string section, string key);

/*stdfunctions.mqh*/    bool     DeleteIniKey   (string fileName, string section, string key);

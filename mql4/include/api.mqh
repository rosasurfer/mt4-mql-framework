/**
 * Nach Funktionalität gruppierter Überblick aller in MQL zusätzlich zur Verfügung stehenden Funktionen und der jeweils benötigten Library.
 */

                        // Konfiguration
/*stdlib1.ex4     */    string   GetLocalConfigPath();
/*stdlib1.ex4     */    string   GetGlobalConfigPath();

/*stdfunctions.mqh*/    bool     IsConfigKey      (string section, string key);
/*stdlib1.ex4     */    bool     IsLocalConfigKey (string section, string key);
/*stdlib1.ex4     */    bool     IsGlobalConfigKey(string section, string key);

/*stdfunctions.mqh*/ ok bool     GetConfigBool           (string section, string key, bool   defaultValue);
/*                */    int      GetConfigInt            (string section, string key, int    defaultValue);
/*                */    double   GetConfigDouble         (string section, string key, double defaultValue);
/*stdfunctions.mqh*/ ok string   GetConfigString         (string section, string key, string defaultValue);
/*stdfunctions.mqh*/ ok string   GetRawConfigString      (string section, string key, string defaultValue);

/*stdfunctions.mqh*/ ok bool     GetLocalConfigBool      (string section, string key, bool   defaultValue);
/*                */    int      GetLocalConfigInt       (string section, string key, int    defaultValue);
/*                */    double   GetLocalConfigDouble    (string section, string key, double defaultValue);
/*stdfunctions.mqh*/ ok string   GetLocalConfigString    (string section, string key, string defaultValue);
/*stdfunctions.mqh*/ ok string   GetRawLocalConfigString (string section, string key, string defaultValue);

/*stdfunctions.mqh*/ ok bool     GetGlobalConfigBool     (string section, string key, bool   defaultValue);
/*                */    int      GetGlobalConfigInt      (string section, string key, int    defaultValue);
/*                */    double   GetGlobalConfigDouble   (string section, string key, double defaultValue);
/*stdfunctions.mqh*/ ok string   GetGlobalConfigString   (string section, string key, string defaultValue);
/*stdfunctions.mqh*/ ok string   GetRawGlobalConfigString(string section, string key, string defaultValue);

/*stdfunctions.mqh*/ ok bool     GetIniBool     (string fileName, string section, string key, bool   defaultValue);
/*                */    int      GetIniInt      (string fileName, string section, string key, int    defaultValue);
/*                */    double   GetIniDouble   (string fileName, string section, string key, double defaultValue);
/*stdfunctions.mqh*/ ok string   GetIniString   (string fileName, string section, string key, string defaultValue);
/*stdlib1.ex4     */ ok string   GetRawIniString(string fileName, string section, string key, string defaultValue);

/*                */    int      GetIniSections (string fileName, string sections[]);
/*stdlib2.ex4     */    int      GetIniKeys     (string fileName, string section, string keys[]);

/*                */    bool     IsIniSection   (string fileName, string section);
/*                */    bool     IsIniKey       (string fileName, string section, string key);

/*stdfunctions.mqh*/    bool     DeleteIniKey   (string fileName, string section, string key);

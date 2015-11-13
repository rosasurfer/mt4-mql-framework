/**
 * Nach Funktionalität gruppierter Überblick aller in MQL zusätzlich zur Verfügung stehenden Funktionen und der jeweils benötigten Library.
 */

                        // Konfiguration
/*stdlib1.ex4     */    string   GetLocalConfigPath();
/*stdlib1.ex4     */    string   GetGlobalConfigPath();

/*stdfunctions.mqh*/    bool     IsConfigKey      (string section, string key);
/*stdlib1.ex4     */    bool     IsLocalConfigKey (string section, string key);
/*stdlib1.ex4     */    bool     IsGlobalConfigKey(string section, string key);

/*stdfunctions.mqh*/    bool     GetConfigBool           (string section, string key, bool   defaultValue);
/*                */    int      GetConfigInt            (string section, string key, int    defaultValue);
/*                */    double   GetConfigDouble         (string section, string key, double defaultValue);
/*                */    string   GetConfigString         (string section, string key, string defaultValue);
/*                */    string   GetRawConfigString      (string section, string key, string defaultValue);

/*stdfunctions.mqh*/    bool     GetLocalConfigBool      (string section, string key, bool   defaultValue);
/*                */    int      GetLocalConfigInt       (string section, string key, int    defaultValue);
/*                */    double   GetLocalConfigDouble    (string section, string key, double defaultValue);
/*                */    string   GetLocalConfigString    (string section, string key, string defaultValue);
/*                */    string   GetRawLocalConfigString (string section, string key, string defaultValue);

/*stdfunctions.mqh*/    bool     GetGlobalConfigBool     (string section, string key, bool   defaultValue);
/*                */    int      GetGlobalConfigInt      (string section, string key, int    defaultValue);
/*                */    double   GetGlobalConfigDouble   (string section, string key, double defaultValue);
/*                */    string   GetGlobalConfigString   (string section, string key, string defaultValue);
/*                */    string   GetRawGlobalConfigString(string section, string key, string defaultValue);

/*                */    bool     GetIniBool     (string fileName, string section, string key, bool   defaultValue);
/*                */    int      GetIniInt      (string fileName, string section, string key, int    defaultValue);
/*                */    double   GetIniDouble   (string fileName, string section, string key, double defaultValue);
/*stdfunctions.mqh*/    string   GetIniString   (string fileName, string section, string key, string defaultValue);
/*                */    string   GetRawIniString(string fileName, string section, string key, string defaultValue);

/*                */    int      GetIniSections (string fileName, string sections[]);
/*stdlib2.ex4     */    int      GetIniKeys     (string fileName, string section, string keys[]);

/*                */    bool     IsIniSection   (string fileName, string section);
/*                */    bool     IsIniKey       (string fileName, string section, string key);

/*stdfunctions.mqh*/    bool     DeleteIniKey   (string fileName, string section, string key);

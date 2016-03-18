/**
 * TestScript2
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[] = { INIT_DOESNT_REQUIRE_BARS };
int __DEINIT_FLAGS__[];
#include <core/script.mqh>
#include <stdfunctions.mqh>
#include <stdlib.mqh>
#include <functions/InitializeByteBuffer.mqh>
#include <structs/mt4/SYMBOL_GROUP.mqh>


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int onInit() {
   return(last_error);
}


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {

   // Symbol erzeugen
   string symbol         = "MyFX E~001.";
   int    counter        = 1;
   string description    = "MyFX Example MA "+ StringPadLeft(counter, 3, "0") + TimeToStr(GetLocalTime(), TIME_FULL);
   string groupName      = "MyFX Example MA";
   int    digits         = 2;
   string baseCurrency   = AccountCurrency();
   string marginCurrency = AccountCurrency();
   string serverName     = "MyFX-Testresults";

   int id = Symbol.Create(symbol, description, groupName, digits, baseCurrency, marginCurrency, serverName);

   debug("onStart()  id="+ id);

   return(NO_ERROR);
}


/**
 * Erzeugt in der Konfiguration des angegebenen AccountServers ein neues Symbol.
 *
 * @param  string symbol         - Symbol
 * @param  string description    - Symbolbeschreibung
 * @param  string groupname      - Name der Gruppe, in der das Symbol gelistet wird
 * @param  int    digits         - Digits
 * @param  string baseCurrency   - Basiswährung
 * @param  string marginCurrency - Marginwährung
 * @param  string serverName     - Name des Accountservers, in dessen Konfiguration das Symbol angelegt wird (default: der aktuelle AccountServer)
 *
 * @return int - ID des Symbols (Wert >= 0) oder -1, falls ein Fehler auftrat (z.B. wenn das angegebene Symbol bereits existiert)
 */
int Symbol.Create(string symbol, string description, string groupName, int digits, string baseCurrency, string marginCurrency, string serverName="") {
   int   groupIndex;
   color groupColor = CLR_NONE;

   // alle Symbolgruppen einlesen
   /*SYMBOL_GROUP[]*/int sgs[];
   int size = GetSymbolGroups(sgs, serverName);

   // angegebene Gruppe suchen
   for (int i=0; i < size; i++) {
      if (sgs_Name(sgs, i) == groupName)
         break;
   }
   if (i == size) {                                                  // Gruppe nicht gefunden, neu anlegen
      i = AddSymbolGroup(sgs, groupName, groupName, groupColor); if (i < 0) return(-1);
      if (!SaveSymbolGroups(sgs, serverName))                               return(-1);
   }
   groupIndex = i;
   groupColor = sgs_BackgroundColor(sgs, i);

   // Symbol alegen
   /*SYMBOL*/int sym[]; InitializeByteBuffer(sym, SYMBOL.size);
   sym.setTemplate       (sym, SYMBOL_TYPE_INDEX);                   // Template mit allen notwendigen Defaultwerten
   sym_setName           (sym, symbol           );
   sym_setDescription    (sym, description      );
   sym_setDigits         (sym, digits           );
   sym_setBaseCurrency   (sym, baseCurrency     );
   sym_setMarginCurrency (sym, marginCurrency   );
   sym_setGroup          (sym, groupIndex       );
   sym_setBackgroundColor(sym, groupColor       );

   int id = Symbol.Save(sym, serverName); if (id < 0) return(-1);    // weist automatisch SYMBOL.id zu und aktualisiert Struct
   return(id);
}


/**
 * Gibt alle Symbolgruppen des angegebenen AccountServers zurück.
 *
 * @param  SYMBOL_GROUP sgs[]      - Array zur Aufnahme der eingelesenen Symbolgruppen
 * @param  string       serverName - Name des AccountServers (default: der aktuelle AccountServer)
 *
 * @return int - Anzahl der gelesenen Gruppen oder -1 (EMPTY), falls ein Fehler auftrat
 */
int GetSymbolGroups(/*SYMBOL_GROUP*/int sgs[], string serverName="") {
   if (serverName == "0")      serverName = "";                      // (string) NULL
   if (!StringLen(serverName)) serverName = GetServerName(); if (serverName == "") return(_EMPTY(SetLastError(stdlib.GetLastError())));

   ArrayResize(sgs, 0);

   // (1) "symgroups.raw" auf Existenz prüfen                        // Extra-Prüfung, da bei Read-only-Zugriff FileOpen[History]() bei nicht existierender
   string mqlFileName = ".history\\"+ serverName +"\\symgroups.raw"; // Datei das Log mit Warnungen ERR_CANNOT_OPEN_FILE überschwemmt.
   if (!IsMqlFile(mqlFileName))
      return(0);

   // (2) Datei öffnen und Größe validieren
   int hFile = FileOpen(mqlFileName, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)  return(_EMPTY(catch("GetSymbolGroups(1)->FileOpen(\""+ mqlFileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR))));
   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL_GROUP.size != 0) {
      FileClose(hFile);               return(_EMPTY(catch("GetSymbolGroups(2)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL_GROUP size, "+ (fileSize % SYMBOL_GROUP.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR))));
   }
   if (!fileSize) { FileClose(hFile); return(0); }                   // Eine leere Datei wird akzeptiert. Eigentlich muß sie immer 32 * SYMBOL_GROUP.size groß sein,
                                                                     // doch im Moment der Erstellung (von jemand anderem) kann sie vorübergehend 0 Bytes groß sein.
   // (3) Datei einlesen
   InitializeByteBuffer(sgs, fileSize);
   int ints = FileReadArray(hFile, sgs, 0, fileSize/4);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=fileSize/4) return(_EMPTY(catch("GetSymbolGroups(3)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR))));

   return(fileSize/SYMBOL_GROUP.size);
}


/**
 * Fügt einer Liste von Symbolgruppen eine weitere hinzu. Die Gruppe wird an der ersten verfügbaren Position der Liste gespeichert.
 *
 * @param  SYMBOL_GROUP sgs[] - Liste von Symbolgruppen, der die neue Gruppe hinzugefügt werden soll
 * @param  string name        - Gruppenname
 * @param  string description - Gruppenbeschreibung
 * @param  color  bgColor     - Hintergrundfarbe der Symbolgruppe im "Market Watch"-Window
 *
 * @return int - Index der Gruppe innerhalb der Liste oder -1 (EMPTY), falls ein Fehler auftrat (z.B. wenn die angegebene Gruppe bereits existiert)
 */
int AddSymbolGroup(/*SYMBOL_GROUP*/int sgs[], string name, string description, color bgColor) {
   int size = ArraySize(sgs) * 4;
   if (size % SYMBOL_GROUP.size != 0)               return(_EMPTY(catch("AddSymbolGroup(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (size % SYMBOL_GROUP.size) +" trailing bytes)", ERR_RUNTIME_ERROR)));
   if (name == "0") name = "";                                       // (string) NULL
   if (!StringLen(name))                            return(_EMPTY(catch("AddSymbolGroup(2)  invalid parameter name = "+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER)));
   if (description == "0") description = "";                         // (string) NULL
   if (bgColor != CLR_NONE && bgColor & 0xFF000000) return(_EMPTY(catch("AddSymbolGroup(3)  invalid parameter bgColor = 0x"+ IntToHexStr(bgColor) +" (not a color)", ERR_INVALID_PARAMETER)));

   // überprüfen, ob die angegebene Gruppe bereits existiert und dabei den ersten freien Index ermitteln
   int groupsSize = size/SYMBOL_GROUP.size;
   int iFree = -1;
   for (int i=0; i < groupsSize; i++) {
      string foundName = sgs_Name(sgs, i);
      if (name == foundName)                        return(_EMPTY(catch("AddSymbolGroup(4)  a group named "+ DoubleQuoteStr(name) +" already exists", ERR_RUNTIME_ERROR)));
      if (iFree==-1) /*&&*/ if (foundName=="")
         iFree = i;
   }

   // ohne freien Index das Array entsprechend vergrößern
   if (iFree == -1) {
      ArrayResize(sgs, (groupsSize+1)*SYMBOL_GROUP.size);
      iFree = groupsSize;
      groupsSize++;
   }

   // neue Gruppe an freiem Index speichern
   if (  StringIsNull(sgs_setName           (sgs, iFree, name       ))) return(_EMPTY(catch("AddSymbolGroup(5)  failed to set name "+ DoubleQuoteStr(name), ERR_RUNTIME_ERROR)));
   if (  StringIsNull(sgs_setDescription    (sgs, iFree, description))) return(_EMPTY(catch("AddSymbolGroup(6)  failed to set description "+ DoubleQuoteStr(description), ERR_RUNTIME_ERROR)));
   if (EMPTY_COLOR == sgs_setBackgroundColor(sgs, iFree, bgColor    ))  return(_EMPTY(catch("AddSymbolGroup(7)  failed to set backgroundColor 0x"+ IntToHexStr(bgColor), ERR_RUNTIME_ERROR)));

   return(iFree);
}


/**
 * Speichert die Liste von Symbolgruppen in der angegebenen AccountServer-Konfiguration. Eine existierende Konfiguration wird überschrieben.
 *
 * @param  SYMBOL_GROUP sgs[]      - Liste von Symbolgruppen
 * @param  string       serverName - Name des Accountservers, in dessen Konfiguration die Gruppen gespeichert werden (default: der aktuelle AccountServer)
 *
 * @return bool - Erfolgsstatus
 */
bool SaveSymbolGroups(/*SYMBOL_GROUP*/int sgs[], string serverName="") {
   int byteSize = ArraySize(sgs) * 4;
   if (byteSize % SYMBOL_GROUP.size != 0)                                          return(!catch("SaveSymbolGroups(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (byteSize % SYMBOL_GROUP.size) +" trailing bytes)", ERR_RUNTIME_ERROR));
   if (serverName == "0")      serverName = "";                      // (string) NULL
   if (!StringLen(serverName)) serverName = GetServerName(); if (serverName == "") return(!SetLastError(stdlib.GetLastError()));

   // Datei öffnen                                                  // TODO: Verzeichnis überprüfen und ggf. erstellen
   string mqlFileName = ".history\\"+ serverName +"\\symgroups.raw";
   int hFile = FileOpen(mqlFileName, FILE_WRITE|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)  return(!catch("SaveSymbolGroups(2)->FileOpen(\""+ mqlFileName +"\", FILE_WRITE) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));

   // Daten schreiben
   int arraySize = ArraySize(sgs);
   int ints = FileWriteArray(hFile, sgs, 0, arraySize);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=arraySize) return(!catch("SaveSymbolGroups(3)  error writing SYMBOL_GROUP[] to \""+ mqlFileName +"\" ("+ ints*4 +" of "+ byteSize +" bytes written)", ifInt(error, error, ERR_RUNTIME_ERROR)));
   return(true);
}


/**
 *
 */
int Symbol.Save(/*SYMBOL*/int symbol[], string server="") {
   catch("Symbol.Save(1)", ERR_NOT_IMPLEMENTED);
   return(-1);
}


/**
 *
 */
bool sym.setTemplate(/*SYMBOL*/int symbol[], int type) {
   catch("sym.setTemplate()", ERR_NOT_IMPLEMENTED);
   return(false);
}


/**
 *
 */
string sym_setName(/*SYMBOL*/int symbol[], string name) {
   catch("sym_setName()", ERR_NOT_IMPLEMENTED);
   return(EMPTY_STR);
}


/**
 *
 */
string sym_setDescription(/*SYMBOL*/int symbol[], string description) {
   catch("sym_setDescription()", ERR_NOT_IMPLEMENTED);
   return(EMPTY_STR);
}


/**
 *
 */
int sym_setDigits(/*SYMBOL*/int symbol[], int digits) {
   catch("sym_setDigits()", ERR_NOT_IMPLEMENTED);
   return(-1);
}


/**
 *
 */
string sym_setBaseCurrency(/*SYMBOL*/int symbol[], string currency) {
   catch("sym_setBaseCurrency()", ERR_NOT_IMPLEMENTED);
   return(EMPTY_STR);
}


/**
 *
 */
string sym_setMarginCurrency(/*SYMBOL*/int symbol[], string currency) {
   catch("sym_setMarginCurrency()", ERR_NOT_IMPLEMENTED);
   return(EMPTY_STR);
}


/**
 *
 */
int sym_setGroup(/*SYMBOL*/int symbol[], int groupId) {
   catch("sym_setGroup()", ERR_NOT_IMPLEMENTED);
   return(-1);
}


/**
 *
 */
int sym_setBackgroundColor(/*SYMBOL*/int symbol[], color bgColor) {
   catch("sym_setBackgroundColor()", ERR_NOT_IMPLEMENTED);
   return(CLR_NONE);
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int onDeinit() {
   return(last_error);
}
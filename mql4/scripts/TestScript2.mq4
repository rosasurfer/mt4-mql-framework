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
#include <structs/mt4/SYMBOL.mqh>
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
   int    counter        = 4;
   string symbol         = "MyFX E~"+ StringPadLeft(counter, 3, "0") +".";
   string description    = "MyFX Example MA "+ StringPadLeft(counter, 3, "0") +"."+ TimeToStr(GetLocalTime(), TIME_FULL);
   string groupName      = "MyFX Example MA";
   int    digits         = 2;
   string baseCurrency   = "USD";
   string marginCurrency = "USD";
   string serverName     = "MyFX-Testresults";

   int id = CreateSymbol(symbol, description, groupName, digits, baseCurrency, marginCurrency, serverName);

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
int CreateSymbol(string symbolName, string description, string groupName, int digits, string baseCurrency, string marginCurrency, string serverName="") {
   int   groupIndex;
   color groupColor = CLR_NONE;

   // alle Symbolgruppen einlesen
   /*SYMBOL_GROUP[]*/int sgs[];
   int size = GetSymbolGroups(sgs, serverName); if (size < 0) return(-1);

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
   /*SYMBOL*/int symbol[]; InitializeByteBuffer(symbol, SYMBOL.size);
   if (!SetSymbolTemplate        (symbol, SYMBOL_TYPE_INDEX)) return(-1);
   if (!symbol_SetName           (symbol, symbolName       )) return(_EMPTY(catch("CreateSymbol(1)->symbol_SetName() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetDescription    (symbol, description      )) return(_EMPTY(catch("CreateSymbol(2)->symbol_SetDescription() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetDigits         (symbol, digits           )) return(_EMPTY(catch("CreateSymbol(3)->symbol_SetDigits() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetBaseCurrency   (symbol, baseCurrency     )) return(_EMPTY(catch("CreateSymbol(4)->symbol_SetBaseCurrency() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetMarginCurrency (symbol, marginCurrency   )) return(_EMPTY(catch("CreateSymbol(5)->symbol_SetMarginCurrency() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetGroup          (symbol, groupIndex       )) return(_EMPTY(catch("CreateSymbol(6)->symbol_SetGroup() => FALSE", ERR_RUNTIME_ERROR)));
   if (!symbol_SetBackgroundColor(symbol, groupColor       )) return(_EMPTY(catch("CreateSymbol(7)->symbol_SetBackgroundColor() => FALSE", ERR_RUNTIME_ERROR)));

   if (!InsertSymbol(symbol, serverName)) return(-1);
   return(symbol_Id(symbol));
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
   int byteSize = ArraySize(sgs) * 4;
   if (byteSize % SYMBOL_GROUP.size != 0)         return(_EMPTY(catch("AddSymbolGroup(1)  invalid size of sgs[] (not an even SYMBOL_GROUP size, "+ (byteSize % SYMBOL_GROUP.size) +" trailing bytes)", ERR_RUNTIME_ERROR)));
   if (name == "0") name = "";                    // (string) NULL
   if (!StringLen(name))                          return(_EMPTY(catch("AddSymbolGroup(2)  invalid parameter name = "+ DoubleQuoteStr(name), ERR_INVALID_PARAMETER)));
   if (description == "0") description = "";      // (string) NULL
   if (bgColor!=CLR_NONE && bgColor & 0xFF000000) return(_EMPTY(catch("AddSymbolGroup(3)  invalid parameter bgColor = 0x"+ IntToHexStr(bgColor) +" (not a color)", ERR_INVALID_PARAMETER)));

   // überprüfen, ob die angegebene Gruppe bereits existiert und dabei den ersten freien Index ermitteln
   int groupsSize = byteSize/SYMBOL_GROUP.size;
   int iFree = -1;
   for (int i=0; i < groupsSize; i++) {
      string foundName = sgs_Name(sgs, i);
      if (name == foundName)                      return(_EMPTY(catch("AddSymbolGroup(4)  a group named "+ DoubleQuoteStr(name) +" already exists", ERR_RUNTIME_ERROR)));
      if (iFree==-1) /*&&*/ if (foundName=="")
         iFree = i;
   }

   // ohne freien Index das Array entsprechend vergrößern
   if (iFree == -1) {
      ArrayResize(sgs, (groupsSize+1)*SYMBOL_GROUP.intSize);
      iFree = groupsSize;
      groupsSize++;
   }

   // neue Gruppe erstellen und an freien Index kopieren
   /*SYMBOL_GROUP*/int sg[]; InitializeByteBuffer(sg, SYMBOL_GROUP.size);
   if (!sg_SetName           (sg, name       )) return(_EMPTY(catch("AddSymbolGroup(5)->sg_SetName() => FALSE", ERR_RUNTIME_ERROR)));
   if (!sg_SetDescription    (sg, description)) return(_EMPTY(catch("AddSymbolGroup(6)->sg_SetDescription() => FALSE", ERR_RUNTIME_ERROR)));
   if (!sg_SetBackgroundColor(sg, bgColor    )) return(_EMPTY(catch("AddSymbolGroup(7)->sg_SetBackgroundColor() => FALSE", ERR_RUNTIME_ERROR)));

   int src  = GetIntsAddress(sg);
   int dest = GetIntsAddress(sgs) + iFree*SYMBOL_GROUP.size;
   CopyMemory(dest, src, SYMBOL_GROUP.size);
   ArrayResize(sg, 0);

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

   // Datei öffnen                                                   // TODO: Verzeichnis überprüfen und ggf. erstellen
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
 * Kopiert das Template des angegebenen Symbol-Typs in das übergebene Symbol.
 *
 * @param  SYMBOL symbol[] - Symbol
 * @param  int    type     - Symbol-Typ
 *
 * @return bool - Erfolgsstatus
 */
bool SetSymbolTemplate(/*SYMBOL*/int symbol[], int type) {
   // Parameter validieren und Template-Datei bestimmen
   string fileName;
   switch (type) {
      case SYMBOL_TYPE_FOREX  : fileName = "templates/SYMBOL_TYPE_FOREX.raw";   break;
      case SYMBOL_TYPE_CFD    : fileName = "templates/SYMBOL_TYPE_CFD.raw";     break;
      case SYMBOL_TYPE_INDEX  : fileName = "templates/SYMBOL_TYPE_INDEX.raw";   break;
      case SYMBOL_TYPE_FUTURES: fileName = "templates/SYMBOL_TYPE_FUTURES.raw"; break;

      default: return(!catch("SetSymbolTemplate(1)  invalid parameter type = "+ type +" (not a symbol type)", ERR_INVALID_PARAMETER));
   }

   // Template-File auf Existenz prüfen                              // Extra-Prüfung, da bei Read-only-Zugriff FileOpen() bei nicht existierender
   if (!IsMqlFile(fileName))                                         // Datei das Log mit Warnungen ERR_CANNOT_OPEN_FILE zumüllt.
      return(false);

   // Datei öffnen und Größe validieren
   int hFile = FileOpen(fileName, FILE_READ|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0)       return(!catch("SetSymbolTemplate(2)->FileOpen(\""+ fileName +"\", FILE_READ) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));
   int fileSize = FileSize(hFile);
   if (fileSize != SYMBOL.size) {
      FileClose(hFile);                    return(!catch("SetSymbolTemplate(3)  invalid size "+ fileSize +" of \""+ fileName +"\" (not a SYMBOL size)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR)));
   }

   // Datei in das übergebene Symbol einlesen
   InitializeByteBuffer(symbol, fileSize);
   int ints = FileReadArray(hFile, symbol, 0, fileSize/4);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=fileSize/4) return(!catch("SetSymbolTemplate(3)  error reading \""+ fileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR)));

   return(true);
}


/**
 * Fügt das Symbol der angegebenen AccountServer-Konfiguration hinzu.
 *
 * @param  SYMBOL symbol[]   - Symbol
 * @param  string serverName - Name des Accountservers (default: der aktuelle AccountServer)
 *
 * @return bool - Erfolgsstatus
 */
bool InsertSymbol(/*SYMBOL*/int symbol[], string serverName="") {
   if (ArraySize(symbol) != SYMBOL.intSize)                                        return(!catch("InsertSymbol(1)  invalid size "+ ArraySize(symbol) +" of parameter symbol[] (not SYMBOL.intSize)", ERR_RUNTIME_ERROR));
   string name, newName=symbol_Name(symbol);
   if (!StringLen(newName))                                                        return(!catch("InsertSymbol(2)  invalid parameter symbol[], SYMBOL.name = "+ DoubleQuoteStr(newName), ERR_RUNTIME_ERROR));
   if (serverName == "0")      serverName = "";    // (string) NULL
   if (!StringLen(serverName)) serverName = GetServerName(); if (serverName == "") return(!SetLastError(stdlib.GetLastError()));


   // (1) vorhandene Symbole einlesen
   string mqlFileName = ".history\\"+ serverName +"\\symbols.raw";
   int hFile = FileOpen(mqlFileName, FILE_READ|FILE_WRITE|FILE_BIN);
   int error = GetLastError();
   if (IsError(error) || hFile <= 0) return(!catch("InsertSymbol(3)->FileOpen(\""+ mqlFileName +"\", FILE_READ|FILE_WRITE) => "+ hFile, ifInt(error, error, ERR_RUNTIME_ERROR)));
   int fileSize = FileSize(hFile);
   if (fileSize % SYMBOL.size != 0) {
      FileClose(hFile); return(!catch("InsertSymbol(4)  invalid size of \""+ mqlFileName +"\" (not an even SYMBOL size, "+ (fileSize % SYMBOL.size) +" trailing bytes)", ifInt(SetLastError(GetLastError()), last_error, ERR_RUNTIME_ERROR)));
   }
   /*SYMBOL[]*/int symbols[]; InitializeByteBuffer(symbols, fileSize);
   int symbolsSize = fileSize/SYMBOL.size;

   if (fileSize > 0) {
      // (1.1) Datei einlesen
      int ints = FileReadArray(hFile, symbols, 0, fileSize/4);
      error = GetLastError();
      if (IsError(error) || ints!=fileSize/4) {
         FileClose(hFile); return(!catch("InsertSymbol(5)  error reading \""+ mqlFileName +"\" ("+ ints*4 +" of "+ fileSize +" bytes read)", ifInt(error, error, ERR_RUNTIME_ERROR)));
      }
      // (1.2) sicherstellen, daß das Symbol noch nicht existiert
      for (int i=0; i < symbolsSize; i++) {
         if (symbols_Name(symbols, i) == newName) {
            FileClose(hFile); return(!catch("InsertSymbol(6)   a symbol named "+ DoubleQuoteStr(newName) +" already exists", ERR_RUNTIME_ERROR));
         }
      }
   }


   // (2) Symbol am Ende anfügen
   ArrayResize(symbols, (symbolsSize+1)*SYMBOL.intSize);
   i = symbolsSize;
   symbolsSize++;
   int src  = GetIntsAddress(symbol);
   int dest = GetIntsAddress(symbols) + i*SYMBOL.size;
   CopyMemory(dest, src, SYMBOL.size);


   // (3) Array sortieren
   if (symbolsSize > 1) /*&&*/ if (!symbols_Sort(symbols, symbolsSize)) {
      FileClose(hFile); return(!catch("InsertSymbol(7)->symbols_Sort() => FALSE (error sorting symbols)", ERR_RUNTIME_ERROR));
   }


   // (4) Symbol-ID's neu zuordnen und dabei die ID des hinzugefügten Symbols ermitteln
   int id = -1;
   for (i=0; i < symbolsSize; i++) {
      if (!symbols_SetId(symbols, i, i+1)) { FileClose(hFile); return(!catch("InsertSymbol(8)->symbols_SetId() => FALSE", ERR_RUNTIME_ERROR)); }
      if (id==-1) /*&&*/ if (symbols_Name(symbols, i) == newName)
         id = i+1;
   }


   // (5) alle Symbole speichern
   if (!FileSeek(hFile, 0, SEEK_SET)) {
      FileClose(hFile); return(!catch("InsertSymbol(9)->FileSeek(hFile, 0, SEEK_SET) => FALSE", ERR_RUNTIME_ERROR));
   }
   int elements = symbolsSize * SYMBOL.size / 4;
   ints  = FileWriteArray(hFile, symbols, 0, elements);
   error = GetLastError();
   FileClose(hFile);
   if (IsError(error) || ints!=elements) return(!catch("InsertSymbol(10)  error writing SYMBOL[] to \""+ mqlFileName +"\" ("+ ints*4 +" of "+ symbolsSize*SYMBOL.size +" bytes written)", ifInt(error, error, ERR_RUNTIME_ERROR)));


   // (6) erst ganz zum Schluß die ID des hinzugefügten Symbols lokal aktualisieren
   if (!symbol_SetId(symbol, id)) return(!catch("InsertSymbol(11)->symbol_SetId() => FALSE", ERR_RUNTIME_ERROR));

   return(true);
}
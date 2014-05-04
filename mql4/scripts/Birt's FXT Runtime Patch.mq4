/**
 * Birt's FXT Runtime Patch
 *
 * Überarbeitete Version seiner Originalversion vom 11.09.2011. Die Funktionalität selbst ist unverändert.
 *
 * @author  Cristi Dumitrescu <birt@eareview.net>
 * @see     http://eareview.net/tickdata
 */
#include <stddefine.mqh>
int   __INIT_FLAGS__[];
int __DEINIT_FLAGS__[];
#include <stdlib.mqh>
#include <core/script.mqh>

#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern bool   Dont.Overwrite.FXT.Files       = true;
extern string _1____________________________ = "The 2GB limit removal works in Windows Vista, 7 and Server 2008 only.";
extern bool   Remove.2GB.Limit               = false;
extern string _2____________________________ = "The variable spread option requires variable spread FXT files.";
extern bool   Use.Variable.Spread.Files      = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


#define LAST_BUILD_KNOWN   406


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int onStart() {
   int version = GetTerminalBuild();
   if (!version)
      return(SetLastError(stdlib_GetLastError()));

   Print("MT4 build "+ version +" detected.");

   if (version > LAST_BUILD_KNOWN) {
      Print("The patch you are running was not tested with this build so it may or may not work.");
      Print("Check for a new patch at http://eareview.net/tick-data");
   }

   if (Dont.Overwrite.FXT.Files)  DontOverwriteFXTPatch();
   if (Remove.2GB.Limit)          Remove2GBLimitPatch();
   if (Use.Variable.Spread.Files) VariableSpreadPatch();

   return(last_error);
}


/**
 *
 */
void DontOverwriteFXTPatch() {
   /*
   .00540E75: 83 C4 1C                          add     esp, 1Ch
   .00540E78: 85 C0                             test    eax, eax
   .00540E7A: 0F 85 EE 02 00 00                 jnz     loc_54116E
   */
   int search1[] = { 0x83, 0xc4, 0x1c, 0x85, 0xc0, 0x0f, 0x85 };     // 83c41c85c00f85

   /*
   .00540F92: 1B C0                             sbb     eax, eax
   .00540F94: 83 D8 FF                          sbb     eax, 0FFFFFFFFh
   .00540F97: 85 C0                             test    eax, eax
   .00540F99: 0F 85 9D 01 00 00                 jnz     loc_54113C
   */
   int search2[]  = { 0x1b, 0xc0, 0x83, 0xd8, 0xff, 0x85, 0xc0, 0x0f, 0x85, 0x9d, 0x01, 0x00, 0x00 };    // 1bc083d8ff85c00f859d010000
   // builds 405+                                                              ^
   int search2a[] = { 0x1b, 0xc0, 0x83, 0xd8, 0xff, 0x85, 0xc0, 0x0f, 0x85, 0x9b, 0x01, 0x00, 0x00 };    // 1bc083d8ff85c00f859b010000

   /*
   .0054109A: 8B 42 18                          mov     eax, [edx+18h]
   .0054109D: 85 C0                             test    eax, eax
   .0054109F: 0F 85 97 00 00 00                 jnz     loc_54113C
   */
   int search3[] = { 0x8b, 0x42, 0x18, 0x85, 0xc0, 0x0f, 0x85 };

   int patchAddr1 = FindMemoryAddress(0x510000, 0x570000, search1);
   if (patchAddr1 != 0) {
      int patchAddr2 = FindMemoryAddress(patchAddr1, patchAddr1 + 32768, search2);
      if (!patchAddr2)
         patchAddr2 = FindMemoryAddress(patchAddr1, patchAddr1 + 32768, search2a);

      int patchAddr3 = FindMemoryAddress(patchAddr1, patchAddr1 + 32768, search3);
   }

   if (patchAddr1!=0 && patchAddr2!=0 && patchAddr3!=0) {
      int patch[] = { 0x00, 0x00 };
      PatchProcess(patchAddr1 + 7, patch);
      PatchProcess(patchAddr2 + 9, patch);
      PatchProcess(patchAddr3 + 7, patch);
      Print("FXT overwriting disabled. Addresses patched: 0x"+ IntToHexStr(patchAddr1) +", 0x"+ IntToHexStr(patchAddr2) +", 0x"+ IntToHexStr(patchAddr3) +".");
   }
   else {
      Print("FXT overwriting already disabled or unable to find the location to patch.");
   }
   catch("DontOverwriteFXTPatch()");
}


/**
 *
 */
void Remove2GBLimitPatch() {
   int iNull[];

   int va__allmul, va__fseeki64;    // virtual function addresses

   int hModule = LoadLibraryA("ntdll.dll");
   if (hModule != 0) {
      va__allmul = GetProcAddress(hModule, "_allmul");
      if (!va__allmul) {
         Alert("2GB limit removal not activated (could not find function _allmul() in ntdll.dll)");
         catch("Remove2GBLimitPatch(1)");
         return;
      }
   }

   if (GetTerminalBuild() < 399) {
      hModule = LoadLibraryA("msvcrt.dll");
      if (hModule != 0) {
         va__fseeki64 = GetProcAddress(hModule, "_fseeki64");
         if (!va__fseeki64) {
            Alert("The 2GB limit removal for this build works only in Windows 7, Vista and Server 2008.");
            Alert("2GB limit removal not activated (could not find function fseeki64() in msvcrt.dll)");
            catch("Remove2GBLimitPatch(2)");
            return;
         }
      }
      /*
      .00541436: 8D 14 40                       lea     edx, [eax+eax*2]
      .00541439: 8D 04 90                       lea     eax, [eax+edx*4]
      .0054143C: C1 E0 02                       shl     eax, 2
      .0054143F: 50                             push    eax                // Offset
      .00541440: 51                             push    ecx                // File
      .00541441: FF 15 98 4D 56 00              call    ds:fseek           // themida messes it up in 226+
      */
      int search[] = { 0x8d, 0x14, 0x40, 0x8d, 0x04, 0x90, 0xc1, 0xe0, 0x02, 0x50, 0x51 };   // 8d14408d0490c1e0025051
      int patcharea = FindMemoryAddress(0x510000, 0x570000, search);
      if (!patcharea) {
         Print("Process already patched for the 2GB limit removal or we just can't find the area to patch.");
         catch("Remove2GBLimitPatch(3)");
         return;
      }
      int patchaddr = patcharea;
      int calcbase  = patchaddr + 5;
      /*
      .0054144C: 74 0A                          jz      short loc_541458
      */
      int search2[] = { 0x74, 0x0a };           // 740a
      int returnaddr = FindMemoryAddress(patcharea, patchaddr + 1024, search2);
      if (!returnaddr) {
         Print("Can't locate return address for 2GB patch limit removal, skipping patch.");
         catch("Remove2GBLimitPatch(4)");
         return;
      }
      int byte[] = { 0xe9 };
      PatchProcess(patchaddr, byte);

      int new = VirtualAlloc(iNull, 256, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Print("Patch address found: 0x" + IntToHexStr(patcharea) + ". 2GB limit removal patch is being installed at 0x" + IntToHexStr(new) + ".");
      int offset = new - calcbase;
      int b[4];
      StoreDword(offset, b);
      PatchProcess(patchaddr + 1, b);

      /*
      .0054116E: 51                             push        ecx
      .0054116F: 6A00                           push        0
      .00541171: 50                             push        eax
      .00541172: 6A00                           push        0
      .00541174: 6A34                           push        34
      .00541176: FF15A0115400                   call        d,[0005411A0]
      .0054117C: 59                             pop         ecx
      .0054117D: 52                             push        edx
      .0054117E: 50                             push        eax
      .0054117F: 51                             push        ecx
      .00541180: FF15A4115400                   call        d,[0005411A4]
      .00541186: 83C410                         add         esp,00C
      .00541189: 85C0                           test        eax,eax
      .0054118B: E93C0E0000                     jmp         .000541FCC

      int patch[] = { 0x51, 0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34,
                      0xff, 0x15, 0xa0, 0x11, 0x54, 0x00,
                      0x59, 0x52, 0x50, 0x51,
                      0xff, 0x15, 0xa4, 0x11, 0x54, 0x00,
                      0x83, 0xc4, 0x0C,
                      0x85, 0xc0,
                      0xe9 };
      */
      int patch[] = { 0x51, 0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34, 0xff, 0x15, 0xa0, 0x11, 0x54, 0x00, 0x59, 0x52, 0x50, 0x51, 0xff, 0x15, 0xa4, 0x11, 0x54, 0x00, 0x83, 0xc4, 0x0C, 0x85, 0xc0, 0xe9 };

      PatchProcess(new, patch);
      StoreDword(va__fseeki64, b);
      PatchProcess(new + 128, b);               // _fseeki64 goes at the alloced memory area + 128
      StoreDword(va__allmul, b);
      PatchProcess(new + 132, b);               // _allmul goes at the alloced memory area + 132
      StoreDword(new + 132, b);
      PatchProcess(new + 10, b);                // fix the _allmul call
      StoreDword(new + 128, b);
      PatchProcess(new + 20, b);                // fix the _fseeki64 call
      offset = returnaddr - (new + 30 + 4);
      StoreDword(offset, b);
      PatchProcess(new + 30, b);                // fix the returning jump
   }

   else if (GetTerminalBuild() <= 402) {
      hModule = LoadLibraryA("msvcrt.dll");
      if (hModule != 0) {
         va__fseeki64 = GetProcAddress(hModule, "_fseeki64");
         if (!va__fseeki64) {
            Alert("The 2GB limit removal for this build works only in Windows 7, Vista and Server 2008.");
            Alert("2GB limit removal not activated (could not find function _fseeki64() in msvcrt.dll)");
            catch("Remove2GBLimitPatch(5)");
            return;
         }
      }
      /*
      build 399:
      .00547097: 8D 0C 40                       lea     ecx, [eax+eax*2]
      .0054709A: 8D 14 88                       lea     edx, [eax+ecx*4]
      .0054709D: 8B 86 D8 02 00 00              mov     eax, [esi+2D8h]
      .005470A3: C1 E2 02                       shl     edx, 2
      .005470A6: 52                             push    edx
      .005470A7: 50                             push    eax
      .005470A8: FF 15 38 AE 56 00              call    ds:fseek
      .005470AE: 83 C4 0C                       add     esp, 0Ch
      .005470B1: 85 C0                          test    eax, eax
      .005470B3: 74 0A                          jz      short loc_5470BF
      */
      int search3[] = { 0x8d, 0x0c, 0x40, 0x8d, 0x14, 0x88, 0x8b, 0x86, 0xd8, 0x02, 0x00 };
      patcharea = FindMemoryAddress(0x510000, 0x570000, search3);
      if (!patcharea) {
         Print("Process already patched for the 2GB limit removal or we just can't find the area to patch.");
         catch("Remove2GBLimitPatch(6)");
         return;
      }
      patchaddr = patcharea;
      calcbase = patchaddr + 5;
      int search4[] = { 0x74, 0x0A };
      returnaddr = FindMemoryAddress(patcharea, patchaddr + 1024, search4);
      if (!returnaddr) {
         Print("Can't locate return address for 2GB patch limit removal, skipping patch.");
         catch("Remove2GBLimitPatch(7)");
         return;
      }

      byte[0] = 0xe9;
      PatchProcess(patchaddr, byte);

      new = VirtualAlloc(iNull, 256, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Print("Patch address found: 0x" + IntToHexStr(patcharea) + ". 2GB limit removal patch is being installed at 0x" + IntToHexStr(new) + ".");
      offset = new - calcbase;
      StoreDword(offset, b);
      PatchProcess(patchaddr + 1, b);           // fix jump

      /*
      .005475E7: 6A00                           push        0
      .005475E9: 50                             push        eax
      .005475EA: 6A00                           push        0
      .005475EC: 6A34                           push        034 ;'4'
      .005475EE: FF1500000000                   call        d,[0] --?3
      .005475F4: 52                             push        edx
      .005475F5: 50                             push        eax
      .005475F6: 8B86D8020000                   mov         eax,[esi][0000002D8]
      .005475FC: 50                             push        eax
      .005475FD: FF1500000000                   call        d,[0] --?3
      .00547603: 83C410                         add         esp,010
      .00547606: 85C0                           test        eax,eax
      .00547608: E900000000                     jmp        .00054760D --?4

      int patch1[] = {  0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34,
                        0xff, 0x15, 0x00, 0x00, 0x00, 0x00,
                        0x52, 0x50,
                        0x8b, 0x86, 0xd8, 0x02, 0x00, 0x00,
                        0x50,
                        0xff, 0x15, 0x00, 0x00, 0x00, 0x00,
                        0x83, 0xc4, 0x10,
                        0x85, 0xc0,
                        0xe9, 0x00, 0x00, 0x00, 0x00 };
      */
      int patch1[] = {  0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34, 0xff, 0x15, 0x00, 0x00, 0x00, 0x00, 0x52, 0x50, 0x8b, 0x86, 0xd8, 0x02, 0x00, 0x00, 0x50, 0xff, 0x15, 0x00, 0x00, 0x00, 0x00, 0x83, 0xc4, 0x10, 0x85, 0xc0, 0xe9, 0x00, 0x00, 0x00, 0x00 };

      PatchProcess(new, patch1);
      StoreDword(va__fseeki64, b);
      PatchProcess(new + 128, b);                        // _fseeki64 goes at the alloced memory area + 128
      StoreDword(va__allmul, b);
      PatchProcess(new + 132, b);                        // _allmul goes at the alloced memory area + 132
      StoreDword(new + 132, b);
      PatchProcess(new + 9, b);                          // fix the _allmul call
      StoreDword(new + 128, b);
      PatchProcess(new + 24, b);                         // fix the _fseeki64 call
      offset = returnaddr - (new + ArraySize(patch1));
      StoreDword(offset, b);
      PatchProcess(new + ArraySize(patch1) - 4, b);      // fix the returning jump
   }

   else {   // GetTerminalBuild() >= 405
      int fseeki64;

      hModule = LoadLibraryA("msvcrt.dll");
      if (hModule != 0) fseeki64 = GetProcAddress(hModule, "_fseeki64");

      if (!fseeki64) {
         hModule = LoadLibraryA("msvcr80.dll");
         if (hModule != 0) fseeki64 = GetProcAddress(hModule, "_fseeki64");
      }
      if (!fseeki64) {
         hModule = LoadLibraryA("msvcr90.dll");
         if (hModule != 0) fseeki64 = GetProcAddress(hModule, "_fseeki64");
      }
      if (!fseeki64) {
         hModule = LoadLibraryA("msvcr100.dll");
         if (hModule != 0) fseeki64 = GetProcAddress(hModule, "_fseeki64");
      }
      if (!fseeki64) {
         Alert("");
         Alert("If you're using Windows XP, consider getting a copy of the Visual C 2010 runtime, available at http://www.microsoft.com/download/en/details.aspx?id=5555 (x86) and http://www.microsoft.com/download/en/details.aspx?id=14632 (x64).");
         Alert("2GB limit removal not activated (could not find function _fseeki64() in any of the msvcrt libraries)");
         catch("Remove2GBLimitPatch(8)");
         return;
      }
      int filelength = GetProcAddress(hModule, "_filelength");
      int fopen      = GetProcAddress(hModule, "fopen");
      int fclose     = GetProcAddress(hModule, "fclose");
      int fread      = GetProcAddress(hModule, "fread");
      /*
      .00556B84: 8D 14 40                       lea     edx, [eax+eax*2]
      .00556B87: 8D 04 90                       lea     eax, [eax+edx*4]
      .00556B8A: 53                             push    ebx
      .00556B8B: C1 E0 02                       shl     eax, 2
      .00556B8E: 50                             push    eax
      .00556B8F: 51                             push    ecx
      .00556B90: E8 4D B5 02 00                 call    fseek
      */
      int search5[] = { 0x8d, 0x14, 0x40, 0x8d, 0x04, 0x90, 0x53, 0xc1, 0xe0, 0x02, 0x50, 0x51 };
      patcharea = FindMemoryAddress(0x510000, 0x570000, search5);
      if (!patcharea) {
         Print("Process already patched for the 2GB limit removal or we just can't find the area to patch.");
         catch("Remove2GBLimitPatch(9)");
         return;
      }

      /*
      // test
      int fseek = GetProcAddress(h, "fseek");
      if (!patcharea) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(10)");
         return;
      }
      Print("Patcharea: 0x"+ IntToHexStr(patcharea));
      patcharea += 17;
      offset = fseek - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchProcess(patcharea, b);
      */
      patchaddr = patcharea;
      calcbase = patchaddr + 6;
      /*
      .0054144C: 74 0A                          jz      short loc_541458
      */
      int search6[] = { 0x74, 0x0A };
      returnaddr = FindMemoryAddress(patcharea, patchaddr + 1024, search6);

      if (!returnaddr) {
         Print("Can't locate return address for 2GB patch limit removal, skipping patch.");
         catch("Remove2GBLimitPatch(11)");
         return;
      }
      int bytes[] = { 0x53, 0xe9 };
      PatchProcess(patchaddr, bytes);

      new = VirtualAlloc(iNull, 256, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Print("Patch address found: 0x" + IntToHexStr(patcharea) + ". 2gb limit removal patch is being installed at 0x" + IntToHexStr(new) + ".");
      offset = new - calcbase;
      StoreDword(offset, b);
      PatchProcess(patchaddr + 2, b);

      /*
      .0054116E: 51                             push        ecx
      .0054116F: 6A00                           push        0
      .00541171: 50                             push        eax
      .00541172: 6A00                           push        0
      .00541174: 6A34                           push        34
      .00541176: FF15A0115400                   call        d,[0005411A0]
      .0054117C: 59                             pop         ecx
      .0054117D: 52                             push        edx
      .0054117E: 50                             push        eax
      .0054117F: 51                             push        ecx
      .00541180: FF15A4115400                   call        d,[0005411A4]
      .00541186: 83C410                         add         esp,010
      .00541189: 85C0                           test        eax,eax
      .0054118B: E93C0E0000                     jmp        .000541FCC

      int patch3[] = {0x51, 0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34,
                      0xff, 0x15, 0xa0, 0x11, 0x54, 0x00,
                      0x59, 0x52, 0x50, 0x51,
                      0xff, 0x15, 0xa4, 0x11, 0x54, 0x00,
                      0x83, 0xc4, 0x10,
                      0x85, 0xc0,
                      0xe9};
      */
      int patch3[] = {0x51, 0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34, 0xff, 0x15, 0xa0, 0x11, 0x54, 0x00, 0x59, 0x52, 0x50, 0x51, 0xff, 0x15, 0xa4, 0x11, 0x54, 0x00, 0x83, 0xc4, 0x10, 0x85, 0xc0, 0xe9};

      PatchProcess(new, patch3);
      StoreDword(fseeki64, b);
      PatchProcess(new + 128, b);               // _fseeki64 goes at the alloced memory area + 128
      StoreDword(va__allmul, b);
      PatchProcess(new + 132, b);               // _allmul goes at the alloced memory area + 132
      StoreDword(new + 132, b);
      PatchProcess(new + 10, b);                // fix the _allmul call
      StoreDword(new + 128, b);
      PatchProcess(new + 20, b);                // fix the _fseeki64 call
      offset = returnaddr - (new + 30 + 4);
      StoreDword(offset, b);
      PatchProcess(new + 30, b);                // fix the returning jump

      /*
      406:
      .00556A94: E8 CF AE 02 00                 call    fopen
      .00556A99: 83 C4 24                       add     esp, 24h
      .00556A9C: 3B C3                          cmp     eax, ebx
      .00556A9E: 89 86 D8 02 00 00              mov     [esi+2D8h], eax
      .00556AA4: 75 23                          jnz     short loc_556AC9
      */
      int search7[] = { 0x83, 0xc4, 0x24, 0x3b, 0xc3, 0x89, 0x86, 0xd8, 0x02, 0x00, 0x00 };
      patcharea = FindMemoryAddress(0x510000, 0x570000, search7);
      if (!patcharea) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(12)");
         return;
      }
      offset = fopen - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchProcess(patcharea, b);

      /*
      406:
      .005412FE: FF 15 94 4D 56 00              call    ds:fclose
      .00541304: 83 C4 04                       add     esp, 4
      .00541307: 89 9E D8 02 00 00              mov     [esi+2D8h], ebx
      .0054130D: 8B 86 04 03 00 00              mov     eax, [esi+304h]
      */
      int search8[] = { 0x83, 0xc4, 0x04, 0x89, 0x9e, 0xd8, 0x02, 0x00, 0x00, 0x8b, 0x86, 0x04, 0x03, 0x00, 0x00 };
      patcharea = FindMemoryAddress(0x510000, 0x570000, search8);
      if (!patcharea) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(13)");
         return;
      }
      offset = fclose - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchProcess(patcharea, b);

      /*
      406:
      .00556BCD: 8D 04 7F                       lea     eax, [edi+edi*2]
      .00556BD0: 8D 0C 87                       lea     ecx, [edi+eax*4]
      .00556BD3: 6A 01                          push    1
      .00556BD5: C1 E1 02                       shl     ecx, 2
      .00556BD8: 51                             push    ecx
      .00556BD9: 52                             push    edx
      .00556BDA: E8 26 AE 02 00                 call    fread
      */
      int search9[] = { 0x8d, 0x04, 0x7f, 0x8d, 0x0c, 0x87, 0x6a, 0x01, 0xc1, 0xe1, 0x02, 0x51, 0x52, 0xe8 };
      patcharea = FindMemoryAddress(0x510000, 0x570000, search9);
      if (!patcharea) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(14)");
         return;
      }
      patcharea += 18;
      offset = fread - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchProcess(patcharea, b);

      /*
      .00556ACD: E8 A9 AE 02 00                 call    _filelength
      .00556AD2: 8B C8                          mov     ecx, eax
      .00556AD4: 81 E9 D8 02 00 00              sub     ecx, 2D8h
      .00556ADA: B8 4F EC C4 4E                 mov     eax, 4EC4EC4Fh
      .00556ADF: F7 E1                          mul     ecx
      .00556AE1: 83 C4 04                       add     esp, 4
      .00556AE4: C1 EA 04                       shr     edx, 4
      .00556AE7: 89 96 F4 02 00 00              mov     [esi+2F4h], edx
      */
      int search10[] = { 0x8b, 0xc8, 0x81, 0xe9, 0xd8, 0x02, 0x00, 0x00, 0xb8, 0x4f, 0xec, 0xc4, 0x4e, 0xf7, 0xe1, 0x83, 0xc4, 0x04 };
      patcharea = FindMemoryAddress(0x510000, 0x570000, search10);
      if (!patcharea) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(15)");
         return;
      }
      offset = filelength - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchProcess(patcharea, b);
   }
}


/**
 *
 */
void VariableSpreadPatch() {
   /*
   .00541D80: 8B 93 F8 02 00 00                 mov     edx, [ebx+2F8h] // 0x2e8 in b225
   .00541D86: DD 42 1C                          fld     qword ptr [edx+1Ch]
   .00541D89: DC 83 20 03 00 00                 fadd    qword ptr [ebx+320h]

   int search[] = { 0x02, 0x00, 0x00,
                    0xdd, 0x42, 0x1c,
                    0xdc, 0x83, 0x20, 0x03, 0x00, 0x00 };
   */
   int search[] = { 0x02, 0x00, 0x00, 0xdd, 0x42, 0x1c, 0xdc, 0x83, 0x20, 0x03, 0x00, 0x00 };

   int patcharea = FindMemoryAddress(0x510000, 0x570000, search);
   if (patcharea != 0) {
      int patchaddr = patcharea + 6;
      /*
      .00541209: DC42 24                        fadd qword ptr ds:[edx+24]
      .0054120C: 90                             nop
      .0054120D: 90                             nop
      .0054120E: 90                             nop
      */
      int patch[] = { 0xdc, 0x42, 0x24, 0x90, 0x90, 0x90 };
      PatchProcess(patchaddr, patch);
   }
   else {
      // build 406 (405+ is like this)
      /*
      .0055694D: 8B 93 F8 02 00 00              mov     edx, [ebx+2F8h]
      .00556953: DD 42 1C                       fld     qword ptr [edx+1Ch]
      .00556956: 8B 54 24 20                    mov     edx, [esp+10h+arg_C]
      .0055695A: DC 83 20 03 00 00              fadd    qword ptr [ebx+320h]

      int search1a[] = { 0x02, 0x00, 0x00,
                        0xdd, 0x42, 0x1c,
                        0x8b, 0x54, 0x24, 0x20,
                        0xdc, 0x83, 0x20, 0x03, 0x00, 0x00 };
      */
      int search1a[] = { 0x02, 0x00, 0x00, 0xdd, 0x42, 0x1c, 0x8b, 0x54, 0x24, 0x20, 0xdc, 0x83, 0x20, 0x03, 0x00, 0x00 };

      patcharea = FindMemoryAddress(0x510000, 0x570000, search1a);
      if (patcharea != 0) {
         patchaddr = patcharea + 6;
      }
      int patch1[] = { 0xdc, 0x42, 0x24, 0x8b, 0x54, 0x24, 0x20, 0x90, 0x90, 0x90 };
      PatchProcess(patchaddr, patch1);
   }
   if (!patcharea) {
      Print("Process already patched for variable spread or we just can't find the area to patch.");
      catch("VariableSpreadPatch(1)");
      return;
   }

   /*
   .00541532: DD41 20                           fld qword ptr ds:[ecx+20]
   .00541535: DC1D C05A5600                     fcomp qword ptr ds:[565AC0]
   .0054153B: DFE0                              fstsw ax
   .0054153D: F6C4 41                           test Ah,41
   .00541540: 75 40                             jnz short terminal.00541582
   .00541542: 4F                                dec edi
   .00541543: 83C1 34                           add ecx,34
   .00541546: 3BFB                              cmp edi,ebx
   */
   int search2[] = { 0xdf, 0xe0, 0xf6, 0xc4, 0x41, 0x75, 0x40, 0x4f, 0x83, 0xc1, 0x34, 0x3b, 0xfb };
   int patcharea2 = FindMemoryAddress(0x510000, 0x570000, search2);
   string volstr;
   if (patcharea2 != 0) {
      int byte[] = { 0 };
      PatchProcess(patcharea2 + 6, byte); // remove the volume check
      volstr = " Volume check removed at 0x" + IntToHexStr(patcharea2 + 6) + ".";
   }
   else {
      Print("Volume check NOT removed. You may encounter problems when spread is 0.");
   }
   Print("Process patched for variable spread at 0x" + IntToHexStr(patchaddr) + "." + volstr);

   catch("VariableSpreadPatch(2)");
}


/**
 *
 */
int FindMemoryAddress(int from, int to, int pattern[]) {
   int buffer[1], hProcess=GetCurrentProcess();
   int patternLength = ArraySize(pattern);
   int iNull[];

   for (int i=from; i <= to; i++) {
      buffer[0] = 0;
      if (!ReadProcessMemory(hProcess, i, buffer, 1, iNull))
         return(_NULL(catch("FindMemoryAddress(1)->kernel32::ReadProcessMemory()   error="+ win32.GetLastError(), ERR_WIN32_ERROR)));

      if (buffer[0] == pattern[0]) {
         bool found = true;

         for (int n=1; n < patternLength; n++) {
            buffer[0] = 0;
            if (!ReadProcessMemory(hProcess, i+n, buffer, 1, iNull))
               return(_NULL(catch("FindMemoryAddress(2)->kernel32::ReadProcessMemory()   error="+ win32.GetLastError(), ERR_WIN32_ERROR)));

            if (buffer[0] != pattern[n]) {
               found = false;
               break;
            }
         }
         if (found)
            return(i);
      }
   }
   return(_NULL(catch("FindMemoryAddress(3)")));
}


/**
 *
 */
void StoreDword(int addr, int &bytes[]) {
   bytes[0] = addr       & 0xFF;
   bytes[1] = addr >>  8 & 0xFF;
   bytes[2] = addr >> 16 & 0xFF;
   bytes[3] = addr >> 24 & 0xFF;

   catch("StoreDword()");
}


/**
 *
 */
bool PatchProcess(int address, int bytes[]) {
   int size     = ArraySize(bytes);
   int hProcess = GetCurrentProcess();
   int iNull[], buffer[1];

   for (int i=0; i < size; i++) {
      buffer[0] = bytes[i];
      if (!WriteProcessMemory(hProcess, address+i, buffer, 1, iNull))
         return(!catch("PatchProcess()->kernel32::WriteProcessMemory()   error="+ win32.GetLastError(), ERR_WIN32_ERROR));
   }
   return(true);
}

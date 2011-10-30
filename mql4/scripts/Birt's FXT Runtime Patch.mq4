/**
 * Birt's FXT Runtime Patch
 *
 * Überarbeitete Version seiner Originalversion vom 11.09.2011. Die Funktionalität selbst ist unverändert.
 *
 * @author  Cristi Dumitrescu <birt@eareview.net>
 * @see     http://eareview.net/tickdata
 */
#include <stdlib.mqh>
#include <win32api.mqh>


#property show_inputs


//////////////////////////////////////////////////////////////// Externe Parameter ////////////////////////////////////////////////////////////////

extern bool   Dont.Overwrite.FXT.Files       = true;
extern string _1____________________________ = "The 2GB limit removal works in Windows 7, Vista and Server 2008 only.";
extern bool   Remove.2GB.Limit               = false;
extern string _2____________________________ = "Using the variable spread option requires variable spread FXT files.";
extern bool   Use.Variable.Spread.Files      = false;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


int mt4Build;


/**
 * Initialisierung
 *
 * @return int - Fehlerstatus
 */
int init() {
   init = true; init_error = NO_ERROR; __SCRIPT__ = WindowExpertName();
   stdlib_init(__SCRIPT__);
   return(catch("init()"));
}


/**
 * Deinitialisierung
 *
 * @return int - Fehlerstatus
 */
int deinit() {
   return(catch("deinit()"));
}


#define LAST_BUILD_KNOWN   406

#import "kernel32.dll"
   int  WriteProcessMemory(int handle, int address, int& buffer[], int size, int& written);
   int  ReadProcessMemory(int handle, int address, int& buffer[], int size, int& read);
   int  LoadLibraryA(string file);
   int  GetProcAddress(int hmodule, string procname);
#import


/**
 * Main-Funktion
 *
 * @return int - Fehlerstatus
 */
int start() {
   mt4Build = GetTerminalBuild();
   if (mt4Build == 0)
      return(SetLastError(stdlib_PeekLastError()));

   Print("MT4 build "+ mt4Build +" detected.");

   if (mt4Build > LAST_BUILD_KNOWN) {
      Print("The patch you are running was not tested with this build so it may or may not work.");
      Print("You should check for a new patch at http://eareview.net/tick-data");
   }

   if (Dont.Overwrite.FXT.Files)  DontOverwriteFXTPatch();
   if (Remove.2GB.Limit)          Remove2GBLimitPatch();
   if (Use.Variable.Spread.Files) VariableSpreadPatch();

   return(catch("start()"));
}


/**
 *
 */
void DontOverwriteFXTPatch() {
   /*
   .text:00540E75 83 C4 1C                                add     esp, 1Ch
   .text:00540E78 85 C0                                   test    eax, eax
   .text:00540E7A 0F 85 EE 02 00 00                       jnz     loc_54116E
   */
   int search1[] = { 0x83, 0xc4, 0x1c, 0x85, 0xc0, 0x0f, 0x85 };

   /*
   .text:00540F92 1B C0                                   sbb     eax, eax
   .text:00540F94 83 D8 FF                                sbb     eax, 0FFFFFFFFh
   .text:00540F97 85 C0                                   test    eax, eax
   .text:00540F99 0F 85 9D 01 00 00                       jnz     loc_54113C
   */
   int search2[]  = { 0x1b, 0xc0, 0x83, 0xd8, 0xff, 0x85, 0xc0, 0x0f, 0x85, 0x9d, 0x01, 0x00, 0x00 };
   // builds 405+
   int search2a[] = { 0x1b, 0xc0, 0x83, 0xd8, 0xff, 0x85, 0xc0, 0x0f, 0x85, 0x9b, 0x01, 0x00, 0x00 };

   /*
   .text:0054109A 8B 42 18                                mov     eax, [edx+18h]
   .text:0054109D 85 C0                                   test    eax, eax
   .text:0054109F 0F 85 97 00 00 00                       jnz     loc_54113C
   */
   int search3[] = { 0x8b, 0x42, 0x18, 0x85, 0xc0, 0x0f, 0x85 };

   int patchaddr1 = FindMemory(0x510000, 0x570000, search1);
   if (patchaddr1 != 0) {
      int patchaddr2 = FindMemory(patchaddr1, patchaddr1 + 32768, search2);
      if (patchaddr2 == 0)
         patchaddr2 = FindMemory(patchaddr1, patchaddr1 + 32768, search2a);

      int patchaddr3 = FindMemory(patchaddr1, patchaddr1 + 32768, search3);
   }

   if (patchaddr1!=0 && patchaddr2!=0 && patchaddr3!=0) {
      int patch[] = { 0x00, 0x00 };
      PatchZone(patchaddr1 + 7, patch);
      PatchZone(patchaddr2 + 9, patch);
      PatchZone(patchaddr3 + 7, patch);
      Print("FXT overwriting disabled. Addresses patched: 0x"+ Dec2Hex(patchaddr1) +", 0x"+ Dec2Hex(patchaddr2) +", 0x"+ Dec2Hex(patchaddr3) +".");
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
   int h;
   int addr1 = 0;
   int addr2 = 0;
   h = LoadLibraryA("ntdll.dll");
   if (h != 0) addr2 = GetProcAddress(h, "_allmul");
   if (addr2 == 0) {
      Alert("2GB limit removal not activated.");
      Alert("Could not find the _allmul function in ntdll.dll.");
      catch("Remove2GBLimitPatch(1)");
      return;
   }
   if (mt4Build < 399) {
      string lib = "msvcrt.dll";
      h = LoadLibraryA(lib);
      if (h != 0) addr1 = GetProcAddress(h, "_fseeki64");
      if (addr1 == 0) {
         Alert("The 2GB limit removal for this build works only in Windows 7, Vista and Server 2008.");
         Alert("2GB limit removal not activated.");
         Alert("Could not find the _fseeki64() function in your msvcrt.dll!");
         catch("Remove2GBLimitPatch(2)");
         return;
      }
/*
.text:00541436 8D 14 40                                lea     edx, [eax+eax*2]
.text:00541439 8D 04 90                                lea     eax, [eax+edx*4]
.text:0054143C C1 E0 02                                shl     eax, 2
.text:0054143F 50                                      push    eax             ; Offset
.text:00541440 51                                      push    ecx             ; File
.text:00541441 FF 15 98 4D 56 00                       call    ds:fseek // themida messes it up in 226+
*/
      int search[] = { 0x8d, 0x14, 0x40, 0x8d, 0x04, 0x90, 0xc1, 0xe0, 0x02, 0x50, 0x51 };
      int patcharea = FindMemory(0x510000, 0x570000, search);
      if (patcharea == 0) {
         Print("Process already patched for the 2gb limit removal or we just can't find the area to patch.");
         catch("Remove2GBLimitPatch(3)");
         return;
      }
      int patchaddr = patcharea;
      int calcbase = patchaddr + 5;
/*
.text:0054144C 74 0A                                   jz      short loc_541458
*/
      int search2[] = { 0x74, 0x0A };
      int returnaddr = FindMemory(patcharea, patchaddr + 1024, search2);

      if (returnaddr == 0) {
         Print("Can't locate return address for 2gb patch limit removal, skipping patch.");
         catch("Remove2GBLimitPatch(4)");
         return;
      }

      ProcessPatch(patchaddr, 0xe9);
      int new = VirtualAlloc(0, 256, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Print("Patch address found: 0x" + Dec2Hex(patcharea) + ". 2gb limit removal patch is being installed at 0x" + Dec2Hex(new) + ".");
      int offset = new - calcbase;
      int b[4];
      StoreDword(offset, b);
      PatchZone(patchaddr + 1, b);

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
.0054118B: E93C0E0000                     jmp        .000541FCC
*/
      int patch[] = {0x51, 0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34, 0xff, 0x15, 0xa0, 0x11, 0x54, 0x00, 0x59, 0x52, 0x50, 0x51, 0xff, 0x15, 0xa4, 0x11, 0x54, 0x00, 0x83, 0xc4, 0x0C, 0x85, 0xc0, 0xe9};
      PatchZone(new, patch);
      StoreDword(addr1, b);
      PatchZone(new + 128, b); // _fseeki64 goes at the alloced memory area + 128
      StoreDword(addr2, b);
      PatchZone(new + 132, b); // _allmul goes at the alloced memory area + 132
      StoreDword(new + 132, b);
      PatchZone(new + 10, b); // fix the _allmul call
      StoreDword(new + 128, b);
      PatchZone(new + 20, b); // fix the _fseeki64 call
      offset = returnaddr - (new + 30 + 4);
      StoreDword(offset, b);
      PatchZone(new + 30, b); // fix the returning jump
   }
   else if (mt4Build <= 402) {
      lib = "msvcrt.dll";
      h = LoadLibraryA(lib);
      if (h != 0) addr1 = GetProcAddress(h, "_fseeki64");
      if (addr1 == 0) {
         Alert("The 2GB limit removal for this build works only in Windows 7, Vista and Server 2008.");
         Alert("2GB limit removal not activated.");
         Alert("Could not find the _fseeki64() function in your msvcrt.dll!");
         catch("Remove2GBLimitPatch(5)");
         return;
      }
/*
build 399:
.text:00547097 8D 0C 40                          lea     ecx, [eax+eax*2]
.text:0054709A 8D 14 88                          lea     edx, [eax+ecx*4]
.text:0054709D 8B 86 D8 02 00 00                 mov     eax, [esi+2D8h]
.text:005470A3 C1 E2 02                          shl     edx, 2
.text:005470A6 52                                push    edx
.text:005470A7 50                                push    eax
.text:005470A8 FF 15 38 AE 56 00                 call    ds:fseek
.text:005470AE 83 C4 0C                          add     esp, 0Ch
.text:005470B1 85 C0                             test    eax, eax
.text:005470B3 74 0A                             jz      short loc_5470BF
*/
      int search3[] = { 0x8d, 0x0c, 0x40, 0x8d, 0x14, 0x88, 0x8b, 0x86, 0xd8, 0x02, 0x00 };
      patcharea = FindMemory(0x510000, 0x570000, search3);
      if (patcharea == 0) {
         Print("Process already patched for the 2gb limit removal or we just can't find the area to patch.");
         catch("Remove2GBLimitPatch(6)");
         return;
      }
      patchaddr = patcharea;
      calcbase = patchaddr + 5;
      int search4[] = { 0x74, 0x0A };
      returnaddr = FindMemory(patcharea, patchaddr + 1024, search4);
      if (returnaddr == 0) {
         Print("Can't locate return address for 2gb patch limit removal, skipping patch.");
         catch("Remove2GBLimitPatch(7)");
         return;
      }

      ProcessPatch(patchaddr, 0xe9);
      new = VirtualAlloc(0, 256, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Print("Patch address found: 0x" + Dec2Hex(patcharea) + ". 2gb limit removal patch is being installed at 0x" + Dec2Hex(new) + ".");
      offset = new - calcbase;
      StoreDword(offset, b);
      PatchZone(patchaddr + 1, b); // fix jump

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
*/
      int patch1[] = {  0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34, 0xff, 0x15, 0x00, 0x00, 0x00, 0x00, 0x52, 0x50, 0x8b, 0x86, 0xd8, 0x02, 0x00, 0x00, 0x50, 0xff, 0x15, 0x00, 0x00, 0x00, 0x00, 0x83, 0xc4, 0x10, 0x85, 0xc0, 0xe9, 0x00, 0x00, 0x00, 0x00 };
      PatchZone(new, patch1);
      StoreDword(addr1, b);
      PatchZone(new + 128, b); // _fseeki64 goes at the alloced memory area + 128
      StoreDword(addr2, b);
      PatchZone(new + 132, b); // _allmul goes at the alloced memory area + 132
      StoreDword(new + 132, b);
      PatchZone(new + 9, b); // fix the _allmul call
      StoreDword(new + 128, b);
      PatchZone(new + 24, b); // fix the _fseeki64 call
      offset = returnaddr - (new + ArraySize(patch1));
      StoreDword(offset, b);
      PatchZone(new + ArraySize(patch1) - 4, b); // fix the returning jump
   }
   else { // 405+
      lib = "msvcrt.dll";
      h = LoadLibraryA(lib);
      if (h != 0) int fseeki64 = GetProcAddress(h, "_fseeki64");
      if (fseeki64 == 0) {
         lib = "msvcr80.dll";
         h = LoadLibraryA(lib);
         if (h != 0) fseeki64 = GetProcAddress(h, "_fseeki64");
      }
      if (fseeki64 == 0) {
         lib = "msvcr90.dll";
         h = LoadLibraryA(lib);
         if (h != 0) fseeki64 = GetProcAddress(h, "_fseeki64");
      }
      if (fseeki64 == 0) {
         lib = "msvcr100.dll";
         h = LoadLibraryA(lib);
         if (h != 0) fseeki64 = GetProcAddress(h, "_fseeki64");
      }
      if (fseeki64 == 0) {
         Alert("Could not find the _fseeki64() function in your msvcrt.dll or msvcr100.dll!");
         Alert("If you're using Windows XP, consider getting a copy of the Visual C 2010 runtime, available at http://www.microsoft.com/download/en/details.aspx?id=5555 (x86) and http://www.microsoft.com/download/en/details.aspx?id=14632 (x64).");
         Alert("2GB limit removal not activated.");
         catch("Remove2GBLimitPatch(8)");
         return;
      }
      int filelength = GetProcAddress(h, "_filelength");
      int fopen = GetProcAddress(h, "fopen");
      int fclose = GetProcAddress(h, "fclose");
      int fread = GetProcAddress(h, "fread");
/*
.text:00556B84 8D 14 40                          lea     edx, [eax+eax*2]
.text:00556B87 8D 04 90                          lea     eax, [eax+edx*4]
.text:00556B8A 53                                push    ebx
.text:00556B8B C1 E0 02                          shl     eax, 2
.text:00556B8E 50                                push    eax
.text:00556B8F 51                                push    ecx
.text:00556B90 E8 4D B5 02 00                    call    fseek
*/
      int search5[] = { 0x8d, 0x14, 0x40, 0x8d, 0x04, 0x90, 0x53, 0xc1, 0xe0, 0x02, 0x50, 0x51 };
      patcharea = FindMemory(0x510000, 0x570000, search5);
      if (patcharea == 0) {
         Print("Process already patched for the 2gb limit removal or we just can't find the area to patch.");
         catch("Remove2GBLimitPatch(9)");
         return;
      }

/*
// test
      int fseek = GetProcAddress(h, "fseek");
      if (patcharea == 0) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(10)");
         return;
      }
      Print("Patcharea: 0x" +Dec2Hex(patcharea));
      patcharea += 17;
      offset = fseek - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchZone(patcharea, b);
*/

      patchaddr = patcharea;
      calcbase = patchaddr + 6;
/*
.text:0054144C 74 0A                                   jz      short loc_541458
*/
      int search6[] = { 0x74, 0x0A };
      returnaddr = FindMemory(patcharea, patchaddr + 1024, search6);

      if (returnaddr == 0) {
         Print("Can't locate return address for 2gb patch limit removal, skipping patch.");
         catch("Remove2GBLimitPatch(11)");
         return;
      }

      ProcessPatch(patchaddr, 0x53);
      ProcessPatch(patchaddr + 1, 0xe9);
      new = VirtualAlloc(0, 256, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
      Print("Patch address found: 0x" + Dec2Hex(patcharea) + ". 2gb limit removal patch is being installed at 0x" + Dec2Hex(new) + ".");
      offset = new - calcbase;
      StoreDword(offset, b);
      PatchZone(patchaddr + 2, b);

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
*/
      int patch3[] = {0x51, 0x6a, 0x00, 0x50, 0x6a, 0x00, 0x6a, 0x34, 0xff, 0x15, 0xa0, 0x11, 0x54, 0x00, 0x59, 0x52, 0x50, 0x51, 0xff, 0x15, 0xa4, 0x11, 0x54, 0x00, 0x83, 0xc4, 0x10, 0x85, 0xc0, 0xe9};
      PatchZone(new, patch3);
      StoreDword(fseeki64, b);
      PatchZone(new + 128, b); // _fseeki64 goes at the alloced memory area + 128
      StoreDword(addr2, b);
      PatchZone(new + 132, b); // _allmul goes at the alloced memory area + 132
      StoreDword(new + 132, b);
      PatchZone(new + 10, b); // fix the _allmul call
      StoreDword(new + 128, b);
      PatchZone(new + 20, b); // fix the _fseeki64 call
      offset = returnaddr - (new + 30 + 4);
      StoreDword(offset, b);
      PatchZone(new + 30, b); // fix the returning jump

/*
406:
.text:00556A94 E8 CF AE 02 00                    call    fopen
.text:00556A99 83 C4 24                          add     esp, 24h
.text:00556A9C 3B C3                             cmp     eax, ebx
.text:00556A9E 89 86 D8 02 00 00                 mov     [esi+2D8h], eax
.text:00556AA4 75 23                             jnz     short loc_556AC9
*/
      int search7[] = { 0x83, 0xc4, 0x24, 0x3b, 0xc3, 0x89, 0x86, 0xd8, 0x02, 0x00, 0x00 };
      patcharea = FindMemory(0x510000, 0x570000, search7);
      if (patcharea == 0) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(12)");
         return;
      }
      offset = fopen - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchZone(patcharea, b);
/*
406:
.text:005412FE FF 15 94 4D 56 00                       call    ds:fclose
.text:00541304 83 C4 04                                add     esp, 4
.text:00541307 89 9E D8 02 00 00                       mov     [esi+2D8h], ebx
.text:0054130D 8B 86 04 03 00 00                       mov     eax, [esi+304h]
*/
      int search8[] = { 0x83, 0xc4, 0x04, 0x89, 0x9e, 0xd8, 0x02, 0x00, 0x00, 0x8b, 0x86, 0x04, 0x03, 0x00, 0x00 };
      patcharea = FindMemory(0x510000, 0x570000, search8);
      if (patcharea == 0) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(13)");
         return;
      }
      offset = fclose - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchZone(patcharea, b);
/*
406:
.text:00556BCD 8D 04 7F                          lea     eax, [edi+edi*2]
.text:00556BD0 8D 0C 87                          lea     ecx, [edi+eax*4]
.text:00556BD3 6A 01                             push    1
.text:00556BD5 C1 E1 02                          shl     ecx, 2
.text:00556BD8 51                                push    ecx
.text:00556BD9 52                                push    edx
.text:00556BDA E8 26 AE 02 00                    call    fread
*/
      int search9[] = { 0x8d, 0x04, 0x7f, 0x8d, 0x0c, 0x87, 0x6a, 0x01, 0xc1, 0xe1, 0x02, 0x51, 0x52, 0xe8 };
      patcharea = FindMemory(0x510000, 0x570000, search9);
      if (patcharea == 0) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(14)");
         return;
      }
      patcharea += 18;
      offset = fread - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchZone(patcharea, b);
/*
.text:00556ACD E8 A9 AE 02 00                    call    _filelength
.text:00556AD2 8B C8                             mov     ecx, eax
.text:00556AD4 81 E9 D8 02 00 00                 sub     ecx, 2D8h
.text:00556ADA B8 4F EC C4 4E                    mov     eax, 4EC4EC4Fh
.text:00556ADF F7 E1                             mul     ecx
.text:00556AE1 83 C4 04                          add     esp, 4
.text:00556AE4 C1 EA 04                          shr     edx, 4
.text:00556AE7 89 96 F4 02 00 00                 mov     [esi+2F4h], edx
*/
      int search10[] = { 0x8b, 0xc8, 0x81, 0xe9, 0xd8, 0x02, 0x00, 0x00, 0xb8, 0x4f, 0xec, 0xc4, 0x4e, 0xf7, 0xe1, 0x83, 0xc4, 0x04 };
      patcharea = FindMemory(0x510000, 0x570000, search10);
      if (patcharea == 0) {
         Alert("Failed to fully patch the 2GB limit!");
         Alert("Backtesting will probably result in a crash!");
         catch("Remove2GBLimitPatch(15)");
         return;
      }
      offset = filelength - patcharea;
      patcharea -= 4;
      StoreDword(offset, b);
      PatchZone(patcharea, b);
   }
}


/**
 *
 */
void VariableSpreadPatch() {
/*
.text:00541D80 8B 93 F8 02 00 00                       mov     edx, [ebx+2F8h] // 0x2e8 in b225
.text:00541D86 DD 42 1C                                fld     qword ptr [edx+1Ch]
.text:00541D89 DC 83 20 03 00 00                       fadd    qword ptr [ebx+320h]
*/
   int search[] = { 0x02, 0x00, 0x00, 0xdd, 0x42, 0x1c, 0xdc, 0x83, 0x20, 0x03, 0x00, 0x00 };
   int patcharea = FindMemory(0x510000, 0x570000, search);
   if (patcharea != 0) {
      int patchaddr = patcharea + 6;
/*
00541209       DC42 24                 FADD QWORD PTR DS:[EDX+24]
0054120C       90                      NOP
0054120D       90                      NOP
0054120E       90                      NOP
*/
      int patch[] = { 0xdc, 0x42, 0x24, 0x90, 0x90, 0x90 };
      PatchZone(patchaddr, patch);
   }
   else {
// build 406 (405+ is like this)
/*
.text:0055694D 8B 93 F8 02 00 00                 mov     edx, [ebx+2F8h]
.text:00556953 DD 42 1C                          fld     qword ptr [edx+1Ch]
.text:00556956 8B 54 24 20                       mov     edx, [esp+10h+arg_C]
.text:0055695A DC 83 20 03 00 00                 fadd    qword ptr [ebx+320h]
*/
      int search1a[] = { 0x02, 0x00, 0x00, 0xdd, 0x42, 0x1c, 0x8b, 0x54, 0x24, 0x20, 0xdc, 0x83, 0x20, 0x03, 0x00, 0x00 };
      patcharea = FindMemory(0x510000, 0x570000, search1a);
      if (patcharea != 0) {
         patchaddr = patcharea + 6;
      }
      int patch1[] = { 0xdc, 0x42, 0x24, 0x8b, 0x54, 0x24, 0x20, 0x90, 0x90, 0x90 };
      PatchZone(patchaddr, patch1);
   }
   if (patcharea == 0) {
      Print("Process already patched for variable spread or we just can't find the area to patch.");
      catch("VariableSpreadPatch(1)");
      return;
   }



/*
00541532   |.  DD41 20                 |FLD QWORD PTR DS:[ECX+20]
00541535   |.  DC1D C05A5600           |FCOMP QWORD PTR DS:[565AC0]
0054153B   |.  DFE0                    |FSTSW AX
0054153D   |.  F6C4 41                 |TEST AH,41
00541540   |.  75 40                   |JNZ SHORT terminal.00541582
00541542   |.  4F                      |DEC EDI
00541543   |.  83C1 34                 |ADD ECX,34
00541546   |.  3BFB                    |CMP EDI,EBX
*/
   int search2[] = { 0xdf, 0xe0, 0xf6, 0xc4, 0x41, 0x75, 0x40, 0x4f, 0x83, 0xc1, 0x34, 0x3b, 0xfb };
   int patcharea2 = FindMemory(0x510000, 0x570000, search2);
   string volstr;
   if (patcharea2 != 0) {
      ProcessPatch(patcharea2 + 6, 0); // remove the volume check
      volstr = " Volume check removed at 0x" + Dec2Hex(patcharea2 + 6) + ".";
   }
   else {
      Print("Volume check NOT removed. You may encounter problems when spread is 0.");
   }
   Print("Process patched for variable spread at 0x" + Dec2Hex(patchaddr) + "." + volstr);

   catch("VariableSpreadPatch(2)");
}


/**
 *
 */
int FindMemory(int start, int end, int cmp[]) {
   int mem[1];
   int out;
   int hproc = GetCurrentProcess();
   for (int i = start; i <= end; i++) {
      mem[0] = 0;
      ReadProcessMemory(hproc, i, mem, 1, out);
      if (mem[0] == cmp[0]) {
         bool found = true;
         for (int j = 1; j < ArraySize(cmp); j++) {
            mem[0] = 0;
            ReadProcessMemory(hproc, i + j, mem, 1, out);
            if (mem[0] != cmp[j]) {
               found = false;
               break;
            }
         }
         if (found) {
            catch("FindMemory(1)");
            return(i);
         }
      }
   }
   catch("FindMemory(2)");
   return(0);
}


/**
 *
 */
void ReadDword(int addr, int& arr[]) {
   int mem[1];
   int out;
   int hproc = GetCurrentProcess();
   ReadProcessMemory(hproc, addr, mem, 1, out);
   arr[0] = mem[0];
   ReadProcessMemory(hproc, addr + 1, mem, 1, out);
   arr[1] = mem[0];
   ReadProcessMemory(hproc, addr + 2, mem, 1, out);
   arr[2] = mem[0];
   ReadProcessMemory(hproc, addr + 3, mem, 1, out);
   arr[3] = mem[0];

   catch("ReadDword()");
}


/**
 *
 */
void StoreDword(int addr, int& arr[]) {
   arr[0] = addr & 0xFF;
   arr[1] = (addr & 0xFF00) >> 8;
   arr[2] = (addr & 0xFF0000) >> 16;
   arr[3] = (addr & 0xFF000000) >> 24;

   catch("StoreDword()");
}


/**
 *
 */
void PatchZone(int address, int patch[]) {
   int mem[1];
   int out;
   int hproc = GetCurrentProcess();
   for (int i = 0; i < ArraySize(patch); i++) {
      mem[0] = patch[i];
      WriteProcessMemory(hproc, address + i, mem, 1, out);
   }
   catch("PatchZone()");
}


/**
 *
 */
int ProcessPatch(int address, int byte) {
   int mem[1];
   int out;
   mem[0] = byte;
   int hproc = GetCurrentProcess();
   int result = WriteProcessMemory(hproc, address, mem, 1, out);

   catch("ProcessPatch()");
   return(result);
}


/**
 *
 */
string Dec2Hex(int n) {
   string result = "";
   while(n > 0) {
      int d = n % 16;
      string c;
      if (d == 10) {
         c = "A";
      }
      else if (d == 11) {
         c = "B";
      }
      else if (d == 12) {
         c = "C";
      }
      else if (d == 13) {
         c = "D";
      }
      else if (d == 14) {
         c = "E";
      }
      else if (d == 15) {
         c = "F";
      }
      else {
         c = d;
      }
      result = c + result;
      n = n / 16;
   }

   catch("Dec2Hex()");
   return (result);

   // Dummy-Calls, unterdrücken Compilerwarnungen über unreferenzierte Funktionen
   int array[]; ReadDword(NULL, array); StoreDword(NULL, array);
}

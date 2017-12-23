//+---------------------------------------------------------------------------+
//|   EA VERSION
//|   RenkoLiveChart_v4.13.mq4
//|   Inspired from Renko script by "e4" (renko_live_scr.mq4)
//|   Copyleft 2009 LastViking
//|   2014 PimpMyEA.Com
//|
//|   Aug 12 2009 (LV): 
//|            - Wanted volume in my Renko chart so I wrote my own script
//|     
//|   Aug 20-21 2009 (LV) (v1.1 - v1.3):
//|            - First attempt at live Renko brick formation (bugs O bugs...)
//|            - Fixed problem with strange symbol names at some 5 digit 
//|               brokers (credit to Tigertron)
//|     
//|   Aug 24 2009 (LV) (v1.4):
//|            - Handle High / Low in history in a reasonable way (prev. 
//|               used Close)
//|   
//|   Aug 26 2009 (Lou G) (v1.5/v1.6):
//|            - Finaly fixing the "late appearance" (live Renko brick 
//|               formation) bug
//| 
//|   Aug 31 2009 (LV) (v2.0):
//|            - Not a script anylonger, but run as indicator 
//|            - Naroved down the MT4 bug that used to cause the "late appearance bug" 
//|               a little closer (has to do with High / Low gaps)
//|            - Removed the while ... sleep() loop. Renko chart is now tick 
//|               driven: -MUSH nicer to system resources this way
//| 
//|   Sep 03 2009 (LV) (v2.1):
//|            - Fixed so that Time[] holds the open time of the renko 
//|               bricks (prev. used time of close)
//|     
//|   Sep 16 2009 (Lou G) (v3.0): 
//|            - Optional wicks added
//|            - Conversion back to EA 
//|            - Auto adjust for 5 and 6 dec brokers added
//|               enter RenkoBoxSize as "actual" size e.g. "10" for 10 pips
//|            - Compensation for "zero compare" problem added
//|
//|   Okt 05 2009 (LV) (v3.1): 
//|            - Fixed a bug related to BoxOffset
//|            - Auto adjust for 3 and 4 dec JPY pairs
//|            - Removed init() function
//|            - Changed back to old style Renko brick formation
//| 
//|   Okt 13 2009 (LV) (v3.2): 
//|            - Added "EmulateOnLineChart" option (credit to Skipperxit/Mimmo)
//|
//|   Jan 03 2014 (Andrea) (v4.0):
//|            - Removed "StrangeSymbolName" option and made it automatic
//|            - Set "ShowWicks" to false by default
//|            - Restored init() function
//|            - Added ATR based box size
//|            - Added improved on chart instruction with automatic detection
//|               of offline chart opening 
//|
//|   Jan 20 2014 (Andrea) (v4.1):
//|            - Added support for charts with postfix (example: "EURUSDm")
//| 
//|   Feb 06 2014 (Andrea) (v4.11):
//|            - Version that can run on Build 600 (removed reserved word "SymbolName")
//| 
//|   Mar 26 2014 (Andrea) (v4.12):
//|            - Offline charts available correctly on Build 600
//| 
//|   Aug 22 2014 (Tim Welch) (v4.13):
//|            - Added a startup option (BuildChartsWhenMarketOffline) to build the offline charts when inside of the OnInit() for times when the market is closed
//|            - Changed the RenkoBoxSize variable from an INT to a DOUBLE for 5 digit currency accuracy (i.e. 5.5 == 55 pipettes) 
//| 
//+---------------------------------------------------------------------------+
#property copyright "" 
//+------------------------------------------------------------------+
#include <WinUser32.mqh>
#include <stdlib.mqh>
//+------------------------------------------------------------------+
#import "user32.dll"
    int RegisterWindowMessageA(string lpString); 
#import
//+------------------------------------------------------------------+
#define RENKO_VERSION "v4.13"

extern double RenkoBoxSize = 10;
extern int RenkoBoxOffset = 0;
extern int RenkoTimeFrame = 2;      // What time frame to use for the offline renko chart
extern bool ShowWicks = true;
extern bool EmulateOnLineChart = true;
extern bool BuildChartsWhenMarketOffline=true;


extern string note = "== ATR Based Boxes ==";
extern bool CalculateBestBoxSize = false;
extern int ATRPeriod = 24;
extern int ATRTimeFrame = 60;
extern bool UseATRMA = true;
extern int MAMethod = 0;
extern int MAPeriod = 120;

// extern bool StrangeSymbolName = false;
//+------------------------------------------------------------------+
int HstHandle = -1, LastFPos = 0, MT4InternalMsg = 0;
string SymbName;
//+------------------------------------------------------------------+

int dg;
double pt,mt;

void OnInit(){

   Comment("");

   dg=Digits;
   if(dg==3 || dg==5){
         pt=Point*10;
         mt=10;
      }else{
         pt=Point;
         mt=1;
      }
      
   if (CalculateBestBoxSize){
           RenkoBoxSize = CalculateATRBoxSize(Symbol(), ATRTimeFrame, ATRPeriod, 0, MAMethod, MAPeriod)/pt;
        }
        

   if(BuildChartsWhenMarketOffline)
     {
        // Manually call OnTick() function once so we build offline charts even if the market is closed...
        // This continues to exit properly after the charts have been built so as not to mess anything up.
        OnTick();
     }
        
   return;
}


void UpdateChartWindow() {
    static int hwnd = 0;

     if(hwnd == 0) {
        hwnd = WindowHandle(SymbName, RenkoTimeFrame);
        if(hwnd != 0) Print("Chart window detected");
    }
 
    if(EmulateOnLineChart && MT4InternalMsg == 0) 
        MT4InternalMsg = RegisterWindowMessageA("MetaTrader4_Internal_Message");
 
    if(hwnd != 0) if(PostMessageA(hwnd, WM_COMMAND, 0x822c, 0) == 0) hwnd = 0;
    if(hwnd != 0 && MT4InternalMsg != 0) PostMessageA(hwnd, MT4InternalMsg, 2, 1);
 
    return;
}
//+------------------------------------------------------------------+
void OnTick() {
    static double BoxPoints, UpWick, DnWick;
    static double PrevLow, PrevHigh, PrevOpen, PrevClose, CurVolume, CurLow, CurHigh, CurOpen, CurClose;
    static datetime PrevTime;
           
    //+------------------------------------------------------------------+
    // This is only executed ones, then the first tick arives.
    if(HstHandle < 0) {
        // Init
 
        // Error checking    
        if(!IsConnected()) {
            Print("Waiting for connection...");
            return;
        }                            
        if(!IsDllsAllowed()) {
            Print("Error: Dll calls must be allowed!");
            return;
        }        
        if(MathAbs(RenkoBoxOffset) >= RenkoBoxSize) {
            Print("Error: |RenkoBoxOffset| should be less then RenkoBoxSize!");
            return;
        }
        switch(RenkoTimeFrame) {
        case 1: case 5: case 15: case 30: case 60: case 240:
        case 1440: case 10080: case 43200: case 0:
            Print("Error: Invald time frame used for offline renko chart (RenkoTimeFrame)!");
            return;
        }
        //
        
        double BoxSize = RenkoBoxSize;
        
        int BoxOffset = RenkoBoxOffset;

        SymbName = Symbol();

        BoxPoints = NormalizeDouble(BoxSize*pt, Digits);
        PrevLow = NormalizeDouble(BoxOffset*pt + MathFloor(Close[Bars-1]/BoxPoints)*BoxPoints, Digits);
        
        DnWick = PrevLow;
        PrevHigh = PrevLow + BoxPoints;
        UpWick = PrevHigh;
        PrevOpen = PrevLow;
        PrevClose = PrevHigh;
        CurVolume = 1;
        PrevTime = Time[Bars-1];
    
        // create / open hst file        
        HstHandle = FileOpenHistory(SymbName + RenkoTimeFrame + ".hst", FILE_BIN|FILE_WRITE|FILE_SHARE_WRITE|FILE_SHARE_READ);
        if(HstHandle < 0) {
            Print("Error: can\'t create / open history file: " + ErrorDescription(GetLastError()) + ": " + SymbName + RenkoTimeFrame + ".hst");
            return;
        }
        //
       
        // write hst file header
        int HstUnused[13];
        FileWriteInteger(HstHandle, 400, LONG_VALUE);             // Version
        FileWriteString(HstHandle, "", 64);                    // Copyright
        FileWriteString(HstHandle, SymbName, 12);            // Symbol
        FileWriteInteger(HstHandle, RenkoTimeFrame, LONG_VALUE);    // Period
        FileWriteInteger(HstHandle, Digits, LONG_VALUE);        // Digits
        FileWriteInteger(HstHandle, 0, LONG_VALUE);            // Time Sign
        FileWriteInteger(HstHandle, 0, LONG_VALUE);            // Last Sync
        FileWriteArray(HstHandle, HstUnused, 0, 13);            // Unused
        //

         // process historical data
          int i = Bars-2;
        //Print(Symbol() + " " + High[i] + " " + Low[i] + " " + Open[i] + " " + Close[i]);
        //---------------------------------------------------------------------------
          while(i >= 0) {

            CurVolume = CurVolume + Volume[i];
        
            UpWick = MathMax(UpWick, High[i]);
            DnWick = MathMin(DnWick, Low[i]);
 
            // update low before high or the revers depending on is closest to prev. bar
            bool UpTrend = High[i]+Low[i] > High[i+1]+Low[i+1];
        
            while(UpTrend && (Low[i] < PrevLow-BoxPoints || CompareDoubles(Low[i], PrevLow-BoxPoints))) {
                  PrevHigh = PrevHigh - BoxPoints;
                  PrevLow = PrevLow - BoxPoints;
                  PrevOpen = PrevHigh;
                  PrevClose = PrevLow;
 
                FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);
                FileWriteDouble(HstHandle, PrevOpen, DOUBLE_VALUE);
                FileWriteDouble(HstHandle, PrevLow, DOUBLE_VALUE);
 
                if(ShowWicks && UpWick > PrevHigh) FileWriteDouble(HstHandle, UpWick, DOUBLE_VALUE);
                else FileWriteDouble(HstHandle, PrevHigh, DOUBLE_VALUE);
                                                
                FileWriteDouble(HstHandle, PrevClose, DOUBLE_VALUE);
                FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);
                
                UpWick = 0;
                DnWick = EMPTY_VALUE;
                CurVolume = 0;
                CurHigh = PrevLow;
                CurLow = PrevLow;  
                
                if(PrevTime < Time[i]) PrevTime = Time[i];
                else PrevTime++;
            }
        
            while(High[i] > PrevHigh+BoxPoints || CompareDoubles(High[i], PrevHigh+BoxPoints)) {
                  PrevHigh = PrevHigh + BoxPoints;
                  PrevLow = PrevLow + BoxPoints;
                  PrevOpen = PrevLow;
                  PrevClose = PrevHigh;
              
                FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);
                FileWriteDouble(HstHandle, PrevOpen, DOUBLE_VALUE);
 
                    if(ShowWicks && DnWick < PrevLow) FileWriteDouble(HstHandle, DnWick, DOUBLE_VALUE);
                else FileWriteDouble(HstHandle, PrevLow, DOUBLE_VALUE);
                                
                FileWriteDouble(HstHandle, PrevHigh, DOUBLE_VALUE);
                FileWriteDouble(HstHandle, PrevClose, DOUBLE_VALUE);
                FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);
                
                UpWick = 0;
                DnWick = EMPTY_VALUE;
                CurVolume = 0;
                CurHigh = PrevHigh;
                CurLow = PrevHigh;  
                
                if(PrevTime < Time[i]) PrevTime = Time[i];
                else PrevTime++;
            }
        
            while(!UpTrend && (Low[i] < PrevLow-BoxPoints || CompareDoubles(Low[i], PrevLow-BoxPoints))) {
                  PrevHigh = PrevHigh - BoxPoints;
                  PrevLow = PrevLow - BoxPoints;
                  PrevOpen = PrevHigh;
                  PrevClose = PrevLow;
              
                FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);
                FileWriteDouble(HstHandle, PrevOpen, DOUBLE_VALUE);
                FileWriteDouble(HstHandle, PrevLow, DOUBLE_VALUE);
                
                if(ShowWicks && UpWick > PrevHigh) FileWriteDouble(HstHandle, UpWick, DOUBLE_VALUE);
                else FileWriteDouble(HstHandle, PrevHigh, DOUBLE_VALUE);
                
                FileWriteDouble(HstHandle, PrevClose, DOUBLE_VALUE);
                FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);
 
                UpWick = 0;
                DnWick = EMPTY_VALUE;
                CurVolume = 0;
                CurHigh = PrevLow;
                CurLow = PrevLow;  
                                
                if(PrevTime < Time[i]) PrevTime = Time[i];
                else PrevTime++;
            }        
            i--;
        }
   
   LastFPos = FileTell(HstHandle);   // Remember Last pos in file
        //
                    
        if(Close[0] > MathMax(PrevClose, PrevOpen)) CurOpen = MathMax(PrevClose, PrevOpen);
        else if (Close[0] < MathMin(PrevClose, PrevOpen)) CurOpen = MathMin(PrevClose, PrevOpen);
        else CurOpen = Close[0];
        
        CurClose = Close[0];
                
        if(UpWick > PrevHigh) CurHigh = UpWick;
        if(DnWick < PrevLow) CurLow = DnWick;
      
        FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);        // Time
        FileWriteDouble(HstHandle, CurOpen, DOUBLE_VALUE);             // Open
        FileWriteDouble(HstHandle, CurLow, DOUBLE_VALUE);        // Low
        FileWriteDouble(HstHandle, CurHigh, DOUBLE_VALUE);        // High
        FileWriteDouble(HstHandle, CurClose, DOUBLE_VALUE);        // Close
        FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);        // Volume                
        FileFlush(HstHandle);
            
        UpdateChartWindow();
        
        // Show the Renko Comments...
        AddRenkoComment(BoxPoints);
    
        return;
         // End historical data / Init        
    }         
    //----------------------------------------------------------------------------
     // HstHandle not < 0 so we always enter here after history done
    // Begin live data feed
               
    UpWick = MathMax(UpWick, Bid);
    DnWick = MathMin(DnWick, Bid);
 
    CurVolume++;               
    FileSeek(HstHandle, LastFPos, SEEK_SET);
 
     //-------------------------------------------------------------------------                       
     // up box                       
       if(Bid > PrevHigh+BoxPoints || CompareDoubles(Bid, PrevHigh+BoxPoints)) {
        PrevHigh = PrevHigh + BoxPoints;
        PrevLow = PrevLow + BoxPoints;
          PrevOpen = PrevLow;
          PrevClose = PrevHigh;
                                
        FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);
        FileWriteDouble(HstHandle, PrevOpen, DOUBLE_VALUE);
 
        if (ShowWicks && DnWick < PrevLow) FileWriteDouble(HstHandle, DnWick, DOUBLE_VALUE);
        else FileWriteDouble(HstHandle, PrevLow, DOUBLE_VALUE);
                      
        FileWriteDouble(HstHandle, PrevHigh, DOUBLE_VALUE);
        FileWriteDouble(HstHandle, PrevClose, DOUBLE_VALUE);
        FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);
          FileFlush(HstHandle);
            LastFPos = FileTell(HstHandle);   // Remeber Last pos in file                                              
          
        if(PrevTime < TimeCurrent()) PrevTime = TimeCurrent();
        else PrevTime++;
                    
          CurVolume = 0;
        CurHigh = PrevHigh;
        CurLow = PrevHigh;  
        
        UpWick = 0;
        DnWick = EMPTY_VALUE;        
        
        UpdateChartWindow();                                    
      }
     //-------------------------------------------------------------------------                       
     // down box
    else if(Bid < PrevLow-BoxPoints || CompareDoubles(Bid,PrevLow-BoxPoints)) {
          PrevHigh = PrevHigh - BoxPoints;
          PrevLow = PrevLow - BoxPoints;
          PrevOpen = PrevHigh;
          PrevClose = PrevLow;
                                
        FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);
        FileWriteDouble(HstHandle, PrevOpen, DOUBLE_VALUE);
        FileWriteDouble(HstHandle, PrevLow, DOUBLE_VALUE);
 
        if(ShowWicks && UpWick > PrevHigh) FileWriteDouble(HstHandle, UpWick, DOUBLE_VALUE);
        else FileWriteDouble(HstHandle, PrevHigh, DOUBLE_VALUE);
                              
        FileWriteDouble(HstHandle, PrevClose, DOUBLE_VALUE);
        FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);
          FileFlush(HstHandle);
            LastFPos = FileTell(HstHandle);   // Remeber Last pos in file                                              
          
        if(PrevTime < TimeCurrent()) PrevTime = TimeCurrent();
        else PrevTime++;          
                    
        CurVolume = 0;
        CurHigh = PrevLow;
        CurLow = PrevLow;  
        
        UpWick = 0;
        DnWick = EMPTY_VALUE;        
        
        UpdateChartWindow();                        
         } 
     //-------------------------------------------------------------------------                       
       // no box - high/low not hit                
    else {
        if(Bid > CurHigh) CurHigh = Bid;
        if(Bid < CurLow) CurLow = Bid;
        
        if(PrevHigh <= Bid) CurOpen = PrevHigh;
        else if(PrevLow >= Bid) CurOpen = PrevLow;
        else CurOpen = Bid;
        
        CurClose = Bid;
        
        FileWriteInteger(HstHandle, PrevTime, LONG_VALUE);        // Time
        FileWriteDouble(HstHandle, CurOpen, DOUBLE_VALUE);             // Open
        FileWriteDouble(HstHandle, CurLow, DOUBLE_VALUE);        // Low
        FileWriteDouble(HstHandle, CurHigh, DOUBLE_VALUE);        // High
        FileWriteDouble(HstHandle, CurClose, DOUBLE_VALUE);        // Close
        FileWriteDouble(HstHandle, CurVolume, DOUBLE_VALUE);        // Volume                
            FileFlush(HstHandle);
            
        UpdateChartWindow();            
      }
         

   // Show prett comments on the Renko builder chart...
   AddRenkoComment(BoxPoints);
         
   return;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if(HstHandle >= 0) {
        FileClose(HstHandle);
        HstHandle = -1;
    }
       Comment("");
    return;
}
//+------------------------------------------------------------------+

double CalculateATRBoxSize(string instrument, int atr_timeframe, int atr_period, int atr_shift, int ma_method, int ma_period){

   double ATR_Value[];
   
   if(UseATRMA){
      ArrayResize(ATR_Value, ma_period);
      ArrayInitialize(ATR_Value,0);
      for (int i = 0; i < ma_period; i++){
         ATR_Value[i] = iATR(instrument,atr_timeframe,atr_period,atr_shift+i);
      }
      return (iMAOnArray(ATR_Value,0,ma_period,0,ma_method,0));
   } else {
      return(iATR(instrument,atr_timeframe,atr_period,atr_shift));
   }
   return(0);
}

//
// AddRenkoComment() - Tim Welch v4.13
// 
// This just adds the comment to the top left of the Chart. I had to pull
// this out into its own function as part of adding the ability to build
// charts while the market is closed.
void AddRenkoComment(double BP) 
  {

   string text="\n ========================\n";
   text = text + "   RENKO LIVE CHART " + RENKO_VERSION + " (" + DoubleToStr(BP/pt,1) + " pips)\n";
   text = text + " ========================\n";

   if(WindowHandle(SymbName,RenkoTimeFrame)==0)
     {
      text = text + "   Go to Menu FILE > OPEN OFFLINE\n";
      text = text + "   Select >> "+ SymbName+ ",M"+ RenkoTimeFrame+ " <<\n";
      text = text + "   and click OPEN to view chart.";
        } else {
      text=text+"  You can MINIMIZE this window, now!\n";
     }

   Comment(text);

  }
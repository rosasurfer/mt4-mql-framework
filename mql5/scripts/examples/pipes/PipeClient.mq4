//+------------------------------------------------------------------+
//|                                                   PipeClient.mq4 |
//|                   Copyright 2012-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2012-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property version     "1.00"
#property description "Pipe client sample using CFilePipe standard class"
#property strict

#include <Files\FilePipe.mqh>

CFilePipe ExtPipe;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- wait for pipe server
   bool bfirst=true;
   while(!IsStopped())
     {
      if(ExtPipe.Open("\\\\.\\pipe\\MQL5.Pipe.Server",FILE_READ|FILE_WRITE|FILE_BIN)!=INVALID_HANDLE)
         break;
      if(bfirst)
        {
         bfirst=false;
         Print("Client: waiting for pipe server");
        }
      Sleep(250);
     }
   if(IsStopped())
      return;
   Print("Client: pipe opened");
//--- send welcome message
   if(!ExtPipe.WriteString(__FILE__+" on MQL4 build "+IntegerToString(__MQL4BUILD__)))
     {
      Print("Client: sending welcome message failed");
      return;
     }
//--- read data from server
   string str;
   int    value=0;

   if(!ExtPipe.ReadString(str))
     {
      Print("Client: reading string failed");
      return;
     }
   Print("Server: \"",str,"\" received");

   if(!ExtPipe.ReadInteger(value))
     {
      Print("Client: reading integer failed");
      return;
     }
   Print("Server: ",value," received");
//--- send data to server
   if(!ExtPipe.WriteString("Test string"))
     {
      Print("Client: sending string failed");
      return;
     }

   if(!ExtPipe.WriteInteger(value))
     {
      Print("Client: sending integer failed");
      return;
     }
//--- benchmark
   double buffer[];
   double volume=0.0;

   if(ArrayResize(buffer,1024*1024,0)==1024*1024)
     {
      uint  ticks=GetTickCount();
      //--- read 8 Mb * 128 = 1024 Mb from server
      for(int i=0; i<128 && !IsStopped(); i++)
        {
         uint items=ExtPipe.ReadArray(buffer);
         if(items!=1024*1024)
           {
            Print("Client: benchmark failed after ",volume/1024," Kb, ",items," items received");
            break;
           }
         //--- check the guard data
         if(buffer[0]!=i || buffer[1024*1024-1]!=i+1024*1024-1)
           {
            Print("Client: benchmark invalid content");
            break;
           }
         //---
         volume+=sizeof(double)*1024*1024;
        }
      if(IsStopped())
         return;
      //--- send confirmation
      value=12345;
      if(!ExtPipe.WriteInteger(value))
         Print("Client: benchmark confirmation failed ");
      //--- show statistics
      ticks=GetTickCount()-ticks;
      if(ticks>0)
         printf("Client: %.0f Mb received at %.0f Mb per second\n",volume/1024/1024,volume/1024/ticks);
      //---
      ArrayFree(buffer);
     }
//---
   ExtPipe.Close();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                               PipeClientPure.mq4 |
//|                   Copyright 2012-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2012-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property version     "1.00"
#property description "Pipe client sample using pure file functions"
#property strict

int ExtPipe=-1;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnStart()
  {
   string str_client="PipeClient on MQL4 build "+IntegerToString(__MQL4BUILD__);
   uint   size_str=StringLen(str_client);
//--- wait for pipe server
   bool bfirst=true;
   while(!IsStopped())
     {
      ExtPipe=FileOpen("\\\\.\\pipe\\MQL5.Pipe.Server",FILE_READ|FILE_WRITE|FILE_BIN|FILE_ANSI);
      if(ExtPipe>=0)
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
   FileWriteInteger(ExtPipe,size_str);
   if(FileWriteString(ExtPipe,str_client,size_str)<size_str)
     {
      Print("Client: send welcome message failed [",GetLastError(),"]");
      return;
     }
   FileFlush(ExtPipe);
   FileSeek(ExtPipe,0,SEEK_SET);
//--- read data from server
   string str;
   int    value=0,size=0,last_error=0;
//--- read string
   size=FileReadInteger(ExtPipe);
   str=FileReadString(ExtPipe,size);
   last_error=GetLastError();
   if(last_error!=0 || size!=StringLen(str))
     {
      Print("Client: read string failed [",last_error,"]");
      return;
     }
   Print("Server: \"",str,"\" received");
//--- read integer
   value=FileReadInteger(ExtPipe);
   last_error=GetLastError();
   if(last_error!=0)
     {
      Print("Client: read integer failed [",last_error,"]");
      return;
     }
   Print("Server: ",value," received");
//--- send data to server
   FileFlush(ExtPipe);
   FileSeek(ExtPipe,0,SEEK_SET);
//--- send string
   str="Test string";
   size_str=StringLen(str);
   FileWriteInteger(ExtPipe,size_str);
   if(FileWriteString(ExtPipe,str,size_str)<size_str)
     {
      Print("Client: send string failed [",GetLastError(),"]");
      return;
     }
//--- send integer
   if(FileWriteInteger(ExtPipe,value)<4)
     {
      Print("Client: send integer failed [",GetLastError(),"]");
      return;
     }
//--- benchmark
   FileFlush(ExtPipe);
   FileSeek(ExtPipe,0,SEEK_SET);
//---
   double buffer[];
   double volume=0.0;
   uint   array_size=1024*1024;

   if(ArrayResize(buffer,array_size)==array_size)
     {
      uint ticks=GetTickCount();
      //--- read 8 Mb * 128 = 1024 Mb from server
      for(int i=0; i<128; i++)
        {
         if(!WaitForRead(ExtPipe,array_size))
            break;
         if(FileReadArray(ExtPipe,buffer,0,array_size)<array_size)
           {
            Print("Client: benchmark failed after ",volume/1024," Kb");
            break;
           }
         //--- check the data
         if(buffer[0]!=i || buffer[array_size-1]!=i+array_size-1)
           {
            Print("Client: benchmark invalid content (buffer[0]=",buffer[0]," i=",i,")");
            break;
           }
         volume+=array_size*8;
        }
      if(IsStopped())
         return;
      //--- send final confirmation
      FileFlush(ExtPipe);
      FileSeek(ExtPipe,0,SEEK_SET);
      value=12345;
      if(FileWriteInteger(ExtPipe,value)<4)
         Print("Client: benchmark confirmation failed ");
      //--- show statistics
      ticks=GetTickCount()-ticks;
      if(ticks>0)
        {
         volume/=1024;
         Print("Client: ",DoubleToStr(volume/1024,0)," Mb sent in ",ticks," milliseconds at ",DoubleToStr(volume/ticks,2)," Mb per second");
        }
     }
//--- close pipe
   FileClose(ExtPipe);
//---
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool WaitForRead(int handle,uint size)
  {
//---
   while(!IsStopped())
     {
      if(FileSize(handle)>=size)
         return(true);
      Sleep(1);
     }
//---
   return(false);
  }
//+------------------------------------------------------------------+

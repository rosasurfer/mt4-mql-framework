//+------------------------------------------------------------------+
//|                                              DLLSampleTester.mq4 |
//|                 Copyright © 2005-2016, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2005-2016, MetaQuotes Software Corp."
#property link      "http://www.metaquotes.net/"

#import "DLLSample.dll"
int    GetIntValue(int);
double GetDoubleValue(double);
string GetStringValue(string);
double GetArrayItemValue(double &arr[],int,int);
bool   SetArrayItemValue(double &arr[],int,int,double);
double GetRatesItemValue(MqlRates &rates[],int,int,int);
#import

#define TIME_INDEX   0
#define OPEN_INDEX   1
#define LOW_INDEX    2
#define HIGH_INDEX   3
#define CLOSE_INDEX  4
#define VOLUME_INDEX 5
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
   double ret,some_value=10.5;
   string sret;
   int    cnt;
//--- simple dll-functions call
   cnt=GetIntValue(int(some_value));
   Print("Returned value is ",cnt);

   ret=GetDoubleValue(some_value);
   Print("Returned value is ",ret);

   sret=GetStringValue("some string");
   Print("Returned value is ",sret);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| array functions call                                             |
//+------------------------------------------------------------------+
int start()
  {
   double   price;
   double   arr[5]={1.5,2.6,3.7,4.8,5.9 };
   MqlRates rates[];
//--- get first item from passed array
   price=GetArrayItemValue(arr,5,0);
   Print("Returned from arr[0] ",price);
//--- change second item in the passed array
   if(SetArrayItemValue(arr,5,1,1234.5)==true)
      Print("Changed to ",arr[1]);
//--- get current close
   ArrayCopyRates(rates);
   price=GetRatesItemValue(rates,Bars,0,CLOSE_INDEX);
   Print("Returned from Close ",price);
//---
   return(0);
  }
//+------------------------------------------------------------------+

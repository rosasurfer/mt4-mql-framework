//+------------------------------------------------------------------+
//|                                                    Indicator.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Series.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_INDICATOR
  {
   IND_AC,           // Accelerator Oscillator
   IND_AD,           // Accumulation/Distribution
   IND_ADX,          // Average Directional Index
   IND_ADXW,         // ADX by Welles Wilder
   IND_ALLIGATOR,    // Alligator
   IND_AMA,          // Adaptive Moving Average
   IND_AO,           // Awesome Oscillator
   IND_ATR,          // Average True Range
   IND_BANDS,        // Bollinger Bands®
   IND_BEARS,        // Bears Power
   IND_BULLS,        // Bulls Power
   IND_BWMFI,        // Market Facilitation Index
   IND_CCI,          // Commodity Channel Index
   IND_CHAIKIN,      // Chaikin Oscillator
   IND_CUSTOM,       // Custom indicator
   IND_DEMA,         // Double Exponential Moving Average
   IND_DEMARKER,     // DeMarker
   IND_ENVELOPES,    // Envelopes
   IND_FORCE,        // Force Index
   IND_FRACTALS,     // Fractals
   IND_FRAMA,        // Fractal Adaptive Moving Average
   IND_GATOR,        // Gator Oscillator
   IND_ICHIMOKU,     // Ichimoku Kinko Hyo
   IND_MA,           // Moving Average
   IND_MACD,         // MACD
   IND_MFI,          // Money Flow Index
   IND_MOMENTUM,     // Momentum
   IND_OBV,          // On Balance Volume
   IND_OSMA,         // OsMA
   IND_RSI,          // Relative Strength Index
   IND_RVI,          // Relative Vigor Index
   IND_SAR,          // Parabolic SAR
   IND_STDDEV,       // Standard Deviation
   IND_STOCHASTIC,   // Stochastic Oscillator
   IND_TEMA,         // Triple Exponential Moving Average
   IND_TRIX,         // Triple Exponential Moving Averages Oscillator
   IND_VIDYA,        // Variable Index Dynamic Average
   IND_VOLUMES,      // Volumes
   IND_WPR           // Williams' Percent Range
  };
enum ENUM_APPLIED_VOLUME
  {
  };
//+------------------------------------------------------------------+
//| Class CIndicator.                                                |
//| Purpose: Base class of technical indicators.                     |
//|          Derives from class CSeries.                             |
//+------------------------------------------------------------------+
class CIndicator : public CSeries
  {
public:
                     CIndicator(void);
                    ~CIndicator(void);
   //--- method for creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const ENUM_INDICATOR type,const int num_params,const MqlParam &params[]);
   //--- methods of access to data
   virtual double    GetData(const int index) const { return(GetData(0,index)); }
   virtual double    GetData(const int buffer_num,const int index) const { return (0); }
   //--- methods of conversion of constants to strings
   string            MethodDescription(const int val) const;
   string            PriceDescription(const int val) const;
   string            VolumeDescription(const int val) const;

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int num_params,const MqlParam &params[]) {return(false);}
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CIndicator::CIndicator(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
void CIndicator::~CIndicator(void)
  {
  }
//+------------------------------------------------------------------+
//| Creation of the indicator with universal parameters              |
//+------------------------------------------------------------------+
bool CIndicator::Create(const string symbol,const ENUM_TIMEFRAMES period,
                        const ENUM_INDICATOR type,const int num_params,const MqlParam &params[])
  {
//--- check history
   SetSymbolPeriod(symbol,period);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Converting value of ENUM_MA_METHOD into string                   |
//+------------------------------------------------------------------+
string CIndicator::MethodDescription(const int val) const
  {
   string str;
//--- array for conversion of ENUM_MA_METHOD to string
   static string _m_str[]={"SMA","EMA","SMMA","LWMA"};
//--- check
   if(val<0)
      return("ERROR");
//---
   if(val<4)
      str=_m_str[val];
   else
   if(val<10)
      str="METHOD_UNKNOWN="+IntegerToString(val);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Converting value of ENUM_APPLIED_PRICE into string               |
//+------------------------------------------------------------------+
string CIndicator::PriceDescription(const int val) const
  {
   string str;
//--- array for conversion of ENUM_APPLIED_PRICE to string
   static string _a_str[]={"Close","Open","High","Low","Median","Typical","Weighted"};
//--- check
   if(val<0)
      return("Unknown");
//---
   if(val<7)
      str=_a_str[val];
   else
     {
      if(val<10)
         str="PriceUnknown="+IntegerToString(val);
      else
         str="AppliedHandle="+IntegerToString(val);
     }
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Converting value of ENUM_APPLIED_VOLUME into string              |
//+------------------------------------------------------------------+
string CIndicator::VolumeDescription(const int val) const
  {
   string str;
//--- array for conversion of ENUM_APPLIED_VOLUME to string
   static string _v_str[]={"None","Tick","Real"};
//--- check
   if(val<0)
      return("Unknown");
//---
   if(val<3)
      str=_v_str[val];
   else
     {
      if(val<10)
         str="VolumeUnknown="+IntegerToString(val);
      else
         str="AppliedHandle="+IntegerToString(val);
     }
//---
   return(str);
  }
//+------------------------------------------------------------------+

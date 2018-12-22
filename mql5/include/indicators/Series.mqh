//+------------------------------------------------------------------+
//|                                                       Series.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include <Object.mqh>
//+------------------------------------------------------------------+
//| Class CSeries.                                                   |
//| Purpose: Base class for access to timeseries.                    |
//|          Derives from class CObject.                             |
//+------------------------------------------------------------------+
class CSeries : public CObject
  {
protected:
   string            m_name;             // name of series
   int               m_buffers_total;    // number of buffers
   int               m_timeframe_flags;  // flags of timeframes (similar to "flags of visibility of objects")
   string            m_symbol;           // symbol
   int               m_period;           // period

public:
                     CSeries(void);
                    ~CSeries(void);
   //--- methods of access to protected data
   string            Name(void)                const { return(m_name);            }
   int               BuffersTotal(void)        const { return(m_buffers_total);   }
   int               Timeframe(void)           const { return(m_timeframe_flags); }
   string            Symbol(void)              const { return(m_symbol);          }
   int               Period(void)              const { return(m_period);          }
   string            PeriodDescription(const int val=0);
   //--- method of tuning
   virtual bool      BufferResize(const int size)    { return(true);              }
   //--- method of refreshing" of the data
   virtual void      Refresh(const int flags=OBJ_ALL_PERIODS)  {                  }

protected:
   //--- methods of tuning
   void              SetSymbolPeriod(const string symbol,const int period);
   void              PeriodToTimeframeFlag(const ENUM_TIMEFRAMES period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
void CSeries::CSeries(void) : m_name(""),
                              m_timeframe_flags(0),
                              m_buffers_total(0),
                              m_symbol(""),
                              m_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSeries::~CSeries(void)
  {
  }
//+------------------------------------------------------------------+
//| Set symbol and period                                            |
//+------------------------------------------------------------------+
void CSeries::SetSymbolPeriod(const string symbol,const int period)
  {
   m_symbol=(symbol==NULL) ? Symbol() : symbol;
   m_period=(period==0)    ? Period() : period;
   PeriodToTimeframeFlag((ENUM_TIMEFRAMES)m_period);
  }
//+------------------------------------------------------------------+
//| Convert period to timeframe flag (similar to visibility flags)   |
//+------------------------------------------------------------------+
void CSeries::PeriodToTimeframeFlag(const ENUM_TIMEFRAMES period)
  {
   static ENUM_TIMEFRAMES _p_int[]=
     {
      PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_M30,
      PERIOD_H1,PERIOD_H4,PERIOD_D1,PERIOD_W1,PERIOD_MN1
     };
//--- cycle for all timeframes
   for(int i=0;i<ArraySize(_p_int);i++)
      if(period==_p_int[i])
        {
         //--- at the same time generate the flag of the working timeframe
         m_timeframe_flags=((int)1)<<i;
         return;
        }
  }
//+------------------------------------------------------------------+
//| Converting value of ENUM_TIMEFRAMES to string                    |
//+------------------------------------------------------------------+
string CSeries::PeriodDescription(const int val)
  {
   int i,frame;
//--- arrays for conversion of ENUM_TIMEFRAMES to string
   static string _p_str[]=
     {
      "M1","M2","M3","M4","M5","M6","M10","M12","M15","M20","M30",
      "H1","H2","H3","H4","H6","H8","H12","D1","W1","MN","UNKNOWN"
     };
   static int _p_int[]=
     {
      PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,
      PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,PERIOD_M30,
      PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,
      PERIOD_D1,PERIOD_W1,PERIOD_MN1
     };
//--- check
   frame=(val==0)?m_period:val;
///   if(frame==WRONG_VALUE)
   if(frame==-1)
      return("WRONG_VALUE");
//--- cycle for all timeframes
   for(i=0;i<ArraySize(_p_int);i++)
      if(frame==_p_int[i])
         break;
//---
   return(_p_str[i]);
  }
//+------------------------------------------------------------------+

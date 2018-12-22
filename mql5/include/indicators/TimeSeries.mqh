//+------------------------------------------------------------------+
//|                                                   TimeSeries.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Series.mqh"
//+------------------------------------------------------------------+
//| Class CPriceSeries.                                              |
//| Purpose: Base class of price series.                             |
//|          Derives from class CSeries.                             |
//+------------------------------------------------------------------+
class CPriceSeries : public CSeries
  {
public:
                     CPriceSeries(void);
                    ~CPriceSeries(void);
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods for searching extremum
   virtual int       MinIndex(const int start,const int count) const { return(0); }
   virtual double    MinValue(const int start,const int count,int &index) const;
   virtual int       MaxIndex(const int start,const int count) const { return(0); }
   virtual double    MaxValue(const int start,const int count,int &index) const;
   //--- methods of access to data
   virtual double    GetData(const int index) const { return(0); }
   //--- operator
   double operator [](const int index) { return(GetData(index)); }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPriceSeries::CPriceSeries(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPriceSeries::~CPriceSeries(void)
  {
  }
//+------------------------------------------------------------------+
//| Creation of price series                                         |
//+------------------------------------------------------------------+
bool CPriceSeries::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
   SetSymbolPeriod(symbol,period);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
double CPriceSeries::MinValue(const int start,const int count,int &index) const
  {
   index=MinIndex(start,count);
//---
   return(GetData(index));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
double CPriceSeries::MaxValue(const int start,const int count,int &index) const
  {
   index=MaxIndex(start,count);
//---
   return(GetData(index));
  }
//+------------------------------------------------------------------+
//| Class CiOpen.                                                    |
//| Purpose: Class of open series.                                   |
//|          Derives from class CPriceSeries.                        |
//+------------------------------------------------------------------+
class CiOpen : public CPriceSeries
  {
public:
                     CiOpen(void);
                    ~CiOpen(void);
   //--- methods for searching extremum
   virtual int       MinIndex(const int start,const int count) const;
   virtual int       MaxIndex(const int start,const int count) const;
   //--- methods of access to data
   virtual double    GetData(const int index) const;
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiOpen::CiOpen(void)
  {
   m_name="Open";
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiOpen::~CiOpen(void)
  {
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiOpen::MinIndex(const int start,const int count) const
  {
   return(iLowest(m_symbol,m_period,MODE_OPEN,count,start));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiOpen::MaxIndex(const int start,const int count) const
  {
   return(iHighest(m_symbol,m_period,MODE_OPEN,count,start));
  }
//+------------------------------------------------------------------+
//| Method to access data                                            |
//+------------------------------------------------------------------+
double CiOpen::GetData(const int index) const
  {
   return(iOpen(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Class CiHigh.                                                    |
//| Purpose: Class of high series.                                   |
//|          Derives from class CPriceSeries.                        |
//+------------------------------------------------------------------+
class CiHigh : public CPriceSeries
  {
public:
                     CiHigh(void);
                    ~CiHigh(void);
   //--- methods for searching extremum
   virtual int       MinIndex(const int start,const int count) const;
   virtual int       MaxIndex(const int start,const int count) const;
   //--- methods of access to data
   virtual double    GetData(const int index) const;
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiHigh::CiHigh(void)
  {
   m_name="High";
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiHigh::~CiHigh(void)
  {
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiHigh::MinIndex(const int start,const int count) const
  {
   return(iLowest(m_symbol,m_period,MODE_HIGH,count,start));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiHigh::MaxIndex(const int start,const int count) const
  {
   return(iHighest(m_symbol,m_period,MODE_HIGH,count,start));
  }
//+------------------------------------------------------------------+
//| Method to access data                                            |
//+------------------------------------------------------------------+
double CiHigh::GetData(const int index) const
  {
   return(iHigh(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Class CiLow.                                                     |
//| Purpose: Class of low series.                                    |
//|          Derives from class CPriceSeries.                        |
//+------------------------------------------------------------------+
class CiLow : public CPriceSeries
  {
public:
                     CiLow(void);
                    ~CiLow(void);
   //--- methods for searching extremum
   virtual int       MinIndex(const int start,const int count) const;
   virtual int       MaxIndex(const int start,const int count) const;
   //--- methods of access to data
   virtual double    GetData(const int index) const;
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiLow::CiLow(void)
  {
   m_name="Low";
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiLow::~CiLow(void)
  {
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiLow::MinIndex(const int start,const int count) const
  {
   return(iLowest(m_symbol,m_period,MODE_LOW,count,start));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiLow::MaxIndex(const int start,const int count) const
  {
   return(iHighest(m_symbol,m_period,MODE_LOW,count,start));
  }
//+------------------------------------------------------------------+
//| Method to access data                                            |
//+------------------------------------------------------------------+
double CiLow::GetData(const int index) const
  {
   return(iLow(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Class CiClose.                                                   |
//| Purpose: Class of close series.                                  |
//|          Derives from class CPriceSeries.                        |
//+------------------------------------------------------------------+
class CiClose : public CPriceSeries
  {
public:
                     CiClose(void);
                    ~CiClose(void);
   //--- methods for searching extremum
   virtual int       MinIndex(const int start,const int count) const;
   virtual int       MaxIndex(const int start,const int count) const;
   //--- methods of access to data
   virtual double    GetData(const int index) const;
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiClose::CiClose(void)
  {
   m_name="Close";
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiClose::~CiClose(void)
  {
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiClose::MinIndex(const int start,const int count) const
  {
   return(iLowest(m_symbol,m_period,MODE_CLOSE,count,start));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiClose::MaxIndex(const int start,const int count) const
  {
   return(iHighest(m_symbol,m_period,MODE_CLOSE,count,start));
  }
//+------------------------------------------------------------------+
//| Method to access data                                            |
//+------------------------------------------------------------------+
double CiClose::GetData(const int index) const
  {
   return(iClose(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Class CiTime.                                                    |
//| Purpose: Class of time series.                                   |
//|          Derives from class CSeries.                             |
//+------------------------------------------------------------------+
class CiTime : public CSeries
  {
public:
                     CiTime(void);
                    ~CiTime(void);
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods for searching extremum
   int               MinIndex(const int start,const int count) const;
   datetime          MinValue(const int start,const int count,int &index) const;
   int               MaxIndex(const int start,const int count) const;
   datetime          MaxValue(const int start,const int count,int &index) const;
   //--- methods of access to data
   datetime          GetData(const int index) const;
   //--- operator
   datetime operator [](const int index) { return(GetData(index)); }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiTime::CiTime(void)
  {
   m_name="Time";
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiTime::~CiTime(void)
  {
  }
//+------------------------------------------------------------------+
//| Creating of the time series                                      |
//+------------------------------------------------------------------+
bool CiTime::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
   SetSymbolPeriod(symbol,period);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiTime::MinIndex(const int start,const int count) const
  {
   return(iLowest(m_symbol,m_period,MODE_TIME,count,start));
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
datetime CiTime::MinValue(const int start,const int count,int &index) const
  {
   index=MinIndex(start,count);
//---
   return(GetData(index));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiTime::MaxIndex(const int start,const int count) const
  {
   return(iHighest(m_symbol,m_period,MODE_TIME,count,start));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
datetime CiTime::MaxValue(const int start,const int count,int &index) const
  {
   index=MaxIndex(start,count);
//---
   return(GetData(index));
  }
//+------------------------------------------------------------------+
//| Method to access data                                            |
//+------------------------------------------------------------------+
datetime CiTime::GetData(const int index) const
  {
   return(iTime(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Class CiVolume.                                                  |
//| Purpose: Class of volume series.                                 |
//|          Derives from class CSeries.                             |
//+------------------------------------------------------------------+
class CiVolume : public CSeries
  {
public:
                     CiVolume(void);
                    ~CiVolume(void);
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods for searching extremum
   int               MinIndex(const int start,const int count) const;
   long              MinValue(const int start,const int count,int &index) const;
   int               MaxIndex(const int start,const int count) const;
   long              MaxValue(const int start,const int count,int &index) const;
   //--- methods of access to data
   long              GetData(const int index) const;
   //--- operator
   long operator [](const int index) { return(GetData(index)); }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiVolume::CiVolume(void)
  {
   m_name="Volume";
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiVolume::~CiVolume(void)
  {
  }
//+------------------------------------------------------------------+
//| Creation of the tick volume series                               |
//+------------------------------------------------------------------+
bool CiVolume::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
   SetSymbolPeriod(symbol,period);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiVolume::MinIndex(const int start,const int count) const
  {
   return(iLowest(m_symbol,m_period,MODE_VOLUME,count,start));
  }
//+------------------------------------------------------------------+
//| Find minimum of specified buffer                                 |
//+------------------------------------------------------------------+
long CiVolume::MinValue(const int start,const int count,int &index) const
  {
   index=MinIndex(start,count);
//---
   return(GetData(index));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
int CiVolume::MaxIndex(const int start,const int count) const
  {
   return(iHighest(m_symbol,m_period,MODE_VOLUME,count,start));
  }
//+------------------------------------------------------------------+
//| Find maximum of specified buffer                                 |
//+------------------------------------------------------------------+
long CiVolume::MaxValue(const int start,const int count,int &index) const
  {
   index=MaxIndex(start,count);
//---
   return(GetData(index));
  }
//+------------------------------------------------------------------+
//| Method to access data                                            |
//+------------------------------------------------------------------+
long CiVolume::GetData(const int index) const
  {
   return((long)iVolume(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                      Volumes.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Indicator.mqh"
//+------------------------------------------------------------------+
//| Class CiAD.                                                      |
//| Purpose: Class of the "Accumulation/Distribution" indicator.     |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiAD : public CIndicator
  {
protected:
   ENUM_APPLIED_VOLUME m_applied;        // applied volume

public:
                     CiAD(void);
                    ~CiAD(void);
   //--- methods of access to protected data
   ENUM_APPLIED_VOLUME Applied(void) const { return(m_applied); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_AD); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiAD::CiAD(void) : m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiAD::~CiAD(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Accumulation/Distribution" indicator                 |
//+------------------------------------------------------------------+
bool CiAD::Create(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiAD::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(ENUM_APPLIED_VOLUME)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiAD::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied)
  {
   m_name="AD";
//--- save settings
   m_applied=applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Accumulation/Distribution"                  |
//+------------------------------------------------------------------+
double CiAD::GetData(const int buffer_num,const int index) const
  {
   return(iAD(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Accumulation/Distribution"                  |
//+------------------------------------------------------------------+
double CiAD::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiMFI.                                                     |
//| Purpose: Class of the "Money Flow Index" indicator.              |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiMFI : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiMFI(void);
                    ~CiMFI(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_MFI); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiMFI::CiMFI(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiMFI::~CiMFI(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Money Flow Index" indicator                          |
//+------------------------------------------------------------------+
bool CiMFI::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiMFI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiMFI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="MFI";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Money Flow Index"                           |
//+------------------------------------------------------------------+
double CiMFI::GetData(const int buffer_num,const int index) const
  {
   return(iMFI(m_symbol,m_period,m_ma_period,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Money Flow Index"                           |
//+------------------------------------------------------------------+
double CiMFI::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiOBV.                                                     |
//| Purpose: Class of the "On Balance Volume" indicator.             |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiOBV : public CIndicator
  {
protected:
   ENUM_APPLIED_PRICE m_applied;

public:
                     CiOBV(void);
                    ~CiOBV(void);
   //--- methods of access to protected data
   ENUM_APPLIED_PRICE Applied(void) const { return(m_applied); }
   //--- method create
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_PRICE applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const  { return(IND_OBV); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_PRICE applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiOBV::CiOBV(void) : m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiOBV::~CiOBV(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "On Balance Volume" indicator                         |
//+------------------------------------------------------------------+
bool CiOBV::Create(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_PRICE applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiOBV::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(ENUM_APPLIED_PRICE)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiOBV::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_PRICE applied)
  {
   m_name="OBV";
//--- save settings
   m_applied=applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "On Balance Volume"                          |
//+------------------------------------------------------------------+
double CiOBV::GetData(const int buffer_num,const int index) const
  {
   return(iOBV(m_symbol,m_period,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "On Balance Volume"                          |
//+------------------------------------------------------------------+
double CiOBV::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+

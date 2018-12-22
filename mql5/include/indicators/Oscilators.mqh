//+------------------------------------------------------------------+
//|                                                   Oscilators.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Indicator.mqh"
//+------------------------------------------------------------------+
//| Class CiATR.                                                     |
//| Purpose: Class of the "Average True Range" idnicator.            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiATR : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiATR(void);
                    ~CiATR(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_ATR); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiATR::CiATR(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiATR::~CiATR(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Average True Range" indicator                        |
//+------------------------------------------------------------------+
bool CiATR::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiATR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiATR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="ATR";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Average True Range"                         |
//+------------------------------------------------------------------+
double CiATR::Main(const int index) const
  {
   return(iATR(m_symbol,m_period,m_ma_period,index));
  }
//+------------------------------------------------------------------+
//| Class CiBearsPower.                                              |
//| Purpose: Class indicator "Bears Power".                          |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiBearsPower : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiBearsPower(void);
                    ~CiBearsPower(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method create
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_BEARS); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiBearsPower::CiBearsPower(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiBearsPower::~CiBearsPower(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Bears Power" indicator                               |
//+------------------------------------------------------------------+
bool CiBearsPower::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiBearsPower::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiBearsPower::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="BearsPower";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Bears Power"                                |
//+------------------------------------------------------------------+
double CiBearsPower::GetData(const int buffer_num,const int index) const
  {
   return(iBearsPower(m_symbol,m_period,m_ma_period,PRICE_CLOSE,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Bears Power"                                |
//+------------------------------------------------------------------+
double CiBearsPower::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiBullsPower.                                              |
//| Purpose: Class of the "Bulls Power" indicator.                   |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiBullsPower : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiBullsPower(void);
                    ~CiBullsPower(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method create
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_BULLS); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiBullsPower::CiBullsPower(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiBullsPower::~CiBullsPower(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Bulls Power"                                   |
//+------------------------------------------------------------------+
bool CiBullsPower::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiBullsPower::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiBullsPower::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="BullsPower";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Bulls Power"                                |
//+------------------------------------------------------------------+
double CiBullsPower::GetData(const int buffer_num,const int index) const
  {
   return(iBullsPower(m_symbol,m_period,m_ma_period,PRICE_CLOSE,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Bulls Power"                                |
//+------------------------------------------------------------------+
double CiBullsPower::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiCCI.                                                     |
//| Purpose: Class of the "Commodity Channel Index" indicator.       |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiCCI : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_applied;

public:
                     CiCCI(void);
                    ~CiCCI(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   int               Applied(void)         const { return(m_applied);   }
   //--- method create
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_CCI); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiCCI::CiCCI(void) : m_ma_period(-1),
                     m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiCCI::~CiCCI(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Commodity Channel Index" indicator                   |
//+------------------------------------------------------------------+
bool CiCCI::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiCCI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value));
  }
//+------------------------------------------------------------------+
//| Create the "Commodity Channel Index" indicator                   |
//+------------------------------------------------------------------+
bool CiCCI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied)
  {
   m_name="CCI";
//--- save settings
   m_ma_period=ma_period;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Commodity Channel Index"                    |
//+------------------------------------------------------------------+
double CiCCI::GetData(const int buffer_num,const int index) const
  {
   return(iCCI(m_symbol,m_period,m_ma_period,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Commodity Channel Index"                    |
//+------------------------------------------------------------------+
double CiCCI::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiDeMarker.                                                |
//| Purpose: Class of the "DeMarker" indicator.                      |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiDeMarker : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiDeMarker(void);
                    ~CiDeMarker(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_DEMARKER); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiDeMarker::CiDeMarker(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiDeMarker::~CiDeMarker(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "DeMarker"                                      |
//+------------------------------------------------------------------+
bool CiDeMarker::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiDeMarker::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiDeMarker::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="DeMarker";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "DeMarker"                                   |
//+------------------------------------------------------------------+
double CiDeMarker::GetData(const int buffer_num,const int index) const
  {
   return(iDeMarker(m_symbol,m_period,m_ma_period,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "DeMarker"                                   |
//+------------------------------------------------------------------+
double CiDeMarker::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiForce.                                                   |
//| Purpose: Class of the "Force Index" indicator.                   |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiForce : public CIndicator
  {
protected:
   int               m_ma_period;
   ENUM_MA_METHOD    m_ma_method;
   ENUM_APPLIED_PRICE m_applied;

public:
                     CiForce(void);
                    ~CiForce(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   ENUM_MA_METHOD    MaMethod(void)        const { return(m_ma_method); }
   ENUM_APPLIED_PRICE Applied(void)        const { return(m_applied);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int ma_period,const ENUM_MA_METHOD ma_method,const ENUM_APPLIED_PRICE applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_FORCE); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int ma_period,const ENUM_MA_METHOD ma_method,const ENUM_APPLIED_PRICE applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiForce::CiForce(void) : m_ma_period(-1),
                         m_ma_method(-1),
                         m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiForce::~CiForce(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Force Index"                                   |
//+------------------------------------------------------------------+
bool CiForce::Create(const string symbol,const ENUM_TIMEFRAMES period,
                     const int ma_period,const ENUM_MA_METHOD ma_method,const ENUM_APPLIED_PRICE applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,ma_method,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiForce::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(ENUM_MA_METHOD)params[1].integer_value,
          (ENUM_APPLIED_PRICE)params[2].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiForce::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                         const int ma_period,const ENUM_MA_METHOD ma_method,const ENUM_APPLIED_PRICE applied)
  {
   m_name="Force";
//--- save settings
   m_ma_period=ma_period;
   m_ma_method=ma_method;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Force Index"                                |
//+------------------------------------------------------------------+
double CiForce::GetData(const int buffer_num,const int index) const
  {
   return(iForce(m_symbol,m_period,m_ma_period,m_ma_method,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Force Index"                                |
//+------------------------------------------------------------------+
double CiForce::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiMACD.                                                    |
//| Purpose: Class of the "Moving Averages                           |
//|          Convergence-Divergence" indicator.                      |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiMACD : public CIndicator
  {
protected:
   int               m_fast_ema_period;
   int               m_slow_ema_period;
   int               m_signal_period;
   int               m_applied;

public:
                     CiMACD(void);
                    ~CiMACD(void);
   //--- methods of access to protected data
   int               FastEmaPeriod(void)     const { return(m_fast_ema_period); }
   int               SlowEmaPeriod(void)     const { return(m_slow_ema_period); }
   int               SignalPeriod(void)      const { return(m_signal_period);   }
   int               Applied(void)           const { return(m_applied);         }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int fast_ema_period,const int slow_ema_period,
                            const int signal_period,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   double            Signal(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_MACD); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int fast_ema_period,const int slow_ema_period,
                                const int signal_period,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiMACD::CiMACD(void) : m_fast_ema_period(-1),
                       m_slow_ema_period(-1),
                       m_signal_period(-1),
                       m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiMACD::~CiMACD(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Moving Averages Convergence-Divergence" indicator    |
//+------------------------------------------------------------------+
bool CiMACD::Create(const string symbol,const ENUM_TIMEFRAMES period,
                    const int fast_ema_period,const int slow_ema_period,
                    const int signal_period,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,fast_ema_period,slow_ema_period,signal_period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiMACD::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (int)params[2].integer_value,(int)params[3].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiMACD::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                        const int fast_ema_period,const int slow_ema_period,
                        const int signal_period,const int applied)
  {
   m_name="MACD";
//--- save settings
   m_fast_ema_period=fast_ema_period;
   m_slow_ema_period=slow_ema_period;
   m_signal_period  =signal_period;
   m_applied        =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Moving Averages Convergence-Divergence"     |
//+------------------------------------------------------------------+
double CiMACD::GetData(const int buffer_num,const int index) const
  {
   return(iMACD(m_symbol,m_period,m_fast_ema_period,m_slow_ema_period,m_signal_period,buffer_num,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to Main buffer of "Moving Averages                        |
//|                           Convergence-Divergence"                |
//+------------------------------------------------------------------+
double CiMACD::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Access to Signal buffer of "Moving Averages                      |
//|                             Convergence-Divergence"              |
//+------------------------------------------------------------------+
double CiMACD::Signal(const int index) const
  {
   return(GetData(1,index));
  }
//+------------------------------------------------------------------+
//| Class CiMomentum.                                                |
//| Purpose: Class of the "Momentum" indicator.                      |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiMomentum : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_applied;

public:
                     CiMomentum(void);
                    ~CiMomentum(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   int               Applied(void)         const { return(m_applied);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_MOMENTUM); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiMomentum::CiMomentum(void) : m_ma_period(-1),
                               m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiMomentum::~CiMomentum(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Momentum" indicator                                  |
//+------------------------------------------------------------------+
bool CiMomentum::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiMomentum::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiMomentum::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied)
  {
   m_name="Momentum";
//--- save settings
   m_ma_period=ma_period;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Momentum"                                   |
//+------------------------------------------------------------------+
double CiMomentum::GetData(const int buffer_num,const int index) const
  {
   return(iMomentum(m_symbol,m_period,m_ma_period,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Momentum"                                   |
//+------------------------------------------------------------------+
double CiMomentum::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiOsMA.                                                    |
//| Purpose: Class of the "Moving Average of Oscillator              |
//|          (MACD histogram)" indicator.                            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiOsMA : public CIndicator
  {
protected:
   int               m_fast_ema_period;
   int               m_slow_ema_period;
   int               m_signal_period;
   int               m_applied;

public:
                     CiOsMA(void);
                    ~CiOsMA(void);
   //--- methods of access to protected data
   int               FastEmaPeriod(void)   const { return(m_fast_ema_period); }
   int               SlowEmaPeriod(void)   const { return(m_slow_ema_period); }
   int               SignalPeriod(void)    const { return(m_signal_period);   }
   int               Applied(void)         const { return(m_applied);         }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int fast_ema_period,const int slow_ema_period,
                            const int signal_period,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_OSMA); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int fast_ema_period,const int slow_ema_period,
                                const int signal_period,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiOsMA::CiOsMA(void) : m_fast_ema_period(-1),
                       m_slow_ema_period(-1),
                       m_signal_period(-1),
                       m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiOsMA::~CiOsMA(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Moving Average of Oscillator                   |
//| (MACD histogram)"                                                |
//+------------------------------------------------------------------+
bool CiOsMA::Create(const string symbol,const ENUM_TIMEFRAMES period,
                    const int fast_ema_period,const int slow_ema_period,
                    const int signal_period,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,fast_ema_period,slow_ema_period,signal_period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiOsMA::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (int)params[2].integer_value,(int)params[3].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiOsMA::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                        const int fast_ema_period,const int slow_ema_period,
                        const int signal_period,const int applied)
  {
   m_name="OsMA";
//--- save settings
   m_fast_ema_period=fast_ema_period;
   m_slow_ema_period=slow_ema_period;
   m_signal_period  =signal_period;
   m_applied        =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Moving Average of Oscillator                |
//|                     (MACD histogram)"                            |
//+------------------------------------------------------------------+
double CiOsMA::GetData(const int buffer_num,const int index) const
  {
   return(iOsMA(m_symbol,m_period,m_fast_ema_period,m_slow_ema_period,m_signal_period,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Moving Average of Oscillator                |
//|                     (MACD histogram)"                            |
//+------------------------------------------------------------------+
double CiOsMA::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiRSI.                                                     |
//| Purpose: Class of the "Relative Strength Index" indicator.       |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiRSI : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_applied;

public:
                     CiRSI(void);
                    ~CiRSI(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   int               Applied(void)         const { return(m_applied);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_RSI); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiRSI::CiRSI(void) : m_ma_period(-1),
                     m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiRSI::~CiRSI(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Relative Strength Index"                       |
//+------------------------------------------------------------------+
bool CiRSI::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiRSI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiRSI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period,const int applied)
  {
   m_name="RSI";
//--- save settings
   m_ma_period=ma_period;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Relative Strength Index"                    |
//+------------------------------------------------------------------+
double CiRSI::GetData(const int buffer_num,const int index) const
  {
   return(iRSI(m_symbol,m_period,m_ma_period,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Relative Strength Index"                    |
//+------------------------------------------------------------------+
double CiRSI::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiRVI.                                                     |
//| Purpose: Class of the "Relative Vigor Index" indicator.          |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiRVI : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiRVI(void);
                    ~CiRVI(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   double            Signal(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_RVI); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiRVI::CiRVI(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiRVI::~CiRVI(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Relative Vigor Index" indicator                      |
//+------------------------------------------------------------------+
bool CiRVI::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiRVI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiRVI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="RVI";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Relative Vigor Index"                       |
//+------------------------------------------------------------------+
double CiRVI::GetData(const int buffer_num,const int index) const
  {
   return(iRVI(m_symbol,m_period,m_ma_period,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Main buffer of "Relative Vigor Index"                  |
//+------------------------------------------------------------------+
double CiRVI::Main(const int index) const
  {
   return(GetData(MODE_MAIN,index));
  }
//+------------------------------------------------------------------+
//| Access to Signal buffer of "Relative Vigor Index"                |
//+------------------------------------------------------------------+
double CiRVI::Signal(const int index) const
  {
   return(GetData(MODE_SIGNAL,index));
  }
//+------------------------------------------------------------------+
//| Class CiStochastic.                                              |
//| Purpose: Class of the "Stochastic Oscillator" indicator.         |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiStochastic : public CIndicator
  {
protected:
   int               m_Kperiod;
   int               m_Dperiod;
   int               m_slowing;
   ENUM_MA_METHOD    m_ma_method;
   ENUM_STO_PRICE    m_price_field;

public:
                     CiStochastic(void);
                    ~CiStochastic(void);
   //--- methods of access to protected data
   int               Kperiod(void)           const { return(m_Kperiod);     }
   int               Dperiod(void)           const { return(m_Dperiod);     }
   int               Slowing(void)           const { return(m_slowing);     }
   ENUM_MA_METHOD    MaMethod(void)          const { return(m_ma_method);   }
   ENUM_STO_PRICE    PriceField(void)        const { return(m_price_field); }
   //--- method create
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int Kperiod,const int Dperiod,const int slowing,
                            const ENUM_MA_METHOD ma_method,const ENUM_STO_PRICE price_field);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   double            Signal(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_STOCHASTIC); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int Kperiod,const int Dperiod,const int slowing,
                                const ENUM_MA_METHOD ma_method,const ENUM_STO_PRICE price_field);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiStochastic::CiStochastic(void) : m_Kperiod(-1),
                                   m_Dperiod(-1),
                                   m_slowing(-1),
                                   m_ma_method(WRONG_VALUE),
                                   m_price_field(WRONG_VALUE)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiStochastic::~CiStochastic(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Stochastic Oscillator" indicator                     |
//+------------------------------------------------------------------+
bool CiStochastic::Create(const string symbol,const ENUM_TIMEFRAMES period,
                          const int Kperiod,const int Dperiod,const int slowing,
                          const ENUM_MA_METHOD ma_method,const ENUM_STO_PRICE price_field)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,Kperiod,Dperiod,slowing,ma_method,price_field));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiStochastic::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (int)params[2].integer_value,(ENUM_MA_METHOD)params[3].integer_value,
          (ENUM_STO_PRICE)params[4].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiStochastic::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                              const int Kperiod,const int Dperiod,const int slowing,
                              const ENUM_MA_METHOD ma_method,const ENUM_STO_PRICE price_field)
  {
   m_name="Stochastic";
//--- save settings
   m_Kperiod    =Kperiod;
   m_Dperiod    =Dperiod;
   m_slowing    =slowing;
   m_ma_method  =ma_method;
   m_price_field=price_field;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Stochastic Oscillator"                      |
//+------------------------------------------------------------------+
double CiStochastic::GetData(const int buffer_num,const int index) const
  {
   return(iStochastic(m_symbol,m_period,m_Kperiod,m_Dperiod,m_slowing,m_ma_method,m_price_field,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Main buffer of "Stochastic Oscillator"                 |
//+------------------------------------------------------------------+
double CiStochastic::Main(const int index) const
  {
   return(GetData(MODE_MAIN,index));
  }
//+------------------------------------------------------------------+
//| Access to Signal buffer of "Stochastic Oscillator"               |
//+------------------------------------------------------------------+
double CiStochastic::Signal(const int index) const
  {
   return(GetData(MODE_SIGNAL,index));
  }
//+------------------------------------------------------------------+
//| Class CiWPR.                                                     |
//| Purpose: Class of the "Williams' Percent Range" indicator.       |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiWPR : public CIndicator
  {
protected:
   int               m_calc_period;

public:
                     CiWPR(void);
                    ~CiWPR(void);
   //--- methods of access to protected data
   int               CalcPeriod(void) const { return(m_calc_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int calc_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const  { return(IND_WPR); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int calc_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiWPR::CiWPR(void) : m_calc_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiWPR::~CiWPR(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Williams' Percent Range" indicator                   |
//+------------------------------------------------------------------+
bool CiWPR::Create(const string symbol,const ENUM_TIMEFRAMES period,const int calc_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,calc_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiWPR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the cpecial parameters                 |
//+------------------------------------------------------------------+
bool CiWPR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int calc_period)
  {
   m_name="WPR";
//--- save settings
   m_calc_period=calc_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Williams' Percent Range"                    |
//+------------------------------------------------------------------+
double CiWPR::GetData(const int buffer_num,const int index) const
  {
   return(iWPR(m_symbol,m_period,m_calc_period,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Williams' Percent Range"                    |
//+------------------------------------------------------------------+
double CiWPR::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+

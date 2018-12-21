//+------------------------------------------------------------------+
//|                                                 BillWilliams.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Indicator.mqh"
//+------------------------------------------------------------------+
//| Class CiAC.                                                      |
//| Purpose: Class of the "Accelerator Oscillator" indicator.        |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiAC : public CIndicator
  {
public:
                     CiAC(void);
                    ~CiAC(void);
   //--- method of creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods of access to data of indicator
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_AC); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiAC::CiAC(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiAC::~CiAC(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Accelerator Oscillator" indicator                    |
//+------------------------------------------------------------------+
bool CiAC::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiAC::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiAC::Initialize(const string symbol,const ENUM_TIMEFRAMES period)
  {
   m_name="AC";
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to the buffer of "Accelerator Oscillator"                 |
//+------------------------------------------------------------------+
double CiAC::GetData(const int buffer_num,const int index) const
  {
   return(iAC(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Access to the buffer of "Accelerator Oscillator"                 |
//+------------------------------------------------------------------+
double CiAC::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiAlligator.                                               |
//| Purpose: Class of the "Alligator" indicator.                     |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiAlligator : public CIndicator
  {
protected:
   int               m_jaw_period;
   int               m_jaw_shift;
   int               m_teeth_period;
   int               m_teeth_shift;
   int               m_lips_period;
   int               m_lips_shift;
   ENUM_MA_METHOD    m_ma_method;
   int               m_applied;

public:
                     CiAlligator(void);
                    ~CiAlligator(void);
   //--- methods of access to protected data
   int               JawPeriod(void)        const { return(m_jaw_period);   }
   int               JawShift(void)         const { return(m_jaw_shift);    }
   int               TeethPeriod(void)      const { return(m_teeth_period); }
   int               TeethShift(void)       const { return(m_teeth_shift);  }
   int               LipsPeriod(void)       const { return(m_lips_period);  }
   int               LipsShift(void)        const { return(m_lips_shift);   }
   ENUM_MA_METHOD    MaMethod(void)         const { return(m_ma_method);    }
   int               Applied(void)          const { return(m_applied);      }
   //--- method of creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int jaw_period,const int jaw_shift,
                            const int teeth_period,const int teeth_shift,
                            const int lips_period,const int lips_shift,
                            const ENUM_MA_METHOD ma_method,const int applied);
   //--- methods of access to data of indicator
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Jaw(const int index) const;
   double            Teeth(const int index) const;
   double            Lips(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_ALLIGATOR); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int jaw_period,const int jaw_shift,
                                const int teeth_period,const int teeth_shift,
                                const int lips_period,const int lips_shift,
                                const ENUM_MA_METHOD ma_method,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiAlligator::CiAlligator(void) : m_jaw_period(-1),
                                 m_jaw_shift(-1),
                                 m_teeth_period(-1),
                                 m_teeth_shift(-1),
                                 m_lips_period(-1),
                                 m_lips_shift(-1),
                                 m_ma_method(-1),
                                 m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiAlligator::~CiAlligator(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Alligator" indicator                                 |
//+------------------------------------------------------------------+
bool CiAlligator::Create(const string symbol,const ENUM_TIMEFRAMES period,
                         const int jaw_period,const int jaw_shift,
                         const int teeth_period,const int teeth_shift,
                         const int lips_period,const int lips_shift,
                         const ENUM_MA_METHOD ma_method,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,jaw_period,jaw_shift,teeth_period,teeth_shift,lips_period,lips_shift,ma_method,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiAlligator::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (int)params[2].integer_value,(int)params[3].integer_value,
          (int)params[4].integer_value,(int)params[5].integer_value,
          (ENUM_MA_METHOD)params[6].integer_value,(int)params[7].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiAlligator::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                             const int jaw_period,const int jaw_shift,
                             const int teeth_period,const int teeth_shift,
                             const int lips_period,const int lips_shift,
                             const ENUM_MA_METHOD ma_method,const int applied)
  {
   m_name="Alligator";
//--- save settings
   m_jaw_period  =jaw_period;
   m_jaw_shift   =jaw_shift;
   m_teeth_period=teeth_period;
   m_teeth_shift =teeth_shift;
   m_lips_period =lips_period;
   m_lips_shift  =lips_shift;
   m_ma_method   =ma_method;
   m_applied     =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Alligator"                                  |
//+------------------------------------------------------------------+
double CiAlligator::GetData(const int buffer_num,const int index) const
  {
   return(iAlligator(m_symbol,m_period,m_jaw_period,m_jaw_shift,
                                       m_teeth_period,m_teeth_shift,
                                       m_lips_period,m_lips_shift,
                                       m_ma_method,m_applied,
                                       buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Jaw buffer of "Alligator"                              |
//+------------------------------------------------------------------+
double CiAlligator::Jaw(const int index) const
  {
   return(GetData(MODE_GATORJAW,index));
  }
//+------------------------------------------------------------------+
//| Access to Teeth buffer of "Alligator"                            |
//+------------------------------------------------------------------+
double CiAlligator::Teeth(const int index) const
  {
   return(GetData(MODE_GATORTEETH,index));
  }
//+------------------------------------------------------------------+
//| Access to Lips buffer of "Alligator"                             |
//+------------------------------------------------------------------+
double CiAlligator::Lips(const int index) const
  {
   return(GetData(MODE_GATORLIPS,index));
  }
//+------------------------------------------------------------------+
//| Class CiAO.                                                      |
//| Purpose: Class of the "Awesome Oscillator" indicator.            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiAO : public CIndicator
  {
public:
                     CiAO(void);
                    ~CiAO(void);
   //--- method of creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods of access to data of indicator
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_AO); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiAO::CiAO(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiAO::~CiAO(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Awesome Oscillator" indicator                        |
//+------------------------------------------------------------------+
bool CiAO::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiAO::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Create the "Awesome Oscillator" indicator                        |
//+------------------------------------------------------------------+
bool CiAO::Initialize(const string symbol,const ENUM_TIMEFRAMES period)
  {
   m_name="AO";
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Awesome Oscillator"                         |
//+------------------------------------------------------------------+
double CiAO::GetData(const int buffer_num,const int index) const
  {
   return(iAO(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Awesome Oscillator"                         |
//+------------------------------------------------------------------+
double CiAO::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiFractals.                                                |
//| Purpose: Class of the "Fractals" indicator.                      |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiFractals : public CIndicator
  {
public:
                     CiFractals(void);
                    ~CiFractals(void);
   //--- method of creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Upper(const int index) const;
   double            Lower(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_FRACTALS); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiFractals::CiFractals(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiFractals::~CiFractals(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Fractals" indicator                                  |
//+------------------------------------------------------------------+
bool CiFractals::Create(const string symbol,const ENUM_TIMEFRAMES period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiFractals::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiFractals::Initialize(const string symbol,const ENUM_TIMEFRAMES period)
  {
   m_name="Fractals";
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Fractals"                                   |
//+------------------------------------------------------------------+
double CiFractals::GetData(const int buffer_num,const int index) const
  {
   return(iFractals(m_symbol,m_period,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Upper buffer of "Fractals"                             |
//+------------------------------------------------------------------+
double CiFractals::Upper(const int index) const
  {
   return(GetData(MODE_UPPER,index));
  }
//+------------------------------------------------------------------+
//| Access to Lower buffer of "Fractals"                             |
//+------------------------------------------------------------------+
double CiFractals::Lower(const int index) const
  {
   return(GetData(MODE_LOWER,index));
  }
//+------------------------------------------------------------------+
//| Class CiGator.                                                   |
//| Purpose: Class of the "Gator oscillator" indicator.              |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiGator : public CIndicator
  {
protected:
   int               m_jaw_period;
   int               m_jaw_shift;
   int               m_teeth_period;
   int               m_teeth_shift;
   int               m_lips_period;
   int               m_lips_shift;
   ENUM_MA_METHOD    m_ma_method;
   int               m_applied;

public:
                     CiGator(void);
                    ~CiGator(void);
   //--- methods of access to protected data
   int               JawPeriod(void)        const { return(m_jaw_period);   }
   int               JawShift(void)         const { return(m_jaw_shift);    }
   int               TeethPeriod(void)      const { return(m_teeth_period); }
   int               TeethShift(void)       const { return(m_teeth_shift);  }
   int               LipsPeriod(void)       const { return(m_lips_period);  }
   int               LipsShift(void)        const { return(m_lips_shift);   }
   ENUM_MA_METHOD    MaMethod(void)         const { return(m_ma_method);    }
   int               Applied(void)          const { return(m_applied);      }
   //--- method of creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int jaw_period,const int jaw_shift,
                            const int teeth_period,const int teeth_shift,
                            const int lips_period,const int lips_shift,
                            const ENUM_MA_METHOD ma_method,const int applied);
   //--- methods of access to data of indicator
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Upper(const int index) const;
   double            Lower(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_GATOR); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int jaw_period,const int jaw_shift,
                                const int teeth_period,const int teeth_shift,
                                const int lips_period,const int lips_shift,
                                const ENUM_MA_METHOD ma_method,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiGator::CiGator(void) : m_jaw_period(-1),
                         m_jaw_shift(-1),
                         m_teeth_period(-1),
                         m_teeth_shift(-1),
                         m_lips_period(-1),
                         m_lips_shift(-1),
                         m_ma_method(-1),
                         m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiGator::~CiGator(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Gator oscillator"                              |
//+------------------------------------------------------------------+
bool CiGator::Create(const string symbol,const ENUM_TIMEFRAMES period,
                     const int jaw_period,const int jaw_shift,
                     const int teeth_period,const int teeth_shift,
                     const int lips_period,const int lips_shift,
                     const ENUM_MA_METHOD ma_method,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,jaw_period,jaw_shift,teeth_period,teeth_shift,lips_period,lips_shift,ma_method,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiGator::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (int)params[2].integer_value,(int)params[3].integer_value,
          (int)params[4].integer_value,(int)params[5].integer_value,
          (ENUM_MA_METHOD)params[6].integer_value,(int)params[7].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiGator::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                         const int jaw_period,const int jaw_shift,
                         const int teeth_period,const int teeth_shift,
                         const int lips_period,const int lips_shift,
                         const ENUM_MA_METHOD ma_method,const int applied)
  {
   m_name="Gator";
//--- save settings
   m_jaw_period  =jaw_period;
   m_jaw_shift   =jaw_shift;
   m_teeth_period=teeth_period;
   m_teeth_shift =teeth_shift;
   m_lips_period =lips_period;
   m_lips_shift  =lips_shift;
   m_ma_method   =ma_method;
   m_applied     =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Gator oscillator"                           |
//+------------------------------------------------------------------+
double CiGator::GetData(const int buffer_num,const int index) const
  {
   return(iGator(m_symbol,m_period,m_jaw_period,m_jaw_shift,
                                   m_teeth_period,m_teeth_shift,
                                   m_lips_period,m_lips_shift,
                                   m_ma_method,m_applied,
                                   buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Upper buffer of "Gator oscillator"                     |
//+------------------------------------------------------------------+
double CiGator::Upper(const int index) const
  {
   return(GetData(MODE_UPPER,index));
  }
//+------------------------------------------------------------------+
//| Access to Lower buffer of "Gator oscillator"                     |
//+------------------------------------------------------------------+
double CiGator::Lower(const int index) const
  {
   return(GetData(MODE_LOWER,index));
  }
//+------------------------------------------------------------------+
//| Class CiBWMFI.                                                   |
//| Purpose: Class of the "Market Facilitation Index" indicator      |
//|          by Bill Williams".                                      |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiBWMFI : public CIndicator
  {
protected:
   ENUM_APPLIED_VOLUME m_applied;

public:
                     CiBWMFI(void);
                    ~CiBWMFI(void);
   //--- methods of access to protected data
   ENUM_APPLIED_VOLUME Applied(void) const { return(m_applied); }
   //--- method of creating
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied);
   //--- methods of access to data of indicator
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_BWMFI); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiBWMFI::CiBWMFI(void) : m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiBWMFI::~CiBWMFI(void)
  {
  }
//+------------------------------------------------------------------+
//| Create "Market Facilitation Index by Bill Williams" indicator    |
//+------------------------------------------------------------------+
bool CiBWMFI::Create(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiBWMFI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(ENUM_APPLIED_VOLUME)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiBWMFI::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const ENUM_APPLIED_VOLUME applied)
  {
   m_name="BWMFI";
//--- save settings
   m_applied=applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Market Facilitation Index by Bill Williams".|
//+------------------------------------------------------------------+
double CiBWMFI::GetData(const int buffer_num,const int index) const
  {
   return(iBWMFI(m_symbol,m_period,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Market Facilitation Index by Bill Williams".|
//+------------------------------------------------------------------+
double CiBWMFI::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                        Trend.mqh |
//|                   Copyright 2009-2016, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Indicator.mqh"
//+------------------------------------------------------------------+
//| Class CiADX.                                                     |
//| Purpose: Class of the "Average Directional Index" indicator.     |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiADX : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiADX(void);
                    ~CiADX(void);
   //--- methods of access to protected data
   int               MaPeriod(void) const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   double            Plus(const int index) const;
   double            Minus(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_ADX); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiADX::CiADX(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiADX::~CiADX(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Average Directional Index" indicator                 |
//+------------------------------------------------------------------+
bool CiADX::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiADX::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiADX::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   m_name="ADX";
//--- save settings
   m_ma_period=ma_period;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Average Directional Index"                  |
//+------------------------------------------------------------------+
double CiADX::GetData(const int buffer_num,const int index) const
  {
   return(iADX(m_symbol,m_period,m_ma_period,PRICE_CLOSE,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Main buffer of "Average Directional Index"             |
//+------------------------------------------------------------------+
double CiADX::Main(const int index) const
  {
   return(GetData(MODE_MAIN,index));
  }
//+------------------------------------------------------------------+
//| Access to Plus buffer of "Average Directional Index"             |
//+------------------------------------------------------------------+
double CiADX::Plus(const int index) const
  {
   return(GetData(MODE_PLUSDI,index));
  }
//+------------------------------------------------------------------+
//| Access to Minus buffer of "Average Directional Index"            |
//+------------------------------------------------------------------+
double CiADX::Minus(const int index) const
  {
   return(GetData(MODE_MINUSDI,index));
  }
//+------------------------------------------------------------------+
//| Class CiBands.                                                   |
//| Purpose: Class of the "Bollinger Bands" indicator.               |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiBands : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_ma_shift;
   double            m_deviation;
   int               m_applied;

public:
                     CiBands(void);
                    ~CiBands(void);
   //--- methods of access to protected data
   int               MaPeriod(void)         const { return(m_ma_period); }
   int               MaShift(void)          const { return(m_ma_shift);  }
   double            Deviation(void)        const { return(m_deviation); }
   int               Applied(void)          const { return(m_applied);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int ma_period,const int ma_shift,
                            const double deviation,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Base(const int index) const;
   double            Upper(const int index) const;
   double            Lower(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_BANDS); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int ma_period,const int ma_shift,
                                const double deviation,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiBands::CiBands(void) : m_ma_period(-1),
                         m_ma_shift(-1),
                         m_deviation(EMPTY_VALUE),
                         m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiBands::~CiBands(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Bollinger Bands"                               |
//+------------------------------------------------------------------+
bool CiBands::Create(const string symbol,const ENUM_TIMEFRAMES period,
                     const int ma_period,const int ma_shift,
                     const double deviation,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,ma_shift,deviation,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiBands::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          params[2].double_value,(int)params[3].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiBands::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                         const int ma_period,const int ma_shift,
                         const double deviation,const int applied)
  {
   m_name="Bands";
//--- save settings
   m_ma_period=ma_period;
   m_ma_shift =ma_shift;
   m_deviation=deviation;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Bollinger Bands"                            |
//+------------------------------------------------------------------+
double CiBands::GetData(const int buffer_num,const int index) const
  {
   return(iBands(m_symbol,m_period,m_ma_period,(int)m_deviation,m_ma_shift,m_applied,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Base buffer of "Bollinger Bands"                       |
//+------------------------------------------------------------------+
double CiBands::Base(const int index) const
  {
   return(GetData(MODE_MAIN,index));
  }
//+------------------------------------------------------------------+
//| Access to Upper buffer of "Bollinger Bands"                      |
//+------------------------------------------------------------------+
double CiBands::Upper(const int index) const
  {
   return(GetData(MODE_UPPER,index));
  }
//+------------------------------------------------------------------+
//| Access to Lower buffer of "Bollinger Bands"                      |
//+------------------------------------------------------------------+
double CiBands::Lower(const int index) const
  {
   return(GetData(MODE_LOWER,index));
  }
//+------------------------------------------------------------------+
//| Class CiEnvelopes.                                               |
//| Purpose: Class of the "Envelopes" indicator.                     |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiEnvelopes : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_ma_shift;
   ENUM_MA_METHOD    m_ma_method;
   int               m_applied;
   double            m_deviation;

public:
                     CiEnvelopes(void);
                    ~CiEnvelopes(void);
   //--- methods of access to protected data
   int               MaPeriod(void)         const { return(m_ma_period);   }
   int               MaShift(void)          const { return(m_ma_shift);    }
   ENUM_MA_METHOD    MaMethod(void)         const { return(m_ma_method);   }
   int               Applied(void)          const { return(m_applied);     }
   double            Deviation(void)        const { return(m_deviation);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int ma_period,const int ma_shift,const ENUM_MA_METHOD ma_method,
                            const int applied,const double deviation);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Upper(const int index) const;
   double            Lower(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_ENVELOPES); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int ma_period,const int ma_shift,const ENUM_MA_METHOD ma_method,
                                const int applied,const double deviation);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiEnvelopes::CiEnvelopes(void) : m_ma_period(-1),
                                 m_ma_shift(-1),
                                 m_ma_method(WRONG_VALUE),
                                 m_applied(-1),
                                 m_deviation(EMPTY_VALUE)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiEnvelopes::~CiEnvelopes(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Envelopes"                                     |
//+------------------------------------------------------------------+
bool CiEnvelopes::Create(const string symbol,const ENUM_TIMEFRAMES period,
                         const int ma_period,const int ma_shift,const ENUM_MA_METHOD ma_method,
                         const int applied,const double deviation)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,ma_shift,ma_method,applied,deviation));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiEnvelopes::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (ENUM_MA_METHOD)params[2].integer_value,(int)params[3].integer_value,
          (int)params[4].double_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiEnvelopes::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                             const int ma_period,const int ma_shift,const ENUM_MA_METHOD ma_method,
                             const int applied,const double deviation)
  {
   m_name="Envelopes";
//--- save settings
   m_ma_period=ma_period;
   m_ma_shift =ma_shift;
   m_ma_method=ma_method;
   m_applied  =applied;
   m_deviation=deviation;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Envelopes"                                  |
//+------------------------------------------------------------------+
double CiEnvelopes::GetData(const int buffer_num,const int index) const
  {
   return(iEnvelopes(m_symbol,m_period,m_ma_period,m_ma_method,m_ma_shift,m_applied,m_deviation,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to Upper buffer of "Envelopes"                            |
//+------------------------------------------------------------------+
double CiEnvelopes::Upper(const int index) const
  {
   return(GetData(MODE_UPPER,index));
  }
//+------------------------------------------------------------------+
//| Access to Lower buffer of "Envelopes"                            |
//+------------------------------------------------------------------+
double CiEnvelopes::Lower(const int index) const
  {
   return(GetData(MODE_LOWER,index));
  }
//+------------------------------------------------------------------+
//| Class CiIchimoku.                                                |
//| Purpose: Class of the "Ichimoku Kinko Hyo" indicator.            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiIchimoku : public CIndicator
  {
protected:
   int               m_tenkan_sen;
   int               m_kijun_sen;
   int               m_senkou_span_b;

public:
                     CiIchimoku(void);
                    ~CiIchimoku(void);
   //--- methods of access to protected data
   int               TenkanSenPeriod(void)        const { return(m_tenkan_sen);    }
   int               KijunSenPeriod(void)         const { return(m_kijun_sen);     }
   int               SenkouSpanBPeriod(void)      const { return(m_senkou_span_b); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int tenkan_sen,const int kijun_sen,const int senkou_span_b);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            TenkanSen(const int index) const;
   double            KijunSen(const int index) const;
   double            SenkouSpanA(const int index) const;
   double            SenkouSpanB(const int index) const;
   double            ChinkouSpan(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_ICHIMOKU); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int tenkan_sen,const int kijun_sen,const int senkou_span_b);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiIchimoku::CiIchimoku(void) : m_tenkan_sen(-1),
                               m_kijun_sen(-1),
                               m_senkou_span_b(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiIchimoku::~CiIchimoku(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Ichimoku Kinko Hyo"                            |
//+------------------------------------------------------------------+
bool CiIchimoku::Create(const string symbol,const ENUM_TIMEFRAMES period,
                        const int tenkan_sen,const int kijun_sen,const int senkou_span_b)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,tenkan_sen,kijun_sen,senkou_span_b));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiIchimoku::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,(int)params[2].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiIchimoku::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                            const int tenkan_sen,const int kijun_sen,const int senkou_span_b)
  {
   m_name="Ichimoku";
//--- save settings
   m_tenkan_sen   =tenkan_sen;
   m_kijun_sen    =kijun_sen;
   m_senkou_span_b=senkou_span_b;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Ichimoku Kinko Hyo"                         |
//+------------------------------------------------------------------+
double CiIchimoku::GetData(const int buffer_num,const int index) const
  {
   return(iIchimoku(m_symbol,m_period,m_tenkan_sen,m_kijun_sen,m_senkou_span_b,buffer_num,index));
  }
//+------------------------------------------------------------------+
//| Access to TenkanSen buffer of "Ichimoku Kinko Hyo"               |
//+------------------------------------------------------------------+
double CiIchimoku::TenkanSen(const int index) const
  {
   return(GetData(MODE_TENKANSEN,index));
  }
//+------------------------------------------------------------------+
//| Access to KijunSen buffer of "Ichimoku Kinko Hyo"                |
//+------------------------------------------------------------------+
double CiIchimoku::KijunSen(const int index) const
  {
   return(GetData(MODE_KIJUNSEN,index));
  }
//+------------------------------------------------------------------+
//| Access to SenkouSpanA buffer of "Ichimoku Kinko Hyo"             |
//+------------------------------------------------------------------+
double CiIchimoku::SenkouSpanA(const int index) const
  {
   return(GetData(MODE_SENKOUSPANA,index));
  }
//+------------------------------------------------------------------+
//| Access to SenkouSpanB buffer of "Ichimoku Kinko Hyo"             |
//+------------------------------------------------------------------+
double CiIchimoku::SenkouSpanB(const int index) const
  {
   return(GetData(MODE_SENKOUSPANB,index));
  }
//+------------------------------------------------------------------+
//| Access to ChikouSpan buffer of "Ichimoku Kinko Hyo"              |
//+------------------------------------------------------------------+
double CiIchimoku::ChinkouSpan(const int index) const
  {
   return(GetData(MODE_CHIKOUSPAN,index));
  }
//+------------------------------------------------------------------+
//| Class CiMA.                                                      |
//| Purpose: Class of the "Moving Average" indicator.                |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiMA : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_ma_shift;
   ENUM_MA_METHOD    m_ma_method;
   int               m_applied;

public:
                     CiMA(void);
                    ~CiMA(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   int               MaShift(void)         const { return(m_ma_shift);  }
   ENUM_MA_METHOD    MaMethod(void)        const { return(m_ma_method); }
   int               Applied(void)         const { return(m_applied);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int ma_period,const int ma_shift,
                            const ENUM_MA_METHOD ma_method,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_MA); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int ma_period,const int ma_shift,
                                const ENUM_MA_METHOD ma_method,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiMA::CiMA(void) : m_ma_period(-1),
                   m_ma_shift(-1),
///                   m_ma_method(WRONG_VALUE),
                   m_ma_method(-1),
                   m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiMA::~CiMA(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Moving Average"                                |
//+------------------------------------------------------------------+
bool CiMA::Create(const string symbol,const ENUM_TIMEFRAMES period,
                  const int ma_period,const int ma_shift,
                  const ENUM_MA_METHOD ma_method,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,ma_shift,ma_method,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiMA::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (ENUM_MA_METHOD)params[2].integer_value,(int)params[3].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiMA::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                      const int ma_period,const int ma_shift,
                      const ENUM_MA_METHOD ma_method,const int applied)
  {
   m_name="MA";
//--- save settings
   m_ma_period=ma_period;
   m_ma_shift =ma_shift;
   m_ma_method=ma_method;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Moving Average"                             |
//+------------------------------------------------------------------+
double CiMA::GetData(const int buffer_num,const int index) const
  {
   return(iMA(m_symbol,m_period,m_ma_period,m_ma_shift,m_ma_method,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Moving Average"                             |
//+------------------------------------------------------------------+
double CiMA::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiSAR.                                                     |
//| Purpose: Class of the "Parabolic Stop And Reverse System"        |
//|          indicator.                                              |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiSAR : public CIndicator
  {
protected:
   double            m_step;
   double            m_maximum;

public:
                     CiSAR(void);
                    ~CiSAR(void);
   //--- methods of access to protected data
   double            SarStep(void)         const { return(m_step);    }
   double            Maximum(void)         const { return(m_maximum); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const double step,const double maximum);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_SAR); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const double step,const double maximum);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiSAR::CiSAR(void) : m_step(EMPTY_VALUE),
                     m_maximum(EMPTY_VALUE)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiSAR::~CiSAR(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Parabolic Stop And Reverse System"             |
//+------------------------------------------------------------------+
bool CiSAR::Create(const string symbol,const ENUM_TIMEFRAMES period,const double step,const double maximum)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,step,maximum));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiSAR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,params[0].double_value,params[1].double_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiSAR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const double step,const double maximum)
  {
//--- string of status of drawing
   m_name  ="SAR";
//--- save settings
   m_step   =step;
   m_maximum=maximum;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Parabolic Stop And Reverse System"          |
//+------------------------------------------------------------------+
double CiSAR::GetData(const int buffer_num,const int index) const
  {
   return(iSAR(m_symbol,m_period,m_step,m_maximum,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Parabolic Stop And Reverse System"          |
//+------------------------------------------------------------------+
double CiSAR::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+
//| Class CiStdDev.                                                  |
//| Purpose: Class indicator "Standard Deviation".                   |
//|              Derives from class CIndicator.                      |
//+------------------------------------------------------------------+
class CiStdDev : public CIndicator
  {
protected:
   int               m_ma_period;
   int               m_ma_shift;
   ENUM_MA_METHOD    m_ma_method;
   int               m_applied;

public:
                     CiStdDev(void);
                    ~CiStdDev(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   int               MaShift(void)         const { return(m_ma_shift);  }
   ENUM_MA_METHOD    MaMethod(void)        const { return(m_ma_method); }
   int               Applied(void)         const { return(m_applied);   }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,
                            const int ma_period,const int ma_shift,
                            const ENUM_MA_METHOD ma_method,const int applied);
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_STDDEV); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                                const int ma_period,const int ma_shift,
                                const ENUM_MA_METHOD ma_method,const int applied);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiStdDev::CiStdDev(void) : m_ma_period(-1),
                           m_ma_shift(-1),
                           m_ma_method(-1),
                           m_applied(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiStdDev::~CiStdDev(void)
  {
  }
//+------------------------------------------------------------------+
//| Create indicator "Standard Deviation"                            |
//+------------------------------------------------------------------+
bool CiStdDev::Create(const string symbol,const ENUM_TIMEFRAMES period,
                      const int ma_period,const int ma_shift,
                      const ENUM_MA_METHOD ma_method,const int applied)
  {
   SetSymbolPeriod(symbol,period);
//--- result of initialization
   return(Initialize(symbol,period,ma_period,ma_shift,ma_method,applied));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiStdDev::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value,(int)params[1].integer_value,
          (ENUM_MA_METHOD)params[2].integer_value,(int)params[3].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize indicator with the special parameters                 |
//+------------------------------------------------------------------+
bool CiStdDev::Initialize(const string symbol,const ENUM_TIMEFRAMES period,
                          const int ma_period,const int ma_shift,
                          const ENUM_MA_METHOD ma_method,const int applied)
  {
   m_name="StdDev";
//--- save settings
   m_ma_period=ma_period;
   m_ma_shift =ma_shift;
   m_ma_method=ma_method;
   m_applied  =applied;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Standard Deviation"                         |
//+------------------------------------------------------------------+
double CiStdDev::GetData(const int buffer_num,const int index) const
  {
   return(iStdDev(m_symbol,m_period,m_ma_period,m_ma_shift,m_ma_method,m_applied,index));
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Standard Deviation"                         |
//+------------------------------------------------------------------+
double CiStdDev::Main(const int index) const
  {
   return(GetData(0,index));
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                       Custom.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#include "Indicator.mqh"
//+------------------------------------------------------------------+
//| Class CiCustom.                                                  |
//| Purpose: Class of custom indicators.                             |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiCustom : public CIndicator
  {
protected:
   int               m_num_params;       // number of creation parameters
   MqlParam          m_params[];         // creation parameters

public:
                     CiCustom(void);
                    ~CiCustom(void);
   //--- methods of access to protected data
   bool              NumBuffers(const int buffers);
   int               NumParams(void) const { return(m_num_params); }
   ENUM_DATATYPE     ParamType(const int ind) const;
   long              ParamLong(const int ind) const;
   double            ParamDouble(const int ind) const;
   string            ParamString(const int ind) const;
   //--- methods of access to indicator data
   virtual double    GetData(const int buffer_num,const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_CUSTOM); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiCustom::CiCustom(void) : m_num_params(0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiCustom::~CiCustom(void)
  {
  }
//+------------------------------------------------------------------+
//| Set number of buffers of indicator                               |
//+------------------------------------------------------------------+
bool CiCustom::NumBuffers(const int buffers)
  {
   return(true);
  }
//+------------------------------------------------------------------+
//| Get type of specified parameter of creation                      |
//+------------------------------------------------------------------+
ENUM_DATATYPE CiCustom::ParamType(const int ind) const
  {
   if(ind>=m_num_params)
//      return(WRONG_VALUE);
      return(-1);
//---
   return(m_params[ind].type);
  }
//+------------------------------------------------------------------+
//| Get specified parameter of creatiob as a long value              |
//+------------------------------------------------------------------+
long CiCustom::ParamLong(const int ind) const
  {
   if(ind>=m_num_params)
      return(0);
   switch(m_params[ind].type)
     {
      case TYPE_DOUBLE:
      case TYPE_FLOAT:
      case TYPE_STRING:
         return(0);
     }
//---
   return(m_params[ind].integer_value);
  }
//+------------------------------------------------------------------+
//| Get specified parameter of creation as a double value            |
//+------------------------------------------------------------------+
double CiCustom::ParamDouble(const int ind) const
  {
   if(ind>=m_num_params)
      return(EMPTY_VALUE);
   switch(m_params[ind].type)
     {
      case TYPE_DOUBLE:
      case TYPE_FLOAT:
         break;
      default:
         return(EMPTY_VALUE);
     }
//---
   return(m_params[ind].double_value);
  }
//+------------------------------------------------------------------+
//| Get specified parameter of creation as a string value            |
//+------------------------------------------------------------------+
string CiCustom::ParamString(const int ind) const
  {
   if(ind>=m_num_params || m_params[ind].type!=TYPE_STRING)
      return("");
//---
   return(m_params[ind].string_value);
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiCustom::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
//--- string of status of drawing
   m_name  ="Custom "+params[0].string_value;
//--- save settings
   ArrayResize(m_params,num_params);
   for(int i=0;i<num_params;i++)
     {
      m_params[i].type         =params[i].type;
      m_params[i].double_value =params[i].double_value;
      m_params[i].integer_value=params[i].integer_value;
      m_params[i].string_value =params[i].string_value;
     }
   m_num_params=num_params;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Access to buffer of "Standard Deviation"                         |
//+------------------------------------------------------------------+
double CiCustom::GetData(const int buffer_num,const int index) const
  {
   //--- ???
   return(0);
//   return(iCustom(m_symbol,m_period,m_ma_period,m_ma_shift,m_ma_method,m_applied,index));
  }
//+------------------------------------------------------------------+

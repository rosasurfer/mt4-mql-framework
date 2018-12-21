//+------------------------------------------------------------------+
//|                                                   TimePicker.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include "WndContainer.mqh"
#include "BmpButton.mqh"
#include "Picture.mqh"
#include <Canvas\Canvas.mqh>
#include <Tools\DateTime.mqh>
//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
//--- time modes
enum ENUM_TIME_MODES
  {
   DATE_TIME_SEC,                           // seconds mode
   DATE_TIME_MIN,                           // minutes mode
   DATE_TIME_HOUR                           // hours mode
  };
//+------------------------------------------------------------------+
//| Resources                                                        |
//+------------------------------------------------------------------+
//--- Can not place the same file into resource twice
#resource "res\\SpinInc.bmp"
#resource "res\\SpinDec.bmp"
//+------------------------------------------------------------------+
//| Class CTimePicker                                                |
//| Usage: time picker                                               |
//+------------------------------------------------------------------+
class CTimePicker : public CWndContainer
  {
private:
   //--- dependent controls
   CBmpButton        m_dec;                 // the button object
   CBmpButton        m_inc;                 // the button object
   CPicture          m_edit;                // the time edit object
   CCanvas           m_canvas;              // and its canvas
   //--- adjusted parameters
   ENUM_TIME_MODES   m_mode;                // view mode
   //--- data
   CDateTime         m_value;               // current value
   //--- variable
   ENUM_TIME_MODES   m_edit_mode;           // operation mode
   CRect             m_click_rect[5];       // array of click sensibility areas on canvas

public:
                     CTimePicker(void);
                    ~CTimePicker(void);
   //--- create
   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   //--- chart event handler
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
   //--- adjusted parameters
   void              Mode(ENUM_TIME_MODES value);
   //--- data
   datetime          Value(void)                    { return(StructToTime(m_value)); }
   void              Value(datetime value)          { m_value.Time(value);           }
   void              Value(MqlDateTime& value)      { m_value=value;                 }
   //--- state
   virtual bool      Show(void);

protected:
   //--- internal event handlers
   virtual bool      OnClick(void);
   //--- create dependent controls
   virtual bool      CreateEdit(void);
   virtual bool      CreateInc(void);
   virtual bool      CreateDec(void);
   //--- draw
   void              DrawCanvas(bool select=true);
   void              DrawClickRect(const int idx,string text,const uint clr,uint alignment=0);
   void              CheckSelectHide(const int id,int x,int y);
   //--- handlers of the dependent controls events
   virtual bool      OnClickDec(void);
   virtual bool      OnClickInc(void);
   virtual bool      OnClickEdit(void);
  };
//+------------------------------------------------------------------+
//| Common handler of chart events                                   |
//+------------------------------------------------------------------+
EVENT_MAP_BEGIN(CTimePicker)
   ON_EVENT(ON_CLICK,m_dec,OnClickDec)
   ON_EVENT(ON_CLICK,m_inc,OnClickInc)
   ON_EVENT(ON_CLICK,m_edit,OnClickEdit)
   CheckSelectHide(id,(int)lparam,(int)dparam);
EVENT_MAP_END(CWndContainer)
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimePicker::CTimePicker(void) : m_mode(DATE_TIME_SEC)
  {
   ZeroMemory(m_value);
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimePicker::~CTimePicker(void)
  {
  }
//+------------------------------------------------------------------+
//| Create a control                                                 |
//+------------------------------------------------------------------+
bool CTimePicker::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
//--- need to find dimensions depending on font size
//--- call method of the parent class
   if(!CWndContainer::Create(chart,name,subwin,x1,y1,x2,y2))
      return(false);
//--- create dependent controls
   if(!CreateEdit())
      return(false);
   if(!CreateInc())
      return(false);
   if(!CreateDec())
      return(false);
   Mode(m_mode);
   Show();
//--- succeeded
   return(true);
  }
//+------------------------------------------------------------------+
//| Create drop-down edit                                            |
//+------------------------------------------------------------------+
bool CTimePicker::CreateEdit(void)
  {
//--- create object
   if(!m_edit.Create(m_chart_id,m_name+"Edit",m_subwin,0,0,Width(),Height()))
      return(false);
   if(!Add(m_edit))
      return(false);
//--- create canvas
   if(!m_canvas.Create(m_name,Width(),Height()))
      return(false);
   m_canvas.FontSet(CONTROLS_FONT_NAME,CONTROLS_FONT_SIZE*(-10));
   m_edit.BmpName(m_canvas.ResourceName());
//--- succeeded
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the "Increment" button                                    |
//+------------------------------------------------------------------+
bool CTimePicker::CreateInc(void)
  {
//--- right align button (try to make equal offsets from top and bottom)
   int x1=Width()-(CONTROLS_BUTTON_SIZE+CONTROLS_SPIN_BUTTON_X_OFF);
   int y1=(Height()-2*CONTROLS_SPIN_BUTTON_SIZE)/2;
   int x2=x1+CONTROLS_BUTTON_SIZE;
   int y2=y1+CONTROLS_SPIN_BUTTON_SIZE;
//--- create
   if(!m_inc.Create(m_chart_id,m_name+"Inc",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_inc.BmpNames("::res\\SpinInc.bmp"))
      return(false);
   if(!Add(m_inc))
      return(false);
//--- property
   m_inc.PropFlags(WND_PROP_FLAG_CLICKS_BY_PRESS);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Create the "Decrement" button                                    |
//+------------------------------------------------------------------+
bool CTimePicker::CreateDec(void)
  {
//--- right align button (try to make equal offsets from top and bottom)
   int x1=Width()-(CONTROLS_BUTTON_SIZE+CONTROLS_SPIN_BUTTON_X_OFF);
   int y1=(Height()-2*CONTROLS_SPIN_BUTTON_SIZE)/2+CONTROLS_SPIN_BUTTON_SIZE;
   int x2=x1+CONTROLS_BUTTON_SIZE;
   int y2=y1+CONTROLS_SPIN_BUTTON_SIZE;
//--- create
   if(!m_dec.Create(m_chart_id,m_name+"Dec",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_dec.BmpNames("::res\\SpinDec.bmp"))
      return(false);
   if(!Add(m_dec))
      return(false);
//--- property
   m_dec.PropFlags(WND_PROP_FLAG_CLICKS_BY_PRESS);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CTimePicker::Mode(ENUM_TIME_MODES value)
  {
   int ws,wt,ht;
   int width=0;
   int total=0;
//--- zero out array of areas
   ZeroMemory(m_click_rect);
//--- set font
   m_canvas.FontSet(CONTROLS_FONT_NAME,CONTROLS_FONT_SIZE*(-10));
   m_canvas.TextSize("00",wt,ht);
   ws=m_canvas.TextWidth(":");
   switch(value)
     {
      case DATE_TIME_SEC:
         m_click_rect[4].right=wt;
         m_click_rect[3].right=ws;
         width+=wt+ws;
         total+=2;
      case DATE_TIME_MIN:
         m_click_rect[2].right=wt;
         m_click_rect[1].right=ws;
         width+=wt+ws;
         total+=2;
      case DATE_TIME_HOUR:
         m_click_rect[0].right=wt;
         width+=wt;
         total++;
         break;
     }
//---
   int x=(Width()-(CONTROLS_BUTTON_SIZE+CONTROLS_SPIN_BUTTON_X_OFF)-width)/2;
   int y=(Height()-ht)/2;
   for(int i=0;i<total;i++)
     {
      m_click_rect[i].bottom=ht;
      m_click_rect[i].Move(x,y);
      x+=m_click_rect[i].Width();
     }
//---
   m_mode     =value;
   m_edit_mode=value;
  }
//+------------------------------------------------------------------+
//| Makes the control visible                                        |
//+------------------------------------------------------------------+
bool CTimePicker::Show(void)
  {
//--- draw canvas
   DrawCanvas(false);
//--- call method of the parent class
   return(CWndContainer::Show());
  }
//+------------------------------------------------------------------+
//| Handler of click on button                                       |
//+------------------------------------------------------------------+
bool CTimePicker::OnClickDec(void)
  {
   switch(m_edit_mode)
     {
      case DATE_TIME_SEC:
         m_value.SecDec();
         break;
      case DATE_TIME_MIN:
         m_value.MinDec();
         break;
      case DATE_TIME_HOUR:
         m_value.HourDec();
         break;
      default:
         break;
     }
   DrawCanvas();
//--- handled
   return(true);
  }
//+------------------------------------------------------------------+
//| Handler of click on button                                       |
//+------------------------------------------------------------------+
bool CTimePicker::OnClickInc(void)
  {
   switch(m_edit_mode)
     {
      case DATE_TIME_SEC:
         m_value.SecInc();
         break;
      case DATE_TIME_MIN:
         m_value.MinInc();
         break;
      case DATE_TIME_HOUR:
         m_value.HourInc();
         break;
      default:
         break;
     }
   DrawCanvas();
//--- handled
   return(true);
  }
//+------------------------------------------------------------------+
//| Handler of click on picture                                      |
//+------------------------------------------------------------------+
bool CTimePicker::OnClickEdit(void)
  {
   m_mouse_x=m_edit.MouseX();
   m_mouse_y=m_edit.MouseY();
//---
   OnClick();
//---
   m_mouse_x=0;
   m_mouse_y=0;
//--- handled
   return(true);
  }
//+------------------------------------------------------------------+
//| Handler of the "click" event                                     |
//+------------------------------------------------------------------+
bool CTimePicker::OnClick(void)
  {
   m_mouse_x-=Left();
   m_mouse_y-=Top();
   for(int i=0;i<5;i++)
     {
      if(m_click_rect[i].Contains(m_mouse_x,m_mouse_y))
        {
         switch(i)
           {
            case 0:
               m_edit_mode=DATE_TIME_HOUR;
               break;
            case 2:
               m_edit_mode=DATE_TIME_MIN;
               break;
            case 4:
               m_edit_mode=DATE_TIME_SEC;
               break;
           }
         DrawCanvas();
         break;
        }
     }
//--- handled
   return(true);
  }
//+------------------------------------------------------------------+
//| Draw canvas                                                      |
//+------------------------------------------------------------------+
void CTimePicker::DrawCanvas(bool select)
  {
   string text="00:00:00";
   uint   clr=COLOR2RGB(CONTROLS_EDIT_COLOR);
//--- clear
   m_canvas.Erase(COLOR2RGB(CONTROLS_EDIT_COLOR_BG));
   m_canvas.Rectangle(0,0,Width()-1,Height()-1,COLOR2RGB(CONTROLS_EDIT_COLOR_BORDER));
//--- draw
   switch(m_mode)
     {
      case DATE_TIME_SEC:
         if(select && m_edit_mode==DATE_TIME_SEC)
            m_canvas.FillRectangle(m_click_rect[4].left,m_click_rect[4].top,
                                   m_click_rect[4].right,m_click_rect[4].bottom,
                                   COLOR2RGB(CONTROLS_COLOR_BG_SEL));
         text=StringFormat("%02d",m_value.sec);
         m_canvas.TextOut(m_click_rect[4].left,m_click_rect[4].top,text,clr);
         m_canvas.TextOut(m_click_rect[3].left,m_click_rect[3].top,":",clr);
      case DATE_TIME_MIN:
         if(select && m_edit_mode==DATE_TIME_MIN)
            m_canvas.FillRectangle(m_click_rect[2].left,m_click_rect[2].top,
                                   m_click_rect[2].right,m_click_rect[2].bottom,
                                   COLOR2RGB(CONTROLS_COLOR_BG_SEL));
         text=StringFormat("%02d",m_value.min);
         m_canvas.TextOut(m_click_rect[2].left,m_click_rect[2].top,text,clr);
         m_canvas.TextOut(m_click_rect[1].left,m_click_rect[1].top,":",clr);
      case DATE_TIME_HOUR:
         if(select && m_edit_mode==DATE_TIME_HOUR)
            m_canvas.FillRectangle(m_click_rect[0].left,m_click_rect[0].top,
                                   m_click_rect[0].right,m_click_rect[0].bottom,
                                   COLOR2RGB(CONTROLS_COLOR_BG_SEL));
         text=StringFormat("%02d",m_value.hour);
         m_canvas.TextOut(m_click_rect[0].left,m_click_rect[0].top,text,clr);
         break;
      default:
         break;
     }
//--- update canvas
   m_canvas.Update();
  }
//+------------------------------------------------------------------+
//| Unselect if necessary                                            |
//+------------------------------------------------------------------+
void CTimePicker::CheckSelectHide(const int id,int x,int y)
  {
//--- check event ID
   if(id!=CHARTEVENT_CLICK)
      return;
//--- check mouse cursor's position
///   y-=(int)ChartGetInteger(m_chart_id,CHART_WINDOW_YDISTANCE,m_subwin);
   if(!m_edit.Contains(x,y))
      DrawCanvas(false);
  }
//+------------------------------------------------------------------+

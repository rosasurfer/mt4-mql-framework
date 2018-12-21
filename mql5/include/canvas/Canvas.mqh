//+------------------------------------------------------------------+
//|                                                       Canvas.mqh |
//|                   Copyright 2009-2013, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include <Files\FileBin.mqh>
#include <Controls\Rect.mqh>
//+------------------------------------------------------------------+
#define SIGN(i) ((i<0) ? -1 : 1)
//+------------------------------------------------------------------+
//| Macro to generate color                                          |
//+------------------------------------------------------------------+
#define XRGB(r,g,b)    (0xFF000000|(uchar(r)<<16)|(uchar(g)<<8)|uchar(b))
#define ARGB(a,r,g,b)  ((uchar(a)<<24)|(uchar(r)<<16)|(uchar(g)<<8)|uchar(b))
#define TRGB(a,rgb)    ((uchar(a)<<24)|(rgb))
#define GETRGB(clr)    ((clr)&0xFFFFFF)
#define GETRGBA(clr)   uchar((clr)>>24)
#define GETRGBR(clr)   uchar((clr)>>16)
#define GETRGBG(clr)   uchar((clr)>>8)
#define GETRGBB(clr)   uchar(clr)
#define COLOR2RGB(clr) (0xFF000000|(uchar(clr)<<16)|(uchar((clr)>>8)<<8)|uchar((clr)>>16))
#define RGB2COLOR(rgb) ((uchar(rgb)<<16)|(uchar((rgb)>>8)<<8)|uchar((rgb)>>16))
//+------------------------------------------------------------------+
//| Class CCanvas                                                    |
//| Usage: class for working with a dynamic resource                 |
//+------------------------------------------------------------------+
class CCanvas
  {
private:
   uint              m_style;                  // line style template
   uint              m_style_idx;              // variable - current index of bit in line style template
   static uint       m_default_colors[9];      // default colors

protected:
   long              m_chart_id;               // chart ID
   string            m_objname;                // object name
   ENUM_OBJECT       m_objtype;                // object type
   string            m_rcname;                 // resource name
   int               m_width;                  // canvas width
   int               m_height;                 // canvas height
   ENUM_COLOR_FORMAT m_format;                 // method of color processing
   //--- for text
   string            m_fontname;               // font name
   int               m_fontsize;               // font size
   uint              m_fontflags;              // font flags
   uint              m_fontangle;              // angle of text tilt to the X axis in 0.1 degrees
   //--- data
   uint              m_pixels[];               // array of pixels

public:
                     CCanvas(void);
                    ~CCanvas(void);
   //--- create/destroy
   virtual bool      Create(const string name,const int width,const int height,ENUM_COLOR_FORMAT clrfmt=COLOR_FORMAT_XRGB_NOALPHA);
   bool              CreateBitmap(const string name,const datetime time,const double price,
                                  const int width,const int height,ENUM_COLOR_FORMAT clrfmt=COLOR_FORMAT_XRGB_NOALPHA);
   bool              CreateBitmap(const long chart_id,const int subwin,const string name,
                                  const datetime time,const double price,const int width,const int height,
                                  ENUM_COLOR_FORMAT clrfmt=COLOR_FORMAT_XRGB_NOALPHA);
   bool              CreateBitmapLabel(const string name,const int x,const int y,
                                       const int width,const int height,ENUM_COLOR_FORMAT clrfmt=COLOR_FORMAT_XRGB_NOALPHA);
   bool              CreateBitmapLabel(const long chart_id,const int subwin,const string name,
                                       const int x,const int y,const int width,const int height,
                                       ENUM_COLOR_FORMAT clrfmt=COLOR_FORMAT_XRGB_NOALPHA);
   void              Destroy(void);
   //--- properties
   string            ChartObjectName(void)          const { return(m_objname); }
   string            ResourceName(void)             const { return(m_rcname);  }
   int               Width(void)                    const { return(m_width);   }
   int               Height(void)                   const { return(m_height);  }
   //--- update object on screen
   void              Update(const bool redraw=true);
   bool              Resize(const int width,const int height);
   //--- clear/fill color
   void              Erase(const uint clr=0);
   //--- data access
   uint              PixelGet(const int x,const int y) const;
   void              PixelSet(const int x,const int y,const uint clr);
   //--- draw primitives
   void              LineVertical(int x,int y1,int y2,const uint clr);
   void              LineHorizontal(int x1,int x2,int y,const uint clr);
   void              Line(int x1,int y1,int x2,int y2,const uint clr);
   void              Polyline(int &x[],int &y[],const uint clr);
   void              Polygon(int &x[],int &y[],const uint clr);
   void              Rectangle(int x1,int y1,int x2,int y2,const uint clr);
   void              Triangle(int x1,int y1,int x2,int y2,int x3,int y3,const uint clr);
   void              Circle(int x,int y,int r,const uint clr);
   void              Ellipse(int x1,int y1,int x2,int y2,const uint clr);
   void              Arc(int x1,int y1,int x2,int y2,int x3,int y3,int x4,int y4,const uint clr);
   void              Arc(int x,int y,int rx,int ry,double fi3,double fi4,const uint clr);
   void              Arc(int x,int y,int rx,int ry,double fi3,double fi4,int &x3,int &y3,int &x4,int &y4,const uint clr);
   void              Pie(int x1,int y1,int x2,int y2,int x3,int y3,int x4,int y4,const uint clr,const uint fill_clr);
   void              Pie(int x,int y,int rx,int ry,double fi3,double fi4,const uint clr,const uint fill_clr);
   //--- draw filled primitives
   void              FillRectangle(int x1,int y1,int x2,int y2,const uint clr);
   void              FillTriangle(int x1,int y1,int x2,int y2,int x3,int y3,const uint clr);
   void              FillPolygon(int &x[],int &y[],const uint clr);
   void              FillCircle(int x,int y,int r,const uint clr);
   void              FillEllipse(int x1,int y1,int x2,int y2,const uint clr);
   void              Fill(int x,int y,const uint clr);
   //--- draw primitives with antialiasing
   void              PixelSetAA(const double x,const double y,const uint clr);
   void              LineAA(const int x1,const int y1,const int x2,const int y2,const uint clr,const uint style=UINT_MAX);
   void              PolylineAA(int &x[],int &y[],const uint clr,const uint style=UINT_MAX);
   void              PolygonAA(int &x[],int &y[],const uint clr,const uint style=UINT_MAX);
   void              TriangleAA(const int x1,const int y1,const int x2,const int y2,const int x3,const int y3,
                                const uint clr,const uint style=UINT_MAX);
   void              CircleAA(const int x,const int y,const double r,const uint clr);
   //--- for text
   bool              FontSet(const string name,const int size,const uint flags=0,const uint angle=0);
   bool              FontNameSet(string name);
   bool              FontSizeSet(int size);
   bool              FontFlagsSet(uint flags);
   bool              FontAngleSet(uint angle);
   void              FontGet(string &name,int &size,uint &flags,uint &angle);
   string            FontNameGet(void)                 const { return(m_fontname);  }
   int               FontSizeGet(void)                 const { return(m_fontsize);  }
   uint              FontFlagsGet(void)                const { return(m_fontflags); }
   uint              FontAngleGet(void)                const { return(m_fontangle); }
   void              TextOut(int x,int y,string text,const uint clr,uint alignment=0);
   int               TextWidth(const string text);
   int               TextHeight(const string text);
   void              TextSize(const string text,int &width,int &height);
   //--- services
   static uint       GetDefaultColor(const int i);
   void              TransparentLevelSet(const uchar value);
   //--- load bitmap from file
   bool              LoadFromFile(const string filename);

private:
   void              LineStyleSet(const uint style);
   bool              FontSet(void);
   void              TextOutFast(int x,int y,string text,const uint clr,uint alignment=0);
   //--- for pie
   double            AngleCalc(int x1,int y1,int x2,int y2);
   //--- for polygon
   int               PointClassify(const CPoint &p0,const CPoint &p1,const CPoint &p2);
   int               PolygonClassify(const CPoint &p[]);
   bool              IsPolygonConvex(CPoint &p[]);
   void              PolygonNormalize(CPoint &p[]);
   void              PolygonIntersect(CPoint &p[],CPoint &add[]);
   void              PolygonFill(CPoint &p[],const uint clr);
  };
//+------------------------------------------------------------------+
//| Initialize static array                                          |
//+------------------------------------------------------------------+
uint CCanvas::m_default_colors[9]={ XRGB(0,0,255),     // blue
                                    XRGB(255,0,0),     // red
                                    XRGB(0,128,0),     // green
                                    XRGB(255,242,0),   // yellow
                                    XRGB(255,0,128),   // pink
                                    XRGB(0,255,0),     // lime
                                    XRGB(185,0,61),    // crimson
                                    XRGB(0,183,239),   // sky blue
                                    XRGB(255,128,0)};  // orange
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCanvas::CCanvas(void) : m_chart_id(0),
                         m_objname(NULL),
                         m_objtype(WRONG_VALUE),
                         m_rcname(NULL),
                         m_width(0),
                         m_height(0),
                         m_format(COLOR_FORMAT_XRGB_NOALPHA),
                         m_fontname("arial"),
                         m_fontsize(-120),
                         m_fontflags(0),
                         m_fontangle(0),
                         m_style(UINT_MAX),
                         m_style_idx(0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCanvas::~CCanvas(void)
  {
  }
//+------------------------------------------------------------------+
//| Create dynamic resource                                          |
//+------------------------------------------------------------------+
bool CCanvas::Create(const string name,const int width,const int height,ENUM_COLOR_FORMAT clrfmt)
  {
   Destroy();
//--- prepare data array
   if(width>0 && height>0 && ArrayResize(m_pixels,width*height)>0)
     {
      //--- generate resource name
      m_rcname="::"+name+(string)(GetTickCount()+MathRand());
      //--- initialize data with zeros
      ArrayInitialize(m_pixels,0);
      //--- create dynamic resource
      if(ResourceCreate(m_rcname,m_pixels,width,height,0,0,0,clrfmt))
        {
         //--- successfully created
         //--- complete initialization
         m_width =width;
         m_height=height;
         m_format=clrfmt;
         //--- succeed
         return(true);
        }
     }
//--- error - destroy object
   Destroy();
   return(false);
  }
//+------------------------------------------------------------------+
//| Create object on chart with attached dynamic resource            |
//+------------------------------------------------------------------+
bool CCanvas::CreateBitmap(const string name,const datetime time,const double price,
                           const int width,const int height,ENUM_COLOR_FORMAT clrfmt)
  {
   return(CreateBitmap(0,0,name,time,price,width,height,clrfmt));
  }
//+------------------------------------------------------------------+
//| Create object on chart with attached dynamic resource            |
//+------------------------------------------------------------------+
bool CCanvas::CreateBitmap(const long chart_id,const int subwin,const string name,
                           const datetime time,const double price,const int width,const int height,
                           ENUM_COLOR_FORMAT clrfmt)
  {
//--- create canvas
   if(Create(name,width,height,clrfmt))
     {
      //--- create attached object
      if(ObjectCreate(chart_id,name,OBJ_BITMAP,subwin,time,price))
        {
         //--- bind object with resource
         if(ObjectSetString(chart_id,name,OBJPROP_BMPFILE,m_rcname))
           {
            //--- successfully created
            //--- complete initialization
            m_chart_id=chart_id;
            m_objname =name;
            m_objtype =OBJ_BITMAP;
            //--- succeed
            return(true);
           }
        }
     }
//--- error - destroy object
   Destroy();
   return(false);
  }
//+------------------------------------------------------------------+
//| Create object on chart with attached dynamic resource            |
//+------------------------------------------------------------------+
bool CCanvas::CreateBitmapLabel(const string name,const int x,const int y,
                                const int width,const int height,ENUM_COLOR_FORMAT clrfmt)
  {
   return(CreateBitmapLabel(0,0,name,x,y,width,height,clrfmt));
  }
//+------------------------------------------------------------------+
//| Create object on chart with attached dynamic resource            |
//+------------------------------------------------------------------+
bool CCanvas::CreateBitmapLabel(const long chart_id,const int subwin,const string name,
                                const int x,const int y,const int width,const int height,
                                ENUM_COLOR_FORMAT clrfmt)
  {
//--- create canvas
   if(Create(name,width,height,clrfmt))
     {
      //--- create attached object
      if(ObjectCreate(chart_id,name,OBJ_BITMAP_LABEL,subwin,0,0))
        {
         //--- set x,y and bind object with resource
         if(ObjectSetInteger(chart_id,name,OBJPROP_XDISTANCE,x) && 
            ObjectSetInteger(chart_id,name,OBJPROP_YDISTANCE,y) && 
            ObjectSetString(chart_id,name,OBJPROP_BMPFILE,m_rcname))
           {
            //--- successfully created
            //--- complete initialization
            m_chart_id=chart_id;
            m_objname =name;
            m_objtype =OBJ_BITMAP_LABEL;
            //--- succeed
            return(true);
           }
        }
     }
//--- error - destroy object
   Destroy();
   return(false);
  }
//+------------------------------------------------------------------+
//| Remove object from chart and deallocate data array               |
//+------------------------------------------------------------------+
void CCanvas::Destroy(void)
  {
//--- delete object
   if(m_objname!=NULL)
     {
      ObjectDelete(m_chart_id,m_objname);
      m_chart_id=0;
      m_objname =NULL;
      m_objtype =WRONG_VALUE;
     }
//--- deallocate array
   ArrayFree(m_pixels);
//--- free resource
   if(m_rcname!=NULL)
     {
      ResourceFree(m_rcname);
      m_rcname=NULL;
     }
//--- zeroize data
   m_width =0;
   m_height=0;
  }
//+------------------------------------------------------------------+
//| Update object on screen (redraw)                                 |
//+------------------------------------------------------------------+
void CCanvas::Update(const bool redraw)
  {
//--- check
   if(m_rcname==NULL)
      return;
//--- update resource and redraw
   if(ResourceCreate(m_rcname,m_pixels,m_width,m_height,0,0,0,m_format) && redraw)
      ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Resize                                                           |
//+------------------------------------------------------------------+
bool CCanvas::Resize(const int width,const int height)
  {
//--- check
   if(m_rcname!=NULL && width>0 && height>0)
      if(ArrayResize(m_pixels,width*height)>0)
        {
         m_width =width;
         m_height=height;
         //--- initialize data with zeros
         ArrayInitialize(m_pixels,0);
         //--- create dynamic resource
         if(ResourceCreate(m_rcname,m_pixels,m_width,m_height,0,0,0,m_format))
           {
            //--- bind object with resource
            if(m_objname!=NULL && ObjectSetString(m_chart_id,m_objname,OBJPROP_BMPFILE,m_rcname))
               return(true);
           }
        }
//--- error - destroy object
   Destroy();
   return(false);
  }
//+------------------------------------------------------------------+
//| Clear/Fill color                                                 |
//+------------------------------------------------------------------+
void CCanvas::Erase(const uint clr)
  {
   ArrayInitialize(m_pixels,clr);
  }
//+------------------------------------------------------------------+
//| Get pixel color                                                  |
//+------------------------------------------------------------------+
uint CCanvas::PixelGet(const int x,const int y) const
  {
//--- check coordinates
   if(x>=0 && x<m_width && y>=0 && y<m_height)
      return(m_pixels[y*m_width+x]);
//--- error
   return(0);
  }
//+------------------------------------------------------------------+
//| Set pixel                                                        |
//+------------------------------------------------------------------+
void CCanvas::PixelSet(const int x,const int y,const uint clr)
  {
//--- check coordinates
   if(x>=0 && x<m_width && y>=0 && y<m_height)
      m_pixels[y*m_width+x]=clr;
  }
//+------------------------------------------------------------------+
//| Fill closed region with color                                    |
//+------------------------------------------------------------------+
void CCanvas::Fill(int x,int y,const uint clr)
  {
//--- check
   if(x<0 || x>=m_width || y<0 || y>=m_height)
      return;
//---
   int  index=y*m_width+x;
   uint old_clr=m_pixels[index];
//--- check if replacement is necessary
   if(old_clr==clr)
      return;
//--- use pseudo stack to emulate deeply-nested recursive calls
   int  stack[];
   uint count=1;
   int  idx;
   int  total=ArraySize(m_pixels);
//--- allocate memory for stack
   if(ArrayResize(stack,total)==-1)
      return;
   stack[0]=index;
   m_pixels[index]=clr;
   for(uint i=0;i<count;i++)
     {
      index=stack[i];
      x=index%m_width;
      //--- left adjacent point
      idx=index-1;
      if(x>0 && m_pixels[idx]==old_clr)
        {
         m_pixels[idx]=clr;
         stack[count++]=idx;
        }
      //--- top adjacent point
      idx=index-m_width;
      if(idx>=0 && m_pixels[idx]==old_clr)
        {
         m_pixels[idx]=clr;
         stack[count++]=idx;
        }
      //--- right adjacent point
      idx=index+1;
      if(x<m_width-1 && m_pixels[idx]==old_clr)
        {
         m_pixels[idx]=clr;
         stack[count++]=idx;
        }
      //--- bottom adjacent point
      idx=index+m_width;
      if(idx<total && m_pixels[idx]==old_clr)
        {
         m_pixels[idx]=clr;
         stack[count++]=idx;
        }
     }
//--- deallocate memory
   ArrayFree(stack);
  }
//+------------------------------------------------------------------+
//| Draw vertical line                                               |
//+------------------------------------------------------------------+
void CCanvas::LineVertical(int x,int y1,int y2,const uint clr)
  {
   int tmp;
//--- sort by Y
   if(y1>y2)
     {
      tmp=y1;
      y1 =y2;
      y2 =tmp;
     }
//--- line is out of image boundaries
   if(y2<0 || y1>=m_height || x<0 || x>=m_width)
      return;
//--- stay withing image boundaries
   if(y1<0)
      y1=0;
   if(y2>=m_height-1)
      y2=m_height-1;
//--- draw line
   int index=y1*m_width+x;
   for(int i=y1;i<=y2;i++,index+=m_width)
      m_pixels[index]=clr;
  }
//+------------------------------------------------------------------+
//| Draw horizontal line                                             |
//+------------------------------------------------------------------+
void CCanvas::LineHorizontal(int x1,int x2,int y,const uint clr)
  {
   int tmp;
//--- sort by X
   if(x1>x2)
     {
      tmp=x1;
      x1 =x2;
      x2 =tmp;
     }
//--- line is out of image boundaries
   if(x2<0 || x1>=m_width || y<0 || y>=m_height)
      return;
//--- stay withing image boundaries
   if(x1<0)
      x1=0;
   if(x2>=m_width)
      x2=m_width-1;
//--- draw line
   ArrayFill(m_pixels,y*m_width+x1,x2-x1,clr);
  }
//+------------------------------------------------------------------+
//| Draw line according to Bresenham's algorithm                     |
//+------------------------------------------------------------------+
void CCanvas::Line(int x1,int y1,int x2,int y2,const uint clr)
  {
//--- line is out of image boundaries
   if((x1<0 && x2<0) || (y1<0 && y2<0))
      return;
   if(x1>=m_width && x2>=m_width)
      return;
   if(y1>=m_height && y2>=m_height)
      return;
//--- get length by X and Y
   int dx=(x2>x1)? x2-x1 : x1-x2;
   int dy=(y2>y1)? y2-y1 : y1-y2;
   if(dx==0)
     {
      //--- vertical line
      LineVertical(x1,y1,y2,clr);
      return;
     }
   if(dy==0)
     {
      //--- horizontal line
      LineHorizontal(x1,x2,y1,clr);
      return;
     }
//--- get direction by X and Y
   int  sx=(x1<x2)? 1 : -1;
   int  sy=(y1<y2)? 1 : -1;
   int  er=dx-dy;
   bool draw=false;
//--- continue to draw line
   while(x1!=x2 || y1!=y2)
     {
      if(x1<0 || x1>=m_width ||
         y1<0 || y1>=m_height)
        {
         if(draw)
            return;
        }
      else
        {
         //--- draw pixel
         m_pixels[y1*m_width+x1]=clr;
         draw=true;
        }
      //--- get coordinates of next pixel
      int er2=er<<1;
      if(er2>-dy)
        {
         er-=dy;
         x1+=sx;
        }
      if(er2<dx)
        {
         er+=dx;
         y1+=sy;
        }
     }
//--- set pixel at the end
   PixelSet(x2,y2,clr);
  }
//+------------------------------------------------------------------+
//| Draw polyline                                                    |
//+------------------------------------------------------------------+
void CCanvas::Polyline(int &x[],int &y[],const uint clr)
  {
   int total=ArraySize(x);
   if(total>ArraySize(y))
      total=ArraySize(y);
//--- check
   if(total<2)
      return;
   total--;
//--- draw
   for(int i=0;i<total;i++)
      Line(x[i],y[i],x[i+1],y[i+1],clr);
  }
//+------------------------------------------------------------------+
//| Draw polygon                                                     |
//+------------------------------------------------------------------+
void CCanvas::Polygon(int &x[],int &y[],const uint clr)
  {
//--- check arrays
   int total=ArraySize(x);
   if(total>ArraySize(y))
      total=ArraySize(y);
//--- check
   if(total<2)
      return;
   total--;
//--- draw
   for(int i=0;i<total;i++)
      Line(x[i],y[i],x[i+1],y[i+1],clr);
//--- close the outline
   Line(x[total],y[total],x[0],y[0],clr);
  }
//+------------------------------------------------------------------+
//| Draw rectangle                                                   |
//+------------------------------------------------------------------+
void CCanvas::Rectangle(int x1,int y1,int x2,int y2,const uint clr)
  {
   LineHorizontal(x1,x2,y1,clr);
   LineVertical(x2,y1,y2,clr);
   LineHorizontal(x2,x1,y2,clr);
   LineVertical(x1,y2,y1,clr);
  }
//+------------------------------------------------------------------+
//| Draw triangle                                                    |
//+------------------------------------------------------------------+
void CCanvas::Triangle(int x1,int y1,int x2,int y2,int x3,int y3,const uint clr)
  {
   Line(x1,y1,x2,y2,clr);
   Line(x2,y2,x3,y3,clr);
   Line(x3,y3,x1,y1,clr);
  }
//+------------------------------------------------------------------+
//| Draw circle according to Bresenham's algorithm                   |
//+------------------------------------------------------------------+
void CCanvas::Circle(int x,int y,int r,const uint clr)
  {
   int f   =1-r;
   int dd_x=1;
   int dd_y=-2*r;
   int dx  =0;
   int dy  =r;
   int xx,yy;
//--- draw
   while(dy>=dx)
     {
      xx=x+dx;
      if(xx>=0 && xx<m_width)
        {
         yy=y+dy;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
         yy=y-dy;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
        }
      xx=x-dx;
      if(xx>=0 && xx<m_width)
        {
         yy=y+dy;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
         yy=y-dy;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
        }
      xx=x+dy;
      if(xx>=0 && xx<m_width)
        {
         yy=y+dx;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
         yy=y-dx;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
        }
      xx=x-dy;
      if(xx>=0 && xx<m_width)
        {
         yy=y+dx;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
         yy=y-dx;
         if(yy>=0 && yy<m_height)
            m_pixels[yy*m_width+xx]=clr;
        }
      //---
      if(f>=0)
        {
         dy--;
         dd_y+=2;
         f+=dd_y;
        }
      dx++;
      dd_x+=2;
      f+=dd_x;
     }
  }
//+------------------------------------------------------------------+
//| Draw ellipse according to Bresenham's algorithm                  |
//+------------------------------------------------------------------+
void CCanvas::Ellipse(int x1,int y1,int x2,int y2,const uint clr)
  {
   int x,y;
   int rx,ry;
   int dx,dy;
   int xx,yy;
   int rx_sq,ry_sq;
   int f;
   int tmp;
//--- handle extreme conditions
   if(x1==x2)
     {
      if(y1==y2)
         PixelSet(x1,y1,clr);
      else
         LineVertical(x1,y1,y2,clr);
      return;
     }
   if(y1==y2)
     {
      LineHorizontal(x1,x2,y1,clr);
      return;
     }
//--- sort by X
   if(x1>x2)
     {
      tmp=x1;
      x1 =x2;
      x2 =tmp;
     }
//--- sort by Y
   if(y1>y2)
     {
      tmp=y1;
      y1 =y2;
      y2 =tmp;
     }
   x =(x2+x1)>>1;
   y =(y2+y1)>>1;
   rx=(x2-x1)>>1;
   ry=(y2-y1)>>1;
   dx=0;
   dy=ry;
   rx_sq=rx*rx;
   ry_sq=ry*ry;
   f=(rx_sq<<1)*((dy-1)*dy)+rx_sq+(ry_sq<<1)*(1-rx_sq);
   while(rx_sq*dy>ry_sq*dx)
     {
      yy=y+dy;
      if(yy>=0 && yy<m_height)
        {
         yy*=m_width;
         xx=x+dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
         xx=x-dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
        }
      yy=y-dy;
      if(yy>=0 && yy<m_height)
        {
         yy*=m_width;
         xx=x+dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
         xx=x-dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
        }
      if(f>=0)
        {
         dy--;
         f-=(rx_sq<<2)*dy;
        }
      f+=(ry_sq<<1)*(3+(dx<<1));
      dx++;
     }
   f=(ry_sq<<1)*(dx+1)*dx+(rx_sq<<1)*(dy*(dy-2)+1)+(1-(rx_sq<<1))*ry_sq;
   while(dy>=0)
     {
      yy=y+dy;
      if(yy>=0 && yy<m_height)
        {
         yy*=m_width;
         xx=x+dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
         xx=x-dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
        }
      yy=y-dy;
      if(yy>=0 && yy<m_height)
        {
         yy*=m_width;
         xx=x+dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
         xx=x-dx;
         if(xx>=0 && xx<m_width)
            m_pixels[yy+xx]=clr;
        }
      if(f<=0)
        {
         dx++;
         f+=(ry_sq<<2)*dx;
        }
      dy--;
      f+=(rx_sq<<1)*(3-(dy<<1));
     }
  }
//+------------------------------------------------------------------+
//| Draws ellipse arc                                                |
//+------------------------------------------------------------------+
void CCanvas::Arc(int x1,int y1,int x2,int y2,int x3,int y3,int x4,int y4,const uint clr)
  {
   int    tmp;
   int    x,y;
   double fi3;
   double fi4;
//--- check
   if(x1==x2 || y1==y2)
      return;
//--- sort by X
   if(x1>x2)
     {
      tmp=x1;
      x1 =x2;
      x2 =tmp;
     }
//--- sort by Y
   if(y1>y2)
     {
      tmp=y1;
      y1 =y2;
      y2 =tmp;
     }
   x =(x2+x1)>>1;
   y =(y2+y1)>>1;
//--- check rays
   if(x3==x && y3==y)
      return;
   if(x4==x && y4==y)
      return;
//--- calculate parameters of ray x3,y3
   fi3=AngleCalc(x,y,x3,y3);
//--- calculate parameters of ray x4,y4
   fi4=AngleCalc(x,y,x4,y4);
//--- draw arc
   Arc(x,y,x2-x,y2-y,fi3,fi4,clr);
  }
//+------------------------------------------------------------------+
//| Draws ellipse arc                                                |
//+------------------------------------------------------------------+
void CCanvas::Arc(int x,int y,int rx,int ry,double fi3,double fi4,const uint clr)
  {
   int x3,y3,x4,y4;
//--- check
   if(rx<10 || ry<10)
      return;
   if(rx<0)
      rx=-rx;
   if(ry<0)
      ry=-ry;
//--- check rays
   if(fi3==fi4)
      return;
//--- adjustment for passing through 0
   if(fi4<fi3)
      fi4+=2*M_PI;
//--- draw arc
   Arc(x,y,rx,ry,fi3,fi4,x3,y3,x4,y4,clr);
  }
//+------------------------------------------------------------------+
//| Calculates angle between ray (x1,y1),(x1+1,y1) and               |
//|                          ray (x1,y1),(x2,y2)                     |
//| Note that y coordinates are inversed 				                  |
//+------------------------------------------------------------------+
double CCanvas::AngleCalc(int x1,int y1,int x2,int y2)
  {
   double fi;
//--- check
   if(x1==x2)
     {
      if(y1==y2)
         return(EMPTY_VALUE);
      fi=(y2<y1) ? M_PI_2 : 3*M_PI_2;
     }
   else
     {
      //--- calc
      fi=atan((double)(y1-y2)/(x2-x1));
      //--- adjust to the 0-2Pi range
      if(x2<x1)
         fi+=M_PI;
      else
        {
         if(fi<0)
            fi+=2*M_PI;
        }
     }
//--- result
   return(fi);
  }
//+------------------------------------------------------------------+
//| Draws ellipse arc and finds points of intersection with rays     |
//+------------------------------------------------------------------+
void CCanvas::Arc(int x,int y,int rx,int ry,double fi3,double fi4,int &x3,int &y3,int &x4,int &y4,const uint clr)
  {
//--- check
   if(rx<10 || ry<10)
      return;
//--- variables
   int dx,dy;
   int xx,yy;
   int rx_sq,ry_sq;
   int f;
   double fi;
//--- to find intersections
   bool   ray3=false;
   bool   ray4=false;
   bool   ckw=false;
   int    xx_c=0,yy_c=0;
   double fi_c=0.0;
   bool   ackw=false;
   int    xx_a=0,yy_a=0;
   double fi_a=0.0;
//---
   rx_sq=rx*rx;
   ry_sq=ry*ry;
//--- cannot avoid check if each intersection point is between rays
//--- this will significantly decrease drawing speed, but there is no other way
//--- split ellipse into four arcs
//---
//--- 1 top
//---
//--- if arc is obviously not within the rays range, don't draw
   fi=MathMod(fi4,2*M_PI);
   if((fi3<M_PI && fi3>0) ||  // ray 3 is in the 1st or 2nd quadrant
      (fi<M_PI && fi>0)   ||  // ray 4 is in the 1st or 2nd quadrant
       fi4-fi3>=M_PI)         // arc will pass through the top of the ellipse
     {
      dx=0;
      dy=ry;
      f=(rx_sq<<1)*((dy-1)*dy)+rx_sq+(ry_sq<<1)*(1-rx_sq);
      while(rx_sq*dy>=ry_sq*dx)
        {
         yy=y-dy;
         if(dx==0)
           {
            //--- central point
            fi=AngleCalc(0,0,0,-dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(x,yy,clr);
               ckw=ackw=true;
              }
            else
               ckw=ackw=false;
            xx_c=x;
            yy_c=yy;
            fi_c=fi;
            xx_a=x;
            yy_a=yy;
            fi_a=fi;
           }
         else
           {
            //--- iterate clockwise
            xx=x+dx;
            fi=AngleCalc(0,0,dx,-dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 4 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(!ckw)
                 {
                  ckw=true;
                  if(!ray4)
                    {
                     if(MathAbs(fi_c-MathMod(fi4,2*M_PI))<MathAbs(fi-MathMod(fi4,2*M_PI)))
                        PixelSet(x4=xx_c,y4=yy_c,clr);
                     else
                       {
                        x4=xx;
                        y4=yy;
                       }
                     ray4=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(ckw && !ray3)
                 {
                  if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
                     PixelSet(x3=xx,y3=yy,clr);
                  else
                    {
                     x3=xx_c;
                     y3=yy_c;
                    }
                  ray3=true;
                 }
               ckw=false;
              }
            //--- save parameters of the last iteration
            xx_c=xx;
            yy_c=yy;
            fi_c=fi;
            //--- iterate counterclockwise
            xx=x-dx;
            fi=AngleCalc(0,0,-dx,-dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(!ackw)
                 {
                  ackw=true;
                  if(!ray3)
                    {
                     if(MathAbs(fi_a-fi3)<MathAbs(fi-fi3))
                        PixelSet(x3=xx_a,y3=yy_a,clr);
                     else
                       {
                        x3=xx;
                        y3=yy;
                       }
                     ray3=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(ackw && !ray4)
                 {
                  if(MathAbs(fi_a-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
                     PixelSet(x4=xx,y4=yy,clr);
                  else
                    {
                     x4=xx_a;
                     y4=yy_a;
                    }
                  ray4=true;
                 }
               ackw=false;
              }
            //--- save parameters of the last iteration
            xx_a=xx;
            yy_a=yy;
            fi_a=fi;
           }
         //--- calculate coordinates of the next point
         if(f>=0)
           {
            dy--;
            f-=(rx_sq<<2)*dy;
           }
         f+=(ry_sq<<1)*(3+(dx<<1));
         dx++;
        }
      //--- if arc has been drawn clockwise "to the end" and ray 3 had not been found
      if(ckw && !ray3)
        {
         fi=AngleCalc(0,0,dx,-dy);
         if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
            PixelSet(x3=x+dx,y3=y-dy,clr);
         else
           {
            x3=xx_c;
            y3=yy_c;
           }
        }
      //--- if arc has been drawn counterclockwise "to the end" and ray 4 had not been found
      if(ackw && !ray4)
        {
         fi=AngleCalc(0,0,-dx,-dy);
         if(MathAbs(fi_a-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
            PixelSet(x4=x-dx,y4=y-dy,clr);
         else
           {
            x4=xx_a;
            y4=yy_a;
           }
        }
     }
//--- 2 left
//---
//--- if arc is obviously not within the rays range, don't draw
   fi=MathMod(fi4,2*M_PI);
   if((fi3>M_PI_2 && fi3<3*M_PI_2) ||  // ray 3 is in the 2nd or 3rd quadrant
      (fi>M_PI_2 && fi<3*M_PI_2)   ||  // ray 4 is in the 2nd or 3rd quadrant
       fi4-fi3>=M_PI)                  // arc will pass through the left part of the ellipse
     {
      dx=rx;
      dy=0;
      f=(ry_sq<<1)*((dx-1)*dx)+ry_sq+(rx_sq<<1)*(1-ry_sq);
      while(ry_sq*dx>=rx_sq*dy)
        {
         xx=x-dx;
         if(dy==0)
           {
            //--- central point
            fi=AngleCalc(0,0,-dx,0);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,y,clr);
               ckw=ackw=true;
              }
            else
               ckw=ackw=false;
            xx_c=xx;
            yy_c=y;
            fi_c=fi;
            xx_a=xx;
            yy_a=y;
            fi_a=fi;
           }
         else
           {
            //--- iterate clockwise
            yy=y-dy;
            fi=AngleCalc(0,0,-dx,-dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 4 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(!ckw)
                 {
                  ckw=true;
                  if(!ray4)
                    {
                     if(MathAbs(fi_c-MathMod(fi4,2*M_PI))<MathAbs(fi-MathMod(fi4,2*M_PI)))
                        PixelSet(x4=xx_c,y4=yy_c,clr);
                     else
                       {
                        x4=xx;
                        y4=yy;
                       }
                     ray4=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(ckw && !ray3)
                 {
                  if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
                     PixelSet(x3=xx,y3=yy,clr);
                  else
                    {
                     x3=xx_c;
                     y3=yy_c;
                    }
                  ray3=true;
                 }
               ckw=false;
              }
            //--- save parameters of the last iteration
            xx_c=xx;
            yy_c=yy;
            fi_c=fi;
            //--- iterate counterclockwise
            yy=y+dy;
            fi=AngleCalc(0,0,-dx,dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(!ackw)
                 {
                  ackw=true;
                  if(!ray3)
                    {
                     if(MathAbs(fi_a-fi3)<MathAbs(fi-fi3))
                        PixelSet(x3=xx_a,y3=yy_a,clr);
                     else
                       {
                        x3=xx;
                        y3=yy;
                       }
                     ray3=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(ackw && !ray4)
                 {
                  if(MathAbs(fi_a-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
                     PixelSet(x4=xx,y4=yy,clr);
                  else
                    {
                     x4=xx_a;
                     y4=yy_a;
                    }
                  ray4=true;
                 }
               ackw=false;
              }
            //--- save parameters of the last iteration
            xx_a=xx;
            yy_a=yy;
            fi_a=fi;
           }
         //--- calculate coordinates of the next point
         if(f>=0)
           {
            dx--;
            f-=(ry_sq<<2)*dx;
           }
         f+=(rx_sq<<1)*(3+(dy<<1));
         dy++;
        }
      //--- if arc has been drawn clockwise "to the end" and ray 3 had not been found
      if(ckw && !ray3)
        {
         fi=AngleCalc(0,0,-dx,-dy);
         if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
            PixelSet(x3=x-dx,y3=y-dy,clr);
         else
           {
            x3=xx_c;
            y3=yy_c;
           }
        }
      //--- if arc has been drawn counterclockwise "to the end" and ray 4 had not been found
      if(ackw && !ray4)
        {
         fi=AngleCalc(0,0,-dx,dy);
         if(MathAbs(fi_a-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
            PixelSet(x4=x-dx,y4=y+dy,clr);
         else
           {
            x4=xx_a;
            y4=yy_a;
           }
        }
     }
//--- 3 bottom
//---
//--- if arc is obviously not within the rays range, don't draw
   fi=MathMod(fi4,2*M_PI);
   if((fi3>M_PI && fi3<2*M_PI) ||  // ray 3 is in the 3rd or 4th quadrant
      (fi>M_PI && fi<2*M_PI)   ||  // ray 4 is in the 3rd or 4th quadrant
       fi4-fi3>=M_PI)              // arc will pass through the bottom of the ellipse
     {
      dx=0;
      dy=ry;
      f=(rx_sq<<1)*((dy-1)*dy)+rx_sq+(ry_sq<<1)*(1-rx_sq);
      while(rx_sq*dy>=ry_sq*dx)
        {
         yy=y+dy;
         if(dx==0)
           {
            //--- central point
            fi=AngleCalc(0,0,0,dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(x,yy,clr);
               ckw=ackw=true;
              }
            else
               ckw=ackw=false;
            xx_c=x;
            yy_c=yy;
            fi_c=fi;
            xx_a=x;
            yy_a=yy;
            fi_a=fi;
           }
         else
           {
            //--- iterate clockwise
            xx=x-dx;
            fi=AngleCalc(0,0,-dx,dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 4 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(!ckw)
                 {
                  ckw=true;
                  if(!ray4)
                    {
                     if(MathAbs(fi_c-MathMod(fi4,2*M_PI))<MathAbs(fi-MathMod(fi4,2*M_PI)))
                        PixelSet(x4=xx_c,y4=yy_c,clr);
                     else
                       {
                        x4=xx;
                        y4=yy;
                       }
                     ray4=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(ckw && !ray3)
                 {
                  if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
                     PixelSet(x3=xx,y3=yy,clr);
                  else
                    {
                     x3=xx_c;
                     y3=yy_c;
                    }
                  ray3=true;
                 }
               ckw=false;
              }
            //--- save parameters of the last iteration
            xx_c=xx;
            yy_c=yy;
            fi_c=fi;
            //--- iterate counterclockwise
            xx=x+dx;
            fi=AngleCalc(0,0,dx,dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(!ackw)
                 {
                  ackw=true;
                  if(!ray3)
                    {
                     if(MathAbs(fi_a-fi3)<MathAbs(fi-fi3))
                        PixelSet(x3=xx_a,y3=yy_a,clr);
                     else
                       {
                        x3=xx;
                        y3=yy;
                       }
                     ray3=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(ackw && !ray4)
                 {
                  if(MathAbs(fi_a-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
                     PixelSet(x4=xx,y4=yy,clr);
                  else
                    {
                     x4=xx_a;
                     y4=yy_a;
                    }
                  ray4=true;
                 }
               ackw=false;
              }
            //--- save parameters of the last iteration
            xx_a=xx;
            yy_a=yy;
            fi_a=fi;
           }
         //--- calculate coordinates of the next point
         if(f>=0)
           {
            dy--;
            f-=(rx_sq<<2)*dy;
           }
         f+=(ry_sq<<1)*(3+(dx<<1));
         dx++;
        }
      //--- if arc has been drawn clockwise "to the end" and ray 3 had not been found
      if(ckw && !ray3)
        {
         fi=AngleCalc(0,0,-dx,dy);
         if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
            PixelSet(x3=x-dx,y3=y+dy,clr);
         else
           {
            x3=xx_c;
            y3=yy_c;
           }
        }
      //--- if arc has been drawn counterclockwise "to the end" and ray 4 had not been found
      if(ackw && !ray4)
        {
         fi=AngleCalc(0,0,dx,dy);
         if(MathAbs(fi_a-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
            PixelSet(x4=x+dx,y4=y+dy,clr);
         else
           {
            x4=xx_a;
            y4=yy_a;
           }
        }
     }
//--- 4 right
//---
//--- if arc is obviously not within the rays range, don't draw
   fi=MathMod(fi4,2*M_PI);
   if((fi3<M_PI_2 || fi3>3*M_PI_2) ||  // луч 3 попадает в 1 или 4 квадрант
      (fi<M_PI_2 || fi>3*M_PI_2)   ||  // луч 4 попадает в 1 или 4 квадрант
       fi4-fi3>=M_PI)                  // дуга пройдет через правую часть эллипса
     {
      dx=rx;
      dy=0;
      f=(ry_sq<<1)*((dx-1)*dx)+ry_sq+(rx_sq<<1)*(1-ry_sq);
      while(ry_sq*dx>=rx_sq*dy)
        {
         xx=x+dx;
         if(dy==0)
           {
            //--- central point
            fi=AngleCalc(0,0,dx,0);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,y,clr);
               ckw=ackw=true;
              }
            else
               ckw=ackw=false;
            xx_c=xx;
            yy_c=y;
            fi_c=fi;
            xx_a=xx;
            yy_a=y;
            fi_a=fi;
           }
         else
           {
            //--- iterate clockwise
            yy=y+dy;
            fi=AngleCalc(0,0,dx,dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 4 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(!ckw)
                 {
                  ckw=true;
                  if(!ray4)
                    {
                     if(MathAbs(fi_c-MathMod(fi4,2*M_PI))<MathAbs(fi-MathMod(fi4,2*M_PI)))
                        PixelSet(x4=xx_c,y4=yy_c,clr);
                     else
                       {
                        x4=xx;
                        y4=yy;
                       }
                     ray4=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(ckw && !ray3)
                 {
                  if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
                     PixelSet(x3=xx,y3=yy,clr);
                  else
                    {
                     x3=xx_c;
                     y3=yy_c;
                    }
                  ray3=true;
                 }
               ckw=false;
              }
            //--- save parameters of the last iteration
            xx_c=xx;
            yy_c=yy;
            fi_c=fi;
            //--- iterate counterclockwise
            yy=y-dy;
            fi=AngleCalc(0,0,dx,-dy);
            if((fi<=fi4 && fi3<=fi) || (fi4>=2*M_PI && fi<=fi4-2*M_PI))
              {
               PixelSet(xx,yy,clr);
               //--- if arc haven't been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 3
               if(!ackw)
                 {
                  ackw=true;
                  if(!ray3)
                    {
                     if(MathAbs(MathMod(fi_a,2*M_PI)-fi3)<MathAbs(fi-fi3))
                        PixelSet(x3=xx_a,y3=yy_a,clr);
                     else
                       {
                        x3=xx;
                        y3=yy;
                       }
                     ray3=true;
                    }
                 }
              }
            else
              {
               //--- if arc has been drawn before and intersection point of ray 3 and arc is not defined
               //--- this means that we (while iterating over points of the ellipse) had just crossed ray 4
               if(ackw && !ray4)
                 {
                  if(MathAbs(MathMod(fi_a,2*M_PI)-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
                     PixelSet(x4=xx,y4=yy,clr);
                  else
                    {
                     x4=xx_a;
                     y4=yy_a;
                    }
                  ray4=true;
                 }
               ackw=false;
              }
            //--- save parameters of the last iteration
            xx_a=xx;
            yy_a=yy;
            fi_a=fi;
           }
         //--- calculate coordinates of the next point
         if(f>=0)
           {
            dx--;
            f-=(ry_sq<<2)*dx;
           }
         f+=(rx_sq<<1)*(3+(dy<<1));
         dy++;
        }
      //--- if arc has been drawn clockwise "to the end" and ray 3 had not been found
      if(ckw && !ray3)
        {
         fi=AngleCalc(0,0,dx,dy);
         if(MathAbs(fi_c-fi3)>MathAbs(fi-fi3))
            PixelSet(x3=x+dx,y3=y+dy,clr);
         else
           {
            x3=xx_c;
            y3=yy_c;
           }
        }
      //--- if arc has been drawn counterclockwise "to the end" and ray 4 had not been found
      if(ackw && !ray4)
        {
         fi=AngleCalc(0,0,dx,-dy);
         if(MathAbs(MathMod(fi_a,2*M_PI)-MathMod(fi4,2*M_PI))>MathAbs(fi-MathMod(fi4,2*M_PI)))
            PixelSet(x4=x+dx,y4=y-dy,clr);
         else
           {
            x4=xx_a;
            y4=yy_a;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Draws ellipse pie                                                |
//+------------------------------------------------------------------+
void CCanvas::Pie(int x1,int y1,int x2,int y2,int x3,int y3,int x4,int y4,const uint clr,const uint fill_clr)
  {
   int tmp;
   int x,y;
//---
   double fi3;
   double fi4;
//--- check
   if(x1==x2 || y1==y2)
      return;
//--- sort by X
   if(x1>x2)
     {
      tmp=x1;
      x1 =x2;
      x2 =tmp;
     }
//--- sort by Y
   if(y1>y2)
     {
      tmp=y1;
      y1 =y2;
      y2 =tmp;
     }
   x =(x2+x1)>>1;
   y =(y2+y1)>>1;
//--- check rays
   if(x3==x && y3==y)
      return;
   if(x4==x && y4==y)
      return;
//--- calculate parameters of ray x3,y3
   fi3=AngleCalc(x,y,x3,y3);
//--- calculate parameters of ray x4,y4
   fi4=AngleCalc(x,y,x4,y4);
//--- draw pie
   Pie(x,y,x2-x,y2-y,fi3,fi4,clr,fill_clr);
  }
//+------------------------------------------------------------------+
//| Draws ellipse pie                                                |
//+------------------------------------------------------------------+
void CCanvas::Pie(int x,int y,int rx,int ry,double fi3,double fi4,const uint clr,const uint fill_clr)
  {
   int x3=x;
   int y3=y;
   int x4=x;
   int y4=y;
//--- check
   if(rx==0 || ry==0)
      return;
   if(rx<0)
      rx=-rx;
   if(ry<0)
      ry=-ry;
//--- check rays
   if(fi3==fi4)
      return;
//--- adjustment for passing through 0
   if(fi4<fi3)
      fi4+=2*M_PI;
//--- draw arc and radii
   Arc(x,y,rx,ry,fi3,fi4,x3,y3,x4,y4,clr);
   if((x==x3 && y==y3) || (x==x4 && y==y4))
      return;
   Line(x,y,x3,y3,clr);
   Line(x,y,x4,y4,clr);
//--- fill
   if(rx>ry)
      rx=ry;
   double fi=(fi3+fi4)/2;
   int xf=x+(int)(0.9*rx*cos(fi));
   int yf=y-(int)(0.9*rx*sin(fi));
   Fill(xf,yf,fill_clr);
  }
//+------------------------------------------------------------------+
//| Draw filled circle                                               |
//+------------------------------------------------------------------+
void CCanvas::FillCircle(int x,int y,int r,const uint clr)
  {
   int f   =1-r;
   int dd_x=1;
   int dd_y=-2*r;
   int dx  =0;
   int dy  =r;
//--- draw
   while(dy>=dx)
     {
      LineHorizontal(x-dx,x+dx,y-dy,clr);
      LineHorizontal(x-dx,x+dx,y+dy,clr);
      LineHorizontal(x-dy,x+dy,y-dx,clr);
      LineHorizontal(x-dy,x+dy,y+dx,clr);
      //---
      if(f>=0)
        {
         dy--;
         dd_y+=2;
         f+=dd_y;
        }
      dx++;
      dd_x+=2;
      f+=dd_x;
     }
  }
//+------------------------------------------------------------------+
//| Draw filled ellipse                                              |
//+------------------------------------------------------------------+
void CCanvas::FillEllipse(int x1,int y1,int x2,int y2,const uint clr)
  {
   int x,y;
   int rx,ry;
   int dx,dy;
   int rx_sq,ry_sq;
   int f;
   int tmp;
//--- handle extreme conditions
   if(x1==x2)
     {
      if(y1==y2)
         PixelSet(x1,y1,clr);
      else
         LineVertical(x1,y1,y2,clr);
      return;
     }
   if(y1==y2)
     {
      LineHorizontal(x1,x2,y1,clr);
      return;
     }
//--- sort by X
   if(x1>x2)
     {
      tmp=x1;
      x1 =x2;
      x2 =tmp;
     }
//--- sort by Y
   if(y1>y2)
     {
      tmp=y1;
      y1 =y2;
      y2 =tmp;
     }
   x =(x2+x1)>>1;
   y =(y2+y1)>>1;
   rx=(x2-x1)>>1;
   ry=(y2-y1)>>1;
   dx=0;
   dy=ry;
   rx_sq=rx*rx;
   ry_sq=ry*ry;
   f=(rx_sq<<1)*((dy-1)*dy)+rx_sq+(ry_sq<<1)*(1-rx_sq);
   while(rx_sq*dy>ry_sq*(dx))
     {
      LineHorizontal(x-dx,x+dx,y+dy,clr);
      LineHorizontal(x-dx,x+dx,y-dy,clr);
      if(f>=0)
        {
         dy--;
         f-=(rx_sq<<2)*dy;
        }
      f+=(ry_sq<<1)*(3+(dx<<1));
      dx++;
     }
   f=(ry_sq<<1)*(dx+1)*dx+(rx_sq<<1)*(dy*(dy-2)+1)+(1-(rx_sq<<1))*ry_sq;
   while(dy>=0)
     {
      LineHorizontal(x-dx,x+dx,y+dy,clr);
      LineHorizontal(x-dx,x+dx,y-dy,clr);
      if(f<=0)
        {
         dx++;
         f+=(ry_sq<<2)*dx;
        }
      dy--;
      f+=(rx_sq<<1)*(3-(dy<<1));
     }
  }
//+------------------------------------------------------------------+
//| Draw filled rectangle                                            |
//+------------------------------------------------------------------+
void CCanvas::FillRectangle(int x1,int y1,int x2,int y2,const uint clr)
  {
   int tmp;
//--- sort vertexes
   if(x2<x1)
     {
      tmp=x1;
      x1 =x2;
      x2 =tmp;
     }
   if(y2<y1)
     {
      tmp=y1;
      y1 =y2;
      y2 =tmp;
     }
//--- out of screen boundaries
   if(x2<0 || y2<0 || x1>=m_width || y1>=m_height)
      return;
//--- stay withing screen boundaries
   if(x1<0)
      x1=0;
   if(y1<0)
      y1=0;
   if(x2>=m_width)
      x2=m_width -1;
   if(y2>=m_height)
      y2=m_height-1;
//--- set pixels
   for(;y1<=y2;y1++)
      ArrayFill(m_pixels,y1*m_width+x1,x2-x1,clr);
  }
//+------------------------------------------------------------------+
//| Draw filled triangle                                             |
//+------------------------------------------------------------------+
void CCanvas::FillTriangle(int x1,int y1,int x2,int y2,int x3,int y3,const uint clr)
  {
   int    xx1,xx2,tmp;
   double k1=0,k2=0,xd1,xd2;
//--- sort vertexes from lesser to greater
   if(y1>y2)
     {
      tmp=y2;
      y2 =y1;
      y1 =tmp;
      tmp=x2;
      x2 =x1;
      x1=tmp;
     }
   if(y1>y3)
     {
      tmp=y1;
      y1 =y3;
      y3 =tmp;
      tmp=x1;
      x1 =x3;
      x3 =tmp;
     }
   if(y2>y3)
     {
      tmp=y2;
      y2 =y3;
      y3 =tmp;
      tmp=x2;
      x2 =x3;
      x3 =tmp;
     }
//--- all vertexes are out of image boundaries
   if(y3<0 || y1>m_height)
      return;
   if(x1<0 && x2<0 && x3<0)
      return;
   if(x1>m_width && x2>m_width && x3>m_width)
      return;
//--- find coefficients of lines
   if((tmp=y1-y2)!=0)
      k1=(x1-x2)/(double)tmp;
   if((tmp=y1-y3)!=0)
      k2=(x1-x3)/(double)tmp;
//---
   xd1=x1;
   xd2=x1;
//---
   for(int i=y1;i<=y3;i++)
     {
      if(i==y2)
        {
         if((tmp=y2-y3)!=0)
            k1=(x2-x3)/(double)tmp;
         xd1=x2;
        }
      //--- calculate new boundaries of triangle line
      xx1 =(int)xd1;
      xd1+=k1;
      xx2 =(int)xd2;
      xd2+=k2;
      //--- triangle line is out of screen boundaries
      if(i<0 || i>=m_height)
         continue;
      //--- sort
      if(xx1>xx2)
        {
         tmp=xx1;
         xx1=xx2;
         xx2=tmp;
        }
      //--- line is out of screen boundaries
      if(xx2<0 || xx1>=m_width)
         continue;
      //--- draw only what is within screen boundaries
      if(xx1<0)
         xx1=0;
      if(xx2>=m_width)
         xx2=m_width-1;
      //--- draw horizontal line of triangle
      ArrayFill(m_pixels,i*m_width+xx1,xx2-xx1,clr);
     }
  }
//+------------------------------------------------------------------+
//| Draw filled poligon                                              |
//+------------------------------------------------------------------+
void CCanvas::FillPolygon(int &x[],int &y[],const uint clr)
  {
   static CPoint p[];
   int total=ArraySize(x);
   if(total>ArraySize(y))
      total=ArraySize(y);
//--- check
   if(total<3)
      return;
//--- resize array of points
   ArrayResize(p,total);
//--- find top-left point
   int imin=0;
   int xmin=x[0];
   int ymin=y[0];
   int i;
   for(i=1;i<total;i++)
     {
      if(y[i]>ymin)
         continue;
      if(y[i]==ymin)
        {
         if(x[i]<xmin)
           {
            xmin=x[i];
            imin=i;
           }
         continue;
        }
      xmin=x[i];
      ymin=y[i];
      imin=i;
     }
//--- copy coordinates arrays to array of pixels (starting from top-left)
   for(i=0;i<total;i++,imin++)
     {
      p[i].x=x[imin%total];
      p[i].y=y[imin%total];
     }
   PolygonFill(p,clr);
   ArrayFree(p);
  }
//+------------------------------------------------------------------+
//| Draw pixel with antialiasing                                     |
//+------------------------------------------------------------------+
void CCanvas::PixelSetAA(const double x,const double y,const uint clr)
  {
   static double rr[4];
   static int    xx[4];
   static int    yy[4];
//--- preliminary calculations
   int    ix=(int)MathRound(x);
   int    iy=(int)MathRound(y);
   double rrr=0;
   double k;
   double dx=x-ix;
   double dy=y-iy;
   uchar  a,r,g,b;
   uint   c;
//--- no need for anti-aliasing
   if(dx==0.0 && dy==0.0)
     {
      PixelSet(ix,iy,clr);
      return;
     }
//--- prepare array of pixels
   xx[0]=xx[2]=ix;
   yy[0]=yy[1]=iy;
   if(dx<0.0)
      xx[1]=xx[3]=ix-1;
   if(dx==0.0)
      xx[1]=xx[3]=ix;
   if(dx>0.0)
      xx[1]=xx[3]=ix+1;
   if(dy<0.0)
      yy[2]=yy[2]=iy-1;
   if(dy==0.0)
      yy[2]=yy[2]=iy;
   if(dy>0.0)
      yy[2]=yy[2]=iy+1;
//--- calculate radii and sum of their squares
   int i;
   for(i=0;i<4;i++)
     {
      dx=xx[i]-x;
      dy=yy[i]-y;
      rr[i]=1/(dx*dx+dy*dy);
      rrr+=rr[i];
     }
//--- draw pixels
   for(i=0;i<4;i++)
     {
      k=rr[i]/rrr;
      c=PixelGet(xx[i],yy[i]);
      a=(uchar)(k*GETRGBA(clr)+(1-k)*GETRGBA(c));
      r=(uchar)(k*GETRGBR(clr)+(1-k)*GETRGBR(c));
      g=(uchar)(k*GETRGBG(clr)+(1-k)*GETRGBG(c));
      b=(uchar)(k*GETRGBB(clr)+(1-k)*GETRGBB(c));
      PixelSet(xx[i],yy[i],ARGB(a,r,g,b));
     }
  }
//+------------------------------------------------------------------+
//| Set line style                                                   |
//+------------------------------------------------------------------+
void CCanvas::LineStyleSet(const uint style)
  {
   switch(style)
     {
      case STYLE_SOLID:
         m_style=0xFFFFFF;
         break;
      case STYLE_DASH:
         m_style=0x3FFFF;
         break;
      case STYLE_DOT:
         m_style=0x1C71C7;
         break;
      case STYLE_DASHDOT:
         m_style=0x381FF;
         break;
      case STYLE_DASHDOTDOT:
         m_style=0x1C71FF;
         break;
      default:
         //--- high-order bit must be set then custom style
         if((style&0x80000000)!=0)
            m_style=style;
         break;
     }
   m_style_idx=0;
  }
//+------------------------------------------------------------------+
//| Draw line with antialiasing (with style)                         |
//+------------------------------------------------------------------+
void CCanvas::LineAA(const int x1,const int y1,const int x2,const int y2,const uint clr,const uint style)
  {
//--- line is out of image boundaries
   if((x1<0 && x2<0) || (y1<0 && y2<0))
      return;
   if(x1>=m_width && x2>=m_width)
      return;
   if(y1>=m_height && y2>=m_height)
      return;
//--- check
   if(x1==x2 && y1==y2)
     {
      PixelSet(x1,y1,clr);
      return;
     }
//--- set the line style
   if(style!=UINT_MAX)
      LineStyleSet(style);
//--- preliminary calculations
   double dx=x2-x1;
   double dy=y2-y1;
   double xy=sqrt(dx*dx+dy*dy);
   double xx=x1;
   double yy=y1;
   uint   mask=1<<m_style_idx;
//--- set pixels
   dx/=xy;
   dy/=xy;
   do
     {
      if((m_style&mask)==mask)
         PixelSetAA(xx,yy,clr);
      xx+=dx;
      yy+=dy;
      mask<<=1;
      if(mask==0x1000000)
         mask=1;
     }
   while(fabs(x2-xx)>=fabs(dx) && fabs(y2-yy)>=fabs(dy));
//--- set last pixel
   if((m_style&mask)==mask)
      PixelSetAA(x2,y2,clr);
  }
//+------------------------------------------------------------------+
//| Draw polyline with antialiasing (with style)                     |
//+------------------------------------------------------------------+
void CCanvas::PolylineAA(int &x[],int &y[],const uint clr,const uint style)
  {
//--- set the line style
   LineStyleSet(style);
//--- check arrays
   int total=ArraySize(x);
   if(total>ArraySize(y))
      total=ArraySize(y);
//--- check
   if(total<2)
      return;
   total--;
//--- draw
   for(int i=0;i<total;i++)
      LineAA(x[i],y[i],x[i+1],y[i+1],clr);
  }
//+------------------------------------------------------------------+
//| Draw polygon with antialiasing (with style)                      |
//+------------------------------------------------------------------+
void CCanvas::PolygonAA(int &x[],int &y[],const uint clr,const uint style)
  {
//--- set the line style
   LineStyleSet(style);
//--- check arrays
   int total=ArraySize(x);
   if(total>ArraySize(y))
      total=ArraySize(y);
//--- check
   if(total<2)
      return;
   total--;
//--- draw
   for(int i=0;i<total;i++)
      LineAA(x[i],y[i],x[i+1],y[i+1],clr);
//--- close the outline
   LineAA(x[total],y[total],x[0],y[0],clr);
  }
//+------------------------------------------------------------------+
//| Draw triangle with antialiasing                                  |
//+------------------------------------------------------------------+
void CCanvas::TriangleAA(const int x1,const int y1,const int x2,const int y2,const int x3,const int y3,const uint clr,const uint style)
  {
//--- set the line style
   LineStyleSet(style);
//--- draw
   LineAA(x1,y1,x2,y2,clr);
   LineAA(x2,y2,x3,y3,clr);
   LineAA(x3,y3,x1,y1,clr);
  }
//+------------------------------------------------------------------+
//| Draw circle with antialiasing                                    |
//+------------------------------------------------------------------+
void CCanvas::CircleAA(const int x,const int y,const double r,const uint clr)
  {
   if(r<=0)
      return;
//--- preliminary calculations
   double xx=x+r;
   double yy=y;
   double fi=0;
   double df=M_PI_2/MathCeil(r);
//--- draw
   if(r>M_PI)
      df/=2;
   do
     {
      xx=x+r*cos(fi);
      yy=y-r*sin(fi);
      PixelSetAA(xx,yy,clr);
      fi+=df;
     }
   while(fabs(2*M_PI-fi)>=df/2);
  }
//+------------------------------------------------------------------+
//| Gets default color                                               |
//+------------------------------------------------------------------+
static uint CCanvas::GetDefaultColor(const int i)
  {
   if(i<0)
      return(0);
   if(i<ArraySize(m_default_colors))
      return(m_default_colors[i]);
//---
   return(XRGB((i%3)*60+i*50,((i+1)%3)*60+i*60,((i+2)%3)*60+i*50));
  }
//+------------------------------------------------------------------+
//| Set level of transparency                                        |
//+------------------------------------------------------------------+
void CCanvas::TransparentLevelSet(const uchar value)
  {
   uint clr;
   int total=ArraySize(m_pixels);
   for(int i=0;i<total;i++)
     {
      clr=m_pixels[i]&0xFFFFFF;
      m_pixels[i]=((uint)value<<24)|(m_pixels[i]&0xFFFFFF);
     }
  }
//+------------------------------------------------------------------+
//| Set font                                                         |
//+------------------------------------------------------------------+
bool CCanvas::FontSet(const string name,const int size,const uint flags,const uint angle)
  {
   if(!TextSetFont(name,size,flags,angle))
      return(false);
//--- save parameters of generated font
   m_fontname =name;
   m_fontsize =size;
   m_fontflags=flags;
   m_fontangle=angle;
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Set fontname                                                     |
//+------------------------------------------------------------------+
bool CCanvas::FontNameSet(string name)
  {
   if(!TextSetFont(name,m_fontsize,m_fontflags,m_fontangle))
      return(false);
//--- save parameter of generated font
   m_fontname=name;
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Set fontsize                                                     |
//+------------------------------------------------------------------+
bool CCanvas::FontSizeSet(int size)
  {
   if(!TextSetFont(m_fontname,size,m_fontflags,m_fontangle))
      return(false);
//--- save parameter of generated font
   m_fontsize=size;
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Set fontflags                                                    |
//+------------------------------------------------------------------+
bool CCanvas::FontFlagsSet(uint flags)
  {
   if(!TextSetFont(m_fontname,m_fontsize,flags,m_fontangle))
      return(false);
//--- save parameter of generated font
   m_fontflags=flags;
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Set fontangle                                                    |
//+------------------------------------------------------------------+
bool CCanvas::FontAngleSet(uint angle)
  {
   if(!TextSetFont(m_fontname,m_fontsize,m_fontflags,angle))
      return(false);
//--- save parameter of generated font
   m_fontangle=angle;
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Set font                                                         |
//+------------------------------------------------------------------+
bool CCanvas::FontSet(void)
  {
   return(TextSetFont(m_fontname,m_fontsize,m_fontflags,m_fontangle));
  }
//+------------------------------------------------------------------+
//| Get font params                                                  |
//+------------------------------------------------------------------+
void CCanvas::FontGet(string &name,int &size,uint &flags,uint &angle)
  {
   name =m_fontname;
   size =m_fontsize;
   flags=m_fontflags;
   angle=m_fontangle;
  }
//+------------------------------------------------------------------+
//| Out text                                                         |
//+------------------------------------------------------------------+
void CCanvas::TextOut(int x,int y,string text,const uint clr,uint alignment)
  {
   if(FontSet())
      TextOut(text,x,y,alignment,m_pixels,m_width,m_height,clr,m_format);
  }
//+------------------------------------------------------------------+
//| Out text                                                         |
//+------------------------------------------------------------------+
void CCanvas::TextOutFast(int x,int y,string text,const uint clr,uint alignment)
  {
   TextOut(text,x,y,alignment,m_pixels,m_width,m_height,clr,m_format);
  }
//+------------------------------------------------------------------+
//| Text width                                                       |
//+------------------------------------------------------------------+
int CCanvas::TextWidth(const string text)
  {
   if(!FontSet())
      return(0);
//---
   int w,h;
   TextGetSize(text,w,h);
//--- result
   return(w);
  }
//+------------------------------------------------------------------+
//| Text height                                                      |
//+------------------------------------------------------------------+
int CCanvas::TextHeight(const string text)
  {
   if(!FontSet())
      return(0);
//---
   int w,h;
   TextGetSize(text,w,h);
//--- result
   return(h);
  }
//+------------------------------------------------------------------+
//| Text rectangle                                                   |
//+------------------------------------------------------------------+
void CCanvas::TextSize(const string text,int &width,int &height)
  {
   if(FontSet())
      TextGetSize(text,width,height);
  }
//+------------------------------------------------------------------+
//| Load data from file                                              |
//+------------------------------------------------------------------+
bool CCanvas::LoadFromFile(const string filename)
  {
   struct BitmapHeader
     {
      ushort            type;
      uint              size;
      uint              reserv;
      uint              offbits;
      uint              imgSSize;
      uint              imgWidth;
      uint              imgHeight;
      ushort            imgPlanes;
      ushort            imgBitCount;
      uint              imgCompression;
      uint              imgSizeImage;
      uint              imgXPelsPerMeter;
      uint              imgYPelsPerMeter;
      uint              imgClrUsed;
      uint              imgClrImportant;
     }      header;
   bool     result=true;
   CFileBin file;
   int      x,y;
   uchar    a,r,g,b;
   uchar    tmp[];
   uint     img_size;
   bool     no_alpha,no_flip=false;
//--- open file
   if(file.Open(filename,FILE_READ)==INVALID_HANDLE)
     {
      Print("File not found");
      return(false);
     }
//--- read header
   if(file.ReadStruct(header)!=sizeof(header))
     {
      Print("Failed to read file header");
      file.Close();
      return(false);
     }
   m_width =(int)header.imgWidth;
   m_height=(int)header.imgHeight;
   if(m_height<0)
     {
      m_height=-m_height;
      no_flip=true;
     }
//--- process depending on color depth
   if(header.imgBitCount==32)
     {
      no_alpha=true;
      img_size=file.ReadArray(m_pixels);
      //--- flip image
      if(!no_flip)
         for(y=0;y<m_height/2;y++)
           {
            ArrayCopy(tmp,m_pixels,0,m_width*y,m_width);
            ArrayCopy(m_pixels,m_pixels,m_width*y,m_width*(m_height-y-1),m_width);
            ArrayCopy(m_pixels,tmp,m_width*(m_height-y-1),0,m_width);
           }
      //--- check if at least one pixel has alpha channel
      //--- then leave image as is (consider it as premultiplied ARGB)
      uint i;
      for(i=0;i<img_size;i++)
        {
         //--- there is alpha channel
         if(GETRGBA(m_pixels[i])!=0)
           {
            no_alpha=false;
            break;
           }
        }
      //--- no alpha channel
      if(no_alpha)
        {
         //--- consider image as nontransparent, add alpha channel as 0xFF
         for(i=0;i<img_size;i++)
            m_pixels[i]|=0xFF000000;
        }
      else
        {
         if(m_format==COLOR_FORMAT_ARGB_RAW)
           {
            //--- color components are not processed by terminal (they should be correctly specified by user) 
            //--- convert image to premultiplied ARGB
            for(i=0;i<img_size;i++)
              {
               switch(a=GETRGBA(m_pixels[i]))
                 {
                  case 0xFF:
                     break;
                  case 0x00:
                     m_pixels[i]=0;
                     break;
                  default:
                     r=GETRGBR(m_pixels[i])*a/255;
                     g=GETRGBG(m_pixels[i])*a/255;
                     b=GETRGBB(m_pixels[i])*a/255;
                     m_pixels[i]=ARGB(a,r,g,b);
                     break;
                 }
              }
           }
        }
     }
   else
     {
      //--- 24 bits - change image color depth to 32 bits
      int byte_width;
      //--- allocate memory for pixels
      if(ArrayResize(m_pixels,m_width*m_height)!=-1)
        {
         //--- the number of bytes that define a line of pixels must be multiple of 4
         byte_width=m_width*3;             // number of bytes in line of pixels
         byte_width=(byte_width+3)&~3;     // align line to the 4 byte boundary
         for(y=0;y<m_height;y++)
           {
            if(file.ReadArray(tmp,0,byte_width)!=byte_width)
              {
               result=false;
               break;
              }
            int k,p;
            for(x=0,k=0,p=m_width*(m_height-y-1);x<m_width;x++,p++,k+=3)
              {
               r=tmp[k+2];
               g=tmp[k+1];
               b=tmp[k];
               m_pixels[p]=XRGB(r,g,b);
              }
           }
        }
      else
         result=false;
     }
//--- succeed
   file.Close();
   return(result);
  }
//+------------------------------------------------------------------+
//| Determines direction of points iteration (<0 - clockwise)        |
//+------------------------------------------------------------------+
int CCanvas::PointClassify(const CPoint &p0,const CPoint &p1,const CPoint &p2)
  {
   return((p1.x-p0.x)*(p2.y-p0.y)-(p2.x-p0.x)*(p1.y-p0.y));
  }
//+------------------------------------------------------------------+
//| Determines direction of polygon iteration                        |
//+------------------------------------------------------------------+
int CCanvas::PolygonClassify(const CPoint &p[])
  {
   int total=ArraySize(p);
   int im= 0;
   int xm=p[0].x;
   int ym=p[0].y;
//--- find the most top-left vertex 
   for(int i=1;i<total;i++)
     {
      if(p[i].y>ym)
         continue;
      if((p[i].y==ym) && (p[i].x>xm))
         continue;
      im=i;
      xm=p[i].x;
      ym=p[i].y;
     }
//--- check the orientation of triangle
   return PointClassify(p[(im-1+total)%total],p[im],p[(im+1)%total]);
  }
//+------------------------------------------------------------------+
//| Checks convexity of polygon                                      |
//+------------------------------------------------------------------+
bool CCanvas::IsPolygonConvex(CPoint &p[])
  {
   int total=ArraySize(p);
//--- triangle - always convex
   if(total==3)
      return(true);
   int res=SIGN(PointClassify(p[0],p[1],p[2]));
   for(int i=1;i<total;i++)
     {
      int res1=SIGN(PointClassify(p[i],p[(i+1)%total],p[(i+2)%total]));
      if(res!=res1)
         return(false);
     }
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Normalizes polygon for drawing                                   |
//+------------------------------------------------------------------+
void CCanvas::PolygonNormalize(CPoint &p[])
  {
   int total=ArraySize(p);
//--- find top-left point
   int imin=0;
   int xmin=p[0].x;
   int ymin=p[0].y;
   int i;
   for(i=1;i<total;i++)
     {
      if(p[i].y>ymin)
         continue;
      if(p[i].y==ymin)
        {
         if(p[i].x<xmin)
           {
            xmin=p[i].x;
            imin=i;
           }
         continue;
        }
      xmin=p[i].x;
      ymin=p[i].y;
      imin=i;
     }
   if(imin==0)
      return;
   for(i=0;i<imin;i++)
     {
      CPoint tmp=p[0];
      ArrayCopy(p,p,0,1);
      p[total-1]=tmp;
     }
  }
//+------------------------------------------------------------------+
//| Dissects non-convex polygon into two                             |
//+------------------------------------------------------------------+
void CCanvas::PolygonIntersect(CPoint &p[],CPoint &add[])
  {
   int total=ArraySize(p);
   int res=SIGN(PolygonClassify(p));
//--- scan vertices clockwise and counterclockwise to find a non-convex one
   for(int i=0;i<total;i++)
     {
      int rr=SIGN(PointClassify(p[i],p[(i+1)%total],p[(i+2)%total]));
      int rl=SIGN(PointClassify(p[(total-i-2)%total],p[(total-i-1)%total],p[(total-i)%total]));
      if(rl!=res || rr!=res)
        {
         //--- find non-convex vertex, dissect
         res=(total-i-1)-(i+1);
         if(res<0)
            return;
         if(res<2)
           {
            ArrayResize(add,total-i);
            add[0]=p[0];
            ArrayCopy(add,p,1,i+1,total-i-1);
            ArrayResize(p,i+2);
           }
         else
           {
            ArrayResize(add,res+1);
            ArrayCopy(add,p,0,i+1,res+1);
            ArrayCopy(p,p,i+2,i+res+1,total-res-i-1);
            ArrayResize(p,total-res+1);
           }
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//| Draws filled convex polygon (point 0 is top-left)                |
//+------------------------------------------------------------------+
void CCanvas::PolygonFill(CPoint &p[],const uint clr)
  {
   int    il,ir;
   double xl,xr;
   int    yy;
   double dl=0.0,dr=0.0;
   int    total=ArraySize(p);
//--- check
   if(total<3)
      return;
//--- check polygon for convexity
   while(!IsPolygonConvex(p))
     {
      CPoint add[];
      PolygonIntersect(p,add);
      PolygonNormalize(add);
      PolygonFill(add,clr);
      ArrayFree(add);
     }
   total=ArraySize(p);
//--- initial settings
   il=ir=0;
   xl=xr=p[0].x;
   yy=p[0].y;
//--- in case of top horizontal line
   if(yy==p[1].y)
      xr=p[ir=1].x;
//--- draw the top
   LineHorizontal((int)MathCeil(xl),(int)MathFloor(xr),yy,clr);
//--- loop by Y
   do
     {
      while(yy==p[il].y)
        {
         il=(il-1+total)%total;
         if(yy>p[il].y)
            return;
         if(yy!=p[il].y)
           {
            dl=(p[il].x-xl)/(p[il].y-yy);
            //--- make adjustment for half of left increment dl/2
            LineHorizontal((int)MathCeil(xl+dl/2),(int)MathFloor(xl),yy,clr);
            xl+=dl/2;
           }
         else
            LineHorizontal((int)MathCeil(xl),(int)MathFloor(p[il].x),yy,clr);
        }
      while(yy==p[ir].y)
        {
         ir=(ir+1)%total;
         if(yy>p[ir].y)
            return;
         if(yy!=p[ir].y)
           {
            dr=(p[ir].x-xr)/(p[ir].y-yy);
            //--- make adjustment for half of right increment dr/2
            LineHorizontal((int)MathCeil(xr),(int)MathFloor(xr+dr/2),yy,clr);
            xr+=dr/2;
           }
         else
            LineHorizontal((int)MathCeil(p[ir].x),(int)MathFloor(xr),yy,clr);
        }
      yy++;
      if(yy==p[il].y)
         xl=p[il].x;
      else
         xl+=dl;
      if(yy==p[ir].y)
         xr=p[ir].x;
      else
         xr+=dr;
      LineHorizontal((int)MathCeil(xl),(int)MathFloor(xr),yy,clr);
     }
   while(il>=ir && ir!=0);
  }
//+------------------------------------------------------------------+

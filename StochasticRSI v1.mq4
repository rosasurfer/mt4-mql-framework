/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                                                                                    My Stoch RSI v1
                                                                   Copyright (c) 2019,  Broketrader
                                                                                        Switzerland

 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/



/**************************************************************************************************
   Input vars
**************************************************************************************************/
input int RsiLength     = 100;
input int StochLength   = 100;
input int SmoothK       = 30;
input int SmoothD       = 6;


/**************************************************************************************************
   Include files
**************************************************************************************************/



/**************************************************************************************************
   Indicator Properties
**************************************************************************************************/
#property indicator_separate_window
#property indicator_minimum    -10
#property indicator_maximum    110


//#property indicator_color1
//#property indicator_color2 Black
#property indicator_color3 DodgerBlue


#property indicator_separate_window
#property indicator_buffers    3
#property indicator_levelcolor clrBlack
#property indicator_levelstyle STYLE_SOLID



/**************************************************************************************************
   EA Identification.
**************************************************************************************************/
#define        IN          "MyStochRSI"            // Indicator NAme
#define        IC          "(c) 2019 BT"           // Copyright 2010 BrokeTrader
#define        IV          "01.00"                 // Indicator Version: Version.Year
#define        IBUILD      "01"                    // Indicator Build Number: #Month#Day
string         IName   =   IN " V " IV IBUILD;     // Indicator Full name composite
#property      copyright   IC
#property      version     IV
#property      strict



/**************************************************************************************************
   Global definitions and Input var Declarations.
***************************************************************************************************/
double Buffer1[];
double Buffer2[];
double Buffer3[];



/**************************************************************************************************
   OnInit
***************************************************************************************************/
int OnInit()
{
   IndicatorShortName( IName );

   SetIndexStyle(0,DRAW_NONE,STYLE_SOLID,1);
   SetIndexBuffer(0,Buffer1);
   SetIndexLabel(0,NULL );

   SetIndexStyle(1,DRAW_NONE,STYLE_SOLID,1);
   SetIndexBuffer(1,Buffer2);
   SetIndexLabel(1,NULL);

   SetIndexStyle(2,DRAW_LINE,STYLE_SOLID,2);
   SetIndexBuffer(2,Buffer3);
   SetIndexLabel(2,"MyStochRSI");

   SetLevelStyle( STYLE_DASH, 2, DodgerBlue );
   SetLevelValue( 0, 5 );
   SetLevelValue( 1, 95 );
   SetLevelStyle( STYLE_DASH, 1, DodgerBlue );
   SetLevelValue( 2, 40 );
   SetLevelValue( 3, 50 );
   SetLevelValue( 4, 60 );


   return INIT_SUCCEEDED;
}



/**************************************************************************************************
   OnDeinit
***************************************************************************************************/
void OnDeinit( const int pReason )
{
}



/**************************************************************************************************
***************************************************************************************************/
int start()
{
   int counted_bars = IndicatorCounted();

   double lRsi, lLowestRsi, lHighestRsi;

   int NumOfBars = MathMin( Bars, 2400) ;

   for( int i=NumOfBars-MathMax(RsiLength,StochLength)-1; i>=0; i-- ){
      // Calculate RSI
      lRsi = iRSI( NULL, 0, RsiLength, PRICE_CLOSE, i );

      // Calulate Stoch of RSI
      // Stochastic is calculated by a formula: 100 * (close - lowest(low, length)) / (highest(high, length) - lowest(low, length))
      lHighestRsi = lLowestRsi = lRsi;

      for( int x=0; x<StochLength; x++ ){
         lLowestRsi  = MathMin( lLowestRsi,  iRSI(NULL,0,RsiLength,PRICE_CLOSE,i+x) );
         lHighestRsi = MathMax( lHighestRsi, iRSI(NULL,0,RsiLength,PRICE_CLOSE,i+x) );
      }

      Buffer1[i] = ((lRsi-lLowestRsi)/(lHighestRsi-lLowestRsi))*100;

      double lKSum=0;
      for(int x=0; x<SmoothK; x++ ){
         lKSum += Buffer1[i+x];
      }
      Buffer2[i] = lKSum/SmoothK;


      double lDSum = 0;
      for( int x=0; x<SmoothD; x++ ){
         lDSum += Buffer2[i+x];
      }
      //Buffer3[i] = lDSum/SmoothD; // Should be this, but not accurate !?
      Buffer3[i] = ( lDSum/SmoothD + Buffer2[i] ) / 2;


   }

   return(0);

}


// End of File.

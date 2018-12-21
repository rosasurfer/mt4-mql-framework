//+------------------------------------------------------------------+
//|                                                  integration.mqh |
//|            Copyright 2003-2012 Sergey Bochkanov (ALGLIB project) |
//|                   Copyright 2012-2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//| Implementation of ALGLIB library in MetaQuotes Language 5        |
//|                                                                  |
//| The features of the library include:                             |
//| - Linear algebra (direct algorithms, EVD, SVD)                   |
//| - Solving systems of linear and non-linear equations             |
//| - Interpolation                                                  |
//| - Optimization                                                   |
//| - FFT (Fast Fourier Transform)                                   |
//| - Numerical integration                                          |
//| - Linear and nonlinear least-squares fitting                     |
//| - Ordinary differential equations                                |
//| - Computation of special functions                               |
//| - Descriptive statistics and hypothesis testing                  |
//| - Data analysis - classification, regression                     |
//| - Implementing linear algebra algorithms, interpolation, etc.    |
//|   in high-precision arithmetic (using MPFR)                      |
//|                                                                  |
//| This file is free software; you can redistribute it and/or       |
//| modify it under the terms of the GNU General Public License as   |
//| published by the Free Software Foundation (www.fsf.org); either  |
//| version 2 of the License, or (at your option) any later version. |
//|                                                                  |
//| This program is distributed in the hope that it will be useful,  |
//| but WITHOUT ANY WARRANTY; without even the implied warranty of   |
//| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the     |
//| GNU General Public License for more details.                     |
//+------------------------------------------------------------------+
#include "ap.mqh"
#include "alglibinternal.mqh"
#include "linalg.mqh"
#include "specialfunctions.mqh"
//+------------------------------------------------------------------+
//| Gauss quadrature formula                                         |
//+------------------------------------------------------------------+
class CGaussQ
  {
public:
                     CGaussQ(void);
                    ~CGaussQ(void);

   static void       GQGenerateRec(double &alpha[],double &beta[],const double mu0,const int n,int &info,double &x[],double &w[]);
   static void       GQGenerateGaussLobattoRec(double &calpha[],double &cbeta[],const double mu0,const double a,const double b,int n,int &info,double &x[],double &w[]);
   static void       GQGenerateGaussRadauRec(double &calpha[],double &cbeta[],const double mu0,const double a,int n,int &info,double &x[],double &w[]);
   static void       GQGenerateGaussLegendre(const int n,int &info,double &x[],double &w[]);
   static void       GQGenerateGaussJacobi(const int n,const double alpha,const double beta,int &info,double &x[],double &w[]);
   static void       GQGenerateGaussLaguerre(const int n,const double alpha,int &info,double &x[],double &w[]);
   static void       GQGenerateGaussHermite(const int n,int &info,double &x[],double &w[]);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CGaussQ::CGaussQ(void)
  {

  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGaussQ::~CGaussQ(void)
  {

  }
//+------------------------------------------------------------------+
//| Computation of nodes and weights for a Gauss quadrature formula  |
//| The algorithm generates the N-point Gauss quadrature formula     |
//| with weight function given by coefficients alpha and beta of a   |
//| recurrence relation which generates a system of orthogonal       |
//| polynomials:                                                     |
//| P-1(x)   =  0                                                    |
//| P0(x)    =  1                                                    |
//| Pn+1(x)  =  (x-alpha(n))*Pn(x)  -  beta(n)*Pn-1(x)               |
//| and zeroth moment Mu0                                            |
//| Mu0 = integral(W(x)dx,a,b)                                       |
//| INPUT PARAMETERS:                                                |
//|     Alpha   Ц   array[0..N-1], alpha coefficients                |
//|     Beta    Ц   array[0..N-1], beta coefficients                 |
//|                 Zero-indexed element is not used and may be      |
//|                 arbitrary. Beta[I]>0.                            |
//|     Mu0     Ц   zeroth moment of the weight function.            |
//|     N       Ц   number of nodes of the quadrature formula, N>=1  |
//| OUTPUT PARAMETERS:                                               |
//|     Info    -   error code:                                      |
//|                 * -3    internal eigenproblem solver hasn't      |
//|                         converged                                |
//|                 * -2    Beta[i]<=0                               |
//|                 * -1    incorrect N was passed                   |
//|                 *  1    OK                                       |
//|     X       -   array[0..N-1] - array of quadrature nodes,       |
//|                 in ascending order.                              |
//|     W       -   array[0..N-1] - array of quadrature weights.     |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateRec(double &alpha[],double &beta[],
                                   const double mu0,const int n,
                                   int &info,double &x[],double &w[])
  {
//--- create a variable
   int i=0;
//--- create arrays
   double d[];
   double e[];
//--- create matrix
   CMatrixDouble z;
//--- initialization
   info=0;
//--- check
   if(n<1)
     {
      info=-1;
      return;
     }
   info=1;
//--- Initialize
   ArrayResizeAL(d,n);
   ArrayResizeAL(e,n);
//--- calculation
   for(i=1;i<=n-1;i++)
     {
      d[i-1]=alpha[i-1];
      //--- check
      if(beta[i]<=0.0)
        {
         info=-2;
         return;
        }
      e[i-1]=MathSqrt(beta[i]);
     }
//--- change value
   d[n-1]=alpha[n-1];
//--- EVD
   if(!CEigenVDetect::SMatrixTdEVD(d,e,n,3,z))
     {
      info=-3;
      return;
     }
//--- Generate
   ArrayResizeAL(x,n);
   ArrayResizeAL(w,n);
//--- calculation
   for(i=1;i<=n;i++)
     {
      x[i-1]=d[i-1];
      w[i-1]=mu0*CMath::Sqr(z[0][i-1]);
     }
  }
//+------------------------------------------------------------------+
//| Computation of nodes and weights for a Gauss-Lobatto quadrature  |
//| formula                                                          |
//| The algorithm generates the N-point Gauss-Lobatto quadrature     |
//| formula with weight function given by coefficients alpha and beta|
//| of a recurrence which generates a system of orthogonal           |
//| polynomials.                                                     |
//| P-1(x)   =  0                                                    |
//| P0(x)    =  1                                                    |
//| Pn+1(x)  =  (x-alpha(n))*Pn(x)  -  beta(n)*Pn-1(x)               |
//| and zeroth moment Mu0                                            |
//| Mu0 = integral(W(x)dx,a,b)                                       |
//| INPUT PARAMETERS:                                                |
//|     Alpha   Ц   array[0..N-2], alpha coefficients                |
//|     Beta    Ц   array[0..N-2], beta coefficients.                |
//|                 Zero-indexed element is not used, may be         |
//|                 arbitrary. Beta[I]>0                             |
//|     Mu0     Ц   zeroth moment of the weighting function.         |
//|     A       Ц   left boundary of the integration interval.       |
//|     B       Ц   right boundary of the integration interval.      |
//|     N       Ц   number of nodes of the quadrature formula, N>=3  |
//|                 (including the left and right boundary nodes).   |
//| OUTPUT PARAMETERS:                                               |
//|     Info    -   error code:                                      |
//|                 * -3    internal eigenproblem solver hasn't      |
//|                         converged                                |
//|                 * -2    Beta[i]<=0                               |
//|                 * -1    incorrect N was passed                   |
//|                 *  1    OK                                       |
//|     X       -   array[0..N-1] - array of quadrature nodes,       |
//|                 in ascending order.                              |
//|     W       -   array[0..N-1] - array of quadrature weights.     |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateGaussLobattoRec(double &calpha[],double &cbeta[],
                                               const double mu0,const double a,
                                               const double b,int n,int &info,
                                               double &x[],double &w[])
  {
//--- create variables
   int    i=0;
   double pim1a=0;
   double pia=0;
   double pim1b=0;
   double pib=0;
   double t=0;
   double a11=0;
   double a12=0;
   double a21=0;
   double a22=0;
   double b1=0;
   double b2=0;
   double alph=0;
   double bet=0;
//--- create arrays
   double d[];
   double e[];
//--- create matrix
   CMatrixDouble z;
//--- creating copies of arrays
   double alpha[];
   double beta[];
   ArrayCopy(alpha,calpha);
   ArrayCopy(beta,cbeta);
//--- initialization
   info=0;
//--- check
   if(n<=2)
     {
      info=-1;
      return;
     }
   info=1;
//--- Initialize,D[1:N+1],E[1:N]
   n=n-2;
//--- allocation
   ArrayResizeAL(d,n+2);
   ArrayResizeAL(e,n+1);
//--- copy
   for(i=1;i<=n+1;i++)
      d[i-1]=alpha[i-1];
   for(i=1;i<=n;i++)
     {
      //--- check
      if(beta[i]<=0.0)
        {
         info=-2;
         return;
        }
      e[i-1]=MathSqrt(beta[i]);
     }
//--- Caclulate Pn(a),Pn+1(a),Pn(b),Pn+1(b)
   beta[0]=0;
   pim1a=0;
   pia=1;
   pim1b=0;
   pib=1;
   for(i=1;i<=n+1;i++)
     {
      //--- Pi(a)
      t=(a-alpha[i-1])*pia-beta[i-1]*pim1a;
      pim1a=pia;
      pia=t;
      //--- Pi(b)
      t=(b-alpha[i-1])*pib-beta[i-1]*pim1b;
      pim1b=pib;
      pib=t;
     }
//--- Calculate alpha'(n+1),beta'(n+1)
   a11=pia;
   a12=pim1a;
   a21=pib;
   a22=pim1b;
   b1=a*pia;
   b2=b*pib;
//--- check
   if(MathAbs(a11)>MathAbs(a21))
     {
      //--- change values
      a22=a22-a12*a21/a11;
      b2=b2-b1*a21/a11;
      bet=b2/a22;
      alph=(b1-bet*a12)/a11;
     }
   else
     {
      //--- change values
      a12=a12-a22*a11/a21;
      b1=b1-b2*a11/a21;
      bet=b1/a12;
      alph=(b2-bet*a22)/a21;
     }
//--- check
   if(bet<0.0)
     {
      info=-3;
      return;
     }
//--- change values
   d[n+1]=alph;
   e[n]=MathSqrt(bet);
//--- EVD
   if(!CEigenVDetect::SMatrixTdEVD(d,e,n+2,3,z))
     {
      info=-3;
      return;
     }
//--- Generate
   ArrayResizeAL(x,n+2);
   ArrayResizeAL(w,n+2);
//--- get result
   for(i=1;i<=n+2;i++)
     {
      x[i-1]=d[i-1];
      w[i-1]=mu0*CMath::Sqr(z[0][i-1]);
     }
  }
//+------------------------------------------------------------------+
//| Computation of nodes and weights for a Gauss-Radau quadrature    |
//| formula                                                          |
//| The algorithm generates the N-point Gauss-Radau  quadrature      |
//| formula with weight function given by the coefficients alpha and |
//| beta of a recurrence which generates a system of orthogonal      |
//| polynomials.                                                     |
//| P-1(x)   =  0                                                    |
//| P0(x)    =  1                                                    |
//| Pn+1(x)  =  (x-alpha(n))*Pn(x)  -  beta(n)*Pn-1(x)               |
//| and zeroth moment Mu0                                            |
//| Mu0 = integral(W(x)dx,a,b)                                       |
//| INPUT PARAMETERS:                                                |
//|     Alpha   Ц   array[0..N-2], alpha coefficients.               |
//|     Beta    Ц   array[0..N-1], beta coefficients                 |
//|                 Zero-indexed element is not used.                |
//|                 Beta[I]>0                                        |
//|     Mu0     Ц   zeroth moment of the weighting function.         |
//|     A       Ц   left boundary of the integration interval.       |
//|     N       Ц   number of nodes of the quadrature formula, N>=2  |
//|                 (including the left boundary node).              |
//| OUTPUT PARAMETERS:                                               |
//|     Info    -   error code:                                      |
//|                 * -3    internal eigenproblem solver hasn't      |
//|                         converged                                |
//|                 * -2    Beta[i]<=0                               |
//|                 * -1    incorrect N was passed                   |
//|                 *  1    OK                                       |
//|     X       -   array[0..N-1] - array of quadrature nodes,       |
//|                 in ascending order.                              |
//|     W       -   array[0..N-1] - array of quadrature weights.     |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateGaussRadauRec(double &calpha[],double &cbeta[],
                                             const double mu0,const double a,
                                             int n,int &info,double &x[],
                                             double &w[])
  {
//--- create variables
   int i=0;
   double polim1=0;
   double poli=0;
   double t=0;
//--- create arrays
   double d[];
   double e[];
//--- create matrix
   CMatrixDouble z;
//--- creating copies of arrays
   double alpha[];
   double beta[];
   ArrayCopy(alpha,calpha);
   ArrayCopy(beta,cbeta);
//--- initialization
   info=0;
//--- check
   if(n<2)
     {
      info=-1;
      return;
     }
   info=1;
//--- Initialize,D[1:N],E[1:N]
   n=n-1;
//--- allocation
   ArrayResizeAL(d,n+1);
   ArrayResizeAL(e,n);
   for(i=1;i<=n;i++)
     {
      d[i-1]=alpha[i-1];
      //--- check
      if(beta[i]<=0.0)
        {
         info=-2;
         return;
        }
      e[i-1]=MathSqrt(beta[i]);
     }
//--- Caclulate Pn(a),Pn-1(a),and D[N+1]
   beta[0]=0;
   polim1=0;
   poli=1;
//--- calculation
   for(i=1;i<=n;i++)
     {
      t=(a-alpha[i-1])*poli-beta[i-1]*polim1;
      polim1=poli;
      poli=t;
     }
   d[n]=a-beta[n]*polim1/poli;
//--- EVD
   if(!CEigenVDetect::SMatrixTdEVD(d,e,n+1,3,z))
     {
      info=-3;
      return;
     }
//--- Generate
   ArrayResizeAL(x,n+1);
   ArrayResizeAL(w,n+1);
//--- get result
   for(i=1;i<=n+1;i++)
     {
      x[i-1]=d[i-1];
      w[i-1]=mu0*CMath::Sqr(z[0][i-1]);
     }
  }
//+------------------------------------------------------------------+
//| Returns nodes/weights for Gauss-Legendre quadrature on [-1,1]    |
//| with N nodes.                                                    |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of nodes, >=1                         |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -4    an error was detected when           |
//|                             calculating weights/nodes. N is too  |
//|                             large to obtain weights/nodes with   |
//|                             high enough accuracy. Try to use     |
//|                             multiple precision version.          |
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N was passed               |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     in ascending order.                          |
//|     W           -   array[0..N-1] - array of quadrature weights. |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateGaussLegendre(const int n,int &info,
                                             double &x[],double &w[])
  {
//--- create a variable
   int i=0;
//--- create arrays
   double alpha[];
   double beta[];
//--- initialization
   info=0;
//--- check
   if(n<1)
     {
      info=-1;
      return;
     }
//--- allocation
   ArrayResizeAL(alpha,n);
   ArrayResizeAL(beta,n);
//--- initialization
   for(i=0;i<=n-1;i++)
      alpha[i]=0;
   beta[0]=2;
   for(i=1;i<=n-1;i++)
      beta[i]=1/(4-1/CMath::Sqr(i));
//--- function call
   GQGenerateRec(alpha,beta,beta[0],n,info,x,w);
//--- test basic properties to detect errors
   if(info>0)
     {
      //--- check
      if(x[0]<-1.0 || x[n-1]>1.0)
         info=-4;
      for(i=0;i<=n-2;i++)
        {
         //--- check
         if(x[i]>=x[i+1])
            info=-4;
        }
     }
  }
//+------------------------------------------------------------------+
//| Returns  nodes/weights  for  Gauss-Jacobi quadrature on [-1,1]   |
//| with weight function W(x)=Power(1-x,Alpha)*Power(1+x,Beta).      |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of nodes, >=1                         |
//|     Alpha       -   power-law coefficient, Alpha>-1              |
//|     Beta        -   power-law coefficient, Beta>-1               |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -4    an error was detected when           |
//|                             calculating weights/nodes. Alpha or  |
//|                             Beta are too close to -1 to obtain   |
//|                             weights/nodes with high enough       |
//|                             accuracy, or, may be, N is too large.|
//|                             Try to use multiple precision version|
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N/Alpha/Beta was passed    |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     in ascending order.                          |
//|     W           -   array[0..N-1] - array of quadrature weights. |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateGaussJacobi(const int n,const double alpha,
                                           const double beta,int &info,
                                           double &x[],double &w[])
  {
//--- create variables
   double alpha2=0;
   double beta2=0;
   double apb=0;
   double t=0;
   int    i=0;
   double s=0;
//--- create arrays
   double a[];
   double b[];
//--- initialization
   info=0;
//--- check
   if((n<1 || alpha<=-1.0) || beta<=-1.0)
     {
      info=-1;
      return;
     }
//--- allocation
   ArrayResizeAL(a,n);
   ArrayResizeAL(b,n);
//--- initialization
   apb=alpha+beta;
   a[0]=(beta-alpha)/(apb+2);
   t=(apb+1)*MathLog(2)+CGammaFunc::LnGamma(alpha+1,s)+CGammaFunc::LnGamma(beta+1,s)-CGammaFunc::LnGamma(apb+2,s);
//--- check
   if(t>MathLog(CMath::m_maxrealnumber))
     {
      info=-4;
      return;
     }
   b[0]=MathExp(t);
//--- check
   if(n>1)
     {
      //--- change values
      alpha2=CMath::Sqr(alpha);
      beta2=CMath::Sqr(beta);
      a[1]=(beta2-alpha2)/((apb+2)*(apb+4));
      b[1]=4*(alpha+1)*(beta+1)/((apb+3)*CMath::Sqr(apb+2));
      //--- calculation
      for(i=2;i<=n-1;i++)
        {
         a[i]=0.25*(beta2-alpha2)/(i*i*(1+0.5*apb/i)*(1+0.5*(apb+2)/i));
         b[i]=0.25*(1+alpha/i)*(1+beta/i)*(1+apb/i)/((1+0.5*(apb+1)/i)*(1+0.5*(apb-1)/i)*CMath::Sqr(1+0.5*apb/i));
        }
     }
//--- function call
   GQGenerateRec(a,b,b[0],n,info,x,w);
//--- test basic properties to detect errors
   if(info>0)
     {
      //--- check
      if(x[0]<-1.0 || x[n-1]>1.0)
         info=-4;
      for(i=0;i<=n-2;i++)
        {
         //--- check
         if(x[i]>=x[i+1])
            info=-4;
        }
     }
  }
//+------------------------------------------------------------------+
//| Returns nodes/weights for Gauss-Laguerre quadrature on [0,+inf)  |
//| with weight function W(x)=Power(x,Alpha)*Exp(-x)                 |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of nodes, >=1                         |
//|     Alpha       -   power-law coefficient, Alpha>-1              |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -4    an error was detected when           |
//|                             calculating weights/nodes. Alpha is  |
//|                             too close to -1 to obtain            |
//|                             weights/nodes with high enough       |
//|                             accuracy or, may  be, N is too large.|
//|                             Try  to  use multiple precision      |
//|                             version.                             |
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N/Alpha was passed         |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     in ascending order.                          |
//|     W           -   array[0..N-1] - array of quadrature weights. |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateGaussLaguerre(const int n,const double alpha,
                                             int &info,double &x[],
                                             double &w[])
  {
//--- create arrays
   double a[];
   double b[];
//--- create variables
   double t=0;
   int    i=0;
   double s=0;
//--- initialization
   info=0;
//--- check
   if(n<1 || alpha<=-1.0)
     {
      info=-1;
      return;
     }
//--- allocation
   ArrayResizeAL(a,n);
   ArrayResizeAL(b,n);
//--- initialization
   a[0]=alpha+1;
   t=CGammaFunc::LnGamma(alpha+1,s);
//--- check
   if(t>=MathLog(CMath::m_maxrealnumber))
     {
      info=-4;
      return;
     }
   b[0]=MathExp(t);
//--- check
   if(n>1)
     {
      //--- calculation
      for(i=1;i<=n-1;i++)
        {
         a[i]=2*i+alpha+1;
         b[i]=i*(i+alpha);
        }
     }
//--- function call
   GQGenerateRec(a,b,b[0],n,info,x,w);
//--- test basic properties to detect errors
   if(info>0)
     {
      //--- check
      if(x[0]<0.0)
         info=-4;
      for(i=0;i<=n-2;i++)
        {
         //--- check
         if(x[i]>=x[i+1])
            info=-4;
        }
     }
  }
//+------------------------------------------------------------------+
//| Returns  nodes/weights  for  Gauss-Hermite  quadrature on        |
//| (-inf,+inf) with weight function W(x)=Exp(-x*x)                  |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of nodes, >=1                         |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -4    an error was detected when           |
//|                             calculating weights/nodes. May be, N |
//|                             is too large. Try to use multiple    |
//|                             precision version.                   |
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N/Alpha was passed         |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     in ascending order.                          |
//|     W           -   array[0..N-1] - array of quadrature weights. |
//+------------------------------------------------------------------+
static void CGaussQ::GQGenerateGaussHermite(const int n,int &info,
                                            double &x[],double &w[])
  {
//--- create a variable
   int i=0;
//--- create arrays
   double a[];
   double b[];
//--- initialization
   info=0;
//--- check
   if(n<1)
     {
      info=-1;
      return;
     }
//--- allocation
   ArrayResizeAL(a,n);
   ArrayResizeAL(b,n);
//--- initialization
   for(i=0;i<=n-1;i++)
      a[i]=0;
   b[0]=MathSqrt(4*MathArctan(1));
//--- check
   if(n>1)
     {
      for(i=1;i<=n-1;i++)
         b[i]=0.5*i;
     }
//--- function call
   GQGenerateRec(a,b,b[0],n,info,x,w);
//--- test basic properties to detect errors
   if(info>0)
     {
      for(i=0;i<=n-2;i++)
        {
         //--- check
         if(x[i]>=x[i+1])
            info=-4;
        }
     }
  }
//+------------------------------------------------------------------+
//| Gauss-Kronrod quadrature formula                                 |
//+------------------------------------------------------------------+
class CGaussKronrodQ
  {
public:
   //--- constructor, destructor
                     CGaussKronrodQ(void);
                    ~CGaussKronrodQ(void);
   //--- methods
   static void       GKQGenerateRec(double &calpha[],double &cbeta[],const double mu0,int n,int &info,double &x[],double &wkronrod[],double &wgauss[]);
   static void       GKQGenerateGaussLegendre(const int n,int &info,double &x[],double &wkronrod[],double &wgauss[]);
   static void       GKQGenerateGaussJacobi(const int n,const double alpha,const double beta,int &info,double &x[],double &wkronrod[],double &wgauss[]);
   static void       GKQLegendreCalc(const int n,int &info,double &x[],double &wkronrod[],double &wgauss[]);
   static void       GKQLegendreTbl(const int n,double &x[],double &wkronrod[],double &wgauss[],double &eps);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CGaussKronrodQ::CGaussKronrodQ(void)
  {

  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CGaussKronrodQ::~CGaussKronrodQ(void)
  {

  }
//+------------------------------------------------------------------+
//| Computation of nodes and weights of a Gauss-Kronrod quadrature   |
//| formula                                                          |
//| The algorithm generates the N-point Gauss-Kronrod quadrature     |
//| formula with weight function given by coefficients alpha and beta|
//| of a recurrence relation which generates a system of orthogonal  |
//| polynomials:                                                     |
//|     P-1(x)   =  0                                                |
//|     P0(x)    =  1                                                |
//|     Pn+1(x)  =  (x-alpha(n))*Pn(x)  -  beta(n)*Pn-1(x)           |
//| and zero moment Mu0                                              |
//|     Mu0 = integral(W(x)dx,a,b)                                   |
//| INPUT PARAMETERS:                                                |
//|     Alpha       Ц   alpha coefficients, array[0..floor(3*K/2)].  |
//|     Beta        Ц   beta coefficients,  array[0..ceil(3*K/2)].   |
//|                     Beta[0] is not used and may be arbitrary.    |
//|                     Beta[I]>0.                                   |
//|     Mu0         Ц   zeroth moment of the weight function.        |
//|     N           Ц   number of nodes of the Gauss-Kronrod         |
//|                     quadrature formula,                          |
//|                     N >= 3,                                      |
//|                     N =  2*K+1.                                  |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -5    no real and positive Gauss-Kronrod   |
//|                             formula can be created for such a    |
//|                             weight function with a given number  |
//|                             of nodes.                            |
//|                     * -4    N is too large, task may be ill      |
//|                             conditioned - x[i]=x[i+1] found.     |
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -2    Beta[i]<=0                           |
//|                     * -1    incorrect N was passed               |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     in ascending order.                          |
//|     WKronrod    -   array[0..N-1] - Kronrod weights              |
//|     WGauss      -   array[0..N-1] - Gauss weights (interleaved   |
//|                     with zeros corresponding to extended Kronrod |
//|                     nodes).                                      |
//+------------------------------------------------------------------+
static void CGaussKronrodQ::GKQGenerateRec(double &calpha[],double &cbeta[],
                                           const double mu0,int n,int &info,
                                           double &x[],double &wkronrod[],
                                           double &wgauss[])
  {
//--- create variables
   int    i=0;
   int    j=0;
   int    wlen=0;
   int    woffs=0;
   double u=0;
   int    m=0;
   int    l=0;
   int    k=0;
   int    i_=0;
//--- create arrays
   double ta[];
   double t[];
   double s[];
   double xgtmp[];
   double wgtmp[];
//--- creating copies of arrays
   double alpha[];
   double beta[];
   ArrayCopy(alpha,calpha);
   ArrayCopy(beta,cbeta);
//--- initialization
   info=0;
//--- check
   if(n%2!=1 || n<3)
     {
      info=-1;
      return;
     }
   for(i=0;i<=(int)MathCeil((double)(3*(n/2))/2.0);i++)
     {
      //--- check
      if(beta[i]<=0.0)
        {
         info=-2;
         return;
        }
     }
   info=1;
//--- from external conventions about N/Beta/Mu0 to internal
   n=n/2;
   beta[0]=mu0;
//--- Calculate Gauss nodes/weights,save them for later processing
   CGaussQ::GQGenerateRec(alpha,beta,mu0,n,info,xgtmp,wgtmp);
//--- check
   if(info<0)
      return;
//--- Resize:
//--- * A from 0..floor(3*n/2) to 0..2*n
//--- * B from 0..ceil(3*n/2)  to 0..2*n
   ArrayResizeAL(ta,(int)MathFloor((double)(3*n)/2.0)+1);
//--- copy
   for(i_=0;i_<=(int)MathFloor((double)(3*n)/2.0);i_++)
      ta[i_]=alpha[i_];
//--- allocation
   ArrayResizeAL(alpha,2*n+1);
//--- copy
   for(i_=0;i_<=(int)MathFloor((double)(3*n)/2.0);i_++)
      alpha[i_]=ta[i_];
//--- initialization
   for(i=(int)MathFloor((double)(3*n)/2.0)+1;i<=2*n;i++)
      alpha[i]=0;
//--- allocation
   ArrayResizeAL(ta,(int)MathCeil((double)(3*n)/2.0)+1);
//--- copy
   for(i_=0;i_<=(int)MathCeil((double)(3*n)/2.0);i_++)
      ta[i_]=beta[i_];
//--- allocation
   ArrayResizeAL(beta,2*n+1);
//--- copy
   for(i_=0;i_<=(int)MathCeil((double)(3*n)/2.0);i_++)
      beta[i_]=ta[i_];
//--- initialization
   for(i=(int)MathCeil((double)(3*n)/2.0)+1;i<=2*n;i++)
      beta[i]=0;
//--- Initialize T,S
   wlen=2+n/2;
//--- allocation
   ArrayResizeAL(t,wlen);
   ArrayResizeAL(s,wlen);
   ArrayResizeAL(ta,wlen);
   woffs=1;
   for(i=0;i<=wlen-1;i++)
     {
      t[i]=0;
      s[i]=0;
     }
//--- Algorithm from Dirk P. Laurie,"Calculation of Gauss-Kronrod quadrature rules",1997.
   t[woffs+0]=beta[n+1];
   for(m=0;m<=n-2;m++)
     {
      u=0;
      //--- calculation
      for(k=(m+1)/2;k>=0;k--)
        {
         l=m-k;
         u=u+(alpha[k+n+1]-alpha[l])*t[woffs+k]+beta[k+n+1]*s[woffs+k-1]-beta[l]*s[woffs+k];
         s[woffs+k]=u;
        }
      //--- copy
      for(i_=0;i_<=wlen-1;i_++)
         ta[i_]=t[i_];
      //--- copy
      for(i_=0;i_<=wlen-1;i_++)
         t[i_]=s[i_];
      //--- copy
      for(i_=0;i_<=wlen-1;i_++)
         s[i_]=ta[i_];
     }
//--- copy
   for(j=n/2;j>=0;j--)
      s[woffs+j]=s[woffs+j-1];
//--- cycle
   for(m=n-1;m<=2*n-3;m++)
     {
      u=0;
      //--- calculation
      for(k=m+1-n;k<=(m-1)/2;k++)
        {
         l=m-k;
         j=n-1-l;
         u=u-(alpha[k+n+1]-alpha[l])*t[woffs+j]-beta[k+n+1]*s[woffs+j]+beta[l]*s[woffs+j+1];
         s[woffs+j]=u;
        }
      //--- check
      if(m%2==0)
        {
         k=m/2;
         alpha[k+n+1]=alpha[k]+(s[woffs+j]-beta[k+n+1]*s[woffs+j+1])/t[woffs+j+1];
        }
      else
        {
         k=(m+1)/2;
         beta[k+n+1]=s[woffs+j]/s[woffs+j+1];
        }
      //--- copy
      for(i_=0;i_<=wlen-1;i_++)
         ta[i_]=t[i_];
      //--- copy
      for(i_=0;i_<=wlen-1;i_++)
         t[i_]=s[i_];
      //--- copy
      for(i_=0;i_<=wlen-1;i_++)
         s[i_]=ta[i_];
     }
//--- change value
   alpha[2*n]=alpha[n-1]-beta[2*n]*s[woffs+0]/t[woffs+0];
//--- calculation of Kronrod nodes and weights,unpacking of Gauss weights
   CGaussQ::GQGenerateRec(alpha,beta,mu0,2*n+1,info,x,wkronrod);
//--- check
   if(info==-2)
      info=-5;
//--- check
   if(info<0)
      return;
   for(i=0;i<=2*n-1;i++)
     {
      //--- check
      if(x[i]>=x[i+1])
         info=-4;
     }
//--- check
   if(info<0)
      return;
//--- allocation
   ArrayResizeAL(wgauss,2*n+1);
//--- get result
   for(i=0;i<=2*n;i++)
      wgauss[i]=0;
   for(i=0;i<=n-1;i++)
      wgauss[2*i+1]=wgtmp[i];
  }
//+------------------------------------------------------------------+
//| Returns Gauss and Gauss-Kronrod nodes/weights for Gauss-Legendre |
//| quadrature with N points.                                        |
//| GKQLegendreCalc (calculation) or GKQLegendreTbl (precomputed     |
//| table) is used depending on machine precision and number of      |
//| nodes.                                                           |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of Kronrod nodes, must be odd number, |
//|                     >=3.                                         |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -4    an error was detected when           |
//|                             calculating weights/nodes. N is too  |
//|                             obtain large to weights/nodes with   |
//|                             high enough accuracy. Try to use     |
//|                             multiple precision version.          |
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N was passed               |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     ordered in ascending order.                  |
//|     WKronrod    -   array[0..N-1] - Kronrod weights              |
//|     WGauss      -   array[0..N-1] - Gauss weights (interleaved   |
//|                     with zeros corresponding to extended Kronrod |
//|                     nodes).                                      |
//+------------------------------------------------------------------+
static void CGaussKronrodQ::GKQGenerateGaussLegendre(const int n,int &info,
                                                     double &x[],double &wkronrod[],
                                                     double &wgauss[])
  {
//--- create a variable
   double eps=0;
//--- initialization
   info=0;
//--- check
   if(CMath::m_machineepsilon>1.0E-32 && (((((n==15 || n==21) || n==31) || n==41) || n==51) || n==61))
     {
      info=1;
      GKQLegendreTbl(n,x,wkronrod,wgauss,eps);
     }
   else
      GKQLegendreCalc(n,info,x,wkronrod,wgauss);
  }
//+------------------------------------------------------------------+
//| Returns Gauss and Gauss-Kronrod nodes/weights for Gauss-Jacobi   |
//| quadrature on [-1,1] with weight function                        |
//|     W(x)=Power(1-x,Alpha)*Power(1+x,Beta).                       |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of Kronrod nodes, must be odd number, |
//|                     >=3.                                         |
//|     Alpha       -   power-law coefficient, Alpha>-1              |
//|     Beta        -   power-law coefficient, Beta>-1               |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -5    no real and positive Gauss-Kronrod   |
//|                             formula can be created for such a    |
//|                             weight function with a given number  |
//|                             of nodes.                            |
//|                     * -4    an  error was detected when          |
//|                             calculating weights/nodes. Alpha or  |
//|                             Beta are too close to -1 to obtain   |
//|                             weights/nodes with high enough       |
//|                             accuracy, or, may be, N is too large.|
//|                             Try to use multiple precision version|
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N was passed               |
//|                     * +1    OK                                   |
//|                     * +2    OK, but quadrature rule have exterior|
//|                             nodes, x[0]<-1 or x[n-1]>+1          |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     ordered in ascending order.                  |
//|     WKronrod    -   array[0..N-1] - Kronrod weights              |
//|     WGauss      -   array[0..N-1] - Gauss weights (interleaved   |
//|                     with zeros corresponding to extended Kronrod |
//|                     nodes).                                      |
//+------------------------------------------------------------------+
static void CGaussKronrodQ::GKQGenerateGaussJacobi(const int n,const double alpha,
                                                   const double beta,int &info,
                                                   double &x[],double &wkronrod[],
                                                   double &wgauss[])
  {
//--- create variables
   int clen=0;
   double alpha2=0;
   double beta2=0;
   double apb=0;
   double t=0;
   int    i=0;
   double s=0;
//--- create arrays
   double a[];
   double b[];
//--- initialization
   info=0;
//--- check
   if(n%2!=1 || n<3)
     {
      info=-1;
      return;
     }
//--- check
   if(alpha<=-1.0 || beta<=-1.0)
     {
      info=-1;
      return;
     }
//--- change value
   clen=(int)MathCeil((double)(3*(n/2))/2.0)+1;
//--- allocation
   ArrayResizeAL(a,clen);
   ArrayResizeAL(b,clen);
//--- initialization
   for(i=0;i<=clen-1;i++)
      a[i]=0;
   apb=alpha+beta;
   a[0]=(beta-alpha)/(apb+2);
   t=(apb+1)*MathLog(2)+CGammaFunc::LnGamma(alpha+1,s)+CGammaFunc::LnGamma(beta+1,s)-CGammaFunc::LnGamma(apb+2,s);
//--- check
   if(t>MathLog(CMath::m_maxrealnumber))
     {
      info=-4;
      return;
     }
   b[0]=MathExp(t);
//--- check
   if(clen>1)
     {
      //--- change values
      alpha2=CMath::Sqr(alpha);
      beta2=CMath::Sqr(beta);
      a[1]=(beta2-alpha2)/((apb+2)*(apb+4));
      b[1]=4*(alpha+1)*(beta+1)/((apb+3)*CMath::Sqr(apb+2));
      //--- calculation
      for(i=2;i<=clen-1;i++)
        {
         a[i]=0.25*(beta2-alpha2)/(i*i*(1+0.5*apb/i)*(1+0.5*(apb+2)/i));
         b[i]=0.25*(1+alpha/i)*(1+beta/i)*(1+apb/i)/((1+0.5*(apb+1)/i)*(1+0.5*(apb-1)/i)*CMath::Sqr(1+0.5*apb/i));
        }
     }
//--- function call
   GKQGenerateRec(a,b,b[0],n,info,x,wkronrod,wgauss);
//--- test basic properties to detect errors
   if(info>0)
     {
      //--- check
      if(x[0]<-1.0 || x[n-1]>1.0)
         info=2;
      for(i=0;i<=n-2;i++)
        {
         //--- check
         if(x[i]>=x[i+1])
            info=-4;
        }
     }
  }
//+------------------------------------------------------------------+
//| Returns Gauss and Gauss-Kronrod nodes for quadrature with N      |
//| points.                                                          |
//| Reduction to tridiagonal eigenproblem is used.                   |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of Kronrod nodes, must be odd number, |
//|                     >=3.                                         |
//| OUTPUT PARAMETERS:                                               |
//|     Info        -   error code:                                  |
//|                     * -4    an error was detected when           |
//|                             calculating weights/nodes. N is too  |
//|                             large to obtain weights/nodes with   |
//|                             high enough accuracy.                |
//|                             Try to use multiple precision        |
//|                             version.                             |
//|                     * -3    internal eigenproblem solver hasn't  |
//|                             converged                            |
//|                     * -1    incorrect N was passed               |
//|                     * +1    OK                                   |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     ordered in ascending order.                  |
//|     WKronrod    -   array[0..N-1] - Kronrod weights              |
//|     WGauss      -   array[0..N-1] - Gauss weights (interleaved   |
//|                     with zeros corresponding to extended Kronrod |
//|                     nodes).                                      |
//+------------------------------------------------------------------+
static void CGaussKronrodQ::GKQLegendreCalc(const int n,int &info,double &x[],
                                            double &wkronrod[],double &wgauss[])
  {
//--- create variables
   int    alen=0;
   int    blen=0;
   double mu0=0;
   int    k=0;
   int    i=0;
//--- create arrays
   double alpha[];
   double beta[];
//--- initialization
   info=0;
//--- check
   if(n%2!=1 || n<3)
     {
      info=-1;
      return;
     }
//--- initialization
   mu0=2;
   alen=(int)MathFloor((double)(3*(n/2))/2.0)+1;
   blen=(int)MathCeil((double)(3*(n/2))/2.0)+1;
//--- allocation
   ArrayResizeAL(alpha,alen);
   ArrayResizeAL(beta,blen);
//--- initialization
   for(k=0;k<=alen-1;k++)
      alpha[k]=0;
   beta[0]=2;
   for(k=1;k<=blen-1;k++)
      beta[k]=1/(4-1/CMath::Sqr(k));
//--- function call
   GKQGenerateRec(alpha,beta,mu0,n,info,x,wkronrod,wgauss);
//--- test basic properties to detect errors
   if(info>0)
     {
      //--- check
      if(x[0]<-1.0 || x[n-1]>1.0)
         info=-4;
      for(i=0;i<=n-2;i++)
        {
         //--- check
         if(x[i]>=x[i+1])
            info=-4;
        }
     }
  }
//+------------------------------------------------------------------+
//| Returns Gauss and Gauss-Kronrod nodes for quadrature with N      |
//| points using pre-calculated table. Nodes/weights were computed   |
//| with accuracy up to 1.0E-32 (if MPFR version of ALGLIB is used). |
//| In standard double precision accuracy reduces to something about |
//| 2.0E-16 (depending  on your compiler's handling of long floating |
//| point constants).                                                |
//| INPUT PARAMETERS:                                                |
//|     N           -   number of Kronrod nodes.                     |
//|                     N can be 15, 21, 31, 41, 51, 61.             |
//| OUTPUT PARAMETERS:                                               |
//|     X           -   array[0..N-1] - array of quadrature nodes,   |
//|                     ordered in ascending order.                  |
//|     WKronrod    -   array[0..N-1] - Kronrod weights              |
//|     WGauss      -   array[0..N-1] - Gauss weights (interleaved   |
//|                     with zeros corresponding to extended Kronrod |
//|                     nodes).                                      |
//+------------------------------------------------------------------+
static void CGaussKronrodQ::GKQLegendreTbl(const int n,double &x[],
                                           double &wkronrod[],double &wgauss[],
                                           double &eps)
  {
//--- create variables
   int    i=0;
   int    ng=0;
   double tmp=0;
//--- create arrays
   int p1[];
   int p2[];
//--- initialization
   eps=0;
//--- these initializers are not really necessary,
//--- but without them compiler complains about uninitialized locals
   ng=0;
//--- Process
   if(!CAp::Assert(n==15 || n==21 || n==31 || n==41 || n==51 || n==61,__FUNCTION__+": incorrect N!"))
      return;
//--- allocation
   ArrayResizeAL(x,n);
   ArrayResizeAL(wkronrod,n);
   ArrayResizeAL(wgauss,n);
//--- initialization
   for(i=0;i<=n-1;i++)
     {
      x[i]=0;
      wkronrod[i]=0;
      wgauss[i]=0;
     }
   eps=MathMax(CMath::m_machineepsilon,1.0E-32);
//--- check
   if(n==15)
     {
      //--- change values
      ng=4;
      wgauss[0]=0.129484966168869693270611432679082;
      wgauss[1]=0.279705391489276667901467771423780;
      wgauss[2]=0.381830050505118944950369775488975;
      wgauss[3]=0.417959183673469387755102040816327;
      x[0]=0.991455371120812639206854697526329;
      x[1]=0.949107912342758524526189684047851;
      x[2]=0.864864423359769072789712788640926;
      x[3]=0.741531185599394439863864773280788;
      x[4]=0.586087235467691130294144838258730;
      x[5]=0.405845151377397166906606412076961;
      x[6]=0.207784955007898467600689403773245;
      x[7]=0.000000000000000000000000000000000;
      wkronrod[0]=0.022935322010529224963732008058970;
      wkronrod[1]=0.063092092629978553290700663189204;
      wkronrod[2]=0.104790010322250183839876322541518;
      wkronrod[3]=0.140653259715525918745189590510238;
      wkronrod[4]=0.169004726639267902826583426598550;
      wkronrod[5]=0.190350578064785409913256402421014;
      wkronrod[6]=0.204432940075298892414161999234649;
      wkronrod[7]=0.209482141084727828012999174891714;
     }
//--- check
   if(n==21)
     {
      //--- change values
      ng=5;
      wgauss[0]=0.066671344308688137593568809893332;
      wgauss[1]=0.149451349150580593145776339657697;
      wgauss[2]=0.219086362515982043995534934228163;
      wgauss[3]=0.269266719309996355091226921569469;
      wgauss[4]=0.295524224714752870173892994651338;
      x[0]=0.995657163025808080735527280689003;
      x[1]=0.973906528517171720077964012084452;
      x[2]=0.930157491355708226001207180059508;
      x[3]=0.865063366688984510732096688423493;
      x[4]=0.780817726586416897063717578345042;
      x[5]=0.679409568299024406234327365114874;
      x[6]=0.562757134668604683339000099272694;
      x[7]=0.433395394129247190799265943165784;
      x[8]=0.294392862701460198131126603103866;
      x[9]=0.148874338981631210884826001129720;
      x[10]=0.000000000000000000000000000000000;
      wkronrod[0]=0.011694638867371874278064396062192;
      wkronrod[1]=0.032558162307964727478818972459390;
      wkronrod[2]=0.054755896574351996031381300244580;
      wkronrod[3]=0.075039674810919952767043140916190;
      wkronrod[4]=0.093125454583697605535065465083366;
      wkronrod[5]=0.109387158802297641899210590325805;
      wkronrod[6]=0.123491976262065851077958109831074;
      wkronrod[7]=0.134709217311473325928054001771707;
      wkronrod[8]=0.142775938577060080797094273138717;
      wkronrod[9]=0.147739104901338491374841515972068;
      wkronrod[10]=0.149445554002916905664936468389821;
     }
//--- check
   if(n==31)
     {
      //--- change values
      ng=8;
      wgauss[0]=0.030753241996117268354628393577204;
      wgauss[1]=0.070366047488108124709267416450667;
      wgauss[2]=0.107159220467171935011869546685869;
      wgauss[3]=0.139570677926154314447804794511028;
      wgauss[4]=0.166269205816993933553200860481209;
      wgauss[5]=0.186161000015562211026800561866423;
      wgauss[6]=0.198431485327111576456118326443839;
      wgauss[7]=0.202578241925561272880620199967519;
      x[0]=0.998002298693397060285172840152271;
      x[1]=0.987992518020485428489565718586613;
      x[2]=0.967739075679139134257347978784337;
      x[3]=0.937273392400705904307758947710209;
      x[4]=0.897264532344081900882509656454496;
      x[5]=0.848206583410427216200648320774217;
      x[6]=0.790418501442465932967649294817947;
      x[7]=0.724417731360170047416186054613938;
      x[8]=0.650996741297416970533735895313275;
      x[9]=0.570972172608538847537226737253911;
      x[10]=0.485081863640239680693655740232351;
      x[11]=0.394151347077563369897207370981045;
      x[12]=0.299180007153168812166780024266389;
      x[13]=0.201194093997434522300628303394596;
      x[14]=0.101142066918717499027074231447392;
      x[15]=0.000000000000000000000000000000000;
      wkronrod[0]=0.005377479872923348987792051430128;
      wkronrod[1]=0.015007947329316122538374763075807;
      wkronrod[2]=0.025460847326715320186874001019653;
      wkronrod[3]=0.035346360791375846222037948478360;
      wkronrod[4]=0.044589751324764876608227299373280;
      wkronrod[5]=0.053481524690928087265343147239430;
      wkronrod[6]=0.062009567800670640285139230960803;
      wkronrod[7]=0.069854121318728258709520077099147;
      wkronrod[8]=0.076849680757720378894432777482659;
      wkronrod[9]=0.083080502823133021038289247286104;
      wkronrod[10]=0.088564443056211770647275443693774;
      wkronrod[11]=0.093126598170825321225486872747346;
      wkronrod[12]=0.096642726983623678505179907627589;
      wkronrod[13]=0.099173598721791959332393173484603;
      wkronrod[14]=0.100769845523875595044946662617570;
      wkronrod[15]=0.101330007014791549017374792767493;
     }
//--- check
   if(n==41)
     {
      //--- change values
      ng=10;
      wgauss[0]=0.017614007139152118311861962351853;
      wgauss[1]=0.040601429800386941331039952274932;
      wgauss[2]=0.062672048334109063569506535187042;
      wgauss[3]=0.083276741576704748724758143222046;
      wgauss[4]=0.101930119817240435036750135480350;
      wgauss[5]=0.118194531961518417312377377711382;
      wgauss[6]=0.131688638449176626898494499748163;
      wgauss[7]=0.142096109318382051329298325067165;
      wgauss[8]=0.149172986472603746787828737001969;
      wgauss[9]=0.152753387130725850698084331955098;
      x[0]=0.998859031588277663838315576545863;
      x[1]=0.993128599185094924786122388471320;
      x[2]=0.981507877450250259193342994720217;
      x[3]=0.963971927277913791267666131197277;
      x[4]=0.940822633831754753519982722212443;
      x[5]=0.912234428251325905867752441203298;
      x[6]=0.878276811252281976077442995113078;
      x[7]=0.839116971822218823394529061701521;
      x[8]=0.795041428837551198350638833272788;
      x[9]=0.746331906460150792614305070355642;
      x[10]=0.693237656334751384805490711845932;
      x[11]=0.636053680726515025452836696226286;
      x[12]=0.575140446819710315342946036586425;
      x[13]=0.510867001950827098004364050955251;
      x[14]=0.443593175238725103199992213492640;
      x[15]=0.373706088715419560672548177024927;
      x[16]=0.301627868114913004320555356858592;
      x[17]=0.227785851141645078080496195368575;
      x[18]=0.152605465240922675505220241022678;
      x[19]=0.076526521133497333754640409398838;
      x[20]=0.000000000000000000000000000000000;
      wkronrod[0]=0.003073583718520531501218293246031;
      wkronrod[1]=0.008600269855642942198661787950102;
      wkronrod[2]=0.014626169256971252983787960308868;
      wkronrod[3]=0.020388373461266523598010231432755;
      wkronrod[4]=0.025882133604951158834505067096153;
      wkronrod[5]=0.031287306777032798958543119323801;
      wkronrod[6]=0.036600169758200798030557240707211;
      wkronrod[7]=0.041668873327973686263788305936895;
      wkronrod[8]=0.046434821867497674720231880926108;
      wkronrod[9]=0.050944573923728691932707670050345;
      wkronrod[10]=0.055195105348285994744832372419777;
      wkronrod[11]=0.059111400880639572374967220648594;
      wkronrod[12]=0.062653237554781168025870122174255;
      wkronrod[13]=0.065834597133618422111563556969398;
      wkronrod[14]=0.068648672928521619345623411885368;
      wkronrod[15]=0.071054423553444068305790361723210;
      wkronrod[16]=0.073030690332786667495189417658913;
      wkronrod[17]=0.074582875400499188986581418362488;
      wkronrod[18]=0.075704497684556674659542775376617;
      wkronrod[19]=0.076377867672080736705502835038061;
      wkronrod[20]=0.076600711917999656445049901530102;
     }
//--- check
   if(n==51)
     {
      //--- change values
      ng=13;
      wgauss[0]=0.011393798501026287947902964113235;
      wgauss[1]=0.026354986615032137261901815295299;
      wgauss[2]=0.040939156701306312655623487711646;
      wgauss[3]=0.054904695975835191925936891540473;
      wgauss[4]=0.068038333812356917207187185656708;
      wgauss[5]=0.080140700335001018013234959669111;
      wgauss[6]=0.091028261982963649811497220702892;
      wgauss[7]=0.100535949067050644202206890392686;
      wgauss[8]=0.108519624474263653116093957050117;
      wgauss[9]=0.114858259145711648339325545869556;
      wgauss[10]=0.119455763535784772228178126512901;
      wgauss[11]=0.122242442990310041688959518945852;
      wgauss[12]=0.123176053726715451203902873079050;
      x[0]=0.999262104992609834193457486540341;
      x[1]=0.995556969790498097908784946893902;
      x[2]=0.988035794534077247637331014577406;
      x[3]=0.976663921459517511498315386479594;
      x[4]=0.961614986425842512418130033660167;
      x[5]=0.942974571228974339414011169658471;
      x[6]=0.920747115281701561746346084546331;
      x[7]=0.894991997878275368851042006782805;
      x[8]=0.865847065293275595448996969588340;
      x[9]=0.833442628760834001421021108693570;
      x[10]=0.797873797998500059410410904994307;
      x[11]=0.759259263037357630577282865204361;
      x[12]=0.717766406813084388186654079773298;
      x[13]=0.673566368473468364485120633247622;
      x[14]=0.626810099010317412788122681624518;
      x[15]=0.577662930241222967723689841612654;
      x[16]=0.526325284334719182599623778158010;
      x[17]=0.473002731445714960522182115009192;
      x[18]=0.417885382193037748851814394594572;
      x[19]=0.361172305809387837735821730127641;
      x[20]=0.303089538931107830167478909980339;
      x[21]=0.243866883720988432045190362797452;
      x[22]=0.183718939421048892015969888759528;
      x[23]=0.122864692610710396387359818808037;
      x[24]=0.061544483005685078886546392366797;
      x[25]=0.000000000000000000000000000000000;
      wkronrod[0]=0.001987383892330315926507851882843;
      wkronrod[1]=0.005561932135356713758040236901066;
      wkronrod[2]=0.009473973386174151607207710523655;
      wkronrod[3]=0.013236229195571674813656405846976;
      wkronrod[4]=0.016847817709128298231516667536336;
      wkronrod[5]=0.020435371145882835456568292235939;
      wkronrod[6]=0.024009945606953216220092489164881;
      wkronrod[7]=0.027475317587851737802948455517811;
      wkronrod[8]=0.030792300167387488891109020215229;
      wkronrod[9]=0.034002130274329337836748795229551;
      wkronrod[10]=0.037116271483415543560330625367620;
      wkronrod[11]=0.040083825504032382074839284467076;
      wkronrod[12]=0.042872845020170049476895792439495;
      wkronrod[13]=0.045502913049921788909870584752660;
      wkronrod[14]=0.047982537138836713906392255756915;
      wkronrod[15]=0.050277679080715671963325259433440;
      wkronrod[16]=0.052362885806407475864366712137873;
      wkronrod[17]=0.054251129888545490144543370459876;
      wkronrod[18]=0.055950811220412317308240686382747;
      wkronrod[19]=0.057437116361567832853582693939506;
      wkronrod[20]=0.058689680022394207961974175856788;
      wkronrod[21]=0.059720340324174059979099291932562;
      wkronrod[22]=0.060539455376045862945360267517565;
      wkronrod[23]=0.061128509717053048305859030416293;
      wkronrod[24]=0.061471189871425316661544131965264;
      wkronrod[25]=0.061580818067832935078759824240055;
     }
//--- check
   if(n==61)
     {
      //--- change values
      ng=15;
      wgauss[0]=0.007968192496166605615465883474674;
      wgauss[1]=0.018466468311090959142302131912047;
      wgauss[2]=0.028784707883323369349719179611292;
      wgauss[3]=0.038799192569627049596801936446348;
      wgauss[4]=0.048402672830594052902938140422808;
      wgauss[5]=0.057493156217619066481721689402056;
      wgauss[6]=0.065974229882180495128128515115962;
      wgauss[7]=0.073755974737705206268243850022191;
      wgauss[8]=0.080755895229420215354694938460530;
      wgauss[9]=0.086899787201082979802387530715126;
      wgauss[10]=0.092122522237786128717632707087619;
      wgauss[11]=0.096368737174644259639468626351810;
      wgauss[12]=0.099593420586795267062780282103569;
      wgauss[13]=0.101762389748405504596428952168554;
      wgauss[14]=0.102852652893558840341285636705415;
      x[0]=0.999484410050490637571325895705811;
      x[1]=0.996893484074649540271630050918695;
      x[2]=0.991630996870404594858628366109486;
      x[3]=0.983668123279747209970032581605663;
      x[4]=0.973116322501126268374693868423707;
      x[5]=0.960021864968307512216871025581798;
      x[6]=0.944374444748559979415831324037439;
      x[7]=0.926200047429274325879324277080474;
      x[8]=0.905573307699907798546522558925958;
      x[9]=0.882560535792052681543116462530226;
      x[10]=0.857205233546061098958658510658944;
      x[11]=0.829565762382768397442898119732502;
      x[12]=0.799727835821839083013668942322683;
      x[13]=0.767777432104826194917977340974503;
      x[14]=0.733790062453226804726171131369528;
      x[15]=0.697850494793315796932292388026640;
      x[16]=0.660061064126626961370053668149271;
      x[17]=0.620526182989242861140477556431189;
      x[18]=0.579345235826361691756024932172540;
      x[19]=0.536624148142019899264169793311073;
      x[20]=0.492480467861778574993693061207709;
      x[21]=0.447033769538089176780609900322854;
      x[22]=0.400401254830394392535476211542661;
      x[23]=0.352704725530878113471037207089374;
      x[24]=0.304073202273625077372677107199257;
      x[25]=0.254636926167889846439805129817805;
      x[26]=0.204525116682309891438957671002025;
      x[27]=0.153869913608583546963794672743256;
      x[28]=0.102806937966737030147096751318001;
      x[29]=0.051471842555317695833025213166723;
      x[30]=0.000000000000000000000000000000000;
      wkronrod[0]=0.001389013698677007624551591226760;
      wkronrod[1]=0.003890461127099884051267201844516;
      wkronrod[2]=0.006630703915931292173319826369750;
      wkronrod[3]=0.009273279659517763428441146892024;
      wkronrod[4]=0.011823015253496341742232898853251;
      wkronrod[5]=0.014369729507045804812451432443580;
      wkronrod[6]=0.016920889189053272627572289420322;
      wkronrod[7]=0.019414141193942381173408951050128;
      wkronrod[8]=0.021828035821609192297167485738339;
      wkronrod[9]=0.024191162078080601365686370725232;
      wkronrod[10]=0.026509954882333101610601709335075;
      wkronrod[11]=0.028754048765041292843978785354334;
      wkronrod[12]=0.030907257562387762472884252943092;
      wkronrod[13]=0.032981447057483726031814191016854;
      wkronrod[14]=0.034979338028060024137499670731468;
      wkronrod[15]=0.036882364651821229223911065617136;
      wkronrod[16]=0.038678945624727592950348651532281;
      wkronrod[17]=0.040374538951535959111995279752468;
      wkronrod[18]=0.041969810215164246147147541285970;
      wkronrod[19]=0.043452539701356069316831728117073;
      wkronrod[20]=0.044814800133162663192355551616723;
      wkronrod[21]=0.046059238271006988116271735559374;
      wkronrod[22]=0.047185546569299153945261478181099;
      wkronrod[23]=0.048185861757087129140779492298305;
      wkronrod[24]=0.049055434555029778887528165367238;
      wkronrod[25]=0.049795683427074206357811569379942;
      wkronrod[26]=0.050405921402782346840893085653585;
      wkronrod[27]=0.050881795898749606492297473049805;
      wkronrod[28]=0.051221547849258772170656282604944;
      wkronrod[29]=0.051426128537459025933862879215781;
      wkronrod[30]=0.051494729429451567558340433647099;
     }
//--- copy nodes
   for(i=n-1;i>=n/2;i--)
      x[i]=-x[n-1-i];
//--- copy Kronrod weights
   for(i=n-1;i>=n/2;i--)
      wkronrod[i]=wkronrod[n-1-i];
//--- copy Gauss weights
   for(i=ng-1;i>=0;i--)
     {
      wgauss[n-2-2*i]=wgauss[i];
      wgauss[1+2*i]=wgauss[i];
     }
   for(i=0;i<=n/2;i++)
      wgauss[2*i]=0;
//--- reorder
   CTSort::TagSort(x,n,p1,p2);
   for(i=0;i<=n-1;i++)
     {
      //--- swap
      tmp=wkronrod[i];
      wkronrod[i]=wkronrod[p2[i]];
      wkronrod[p2[i]]=tmp;
      tmp=wgauss[i];
      wgauss[i]=wgauss[p2[i]];
      wgauss[p2[i]]=tmp;
     }
  }
//+------------------------------------------------------------------+
//| Integration report:                                              |
//| * TerminationType = completetion code:                           |
//|     * -5    non-convergence of Gauss-Kronrod nodes               |
//|             calculation subroutine.                              |
//|     * -1    incorrect parameters were specified                  |
//|     *  1    OK                                                   |
//| * Rep.NFEV countains number of function calculations             |
//| * Rep.NIntervals contains number of intervals [a,b]              |
//|   was partitioned into.                                          |
//+------------------------------------------------------------------+
class CAutoGKReport
  {
public:
   //--- variables
   int               m_terminationtype;
   int               m_nfev;
   int               m_nintervals;
   //--- constructor, destructor
                     CAutoGKReport(void);
                    ~CAutoGKReport(void);
   //--- copy
   void              Copy(CAutoGKReport &obj);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CAutoGKReport::CAutoGKReport(void)
  {

  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAutoGKReport::~CAutoGKReport(void)
  {

  }
//+------------------------------------------------------------------+
//| Copy                                                             |
//+------------------------------------------------------------------+
void CAutoGKReport::Copy(CAutoGKReport &obj)
  {
//--- copy variables
   m_terminationtype=obj.m_terminationtype;
   m_nfev=obj.m_nfev;
   m_nintervals=obj.m_nintervals;
  }
//+------------------------------------------------------------------+
//| Integration report:                                              |
//| * TerminationType = completetion code:                           |
//|     * -5    non-convergence of Gauss-Kronrod nodes               |
//|             calculation subroutine.                              |
//|     * -1    incorrect parameters were specified                  |
//|     *  1    OK                                                   |
//| * Rep.NFEV countains number of function calculations             |
//| * Rep.NIntervals contains number of intervals [a,b]              |
//|   was partitioned into.                                          |
//+------------------------------------------------------------------+
class CAutoGKReportShell
  {
private:
   CAutoGKReport     m_innerobj;
public:
   //--- constructors, destructor
                     CAutoGKReportShell(void);
                     CAutoGKReportShell(CAutoGKReport &obj);
                    ~CAutoGKReportShell(void);
   //--- methods
   int               GetTerminationType(void);
   void              SetTerminationType(const int i);
   int               GetNFev(void);
   void              SetNFev(const int i);
   int               GetNIntervals(void);
   void              SetNIntervals(const int i);
   CAutoGKReport    *GetInnerObj(void);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CAutoGKReportShell::CAutoGKReportShell(void)
  {

  }
//+------------------------------------------------------------------+
//| Copy constructor                                                 |
//+------------------------------------------------------------------+
CAutoGKReportShell::CAutoGKReportShell(CAutoGKReport &obj)
  {
//--- copy
   m_innerobj.Copy(obj);
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAutoGKReportShell::~CAutoGKReportShell(void)
  {

  }
//+------------------------------------------------------------------+
//| Returns the value of the variable nfev                           |
//+------------------------------------------------------------------+
int CAutoGKReportShell::GetNFev(void)
  {
//--- return result
   return(m_innerobj.m_nfev);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable nfev                          |
//+------------------------------------------------------------------+
void CAutoGKReportShell::SetNFev(const int i)
  {
//--- change value
   m_innerobj.m_nfev=i;
  }
//+------------------------------------------------------------------+
//| Returns the value of the variable terminationtype                |
//+------------------------------------------------------------------+
int CAutoGKReportShell::GetTerminationType(void)
  {
//--- return result
   return(m_innerobj.m_terminationtype);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable terminationtype               |
//+------------------------------------------------------------------+
void CAutoGKReportShell::SetTerminationType(const int i)
  {
//--- change value
   m_innerobj.m_terminationtype=i;
  }
//+------------------------------------------------------------------+
//| Returns the value of the variable nintervals                     |
//+------------------------------------------------------------------+
int CAutoGKReportShell::GetNIntervals(void)
  {
//--- return result
   return(m_innerobj.m_nintervals);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable nintervals                    |
//+------------------------------------------------------------------+
void CAutoGKReportShell::SetNIntervals(const int i)
  {
//--- change value
   m_innerobj.m_nintervals=i;
  }
//+------------------------------------------------------------------+
//| Return object of class                                           |
//+------------------------------------------------------------------+
CAutoGKReport *CAutoGKReportShell::GetInnerObj(void)
  {
//--- return result
   return(GetPointer(m_innerobj));
  }
//+------------------------------------------------------------------+
//| Auxiliary class for CAutoGK                                      |
//+------------------------------------------------------------------+
class CAutoGKInternalState
  {
public:
   //--- variables
   double            m_a;
   double            m_b;
   double            m_eps;
   double            m_xwidth;
   double            m_x;
   double            m_f;
   int               m_info;
   double            m_r;
   int               m_heapsize;
   int               m_heapwidth;
   int               m_heapused;
   double            m_sumerr;
   double            m_sumabs;
   int               m_n;
   RCommState        m_rstate;
   //--- arrays
   double            m_qn[];
   double            m_wg[];
   double            m_wk[];
   double            m_wr[];
   //--- matrix
   CMatrixDouble     m_heap;
   //--- constructor, destructor
                     CAutoGKInternalState(void);
                    ~CAutoGKInternalState(void);
   //--- copy
   void              Copy(CAutoGKInternalState &obj);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CAutoGKInternalState::CAutoGKInternalState(void)
  {

  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAutoGKInternalState::~CAutoGKInternalState(void)
  {

  }
//+------------------------------------------------------------------+
//| Copy                                                             |
//+------------------------------------------------------------------+
void CAutoGKInternalState::Copy(CAutoGKInternalState &obj)
  {
//--- copy variables
   m_a=obj.m_a;
   m_b=obj.m_b;
   m_eps=obj.m_eps;
   m_xwidth=obj.m_xwidth;
   m_x=obj.m_x;
   m_f=obj.m_f;
   m_info=obj.m_info;
   m_r=obj.m_r;
   m_heapsize=obj.m_heapsize;
   m_heapwidth=obj.m_heapwidth;
   m_heapused=obj.m_heapused;
   m_sumerr=obj.m_sumerr;
   m_sumabs=obj.m_sumabs;
   m_n=obj.m_n;
   m_rstate.Copy(obj.m_rstate);
//--- copy arrays
   ArrayCopy(m_qn,obj.m_qn);
   ArrayCopy(m_wg,obj.m_wg);
   ArrayCopy(m_wk,obj.m_wk);
   ArrayCopy(m_wr,obj.m_wr);
//--- copy matrix
   m_heap=obj.m_heap;
  }
//+------------------------------------------------------------------+
//| This structure stores state of the integration algorithm.        |
//| Although this class has public fields,  they are not intended for| 
//| external use. You should use ALGLIB functions to work with this  |
//| class:                                                           |
//| * autogksmooth()/AutoGKSmoothW()/... to create objects           |
//| * autogkintegrate() to begin integration                         |
//| * autogkresults() to get results                                 |
//+------------------------------------------------------------------+
class CAutoGKState
  {
public:
   //--- variables
   double            m_a;
   double            m_b;
   double            m_alpha;
   double            m_beta;
   double            m_xwidth;
   double            m_x;
   double            m_xminusa;
   double            m_bminusx;
   bool              m_needf;
   double            m_f;
   int               m_wrappermode;
   double            m_v;
   int               m_terminationtype;
   int               m_nfev;
   int               m_nintervals;
   CAutoGKInternalState m_internalstate;
   RCommState        m_rstate;
   //--- constructor, destructor
                     CAutoGKState(void);
                    ~CAutoGKState(void);
   //--- copy
   void              Copy(CAutoGKState &obj);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CAutoGKState::CAutoGKState(void)
  {

  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAutoGKState::~CAutoGKState(void)
  {

  }
//+------------------------------------------------------------------+
//| Copy                                                             |
//+------------------------------------------------------------------+
CAutoGKState::Copy(CAutoGKState &obj)
  {
//--- copy variables
   m_a=obj.m_a;
   m_b=obj.m_b;
   m_alpha=obj.m_alpha;
   m_beta=obj.m_beta;
   m_xwidth=obj.m_xwidth;
   m_x=obj.m_x;
   m_xminusa=obj.m_xminusa;
   m_bminusx=obj.m_bminusx;
   m_needf=obj.m_needf;
   m_f=obj.m_f;
   m_wrappermode=obj.m_wrappermode;
   m_v=obj.m_v;
   m_terminationtype=obj.m_terminationtype;
   m_nfev=obj.m_nfev;
   m_nintervals=obj.m_nintervals;
   m_internalstate.Copy(obj.m_internalstate);
   m_rstate.Copy(obj.m_rstate);
  }
//+------------------------------------------------------------------+
//| This structure stores state of the integration algorithm.        |
//| Although this class has public fields,  they are not intended for| 
//| external use. You should use ALGLIB functions to work with this  |
//| class:                                                           |
//| * autogksmooth()/AutoGKSmoothW()/... to create objects           |
//| * autogkintegrate() to begin integration                         |
//| * autogkresults() to get results                                 |
//+------------------------------------------------------------------+
class CAutoGKStateShell
  {
private:
   CAutoGKState      m_innerobj;
public:
   //--- constructors, destructor
                     CAutoGKStateShell(void);
                     CAutoGKStateShell(CAutoGKState &obj);
                    ~CAutoGKStateShell(void);
   //--- methods
   bool              GetNeedF(void);
   void              SetNeedF(const bool b);
   double            GetX(void);
   void              SetX(const double d);
   double            GetXMinusA(void);
   void              SetXMinusA(const double d);
   double            GetBMinusX(void);
   void              SetBMinusX(const double d);
   double            GetF(void);
   void              SetF(const double d);
   CAutoGKState     *GetInnerObj(void);
  };
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CAutoGKStateShell::CAutoGKStateShell(void)
  {

  }
//+------------------------------------------------------------------+
//| Copy constructor                                                 |
//+------------------------------------------------------------------+
CAutoGKStateShell::CAutoGKStateShell(CAutoGKState &obj)
  {
   m_innerobj.Copy(obj);
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAutoGKStateShell::~CAutoGKStateShell(void)
  {

  }
//+------------------------------------------------------------------+
//| Returns the value of the variable needf                          |
//+------------------------------------------------------------------+
bool CAutoGKStateShell::GetNeedF(void)
  {
//--- return result
   return(m_innerobj.m_needf);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable needf                         |
//+------------------------------------------------------------------+
void CAutoGKStateShell::SetNeedF(const bool b)
  {
//--- change value
   m_innerobj.m_needf=b;
  }
//+------------------------------------------------------------------+
//| Returns the value of the variable x                              |
//+------------------------------------------------------------------+
double CAutoGKStateShell::GetX(void)
  {
//--- return result
   return(m_innerobj.m_x);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable x                             |
//+------------------------------------------------------------------+
void CAutoGKStateShell::SetX(const double d)
  {
//--- change value
   m_innerobj.m_x=d;
  }
//+------------------------------------------------------------------+
//| Returns the value of the variable xminusa                        |
//+------------------------------------------------------------------+
double CAutoGKStateShell::GetXMinusA(void)
  {
//--- return result
   return(m_innerobj.m_xminusa);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable xminusa                       |
//+------------------------------------------------------------------+
void CAutoGKStateShell::SetXMinusA(const double d)
  {
//--- change value
   m_innerobj.m_xminusa=d;
  }
//+------------------------------------------------------------------+
//| Returns the value of the variable bminusx                        |
//+------------------------------------------------------------------+
double CAutoGKStateShell::GetBMinusX(void)
  {
//--- return result
   return(m_innerobj.m_bminusx);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable bminusx                       |
//+------------------------------------------------------------------+
void CAutoGKStateShell::SetBMinusX(const double d)
  {
//--- change value
   m_innerobj.m_bminusx=d;
  }
//+------------------------------------------------------------------+
//| Returns the value of the variable f                              |
//+------------------------------------------------------------------+
double CAutoGKStateShell::GetF(void)
  {
//--- return result
   return(m_innerobj.m_f);
  }
//+------------------------------------------------------------------+
//| Changing the value of the variable f                             |
//+------------------------------------------------------------------+
void CAutoGKStateShell::SetF(const double d)
  {
//--- change value
   m_innerobj.m_f=d;
  }
//+------------------------------------------------------------------+
//| Return object of class                                           |
//+------------------------------------------------------------------+
CAutoGKState *CAutoGKStateShell::GetInnerObj(void)
  {
//--- return result
   return(GetPointer(m_innerobj));
  }
//+------------------------------------------------------------------+
//| Auto Gauss-Kronrod                                               |
//+------------------------------------------------------------------+
class CAutoGK
  {
private:
   //--- private methods
   static void       AutoGKInternalPrepare(const double a,const double b,const double eps,const double xwidth,CAutoGKInternalState &state);
   static void       MHeapPop(CMatrixDouble &heap,const int heapsize,const int heapwidth);
   static void       MHeapPush(CMatrixDouble &heap,const int heapsize,const int heapwidth);
   static void       MHeapResize(CMatrixDouble &heap,int &heapsize,const int newheapsize,const int heapwidth);
   static bool       AutoGKInternalIteration(CAutoGKInternalState &state);
   //--- auxiliary functions for AutoGKInternalIteration
   static void       Func_Internal_lbl_rcomm(CAutoGKInternalState &state,int i,int j,int ns,int info,double c1,double c2,double intg,double intk,double inta,double v,double ta,double tb,double qeps);
   static bool       Func_Internal_lbl_5(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   static bool       Func_Internal_lbl_7(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   static bool       Func_Internal_lbl_8(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   static bool       Func_Internal_lbl_11(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   static bool       Func_Internal_lbl_14(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   static bool       Func_Internal_lbl_16(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   static bool       Func_Internal_lbl_19(CAutoGKInternalState &state,int &i,int &j,int &ns,int &info,double &c1,double &c2,double &intg,double &intk,double &inta,double &v,double &ta,double &tb,double &qeps);
   //--- auxiliary functions for AutoGKIteration
   static void       Func_lbl_rcomm(CAutoGKState &state,double s,double tmp,double eps,double a,double b,double x,double t,double alpha,double beta,double v1,double v2);
   static bool       Func_lbl_5(CAutoGKState &state,double &s,double &tmp,double &eps,double &a,double &b,double &x,double &t,double &alpha,double &beta,double &v1,double &v2);
   static bool       Func_lbl_9(CAutoGKState &state,double &s,double &tmp,double &eps,double &a,double &b,double &x,double &t,double &alpha,double &beta,double &v1,double &v2);
   static bool       Func_lbl_11(CAutoGKState &state,double &s,double &tmp,double &eps,double &a,double &b,double &x,double &t,double &alpha,double &beta,double &v1,double &v2);
public:
   //--- class constant
   static const int  m_maxsubintervals;
   //--- constructor, destructor
                     CAutoGK(void);
                    ~CAutoGK(void);
   //--- public methods
   static void       AutoGKSmooth(const double a,const double b,CAutoGKState &state);
   static void       AutoGKSmoothW(const double a,const double b,const double xwidth,CAutoGKState &state);
   static void       AutoGKSingular(const double a,const double b,const double alpha,const double beta,CAutoGKState &state);
   static void       AutoGKResults(CAutoGKState &state,double &v,CAutoGKReport &rep);
   static bool       AutoGKIteration(CAutoGKState &state);
  };
//+------------------------------------------------------------------+
//| Initialize constant                                              |
//+------------------------------------------------------------------+
const int CAutoGK::m_maxsubintervals=10000;
//+------------------------------------------------------------------+
//| Constructor without parameters                                   |
//+------------------------------------------------------------------+
CAutoGK::CAutoGK(void)
  {

  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAutoGK::~CAutoGK(void)
  {

  }
//+------------------------------------------------------------------+
//| Integration of a smooth function F(x) on a finite interval [a,b].|
//| Fast-convergent algorithm based on a Gauss-Kronrod formula is    |
//| used. Result is calculated with accuracy close to the machine    |
//| precision.                                                       |
//| Algorithm works well only with smooth integrands. It may be used |
//| with continuous non-smooth integrands, but with less performance.|
//| It should never be used with integrands which have integrable    |
//| singularities at lower or upper limits - algorithm may crash.    |
//| Use AutoGKSingular in such cases.                                |
//| INPUT PARAMETERS:                                                |
//|     A, B    -   interval boundaries (A<B, A=B or A>B)            |
//| OUTPUT PARAMETERS                                                |
//|     State   -   structure which stores algorithm state           |
//| SEE ALSO                                                         |
//|     AutoGKSmoothW, AutoGKSingular, AutoGKResults.                |
//+------------------------------------------------------------------+
static void CAutoGK::AutoGKSmooth(const double a,const double b,
                                  CAutoGKState &state)
  {
//--- check
   if(!CAp::Assert(CMath::IsFinite(a),__FUNCTION__+": A is not finite!"))
      return;
//--- check
   if(!CAp::Assert(CMath::IsFinite(b),__FUNCTION__+": B is not finite!"))
      return;
//--- function call
   AutoGKSmoothW(a,b,0.0,state);
  }
//+------------------------------------------------------------------+
//| Integration of a smooth function F(x) on a finite interval [a,b].|
//| This subroutine is same as AutoGKSmooth(), but it guarantees that|
//| interval [a,b] is partitioned into subintervals which have width |
//| at most XWidth.                                                  |
//| Subroutine can be used when integrating nearly-constant function |
//| with narrow "bumps" (about XWidth wide). If "bumps" are too      |
//| narrow, AutoGKSmooth subroutine can overlook them.               |
//| INPUT PARAMETERS:                                                |
//|     A, B    -   interval boundaries (A<B, A=B or A>B)            |
//| OUTPUT PARAMETERS                                                |
//|     State   -   structure which stores algorithm state           |
//| SEE ALSO                                                         |
//|     AutoGKSmooth, AutoGKSingular, AutoGKResults.                 |
//+------------------------------------------------------------------+
static void CAutoGK::AutoGKSmoothW(const double a,const double b,
                                   const double xwidth,CAutoGKState &state)
  {
//--- check
   if(!CAp::Assert(CMath::IsFinite(a),__FUNCTION__+": A is not finite!"))
      return;
//--- check
   if(!CAp::Assert(CMath::IsFinite(b),__FUNCTION__+": B is not finite!"))
      return;
//--- check
   if(!CAp::Assert(CMath::IsFinite(xwidth),__FUNCTION__+": XWidth is not finite!"))
      return;
//--- initialization
   state.m_wrappermode=0;
   state.m_a=a;
   state.m_b=b;
   state.m_xwidth=xwidth;
   state.m_needf=false;
//--- allocation
   ArrayResizeAL(state.m_rstate.ra,11);
   state.m_rstate.stage=-1;
  }
//+------------------------------------------------------------------+
//| Integration on a finite interval [A,B].                          |
//| Integrand have integrable singularities at A/B.                  |
//| F(X) must diverge as "(x-A)^alpha" at A, as "(B-x)^beta" at B,   |
//| with known alpha/beta (alpha>-1, beta>-1). If alpha/beta are not |
//| known, estimates from below can be used (but these estimates     |
//| should be greater than -1 too).                                  |
//| One of alpha/beta variables (or even both alpha/beta) may be     |
//| equal to 0, which means than function F(x) is non-singular at    |
//| A/B. Anyway (singular at bounds or not), function F(x) is        |
//| supposed to be continuous on (A,B).                              |
//| Fast-convergent algorithm based on a Gauss-Kronrod formula is    |
//| used. Result is calculated with accuracy close to the machine    |
//| precision.                                                       |
//| INPUT PARAMETERS:                                                |
//|     A, B    -   interval boundaries (A<B, A=B or A>B)            |
//|     Alpha   -   power-law coefficient of the F(x) at A,          |
//|                 Alpha>-1                                         |
//|     Beta    -   power-law coefficient of the F(x) at B,          |
//|                 Beta>-1                                          |
//| OUTPUT PARAMETERS                                                |
//|     State   -   structure which stores algorithm state           |
//| SEE ALSO                                                         |
//|     AutoGKSmooth, AutoGKSmoothW, AutoGKResults.                  |
//+------------------------------------------------------------------+
static void CAutoGK::AutoGKSingular(const double a,const double b,
                                    const double alpha,const double beta,
                                    CAutoGKState &state)
  {
//--- check
   if(!CAp::Assert(CMath::IsFinite(a),__FUNCTION__+": A is not finite!"))
      return;
//--- check
   if(!CAp::Assert(CMath::IsFinite(b),__FUNCTION__+": B is not finite!"))
      return;
//--- check
   if(!CAp::Assert(CMath::IsFinite(alpha),__FUNCTION__+": Alpha is not finite!"))
      return;
//--- check
   if(!CAp::Assert(CMath::IsFinite(beta),__FUNCTION__+": Beta is not finite!"))
      return;
//--- initialization
   state.m_wrappermode=1;
   state.m_a=a;
   state.m_b=b;
   state.m_alpha=alpha;
   state.m_beta=beta;
   state.m_xwidth=0.0;
   state.m_needf=false;
//--- allocation
   ArrayResizeAL(state.m_rstate.ra,11);
   state.m_rstate.stage=-1;
  }
//+------------------------------------------------------------------+
//| Adaptive integration results                                     |
//| Called after AutoGKIteration returned False.                     |
//| Input parameters:                                                |
//|     State   -   algorithm state (used by AutoGKIteration).       |
//| Output parameters:                                               |
//|     V       -   integral(f(x)dx,a,b)                             |
//|     Rep     -   optimization report (see AutoGKReport            |
//|                 description)                                     |
//+------------------------------------------------------------------+
static void CAutoGK::AutoGKResults(CAutoGKState &state,double &v,CAutoGKReport &rep)
  {
//--- change values
   v=state.m_v;
   rep.m_terminationtype=state.m_terminationtype;
   rep.m_nfev=state.m_nfev;
   rep.m_nintervals=state.m_nintervals;
  }
//+------------------------------------------------------------------+
//| Internal AutoGK subroutine                                       |
//| eps<0   - error                                                  |
//| eps=0   - automatic eps selection                                |
//| width<0 -   error                                                |
//| width=0 -   no width requirements                                |
//+------------------------------------------------------------------+
static void CAutoGK::AutoGKInternalPrepare(const double a,const double b,
                                           const double eps,const double xwidth,
                                           CAutoGKInternalState &state)
  {
//--- Save settings
   state.m_a=a;
   state.m_b=b;
   state.m_eps=eps;
   state.m_xwidth=xwidth;
//--- Prepare RComm structure
   ArrayResizeAL(state.m_rstate.ia,4);
   ArrayResizeAL(state.m_rstate.ra,9);
   state.m_rstate.stage=-1;
  }
//+------------------------------------------------------------------+
//| Internal subroutine                                              |
//+------------------------------------------------------------------+
static void CAutoGK::MHeapPop(CMatrixDouble &heap,const int heapsize,
                              const int heapwidth)
  {
//--- create variables
   int    i=0;
   int    p=0;
   double t=0;
   int    maxcp=0;
//--- check
   if(heapsize==1)
      return;
//--- initialization
   for(i=0;i<=heapwidth-1;i++)
     {
      t=heap[heapsize-1][i];
      heap[heapsize-1].Set(i,heap[0][i]);
      heap[0].Set(i,t);
     }
   p=0;
//--- cycle
   while(2*p+1<heapsize-1)
     {
      maxcp=2*p+1;
      //--- check
      if(2*p+2<heapsize-1)
        {
         //--- check
         if(heap[2*p+2][0]>heap[2*p+1][0])
            maxcp=2*p+2;
        }
      //--- check
      if(heap[p][0]<heap[maxcp][0])
        {
         for(i=0;i<=heapwidth-1;i++)
           {
            //--- change values
            t=heap[p][i];
            heap[p].Set(i,heap[maxcp][i]);
            heap[maxcp].Set(i,t);
           }
         p=maxcp;
        }
      else
         break;
     }
  }
//+------------------------------------------------------------------+
//| Internal subroutine                                              |
//+------------------------------------------------------------------+
static void CAutoGK::MHeapPush(CMatrixDouble &heap,const int heapsize,
                               const int heapwidth)
  {
//--- create variables
   int    i=0;
   int    p=0;
   double t=0;
   int    parent=0;
//--- check
   if(heapsize==0)
      return;
   p=heapsize;
//--- cycle
   while(p!=0)
     {
      parent=(p-1)/2;
      //--- check
      if(heap[p][0]>heap[parent][0])
        {
         for(i=0;i<=heapwidth-1;i++)
           {
            //--- change values
            t=heap[p][i];
            heap[p].Set(i,heap[parent][i]);
            heap[parent].Set(i,t);
           }
         p=parent;
        }
      else
         break;
     }
  }
//+------------------------------------------------------------------+
//| Internal subroutine                                              |
//+------------------------------------------------------------------+
static void CAutoGK::MHeapResize(CMatrixDouble &heap,int &heapsize,
                                 const int newheapsize,const int heapwidth)
  {
//--- create variables
   int i=0;
   int i_=0;
//--- create matrix
   CMatrixDouble tmp;
//--- allocation
   tmp.Resize(heapsize,heapwidth);
//--- copy
   for(i=0;i<=heapsize-1;i++)
     {
      for(i_=0;i_<=heapwidth-1;i_++)
         tmp[i].Set(i_,heap[i][i_]);
     }
//--- allocation
   heap.Resize(newheapsize,heapwidth);
//--- copy
   for(i=0;i<=heapsize-1;i++)
     {
      for(i_=0;i_<=heapwidth-1;i_++)
         heap[i].Set(i_,tmp[i][i_]);
     }
//--- change value
   heapsize=newheapsize;
  }
//+------------------------------------------------------------------+
//| Internal AutoGK subroutine                                       |
//+------------------------------------------------------------------+
static bool CAutoGK::AutoGKInternalIteration(CAutoGKInternalState &state)
  {
//--- create variables
   double c1=0;
   double c2=0;
   int    i=0;
   int    j=0;
   double intg=0;
   double intk=0;
   double inta=0;
   double v=0;
   double ta=0;
   double tb=0;
   int    ns=0;
   double qeps=0;
   int    info=0;
//--- This code initializes locals by:
//--- * random values determined during code
//---   generation - on first subroutine call
//--- * values from previous call - on subsequent calls
   if(state.m_rstate.stage>=0)
     {
      //--- initialization
      i=state.m_rstate.ia[0];
      j=state.m_rstate.ia[1];
      ns=state.m_rstate.ia[2];
      info=state.m_rstate.ia[3];
      c1=state.m_rstate.ra[0];
      c2=state.m_rstate.ra[1];
      intg=state.m_rstate.ra[2];
      intk=state.m_rstate.ra[3];
      inta=state.m_rstate.ra[4];
      v=state.m_rstate.ra[5];
      ta=state.m_rstate.ra[6];
      tb=state.m_rstate.ra[7];
      qeps=state.m_rstate.ra[8];
     }
   else
     {
      //--- initialization
      i=497;
      j=-271;
      ns=-581;
      info=745;
      c1=-533;
      c2=-77;
      intg=678;
      intk=-293;
      inta=316;
      v=647;
      ta=-756;
      tb=830;
      qeps=-871;
     }
//--- check
   if(state.m_rstate.stage==0)
     {
      //--- change value
      v=state.m_f;
      //--- Gauss-Kronrod formula
      intk=intk+v*state.m_wk[i];
      //--- check
      if(i%2==1)
         intg=intg+v*state.m_wg[i];
      //--- Integral |F(x)|
      //--- Use rectangles method
      inta=inta+MathAbs(v)*state.m_wr[i];
      i=i+1;
      //--- function call, возврат результата
      return(Func_Internal_lbl_5(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- check
   if(state.m_rstate.stage==1)
     {
      //--- change value
      v=state.m_f;
      //--- Gauss-Kronrod formula
      intk=intk+v*state.m_wk[i];
      //--- check
      if(i%2==1)
         intg=intg+v*state.m_wg[i];
      //--- Integral |F(x)|
      //--- Use rectangles method
      inta=inta+MathAbs(v)*state.m_wr[i];
      i=i+1;
      //--- function call, возврат результата
      return(Func_Internal_lbl_11(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- check
   if(state.m_rstate.stage==2)
     {
      //--- change value
      v=state.m_f;
      //--- Gauss-Kronrod formula
      intk=intk+v*state.m_wk[i];
      //--- check
      if(i%2==1)
         intg=intg+v*state.m_wg[i];
      //--- Integral |F(x)|
      //--- Use rectangles method
      inta=inta+MathAbs(v)*state.m_wr[i];
      i=i+1;
      //--- function call, возврат результата
      return(Func_Internal_lbl_19(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- Routine body
//--- initialize quadratures.
//--- use 15-point Gauss-Kronrod formula.
   state.m_n=15;
   CGaussKronrodQ::GKQGenerateGaussLegendre(state.m_n,info,state.m_qn,state.m_wk,state.m_wg);
//--- check
   if(info<0)
     {
      //--- change values
      state.m_info=-5;
      state.m_r=0;
      //--- return result
      return(false);
     }
//--- allocation
   ArrayResizeAL(state.m_wr,state.m_n);
   for(i=0;i<=state.m_n-1;i++)
     {
      //--- check
      if(i==0)
        {
         state.m_wr[i]=0.5*MathAbs(state.m_qn[1]-state.m_qn[0]);
         continue;
        }
      //--- check
      if(i==state.m_n-1)
        {
         state.m_wr[state.m_n-1]=0.5*MathAbs(state.m_qn[state.m_n-1]-state.m_qn[state.m_n-2]);
         continue;
        }
      state.m_wr[i]=0.5*MathAbs(state.m_qn[i-1]-state.m_qn[i+1]);
     }
//--- special case
   if(state.m_a==state.m_b)
     {
      //--- change values
      state.m_info=1;
      state.m_r=0;
      //--- return result
      return(false);
     }
//--- test parameters
   if(state.m_eps<0.0 || state.m_xwidth<0.0)
     {
      //--- change values
      state.m_info=-1;
      state.m_r=0;
      //--- return result
      return(false);
     }
   state.m_info=1;
//--- check
   if(state.m_eps==0.0)
      state.m_eps=100000*CMath::m_machineepsilon;
//--- First,prepare heap
//--- * column 0   -   absolute error
//--- * column 1   -   integral of a F(x) (calculated using Kronrod extension nodes)
//--- * column 2   -   integral of a |F(x)| (calculated using modified rect. method)
//--- * column 3   -   left boundary of a subinterval
//--- * column 4   -   right boundary of a subinterval
   if(state.m_xwidth!=0.0)
     {
      //--- maximum subinterval should be no more than XWidth.
      //--- so we create Ceil((B-A)/XWidth)+1 small subintervals
      ns=(int)MathCeil(MathAbs(state.m_b-state.m_a)/state.m_xwidth)+1;
      state.m_heapsize=ns;
      state.m_heapused=ns;
      state.m_heapwidth=5;
      state.m_heap.Resize(state.m_heapsize,state.m_heapwidth);
      state.m_sumerr=0;
      state.m_sumabs=0;
      j=0;
      //--- function call, возврат результата
      return(Func_Internal_lbl_8(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- no maximum width requirements
//--- start from one big subinterval
   state.m_heapwidth=5;
   state.m_heapsize=1;
   state.m_heapused=1;
   state.m_heap.Resize(state.m_heapsize,state.m_heapwidth);
   c1=0.5*(state.m_b-state.m_a);
   c2=0.5*(state.m_b+state.m_a);
   intg=0;
   intk=0;
   inta=0;
   i=0;
//--- function call, возврат результата
   return(Func_Internal_lbl_5(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static void CAutoGK::Func_Internal_lbl_rcomm(CAutoGKInternalState &state,
                                             int i,int j,int ns,int info,
                                             double c1,double c2,double intg,
                                             double intk,double inta,double v,
                                             double ta,double tb,double qeps)
  {
//--- save
   state.m_rstate.ia[0]=i;
   state.m_rstate.ia[1]=j;
   state.m_rstate.ia[2]=ns;
   state.m_rstate.ia[3]=info;
   state.m_rstate.ra[0]=c1;
   state.m_rstate.ra[1]=c2;
   state.m_rstate.ra[2]=intg;
   state.m_rstate.ra[3]=intk;
   state.m_rstate.ra[4]=inta;
   state.m_rstate.ra[5]=v;
   state.m_rstate.ra[6]=ta;
   state.m_rstate.ra[7]=tb;
   state.m_rstate.ra[8]=qeps;
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_5(CAutoGKInternalState &state,
                                         int &i,int &j,int &ns,int &info,
                                         double &c1,double &c2,double &intg,
                                         double &intk,double &inta,double &v,
                                         double &ta,double &tb,double &qeps)
  {
//--- check
   if(i>state.m_n-1)
      return(Func_Internal_lbl_7(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
//--- obtain F
   state.m_x=c1*state.m_qn[i]+c2;
   state.m_rstate.stage=0;
//--- Saving state
   Func_Internal_lbl_rcomm(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps);
//--- return result
   return(true);
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_7(CAutoGKInternalState &state,
                                         int &i,int &j,int &ns,int &info,
                                         double &c1,double &c2,double &intg,
                                         double &intk,double &inta,double &v,
                                         double &ta,double &tb,double &qeps)
  {
//--- calculation
   intk=intk*(state.m_b-state.m_a)*0.5;
   intg=intg*(state.m_b-state.m_a)*0.5;
   inta=inta*(state.m_b-state.m_a)*0.5;
   state.m_heap[0].Set(0,MathAbs(intg-intk));
   state.m_heap[0].Set(1,intk);
   state.m_heap[0].Set(2,inta);
   state.m_heap[0].Set(3,state.m_a);
   state.m_heap[0].Set(4,state.m_b);
   state.m_sumerr=state.m_heap[0][0];
   state.m_sumabs=MathAbs(inta);
//--- method iterations
   return(Func_Internal_lbl_14(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_8(CAutoGKInternalState &state,
                                         int &i,int &j,int &ns,int &info,
                                         double &c1,double &c2,double &intg,
                                         double &intk,double &inta,double &v,
                                         double &ta,double &tb,double &qeps)
  {
//--- check
   if(j>ns-1)
     {
      //--- method iterations
      return(Func_Internal_lbl_14(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- calculation
   ta=state.m_a+j*(state.m_b-state.m_a)/ns;
   tb=state.m_a+(j+1)*(state.m_b-state.m_a)/ns;
   c1=0.5*(tb-ta);
   c2=0.5*(tb+ta);
   intg=0;
   intk=0;
   inta=0;
   i=0;
//--- function call, возврат результата
   return(Func_Internal_lbl_11(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_11(CAutoGKInternalState &state,
                                          int &i,int &j,int &ns,int &info,
                                          double &c1,double &c2,double &intg,
                                          double &intk,double &inta,double &v,
                                          double &ta,double &tb,double &qeps)
  {
//--- check
   if(i>state.m_n-1)
     {
      //--- calculation
      intk=intk*(tb-ta)*0.5;
      intg=intg*(tb-ta)*0.5;
      inta=inta*(tb-ta)*0.5;
      state.m_heap[j].Set(0,MathAbs(intg-intk));
      state.m_heap[j].Set(1,intk);
      state.m_heap[j].Set(2,inta);
      state.m_heap[j].Set(3,ta);
      state.m_heap[j].Set(4,tb);
      state.m_sumerr=state.m_sumerr+state.m_heap[j][0];
      state.m_sumabs=state.m_sumabs+MathAbs(inta);
      j=j+1;
      //--- function call, возврат результата
      return(Func_Internal_lbl_8(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- obtain F
   state.m_x=c1*state.m_qn[i]+c2;
   state.m_rstate.stage=1;
//--- Saving state
   Func_Internal_lbl_rcomm(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps);
//--- return result
   return(true);
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_14(CAutoGKInternalState &state,
                                          int &i,int &j,int &ns,int &info,
                                          double &c1,double &c2,double &intg,
                                          double &intk,double &inta,double &v,
                                          double &ta,double &tb,double &qeps)
  {
//--- additional memory if needed
   if(state.m_heapused==state.m_heapsize)
      MHeapResize(state.m_heap,state.m_heapsize,4*state.m_heapsize,state.m_heapwidth);
//--- TODO: every 20 iterations recalculate errors/sums
   if(state.m_sumerr<=state.m_eps*state.m_sumabs || state.m_heapused>=m_maxsubintervals)
     {
      state.m_r=0;
      for(j=0;j<=state.m_heapused-1;j++)
         state.m_r=state.m_r+state.m_heap[j][1];
      //--- return result
      return(false);
     }
//--- Exclude interval with maximum absolute error
   MHeapPop(state.m_heap,state.m_heapused,state.m_heapwidth);
   state.m_sumerr=state.m_sumerr-state.m_heap[state.m_heapused-1][0];
   state.m_sumabs=state.m_sumabs-state.m_heap[state.m_heapused-1][2];
//--- Divide interval,create subintervals
   ta=state.m_heap[state.m_heapused-1][3];
   tb=state.m_heap[state.m_heapused-1][4];
   state.m_heap[state.m_heapused-1].Set(3,ta);
   state.m_heap[state.m_heapused-1].Set(4,0.5*(ta+tb));
   state.m_heap[state.m_heapused].Set(3,0.5*(ta+tb));
   state.m_heap[state.m_heapused].Set(4,tb);
   j=state.m_heapused-1;
//--- function call, возврат результата
   return(Func_Internal_lbl_16(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_16(CAutoGKInternalState &state,
                                          int &i,int &j,int &ns,int &info,
                                          double &c1,double &c2,double &intg,
                                          double &intk,double &inta,double &v,
                                          double &ta,double &tb,double &qeps)
  {
//--- check
   if(j>state.m_heapused)
     {
      //--- function call
      MHeapPush(state.m_heap,state.m_heapused-1,state.m_heapwidth);
      //--- function call
      MHeapPush(state.m_heap,state.m_heapused,state.m_heapwidth);
      state.m_heapused=state.m_heapused+1;
      //--- method iterations
      return(Func_Internal_lbl_14(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- calculation
   c1=0.5*(state.m_heap[j][4]-state.m_heap[j][3]);
   c2=0.5*(state.m_heap[j][4]+state.m_heap[j][3]);
   intg=0;
   intk=0;
   inta=0;
   i=0;
//--- function call, возврат результата
   return(Func_Internal_lbl_19(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKInternalIteration. Is a product to  |
//| get rid of the operator unconditional jump goto.                 |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_Internal_lbl_19(CAutoGKInternalState &state,
                                          int &i,int &j,int &ns,int &info,
                                          double &c1,double &c2,double &intg,
                                          double &intk,double &inta,double &v,
                                          double &ta,double &tb,double &qeps)
  {
//--- check
   if(i>state.m_n-1)
     {
      //--- calculation
      intk=intk*(state.m_heap[j][4]-state.m_heap[j][3])*0.5;
      intg=intg*(state.m_heap[j][4]-state.m_heap[j][3])*0.5;
      inta=inta*(state.m_heap[j][4]-state.m_heap[j][3])*0.5;
      state.m_heap[j].Set(0,MathAbs(intg-intk));
      state.m_heap[j].Set(1,intk);
      state.m_heap[j].Set(2,inta);
      state.m_sumerr=state.m_sumerr+state.m_heap[j][0];
      state.m_sumabs=state.m_sumabs+state.m_heap[j][2];
      j=j+1;
      //--- function call, возврат результата
      return(Func_Internal_lbl_16(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps));
     }
//--- F(x)
   state.m_x=c1*state.m_qn[i]+c2;
   state.m_rstate.stage=2;
//--- Saving state
   Func_Internal_lbl_rcomm(state,i,j,ns,info,c1,c2,intg,intk,inta,v,ta,tb,qeps);
//--- return result
   return(true);
  }
//+------------------------------------------------------------------+
//| Iterative method                                                 |
//+------------------------------------------------------------------+
static bool CAutoGK::AutoGKIteration(CAutoGKState &state)
  {
//--- create variables
   double s=0;
   double tmp=0;
   double eps=0;
   double a=0;
   double b=0;
   double x=0;
   double t=0;
   double alpha=0;
   double beta=0;
   double v1=0;
   double v2=0;
//--- This code initializes locals by:
//--- * random values determined during code
//---   generation - on first subroutine call
//--- * values from previous call - on subsequent calls
   if(state.m_rstate.stage>=0)
     {
      //--- initialization
      s=state.m_rstate.ra[0];
      tmp=state.m_rstate.ra[1];
      eps=state.m_rstate.ra[2];
      a=state.m_rstate.ra[3];
      b=state.m_rstate.ra[4];
      x=state.m_rstate.ra[5];
      t=state.m_rstate.ra[6];
      alpha=state.m_rstate.ra[7];
      beta=state.m_rstate.ra[8];
      v1=state.m_rstate.ra[9];
      v2=state.m_rstate.ra[10];
     }
   else
     {
      //--- initialization
      s=-983;
      tmp=-989;
      eps=-834;
      a=900;
      b=-287;
      x=364;
      t=214;
      alpha=-338;
      beta=-686;
      v1=912;
      v2=585;
     }
//--- check
   if(state.m_rstate.stage==0)
     {
      //--- change values
      state.m_needf=false;
      state.m_nfev=state.m_nfev+1;
      state.m_internalstate.m_f=state.m_f;
      //--- function call, возврат результата
      return(Func_lbl_5(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2));
     }
//--- check
   if(state.m_rstate.stage==1)
     {
      //--- change value
      state.m_needf=false;
      //--- check
      if(alpha!=0.0)
         state.m_internalstate.m_f=state.m_f*MathPow(x,-(alpha/(1+alpha)))/(1+alpha);
      else
         state.m_internalstate.m_f=state.m_f;
      state.m_nfev=state.m_nfev+1;
      //--- function call, возврат результата
      return(Func_lbl_9(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2));
     }
//--- check
   if(state.m_rstate.stage==2)
     {
      //--- change value
      state.m_needf=false;
      //--- check
      if(beta!=0.0)
         state.m_internalstate.m_f=state.m_f*MathPow(x,-(beta/(1+beta)))/(1+beta);
      else
         state.m_internalstate.m_f=state.m_f;
      state.m_nfev=state.m_nfev+1;
      //--- function call, возврат результата
      return(Func_lbl_11(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2));
     }
//--- Routine body
   eps=0;
   a=state.m_a;
   b=state.m_b;
   alpha=state.m_alpha;
   beta=state.m_beta;
   state.m_terminationtype=-1;
   state.m_nfev=0;
   state.m_nintervals=0;
//--- smooth function  at a finite interval
   if(state.m_wrappermode!=0)
     {
      //--- function with power-law singularities at the ends of a finite interval
      if(state.m_wrappermode!=1)
         return(false);
      //--- test coefficients
      if(alpha<=-1.0 || beta<=-1.0)
        {
         //--- change values
         state.m_terminationtype=-1;
         state.m_v=0;
         //--- return result
         return(false);
        }
      //--- special cases
      if(a==b)
        {
         //--- change values
         state.m_terminationtype=1;
         state.m_v=0;
         //--- return result
         return(false);
        }
      //--- reduction to general form
      if(a<b)
         s=1;
      else
        {
         //--- change values
         s=-1;
         tmp=a;
         a=b;
         b=tmp;
         tmp=alpha;
         alpha=beta;
         beta=tmp;
        }
      //--- change values
      alpha=MathMin(alpha,0);
      beta=MathMin(beta,0);
      //--- first,integrate left half of [a,b]:
      //---     integral(f(x)dx,a,(b+a)/2)=
      //---     =1/(1+alpha) * integral(t^(-alpha/(1+alpha))*f(a+t^(1/(1+alpha)))dt,0,(0.5*(b-a))^(1+alpha))
      AutoGKInternalPrepare(0,MathPow(0.5*(b-a),1+alpha),eps,state.m_xwidth,state.m_internalstate);
      //--- function call, возврат результата
      return(Func_lbl_9(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2));
     }
//--- special case
   if(a==b)
     {
      //--- change values
      state.m_terminationtype=1;
      state.m_v=0;
      //--- return result
      return(false);
     }
//--- general case
   AutoGKInternalPrepare(a,b,eps,state.m_xwidth,state.m_internalstate);
//--- function call, возврат результата
   return(Func_lbl_5(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2));
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKIteration. Is a product to get rid  |
//| of the operator unconditional jump goto.                         |
//+------------------------------------------------------------------+
static void CAutoGK::Func_lbl_rcomm(CAutoGKState &state,double s,double tmp,
                                    double eps,double a,double b,double x,
                                    double t,double alpha,double beta,
                                    double v1,double v2)
  {
//--- save
   state.m_rstate.ra[0]=s;
   state.m_rstate.ra[1]=tmp;
   state.m_rstate.ra[2]=eps;
   state.m_rstate.ra[3]=a;
   state.m_rstate.ra[4]=b;
   state.m_rstate.ra[5]=x;
   state.m_rstate.ra[6]=t;
   state.m_rstate.ra[7]=alpha;
   state.m_rstate.ra[8]=beta;
   state.m_rstate.ra[9]=v1;
   state.m_rstate.ra[10]=v2;
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKIteration. Is a product to get rid  |
//| of the operator unconditional jump goto.                         |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_lbl_5(CAutoGKState &state,double &s,double &tmp,
                                double &eps,double &a,double &b,double &x,
                                double &t,double &alpha,double &beta,
                                double &v1,double &v2)
  {
//--- check
   if(!AutoGKInternalIteration(state.m_internalstate))
     {
      //--- change values
      state.m_v=state.m_internalstate.m_r;
      state.m_terminationtype=state.m_internalstate.m_info;
      state.m_nintervals=state.m_internalstate.m_heapused;
      //--- return result
      return(false);
     }
//--- change values
   x=state.m_internalstate.m_x;
   state.m_x=x;
   state.m_xminusa=x-a;
   state.m_bminusx=b-x;
   state.m_needf=true;
   state.m_rstate.stage=0;
//--- Saving state
   Func_lbl_rcomm(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2);
//--- return result
   return(true);
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKIteration. Is a product to get rid  |
//| of the operator unconditional jump goto.                         |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_lbl_9(CAutoGKState &state,double &s,double &tmp,
                                double &eps,double &a,double &b,double &x,
                                double &t,double &alpha,double &beta,
                                double &v1,double &v2)
  {
//--- check
   if(!AutoGKInternalIteration(state.m_internalstate))
     {
      v1=state.m_internalstate.m_r;
      state.m_nintervals=state.m_nintervals+state.m_internalstate.m_heapused;
      //--- then,integrate right half of [a,b]:
      //---     integral(f(x)dx,(b+a)/2,b)=
      //---     =1/(1+beta) * integral(t^(-beta/(1+beta))*f(b-t^(1/(1+beta)))dt,0,(0.5*(b-a))^(1+beta))
      AutoGKInternalPrepare(0,MathPow(0.5*(b-a),1+beta),eps,state.m_xwidth,state.m_internalstate);
      //--- function call, возврат результата
      return(Func_lbl_11(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2));
     }
//--- Fill State.X,State.XMinusA,State.BMinusX.
//--- Latter two are filled correctly even if B<A.
   x=state.m_internalstate.m_x;
   t=MathPow(x,1/(1+alpha));
   state.m_x=a+t;
//--- check
   if(s>0.0)
     {
      state.m_xminusa=t;
      state.m_bminusx=b-(a+t);
     }
   else
     {
      state.m_xminusa=a+t-b;
      state.m_bminusx=-t;
     }
//--- change values
   state.m_needf=true;
   state.m_rstate.stage=1;
//--- Saving state
   Func_lbl_rcomm(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2);
//--- return result
   return(true);
  }
//+------------------------------------------------------------------+
//| Auxiliary function for AutoGKIteration. Is a product to get rid  |
//| of the operator unconditional jump goto.                         |
//+------------------------------------------------------------------+
static bool CAutoGK::Func_lbl_11(CAutoGKState &state,double &s,double &tmp,
                                 double &eps,double &a,double &b,double &x,
                                 double &t,double &alpha,double &beta,
                                 double &v1,double &v2)
  {
//--- check
   if(!AutoGKInternalIteration(state.m_internalstate))
     {
      //--- change values
      v2=state.m_internalstate.m_r;
      state.m_nintervals=state.m_nintervals+state.m_internalstate.m_heapused;
      //--- final result
      state.m_v=s*(v1+v2);
      state.m_terminationtype=1;
      //--- return result
      return(false);
     }
//--- Fill State.X,State.XMinusA,State.BMinusX.
//--- Latter two are filled correctly (X-A,B-X) even if B<A.
   x=state.m_internalstate.m_x;
   t=MathPow(x,1/(1+beta));
   state.m_x=b-t;
//--- check
   if(s>0.0)
     {
      state.m_xminusa=b-t-a;
      state.m_bminusx=t;
     }
   else
     {
      state.m_xminusa=-t;
      state.m_bminusx=a-(b-t);
     }
//--- change values
   state.m_needf=true;
   state.m_rstate.stage=2;
//--- Saving state
   Func_lbl_rcomm(state,s,tmp,eps,a,b,x,t,alpha,beta,v1,v2);
//--- return result
   return(true);
  }
//+------------------------------------------------------------------+

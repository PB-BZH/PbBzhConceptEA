#ifndef PB_BZH_LOCAL_PRICE_WINDOW_ANALYZER_MQH
#define PB_BZH_LOCAL_PRICE_WINDOW_ANALYZER_MQH


// --------------------------------------------------
// Photographie d'une fenêtre locale de prix.
//
// Pour notre première expérimentation :
//    timeframe = M5
//    durée     = 60 minutes
//
// Aucune décision de trading n'est prise ici.
// --------------------------------------------------
struct SLocalPriceWindowSnapshot
  {
   datetime referenceTime;
   datetime windowStartTime;

   datetime firstBarOpenTime;
   datetime lastBarOpenTime;
   datetime lastBarCloseTime;

   int      expectedBars;
   int      barCount;

   bool     isComplete;

   double   windowOpen;
   double   windowClose;

   double   highestPrice;
   double   lowestPrice;

   double   netChangePoints;
   double   rangePoints;

   // --------------------------------------------------
    // Ajustement quadratique local.
    //
    // Prix(t) ≈ a.t² + b.t + c
    //
    // t est exprimé en heures et t=0 correspond
    // à l'instant du signal H1.
    //
    // La pente à t=0 vaut b.
    // La courbure vaut 2a.
    // --------------------------------------------------
    int      fitPointCount;
    bool     quadraticFitValid;

    double   localSlopePointsPerHour;
    double   localCurvaturePointsPerHour2;

    double   quadraticRSquared;
  };


//+------------------------------------------------------------------+
//| Analyse d'une fenêtre locale de prix                              |
//+------------------------------------------------------------------+
class CLocalPriceWindowAnalyzer
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   int               m_periodSeconds;
   int               m_windowSeconds;
   int               m_expectedBars;

   double            m_point;
// --------------------------------------------------
// Déterminant d'une matrice 3 x 3.
// Utilisé pour résoudre le système normal de la
// régression quadratique.
// --------------------------------------------------
double Determinant3x3(
   const double a11,
   const double a12,
   const double a13,
   const double a21,
   const double a22,
   const double a23,
   const double a31,
   const double a32,
   const double a33) const
  {
   return
      a11*(a22*a33-a23*a32)
      -a12*(a21*a33-a23*a31)
      +a13*(a21*a32-a22*a31);
  }

public:

   CLocalPriceWindowAnalyzer(void)
     {
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;

      m_periodSeconds=0;
      m_windowSeconds=0;
      m_expectedBars=0;

      m_point=0.0;
     }


   // --------------------------------------------------
   // Initialisation.
   // --------------------------------------------------
   bool Init(
      const string          symbol,
      const ENUM_TIMEFRAMES timeframe,
      const int             windowMinutes)
     {
      if(symbol=="")
        {
         Print(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "Symbole invalide.");

         return false;
        }

      if(windowMinutes<=0)
        {
         Print(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "La durée de la fenêtre doit être positive.");

         return false;
        }

      int periodSeconds=
         PeriodSeconds(timeframe);

      if(periodSeconds<=0)
        {
         PrintFormat(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "Période invalide : %s.",
            EnumToString(timeframe));

         return false;
        }

      int windowSeconds=
         windowMinutes*60;

      if(windowSeconds<periodSeconds)
        {
         Print(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "La fenêtre est plus courte que le timeframe.");

         return false;
        }

      if((windowSeconds%periodSeconds)!=0)
        {
         Print(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "La durée de la fenêtre doit être un multiple "
            "exact du timeframe.");

         return false;
        }

      double point=
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT);

      if(point<=0.0)
        {
         PrintFormat(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "SYMBOL_POINT invalide pour %s.",
            symbol);

         return false;
        }

      m_symbol=symbol;
      m_timeframe=timeframe;

      m_periodSeconds=periodSeconds;
      m_windowSeconds=windowSeconds;

      m_expectedBars=
         windowSeconds/
         periodSeconds;

      m_point=point;

      return true;
     }


   // --------------------------------------------------
   // Analyse la fenêtre qui précède referenceTime.
   //
   // Exemple :
   //
   // referenceTime = 14:00
   // fenêtre M5 60 min :
   //
   // 13:00 13:05 ... 13:50 13:55
   //                           |
   //                           + fermeture à 14:00
   //
   // Rien après 14:00 n'est utilisé.
   // --------------------------------------------------
   bool Analyze(
      const datetime                 referenceTime,
      SLocalPriceWindowSnapshot     &snapshot) const
     {
      ZeroMemory(snapshot);

      snapshot.referenceTime =
         referenceTime;

      snapshot.windowStartTime=
         referenceTime-
         m_windowSeconds;

      snapshot.expectedBars=
         m_expectedBars;


      MqlRates rates[];

      ArraySetAsSeries(
         rates,
         false);


      ResetLastError();

      int copied=
         CopyRates(
            m_symbol,
            m_timeframe,
            snapshot.windowStartTime,
            referenceTime-1,
            rates);


      if(copied<2)
        {
         PrintFormat(
            "[CLocalPriceWindowAnalyzer][ERROR] "
            "Lecture de la fenêtre %s impossible. "
            "Barres=%d | Erreur=%d.",
            EnumToString(m_timeframe),
            copied,
            GetLastError());

         return false;
        }


      snapshot.barCount=
         copied;


      // --------------------------------------------------
      // Recherche explicite de la première et de la
      // dernière bougie.
      //
      // On ne dépend ainsi pas de l'ordre physique
      // retourné par CopyRates().
      // --------------------------------------------------
      int firstIndex=0;
      int lastIndex=0;

      for(int i=1;i<copied;i++)
        {
         if(rates[i].time<
            rates[firstIndex].time)
           {
            firstIndex=i;
           }

         if(rates[i].time>
            rates[lastIndex].time)
           {
            lastIndex=i;
           }
        }


      snapshot.firstBarOpenTime=
         rates[firstIndex].time;

      snapshot.lastBarOpenTime=
         rates[lastIndex].time;

      snapshot.lastBarCloseTime=
         snapshot.lastBarOpenTime+
         m_periodSeconds;


      // --------------------------------------------------
      // Variation nette sur la totalité de l'heure :
      //
      // ouverture de la première M5
      //       ->
      // clôture de la dernière M5.
      // --------------------------------------------------
      snapshot.windowOpen=
         rates[firstIndex].open;

      snapshot.windowClose=
         rates[lastIndex].close;


      // --------------------------------------------------
      // Amplitude totale de la fenêtre.
      // --------------------------------------------------
      snapshot.highestPrice=
         rates[0].high;

      snapshot.lowestPrice=
         rates[0].low;


      for(int i=1;i<copied;i++)
        {
         if(rates[i].high>
            snapshot.highestPrice)
           {
            snapshot.highestPrice=
               rates[i].high;
           }

         if(rates[i].low<
            snapshot.lowestPrice)
           {
            snapshot.lowestPrice=
               rates[i].low;
           }
        }


      snapshot.netChangePoints=
         (snapshot.windowClose-
          snapshot.windowOpen)/
         m_point;

      snapshot.rangePoints=
         (snapshot.highestPrice-
          snapshot.lowestPrice)/
         m_point;


      // --------------------------------------------------
      // La fenêtre est dite complète uniquement si :
      //
      // - le nombre de bougies est celui attendu ;
      // - la première commence exactement au début ;
      // - la dernière se ferme exactement à la référence.
      // --------------------------------------------------
      snapshot.isComplete=
         snapshot.barCount==
            snapshot.expectedBars
         &&
         snapshot.firstBarOpenTime==
            snapshot.windowStartTime
         &&
         snapshot.lastBarCloseTime==
            referenceTime;


// --------------------------------------------------
// L'ajustement quadratique n'est effectué que sur
// une fenêtre temporelle complète.
// --------------------------------------------------
if(!snapshot.isComplete)
   return true;


// ==================================================
// Ajustement quadratique local
//
//     y(t) = a.t² + b.t + c
//
// t : heures relativement à referenceTime.
//     referenceTime correspond donc à t=0.
//
// y : déplacement du prix en points par rapport à
//     l'ouverture de la première bougie M5.
//
// Nous avons 12 bougies M5 mais 13 points temporels :
//
// ouverture première bougie : t=-1 h
// clôture première bougie   : t=-55 min
// ...
// clôture dernière bougie   : t=0
// ==================================================


// --------------------------------------------------
// Sommes nécessaires aux équations normales.
// --------------------------------------------------
double sumT=0.0;
double sumT2=0.0;
double sumT3=0.0;
double sumT4=0.0;

double sumY=0.0;
double sumTY=0.0;
double sumT2Y=0.0;


// --------------------------------------------------
// Premier point : ouverture de la fenêtre.
//
// Comme windowOpen sert de référence :
//
// y = 0 point.
// --------------------------------------------------
double t=
   (double)(
      snapshot.windowStartTime-
      referenceTime)/
   3600.0;

double y=0.0;

double t2=t*t;

sumT+=t;
sumT2+=t2;
sumT3+=t2*t;
sumT4+=t2*t2;

sumY+=y;
sumTY+=t*y;
sumT2Y+=t2*y;


// --------------------------------------------------
// Les douze clôtures M5.
// --------------------------------------------------
for(int i=0;i<copied;i++)
  {
   datetime closeTime=
      rates[i].time+
      m_periodSeconds;

   t=
      (double)(
         closeTime-
         referenceTime)/
      3600.0;

   y=
      (rates[i].close-
       snapshot.windowOpen)/
      m_point;

   t2=t*t;

   sumT+=t;
   sumT2+=t2;
   sumT3+=t2*t;
   sumT4+=t2*t2;

   sumY+=y;
   sumTY+=t*y;
   sumT2Y+=t2*y;
  }


snapshot.fitPointCount=
   copied+1;

double n=
   (double)snapshot.fitPointCount;


// ==================================================
// Équations normales :
//
// [ Σt⁴  Σt³  Σt² ] [ a ]   [ Σt²y ]
// [ Σt³  Σt²  Σt  ] [ b ] = [ Σty  ]
// [ Σt²  Σt   n    ] [ c ]   [ Σy   ]
// ==================================================

double determinant=
   Determinant3x3(
      sumT4, sumT3, sumT2,
      sumT3, sumT2, sumT,
      sumT2, sumT,  n);


// --------------------------------------------------
// Protection contre un système singulier.
// --------------------------------------------------
if(MathAbs(determinant)<1.0e-12)
  {
   snapshot.quadraticFitValid=false;

   return true;
  }


// --------------------------------------------------
// Déterminant pour a.
// --------------------------------------------------
double determinantA=
   Determinant3x3(
      sumT2Y, sumT3, sumT2,
      sumTY,  sumT2, sumT,
      sumY,   sumT,  n);


// --------------------------------------------------
// Déterminant pour b.
// --------------------------------------------------
double determinantB=
   Determinant3x3(
      sumT4, sumT2Y, sumT2,
      sumT3, sumTY,  sumT,
      sumT2, sumY,   n);


// --------------------------------------------------
// Déterminant pour c.
// --------------------------------------------------
double determinantC=
   Determinant3x3(
      sumT4, sumT3, sumT2Y,
      sumT3, sumT2, sumTY,
      sumT2, sumT,  sumY);


double a=
   determinantA/
   determinant;

double b=
   determinantB/
   determinant;

double c=
   determinantC/
   determinant;


// ==================================================
// Grandeurs physiques recherchées.
//
// y(t) = a.t²+b.t+c
//
// y'(t) = 2a.t+b
//
// à t=0 :
//
// y'(0) = b
//
// y''(t) = 2a
//
// Comme t est en heures :
//
// b  -> points/heure
// 2a -> points/heure²
// ==================================================

snapshot.localSlopePointsPerHour=
   b;

snapshot.localCurvaturePointsPerHour2=
   2.0*a;


// ==================================================
// Qualité de l'ajustement : R².
// ==================================================

double meanY=
   sumY/n;

double totalSquareSum=0.0;
double residualSquareSum=0.0;


// --------------------------------------------------
// Premier point : t=-1 h, y=0.
// --------------------------------------------------
t=
   (double)(
      snapshot.windowStartTime-
      referenceTime)/
   3600.0;

y=0.0;

double estimatedY=
   a*t*t+
   b*t+
   c;

totalSquareSum+=
   (y-meanY)*
   (y-meanY);

residualSquareSum+=
   (y-estimatedY)*
   (y-estimatedY);


// --------------------------------------------------
// Douze clôtures.
// --------------------------------------------------
for(int i=0;i<copied;i++)
  {
   datetime closeTime=
      rates[i].time+
      m_periodSeconds;

   t=
      (double)(
         closeTime-
         referenceTime)/
      3600.0;

   y=
      (rates[i].close-
       snapshot.windowOpen)/
      m_point;

   estimatedY=
      a*t*t+
      b*t+
      c;

   totalSquareSum+=
      (y-meanY)*
      (y-meanY);

   residualSquareSum+=
      (y-estimatedY)*
      (y-estimatedY);
  }


// --------------------------------------------------
// Cas particulier : série pratiquement constante.
// --------------------------------------------------
if(totalSquareSum<1.0e-12)
  {
   snapshot.quadraticRSquared=
      residualSquareSum<1.0e-12
      ? 1.0
      : 0.0;
  }
else
  {
   snapshot.quadraticRSquared=
      1.0-
      residualSquareSum/
      totalSquareSum;

   // Protection uniquement contre les minuscules
   // dépassements numériques.
   if(snapshot.quadraticRSquared>1.0)
      snapshot.quadraticRSquared=1.0;

   if(snapshot.quadraticRSquared<0.0)
      snapshot.quadraticRSquared=0.0;
  }


snapshot.quadraticFitValid=true;

return true;
     }
  };


#endif
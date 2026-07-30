#ifndef PB_BZH_LOCAL_MARKET_DYNAMICS_MQH
#define PB_BZH_LOCAL_MARKET_DYNAMICS_MQH


// --------------------------------------------------
// Dynamique locale du marché observée au moment
// de l'entrée.
//
// Les grandeurs directionnelles sont exprimées
// dans le sens du signal :
//
//     positif = favorable au trade
//     négatif = défavorable au trade
//
// L'amplitude et R² ne sont pas directionnels.
// --------------------------------------------------
struct SLocalMarketDynamics
  {
   bool   isValid;

   double directionalChangePoints;
   double rangePoints;

   double directionalSlopePointsPerHour;
   double directionalCurvaturePointsPerHour2;

   double quadraticRSquared ;
  };


#endif
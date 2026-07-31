#ifndef PB_BZH_LOCAL_MARKET_DYNAMICS_MQH
#define PB_BZH_LOCAL_MARKET_DYNAMICS_MQH

// --------------------------------------------------
// Quadrant de dynamique locale.
//
// Les signes sont directionnels :
// positif = favorable au sens du trade.
//
// I   : pente positive, courbure positive
// II  : pente négative, courbure positive
// III : pente négative, courbure négative
// IV  : pente positive, courbure négative
//
// Une valeur exactement nulle reste volontairement
// non classée pour ne pas introduire de convention
// arbitraire à ce stade.
// --------------------------------------------------
enum ENUM_PB_LOCAL_DYNAMICS_QUADRANT {
  PB_LOCAL_QUADRANT_UNDEFINED = 0,
    PB_LOCAL_QUADRANT_I,
    PB_LOCAL_QUADRANT_II,
    PB_LOCAL_QUADRANT_III,
    PB_LOCAL_QUADRANT_IV
};


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
struct SLocalMarketDynamics {
  bool isValid;

  double directionalChangePoints;
  double rangePoints;

  double directionalSlopePointsPerHour;
  double directionalCurvaturePointsPerHour2;

  double quadraticRSquared;
};

ENUM_PB_LOCAL_DYNAMICS_QUADRANT DetermineLocalDynamicsQuadrant(
  const SLocalMarketDynamics &dynamics) {
  if (!dynamics.isValid)
  return PB_LOCAL_QUADRANT_UNDEFINED;

  double slope =
    dynamics.directionalSlopePointsPerHour;

  double curvature =
    dynamics.directionalCurvaturePointsPerHour2;


  if (slope > 0.0 && curvature > 0.0)
  return PB_LOCAL_QUADRANT_I;

  if (slope < 0.0 && curvature > 0.0)
  return PB_LOCAL_QUADRANT_II;

  if (slope < 0.0 && curvature < 0.0)
  return PB_LOCAL_QUADRANT_III;

  if (slope > 0.0 && curvature < 0.0)
  return PB_LOCAL_QUADRANT_IV;


  return PB_LOCAL_QUADRANT_UNDEFINED;
}

string LocalDynamicsQuadrantToString(
  const ENUM_PB_LOCAL_DYNAMICS_QUADRANT quadrant) {
  switch (quadrant) {
    case PB_LOCAL_QUADRANT_I:
      return "I";

    case PB_LOCAL_QUADRANT_II:
      return "II";

    case PB_LOCAL_QUADRANT_III:
      return "III";

    case PB_LOCAL_QUADRANT_IV:
      return "IV";

    default:
      return "NON CLASSE";
  }
}

#endif
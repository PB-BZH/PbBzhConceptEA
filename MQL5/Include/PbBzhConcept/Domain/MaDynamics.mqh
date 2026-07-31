//+------------------------------------------------------------------+
//|                                                   MaDynamics.mqh |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
#ifndef PB_BZH_MA_DYNAMICS_MQH
#define PB_BZH_MA_DYNAMICS_MQH

// --------------------------------------------------
// Régime de dynamique de moyenne mobile.
//
// Les pentes sont directionnelles :
// positif = favorable au sens du signal.
//
// Avec S0 > 0 :
// +++ : continuation
// -++ : retournement déjà engagé
// --+ : retournement au voisinage du signal
// +-+ : oscillation / reprise
//
// Une pente exactement nulle reste non classée.
// --------------------------------------------------
enum ENUM_PB_MA_DYNAMICS_REGIME
{
  PB_MA_REGIME_UNDEFINED = 0,
  PB_MA_REGIME_CONTINUATION,
  PB_MA_REGIME_REVERSAL_EARLY,
  PB_MA_REGIME_REVERSAL_LATE,
  PB_MA_REGIME_OSCILLATION
};

// ==================================================
// SMaDynamics
//
// Décrit la dynamique locale d'une moyenne mobile
// autour du croisement.
//
// S2 : pente la plus ancienne
// S1 : pente juste avant le croisement
// S0 : pente au croisement
//
// A1 = S1 - S2
// A0 = S0 - S1
//
// Les pentes sont exprimées en points/bougie.
// Les accélérations en points/bougie².
// ==================================================
struct SMaDynamics
  {
   double slopeEarlier;          // S2
   double slopePrevious;         // S1
   double slopeCurrent;          // S0

   double accelerationPrevious;  // A1
   double accelerationCurrent;   // A0;
  };

ENUM_PB_MA_DYNAMICS_REGIME DetermineMaDynamicsRegime(
  const SMaDynamics &dynamics) {

  double s2 = dynamics.slopeEarlier;
  double s1 = dynamics.slopePrevious;
  double s0 = dynamics.slopeCurrent;


  // Dans l'étude actuelle, le régime est défini
  // pour une pente courante favorable au signal.
  if (s0 <= 0.0)
    return PB_MA_REGIME_UNDEFINED;


  if (s2 > 0.0 && s1 > 0.0)
    return PB_MA_REGIME_CONTINUATION;   // +++

  if (s2 < 0.0 && s1 > 0.0)
    return PB_MA_REGIME_REVERSAL_EARLY; // -++

  if (s2 < 0.0 && s1 < 0.0)
    return PB_MA_REGIME_REVERSAL_LATE;  // --+

  if (s2 > 0.0 && s1 < 0.0)
    return PB_MA_REGIME_OSCILLATION;    // +-+


  return PB_MA_REGIME_UNDEFINED;
}

string MaDynamicsRegimeToString(
  const ENUM_PB_MA_DYNAMICS_REGIME regime) {

  switch (regime) {
    case PB_MA_REGIME_CONTINUATION:
      return "+++";

    case PB_MA_REGIME_REVERSAL_EARLY:
      return "-++";

    case PB_MA_REGIME_REVERSAL_LATE:
      return "--+";

    case PB_MA_REGIME_OSCILLATION:
      return "+-+";

    default:
      return "NON CLASSE";
  }
}

#endif
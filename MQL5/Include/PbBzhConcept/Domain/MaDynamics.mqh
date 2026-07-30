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

#endif
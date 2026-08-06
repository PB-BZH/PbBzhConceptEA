#ifndef PB_BZH_CONCEPT_VIRTUAL_POSITION_MANAGER_MQH
#define PB_BZH_CONCEPT_VIRTUAL_POSITION_MANAGER_MQH

#include <PbBzhConcept/Domain/TradeSignal.mqh>
#include <PbBzhConcept/Simulation/VirtualVolumeCalculator.mqh>
#include <PbBzhConcept/Domain/MaDynamics.mqh>
#include <PbBzhConcept/Domain/LocalMarketDynamics.mqh>


// --------------------------------------------------
// État de la position virtuelle.
// --------------------------------------------------
enum ENUM_PB_VIRTUAL_POSITION_STATE {
  PB_VIRTUAL_POSITION_FLAT = 0,
  PB_VIRTUAL_POSITION_LONG = 1,
  PB_VIRTUAL_POSITION_SHORT = -1
};


// --------------------------------------------------
// Motif de clôture d'une position virtuelle.
// --------------------------------------------------
enum ENUM_PB_VIRTUAL_EXIT_REASON {
  PB_VIRTUAL_EXIT_SIGNAL = 0,
    PB_VIRTUAL_EXIT_STOP_LOSS = 1,
    PB_VIRTUAL_EXIT_TAKE_PROFIT = 2
};

// --------------------------------------------------
// Convertit l'état de position en texte.
// --------------------------------------------------
string VirtualPositionStateToString(
  const ENUM_PB_VIRTUAL_POSITION_STATE state) {
  switch (state) {
    case PB_VIRTUAL_POSITION_LONG:
      return "LONG";

    case PB_VIRTUAL_POSITION_SHORT:
      return "SHORT";

    case PB_VIRTUAL_POSITION_FLAT:
      return "FLAT";

    default:
      return "INCONNU";
  }
}


// --------------------------------------------------
// Convertit le motif de sortie en texte.
// --------------------------------------------------
string VirtualExitReasonToString(
  const ENUM_PB_VIRTUAL_EXIT_REASON reason) {
  switch (reason) {
    case PB_VIRTUAL_EXIT_SIGNAL:
      return "SIGNAL";

    case PB_VIRTUAL_EXIT_STOP_LOSS:
      return "STOP_LOSS";

    case PB_VIRTUAL_EXIT_TAKE_PROFIT:
      return "TAKE_PROFIT";

    default:
      return "INCONNU";
  }
}


// --------------------------------------------------
// Capacité maximale du bilan annuel.
// 64 années couvrent très largement les tests usuels.
// --------------------------------------------------
#define PB_VIRTUAL_ANNUAL_STATS_CAPACITY 64


// --------------------------------------------------
// Statistiques agrégées pour une année civile.
// Les trades sont rattachés à l'année de leur clôture.
// --------------------------------------------------
struct SPbVirtualAnnualStatistics {
  int year;

  datetime firstObservedTime;
  datetime lastObservedTime;

  int closedTradeCount;
  int winningTradeCount;
  int losingTradeCount;
  int breakEvenTradeCount;

  int currentLosingStreak;
  int maxLosingStreak;

  double totalClosedPoints;
  double grossProfitMoney;
  double grossLossMoney;
  double totalClosedMoney;

  double startCapital;
  double endCapital;

  double peakCapital;
  double maxCapitalDrawdownMoney;
  double maxCapitalDrawdownPercent;

  double peakEquity;
  double maxEquityDrawdownMoney;
  double maxEquityDrawdownPercent;
};


// --------------------------------------------------
// Capacité maximale du rapport détaillé des trades.
// 8192 enregistrements couvrent très largement les
// campagnes H1 actuellement réalisées.
// --------------------------------------------------
#define PB_VIRTUAL_CLOSED_TRADES_CAPACITY 8192


// --------------------------------------------------
// Photographie complète d'un trade virtuel clôturé.
// Aucune chaîne n'est stockée afin de limiter la mémoire.
// --------------------------------------------------
struct SPbVirtualClosedTradeRecord {
  int sequence;

  datetime entryTime;
  datetime exitTime;

  ENUM_PB_VIRTUAL_POSITION_STATE positionState;
  ENUM_PB_VIRTUAL_EXIT_REASON exitReason;

  bool openedAfterInversion;

  double entryPrice;
  double exitPrice;
  double volumeLots;
  double entrySpreadPoints;

  int stopLossPoints;
  int takeProfitPoints;
  int breakEvenTriggerPoints;

  double initialStopLossPrice;
  double initialTakeProfitPrice;
  double finalStopLossPrice;
  double finalTakeProfitPrice;

  bool breakEvenActivated;
  bool profitLockActivated;

  double resultPoints;
  double resultMoney;
  double resultRPoints;
  double resultRMoney;

  double maxFavorablePoints;
  double maxFavorableR;

  double openingCapital;
  double targetRiskMoney;
  double estimatedLossAtStop;

  bool entryAtrValid;
  double entryAtrPoints;
  double entryStopLossAtr;

  SMaDynamics entryMaDynamics;
  SLocalMarketDynamics entryLocalDynamics;

  bool trendContextValid;
  double trendClose1;
  double trendMa1;
  double trendMa2;
  bool trendAligned;

  double pointSize;
  int symbolDigits;
  double tickSize;
  double tickValue;
  double contractSize;
};


// --------------------------------------------------
// Gère une seule position virtuelle à la fois.
// --------------------------------------------------
class CVirtualPositionManager {
  private:
    bool m_isInitialized;

  string m_symbol;
  double m_point;
  int m_digits;

  string m_accountCurrency;
  int m_accountCurrencyDigits;

  // Distances fixes servant de repli.
  int m_stopLossPoints;
  int m_takeProfitPoints;

  // Distances figées pour la position courante.
  int m_currentStopLossPoints;
  int m_currentTakeProfitPoints;
  int m_currentBreakEvenTriggerPoints;

  double m_stopLossPrice;
  double m_takeProfitPrice;

  CVirtualVolumeCalculator m_volumeCalculator;

  double m_initialVirtualCapital;
  double m_currentPositionVolumeLots;

  double m_lastOpeningCapital;
  double m_lastTargetRiskMoney;
  double m_lastEstimatedLossAtStop;
  double m_lastOpenedVolumeLots;

  ENUM_PB_VIRTUAL_POSITION_STATE m_state;

  datetime m_entryTime;
  double m_entryPrice;

  datetime m_lastKnownTime;
  double m_lastKnownBid;
  double m_lastKnownAsk;

  int m_openCount;
  int m_closedTradeCount;

  int m_winningTradeCount;
  int m_losingTradeCount;
  int m_breakEvenTradeCount;

  // --------------------------------------------------
  // Maximum Favorable Excursion (MFE) des trades perdants.
  // --------------------------------------------------
  double m_maxFavorablePoints;

  int m_losingMfeTradeCount;
  int m_losingReached50Points;
  int m_losingReached100Points;
  int m_losingReached200Points;
  int m_losingReached300Points;

  // --------------------------------------------------
  // Volatilité ATR H1 observée à l'ouverture.
  // Les valeurs de la position courante sont figées
  // jusqu'à sa clôture, puis classées selon le résultat.
  // --------------------------------------------------
  bool m_currentEntryAtrValid;
  double m_currentEntryAtrPoints;
  double m_currentEntryStopLossAtr;

  int m_entryAtrValidTradeCount;
  int m_entryAtrUnavailableTradeCount;

  int m_entryAtrWinningTradeCount;
  int m_entryAtrLosingTradeCount;
  int m_entryAtrBreakEvenTradeCount;

  double m_entryAtrWinningPointsSum;
  double m_entryAtrLosingPointsSum;
  double m_entryAtrBreakEvenPointsSum;

  double m_entryStopLossAtrWinningSum;
  double m_entryStopLossAtrLosingSum;
  double m_entryStopLossAtrBreakEvenSum;

  // --------------------------------------------------
  // Statistiques des positions LONG.
  // --------------------------------------------------
  int m_longClosedTradeCount;
  int m_longWinningTradeCount;
  int m_longLosingTradeCount;
  int m_longBreakEvenTradeCount;

  double m_longTotalClosedPoints;
  double m_longTotalClosedMoney;

  double m_longGrossProfitMoney;
  double m_longGrossLossMoney;


  // --------------------------------------------------
  // Statistiques des positions SHORT.
  // --------------------------------------------------
  int m_shortClosedTradeCount;
  int m_shortWinningTradeCount;
  int m_shortLosingTradeCount;
  int m_shortBreakEvenTradeCount;

  double m_shortTotalClosedPoints;
  double m_shortTotalClosedMoney;

  double m_shortGrossProfitMoney;
  double m_shortGrossLossMoney;

  int m_reversalCount;

  int m_signalExitCount;
  int m_stopLossExitCount;
  int m_takeProfitExitCount;

  double m_totalClosedPoints;
  double m_totalClosedMoney;

  double m_grossProfitMoney;
  double m_grossLossMoney;

  double m_bestTradePoints;
  double m_worstTradePoints;

  int m_currentLosingStreak;
  int m_maxLosingStreak;

  // --------------------------------------------------
  // Bilans annuels persistants.
  // --------------------------------------------------
  SPbVirtualAnnualStatistics
    m_annualStatistics[PB_VIRTUAL_ANNUAL_STATS_CAPACITY];

  int m_annualStatisticsCount;

  // --------------------------------------------------
  // Rapport détaillé des trades clôturés.
  // --------------------------------------------------
  SPbVirtualClosedTradeRecord
    m_closedTradeRecords[PB_VIRTUAL_CLOSED_TRADES_CAPACITY];

  int m_closedTradeRecordCount;
  int m_closedTradeRecordOverflowCount;

  // --------------------------------------------------
  // Contexte complémentaire de la position courante.
  // --------------------------------------------------
  double m_currentEntrySpreadPoints;

  bool m_currentTrendContextValid;
  double m_currentTrendClose1;
  double m_currentTrendMa1;
  double m_currentTrendMa2;
  bool m_currentTrendAligned;

  double m_currentEntryTickSize;
  double m_currentEntryTickValue;
  double m_currentEntryContractSize;

  // Plus haut capital virtuel clôturé atteint.
  double m_peakVirtualCapital;

  // Drawdown maximal exprimé en devise du compte.
  double m_maxDrawdownMoney;

  // Drawdown maximal exprimé en pourcentage
  // du plus haut capital atteint.
  double m_maxDrawdownPercent;

  // Plus haute équité virtuelle observée.
  double m_peakVirtualEquity;

  // Drawdown maximal de l'équité en devise du compte.
  double m_maxEquityDrawdownMoney;

  // Drawdown maximal de l'équité en pourcentage.
  double m_maxEquityDrawdownPercent;

  // Date du sommet actuellement utilisé pour mesurer
  // le drawdown du capital clôturé.
  datetime m_currentCapitalPeakTime;

  // Période du drawdown maximal du capital.
  datetime m_maxCapitalDrawdownStartTime;
  datetime m_maxCapitalDrawdownLowTime;


  // Date du sommet actuellement utilisé pour mesurer
  // le drawdown de l'équité.
  datetime m_currentEquityPeakTime;

  // Période du drawdown maximal de l'équité.
  datetime m_maxEquityDrawdownStartTime;
  datetime m_maxEquityDrawdownLowTime;

  // --------------------------------------------------
  // Performances des sorties sur SIGNAL.
  // --------------------------------------------------
  int m_signalExitWinningCount;
  int m_signalExitLosingCount;
  int m_signalExitBreakEvenCount;

  double m_signalExitTotalPoints;
  double m_signalExitTotalMoney;

  double m_signalExitGrossProfitMoney;
  double m_signalExitGrossLossMoney;


  // --------------------------------------------------
  // Performances des sorties sur STOP LOSS.
  // --------------------------------------------------
  int m_stopLossWinningCount;
  int m_stopLossLosingCount;
  int m_stopLossBreakEvenCount;

  double m_stopLossTotalPoints;
  double m_stopLossTotalMoney;

  double m_stopLossGrossProfitMoney;
  double m_stopLossGrossLossMoney;


  // --------------------------------------------------
  // Performances des sorties sur TAKE PROFIT.
  // --------------------------------------------------
  int m_takeProfitWinningCount;
  int m_takeProfitLosingCount;
  int m_takeProfitBreakEvenCount;

  double m_takeProfitTotalPoints;
  double m_takeProfitTotalMoney;

  double m_takeProfitGrossProfitMoney;
  double m_takeProfitGrossLossMoney;

  // --------------------------------------------------
  // Croisement LONG / motif de sortie.
  // --------------------------------------------------
  int m_longSignalExitCount;
  double m_longSignalExitMoney;

  int m_longStopLossExitCount;
  double m_longStopLossExitMoney;

  int m_longTakeProfitExitCount;
  double m_longTakeProfitExitMoney;


  // --------------------------------------------------
  // Croisement SHORT / motif de sortie.
  // --------------------------------------------------
  int m_shortSignalExitCount;
  double m_shortSignalExitMoney;

  int m_shortStopLossExitCount;
  double m_shortStopLossExitMoney;

  int m_shortTakeProfitExitCount;
  double m_shortTakeProfitExitMoney;

  // --------------------------------------------------
  // Analyse détaillée des sorties SIGNAL LONG.
  // --------------------------------------------------
  int m_longSignalWinningCount;
  int m_longSignalLosingCount;

  double m_longSignalWinningMoney;
  double m_longSignalLosingMoney;


  // --------------------------------------------------
  // Analyse détaillée des sorties SIGNAL SHORT.
  // --------------------------------------------------
  int m_shortSignalWinningCount;
  int m_shortSignalLosingCount;

  double m_shortSignalWinningMoney;
  double m_shortSignalLosingMoney;

  // --------------------------------------------------
  // Pente directionnelle de la MA au moment où
  // la position courante a été ouverte.
  // --------------------------------------------------
  double m_currentEntryMaSlopePoints;

  bool m_currentPositionOpenedAfterInversion;

  // --------------------------------------------------
  // Dynamique complète de la MA au moment de
  // l'ouverture de la position courante.
  // --------------------------------------------------
  SMaDynamics m_currentEntryMaDynamics;


  // --------------------------------------------------
  // Dynamique locale M5 observée au moment de
  // l'ouverture de la position courante.
  // --------------------------------------------------
  SLocalMarketDynamics m_currentEntryLocalDynamics;

  // --------------------------------------------------
  // v1.20 - Dynamique locale M5 à l'entrée.
  //
  // Une somme et un nombre d'observations valides
  // pour chacune des quatre populations.
  // --------------------------------------------------

  SLocalMarketDynamics m_flatEntryWinningLocalDynamicsSum;
  SLocalMarketDynamics m_flatEntryLosingLocalDynamicsSum;

  SLocalMarketDynamics m_inversionEntryWinningLocalDynamicsSum;
  SLocalMarketDynamics m_inversionEntryLosingLocalDynamicsSum;

  int m_flatEntryWinningLocalDynamicsCount;
  int m_flatEntryLosingLocalDynamicsCount;

  int m_inversionEntryWinningLocalDynamicsCount;
  int m_inversionEntryLosingLocalDynamicsCount;

  // --------------------------------------------------
  // Performances des positions ouvertes après inversion.
  // --------------------------------------------------
  int m_inversionTradeClosedCount;

  int m_inversionTradeWinningCount;
  int m_inversionTradeLosingCount;
  int m_inversionTradeBreakEvenCount;

  double m_inversionTradeTotalPoints;
  double m_inversionTradeTotalMoney;

  double m_inversionTradeGrossProfitMoney;
  double m_inversionTradeGrossLossMoney;

  // --------------------------------------------------
  // Positions LONG ouvertes après inversion.
  // --------------------------------------------------
  int m_inversionLongClosedCount;
  double m_inversionLongTotalMoney;


  // --------------------------------------------------
  // Positions SHORT ouvertes après inversion.
  // --------------------------------------------------
  int m_inversionShortClosedCount;
  double m_inversionShortTotalMoney;

  // --------------------------------------------------
  // Performances des positions ouvertes depuis FLAT.
  // --------------------------------------------------
  int m_flatEntryTradeClosedCount;

  int m_flatEntryTradeWinningCount;
  int m_flatEntryTradeLosingCount;
  int m_flatEntryTradeBreakEvenCount;

  double m_flatEntryTradeTotalPoints;
  double m_flatEntryTradeTotalMoney;

  double m_flatEntryTradeGrossProfitMoney;
  double m_flatEntryTradeGrossLossMoney;


  // --------------------------------------------------
  // Positions LONG ouvertes depuis FLAT.
  // --------------------------------------------------
  int m_flatEntryLongClosedCount;
  double m_flatEntryLongTotalMoney;


  // --------------------------------------------------
  // Positions SHORT ouvertes depuis FLAT.
  // --------------------------------------------------
  int m_flatEntryShortClosedCount;
  double m_flatEntryShortTotalMoney;

  // --------------------------------------------------
  // Entrées depuis FLAT × motif de sortie.
  // --------------------------------------------------
  int m_flatEntrySignalExitCount;
  double m_flatEntrySignalExitMoney;

  int m_flatEntryStopLossExitCount;
  double m_flatEntryStopLossExitMoney;

  int m_flatEntryTakeProfitExitCount;
  double m_flatEntryTakeProfitExitMoney;


  // --------------------------------------------------
  // Entrées post-inversion × motif de sortie.
  // --------------------------------------------------
  int m_inversionEntrySignalExitCount;
  double m_inversionEntrySignalExitMoney;

  int m_inversionEntryStopLossExitCount;
  double m_inversionEntryStopLossExitMoney;

  int m_inversionEntryTakeProfitExitCount;
  double m_inversionEntryTakeProfitExitMoney;

  // --------------------------------------------------
  // v1.18 - Pente MA à l'entrée selon origine
  // et résultat du trade.
  // --------------------------------------------------

  // Entrées depuis FLAT
  double m_flatEntryWinningSlopeSum;
  double m_flatEntryLosingSlopeSum;

  // Entrées post-inversion
  double m_inversionEntryWinningSlopeSum;
  double m_inversionEntryLosingSlopeSum;

  // --------------------------------------------------
  // Répartition des résultats selon le quadrant
  // de dynamique locale à l'entrée.
  //
  // Indice 0 : non classé
  // Indice 1 : quadrant I
  // Indice 2 : quadrant II
  // Indice 3 : quadrant III
  // Indice 4 : quadrant IV
  // --------------------------------------------------
  int m_flatEntryWinningLocalQuadrantCount[5];
  int m_flatEntryLosingLocalQuadrantCount[5];

  int m_inversionEntryWinningLocalQuadrantCount[5];
  int m_inversionEntryLosingLocalQuadrantCount[5];

  double m_flatEntryLocalQuadrantMoney[5];
  double m_inversionEntryLocalQuadrantMoney[5];

  double m_flatEntryLocalQuadrantPoints[5];
  double m_inversionEntryLocalQuadrantPoints[5];

  // --------------------------------------------------
  // Croisement régime MA × quadrant local
  // pour les positions ouvertes après inversion.
  //
  // Premier indice : régime MA
  //   0 = non classé
  //   1 = +++
  //   2 = -++
  //   3 = --+
  //   4 = +-+
  //
  // Second indice : quadrant local M5
  //   0 = non classé
  //   1 = I
  //   2 = II
  //   3 = III
  //   4 = IV
  // --------------------------------------------------
  int m_inversionWinningMaRegimeLocalQuadrantCount[5][5];
  int m_inversionLosingMaRegimeLocalQuadrantCount[5][5];
  double m_inversionMaRegimeLocalQuadrantPoints[5][5];

  // --------------------------------------------------
  // Profils détaillés de deux configurations POST
  // étudiées sur 2024 / 2025 / 2026.
  //
  // H1 --+ / M5 III : configuration favorable stable.
  // H1 +++ / M5 I   : configuration défavorable stable.
  // --------------------------------------------------
  int m_inversionReversalLateQuadrantIIIProfileCount;
  SMaDynamics m_inversionReversalLateQuadrantIIIMaDynamicsSum;
  SLocalMarketDynamics m_inversionReversalLateQuadrantIIILocalDynamicsSum;

  int m_inversionReversalLateQuadrantIIIWinningProfileCount;
  SMaDynamics m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum;
  SLocalMarketDynamics m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum;

  int m_inversionReversalLateQuadrantIIILosingProfileCount;
  SMaDynamics m_inversionReversalLateQuadrantIIILosingMaDynamicsSum;
  SLocalMarketDynamics m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum;

  int m_inversionContinuationQuadrantIProfileCount;
  SMaDynamics m_inversionContinuationQuadrantIMaDynamicsSum;
  SLocalMarketDynamics m_inversionContinuationQuadrantILocalDynamicsSum;


  int m_inversionReversalLateQuadrantIIIWinningTurningTimeCount;
  double m_inversionReversalLateQuadrantIIIWinningTurningTimeMinutesSum;

  int m_inversionReversalLateQuadrantIIILosingTurningTimeCount;
  double m_inversionReversalLateQuadrantIIILosingTurningTimeMinutesSum;

  // --------------------------------------------------
  // Break-even virtuel.
  // --------------------------------------------------
  bool m_breakEvenEnabled;
  int m_breakEvenTriggerPoints;
  bool m_breakEvenActivated;

  // --------------------------------------------------
  // Verrouillage d'une partie du gain latent.
  // Exemple :
  // déclenchement à +300 points,
  // déplacement du SL à +100 points.
  // --------------------------------------------------
  bool m_profitLockEnabled;
  int m_profitLockTriggerPoints;
  int m_profitLockPoints;
  bool m_profitLockActivated;

  // ----------------------------------------------
  bool TryGetLocalTurningTimeBeforeSignalMinutes(
    const SLocalMarketDynamics &dynamics,
    double &minutesBeforeSignal) {

    minutesBeforeSignal = 0.0;

    if (!dynamics.isValid)
    return false;

    double curvature =
      dynamics.directionalCurvaturePointsPerHour2;

    if (MathAbs(curvature) < 1e-9)
    return false;

    double slope =
      dynamics.directionalSlopePointsPerHour;

    double turningTimeHours =
      -slope / curvature;

    // Étude actuelle : fenêtre locale de 60 minutes.
    // t=0 correspond au signal et t=-1 au début
    // de la fenêtre d'observation.
    if (turningTimeHours < -1.0 ||
      turningTimeHours > 0.0)
    return false;

    minutesBeforeSignal =
      -turningTimeHours * 60.0;

    return true;
  }

  // --------------------------------------------------
  // Remet à zéro une structure SMaDynamics.
  // --------------------------------------------------
  void ResetMaDynamics(SMaDynamics &dynamics) {
    dynamics.slopeEarlier = 0.0;
    dynamics.slopePrevious = 0.0;
    dynamics.slopeCurrent = 0.0;

    dynamics.accelerationPrevious = 0.0;
    dynamics.accelerationCurrent = 0.0;
  }


  // --------------------------------------------------
  // Ajoute une dynamique à un accumulateur.
  // --------------------------------------------------
  void AddMaDynamics(
    SMaDynamics &sum,
    const SMaDynamics &value) {
    sum.slopeEarlier += value.slopeEarlier;
    sum.slopePrevious += value.slopePrevious;
    sum.slopeCurrent += value.slopeCurrent;

    sum.accelerationPrevious +=
      value.accelerationPrevious;

    sum.accelerationCurrent +=
      value.accelerationCurrent;
  }

  // --------------------------------------------------
  // Construit une ligne de synthèse de la dynamique
  // locale observée à l'entrée.
  //
  // Les moyennes sont calculées uniquement sur les
  // observations M5 valides.
  // --------------------------------------------------
  string BuildLocalDynamicsAverageRow(
    const string label,
    const int tradeCount,
    const int localCount,
    const SLocalMarketDynamics &sum) const {
    double change = 0.0;
    double range = 0.0;
    double slope = 0.0;
    double curvature = 0.0;
    double rSquared = 0.0;

    if (localCount > 0) {
      double count = (double)localCount;

      change =
        sum.directionalChangePoints / count;

      range =
        sum.rangePoints / count;

      slope =
        sum.directionalSlopePointsPerHour / count;

      curvature =
        sum.directionalCurvaturePointsPerHour2 / count;

      rSquared =
        sum.quadraticRSquared / count;
    }

    return StringFormat(
      "%s : N local=%d/%d | "
      "Variation dir. moy=%.2f pts | "
      "Amplitude moy=%.2f pts | "
      "Pente dir. moy=%.2f pts/h | "
      "Courbure dir. moy=%.2f pts/h^2 | "
      "R2 moy=%.4f",
      label,
      localCount,
      tradeCount,
      change,
      range,
      slope,
      curvature,
      rSquared);
  }

  // --------------------------------------------------
  // Remise à zéro d'une dynamique locale.
  // --------------------------------------------------
  void ResetLocalMarketDynamics(
    SLocalMarketDynamics &dynamics) {
    dynamics.isValid = false;

    dynamics.directionalChangePoints = 0.0;
    dynamics.rangePoints = 0.0;

    dynamics.directionalSlopePointsPerHour = 0.0;
    dynamics.directionalCurvaturePointsPerHour2 = 0.0;

    dynamics.quadraticRSquared = 0.0;
  }


  // --------------------------------------------------
  // Ajoute une observation locale à un accumulateur.
  //
  // Retourne false si l'observation n'est pas valide.
  // --------------------------------------------------
  bool AddLocalMarketDynamics(
    SLocalMarketDynamics &sum,
    const SLocalMarketDynamics &value) {
    if (!value.isValid)
    return false;

    sum.directionalChangePoints +=
      value.directionalChangePoints;

    sum.rangePoints +=
      value.rangePoints;

    sum.directionalSlopePointsPerHour +=
      value.directionalSlopePointsPerHour;

    sum.directionalCurvaturePointsPerHour2 +=
      value.directionalCurvaturePointsPerHour2;

    sum.quadraticRSquared +=
      value.quadraticRSquared;

    sum.isValid = true;

    return true;
  }

  // --------------------------------------------------
  // Accumule les caractéristiques H1 et M5 des deux
  // configurations POST actuellement étudiées.
  // --------------------------------------------------
  void RecordSelectedInversionProfile(
    const ENUM_PB_MA_DYNAMICS_REGIME maRegime,
    const ENUM_PB_LOCAL_DYNAMICS_QUADRANT quadrant,
    const SMaDynamics &entryMaDynamics,
    const SLocalMarketDynamics &entryLocalDynamics) {

    if (!entryLocalDynamics.isValid)
    return;


    // H1 --+ / M5 III.
    if (maRegime == PB_MA_REGIME_REVERSAL_LATE &&
      quadrant == PB_LOCAL_QUADRANT_III) {

      if (AddLocalMarketDynamics(
          m_inversionReversalLateQuadrantIIILocalDynamicsSum,
          entryLocalDynamics)) {

        AddMaDynamics(
          m_inversionReversalLateQuadrantIIIMaDynamicsSum,
          entryMaDynamics);

        m_inversionReversalLateQuadrantIIIProfileCount++;
      }

      return;
    }


    // H1 +++ / M5 I.
    if (maRegime == PB_MA_REGIME_CONTINUATION &&
      quadrant == PB_LOCAL_QUADRANT_I) {

      if (AddLocalMarketDynamics(
          m_inversionContinuationQuadrantILocalDynamicsSum,
          entryLocalDynamics)) {

        AddMaDynamics(
          m_inversionContinuationQuadrantIMaDynamicsSum,
          entryMaDynamics);

        m_inversionContinuationQuadrantIProfileCount++;
      }
    }
  }
  // --------------------------------------------------
  // Construit une ligne de synthèse des moyennes
  // S2 / S1 / S0 / A1 / A0.
  // --------------------------------------------------
  string BuildMaDynamicsAverageRow(
    const string label,
    const int tradeCount,
    const SMaDynamics &sum) const {
    double s2 = 0.0;
    double s1 = 0.0;
    double s0 = 0.0;
    double a1 = 0.0;
    double a0 = 0.0;

    if (tradeCount > 0) {
      double count = (double)tradeCount;

      s2 = sum.slopeEarlier / count;
      s1 = sum.slopePrevious / count;
      s0 = sum.slopeCurrent / count;

      a1 = sum.accelerationPrevious / count;
      a0 = sum.accelerationCurrent / count;
    }

    return StringFormat(
      "%s : Trades=%d | "
      "S2=%.2f | S1=%.2f | S0=%.2f pts | "
      "A1=%.2f | A0=%.2f pts/bougie^2",
      label,
      tradeCount,
      s2,
      s1,
      s0,
      a1,
      a0);
  }


  // --------------------------------------------------
  // Ouvre une position virtuelle.
  // --------------------------------------------------
  bool OpenPosition(
    const ENUM_PB_VIRTUAL_POSITION_STATE newState,
    const datetime entryTime,
    const double entryPrice,
    const SMaDynamics &entryMaDynamics,
    const SLocalMarketDynamics &entryLocalDynamics,
    const bool openedAfterInversion,
    const bool entryAtrValid,
    const double entryAtrPoints,
    const int entryStopLossPoints,
    const int entryTakeProfitPoints,
    const int entryBreakEvenTriggerPoints,
    const double entrySpreadPoints,
    const bool entryTrendContextValid,
    const double entryTrendClose1,
    const double entryTrendMa1,
    const double entryTrendMa2,
    const bool entryTrendAligned,
    string &errorMessage) {
    errorMessage = "";

    if (!m_isInitialized) {
      errorMessage =
        "Le gestionnaire de positions virtuelles n'est pas initialisé.";

      return false;
    }

    if (m_point <= 0.0) {
      errorMessage =
        "La valeur du point du symbole est invalide.";

      return false;
    }

    if (newState != PB_VIRTUAL_POSITION_LONG &&
      newState != PB_VIRTUAL_POSITION_SHORT) {
      errorMessage =
        "État de position invalide lors de l'ouverture.";

      return false;
    }

    if (entryPrice <= 0.0) {
      errorMessage = "Prix d'entrée invalide.";

      return false;
    }

    int resolvedStopLossPoints =
      (entryStopLossPoints > 0)
      ? entryStopLossPoints
      : m_stopLossPoints;

    int resolvedTakeProfitPoints =
      (entryTakeProfitPoints > 0)
      ? entryTakeProfitPoints
      : m_takeProfitPoints;

    int resolvedBreakEvenTriggerPoints =
      (entryBreakEvenTriggerPoints > 0)
      ? entryBreakEvenTriggerPoints
      : m_breakEvenTriggerPoints;

    double stopLossPrice = 0.0;
    double takeProfitPrice = 0.0;
    ENUM_ORDER_TYPE orderType;
    m_maxFavorablePoints = 0.0;

    if (newState == PB_VIRTUAL_POSITION_LONG) {
      orderType = ORDER_TYPE_BUY;

      if (resolvedStopLossPoints > 0) {
        stopLossPrice =
          NormalizeDouble(
          entryPrice - resolvedStopLossPoints * m_point,
          m_digits);
      }

      if (resolvedTakeProfitPoints > 0) {
        takeProfitPrice =
          NormalizeDouble(
          entryPrice + resolvedTakeProfitPoints * m_point,
          m_digits);
      }
    } else {
      orderType = ORDER_TYPE_SELL;

      if (resolvedStopLossPoints > 0) {
        stopLossPrice =
          NormalizeDouble(
          entryPrice + resolvedStopLossPoints * m_point,
          m_digits);
      }

      if (resolvedTakeProfitPoints > 0) {
        takeProfitPrice =
          NormalizeDouble(
          entryPrice - resolvedTakeProfitPoints * m_point,
          m_digits);
      }
    }

    double currentVirtualCapital =
      m_initialVirtualCapital+
      m_totalClosedMoney;

    double volumeLots = 0.0;
    double targetRiskMoney = 0.0;
    double estimatedStopLoss = 0.0;

    if (!m_volumeCalculator.Calculate(
        orderType,
        currentVirtualCapital,
        entryPrice,
        stopLossPrice,
        volumeLots,
        targetRiskMoney,
        estimatedStopLoss,
        errorMessage)) {
      return false;
    }

    // Une ouverture avec un volume nul créerait un état
    // incohérent : position LONG/SHORT sans volume.
    if (volumeLots <= 0.0) {
      errorMessage = StringFormat(
        "Le calculateur de volume a renvoyé un volume invalide : %.8f | %s",
        volumeLots,
        m_volumeCalculator.BuildModeSummary());

      return false;
    }

    m_state = newState;
    m_entryTime = entryTime;
    m_entryPrice = entryPrice;

    m_currentStopLossPoints =
      resolvedStopLossPoints;

    m_currentTakeProfitPoints =
      resolvedTakeProfitPoints;

    m_currentBreakEvenTriggerPoints =
      resolvedBreakEvenTriggerPoints;

    // S0 conservé pour les statistiques v1.18 existantes.
    m_currentEntryMaSlopePoints =
      entryMaDynamics.slopeCurrent;


    // Dynamique complète de la MA à l'entrée.
    m_currentEntryMaDynamics.slopeEarlier =
      entryMaDynamics.slopeEarlier;

    m_currentEntryMaDynamics.slopePrevious =
      entryMaDynamics.slopePrevious;

    m_currentEntryMaDynamics.slopeCurrent =
      entryMaDynamics.slopeCurrent;

    m_currentEntryMaDynamics.accelerationPrevious =
      entryMaDynamics.accelerationPrevious;

    m_currentEntryMaDynamics.accelerationCurrent =
      entryMaDynamics.accelerationCurrent;

    // --------------------------------------------------
    // Photographie de la dynamique locale M5.
    // --------------------------------------------------
    m_currentEntryLocalDynamics.isValid =
      entryLocalDynamics.isValid;

    m_currentEntryLocalDynamics.directionalChangePoints =
      entryLocalDynamics.directionalChangePoints;

    m_currentEntryLocalDynamics.rangePoints =
      entryLocalDynamics.rangePoints;

    m_currentEntryLocalDynamics.directionalSlopePointsPerHour =
      entryLocalDynamics.directionalSlopePointsPerHour;

    m_currentEntryLocalDynamics.directionalCurvaturePointsPerHour2 =
      entryLocalDynamics.directionalCurvaturePointsPerHour2;

    m_currentEntryLocalDynamics.quadraticRSquared =
      entryLocalDynamics.quadraticRSquared;


    // --------------------------------------------------
    // Photographie de l'ATR à l'ouverture.
    // --------------------------------------------------
    m_currentEntryAtrValid =
      entryAtrValid &&
      entryAtrPoints > 0.0;

    m_currentEntryAtrPoints =
      m_currentEntryAtrValid
      ? entryAtrPoints
      : 0.0;

    m_currentEntryStopLossAtr = 0.0;

    if (m_currentEntryAtrValid &&
        m_currentStopLossPoints > 0) {

      m_currentEntryStopLossAtr =
        (double)m_currentStopLossPoints /
        m_currentEntryAtrPoints;
    }

    // --------------------------------------------------
    // Contexte complémentaire figé à l'ouverture.
    // --------------------------------------------------
    m_currentEntrySpreadPoints =
      (entrySpreadPoints >= 0.0)
      ? entrySpreadPoints
      : 0.0;

    m_currentTrendContextValid =
      entryTrendContextValid;

    m_currentTrendClose1 =
      entryTrendContextValid
      ? entryTrendClose1
      : 0.0;

    m_currentTrendMa1 =
      entryTrendContextValid
      ? entryTrendMa1
      : 0.0;

    m_currentTrendMa2 =
      entryTrendContextValid
      ? entryTrendMa2
      : 0.0;

    m_currentTrendAligned =
      entryTrendContextValid &&
      entryTrendAligned;

    m_currentEntryTickSize =
      SymbolInfoDouble(
        m_symbol,
        SYMBOL_TRADE_TICK_SIZE);

    m_currentEntryTickValue =
      SymbolInfoDouble(
        m_symbol,
        SYMBOL_TRADE_TICK_VALUE);

    m_currentEntryContractSize =
      SymbolInfoDouble(
        m_symbol,
        SYMBOL_TRADE_CONTRACT_SIZE);


    m_currentPositionOpenedAfterInversion =
      openedAfterInversion;

    m_stopLossPrice = stopLossPrice;
    m_takeProfitPrice = takeProfitPrice;

    m_currentPositionVolumeLots = volumeLots;

    m_lastOpeningCapital = currentVirtualCapital;
    m_lastTargetRiskMoney = targetRiskMoney;
    m_lastEstimatedLossAtStop = estimatedStopLoss;
    m_lastOpenedVolumeLots = volumeLots;

    m_breakEvenActivated = false;
    m_profitLockActivated = false;

    m_openCount++;

    return true;
  }


  // --------------------------------------------------
  // Résume le dimensionnement de la dernière position.
  // --------------------------------------------------
  string BuildLastOpeningVolumeSummary(void) const {
    string result = StringFormat(
      "Volume=%s lot(s) | "
      "Capital virtuel=%.*f %s",

      m_volumeCalculator.FormatVolume(
        m_lastOpenedVolumeLots),

      m_accountCurrencyDigits,
      m_lastOpeningCapital,

      m_accountCurrency);

    result += StringFormat(
      " | Protections=SL %d pts / TP %d pts",
      m_currentStopLossPoints,
      m_currentTakeProfitPoints);

    if (m_breakEvenEnabled &&
        m_currentBreakEvenTriggerPoints > 0) {

      result += StringFormat(
        " | BE à +%d pts",
        m_currentBreakEvenTriggerPoints);
    }

    if (m_lastTargetRiskMoney > 0.0) {
      result += StringFormat(
        " | Risque cible=%.*f %s",

        m_accountCurrencyDigits,
        m_lastTargetRiskMoney,

        m_accountCurrency);
    }

    if (m_lastEstimatedLossAtStop > 0.0) {
      result += StringFormat(
        " | Perte estimée au SL=%.*f %s",

        m_accountCurrencyDigits,
        m_lastEstimatedLossAtStop,

        m_accountCurrency);
    }

    return result;
  }


  // --------------------------------------------------
  // Calcule le résultat monétaire d'une position.
  // --------------------------------------------------
  bool CalculateMoneyResult(
    const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
    const double openPrice,
    const double closePrice,
    double &resultMoney,
    string &errorMessage) const {
    resultMoney = 0.0;
    errorMessage = "";

    if (!m_isInitialized) {
      errorMessage =
        "Le gestionnaire de positions virtuelles n'est pas initialisé.";

      return false;
    }

    if (openPrice <= 0.0 || closePrice <= 0.0) {
      errorMessage = StringFormat(
        "Prix invalide pour le calcul monétaire | Ouverture=%.*f | Fermeture=%.*f",
        m_digits,
        openPrice,
        m_digits,
        closePrice);

      return false;
    }

    if (m_currentPositionVolumeLots <= 0.0) {
      errorMessage =
        "Le volume de la position virtuelle est invalide.";

      return false;
    }

    ENUM_ORDER_TYPE orderType;

    if (positionState == PB_VIRTUAL_POSITION_LONG) {
      orderType = ORDER_TYPE_BUY;
    } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
      orderType = ORDER_TYPE_SELL;
    } else {
      errorMessage =
        "Calcul monétaire impossible : "
      "aucune position n'est ouverte.";

      return false;
    }

    ResetLastError();

    if (!OrderCalcProfit(
        orderType,
        m_symbol,
        m_currentPositionVolumeLots,
        openPrice,
        closePrice,
        resultMoney)) {
      int errorCode = GetLastError();

      errorMessage = StringFormat(
        "OrderCalcProfit a échoué | "
        "Position=%s | Volume=%s | "
        "Ouverture=%.*f | Fermeture=%.*f | "
        "Erreur=%d",

        VirtualPositionStateToString(
          positionState),

        m_volumeCalculator.FormatVolume(
          m_currentPositionVolumeLots),

        m_digits,
        openPrice,

        m_digits,
        closePrice,

        errorCode);

      return false;
    }

    return true;
  }

  // --------------------------------------------------
  // Extrait l'année civile d'un horodatage.
  // --------------------------------------------------
  int ExtractYear(
    const datetime value) const {

    if (value <= 0)
      return 0;

    MqlDateTime parts;

    if (!TimeToStruct(
        value,
        parts)) {
      return 0;
    }

    return parts.year;
  }


  // --------------------------------------------------
  // Initialise une ligne de statistiques annuelles.
  // --------------------------------------------------
  void InitializeAnnualStatistics(
    const int index,
    const int year,
    const datetime observationTime,
    const double currentCapital,
    const double currentEquity) {

    m_annualStatistics[index].year = year;

    m_annualStatistics[index].firstObservedTime =
      observationTime;

    m_annualStatistics[index].lastObservedTime =
      observationTime;

    m_annualStatistics[index].closedTradeCount = 0;
    m_annualStatistics[index].winningTradeCount = 0;
    m_annualStatistics[index].losingTradeCount = 0;
    m_annualStatistics[index].breakEvenTradeCount = 0;

    m_annualStatistics[index].currentLosingStreak = 0;
    m_annualStatistics[index].maxLosingStreak = 0;

    m_annualStatistics[index].totalClosedPoints = 0.0;
    m_annualStatistics[index].grossProfitMoney = 0.0;
    m_annualStatistics[index].grossLossMoney = 0.0;
    m_annualStatistics[index].totalClosedMoney = 0.0;

    m_annualStatistics[index].startCapital =
      currentCapital;

    m_annualStatistics[index].endCapital =
      currentCapital;

    m_annualStatistics[index].peakCapital =
      currentCapital;

    m_annualStatistics[index].maxCapitalDrawdownMoney = 0.0;
    m_annualStatistics[index].maxCapitalDrawdownPercent = 0.0;

    m_annualStatistics[index].peakEquity =
      currentEquity;

    m_annualStatistics[index].maxEquityDrawdownMoney = 0.0;
    m_annualStatistics[index].maxEquityDrawdownPercent = 0.0;
  }


  // --------------------------------------------------
  // Recherche l'index correspondant à une année.
  // --------------------------------------------------
  int FindAnnualStatisticsIndex(
    const int year) const {

    for (int index = 0;
      index < m_annualStatisticsCount;
      index++) {

      if (m_annualStatistics[index].year == year)
        return index;
    }

    return -1;
  }


  // --------------------------------------------------
  // Retourne la ligne annuelle existante ou la crée.
  // --------------------------------------------------
  int GetOrCreateAnnualStatisticsIndex(
    const datetime observationTime,
    const double currentCapital,
    const double currentEquity) {

    int year =
      ExtractYear(
        observationTime);

    if (year <= 0)
      return -1;

    int existingIndex =
      FindAnnualStatisticsIndex(
        year);

    if (existingIndex >= 0)
      return existingIndex;

    if (m_annualStatisticsCount >=
        PB_VIRTUAL_ANNUAL_STATS_CAPACITY) {
      return -1;
    }

    int newIndex =
      m_annualStatisticsCount;

    m_annualStatisticsCount++;

    InitializeAnnualStatistics(
      newIndex,
      year,
      observationTime,
      currentCapital,
      currentEquity);

    return newIndex;
  }


  // --------------------------------------------------
  // Met à jour les drawdowns annuels de capital
  // et d'équité à partir d'une observation courante.
  // --------------------------------------------------
  void UpdateAnnualDrawdowns(
    const datetime observationTime,
    const double currentCapital,
    const double currentEquity) {

    int index =
      GetOrCreateAnnualStatisticsIndex(
        observationTime,
        currentCapital,
        currentEquity);

    if (index < 0)
      return;

    m_annualStatistics[index].lastObservedTime =
      observationTime;

    m_annualStatistics[index].endCapital =
      currentCapital;

    if (currentCapital >
        m_annualStatistics[index].peakCapital) {

      m_annualStatistics[index].peakCapital =
        currentCapital;
    }

    double capitalDrawdownMoney =
      m_annualStatistics[index].peakCapital-
      currentCapital;

    if (capitalDrawdownMoney < 0.0)
      capitalDrawdownMoney = 0.0;

    double capitalDrawdownPercent = 0.0;

    if (m_annualStatistics[index].peakCapital > 0.0) {
      capitalDrawdownPercent =
        capitalDrawdownMoney/
        m_annualStatistics[index].peakCapital*
        100.0;
    }

    if (capitalDrawdownMoney >
        m_annualStatistics[index].maxCapitalDrawdownMoney) {

      m_annualStatistics[index].maxCapitalDrawdownMoney =
        capitalDrawdownMoney;

      m_annualStatistics[index].maxCapitalDrawdownPercent =
        capitalDrawdownPercent;
    }

    if (currentEquity >
        m_annualStatistics[index].peakEquity) {

      m_annualStatistics[index].peakEquity =
        currentEquity;
    }

    double equityDrawdownMoney =
      m_annualStatistics[index].peakEquity-
      currentEquity;

    if (equityDrawdownMoney < 0.0)
      equityDrawdownMoney = 0.0;

    double equityDrawdownPercent = 0.0;

    if (m_annualStatistics[index].peakEquity > 0.0) {
      equityDrawdownPercent =
        equityDrawdownMoney/
        m_annualStatistics[index].peakEquity*
        100.0;
    }

    if (equityDrawdownMoney >
        m_annualStatistics[index].maxEquityDrawdownMoney) {

      m_annualStatistics[index].maxEquityDrawdownMoney =
        equityDrawdownMoney;

      m_annualStatistics[index].maxEquityDrawdownPercent =
        equityDrawdownPercent;
    }
  }


  // --------------------------------------------------
  // Enregistre un trade dans son année de clôture.
  // --------------------------------------------------
  void RecordAnnualClosedTrade(
    const datetime exitTime,
    const double resultPoints,
    const double resultMoney,
    const double capitalBeforeTrade,
    const double capitalAfterTrade) {

    int index =
      GetOrCreateAnnualStatisticsIndex(
        exitTime,
        capitalBeforeTrade,
        capitalBeforeTrade);

    if (index < 0)
      return;

    m_annualStatistics[index].closedTradeCount++;

    m_annualStatistics[index].totalClosedPoints +=
      resultPoints;

    m_annualStatistics[index].totalClosedMoney +=
      resultMoney;

    if (resultPoints > 0.0) {
      m_annualStatistics[index].winningTradeCount++;

      m_annualStatistics[index].grossProfitMoney +=
        resultMoney;

      m_annualStatistics[index].currentLosingStreak = 0;
    } else if (resultPoints < 0.0) {
      m_annualStatistics[index].losingTradeCount++;

      m_annualStatistics[index].grossLossMoney +=
        MathAbs(
          resultMoney);

      m_annualStatistics[index].currentLosingStreak++;

      if (m_annualStatistics[index].currentLosingStreak >
          m_annualStatistics[index].maxLosingStreak) {

        m_annualStatistics[index].maxLosingStreak =
          m_annualStatistics[index].currentLosingStreak;
      }
    } else {
      m_annualStatistics[index].breakEvenTradeCount++;
      m_annualStatistics[index].currentLosingStreak = 0;
    }

    UpdateAnnualDrawdowns(
      exitTime,
      capitalAfterTrade,
      capitalAfterTrade);
  }


  // --------------------------------------------------
  // Nettoie une valeur textuelle destinée au CSV.
  // --------------------------------------------------
  string SanitizeCsvValue(
    const string value) const {

    string result = value;

    StringReplace(
      result,
      ";",
      ",");

    StringReplace(
      result,
      "\r",
      " ");

    StringReplace(
      result,
      "\n",
      " ");

    return result;
  }


  // --------------------------------------------------
  // Met à jour le drawdown de l'équité virtuelle.
  //
  // Équité virtuelle :
  //   capital initial
  //   + résultats clôturés
  //   + résultat latent de la position ouverte
  // --------------------------------------------------
  bool UpdateEquityDrawdown(
    const datetime tickTime,
    const double bid,
    const double ask,
    string &errorMessage) {
    errorMessage = "";

    if (!m_isInitialized) {
      errorMessage =
        "Le gestionnaire de positions virtuelles n'est pas initialisé.";

      return false;
    }

    double currentVirtualEquity =
      m_initialVirtualCapital+
      m_totalClosedMoney;


    // ------------------------------------------------
    // Ajout du résultat latent lorsqu'une position
    // virtuelle est ouverte.
    // ------------------------------------------------
    if (m_state != PB_VIRTUAL_POSITION_FLAT) {
      double theoreticalExitPrice =
        (m_state == PB_VIRTUAL_POSITION_LONG)
        ? bid
        : ask;

      double latentMoney = 0.0;

      if (!CalculateMoneyResult(
          m_state,
          m_entryPrice,
          theoreticalExitPrice,
          latentMoney,
          errorMessage)) {
        return false;
      }

      currentVirtualEquity += latentMoney;
    }


    // ------------------------------------------------
    // Nouveau sommet d'équité.
    // ------------------------------------------------
    if (currentVirtualEquity > m_peakVirtualEquity) {
      m_peakVirtualEquity =
        currentVirtualEquity;

      m_currentEquityPeakTime =
        tickTime;
    }

    // ------------------------------------------------
    // Drawdown courant depuis le sommet de l'équité.
    // ------------------------------------------------
    double currentDrawdownMoney =
      m_peakVirtualEquity-
      currentVirtualEquity;

    if (currentDrawdownMoney < 0.0)
    currentDrawdownMoney = 0.0;


    double currentDrawdownPercent = 0.0;

    if (m_peakVirtualEquity > 0.0) {
      currentDrawdownPercent =
        currentDrawdownMoney/
        m_peakVirtualEquity*
        100.0;
    }


    // ------------------------------------------------
    // Conservation du pire drawdown observé.
    // ------------------------------------------------
    if (currentDrawdownMoney >
      m_maxEquityDrawdownMoney) {
      m_maxEquityDrawdownMoney =
        currentDrawdownMoney;

      m_maxEquityDrawdownPercent =
        currentDrawdownPercent;

      m_maxEquityDrawdownStartTime =
        m_currentEquityPeakTime;

      m_maxEquityDrawdownLowTime =
        tickTime;
    }

    double currentVirtualCapital =
      m_initialVirtualCapital+
      m_totalClosedMoney;

    UpdateAnnualDrawdowns(
      tickTime,
      currentVirtualCapital,
      currentVirtualEquity);

    return true;
  }

  // --------------------------------------------------
  // Enregistre le résultat selon l'origine de l'entrée
  // et le motif de sortie.
  // --------------------------------------------------
  void RecordEntryOriginExitPerformance(
    const bool openedAfterInversion,
    const ENUM_PB_VIRTUAL_EXIT_REASON exitReason,
    const double resultMoney) {
    // ==================================================
    // POSITION OUVERTE APRÈS INVERSION
    // ==================================================
    if (openedAfterInversion) {
      if (exitReason == PB_VIRTUAL_EXIT_SIGNAL) {
        m_inversionEntrySignalExitCount++;
        m_inversionEntrySignalExitMoney += resultMoney;
      } else if (exitReason == PB_VIRTUAL_EXIT_STOP_LOSS) {
        m_inversionEntryStopLossExitCount++;
        m_inversionEntryStopLossExitMoney += resultMoney;
      } else if (exitReason == PB_VIRTUAL_EXIT_TAKE_PROFIT) {
        m_inversionEntryTakeProfitExitCount++;
        m_inversionEntryTakeProfitExitMoney += resultMoney;
      }

      return;
    }


    // ==================================================
    // POSITION OUVERTE DEPUIS FLAT
    // ==================================================
    if (exitReason == PB_VIRTUAL_EXIT_SIGNAL) {
      m_flatEntrySignalExitCount++;
      m_flatEntrySignalExitMoney += resultMoney;
    } else if (exitReason == PB_VIRTUAL_EXIT_STOP_LOSS) {
      m_flatEntryStopLossExitCount++;
      m_flatEntryStopLossExitMoney += resultMoney;
    } else if (exitReason == PB_VIRTUAL_EXIT_TAKE_PROFIT) {
      m_flatEntryTakeProfitExitCount++;
      m_flatEntryTakeProfitExitMoney += resultMoney;
    }
  }



  // --------------------------------------------------
  // Enregistre les performances selon le motif
  // de clôture et le sens de la position.
  // --------------------------------------------------
  void RecordExitPerformance(
    const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
    const bool openedAfterInversion,
    const ENUM_PB_VIRTUAL_EXIT_REASON exitReason,
    const double resultPoints,
    const double resultMoney) {

    RecordEntryOriginExitPerformance(
      openedAfterInversion,
      exitReason,
      resultMoney);

    // ==================================================
    // SORTIE SUR SIGNAL
    // ==================================================
    if (exitReason == PB_VIRTUAL_EXIT_SIGNAL) {
      m_signalExitTotalPoints += resultPoints;
      m_signalExitTotalMoney += resultMoney;

      if (resultPoints > 0.0) {
        m_signalExitWinningCount++;
        m_signalExitGrossProfitMoney += resultMoney;
      } else if (resultPoints < 0.0) {
        m_signalExitLosingCount++;
        m_signalExitGrossLossMoney += MathAbs(resultMoney);
      } else {
        m_signalExitBreakEvenCount++;
      }


      // --------------------------------------------------
      // Croisement sens × motif SIGNAL,
      // avec détail gagnant / perdant.
      // --------------------------------------------------
      if (positionState == PB_VIRTUAL_POSITION_LONG) {
        m_longSignalExitCount++;
        m_longSignalExitMoney += resultMoney;

        if (resultPoints > 0.0) {
          m_longSignalWinningCount++;
          m_longSignalWinningMoney += resultMoney;
        } else if (resultPoints < 0.0) {
          m_longSignalLosingCount++;
          m_longSignalLosingMoney += MathAbs(resultMoney);
        }
      } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
        m_shortSignalExitCount++;
        m_shortSignalExitMoney += resultMoney;

        if (resultPoints > 0.0) {
          m_shortSignalWinningCount++;
          m_shortSignalWinningMoney += resultMoney;
        } else if (resultPoints < 0.0) {
          m_shortSignalLosingCount++;
          m_shortSignalLosingMoney += MathAbs(resultMoney);
        }
      }
      return;
    }


    // ==================================================
    // SORTIE SUR STOP LOSS
    // ==================================================
    if (exitReason == PB_VIRTUAL_EXIT_STOP_LOSS) {
      m_stopLossTotalPoints += resultPoints;
      m_stopLossTotalMoney += resultMoney;

      if (resultPoints > 0.0) {
        m_stopLossWinningCount++;
        m_stopLossGrossProfitMoney += resultMoney;
      } else if (resultPoints < 0.0) {
        m_stopLossLosingCount++;
        m_stopLossGrossLossMoney += MathAbs(resultMoney);
      } else {
        m_stopLossBreakEvenCount++;
      }


      // Croisement sens × motif.
      if (positionState == PB_VIRTUAL_POSITION_LONG) {
        m_longStopLossExitCount++;
        m_longStopLossExitMoney += resultMoney;
      } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
        m_shortStopLossExitCount++;
        m_shortStopLossExitMoney += resultMoney;
      }

      return;
    }


    // ==================================================
    // SORTIE SUR TAKE PROFIT
    // ==================================================
    if (exitReason == PB_VIRTUAL_EXIT_TAKE_PROFIT) {
      m_takeProfitTotalPoints += resultPoints;
      m_takeProfitTotalMoney += resultMoney;

      if (resultPoints > 0.0) {
        m_takeProfitWinningCount++;
        m_takeProfitGrossProfitMoney += resultMoney;
      } else if (resultPoints < 0.0) {
        m_takeProfitLosingCount++;
        m_takeProfitGrossLossMoney += MathAbs(resultMoney);
      } else {
        m_takeProfitBreakEvenCount++;
      }


      // Croisement sens × motif.
      if (positionState == PB_VIRTUAL_POSITION_LONG) {
        m_longTakeProfitExitCount++;
        m_longTakeProfitExitMoney += resultMoney;
      } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
        m_shortTakeProfitExitCount++;
        m_shortTakeProfitExitMoney += resultMoney;
      }
    }
  }

  // --------------------------------------------------
  // Enregistre le résultat d'une position qui avait
  // été ouverte à la suite d'une inversion.
  // --------------------------------------------------
  void RecordInversionTradePerformance(
    const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
    const double resultPoints,
    const double resultMoney,
    const SMaDynamics &entryMaDynamics,
    const SLocalMarketDynamics &entryLocalDynamics) {

    m_inversionTradeClosedCount++;

    m_inversionTradeTotalPoints += resultPoints;
    m_inversionTradeTotalMoney += resultMoney;


    if (resultPoints > 0.0) {
      m_inversionTradeWinningCount++;
      m_inversionTradeGrossProfitMoney += resultMoney;
      m_inversionEntryWinningSlopeSum +=
        entryMaDynamics.slopeCurrent;

      AddMaDynamics(
        m_inversionEntryWinningDynamicsSum,
        entryMaDynamics);

      if (AddLocalMarketDynamics(
          m_inversionEntryWinningLocalDynamicsSum,
          entryLocalDynamics)) {

        m_inversionEntryWinningLocalDynamicsCount++;

        ENUM_PB_LOCAL_DYNAMICS_QUADRANT quadrant =
          DetermineLocalDynamicsQuadrant(
          entryLocalDynamics);

        m_inversionEntryWinningLocalQuadrantCount[
          (int)quadrant]++;

        m_inversionEntryLocalQuadrantMoney[
          (int)quadrant] += resultMoney;

        m_inversionEntryLocalQuadrantPoints[
          (int)quadrant] += resultPoints;

        ENUM_PB_MA_DYNAMICS_REGIME maRegime =
          DetermineMaDynamicsRegime(
          entryMaDynamics);

        m_inversionWinningMaRegimeLocalQuadrantCount[
          (int)maRegime][
          (int)quadrant]++;

        m_inversionMaRegimeLocalQuadrantPoints[
          (int)maRegime][
          (int)quadrant] += resultPoints;

        RecordSelectedInversionProfile(
          maRegime,
          quadrant,
          entryMaDynamics,
          entryLocalDynamics);

        if (maRegime == PB_MA_REGIME_REVERSAL_LATE &&
          quadrant == PB_LOCAL_QUADRANT_III) {

          if (AddLocalMarketDynamics(
              m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum,
              entryLocalDynamics)) {

            AddMaDynamics(
              m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum,
              entryMaDynamics);

            m_inversionReversalLateQuadrantIIIWinningProfileCount++;

            double turningTimeMinutes = 0.0;

            if (TryGetLocalTurningTimeBeforeSignalMinutes(
                entryLocalDynamics,
                turningTimeMinutes)) {

              m_inversionReversalLateQuadrantIIIWinningTurningTimeMinutesSum +=
                turningTimeMinutes;

              m_inversionReversalLateQuadrantIIIWinningTurningTimeCount++;
            }
          }
        }
      }

    } else if (resultPoints < 0.0) {
      m_inversionTradeLosingCount++;
      m_inversionTradeGrossLossMoney += MathAbs(resultMoney);
      m_inversionEntryLosingSlopeSum +=
        entryMaDynamics.slopeCurrent;

      AddMaDynamics(
        m_inversionEntryLosingDynamicsSum,
        entryMaDynamics);

      if (AddLocalMarketDynamics(
          m_inversionEntryLosingLocalDynamicsSum,
          entryLocalDynamics)) {

        m_inversionEntryLosingLocalDynamicsCount++;

        ENUM_PB_LOCAL_DYNAMICS_QUADRANT quadrant =
          DetermineLocalDynamicsQuadrant(
          entryLocalDynamics);

        m_inversionEntryLosingLocalQuadrantCount[
          (int)quadrant]++;

        m_inversionEntryLocalQuadrantMoney[
          (int)quadrant] += resultMoney;

        m_inversionEntryLocalQuadrantPoints[
          (int)quadrant] += resultPoints;

        ENUM_PB_MA_DYNAMICS_REGIME maRegime =
          DetermineMaDynamicsRegime(
          entryMaDynamics);

        m_inversionLosingMaRegimeLocalQuadrantCount[
          (int)maRegime][
          (int)quadrant]++;

        m_inversionMaRegimeLocalQuadrantPoints[
          (int)maRegime][
          (int)quadrant] += resultPoints;

        RecordSelectedInversionProfile(
          maRegime,
          quadrant,
          entryMaDynamics,
          entryLocalDynamics);

        if (maRegime == PB_MA_REGIME_REVERSAL_LATE &&
          quadrant == PB_LOCAL_QUADRANT_III) {

          if (AddLocalMarketDynamics(
              m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum,
              entryLocalDynamics)) {

            AddMaDynamics(
              m_inversionReversalLateQuadrantIIILosingMaDynamicsSum,
              entryMaDynamics);

            m_inversionReversalLateQuadrantIIILosingProfileCount++;

            double turningTimeMinutes = 0.0;

            if (TryGetLocalTurningTimeBeforeSignalMinutes(
                entryLocalDynamics,
                turningTimeMinutes)) {

              m_inversionReversalLateQuadrantIIILosingTurningTimeMinutesSum +=
                turningTimeMinutes;

              m_inversionReversalLateQuadrantIIILosingTurningTimeCount++;
            }
          }
        }
      }

    } else {
      m_inversionTradeBreakEvenCount++;
    }


    if (positionState == PB_VIRTUAL_POSITION_LONG) {
      m_inversionLongClosedCount++;
      m_inversionLongTotalMoney += resultMoney;

    } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
      m_inversionShortClosedCount++;
      m_inversionShortTotalMoney += resultMoney;
    }
  }
  // --------------------------------------------------
  // Enregistre le résultat d'une position qui avait
  // été ouverte depuis l'état FLAT.
  // --------------------------------------------------
  void RecordFlatEntryTradePerformance(
    const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
    const double resultPoints,
    const double resultMoney,
    const SMaDynamics &entryMaDynamics,
    const SLocalMarketDynamics &entryLocalDynamics) {
    m_flatEntryTradeClosedCount++;

    m_flatEntryTradeTotalPoints += resultPoints;
    m_flatEntryTradeTotalMoney += resultMoney;


    if (resultPoints > 0.0) {
      m_flatEntryTradeWinningCount++;
      m_flatEntryTradeGrossProfitMoney += resultMoney;

      // Ancienne statistique S0 conservée.
      m_flatEntryWinningSlopeSum +=
        entryMaDynamics.slopeCurrent;

      // Nouvelle dynamique complète.
      AddMaDynamics(
        m_flatEntryWinningDynamicsSum,
        entryMaDynamics);
      if (AddLocalMarketDynamics(
          m_flatEntryWinningLocalDynamicsSum,
          entryLocalDynamics)) {
        m_flatEntryWinningLocalDynamicsCount++;

        ENUM_PB_LOCAL_DYNAMICS_QUADRANT quadrant =
          DetermineLocalDynamicsQuadrant(
          entryLocalDynamics);

        m_flatEntryWinningLocalQuadrantCount[
          (int)quadrant]++;

        m_flatEntryLocalQuadrantMoney[
          (int)quadrant] += resultMoney;

        m_flatEntryLocalQuadrantPoints[
          (int)quadrant] += resultPoints;

      }
    } else if (resultPoints < 0.0) {
      m_flatEntryTradeLosingCount++;
      m_flatEntryTradeGrossLossMoney += MathAbs(resultMoney);

      m_flatEntryLosingSlopeSum +=
        entryMaDynamics.slopeCurrent;

      AddMaDynamics(
        m_flatEntryLosingDynamicsSum,
        entryMaDynamics);

      if (AddLocalMarketDynamics(
          m_flatEntryLosingLocalDynamicsSum,
          entryLocalDynamics)) {
        m_flatEntryLosingLocalDynamicsCount++;

        ENUM_PB_LOCAL_DYNAMICS_QUADRANT quadrant =
          DetermineLocalDynamicsQuadrant(
          entryLocalDynamics);

        m_flatEntryLosingLocalQuadrantCount[
          (int)quadrant]++;

        m_flatEntryLocalQuadrantMoney[
          (int)quadrant] += resultMoney;

        m_flatEntryLocalQuadrantPoints[
          (int)quadrant] += resultPoints;

      }
    } else {
      m_flatEntryTradeBreakEvenCount++;
    }

    if (positionState == PB_VIRTUAL_POSITION_LONG) {
      m_flatEntryLongClosedCount++;
      m_flatEntryLongTotalMoney += resultMoney;
    } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
      m_flatEntryShortClosedCount++;
      m_flatEntryShortTotalMoney += resultMoney;
    }
  }


  // --------------------------------------------------
  // Enregistre le résultat d'un trade clôturé.
  // --------------------------------------------------
  void RecordClosedTrade(
    const datetime exitTime,
    const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
    const double resultPoints,
    const double resultMoney) {

    double capitalBeforeTrade =
      m_initialVirtualCapital+
      m_totalClosedMoney;

    double capitalAfterTrade =
      capitalBeforeTrade+
      resultMoney;

    RecordAnnualClosedTrade(
      exitTime,
      resultPoints,
      resultMoney,
      capitalBeforeTrade,
      capitalAfterTrade);

    m_closedTradeCount++;

    m_totalClosedPoints += resultPoints;
    m_totalClosedMoney += resultMoney;

    // --------------------------------------------------
    // Mise à jour du capital virtuel après clôture.
    // --------------------------------------------------
    double currentVirtualCapital =
      m_initialVirtualCapital+
      m_totalClosedMoney;


    if (currentVirtualCapital > m_peakVirtualCapital) {
      m_peakVirtualCapital =
        currentVirtualCapital;

      m_currentCapitalPeakTime =
        exitTime;
    }

    // Le capital est sous son précédent sommet.
    double currentDrawdownMoney =
      m_peakVirtualCapital-
      currentVirtualCapital;

    if (currentDrawdownMoney < 0.0)
    currentDrawdownMoney = 0.0;


    double currentDrawdownPercent = 0.0;

    if (m_peakVirtualCapital > 0.0) {
      currentDrawdownPercent =
        currentDrawdownMoney/
        m_peakVirtualCapital*
        100.0;
    }

    // Conservation du pire drawdown observé.
    if (currentDrawdownMoney > m_maxDrawdownMoney) {
      m_maxDrawdownMoney =
        currentDrawdownMoney;

      m_maxDrawdownPercent =
        currentDrawdownPercent;

      m_maxCapitalDrawdownStartTime =
        m_currentCapitalPeakTime;

      m_maxCapitalDrawdownLowTime =
        exitTime;
    }

    if (resultPoints > 0.0) {
      m_winningTradeCount++;

      m_grossProfitMoney += resultMoney;

      // Un trade gagnant interrompt la série de pertes.
      m_currentLosingStreak = 0;
    } else if (resultPoints < 0.0) {
      m_losingTradeCount++;

      m_grossLossMoney += MathAbs(resultMoney);

      // La série de pertes se poursuit.
      m_currentLosingStreak++;

      if (m_currentLosingStreak > m_maxLosingStreak) {
        m_maxLosingStreak =
          m_currentLosingStreak;
      }
    } else {
      m_breakEvenTradeCount++;

      // Un trade neutre interrompt également la série.
      m_currentLosingStreak = 0;
    }

    // --------------------------------------------------
    // Statistiques selon le sens de la position clôturée.
    // --------------------------------------------------
    if (positionState == PB_VIRTUAL_POSITION_LONG) {
      m_longClosedTradeCount++;

      m_longTotalClosedPoints += resultPoints;
      m_longTotalClosedMoney += resultMoney;

      if (resultPoints > 0.0) {
        m_longWinningTradeCount++;
        m_longGrossProfitMoney += resultMoney;
      } else if (resultPoints < 0.0) {
        m_longLosingTradeCount++;
        m_longGrossLossMoney += MathAbs(resultMoney);
      } else {
        m_longBreakEvenTradeCount++;
      }
    } else if (positionState == PB_VIRTUAL_POSITION_SHORT) {
      m_shortClosedTradeCount++;

      m_shortTotalClosedPoints += resultPoints;
      m_shortTotalClosedMoney += resultMoney;

      if (resultPoints > 0.0) {
        m_shortWinningTradeCount++;
        m_shortGrossProfitMoney += resultMoney;
      } else if (resultPoints < 0.0) {
        m_shortLosingTradeCount++;
        m_shortGrossLossMoney += MathAbs(resultMoney);
      } else {
        m_shortBreakEvenTradeCount++;
      }
    }

    if (m_closedTradeCount == 1) {
      m_bestTradePoints = resultPoints;
      m_worstTradePoints = resultPoints;
    } else {
      if (resultPoints > m_bestTradePoints)
      m_bestTradePoints = resultPoints;

      if (resultPoints < m_worstTradePoints)
      m_worstTradePoints = resultPoints;
    }
  }


  // --------------------------------------------------
  // Enregistre le MFE d'un trade qui termine en perte.
  // Les seuils sont cumulatifs.
  // --------------------------------------------------
  void RecordLosingTradeMfe(
    const double resultPoints) {

    if (resultPoints >= 0.0)
      return;

    m_losingMfeTradeCount++;

    if (m_maxFavorablePoints >= 50.0)
      m_losingReached50Points++;

    if (m_maxFavorablePoints >= 100.0)
      m_losingReached100Points++;

    if (m_maxFavorablePoints >= 200.0)
      m_losingReached200Points++;

    if (m_maxFavorablePoints >= 300.0)
      m_losingReached300Points++;
  }


  // --------------------------------------------------
  // Enregistre l'ATR observé à l'ouverture du trade
  // qui vient d'être clôturé.
  // --------------------------------------------------
  void RecordEntryAtrPerformance(
    const double resultPoints) {

    if (!m_currentEntryAtrValid ||
        m_currentEntryAtrPoints <= 0.0) {

      m_entryAtrUnavailableTradeCount++;
      return;
    }

    m_entryAtrValidTradeCount++;

    if (resultPoints > 0.0) {
      m_entryAtrWinningTradeCount++;

      m_entryAtrWinningPointsSum +=
        m_currentEntryAtrPoints;

      m_entryStopLossAtrWinningSum +=
        m_currentEntryStopLossAtr;
    } else if (resultPoints < 0.0) {
      m_entryAtrLosingTradeCount++;

      m_entryAtrLosingPointsSum +=
        m_currentEntryAtrPoints;

      m_entryStopLossAtrLosingSum +=
        m_currentEntryStopLossAtr;
    } else {
      m_entryAtrBreakEvenTradeCount++;

      m_entryAtrBreakEvenPointsSum +=
        m_currentEntryAtrPoints;

      m_entryStopLossAtrBreakEvenSum +=
        m_currentEntryStopLossAtr;
    }
  }


  // --------------------------------------------------
  // Enregistre une ligne détaillée pour le trade clôturé.
  // --------------------------------------------------
  void RecordClosedTradeReport(
    const datetime exitTime,
    const double exitPrice,
    const ENUM_PB_VIRTUAL_EXIT_REASON exitReason,
    const double resultPoints,
    const double resultMoney) {

    if (m_closedTradeRecordCount >=
        PB_VIRTUAL_CLOSED_TRADES_CAPACITY) {

      m_closedTradeRecordOverflowCount++;
      return;
    }

    int index = m_closedTradeRecordCount;

    double initialStopLossPrice = 0.0;
    double initialTakeProfitPrice = 0.0;

    if (m_currentStopLossPoints > 0) {
      if (m_state == PB_VIRTUAL_POSITION_LONG) {
        initialStopLossPrice =
          NormalizeDouble(
            m_entryPrice -
            m_currentStopLossPoints * m_point,
            m_digits);
      } else {
        initialStopLossPrice =
          NormalizeDouble(
            m_entryPrice +
            m_currentStopLossPoints * m_point,
            m_digits);
      }
    }

    if (m_currentTakeProfitPoints > 0) {
      if (m_state == PB_VIRTUAL_POSITION_LONG) {
        initialTakeProfitPrice =
          NormalizeDouble(
            m_entryPrice +
            m_currentTakeProfitPoints * m_point,
            m_digits);
      } else {
        initialTakeProfitPrice =
          NormalizeDouble(
            m_entryPrice -
            m_currentTakeProfitPoints * m_point,
            m_digits);
      }
    }

    double resultRPoints = 0.0;

    if (m_currentStopLossPoints > 0) {
      resultRPoints =
        resultPoints /
        (double)m_currentStopLossPoints;
    }

    double resultRMoney = 0.0;

    if (m_lastEstimatedLossAtStop > 0.0) {
      resultRMoney =
        resultMoney /
        m_lastEstimatedLossAtStop;
    } else if (m_lastTargetRiskMoney > 0.0) {
      resultRMoney =
        resultMoney /
        m_lastTargetRiskMoney;
    }

    double maxFavorableR = 0.0;

    if (m_currentStopLossPoints > 0) {
      maxFavorableR =
        m_maxFavorablePoints /
        (double)m_currentStopLossPoints;
    }

    m_closedTradeRecords[index].sequence =
      index + 1;

    m_closedTradeRecords[index].entryTime =
      m_entryTime;

    m_closedTradeRecords[index].exitTime =
      exitTime;

    m_closedTradeRecords[index].positionState =
      m_state;

    m_closedTradeRecords[index].exitReason =
      exitReason;

    m_closedTradeRecords[index].openedAfterInversion =
      m_currentPositionOpenedAfterInversion;

    m_closedTradeRecords[index].entryPrice =
      m_entryPrice;

    m_closedTradeRecords[index].exitPrice =
      exitPrice;

    m_closedTradeRecords[index].volumeLots =
      m_currentPositionVolumeLots;

    m_closedTradeRecords[index].entrySpreadPoints =
      m_currentEntrySpreadPoints;

    m_closedTradeRecords[index].stopLossPoints =
      m_currentStopLossPoints;

    m_closedTradeRecords[index].takeProfitPoints =
      m_currentTakeProfitPoints;

    m_closedTradeRecords[index].breakEvenTriggerPoints =
      m_currentBreakEvenTriggerPoints;

    m_closedTradeRecords[index].initialStopLossPrice =
      initialStopLossPrice;

    m_closedTradeRecords[index].initialTakeProfitPrice =
      initialTakeProfitPrice;

    m_closedTradeRecords[index].finalStopLossPrice =
      m_stopLossPrice;

    m_closedTradeRecords[index].finalTakeProfitPrice =
      m_takeProfitPrice;

    m_closedTradeRecords[index].breakEvenActivated =
      m_breakEvenActivated;

    m_closedTradeRecords[index].profitLockActivated =
      m_profitLockActivated;

    m_closedTradeRecords[index].resultPoints =
      resultPoints;

    m_closedTradeRecords[index].resultMoney =
      resultMoney;

    m_closedTradeRecords[index].resultRPoints =
      resultRPoints;

    m_closedTradeRecords[index].resultRMoney =
      resultRMoney;

    m_closedTradeRecords[index].maxFavorablePoints =
      m_maxFavorablePoints;

    m_closedTradeRecords[index].maxFavorableR =
      maxFavorableR;

    m_closedTradeRecords[index].openingCapital =
      m_lastOpeningCapital;

    m_closedTradeRecords[index].targetRiskMoney =
      m_lastTargetRiskMoney;

    m_closedTradeRecords[index].estimatedLossAtStop =
      m_lastEstimatedLossAtStop;

    m_closedTradeRecords[index].entryAtrValid =
      m_currentEntryAtrValid;

    m_closedTradeRecords[index].entryAtrPoints =
      m_currentEntryAtrPoints;

    m_closedTradeRecords[index].entryStopLossAtr =
      m_currentEntryStopLossAtr;

    m_closedTradeRecords[index].entryMaDynamics.slopeEarlier =
      m_currentEntryMaDynamics.slopeEarlier;

    m_closedTradeRecords[index].entryMaDynamics.slopePrevious =
      m_currentEntryMaDynamics.slopePrevious;

    m_closedTradeRecords[index].entryMaDynamics.slopeCurrent =
      m_currentEntryMaDynamics.slopeCurrent;

    m_closedTradeRecords[index].entryMaDynamics.accelerationPrevious =
      m_currentEntryMaDynamics.accelerationPrevious;

    m_closedTradeRecords[index].entryMaDynamics.accelerationCurrent =
      m_currentEntryMaDynamics.accelerationCurrent;

    m_closedTradeRecords[index].entryLocalDynamics.isValid =
      m_currentEntryLocalDynamics.isValid;

    m_closedTradeRecords[index].entryLocalDynamics.directionalChangePoints =
      m_currentEntryLocalDynamics.directionalChangePoints;

    m_closedTradeRecords[index].entryLocalDynamics.rangePoints =
      m_currentEntryLocalDynamics.rangePoints;

    m_closedTradeRecords[index].entryLocalDynamics.directionalSlopePointsPerHour =
      m_currentEntryLocalDynamics.directionalSlopePointsPerHour;

    m_closedTradeRecords[index].entryLocalDynamics.directionalCurvaturePointsPerHour2 =
      m_currentEntryLocalDynamics.directionalCurvaturePointsPerHour2;

    m_closedTradeRecords[index].entryLocalDynamics.quadraticRSquared =
      m_currentEntryLocalDynamics.quadraticRSquared;

    m_closedTradeRecords[index].trendContextValid =
      m_currentTrendContextValid;

    m_closedTradeRecords[index].trendClose1 =
      m_currentTrendClose1;

    m_closedTradeRecords[index].trendMa1 =
      m_currentTrendMa1;

    m_closedTradeRecords[index].trendMa2 =
      m_currentTrendMa2;

    m_closedTradeRecords[index].trendAligned =
      m_currentTrendAligned;

    m_closedTradeRecords[index].pointSize =
      m_point;

    m_closedTradeRecords[index].symbolDigits =
      m_digits;

    m_closedTradeRecords[index].tickSize =
      m_currentEntryTickSize;

    m_closedTradeRecords[index].tickValue =
      m_currentEntryTickValue;

    m_closedTradeRecords[index].contractSize =
      m_currentEntryContractSize;

    m_closedTradeRecordCount++;
  }


  // --------------------------------------------------
  // Ferme la position virtuelle actuelle.
  // --------------------------------------------------
  bool CloseCurrentPosition(
    const datetime exitTime,
    const double exitPrice,
    const ENUM_PB_VIRTUAL_EXIT_REASON exitReason,
    double &resultPoints,
    double &resultMoney,
    string &errorMessage) {
    resultPoints = 0.0;
    resultMoney = 0.0;
    errorMessage = "";

    if (!m_isInitialized) {
      errorMessage =
        "Le gestionnaire de positions virtuelles n'est pas initialisé.";

      return false;
    }

    if (m_point <= 0.0) {
      errorMessage =
        "La valeur du point du symbole est invalide.";

      return false;
    }

    if (m_state == PB_VIRTUAL_POSITION_FLAT) {
      errorMessage =
        "Aucune position virtuelle à clôturer.";

      return false;
    }

    if (exitPrice <= 0.0 || m_entryPrice <= 0.0) {
      errorMessage = StringFormat(
        "Prix invalide lors de la clôture | "
        "Entrée=%.*f | Sortie=%.*f",

        m_digits,
        m_entryPrice,

        m_digits,
        exitPrice);

      return false;
    }

    if (m_state == PB_VIRTUAL_POSITION_LONG) {
      resultPoints =
        (exitPrice - m_entryPrice) / m_point;
    } else {
      resultPoints =
        (m_entryPrice - exitPrice) / m_point;
    }

    if (!CalculateMoneyResult(
        m_state,
        m_entryPrice,
        exitPrice,
        resultMoney,
        errorMessage)) {
      return false;
    }

    ENUM_PB_VIRTUAL_POSITION_STATE closedState =
      m_state;

    bool wasOpenedAfterInversion =
      m_currentPositionOpenedAfterInversion;

    SMaDynamics closedEntryMaDynamics =
      m_currentEntryMaDynamics;

    SLocalMarketDynamics closedEntryLocalDynamics =
      m_currentEntryLocalDynamics;

    RecordClosedTradeReport(
      exitTime,
      exitPrice,
      exitReason,
      resultPoints,
      resultMoney);

    RecordClosedTrade(
      exitTime,
      closedState,
      resultPoints,
      resultMoney);

    RecordLosingTradeMfe(
      resultPoints);

    RecordEntryAtrPerformance(
      resultPoints);

    if (wasOpenedAfterInversion)
    RecordInversionTradePerformance(
      closedState,
      resultPoints,
      resultMoney,
      closedEntryMaDynamics,
      closedEntryLocalDynamics);
    else
    RecordFlatEntryTradePerformance(
      closedState,
      resultPoints,
      resultMoney,
      closedEntryMaDynamics,
      closedEntryLocalDynamics);

    m_lastKnownTime = exitTime;

    m_state = PB_VIRTUAL_POSITION_FLAT;
    m_entryTime = 0;
    m_entryPrice = 0.0;

    m_currentEntryMaSlopePoints = 0.0;

    m_currentEntryMaDynamics.slopeEarlier = 0.0;

    m_currentEntryLocalDynamics.isValid = false;

    m_currentEntryLocalDynamics.directionalChangePoints = 0.0;
    m_currentEntryLocalDynamics.rangePoints = 0.0;

    m_currentEntryLocalDynamics.directionalSlopePointsPerHour = 0.0;
    m_currentEntryLocalDynamics.directionalCurvaturePointsPerHour2 = 0.0;

    m_currentEntryLocalDynamics.quadraticRSquared = 0.0;

    m_currentEntryMaDynamics.slopePrevious = 0.0;
    m_currentEntryMaDynamics.slopeCurrent = 0.0;

    m_currentEntryMaDynamics.accelerationPrevious = 0.0;
    m_currentEntryMaDynamics.accelerationCurrent = 0.0;

    m_currentPositionOpenedAfterInversion = false;
    m_breakEvenActivated = false;
    m_profitLockActivated = false;
    m_maxFavorablePoints = 0.0;

    m_currentEntryAtrValid = false;
    m_currentEntryAtrPoints = 0.0;
    m_currentEntryStopLossAtr = 0.0;

    m_currentEntrySpreadPoints = 0.0;

    m_currentTrendContextValid = false;
    m_currentTrendClose1 = 0.0;
    m_currentTrendMa1 = 0.0;
    m_currentTrendMa2 = 0.0;
    m_currentTrendAligned = false;

    m_currentEntryTickSize = 0.0;
    m_currentEntryTickValue = 0.0;
    m_currentEntryContractSize = 0.0;

    m_stopLossPrice = 0.0;
    m_takeProfitPrice = 0.0;

    m_currentStopLossPoints = 0;
    m_currentTakeProfitPoints = 0;
    m_currentBreakEvenTriggerPoints = 0;

    m_currentPositionVolumeLots = 0.0;

    return true;
  }


  public:

    // --------------------------------------------------
  // Constructeur.
  // --------------------------------------------------
  CVirtualPositionManager(void) {
    m_isInitialized = false;

    m_symbol = "";
    m_point = 0.0;
    m_digits = 0;

    m_accountCurrency = "";
    m_accountCurrencyDigits = 2;

    m_stopLossPoints = 0;
    m_takeProfitPoints = 0;

    m_currentStopLossPoints = 0;
    m_currentTakeProfitPoints = 0;
    m_currentBreakEvenTriggerPoints = 0;

    m_initialVirtualCapital = 0.0;
    m_currentPositionVolumeLots = 0.0;

    m_lastOpeningCapital = 0.0;
    m_lastTargetRiskMoney = 0.0;
    m_lastEstimatedLossAtStop = 0.0;
    m_lastOpenedVolumeLots = 0.0;

    m_breakEvenEnabled = false;
    m_breakEvenTriggerPoints = 0;
    m_breakEvenActivated = false;

    m_profitLockEnabled = false;
    m_profitLockTriggerPoints = 0;
    m_profitLockPoints = 0;
    m_profitLockActivated = false;

    m_maxFavorablePoints = 0.0;

    m_currentEntryAtrValid = false;
    m_currentEntryAtrPoints = 0.0;
    m_currentEntryStopLossAtr = 0.0;

    Reset();
  }

  string BuildInversionReversalLateQuadrantIIIWinningTurningTimeSummary(void) const {

  if (m_inversionReversalLateQuadrantIIIWinningTurningTimeCount <= 0)
    return "POST H1 --+ / M5 III GAGNANTS | Retournement : aucune observation valide";

  double averageMinutes =
    m_inversionReversalLateQuadrantIIIWinningTurningTimeMinutesSum /
    (double)m_inversionReversalLateQuadrantIIIWinningTurningTimeCount;

  return StringFormat(
    "POST H1 --+ / M5 III GAGNANTS | "
    "Retournements valides=%d/%d | "
    "Temps moyen avant signal=%.2f min",
    m_inversionReversalLateQuadrantIIIWinningTurningTimeCount,
    m_inversionReversalLateQuadrantIIIWinningProfileCount,
    averageMinutes);
}

string BuildInversionReversalLateQuadrantIIILosingTurningTimeSummary(void) const {

  if (m_inversionReversalLateQuadrantIIILosingTurningTimeCount <= 0)
    return "POST H1 --+ / M5 III PERDANTS | Retournement : aucune observation valide";

  double averageMinutes =
    m_inversionReversalLateQuadrantIIILosingTurningTimeMinutesSum /
    (double)m_inversionReversalLateQuadrantIIILosingTurningTimeCount;

  return StringFormat(
    "POST H1 --+ / M5 III PERDANTS | "
    "Retournements valides=%d/%d | "
    "Temps moyen avant signal=%.2f min",
    m_inversionReversalLateQuadrantIIILosingTurningTimeCount,
    m_inversionReversalLateQuadrantIIILosingProfileCount,
    averageMinutes);
}

  // --------------------------------------------------
  // Dynamique locale - FLAT gagnants.
  // --------------------------------------------------
  string BuildFlatWinningLocalDynamicsSummary(void) const {
    return BuildLocalDynamicsAverageRow(
      "Dynamique locale FLAT GAGNANTS",
      m_flatEntryTradeWinningCount,
      m_flatEntryWinningLocalDynamicsCount,
      m_flatEntryWinningLocalDynamicsSum);
  }


  // --------------------------------------------------
  // Dynamique locale - FLAT perdants.
  // --------------------------------------------------
  string BuildFlatLosingLocalDynamicsSummary(void) const {
    return BuildLocalDynamicsAverageRow(
      "Dynamique locale FLAT PERDANTS",
      m_flatEntryTradeLosingCount,
      m_flatEntryLosingLocalDynamicsCount,
      m_flatEntryLosingLocalDynamicsSum);
  }


  // --------------------------------------------------
  // Dynamique locale - POST-INVERSION gagnants.
  // --------------------------------------------------
  string BuildInversionWinningLocalDynamicsSummary(void) const {
    return BuildLocalDynamicsAverageRow(
      "Dynamique locale POST-INVERSION GAGNANTS",
      m_inversionTradeWinningCount,
      m_inversionEntryWinningLocalDynamicsCount,
      m_inversionEntryWinningLocalDynamicsSum);
  }


  // --------------------------------------------------
  // Dynamique locale - POST-INVERSION perdants.
  // --------------------------------------------------
  string BuildInversionLosingLocalDynamicsSummary(void) const {
    return BuildLocalDynamicsAverageRow(
      "Dynamique locale POST-INVERSION PERDANTS",
      m_inversionTradeLosingCount,
      m_inversionEntryLosingLocalDynamicsCount,
      m_inversionEntryLosingLocalDynamicsSum);
  }

  // --------------------------------------------------
  // Répartition par quadrant des trades ouverts
  // depuis FLAT.
  // --------------------------------------------------
  string BuildFlatLocalQuadrantSummary(void) const {
    return StringFormat(
      "Quadrants locaux FLAT : "
      "I G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "II G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "III G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "IV G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "NON CLASSE G=%d P=%d Pts=%.0f Net=%.2f EUR",

      m_flatEntryWinningLocalQuadrantCount[1],
      m_flatEntryLosingLocalQuadrantCount[1],
      m_flatEntryLocalQuadrantPoints[1],
      m_flatEntryLocalQuadrantMoney[1],

      m_flatEntryWinningLocalQuadrantCount[2],
      m_flatEntryLosingLocalQuadrantCount[2],
      m_flatEntryLocalQuadrantPoints[2],
      m_flatEntryLocalQuadrantMoney[2],

      m_flatEntryWinningLocalQuadrantCount[3],
      m_flatEntryLosingLocalQuadrantCount[3],
      m_flatEntryLocalQuadrantPoints[3],
      m_flatEntryLocalQuadrantMoney[3],

      m_flatEntryWinningLocalQuadrantCount[4],
      m_flatEntryLosingLocalQuadrantCount[4],
      m_flatEntryLocalQuadrantPoints[4],
      m_flatEntryLocalQuadrantMoney[4],

      m_flatEntryWinningLocalQuadrantCount[0],
      m_flatEntryLosingLocalQuadrantCount[0],
      m_flatEntryLocalQuadrantPoints[0],
      m_flatEntryLocalQuadrantMoney[0]);
  }

  // --------------------------------------------------
  // Répartition par quadrant des trades ouverts
  // après inversion.
  // --------------------------------------------------
  string BuildInversionLocalQuadrantSummary(void) const {
    return StringFormat(
      "Quadrants locaux POST-INVERSION : "
      "I G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "II G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "III G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "IV G=%d P=%d Pts=%.0f Net=%.2f EUR | "
      "NON CLASSE G=%d P=%d Pts=%.0f Net=%.2f EUR",

      m_inversionEntryWinningLocalQuadrantCount[1],
      m_inversionEntryLosingLocalQuadrantCount[1],
      m_inversionEntryLocalQuadrantPoints[1],
      m_inversionEntryLocalQuadrantMoney[1],

      m_inversionEntryWinningLocalQuadrantCount[2],
      m_inversionEntryLosingLocalQuadrantCount[2],
      m_inversionEntryLocalQuadrantPoints[2],
      m_inversionEntryLocalQuadrantMoney[2],

      m_inversionEntryWinningLocalQuadrantCount[3],
      m_inversionEntryLosingLocalQuadrantCount[3],
      m_inversionEntryLocalQuadrantPoints[3],
      m_inversionEntryLocalQuadrantMoney[3],

      m_inversionEntryWinningLocalQuadrantCount[4],
      m_inversionEntryLosingLocalQuadrantCount[4],
      m_inversionEntryLocalQuadrantPoints[4],
      m_inversionEntryLocalQuadrantMoney[4],

      m_inversionEntryWinningLocalQuadrantCount[0],
      m_inversionEntryLosingLocalQuadrantCount[0],
      m_inversionEntryLocalQuadrantPoints[0],
      m_inversionEntryLocalQuadrantMoney[0]);
  }

  // --------------------------------------------------
  // Répartition POST-INVERSION pour un régime MA H1,
  // croisée avec le quadrant de dynamique locale M5.
  // --------------------------------------------------
  string BuildInversionMaRegimeLocalQuadrantSummary(
    const ENUM_PB_MA_DYNAMICS_REGIME regime) const {

    int regimeIndex = (int)regime;

    return StringFormat(
      "POST H1 %s : "
      "I G=%d P=%d Pts=%.0f | "
      "II G=%d P=%d Pts=%.0f | "
      "III G=%d P=%d Pts=%.0f | "
      "IV G=%d P=%d Pts=%.0f | "
      "NON CLASSE G=%d P=%d Pts=%.0f",

      MaDynamicsRegimeToString(regime),

      m_inversionWinningMaRegimeLocalQuadrantCount[
        regimeIndex][1],
      m_inversionLosingMaRegimeLocalQuadrantCount[
        regimeIndex][1],
      m_inversionMaRegimeLocalQuadrantPoints[
        regimeIndex][1],

      m_inversionWinningMaRegimeLocalQuadrantCount[
        regimeIndex][2],
      m_inversionLosingMaRegimeLocalQuadrantCount[
        regimeIndex][2],
      m_inversionMaRegimeLocalQuadrantPoints[
        regimeIndex][2],

      m_inversionWinningMaRegimeLocalQuadrantCount[
        regimeIndex][3],
      m_inversionLosingMaRegimeLocalQuadrantCount[
        regimeIndex][3],
      m_inversionMaRegimeLocalQuadrantPoints[
        regimeIndex][3],

      m_inversionWinningMaRegimeLocalQuadrantCount[
        regimeIndex][4],
      m_inversionLosingMaRegimeLocalQuadrantCount[
        regimeIndex][4],
      m_inversionMaRegimeLocalQuadrantPoints[
        regimeIndex][4],

      m_inversionWinningMaRegimeLocalQuadrantCount[
        regimeIndex][0],
      m_inversionLosingMaRegimeLocalQuadrantCount[
        regimeIndex][0],
      m_inversionMaRegimeLocalQuadrantPoints[
        regimeIndex][0]);
  }

  string BuildInversionReversalLateQuadrantIIIProfileSummary(void) const {

    if (m_inversionReversalLateQuadrantIIIProfileCount <= 0)
    return "Profil POST H1 --+ / M5 III : aucune observation";

    double count =
      (double)m_inversionReversalLateQuadrantIIIProfileCount;

    return StringFormat(
      "Profil POST H1 --+ / M5 III : "
      "N=%d | "
      "H1 S2=%.2f S1=%.2f S0=%.2f A1=%.2f A0=%.2f | "
      "M5 Var=%.2f Amp=%.2f Pente=%.2f Courbure=%.2f R2=%.4f",

      m_inversionReversalLateQuadrantIIIProfileCount,

      m_inversionReversalLateQuadrantIIIMaDynamicsSum.slopeEarlier / count,
      m_inversionReversalLateQuadrantIIIMaDynamicsSum.slopePrevious / count,
      m_inversionReversalLateQuadrantIIIMaDynamicsSum.slopeCurrent / count,
      m_inversionReversalLateQuadrantIIIMaDynamicsSum.accelerationPrevious / count,
      m_inversionReversalLateQuadrantIIIMaDynamicsSum.accelerationCurrent / count,

      m_inversionReversalLateQuadrantIIILocalDynamicsSum.directionalChangePoints / count,
      m_inversionReversalLateQuadrantIIILocalDynamicsSum.rangePoints / count,
      m_inversionReversalLateQuadrantIIILocalDynamicsSum.directionalSlopePointsPerHour / count,
      m_inversionReversalLateQuadrantIIILocalDynamicsSum.directionalCurvaturePointsPerHour2 / count,
      m_inversionReversalLateQuadrantIIILocalDynamicsSum.quadraticRSquared / count);
  }

  string BuildInversionReversalLateQuadrantIIIWinningProfileSummary(void) const {

    if (m_inversionReversalLateQuadrantIIIWinningProfileCount <= 0)
    return "Profil POST H1 --+ / M5 III GAGNANTS : aucune observation";

    double count =
      (double)m_inversionReversalLateQuadrantIIIWinningProfileCount;

    return StringFormat(
      "Profil POST H1 --+ / M5 III GAGNANTS : "
      "N=%d | "
      "H1 S2=%.2f S1=%.2f S0=%.2f A1=%.2f A0=%.2f | "
      "M5 Var=%.2f Amp=%.2f Pente=%.2f Courbure=%.2f R2=%.4f",

      m_inversionReversalLateQuadrantIIIWinningProfileCount,

      m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum.slopeEarlier / count,
      m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum.slopePrevious / count,
      m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum.slopeCurrent / count,
      m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum.accelerationPrevious / count,
      m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum.accelerationCurrent / count,

      m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum.directionalChangePoints / count,
      m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum.rangePoints / count,
      m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum.directionalSlopePointsPerHour / count,
      m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum.directionalCurvaturePointsPerHour2 / count,
      m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum.quadraticRSquared / count);
  }

  string BuildInversionReversalLateQuadrantIIILosingProfileSummary(void) const {

    if (m_inversionReversalLateQuadrantIIILosingProfileCount <= 0)
    return "Profil POST H1 --+ / M5 III PERDANTS : aucune observation";

    double count =
      (double)m_inversionReversalLateQuadrantIIILosingProfileCount;

    return StringFormat(
      "Profil POST H1 --+ / M5 III PERDANTS : "
      "N=%d | "
      "H1 S2=%.2f S1=%.2f S0=%.2f A1=%.2f A0=%.2f | "
      "M5 Var=%.2f Amp=%.2f Pente=%.2f Courbure=%.2f R2=%.4f",

      m_inversionReversalLateQuadrantIIILosingProfileCount,

      m_inversionReversalLateQuadrantIIILosingMaDynamicsSum.slopeEarlier / count,
      m_inversionReversalLateQuadrantIIILosingMaDynamicsSum.slopePrevious / count,
      m_inversionReversalLateQuadrantIIILosingMaDynamicsSum.slopeCurrent / count,
      m_inversionReversalLateQuadrantIIILosingMaDynamicsSum.accelerationPrevious / count,
      m_inversionReversalLateQuadrantIIILosingMaDynamicsSum.accelerationCurrent / count,

      m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum.directionalChangePoints / count,
      m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum.rangePoints / count,
      m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum.directionalSlopePointsPerHour / count,
      m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum.directionalCurvaturePointsPerHour2 / count,
      m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum.quadraticRSquared / count);
  }

  string BuildInversionContinuationQuadrantIProfileSummary(void) const {

    if (m_inversionContinuationQuadrantIProfileCount <= 0)
    return "Profil POST H1 +++ / M5 I : aucune observation";

    double count =
      (double)m_inversionContinuationQuadrantIProfileCount;

    return StringFormat(
      "Profil POST H1 +++ / M5 I : "
      "N=%d | "
      "H1 S2=%.2f S1=%.2f S0=%.2f A1=%.2f A0=%.2f | "
      "M5 Var=%.2f Amp=%.2f Pente=%.2f Courbure=%.2f R2=%.4f",

      m_inversionContinuationQuadrantIProfileCount,

      m_inversionContinuationQuadrantIMaDynamicsSum.slopeEarlier / count,
      m_inversionContinuationQuadrantIMaDynamicsSum.slopePrevious / count,
      m_inversionContinuationQuadrantIMaDynamicsSum.slopeCurrent / count,
      m_inversionContinuationQuadrantIMaDynamicsSum.accelerationPrevious / count,
      m_inversionContinuationQuadrantIMaDynamicsSum.accelerationCurrent / count,

      m_inversionContinuationQuadrantILocalDynamicsSum.directionalChangePoints / count,
      m_inversionContinuationQuadrantILocalDynamicsSum.rangePoints / count,
      m_inversionContinuationQuadrantILocalDynamicsSum.directionalSlopePointsPerHour / count,
      m_inversionContinuationQuadrantILocalDynamicsSum.directionalCurvaturePointsPerHour2 / count,
      m_inversionContinuationQuadrantILocalDynamicsSum.quadraticRSquared / count);
  }

  // --------------------------------------------------
  // Réinitialise l'état et les statistiques.
  // --------------------------------------------------
  void Reset(void) {
    m_state = PB_VIRTUAL_POSITION_FLAT;

    m_entryTime = 0;
    m_entryPrice = 0.0;

    m_stopLossPrice = 0.0;
    m_takeProfitPrice = 0.0;

    m_currentStopLossPoints = 0;
    m_currentTakeProfitPoints = 0;
    m_currentBreakEvenTriggerPoints = 0;

    // État propre de la position courante.
    // La configuration reste conservée.
    m_breakEvenActivated = false;
    m_profitLockActivated = false;

    m_lastKnownTime = 0;
    
    m_lastKnownBid = 0.0;
    m_lastKnownAsk = 0.0;

    m_currentPositionVolumeLots = 0.0;

    m_lastOpeningCapital = 0.0;
    m_lastTargetRiskMoney = 0.0;
    m_lastEstimatedLossAtStop = 0.0;
    m_lastOpenedVolumeLots = 0.0;

    m_openCount = 0;
    m_closedTradeCount = 0;

    m_winningTradeCount = 0;
    m_losingTradeCount = 0;
    m_breakEvenTradeCount = 0;

    m_maxFavorablePoints = 0.0;

    m_losingMfeTradeCount = 0;
    m_losingReached50Points = 0;
    m_losingReached100Points = 0;
    m_losingReached200Points = 0;
    m_losingReached300Points = 0;

    // Volatilité ATR de la position courante.
    m_currentEntryAtrValid = false;
    m_currentEntryAtrPoints = 0.0;
    m_currentEntryStopLossAtr = 0.0;

    m_currentEntrySpreadPoints = 0.0;

    m_currentTrendContextValid = false;
    m_currentTrendClose1 = 0.0;
    m_currentTrendMa1 = 0.0;
    m_currentTrendMa2 = 0.0;
    m_currentTrendAligned = false;

    m_currentEntryTickSize = 0.0;
    m_currentEntryTickValue = 0.0;
    m_currentEntryContractSize = 0.0;

    // Statistiques ATR à l'entrée.
    m_entryAtrValidTradeCount = 0;
    m_entryAtrUnavailableTradeCount = 0;

    m_entryAtrWinningTradeCount = 0;
    m_entryAtrLosingTradeCount = 0;
    m_entryAtrBreakEvenTradeCount = 0;

    m_entryAtrWinningPointsSum = 0.0;
    m_entryAtrLosingPointsSum = 0.0;
    m_entryAtrBreakEvenPointsSum = 0.0;

    m_entryStopLossAtrWinningSum = 0.0;
    m_entryStopLossAtrLosingSum = 0.0;
    m_entryStopLossAtrBreakEvenSum = 0.0;

    // Statistiques LONG.
    m_longClosedTradeCount = 0;
    m_longWinningTradeCount = 0;
    m_longLosingTradeCount = 0;
    m_longBreakEvenTradeCount = 0;

    m_longTotalClosedPoints = 0.0;
    m_longTotalClosedMoney = 0.0;

    m_longGrossProfitMoney = 0.0;
    m_longGrossLossMoney = 0.0;


    // Statistiques SHORT.
    m_shortClosedTradeCount = 0;
    m_shortWinningTradeCount = 0;
    m_shortLosingTradeCount = 0;
    m_shortBreakEvenTradeCount = 0;

    m_shortTotalClosedPoints = 0.0;
    m_shortTotalClosedMoney = 0.0;

    m_shortGrossProfitMoney = 0.0;
    m_shortGrossLossMoney = 0.0;

    // --------------------------------------------------
    // Performances sorties SIGNAL.
    // --------------------------------------------------
    m_signalExitWinningCount = 0;
    m_signalExitLosingCount = 0;
    m_signalExitBreakEvenCount = 0;

    m_signalExitTotalPoints = 0.0;
    m_signalExitTotalMoney = 0.0;

    m_signalExitGrossProfitMoney = 0.0;
    m_signalExitGrossLossMoney = 0.0;


    // --------------------------------------------------
    // Performances sorties STOP LOSS.
    // --------------------------------------------------
    m_stopLossWinningCount = 0;
    m_stopLossLosingCount = 0;
    m_stopLossBreakEvenCount = 0;

    m_stopLossTotalPoints = 0.0;
    m_stopLossTotalMoney = 0.0;

    m_stopLossGrossProfitMoney = 0.0;
    m_stopLossGrossLossMoney = 0.0;


    // --------------------------------------------------
    // Performances sorties TAKE PROFIT.
    // --------------------------------------------------
    m_takeProfitWinningCount = 0;
    m_takeProfitLosingCount = 0;
    m_takeProfitBreakEvenCount = 0;

    m_takeProfitTotalPoints = 0.0;
    m_takeProfitTotalMoney = 0.0;

    m_takeProfitGrossProfitMoney = 0.0;
    m_takeProfitGrossLossMoney = 0.0;

    m_currentLosingStreak = 0;
    m_maxLosingStreak = 0;

    m_annualStatisticsCount = 0;

    m_closedTradeRecordCount = 0;
    m_closedTradeRecordOverflowCount = 0;

    m_reversalCount = 0;

    m_signalExitCount = 0;
    m_stopLossExitCount = 0;
    m_takeProfitExitCount = 0;

    m_totalClosedPoints = 0.0;
    m_totalClosedMoney = 0.0;

    m_grossProfitMoney = 0.0;
    m_grossLossMoney = 0.0;

    // Lors de l'appel depuis Init(), le capital initial
    // a déjà été chargé.
    m_peakVirtualCapital = m_initialVirtualCapital;

    m_maxDrawdownMoney = 0.0;
    m_maxDrawdownPercent = 0.0;

    m_currentCapitalPeakTime = 0;
    m_maxCapitalDrawdownStartTime = 0;
    m_maxCapitalDrawdownLowTime = 0;
    m_currentEquityPeakTime = 0;
    m_maxEquityDrawdownStartTime = 0;
    m_maxEquityDrawdownLowTime = 0;

    m_peakVirtualEquity = m_initialVirtualCapital;

    m_maxEquityDrawdownMoney = 0.0;
    m_maxEquityDrawdownPercent = 0.0;

    m_bestTradePoints = 0.0;
    m_worstTradePoints = 0.0;

    // --------------------------------------------------
    // Croisement LONG / motif de sortie.
    // --------------------------------------------------
    m_longSignalExitCount = 0;
    m_longSignalExitMoney = 0.0;

    m_longStopLossExitCount = 0;
    m_longStopLossExitMoney = 0.0;

    m_longTakeProfitExitCount = 0;
    m_longTakeProfitExitMoney = 0.0;


    // --------------------------------------------------
    // Croisement SHORT / motif de sortie.
    // --------------------------------------------------
    m_shortSignalExitCount = 0;
    m_shortSignalExitMoney = 0.0;

    m_shortStopLossExitCount = 0;
    m_shortStopLossExitMoney = 0.0;

    m_shortTakeProfitExitCount = 0;
    m_shortTakeProfitExitMoney = 0.0;

    // --------------------------------------------------
    // Analyse détaillée sorties SIGNAL LONG.
    // --------------------------------------------------
    m_longSignalWinningCount = 0;
    m_longSignalLosingCount = 0;

    m_longSignalWinningMoney = 0.0;
    m_longSignalLosingMoney = 0.0;


    // --------------------------------------------------
    // Analyse détaillée sorties SIGNAL SHORT.
    // --------------------------------------------------
    m_shortSignalWinningCount = 0;
    m_shortSignalLosingCount = 0;

    m_shortSignalWinningMoney = 0.0;
    m_shortSignalLosingMoney = 0.0;

    // --------------------------------------------------
    // Pente MA de la position courante.
    // --------------------------------------------------
    m_currentEntryMaSlopePoints = 0.0;

    // --------------------------------------------------
    // Origine de la position courante.
    // --------------------------------------------------
    m_currentPositionOpenedAfterInversion = false;


    // --------------------------------------------------
    // Performances après inversion.
    // --------------------------------------------------
    m_inversionTradeClosedCount = 0;

    m_inversionTradeWinningCount = 0;
    m_inversionTradeLosingCount = 0;
    m_inversionTradeBreakEvenCount = 0;

    m_inversionTradeTotalPoints = 0.0;
    m_inversionTradeTotalMoney = 0.0;

    m_inversionTradeGrossProfitMoney = 0.0;
    m_inversionTradeGrossLossMoney = 0.0;


    // --------------------------------------------------
    // Répartition LONG / SHORT après inversion.
    // --------------------------------------------------
    m_inversionLongClosedCount = 0;
    m_inversionLongTotalMoney = 0.0;

    m_inversionShortClosedCount = 0;
    m_inversionShortTotalMoney = 0.0;

    // --------------------------------------------------
    // Performances des positions ouvertes depuis FLAT.
    // --------------------------------------------------
    m_flatEntryTradeClosedCount = 0;

    m_flatEntryTradeWinningCount = 0;
    m_flatEntryTradeLosingCount = 0;
    m_flatEntryTradeBreakEvenCount = 0;

    m_flatEntryTradeTotalPoints = 0.0;
    m_flatEntryTradeTotalMoney = 0.0;

    m_flatEntryTradeGrossProfitMoney = 0.0;
    m_flatEntryTradeGrossLossMoney = 0.0;


    // --------------------------------------------------
    // Répartition LONG / SHORT depuis FLAT.
    // --------------------------------------------------
    m_flatEntryLongClosedCount = 0;
    m_flatEntryLongTotalMoney = 0.0;

    m_flatEntryShortClosedCount = 0;
    m_flatEntryShortTotalMoney = 0.0;

    // --------------------------------------------------
    // Entrées depuis FLAT × motif de sortie.
    // --------------------------------------------------
    m_flatEntrySignalExitCount = 0;
    m_flatEntrySignalExitMoney = 0.0;

    m_flatEntryStopLossExitCount = 0;
    m_flatEntryStopLossExitMoney = 0.0;

    m_flatEntryTakeProfitExitCount = 0;
    m_flatEntryTakeProfitExitMoney = 0.0;


    // --------------------------------------------------
    // Entrées post-inversion × motif de sortie.
    // --------------------------------------------------
    m_inversionEntrySignalExitCount = 0;
    m_inversionEntrySignalExitMoney = 0.0;

    m_inversionEntryStopLossExitCount = 0;
    m_inversionEntryStopLossExitMoney = 0.0;

    m_inversionEntryTakeProfitExitCount = 0;
    m_inversionEntryTakeProfitExitMoney = 0.0;

    // --------------------------------------------------
    // v1.18 - Pente MA à l'entrée.
    // --------------------------------------------------
    m_flatEntryWinningSlopeSum = 0.0;
    m_flatEntryLosingSlopeSum = 0.0;

    m_inversionEntryWinningSlopeSum = 0.0;
    m_inversionEntryLosingSlopeSum = 0.0;

    m_currentEntryMaDynamics.slopeEarlier = 0.0;
    m_currentEntryMaDynamics.slopePrevious = 0.0;
    m_currentEntryMaDynamics.slopeCurrent = 0.0;

    m_currentEntryMaDynamics.accelerationPrevious = 0.0;
    m_currentEntryMaDynamics.accelerationCurrent = 0.0;

    ResetMaDynamics(
      m_flatEntryWinningDynamicsSum);

    ResetMaDynamics(
      m_flatEntryLosingDynamicsSum);

    ResetMaDynamics(
      m_inversionEntryWinningDynamicsSum);

    ResetMaDynamics(
      m_inversionEntryLosingDynamicsSum);

    m_currentEntryLocalDynamics.isValid = false;

    m_currentEntryLocalDynamics.directionalChangePoints = 0.0;
    m_currentEntryLocalDynamics.rangePoints = 0.0;

    m_currentEntryLocalDynamics.directionalSlopePointsPerHour = 0.0;
    m_currentEntryLocalDynamics.directionalCurvaturePointsPerHour2 = 0.0;

    m_currentEntryLocalDynamics.quadraticRSquared = 0.0;

    ResetLocalMarketDynamics(
      m_flatEntryWinningLocalDynamicsSum);

    ResetLocalMarketDynamics(
      m_flatEntryLosingLocalDynamicsSum);

    ResetLocalMarketDynamics(
      m_inversionEntryWinningLocalDynamicsSum);

    ResetLocalMarketDynamics(
      m_inversionEntryLosingLocalDynamicsSum);

    ResetMaDynamics(
      m_inversionReversalLateQuadrantIIIMaDynamicsSum);

    ResetLocalMarketDynamics(
      m_inversionReversalLateQuadrantIIILocalDynamicsSum);

    m_inversionReversalLateQuadrantIIIProfileCount = 0;

    ResetMaDynamics(
      m_inversionReversalLateQuadrantIIIWinningMaDynamicsSum);

    ResetLocalMarketDynamics(
      m_inversionReversalLateQuadrantIIIWinningLocalDynamicsSum);

    m_inversionReversalLateQuadrantIIIWinningProfileCount = 0;

    m_inversionReversalLateQuadrantIIIWinningTurningTimeCount = 0;
    m_inversionReversalLateQuadrantIIIWinningTurningTimeMinutesSum = 0.0;

    ResetMaDynamics(
      m_inversionReversalLateQuadrantIIILosingMaDynamicsSum);

    ResetLocalMarketDynamics(
      m_inversionReversalLateQuadrantIIILosingLocalDynamicsSum);

    m_inversionReversalLateQuadrantIIILosingProfileCount = 0;
    m_inversionReversalLateQuadrantIIILosingTurningTimeCount = 0;
    m_inversionReversalLateQuadrantIIILosingTurningTimeMinutesSum = 0.0;

    ResetMaDynamics(
      m_inversionContinuationQuadrantIMaDynamicsSum);

    ResetLocalMarketDynamics(
      m_inversionContinuationQuadrantILocalDynamicsSum);

    m_inversionContinuationQuadrantIProfileCount = 0;

    m_flatEntryWinningLocalDynamicsCount = 0;
    m_flatEntryLosingLocalDynamicsCount = 0;

    m_inversionEntryWinningLocalDynamicsCount = 0;
    m_inversionEntryLosingLocalDynamicsCount = 0;

    for (int quadrantIndex = 0;
      quadrantIndex < 5;
      quadrantIndex++) {
      m_flatEntryWinningLocalQuadrantCount[
        quadrantIndex] = 0;

      m_flatEntryLosingLocalQuadrantCount[
        quadrantIndex] = 0;

      m_inversionEntryWinningLocalQuadrantCount[
        quadrantIndex] = 0;

      m_inversionEntryLosingLocalQuadrantCount[
        quadrantIndex] = 0;

      m_flatEntryLocalQuadrantMoney[
        quadrantIndex] = 0.0;

      m_inversionEntryLocalQuadrantMoney[
        quadrantIndex] = 0.0;

      m_flatEntryLocalQuadrantPoints[
        quadrantIndex] = 0.0;

      m_inversionEntryLocalQuadrantPoints[
        quadrantIndex] = 0.0;
    }
    for (int regimeIndex = 0;
      regimeIndex < 5;
      regimeIndex++) {

      for (int quadrantIndex = 0;
        quadrantIndex < 5;
        quadrantIndex++) {

        m_inversionWinningMaRegimeLocalQuadrantCount[
          regimeIndex][
          quadrantIndex] = 0;

        m_inversionLosingMaRegimeLocalQuadrantCount[
          regimeIndex][
          quadrantIndex] = 0;

        m_inversionMaRegimeLocalQuadrantPoints[
          regimeIndex][
          quadrantIndex] = 0.0;
      }
    }
  }


  // --------------------------------------------------
  // v1.18 - Dynamique MA moyenne des trades gagnants
  // ouverts depuis FLAT.
  // --------------------------------------------------
  string BuildFlatWinningMaDynamicsSummary(void) const {
    return BuildMaDynamicsAverageRow(
      "Dynamique MA FLAT GAGNANTS",
      m_flatEntryTradeWinningCount,
      m_flatEntryWinningDynamicsSum);
  }


  // --------------------------------------------------
  // v1.18 - Dynamique MA moyenne des trades perdants
  // ouverts depuis FLAT.
  // --------------------------------------------------
  string BuildFlatLosingMaDynamicsSummary(void) const {
    return BuildMaDynamicsAverageRow(
      "Dynamique MA FLAT PERDANTS",
      m_flatEntryTradeLosingCount,
      m_flatEntryLosingDynamicsSum);
  }


  // --------------------------------------------------
  // v1.18 - Dynamique MA moyenne des trades gagnants
  // ouverts après inversion.
  // --------------------------------------------------
  string BuildInversionWinningMaDynamicsSummary(void) const {
    return BuildMaDynamicsAverageRow(
      "Dynamique MA POST-INVERSION GAGNANTS",
      m_inversionTradeWinningCount,
      m_inversionEntryWinningDynamicsSum);
  }


  // --------------------------------------------------
  // v1.18 - Dynamique MA moyenne des trades perdants
  // ouverts après inversion.
  // --------------------------------------------------
  string BuildInversionLosingMaDynamicsSummary(void) const {
    return BuildMaDynamicsAverageRow(
      "Dynamique MA POST-INVERSION PERDANTS",
      m_inversionTradeLosingCount,
      m_inversionEntryLosingDynamicsSum);
  }

  // --------------------------------------------------
  // Initialise le gestionnaire.
  // --------------------------------------------------
  bool Init(
    const string symbol,
    const int stopLossPoints,
    const int takeProfitPoints,
    const ENUM_PB_VIRTUAL_VOLUME_MODE volumeMode,
    const double fixedVolumeLots,
    const double riskPercent,
    string &errorMessage) {
    errorMessage = "";
    m_isInitialized = false;

    m_symbol = symbol;

    if (m_symbol == "") {
      errorMessage = "Le symbole est vide.";
      return false;
    }

    m_point =
      SymbolInfoDouble(
      m_symbol,
      SYMBOL_POINT);

    m_digits =
      (int)SymbolInfoInteger(
      m_symbol,
      SYMBOL_DIGITS);

    if (m_point <= 0.0 || m_digits < 0) {
      errorMessage =
        "Les propriétés de prix du symbole sont invalides.";

      return false;
    }

    m_stopLossPoints =
      (stopLossPoints < 0)
      ? 0
      : stopLossPoints;

    m_takeProfitPoints =
      (takeProfitPoints < 0)
      ? 0
      : takeProfitPoints;

    if (volumeMode == PB_VIRTUAL_VOLUME_RISK_PERCENT &&
      m_stopLossPoints <= 0) {
      errorMessage =
        "Le mode de volume RISQUE nécessite "
      "un Stop Loss supérieur à zéro.";

      return false;
    }

    m_accountCurrency =
      AccountInfoString(
      ACCOUNT_CURRENCY);

    m_accountCurrencyDigits =
      (int)AccountInfoInteger(
      ACCOUNT_CURRENCY_DIGITS);

    if (m_accountCurrency == "") {
      errorMessage =
        "Impossible de déterminer la devise du compte.";

      return false;
    }

    if (!m_volumeCalculator.Init(
        m_symbol,
        volumeMode,
        fixedVolumeLots,
        riskPercent,
        errorMessage)) {
      return false;
    }

    m_initialVirtualCapital =
      AccountInfoDouble(
      ACCOUNT_BALANCE);

    if (m_initialVirtualCapital <= 0.0) {
      errorMessage = StringFormat(
        "Capital initial invalide : %.2f",
        m_initialVirtualCapital);

      return false;
    }

    Reset();
    m_isInitialized = true;

    return true;
  }

  // --------------------------------------------------
  // v1.18 - Résumé de la pente MA à l'entrée
  // pour les positions ouvertes depuis FLAT.
  // --------------------------------------------------
  string BuildFlatEntrySlopeSummary(void) const {
    double winningAverageSlope = 0.0;

    if (m_flatEntryTradeWinningCount > 0)
    winningAverageSlope =
      m_flatEntryWinningSlopeSum/
      (double)m_flatEntryTradeWinningCount;


    double losingAverageSlope = 0.0;

    if (m_flatEntryTradeLosingCount > 0)
    losingAverageSlope =
      m_flatEntryLosingSlopeSum/
      (double)m_flatEntryTradeLosingCount;


    return StringFormat(
      "Pente entrée FLAT : "
      "Gagnants=%d / pente moyenne=%.2f pts | "
      "Perdants=%d / pente moyenne=%.2f pts",

      m_flatEntryTradeWinningCount,
      winningAverageSlope,

      m_flatEntryTradeLosingCount,
      losingAverageSlope);
  }

  // --------------------------------------------------
  // v1.18 - Résumé de la pente MA à l'entrée
  // pour les positions ouvertes post-inversion.
  // --------------------------------------------------
  string BuildInversionEntrySlopeSummary(void) const {
    double winningAverageSlope = 0.0;

    if (m_inversionTradeWinningCount > 0)
    winningAverageSlope =
      m_inversionEntryWinningSlopeSum/
      (double)m_inversionTradeWinningCount;


    double losingAverageSlope = 0.0;

    if (m_inversionTradeLosingCount > 0)
    losingAverageSlope =
      m_inversionEntryLosingSlopeSum/
      (double)m_inversionTradeLosingCount;


    return StringFormat(
      "Pente entrée POST-INVERSION : "
      "Gagnants=%d / pente moyenne=%.2f pts | "
      "Perdants=%d / pente moyenne=%.2f pts",

      m_inversionTradeWinningCount,
      winningAverageSlope,

      m_inversionTradeLosingCount,
      losingAverageSlope);
  }

  // --------------------------------------------------
  // Configure le déplacement du SL au prix d'entrée.
  // --------------------------------------------------
  void ConfigureBreakEven(
    const bool enabled,
    const int triggerPoints) {

    m_breakEvenEnabled = enabled;

    m_breakEvenTriggerPoints =
      (triggerPoints < 0)
      ? 0
      : triggerPoints;
  }


  // --------------------------------------------------
  // Configure le verrouillage d'une partie du gain.
  //
  // Exemple :
  // triggerPoints = 300
  // lockedPoints  = 100
  //
  // À partir de +300 points, le SL est déplacé
  // à +100 points par rapport au prix d'entrée.
  // --------------------------------------------------
  void ConfigureProfitLock(
    const bool enabled,
    const int triggerPoints,
    const int lockedPoints) {

    m_profitLockTriggerPoints =
      (triggerPoints < 0)
      ? 0
      : triggerPoints;

    m_profitLockPoints =
      (lockedPoints < 0)
      ? 0
      : lockedPoints;

    // La protection n'est valide que si le gain
    // verrouillé reste inférieur au seuil déclencheur.
    m_profitLockEnabled =
      enabled &&
      m_profitLockTriggerPoints > 0 &&
      m_profitLockPoints <
        m_profitLockTriggerPoints;
  }

  // --------------------------------------------------
  // Surveille SL et TP à chaque tick.
  // --------------------------------------------------
  bool ProcessTick(
    const datetime tickTime,
    const double bid,
    const double ask,
    string &eventMessage) {
    eventMessage = "";

    if (!m_isInitialized) {
      eventMessage =
        "Le gestionnaire de positions virtuelles n'est pas initialisé.";

      return false;
    }

    if (bid <= 0.0 || ask <= 0.0 || ask < bid) {
      eventMessage = StringFormat(
        "Cotation invalide : Bid=%.*f Ask=%.*f",

        m_digits,
        bid,

        m_digits,
        ask);

      return false;
    }

    m_lastKnownTime = tickTime;
    m_lastKnownBid = bid;
    m_lastKnownAsk = ask;


    // --------------------------------------------------
    // L'équité est contrôlée à chaque tick, avant une
    // éventuelle fermeture au Stop Loss ou Take Profit.
    // --------------------------------------------------
    string equityError;

    // Le premier tick représente le sommet initial,
    // correspondant au capital de départ.
    if (m_currentCapitalPeakTime == 0) {
      m_currentCapitalPeakTime =
        tickTime;
    }

    if (m_currentEquityPeakTime == 0) {
      m_currentEquityPeakTime =
        tickTime;
    }

    if (!UpdateEquityDrawdown(
        tickTime,
        bid,
        ask,
        equityError)) {
      eventMessage = StringFormat(
        "Calcul du drawdown d'équité impossible : %s",
        equityError);

      return false;
    }

    if (m_state == PB_VIRTUAL_POSITION_FLAT)
      return true;

    // --------------------------------------------------
    // Maximum Favorable Excursion (MFE) de la position
    // courante, calculé sur le prix réel de sortie.
    // --------------------------------------------------
    double favorablePoints = 0.0;

    if (m_state == PB_VIRTUAL_POSITION_LONG) {
      favorablePoints =
        (bid - m_entryPrice) / m_point;
    } else {
      favorablePoints =
        (m_entryPrice - ask) / m_point;
    }

    if (favorablePoints > m_maxFavorablePoints)
      m_maxFavorablePoints = favorablePoints;


    bool stopLossHit = false;
    bool takeProfitHit = false;
    double exitPrice = 0.0;
    double triggerPrice = 0.0;

    if (m_state == PB_VIRTUAL_POSITION_LONG) {
      exitPrice = bid;

      if (m_stopLossPrice > 0.0 &&
        bid <= m_stopLossPrice) {
        stopLossHit = true;
        triggerPrice = m_stopLossPrice;
      } else if (m_takeProfitPrice > 0.0 &&
        bid >= m_takeProfitPrice) {
        takeProfitHit = true;
        triggerPrice = m_takeProfitPrice;
      }
    } else {
      exitPrice = ask;

      if (m_stopLossPrice > 0.0 &&
        ask >= m_stopLossPrice) {
        stopLossHit = true;
        triggerPrice = m_stopLossPrice;
      } else if (m_takeProfitPrice > 0.0 &&
        ask <= m_takeProfitPrice) {
        takeProfitHit = true;
        triggerPrice = m_takeProfitPrice;
      }
    }

    if (!stopLossHit && !takeProfitHit) {

      // ------------------------------------------------
      // Deuxième niveau : verrouillage d'un gain.
      //
      // Cette protection est contrôlée avant le
      // break-even. Ainsi, si un tick franchit
      // directement le seuil de +300 points, le SL
      // est immédiatement déplacé à +100 points.
      // ------------------------------------------------
      if (m_profitLockEnabled &&
          !m_profitLockActivated &&
          m_profitLockTriggerPoints > 0 &&
          m_profitLockPoints >= 0 &&
          m_profitLockPoints <
            m_profitLockTriggerPoints &&
          m_stopLossPrice > 0.0 &&
          favorablePoints >=
            (double)m_profitLockTriggerPoints) {

        double previousStopLossPrice =
          m_stopLossPrice;

        double newStopLossPrice = 0.0;

        if (m_state ==
            PB_VIRTUAL_POSITION_LONG) {

          newStopLossPrice =
            m_entryPrice +
            m_profitLockPoints * m_point;
        } else {

          newStopLossPrice =
            m_entryPrice -
            m_profitLockPoints * m_point;
        }

        newStopLossPrice =
          NormalizeDouble(
            newStopLossPrice,
            m_digits);

        // Le SL ne doit jamais être déplacé
        // dans un sens moins favorable.
        bool improvesStopLoss = false;

        if (m_state ==
            PB_VIRTUAL_POSITION_LONG) {

          improvesStopLoss =
            newStopLossPrice >
            m_stopLossPrice;
        } else {

          improvesStopLoss =
            newStopLossPrice <
            m_stopLossPrice;
        }

        if (improvesStopLoss) {

          m_stopLossPrice =
            newStopLossPrice;

          m_profitLockActivated = true;

          // Le niveau de protection est désormais
          // supérieur au simple break-even.
          m_breakEvenActivated = true;

          eventMessage = StringFormat(
            "VERROUILLAGE DE GAIN VIRTUEL ACTIVÉ | "
            "Position=%s | "
            "Entrée=%.*f | "
            "Ancien SL=%.*f | "
            "Nouveau SL=%.*f | "
            "Progression=%.1f points | "
            "Seuil=%d points | "
            "Gain protégé=%d points",

            VirtualPositionStateToString(
              m_state),

            m_digits,
            m_entryPrice,

            m_digits,
            previousStopLossPrice,

            m_digits,
            m_stopLossPrice,

            favorablePoints,

            m_profitLockTriggerPoints,
            m_profitLockPoints);

          return true;
        }
      }


      // ------------------------------------------------
      // Premier niveau : break-even virtuel.
      //
      // Lorsque le prix a progressé d'au moins le seuil
      // demandé, le SL est déplacé au prix d'entrée.
      // ------------------------------------------------
      if (m_breakEvenEnabled &&
          !m_breakEvenActivated &&
          m_currentBreakEvenTriggerPoints > 0 &&
          m_stopLossPrice > 0.0 &&
          favorablePoints >=
            (double)m_currentBreakEvenTriggerPoints) {

        double previousStopLossPrice =
          m_stopLossPrice;

        m_stopLossPrice =
          NormalizeDouble(
            m_entryPrice,
            m_digits);

        m_breakEvenActivated = true;

        eventMessage = StringFormat(
          "BREAK-EVEN VIRTUEL ACTIVÉ | "
          "Position=%s | "
          "Entrée=%.*f | "
          "Ancien SL=%.*f | "
          "Nouveau SL=%.*f | "
          "Progression=%.1f points | "
          "Seuil=%d points",

          VirtualPositionStateToString(
            m_state),

          m_digits,
          m_entryPrice,

          m_digits,
          previousStopLossPrice,

          m_digits,
          m_stopLossPrice,

          favorablePoints,

          m_currentBreakEvenTriggerPoints);
      }

      return true;
    }
    
    ENUM_PB_VIRTUAL_POSITION_STATE previousState =
      m_state;

    bool previousOpenedAfterInversion =
      m_currentPositionOpenedAfterInversion;

    datetime previousEntryTime = m_entryTime;
    double previousEntryPrice = m_entryPrice;
    double previousVolume = m_currentPositionVolumeLots;

    double resultPoints = 0.0;
    double resultMoney = 0.0;
    string closeError;

    ENUM_PB_VIRTUAL_EXIT_REASON closeReason =
      stopLossHit
      ? PB_VIRTUAL_EXIT_STOP_LOSS
      : PB_VIRTUAL_EXIT_TAKE_PROFIT;

    if (!CloseCurrentPosition(
        tickTime,
        exitPrice,
        closeReason,
        resultPoints,
        resultMoney,
        closeError)) {
      eventMessage = closeError;
      return false;
    }

    string exitReason;

    if (stopLossHit) {
      m_stopLossExitCount++;

      RecordExitPerformance(
        previousState,
        previousOpenedAfterInversion,
        PB_VIRTUAL_EXIT_STOP_LOSS,
        resultPoints,
        resultMoney);

      exitReason = "STOP LOSS";
    } else {
      m_takeProfitExitCount++;

      RecordExitPerformance(
        previousState,
        previousOpenedAfterInversion,
        PB_VIRTUAL_EXIT_TAKE_PROFIT,
        resultPoints,
        resultMoney);

      exitReason = "TAKE PROFIT";
    }
    eventMessage = StringFormat(
      "SORTIE VIRTUELLE %s | "
      "Position=%s | "
      "Ouverte le %s à %.*f | "
      "Volume=%s lot(s) | "
      "Niveau=%.*f | "
      "Bid=%.*f Ask=%.*f | "
      "Sortie=%.*f | "
      "Résultat=%.1f points | "
      "Résultat monétaire=%.*f %s",

      exitReason,

      VirtualPositionStateToString(
        previousState),

      TimeToString(
        previousEntryTime,
        TIME_DATE|TIME_MINUTES),

      m_digits,
      previousEntryPrice,

      m_volumeCalculator.FormatVolume(
        previousVolume),

      m_digits,
      triggerPrice,

      m_digits,
      bid,

      m_digits,
      ask,

      m_digits,
      exitPrice,

      resultPoints,

      m_accountCurrencyDigits,
      resultMoney,

      m_accountCurrency);

    return true;
  }


  // --------------------------------------------------
  // Traite le signal à la nouvelle bougie.
  // --------------------------------------------------
bool ProcessSignal(
  const ENUM_PB_TRADE_SIGNAL signal,
  const SMaDynamics &entryMaDynamics,
  const SLocalMarketDynamics &entryLocalDynamics,
  const datetime executionTime,
  const double bid,
  const double ask,
  string &eventMessage,
  const bool allowFlatEntry = true,
  const bool allowReversalEntry = true,
  const bool entryAtrValid = false,
  const double entryAtrPoints = 0.0,
  const int entryStopLossPoints = 0,
  const int entryTakeProfitPoints = 0,
  const int entryBreakEvenTriggerPoints = 0,
  const bool entryTrendContextValid = false,
  const double entryTrendClose1 = 0.0,
  const double entryTrendMa1 = 0.0,
  const double entryTrendMa2 = 0.0,
  const bool entryTrendAligned = false) {
    eventMessage = "";

    if (!m_isInitialized) {
      eventMessage =
        "Le gestionnaire de positions virtuelles n'est pas initialisé.";

      return false;
    }

    if (bid <= 0.0 || ask <= 0.0 || ask < bid) {
      eventMessage = StringFormat(
        "Cotation invalide : Bid=%.*f Ask=%.*f",

        m_digits,
        bid,

        m_digits,
        ask);

      return false;
    }

    double entrySpreadPoints = 0.0;

    if (m_point > 0.0) {
      entrySpreadPoints =
        (ask - bid) /
        m_point;
    }

    m_lastKnownTime = executionTime;
    m_lastKnownBid = bid;
    m_lastKnownAsk = ask;

    if (signal == PB_SIGNAL_NONE)
    return true;

    ENUM_PB_VIRTUAL_POSITION_STATE newState;
    double newEntryPrice = 0.0;

    if (signal == PB_SIGNAL_BUY) {
      newState = PB_VIRTUAL_POSITION_LONG;
      newEntryPrice = ask;
    } else if (signal == PB_SIGNAL_SELL) {
      newState = PB_VIRTUAL_POSITION_SHORT;
      newEntryPrice = bid;
    } else {
      eventMessage = "Signal inconnu.";
      return false;
    }

    // --------------------------------------------------
    // Aucune position ouverte : le signal peut ouvrir
    // une nouvelle position uniquement si la stratégie
    // autorise une entrée depuis FLAT.
    // --------------------------------------------------
    if (m_state == PB_VIRTUAL_POSITION_FLAT) {
      if (!allowFlatEntry) {
        eventMessage = StringFormat(
          "SIGNAL SANS OUVERTURE | "
          "Position proposée=%s | "
          "Bid=%.*f Ask=%.*f | "
          "Entrée=REFUSÉE",

          VirtualPositionStateToString(
            newState),

          m_digits,
          bid,

          m_digits,
          ask);

        return true;
      }

      string openError;

      if (!OpenPosition(
          newState,
          executionTime,
          newEntryPrice,
          entryMaDynamics,
          entryLocalDynamics,
          false,
          entryAtrValid,
          entryAtrPoints,
          entryStopLossPoints,
          entryTakeProfitPoints,
          entryBreakEvenTriggerPoints,
          entrySpreadPoints,
          entryTrendContextValid,
          entryTrendClose1,
          entryTrendMa1,
          entryTrendMa2,
          entryTrendAligned,
          openError)) {
        eventMessage = StringFormat(
          "Ouverture virtuelle impossible : %s",
          openError);

        return false;
      }

      eventMessage = StringFormat(
        "OUVERTURE VIRTUELLE | "
        "Position=%s | "
        "Bid=%.*f Ask=%.*f | "
        "Entrée=%.*f | "
        "SL=%.*f | TP=%.*f",

        VirtualPositionStateToString(
          m_state),

        m_digits,
        bid,

        m_digits,
        ask,

        m_digits,
        m_entryPrice,

        m_digits,
        m_stopLossPrice,

        m_digits,
        m_takeProfitPrice);

      eventMessage +=
        " | "+
        BuildLastOpeningVolumeSummary();

      return true;
    }

    // Même sens que la position actuelle : rien à faire.
    if (m_state == newState)
    return true;

    // --------------------------------------------------
    // Signal opposé : fermeture puis inversion.
    // --------------------------------------------------
    ENUM_PB_VIRTUAL_POSITION_STATE previousState =
      m_state;

    bool previousOpenedAfterInversion =
      m_currentPositionOpenedAfterInversion;

    datetime previousEntryTime = m_entryTime;
    double previousEntryPrice = m_entryPrice;
    double previousVolume = m_currentPositionVolumeLots;

    double exitPrice =
      (previousState == PB_VIRTUAL_POSITION_LONG)
      ? bid
      : ask;

    double resultPoints = 0.0;
    double resultMoney = 0.0;
    string closeError;

    // IMPORTANT :
    // on clôture d'abord l'ancienne position.
    // CloseCurrentPosition() enregistre les statistiques globales,
    // FLAT / POST-INVERSION et la dynamique MA de cette position.
    if (!CloseCurrentPosition(
        executionTime,
        exitPrice,
        PB_VIRTUAL_EXIT_SIGNAL,
        resultPoints,
        resultMoney,
        closeError)) {
      eventMessage = closeError;
      return false;
    }

    m_signalExitCount++;

    RecordExitPerformance(
      previousState,
      previousOpenedAfterInversion,
      PB_VIRTUAL_EXIT_SIGNAL,
      resultPoints,
      resultMoney);

// --------------------------------------------------
// La position précédente est toujours fermée sur
// signal opposé.
//
// La stratégie peut cependant refuser l'ouverture
// immédiate de la position opposée.
// --------------------------------------------------
if (!allowReversalEntry) {

  eventMessage = StringFormat(
    "SORTIE VIRTUELLE SUR SIGNAL | "
    "Fermeture %s ouverte le %s à %.*f | "
    "Sortie=%.*f | "
    "Résultat=%.1f points | "
    "Résultat monétaire=%.*f %s | "
    "Réouverture opposée=REFUSÉE",

    VirtualPositionStateToString(
      previousState),

    TimeToString(
      previousEntryTime,
      TIME_DATE|TIME_MINUTES),

    m_digits,
    previousEntryPrice,

    m_digits,
    exitPrice,

    resultPoints,

    m_accountCurrencyDigits,
    resultMoney,

    m_accountCurrency);

  return true;
}

    // L'ancienne position est maintenant fermée.
    // On ouvre la position opposée avec la dynamique
    // correspondant au signal courant.

    string openError;

    if (!OpenPosition(
        newState,
        executionTime,
        newEntryPrice,
        entryMaDynamics,
        entryLocalDynamics,
        true,
        entryAtrValid,
        entryAtrPoints,
        entryStopLossPoints,
        entryTakeProfitPoints,
        entryBreakEvenTriggerPoints,
        entrySpreadPoints,
        entryTrendContextValid,
        entryTrendClose1,
        entryTrendMa1,
        entryTrendMa2,
        entryTrendAligned,
        openError)) {
      eventMessage = StringFormat(
        "La position précédente a été fermée, "
        "mais l'ouverture opposée a échoué : %s",
        openError);

      return false;
    }

    m_reversalCount++;

    eventMessage = StringFormat(
      "INVERSION VIRTUELLE | "
      "Bid=%.*f Ask=%.*f | "
      "Fermeture %s ouverte le %s à %.*f | "
      "Volume précédent=%s lot(s) | "
      "Sortie=%.*f | "
      "Résultat=%.1f points | "
      "Résultat monétaire=%.*f %s | "
      "Ouverture %s à %.*f",

      m_digits,
      bid,

      m_digits,
      ask,

      VirtualPositionStateToString(
        previousState),

      TimeToString(
        previousEntryTime,
        TIME_DATE|TIME_MINUTES),

      m_digits,
      previousEntryPrice,

      m_volumeCalculator.FormatVolume(
        previousVolume),

      m_digits,
      exitPrice,

      resultPoints,

      m_accountCurrencyDigits,
      resultMoney,

      m_accountCurrency,

      VirtualPositionStateToString(
        m_state),

      m_digits,
      newEntryPrice);

    eventMessage +=
      " | Nouvelle position : "+
      BuildLastOpeningVolumeSummary();

    return true;
  }


  // --------------------------------------------------
  // Vérifie les invariants des statistiques.
  // --------------------------------------------------
  bool IsConsistent(void) const {
    if (!m_isInitialized)
    return false;

    if (m_closedTradeCount !=
      m_winningTradeCount+
      m_losingTradeCount+
      m_breakEvenTradeCount) {
      return false;
    }

    if (m_closedTradeCount !=
      m_signalExitCount+
      m_stopLossExitCount+
      m_takeProfitExitCount) {
      return false;
    }

    if (m_entryAtrValidTradeCount !=
        m_entryAtrWinningTradeCount+
        m_entryAtrLosingTradeCount+
        m_entryAtrBreakEvenTradeCount) {
      return false;
    }

    if (m_entryAtrValidTradeCount+
        m_entryAtrUnavailableTradeCount !=
        m_closedTradeCount) {
      return false;
    }

    int expectedOpenDifference =
      (m_state == PB_VIRTUAL_POSITION_FLAT)
      ? 0
      : 1;

    if (m_openCount - m_closedTradeCount !=
      expectedOpenDifference) {
      return false;
    }

    if (m_state == PB_VIRTUAL_POSITION_FLAT &&
      m_currentPositionVolumeLots != 0.0) {
      return false;
    }

    if (m_state != PB_VIRTUAL_POSITION_FLAT &&
      m_currentPositionVolumeLots <= 0.0) {
      return false;
    }

    if (m_currentLosingStreak < 0 ||
      m_maxLosingStreak < 0 ||
      m_currentLosingStreak > m_maxLosingStreak ||
      m_maxLosingStreak > m_losingTradeCount) {
      return false;
    }

    if (m_peakVirtualCapital < m_initialVirtualCapital ||
      m_maxDrawdownMoney < 0.0 ||
      m_maxDrawdownPercent < 0.0 ||
      m_maxDrawdownPercent > 100.0) {
      return false;
    }

    if (m_peakVirtualEquity < m_initialVirtualCapital ||
      m_maxEquityDrawdownMoney < 0.0 ||
      m_maxEquityDrawdownPercent < 0.0 ||
      m_maxEquityDrawdownPercent > 100.0) {
      return false;
    }

    if (m_maxDrawdownMoney > 0.0) {
      if (m_maxCapitalDrawdownStartTime <= 0 ||
        m_maxCapitalDrawdownLowTime <= 0 ||
        m_maxCapitalDrawdownStartTime >
        m_maxCapitalDrawdownLowTime) {
        return false;
      }
    }


    if (m_maxEquityDrawdownMoney > 0.0) {
      if (m_maxEquityDrawdownStartTime <= 0 ||
        m_maxEquityDrawdownLowTime <= 0 ||
        m_maxEquityDrawdownStartTime >
        m_maxEquityDrawdownLowTime) {
        return false;
      }
    }

    // --------------------------------------------------
    // Cohérence des statistiques LONG / SHORT.
    // --------------------------------------------------

    // Tous les trades clôturés doivent être soit LONG,
    // soit SHORT.
    if (m_longClosedTradeCount+
      m_shortClosedTradeCount !=
      m_closedTradeCount)
    return false;


    // Même contrôle pour les trades gagnants.
    if (m_longWinningTradeCount+
      m_shortWinningTradeCount !=
      m_winningTradeCount)
    return false;


    // Même contrôle pour les trades perdants.
    if (m_longLosingTradeCount+
      m_shortLosingTradeCount !=
      m_losingTradeCount)
    return false;


    // Même contrôle pour les trades neutres.
    if (m_longBreakEvenTradeCount+
      m_shortBreakEvenTradeCount !=
      m_breakEvenTradeCount)
    return false;


    // Chaque ensemble LONG doit être cohérent en lui-même.
    if (m_longWinningTradeCount+
      m_longLosingTradeCount+
      m_longBreakEvenTradeCount !=
      m_longClosedTradeCount)
    return false;


    // Même contrôle pour les SHORT.
    if (m_shortWinningTradeCount+
      m_shortLosingTradeCount+
      m_shortBreakEvenTradeCount !=
      m_shortClosedTradeCount)
    return false;

    // --------------------------------------------------
    // Cohérence des performances par motif de sortie.
    // --------------------------------------------------

    // SIGNAL : toutes les sorties doivent être classées.
    if (m_signalExitWinningCount+
      m_signalExitLosingCount+
      m_signalExitBreakEvenCount !=
      m_signalExitCount)
    return false;


    // STOP LOSS : toutes les sorties doivent être classées.
    if (m_stopLossWinningCount+
      m_stopLossLosingCount+
      m_stopLossBreakEvenCount !=
      m_stopLossExitCount)
    return false;


    // TAKE PROFIT : toutes les sorties doivent être classées.
    if (m_takeProfitWinningCount+
      m_takeProfitLosingCount+
      m_takeProfitBreakEvenCount !=
      m_takeProfitExitCount)
    return false;


    // Tous les trades gagnants doivent provenir
    // d'un des trois motifs de sortie.
    if (m_signalExitWinningCount+
      m_stopLossWinningCount+
      m_takeProfitWinningCount !=
      m_winningTradeCount)
    return false;


    // Même contrôle pour les trades perdants.
    if (m_signalExitLosingCount+
      m_stopLossLosingCount+
      m_takeProfitLosingCount !=
      m_losingTradeCount)
    return false;


    // Même contrôle pour les trades neutres.
    if (m_signalExitBreakEvenCount+
      m_stopLossBreakEvenCount+
      m_takeProfitBreakEvenCount !=
      m_breakEvenTradeCount)
    return false;

    // --------------------------------------------------
    // Cohérence de la matrice sens × motif de sortie.
    // --------------------------------------------------

    // Toutes les positions LONG clôturées doivent être
    // réparties entre SIGNAL, STOP LOSS et TAKE PROFIT.
    if (m_longSignalExitCount+
      m_longStopLossExitCount+
      m_longTakeProfitExitCount !=
      m_longClosedTradeCount)
    return false;


    // Même contrôle pour les positions SHORT.
    if (m_shortSignalExitCount+
      m_shortStopLossExitCount+
      m_shortTakeProfitExitCount !=
      m_shortClosedTradeCount)
    return false;


    // Toutes les sorties SIGNAL doivent être soit LONG,
    // soit SHORT.
    if (m_longSignalExitCount+
      m_shortSignalExitCount !=
      m_signalExitCount)
    return false;


    // Même contrôle pour les STOP LOSS.
    if (m_longStopLossExitCount+
      m_shortStopLossExitCount !=
      m_stopLossExitCount)
    return false;


    // Même contrôle pour les TAKE PROFIT.
    if (m_longTakeProfitExitCount+
      m_shortTakeProfitExitCount !=
      m_takeProfitExitCount)
    return false;

    // --------------------------------------------------
    // Cohérence monétaire de la matrice.
    // --------------------------------------------------
    const double moneyTolerance = 0.01;


    // Ligne LONG.
    if (MathAbs(
        m_longSignalExitMoney+
        m_longStopLossExitMoney+
        m_longTakeProfitExitMoney-
        m_longTotalClosedMoney) > moneyTolerance)
    return false;


    // Ligne SHORT.
    if (MathAbs(
        m_shortSignalExitMoney+
        m_shortStopLossExitMoney+
        m_shortTakeProfitExitMoney-
        m_shortTotalClosedMoney) > moneyTolerance)
    return false;


    // Colonne SIGNAL.
    if (MathAbs(
        m_longSignalExitMoney+
        m_shortSignalExitMoney-
        m_signalExitTotalMoney) > moneyTolerance)
    return false;


    // Colonne STOP LOSS.
    if (MathAbs(
        m_longStopLossExitMoney+
        m_shortStopLossExitMoney-
        m_stopLossTotalMoney) > moneyTolerance)
    return false;


    // Colonne TAKE PROFIT.
    if (MathAbs(
        m_longTakeProfitExitMoney+
        m_shortTakeProfitExitMoney-
        m_takeProfitTotalMoney) > moneyTolerance)
    return false;


    // Total LONG + SHORT.
    if (MathAbs(
        m_longTotalClosedMoney+
        m_shortTotalClosedMoney-
        m_totalClosedMoney) > moneyTolerance)
    return false;

    // --------------------------------------------------
    // Cohérence du détail des sorties SIGNAL
    // selon le sens LONG / SHORT.
    // --------------------------------------------------

    // Tous les SIGNAL gagnants doivent être répartis
    // entre LONG et SHORT.
    if (m_longSignalWinningCount+
      m_shortSignalWinningCount !=
      m_signalExitWinningCount)
    return false;


    // Tous les SIGNAL perdants doivent être répartis
    // entre LONG et SHORT.
    if (m_longSignalLosingCount+
      m_shortSignalLosingCount !=
      m_signalExitLosingCount)
    return false;


    // Les nombres gagnants/perdants ne peuvent pas
    // dépasser le nombre de sorties SIGNAL du sens.
    if (m_longSignalWinningCount+
      m_longSignalLosingCount >
      m_longSignalExitCount)
    return false;

    if (m_shortSignalWinningCount+
      m_shortSignalLosingCount >
      m_shortSignalExitCount)
    return false;

    // --------------------------------------------------
    // Cohérence monétaire du détail des sorties SIGNAL.
    // --------------------------------------------------

    // Les gains SIGNAL LONG + SHORT doivent retrouver
    // les gains bruts SIGNAL globaux.
    if (MathAbs(
        m_longSignalWinningMoney+
        m_shortSignalWinningMoney-
        m_signalExitGrossProfitMoney) > moneyTolerance)
    return false;


    // Même contrôle pour les pertes brutes.
    if (MathAbs(
        m_longSignalLosingMoney+
        m_shortSignalLosingMoney-
        m_signalExitGrossLossMoney) > moneyTolerance)
    return false;


    // Résultat net des SIGNAL LONG.
    if (MathAbs(
        m_longSignalWinningMoney-
        m_longSignalLosingMoney-
        m_longSignalExitMoney) > moneyTolerance)
    return false;


    // Résultat net des SIGNAL SHORT.
    if (MathAbs(
        m_shortSignalWinningMoney-
        m_shortSignalLosingMoney-
        m_shortSignalExitMoney) > moneyTolerance)
    return false;

    // --------------------------------------------------
    // Cohérence des positions ouvertes après inversion.
    // --------------------------------------------------

    // Toute position post-inversion clôturée doit être
    // gagnante, perdante ou neutre.
    if (m_inversionTradeWinningCount+
      m_inversionTradeLosingCount+
      m_inversionTradeBreakEvenCount !=
      m_inversionTradeClosedCount)
    return false;


    // Répartition LONG + SHORT.
    if (m_inversionLongClosedCount+
      m_inversionShortClosedCount !=
      m_inversionTradeClosedCount)
    return false;


    // Une position FLAT ne peut pas être marquée
    // comme ayant été ouverte après inversion.
    if (m_state == PB_VIRTUAL_POSITION_FLAT &&
      m_currentPositionOpenedAfterInversion)
    return false;

    // --------------------------------------------------
    // Cohérence monétaire post-inversion.
    // --------------------------------------------------

    // LONG + SHORT = total post-inversion.
    if (MathAbs(
        m_inversionLongTotalMoney+
        m_inversionShortTotalMoney-
        m_inversionTradeTotalMoney) > moneyTolerance)
    return false;


    // Gains bruts - pertes brutes = résultat net.
    if (MathAbs(
        m_inversionTradeGrossProfitMoney-
        m_inversionTradeGrossLossMoney-
        m_inversionTradeTotalMoney) > moneyTolerance)
    return false;

    // --------------------------------------------------
    // Cohérence des positions ouvertes depuis FLAT.
    // --------------------------------------------------

    // Toute position ouverte depuis FLAT puis clôturée
    // doit être gagnante, perdante ou neutre.
    if (m_flatEntryTradeWinningCount+
      m_flatEntryTradeLosingCount+
      m_flatEntryTradeBreakEvenCount !=
      m_flatEntryTradeClosedCount)
    return false;


    // Répartition LONG + SHORT des entrées depuis FLAT.
    if (m_flatEntryLongClosedCount+
      m_flatEntryShortClosedCount !=
      m_flatEntryTradeClosedCount)
    return false;

    // --------------------------------------------------
    // Toute position clôturée doit provenir soit
    // d'une entrée depuis FLAT, soit d'une inversion.
    // --------------------------------------------------
    if (m_flatEntryTradeClosedCount+
      m_inversionTradeClosedCount !=
      m_closedTradeCount)
    return false;


    // Même contrôle pour les gagnants.
    if (m_flatEntryTradeWinningCount+
      m_inversionTradeWinningCount !=
      m_winningTradeCount)
    return false;


    // Même contrôle pour les perdants.
    if (m_flatEntryTradeLosingCount+
      m_inversionTradeLosingCount !=
      m_losingTradeCount)
    return false;


    // Même contrôle pour les neutres.
    if (m_flatEntryTradeBreakEvenCount+
      m_inversionTradeBreakEvenCount !=
      m_breakEvenTradeCount)
    return false;

    // --------------------------------------------------
    // Cohérence selon le sens de la position.
    // --------------------------------------------------

    // Tous les LONG proviennent de FLAT ou
    // d'une inversion.
    if (m_flatEntryLongClosedCount+
      m_inversionLongClosedCount !=
      m_longClosedTradeCount)
    return false;


    // Même contrôle pour les SHORT.
    if (m_flatEntryShortClosedCount+
      m_inversionShortClosedCount !=
      m_shortClosedTradeCount)
    return false;

    // --------------------------------------------------
    // Cohérence monétaire des entrées depuis FLAT.
    // --------------------------------------------------

    // LONG + SHORT = résultat total depuis FLAT.
    if (MathAbs(
        m_flatEntryLongTotalMoney+
        m_flatEntryShortTotalMoney-
        m_flatEntryTradeTotalMoney) > moneyTolerance)
    return false;


    // Gains bruts - pertes brutes = résultat net FLAT.
    if (MathAbs(
        m_flatEntryTradeGrossProfitMoney-
        m_flatEntryTradeGrossLossMoney-
        m_flatEntryTradeTotalMoney) > moneyTolerance)
    return false;


    // --------------------------------------------------
    // FLAT + POST-INVERSION = résultat global.
    // --------------------------------------------------
    if (MathAbs(
        m_flatEntryTradeTotalMoney+
        m_inversionTradeTotalMoney-
        m_totalClosedMoney) > moneyTolerance)
    return false;


    // Gains bruts des deux populations = gains globaux.
    if (MathAbs(
        m_flatEntryTradeGrossProfitMoney+
        m_inversionTradeGrossProfitMoney-
        m_grossProfitMoney) > moneyTolerance)
    return false;


    // Pertes brutes des deux populations = pertes globales.
    if (MathAbs(
        m_flatEntryTradeGrossLossMoney+
        m_inversionTradeGrossLossMoney-
        m_grossLossMoney) > moneyTolerance)
    return false;

    // --------------------------------------------------
    // Cohérence origine de l'entrée × motif de sortie.
    // --------------------------------------------------

    // Toutes les positions ouvertes depuis FLAT doivent
    // se terminer par SIGNAL, STOP LOSS ou TAKE PROFIT.
    if (m_flatEntrySignalExitCount+
      m_flatEntryStopLossExitCount+
      m_flatEntryTakeProfitExitCount !=
      m_flatEntryTradeClosedCount)
    return false;


    // Même contrôle pour les positions post-inversion.
    if (m_inversionEntrySignalExitCount+
      m_inversionEntryStopLossExitCount+
      m_inversionEntryTakeProfitExitCount !=
      m_inversionTradeClosedCount)
    return false;


    // Toutes les sorties SIGNAL doivent provenir
    // d'une entrée depuis FLAT ou post-inversion.
    if (m_flatEntrySignalExitCount+
      m_inversionEntrySignalExitCount !=
      m_signalExitCount)
    return false;


    // Même contrôle pour les STOP LOSS.
    if (m_flatEntryStopLossExitCount+
      m_inversionEntryStopLossExitCount !=
      m_stopLossExitCount)
    return false;


    // Même contrôle pour les TAKE PROFIT.
    if (m_flatEntryTakeProfitExitCount+
      m_inversionEntryTakeProfitExitCount !=
      m_takeProfitExitCount)
    return false;

    // --------------------------------------------------
    // Cohérence monétaire origine × motif de sortie.
    // --------------------------------------------------

    // Ligne : entrées depuis FLAT.
    if (MathAbs(
        m_flatEntrySignalExitMoney+
        m_flatEntryStopLossExitMoney+
        m_flatEntryTakeProfitExitMoney-
        m_flatEntryTradeTotalMoney) > moneyTolerance)
    return false;


    // Ligne : entrées post-inversion.
    if (MathAbs(
        m_inversionEntrySignalExitMoney+
        m_inversionEntryStopLossExitMoney+
        m_inversionEntryTakeProfitExitMoney-
        m_inversionTradeTotalMoney) > moneyTolerance)
    return false;


    // Colonne : sorties SIGNAL.
    if (MathAbs(
        m_flatEntrySignalExitMoney+
        m_inversionEntrySignalExitMoney-
        m_signalExitTotalMoney) > moneyTolerance)
    return false;


    // Colonne : sorties STOP LOSS.
    if (MathAbs(
        m_flatEntryStopLossExitMoney+
        m_inversionEntryStopLossExitMoney-
        m_stopLossTotalMoney) > moneyTolerance)
    return false;


    // Colonne : sorties TAKE PROFIT.
    if (MathAbs(
        m_flatEntryTakeProfitExitMoney+
        m_inversionEntryTakeProfitExitMoney-
        m_takeProfitTotalMoney) > moneyTolerance)
    return false;

    // --------------------------------------------------
    // v1.18 - Cohérence des statistiques de dynamique MA.
    //
    // slopeCurrent correspond exactement à l'ancienne
    // statistique de pente directionnelle S0.
    // --------------------------------------------------

    if (MathAbs(
        m_flatEntryWinningDynamicsSum.slopeCurrent-
        m_flatEntryWinningSlopeSum) > moneyTolerance)
    return false;

    if (MathAbs(
        m_flatEntryLosingDynamicsSum.slopeCurrent-
        m_flatEntryLosingSlopeSum) > moneyTolerance)
    return false;

    if (MathAbs(
        m_inversionEntryWinningDynamicsSum.slopeCurrent-
        m_inversionEntryWinningSlopeSum) > moneyTolerance)
    return false;

    if (MathAbs(
        m_inversionEntryLosingDynamicsSum.slopeCurrent-
        m_inversionEntryLosingSlopeSum) > moneyTolerance)
    return false;

    // --------------------------------------------------
    // v1.20 - Les observations locales ne peuvent jamais
    // être plus nombreuses que les trades correspondants.
    // --------------------------------------------------
    if (m_flatEntryWinningLocalDynamicsCount >
      m_flatEntryTradeWinningCount)
    return false;

    if (m_flatEntryLosingLocalDynamicsCount >
      m_flatEntryTradeLosingCount)
    return false;

    if (m_inversionEntryWinningLocalDynamicsCount >
      m_inversionTradeWinningCount)
    return false;

    if (m_inversionEntryLosingLocalDynamicsCount >
      m_inversionTradeLosingCount)
    return false;

    return true;
  }

  // --------------------------------------------------
  // v1.18 - Sommes des dynamiques MA à l'entrée.
  //
  // Elles permettront de calculer les moyennes de :
  // S2, S1, S0, A1 et A0.
  // --------------------------------------------------

  // Entrées depuis FLAT
  SMaDynamics m_flatEntryWinningDynamicsSum;
  SMaDynamics m_flatEntryLosingDynamicsSum;

  // Entrées post-inversion
  SMaDynamics m_inversionEntryWinningDynamicsSum;
  SMaDynamics m_inversionEntryLosingDynamicsSum;

  // --------------------------------------------------
  // Matrice des positions ouvertes depuis FLAT
  // selon leur motif de sortie.
  // --------------------------------------------------
  string BuildFlatEntryExitMatrixSummary(void) const {
    return StringFormat(
      "Matrice entrée FLAT : "
      "SIGNAL=%d trade(s) / %.2f EUR | "
      "STOP LOSS=%d trade(s) / %.2f EUR | "
      "TAKE PROFIT=%d trade(s) / %.2f EUR | "
      "TOTAL=%d trade(s) / %.2f EUR",

      m_flatEntrySignalExitCount,
      m_flatEntrySignalExitMoney,

      m_flatEntryStopLossExitCount,
      m_flatEntryStopLossExitMoney,

      m_flatEntryTakeProfitExitCount,
      m_flatEntryTakeProfitExitMoney,

      m_flatEntryTradeClosedCount,
      m_flatEntryTradeTotalMoney);
  }

  // --------------------------------------------------
  // Matrice des positions ouvertes après inversion
  // selon leur motif de sortie.
  // --------------------------------------------------
  string BuildInversionEntryExitMatrixSummary(void) const {
    return StringFormat(
      "Matrice entrée POST-INVERSION : "
      "SIGNAL=%d trade(s) / %.2f EUR | "
      "STOP LOSS=%d trade(s) / %.2f EUR | "
      "TAKE PROFIT=%d trade(s) / %.2f EUR | "
      "TOTAL=%d trade(s) / %.2f EUR",

      m_inversionEntrySignalExitCount,
      m_inversionEntrySignalExitMoney,

      m_inversionEntryStopLossExitCount,
      m_inversionEntryStopLossExitMoney,

      m_inversionEntryTakeProfitExitCount,
      m_inversionEntryTakeProfitExitMoney,

      m_inversionTradeClosedCount,
      m_inversionTradeTotalMoney);
  }

  // --------------------------------------------------
  // Résume les sorties sur SIGNAL des positions LONG.
  // --------------------------------------------------
  string BuildLongSignalDetailSummary(void) const {
    int neutralCount =
      m_longSignalExitCount-
      m_longSignalWinningCount-
      m_longSignalLosingCount;

    double winRate = 0.0;

    if (m_longSignalExitCount > 0)
    winRate =
      100.0*
      (double)m_longSignalWinningCount/
      (double)m_longSignalExitCount;


    double expectancy = 0.0;

    if (m_longSignalExitCount > 0)
    expectancy =
      m_longSignalExitMoney/
      (double)m_longSignalExitCount;


    double profitFactor = 0.0;

    if (m_longSignalLosingMoney > 0.0)
    profitFactor =
      m_longSignalWinningMoney/
      m_longSignalLosingMoney;


    return StringFormat(
      "Détail SIGNAL LONG : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Taux réussite=%.2f%% | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_longSignalExitCount,
      m_longSignalWinningCount,
      m_longSignalLosingCount,
      neutralCount,
      winRate,
      m_longSignalWinningMoney,
      m_longSignalLosingMoney,
      m_longSignalExitMoney,
      profitFactor,
      expectancy);
  }

  // --------------------------------------------------
  // Résume les sorties sur SIGNAL des positions SHORT.
  // --------------------------------------------------
  string BuildShortSignalDetailSummary(void) const {
    int neutralCount =
      m_shortSignalExitCount-
      m_shortSignalWinningCount-
      m_shortSignalLosingCount;

    double winRate = 0.0;

    if (m_shortSignalExitCount > 0)
    winRate =
      100.0*
      (double)m_shortSignalWinningCount/
      (double)m_shortSignalExitCount;


    double expectancy = 0.0;

    if (m_shortSignalExitCount > 0)
    expectancy =
      m_shortSignalExitMoney/
      (double)m_shortSignalExitCount;


    double profitFactor = 0.0;

    if (m_shortSignalLosingMoney > 0.0)
    profitFactor =
      m_shortSignalWinningMoney/
      m_shortSignalLosingMoney;


    return StringFormat(
      "Détail SIGNAL SHORT : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Taux réussite=%.2f%% | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_shortSignalExitCount,
      m_shortSignalWinningCount,
      m_shortSignalLosingCount,
      neutralCount,
      winRate,
      m_shortSignalWinningMoney,
      m_shortSignalLosingMoney,
      m_shortSignalExitMoney,
      profitFactor,
      expectancy);
  }

  // --------------------------------------------------
  // Résume les performances des positions ouvertes
  // depuis FLAT, donc sans position préalable.
  // --------------------------------------------------
  string BuildFlatEntryTradeSummary(void) const {
    double profitFactor = 0.0;

    if (m_flatEntryTradeGrossLossMoney > 0.0)
    profitFactor =
      m_flatEntryTradeGrossProfitMoney/
      m_flatEntryTradeGrossLossMoney;


    double expectancy = 0.0;

    if (m_flatEntryTradeClosedCount > 0)
    expectancy =
      m_flatEntryTradeTotalMoney/
      (double)m_flatEntryTradeClosedCount;


    double winRate = 0.0;

    if (m_flatEntryTradeClosedCount > 0)
    winRate =
      100.0*
      (double)m_flatEntryTradeWinningCount/
      (double)m_flatEntryTradeClosedCount;


    return StringFormat(
      "Résumé entrée depuis FLAT : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Taux réussite=%.2f%% | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_flatEntryTradeClosedCount,
      m_flatEntryTradeWinningCount,
      m_flatEntryTradeLosingCount,
      m_flatEntryTradeBreakEvenCount,
      winRate,
      m_flatEntryTradeTotalPoints,
      m_flatEntryTradeGrossProfitMoney,
      m_flatEntryTradeGrossLossMoney,
      m_flatEntryTradeTotalMoney,
      profitFactor,
      expectancy);
  }

  // --------------------------------------------------
  // Résume les LONG / SHORT ouverts depuis FLAT.
  // --------------------------------------------------
  string BuildFlatEntryDirectionSummary(void) const {
    double longExpectancy = 0.0;

    if (m_flatEntryLongClosedCount > 0)
    longExpectancy =
      m_flatEntryLongTotalMoney/
      (double)m_flatEntryLongClosedCount;


    double shortExpectancy = 0.0;

    if (m_flatEntryShortClosedCount > 0)
    shortExpectancy =
      m_flatEntryShortTotalMoney/
      (double)m_flatEntryShortClosedCount;


    return StringFormat(
      "Détail entrée depuis FLAT : "
      "LONG=%d trade(s) / %.2f EUR / espérance=%.2f EUR | "
      "SHORT=%d trade(s) / %.2f EUR / espérance=%.2f EUR",

      m_flatEntryLongClosedCount,
      m_flatEntryLongTotalMoney,
      longExpectancy,

      m_flatEntryShortClosedCount,
      m_flatEntryShortTotalMoney,
      shortExpectancy);
  }


  // --------------------------------------------------
  // Résume les performances des positions ouvertes
  // après une inversion.
  // --------------------------------------------------
  string BuildInversionTradeSummary(void) const {
    double profitFactor = 0.0;

    if (m_inversionTradeGrossLossMoney > 0.0)
    profitFactor =
      m_inversionTradeGrossProfitMoney/
      m_inversionTradeGrossLossMoney;


    double expectancy = 0.0;

    if (m_inversionTradeClosedCount > 0)
    expectancy =
      m_inversionTradeTotalMoney/
      (double)m_inversionTradeClosedCount;


    double winRate = 0.0;

    if (m_inversionTradeClosedCount > 0)
    winRate =
      100.0*
      (double)m_inversionTradeWinningCount/
      (double)m_inversionTradeClosedCount;


    return StringFormat(
      "Résumé post-inversion : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Taux réussite=%.2f%% | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_inversionTradeClosedCount,
      m_inversionTradeWinningCount,
      m_inversionTradeLosingCount,
      m_inversionTradeBreakEvenCount,
      winRate,
      m_inversionTradeTotalPoints,
      m_inversionTradeGrossProfitMoney,
      m_inversionTradeGrossLossMoney,
      m_inversionTradeTotalMoney,
      profitFactor,
      expectancy);
  }

  // --------------------------------------------------
  // Résume la répartition LONG / SHORT des positions
  // ouvertes après inversion.
  // --------------------------------------------------
  string BuildInversionDirectionSummary(void) const {
    double longExpectancy = 0.0;

    if (m_inversionLongClosedCount > 0)
    longExpectancy =
      m_inversionLongTotalMoney/
      (double)m_inversionLongClosedCount;


    double shortExpectancy = 0.0;

    if (m_inversionShortClosedCount > 0)
    shortExpectancy =
      m_inversionShortTotalMoney/
      (double)m_inversionShortClosedCount;


    return StringFormat(
      "Détail post-inversion : "
      "LONG=%d trade(s) / %.2f EUR / espérance=%.2f EUR | "
      "SHORT=%d trade(s) / %.2f EUR / espérance=%.2f EUR",

      m_inversionLongClosedCount,
      m_inversionLongTotalMoney,
      longExpectancy,

      m_inversionShortClosedCount,
      m_inversionShortTotalMoney,
      shortExpectancy);
  }

  // --------------------------------------------------
  // Résume les périodes des drawdowns maximaux.
  // --------------------------------------------------
  string BuildDrawdownTimingSummary(void) const {
    if (!m_isInitialized)
    return "Périodes de drawdown indisponibles : gestionnaire non initialisé.";

    string capitalPeriod = "AUCUN";

    if (m_maxDrawdownMoney > 0.0 &&
      m_maxCapitalDrawdownStartTime > 0 &&
      m_maxCapitalDrawdownLowTime > 0) {
      capitalPeriod = StringFormat(
        "début=%s | creux=%s",

        TimeToString(
          m_maxCapitalDrawdownStartTime,
          TIME_DATE|TIME_MINUTES),

        TimeToString(
          m_maxCapitalDrawdownLowTime,
          TIME_DATE|TIME_MINUTES));
    }


    string equityPeriod = "AUCUN";

    if (m_maxEquityDrawdownMoney > 0.0 &&
      m_maxEquityDrawdownStartTime > 0 &&
      m_maxEquityDrawdownLowTime > 0) {
      equityPeriod = StringFormat(
        "début=%s | creux=%s",

        TimeToString(
          m_maxEquityDrawdownStartTime,
          TIME_DATE|TIME_MINUTES),

        TimeToString(
          m_maxEquityDrawdownLowTime,
          TIME_DATE|TIME_MINUTES));
    }


    return StringFormat(
      "Période drawdown capital : %s | "
      "Période drawdown équité : %s",

      capitalPeriod,
      equityPeriod);
  }

  string BuildSignalExitSummary(void) const {
    double profitFactor = 0.0;

    if (m_signalExitGrossLossMoney > 0.0)
    profitFactor =
      m_signalExitGrossProfitMoney/
      m_signalExitGrossLossMoney;


    double expectancy = 0.0;

    if (m_signalExitCount > 0)
    expectancy =
      m_signalExitTotalMoney/
      (double)m_signalExitCount;


    return StringFormat(
      "Résumé sorties SIGNAL : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_signalExitCount,
      m_signalExitWinningCount,
      m_signalExitLosingCount,
      m_signalExitBreakEvenCount,
      m_signalExitTotalPoints,
      m_signalExitGrossProfitMoney,
      m_signalExitGrossLossMoney,
      m_signalExitTotalMoney,
      profitFactor,
      expectancy);
  }

  string BuildStopLossSummary(void) const {
    double profitFactor = 0.0;

    if (m_stopLossGrossLossMoney > 0.0)
    profitFactor =
      m_stopLossGrossProfitMoney/
      m_stopLossGrossLossMoney;


    double expectancy = 0.0;

    if (m_stopLossExitCount > 0)
    expectancy =
      m_stopLossTotalMoney/
      (double)m_stopLossExitCount;


    return StringFormat(
      "Résumé sorties STOP LOSS : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_stopLossExitCount,
      m_stopLossWinningCount,
      m_stopLossLosingCount,
      m_stopLossBreakEvenCount,
      m_stopLossTotalPoints,
      m_stopLossGrossProfitMoney,
      m_stopLossGrossLossMoney,
      m_stopLossTotalMoney,
      profitFactor,
      expectancy);
  }

  string BuildTakeProfitSummary(void) const {
    double profitFactor = 0.0;

    if (m_takeProfitGrossLossMoney > 0.0)
    profitFactor =
      m_takeProfitGrossProfitMoney/
      m_takeProfitGrossLossMoney;


    double expectancy = 0.0;

    if (m_takeProfitExitCount > 0)
    expectancy =
      m_takeProfitTotalMoney/
      (double)m_takeProfitExitCount;


    return StringFormat(
      "Résumé sorties TAKE PROFIT : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_takeProfitExitCount,
      m_takeProfitWinningCount,
      m_takeProfitLosingCount,
      m_takeProfitBreakEvenCount,
      m_takeProfitTotalPoints,
      m_takeProfitGrossProfitMoney,
      m_takeProfitGrossLossMoney,
      m_takeProfitTotalMoney,
      profitFactor,
      expectancy);
  }

  string BuildEntryAtrSummary(void) const {

    if (m_entryAtrValidTradeCount <= 0) {
      return StringFormat(
        "Résumé ATR entrée : aucune observation valide | "
        "Indisponibles=%d",
        m_entryAtrUnavailableTradeCount);
    }

    double winningAtrAverage = 0.0;
    double losingAtrAverage = 0.0;
    double breakEvenAtrAverage = 0.0;

    double winningStopLossAtrAverage = 0.0;
    double losingStopLossAtrAverage = 0.0;
    double breakEvenStopLossAtrAverage = 0.0;

    if (m_entryAtrWinningTradeCount > 0) {
      winningAtrAverage =
        m_entryAtrWinningPointsSum /
        (double)m_entryAtrWinningTradeCount;

      winningStopLossAtrAverage =
        m_entryStopLossAtrWinningSum /
        (double)m_entryAtrWinningTradeCount;
    }

    if (m_entryAtrLosingTradeCount > 0) {
      losingAtrAverage =
        m_entryAtrLosingPointsSum /
        (double)m_entryAtrLosingTradeCount;

      losingStopLossAtrAverage =
        m_entryStopLossAtrLosingSum /
        (double)m_entryAtrLosingTradeCount;
    }

    if (m_entryAtrBreakEvenTradeCount > 0) {
      breakEvenAtrAverage =
        m_entryAtrBreakEvenPointsSum /
        (double)m_entryAtrBreakEvenTradeCount;

      breakEvenStopLossAtrAverage =
        m_entryStopLossAtrBreakEvenSum /
        (double)m_entryAtrBreakEvenTradeCount;
    }

    return StringFormat(
      "Résumé ATR entrée : "
      "Valides=%d | Indisponibles=%d | "
      "Gagnants=%d ATR moyen=%.1f pts SL moyen=%.2f ATR | "
      "Perdants=%d ATR moyen=%.1f pts SL moyen=%.2f ATR | "
      "Neutres=%d ATR moyen=%.1f pts SL moyen=%.2f ATR",

      m_entryAtrValidTradeCount,
      m_entryAtrUnavailableTradeCount,

      m_entryAtrWinningTradeCount,
      winningAtrAverage,
      winningStopLossAtrAverage,

      m_entryAtrLosingTradeCount,
      losingAtrAverage,
      losingStopLossAtrAverage,

      m_entryAtrBreakEvenTradeCount,
      breakEvenAtrAverage,
      breakEvenStopLossAtrAverage);
  }


  string BuildLosingTradeMfeSummary(void) const {

    if (m_losingMfeTradeCount <= 0)
      return "MFE trades perdants : aucune observation.";

    return StringFormat(
      "MFE trades perdants : Total=%d | "
      ">=50 pts=%d | >=100 pts=%d | "
      ">=200 pts=%d | >=300 pts=%d",
      m_losingMfeTradeCount,
      m_losingReached50Points,
      m_losingReached100Points,
      m_losingReached200Points,
      m_losingReached300Points);
  }


  // --------------------------------------------------
  // Nombre d'années présentes dans le bilan.
  // --------------------------------------------------
  int AnnualStatisticsCount(void) const {
    return m_annualStatisticsCount;
  }


  // --------------------------------------------------
  // Construit une ligne de bilan annuel pour le journal.
  // --------------------------------------------------
  string BuildAnnualSummary(
    const int index) const {

    if (index < 0 ||
        index >= m_annualStatisticsCount) {
      return "BILAN ANNUEL : index invalide";
    }

    double profitFactor = 0.0;

    if (m_annualStatistics[index].grossLossMoney > 0.0) {
      profitFactor =
        m_annualStatistics[index].grossProfitMoney/
        m_annualStatistics[index].grossLossMoney;
    }

    double expectancy = 0.0;

    if (m_annualStatistics[index].closedTradeCount > 0) {
      expectancy =
        m_annualStatistics[index].totalClosedMoney/
        (double)m_annualStatistics[index].closedTradeCount;
    }

    return StringFormat(
      "BILAN ANNUEL %d | "
      "Trades=%d | Gagnants=%d | Perdants=%d | Neutres=%d | "
      "Série pertes max=%d | Points=%.1f | "
      "Gains=%.2f %s | Pertes=%.2f %s | Net=%.2f %s | "
      "PF=%.2f | Espérance=%.2f %s | "
      "DD capital=%.2f %s (%.2f%%) | "
      "DD équité=%.2f %s (%.2f%%)",

      m_annualStatistics[index].year,
      m_annualStatistics[index].closedTradeCount,
      m_annualStatistics[index].winningTradeCount,
      m_annualStatistics[index].losingTradeCount,
      m_annualStatistics[index].breakEvenTradeCount,
      m_annualStatistics[index].maxLosingStreak,
      m_annualStatistics[index].totalClosedPoints,

      m_annualStatistics[index].grossProfitMoney,
      m_accountCurrency,

      m_annualStatistics[index].grossLossMoney,
      m_accountCurrency,

      m_annualStatistics[index].totalClosedMoney,
      m_accountCurrency,

      profitFactor,
      expectancy,
      m_accountCurrency,

      m_annualStatistics[index].maxCapitalDrawdownMoney,
      m_accountCurrency,
      m_annualStatistics[index].maxCapitalDrawdownPercent,

      m_annualStatistics[index].maxEquityDrawdownMoney,
      m_accountCurrency,
      m_annualStatistics[index].maxEquityDrawdownPercent);
  }


  // --------------------------------------------------
  // En-tête du rapport global persistant.
  // --------------------------------------------------
  string BuildPersistentGlobalCsvHeader(void) const {
    return
      "RunId;SimulationEnd;Version;Source;Symbol;SignalTF;"
      "TestStart;TestEnd;Strategy;Parameters;BuyFunnel;Currency;"
      "Openings;ClosedTrades;Wins;Losses;Neutrals;MaxLossStreak;"
      "Inversions;SignalExits;StopLossExits;TakeProfitExits;"
      "Points;GrossProfit;GrossLoss;Net;ProfitFactor;Expectancy;"
      "MaxCapitalDDMoney;MaxCapitalDDPercent;"
      "MaxEquityDDMoney;MaxEquityDDPercent;"
      "InitialCapital;FinalCapital";
  }


  // --------------------------------------------------
  // Ligne du rapport global persistant.
  // --------------------------------------------------
  string BuildPersistentGlobalCsvLine(
    const string runId,
    const string SimulationEnd,
    const string version,
    const string sourceFile,
    const string symbol,
    const string signalTimeframe,
    const datetime testStart,
    const datetime testEnd,
    const string strategyDescription,
    const string parameterDescription,
    const string buyFunnelDescription) const {

    double profitFactor = 0.0;

    if (m_grossLossMoney > 0.0) {
      profitFactor =
        m_grossProfitMoney/
        m_grossLossMoney;
    }

    double expectancy = 0.0;

    if (m_closedTradeCount > 0) {
      expectancy =
        m_totalClosedMoney/
        (double)m_closedTradeCount;
    }

    double finalCapital =
      m_initialVirtualCapital+
      m_totalClosedMoney;

    string line =
      SanitizeCsvValue(runId)+";"+
      SanitizeCsvValue(SimulationEnd)+";"+
      SanitizeCsvValue(version)+";"+
      SanitizeCsvValue(sourceFile)+";"+
      SanitizeCsvValue(symbol)+";"+
      SanitizeCsvValue(signalTimeframe)+";"+
      SanitizeCsvValue(
        TimeToString(testStart, TIME_DATE|TIME_MINUTES))+";"+
      SanitizeCsvValue(
        TimeToString(testEnd, TIME_DATE|TIME_MINUTES))+";"+
      SanitizeCsvValue(strategyDescription)+";"+
      SanitizeCsvValue(parameterDescription)+";"+
      SanitizeCsvValue(buyFunnelDescription)+";"+
      SanitizeCsvValue(m_accountCurrency);

    line += StringFormat(
      ";%d;%d;%d;%d;%d;%d;%d;%d;%d;%d",
      m_openCount,
      m_closedTradeCount,
      m_winningTradeCount,
      m_losingTradeCount,
      m_breakEvenTradeCount,
      m_maxLosingStreak,
      m_reversalCount,
      m_signalExitCount,
      m_stopLossExitCount,
      m_takeProfitExitCount);

    line += StringFormat(
      ";%.1f;%.2f;%.2f;%.2f;%.4f;%.2f",
      m_totalClosedPoints,
      m_grossProfitMoney,
      m_grossLossMoney,
      m_totalClosedMoney,
      profitFactor,
      expectancy);

    line += StringFormat(
      ";%.2f;%.4f;%.2f;%.4f;%.2f;%.2f",
      m_maxDrawdownMoney,
      m_maxDrawdownPercent,
      m_maxEquityDrawdownMoney,
      m_maxEquityDrawdownPercent,
      m_initialVirtualCapital,
      finalCapital);

    return line;
  }


  // --------------------------------------------------
  // En-tête du rapport annuel persistant.
  // --------------------------------------------------
  string BuildPersistentAnnualCsvHeader(void) const {
    return
      "RunId;Version;Symbol;SignalTF;TestStart;TestEnd;Year;"
      "FirstObserved;LastObserved;Trades;Wins;Losses;Neutrals;"
      "MaxLossStreak;Points;GrossProfit;GrossLoss;Net;"
      "ProfitFactor;Expectancy;StartCapital;EndCapital;"
      "MaxCapitalDDMoney;MaxCapitalDDPercent;"
      "MaxEquityDDMoney;MaxEquityDDPercent;Currency";
  }


  // --------------------------------------------------
  // Ligne annuelle du rapport persistant.
  // --------------------------------------------------
  string BuildPersistentAnnualCsvLine(
    const int index,
    const string runId,
    const string version,
    const string symbol,
    const string signalTimeframe,
    const datetime testStart,
    const datetime testEnd) const {

    if (index < 0 ||
        index >= m_annualStatisticsCount) {
      return "";
    }

    double profitFactor = 0.0;

    if (m_annualStatistics[index].grossLossMoney > 0.0) {
      profitFactor =
        m_annualStatistics[index].grossProfitMoney/
        m_annualStatistics[index].grossLossMoney;
    }

    double expectancy = 0.0;

    if (m_annualStatistics[index].closedTradeCount > 0) {
      expectancy =
        m_annualStatistics[index].totalClosedMoney/
        (double)m_annualStatistics[index].closedTradeCount;
    }

    string line =
      SanitizeCsvValue(runId)+";"+
      SanitizeCsvValue(version)+";"+
      SanitizeCsvValue(symbol)+";"+
      SanitizeCsvValue(signalTimeframe)+";"+
      SanitizeCsvValue(
        TimeToString(testStart, TIME_DATE|TIME_MINUTES))+";"+
      SanitizeCsvValue(
        TimeToString(testEnd, TIME_DATE|TIME_MINUTES));

    line += StringFormat(
      ";%d;%s;%s;%d;%d;%d;%d;%d",
      m_annualStatistics[index].year,
      TimeToString(
        m_annualStatistics[index].firstObservedTime,
        TIME_DATE|TIME_MINUTES),
      TimeToString(
        m_annualStatistics[index].lastObservedTime,
        TIME_DATE|TIME_MINUTES),
      m_annualStatistics[index].closedTradeCount,
      m_annualStatistics[index].winningTradeCount,
      m_annualStatistics[index].losingTradeCount,
      m_annualStatistics[index].breakEvenTradeCount,
      m_annualStatistics[index].maxLosingStreak);

    line += StringFormat(
      ";%.1f;%.2f;%.2f;%.2f;%.4f;%.2f",
      m_annualStatistics[index].totalClosedPoints,
      m_annualStatistics[index].grossProfitMoney,
      m_annualStatistics[index].grossLossMoney,
      m_annualStatistics[index].totalClosedMoney,
      profitFactor,
      expectancy);

    line += StringFormat(
      ";%.2f;%.2f;%.2f;%.4f;%.2f;%.4f;%s",
      m_annualStatistics[index].startCapital,
      m_annualStatistics[index].endCapital,
      m_annualStatistics[index].maxCapitalDrawdownMoney,
      m_annualStatistics[index].maxCapitalDrawdownPercent,
      m_annualStatistics[index].maxEquityDrawdownMoney,
      m_annualStatistics[index].maxEquityDrawdownPercent,
      SanitizeCsvValue(m_accountCurrency));

    return line;
  }


  // --------------------------------------------------
  // Nombre de trades disponibles pour le rapport détaillé.
  // --------------------------------------------------
  int ClosedTradeReportCount(void) const {
    return m_closedTradeRecordCount;
  }


  // --------------------------------------------------
  // Nombre de trades non enregistrés faute de capacité.
  // --------------------------------------------------
  int ClosedTradeReportOverflowCount(void) const {
    return m_closedTradeRecordOverflowCount;
  }


  // --------------------------------------------------
  // En-tête du rapport détaillé des trades clôturés.
  // --------------------------------------------------
  string BuildPersistentClosedTradeCsvHeader(void) const {
    return
      "RunId;Version;Symbol;SignalTF;LocalTF;TrendTF;AtrTF;"
      "Sequence;EntryTime;ExitTime;DurationMinutes;"
      "Direction;Origin;ExitReason;Outcome;"
      "EntryPrice;ExitPrice;VolumeLots;EntrySpreadPoints;"
      "SLPoints;TPPoints;BETriggerPoints;"
      "InitialSLPrice;InitialTPPrice;FinalSLPrice;FinalTPPrice;"
      "BEActivated;ProfitLockActivated;"
      "ResultPoints;ResultMoney;ResultRPoints;ResultRMoney;"
      "MFEPoints;MFER;OpeningCapital;TargetRiskMoney;"
      "EstimatedLossAtStop;ATRValid;ATRPoints;SL_ATR;"
      "MARegime;S2;S1;S0;A1;A0;"
      "LocalValid;LocalQuadrant;DirectionalChangePoints;"
      "RangePoints;LocalSlopePointsPerHour;"
      "LocalCurvaturePointsPerHour2;LocalR2;"
      "LocalTrendStrength;LocalDirectionalEfficiency;"
      "TrendValid;TrendClose1;TrendMa1;TrendMa2;TrendAligned;"
      "Point;Digits;TickSize;TickValue;ContractSize;Currency";
  }


  // --------------------------------------------------
  // Ligne du rapport détaillé des trades clôturés.
  // --------------------------------------------------
  string BuildPersistentClosedTradeCsvLine(
    const int index,
    const string runId,
    const string version,
    const string symbol,
    const string signalTimeframe,
    const string localTimeframe,
    const string trendTimeframe,
    const string atrTimeframe) const {

    if (index < 0 ||
        index >= m_closedTradeRecordCount) {
      return "";
    }

    SPbVirtualClosedTradeRecord record =
      m_closedTradeRecords[index];

    long durationSeconds =
      (long)record.exitTime -
      (long)record.entryTime;

    if (durationSeconds < 0)
      durationSeconds = 0;

    long durationMinutes =
      durationSeconds / 60;

    string origin =
      record.openedAfterInversion
      ? "POST_INVERSION"
      : "FLAT";

    string outcome = "NEUTRAL";

    if (record.resultPoints > 0.0)
      outcome = "WIN";
    else if (record.resultPoints < 0.0)
      outcome = "LOSS";

    ENUM_PB_MA_DYNAMICS_REGIME maRegime =
      DetermineMaDynamicsRegime(
        record.entryMaDynamics);

    ENUM_PB_LOCAL_DYNAMICS_QUADRANT localQuadrant =
      DetermineLocalDynamicsQuadrant(
        record.entryLocalDynamics);

    double localTrendStrength = 0.0;
    double localDirectionalEfficiency = 0.0;

    if (record.entryLocalDynamics.isValid &&
        record.entryLocalDynamics.rangePoints > 0.0) {

      localTrendStrength =
        record.entryLocalDynamics.directionalSlopePointsPerHour /
        record.entryLocalDynamics.rangePoints;

      localDirectionalEfficiency =
        record.entryLocalDynamics.directionalChangePoints /
        record.entryLocalDynamics.rangePoints;
    }

    string line =
      SanitizeCsvValue(runId)+";"+
      SanitizeCsvValue(version)+";"+
      SanitizeCsvValue(symbol)+";"+
      SanitizeCsvValue(signalTimeframe)+";"+
      SanitizeCsvValue(localTimeframe)+";"+
      SanitizeCsvValue(trendTimeframe)+";"+
      SanitizeCsvValue(atrTimeframe)+";"+
      IntegerToString(record.sequence)+";"+
      SanitizeCsvValue(
        TimeToString(
          record.entryTime,
          TIME_DATE|TIME_SECONDS))+";"+
      SanitizeCsvValue(
        TimeToString(
          record.exitTime,
          TIME_DATE|TIME_SECONDS))+";"+
      IntegerToString(durationMinutes)+";"+
      SanitizeCsvValue(
        VirtualPositionStateToString(
          record.positionState))+";"+
      SanitizeCsvValue(origin)+";"+
      SanitizeCsvValue(
        VirtualExitReasonToString(
          record.exitReason))+";"+
      SanitizeCsvValue(outcome);

    line +=
      ";"+DoubleToString(record.entryPrice, record.symbolDigits)+
      ";"+DoubleToString(record.exitPrice, record.symbolDigits)+
      ";"+DoubleToString(record.volumeLots, 4)+
      ";"+DoubleToString(record.entrySpreadPoints, 2)+
      ";"+IntegerToString(record.stopLossPoints)+
      ";"+IntegerToString(record.takeProfitPoints)+
      ";"+IntegerToString(record.breakEvenTriggerPoints)+
      ";"+DoubleToString(record.initialStopLossPrice, record.symbolDigits)+
      ";"+DoubleToString(record.initialTakeProfitPrice, record.symbolDigits)+
      ";"+DoubleToString(record.finalStopLossPrice, record.symbolDigits)+
      ";"+DoubleToString(record.finalTakeProfitPrice, record.symbolDigits)+
      ";"+(record.breakEvenActivated ? "1" : "0")+
      ";"+(record.profitLockActivated ? "1" : "0");

    line +=
      ";"+DoubleToString(record.resultPoints, 2)+
      ";"+DoubleToString(record.resultMoney, m_accountCurrencyDigits)+
      ";"+DoubleToString(record.resultRPoints, 4)+
      ";"+DoubleToString(record.resultRMoney, 4)+
      ";"+DoubleToString(record.maxFavorablePoints, 2)+
      ";"+DoubleToString(record.maxFavorableR, 4)+
      ";"+DoubleToString(record.openingCapital, m_accountCurrencyDigits)+
      ";"+DoubleToString(record.targetRiskMoney, m_accountCurrencyDigits)+
      ";"+DoubleToString(record.estimatedLossAtStop, m_accountCurrencyDigits)+
      ";"+(record.entryAtrValid ? "1" : "0")+
      ";"+DoubleToString(record.entryAtrPoints, 4)+
      ";"+DoubleToString(record.entryStopLossAtr, 4);

    line +=
      ";"+SanitizeCsvValue(
        MaDynamicsRegimeToString(
          maRegime))+
      ";"+DoubleToString(record.entryMaDynamics.slopeEarlier, 4)+
      ";"+DoubleToString(record.entryMaDynamics.slopePrevious, 4)+
      ";"+DoubleToString(record.entryMaDynamics.slopeCurrent, 4)+
      ";"+DoubleToString(record.entryMaDynamics.accelerationPrevious, 4)+
      ";"+DoubleToString(record.entryMaDynamics.accelerationCurrent, 4)+
      ";"+(record.entryLocalDynamics.isValid ? "1" : "0")+
      ";"+SanitizeCsvValue(
        LocalDynamicsQuadrantToString(
          localQuadrant))+
      ";"+DoubleToString(
        record.entryLocalDynamics.directionalChangePoints,
        4)+
      ";"+DoubleToString(
        record.entryLocalDynamics.rangePoints,
        4)+
      ";"+DoubleToString(
        record.entryLocalDynamics.directionalSlopePointsPerHour,
        4)+
      ";"+DoubleToString(
        record.entryLocalDynamics.directionalCurvaturePointsPerHour2,
        4)+
      ";"+DoubleToString(
        record.entryLocalDynamics.quadraticRSquared,
        6)+
      ";"+DoubleToString(localTrendStrength, 6)+
      ";"+DoubleToString(localDirectionalEfficiency, 6);

    line +=
      ";"+(record.trendContextValid ? "1" : "0")+
      ";"+DoubleToString(record.trendClose1, record.symbolDigits)+
      ";"+DoubleToString(record.trendMa1, record.symbolDigits)+
      ";"+DoubleToString(record.trendMa2, record.symbolDigits)+
      ";"+(record.trendAligned ? "1" : "0")+
      ";"+DoubleToString(record.pointSize, 10)+
      ";"+IntegerToString(record.symbolDigits)+
      ";"+DoubleToString(record.tickSize, 10)+
      ";"+DoubleToString(record.tickValue, 8)+
      ";"+DoubleToString(record.contractSize, 2)+
      ";"+SanitizeCsvValue(m_accountCurrency);

    return line;
  }


  string BuildLongSummary(void) const {
    double profitFactor = 0.0;

    if (m_longGrossLossMoney > 0.0)
    profitFactor =
      m_longGrossProfitMoney/
      m_longGrossLossMoney;

    double expectancy = 0.0;

    if (m_longClosedTradeCount > 0)
    expectancy =
      m_longTotalClosedMoney/
      (double)m_longClosedTradeCount;

    return StringFormat(
      "Résumé LONG : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_longClosedTradeCount,
      m_longWinningTradeCount,
      m_longLosingTradeCount,
      m_longBreakEvenTradeCount,
      m_longTotalClosedPoints,
      m_longGrossProfitMoney,
      m_longGrossLossMoney,
      m_longTotalClosedMoney,
      profitFactor,
      expectancy);
  }

  string BuildShortSummary(void) const {
    double profitFactor = 0.0;

    if (m_shortGrossLossMoney > 0.0)
    profitFactor =
      m_shortGrossProfitMoney/
      m_shortGrossLossMoney;

    double expectancy = 0.0;

    if (m_shortClosedTradeCount > 0)
    expectancy =
      m_shortTotalClosedMoney/
      (double)m_shortClosedTradeCount;

    return StringFormat(
      "Résumé SHORT : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_shortClosedTradeCount,
      m_shortWinningTradeCount,
      m_shortLosingTradeCount,
      m_shortBreakEvenTradeCount,
      m_shortTotalClosedPoints,
      m_shortGrossProfitMoney,
      m_shortGrossLossMoney,
      m_shortTotalClosedMoney,
      profitFactor,
      expectancy);
  }

  // --------------------------------------------------
  // Résume la matrice des sorties LONG.
  // --------------------------------------------------
  string BuildLongExitMatrixSummary(void) const {
    return StringFormat(
      "Matrice LONG : "
      "SIGNAL=%d trade(s) / %.2f EUR | "
      "STOP LOSS=%d trade(s) / %.2f EUR | "
      "TAKE PROFIT=%d trade(s) / %.2f EUR | "
      "TOTAL=%d trade(s) / %.2f EUR",

      m_longSignalExitCount,
      m_longSignalExitMoney,

      m_longStopLossExitCount,
      m_longStopLossExitMoney,

      m_longTakeProfitExitCount,
      m_longTakeProfitExitMoney,

      m_longClosedTradeCount,
      m_longTotalClosedMoney);
  }

  // --------------------------------------------------
  // Résume la matrice des sorties SHORT.
  // --------------------------------------------------
  string BuildShortExitMatrixSummary(void) const {
    return StringFormat(
      "Matrice SHORT : "
      "SIGNAL=%d trade(s) / %.2f EUR | "
      "STOP LOSS=%d trade(s) / %.2f EUR | "
      "TAKE PROFIT=%d trade(s) / %.2f EUR | "
      "TOTAL=%d trade(s) / %.2f EUR",

      m_shortSignalExitCount,
      m_shortSignalExitMoney,

      m_shortStopLossExitCount,
      m_shortStopLossExitMoney,

      m_shortTakeProfitExitCount,
      m_shortTakeProfitExitMoney,

      m_shortClosedTradeCount,
      m_shortTotalClosedMoney);
  }

  // --------------------------------------------------
  // Construit le résumé final.
  // --------------------------------------------------
  string BuildSummary(void) const {
    if (!m_isInitialized) {
      return
      "Gestionnaire de positions virtuelles non initialisé. "
      "Vérifier l'appel à g_virtualPositions.Init() dans OnInit().";
    }

    // --------------------------------------------------
    // Statistiques monétaires dérivées.
    // --------------------------------------------------
    double averageWinMoney = 0.0;

    if (m_winningTradeCount > 0) {
      averageWinMoney =
        m_grossProfitMoney/
        m_winningTradeCount;
    }


    double averageLossMoney = 0.0;

    if (m_losingTradeCount > 0) {
      averageLossMoney =
        m_grossLossMoney/
        m_losingTradeCount;
    }


    double expectancyMoney = 0.0;

    if (m_closedTradeCount > 0) {
      expectancyMoney =
        m_totalClosedMoney/
        m_closedTradeCount;
    }


    // Le Profit Factor est :
    // somme des gains / somme des pertes.
    string profitFactorText = "N/A";

    if (m_grossLossMoney > 0.0) {
      double profitFactor =
        m_grossProfitMoney/
        m_grossLossMoney;

      profitFactorText =
        DoubleToString(
        profitFactor,
        2);
    }

    string openPositionSummary;

    if (m_state == PB_VIRTUAL_POSITION_FLAT) {
      openPositionSummary = "Position ouverte=NON";
    } else {
      double theoreticalExitPrice =
        (m_state == PB_VIRTUAL_POSITION_LONG)
        ? m_lastKnownBid
        : m_lastKnownAsk;

      double latentPoints = 0.0;

      if (theoreticalExitPrice > 0.0 &&
        m_point > 0.0) {
        if (m_state == PB_VIRTUAL_POSITION_LONG) {
          latentPoints =
            (theoreticalExitPrice - m_entryPrice) / m_point;
        } else {
          latentPoints =
            (m_entryPrice - theoreticalExitPrice) / m_point;
        }
      }

      double latentMoney = 0.0;
      string latentMoneyError;

      bool latentMoneyAvailable =
        theoreticalExitPrice > 0.0 &&
        CalculateMoneyResult(
        m_state,
        m_entryPrice,
        theoreticalExitPrice,
        latentMoney,
        latentMoneyError);

      if (latentMoneyAvailable) {
        openPositionSummary = StringFormat(
          "Position ouverte=%s depuis %s à %.*f | "
          "Volume=%s lot(s) | "
          "SL=%.*f | TP=%.*f | "
          "Derniers Bid=%.*f Ask=%.*f | "
          "Sortie théorique=%.*f | "
          "Latent=%.1f points | "
          "Latent monétaire=%.*f %s",

          VirtualPositionStateToString(
            m_state),

          TimeToString(
            m_entryTime,
            TIME_DATE|TIME_MINUTES),

          m_digits,
          m_entryPrice,

          m_volumeCalculator.FormatVolume(
            m_currentPositionVolumeLots),

          m_digits,
          m_stopLossPrice,

          m_digits,
          m_takeProfitPrice,

          m_digits,
          m_lastKnownBid,

          m_digits,
          m_lastKnownAsk,

          m_digits,
          theoreticalExitPrice,

          latentPoints,

          m_accountCurrencyDigits,
          latentMoney,

          m_accountCurrency);
      } else {
        openPositionSummary = StringFormat(
          "Position ouverte=%s depuis %s à %.*f | "
          "Volume=%s lot(s) | "
          "SL=%.*f | TP=%.*f | "
          "Derniers Bid=%.*f Ask=%.*f | "
          "Sortie théorique=%.*f | "
          "Latent=%.1f points",

          VirtualPositionStateToString(
            m_state),

          TimeToString(
            m_entryTime,
            TIME_DATE|TIME_MINUTES),

          m_digits,
          m_entryPrice,

          m_volumeCalculator.FormatVolume(
            m_currentPositionVolumeLots),

          m_digits,
          m_stopLossPrice,

          m_digits,
          m_takeProfitPrice,

          m_digits,
          m_lastKnownBid,

          m_digits,
          m_lastKnownAsk,

          m_digits,
          theoreticalExitPrice,

          latentPoints);
      }
    }

    double finalVirtualCapital =
      m_initialVirtualCapital+
      m_totalClosedMoney;

    string monetarySummary = StringFormat(
      "%s | "
      "Capital initial=%.*f %s | "
      "Capital virtuel final=%.*f %s | "
      "Total monétaire=%.*f %s | "
      "Dernier volume=%s lot(s)",

      m_volumeCalculator.BuildModeSummary(),

      m_accountCurrencyDigits,
      m_initialVirtualCapital,
      m_accountCurrency,

      m_accountCurrencyDigits,
      finalVirtualCapital,
      m_accountCurrency,

      m_accountCurrencyDigits,
      m_totalClosedMoney,
      m_accountCurrency,

      m_volumeCalculator.FormatVolume(
        m_lastOpenedVolumeLots));

    return StringFormat(
      "Ouvertures=%d | "
      "Trades clôturés=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Série pertes max=%d | "
      "Neutres=%d | "
      "Inversions=%d | "
      "Sorties signal=%d | "
      "Stop Loss=%d | "
      "Take Profit=%d | "
      "Total clôturé=%.1f points | "
      "Meilleur=%.1f | "
      "Pire=%.1f | "
      "Somme gains=%.*f %s | "
      "Somme pertes=%.*f %s | "
      "Gain moyen=%.*f %s | "
      "Perte moyenne=%.*f %s | "
      "Profit factor=%s | "
      "Espérance=%.*f %s | "
      "Drawdown capital montant=%.*f %s | "
      "Drawdown capital taux=%.2f%% | "
      "Drawdown équité montant=%.*f %s | "
      "Drawdown équité taux=%.2f%% | "
      "%s | "
      "%s",

      m_openCount,
      m_closedTradeCount,
      m_winningTradeCount,
      m_losingTradeCount,
      m_maxLosingStreak,
      m_breakEvenTradeCount,
      m_reversalCount,
      m_signalExitCount,
      m_stopLossExitCount,
      m_takeProfitExitCount,

      m_totalClosedPoints,
      m_bestTradePoints,
      m_worstTradePoints,

      m_accountCurrencyDigits,
      m_grossProfitMoney,
      m_accountCurrency,

      m_accountCurrencyDigits,
      m_grossLossMoney,
      m_accountCurrency,

      m_accountCurrencyDigits,
      averageWinMoney,
      m_accountCurrency,

      m_accountCurrencyDigits,
      averageLossMoney,
      m_accountCurrency,

      profitFactorText,

      // Espérance : %.*f %s
      m_accountCurrencyDigits,
      expectancyMoney,
      m_accountCurrency,

      // Drawdown monétaire : %.*f %s
      m_accountCurrencyDigits,
      m_maxDrawdownMoney,
      m_accountCurrency,

      // Drawdown en pourcentage : %.2f%%
      m_maxDrawdownPercent,

      // Drawdown de l'équité, résultat latent inclus.
      m_accountCurrencyDigits,
      m_maxEquityDrawdownMoney,
      m_accountCurrency,

      m_maxEquityDrawdownPercent,

      monetarySummary,
      openPositionSummary);
  }
};


#endif

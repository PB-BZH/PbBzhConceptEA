//+------------------------------------------------------------------+
//|                                              PbBzhConceptEA.mq5  |
//|              Version 1.22 - Analyse locale multi-timeframe       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, PbBzhConcept"
#property link      "https://www.mql5.com"
#property version   "1.22"
#property strict
#property description "EA pédagogique : signaux et positions virtuelles"

#include <PbBzhConcept\Core\BarClock.mqh>
#include <PbBzhConcept\Core\EaLogger.mqh>
#include <PbBzhConcept\Signals\MaPriceCrossSignal.mqh>
#include <PbBzhConcept\Presentation\ChartSignalRenderer.mqh>
#include <PbBzhConcept\Statistics\SignalStatistics.mqh>
#include <PbBzhConcept\Simulation\VirtualPositionManager.mqh>
#include <PbBzhConcept\Simulation\ExecutionQuoteProvider.mqh>
#include <PbBzhConcept\Simulation\VirtualVolumeCalculator.mqh>
#include <PbBzhConcept\Analysis\LocalPriceWindowAnalyzer.mqh>
#include <PbBzhConcept\Domain\LocalMarketDynamics.mqh>

//--- Paramètres généraux
input group "Général"
input string InpExpertName = "PbBzhConceptEA";
input ENUM_TIMEFRAMES InpSignalTimeframe = PERIOD_H1;
//--- Paramètres du signal
input group "Signal : croisement cours / moyenne mobile"
input int InpMaPeriod = 12;
input int InpMaShift = 0;
input ENUM_MA_METHOD InpMaMethod = MODE_SMA;
input ENUM_APPLIED_PRICE InpMaAppliedPrice = PRICE_CLOSE;

//--- Paramètres d'affichage
input group "Affichage graphique"
input bool InpShowSignalArrows = true;
input int InpSignalArrowOffsetPoints = 50;
input color InpBuyArrowColor = clrLimeGreen;
input color InpSellArrowColor = clrTomato;

input group "Simulation : protections virtuelles"
input int InpVirtualStopLossPoints = 200;
input int InpVirtualTakeProfitPoints = 400;

input group "Simulation : gestion du volume"
input ENUM_PB_VIRTUAL_VOLUME_MODE InpVirtualVolumeMode = PB_VIRTUAL_VOLUME_RISK_PERCENT;
input double InpVirtualFixedVolumeLots = 0.10;
input double InpVirtualRiskPercent = 1.00;

input group "Signal : confirmation de tendance"
input bool InpUseMaSlopeFilter = true;

input group "Analyse locale multi-timeframe"
input ENUM_TIMEFRAMES InpLocalTimeframe = PERIOD_M5;
input int InpLocalWindowMinutes = 60;

input group "Contexte tendance H4"
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_H4;
input int InpTrendMaPeriod = 12;

input group "Simulation : break-even virtuel"
input bool InpUseVirtualBreakEven = true;
input int InpVirtualBreakEvenTriggerPoints = 200;

input group "Simulation : verrouillage de gain virtuel"
input bool InpUseVirtualProfitLock = true;
input int InpVirtualProfitLockTriggerPoints = 300;
input int InpVirtualProfitLockPoints = 100;

//--- Objets principaux
CEaLogger g_logger;
CBarClock g_barClock;
CMaPriceCrossSignal g_signal;
CLocalPriceWindowAnalyzer g_localPriceAnalyzer;
CChartSignalRenderer g_renderer;
CSignalStatistics g_statistics;
CVirtualPositionManager g_virtualPositions;
CExecutionQuoteProvider g_quoteProvider;

ENUM_TIMEFRAMES g_timeframe = PERIOD_CURRENT;

int g_trendMaHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
int OnInit(void) {
  // ==================================================
  // 1. Initialisation générale.
  // ==================================================
  g_logger.Init(InpExpertName);
  g_statistics.Reset();

  g_timeframe =
    (InpSignalTimeframe == PERIOD_CURRENT)
    ? (ENUM_TIMEFRAMES)_Period
    : InpSignalTimeframe;


  // ==================================================
  // 2. Identification explicite de la version testée.
  // ==================================================
  g_logger.Info(
    StringFormat(
      "DÉMARRAGE | "
      "Version=1.22 | "
      "Source=%s | "
      "Compilation=%s | "
      "Mode volume=%s | "
      "Risque=%.2f%% | "
      "Filtre pente MA=%s",

      __FILE__,

      TimeToString(
        __DATETIME__,
        TIME_DATE|TIME_SECONDS),

      VirtualVolumeModeToString(
        InpVirtualVolumeMode),

      InpVirtualRiskPercent,

      InpUseMaSlopeFilter
      ? "ACTIF"
      : "INACTIF"));


  // ==================================================
  // 3. Horloge de bougies.
  // ==================================================
  if (!g_barClock.Init(
      _Symbol,
      g_timeframe)) {
    g_logger.Error(
      "Initialisation de l'horloge de bougies impossible.");

    return INIT_FAILED;
  }


  // ==================================================
  // 4. Signal de moyenne mobile.
  // ==================================================
  if (!g_signal.Init(
      _Symbol,
      g_timeframe,
      InpMaPeriod,
      InpMaShift,
      InpMaMethod,
      InpMaAppliedPrice,
      InpUseMaSlopeFilter)) {
    g_logger.Error(
      "Initialisation du signal de moyenne mobile impossible.");

    return INIT_FAILED;
  }

  // ==================================================
  // 5. Analyse locale multi-timeframe.
  // ==================================================
  if (!g_localPriceAnalyzer.Init(
      _Symbol,
      InpLocalTimeframe,
      InpLocalWindowMinutes)) {
    g_logger.Error(
      "Initialisation de l'analyse locale impossible.");

    return INIT_FAILED;
  }

  g_trendMaHandle = iMA(
    _Symbol,
    InpTrendTimeframe,
    InpTrendMaPeriod,
    0,
    MODE_SMA,
    PRICE_CLOSE);

  if (g_trendMaHandle == INVALID_HANDLE) {
    g_logger.Error(
      StringFormat(
        "Impossible de créer la MA de tendance | TF=%s | Période=%d | Erreur=%d",
        EnumToString(InpTrendTimeframe),
        InpTrendMaPeriod,
        GetLastError()));

    return INIT_FAILED;
  }


  // ==================================================
  // 6. Affichage graphique.
  // ==================================================
  if (!g_renderer.Init(
      ChartID(),
      InpExpertName,
      _Symbol,
      g_timeframe,
      InpShowSignalArrows,
      InpSignalArrowOffsetPoints,
      InpBuyArrowColor,
      InpSellArrowColor)) {
    g_logger.Error(
      "Initialisation de l'affichage graphique impossible.");

    return INIT_FAILED;
  }


  // ==================================================
  // 7. Fournisseur de cotations.
  // ==================================================
  if (!g_quoteProvider.Init(_Symbol)) {
    g_logger.Error(
      "Initialisation du fournisseur de cotations impossible.");

    return INIT_FAILED;
  }


  // ==================================================
  // 8. Gestionnaire de positions virtuelles.
  // ==================================================
  string virtualPositionInitError;

  if (!g_virtualPositions.Init(
      _Symbol,
      InpVirtualStopLossPoints,
      InpVirtualTakeProfitPoints,
      InpVirtualVolumeMode,
      InpVirtualFixedVolumeLots,
      InpVirtualRiskPercent,
      virtualPositionInitError)) {
    g_logger.Error(
      StringFormat(
        "Initialisation du gestionnaire de positions "
        "virtuelles impossible : %s",
        virtualPositionInitError));

    return INIT_FAILED;
  }

  g_virtualPositions.ConfigureBreakEven(
    InpUseVirtualBreakEven,
    InpVirtualBreakEvenTriggerPoints);
    
  g_virtualPositions.ConfigureProfitLock(
    InpUseVirtualProfitLock,
    InpVirtualProfitLockTriggerPoints,
    InpVirtualProfitLockPoints);
    
  // ==================================================
  // 9. Fin de l'initialisation.
  // ==================================================
  g_logger.Warning(
    "Cette version simule des positions en mémoire "
    "mais ne peut envoyer aucun ordre.");

  g_logger.Info(
    StringFormat(
      "Prêt : symbole=%s, période=%s, MA=%d, "
      "filtre pente=%s, flèches=%s.",
      _Symbol,
      EnumToString(g_timeframe),
      InpMaPeriod,
      InpUseMaSlopeFilter ? "ACTIF" : "INACTIF",
      InpShowSignalArrows ? "OUI" : "NON"));

  return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Libération des ressources                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
  if (!g_virtualPositions.IsConsistent()) {
    g_logger.Error(
      "Incohérence détectée dans les statistiques "
      "des positions virtuelles.");
  } else {
    g_logger.Info(
      "Contrôle de cohérence des positions "
      "virtuelles : OK.");
  }

  if (g_trendMaHandle != INVALID_HANDLE) {
    IndicatorRelease(g_trendMaHandle);
    g_trendMaHandle = INVALID_HANDLE;
  }

  g_logger.Info(StringFormat("Résumé MA=%d : %s", InpMaPeriod, g_statistics.BuildSummary()));
  LogVirtualPositionSummary();
  g_logger.Info("---------------------------------------------");
  g_logger.Info(g_virtualPositions.BuildLongSummary());
  g_logger.Info(g_virtualPositions.BuildShortSummary());
  g_logger.Info(g_virtualPositions.BuildInversionTradeSummary());
  g_logger.Info(g_virtualPositions.BuildFlatEntryTradeSummary());
  g_logger.Info("---------------------------------------------");
  g_logger.Info(g_virtualPositions.BuildInversionDirectionSummary());
  g_logger.Info(g_virtualPositions.BuildFlatEntryDirectionSummary());
  g_logger.Info("---------------------------------------------");
  g_logger.Info(g_virtualPositions.BuildFlatWinningMaDynamicsSummary());
  g_logger.Info(g_virtualPositions.BuildFlatLosingMaDynamicsSummary());
  g_logger.Info("---------------------------------------------");
  g_logger.Info(g_virtualPositions.BuildFlatWinningLocalDynamicsSummary());
  g_logger.Info(g_virtualPositions.BuildFlatLosingLocalDynamicsSummary());
  g_logger.Info("---------------------------------------------");
  g_logger.Info(g_virtualPositions.BuildLosingTradeMfeSummary());
  g_logger.Info(g_virtualPositions.BuildDrawdownTimingSummary());
  g_logger.Info(g_virtualPositions.BuildLongExitMatrixSummary());
  g_logger.Info(g_virtualPositions.BuildShortExitMatrixSummary());
  g_logger.Info(g_virtualPositions.BuildLongSignalDetailSummary());
  g_logger.Info(g_virtualPositions.BuildShortSignalDetailSummary());
  g_logger.Info(g_virtualPositions.BuildFlatEntryExitMatrixSummary());
  g_logger.Info(g_virtualPositions.BuildInversionEntryExitMatrixSummary());
  g_logger.Info(g_virtualPositions.BuildSignalExitSummary());
  g_logger.Info(g_virtualPositions.BuildStopLossSummary());
  g_logger.Info(g_virtualPositions.BuildTakeProfitSummary());
  g_logger.Info(g_virtualPositions.BuildFlatEntrySlopeSummary());
  g_logger.Info(g_virtualPositions.BuildInversionEntrySlopeSummary());
  g_logger.Info(g_virtualPositions.BuildInversionWinningMaDynamicsSummary());
  g_logger.Info(g_virtualPositions.BuildInversionLosingMaDynamicsSummary());
  g_logger.Info(g_virtualPositions.BuildFlatLocalQuadrantSummary());
  g_logger.Info(g_virtualPositions.BuildInversionLocalQuadrantSummary());
  g_logger.Info(g_virtualPositions.BuildInversionMaRegimeLocalQuadrantSummary(PB_MA_REGIME_CONTINUATION));
  g_logger.Info(g_virtualPositions.BuildInversionMaRegimeLocalQuadrantSummary(PB_MA_REGIME_REVERSAL_EARLY));
  g_logger.Info(g_virtualPositions.BuildInversionMaRegimeLocalQuadrantSummary(PB_MA_REGIME_REVERSAL_LATE));
  g_logger.Info(g_virtualPositions.BuildInversionMaRegimeLocalQuadrantSummary(PB_MA_REGIME_OSCILLATION));
  g_logger.Info(g_virtualPositions.BuildInversionReversalLateQuadrantIIIProfileSummary());
  g_logger.Info(g_virtualPositions.BuildInversionReversalLateQuadrantIIIWinningProfileSummary());
  g_logger.Info(g_virtualPositions.BuildInversionReversalLateQuadrantIIILosingProfileSummary());
  g_logger.Info(g_virtualPositions.BuildInversionReversalLateQuadrantIIIWinningTurningTimeSummary());
  g_logger.Info(g_virtualPositions.BuildInversionReversalLateQuadrantIIILosingTurningTimeSummary());
  g_logger.Info(g_virtualPositions.BuildInversionContinuationQuadrantIProfileSummary());
  g_logger.Info(g_virtualPositions.BuildInversionWinningLocalDynamicsSummary());
  g_logger.Info(g_virtualPositions.BuildInversionLosingLocalDynamicsSummary());
  g_signal.Deinit();
  g_logger.Info(StringFormat("Arrêt de l'EA. Motif=%d.", reason));
}


//+------------------------------------------------------------------+
//| Traitement d'un nouveau tick                                      |
//+------------------------------------------------------------------+
void OnTick(void) {
  // ==================================================
  // 1. Lecture de la cotation à CHAQUE tick.
  // ==================================================
  SExecutionQuote executionQuote;

  if (!g_quoteProvider.Read(executionQuote)) {
    // CExecutionQuoteProvider écrit déjà le détail
    // de l'erreur dans le journal.
    return;
  }


  // ==================================================
  // 2. Surveillance de la position à CHAQUE tick.
  // ==================================================
  string protectionEvent;

  if (!g_virtualPositions.ProcessTick(
      executionQuote.time,
      executionQuote.bid,
      executionQuote.ask,
      protectionEvent)) {
    g_logger.Error(
      StringFormat(
        "Erreur de surveillance virtuelle : %s",
        protectionEvent));

    return;
  }

  if (protectionEvent != "") {
    g_logger.Info(
      StringFormat(
        "SIMULATION | %s",
        protectionEvent));
  }


  // ==================================================
  // 3. Le signal reste limité aux nouvelles bougies.
  // ==================================================
  if (!g_barClock.IsNewBar())
  return;


  // ==================================================
  // 4. Calcul du signal sur les bougies clôturées.
  // ==================================================
  SMaPriceCrossSnapshot snapshot;

  if (!g_signal.Evaluate(snapshot)) {
    g_statistics.RecordError();

    g_logger.Error(
      "Le signal n'a pas pu être calculé "
      "pour la nouvelle bougie.");

    return;
  }

  g_statistics.RecordSignal(snapshot.signal);


  string message = StringFormat(
    "SignalBar[1]=%s | "
    "Bar[0]=%s Open[0]=%.*f | "
    "Close[2]=%.*f MA[2]=%.*f | "
    "Close[1]=%.*f MA[1]=%.*f | "
    "Décision=%s",

    TimeToString(
      snapshot.bar1OpenTime,
      TIME_DATE|TIME_MINUTES),

    TimeToString(
      snapshot.bar0OpenTime,
      TIME_DATE|TIME_MINUTES),

    _Digits,
    snapshot.bar0Open,

    _Digits,
    snapshot.bar2Close,

    _Digits,
    snapshot.bar2Ma,

    _Digits,
    snapshot.bar1Close,

    _Digits,
    snapshot.bar1Ma,

    TradeSignalToString(snapshot.signal));


  // ==================================================
  // 5. Journalisation et affichage.
  // ==================================================
  if (snapshot.signal == PB_SIGNAL_NONE) {
    g_logger.Info(message);
  } else {
    g_logger.Signal(message);

    g_logger.Info(
      StringFormat(
        "COTATION | Date=%s | "
        "Open[0]=%.*f | "
        "Bid=%.*f | Ask=%.*f | "
        "Spread=%.1f points",

        TimeToString(
          executionQuote.time,
          TIME_DATE|TIME_MINUTES),

        _Digits,
        snapshot.bar0Open,

        _Digits,
        executionQuote.bid,

        _Digits,
        executionQuote.ask,

        executionQuote.spreadPoints));

    if (!g_renderer.Draw(
        snapshot.signal,
        snapshot.bar1OpenTime,
        snapshot.bar1High,
        snapshot.bar1Low)) {
      g_logger.Warning(
        "Le signal a été calculé, mais sa flèche "
        "n'a pas pu être affichée.");
    }
  }


  // ==================================================
  // 6. Traitement du signal à la nouvelle bougie.
  // ==================================================
  string virtualEvent;

  SLocalMarketDynamics localDynamics;

  ZeroMemory(localDynamics);

  localDynamics.isValid = false;


  // --------------------------------------------------
  // Diagnostic temporaire de la pente de MA
  // au moment du signal.
  // --------------------------------------------------
  if (snapshot.signal != PB_SIGNAL_NONE) {
    string signalText =
      snapshot.signal == PB_SIGNAL_BUY
      ? "BUY"
      : "SELL";

    ENUM_PB_MA_DYNAMICS_REGIME maRegime =
      DetermineMaDynamicsRegime(
      snapshot.directionalMaDynamics);

    string maRegimeText =
      MaDynamicsRegimeToString(
      maRegime);

    g_logger.Info(
      StringFormat(
        "DIAG DYNAMIQUE | Signal=%s | "
        "S2=%.2f | S1=%.2f | S0=%.2f pts | "
        "A1=%.2f | A0=%.2f pts/bougie^2 | "
        "Régime=%s",

        signalText,

        snapshot.directionalMaDynamics.slopeEarlier,
        snapshot.directionalMaDynamics.slopePrevious,
        snapshot.directionalMaDynamics.slopeCurrent,
        snapshot.directionalMaDynamics.accelerationPrevious,
        snapshot.directionalMaDynamics.accelerationCurrent,
        maRegimeText));
    SLocalPriceWindowSnapshot localWindow;

    datetime localReferenceTime =
      snapshot.bar1OpenTime+
      PeriodSeconds(InpSignalTimeframe);

    if (g_localPriceAnalyzer.Analyze(
        localReferenceTime,
        localWindow)) {

      double direction =
        snapshot.signal == PB_SIGNAL_BUY
        ? 1.0
        : -1.0;

      double directionalChange =
        localWindow.netChangePoints*
        direction;

      double directionalSlope =
        localWindow.localSlopePointsPerHour*
        direction;

      double directionalCurvature =
        localWindow.localCurvaturePointsPerHour2*
        direction;

      localDynamics.isValid =
        localWindow.isComplete &&
        localWindow.quadraticFitValid;

      localDynamics.directionalChangePoints =
        directionalChange;

      localDynamics.rangePoints =
        localWindow.rangePoints;

      localDynamics.directionalSlopePointsPerHour =
        directionalSlope;

      localDynamics.directionalCurvaturePointsPerHour2 =
        directionalCurvature;

      localDynamics.quadraticRSquared =
        localWindow.quadraticRSquared;

      ENUM_PB_LOCAL_DYNAMICS_QUADRANT localQuadrant =
        DetermineLocalDynamicsQuadrant(
        localDynamics);

      string localQuadrantText =
        LocalDynamicsQuadrantToString(
        localQuadrant);

      if (!localDynamics.isValid) {
        g_logger.Warning(
          StringFormat(
            "DIAG LOCAL INVALIDE | "
            "Signal=%s | Heure=%s | "
            "Barres=%d/%d | Complète=%s | Fit=%s",

            signalText,

            TimeToString(
              localReferenceTime,
              TIME_DATE|TIME_MINUTES),

            localWindow.barCount,
            localWindow.expectedBars,

            localWindow.isComplete
            ? "OUI"
            : "NON",

            localWindow.quadraticFitValid
            ? "OUI"
            : "NON"));
      }


      g_logger.Info(
        StringFormat(
          "DIAG LOCAL | "
          "TF=%s | Signal=%s | "
          "Fenêtre=%s -> %s | "
          "Barres=%d/%d | "
          "Complète=%s | "
          "Variation=%.2f pts | "
          "Variation dir.=%.2f pts | "
          "Amplitude=%.2f pts | "
          "Fit=%s | "
          "Points fit=%d | "
          "Pente dir.=%.2f pts/h | "
          "Courbure dir.=%.2f pts/h^2 | "
          "Quadrant=%s | "
          "R2=%.4f",

          EnumToString(
            InpLocalTimeframe),

          signalText,

          TimeToString(
            localWindow.windowStartTime,
            TIME_DATE|TIME_MINUTES),

          TimeToString(
            localWindow.referenceTime,
            TIME_DATE|TIME_MINUTES),

          localWindow.barCount,
          localWindow.expectedBars,

          localWindow.isComplete
          ? "OUI"
          : "NON",

          localWindow.netChangePoints,
          directionalChange,
          localWindow.rangePoints,

          localWindow.quadraticFitValid
          ? "OK"
          : "NON",

          localWindow.fitPointCount,

          directionalSlope,
          directionalCurvature,

          localQuadrantText,

          localWindow.quadraticRSquared));
    } else {
      g_logger.Warning(
        StringFormat(
          "DIAG LOCAL ECHEC | "
          "Signal=%s | Heure=%s | "
          "TF=%s | Fenêtre=%d min",

          signalText,

          TimeToString(
            snapshot.bar0OpenTime,
            TIME_DATE|TIME_MINUTES),

          EnumToString(
            InpLocalTimeframe),

          InpLocalWindowMinutes));
    }
  }

  ENUM_PB_MA_DYNAMICS_REGIME maRegime =
    DetermineMaDynamicsRegime(
    snapshot.directionalMaDynamics);

  ENUM_PB_LOCAL_DYNAMICS_QUADRANT localQuadrant =
    DetermineLocalDynamicsQuadrant(
    localDynamics);


  double localTrendStrength = 0.0;

  if (localDynamics.isValid &&
    localDynamics.rangePoints > 0.0) {

    localTrendStrength =
      localDynamics.directionalSlopePointsPerHour /
      localDynamics.rangePoints;
  }

  double localDirectionalEfficiency = 0.0;

  if (localDynamics.isValid &&
    localDynamics.rangePoints > 0.0) {

    localDirectionalEfficiency =
      localDynamics.directionalChangePoints /
      localDynamics.rangePoints;
  }

  // --------------------------------------------------
  // Contexte H4.
  // --------------------------------------------------
  double trendClose1 = 0.0;
  double trendMa1 = 0.0;
  double trendMa2 = 0.0;

  bool trendContextValid =
    TryGetTrendContext(
    trendClose1,
    trendMa1,
    trendMa2);

  if (snapshot.signal != PB_SIGNAL_NONE) {

    if (trendContextValid) {

      g_logger.Info(
        StringFormat(
          "DIAG H4 | TF=%s | Close[1]=%.*f | MA[1]=%.*f | MA[2]=%.*f | "
          "Cours/MA=%s | Pente MA=%s",
          EnumToString(InpTrendTimeframe),
          _Digits,
          trendClose1,
          _Digits,
          trendMa1,
          _Digits,
          trendMa2,
          trendClose1 > trendMa1
          ? "AU-DESSUS"
          : trendClose1 < trendMa1
          ? "EN-DESSOUS"
          : "EGAL",
          trendMa1 > trendMa2
          ? "HAUSSE"
          : trendMa1 < trendMa2
          ? "BAISSE"
          : "PLATE"));
    } else {

      g_logger.Warning(
        StringFormat(
          "DIAG H4 | Contexte indisponible | TF=%s",
          EnumToString(InpTrendTimeframe)));
    }
  }

  bool trendAligned = false;

  if (trendContextValid) {

    if (snapshot.signal == PB_SIGNAL_BUY) {

      trendAligned =
        trendClose1 > trendMa1 &&
        trendMa1 > trendMa2;
    } else if (snapshot.signal == PB_SIGNAL_SELL) {

      trendAligned =
        trendClose1 < trendMa1 &&
        trendMa1 < trendMa2;
    }
  }

  // Entrée depuis FLAT :
  // tendance H1 établie, dynamique M5 favorable
  // et mouvement local suffisamment énergique.
  bool allowFlatEntry =
    maRegime == PB_MA_REGIME_CONTINUATION &&
    localQuadrant == PB_LOCAL_QUADRANT_I &&
    localTrendStrength >= 1.50 &&
    localDirectionalEfficiency >= 0.60;

  // Réouverture après une sortie sur signal :
  // configuration de retournement retenue par l'étude v1.20.
  bool allowReversalEntry =
    maRegime == PB_MA_REGIME_REVERSAL_LATE &&
    localQuadrant == PB_LOCAL_QUADRANT_III;


  if (!g_virtualPositions.ProcessSignal(
      snapshot.signal,
      snapshot.directionalMaDynamics,
      localDynamics,
      executionQuote.time,
      executionQuote.bid,
      executionQuote.ask,
      virtualEvent,
      allowFlatEntry,
      allowReversalEntry)) {

    g_logger.Error(
      StringFormat(
        "Erreur de simulation : %s",
        virtualEvent));

    return;
  }

  if (virtualEvent != "") {
    g_logger.Info(
      StringFormat(
        "SIMULATION | %s",
        virtualEvent));
  }
}

bool TryGetTrendContext(
  double &close1,
  double &ma1,
  double &ma2) {

  close1 = 0.0;
  ma1 = 0.0;
  ma2 = 0.0;

  if (g_trendMaHandle == INVALID_HANDLE)
  return false;

  if (BarsCalculated(g_trendMaHandle) < 3)
  return false;


  double closeBuffer[1];
  double ma1Buffer[1];
  double ma2Buffer[1];

  if (CopyClose(
      _Symbol,
      InpTrendTimeframe,
      1,
      1,
      closeBuffer) != 1) {

    return false;
  }

  if (CopyBuffer(
      g_trendMaHandle,
      0,
      1,
      1,
      ma1Buffer) != 1) {

    return false;
  }

  if (CopyBuffer(
      g_trendMaHandle,
      0,
      2,
      1,
      ma2Buffer) != 1) {

    return false;
  }


  close1 = closeBuffer[0];
  ma1 = ma1Buffer[0];
  ma2 = ma2Buffer[0];

  return true;
}


// --------------------------------------------------
// Affiche le résumé des positions virtuelles sur
// plusieurs lignes afin d'éviter sa troncature dans
// le journal du Testeur.
// --------------------------------------------------
void LogVirtualPositionSummary(void) {
  string summary =
    g_virtualPositions.BuildSummary();


  // Les marqueurs correspondent aux séparations
  // déjà présentes dans BuildSummary().
  string performanceMarker =
    " | Somme gains=";

  string capitalMarker =
    " | Mode volume=";

  string positionMarker =
    " | Position ouverte=";


  int performancePosition =
    StringFind(
    summary,
    performanceMarker);

  int capitalPosition =
    StringFind(
    summary,
    capitalMarker);

  int positionPosition =
    StringFind(
    summary,
    positionMarker);


  // ------------------------------------------------
  // Sécurité :
  // si la structure du résumé a été modifiée et que
  // les marqueurs ne sont plus trouvés, on conserve
  // l'ancien affichage.
  // ------------------------------------------------
  if (performancePosition < 0 ||
    capitalPosition < 0 ||
    positionPosition < 0 ||
    performancePosition >= capitalPosition ||
    capitalPosition >= positionPosition) {
    g_logger.Info(
      StringFormat(
        "Résumé positions virtuelles : %s",
        summary));

    return;
  }


  // Longueur de la chaîne séparatrice " | ".
  const int separatorLength = 3;


  // ------------------------------------------------
  // Ligne 1 : nombres de trades et résultats points.
  // ------------------------------------------------
  string positionsSummary =
    StringSubstr(
    summary,
    0,
    performancePosition);


  // ------------------------------------------------
  // Ligne 2 : performances monétaires.
  // ------------------------------------------------
  int performanceStart =
    performancePosition+
    separatorLength;

  string performanceSummary =
    StringSubstr(
    summary,
    performanceStart,
    capitalPosition-
    performanceStart);


  // ------------------------------------------------
  // Ligne 3 : capital et gestion du volume.
  // ------------------------------------------------
  int capitalStart =
    capitalPosition+
    separatorLength;

  string capitalSummary =
    StringSubstr(
    summary,
    capitalStart,
    positionPosition-
    capitalStart);


  // ------------------------------------------------
  // Ligne 4 : position éventuellement encore ouverte.
  // ------------------------------------------------
  int positionStart =
    positionPosition+
    separatorLength;

  string openPositionSummary =
    StringSubstr(
    summary,
    positionStart);


  g_logger.Info(
    StringFormat(
      "Résumé positions [1/4] : %s",
      positionsSummary));

  g_logger.Info(
    StringFormat(
      "Résumé performances [2/4] : %s",
      performanceSummary));

  g_logger.Info(
    StringFormat(
      "Résumé capital [3/4] : %s",
      capitalSummary));

  g_logger.Info(
    StringFormat(
      "Résumé position finale [4/4] : %s",
      openPositionSummary));
}

//+------------------------------------------------------------------+
//|             GoldIntradayBarrierProfiler_v7_03.mqh               |
//| GOLD M15/H1 : ordre TP/SL suivi en M1, sans aucune prise de trade|
//+------------------------------------------------------------------+
#ifndef PB_BZH_GOLD_INTRADAY_BARRIER_PROFILER_V7_03_MQH
#define PB_BZH_GOLD_INTRADAY_BARRIER_PROFILER_V7_03_MQH

#define PB_V703_PERIOD_COUNT 4
#define PB_V703_DIRECTION_COUNT 2
#define PB_V703_SCENARIO_COUNT 5
#define PB_V703_HOUR_SLOT_COUNT 2
#define PB_V703_VOL_CLASS_COUNT 2
#define PB_V703_MAX_PENDING 64

enum ENUM_PB_V703_OUTCOME {
  PB_V703_OUTCOME_TP_FIRST = 0,
  PB_V703_OUTCOME_SL_FIRST = 1,
  PB_V703_OUTCOME_AMBIGUOUS = 2,
  PB_V703_OUTCOME_TIMEOUT = 3
};

enum ENUM_PB_V703_VOL_CLASS {
  PB_V703_VOL_NORMAL = 0,
  PB_V703_VOL_EXPANSION = 1
};

struct SPbV703FunnelStats {
  long windowBreakoutCount;
  long alignedCount;
  long eligibleCount;
};

struct SPbV703BarrierStats {
  long tpFirstCount;
  long slFirstCount;
  long ambiguousCount;
  long timeoutCount;
  double sumTimeoutR;
};

struct SPbV703Observation {
  bool isActive;
  int directionIndex;
  int periodIndex;
  int hourSlotIndex;
  int volatilityClassIndex;
  datetime signalTime;
  double entryPrice;
  double atrAtSignal;
  int elapsedMinutes;
  bool scenarioClosed[PB_V703_SCENARIO_COUNT];
};

string PbV703DirectionToString(const int directionIndex) {
  return directionIndex == 0 ? "LONG" : "SHORT";
}

string PbV703PeriodToString(const int periodIndex) {
  switch (periodIndex) {
    case 0:
      return "GLOBAL";

    case 1:
      return "A 2019-2020";

    case 2:
      return "B 2021-2023";

    case 3:
      return "C 2024-FIN";

    default:
      return "INCONNUE";
  }
}

string PbV703VolatilityToString(const int classIndex) {
  return classIndex == PB_V703_VOL_NORMAL
    ? "NORMALE"
    : "EXPANSION";
}

class CGoldIntradayBarrierProfiler {
private:
  string m_symbol;
  ENUM_TIMEFRAMES m_signalTimeframe;
  ENUM_TIMEFRAMES m_contextTimeframe;
  ENUM_TIMEFRAMES m_monitorTimeframe;
  int m_signalPeriodSeconds;
  int m_monitorPeriodSeconds;

  int m_contextAtrPeriod;
  int m_contextTrendEmaPeriod;
  double m_trendNeutralAtrBand;
  int m_breakoutLookbackBars;
  double m_compressionMaximumAtr;
  double m_expansionMinimumAtr;
  int m_entryStartHour;
  int m_entryEndHour;
  int m_maximumHoldingMinutes;

  int m_contextAtrHandle;
  int m_contextEmaHandle;
  datetime m_currentSignalBarTime;
  datetime m_currentMonitorBarTime;
  double m_currentMonitorHigh;
  double m_currentMonitorLow;
  double m_currentMonitorClose;

  double m_tpAtr[PB_V703_SCENARIO_COUNT];
  double m_slAtr[PB_V703_SCENARIO_COUNT];
  SPbV703Observation m_pending[PB_V703_MAX_PENDING];

  SPbV703FunnelStats
    m_funnelStats[PB_V703_PERIOD_COUNT]
      [PB_V703_DIRECTION_COUNT];

  SPbV703BarrierStats
    m_combinedStats[PB_V703_PERIOD_COUNT]
      [PB_V703_DIRECTION_COUNT]
      [PB_V703_SCENARIO_COUNT];

  SPbV703BarrierStats
    m_hourStats[PB_V703_HOUR_SLOT_COUNT]
      [PB_V703_DIRECTION_COUNT]
      [PB_V703_SCENARIO_COUNT];

  SPbV703BarrierStats
    m_volatilityStats[PB_V703_VOL_CLASS_COUNT]
      [PB_V703_DIRECTION_COUNT]
      [PB_V703_SCENARIO_COUNT];

  long m_processedSignalBarCount;
  long m_processedMonitorBarCount;
  long m_invalidSignalBarCount;
  long m_invalidMonitorBarCount;
  long m_contextUnavailableCount;
  long m_pendingDroppedCount;
  datetime m_analysisStartTime;
  datetime m_analysisEndTime;

  int CalendarPeriodIndex(const datetime value) const {
    MqlDateTime parts;
    TimeToStruct(value, parts);

    if (parts.year <= 2020)
      return 1;

    if (parts.year <= 2023)
      return 2;

    return 3;
  }

  int HourIndex(const datetime value) const {
    MqlDateTime parts;
    TimeToStruct(value, parts);
    return parts.hour;
  }

  bool ReadContext(
    double &atrPrice,
    double &emaPrice,
    double &contextClose) const {

    atrPrice = 0.0;
    emaPrice = 0.0;
    contextClose = 0.0;

    double atrBuffer[1];
    double emaBuffer[1];
    MqlRates contextBar[1];

    if (CopyBuffer(m_contextAtrHandle, 0, 1, 1, atrBuffer) != 1)
      return false;

    if (CopyBuffer(m_contextEmaHandle, 0, 1, 1, emaBuffer) != 1)
      return false;

    if (CopyRates(
      m_symbol,
      m_contextTimeframe,
      1,
      1,
      contextBar) != 1) {

      return false;
    }

    if (atrBuffer[0] <= 0.0 || emaBuffer[0] <= 0.0)
      return false;

    atrPrice = atrBuffer[0];
    emaPrice = emaBuffer[0];
    contextClose = contextBar[0].close;
    return true;
  }

  int TrendDirection(
    const double contextClose,
    const double emaPrice,
    const double atrPrice) const {

    double neutralDistance = m_trendNeutralAtrBand * atrPrice;

    if (contextClose > emaPrice + neutralDistance)
      return 1;

    if (contextClose < emaPrice - neutralDistance)
      return -1;

    return 0;
  }

  void IncrementSingleFunnel(
    SPbV703FunnelStats &stats,
    const int stage) {

    if (stage == 0)
      stats.windowBreakoutCount++;
    else if (stage == 1)
      stats.alignedCount++;
    else
      stats.eligibleCount++;
  }

  void IncrementFunnel(
    const int periodIndex,
    const int directionIndex,
    const int stage) {

    int periodSlots[2];
    periodSlots[0] = 0;
    periodSlots[1] = periodIndex;

    for (int slot = 0; slot < 2; slot++) {
      IncrementSingleFunnel(
        m_funnelStats[periodSlots[slot]][directionIndex],
        stage);
    }
  }

  void RecordSingleOutcome(
    SPbV703BarrierStats &stats,
    const ENUM_PB_V703_OUTCOME outcome,
    const double timeoutR) {

    switch (outcome) {
      case PB_V703_OUTCOME_TP_FIRST:
        stats.tpFirstCount++;
        break;

      case PB_V703_OUTCOME_SL_FIRST:
        stats.slFirstCount++;
        break;

      case PB_V703_OUTCOME_AMBIGUOUS:
        stats.ambiguousCount++;
        break;

      case PB_V703_OUTCOME_TIMEOUT:
        stats.timeoutCount++;
        stats.sumTimeoutR += timeoutR;
        break;
    }
  }

  void RecordOutcome(
    const SPbV703Observation &observation,
    const int scenarioIndex,
    const ENUM_PB_V703_OUTCOME outcome,
    const double timeoutR) {

    int periodSlots[2];
    periodSlots[0] = 0;
    periodSlots[1] = observation.periodIndex;

    for (int slot = 0; slot < 2; slot++) {
      RecordSingleOutcome(
        m_combinedStats[periodSlots[slot]]
          [observation.directionIndex]
          [scenarioIndex],
        outcome,
        timeoutR);
    }

    RecordSingleOutcome(
      m_hourStats[observation.hourSlotIndex]
        [observation.directionIndex]
        [scenarioIndex],
      outcome,
      timeoutR);

    RecordSingleOutcome(
      m_volatilityStats[observation.volatilityClassIndex]
        [observation.directionIndex]
        [scenarioIndex],
      outcome,
      timeoutR);
  }

  void CloseScenario(
    SPbV703Observation &observation,
    const int scenarioIndex,
    const ENUM_PB_V703_OUTCOME outcome,
    const double timeoutR) {

    RecordOutcome(
      observation,
      scenarioIndex,
      outcome,
      timeoutR);

    observation.scenarioClosed[scenarioIndex] = true;
  }

  bool AllScenariosClosed(
    const SPbV703Observation &observation) const {

    for (int scenario = 0;
      scenario < PB_V703_SCENARIO_COUNT;
      scenario++) {

      if (!observation.scenarioClosed[scenario])
        return false;
    }

    return true;
  }

  void UpdateObservation(
    SPbV703Observation &observation,
    const MqlRates &monitorBar) {

    observation.elapsedMinutes++;

    for (int scenario = 0;
      scenario < PB_V703_SCENARIO_COUNT;
      scenario++) {

      if (observation.scenarioClosed[scenario])
        continue;

      double targetDistance =
        m_tpAtr[scenario] * observation.atrAtSignal;

      double stopDistance =
        m_slAtr[scenario] * observation.atrAtSignal;

      double targetPrice = observation.directionIndex == 0
        ? observation.entryPrice + targetDistance
        : observation.entryPrice - targetDistance;

      double stopPrice = observation.directionIndex == 0
        ? observation.entryPrice - stopDistance
        : observation.entryPrice + stopDistance;

      bool targetTouched = observation.directionIndex == 0
        ? monitorBar.high >= targetPrice
        : monitorBar.low <= targetPrice;

      bool stopTouched = observation.directionIndex == 0
        ? monitorBar.low <= stopPrice
        : monitorBar.high >= stopPrice;

      if (targetTouched && stopTouched) {
        CloseScenario(
          observation,
          scenario,
          PB_V703_OUTCOME_AMBIGUOUS,
          0.0);

        continue;
      }

      if (targetTouched) {
        CloseScenario(
          observation,
          scenario,
          PB_V703_OUTCOME_TP_FIRST,
          0.0);

        continue;
      }

      if (stopTouched) {
        CloseScenario(
          observation,
          scenario,
          PB_V703_OUTCOME_SL_FIRST,
          0.0);

        continue;
      }

      if (observation.elapsedMinutes >= m_maximumHoldingMinutes) {
        double directionSign = observation.directionIndex == 0
          ? 1.0
          : -1.0;

        double timeoutR = directionSign *
          (monitorBar.close - observation.entryPrice) /
          stopDistance;

        CloseScenario(
          observation,
          scenario,
          PB_V703_OUTCOME_TIMEOUT,
          timeoutR);
      }
    }
  }

  void ProcessClosedMonitorBar(
    const MqlRates &monitorBar) {

    m_processedMonitorBarCount++;

    for (int i = 0; i < PB_V703_MAX_PENDING; i++) {
      if (!m_pending[i].isActive)
        continue;

      UpdateObservation(m_pending[i], monitorBar);

      if (AllScenariosClosed(m_pending[i]))
        ZeroMemory(m_pending[i]);
    }
  }

  void AddObservation(
    const MqlRates &signalBar,
    const int directionIndex,
    const int periodIndex,
    const int hourSlotIndex,
    const int volatilityClassIndex,
    const double atrPrice) {

    for (int i = 0; i < PB_V703_MAX_PENDING; i++) {
      if (m_pending[i].isActive)
        continue;

      ZeroMemory(m_pending[i]);
      m_pending[i].isActive = true;
      m_pending[i].directionIndex = directionIndex;
      m_pending[i].periodIndex = periodIndex;
      m_pending[i].hourSlotIndex = hourSlotIndex;
      m_pending[i].volatilityClassIndex = volatilityClassIndex;
      m_pending[i].signalTime = signalBar.time;
      m_pending[i].entryPrice = signalBar.close;
      m_pending[i].atrAtSignal = atrPrice;
      m_pending[i].elapsedMinutes = 0;
      return;
    }

    m_pendingDroppedCount++;
  }

  bool ProcessClosedSignalBar(void) {
    int requiredBars = m_breakoutLookbackBars + 1;
    MqlRates bars[];
    ArraySetAsSeries(bars, true);

    if (CopyRates(
      m_symbol,
      m_signalTimeframe,
      1,
      requiredBars,
      bars) != requiredBars) {

      m_invalidSignalBarCount++;
      return false;
    }

    MqlRates signalBar = bars[0];
    m_processedSignalBarCount++;
    m_analysisEndTime = signalBar.time;

    if (m_analysisStartTime == 0)
      m_analysisStartTime = signalBar.time;

    int signalHour = HourIndex(signalBar.time);

    if (signalHour < m_entryStartHour || signalHour >= m_entryEndHour)
      return true;

    double priorHigh = bars[1].high;
    double priorLow = bars[1].low;

    for (int i = 2; i < requiredBars; i++) {
      if (bars[i].high > priorHigh)
        priorHigh = bars[i].high;

      if (bars[i].low < priorLow)
        priorLow = bars[i].low;
    }

    int signalDirection = 0;

    if (signalBar.close > priorHigh)
      signalDirection = 1;
    else if (signalBar.close < priorLow)
      signalDirection = -1;

    if (signalDirection == 0)
      return true;

    int directionIndex = signalDirection > 0 ? 0 : 1;
    int periodIndex = CalendarPeriodIndex(signalBar.time);
    IncrementFunnel(periodIndex, directionIndex, 0);

    double atrPrice = 0.0;
    double emaPrice = 0.0;
    double contextClose = 0.0;

    if (!ReadContext(atrPrice, emaPrice, contextClose)) {
      m_contextUnavailableCount++;
      return true;
    }

    int trendDirection = TrendDirection(
      contextClose,
      emaPrice,
      atrPrice);

    if (trendDirection != signalDirection)
      return true;

    IncrementFunnel(periodIndex, directionIndex, 1);

    double priorRangeAtr = (priorHigh - priorLow) / atrPrice;

    if (priorRangeAtr < m_compressionMaximumAtr)
      return true;

    IncrementFunnel(periodIndex, directionIndex, 2);

    int hourSlotIndex = signalHour - m_entryStartHour;
    int volatilityClassIndex = priorRangeAtr > m_expansionMinimumAtr
      ? PB_V703_VOL_EXPANSION
      : PB_V703_VOL_NORMAL;

    AddObservation(
      signalBar,
      directionIndex,
      periodIndex,
      hourSlotIndex,
      volatilityClassIndex,
      atrPrice);

    return true;
  }

  long OutcomeSampleCount(
    const SPbV703BarrierStats &stats) const {

    return stats.tpFirstCount +
      stats.slFirstCount +
      stats.ambiguousCount +
      stats.timeoutCount;
  }

  string ScenarioLabel(const int scenarioIndex) const {
    return StringFormat(
      "TP%.2f_SL%.2f",
      m_tpAtr[scenarioIndex],
      m_slAtr[scenarioIndex]);
  }

  void PrintBarrierLine(
    const string period,
    const string dimension,
    const string value,
    const int directionIndex,
    const int scenarioIndex,
    const SPbV703BarrierStats &stats) const {

    long samples = OutcomeSampleCount(stats);
    long decisiveCount = stats.tpFirstCount + stats.slFirstCount;

    double decisiveTpRate = decisiveCount > 0
      ? 100.0 * (double)stats.tpFirstCount / (double)decisiveCount
      : 0.0;

    double rewardRisk =
      m_tpAtr[scenarioIndex] / m_slAtr[scenarioIndex];

    double baseR =
      (double)stats.tpFirstCount * rewardRisk -
      (double)stats.slFirstCount +
      stats.sumTimeoutR;

    double pessimisticR = samples > 0
      ? (baseR - (double)stats.ambiguousCount) / (double)samples
      : 0.0;

    double optimisticR = samples > 0
      ? (baseR +
        (double)stats.ambiguousCount * rewardRisk) /
        (double)samples
      : 0.0;

    PrintFormat(
      "[%s][INFO] Analyse barrières [%s][%s][%s][%s][%s] : "
      "N=%I64d | TP premier=%I64d | SL premier=%I64d | "
      "Ambigus M1=%I64d | Timeout=%I64d | "
      "TP décisifs=%.2f%% | Espérance=[%.3f ; %.3f] R",
      __FILE__,
      period,
      dimension,
      value,
      PbV703DirectionToString(directionIndex),
      ScenarioLabel(scenarioIndex),
      samples,
      stats.tpFirstCount,
      stats.slFirstCount,
      stats.ambiguousCount,
      stats.timeoutCount,
      decisiveTpRate,
      pessimisticR,
      optimisticR);
  }

public:
  CGoldIntradayBarrierProfiler(void) {
    m_symbol = "";
    m_signalTimeframe = PERIOD_M15;
    m_contextTimeframe = PERIOD_H1;
    m_monitorTimeframe = PERIOD_M1;
    m_signalPeriodSeconds = 0;
    m_monitorPeriodSeconds = 0;
    m_contextAtrPeriod = 14;
    m_contextTrendEmaPeriod = 50;
    m_trendNeutralAtrBand = 0.10;
    m_breakoutLookbackBars = 4;
    m_compressionMaximumAtr = 0.75;
    m_expansionMinimumAtr = 1.25;
    m_entryStartHour = 13;
    m_entryEndHour = 15;
    m_maximumHoldingMinutes = 120;
    m_contextAtrHandle = INVALID_HANDLE;
    m_contextEmaHandle = INVALID_HANDLE;
    m_currentSignalBarTime = 0;
    m_currentMonitorBarTime = 0;
    m_currentMonitorHigh = 0.0;
    m_currentMonitorLow = 0.0;
    m_currentMonitorClose = 0.0;

    m_tpAtr[0] = 0.50;
    m_slAtr[0] = 0.50;
    m_tpAtr[1] = 0.75;
    m_slAtr[1] = 0.50;
    m_tpAtr[2] = 0.75;
    m_slAtr[2] = 0.75;
    m_tpAtr[3] = 1.00;
    m_slAtr[3] = 0.75;
    m_tpAtr[4] = 1.00;
    m_slAtr[4] = 1.00;

    ZeroMemory(m_pending);
    ZeroMemory(m_funnelStats);
    ZeroMemory(m_combinedStats);
    ZeroMemory(m_hourStats);
    ZeroMemory(m_volatilityStats);

    m_processedSignalBarCount = 0;
    m_processedMonitorBarCount = 0;
    m_invalidSignalBarCount = 0;
    m_invalidMonitorBarCount = 0;
    m_contextUnavailableCount = 0;
    m_pendingDroppedCount = 0;
    m_analysisStartTime = 0;
    m_analysisEndTime = 0;
  }

  bool Initialize(
    const string symbol,
    const ENUM_TIMEFRAMES signalTimeframe,
    const ENUM_TIMEFRAMES contextTimeframe,
    const ENUM_TIMEFRAMES monitorTimeframe,
    const int contextAtrPeriod,
    const int contextTrendEmaPeriod,
    const double trendNeutralAtrBand,
    const int breakoutLookbackBars,
    const double compressionMaximumAtr,
    const double expansionMinimumAtr,
    const int entryStartHour,
    const int entryEndHour,
    const int maximumHoldingMinutes) {

    if (signalTimeframe != PERIOD_M15 ||
      contextTimeframe != PERIOD_H1 ||
      monitorTimeframe != PERIOD_M1) {

      PrintFormat(
        "[%s][ERROR] La v7.03 exige Signal=M15, Contexte=H1 "
        "et Suivi=M1.",
        __FILE__);

      return false;
    }

    if (contextAtrPeriod < 2 ||
      contextTrendEmaPeriod < 2 ||
      trendNeutralAtrBand < 0.0 ||
      breakoutLookbackBars < 2 ||
      compressionMaximumAtr <= 0.0 ||
      expansionMinimumAtr <= compressionMaximumAtr ||
      entryStartHour < 0 ||
      entryEndHour <= entryStartHour ||
      entryEndHour - entryStartHour != PB_V703_HOUR_SLOT_COUNT ||
      entryEndHour > 24 ||
      maximumHoldingMinutes < 15) {

      PrintFormat(
        "[%s][ERROR] Paramètres du profileur de barrières invalides.",
        __FILE__);

      return false;
    }

    m_symbol = symbol;
    m_signalTimeframe = signalTimeframe;
    m_contextTimeframe = contextTimeframe;
    m_monitorTimeframe = monitorTimeframe;
    m_signalPeriodSeconds = PeriodSeconds(m_signalTimeframe);
    m_monitorPeriodSeconds = PeriodSeconds(m_monitorTimeframe);
    m_contextAtrPeriod = contextAtrPeriod;
    m_contextTrendEmaPeriod = contextTrendEmaPeriod;
    m_trendNeutralAtrBand = trendNeutralAtrBand;
    m_breakoutLookbackBars = breakoutLookbackBars;
    m_compressionMaximumAtr = compressionMaximumAtr;
    m_expansionMinimumAtr = expansionMinimumAtr;
    m_entryStartHour = entryStartHour;
    m_entryEndHour = entryEndHour;
    m_maximumHoldingMinutes = maximumHoldingMinutes;

    if (m_signalPeriodSeconds <= 0 || m_monitorPeriodSeconds <= 0)
      return false;

    m_contextAtrHandle = iATR(
      m_symbol,
      m_contextTimeframe,
      m_contextAtrPeriod);

    if (m_contextAtrHandle == INVALID_HANDLE) {
      PrintFormat(
        "[%s][ERROR] Création ATR contexte impossible. Erreur=%d",
        __FILE__,
        GetLastError());

      return false;
    }

    m_contextEmaHandle = iMA(
      m_symbol,
      m_contextTimeframe,
      m_contextTrendEmaPeriod,
      0,
      MODE_EMA,
      PRICE_CLOSE);

    if (m_contextEmaHandle == INVALID_HANDLE) {
      PrintFormat(
        "[%s][ERROR] Création EMA contexte impossible. Erreur=%d",
        __FILE__,
        GetLastError());

      IndicatorRelease(m_contextAtrHandle);
      m_contextAtrHandle = INVALID_HANDLE;
      return false;
    }

    return true;
  }

  void Shutdown(void) {
    if (m_contextAtrHandle != INVALID_HANDLE) {
      IndicatorRelease(m_contextAtrHandle);
      m_contextAtrHandle = INVALID_HANDLE;
    }

    if (m_contextEmaHandle != INVALID_HANDLE) {
      IndicatorRelease(m_contextEmaHandle);
      m_contextEmaHandle = INVALID_HANDLE;
    }
  }

  bool ProcessTick(const MqlTick &tick) {
    datetime monitorBarTime = (datetime)(
      ((long)tick.time / m_monitorPeriodSeconds) *
      m_monitorPeriodSeconds);

    datetime signalBarTime = (datetime)(
      ((long)tick.time / m_signalPeriodSeconds) *
      m_signalPeriodSeconds);

    if (monitorBarTime <= 0 || signalBarTime <= 0)
      return false;

    if (m_currentMonitorBarTime == 0) {
      m_currentMonitorBarTime = monitorBarTime;
      m_currentSignalBarTime = signalBarTime;
      m_currentMonitorHigh = tick.bid;
      m_currentMonitorLow = tick.bid;
      m_currentMonitorClose = tick.bid;
      return true;
    }

    bool signalBarChanged = false;

    if (monitorBarTime != m_currentMonitorBarTime) {
      MqlRates closedMonitorBar;
      ZeroMemory(closedMonitorBar);
      closedMonitorBar.time = m_currentMonitorBarTime;
      closedMonitorBar.high = m_currentMonitorHigh;
      closedMonitorBar.low = m_currentMonitorLow;
      closedMonitorBar.close = m_currentMonitorClose;

      ProcessClosedMonitorBar(closedMonitorBar);
      m_currentMonitorBarTime = monitorBarTime;
      m_currentMonitorHigh = tick.bid;
      m_currentMonitorLow = tick.bid;
      m_currentMonitorClose = tick.bid;
    }
    else {
      if (tick.bid > m_currentMonitorHigh)
        m_currentMonitorHigh = tick.bid;

      if (tick.bid < m_currentMonitorLow)
        m_currentMonitorLow = tick.bid;

      m_currentMonitorClose = tick.bid;
    }

    if (signalBarTime != m_currentSignalBarTime) {
      ProcessClosedSignalBar();
      m_currentSignalBarTime = signalBarTime;
      signalBarChanged = true;
    }

    return signalBarChanged;
  }

  string BuildStatusText(const datetime currentTime) const {
    int activeObservations = 0;

    for (int i = 0; i < PB_V703_MAX_PENDING; i++) {
      if (m_pending[i].isActive)
        activeObservations++;
    }

    return StringFormat(
      "PROFILAGE BARRIÈRES GOLD — AUCUN TRADING\n"
      "Heure serveur : %02d h | Fenêtre : %02d h-%02d h\n"
      "Bougies M15 : %I64d | Minutes M1 : %I64d\n"
      "Observations actives : %d | Durée maximale : %d minutes",
      HourIndex(currentTime),
      m_entryStartHour,
      m_entryEndHour,
      m_processedSignalBarCount,
      m_processedMonitorBarCount,
      activeObservations,
      m_maximumHoldingMinutes);
  }

  void PrintFinalReport(void) const {
    int activeObservations = 0;

    for (int i = 0; i < PB_V703_MAX_PENDING; i++) {
      if (m_pending[i].isActive)
        activeObservations++;
    }

    PrintFormat(
      "[%s][INFO] Résumé barrières [1/2] : "
      "Bougies M15=%I64d | Minutes M1=%I64d | "
      "Invalides M15/M1=%I64d/%I64d | Début=%s | Fin=%s | "
      "Contexte indisponible=%I64d | Incomplètes=%d | Perdues=%I64d",
      __FILE__,
      m_processedSignalBarCount,
      m_processedMonitorBarCount,
      m_invalidSignalBarCount,
      m_invalidMonitorBarCount,
      TimeToString(m_analysisStartTime, TIME_DATE|TIME_MINUTES),
      TimeToString(m_analysisEndTime, TIME_DATE|TIME_MINUTES),
      m_contextUnavailableCount,
      activeObservations,
      m_pendingDroppedCount);

    PrintFormat(
      "[%s][INFO] Résumé barrières [2/2] : "
      "Signal=%s | Contexte=%s EMA=%d ATR=%d Bande=%.2f ATR | "
      "Suivi=%s | Fenêtre=%02dh-%02dh | Cassure=%d | "
      "Compression exclue<%.2f ATR | Expansion>%.2f ATR | "
      "Durée=%d minutes | Coûts=NON INCLUS | "
      "Mode=ANALYSE_SANS_TRADING",
      __FILE__,
      EnumToString(m_signalTimeframe),
      EnumToString(m_contextTimeframe),
      m_contextTrendEmaPeriod,
      m_contextAtrPeriod,
      m_trendNeutralAtrBand,
      EnumToString(m_monitorTimeframe),
      m_entryStartHour,
      m_entryEndHour,
      m_breakoutLookbackBars,
      m_compressionMaximumAtr,
      m_expansionMinimumAtr,
      m_maximumHoldingMinutes);

    for (int period = 0; period < PB_V703_PERIOD_COUNT; period++) {
      for (int direction = 0;
        direction < PB_V703_DIRECTION_COUNT;
        direction++) {

        SPbV703FunnelStats funnel =
          m_funnelStats[period][direction];

        double acceptanceRate = funnel.windowBreakoutCount > 0
          ? 100.0 * (double)funnel.eligibleCount /
            (double)funnel.windowBreakoutCount
          : 0.0;

        PrintFormat(
          "[%s][INFO] Entonnoir [%s][%s] : "
          "Cassures %02dh-%02dh=%I64d | Alignées H1=%I64d | "
          "Hors compression=%I64d | Acceptation=%.2f%%",
          __FILE__,
          PbV703PeriodToString(period),
          PbV703DirectionToString(direction),
          m_entryStartHour,
          m_entryEndHour,
          funnel.windowBreakoutCount,
          funnel.alignedCount,
          funnel.eligibleCount,
          acceptanceRate);
      }
    }

    string combinedHourLabel = StringFormat(
      "%02dh-%02dh",
      m_entryStartHour,
      m_entryEndHour);

    for (int period = 0; period < PB_V703_PERIOD_COUNT; period++) {
      for (int direction = 0;
        direction < PB_V703_DIRECTION_COUNT;
        direction++) {

        for (int scenario = 0;
          scenario < PB_V703_SCENARIO_COUNT;
          scenario++) {

          PrintBarrierLine(
            PbV703PeriodToString(period),
            "COMBINE",
            combinedHourLabel,
            direction,
            scenario,
            m_combinedStats[period][direction][scenario]);
        }
      }
    }

    for (int hourSlot = 0;
      hourSlot < PB_V703_HOUR_SLOT_COUNT;
      hourSlot++) {

      string hourLabel = StringFormat(
        "%02dh-%02dh",
        m_entryStartHour + hourSlot,
        m_entryStartHour + hourSlot + 1);

      for (int direction = 0;
        direction < PB_V703_DIRECTION_COUNT;
        direction++) {

        for (int scenario = 0;
          scenario < PB_V703_SCENARIO_COUNT;
          scenario++) {

          PrintBarrierLine(
            "GLOBAL",
            "HEURE",
            hourLabel,
            direction,
            scenario,
            m_hourStats[hourSlot][direction][scenario]);
        }
      }
    }

    for (int volatilityClass = 0;
      volatilityClass < PB_V703_VOL_CLASS_COUNT;
      volatilityClass++) {

      for (int direction = 0;
        direction < PB_V703_DIRECTION_COUNT;
        direction++) {

        for (int scenario = 0;
          scenario < PB_V703_SCENARIO_COUNT;
          scenario++) {

          PrintBarrierLine(
            "GLOBAL",
            "VOLATILITE",
            PbV703VolatilityToString(volatilityClass),
            direction,
            scenario,
            m_volatilityStats[volatilityClass]
              [direction]
              [scenario]);
        }
      }
    }
  }
};

#endif

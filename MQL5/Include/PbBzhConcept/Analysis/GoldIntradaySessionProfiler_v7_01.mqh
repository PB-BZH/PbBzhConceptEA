//+------------------------------------------------------------------+
//|              GoldIntradaySessionProfiler_v7_01.mqh              |
//|  Profileur GOLD M15/H1 par sessions, sans aucune prise de trade |
//+------------------------------------------------------------------+
#ifndef PB_BZH_GOLD_INTRADAY_SESSION_PROFILER_V7_01_MQH
#define PB_BZH_GOLD_INTRADAY_SESSION_PROFILER_V7_01_MQH

#define PB_GOLD_MAX_PENDING_OBSERVATIONS 64

enum ENUM_PB_GOLD_SESSION {
  PB_GOLD_SESSION_ASIA = 0,
  PB_GOLD_SESSION_EUROPE = 1,
  PB_GOLD_SESSION_EUROPE_USA = 2,
  PB_GOLD_SESSION_USA = 3,
  PB_GOLD_SESSION_ROLLOVER = 4,
  PB_GOLD_SESSION_COUNT = 5
};

string PbGoldSessionToString(
  const ENUM_PB_GOLD_SESSION session) {

  switch (session) {
    case PB_GOLD_SESSION_ASIA:
      return "ASIE";

    case PB_GOLD_SESSION_EUROPE:
      return "EUROPE";

    case PB_GOLD_SESSION_EUROPE_USA:
      return "EUROPE_USA";

    case PB_GOLD_SESSION_USA:
      return "USA";

    case PB_GOLD_SESSION_ROLLOVER:
      return "ROLLOVER";

    default:
      return "INCONNUE";
  }
}

struct SPbGoldSessionStats {
  string label;

  long barCount;
  long bullishBarCount;
  long bearishBarCount;
  long neutralBarCount;

  double sumRangePoints;
  double sumBodyPoints;
  double sumSignedReturnPoints;
  double sumAbsoluteReturnPoints;
  double sumDirectionalEfficiencyPercent;
  double sumTickVolume;

  long contextSampleCount;
  double sumContextAtrPoints;
  double sumContextAdx;
  double sumRangeToContextAtrPercent;

  long spreadBarCount;
  double sumAverageSpreadPoints;
  double maximumSpreadPoints;

  long sessionEntryCount;
  double sumSessionEntryGapPoints;

  long breakoutAttemptCount;
  long confirmedBreakoutCount;
  long falseBreakoutCount;
  long confirmedUpBreakoutCount;
  long confirmedDownBreakoutCount;

  long followSampleCount;
  long followSuccessCount;
  double sumFollowMfePoints;
  double sumFollowMaePoints;

  long breakoutFollowSampleCount;
  long breakoutFollowSuccessCount;
  double sumBreakoutFollowMfePoints;
  double sumBreakoutFollowMaePoints;
};

struct SPbGoldForwardObservation {
  bool isActive;
  int sessionIndex;
  int periodIndex;
  int direction;
  bool isConfirmedBreakout;
  datetime signalTime;
  double entryPrice;
  double highestPrice;
  double lowestPrice;
  double atrPointsAtSignal;
  int elapsedBars;
};

class CGoldIntradaySessionProfiler {
private:
  string m_symbol;
  double m_point;
  int m_digits;

  ENUM_TIMEFRAMES m_signalTimeframe;
  ENUM_TIMEFRAMES m_contextTimeframe;
  int m_contextAtrPeriod;
  int m_contextAdxPeriod;
  int m_breakoutLookbackBars;
  int m_followThroughBars;
  double m_followThroughAtrThreshold;

  int m_europeStartHour;
  int m_europeUsaStartHour;
  int m_usaStartHour;
  int m_rolloverStartHour;
  int m_asiaStartHour;

  int m_contextAtrHandle;
  int m_contextAdxHandle;
  int m_signalPeriodSeconds;

  datetime m_currentSignalBarTime;
  double m_currentBarSpreadSum;
  double m_currentBarMaximumSpread;
  long m_currentBarSpreadSampleCount;

  SPbGoldSessionStats m_globalStats[PB_GOLD_SESSION_COUNT];
  SPbGoldSessionStats m_periodStats[3][PB_GOLD_SESSION_COUNT];
  SPbGoldForwardObservation
    m_pending[PB_GOLD_MAX_PENDING_OBSERVATIONS];

  long m_processedBarCount;
  long m_invalidBarCount;
  long m_pendingDroppedCount;
  datetime m_analysisStartTime;
  datetime m_analysisEndTime;
  double m_firstPrice;
  double m_lastPrice;
  int m_lastSessionIndex;
  double m_lastClosedBarPrice;

  void ResetStats(
    SPbGoldSessionStats &stats,
    const string label) {

    ZeroMemory(stats);
    stats.label = label;
  }

  int PeriodIndex(
    const datetime value) const {

    MqlDateTime parts;
    TimeToStruct(value, parts);

    if (parts.year <= 2020)
      return 0;

    if (parts.year <= 2023)
      return 1;

    return 2;
  }

  string PeriodLabel(
    const int periodIndex) const {

    if (periodIndex == 0)
      return "A 2018-2020";

    if (periodIndex == 1)
      return "B 2021-2023";

    return "C 2024-fin";
  }

  ENUM_PB_GOLD_SESSION ClassifySession(
    const datetime value) const {

    MqlDateTime parts;
    TimeToStruct(value, parts);

    int minuteOfDay = parts.hour * 60 + parts.min;
    int europeStart = m_europeStartHour * 60;
    int europeUsaStart = m_europeUsaStartHour * 60;
    int usaStart = m_usaStartHour * 60;
    int rolloverStart = m_rolloverStartHour * 60;
    int asiaStart = m_asiaStartHour * 60;

    if (minuteOfDay >= asiaStart || minuteOfDay < europeStart)
      return PB_GOLD_SESSION_ASIA;

    if (minuteOfDay < europeUsaStart)
      return PB_GOLD_SESSION_EUROPE;

    if (minuteOfDay < usaStart)
      return PB_GOLD_SESSION_EUROPE_USA;

    if (minuteOfDay < rolloverStart)
      return PB_GOLD_SESSION_USA;

    return PB_GOLD_SESSION_ROLLOVER;
  }

  bool ReadContextValues(
    double &atrPoints,
    double &adxValue) const {

    atrPoints = 0.0;
    adxValue = 0.0;

    double atrBuffer[1];
    double adxBuffer[1];

    if (CopyBuffer(
      m_contextAtrHandle,
      0,
      1,
      1,
      atrBuffer) != 1) {

      return false;
    }

    if (CopyBuffer(
      m_contextAdxHandle,
      0,
      1,
      1,
      adxBuffer) != 1) {

      return false;
    }

    if (atrBuffer[0] <= 0.0 || adxBuffer[0] < 0.0)
      return false;

    atrPoints = atrBuffer[0] / m_point;
    adxValue = adxBuffer[0];
    return true;
  }

  void UpdateBarStats(
    SPbGoldSessionStats &stats,
    const MqlRates &bar,
    const double averageSpreadPoints,
    const double maximumSpreadPoints,
    const double contextAtrPoints,
    const double contextAdx,
    const bool hasContext,
    const bool isSessionEntry,
    const double sessionEntryGapPoints,
    const bool breakoutAttempted,
    const int confirmedBreakoutDirection) {

    double rangePoints =
      (bar.high - bar.low) / m_point;

    double signedReturnPoints =
      (bar.close - bar.open) / m_point;

    double bodyPoints = MathAbs(signedReturnPoints);
    double efficiencyPercent =
      rangePoints > 0.0
      ? 100.0 * bodyPoints / rangePoints
      : 0.0;

    stats.barCount++;
    stats.sumRangePoints += rangePoints;
    stats.sumBodyPoints += bodyPoints;
    stats.sumSignedReturnPoints += signedReturnPoints;
    stats.sumAbsoluteReturnPoints += MathAbs(signedReturnPoints);
    stats.sumDirectionalEfficiencyPercent += efficiencyPercent;
    stats.sumTickVolume += (double)bar.tick_volume;

    if (signedReturnPoints > 0.0)
      stats.bullishBarCount++;
    else if (signedReturnPoints < 0.0)
      stats.bearishBarCount++;
    else
      stats.neutralBarCount++;

    if (hasContext) {
      stats.contextSampleCount++;
      stats.sumContextAtrPoints += contextAtrPoints;
      stats.sumContextAdx += contextAdx;

      if (contextAtrPoints > 0.0) {
        stats.sumRangeToContextAtrPercent +=
          100.0 * rangePoints / contextAtrPoints;
      }
    }

    if (averageSpreadPoints >= 0.0) {
      stats.spreadBarCount++;
      stats.sumAverageSpreadPoints += averageSpreadPoints;

      if (maximumSpreadPoints > stats.maximumSpreadPoints)
        stats.maximumSpreadPoints = maximumSpreadPoints;
    }

    if (isSessionEntry) {
      stats.sessionEntryCount++;
      stats.sumSessionEntryGapPoints += sessionEntryGapPoints;
    }

    if (breakoutAttempted)
      stats.breakoutAttemptCount++;

    if (confirmedBreakoutDirection != 0) {
      stats.confirmedBreakoutCount++;

      if (confirmedBreakoutDirection > 0)
        stats.confirmedUpBreakoutCount++;
      else
        stats.confirmedDownBreakoutCount++;
    }
    else if (breakoutAttempted) {
      stats.falseBreakoutCount++;
    }
  }

  void UpdateForwardStats(
    SPbGoldSessionStats &stats,
    const SPbGoldForwardObservation &observation,
    const double mfePoints,
    const double maePoints,
    const bool success) {

    stats.followSampleCount++;
    stats.sumFollowMfePoints += mfePoints;
    stats.sumFollowMaePoints += maePoints;

    if (success)
      stats.followSuccessCount++;

    if (!observation.isConfirmedBreakout)
      return;

    stats.breakoutFollowSampleCount++;
    stats.sumBreakoutFollowMfePoints += mfePoints;
    stats.sumBreakoutFollowMaePoints += maePoints;

    if (success)
      stats.breakoutFollowSuccessCount++;
  }

  void FinalizeObservation(
    const SPbGoldForwardObservation &observation) {

    double mfePoints =
      observation.direction > 0
      ? (observation.highestPrice - observation.entryPrice) / m_point
      : (observation.entryPrice - observation.lowestPrice) / m_point;

    double maePoints =
      observation.direction > 0
      ? (observation.entryPrice - observation.lowestPrice) / m_point
      : (observation.highestPrice - observation.entryPrice) / m_point;

    mfePoints = MathMax(0.0, mfePoints);
    maePoints = MathMax(0.0, maePoints);

    bool success =
      observation.atrPointsAtSignal > 0.0 &&
      mfePoints >=
        m_followThroughAtrThreshold *
        observation.atrPointsAtSignal;

    UpdateForwardStats(
      m_globalStats[observation.sessionIndex],
      observation,
      mfePoints,
      maePoints,
      success);

    UpdateForwardStats(
      m_periodStats[observation.periodIndex]
        [observation.sessionIndex],
      observation,
      mfePoints,
      maePoints,
      success);
  }

  void UpdatePendingObservations(
    const MqlRates &closedBar) {

    for (int i = 0; i < PB_GOLD_MAX_PENDING_OBSERVATIONS; i++) {
      if (!m_pending[i].isActive)
        continue;

      if (closedBar.high > m_pending[i].highestPrice)
        m_pending[i].highestPrice = closedBar.high;

      if (closedBar.low < m_pending[i].lowestPrice)
        m_pending[i].lowestPrice = closedBar.low;

      m_pending[i].elapsedBars++;

      if (m_pending[i].elapsedBars < m_followThroughBars)
        continue;

      FinalizeObservation(m_pending[i]);
      ZeroMemory(m_pending[i]);
    }
  }

  void AddPendingObservation(
    const MqlRates &bar,
    const int sessionIndex,
    const int periodIndex,
    const int direction,
    const bool isConfirmedBreakout,
    const double contextAtrPoints) {

    if (direction == 0 || contextAtrPoints <= 0.0)
      return;

    for (int i = 0; i < PB_GOLD_MAX_PENDING_OBSERVATIONS; i++) {
      if (m_pending[i].isActive)
        continue;

      ZeroMemory(m_pending[i]);
      m_pending[i].isActive = true;
      m_pending[i].sessionIndex = sessionIndex;
      m_pending[i].periodIndex = periodIndex;
      m_pending[i].direction = direction;
      m_pending[i].isConfirmedBreakout = isConfirmedBreakout;
      m_pending[i].signalTime = bar.time;
      m_pending[i].entryPrice = bar.close;
      m_pending[i].highestPrice = bar.close;
      m_pending[i].lowestPrice = bar.close;
      m_pending[i].atrPointsAtSignal = contextAtrPoints;
      m_pending[i].elapsedBars = 0;
      return;
    }

    m_pendingDroppedCount++;
  }

  bool ProcessClosedBar(
    const double averageSpreadPoints,
    const double maximumSpreadPoints) {

    int requiredBars = m_breakoutLookbackBars + 1;
    MqlRates bars[];
    ArraySetAsSeries(bars, true);

    if (CopyRates(
      m_symbol,
      m_signalTimeframe,
      1,
      requiredBars,
      bars) != requiredBars) {

      m_invalidBarCount++;
      return false;
    }

    MqlRates closedBar = bars[0];

    UpdatePendingObservations(closedBar);

    double priorHigh = bars[1].high;
    double priorLow = bars[1].low;

    for (int i = 2; i < requiredBars; i++) {
      if (bars[i].high > priorHigh)
        priorHigh = bars[i].high;

      if (bars[i].low < priorLow)
        priorLow = bars[i].low;
    }

    bool upwardAttempt = closedBar.high > priorHigh;
    bool downwardAttempt = closedBar.low < priorLow;
    bool breakoutAttempted = upwardAttempt || downwardAttempt;

    int confirmedBreakoutDirection = 0;

    if (closedBar.close > priorHigh)
      confirmedBreakoutDirection = 1;
    else if (closedBar.close < priorLow)
      confirmedBreakoutDirection = -1;

    double contextAtrPoints = 0.0;
    double contextAdx = 0.0;
    bool hasContext = ReadContextValues(
      contextAtrPoints,
      contextAdx);

    ENUM_PB_GOLD_SESSION session =
      ClassifySession(closedBar.time);

    int sessionIndex = (int)session;
    int periodIndex = PeriodIndex(closedBar.time);

    bool isSessionEntry =
      m_lastSessionIndex >= 0 &&
      sessionIndex != m_lastSessionIndex;

    double sessionEntryGapPoints =
      isSessionEntry && m_lastClosedBarPrice > 0.0
      ? MathAbs(closedBar.open - m_lastClosedBarPrice) / m_point
      : 0.0;

    UpdateBarStats(
      m_globalStats[sessionIndex],
      closedBar,
      averageSpreadPoints,
      maximumSpreadPoints,
      contextAtrPoints,
      contextAdx,
      hasContext,
      isSessionEntry,
      sessionEntryGapPoints,
      breakoutAttempted,
      confirmedBreakoutDirection);

    UpdateBarStats(
      m_periodStats[periodIndex][sessionIndex],
      closedBar,
      averageSpreadPoints,
      maximumSpreadPoints,
      contextAtrPoints,
      contextAdx,
      hasContext,
      isSessionEntry,
      sessionEntryGapPoints,
      breakoutAttempted,
      confirmedBreakoutDirection);

    int barDirection = 0;

    if (closedBar.close > closedBar.open)
      barDirection = 1;
    else if (closedBar.close < closedBar.open)
      barDirection = -1;

    int observationDirection =
      confirmedBreakoutDirection != 0
      ? confirmedBreakoutDirection
      : barDirection;

    AddPendingObservation(
      closedBar,
      sessionIndex,
      periodIndex,
      observationDirection,
      confirmedBreakoutDirection != 0,
      contextAtrPoints);

    m_processedBarCount++;
    m_analysisEndTime = closedBar.time;

    if (m_analysisStartTime == 0) {
      m_analysisStartTime = closedBar.time;
      m_firstPrice = closedBar.close;
    }

    m_lastPrice = closedBar.close;
    m_lastSessionIndex = sessionIndex;
    m_lastClosedBarPrice = closedBar.close;
    return true;
  }

  void AccumulateSpread(
    const MqlTick &tick) {

    if (tick.ask <= 0.0 || tick.bid <= 0.0 || tick.ask < tick.bid)
      return;

    double spreadPoints =
      (tick.ask - tick.bid) / m_point;

    m_currentBarSpreadSum += spreadPoints;
    m_currentBarSpreadSampleCount++;

    if (spreadPoints > m_currentBarMaximumSpread)
      m_currentBarMaximumSpread = spreadPoints;
  }

  void PrintStatsLine(
    const string scope,
    const SPbGoldSessionStats &stats) const {

    double bars = (double)stats.barCount;
    double contextSamples = (double)stats.contextSampleCount;
    double spreadBars = (double)stats.spreadBarCount;
    double attempts = (double)stats.breakoutAttemptCount;
    double followSamples = (double)stats.followSampleCount;
    double breakoutFollowSamples =
      (double)stats.breakoutFollowSampleCount;

    double averageRange =
      bars > 0.0 ? stats.sumRangePoints / bars : 0.0;

    double averageBody =
      bars > 0.0 ? stats.sumBodyPoints / bars : 0.0;

    double averageBias =
      bars > 0.0 ? stats.sumSignedReturnPoints / bars : 0.0;

    double averageEfficiency =
      bars > 0.0
      ? stats.sumDirectionalEfficiencyPercent / bars
      : 0.0;

    double averageTickVolume =
      bars > 0.0 ? stats.sumTickVolume / bars : 0.0;

    double averageContextAtr =
      contextSamples > 0.0
      ? stats.sumContextAtrPoints / contextSamples
      : 0.0;

    double averageContextAdx =
      contextSamples > 0.0
      ? stats.sumContextAdx / contextSamples
      : 0.0;

    double averageRangeToAtr =
      contextSamples > 0.0
      ? stats.sumRangeToContextAtrPercent / contextSamples
      : 0.0;

    double averageSpread =
      spreadBars > 0.0
      ? stats.sumAverageSpreadPoints / spreadBars
      : 0.0;

    double averageSessionGap =
      stats.sessionEntryCount > 0
      ? stats.sumSessionEntryGapPoints / stats.sessionEntryCount
      : 0.0;

    double confirmationRate =
      attempts > 0.0
      ? 100.0 * stats.confirmedBreakoutCount / attempts
      : 0.0;

    double falseBreakoutRate =
      attempts > 0.0
      ? 100.0 * stats.falseBreakoutCount / attempts
      : 0.0;

    double followSuccessRate =
      followSamples > 0.0
      ? 100.0 * stats.followSuccessCount / followSamples
      : 0.0;

    double averageFollowMfe =
      followSamples > 0.0
      ? stats.sumFollowMfePoints / followSamples
      : 0.0;

    double averageFollowMae =
      followSamples > 0.0
      ? stats.sumFollowMaePoints / followSamples
      : 0.0;

    double breakoutFollowSuccessRate =
      breakoutFollowSamples > 0.0
      ? 100.0 * stats.breakoutFollowSuccessCount /
        breakoutFollowSamples
      : 0.0;

    double averageBreakoutMfe =
      breakoutFollowSamples > 0.0
      ? stats.sumBreakoutFollowMfePoints /
        breakoutFollowSamples
      : 0.0;

    double averageBreakoutMae =
      breakoutFollowSamples > 0.0
      ? stats.sumBreakoutFollowMaePoints /
        breakoutFollowSamples
      : 0.0;

    PrintFormat(
      "[%s][INFO] Profil session [%s][%s][1/2] : "
      "Bougies=%I64d | Haussières=%I64d | Baissières=%I64d | "
      "Range moyen=%.1f pts | Corps moyen=%.1f pts | "
      "Biais moyen=%+.2f pts | Efficacité=%.2f%% | "
      "ATR contexte=%.1f pts | ADX contexte=%.2f | "
      "Range/ATR=%.2f%% | Tick volume moyen=%.1f",
      __FILE__,
      scope,
      stats.label,
      stats.barCount,
      stats.bullishBarCount,
      stats.bearishBarCount,
      averageRange,
      averageBody,
      averageBias,
      averageEfficiency,
      averageContextAtr,
      averageContextAdx,
      averageRangeToAtr,
      averageTickVolume);

    PrintFormat(
      "[%s][INFO] Profil session [%s][%s][2/2] : "
      "Spread moyen=%.2f pts | Maximum=%.1f pts | "
      "Entrées session=%I64d | Gap moyen=%.1f pts | "
      "Tentatives cassure=%I64d | Confirmées=%I64d (%.2f%%) | "
      "Fausses=%I64d (%.2f%%) | Haut/Bas=%I64d/%I64d | "
      "Prolongements=%I64d | Succès=%.2f%% | MFE/MAE=%.1f/%.1f pts | "
      "Cassures suivies=%I64d | Succès=%.2f%% | "
      "MFE/MAE=%.1f/%.1f pts",
      __FILE__,
      scope,
      stats.label,
      averageSpread,
      stats.maximumSpreadPoints,
      stats.sessionEntryCount,
      averageSessionGap,
      stats.breakoutAttemptCount,
      stats.confirmedBreakoutCount,
      confirmationRate,
      stats.falseBreakoutCount,
      falseBreakoutRate,
      stats.confirmedUpBreakoutCount,
      stats.confirmedDownBreakoutCount,
      stats.followSampleCount,
      followSuccessRate,
      averageFollowMfe,
      averageFollowMae,
      stats.breakoutFollowSampleCount,
      breakoutFollowSuccessRate,
      averageBreakoutMfe,
      averageBreakoutMae);
  }

public:
  CGoldIntradaySessionProfiler(void) {
    m_symbol = "";
    m_point = 0.0;
    m_digits = 0;
    m_signalTimeframe = PERIOD_M15;
    m_contextTimeframe = PERIOD_H1;
    m_contextAtrPeriod = 14;
    m_contextAdxPeriod = 14;
    m_breakoutLookbackBars = 4;
    m_followThroughBars = 4;
    m_followThroughAtrThreshold = 0.50;
    m_europeStartHour = 7;
    m_europeUsaStartHour = 13;
    m_usaStartHour = 17;
    m_rolloverStartHour = 21;
    m_asiaStartHour = 22;
    m_contextAtrHandle = INVALID_HANDLE;
    m_contextAdxHandle = INVALID_HANDLE;
    m_signalPeriodSeconds = 0;
    m_currentSignalBarTime = 0;
    m_currentBarSpreadSum = 0.0;
    m_currentBarMaximumSpread = 0.0;
    m_currentBarSpreadSampleCount = 0;
    m_processedBarCount = 0;
    m_invalidBarCount = 0;
    m_pendingDroppedCount = 0;
    m_analysisStartTime = 0;
    m_analysisEndTime = 0;
    m_firstPrice = 0.0;
    m_lastPrice = 0.0;
    m_lastSessionIndex = -1;
    m_lastClosedBarPrice = 0.0;

    for (int i = 0; i < PB_GOLD_MAX_PENDING_OBSERVATIONS; i++)
      ZeroMemory(m_pending[i]);

    for (int session = 0; session < PB_GOLD_SESSION_COUNT; session++) {
      string sessionLabel = PbGoldSessionToString(
        (ENUM_PB_GOLD_SESSION)session);

      ResetStats(m_globalStats[session], sessionLabel);

      for (int period = 0; period < 3; period++)
        ResetStats(m_periodStats[period][session], sessionLabel);
    }
  }

  bool Initialize(
    const string symbol,
    const ENUM_TIMEFRAMES signalTimeframe,
    const ENUM_TIMEFRAMES contextTimeframe,
    const int contextAtrPeriod,
    const int contextAdxPeriod,
    const int breakoutLookbackBars,
    const int followThroughBars,
    const double followThroughAtrThreshold,
    const int europeStartHour,
    const int europeUsaStartHour,
    const int usaStartHour,
    const int rolloverStartHour,
    const int asiaStartHour) {

    if (contextAtrPeriod < 2 ||
      contextAdxPeriod < 2 ||
      breakoutLookbackBars < 2 ||
      followThroughBars < 1 ||
      followThroughBars >= PB_GOLD_MAX_PENDING_OBSERVATIONS ||
      followThroughAtrThreshold <= 0.0 ||
      europeStartHour < 0 ||
      europeStartHour >= europeUsaStartHour ||
      europeUsaStartHour >= usaStartHour ||
      usaStartHour >= rolloverStartHour ||
      rolloverStartHour >= asiaStartHour ||
      asiaStartHour > 23) {

      PrintFormat(
        "[%s][ERROR] Paramètres du profileur invalides.",
        __FILE__);

      return false;
    }

    m_symbol = symbol;
    m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

    if (m_point <= 0.0)
      return false;

    m_signalTimeframe = signalTimeframe;
    m_contextTimeframe = contextTimeframe;
    m_signalPeriodSeconds = PeriodSeconds(m_signalTimeframe);

    if (m_signalPeriodSeconds <= 0) {
      PrintFormat(
        "[%s][ERROR] Durée de l'unité de temps signal invalide : %s",
        __FILE__,
        EnumToString(m_signalTimeframe));

      return false;
    }

    m_contextAtrPeriod = contextAtrPeriod;
    m_contextAdxPeriod = contextAdxPeriod;
    m_breakoutLookbackBars = breakoutLookbackBars;
    m_followThroughBars = followThroughBars;
    m_followThroughAtrThreshold = followThroughAtrThreshold;
    m_europeStartHour = europeStartHour;
    m_europeUsaStartHour = europeUsaStartHour;
    m_usaStartHour = usaStartHour;
    m_rolloverStartHour = rolloverStartHour;
    m_asiaStartHour = asiaStartHour;

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

    m_contextAdxHandle = iADX(
      m_symbol,
      m_contextTimeframe,
      m_contextAdxPeriod);

    if (m_contextAdxHandle == INVALID_HANDLE) {
      PrintFormat(
        "[%s][ERROR] Création ADX contexte impossible. Erreur=%d",
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

    if (m_contextAdxHandle != INVALID_HANDLE) {
      IndicatorRelease(m_contextAdxHandle);
      m_contextAdxHandle = INVALID_HANDLE;
    }
  }

  bool ProcessTick(
    const MqlTick &tick) {

    // Les périodes MT5 standard sont alignées sur leur durée en secondes.
    // Ce calcul local remplace un coûteux iTime() exécuté à chaque tick.
    datetime signalBarTime = (datetime)(
      ((long)tick.time / m_signalPeriodSeconds) *
      m_signalPeriodSeconds);

    if (signalBarTime <= 0)
      return false;

    if (m_currentSignalBarTime == 0) {
      m_currentSignalBarTime = signalBarTime;
      AccumulateSpread(tick);
      return true;
    }

    if (signalBarTime != m_currentSignalBarTime) {
      double averageSpreadPoints =
        m_currentBarSpreadSampleCount > 0
        ? m_currentBarSpreadSum /
          (double)m_currentBarSpreadSampleCount
        : -1.0;

      ProcessClosedBar(
        averageSpreadPoints,
        m_currentBarMaximumSpread);

      m_currentSignalBarTime = signalBarTime;
      m_currentBarSpreadSum = 0.0;
      m_currentBarMaximumSpread = 0.0;
      m_currentBarSpreadSampleCount = 0;

      AccumulateSpread(tick);
      return true;
    }

    AccumulateSpread(tick);
    return false;
  }

  string BuildStatusText(
    const datetime currentTime) const {

    ENUM_PB_GOLD_SESSION currentSession =
      ClassifySession(currentTime);

    int sessionIndex = (int)currentSession;
    double currentAverageSpread =
      m_currentBarSpreadSampleCount > 0
      ? m_currentBarSpreadSum /
        (double)m_currentBarSpreadSampleCount
      : 0.0;

    return StringFormat(
      "PROFILAGE GOLD — AUCUN TRADING\n"
      "Session serveur : %s | Signal : %s | Contexte : %s\n"
      "Bougies traitées : %I64d | Bougies session : %I64d\n"
      "Spread courant moyen : %.2f points | Maximum : %.1f points\n"
      "Cassure : %d bougies | Prolongement : %d bougies / %.2f ATR",
      PbGoldSessionToString(currentSession),
      EnumToString(m_signalTimeframe),
      EnumToString(m_contextTimeframe),
      m_processedBarCount,
      m_globalStats[sessionIndex].barCount,
      currentAverageSpread,
      m_currentBarMaximumSpread,
      m_breakoutLookbackBars,
      m_followThroughBars,
      m_followThroughAtrThreshold);
  }

  void PrintFinalReport(void) const {
    double priceVariationPercent =
      m_firstPrice > 0.0 && m_lastPrice > 0.0
      ? 100.0 * (m_lastPrice / m_firstPrice - 1.0)
      : 0.0;

    int activePendingCount = 0;

    for (int i = 0; i < PB_GOLD_MAX_PENDING_OBSERVATIONS; i++) {
      if (m_pending[i].isActive)
        activePendingCount++;
    }

    PrintFormat(
      "[%s][INFO] Résumé profileur [1/2] : "
      "Bougies traitées=%I64d | Invalides=%I64d | "
      "Début=%s | Fin=%s | Signal=%s | Contexte=%s | "
      "ATR=%d | ADX=%d",
      __FILE__,
      m_processedBarCount,
      m_invalidBarCount,
      TimeToString(m_analysisStartTime, TIME_DATE|TIME_MINUTES),
      TimeToString(m_analysisEndTime, TIME_DATE|TIME_MINUTES),
      EnumToString(m_signalTimeframe),
      EnumToString(m_contextTimeframe),
      m_contextAtrPeriod,
      m_contextAdxPeriod);

    PrintFormat(
      "[%s][INFO] Résumé profileur [2/2] : "
      "GOLD=%.*f -> %.*f | Variation=%.2f%% | "
      "Cassure=%d bougies | Prolongement=%d bougies | "
      "Seuil=%.2f ATR | Observations incomplètes=%d | "
      "Observations perdues=%I64d | Mode=ANALYSE_SANS_TRADING",
      __FILE__,
      m_digits,
      m_firstPrice,
      m_digits,
      m_lastPrice,
      priceVariationPercent,
      m_breakoutLookbackBars,
      m_followThroughBars,
      m_followThroughAtrThreshold,
      activePendingCount,
      m_pendingDroppedCount);

    for (int session = 0; session < PB_GOLD_SESSION_COUNT; session++)
      PrintStatsLine("GLOBAL", m_globalStats[session]);

    for (int period = 0; period < 3; period++) {
      for (int session = 0; session < PB_GOLD_SESSION_COUNT; session++) {
        PrintStatsLine(
          PeriodLabel(period),
          m_periodStats[period][session]);
      }
    }
  }
};

#endif

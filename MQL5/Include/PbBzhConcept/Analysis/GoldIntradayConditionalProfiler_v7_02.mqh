//+------------------------------------------------------------------+
//|          GoldIntradayConditionalProfiler_v7_02.mqh              |
//|  GOLD M15/H1 : étude conditionnelle sans aucune prise de trade  |
//+------------------------------------------------------------------+
#ifndef PB_BZH_GOLD_INTRADAY_CONDITIONAL_PROFILER_V7_02_MQH
#define PB_BZH_GOLD_INTRADAY_CONDITIONAL_PROFILER_V7_02_MQH

#define PB_V702_PERIOD_COUNT 4
#define PB_V702_DIRECTION_COUNT 2
#define PB_V702_HORIZON_COUNT 3
#define PB_V702_TREND_CLASS_COUNT 3
#define PB_V702_COMPRESSION_CLASS_COUNT 3
#define PB_V702_MAX_PENDING 64

enum ENUM_PB_V702_SESSION {
  PB_V702_SESSION_ASIA = 0,
  PB_V702_SESSION_EUROPE = 1,
  PB_V702_SESSION_EUROPE_USA = 2,
  PB_V702_SESSION_USA = 3,
  PB_V702_SESSION_ROLLOVER = 4,
  PB_V702_SESSION_COUNT = 5
};

enum ENUM_PB_V702_TREND_CLASS {
  PB_V702_TREND_ALIGNED = 0,
  PB_V702_TREND_OPPOSED = 1,
  PB_V702_TREND_NEUTRAL = 2
};

enum ENUM_PB_V702_COMPRESSION_CLASS {
  PB_V702_VOL_COMPRESSION = 0,
  PB_V702_VOL_NORMAL = 1,
  PB_V702_VOL_EXPANSION = 2
};

string PbV702SessionToString(const int sessionIndex) {
  switch (sessionIndex) {
    case PB_V702_SESSION_ASIA:
      return "ASIE";

    case PB_V702_SESSION_EUROPE:
      return "EUROPE";

    case PB_V702_SESSION_EUROPE_USA:
      return "EUROPE_USA";

    case PB_V702_SESSION_USA:
      return "USA";

    case PB_V702_SESSION_ROLLOVER:
      return "ROLLOVER";

    default:
      return "INCONNUE";
  }
}

string PbV702DirectionToString(const int directionIndex) {
  return directionIndex == 0 ? "LONG" : "SHORT";
}

string PbV702PeriodToString(const int periodIndex) {
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

string PbV702TrendClassToString(const int classIndex) {
  switch (classIndex) {
    case PB_V702_TREND_ALIGNED:
      return "ALIGNEE";

    case PB_V702_TREND_OPPOSED:
      return "OPPOSEE";

    case PB_V702_TREND_NEUTRAL:
      return "NEUTRE";

    default:
      return "INCONNUE";
  }
}

string PbV702CompressionClassToString(const int classIndex) {
  switch (classIndex) {
    case PB_V702_VOL_COMPRESSION:
      return "COMPRESSION";

    case PB_V702_VOL_NORMAL:
      return "NORMALE";

    case PB_V702_VOL_EXPANSION:
      return "EXPANSION";

    default:
      return "INCONNUE";
  }
}

struct SPbV702OutcomeStats {
  long sampleCount[PB_V702_HORIZON_COUNT];
  long successCount[PB_V702_HORIZON_COUNT];
  double sumMfeAtr[PB_V702_HORIZON_COUNT];
  double sumMaeAtr[PB_V702_HORIZON_COUNT];
};

struct SPbV702Observation {
  bool isActive;
  int directionIndex;
  int sessionIndex;
  int periodIndex;
  int hourIndex;
  int trendClassIndex;
  int compressionClassIndex;
  datetime signalTime;
  double entryPrice;
  double highestPrice;
  double lowestPrice;
  double atrAtSignal;
  int elapsedBars;
};

class CGoldIntradayConditionalProfiler {
private:
  string m_symbol;
  ENUM_TIMEFRAMES m_signalTimeframe;
  ENUM_TIMEFRAMES m_contextTimeframe;
  int m_signalPeriodSeconds;

  int m_contextAtrPeriod;
  int m_contextTrendEmaPeriod;
  double m_trendNeutralAtrBand;
  int m_breakoutLookbackBars;
  double m_compressionMaximumAtr;
  double m_expansionMinimumAtr;
  double m_successThresholdAtr;

  int m_europeStartHour;
  int m_europeUsaStartHour;
  int m_usaStartHour;
  int m_rolloverStartHour;
  int m_asiaStartHour;
  int m_hourlyReportStartHour;
  int m_hourlyReportEndHour;

  int m_contextAtrHandle;
  int m_contextEmaHandle;
  datetime m_currentSignalBarTime;

  int m_horizonBars[PB_V702_HORIZON_COUNT];
  SPbV702Observation m_pending[PB_V702_MAX_PENDING];

  SPbV702OutcomeStats
    m_sessionStats[PB_V702_PERIOD_COUNT]
      [PB_V702_SESSION_COUNT]
      [PB_V702_DIRECTION_COUNT];

  SPbV702OutcomeStats
    m_hourStats[PB_V702_PERIOD_COUNT][24]
      [PB_V702_DIRECTION_COUNT];

  SPbV702OutcomeStats
    m_trendStats[PB_V702_PERIOD_COUNT]
      [PB_V702_TREND_CLASS_COUNT]
      [PB_V702_DIRECTION_COUNT];

  SPbV702OutcomeStats
    m_compressionStats[PB_V702_PERIOD_COUNT]
      [PB_V702_COMPRESSION_CLASS_COUNT]
      [PB_V702_DIRECTION_COUNT];

  long m_processedBarCount;
  long m_invalidBarCount;
  long m_confirmedLongCount;
  long m_confirmedShortCount;
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

  int SessionIndex(const datetime value) const {
    int hour = HourIndex(value);

    if (hour >= m_asiaStartHour || hour < m_europeStartHour)
      return PB_V702_SESSION_ASIA;

    if (hour < m_europeUsaStartHour)
      return PB_V702_SESSION_EUROPE;

    if (hour < m_usaStartHour)
      return PB_V702_SESSION_EUROPE_USA;

    if (hour < m_rolloverStartHour)
      return PB_V702_SESSION_USA;

    return PB_V702_SESSION_ROLLOVER;
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

  int TrendClass(
    const int signalDirection,
    const int trendDirection) const {

    if (trendDirection == 0)
      return PB_V702_TREND_NEUTRAL;

    if (signalDirection == trendDirection)
      return PB_V702_TREND_ALIGNED;

    return PB_V702_TREND_OPPOSED;
  }

  int CompressionClass(
    const double priorRange,
    const double atrPrice) const {

    double ratio = priorRange / atrPrice;

    if (ratio < m_compressionMaximumAtr)
      return PB_V702_VOL_COMPRESSION;

    if (ratio > m_expansionMinimumAtr)
      return PB_V702_VOL_EXPANSION;

    return PB_V702_VOL_NORMAL;
  }

  void UpdateStats(
    SPbV702OutcomeStats &stats,
    const int horizonIndex,
    const double mfeAtr,
    const double maeAtr) {

    stats.sampleCount[horizonIndex]++;
    stats.sumMfeAtr[horizonIndex] += mfeAtr;
    stats.sumMaeAtr[horizonIndex] += maeAtr;

    if (mfeAtr >= m_successThresholdAtr)
      stats.successCount[horizonIndex]++;
  }

  void RecordOutcome(
    const SPbV702Observation &observation,
    const int horizonIndex,
    const double mfeAtr,
    const double maeAtr) {

    int periodSlots[2];
    periodSlots[0] = 0;
    periodSlots[1] = observation.periodIndex;

    for (int slot = 0; slot < 2; slot++) {
      int periodIndex = periodSlots[slot];

      UpdateStats(
        m_sessionStats[periodIndex]
          [observation.sessionIndex]
          [observation.directionIndex],
        horizonIndex,
        mfeAtr,
        maeAtr);

      UpdateStats(
        m_hourStats[periodIndex]
          [observation.hourIndex]
          [observation.directionIndex],
        horizonIndex,
        mfeAtr,
        maeAtr);

      UpdateStats(
        m_trendStats[periodIndex]
          [observation.trendClassIndex]
          [observation.directionIndex],
        horizonIndex,
        mfeAtr,
        maeAtr);

      UpdateStats(
        m_compressionStats[periodIndex]
          [observation.compressionClassIndex]
          [observation.directionIndex],
        horizonIndex,
        mfeAtr,
        maeAtr);
    }
  }

  void FinalizeHorizon(
    const SPbV702Observation &observation,
    const int horizonIndex) {

    double mfePrice = observation.directionIndex == 0
      ? observation.highestPrice - observation.entryPrice
      : observation.entryPrice - observation.lowestPrice;

    double maePrice = observation.directionIndex == 0
      ? observation.entryPrice - observation.lowestPrice
      : observation.highestPrice - observation.entryPrice;

    double mfeAtr = MathMax(0.0, mfePrice) / observation.atrAtSignal;
    double maeAtr = MathMax(0.0, maePrice) / observation.atrAtSignal;

    RecordOutcome(observation, horizonIndex, mfeAtr, maeAtr);
  }

  void UpdatePending(const MqlRates &closedBar) {
    for (int i = 0; i < PB_V702_MAX_PENDING; i++) {
      if (!m_pending[i].isActive)
        continue;

      if (closedBar.high > m_pending[i].highestPrice)
        m_pending[i].highestPrice = closedBar.high;

      if (closedBar.low < m_pending[i].lowestPrice)
        m_pending[i].lowestPrice = closedBar.low;

      m_pending[i].elapsedBars++;

      for (int horizon = 0; horizon < PB_V702_HORIZON_COUNT; horizon++) {
        if (m_pending[i].elapsedBars == m_horizonBars[horizon])
          FinalizeHorizon(m_pending[i], horizon);
      }

      if (m_pending[i].elapsedBars >=
        m_horizonBars[PB_V702_HORIZON_COUNT - 1]) {

        ZeroMemory(m_pending[i]);
      }
    }
  }

  void AddObservation(
    const MqlRates &signalBar,
    const int signalDirection,
    const int sessionIndex,
    const int periodIndex,
    const int hourIndex,
    const int trendClassIndex,
    const int compressionClassIndex,
    const double atrPrice) {

    for (int i = 0; i < PB_V702_MAX_PENDING; i++) {
      if (m_pending[i].isActive)
        continue;

      ZeroMemory(m_pending[i]);
      m_pending[i].isActive = true;
      m_pending[i].directionIndex = signalDirection > 0 ? 0 : 1;
      m_pending[i].sessionIndex = sessionIndex;
      m_pending[i].periodIndex = periodIndex;
      m_pending[i].hourIndex = hourIndex;
      m_pending[i].trendClassIndex = trendClassIndex;
      m_pending[i].compressionClassIndex = compressionClassIndex;
      m_pending[i].signalTime = signalBar.time;
      m_pending[i].entryPrice = signalBar.close;
      m_pending[i].highestPrice = signalBar.close;
      m_pending[i].lowestPrice = signalBar.close;
      m_pending[i].atrAtSignal = atrPrice;
      m_pending[i].elapsedBars = 0;
      return;
    }

    m_pendingDroppedCount++;
  }

  bool ProcessClosedBar(void) {
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
    UpdatePending(closedBar);

    m_processedBarCount++;
    m_analysisEndTime = closedBar.time;

    if (m_analysisStartTime == 0)
      m_analysisStartTime = closedBar.time;

    double priorHigh = bars[1].high;
    double priorLow = bars[1].low;

    for (int i = 2; i < requiredBars; i++) {
      if (bars[i].high > priorHigh)
        priorHigh = bars[i].high;

      if (bars[i].low < priorLow)
        priorLow = bars[i].low;
    }

    int signalDirection = 0;

    if (closedBar.close > priorHigh)
      signalDirection = 1;
    else if (closedBar.close < priorLow)
      signalDirection = -1;

    if (signalDirection == 0)
      return true;

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

    int trendClassIndex = TrendClass(
      signalDirection,
      trendDirection);

    int compressionClassIndex = CompressionClass(
      priorHigh - priorLow,
      atrPrice);

    int sessionIndex = SessionIndex(closedBar.time);
    int periodIndex = CalendarPeriodIndex(closedBar.time);
    int hourIndex = HourIndex(closedBar.time);

    if (signalDirection > 0)
      m_confirmedLongCount++;
    else
      m_confirmedShortCount++;

    AddObservation(
      closedBar,
      signalDirection,
      sessionIndex,
      periodIndex,
      hourIndex,
      trendClassIndex,
      compressionClassIndex,
      atrPrice);

    return true;
  }

  string HorizonText(
    const SPbV702OutcomeStats &stats,
    const int horizonIndex) const {

    long samples = stats.sampleCount[horizonIndex];
    double successRate = samples > 0
      ? 100.0 * (double)stats.successCount[horizonIndex] /
        (double)samples
      : 0.0;

    double averageMfe = samples > 0
      ? stats.sumMfeAtr[horizonIndex] / (double)samples
      : 0.0;

    double averageMae = samples > 0
      ? stats.sumMaeAtr[horizonIndex] / (double)samples
      : 0.0;

    return StringFormat(
      "%dh:N=%I64d Succès=%.2f%% MFE/MAE=%.3f/%.3f ATR",
      m_horizonBars[horizonIndex] / 4,
      samples,
      successRate,
      averageMfe,
      averageMae);
  }

  void PrintOutcomeLine(
    const string dimension,
    const string value,
    const string period,
    const int directionIndex,
    const SPbV702OutcomeStats &stats) const {

    PrintFormat(
      "[%s][INFO] Analyse conditionnelle [%s][%s][%s][%s] : "
      "%s | %s | %s",
      __FILE__,
      period,
      dimension,
      value,
      PbV702DirectionToString(directionIndex),
      HorizonText(stats, 0),
      HorizonText(stats, 1),
      HorizonText(stats, 2));
  }

public:
  CGoldIntradayConditionalProfiler(void) {
    m_symbol = "";
    m_signalTimeframe = PERIOD_M15;
    m_contextTimeframe = PERIOD_H1;
    m_signalPeriodSeconds = 0;
    m_contextAtrPeriod = 14;
    m_contextTrendEmaPeriod = 50;
    m_trendNeutralAtrBand = 0.10;
    m_breakoutLookbackBars = 4;
    m_compressionMaximumAtr = 0.75;
    m_expansionMinimumAtr = 1.25;
    m_successThresholdAtr = 0.50;
    m_europeStartHour = 7;
    m_europeUsaStartHour = 13;
    m_usaStartHour = 17;
    m_rolloverStartHour = 21;
    m_asiaStartHour = 22;
    m_hourlyReportStartHour = 7;
    m_hourlyReportEndHour = 21;
    m_contextAtrHandle = INVALID_HANDLE;
    m_contextEmaHandle = INVALID_HANDLE;
    m_currentSignalBarTime = 0;
    m_horizonBars[0] = 4;
    m_horizonBars[1] = 8;
    m_horizonBars[2] = 16;
    m_processedBarCount = 0;
    m_invalidBarCount = 0;
    m_confirmedLongCount = 0;
    m_confirmedShortCount = 0;
    m_contextUnavailableCount = 0;
    m_pendingDroppedCount = 0;
    m_analysisStartTime = 0;
    m_analysisEndTime = 0;

    ZeroMemory(m_pending);
    ZeroMemory(m_sessionStats);
    ZeroMemory(m_hourStats);
    ZeroMemory(m_trendStats);
    ZeroMemory(m_compressionStats);
  }

  bool Initialize(
    const string symbol,
    const ENUM_TIMEFRAMES signalTimeframe,
    const ENUM_TIMEFRAMES contextTimeframe,
    const int contextAtrPeriod,
    const int contextTrendEmaPeriod,
    const double trendNeutralAtrBand,
    const int breakoutLookbackBars,
    const double compressionMaximumAtr,
    const double expansionMinimumAtr,
    const double successThresholdAtr,
    const int europeStartHour,
    const int europeUsaStartHour,
    const int usaStartHour,
    const int rolloverStartHour,
    const int asiaStartHour,
    const int hourlyReportStartHour,
    const int hourlyReportEndHour) {

    if (contextAtrPeriod < 2 ||
      contextTrendEmaPeriod < 2 ||
      trendNeutralAtrBand < 0.0 ||
      breakoutLookbackBars < 2 ||
      compressionMaximumAtr <= 0.0 ||
      expansionMinimumAtr <= compressionMaximumAtr ||
      successThresholdAtr <= 0.0 ||
      europeStartHour < 0 ||
      europeStartHour >= europeUsaStartHour ||
      europeUsaStartHour >= usaStartHour ||
      usaStartHour >= rolloverStartHour ||
      rolloverStartHour >= asiaStartHour ||
      asiaStartHour > 23 ||
      hourlyReportStartHour < 0 ||
      hourlyReportStartHour > 23 ||
      hourlyReportEndHour <= hourlyReportStartHour ||
      hourlyReportEndHour > 24) {

      PrintFormat(
        "[%s][ERROR] Paramètres du profileur conditionnel invalides.",
        __FILE__);

      return false;
    }

    if (signalTimeframe != PERIOD_M15 ||
      contextTimeframe != PERIOD_H1) {

      PrintFormat(
        "[%s][ERROR] La v7.02 exige Signal=M15 et Contexte=H1.",
        __FILE__);

      return false;
    }

    m_symbol = symbol;
    m_signalTimeframe = signalTimeframe;
    m_contextTimeframe = contextTimeframe;
    m_signalPeriodSeconds = PeriodSeconds(m_signalTimeframe);
    m_contextAtrPeriod = contextAtrPeriod;
    m_contextTrendEmaPeriod = contextTrendEmaPeriod;
    m_trendNeutralAtrBand = trendNeutralAtrBand;
    m_breakoutLookbackBars = breakoutLookbackBars;
    m_compressionMaximumAtr = compressionMaximumAtr;
    m_expansionMinimumAtr = expansionMinimumAtr;
    m_successThresholdAtr = successThresholdAtr;
    m_europeStartHour = europeStartHour;
    m_europeUsaStartHour = europeUsaStartHour;
    m_usaStartHour = usaStartHour;
    m_rolloverStartHour = rolloverStartHour;
    m_asiaStartHour = asiaStartHour;
    m_hourlyReportStartHour = hourlyReportStartHour;
    m_hourlyReportEndHour = hourlyReportEndHour;

    if (m_signalPeriodSeconds <= 0)
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
    datetime signalBarTime = (datetime)(
      ((long)tick.time / m_signalPeriodSeconds) *
      m_signalPeriodSeconds);

    if (signalBarTime <= 0)
      return false;

    if (m_currentSignalBarTime == 0) {
      m_currentSignalBarTime = signalBarTime;
      return true;
    }

    if (signalBarTime == m_currentSignalBarTime)
      return false;

    ProcessClosedBar();
    m_currentSignalBarTime = signalBarTime;
    return true;
  }

  string BuildStatusText(const datetime currentTime) const {
    int activeObservations = 0;

    for (int i = 0; i < PB_V702_MAX_PENDING; i++) {
      if (m_pending[i].isActive)
        activeObservations++;
    }

    return StringFormat(
      "PROFILAGE CONDITIONNEL GOLD — AUCUN TRADING\n"
      "Session : %s | Heure serveur : %02d h\n"
      "Bougies : %I64d | Cassures LONG/SHORT : %I64d/%I64d\n"
      "Observations actives : %d | Horizons : 1 h / 2 h / 4 h",
      PbV702SessionToString(SessionIndex(currentTime)),
      HourIndex(currentTime),
      m_processedBarCount,
      m_confirmedLongCount,
      m_confirmedShortCount,
      activeObservations);
  }

  void PrintFinalReport(void) const {
    int activeObservations = 0;

    for (int i = 0; i < PB_V702_MAX_PENDING; i++) {
      if (m_pending[i].isActive)
        activeObservations++;
    }

    PrintFormat(
      "[%s][INFO] Résumé conditionnel [1/2] : "
      "Bougies=%I64d | Invalides=%I64d | Début=%s | Fin=%s | "
      "Cassures LONG=%I64d | Cassures SHORT=%I64d | "
      "Contexte indisponible=%I64d | Incomplètes=%d | Perdues=%I64d",
      __FILE__,
      m_processedBarCount,
      m_invalidBarCount,
      TimeToString(m_analysisStartTime, TIME_DATE|TIME_MINUTES),
      TimeToString(m_analysisEndTime, TIME_DATE|TIME_MINUTES),
      m_confirmedLongCount,
      m_confirmedShortCount,
      m_contextUnavailableCount,
      activeObservations,
      m_pendingDroppedCount);

    PrintFormat(
      "[%s][INFO] Résumé conditionnel [2/2] : "
      "Signal=%s | Contexte=%s | ATR=%d | EMA=%d | "
      "Bande neutre=%.2f ATR | Cassure=%d bougies | "
      "Compression<%.2f ATR | Expansion>%.2f ATR | "
      "Succès>=%.2f ATR | Horizons=1h/2h/4h | "
      "Mode=ANALYSE_SANS_TRADING",
      __FILE__,
      EnumToString(m_signalTimeframe),
      EnumToString(m_contextTimeframe),
      m_contextAtrPeriod,
      m_contextTrendEmaPeriod,
      m_trendNeutralAtrBand,
      m_breakoutLookbackBars,
      m_compressionMaximumAtr,
      m_expansionMinimumAtr,
      m_successThresholdAtr);

    for (int session = 0; session < PB_V702_SESSION_COUNT; session++) {
      for (int direction = 0;
        direction < PB_V702_DIRECTION_COUNT;
        direction++) {

        PrintOutcomeLine(
          "SESSION",
          PbV702SessionToString(session),
          "GLOBAL",
          direction,
          m_sessionStats[0][session][direction]);
      }
    }

    for (int period = 1; period < PB_V702_PERIOD_COUNT; period++) {
      int selectedSessions[2];
      selectedSessions[0] = PB_V702_SESSION_EUROPE;
      selectedSessions[1] = PB_V702_SESSION_EUROPE_USA;

      for (int selected = 0; selected < 2; selected++) {
        int session = selectedSessions[selected];

        for (int direction = 0;
          direction < PB_V702_DIRECTION_COUNT;
          direction++) {

          PrintOutcomeLine(
            "SESSION",
            PbV702SessionToString(session),
            PbV702PeriodToString(period),
            direction,
            m_sessionStats[period][session][direction]);
        }
      }
    }

    for (int hour = m_hourlyReportStartHour;
      hour < m_hourlyReportEndHour;
      hour++) {

      string hourLabel = StringFormat("%02dh-%02dh", hour, hour + 1);

      for (int direction = 0;
        direction < PB_V702_DIRECTION_COUNT;
        direction++) {

        PrintOutcomeLine(
          "HEURE",
          hourLabel,
          "GLOBAL",
          direction,
          m_hourStats[0][hour][direction]);
      }
    }

    for (int trendClass = 0;
      trendClass < PB_V702_TREND_CLASS_COUNT;
      trendClass++) {

      for (int direction = 0;
        direction < PB_V702_DIRECTION_COUNT;
        direction++) {

        PrintOutcomeLine(
          "TENDANCE_H1",
          PbV702TrendClassToString(trendClass),
          "GLOBAL",
          direction,
          m_trendStats[0][trendClass][direction]);
      }
    }

    for (int compressionClass = 0;
      compressionClass < PB_V702_COMPRESSION_CLASS_COUNT;
      compressionClass++) {

      for (int direction = 0;
        direction < PB_V702_DIRECTION_COUNT;
        direction++) {

        PrintOutcomeLine(
          "VOLATILITE_PREALABLE",
          PbV702CompressionClassToString(compressionClass),
          "GLOBAL",
          direction,
          m_compressionStats[0][compressionClass][direction]);
      }
    }
  }
};

#endif

//+------------------------------------------------------------------+
//|          VirtualGoldSwingPositionManager.mqh                 |
//|  Momentum GOLD LONG, coûts et rapport de robustesse automatique |
//+------------------------------------------------------------------+
#ifndef PB_BZH_VIRTUAL_GOLD_SWING_POSITION_MANAGER_MQH
#define PB_BZH_VIRTUAL_GOLD_SWING_POSITION_MANAGER_MQH

enum ENUM_PB_V6_POSITION_DIRECTION {
  PB_V6_POSITION_FLAT = 0,
  PB_V6_POSITION_LONG = 1,
  PB_V6_POSITION_SHORT = -1
};

enum ENUM_PB_V6_EXIT_MODE {
  PB_V6_EXIT_MODE_SIGNAL_REVERSAL = 0
};

enum ENUM_PB_V6_EXIT_REASON {
  PB_V6_EXIT_NONE = 0,
  PB_V6_EXIT_STOP_INITIAL,
  PB_V6_EXIT_SIGNAL_REVERSAL,
  PB_V6_EXIT_TEST_END
};

string V6PositionDirectionToString(
  const ENUM_PB_V6_POSITION_DIRECTION direction) {

  switch (direction) {
    case PB_V6_POSITION_LONG:
      return "LONG";

    case PB_V6_POSITION_SHORT:
      return "SHORT";

    case PB_V6_POSITION_FLAT:
    default:
      return "FLAT";
  }
}

string V6ExitModeToString(
  const ENUM_PB_V6_EXIT_MODE mode) {
  return "SIGNAL_OR_TREND_REVERSAL";
}

string V6ExitReasonToString(
  const ENUM_PB_V6_EXIT_REASON reason) {

  switch (reason) {
    case PB_V6_EXIT_STOP_INITIAL:
      return "STOP_INITIAL";

    case PB_V6_EXIT_SIGNAL_REVERSAL:
      return "SIGNAL_OR_TREND_REVERSAL";

    case PB_V6_EXIT_TEST_END:
      return "TEST_END";

    case PB_V6_EXIT_NONE:
    default:
      return "NONE";
  }
}

struct SPbVirtualGoldSwingPosition {
  bool isOpen;
  ENUM_PB_V6_POSITION_DIRECTION direction;

  datetime signalBarTime;
  datetime entryTime;

  double entryPrice;
  double initialStopLossPrice;
  double stopLossPrice;
  double volumeLots;

  double entryAtrPrice;
  double entryAtrPoints;
  double initialStopDistancePrice;
  double initialStopDistancePoints;

  double openingCapital;
  double targetRiskMoney;
  double estimatedLossAtStop;
};

struct SPbV6PeriodStats {
  int key;
  string label;
  int closedCount;
  int winnerCount;
  int loserCount;
  int neutralCount;
  double gains;
  double losses;
  double net;
};

class CVirtualGoldSwingPositionManager {
private:
  string m_symbol;
  double m_point;
  int m_digits;
  string m_currency;

  double m_initialCapital;
  double m_virtualCapital;
  double m_riskPercent;
  double m_initialStopAtrMultiplier;
  double m_commissionPerLotRoundTurn;
  double m_annualLongSwapPercent;
  int m_swapRolloverHour;
  ENUM_PB_V6_EXIT_MODE m_exitMode;

  SPbVirtualGoldSwingPosition m_position;

  int m_openCount;
  int m_closedCount;
  int m_winnerCount;
  int m_loserCount;
  int m_neutralCount;
  int m_initialStopExitCount;
  int m_signalExitCount;
  int m_testEndExitCount;
  int m_longCount;
  int m_shortCount;

  double m_totalPoints;
  double m_totalMoney;
  double m_grossTotalMoney;
  double m_totalEstimatedCosts;
  double m_totalCommissionCosts;
  double m_totalSwapCosts;
  int m_totalRolloverUnits;
  double m_sumGains;
  double m_sumLosses;

  long m_totalDurationMinutes;
  long m_maxDurationMinutes;
  datetime m_maxDurationEntryTime;
  datetime m_maxDurationExitTime;

  bool m_hasClosedTrade;
  double m_bestTradeMoney;
  double m_worstTradeMoney;
  datetime m_bestTradeEntryTime;
  datetime m_bestTradeExitTime;
  datetime m_worstTradeEntryTime;
  datetime m_worstTradeExitTime;

  double m_topGainMoney[5];
  datetime m_topGainEntryTime[5];
  datetime m_topGainExitTime[5];

  SPbV6PeriodStats m_yearStats[32];
  int m_yearStatsCount;
  SPbV6PeriodStats m_periodStats[3];

  double m_capitalPeak;
  double m_maxClosedDrawdownMoney;
  double m_maxClosedDrawdownPercent;

  int CountRolloverUnits(
    const datetime entryTime,
    const datetime exitTime) const {

    if (exitTime <= entryTime)
      return 0;

    MqlDateTime parts;
    TimeToStruct(entryTime, parts);
    parts.hour = m_swapRolloverHour;
    parts.min = 0;
    parts.sec = 0;

    datetime rolloverTime = StructToTime(parts);

    if (rolloverTime <= entryTime)
      rolloverTime += 86400;

    int units = 0;

    while (rolloverTime <= exitTime) {
      MqlDateTime rolloverParts;
      TimeToStruct(rolloverTime, rolloverParts);

      if (rolloverParts.day_of_week == 3)
        units += 3;
      else if (rolloverParts.day_of_week == 1 ||
        rolloverParts.day_of_week == 2 ||
        rolloverParts.day_of_week == 4 ||
        rolloverParts.day_of_week == 5) {

        units++;
      }

      rolloverTime += 86400;
    }

    return units;
  }

  bool CalculateLongSwapCost(
    const double entryPrice,
    const double volumeLots,
    const datetime entryTime,
    const datetime exitTime,
    double &swapCostMoney,
    int &rolloverUnits) const {

    swapCostMoney = 0.0;
    rolloverUnits = CountRolloverUnits(entryTime, exitTime);

    if (m_annualLongSwapPercent <= 0.0 ||
      rolloverUnits <= 0) {

      return true;
    }

    double annualizedPriceDistance =
      entryPrice *
      m_annualLongSwapPercent / 100.0 *
      rolloverUnits / 360.0;

    double syntheticExitPrice =
      entryPrice - annualizedPriceDistance;

    double swapResultMoney = 0.0;

    if (syntheticExitPrice <= 0.0 ||
      !OrderCalcProfit(
        ORDER_TYPE_BUY,
        m_symbol,
        volumeLots,
        entryPrice,
        syntheticExitPrice,
        swapResultMoney)) {

      return false;
    }

    swapCostMoney = MathAbs(swapResultMoney);
    return true;
  }

  void ResetPeriodStats(
    SPbV6PeriodStats &stats,
    const int key,
    const string label) {

    stats.key = key;
    stats.label = label;
    stats.closedCount = 0;
    stats.winnerCount = 0;
    stats.loserCount = 0;
    stats.neutralCount = 0;
    stats.gains = 0.0;
    stats.losses = 0.0;
    stats.net = 0.0;
  }

  void UpdatePeriodStats(
    SPbV6PeriodStats &stats,
    const double resultMoney) {

    stats.closedCount++;
    stats.net += resultMoney;

    if (resultMoney > 0.005) {
      stats.winnerCount++;
      stats.gains += resultMoney;
    }
    else if (resultMoney < -0.005) {
      stats.loserCount++;
      stats.losses += MathAbs(resultMoney);
    }
    else {
      stats.neutralCount++;
    }
  }

  int FindOrCreateYearStats(
    const int year) {

    for (int i = 0; i < m_yearStatsCount; i++) {
      if (m_yearStats[i].key == year)
        return i;
    }

    if (m_yearStatsCount >= 32)
      return -1;

    int index = m_yearStatsCount;
    m_yearStatsCount++;

    ResetPeriodStats(
      m_yearStats[index],
      year,
      IntegerToString(year));

    return index;
  }

  void RecordChronologicalStats(
    const datetime exitTime,
    const double resultMoney) {

    MqlDateTime exitParts;
    TimeToStruct(exitTime, exitParts);

    int yearIndex = FindOrCreateYearStats(exitParts.year);

    if (yearIndex >= 0)
      UpdatePeriodStats(m_yearStats[yearIndex], resultMoney);

    int periodIndex = -1;

    if (exitParts.year >= 2018 && exitParts.year <= 2020)
      periodIndex = 0;
    else if (exitParts.year >= 2021 && exitParts.year <= 2023)
      periodIndex = 1;
    else if (exitParts.year >= 2024)
      periodIndex = 2;

    if (periodIndex >= 0)
      UpdatePeriodStats(m_periodStats[periodIndex], resultMoney);
  }

  void RecordTradeExtremes(
    const double resultMoney,
    const datetime entryTime,
    const datetime exitTime,
    const long durationMinutes) {

    if (!m_hasClosedTrade || resultMoney > m_bestTradeMoney) {
      m_bestTradeMoney = resultMoney;
      m_bestTradeEntryTime = entryTime;
      m_bestTradeExitTime = exitTime;
    }

    if (!m_hasClosedTrade || resultMoney < m_worstTradeMoney) {
      m_worstTradeMoney = resultMoney;
      m_worstTradeEntryTime = entryTime;
      m_worstTradeExitTime = exitTime;
    }

    m_hasClosedTrade = true;

    if (durationMinutes > m_maxDurationMinutes) {
      m_maxDurationMinutes = durationMinutes;
      m_maxDurationEntryTime = entryTime;
      m_maxDurationExitTime = exitTime;
    }

    if (resultMoney <= 0.0)
      return;

    for (int i = 0; i < 5; i++) {
      if (resultMoney <= m_topGainMoney[i])
        continue;

      for (int j = 4; j > i; j--) {
        m_topGainMoney[j] = m_topGainMoney[j - 1];
        m_topGainEntryTime[j] = m_topGainEntryTime[j - 1];
        m_topGainExitTime[j] = m_topGainExitTime[j - 1];
      }

      m_topGainMoney[i] = resultMoney;
      m_topGainEntryTime[i] = entryTime;
      m_topGainExitTime[i] = exitTime;
      break;
    }
  }

  int VolumeDigits(
    const double step) const {

    int digits = 0;
    double scaledStep = step;

    while (digits < 8 &&
      MathAbs(scaledStep - MathRound(scaledStep)) > 1e-8) {

      scaledStep *= 10.0;
      digits++;
    }

    return digits;
  }

  void PrintPeriodStatsLine(
    const string category,
    const SPbV6PeriodStats &stats) const {

    double profitFactor =
      stats.losses > 0.0
      ? stats.gains / stats.losses
      : (stats.gains > 0.0 ? 999.0 : 0.0);

    double expectancy =
      stats.closedCount > 0
      ? stats.net / stats.closedCount
      : 0.0;

    double successRate =
      stats.closedCount > 0
      ? 100.0 * stats.winnerCount / stats.closedCount
      : 0.0;

    PrintFormat(
      "[%s][INFO] Analyse %s : %s | Trades=%d | "
      "Gagnants=%d | Perdants=%d | Réussite=%.2f%% | "
      "Gains=%.2f %s | Pertes=%.2f %s | Net=%.2f %s | "
      "PF=%.2f | Espérance=%.2f %s",
      __FILE__,
      category,
      stats.label,
      stats.closedCount,
      stats.winnerCount,
      stats.loserCount,
      successRate,
      stats.gains,
      m_currency,
      stats.losses,
      m_currency,
      stats.net,
      m_currency,
      profitFactor,
      expectancy,
      m_currency);
  }

  bool CalculateVolumeByRisk(
    const ENUM_PB_V6_POSITION_DIRECTION direction,
    const double entryPrice,
    const double stopLossPrice,
    const double targetRiskMoney,
    double &volumeLots,
    double &estimatedLossAtStop) const {

    volumeLots = 0.0;
    estimatedLossAtStop = 0.0;

    ENUM_ORDER_TYPE orderType =
      direction == PB_V6_POSITION_LONG
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

    double oneLotProfit = 0.0;

    if (!OrderCalcProfit(
      orderType,
      m_symbol,
      1.0,
      entryPrice,
      stopLossPrice,
      oneLotProfit)) {

      PrintFormat(
        "[%s][ERROR] "
        "OrderCalcProfit impossible pour le volume. Erreur=%d",
        __FILE__,
        GetLastError());

      return false;
    }

    double oneLotLoss = MathAbs(oneLotProfit);

    if (oneLotLoss <= 0.0 || targetRiskMoney <= 0.0)
      return false;

    double volumeMin = SymbolInfoDouble(
      m_symbol,
      SYMBOL_VOLUME_MIN);

    double volumeMax = SymbolInfoDouble(
      m_symbol,
      SYMBOL_VOLUME_MAX);

    double volumeStep = SymbolInfoDouble(
      m_symbol,
      SYMBOL_VOLUME_STEP);

    if (volumeMin <= 0.0 ||
      volumeMax <= 0.0 ||
      volumeStep <= 0.0) {

      PrintFormat(
        "[%s][ERROR] Propriétés de volume invalides.",
        __FILE__);

      return false;
    }

    double rawVolume = targetRiskMoney / oneLotLoss;

    double normalizedVolume =
      MathFloor((rawVolume + 1e-12) / volumeStep) *
      volumeStep;

    normalizedVolume = MathMin(
      normalizedVolume,
      volumeMax);

    // Nous ne forçons pas le volume minimal : cela pourrait faire
    // dépasser le risque demandé sur un symbole très volatil.
    if (normalizedVolume < volumeMin)
      return false;

    normalizedVolume = NormalizeDouble(
      normalizedVolume,
      VolumeDigits(volumeStep));

    double normalizedProfit = 0.0;

    if (!OrderCalcProfit(
      orderType,
      m_symbol,
      normalizedVolume,
      entryPrice,
      stopLossPrice,
      normalizedProfit)) {

      return false;
    }

    volumeLots = normalizedVolume;
    estimatedLossAtStop = MathAbs(normalizedProfit);
    return true;
  }

  bool ClosePosition(
    const double exitPrice,
    const datetime exitTime,
    const ENUM_PB_V6_EXIT_REASON reason) {

    if (!m_position.isOpen || exitPrice <= 0.0)
      return false;

    ENUM_ORDER_TYPE orderType =
      m_position.direction == PB_V6_POSITION_LONG
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

    double grossResultMoney = 0.0;

    if (!OrderCalcProfit(
      orderType,
      m_symbol,
      m_position.volumeLots,
      m_position.entryPrice,
      exitPrice,
      grossResultMoney)) {

      PrintFormat(
        "[%s][ERROR] "
        "Calcul du résultat impossible. Erreur=%d",
        __FILE__,
        GetLastError());

      return false;
    }

    double resultPoints =
      m_position.direction == PB_V6_POSITION_LONG
      ? (exitPrice - m_position.entryPrice) / m_point
      : (m_position.entryPrice - exitPrice) / m_point;

    long durationMinutes = (long)MathMax(
      0.0,
      (double)(exitTime - m_position.entryTime) / 60.0);

    double commissionCost =
      m_position.volumeLots *
      m_commissionPerLotRoundTurn;

    double swapCost = 0.0;
    int rolloverUnits = 0;

    if (!CalculateLongSwapCost(
      m_position.entryPrice,
      m_position.volumeLots,
      m_position.entryTime,
      exitTime,
      swapCost,
      rolloverUnits)) {

      PrintFormat(
        "[%s][WARNING] Calcul du swap impossible. "
        "La clôture est enregistrée sans swap. Erreur=%d",
        __FILE__,
        GetLastError());

      swapCost = 0.0;
      rolloverUnits = 0;
    }

    double estimatedCosts =
      commissionCost + swapCost;

    double resultMoney =
      grossResultMoney - estimatedCosts;

    double resultR =
      m_position.estimatedLossAtStop > 0.0
      ? resultMoney / m_position.estimatedLossAtStop
      : 0.0;

    m_virtualCapital += resultMoney;
    m_closedCount++;
    m_totalPoints += resultPoints;
    m_totalMoney += resultMoney;
    m_grossTotalMoney += grossResultMoney;
    m_totalEstimatedCosts += estimatedCosts;
    m_totalCommissionCosts += commissionCost;
    m_totalSwapCosts += swapCost;
    m_totalRolloverUnits += rolloverUnits;
    m_totalDurationMinutes += durationMinutes;

    RecordChronologicalStats(
      exitTime,
      resultMoney);

    RecordTradeExtremes(
      resultMoney,
      m_position.entryTime,
      exitTime,
      durationMinutes);

    if (resultMoney > 0.005) {
      m_winnerCount++;
      m_sumGains += resultMoney;
    }
    else if (resultMoney < -0.005) {
      m_loserCount++;
      m_sumLosses += MathAbs(resultMoney);
    }
    else {
      m_neutralCount++;
    }

    if (reason == PB_V6_EXIT_STOP_INITIAL)
      m_initialStopExitCount++;
    else if (reason == PB_V6_EXIT_SIGNAL_REVERSAL)
      m_signalExitCount++;
    else if (reason == PB_V6_EXIT_TEST_END)
      m_testEndExitCount++;

    if (m_virtualCapital > m_capitalPeak)
      m_capitalPeak = m_virtualCapital;

    double drawdownMoney =
      m_capitalPeak - m_virtualCapital;

    double drawdownPercent =
      m_capitalPeak > 0.0
      ? 100.0 * drawdownMoney / m_capitalPeak
      : 0.0;

    if (drawdownMoney > m_maxClosedDrawdownMoney)
      m_maxClosedDrawdownMoney = drawdownMoney;

    if (drawdownPercent > m_maxClosedDrawdownPercent)
      m_maxClosedDrawdownPercent = drawdownPercent;

    PrintFormat(
      "[%s][INFO] "
      "FERMETURE | Direction=%s | Motif=%s | "
      "Entrée=%.*f | Sortie=%.*f | Volume=%.2f | "
      "Résultat=%.1f points | Brut=%.2f %s | "
      "Commission=%.2f %s | Swap=%.2f %s (%d unités) | "
      "Net=%.2f %s | %.2f R | "
      "Capital=%.2f %s | Durée=%d min",

      __FILE__,
      V6PositionDirectionToString(
        m_position.direction),

      V6ExitReasonToString(reason),
      m_digits,
      m_position.entryPrice,
      m_digits,
      exitPrice,
      m_position.volumeLots,
      resultPoints,
      grossResultMoney,
      m_currency,
      commissionCost,
      m_currency,
      swapCost,
      m_currency,
      rolloverUnits,
      resultMoney,
      m_currency,
      resultR,
      m_virtualCapital,
      m_currency,
      (int)durationMinutes);

    ZeroMemory(m_position);
    m_position.direction = PB_V6_POSITION_FLAT;
    return true;
  }

public:
  CVirtualGoldSwingPositionManager(void) {
    m_symbol = "";
    m_point = 0.0;
    m_digits = 0;
    m_currency = "";

    m_initialCapital = 10000.0;
    m_virtualCapital = 10000.0;
    m_riskPercent = 1.0;
    m_initialStopAtrMultiplier = 2.0;
    m_commissionPerLotRoundTurn = 0.0;
    m_annualLongSwapPercent = 0.0;
    m_swapRolloverHour = 21;
    m_exitMode = PB_V6_EXIT_MODE_SIGNAL_REVERSAL;

    ZeroMemory(m_position);
    m_position.direction = PB_V6_POSITION_FLAT;

    m_openCount = 0;
    m_closedCount = 0;
    m_winnerCount = 0;
    m_loserCount = 0;
    m_neutralCount = 0;
    m_initialStopExitCount = 0;
    m_signalExitCount = 0;
    m_testEndExitCount = 0;
    m_longCount = 0;
    m_shortCount = 0;

    m_totalPoints = 0.0;
    m_totalMoney = 0.0;
    m_grossTotalMoney = 0.0;
    m_totalEstimatedCosts = 0.0;
    m_totalCommissionCosts = 0.0;
    m_totalSwapCosts = 0.0;
    m_totalRolloverUnits = 0;
    m_sumGains = 0.0;
    m_sumLosses = 0.0;

    m_totalDurationMinutes = 0;
    m_maxDurationMinutes = 0;
    m_maxDurationEntryTime = 0;
    m_maxDurationExitTime = 0;
    m_hasClosedTrade = false;
    m_bestTradeMoney = 0.0;
    m_worstTradeMoney = 0.0;
    m_bestTradeEntryTime = 0;
    m_bestTradeExitTime = 0;
    m_worstTradeEntryTime = 0;
    m_worstTradeExitTime = 0;
    m_yearStatsCount = 0;

    ArrayInitialize(m_topGainMoney, 0.0);
    ArrayInitialize(m_topGainEntryTime, 0);
    ArrayInitialize(m_topGainExitTime, 0);

    ResetPeriodStats(m_periodStats[0], 0, "A 2018-2020");
    ResetPeriodStats(m_periodStats[1], 1, "B 2021-2023");
    ResetPeriodStats(m_periodStats[2], 2, "C 2024-fin");

    m_capitalPeak = 10000.0;
    m_maxClosedDrawdownMoney = 0.0;
    m_maxClosedDrawdownPercent = 0.0;
  }

  bool Initialize(
    const string symbol,
    const double initialCapital,
    const double riskPercent,
    const double initialStopAtrMultiplier,
    const double commissionPerLotRoundTurn,
    const double annualLongSwapPercent,
    const int swapRolloverHour) {

    if (initialCapital <= 0.0 ||
      riskPercent <= 0.0 ||
      initialStopAtrMultiplier <= 0.0 ||
      commissionPerLotRoundTurn < 0.0 ||
      annualLongSwapPercent < 0.0 ||
      swapRolloverHour < 0 ||
      swapRolloverHour > 23) {

      PrintFormat(
        "[%s][ERROR] Paramètres de simulation invalides.",
        __FILE__);

      return false;
    }

    m_symbol = symbol;
    m_point = SymbolInfoDouble(
      m_symbol,
      SYMBOL_POINT);

    m_digits = (int)SymbolInfoInteger(
      m_symbol,
      SYMBOL_DIGITS);

    m_currency = AccountInfoString(
      ACCOUNT_CURRENCY);

    if (m_currency == "")
      m_currency = "compte";

    if (m_point <= 0.0)
      return false;

    m_initialCapital = initialCapital;
    m_virtualCapital = initialCapital;
    m_riskPercent = riskPercent;
    m_initialStopAtrMultiplier = initialStopAtrMultiplier;
    m_commissionPerLotRoundTurn = commissionPerLotRoundTurn;
    m_annualLongSwapPercent = annualLongSwapPercent;
    m_swapRolloverHour = swapRolloverHour;
    m_exitMode = PB_V6_EXIT_MODE_SIGNAL_REVERSAL;

    ZeroMemory(m_position);
    m_position.direction = PB_V6_POSITION_FLAT;

    m_openCount = 0;
    m_closedCount = 0;
    m_winnerCount = 0;
    m_loserCount = 0;
    m_neutralCount = 0;
    m_initialStopExitCount = 0;
    m_signalExitCount = 0;
    m_testEndExitCount = 0;
    m_longCount = 0;
    m_shortCount = 0;

    m_totalPoints = 0.0;
    m_totalMoney = 0.0;
    m_grossTotalMoney = 0.0;
    m_totalEstimatedCosts = 0.0;
    m_totalCommissionCosts = 0.0;
    m_totalSwapCosts = 0.0;
    m_totalRolloverUnits = 0;
    m_sumGains = 0.0;
    m_sumLosses = 0.0;

    m_totalDurationMinutes = 0;
    m_maxDurationMinutes = 0;
    m_maxDurationEntryTime = 0;
    m_maxDurationExitTime = 0;
    m_hasClosedTrade = false;
    m_bestTradeMoney = 0.0;
    m_worstTradeMoney = 0.0;
    m_bestTradeEntryTime = 0;
    m_bestTradeExitTime = 0;
    m_worstTradeEntryTime = 0;
    m_worstTradeExitTime = 0;
    m_yearStatsCount = 0;

    ArrayInitialize(m_topGainMoney, 0.0);
    ArrayInitialize(m_topGainEntryTime, 0);
    ArrayInitialize(m_topGainExitTime, 0);

    for (int i = 0; i < 32; i++)
      ResetPeriodStats(m_yearStats[i], 0, "");

    ResetPeriodStats(m_periodStats[0], 0, "A 2018-2020");
    ResetPeriodStats(m_periodStats[1], 1, "B 2021-2023");
    ResetPeriodStats(m_periodStats[2], 2, "C 2024-fin");

    m_capitalPeak = initialCapital;
    m_maxClosedDrawdownMoney = 0.0;
    m_maxClosedDrawdownPercent = 0.0;

    return true;
  }

  bool IsOpen(void) const {
    return m_position.isOpen;
  }

  ENUM_PB_V6_POSITION_DIRECTION Direction(void) const {
    return m_position.direction;
  }

  double EntryPrice(void) const {
    return m_position.entryPrice;
  }

  double StopLossPrice(void) const {
    return m_position.stopLossPrice;
  }

  ENUM_PB_V6_EXIT_MODE ExitMode(void) const {
    return m_exitMode;
  }

  double VolumeLots(void) const {
    return m_position.volumeLots;
  }

  double VirtualCapital(void) const {
    return m_virtualCapital;
  }

  int ClosedCount(void) const {
    return m_closedCount;
  }

  bool OpenPosition(
    const ENUM_PB_V6_POSITION_DIRECTION direction,
    const datetime signalBarTime,
    const double atrPrice,
    const double atrPoints,
    const MqlTick &tick) {

    if (m_position.isOpen ||
      direction != PB_V6_POSITION_LONG) {

      return false;
    }

    double entryPrice =
      direction == PB_V6_POSITION_LONG
      ? tick.ask
      : tick.bid;

    if (entryPrice <= 0.0 || atrPrice <= 0.0 || atrPoints <= 0.0)
      return false;

    double stopDistancePrice =
      m_initialStopAtrMultiplier * atrPrice;

    double stopLossPrice =
      direction == PB_V6_POSITION_LONG
      ? entryPrice - stopDistancePrice
      : entryPrice + stopDistancePrice;

    stopLossPrice = NormalizeDouble(
      stopLossPrice,
      m_digits);

    double targetRiskMoney =
      m_virtualCapital * m_riskPercent / 100.0;

    double volumeLots = 0.0;
    double estimatedLossAtStop = 0.0;

    if (!CalculateVolumeByRisk(
      direction,
      entryPrice,
      stopLossPrice,
      targetRiskMoney,
      volumeLots,
      estimatedLossAtStop)) {

      PrintFormat(
        "[%s][WARNING] "
        "OUVERTURE REFUSÉE | Direction=%s | "
        "Capital=%.2f %s | Risque cible=%.2f %s | "
        "SL=%.1f points",
        __FILE__,
        V6PositionDirectionToString(direction),
        m_virtualCapital,
        m_currency,
        targetRiskMoney,
        m_currency,
        stopDistancePrice / m_point);

      return false;
    }

    ZeroMemory(m_position);
    m_position.isOpen = true;
    m_position.direction = direction;
    m_position.signalBarTime = signalBarTime;
    m_position.entryTime = (datetime)tick.time;
    m_position.entryPrice = entryPrice;
    m_position.initialStopLossPrice = stopLossPrice;
    m_position.stopLossPrice = stopLossPrice;
    m_position.volumeLots = volumeLots;
    m_position.entryAtrPrice = atrPrice;
    m_position.entryAtrPoints = atrPoints;
    m_position.initialStopDistancePrice = stopDistancePrice;
    m_position.initialStopDistancePoints =
      stopDistancePrice / m_point;
    m_position.openingCapital = m_virtualCapital;
    m_position.targetRiskMoney = targetRiskMoney;
    m_position.estimatedLossAtStop = estimatedLossAtStop;

    m_openCount++;

    if (direction == PB_V6_POSITION_LONG)
      m_longCount++;
    else
      m_shortCount++;

    PrintFormat(
      "[%s][INFO] "
      "OUVERTURE | Direction=%s | Signal=%s | "
      "Entrée=%.*f | SL=%.*f | Distance=%.1f points | "
      "ATR=%.1f points | Volume=%.2f | "
      "Risque cible=%.2f %s | Risque estimé=%.2f %s | "
      "Capital=%.2f %s",

      __FILE__,
      V6PositionDirectionToString(direction),
      TimeToString(
        signalBarTime,
        TIME_DATE|TIME_MINUTES),
      m_digits,
      entryPrice,
      m_digits,
      stopLossPrice,
      m_position.initialStopDistancePoints,
      atrPoints,
      volumeLots,
      targetRiskMoney,
      m_currency,
      estimatedLossAtStop,
      m_currency,
      m_virtualCapital,
      m_currency);

    return true;
  }

  bool ProcessTick(
    const MqlTick &tick) {

    if (!m_position.isOpen)
      return false;

    double executablePrice =
      m_position.direction == PB_V6_POSITION_LONG
      ? tick.bid
      : tick.ask;

    if (executablePrice <= 0.0)
      return false;

    bool stopReached =
      (
        m_position.direction == PB_V6_POSITION_LONG &&
        executablePrice <= m_position.stopLossPrice
      )
      ||
      (
        m_position.direction == PB_V6_POSITION_SHORT &&
        executablePrice >= m_position.stopLossPrice
      );

    if (!stopReached)
      return false;

    return ClosePosition(
      executablePrice,
      (datetime)tick.time,
      PB_V6_EXIT_STOP_INITIAL);
  }

  bool ProcessSignalExit(
    const ENUM_PB_V6_POSITION_DIRECTION signalDirection,
    const MqlTick &tick) {

    if (!m_position.isOpen)
      return false;

    bool signalReversed =
      signalDirection != PB_V6_POSITION_FLAT &&
      signalDirection != m_position.direction;

    if (!signalReversed)
      return false;

    double exitPrice =
      m_position.direction == PB_V6_POSITION_LONG
      ? tick.bid
      : tick.ask;

    return ClosePosition(
      exitPrice,
      (datetime)tick.time,
      PB_V6_EXIT_SIGNAL_REVERSAL);
  }

  bool CloseAtTestEnd(
    const MqlTick &tick) {

    if (!m_position.isOpen)
      return false;

    double exitPrice =
      m_position.direction == PB_V6_POSITION_LONG
      ? tick.bid
      : tick.ask;

    return ClosePosition(
      exitPrice,
      (datetime)tick.time,
      PB_V6_EXIT_TEST_END);
  }

  string BuildStatusText(void) const {
    if (!m_position.isOpen) {
      return StringFormat(
        "Position virtuelle : FLAT\n"
        "Capital virtuel : %.2f %s | Trades clôturés : %d",
        m_virtualCapital,
        m_currency,
        m_closedCount);
    }

    return StringFormat(
      "Position virtuelle : %s | Volume : %.2f lot(s)\n"
      "Entrée : %.*f | SL initial : %.*f | ATR entrée : %.1f points\n"
      "Capital virtuel : %.2f %s | Risque initial estimé : %.2f %s",

      V6PositionDirectionToString(
        m_position.direction),
      m_position.volumeLots,
      m_digits,
      m_position.entryPrice,
      m_digits,
      m_position.stopLossPrice,
      m_position.entryAtrPoints,
      m_virtualCapital,
      m_currency,
      m_position.estimatedLossAtStop,
      m_currency);
  }

  void PrintAutomaticAnalysis(
    const datetime analysisStartTime,
    const datetime analysisEndTime,
    const double firstGoldPrice,
    const double lastGoldPrice) const {

    double analysisMinutes =
      analysisEndTime > analysisStartTime
      ? (double)(analysisEndTime - analysisStartTime) / 60.0
      : 0.0;

    double exposurePercent =
      analysisMinutes > 0.0
      ? 100.0 * (double)m_totalDurationMinutes / analysisMinutes
      : 0.0;

    double averageDurationDays =
      m_closedCount > 0
      ? (double)m_totalDurationMinutes / 1440.0 / m_closedCount
      : 0.0;

    double maximumDurationDays =
      (double)m_maxDurationMinutes / 1440.0;

    double goldVariationPercent =
      firstGoldPrice > 0.0 && lastGoldPrice > 0.0
      ? 100.0 * (lastGoldPrice / firstGoldPrice - 1.0)
      : 0.0;

    double strategyReturnPercent =
      m_initialCapital > 0.0
      ? 100.0 * (m_virtualCapital / m_initialCapital - 1.0)
      : 0.0;

    double topFiveGains = 0.0;

    for (int i = 0; i < 5; i++)
      topFiveGains += m_topGainMoney[i];

    double topFiveContribution =
      m_sumGains > 0.0
      ? 100.0 * topFiveGains / m_sumGains
      : 0.0;

    PrintFormat(
      "[%s][INFO] Analyse avancée [1/4] : "
      "Temps exposé=%.2f%% | Durée moyenne=%.2f jours | "
      "Durée maximale=%.2f jours | Du=%s | Au=%s",
      __FILE__,
      exposurePercent,
      averageDurationDays,
      maximumDurationDays,
      TimeToString(m_maxDurationEntryTime, TIME_DATE),
      TimeToString(m_maxDurationExitTime, TIME_DATE));

    PrintFormat(
      "[%s][INFO] Analyse avancée [2/4] : "
      "Meilleur trade=%.2f %s (%s -> %s) | "
      "Pire trade=%.2f %s (%s -> %s) | "
      "Top 5 gains=%.2f %s (%.2f%% des gains)",
      __FILE__,
      m_bestTradeMoney,
      m_currency,
      TimeToString(m_bestTradeEntryTime, TIME_DATE),
      TimeToString(m_bestTradeExitTime, TIME_DATE),
      m_worstTradeMoney,
      m_currency,
      TimeToString(m_worstTradeEntryTime, TIME_DATE),
      TimeToString(m_worstTradeExitTime, TIME_DATE),
      topFiveGains,
      m_currency,
      topFiveContribution);

    PrintFormat(
      "[%s][INFO] Analyse avancée [3/4] : "
      "Référence GOLD=%.5f -> %.5f | Variation prix=%.2f%% | "
      "Rendement stratégie=%.2f%% | Comparaison non ajustée du risque",
      __FILE__,
      firstGoldPrice,
      lastGoldPrice,
      goldVariationPercent,
      strategyReturnPercent);

    PrintFormat(
      "[%s][INFO] Analyse avancée [4/4] : "
      "Résultat brut=%.2f %s | Coûts estimés=%.2f %s | "
      "Résultat net=%.2f %s | Commissions=%.2f %s | "
      "Swap=%.2f %s | Unités rollover=%d | "
      "Taux LONG=%.2f%% annuel | Rollover=%02dh",
      __FILE__,
      m_grossTotalMoney,
      m_currency,
      m_totalEstimatedCosts,
      m_currency,
      m_totalMoney,
      m_currency,
      m_totalCommissionCosts,
      m_currency,
      m_totalSwapCosts,
      m_currency,
      m_totalRolloverUnits,
      m_annualLongSwapPercent,
      m_swapRolloverHour);

    for (int i = 0; i < m_yearStatsCount; i++)
      PrintPeriodStatsLine("année de clôture", m_yearStats[i]);

    for (int i = 0; i < 3; i++)
      PrintPeriodStatsLine("période de clôture", m_periodStats[i]);
  }

  void PrintFinalSummary(void) const {
    double profitFactor =
      m_sumLosses > 0.0
      ? m_sumGains / m_sumLosses
      : (m_sumGains > 0.0 ? 999.0 : 0.0);

    double expectancy =
      m_closedCount > 0
      ? m_totalMoney / m_closedCount
      : 0.0;

    PrintFormat(
      "[%s][INFO] "
      "Résumé positions [1/3] : Ouvertures=%d | "
      "Clôturés=%d | LONG=%d | SHORT=%d | "
      "Gagnants=%d | Perdants=%d | Neutres=%d | "
      "Stop initial=%d | Inversion signal/tendance=%d | Fin test=%d",
      __FILE__,
      m_openCount,
      m_closedCount,
      m_longCount,
      m_shortCount,
      m_winnerCount,
      m_loserCount,
      m_neutralCount,
      m_initialStopExitCount,
      m_signalExitCount,
      m_testEndExitCount);

    PrintFormat(
      "[%s][INFO] "
      "Résumé performances [2/3] : Points=%.1f | "
      "Gains=%.2f %s | Pertes=%.2f %s | "
      "Net=%.2f %s | Profit factor=%.2f | "
      "Espérance=%.2f %s | "
      "Drawdown clôturé=%.2f %s (%.2f%%)",
      __FILE__,
      m_totalPoints,
      m_sumGains,
      m_currency,
      m_sumLosses,
      m_currency,
      m_totalMoney,
      m_currency,
      profitFactor,
      expectancy,
      m_currency,
      m_maxClosedDrawdownMoney,
      m_currency,
      m_maxClosedDrawdownPercent);

    PrintFormat(
      "[%s][INFO] "
      "Résumé capital [3/3] : Capital initial=%.2f %s | "
      "Capital final=%.2f %s | Résultat=%.2f %s | "
      "Risque=%.2f%% | SL initial=%.2f ATR | "
      "Sortie=%s | TP fixe=AUCUN | Coûts estimés=%.2f %s",
      __FILE__,
      m_initialCapital,
      m_currency,
      m_virtualCapital,
      m_currency,
      m_virtualCapital - m_initialCapital,
      m_currency,
      m_riskPercent,
      m_initialStopAtrMultiplier,
      V6ExitModeToString(m_exitMode),
      m_totalEstimatedCosts,
      m_currency);
  }
};

#endif

//+------------------------------------------------------------------+
//|             VirtualDonchianPositionManager.mqh                   |
//|  Sorties Donchian / Chandelier ATR et simulation du capital     |
//+------------------------------------------------------------------+
#ifndef PB_BZH_VIRTUAL_DONCHIAN_POSITION_MANAGER_MQH
#define PB_BZH_VIRTUAL_DONCHIAN_POSITION_MANAGER_MQH

#include <PbBzhConcept\Signals\DonchianBreakoutSignal.mqh>

enum ENUM_PB_V2_POSITION_DIRECTION {
  PB_V2_POSITION_FLAT = 0,
  PB_V2_POSITION_LONG = 1,
  PB_V2_POSITION_SHORT = -1
};

enum ENUM_PB_V2_EXIT_MODE {
  PB_V2_EXIT_DONCHIAN_ONLY = 0,
  PB_V2_EXIT_CHANDELIER_ONLY,
  PB_V2_EXIT_DONCHIAN_OR_CHANDELIER
};

enum ENUM_PB_V2_EXIT_REASON {
  PB_V2_EXIT_NONE = 0,
  PB_V2_EXIT_STOP_INITIAL,
  PB_V2_EXIT_CHANDELIER,
  PB_V2_EXIT_DONCHIAN,
  PB_V2_EXIT_TEST_END
};

string V2PositionDirectionToString(
  const ENUM_PB_V2_POSITION_DIRECTION direction) {

  switch (direction) {
    case PB_V2_POSITION_LONG:
      return "LONG";

    case PB_V2_POSITION_SHORT:
      return "SHORT";

    case PB_V2_POSITION_FLAT:
    default:
      return "FLAT";
  }
}

string V2ExitModeToString(
  const ENUM_PB_V2_EXIT_MODE mode) {

  switch (mode) {
    case PB_V2_EXIT_DONCHIAN_ONLY:
      return "DONCHIAN_ONLY";

    case PB_V2_EXIT_CHANDELIER_ONLY:
      return "CHANDELIER_ONLY";

    case PB_V2_EXIT_DONCHIAN_OR_CHANDELIER:
    default:
      return "DONCHIAN_OR_CHANDELIER";
  }
}

string V2ExitReasonToString(
  const ENUM_PB_V2_EXIT_REASON reason) {

  switch (reason) {
    case PB_V2_EXIT_STOP_INITIAL:
      return "STOP_INITIAL";

    case PB_V2_EXIT_CHANDELIER:
      return "CHANDELIER";

    case PB_V2_EXIT_DONCHIAN:
      return "DONCHIAN";

    case PB_V2_EXIT_TEST_END:
      return "TEST_END";

    case PB_V2_EXIT_NONE:
    default:
      return "NONE";
  }
}

struct SPbVirtualDonchianPosition {
  bool isOpen;
  ENUM_PB_V2_POSITION_DIRECTION direction;

  datetime signalBarTime;
  datetime entryTime;

  double entryPrice;
  double initialStopLossPrice;
  double stopLossPrice;
  double volumeLots;

  double highestPriceSinceEntry;
  double lowestPriceSinceEntry;
  double currentAtrPrice;
  double currentAtrPoints;
  bool chandelierActivated;
  int chandelierMoveCount;

  double entryAtrPrice;
  double entryAtrPoints;
  double initialStopDistancePrice;
  double initialStopDistancePoints;

  double openingCapital;
  double targetRiskMoney;
  double estimatedLossAtStop;
};

class CVirtualDonchianPositionManager {
private:
  string m_symbol;
  double m_point;
  int m_digits;
  string m_currency;

  double m_initialCapital;
  double m_virtualCapital;
  double m_riskPercent;
  double m_initialStopAtrMultiplier;
  ENUM_PB_V2_EXIT_MODE m_exitMode;
  double m_chandelierAtrMultiplier;

  SPbVirtualDonchianPosition m_position;

  int m_openCount;
  int m_closedCount;
  int m_winnerCount;
  int m_loserCount;
  int m_neutralCount;
  int m_initialStopExitCount;
  int m_chandelierExitCount;
  int m_donchianExitCount;
  int m_testEndExitCount;
  int m_chandelierMoveCount;
  int m_longCount;
  int m_shortCount;

  double m_totalPoints;
  double m_totalMoney;
  double m_sumGains;
  double m_sumLosses;

  double m_capitalPeak;
  double m_maxClosedDrawdownMoney;
  double m_maxClosedDrawdownPercent;

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

  bool CalculateVolumeByRisk(
    const ENUM_PB_V2_POSITION_DIRECTION direction,
    const double entryPrice,
    const double stopLossPrice,
    const double targetRiskMoney,
    double &volumeLots,
    double &estimatedLossAtStop) const {

    volumeLots = 0.0;
    estimatedLossAtStop = 0.0;

    ENUM_ORDER_TYPE orderType =
      direction == PB_V2_POSITION_LONG
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
    const ENUM_PB_V2_EXIT_REASON reason) {

    if (!m_position.isOpen || exitPrice <= 0.0)
      return false;

    ENUM_ORDER_TYPE orderType =
      m_position.direction == PB_V2_POSITION_LONG
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

    double resultMoney = 0.0;

    if (!OrderCalcProfit(
      orderType,
      m_symbol,
      m_position.volumeLots,
      m_position.entryPrice,
      exitPrice,
      resultMoney)) {

      PrintFormat(
        "[%s][ERROR] "
        "Calcul du résultat impossible. Erreur=%d",
        __FILE__,
        GetLastError());

      return false;
    }

    double resultPoints =
      m_position.direction == PB_V2_POSITION_LONG
      ? (exitPrice - m_position.entryPrice) / m_point
      : (m_position.entryPrice - exitPrice) / m_point;

    double resultR =
      m_position.estimatedLossAtStop > 0.0
      ? resultMoney / m_position.estimatedLossAtStop
      : 0.0;

    m_virtualCapital += resultMoney;
    m_closedCount++;
    m_totalPoints += resultPoints;
    m_totalMoney += resultMoney;

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

    if (reason == PB_V2_EXIT_STOP_INITIAL)
      m_initialStopExitCount++;
    else if (reason == PB_V2_EXIT_CHANDELIER)
      m_chandelierExitCount++;
    else if (reason == PB_V2_EXIT_DONCHIAN)
      m_donchianExitCount++;
    else if (reason == PB_V2_EXIT_TEST_END)
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
      "Résultat=%.1f points | %.2f %s | %.2f R | "
      "Capital=%.2f %s | Durée=%d min",

      __FILE__,
      V2PositionDirectionToString(
        m_position.direction),

      V2ExitReasonToString(reason),
      m_digits,
      m_position.entryPrice,
      m_digits,
      exitPrice,
      m_position.volumeLots,
      resultPoints,
      resultMoney,
      m_currency,
      resultR,
      m_virtualCapital,
      m_currency,
      (int)((exitTime - m_position.entryTime) / 60));

    ZeroMemory(m_position);
    m_position.direction = PB_V2_POSITION_FLAT;
    return true;
  }

public:
  CVirtualDonchianPositionManager(void) {
    m_symbol = "";
    m_point = 0.0;
    m_digits = 0;
    m_currency = "";

    m_initialCapital = 10000.0;
    m_virtualCapital = 10000.0;
    m_riskPercent = 1.0;
    m_initialStopAtrMultiplier = 2.0;
    m_exitMode = PB_V2_EXIT_DONCHIAN_ONLY;
    m_chandelierAtrMultiplier = 3.0;

    ZeroMemory(m_position);
    m_position.direction = PB_V2_POSITION_FLAT;

    m_openCount = 0;
    m_closedCount = 0;
    m_winnerCount = 0;
    m_loserCount = 0;
    m_neutralCount = 0;
    m_initialStopExitCount = 0;
    m_chandelierExitCount = 0;
    m_donchianExitCount = 0;
    m_testEndExitCount = 0;
    m_chandelierMoveCount = 0;
    m_longCount = 0;
    m_shortCount = 0;

    m_totalPoints = 0.0;
    m_totalMoney = 0.0;
    m_sumGains = 0.0;
    m_sumLosses = 0.0;

    m_capitalPeak = 10000.0;
    m_maxClosedDrawdownMoney = 0.0;
    m_maxClosedDrawdownPercent = 0.0;
  }

  bool Initialize(
    const string symbol,
    const double initialCapital,
    const double riskPercent,
    const double initialStopAtrMultiplier,
    const ENUM_PB_V2_EXIT_MODE exitMode,
    const double chandelierAtrMultiplier) {

    if (initialCapital <= 0.0 ||
      riskPercent <= 0.0 ||
      initialStopAtrMultiplier <= 0.0 ||
      chandelierAtrMultiplier <= 0.0) {

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
    m_exitMode = exitMode;
    m_chandelierAtrMultiplier = chandelierAtrMultiplier;

    ZeroMemory(m_position);
    m_position.direction = PB_V2_POSITION_FLAT;

    m_openCount = 0;
    m_closedCount = 0;
    m_winnerCount = 0;
    m_loserCount = 0;
    m_neutralCount = 0;
    m_initialStopExitCount = 0;
    m_chandelierExitCount = 0;
    m_donchianExitCount = 0;
    m_testEndExitCount = 0;
    m_chandelierMoveCount = 0;
    m_longCount = 0;
    m_shortCount = 0;

    m_totalPoints = 0.0;
    m_totalMoney = 0.0;
    m_sumGains = 0.0;
    m_sumLosses = 0.0;

    m_capitalPeak = initialCapital;
    m_maxClosedDrawdownMoney = 0.0;
    m_maxClosedDrawdownPercent = 0.0;

    return true;
  }

  bool IsOpen(void) const {
    return m_position.isOpen;
  }

  ENUM_PB_V2_POSITION_DIRECTION Direction(void) const {
    return m_position.direction;
  }

  double EntryPrice(void) const {
    return m_position.entryPrice;
  }

  double StopLossPrice(void) const {
    return m_position.stopLossPrice;
  }

  bool ChandelierActivated(void) const {
    return m_position.chandelierActivated;
  }

  double HighestPriceSinceEntry(void) const {
    return m_position.highestPriceSinceEntry;
  }

  double LowestPriceSinceEntry(void) const {
    return m_position.lowestPriceSinceEntry;
  }

  ENUM_PB_V2_EXIT_MODE ExitMode(void) const {
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

  bool OpenFromSignal(
    const SPbDonchianSnapshot &snapshot,
    const MqlTick &tick,
    const bool allowLong,
    const bool allowShort) {

    if (m_position.isOpen || !snapshot.isValid)
      return false;

    ENUM_PB_V2_POSITION_DIRECTION direction =
      PB_V2_POSITION_FLAT;

    double entryPrice = 0.0;

    if (snapshot.signal == PB_BREAKOUT_BUY && allowLong) {
      direction = PB_V2_POSITION_LONG;
      entryPrice = tick.ask;
    }
    else if (snapshot.signal == PB_BREAKOUT_SELL && allowShort) {
      direction = PB_V2_POSITION_SHORT;
      entryPrice = tick.bid;
    }
    else {
      return false;
    }

    if (entryPrice <= 0.0 || snapshot.atrPrice <= 0.0)
      return false;

    double stopDistancePrice =
      m_initialStopAtrMultiplier * snapshot.atrPrice;

    double stopLossPrice =
      direction == PB_V2_POSITION_LONG
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
        V2PositionDirectionToString(direction),
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
    m_position.signalBarTime = snapshot.signalBarTime;
    m_position.entryTime = (datetime)tick.time;
    m_position.entryPrice = entryPrice;
    m_position.initialStopLossPrice = stopLossPrice;
    m_position.stopLossPrice = stopLossPrice;
    m_position.volumeLots = volumeLots;
    m_position.highestPriceSinceEntry = entryPrice;
    m_position.lowestPriceSinceEntry = entryPrice;
    m_position.currentAtrPrice = snapshot.atrPrice;
    m_position.currentAtrPoints = snapshot.atrPoints;
    m_position.chandelierActivated = false;
    m_position.chandelierMoveCount = 0;
    m_position.entryAtrPrice = snapshot.atrPrice;
    m_position.entryAtrPoints = snapshot.atrPoints;
    m_position.initialStopDistancePrice = stopDistancePrice;
    m_position.initialStopDistancePoints =
      stopDistancePrice / m_point;
    m_position.openingCapital = m_virtualCapital;
    m_position.targetRiskMoney = targetRiskMoney;
    m_position.estimatedLossAtStop = estimatedLossAtStop;

    m_openCount++;

    if (direction == PB_V2_POSITION_LONG)
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
      V2PositionDirectionToString(direction),
      TimeToString(
        snapshot.signalBarTime,
        TIME_DATE|TIME_MINUTES),
      m_digits,
      entryPrice,
      m_digits,
      stopLossPrice,
      m_position.initialStopDistancePoints,
      snapshot.atrPoints,
      volumeLots,
      targetRiskMoney,
      m_currency,
      estimatedLossAtStop,
      m_currency,
      m_virtualCapital,
      m_currency);

    return true;
  }

  void UpdateAtr(
    const double atrPrice,
    const double atrPoints) {

    if (!m_position.isOpen ||
      atrPrice <= 0.0 ||
      atrPoints <= 0.0) {

      return;
    }

    m_position.currentAtrPrice = atrPrice;
    m_position.currentAtrPoints = atrPoints;
  }

  bool ProcessTick(
    const MqlTick &tick) {

    if (!m_position.isOpen)
      return false;

    double executablePrice =
      m_position.direction == PB_V2_POSITION_LONG
      ? tick.bid
      : tick.ask;

    if (executablePrice <= 0.0)
      return false;

    if (m_position.direction == PB_V2_POSITION_LONG) {
      if (executablePrice > m_position.highestPriceSinceEntry)
        m_position.highestPriceSinceEntry = executablePrice;
    }
    else {
      if (executablePrice < m_position.lowestPriceSinceEntry)
        m_position.lowestPriceSinceEntry = executablePrice;
    }

    bool useChandelier =
      m_exitMode == PB_V2_EXIT_CHANDELIER_ONLY ||
      m_exitMode == PB_V2_EXIT_DONCHIAN_OR_CHANDELIER;

    if (useChandelier &&
      m_position.currentAtrPrice > 0.0) {

      double candidateStop =
        m_position.direction == PB_V2_POSITION_LONG
        ? m_position.highestPriceSinceEntry -
          m_chandelierAtrMultiplier *
          m_position.currentAtrPrice
        : m_position.lowestPriceSinceEntry +
          m_chandelierAtrMultiplier *
          m_position.currentAtrPrice;

      candidateStop = NormalizeDouble(
        candidateStop,
        m_digits);

      bool improvesStop =
        (
          m_position.direction == PB_V2_POSITION_LONG &&
          candidateStop > m_position.stopLossPrice
        )
        ||
        (
          m_position.direction == PB_V2_POSITION_SHORT &&
          candidateStop < m_position.stopLossPrice
        );

      if (improvesStop) {
        bool firstActivation =
          !m_position.chandelierActivated;

        m_position.stopLossPrice = candidateStop;
        m_position.chandelierActivated = true;
        m_position.chandelierMoveCount++;
        m_chandelierMoveCount++;

        if (firstActivation) {
          PrintFormat(
            "[%s][INFO] "
            "CHANDELIER ACTIVÉ | Direction=%s | "
            "SL dynamique=%.*f | ATR courant=%.1f points | "
            "Extrême=%.*f",

            __FILE__,
            V2PositionDirectionToString(
              m_position.direction),
            m_digits,
            m_position.stopLossPrice,
            m_position.currentAtrPoints,
            m_digits,
            m_position.direction == PB_V2_POSITION_LONG
            ? m_position.highestPriceSinceEntry
            : m_position.lowestPriceSinceEntry);
        }
      }
    }

    bool stopReached =
      (
        m_position.direction == PB_V2_POSITION_LONG &&
        executablePrice <= m_position.stopLossPrice
      )
      ||
      (
        m_position.direction == PB_V2_POSITION_SHORT &&
        executablePrice >= m_position.stopLossPrice
      );

    if (!stopReached)
      return false;

    ENUM_PB_V2_EXIT_REASON exitReason =
      m_position.chandelierActivated
      ? PB_V2_EXIT_CHANDELIER
      : PB_V2_EXIT_STOP_INITIAL;

    return ClosePosition(
      executablePrice,
      (datetime)tick.time,
      exitReason);
  }

  bool ProcessDonchianExit(
    const SPbDonchianSnapshot &snapshot,
    const MqlTick &tick) {

    if (!m_position.isOpen || !snapshot.isValid)
      return false;

    bool useDonchian =
      m_exitMode == PB_V2_EXIT_DONCHIAN_ONLY ||
      m_exitMode == PB_V2_EXIT_DONCHIAN_OR_CHANDELIER;

    if (!useDonchian)
      return false;

    bool mustExit =
      (
        m_position.direction == PB_V2_POSITION_LONG &&
        snapshot.signalClose < snapshot.exitLower
      )
      ||
      (
        m_position.direction == PB_V2_POSITION_SHORT &&
        snapshot.signalClose > snapshot.exitUpper
      );

    if (!mustExit)
      return false;

    double exitPrice =
      m_position.direction == PB_V2_POSITION_LONG
      ? tick.bid
      : tick.ask;

    return ClosePosition(
      exitPrice,
      (datetime)tick.time,
      PB_V2_EXIT_DONCHIAN);
  }

  bool CloseAtTestEnd(
    const MqlTick &tick) {

    if (!m_position.isOpen)
      return false;

    double exitPrice =
      m_position.direction == PB_V2_POSITION_LONG
      ? tick.bid
      : tick.ask;

    return ClosePosition(
      exitPrice,
      (datetime)tick.time,
      PB_V2_EXIT_TEST_END);
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
      "Entrée : %.*f | SL courant : %.*f | ATR courant : %.1f points\n"
      "Chandelier : %s | Déplacements : %d | Extrême : %.*f\n"
      "Capital virtuel : %.2f %s | Risque initial estimé : %.2f %s",

      V2PositionDirectionToString(
        m_position.direction),
      m_position.volumeLots,
      m_digits,
      m_position.entryPrice,
      m_digits,
      m_position.stopLossPrice,
      m_position.currentAtrPoints,
      m_position.chandelierActivated
      ? "ACTIF"
      : "INACTIF",
      m_position.chandelierMoveCount,
      m_digits,
      m_position.direction == PB_V2_POSITION_LONG
      ? m_position.highestPriceSinceEntry
      : m_position.lowestPriceSinceEntry,
      m_virtualCapital,
      m_currency,
      m_position.estimatedLossAtStop,
      m_currency);
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
      "Stop initial=%d | Chandelier=%d | "
      "Sorties Donchian=%d | Fin test=%d | "
      "Déplacements SL=%d",
      __FILE__,
      m_openCount,
      m_closedCount,
      m_longCount,
      m_shortCount,
      m_winnerCount,
      m_loserCount,
      m_neutralCount,
      m_initialStopExitCount,
      m_chandelierExitCount,
      m_donchianExitCount,
      m_testEndExitCount,
      m_chandelierMoveCount);

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
      "Sortie=%s | Chandelier=%.2f ATR | TP=AUCUN",
      __FILE__,
      m_initialCapital,
      m_currency,
      m_virtualCapital,
      m_currency,
      m_virtualCapital - m_initialCapital,
      m_currency,
      m_riskPercent,
      m_initialStopAtrMultiplier,
      V2ExitModeToString(m_exitMode),
      m_chandelierAtrMultiplier);
  }
};

#endif

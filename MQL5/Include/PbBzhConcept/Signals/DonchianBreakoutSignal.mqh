//+------------------------------------------------------------------+
//|                         DonchianBreakoutSignal.mqh                |
//|  Détection d'une cassure Donchian sur bougie clôturée + ATR      |
//+------------------------------------------------------------------+
#ifndef PB_BZH_DONCHIAN_BREAKOUT_SIGNAL_MQH
#define PB_BZH_DONCHIAN_BREAKOUT_SIGNAL_MQH

enum ENUM_PB_BREAKOUT_SIGNAL {
  PB_BREAKOUT_NONE = 0,
  PB_BREAKOUT_BUY,
  PB_BREAKOUT_SELL
};

struct SPbDonchianSnapshot {
  bool isValid;
  datetime signalBarTime;

  double signalOpen;
  double signalHigh;
  double signalLow;
  double signalClose;

  double entryUpper;
  double entryLower;
  double exitUpper;
  double exitLower;

  double atrPrice;
  double atrPoints;
  double entryChannelWidthPoints;
  double entryChannelWidthAtr;

  ENUM_PB_BREAKOUT_SIGNAL signal;
};

string BreakoutSignalToString(
  const ENUM_PB_BREAKOUT_SIGNAL signal) {

  switch (signal) {
    case PB_BREAKOUT_BUY:
      return "BUY";

    case PB_BREAKOUT_SELL:
      return "SELL";

    case PB_BREAKOUT_NONE:
    default:
      return "NONE";
  }
}

class CDonchianBreakoutSignal {
private:
  string m_symbol;
  ENUM_TIMEFRAMES m_timeframe;
  int m_entryPeriod;
  int m_exitPeriod;
  int m_atrPeriod;
  int m_atrHandle;
  double m_point;

  double HighestHigh(
    const MqlRates &rates[],
    const int firstIndex,
    const int count) const {

    double highest = rates[firstIndex].high;

    for (int index = firstIndex + 1;
      index < firstIndex + count;
      index++) {

      if (rates[index].high > highest)
        highest = rates[index].high;
    }

    return highest;
  }

  double LowestLow(
    const MqlRates &rates[],
    const int firstIndex,
    const int count) const {

    double lowest = rates[firstIndex].low;

    for (int index = firstIndex + 1;
      index < firstIndex + count;
      index++) {

      if (rates[index].low < lowest)
        lowest = rates[index].low;
    }

    return lowest;
  }

public:
  CDonchianBreakoutSignal(void) {
    m_symbol = "";
    m_timeframe = PERIOD_CURRENT;
    m_entryPeriod = 20;
    m_exitPeriod = 10;
    m_atrPeriod = 14;
    m_atrHandle = INVALID_HANDLE;
    m_point = 0.0;
  }

  bool Initialize(
    const string symbol,
    const ENUM_TIMEFRAMES timeframe,
    const int entryPeriod,
    const int exitPeriod,
    const int atrPeriod) {

    Release();

    if (entryPeriod < 2 ||
      exitPeriod < 2 ||
      atrPeriod < 2) {

      Print(
        "[PbBzhConceptEA v2.00][ERROR] "
        "Périodes Donchian/ATR invalides.");

      return false;
    }

    m_symbol = symbol;
    m_timeframe = timeframe;
    m_entryPeriod = entryPeriod;
    m_exitPeriod = exitPeriod;
    m_atrPeriod = atrPeriod;

    m_point = SymbolInfoDouble(
      m_symbol,
      SYMBOL_POINT);

    if (m_point <= 0.0) {
      PrintFormat(
        "[PbBzhConceptEA v2.00][ERROR] "
        "Point invalide pour %s.",
        m_symbol);

      return false;
    }

    m_atrHandle = iATR(
      m_symbol,
      m_timeframe,
      m_atrPeriod);

    if (m_atrHandle == INVALID_HANDLE) {
      PrintFormat(
        "[PbBzhConceptEA v2.00][ERROR] "
        "Création iATR impossible. Erreur=%d",
        GetLastError());

      return false;
    }

    return true;
  }

  void Release(void) {
    if (m_atrHandle != INVALID_HANDLE) {
      IndicatorRelease(m_atrHandle);
      m_atrHandle = INVALID_HANDLE;
    }
  }

  bool EvaluateClosedBar(
    SPbDonchianSnapshot &snapshot) const {

    ZeroMemory(snapshot);
    snapshot.signal = PB_BREAKOUT_NONE;

    if (m_atrHandle == INVALID_HANDLE ||
      m_point <= 0.0) {

      return false;
    }

    int longestPeriod = MathMax(
      m_entryPeriod,
      m_exitPeriod);

    // Il faut :
    // - la bougie clôturée [1] ;
    // - le canal associé [2 .. période+1] ;
    // - le canal précédent [3 .. période+2].
    int requiredBars = longestPeriod + 3;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    int copiedRates = CopyRates(
      m_symbol,
      m_timeframe,
      0,
      requiredBars,
      rates);

    if (copiedRates < requiredBars)
      return false;

    double atrBuffer[1];

    int copiedAtr = CopyBuffer(
      m_atrHandle,
      0,
      1,
      1,
      atrBuffer);

    if (copiedAtr != 1 || atrBuffer[0] <= 0.0)
      return false;

    double entryUpperCurrent = HighestHigh(
      rates,
      2,
      m_entryPeriod);

    double entryLowerCurrent = LowestLow(
      rates,
      2,
      m_entryPeriod);

    double entryUpperPrevious = HighestHigh(
      rates,
      3,
      m_entryPeriod);

    double entryLowerPrevious = LowestLow(
      rates,
      3,
      m_entryPeriod);

    snapshot.isValid = true;
    snapshot.signalBarTime = rates[1].time;

    snapshot.signalOpen = rates[1].open;
    snapshot.signalHigh = rates[1].high;
    snapshot.signalLow = rates[1].low;
    snapshot.signalClose = rates[1].close;

    snapshot.entryUpper = entryUpperCurrent;
    snapshot.entryLower = entryLowerCurrent;

    snapshot.exitUpper = HighestHigh(
      rates,
      2,
      m_exitPeriod);

    snapshot.exitLower = LowestLow(
      rates,
      2,
      m_exitPeriod);

    snapshot.atrPrice = atrBuffer[0];
    snapshot.atrPoints = atrBuffer[0] / m_point;

    snapshot.entryChannelWidthPoints =
      (entryUpperCurrent - entryLowerCurrent) /
      m_point;

    snapshot.entryChannelWidthAtr =
      (entryUpperCurrent - entryLowerCurrent) /
      atrBuffer[0];

    // Cassure confirmée par la clôture de [1].
    // La comparaison de [2] avec le canal précédent évite de
    // répéter le même signal à chaque nouvelle bougie.
    bool buyBreakout =
      rates[1].close > entryUpperCurrent &&
      rates[2].close <= entryUpperPrevious;

    bool sellBreakout =
      rates[1].close < entryLowerCurrent &&
      rates[2].close >= entryLowerPrevious;

    if (buyBreakout)
      snapshot.signal = PB_BREAKOUT_BUY;
    else if (sellBreakout)
      snapshot.signal = PB_BREAKOUT_SELL;

    return true;
  }
};

#endif

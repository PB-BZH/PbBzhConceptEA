#ifndef PB_BZH_SIGNAL_STATISTICS_MQH
#define PB_BZH_SIGNAL_STATISTICS_MQH

#include <PbBzhConcept\Domain\TradeSignal.mqh>

// Compte les résultats produits par la stratégie.
//
// Cette classe ne calcule aucun signal.
// Elle ne fait qu'enregistrer les résultats reçus.
class CSignalStatistics
  {
private:
   int m_evaluatedBarCount;
   int m_buyCount;
   int m_sellCount;
   int m_noneCount;
   int m_errorCount;

public:
   CSignalStatistics(void)
     {
      Reset();
     }

   void Reset(void)
     {
      m_evaluatedBarCount=0;
      m_buyCount=0;
      m_sellCount=0;
      m_noneCount=0;
      m_errorCount=0;
     }

   void RecordSignal(const ENUM_PB_TRADE_SIGNAL signal)
     {
      m_evaluatedBarCount++;

      switch(signal)
        {
         case PB_SIGNAL_BUY:
            m_buyCount++;
            break;

         case PB_SIGNAL_SELL:
            m_sellCount++;
            break;

         case PB_SIGNAL_NONE:
         default:
            m_noneCount++;
            break;
        }
     }

   void RecordError(void)
     {
      m_errorCount++;
     }

   int EvaluatedBarCount(void) const
     {
      return m_evaluatedBarCount;
     }

   int BuyCount(void) const
     {
      return m_buyCount;
     }

   int SellCount(void) const
     {
      return m_sellCount;
     }

   int NoneCount(void) const
     {
      return m_noneCount;
     }

   int ErrorCount(void) const
     {
      return m_errorCount;
     }

   int TotalSignalCount(void) const
     {
      return m_buyCount+m_sellCount;
     }

   double SignalRatePercent(void) const
     {
      if(m_evaluatedBarCount==0)
         return 0.0;

      return 100.0*
             (double)TotalSignalCount()/
             (double)m_evaluatedBarCount;
     }

   string BuildSummary(void) const
     {
      return StringFormat(
         "Bougies analysées=%d | BUY=%d | SELL=%d | NONE=%d | "
         "Erreurs=%d | Signaux=%d | Taux de signal=%.2f%%",
         m_evaluatedBarCount,
         m_buyCount,
         m_sellCount,
         m_noneCount,
         m_errorCount,
         TotalSignalCount(),
         SignalRatePercent());
     }
  };

#endif
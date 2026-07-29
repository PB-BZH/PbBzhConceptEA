#ifndef PB_BZH_CHART_SIGNAL_RENDERER_MQH
#define PB_BZH_CHART_SIGNAL_RENDERER_MQH

#include <PbBzhConcept\Domain\TradeSignal.mqh>

// Affiche les signaux théoriques sur le graphique.
// Cette classe ne contient aucune fonction de trading.
class CChartSignalRenderer
  {
private:
   long              m_chartId;
   string            m_objectPrefix;
   double            m_point;
   int               m_offsetPoints;
   color             m_buyColor;
   color             m_sellColor;
   bool              m_enabled;

   string            BuildObjectName(const ENUM_PB_TRADE_SIGNAL signal,
                                     const datetime barOpenTime) const
     {
      return StringFormat("%s_%s_%I64d",
                          m_objectPrefix,
                          TradeSignalToString(signal),
                          (long)barOpenTime);
     }

public:
                     CChartSignalRenderer(void)
     {
      m_chartId=0;
      m_objectPrefix="PbBzhConceptEA";
      m_point=0.0;
      m_offsetPoints=50;
      m_buyColor=clrLimeGreen;
      m_sellColor=clrTomato;
      m_enabled=true;
     }

   bool              Init(const long chartId,
                          const string expertName,
                          const string symbol,
                          const ENUM_TIMEFRAMES timeframe,
                          const bool enabled,
                          const int offsetPoints,
                          const color buyColor,
                          const color sellColor)
     {
      m_chartId=chartId;
      m_enabled=enabled;
      m_offsetPoints=(offsetPoints<0) ? 0 : offsetPoints;
      m_buyColor=buyColor;
      m_sellColor=sellColor;
      m_objectPrefix=StringFormat("%s_%s_%s",
                                  expertName,
                                  symbol,
                                  EnumToString(timeframe));

      m_point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(m_point<=0.0)
        {
         PrintFormat("[CChartSignalRenderer][ERROR] Taille du point introuvable pour %s.",symbol);
         return false;
        }

      return true;
     }

   bool              Draw(const ENUM_PB_TRADE_SIGNAL signal,
                          const datetime barOpenTime,
                          const double barHigh,
                          const double barLow) const
     {
      if(!m_enabled || signal==PB_SIGNAL_NONE)
         return true;

      string objectName=BuildObjectName(signal,barOpenTime);

      // Le nom contient l'heure de la bougie : le même signal ne peut donc
      // pas être dessiné plusieurs fois.
      if(ObjectFind(m_chartId,objectName)>=0)
         return true;

      ENUM_OBJECT objectType=(signal==PB_SIGNAL_BUY)
                             ? OBJ_ARROW_BUY
                             : OBJ_ARROW_SELL;

      double price=(signal==PB_SIGNAL_BUY)
                   ? barLow-m_offsetPoints*m_point
                   : barHigh+m_offsetPoints*m_point;

      color arrowColor=(signal==PB_SIGNAL_BUY) ? m_buyColor : m_sellColor;

      ResetLastError();
      if(!ObjectCreate(m_chartId,objectName,objectType,0,barOpenTime,price))
        {
         PrintFormat("[CChartSignalRenderer][ERROR] Création de %s impossible. Erreur=%d",
                     objectName,GetLastError());
         return false;
        }

      ObjectSetInteger(m_chartId,objectName,OBJPROP_COLOR,arrowColor);
      ObjectSetInteger(m_chartId,objectName,OBJPROP_WIDTH,2);
      ObjectSetInteger(m_chartId,objectName,OBJPROP_BACK,false);
      ObjectSetInteger(m_chartId,objectName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(m_chartId,objectName,OBJPROP_HIDDEN,false);
      ObjectSetString(m_chartId,objectName,OBJPROP_TOOLTIP,
                      StringFormat("Signal théorique %s\n%s",
                                   TradeSignalToString(signal),
                                   TimeToString(barOpenTime,TIME_DATE|TIME_MINUTES)));

      ChartRedraw(m_chartId);
      return true;
     }
  };

#endif

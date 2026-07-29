#ifndef PB_BZH_BAR_CLOCK_MQH
#define PB_BZH_BAR_CLOCK_MQH

// Détecte l'ouverture d'une nouvelle bougie pour un symbole et une période.
// OnTick peut être appelé de nombreuses fois pendant une même bougie : cette
// classe permet de ne lancer l'analyse du signal qu'une seule fois par bougie.
class CBarClock
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   datetime          m_currentBarOpenTime;

   bool ReadCurrentBarOpenTime(datetime &barOpenTime) const
     {
      datetime times[1];
      ResetLastError();

      if(CopyTime(m_symbol,m_timeframe,0,1,times)!=1)
        {
         PrintFormat("[CBarClock][ERROR] CopyTime a échoué. Erreur=%d",GetLastError());
         return false;
        }

      barOpenTime=times[0];
      return true;
     }

public:
   CBarClock(void)
     {
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_currentBarOpenTime=0;
     }

   bool Init(const string symbol,const ENUM_TIMEFRAMES timeframe)
     {
      m_symbol=symbol;
      m_timeframe=timeframe;

      datetime currentBarOpenTime=0;
      if(!ReadCurrentBarOpenTime(currentBarOpenTime))
         return false;

      // Mémoriser la bougie actuelle évite de produire artificiellement un
      // événement "nouvelle bougie" dès l'attachement de l'EA au graphique.
      m_currentBarOpenTime=currentBarOpenTime;
      return true;
     }

   bool IsNewBar(void)
     {
      datetime currentBarOpenTime=0;
      if(!ReadCurrentBarOpenTime(currentBarOpenTime))
         return false;

      if(currentBarOpenTime==m_currentBarOpenTime)
         return false;

      m_currentBarOpenTime=currentBarOpenTime;
      return true;
     }
  };

#endif

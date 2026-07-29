#ifndef PB_BZH_MA_PRICE_CROSS_SIGNAL_MQH
#define PB_BZH_MA_PRICE_CROSS_SIGNAL_MQH

#include <PbBzhConcept\Domain\TradeSignal.mqh>

// Photographie des données utilisées pour prendre la décision.
// bar1 = dernière bougie clôturée ; bar2 = bougie clôturée précédente.
struct SMaPriceCrossSnapshot
  {
   // Bougie courante : point potentiel d'exécution.
   datetime             bar0OpenTime;
   double               bar0Open;

   // Dernière bougie clôturée : bougie ayant confirmé le signal.
   datetime             bar1OpenTime;
   double               bar1High;
   double               bar1Low;
   double               bar1Close;

   // Bougie clôturée précédente.
   double               bar2Close;

   // Valeurs de la moyenne mobile.
   double               bar1Ma;
   double               bar2Ma;

   ENUM_PB_TRADE_SIGNAL signal;
  };
  
// Stratégie volontairement simple et explicite :
// BUY  lorsque le cours clôturé passe de sous la MA à au-dessus de la MA.
// SELL lorsque le cours clôturé passe d'au-dessus de la MA à sous la MA.
class CMaPriceCrossSignal
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_maHandle;
   
   bool m_useMaSlopeFilter;

   bool ReadMaValue(const int shift,double &value) const
     {
      double buffer[1];
      ResetLastError();

      if(CopyBuffer(m_maHandle,0,shift,1,buffer)!=1)
        {
         PrintFormat("[CMaPriceCrossSignal][ERROR] CopyBuffer shift=%d a échoué. Erreur=%d",
                     shift,GetLastError());
         return false;
        }

      value=buffer[0];
      return true;
     }

   bool ReadOpenValue(const int shift,double &value) const
  {
   double buffer[1];
   ResetLastError();

   if(CopyOpen(m_symbol,m_timeframe,shift,1,buffer)!=1)
     {
      PrintFormat(
         "[CMaPriceCrossSignal][ERROR] "
         "CopyOpen shift=%d a échoué. Erreur=%d",
         shift,
         GetLastError());

      return false;
     }

   value=buffer[0];
   return true;
  }
   
   bool ReadCloseValue(const int shift,double &value) const
     {
      double buffer[1];
      ResetLastError();

      if(CopyClose(m_symbol,m_timeframe,shift,1,buffer)!=1)
        {
         PrintFormat("[CMaPriceCrossSignal][ERROR] CopyClose shift=%d a échoué. Erreur=%d",
                     shift,GetLastError());
         return false;
        }

      value=buffer[0];
      return true;
     }

   bool ReadHighValue(const int shift,double &value) const
     {
      double buffer[1];
      ResetLastError();

      if(CopyHigh(m_symbol,m_timeframe,shift,1,buffer)!=1)
        {
         PrintFormat("[CMaPriceCrossSignal][ERROR] CopyHigh shift=%d a échoué. Erreur=%d",
                     shift,GetLastError());
         return false;
        }

      value=buffer[0];
      return true;
     }

   bool ReadLowValue(const int shift,double &value) const
     {
      double buffer[1];
      ResetLastError();

      if(CopyLow(m_symbol,m_timeframe,shift,1,buffer)!=1)
        {
         PrintFormat("[CMaPriceCrossSignal][ERROR] CopyLow shift=%d a échoué. Erreur=%d",
                     shift,GetLastError());
         return false;
        }

      value=buffer[0];
      return true;
     }

   bool ReadBarOpenTime(const int shift,datetime &value) const
     {
      datetime buffer[1];
      ResetLastError();

      if(CopyTime(m_symbol,m_timeframe,shift,1,buffer)!=1)
        {
         PrintFormat("[CMaPriceCrossSignal][ERROR] CopyTime shift=%d a échoué. Erreur=%d",
                     shift,GetLastError());
         return false;
        }

      value=buffer[0];
      return true;
     }

public:
   CMaPriceCrossSignal(void)
     {
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_maHandle=INVALID_HANDLE;
      m_useMaSlopeFilter=false;
     }

   bool Init(
      const string             symbol,
      const ENUM_TIMEFRAMES    timeframe,
      const int                maPeriod,
      const int                maShift,
      const ENUM_MA_METHOD     maMethod,
      const ENUM_APPLIED_PRICE appliedPrice,
      const bool               useMaSlopeFilter)
     {
      if(maPeriod<2)
        {
         Print(
            "[CMaPriceCrossSignal][ERROR] "
            "La période de la moyenne doit être "
            "au moins égale à 2.");
   
         return false;
        }
   
      m_symbol           =symbol;
      m_timeframe        =timeframe;
      m_useMaSlopeFilter =useMaSlopeFilter;
   
      ResetLastError();
   
      m_maHandle=iMA(
         m_symbol,
         m_timeframe,
         maPeriod,
         maShift,
         maMethod,
         appliedPrice);
   
      if(m_maHandle==INVALID_HANDLE)
        {
         PrintFormat(
            "[CMaPriceCrossSignal][ERROR] "
            "Création de iMA impossible. Erreur=%d",
            GetLastError());
   
         return false;
        }
   
      return true;
     }
  
   void Deinit(void)
     {
      if(m_maHandle!=INVALID_HANDLE)
        {
         IndicatorRelease(m_maHandle);
         m_maHandle=INVALID_HANDLE;
        }
     }

   bool Evaluate(SMaPriceCrossSnapshot &snapshot) const
     {
      ZeroMemory(snapshot);
      snapshot.signal=PB_SIGNAL_NONE;

      // Bougie 0 : bougie qui vient de s'ouvrir.
      // Son ouverture servira plus tard de référence d'exécution.
      if(!ReadBarOpenTime(0,snapshot.bar0OpenTime) ||
         !ReadOpenValue(0,snapshot.bar0Open))
        {
         return false;
        }
      
      // Bougies 1 et 2 : bougies clôturées utilisées pour le signal.
      if(!ReadBarOpenTime(1,snapshot.bar1OpenTime) ||
         !ReadHighValue(1,snapshot.bar1High)       ||
         !ReadLowValue(1,snapshot.bar1Low)         ||
         !ReadCloseValue(1,snapshot.bar1Close)     ||
         !ReadCloseValue(2,snapshot.bar2Close)     ||
         !ReadMaValue(1,snapshot.bar1Ma)           ||
         !ReadMaValue(2,snapshot.bar2Ma))
        {
         return false;
        }
        
      // --------------------------------------------------
      // Détection brute du croisement du prix avec la MA.
      // --------------------------------------------------
      bool buyCross=
         snapshot.bar2Close<=snapshot.bar2Ma &&
         snapshot.bar1Close>snapshot.bar1Ma;
      
      bool sellCross=
         snapshot.bar2Close>=snapshot.bar2Ma &&
         snapshot.bar1Close<snapshot.bar1Ma;
      
      
      // --------------------------------------------------
      // Confirmation éventuelle par la pente de la MA.
      //
      // BUY  : la moyenne doit monter.
      // SELL : la moyenne doit descendre.
      // --------------------------------------------------
      bool buySlopeAccepted=
         !m_useMaSlopeFilter ||
         snapshot.bar1Ma>snapshot.bar2Ma;
      
      bool sellSlopeAccepted=
         !m_useMaSlopeFilter ||
         snapshot.bar1Ma<snapshot.bar2Ma;
      
      
      // --------------------------------------------------
      // Décision finale.
      // --------------------------------------------------
      if(buyCross && buySlopeAccepted)
        {
         snapshot.signal=PB_SIGNAL_BUY;
        }
      else if(sellCross && sellSlopeAccepted)
        {
         snapshot.signal=PB_SIGNAL_SELL;
        }
      else
        {
         snapshot.signal=PB_SIGNAL_NONE;
        }
  
      return true;
     }
  };

#endif

#ifndef PB_BZH_MA_PRICE_CROSS_SIGNAL_MQH
#define PB_BZH_MA_PRICE_CROSS_SIGNAL_MQH

#include <PbBzhConcept\Domain\TradeSignal.mqh>
#include <PbBzhConcept\Domain\MaDynamics.mqh>

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
   double bar1Ma;
   double bar2Ma;
   double bar3Ma;
   double bar4Ma;
   
   // --------------------------------------------------
   // Dynamique locale de la moyenne mobile.
   //
   // S0 = pente entre MA[2] et MA[1] : au croisement
   // S1 = pente entre MA[3] et MA[2] : juste avant
   // S2 = pente entre MA[4] et MA[3] : encore avant
   //
   // A0 = S0 - S1 : évolution de pente au croisement
   // A1 = S1 - S2 : évolution de pente avant croisement
   // --------------------------------------------------
   
   // Grandeurs brutes.
   double maSlopePoints;              // S0
   double previousMaSlopePoints;      // S1
   double earlierMaSlopePoints;       // S2
   
   double maAccelerationPoints;       // A0
   double previousMaAccelerationPoints; // A1
   
   // Grandeurs orientées dans le sens du signal.
   double directionalMaSlopePoints;              // S0
   double directionalPreviousMaSlopePoints;      // S1
   double directionalEarlierMaSlopePoints;       // S2
   
   double directionalMaAccelerationPoints;       // A0
   double directionalPreviousMaAccelerationPoints; // A1
   
   // --------------------------------------------------
   // Représentation structurée de la dynamique MA.
   //
   // maDynamics : valeurs mathématiques brutes.
   // directionalMaDynamics : valeurs orientées dans
   // le sens du signal BUY ou SELL.
   // --------------------------------------------------
   SMaDynamics maDynamics;
   SMaDynamics directionalMaDynamics;
   
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
         !ReadMaValue(1,snapshot.bar1Ma) ||
         !ReadMaValue(2,snapshot.bar2Ma) ||
         !ReadMaValue(3,snapshot.bar3Ma) ||
         !ReadMaValue(4,snapshot.bar4Ma))         
        {
         return false;
        }
      
      // --------------------------------------------------
      // Calcul de la pente de la moyenne mobile.
      //
      // La pente est exprimée en points par bougie :
      //    MA[1] - MA[2]
      // --------------------------------------------------
      double point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);
      
      if(point<=0.0)
        {
         PrintFormat(
            "[CMaPriceCrossSignal][ERROR] "
            "Valeur SYMBOL_POINT invalide pour %s.",
            m_symbol);
      
         return false;
        }
      
      // --------------------------------------------------
      // Première dérivée discrète.
      //
      // Les valeurs sont exprimées en points par bougie.
      // --------------------------------------------------
      
      // S0 : pente au moment du croisement.
      snapshot.maSlopePoints=
         (snapshot.bar1Ma-snapshot.bar2Ma)/point;
      
      // S1 : pente juste avant le croisement.
      snapshot.previousMaSlopePoints=
         (snapshot.bar2Ma-snapshot.bar3Ma)/point;
      
      // S2 : pente encore une bougie auparavant.
      snapshot.earlierMaSlopePoints=
         (snapshot.bar3Ma-snapshot.bar4Ma)/point;
           
      // --------------------------------------------------
      // Seconde dérivée discrète.
      //
      // A0 = évolution de la pente entre S1 et S0.
      // A1 = évolution de la pente entre S2 et S1.
      //
      // Unité conceptuelle : points par bougie².
      // --------------------------------------------------
      snapshot.maAccelerationPoints=
         snapshot.maSlopePoints-
         snapshot.previousMaSlopePoints;
      
      snapshot.previousMaAccelerationPoints=
         snapshot.previousMaSlopePoints-
         snapshot.earlierMaSlopePoints;

      // --------------------------------------------------
      // Regroupement de la dynamique brute.
      // --------------------------------------------------
      snapshot.maDynamics.slopeEarlier=
         snapshot.earlierMaSlopePoints;
      
      snapshot.maDynamics.slopePrevious=
         snapshot.previousMaSlopePoints;
      
      snapshot.maDynamics.slopeCurrent=
         snapshot.maSlopePoints;
      
      snapshot.maDynamics.accelerationPrevious=
         snapshot.previousMaAccelerationPoints;
      
      snapshot.maDynamics.accelerationCurrent=
         snapshot.maAccelerationPoints;
      
      
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
      
         snapshot.directionalMaSlopePoints=
            snapshot.maSlopePoints;
      
         snapshot.directionalPreviousMaSlopePoints=
            snapshot.previousMaSlopePoints;
      
         snapshot.directionalEarlierMaSlopePoints=
            snapshot.earlierMaSlopePoints;
      
         snapshot.directionalMaAccelerationPoints=
            snapshot.maAccelerationPoints;
      
         snapshot.directionalPreviousMaAccelerationPoints=
            snapshot.previousMaAccelerationPoints;

         snapshot.directionalMaDynamics.slopeEarlier=
            snapshot.directionalEarlierMaSlopePoints;
         
         snapshot.directionalMaDynamics.slopePrevious=
            snapshot.directionalPreviousMaSlopePoints;
         
         snapshot.directionalMaDynamics.slopeCurrent=
            snapshot.directionalMaSlopePoints;
         
         snapshot.directionalMaDynamics.accelerationPrevious=
            snapshot.directionalPreviousMaAccelerationPoints;
         
         snapshot.directionalMaDynamics.accelerationCurrent=
            snapshot.directionalMaAccelerationPoints;
        }
      else if(sellCross && sellSlopeAccepted)
        {
         snapshot.signal=PB_SIGNAL_SELL;
      
         snapshot.directionalMaSlopePoints=
            -snapshot.maSlopePoints;
      
         snapshot.directionalPreviousMaSlopePoints=
            -snapshot.previousMaSlopePoints;
      
         snapshot.directionalEarlierMaSlopePoints=
            -snapshot.earlierMaSlopePoints;
      
         snapshot.directionalMaAccelerationPoints=
            -snapshot.maAccelerationPoints;
      
         snapshot.directionalPreviousMaAccelerationPoints=
            -snapshot.previousMaAccelerationPoints;
            
         snapshot.directionalMaDynamics.slopeEarlier=
            snapshot.directionalEarlierMaSlopePoints;
         
         snapshot.directionalMaDynamics.slopePrevious=
            snapshot.directionalPreviousMaSlopePoints;
         
         snapshot.directionalMaDynamics.slopeCurrent=
            snapshot.directionalMaSlopePoints;
         
         snapshot.directionalMaDynamics.accelerationPrevious=
            snapshot.directionalPreviousMaAccelerationPoints;
         
         snapshot.directionalMaDynamics.accelerationCurrent=
            snapshot.directionalMaAccelerationPoints;            
        }        
      else
        {
         snapshot.signal=PB_SIGNAL_NONE;
      
         snapshot.directionalMaSlopePoints=0.0;
         snapshot.directionalPreviousMaSlopePoints=0.0;
         snapshot.directionalEarlierMaSlopePoints=0.0;
      
         snapshot.directionalMaAccelerationPoints=0.0;
         snapshot.directionalPreviousMaAccelerationPoints=0.0;
         
         snapshot.directionalMaDynamics.slopeEarlier=0.0;
         snapshot.directionalMaDynamics.slopePrevious=0.0;
         snapshot.directionalMaDynamics.slopeCurrent=0.0;
         
         snapshot.directionalMaDynamics.accelerationPrevious=0.0;
         snapshot.directionalMaDynamics.accelerationCurrent=0.0;
        }
        
      return true;  
     }
  };

#endif

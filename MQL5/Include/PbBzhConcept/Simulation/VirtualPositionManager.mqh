#ifndef PB_BZH_CONCEPT_VIRTUAL_POSITION_MANAGER_MQH
#define PB_BZH_CONCEPT_VIRTUAL_POSITION_MANAGER_MQH

#include <PbBzhConcept/Domain/TradeSignal.mqh>
#include <PbBzhConcept/Simulation/VirtualVolumeCalculator.mqh>


// --------------------------------------------------
// État de la position virtuelle.
// --------------------------------------------------
enum ENUM_PB_VIRTUAL_POSITION_STATE
  {
   PB_VIRTUAL_POSITION_FLAT =0,
   PB_VIRTUAL_POSITION_LONG =1,
   PB_VIRTUAL_POSITION_SHORT=-1
  };


// --------------------------------------------------
// Motif de clôture d'une position virtuelle.
// --------------------------------------------------
enum ENUM_PB_VIRTUAL_EXIT_REASON
  {
   PB_VIRTUAL_EXIT_SIGNAL=0,
   PB_VIRTUAL_EXIT_STOP_LOSS=1,
   PB_VIRTUAL_EXIT_TAKE_PROFIT=2
  };
  
// --------------------------------------------------
// Convertit l'état de position en texte.
// --------------------------------------------------
string VirtualPositionStateToString(
   const ENUM_PB_VIRTUAL_POSITION_STATE state)
  {
   switch(state)
     {
      case PB_VIRTUAL_POSITION_LONG:
         return "LONG";

      case PB_VIRTUAL_POSITION_SHORT:
         return "SHORT";

      case PB_VIRTUAL_POSITION_FLAT:
         return "FLAT";

      default:
         return "INCONNU";
     }
  }


// --------------------------------------------------
// Gère une seule position virtuelle à la fois.
// --------------------------------------------------
class CVirtualPositionManager
  {
private:
   bool   m_isInitialized;

   string m_symbol;
   double m_point;
   int    m_digits;

   string m_accountCurrency;
   int    m_accountCurrencyDigits;

   int    m_stopLossPoints;
   int    m_takeProfitPoints;

   double m_stopLossPrice;
   double m_takeProfitPrice;

   CVirtualVolumeCalculator m_volumeCalculator;

   double m_initialVirtualCapital;
   double m_currentPositionVolumeLots;

   double m_lastOpeningCapital;
   double m_lastTargetRiskMoney;
   double m_lastEstimatedLossAtStop;
   double m_lastOpenedVolumeLots;

   ENUM_PB_VIRTUAL_POSITION_STATE m_state;

   datetime m_entryTime;
   double   m_entryPrice;

   datetime m_lastKnownTime;
   double   m_lastKnownBid;
   double   m_lastKnownAsk;

   int m_openCount;
   int m_closedTradeCount;

   int m_winningTradeCount;
   int m_losingTradeCount;
   int m_breakEvenTradeCount;

   // --------------------------------------------------
   // Statistiques des positions LONG.
   // --------------------------------------------------
   int    m_longClosedTradeCount;
   int    m_longWinningTradeCount;
   int    m_longLosingTradeCount;
   int    m_longBreakEvenTradeCount;
   
   double m_longTotalClosedPoints;
   double m_longTotalClosedMoney;
   
   double m_longGrossProfitMoney;
   double m_longGrossLossMoney;


   // --------------------------------------------------
   // Statistiques des positions SHORT.
   // --------------------------------------------------
   int    m_shortClosedTradeCount;
   int    m_shortWinningTradeCount;
   int    m_shortLosingTradeCount;
   int    m_shortBreakEvenTradeCount;
   
   double m_shortTotalClosedPoints;
   double m_shortTotalClosedMoney;
   
   double m_shortGrossProfitMoney;
   double m_shortGrossLossMoney;
   
   int m_reversalCount;

   int m_signalExitCount;
   int m_stopLossExitCount;
   int m_takeProfitExitCount;

   double m_totalClosedPoints;
   double m_totalClosedMoney;
   
   double m_grossProfitMoney;
   double m_grossLossMoney;

   double m_bestTradePoints;
   double m_worstTradePoints;
   
   int m_currentLosingStreak;
   int m_maxLosingStreak;

   // Plus haut capital virtuel clôturé atteint.
   double m_peakVirtualCapital;
   
   // Drawdown maximal exprimé en devise du compte.
   double m_maxDrawdownMoney;
   
   // Drawdown maximal exprimé en pourcentage
   // du plus haut capital atteint.
   double m_maxDrawdownPercent;

   // Plus haute équité virtuelle observée.
   double m_peakVirtualEquity;
   
   // Drawdown maximal de l'équité en devise du compte.
   double m_maxEquityDrawdownMoney;
   
   // Drawdown maximal de l'équité en pourcentage.
   double m_maxEquityDrawdownPercent;
   
   // Date du sommet actuellement utilisé pour mesurer
   // le drawdown du capital clôturé.
   datetime m_currentCapitalPeakTime;
   
   // Période du drawdown maximal du capital.
   datetime m_maxCapitalDrawdownStartTime;
   datetime m_maxCapitalDrawdownLowTime;
   
   
   // Date du sommet actuellement utilisé pour mesurer
   // le drawdown de l'équité.
   datetime m_currentEquityPeakTime;
   
   // Période du drawdown maximal de l'équité.
   datetime m_maxEquityDrawdownStartTime;
   datetime m_maxEquityDrawdownLowTime;   
   
   // --------------------------------------------------
   // Performances des sorties sur SIGNAL.
   // --------------------------------------------------
   int    m_signalExitWinningCount;
   int    m_signalExitLosingCount;
   int    m_signalExitBreakEvenCount;
   
   double m_signalExitTotalPoints;
   double m_signalExitTotalMoney;
   
   double m_signalExitGrossProfitMoney;
   double m_signalExitGrossLossMoney;
   
   
   // --------------------------------------------------
   // Performances des sorties sur STOP LOSS.
   // --------------------------------------------------
   int    m_stopLossWinningCount;
   int    m_stopLossLosingCount;
   int    m_stopLossBreakEvenCount;
   
   double m_stopLossTotalPoints;
   double m_stopLossTotalMoney;
   
   double m_stopLossGrossProfitMoney;
   double m_stopLossGrossLossMoney;
   
   
   // --------------------------------------------------
   // Performances des sorties sur TAKE PROFIT.
   // --------------------------------------------------
   int    m_takeProfitWinningCount;
   int    m_takeProfitLosingCount;
   int    m_takeProfitBreakEvenCount;
   
   double m_takeProfitTotalPoints;
   double m_takeProfitTotalMoney;
   
   double m_takeProfitGrossProfitMoney;
   double m_takeProfitGrossLossMoney;
   
   // --------------------------------------------------
   // Croisement LONG / motif de sortie.
   // --------------------------------------------------
   int    m_longSignalExitCount;
   double m_longSignalExitMoney;
   
   int    m_longStopLossExitCount;
   double m_longStopLossExitMoney;
   
   int    m_longTakeProfitExitCount;
   double m_longTakeProfitExitMoney;
   
   
   // --------------------------------------------------
   // Croisement SHORT / motif de sortie.
   // --------------------------------------------------
   int    m_shortSignalExitCount;
   double m_shortSignalExitMoney;
   
   int    m_shortStopLossExitCount;
   double m_shortStopLossExitMoney;
   
   int    m_shortTakeProfitExitCount;
   double m_shortTakeProfitExitMoney;
   
   // --------------------------------------------------
   // Ouvre une position virtuelle.
   // --------------------------------------------------
   bool OpenPosition(
      const ENUM_PB_VIRTUAL_POSITION_STATE newState,
      const datetime                       entryTime,
      const double                         entryPrice,
      string                              &errorMessage)
     {
      errorMessage="";

      if(!m_isInitialized)
        {
         errorMessage=
            "Le gestionnaire de positions virtuelles n'est pas initialisé.";

         return false;
        }

      if(m_point<=0.0)
        {
         errorMessage=
            "La valeur du point du symbole est invalide.";

         return false;
        }

      if(newState!=PB_VIRTUAL_POSITION_LONG &&
         newState!=PB_VIRTUAL_POSITION_SHORT)
        {
         errorMessage=
            "État de position invalide lors de l'ouverture.";

         return false;
        }

      if(entryPrice<=0.0)
        {
         errorMessage="Prix d'entrée invalide.";

         return false;
        }

      double stopLossPrice  =0.0;
      double takeProfitPrice=0.0;
      ENUM_ORDER_TYPE orderType;

      if(newState==PB_VIRTUAL_POSITION_LONG)
        {
         orderType=ORDER_TYPE_BUY;

         if(m_stopLossPoints>0)
           {
            stopLossPrice=
               NormalizeDouble(
                  entryPrice-m_stopLossPoints*m_point,
                  m_digits);
           }

         if(m_takeProfitPoints>0)
           {
            takeProfitPrice=
               NormalizeDouble(
                  entryPrice+m_takeProfitPoints*m_point,
                  m_digits);
           }
        }
      else
        {
         orderType=ORDER_TYPE_SELL;

         if(m_stopLossPoints>0)
           {
            stopLossPrice=
               NormalizeDouble(
                  entryPrice+m_stopLossPoints*m_point,
                  m_digits);
           }

         if(m_takeProfitPoints>0)
           {
            takeProfitPrice=
               NormalizeDouble(
                  entryPrice-m_takeProfitPoints*m_point,
                  m_digits);
           }
        }

      double currentVirtualCapital=
         m_initialVirtualCapital+
         m_totalClosedMoney;

      double volumeLots       =0.0;
      double targetRiskMoney  =0.0;
      double estimatedStopLoss=0.0;

      if(!m_volumeCalculator.Calculate(
            orderType,
            currentVirtualCapital,
            entryPrice,
            stopLossPrice,
            volumeLots,
            targetRiskMoney,
            estimatedStopLoss,
            errorMessage))
        {
         return false;
        }

      // Une ouverture avec un volume nul créerait un état
      // incohérent : position LONG/SHORT sans volume.
      if(volumeLots<=0.0)
        {
         errorMessage=StringFormat(
            "Le calculateur de volume a renvoyé un volume invalide : %.8f | %s",
            volumeLots,
            m_volumeCalculator.BuildModeSummary());

         return false;
        }

      m_state      =newState;
      m_entryTime  =entryTime;
      m_entryPrice =entryPrice;

      m_stopLossPrice  =stopLossPrice;
      m_takeProfitPrice=takeProfitPrice;

      m_currentPositionVolumeLots=volumeLots;

      m_lastOpeningCapital      =currentVirtualCapital;
      m_lastTargetRiskMoney     =targetRiskMoney;
      m_lastEstimatedLossAtStop =estimatedStopLoss;
      m_lastOpenedVolumeLots    =volumeLots;

      m_openCount++;

      return true;
     }


   // --------------------------------------------------
   // Résume le dimensionnement de la dernière position.
   // --------------------------------------------------
   string BuildLastOpeningVolumeSummary(void) const
     {
      string result=StringFormat(
         "Volume=%s lot(s) | "
         "Capital virtuel=%.*f %s",

         m_volumeCalculator.FormatVolume(
            m_lastOpenedVolumeLots),

         m_accountCurrencyDigits,
         m_lastOpeningCapital,

         m_accountCurrency);

      if(m_lastTargetRiskMoney>0.0)
        {
         result+=StringFormat(
            " | Risque cible=%.*f %s",

            m_accountCurrencyDigits,
            m_lastTargetRiskMoney,

            m_accountCurrency);
        }

      if(m_lastEstimatedLossAtStop>0.0)
        {
         result+=StringFormat(
            " | Perte estimée au SL=%.*f %s",

            m_accountCurrencyDigits,
            m_lastEstimatedLossAtStop,

            m_accountCurrency);
        }

      return result;
     }


   // --------------------------------------------------
   // Calcule le résultat monétaire d'une position.
   // --------------------------------------------------
   bool CalculateMoneyResult(
      const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
      const double                         openPrice,
      const double                         closePrice,
      double                              &resultMoney,
      string                              &errorMessage) const
     {
      resultMoney =0.0;
      errorMessage="";

      if(!m_isInitialized)
        {
         errorMessage=
            "Le gestionnaire de positions virtuelles n'est pas initialisé.";

         return false;
        }

      if(openPrice<=0.0 || closePrice<=0.0)
        {
         errorMessage=StringFormat(
            "Prix invalide pour le calcul monétaire | Ouverture=%.*f | Fermeture=%.*f",
            m_digits,
            openPrice,
            m_digits,
            closePrice);

         return false;
        }

      if(m_currentPositionVolumeLots<=0.0)
        {
         errorMessage=
            "Le volume de la position virtuelle est invalide.";

         return false;
        }

      ENUM_ORDER_TYPE orderType;

      if(positionState==PB_VIRTUAL_POSITION_LONG)
        {
         orderType=ORDER_TYPE_BUY;
        }
      else if(positionState==PB_VIRTUAL_POSITION_SHORT)
        {
         orderType=ORDER_TYPE_SELL;
        }
      else
        {
         errorMessage=
            "Calcul monétaire impossible : "
            "aucune position n'est ouverte.";

         return false;
        }

      ResetLastError();

      if(!OrderCalcProfit(
            orderType,
            m_symbol,
            m_currentPositionVolumeLots,
            openPrice,
            closePrice,
            resultMoney))
        {
         int errorCode=GetLastError();

         errorMessage=StringFormat(
            "OrderCalcProfit a échoué | "
            "Position=%s | Volume=%s | "
            "Ouverture=%.*f | Fermeture=%.*f | "
            "Erreur=%d",

            VirtualPositionStateToString(
               positionState),

            m_volumeCalculator.FormatVolume(
               m_currentPositionVolumeLots),

            m_digits,
            openPrice,

            m_digits,
            closePrice,

            errorCode);

         return false;
        }

      return true;
     }

   // --------------------------------------------------
   // Met à jour le drawdown de l'équité virtuelle.
   //
   // Équité virtuelle :
   //   capital initial
   //   + résultats clôturés
   //   + résultat latent de la position ouverte
   // --------------------------------------------------
   bool UpdateEquityDrawdown(
      const datetime tickTime,
      const double   bid,
      const double   ask,
      string        &errorMessage)      
     {
      errorMessage="";

      if(!m_isInitialized)
        {
         errorMessage=
            "Le gestionnaire de positions virtuelles n'est pas initialisé.";

         return false;
        }
   
      double currentVirtualEquity=
         m_initialVirtualCapital+
         m_totalClosedMoney;
   
   
      // ------------------------------------------------
      // Ajout du résultat latent lorsqu'une position
      // virtuelle est ouverte.
      // ------------------------------------------------
      if(m_state!=PB_VIRTUAL_POSITION_FLAT)
        {
         double theoreticalExitPrice=
            (m_state==PB_VIRTUAL_POSITION_LONG)
            ? bid
            : ask;
   
         double latentMoney=0.0;
   
         if(!CalculateMoneyResult(
               m_state,
               m_entryPrice,
               theoreticalExitPrice,
               latentMoney,
               errorMessage))
           {
            return false;
           }
   
         currentVirtualEquity+=latentMoney;
        }
   
   
      // ------------------------------------------------
      // Nouveau sommet d'équité.
      // ------------------------------------------------
      if(currentVirtualEquity>m_peakVirtualEquity)
        {
         m_peakVirtualEquity=
            currentVirtualEquity;
      
         m_currentEquityPeakTime=
            tickTime;
        }   
   
      // ------------------------------------------------
      // Drawdown courant depuis le sommet de l'équité.
      // ------------------------------------------------
      double currentDrawdownMoney=
         m_peakVirtualEquity-
         currentVirtualEquity;
   
      if(currentDrawdownMoney<0.0)
         currentDrawdownMoney=0.0;
   
   
      double currentDrawdownPercent=0.0;
   
      if(m_peakVirtualEquity>0.0)
        {
         currentDrawdownPercent=
            currentDrawdownMoney/
            m_peakVirtualEquity*
            100.0;
        }
   
   
      // ------------------------------------------------
      // Conservation du pire drawdown observé.
      // ------------------------------------------------
      if(currentDrawdownMoney>
         m_maxEquityDrawdownMoney)
        {
         m_maxEquityDrawdownMoney=
            currentDrawdownMoney;
      
         m_maxEquityDrawdownPercent=
            currentDrawdownPercent;
      
         m_maxEquityDrawdownStartTime=
            m_currentEquityPeakTime;
      
         m_maxEquityDrawdownLowTime=
            tickTime;
        }   
      return true;
     }

// --------------------------------------------------
// Enregistre les performances selon le motif
// de clôture et le sens de la position.
// --------------------------------------------------
void RecordExitPerformance(
   const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
   const ENUM_PB_VIRTUAL_EXIT_REASON     exitReason,
   const double                          resultPoints,
   const double                          resultMoney)
  {
   // ==================================================
   // SORTIE SUR SIGNAL
   // ==================================================
   if(exitReason==PB_VIRTUAL_EXIT_SIGNAL)
     {
      m_signalExitTotalPoints+=resultPoints;
      m_signalExitTotalMoney +=resultMoney;

      if(resultPoints>0.0)
        {
         m_signalExitWinningCount++;
         m_signalExitGrossProfitMoney+=resultMoney;
        }
      else if(resultPoints<0.0)
        {
         m_signalExitLosingCount++;
         m_signalExitGrossLossMoney+=MathAbs(resultMoney);
        }
      else
        {
         m_signalExitBreakEvenCount++;
        }


      // Croisement sens × motif.
      if(positionState==PB_VIRTUAL_POSITION_LONG)
        {
         m_longSignalExitCount++;
         m_longSignalExitMoney+=resultMoney;
        }
      else if(positionState==PB_VIRTUAL_POSITION_SHORT)
        {
         m_shortSignalExitCount++;
         m_shortSignalExitMoney+=resultMoney;
        }

      return;
     }


   // ==================================================
   // SORTIE SUR STOP LOSS
   // ==================================================
   if(exitReason==PB_VIRTUAL_EXIT_STOP_LOSS)
     {
      m_stopLossTotalPoints+=resultPoints;
      m_stopLossTotalMoney +=resultMoney;

      if(resultPoints>0.0)
        {
         m_stopLossWinningCount++;
         m_stopLossGrossProfitMoney+=resultMoney;
        }
      else if(resultPoints<0.0)
        {
         m_stopLossLosingCount++;
         m_stopLossGrossLossMoney+=MathAbs(resultMoney);
        }
      else
        {
         m_stopLossBreakEvenCount++;
        }


      // Croisement sens × motif.
      if(positionState==PB_VIRTUAL_POSITION_LONG)
        {
         m_longStopLossExitCount++;
         m_longStopLossExitMoney+=resultMoney;
        }
      else if(positionState==PB_VIRTUAL_POSITION_SHORT)
        {
         m_shortStopLossExitCount++;
         m_shortStopLossExitMoney+=resultMoney;
        }

      return;
     }


   // ==================================================
   // SORTIE SUR TAKE PROFIT
   // ==================================================
   if(exitReason==PB_VIRTUAL_EXIT_TAKE_PROFIT)
     {
      m_takeProfitTotalPoints+=resultPoints;
      m_takeProfitTotalMoney +=resultMoney;

      if(resultPoints>0.0)
        {
         m_takeProfitWinningCount++;
         m_takeProfitGrossProfitMoney+=resultMoney;
        }
      else if(resultPoints<0.0)
        {
         m_takeProfitLosingCount++;
         m_takeProfitGrossLossMoney+=MathAbs(resultMoney);
        }
      else
        {
         m_takeProfitBreakEvenCount++;
        }


      // Croisement sens × motif.
      if(positionState==PB_VIRTUAL_POSITION_LONG)
        {
         m_longTakeProfitExitCount++;
         m_longTakeProfitExitMoney+=resultMoney;
        }
      else if(positionState==PB_VIRTUAL_POSITION_SHORT)
        {
         m_shortTakeProfitExitCount++;
         m_shortTakeProfitExitMoney+=resultMoney;
        }
     }
  }
  
   // --------------------------------------------------
   // Enregistre le résultat d'un trade clôturé.
   // --------------------------------------------------
   void RecordClosedTrade(
      const datetime                       exitTime,
      const ENUM_PB_VIRTUAL_POSITION_STATE positionState,
      const double                         resultPoints,
      const double                         resultMoney)          
     {
      m_closedTradeCount++;

      m_totalClosedPoints+=resultPoints;
      m_totalClosedMoney +=resultMoney;

   // --------------------------------------------------
   // Mise à jour du capital virtuel après clôture.
   // --------------------------------------------------
   double currentVirtualCapital=
      m_initialVirtualCapital+
      m_totalClosedMoney;


   if(currentVirtualCapital>m_peakVirtualCapital)
     {
      m_peakVirtualCapital=
         currentVirtualCapital;
   
      m_currentCapitalPeakTime=
         exitTime;
     }   
   
   // Le capital est sous son précédent sommet.
   double currentDrawdownMoney=
      m_peakVirtualCapital-
      currentVirtualCapital;
   
   if(currentDrawdownMoney<0.0)
      currentDrawdownMoney=0.0;
   
   
   double currentDrawdownPercent=0.0;
   
   if(m_peakVirtualCapital>0.0)
     {
      currentDrawdownPercent=
         currentDrawdownMoney/
         m_peakVirtualCapital*
         100.0;
     }   
   
   // Conservation du pire drawdown observé.
   if(currentDrawdownMoney>m_maxDrawdownMoney)
     {
      m_maxDrawdownMoney=
         currentDrawdownMoney;
   
      m_maxDrawdownPercent=
         currentDrawdownPercent;
   
      m_maxCapitalDrawdownStartTime=
         m_currentCapitalPeakTime;
   
      m_maxCapitalDrawdownLowTime=
         exitTime;
     }
     
      if(resultPoints>0.0)
        {
         m_winningTradeCount++;
      
         m_grossProfitMoney+=resultMoney;
      
         // Un trade gagnant interrompt la série de pertes.
         m_currentLosingStreak=0;
        }
      else if(resultPoints<0.0)
        {
         m_losingTradeCount++;
      
         m_grossLossMoney+=MathAbs(resultMoney);
      
         // La série de pertes se poursuit.
         m_currentLosingStreak++;
      
         if(m_currentLosingStreak>m_maxLosingStreak)
           {
            m_maxLosingStreak=
               m_currentLosingStreak;
           }
        }
      else
        {
         m_breakEvenTradeCount++;
      
         // Un trade neutre interrompt également la série.
         m_currentLosingStreak=0;
        }  
        
      // --------------------------------------------------
      // Statistiques selon le sens de la position clôturée.
      // --------------------------------------------------
      if(positionState==PB_VIRTUAL_POSITION_LONG)
        {
         m_longClosedTradeCount++;
      
         m_longTotalClosedPoints+=resultPoints;
         m_longTotalClosedMoney +=resultMoney;
      
         if(resultPoints>0.0)
           {
            m_longWinningTradeCount++;
            m_longGrossProfitMoney+=resultMoney;
           }
         else if(resultPoints<0.0)
           {
            m_longLosingTradeCount++;
            m_longGrossLossMoney+=MathAbs(resultMoney);
           }
         else
           {
            m_longBreakEvenTradeCount++;
           }
        }
      else if(positionState==PB_VIRTUAL_POSITION_SHORT)
        {
         m_shortClosedTradeCount++;
      
         m_shortTotalClosedPoints+=resultPoints;
         m_shortTotalClosedMoney +=resultMoney;
      
         if(resultPoints>0.0)
           {
            m_shortWinningTradeCount++;
            m_shortGrossProfitMoney+=resultMoney;
           }
         else if(resultPoints<0.0)
           {
            m_shortLosingTradeCount++;
            m_shortGrossLossMoney+=MathAbs(resultMoney);
           }
         else
           {
            m_shortBreakEvenTradeCount++;
           }
        }

      if(m_closedTradeCount==1)
        {
         m_bestTradePoints =resultPoints;
         m_worstTradePoints=resultPoints;
        }
      else
        {
         if(resultPoints>m_bestTradePoints)
            m_bestTradePoints=resultPoints;

         if(resultPoints<m_worstTradePoints)
            m_worstTradePoints=resultPoints;
        }
     }


   // --------------------------------------------------
   // Ferme la position virtuelle actuelle.
   // --------------------------------------------------
   bool CloseCurrentPosition(
      const datetime exitTime,
      const double   exitPrice,
      double        &resultPoints,
      double        &resultMoney,
      string        &errorMessage)
     {
      resultPoints=0.0;
      resultMoney =0.0;
      errorMessage="";

      if(!m_isInitialized)
        {
         errorMessage=
            "Le gestionnaire de positions virtuelles n'est pas initialisé.";

         return false;
        }

      if(m_point<=0.0)
        {
         errorMessage=
            "La valeur du point du symbole est invalide.";

         return false;
        }

      if(m_state==PB_VIRTUAL_POSITION_FLAT)
        {
         errorMessage=
            "Aucune position virtuelle à clôturer.";

         return false;
        }

      if(exitPrice<=0.0 || m_entryPrice<=0.0)
        {
         errorMessage=StringFormat(
            "Prix invalide lors de la clôture | "
            "Entrée=%.*f | Sortie=%.*f",

            m_digits,
            m_entryPrice,

            m_digits,
            exitPrice);

         return false;
        }

      if(m_state==PB_VIRTUAL_POSITION_LONG)
        {
         resultPoints=
            (exitPrice-m_entryPrice)/m_point;
        }
      else
        {
         resultPoints=
            (m_entryPrice-exitPrice)/m_point;
        }

      if(!CalculateMoneyResult(
            m_state,
            m_entryPrice,
            exitPrice,
            resultMoney,
            errorMessage))
        {
         return false;
        }

      RecordClosedTrade(
         exitTime,
         m_state,
         resultPoints,
         resultMoney);
      
      m_lastKnownTime=exitTime;

      m_state      =PB_VIRTUAL_POSITION_FLAT;
      m_entryTime  =0;
      m_entryPrice =0.0;

      m_stopLossPrice  =0.0;
      m_takeProfitPrice=0.0;

      m_currentPositionVolumeLots=0.0;

      return true;
     }


public:

   // --------------------------------------------------
   // Constructeur.
   // --------------------------------------------------
   CVirtualPositionManager(void)
     {
      m_isInitialized=false;

      m_symbol="";
      m_point =0.0;
      m_digits=0;

      m_accountCurrency      ="";
      m_accountCurrencyDigits=2;

      m_stopLossPoints  =0;
      m_takeProfitPoints=0;

      m_initialVirtualCapital    =0.0;
      m_currentPositionVolumeLots=0.0;

      m_lastOpeningCapital       =0.0;
      m_lastTargetRiskMoney      =0.0;
      m_lastEstimatedLossAtStop  =0.0;
      m_lastOpenedVolumeLots     =0.0;

      Reset();
     }


   // --------------------------------------------------
   // Réinitialise l'état et les statistiques.
   // --------------------------------------------------
   void Reset(void)
     {
      m_state=PB_VIRTUAL_POSITION_FLAT;

      m_entryTime =0;
      m_entryPrice=0.0;

      m_stopLossPrice  =0.0;
      m_takeProfitPrice=0.0;

      m_lastKnownTime=0;
      m_lastKnownBid =0.0;
      m_lastKnownAsk =0.0;

      m_currentPositionVolumeLots=0.0;

      m_lastOpeningCapital      =0.0;
      m_lastTargetRiskMoney     =0.0;
      m_lastEstimatedLossAtStop =0.0;
      m_lastOpenedVolumeLots    =0.0;

      m_openCount       =0;
      m_closedTradeCount=0;

      m_winningTradeCount =0;
      m_losingTradeCount  =0;
      m_breakEvenTradeCount=0;
      
      // Statistiques LONG.
      m_longClosedTradeCount  =0;
      m_longWinningTradeCount =0;
      m_longLosingTradeCount  =0;
      m_longBreakEvenTradeCount=0;
      
      m_longTotalClosedPoints=0.0;
      m_longTotalClosedMoney =0.0;
      
      m_longGrossProfitMoney=0.0;
      m_longGrossLossMoney  =0.0;
      
      
      // Statistiques SHORT.
      m_shortClosedTradeCount  =0;
      m_shortWinningTradeCount =0;
      m_shortLosingTradeCount  =0;
      m_shortBreakEvenTradeCount=0;
      
      m_shortTotalClosedPoints=0.0;
      m_shortTotalClosedMoney =0.0;
      
      m_shortGrossProfitMoney=0.0;
      m_shortGrossLossMoney  =0.0;
 
      // --------------------------------------------------
      // Performances sorties SIGNAL.
      // --------------------------------------------------
      m_signalExitWinningCount   =0;
      m_signalExitLosingCount    =0;
      m_signalExitBreakEvenCount =0;
      
      m_signalExitTotalPoints=0.0;
      m_signalExitTotalMoney =0.0;
      
      m_signalExitGrossProfitMoney=0.0;
      m_signalExitGrossLossMoney  =0.0;
      
      
      // --------------------------------------------------
      // Performances sorties STOP LOSS.
      // --------------------------------------------------
      m_stopLossWinningCount   =0;
      m_stopLossLosingCount    =0;
      m_stopLossBreakEvenCount =0;
      
      m_stopLossTotalPoints=0.0;
      m_stopLossTotalMoney =0.0;
      
      m_stopLossGrossProfitMoney=0.0;
      m_stopLossGrossLossMoney  =0.0;
      
      
      // --------------------------------------------------
      // Performances sorties TAKE PROFIT.
      // --------------------------------------------------
      m_takeProfitWinningCount   =0;
      m_takeProfitLosingCount    =0;
      m_takeProfitBreakEvenCount =0;
      
      m_takeProfitTotalPoints=0.0;
      m_takeProfitTotalMoney =0.0;
      
      m_takeProfitGrossProfitMoney=0.0;
      m_takeProfitGrossLossMoney  =0.0;
      
      m_currentLosingStreak=0;
      m_maxLosingStreak    =0;

      m_reversalCount=0;

      m_signalExitCount    =0;
      m_stopLossExitCount  =0;
      m_takeProfitExitCount=0;

      m_totalClosedPoints=0.0;
      m_totalClosedMoney =0.0;
      
      m_grossProfitMoney=0.0;
      m_grossLossMoney  =0.0;
      
      // Lors de l'appel depuis Init(), le capital initial
      // a déjà été chargé.
      m_peakVirtualCapital=m_initialVirtualCapital;
      
      m_maxDrawdownMoney  =0.0;
      m_maxDrawdownPercent=0.0;    
      
      m_currentCapitalPeakTime       =0;
      m_maxCapitalDrawdownStartTime  =0;
      m_maxCapitalDrawdownLowTime    =0;
      m_currentEquityPeakTime        =0;
      m_maxEquityDrawdownStartTime   =0;
      m_maxEquityDrawdownLowTime     =0;  
      
      m_peakVirtualEquity=m_initialVirtualCapital;
      
      m_maxEquityDrawdownMoney  =0.0;
      m_maxEquityDrawdownPercent=0.0;      

      m_bestTradePoints =0.0;
      m_worstTradePoints=0.0;
      
      // --------------------------------------------------
      // Croisement LONG / motif de sortie.
      // --------------------------------------------------
      m_longSignalExitCount=0;
      m_longSignalExitMoney=0.0;
      
      m_longStopLossExitCount=0;
      m_longStopLossExitMoney=0.0;
      
      m_longTakeProfitExitCount=0;
      m_longTakeProfitExitMoney=0.0;
      
      
      // --------------------------------------------------
      // Croisement SHORT / motif de sortie.
      // --------------------------------------------------
      m_shortSignalExitCount=0;
      m_shortSignalExitMoney=0.0;
      
      m_shortStopLossExitCount=0;
      m_shortStopLossExitMoney=0.0;
      
      m_shortTakeProfitExitCount=0;
      m_shortTakeProfitExitMoney=0.0;
     }


   // --------------------------------------------------
   // Initialise le gestionnaire.
   // --------------------------------------------------
   bool Init(
      const string                      symbol,
      const int                         stopLossPoints,
      const int                         takeProfitPoints,
      const ENUM_PB_VIRTUAL_VOLUME_MODE volumeMode,
      const double                      fixedVolumeLots,
      const double                      riskPercent,
      string                           &errorMessage)
     {
      errorMessage="";
      m_isInitialized=false;

      m_symbol=symbol;

      if(m_symbol=="")
        {
         errorMessage="Le symbole est vide.";
         return false;
        }

      m_point=
         SymbolInfoDouble(
            m_symbol,
            SYMBOL_POINT);

      m_digits=
         (int)SymbolInfoInteger(
            m_symbol,
            SYMBOL_DIGITS);

      if(m_point<=0.0 || m_digits<0)
        {
         errorMessage=
            "Les propriétés de prix du symbole sont invalides.";

         return false;
        }

      m_stopLossPoints=
         (stopLossPoints<0)
         ? 0
         : stopLossPoints;

      m_takeProfitPoints=
         (takeProfitPoints<0)
         ? 0
         : takeProfitPoints;

      if(volumeMode==PB_VIRTUAL_VOLUME_RISK_PERCENT &&
         m_stopLossPoints<=0)
        {
         errorMessage=
            "Le mode de volume RISQUE nécessite "
            "un Stop Loss supérieur à zéro.";

         return false;
        }

      m_accountCurrency=
         AccountInfoString(
            ACCOUNT_CURRENCY);

      m_accountCurrencyDigits=
         (int)AccountInfoInteger(
            ACCOUNT_CURRENCY_DIGITS);

      if(m_accountCurrency=="")
        {
         errorMessage=
            "Impossible de déterminer la devise du compte.";

         return false;
        }

      if(!m_volumeCalculator.Init(
            m_symbol,
            volumeMode,
            fixedVolumeLots,
            riskPercent,
            errorMessage))
        {
         return false;
        }

      m_initialVirtualCapital=
         AccountInfoDouble(
            ACCOUNT_BALANCE);

      if(m_initialVirtualCapital<=0.0)
        {
         errorMessage=StringFormat(
            "Capital initial invalide : %.2f",
            m_initialVirtualCapital);

         return false;
        }

      Reset();
      m_isInitialized=true;

      return true;
     }


   // --------------------------------------------------
   // Surveille SL et TP à chaque tick.
   // --------------------------------------------------
   bool ProcessTick(
      const datetime tickTime,
      const double   bid,
      const double   ask,
      string        &eventMessage)
     {
      eventMessage="";

      if(!m_isInitialized)
        {
         eventMessage=
            "Le gestionnaire de positions virtuelles n'est pas initialisé.";

         return false;
        }

      if(bid<=0.0 || ask<=0.0 || ask<bid)
        {
         eventMessage=StringFormat(
            "Cotation invalide : Bid=%.*f Ask=%.*f",

            m_digits,
            bid,

            m_digits,
            ask);

         return false;
        }

      m_lastKnownTime=tickTime;
      m_lastKnownBid =bid;
      m_lastKnownAsk =ask;
      
      
      // --------------------------------------------------
      // L'équité est contrôlée à chaque tick, avant une
      // éventuelle fermeture au Stop Loss ou Take Profit.
      // --------------------------------------------------
      string equityError;
      
      // Le premier tick représente le sommet initial,
      // correspondant au capital de départ.
      if(m_currentCapitalPeakTime==0)
        {
         m_currentCapitalPeakTime=
            tickTime;
        }
      
      if(m_currentEquityPeakTime==0)
        {
         m_currentEquityPeakTime=
            tickTime;
        }      
      
      if(!UpdateEquityDrawdown(
            tickTime,
            bid,
            ask,
            equityError))            
        {
         eventMessage=StringFormat(
            "Calcul du drawdown d'équité impossible : %s",
            equityError);
      
         return false;
        }
      
      
      if(m_state==PB_VIRTUAL_POSITION_FLAT)
         return true;
   
      bool   stopLossHit =false;
      bool   takeProfitHit=false;
      double exitPrice   =0.0;
      double triggerPrice=0.0;

      if(m_state==PB_VIRTUAL_POSITION_LONG)
        {
         exitPrice=bid;

         if(m_stopLossPrice>0.0 &&
            bid<=m_stopLossPrice)
           {
            stopLossHit =true;
            triggerPrice=m_stopLossPrice;
           }
         else if(m_takeProfitPrice>0.0 &&
                 bid>=m_takeProfitPrice)
           {
            takeProfitHit=true;
            triggerPrice  =m_takeProfitPrice;
           }
        }
      else
        {
         exitPrice=ask;

         if(m_stopLossPrice>0.0 &&
            ask>=m_stopLossPrice)
           {
            stopLossHit =true;
            triggerPrice=m_stopLossPrice;
           }
         else if(m_takeProfitPrice>0.0 &&
                 ask<=m_takeProfitPrice)
           {
            takeProfitHit=true;
            triggerPrice  =m_takeProfitPrice;
           }
        }

      if(!stopLossHit && !takeProfitHit)
         return true;

      ENUM_PB_VIRTUAL_POSITION_STATE previousState=
         m_state;

      datetime previousEntryTime =m_entryTime;
      double   previousEntryPrice=m_entryPrice;
      double   previousVolume    =m_currentPositionVolumeLots;

      double resultPoints=0.0;
      double resultMoney =0.0;
      string closeError;

      if(!CloseCurrentPosition(
            tickTime,
            exitPrice,
            resultPoints,
            resultMoney,
            closeError))
        {
         eventMessage=closeError;
         return false;
        }

      string exitReason;

      if(stopLossHit)
        {
         m_stopLossExitCount++;
      
         RecordExitPerformance(
            previousState,
            PB_VIRTUAL_EXIT_STOP_LOSS,
            resultPoints,
            resultMoney);
      
         exitReason="STOP LOSS";
        }
      else
        {
         m_takeProfitExitCount++;
      
         RecordExitPerformance(
            previousState,
            PB_VIRTUAL_EXIT_TAKE_PROFIT,
            resultPoints,
            resultMoney);
      
         exitReason="TAKE PROFIT";
        }  
                 
      eventMessage=StringFormat(
         "SORTIE VIRTUELLE %s | "
         "Position=%s | "
         "Ouverte le %s à %.*f | "
         "Volume=%s lot(s) | "
         "Niveau=%.*f | "
         "Bid=%.*f Ask=%.*f | "
         "Sortie=%.*f | "
         "Résultat=%.1f points | "
         "Résultat monétaire=%.*f %s",

         exitReason,

         VirtualPositionStateToString(
            previousState),

         TimeToString(
            previousEntryTime,
            TIME_DATE|TIME_MINUTES),

         m_digits,
         previousEntryPrice,

         m_volumeCalculator.FormatVolume(
            previousVolume),

         m_digits,
         triggerPrice,

         m_digits,
         bid,

         m_digits,
         ask,

         m_digits,
         exitPrice,

         resultPoints,

         m_accountCurrencyDigits,
         resultMoney,

         m_accountCurrency);

      return true;
     }


   // --------------------------------------------------
   // Traite le signal à la nouvelle bougie.
   // --------------------------------------------------
   bool ProcessSignal(
      const ENUM_PB_TRADE_SIGNAL signal,
      const datetime             executionTime,
      const double               bid,
      const double               ask,
      string                    &eventMessage)
     {
      eventMessage="";

      if(!m_isInitialized)
        {
         eventMessage=
            "Le gestionnaire de positions virtuelles n'est pas initialisé.";

         return false;
        }

      if(bid<=0.0 || ask<=0.0 || ask<bid)
        {
         eventMessage=StringFormat(
            "Cotation invalide : Bid=%.*f Ask=%.*f",

            m_digits,
            bid,

            m_digits,
            ask);

         return false;
        }

      m_lastKnownTime=executionTime;
      m_lastKnownBid =bid;
      m_lastKnownAsk =ask;

      if(signal==PB_SIGNAL_NONE)
         return true;

      ENUM_PB_VIRTUAL_POSITION_STATE newState;
      double newEntryPrice=0.0;

      if(signal==PB_SIGNAL_BUY)
        {
         newState     =PB_VIRTUAL_POSITION_LONG;
         newEntryPrice=ask;
        }
      else if(signal==PB_SIGNAL_SELL)
        {
         newState     =PB_VIRTUAL_POSITION_SHORT;
         newEntryPrice=bid;
        }
      else
        {
         eventMessage="Signal inconnu.";
         return false;
        }

      if(m_state==PB_VIRTUAL_POSITION_FLAT)
        {
         string openError;

         if(!OpenPosition(
               newState,
               executionTime,
               newEntryPrice,
               openError))
           {
            eventMessage=StringFormat(
               "Ouverture virtuelle impossible : %s",
               openError);

            return false;
           }

         eventMessage=StringFormat(
            "OUVERTURE VIRTUELLE | "
            "Position=%s | "
            "Bid=%.*f Ask=%.*f | "
            "Entrée=%.*f | "
            "SL=%.*f | TP=%.*f",

            VirtualPositionStateToString(
               m_state),

            m_digits,
            bid,

            m_digits,
            ask,

            m_digits,
            m_entryPrice,

            m_digits,
            m_stopLossPrice,

            m_digits,
            m_takeProfitPrice);

         eventMessage+=
            " | "+
            BuildLastOpeningVolumeSummary();

         return true;
        }

      if(m_state==newState)
         return true;

      ENUM_PB_VIRTUAL_POSITION_STATE previousState=
         m_state;

      datetime previousEntryTime =m_entryTime;
      double   previousEntryPrice=m_entryPrice;
      double   previousVolume    =m_currentPositionVolumeLots;

      double exitPrice=
         (previousState==PB_VIRTUAL_POSITION_LONG)
         ? bid
         : ask;

      double resultPoints=0.0;
      double resultMoney =0.0;
      string closeError;

      if(!CloseCurrentPosition(
            executionTime,
            exitPrice,
            resultPoints,
            resultMoney,
            closeError))
        {
         eventMessage=closeError;
         return false;
        }

      m_signalExitCount++;
      
      RecordExitPerformance(
         previousState,
         PB_VIRTUAL_EXIT_SIGNAL,
         resultPoints,
         resultMoney);
         
      string openError;

      if(!OpenPosition(
            newState,
            executionTime,
            newEntryPrice,
            openError))
        {
         eventMessage=StringFormat(
            "La position précédente a été fermée, "
            "mais l'ouverture opposée a échoué : %s",
            openError);

         return false;
        }

      m_reversalCount++;

      eventMessage=StringFormat(
         "INVERSION VIRTUELLE | "
         "Bid=%.*f Ask=%.*f | "
         "Fermeture %s ouverte le %s à %.*f | "
         "Volume précédent=%s lot(s) | "
         "Sortie=%.*f | "
         "Résultat=%.1f points | "
         "Résultat monétaire=%.*f %s | "
         "Ouverture %s à %.*f",

         m_digits,
         bid,

         m_digits,
         ask,

         VirtualPositionStateToString(
            previousState),

         TimeToString(
            previousEntryTime,
            TIME_DATE|TIME_MINUTES),

         m_digits,
         previousEntryPrice,

         m_volumeCalculator.FormatVolume(
            previousVolume),

         m_digits,
         exitPrice,

         resultPoints,

         m_accountCurrencyDigits,
         resultMoney,

         m_accountCurrency,

         VirtualPositionStateToString(
            m_state),

         m_digits,
         newEntryPrice);

      eventMessage+=
         " | Nouvelle position : "+
         BuildLastOpeningVolumeSummary();

      return true;
     }


   // --------------------------------------------------
   // Vérifie les invariants des statistiques.
   // --------------------------------------------------
   bool IsConsistent(void) const
     {
      if(!m_isInitialized)
         return false;

      if(m_closedTradeCount !=
         m_winningTradeCount+
         m_losingTradeCount+
         m_breakEvenTradeCount)
        {
         return false;
        }

      if(m_closedTradeCount !=
         m_signalExitCount+
         m_stopLossExitCount+
         m_takeProfitExitCount)
        {
         return false;
        }

      int expectedOpenDifference=
         (m_state==PB_VIRTUAL_POSITION_FLAT)
         ? 0
         : 1;

      if(m_openCount-m_closedTradeCount !=
         expectedOpenDifference)
        {
         return false;
        }

      if(m_state==PB_VIRTUAL_POSITION_FLAT &&
         m_currentPositionVolumeLots!=0.0)
        {
         return false;
        }

      if(m_state!=PB_VIRTUAL_POSITION_FLAT &&
         m_currentPositionVolumeLots<=0.0)
        {
         return false;
        }

      if(m_currentLosingStreak<0 ||
         m_maxLosingStreak<0 ||
         m_currentLosingStreak>m_maxLosingStreak ||
         m_maxLosingStreak>m_losingTradeCount)
        {
         return false;
        }

      if(m_peakVirtualCapital<m_initialVirtualCapital ||
         m_maxDrawdownMoney<0.0 ||
         m_maxDrawdownPercent<0.0 ||
         m_maxDrawdownPercent>100.0)
        {
         return false;
        }

      if(m_peakVirtualEquity<m_initialVirtualCapital ||
         m_maxEquityDrawdownMoney<0.0 ||
         m_maxEquityDrawdownPercent<0.0 ||
         m_maxEquityDrawdownPercent>100.0)
        {
         return false;
        }

      if(m_maxDrawdownMoney>0.0)
        {
         if(m_maxCapitalDrawdownStartTime<=0 ||
            m_maxCapitalDrawdownLowTime<=0 ||
            m_maxCapitalDrawdownStartTime>
            m_maxCapitalDrawdownLowTime)
           {
            return false;
           }
        }
      
      
      if(m_maxEquityDrawdownMoney>0.0)
        {
         if(m_maxEquityDrawdownStartTime<=0 ||
            m_maxEquityDrawdownLowTime<=0 ||
            m_maxEquityDrawdownStartTime>
            m_maxEquityDrawdownLowTime)
           {
            return false;
           }
        }

      // --------------------------------------------------
      // Cohérence des statistiques LONG / SHORT.
      // --------------------------------------------------
      
      // Tous les trades clôturés doivent être soit LONG,
      // soit SHORT.
      if(m_longClosedTradeCount+
         m_shortClosedTradeCount!=
         m_closedTradeCount)
         return false;


      // Même contrôle pour les trades gagnants.
      if(m_longWinningTradeCount+
         m_shortWinningTradeCount!=
         m_winningTradeCount)
         return false;
      
      
      // Même contrôle pour les trades perdants.
      if(m_longLosingTradeCount+
         m_shortLosingTradeCount!=
         m_losingTradeCount)
         return false;
      
      
      // Même contrôle pour les trades neutres.
      if(m_longBreakEvenTradeCount+
         m_shortBreakEvenTradeCount!=
         m_breakEvenTradeCount)
         return false;
      
      
      // Chaque ensemble LONG doit être cohérent en lui-même.
      if(m_longWinningTradeCount+
         m_longLosingTradeCount+
         m_longBreakEvenTradeCount!=
         m_longClosedTradeCount)
         return false;
      
      
      // Même contrôle pour les SHORT.
      if(m_shortWinningTradeCount+
         m_shortLosingTradeCount+
         m_shortBreakEvenTradeCount!=
         m_shortClosedTradeCount)
         return false;

      // --------------------------------------------------
      // Cohérence des performances par motif de sortie.
      // --------------------------------------------------
      
      // SIGNAL : toutes les sorties doivent être classées.
      if(m_signalExitWinningCount+
         m_signalExitLosingCount+
         m_signalExitBreakEvenCount!=
         m_signalExitCount)
         return false;
      
      
      // STOP LOSS : toutes les sorties doivent être classées.
      if(m_stopLossWinningCount+
         m_stopLossLosingCount+
         m_stopLossBreakEvenCount!=
         m_stopLossExitCount)
         return false;


      // TAKE PROFIT : toutes les sorties doivent être classées.
      if(m_takeProfitWinningCount+
         m_takeProfitLosingCount+
         m_takeProfitBreakEvenCount!=
         m_takeProfitExitCount)
         return false;
      
      
      // Tous les trades gagnants doivent provenir
      // d'un des trois motifs de sortie.
      if(m_signalExitWinningCount+
         m_stopLossWinningCount+
         m_takeProfitWinningCount!=
         m_winningTradeCount)
         return false;
      
      
      // Même contrôle pour les trades perdants.
      if(m_signalExitLosingCount+
         m_stopLossLosingCount+
         m_takeProfitLosingCount!=
         m_losingTradeCount)
         return false;
      
      
      // Même contrôle pour les trades neutres.
      if(m_signalExitBreakEvenCount+
         m_stopLossBreakEvenCount+
         m_takeProfitBreakEvenCount!=
         m_breakEvenTradeCount)
         return false;

      // --------------------------------------------------
      // Cohérence de la matrice sens × motif de sortie.
      // --------------------------------------------------
      
      // Toutes les positions LONG clôturées doivent être
      // réparties entre SIGNAL, STOP LOSS et TAKE PROFIT.
      if(m_longSignalExitCount+
         m_longStopLossExitCount+
         m_longTakeProfitExitCount!=
         m_longClosedTradeCount)
         return false;
      
      
      // Même contrôle pour les positions SHORT.
      if(m_shortSignalExitCount+
         m_shortStopLossExitCount+
         m_shortTakeProfitExitCount!=
         m_shortClosedTradeCount)
         return false;
      
      
      // Toutes les sorties SIGNAL doivent être soit LONG,
      // soit SHORT.
      if(m_longSignalExitCount+
         m_shortSignalExitCount!=
         m_signalExitCount)
         return false;
      
      
      // Même contrôle pour les STOP LOSS.
      if(m_longStopLossExitCount+
         m_shortStopLossExitCount!=
         m_stopLossExitCount)
         return false;


      // Même contrôle pour les TAKE PROFIT.
      if(m_longTakeProfitExitCount+
         m_shortTakeProfitExitCount!=
         m_takeProfitExitCount)
         return false;

      // --------------------------------------------------
      // Cohérence monétaire de la matrice.
      // --------------------------------------------------
      const double moneyTolerance=0.01;
      
      
      // Ligne LONG.
      if(MathAbs(
            m_longSignalExitMoney+
            m_longStopLossExitMoney+
            m_longTakeProfitExitMoney-
            m_longTotalClosedMoney)>moneyTolerance)
         return false;


      // Ligne SHORT.
      if(MathAbs(
            m_shortSignalExitMoney+
            m_shortStopLossExitMoney+
            m_shortTakeProfitExitMoney-
            m_shortTotalClosedMoney)>moneyTolerance)
         return false;
      
      
      // Colonne SIGNAL.
      if(MathAbs(
            m_longSignalExitMoney+
            m_shortSignalExitMoney-
            m_signalExitTotalMoney)>moneyTolerance)
         return false;
      
      
      // Colonne STOP LOSS.
      if(MathAbs(
            m_longStopLossExitMoney+
            m_shortStopLossExitMoney-
            m_stopLossTotalMoney)>moneyTolerance)
         return false;
      
      
      // Colonne TAKE PROFIT.
      if(MathAbs(
            m_longTakeProfitExitMoney+
            m_shortTakeProfitExitMoney-
            m_takeProfitTotalMoney)>moneyTolerance)
         return false;
      
      
      // Total LONG + SHORT.
      if(MathAbs(
            m_longTotalClosedMoney+
            m_shortTotalClosedMoney-
            m_totalClosedMoney)>moneyTolerance)
         return false;

      return true;
     }

   // --------------------------------------------------
   // Résume les périodes des drawdowns maximaux.
   // --------------------------------------------------
   string BuildDrawdownTimingSummary(void) const
     {
      if(!m_isInitialized)
         return "Périodes de drawdown indisponibles : gestionnaire non initialisé.";

      string capitalPeriod="AUCUN";
   
      if(m_maxDrawdownMoney>0.0 &&
         m_maxCapitalDrawdownStartTime>0 &&
         m_maxCapitalDrawdownLowTime>0)
        {
         capitalPeriod=StringFormat(
            "début=%s | creux=%s",
   
            TimeToString(
               m_maxCapitalDrawdownStartTime,
               TIME_DATE|TIME_MINUTES),
   
            TimeToString(
               m_maxCapitalDrawdownLowTime,
               TIME_DATE|TIME_MINUTES));
        }
   
   
      string equityPeriod="AUCUN";
   
      if(m_maxEquityDrawdownMoney>0.0 &&
         m_maxEquityDrawdownStartTime>0 &&
         m_maxEquityDrawdownLowTime>0)
        {
         equityPeriod=StringFormat(
            "début=%s | creux=%s",
   
            TimeToString(
               m_maxEquityDrawdownStartTime,
               TIME_DATE|TIME_MINUTES),
   
            TimeToString(
               m_maxEquityDrawdownLowTime,
               TIME_DATE|TIME_MINUTES));
        }
   
   
      return StringFormat(
         "Période drawdown capital : %s | "
         "Période drawdown équité : %s",
   
         capitalPeriod,
         equityPeriod);
     }

   string BuildSignalExitSummary(void) const
     {
      double profitFactor=0.0;
   
      if(m_signalExitGrossLossMoney>0.0)
         profitFactor=
            m_signalExitGrossProfitMoney/
            m_signalExitGrossLossMoney;
   
   
      double expectancy=0.0;
   
      if(m_signalExitCount>0)
         expectancy=
            m_signalExitTotalMoney/
            (double)m_signalExitCount;
   
   
      return StringFormat(
         "Résumé sorties SIGNAL : "
         "Trades=%d | "
         "Gagnants=%d | "
         "Perdants=%d | "
         "Neutres=%d | "
         "Points=%.1f | "
         "Gains=%.2f EUR | "
         "Pertes=%.2f EUR | "
         "Net=%.2f EUR | "
         "Profit factor=%.2f | "
         "Espérance=%.2f EUR",
   
         m_signalExitCount,
         m_signalExitWinningCount,
         m_signalExitLosingCount,
         m_signalExitBreakEvenCount,
         m_signalExitTotalPoints,
         m_signalExitGrossProfitMoney,
         m_signalExitGrossLossMoney,
         m_signalExitTotalMoney,
         profitFactor,
         expectancy);
     }

string BuildStopLossSummary(void) const
  {
   double profitFactor=0.0;

   if(m_stopLossGrossLossMoney>0.0)
      profitFactor=
         m_stopLossGrossProfitMoney/
         m_stopLossGrossLossMoney;


   double expectancy=0.0;

   if(m_stopLossExitCount>0)
      expectancy=
         m_stopLossTotalMoney/
         (double)m_stopLossExitCount;


   return StringFormat(
      "Résumé sorties STOP LOSS : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_stopLossExitCount,
      m_stopLossWinningCount,
      m_stopLossLosingCount,
      m_stopLossBreakEvenCount,
      m_stopLossTotalPoints,
      m_stopLossGrossProfitMoney,
      m_stopLossGrossLossMoney,
      m_stopLossTotalMoney,
      profitFactor,
      expectancy);
  }

string BuildTakeProfitSummary(void) const
  {
   double profitFactor=0.0;

   if(m_takeProfitGrossLossMoney>0.0)
      profitFactor=
         m_takeProfitGrossProfitMoney/
         m_takeProfitGrossLossMoney;


   double expectancy=0.0;

   if(m_takeProfitExitCount>0)
      expectancy=
         m_takeProfitTotalMoney/
         (double)m_takeProfitExitCount;


   return StringFormat(
      "Résumé sorties TAKE PROFIT : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_takeProfitExitCount,
      m_takeProfitWinningCount,
      m_takeProfitLosingCount,
      m_takeProfitBreakEvenCount,
      m_takeProfitTotalPoints,
      m_takeProfitGrossProfitMoney,
      m_takeProfitGrossLossMoney,
      m_takeProfitTotalMoney,
      profitFactor,
      expectancy);
  }

   string BuildLongSummary(void) const
  {
   double profitFactor=0.0;

   if(m_longGrossLossMoney>0.0)
      profitFactor=
         m_longGrossProfitMoney/
         m_longGrossLossMoney;

   double expectancy=0.0;

   if(m_longClosedTradeCount>0)
      expectancy=
         m_longTotalClosedMoney/
         (double)m_longClosedTradeCount;

   return StringFormat(
      "Résumé LONG : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_longClosedTradeCount,
      m_longWinningTradeCount,
      m_longLosingTradeCount,
      m_longBreakEvenTradeCount,
      m_longTotalClosedPoints,
      m_longGrossProfitMoney,
      m_longGrossLossMoney,
      m_longTotalClosedMoney,
      profitFactor,
      expectancy);
  }
  
  string BuildShortSummary(void) const
  {
   double profitFactor=0.0;

   if(m_shortGrossLossMoney>0.0)
      profitFactor=
         m_shortGrossProfitMoney/
         m_shortGrossLossMoney;

   double expectancy=0.0;

   if(m_shortClosedTradeCount>0)
      expectancy=
         m_shortTotalClosedMoney/
         (double)m_shortClosedTradeCount;

   return StringFormat(
      "Résumé SHORT : "
      "Trades=%d | "
      "Gagnants=%d | "
      "Perdants=%d | "
      "Neutres=%d | "
      "Points=%.1f | "
      "Gains=%.2f EUR | "
      "Pertes=%.2f EUR | "
      "Net=%.2f EUR | "
      "Profit factor=%.2f | "
      "Espérance=%.2f EUR",

      m_shortClosedTradeCount,
      m_shortWinningTradeCount,
      m_shortLosingTradeCount,
      m_shortBreakEvenTradeCount,
      m_shortTotalClosedPoints,
      m_shortGrossProfitMoney,
      m_shortGrossLossMoney,
      m_shortTotalClosedMoney,
      profitFactor,
      expectancy);
  }
 
 // --------------------------------------------------
// Résume la matrice des sorties LONG.
// --------------------------------------------------
string BuildLongExitMatrixSummary(void) const
  {
   return StringFormat(
      "Matrice LONG : "
      "SIGNAL=%d trade(s) / %.2f EUR | "
      "STOP LOSS=%d trade(s) / %.2f EUR | "
      "TAKE PROFIT=%d trade(s) / %.2f EUR | "
      "TOTAL=%d trade(s) / %.2f EUR",

      m_longSignalExitCount,
      m_longSignalExitMoney,

      m_longStopLossExitCount,
      m_longStopLossExitMoney,

      m_longTakeProfitExitCount,
      m_longTakeProfitExitMoney,

      m_longClosedTradeCount,
      m_longTotalClosedMoney);
  }
  
// --------------------------------------------------
// Résume la matrice des sorties SHORT.
// --------------------------------------------------
string BuildShortExitMatrixSummary(void) const
  {
   return StringFormat(
      "Matrice SHORT : "
      "SIGNAL=%d trade(s) / %.2f EUR | "
      "STOP LOSS=%d trade(s) / %.2f EUR | "
      "TAKE PROFIT=%d trade(s) / %.2f EUR | "
      "TOTAL=%d trade(s) / %.2f EUR",

      m_shortSignalExitCount,
      m_shortSignalExitMoney,

      m_shortStopLossExitCount,
      m_shortStopLossExitMoney,

      m_shortTakeProfitExitCount,
      m_shortTakeProfitExitMoney,

      m_shortClosedTradeCount,
      m_shortTotalClosedMoney);
  }  
   
   // --------------------------------------------------
   // Construit le résumé final.
   // --------------------------------------------------
   string BuildSummary(void) const
     {
      if(!m_isInitialized)
        {
         return
            "Gestionnaire de positions virtuelles non initialisé. "
            "Vérifier l'appel à g_virtualPositions.Init() dans OnInit().";
        }

      // --------------------------------------------------
      // Statistiques monétaires dérivées.
      // --------------------------------------------------
      double averageWinMoney=0.0;
      
      if(m_winningTradeCount>0)
        {
         averageWinMoney=
            m_grossProfitMoney/
            m_winningTradeCount;
        }
      
      
      double averageLossMoney=0.0;
      
      if(m_losingTradeCount>0)
        {
         averageLossMoney=
            m_grossLossMoney/
            m_losingTradeCount;
        }
      
      
      double expectancyMoney=0.0;
      
      if(m_closedTradeCount>0)
        {
         expectancyMoney=
            m_totalClosedMoney/
            m_closedTradeCount;
        }
      
      
      // Le Profit Factor est :
      // somme des gains / somme des pertes.
      string profitFactorText="N/A";
      
      if(m_grossLossMoney>0.0)
        {
         double profitFactor=
            m_grossProfitMoney/
            m_grossLossMoney;
      
         profitFactorText=
            DoubleToString(
               profitFactor,
               2);
        }     
     
      string openPositionSummary;

      if(m_state==PB_VIRTUAL_POSITION_FLAT)
        {
         openPositionSummary="Position ouverte=NON";
        }
      else
        {
         double theoreticalExitPrice=
            (m_state==PB_VIRTUAL_POSITION_LONG)
            ? m_lastKnownBid
            : m_lastKnownAsk;

         double latentPoints=0.0;

         if(theoreticalExitPrice>0.0 &&
            m_point>0.0)
           {
            if(m_state==PB_VIRTUAL_POSITION_LONG)
              {
               latentPoints=
                  (theoreticalExitPrice-m_entryPrice)/m_point;
              }
            else
              {
               latentPoints=
                  (m_entryPrice-theoreticalExitPrice)/m_point;
              }
           }

         double latentMoney=0.0;
         string latentMoneyError;

         bool latentMoneyAvailable=
            theoreticalExitPrice>0.0 &&
            CalculateMoneyResult(
               m_state,
               m_entryPrice,
               theoreticalExitPrice,
               latentMoney,
               latentMoneyError);

         if(latentMoneyAvailable)
           {
            openPositionSummary=StringFormat(
               "Position ouverte=%s depuis %s à %.*f | "
               "Volume=%s lot(s) | "
               "SL=%.*f | TP=%.*f | "
               "Derniers Bid=%.*f Ask=%.*f | "
               "Sortie théorique=%.*f | "
               "Latent=%.1f points | "
               "Latent monétaire=%.*f %s",

               VirtualPositionStateToString(
                  m_state),

               TimeToString(
                  m_entryTime,
                  TIME_DATE|TIME_MINUTES),

               m_digits,
               m_entryPrice,

               m_volumeCalculator.FormatVolume(
                  m_currentPositionVolumeLots),

               m_digits,
               m_stopLossPrice,

               m_digits,
               m_takeProfitPrice,

               m_digits,
               m_lastKnownBid,

               m_digits,
               m_lastKnownAsk,

               m_digits,
               theoreticalExitPrice,

               latentPoints,

               m_accountCurrencyDigits,
               latentMoney,

               m_accountCurrency);
           }
         else
           {
            openPositionSummary=StringFormat(
               "Position ouverte=%s depuis %s à %.*f | "
               "Volume=%s lot(s) | "
               "SL=%.*f | TP=%.*f | "
               "Derniers Bid=%.*f Ask=%.*f | "
               "Sortie théorique=%.*f | "
               "Latent=%.1f points",

               VirtualPositionStateToString(
                  m_state),

               TimeToString(
                  m_entryTime,
                  TIME_DATE|TIME_MINUTES),

               m_digits,
               m_entryPrice,

               m_volumeCalculator.FormatVolume(
                  m_currentPositionVolumeLots),

               m_digits,
               m_stopLossPrice,

               m_digits,
               m_takeProfitPrice,

               m_digits,
               m_lastKnownBid,

               m_digits,
               m_lastKnownAsk,

               m_digits,
               theoreticalExitPrice,

               latentPoints);
           }
        }

      double finalVirtualCapital=
         m_initialVirtualCapital+
         m_totalClosedMoney;

      string monetarySummary=StringFormat(
         "%s | "
         "Capital initial=%.*f %s | "
         "Capital virtuel final=%.*f %s | "
         "Total monétaire=%.*f %s | "
         "Dernier volume=%s lot(s)",

         m_volumeCalculator.BuildModeSummary(),

         m_accountCurrencyDigits,
         m_initialVirtualCapital,
         m_accountCurrency,

         m_accountCurrencyDigits,
         finalVirtualCapital,
         m_accountCurrency,

         m_accountCurrencyDigits,
         m_totalClosedMoney,
         m_accountCurrency,

         m_volumeCalculator.FormatVolume(
            m_lastOpenedVolumeLots));

      return StringFormat(
         "Ouvertures=%d | "
         "Trades clôturés=%d | "
         "Gagnants=%d | "
         "Perdants=%d | "
         "Série pertes max=%d | "
         "Neutres=%d | "
         "Inversions=%d | "
         "Sorties signal=%d | "
         "Stop Loss=%d | "
         "Take Profit=%d | "
         "Total clôturé=%.1f points | "
         "Meilleur=%.1f | "
         "Pire=%.1f | "
         "Somme gains=%.*f %s | "
         "Somme pertes=%.*f %s | "
         "Gain moyen=%.*f %s | "
         "Perte moyenne=%.*f %s | "
         "Profit factor=%s | "
         "Espérance=%.*f %s | "
         "Drawdown capital montant=%.*f %s | "
         "Drawdown capital taux=%.2f%% | "
         "Drawdown équité montant=%.*f %s | "
         "Drawdown équité taux=%.2f%% | "
         "%s | "
         "%s",

         m_openCount,
         m_closedTradeCount,
         m_winningTradeCount,
         m_losingTradeCount,
         m_maxLosingStreak,
         m_breakEvenTradeCount,
         m_reversalCount,
         m_signalExitCount,
         m_stopLossExitCount,
         m_takeProfitExitCount,

         m_totalClosedPoints,
         m_bestTradePoints,
         m_worstTradePoints,
         
         m_accountCurrencyDigits,
         m_grossProfitMoney,
         m_accountCurrency,
         
         m_accountCurrencyDigits,
         m_grossLossMoney,
         m_accountCurrency,
         
         m_accountCurrencyDigits,
         averageWinMoney,
         m_accountCurrency,
         
         m_accountCurrencyDigits,
         averageLossMoney,
         m_accountCurrency,
         
         profitFactorText,
         
         // Espérance : %.*f %s
         m_accountCurrencyDigits,
         expectancyMoney,
         m_accountCurrency,
         
         // Drawdown monétaire : %.*f %s
         m_accountCurrencyDigits,
         m_maxDrawdownMoney,
         m_accountCurrency,
         
         // Drawdown en pourcentage : %.2f%%
         m_maxDrawdownPercent,
         
         // Drawdown de l'équité, résultat latent inclus.
         m_accountCurrencyDigits,
         m_maxEquityDrawdownMoney,
         m_accountCurrency,
         
         m_maxEquityDrawdownPercent,         
         
         monetarySummary,
         openPositionSummary);
     }
  };


#endif

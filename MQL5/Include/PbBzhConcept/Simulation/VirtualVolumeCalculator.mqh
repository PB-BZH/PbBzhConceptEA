//+------------------------------------------------------------------+
//|                                      VirtualVolumeCalculator.mqh |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
#ifndef PB_BZH_CONCEPT_VIRTUAL_VOLUME_CALCULATOR_MQH
#define PB_BZH_CONCEPT_VIRTUAL_VOLUME_CALCULATOR_MQH


// --------------------------------------------------
// Mode de calcul du volume virtuel.
// --------------------------------------------------
enum ENUM_PB_VIRTUAL_VOLUME_MODE
  {
   PB_VIRTUAL_VOLUME_FIXED        =0,
   PB_VIRTUAL_VOLUME_RISK_PERCENT =1
  };


// --------------------------------------------------
// Convertit le mode de volume en texte.
// --------------------------------------------------
string VirtualVolumeModeToString(
   const ENUM_PB_VIRTUAL_VOLUME_MODE mode)
  {
   switch(mode)
     {
      case PB_VIRTUAL_VOLUME_FIXED:
         return "FIXE";

      case PB_VIRTUAL_VOLUME_RISK_PERCENT:
         return "RISQUE";

      default:
         return "INCONNU";
     }
  }


// --------------------------------------------------
// Calcule un volume virtuel fixe ou fondé sur
// un pourcentage de risque.
// --------------------------------------------------
class CVirtualVolumeCalculator
  {
private:
   string                      m_symbol;
   ENUM_PB_VIRTUAL_VOLUME_MODE m_mode;

   double m_fixedVolumeLots;
   double m_riskPercent;

   double m_volumeMin;
   double m_volumeMax;
   double m_volumeStep;

   int    m_volumeDigits;


   // ------------------------------------------------
   // Détermine le nombre de décimales nécessaires
   // pour afficher le volume.
   //
   // Exemples :
   //   1.0   -> 0 décimale
   //   0.1   -> 1 décimale
   //   0.01  -> 2 décimales
   //   0.001 -> 3 décimales
   // ------------------------------------------------
   int DetectVolumeDigits(
      const double volumeStep) const
     {
      int    digits=0;
      double value =volumeStep;

      while(digits<8 &&
            MathAbs(value-MathRound(value))>0.00000001)
        {
         value*=10.0;
         digits++;
        }

      return digits;
     }


   // ------------------------------------------------
   // Arrondit toujours le volume vers le bas.
   //
   // Il ne faut pas arrondir au plus proche car cela
   // pourrait dépasser le risque demandé.
   // ------------------------------------------------
   double NormalizeVolumeDown(
      const double volume) const
     {
      if(volume<=0.0 || m_volumeStep<=0.0)
         return 0.0;

      double stepCount=
         MathFloor(
            volume/m_volumeStep+
            0.000000001);

      return NormalizeDouble(
         stepCount*m_volumeStep,
         m_volumeDigits);
     }


   // ------------------------------------------------
   // Calcule la perte monétaire obtenue si le Stop
   // Loss est atteint.
   // ------------------------------------------------
   bool CalculateLossAtStop(
      const ENUM_ORDER_TYPE orderType,
      const double          volumeLots,
      const double          entryPrice,
      const double          stopLossPrice,
      double               &lossMoney,
      string               &errorMessage) const
     {
      lossMoney   =0.0;
      errorMessage="";

      double calculatedProfit=0.0;

      ResetLastError();

      if(!OrderCalcProfit(
            orderType,
            m_symbol,
            volumeLots,
            entryPrice,
            stopLossPrice,
            calculatedProfit))
        {
         int errorCode=GetLastError();

         errorMessage=StringFormat(
            "OrderCalcProfit a échoué lors du calcul "
            "du risque | Volume=%s | "
            "Entrée=%.*f | Stop=%.*f | Erreur=%d",

            FormatVolume(volumeLots),

            (int)SymbolInfoInteger(
               m_symbol,
               SYMBOL_DIGITS),

            entryPrice,

            (int)SymbolInfoInteger(
               m_symbol,
               SYMBOL_DIGITS),

            stopLossPrice,

            errorCode);

         return false;
        }

      // Le Stop Loss doit produire une perte.
      if(calculatedProfit>=0.0)
        {
         errorMessage=StringFormat(
            "Le niveau de Stop Loss ne produit pas "
            "une perte | Résultat calculé=%.2f",
            calculatedProfit);

         return false;
        }

      lossMoney=MathAbs(calculatedProfit);

      return true;
     }


public:

   CVirtualVolumeCalculator(void)
     {
      m_symbol         ="";
      m_mode           =PB_VIRTUAL_VOLUME_FIXED;
      m_fixedVolumeLots=0.0;
      m_riskPercent    =0.0;

      m_volumeMin =0.0;
      m_volumeMax =0.0;
      m_volumeStep=0.0;

      m_volumeDigits=2;
     }


   // ------------------------------------------------
   // Initialise le calculateur.
   // ------------------------------------------------
   bool Init(
      const string                      symbol,
      const ENUM_PB_VIRTUAL_VOLUME_MODE mode,
      const double                      fixedVolumeLots,
      const double                      riskPercent,
      string                           &errorMessage)
     {
      errorMessage="";

      m_symbol=symbol;
      m_mode  =mode;

      m_volumeMin=
         SymbolInfoDouble(
            m_symbol,
            SYMBOL_VOLUME_MIN);

      m_volumeMax=
         SymbolInfoDouble(
            m_symbol,
            SYMBOL_VOLUME_MAX);

      m_volumeStep=
         SymbolInfoDouble(
            m_symbol,
            SYMBOL_VOLUME_STEP);

      if(m_volumeMin<=0.0 ||
         m_volumeMax<=0.0 ||
         m_volumeStep<=0.0)
        {
         errorMessage=
            "Les propriétés de volume du symbole "
            "sont invalides.";

         return false;
        }

      m_volumeDigits=
         DetectVolumeDigits(
            m_volumeStep);


      // ---------------------------------------------
      // Validation du mode fixe.
      // ---------------------------------------------
      if(mode==PB_VIRTUAL_VOLUME_FIXED)
        {
         if(fixedVolumeLots<m_volumeMin ||
            fixedVolumeLots>m_volumeMax)
           {
            errorMessage=StringFormat(
               "Volume fixe %s invalide | "
               "Minimum=%s | Maximum=%s",

               FormatVolume(fixedVolumeLots),
               FormatVolume(m_volumeMin),
               FormatVolume(m_volumeMax));

            return false;
           }

         double normalizedVolume=
            NormalizeDouble(
               MathRound(
                  fixedVolumeLots/m_volumeStep) *
               m_volumeStep,
               m_volumeDigits);

         double tolerance=
            MathMax(
               0.00000001,
               m_volumeStep*0.000001);

         if(MathAbs(
               normalizedVolume-
               fixedVolumeLots)>tolerance)
           {
            errorMessage=StringFormat(
               "Volume fixe %s non aligné sur "
               "le pas %s",

               FormatVolume(fixedVolumeLots),
               FormatVolume(m_volumeStep));

            return false;
           }

         m_fixedVolumeLots=normalizedVolume;
         m_riskPercent    =0.0;

         return true;
        }


      // ---------------------------------------------
      // Validation du mode risque.
      // ---------------------------------------------
      if(mode==PB_VIRTUAL_VOLUME_RISK_PERCENT)
        {
         if(riskPercent<=0.0 ||
            riskPercent>100.0)
           {
            errorMessage=StringFormat(
               "Pourcentage de risque %.2f invalide.",
               riskPercent);

            return false;
           }

         m_fixedVolumeLots=0.0;
         m_riskPercent    =riskPercent;

         return true;
        }

      errorMessage=
         "Mode de calcul du volume inconnu.";

      return false;
     }


   // ------------------------------------------------
   // Calcule le volume de la prochaine position.
   //
   // En mode risque :
   //   - le volume est arrondi vers le bas ;
   //   - le volume minimal n'est jamais forcé ;
   //   - la limite maximale est respectée.
   // ------------------------------------------------
   bool Calculate(
      const ENUM_ORDER_TYPE orderType,
      const double          currentVirtualCapital,
      const double          entryPrice,
      const double          stopLossPrice,
      double               &volumeLots,
      double               &targetRiskMoney,
      double               &estimatedLossAtStop,
      string               &errorMessage) const
     {
      volumeLots        =0.0;
      targetRiskMoney   =0.0;
      estimatedLossAtStop=0.0;
      errorMessage      ="";


      // =============================================
      // MODE FIXE
      // =============================================
      if(m_mode==PB_VIRTUAL_VOLUME_FIXED)
        {
         volumeLots=m_fixedVolumeLots;

         // Le calcul de la perte au Stop est informatif
         // en mode fixe.
         if(stopLossPrice>0.0)
           {
            if(!CalculateLossAtStop(
                  orderType,
                  volumeLots,
                  entryPrice,
                  stopLossPrice,
                  estimatedLossAtStop,
                  errorMessage))
              {
               return false;
              }
           }

         return true;
        }


      // =============================================
      // MODE RISQUE
      // =============================================
      if(currentVirtualCapital<=0.0)
        {
         errorMessage=StringFormat(
            "Capital virtuel invalide : %.2f",
            currentVirtualCapital);

         return false;
        }

      if(stopLossPrice<=0.0)
        {
         errorMessage=
            "Le calcul du volume selon le risque "
            "nécessite un Stop Loss actif.";

         return false;
        }


      // ---------------------------------------------
      // Utilisation d'un volume de référence autorisé.
      // ---------------------------------------------
      double referenceVolume=
         NormalizeVolumeDown(
            MathMin(
               1.0,
               m_volumeMax));

      if(referenceVolume<m_volumeMin)
         referenceVolume=m_volumeMin;


      double referenceLoss=0.0;

      if(!CalculateLossAtStop(
            orderType,
            referenceVolume,
            entryPrice,
            stopLossPrice,
            referenceLoss,
            errorMessage))
        {
         return false;
        }

      if(referenceLoss<=0.0)
        {
         errorMessage=
            "La perte de référence est nulle.";

         return false;
        }


      // ---------------------------------------------
      // Perte pour un lot.
      // ---------------------------------------------
      double lossPerLot=
         referenceLoss/referenceVolume;


      // ---------------------------------------------
      // Montant maximal que nous acceptons de perdre.
      // ---------------------------------------------
      targetRiskMoney=
         currentVirtualCapital *
         m_riskPercent /
         100.0;


      double theoreticalVolume=
         targetRiskMoney/lossPerLot;


      // Toujours arrondir vers le bas.
      volumeLots=
         NormalizeVolumeDown(
            theoreticalVolume);


      // La limite maximale réduit le risque réel.
      if(volumeLots>m_volumeMax)
        {
         volumeLots=
            NormalizeVolumeDown(
               m_volumeMax);
        }


      // Ne pas forcer le volume minimum, car cela
      // pourrait dépasser le risque demandé.
      if(volumeLots<m_volumeMin)
        {
         errorMessage=StringFormat(
            "Volume théorique trop faible | "
            "Volume calculé=%s | Minimum=%s | "
            "Risque cible=%.2f",

            FormatVolume(volumeLots),
            FormatVolume(m_volumeMin),
            targetRiskMoney);

         return false;
        }


      // ---------------------------------------------
      // Perte réellement estimée après normalisation.
      // ---------------------------------------------
      if(!CalculateLossAtStop(
            orderType,
            volumeLots,
            entryPrice,
            stopLossPrice,
            estimatedLossAtStop,
            errorMessage))
        {
         return false;
        }

      return true;
     }


   // ------------------------------------------------
   // Formate un volume selon le pas du symbole.
   // ------------------------------------------------
   string FormatVolume(
      const double volume) const
     {
      return DoubleToString(
         volume,
         m_volumeDigits);
     }


   // ------------------------------------------------
   // Résumé de la configuration.
   // ------------------------------------------------
   string BuildModeSummary(void) const
     {
      if(m_mode==PB_VIRTUAL_VOLUME_FIXED)
        {
         return StringFormat(
            "Mode volume=FIXE | Volume fixe=%s lot(s)",
            FormatVolume(
               m_fixedVolumeLots));
        }

      return StringFormat(
         "Mode volume=RISQUE | Risque=%.2f%%",
         m_riskPercent);
     }
  };


#endif

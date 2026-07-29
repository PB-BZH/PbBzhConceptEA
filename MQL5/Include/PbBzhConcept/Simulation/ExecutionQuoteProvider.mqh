//+------------------------------------------------------------------+
//|                                       ExecutionQuoteProvider.mqh |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
#ifndef PB_BZH_EXECUTION_QUOTE_PROVIDER_MQH
#define PB_BZH_EXECUTION_QUOTE_PROVIDER_MQH


// Photographie des prix disponibles à un instant donné.
struct SExecutionQuote
  {
   datetime time;
   double   bid;
   double   ask;
   double   spreadPoints;
  };


// Lit les prix Bid et Ask du symbole.
//
// Cette classe ne calcule aucun signal
// et n'envoie aucune requête de trading.
class CExecutionQuoteProvider
  {
private:
   string m_symbol;
   double m_point;
   int    m_digits;

public:
   CExecutionQuoteProvider(void)
     {
      m_symbol="";
      m_point =0.0;
      m_digits=0;
     }


   // --------------------------------------------------
   // Initialisation pour un symbole.
   // --------------------------------------------------
   bool Init(const string symbol)
     {
      m_symbol=symbol;

      ResetLastError();

      if(!SymbolInfoDouble(
            m_symbol,
            SYMBOL_POINT,
            m_point) ||
         m_point<=0.0)
        {
         PrintFormat(
            "[CExecutionQuoteProvider][ERROR] "
            "Lecture de SYMBOL_POINT impossible pour %s. "
            "Erreur=%d",
            m_symbol,
            GetLastError());

         return false;
        }

      long digits=0;

      ResetLastError();

      if(!SymbolInfoInteger(
            m_symbol,
            SYMBOL_DIGITS,
            digits))
        {
         PrintFormat(
            "[CExecutionQuoteProvider][ERROR] "
            "Lecture de SYMBOL_DIGITS impossible pour %s. "
            "Erreur=%d",
            m_symbol,
            GetLastError());

         return false;
        }

      m_digits=(int)digits;

      return true;
     }


   // --------------------------------------------------
   // Lecture du dernier tick connu.
   // --------------------------------------------------
   bool Read(SExecutionQuote &quote) const
     {
      ZeroMemory(quote);

      MqlTick tick;
      ZeroMemory(tick);

      ResetLastError();

      if(!SymbolInfoTick(m_symbol,tick))
        {
         PrintFormat(
            "[CExecutionQuoteProvider][ERROR] "
            "SymbolInfoTick a échoué pour %s. Erreur=%d",
            m_symbol,
            GetLastError());

         return false;
        }

      if(tick.bid<=0.0 || tick.ask<=0.0)
        {
         PrintFormat(
            "[CExecutionQuoteProvider][ERROR] "
            "Cotation invalide : Bid=%.*f Ask=%.*f",
            m_digits,
            tick.bid,
            m_digits,
            tick.ask);

         return false;
        }

      if(tick.ask<tick.bid)
        {
         PrintFormat(
            "[CExecutionQuoteProvider][ERROR] "
            "Ask inférieur à Bid : Bid=%.*f Ask=%.*f",
            m_digits,
            tick.bid,
            m_digits,
            tick.ask);

         return false;
        }

      quote.time=tick.time;
      quote.bid =tick.bid;
      quote.ask =tick.ask;

      quote.spreadPoints=
         (tick.ask-tick.bid)/m_point;

      return true;
     }


   int Digits(void) const
     {
      return m_digits;
     }
  };

#endif

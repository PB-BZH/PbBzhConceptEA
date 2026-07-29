#ifndef PB_BZH_TRADE_SIGNAL_MQH
#define PB_BZH_TRADE_SIGNAL_MQH

// Signal métier produit par une stratégie.
// Cette première version ne déclenche encore aucun ordre.
enum ENUM_PB_TRADE_SIGNAL
  {
   PB_SIGNAL_SELL = -1,
   PB_SIGNAL_NONE =  0,
   PB_SIGNAL_BUY  =  1
  };

string TradeSignalToString(const ENUM_PB_TRADE_SIGNAL signal)
  {
   switch(signal)
     {
      case PB_SIGNAL_BUY:
         return "BUY";

      case PB_SIGNAL_SELL:
         return "SELL";

      default:
         return "NONE";
     }
  }

#endif

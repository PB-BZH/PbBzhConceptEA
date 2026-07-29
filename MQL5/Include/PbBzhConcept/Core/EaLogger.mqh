#ifndef PB_BZH_EA_LOGGER_MQH
#define PB_BZH_EA_LOGGER_MQH

// Journal minimal et homogène pour l'Expert Advisor.
class CEaLogger
  {
private:
   string            m_componentName;

   void              Write(const string level,const string message) const
     {
      PrintFormat("[%s][%s] %s",m_componentName,level,message);
     }

public:
                     CEaLogger(void)
     {
      m_componentName="PbBzhConceptEA";
     }

   void              Init(const string componentName)
     {
      if(StringLen(componentName)>0)
         m_componentName=componentName;
     }

   void              Info(const string message) const
     {
      Write("INFO",message);
     }

   void              Signal(const string message) const
     {
      Write("SIGNAL",message);
     }

   void              Warning(const string message) const
     {
      Write("WARNING",message);
     }

   void              Error(const string message) const
     {
      Write("ERROR",message);
     }
  };

#endif

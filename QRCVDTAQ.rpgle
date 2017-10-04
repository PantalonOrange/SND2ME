      /if not defined (#API_QRCVDTAQ)  
      /define #API_QRCVDTAQ            
     D EC#RCVDTAQ      PR                  EXTPGM( 'QRCVDTAQ' )
     D  DQName                       10A    CONST
     D  DQLib                        10A    CONST
     D  DQLen                         5P 0  CONST 
     D  DQDataDS                            LIKEDS( DataDS )
     D  DQWait                        5P 0  CONST
      /endif

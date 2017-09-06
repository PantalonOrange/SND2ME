     *  SND2MERG                      : SND2ME
     *  ######........................: SND2ME MAIL-VERSAND
     *        RG......................: RPG IV
     *  VERSION.......................: V0R1M0

     *  00000000                        BRC      06.09.2017


     *#########################################################################
     *- Kopfdefinitionen
     *#########################################################################

     H MAIN( Main ) ALWNULL( *USRCTL ) AUT( *EXCLUDE )
     H DATFMT( *ISO- ) TIMFMT( *ISO. ) DECEDIT( '0,' )
     H DFTACTGRP( *NO ) ACTGRP( *CALLER ) DEBUG( *YES ) USRPRF( *OWNER )


     *#########################################################################
     *- Definitionen
     *#########################################################################

     * Datentypen -------------------------------------------------------------
      /INCLUDE *LIBL/QRPGLECPY,INLR
      /INCLUDE *LIBL/QRPGLECPY,SQLDEF

     * Programm Prototype -----------------------------------------------------
     D Main            PR                  EXTPGM( 'SND2MERG' )
     D  paLibrary                    10A    CONST
     D  paQueue                      10A    CONST

     * Importierte Prototypen -------------------------------------------------
      /INCLUDE *LIBL/QRPGLECPY,SYSTEM

     * Globale Prototypen -----------------------------------------------------
     D EC#RCVDTAQ      PR                   EXTPGM( 'QRCVDTAQ' )
     D  paDQName                     10A     CONST
     D  paDQLib                      10A     CONST
     D  ppDQLen                       5P 0   CONST
     D  paDQData                    128A
     D  ppDQWait                      5P 0   CONST


     * Globale Konstanten -----------------------------------------------------
      /INCLUDE *LIBL/QRPGLECPY,CONSTANTS


     * Globale Variablen ------------------------------------------------------


     *#########################################################################
     *- MAIN-Prozedur fuer das Programm
     *#########################################################################
    P Main            B
     D Main            PI
     D  paLibrary                    10A   CONST
     D  paQueue                      10A   CONST

     D EC#SendSpool    PR                  EXTPGM( 'SND2MECL' )
     D  paOutQ                       10A    CONST
     D  paOutQLib                    10A    CONST
     D  paFileName                   10A    CONST
     D  paJobNbr                      6A    CONST
     D  paJobUser                    10A    CONST
     D  paJobName                    10A    CONST
     D  paFileNbr                     9A    CONST
     D  paMail                      128A    CONST

     D nSuccess        S               N   INZ( TRUE )
     D aFileNbr        S              9A   INZ
     D aCmd            S            128A   VARYING INZ
     D aMail           S            128A   INZ
     D aData           S            128A   INZ
     D xData           S               *   INZ( %ADDR(aData) )

     D dsData          DS                  QUALIFIED BASED( xData )
     D  aFunction                    10A
     D  aRecordType                   2A
     D  aQualJobName                 26A
     D   aJobName                    10A    OVERLAY( aQualJobName :1 )
     D   aJobUser                    10A    OVERLAY( aQualJobName :11 )
     D   aJobNbr                      6A    OVERLAY( aQualJobName :21 )
     D  aFileName                    10A
     D  bFileNbr                      9B 0
     D  aQualQueueName...
     D                               20A
     D   aQueueName                  10A    OVERLAY( aQualQueueName :1 )
     D   aQueueLibrary...
     D                               10A    OVERLAY( aQualQueueName :11 )
     D  aFiller                      56A
     *-------------------------------------------------------------------------

      // SQL-Optionen
       Exec SQL SET OPTION DATFMT=*ISO, DATSEP='-', TIMFMT=*ISO, TIMSEP='.',
                            USRPRF=*OWNER, DYNUSRPRF=*OWNER,
                            CLOSQLCSR=*ENDMOD, COMMIT=*NONE;

      // DTAQ-Erstellen und an OUTQ haengen
       aCmd='CRTDTAQ DTAQ('+%Trim(paLibrary)+'/'+%Trim(paQueue)+
            ') MAXLEN(128) AUT(*EXCLUDE)';
       System(aCmd);
       aCmd='CHGOUTQ OUTQ('+%Trim(paLibrary)+'/'+%Trim(paQueue)+
            ') DTAQ('+%Trim(paLibrary)+'/'+%Trim(paQueue)+')';
       System(aCmd);

      // Endlos-Loop Abarbeiten
      DoW ( Loop );
         Clear aData;
        Monitor;
           EC#RCVDTAQ(paQueue :paLibrary :%Len(aData) :aData :30);
          On-Error;
             nSuccess=FALSE;
             Iter;
        EndMon;

        If ( aData='' );
           nSuccess=FALSE;
           Iter;
        Else;
           nSuccess=TRUE;
        EndIf;

      // Mailadresse lesen, konvertieren und versenden
        If nSuccess;
           Exec SQL SELECT STRIP(SMTPUID) CONCAT '@' CONCAT STRIP(DOMROUTE)
                      INTO :aMail
                      FROM QUSRSYS.QATMSMTPA A JOIN QUSRSYS.QAOKL02A B
                        ON (B.WOS1USRP=:dsData.aJobUser AND B.WOS1DDEN=A.USERID
                            AND B.WOS1DDGN=A.ADDRESS) WITH NC;
          If ( SQLCode=stsOK );
             aFileNbr=%Char(dsData.bFileNbr);
            Monitor;
               EC#SendSpool(dsData.aQueueName :dsData.aQueueLibrary
                            :dsData.aFileName :dsData.aJobNbr
                            :dsData.aJobUser  :dsData.aJobName
                            :aFileNbr :aMail);
              On-Error;
                 nSuccess=FALSE;
                 Iter;
            EndMon;
          EndIf;
        EndIf;
      EndDo;

      // Programm beenden
       ExitProgram=TRUE;
       Return;

    P                 E


     *  00000000                        BRC      07.09.2017

     H MAIN( Main ) ALWNULL( *USRCTL ) AUT( *EXCLUDE )
     H DATFMT( *ISO- ) TIMFMT( *ISO. ) DECEDIT( '0,' )
     H DFTACTGRP( *NO ) ACTGRP( *NEW ) DEBUG( *YES ) USRPRF( *OWNER )

     * Prototypes -------------------------------------------------------------
      /INCLUDE *LIBL/QRPGLECPY,SYSTEM

     * Program prototype ------------------------------------------------------
     D Main            PR                  EXTPGM( 'SND2MERG' )
     D  pdsQualName                         CONST LIKEDS( QualEntryParm )

     * Global constants -------------------------------------------------------
      /INCLUDE *LIBL/QRPGLECPY,SQLDEF
      /INCLUDE *LIBL/QRPGLECPY,CONSTANTS

     * Global variables -------------------------------------------------------
     D QualEntryParm   DS                  QUALIFIED
     D  aOutQ                        10A
     D  aLibrary                     10A
     D QualJobName_Template...
     D                 DS                  QUALIFIED
     D  aJobName                     10A
     D  aJobUser                     10A
     D  aJobNbr                       6A
     D QualQueueName_Template...
     D                 DS                  QUALIFIED
     D  aQueueName                   10A
     D  aQueueLibrary...
     D                               10A


     *#########################################################################
     *- MAIN-Procedure
     *#########################################################################
    P Main            B
     D Main            PI
     D  pdsQualName                        CONST LIKEDS( QualEntryParm )

      /INCLUDE *LIBL/QRPGLECPY,QRCVDTAQ
     D EC#SendSpool    PR                  EXTPGM( 'SND2MECL' )
     D  pdsQualJobName...
     D                                      CONST LIKEDS( QualJobName_Template )
     D  paFileName                   10A    CONST
     D  paFileNbr                     6A    CONST
     D  paMail                      128A    CONST

     D nSuccess        S               N   INZ( TRUE )
     D aUser           S             10A   INZ
     D aCmd            S            128A   VARYING INZ
     D aMail           S            128A   INZ

     D dsData          DS                  QUALIFIED
     D  aFunction                    10A
     D  aRecordType                   2A
     D  dsQualJobName                       LIKEDS( QualJobName_Template )
     D  aFileName                    10A
     D  iFileNbr                     10I 0
     D  dsQualQueueName...
     D                                      LIKEDS( QualQueueName_Template )
     D  aFiller                      56A
     *-------------------------------------------------------------------------

       Exec SQL SET OPTION DATFMT=*ISO, DATSEP='-', TIMFMT=*ISO, TIMSEP='.',
                            USRPRF=*OWNER, DYNUSRPRF=*OWNER,
                            CLOSQLCSR=*ENDMOD, COMMIT=*NONE;

       aCmd='CRTDTAQ DTAQ('+%Trim(pdsQualName.aLibrary)+'/'+
            %Trim(pdsQualName.aOutQ)+') MAXLEN(128) AUT(*EXCLUDE)';
       System(aCmd);
       aCmd='CHGOUTQ OUTQ('+%Trim(pdsQualName.aLibrary)+'/'+
            %Trim(pdsQualName.aOutQ)+') DTAQ('+
            %Trim(pdsQualName.aLibrary)+'/'+%Trim(pdsQualName.aOutQ)+')';
       System(aCmd);

      DoW ( Loop );
         Clear dsData;
        Monitor;
           EC#RCVDTAQ(pdsQualName.aOutQ :pdsQualName.aLibrary
                      :%Len(dsData) :dsData :30);
          On-Error;
             nSuccess = FALSE;
        EndMon;

         nSuccess = ( nSuccess And dsData.aFunction<>'' );

        If nSuccess;
           aUser = dsData.dsQualJobName.aJobUser;
           Exec SQL SELECT STRIP(SMTPUID) CONCAT '@' CONCAT STRIP(DOMROUTE)
                      INTO :aMail
                      FROM QUSRSYS.QATMSMTPA A JOIN QUSRSYS.QAOKL02A B
                        ON (B.WOS1USRP=:aUser AND B.WOS1DDEN=A.USERID AND
                            B.WOS1DDGN=A.ADDRESS);
          If ( SQLCode = stsOK );
            Monitor;
               EC#SendSpool(dsData.dsQualJobName :dsData.aFileName
                            :%Char(dsData.iFileNbr) :aMail);
              On-Error;
                 nSuccess = FALSE;
            EndMon;
          EndIf;
        EndIf;
      EndDo;

       Return;

    P                 E

**FREE
//- Copyright (c) 2017 Christian Brunner
//-
//- Permission is hereby granted, free of charge, to any person obtaining a copy
//- of this software and associated documentation files (the "Software"), to deal
//- in the Software without restriction, including without limitation the rights
//- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//- copies of the Software, and to permit persons to whom the Software is
//- furnished to do so, subject to the following conditions:

//- The above copyright notice and this permission notice shall be included in all
//- copies or substantial portions of the Software.

//- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//- SOFTWARE.

//  00000000                        BRC      10.10.2017

CTL-OPT MAIN( Main ) ALWNULL( *USRCTL ) AUT( *EXCLUDE )
        DATFMT( *ISO- ) TIMFMT( *ISO. ) DECEDIT( '0,' ) ALLOC( *TERASPACE )
        DFTACTGRP( *NO ) ACTGRP( *NEW ) DEBUG( *YES ) USRPRF( *OWNER );

// Prototypes -------------------------------------------------------------
/INCLUDE SND2ME/QRPGLECPY,SYSTEM

// Program prototype ------------------------------------------------------
DCL-PR Main EXTPGM( 'SND2MERG' );
 QualName LIKEDS( QualEntryParm_Template ) CONST;
 Type CHAR(5) OPTIONS( *NOPASS ) CONST;
END-PR;

// Prototypes ----- -------------------------------------------------------
DCL-PR Do_It_With_DTAQ;
 QualName LIKEDS( QualEntryParm_Template ) CONST;
END-PR;
DCL-PR Do_It_With_API;
 QualName LIKEDS( QualEntryParm_Template ) CONST;
END-PR;
DCL-PR LoopJob IND END-PR;
DCL-PR Get_Mailadress IND;
 User CHAR(10) CONST;
 Mail CHAR(128);
END-PR;
DCL-PR NormalizeJobName LIKEDS( QualJobName_Template );
 QJobName CHAR(28) CONST;
END-PR;

DCL-PR EC#SendSpool EXTPGM( 'SND2MECL' );
 QualJobName CONST LIKEDS( QualJobName_Template );
 FileName CHAR(10) CONST;
 FileNbr CHAR(6) CONST;
 Mail CHAR(128) CONST;
END-PR;

// Global constants -------------------------------------------------------
/INCLUDE SND2ME/QRPGLECPY,SQLDEF
/INCLUDE SND2ME/QRPGLECPY,CONSTANTS

// Global variables -------------------------------------------------------
DCL-DS QualEntryParm_Template QUALIFIED;
 OutQ CHAR(10);
 Library CHAR(10);
END-DS;

DCL-DS QualJobName_Template QUALIFIED;
 JobName CHAR(10);
 JobUser CHAR(10);
 JobNbr CHAR(6);
END-DS;

DCL-DS QualQueueName_Template QUALIFIED;
 QueueName CHAR(10);
 QueueLibrary CHAR(10);
END-DS;


//#########################################################################
//- MAIN-Procedure
//#########################################################################
DCL-PROC Main;
DCL-PI *N;
 pQualName LIKEDS( QualEntryParm_Template ) CONST;
 pType CHAR(5) OPTIONS( *NOPASS ) CONST;
END-PI;
//-------------------------------------------------------------------------

  Exec SQL SET OPTION DATFMT=*ISO, DATSEP='-', TIMFMT=*ISO, TIMSEP='.',
                      USRPRF=*OWNER, DYNUSRPRF=*OWNER,
                      CLOSQLCSR = *ENDMOD, COMMIT=*NONE;

  Select;
    When ( %Parms() = 1 );
      Do_It_With_DTAQ( pQualName );
    When ( pType = '*DTAQ' );
      Do_It_With_DTAQ( pQualName );
    When ( pType = '*API' );
      Do_It_With_API( pQualName );
  EndSl;

  Return;

END-PROC;

//* Do_It_With_DTAQ *******************************************************
//- Work with DTAQ
//*************************************************************************
DCL-PROC Do_It_With_DTAQ;
DCL-PI Do_It_With_DTAQ;
 pQualName LIKEDS( QualEntryParm_Template ) CONST;
END-PI;

/INCLUDE SND2ME/QRPGLECPY,QRCVDTAQ

DCL-S Success IND INZ( TRUE );
DCL-S Cmd VARCHAR(128) INZ;
DCL-S Mail CHAR(128) INZ;
DCl-DS DataDS QUALIFIED INZ;
 Function CHAR(10);
 RecordType CHAR(2);
 QualJobName LIKEDS( QualJobName_Template );
 FileName CHAR(10);
 FileNbr INT(10);
 QualQueueName LIKEDS( QualQueueName_Template );
 Filler CHAR(56);
END-DS;
//-------------------------------------------------------------------------

  Cmd='CRTDTAQ DTAQ('+%Trim(pQualName.Library)+'/'+
       %Trim(pQualName.OutQ)+') MAXLEN(128) AUT(*EXCLUDE)';
  System(Cmd);
  Cmd='CHGOUTQ OUTQ('+%Trim(pQualName.Library)+'/'+
       %Trim(pQualName.OutQ)+') DTAQ('+
       %Trim(pQualName.Library)+'/'+%Trim(pQualName.OutQ)+')';
  System(Cmd);

  DoW LoopJob();
    Clear DataDS;
    Reset Success;
    Monitor;
      EC#RCVDTAQ(pQualName.OutQ :pQualName.Library
                 :%Len(DataDS) :DataDS :30);
      On-Error;
        Success = FALSE;
    EndMon;

    Success = ( Success And DataDS.Function <> '' );

    If Success And Get_Mailadress(DataDS.QualJobName.JobUser :Mail);
      Monitor;
        EC#SendSpool(DataDS.QualJobName :DataDS.FileName
                     :%Char(DataDS.FileNbr) :Mail);
        On-Error;
          Success = FALSE;
      EndMon;
    EndIf;
  EndDo;

END-PROC;
//* Do_It_With_API ********************************************************
//- Work with SQL-API function OUTPUT_QUEUE_ENTRIES
//*************************************************************************
DCL-PROC Do_It_With_API;
DCL-PI Do_It_With_API;
 pQualName LIKEDS( QualEntryParm_Template ) CONST;
END-PI;

/INCLUDE SND2ME/QRPGLECPY,SLEEP

DCL-S Mail CHAR(128) INZ;
DCL-DS QualJobNameDS LIKEDS( QualJobName_Template ) INZ;
DCL-DS QueryDS QUALIFIED INZ;
 FileName CHAR(10);
 UserName CHAR(10);
 QJobName CHAR(28);
 FileNum INT(10);
END-DS;
//-------------------------------------------------------------------------

  DoW LoopJob();
    Exec SQL DECLARE C#SQLAPI CURSOR FOR
              SELECT A.SPOOLNAME, A.USER_NAME, A.JOB_NAME, A.FILENUM
                FROM QSYS2.OUTPUT_QUEUE_ENTRIES A
               WHERE A.OUTQLIB = :pQualName.Library AND A.OUTQ = :pQualName.OutQ
                 AND A.STATUS = 'READY' FETCH FIRST 50 ROWS ONLY;
    Exec SQL OPEN C#SQLAPI;
    DoW ( SQLCode = stsOK );
      Exec SQL FETCH NEXT FROM C#SQLAPI INTO :QueryDS;
      If ( SQLCode <> stsOK );
        Exec SQL CLOSE C#SQLAPI;
        Leave;
      EndIf;

      If Get_Mailadress(QueryDS.UserName :Mail);
        QualJobNameDS = NormalizeJobName(QueryDS.QJobName);
        EC#SendSpool(QualJobNameDS :QueryDS.FileName
                     :%Char(QueryDS.FileNum) :Mail);
      EndIf;
    EndDo;
    Sleep(10);
  EndDo;

END-PROC;
//* LoopJob ***************************************************************
//- Check for continue loop
//*************************************************************************
DCL-PROC LoopJob;
DCL-PI LoopJob IND END-PI;

DCL-S Success IND INZ( TRUE );
//-------------------------------------------------------------------------

  Success = Success And Not %ShtDn;
  Return Success;

END-PROC;
//* Get_Mailadress ********************************************************
//- Read mailadress from systemdirectory
//*************************************************************************
DCL-PROC Get_Mailadress;
DCL-PI Get_Mailadress IND;
 pUser CHAR(10) CONST;
 pMail CHAR(128);
END-PI;
//-------------------------------------------------------------------------

  Exec SQL SELECT TRIM(A.SMTPUID) CONCAT '@' CONCAT TRIM(A.DOMROUTE)
             INTO :pMail
             FROM QUSRSYS.QATMSMTPA A JOIN QUSRSYS.QAOKL02A B
               ON (B.WOS1USRP = :pUser AND B.WOS1DDEN = A.USERID AND
                   B.WOS1DDGN = A.ADDRESS);
  Return ( SQLCode = stsOK );

END-PROC;
//* NormalizeJobName ******************************************************
//- Extract jobinfo
//*************************************************************************
DCL-PROC NormalizeJobName;
DCL-PI NormalizeJobName LIKEDS( QualJobName_Template );
 pQJobName CHAR(28) CONST;
END-PI;

DCL-S a INT(10) INZ;
DCL-S b INT(10) INZ;
DCL-DS QJobNameDS LIKEDS( QualJobName_Template ) INZ;
DCL-C Len %LEN( pQJobName );
//-------------------------------------------------------------------------

  a = %Scan('/' :pQJobName);
  b = %Scan('/' :pQJobName :a+1);

  QJobNameDS.JobNbr  = %SubSt(pQJobName :1 :a-1);
  QJobNameDS.JobUser = %SubSt(pQJobName :a+1 :b-a-1);
  QJobNameDS.JobName = %SubSt(pQJobName :b+1 :Len-b);

  Return QJobNameDS;

END-PROC;

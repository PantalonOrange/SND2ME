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

//  00000000                        BRC      04.10.2017

CTL-OPT MAIN( Main ) ALWNULL( *USRCTL ) AUT( *EXCLUDE )
        DATFMT( *ISO- ) TIMFMT( *ISO. ) DECEDIT( '0,' ) ALLOC( *TERASPACE )
        DFTACTGRP( *NO ) ACTGRP( *NEW ) DEBUG( *YES ) USRPRF( *OWNER );

// Prototypes -------------------------------------------------------------
/INCLUDE *LIBL/QRPGLECPY,SYSTEM

// Program prototype ------------------------------------------------------
DCL-PR Main EXTPGM( 'SND2MERG' );
 QualName LIKEDS( QualEntryParm ) CONST;
END-PR;

// Global constants -------------------------------------------------------
/INCLUDE *LIBL/QRPGLECPY,SQLDEF
/INCLUDE *LIBL/QRPGLECPY,CONSTANTS

// Global variables -------------------------------------------------------
DCL-DS QualEntryParm QUALIFIED;
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
 pQualName LIKEDS( QualEntryParm ) CONST;
END-PI;

/INCLUDE *LIBL/QRPGLECPY,QRCVDTAQ
DCL-PR EC#SendSpool EXTPGM( 'SND2MECL' );
 QualJobName CONST LIKEDS( QualJobName_Template );
 FileName CHAR(10) CONST;
 FileNbr CHAR(6) CONST;
 Mail CHAR(128) CONST;
END-PR;

DCL-S Success IND INZ( TRUE );
DCL-S User CHAR(10) INZ;
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

  Exec SQL SET OPTION DATFMT=*ISO, DATSEP='-', TIMFMT=*ISO, TIMSEP='.',
                      USRPRF=*OWNER, DYNUSRPRF=*OWNER,
                      CLOSQLCSR = *ENDMOD, COMMIT=*NONE;

  Cmd='CRTDTAQ DTAQ('+%Trim(pQualName.Library)+'/'+
       %Trim(pQualName.OutQ)+') MAXLEN(128) AUT(*EXCLUDE)';
  System(Cmd);
  Cmd='CHGOUTQ OUTQ('+%Trim(pQualName.Library)+'/'+
       %Trim(pQualName.OutQ)+') DTAQ('+
       %Trim(pQualName.Library)+'/'+%Trim(pQualName.OutQ)+')';
  System(Cmd);

  DoW ( Loop );
    Clear DataDS;
    Reset Success;
    Monitor;
      EC#RCVDTAQ(pQualName.OutQ :pQualName.Library
                 :%Len(DataDS) :DataDS :30);
      On-Error;
        Success = FALSE;
    EndMon;

    Success = ( Success And DataDS.Function <> '' );

    If Success;
      User = DataDS.QualJobName.JobUser;
      Exec SQL SELECT STRIP(A.SMTPUID) CONCAT '@' CONCAT STRIP(A.DOMROUTE)
                 INTO :Mail
                 FROM QUSRSYS.QATMSMTPA A JOIN QUSRSYS.QAOKL02A B
                   ON (B.WOS1USRP = :User AND B.WOS1DDEN = A.USERID AND
                       B.WOS1DDGN = A.ADDRESS);
      If ( SQLCode = stsOK );
        Monitor;
          EC#SendSpool(DataDS.QualJobName :DataDS.FileName
                       :%Char(DataDS.FileNbr) :Mail);
          On-Error;
            Success = FALSE;
        EndMon;
      EndIf;
    EndIf;
  EndDo;

  Return;

END-PROC;

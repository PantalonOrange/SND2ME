**FREE
//- Copyright (c) 2017 - 2019 Christian Brunner
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


/INCLUDE SND2ME/QRPGLECPY,OPTCTL


// Program prototype
DCL-PR Main EXTPGM('SND2MERG');
  QualName LIKEDS(QualEntryParm_Template) CONST;
  Type CHAR(5) OPTIONS(*NOPASS) CONST;
END-PR;

// Prototypes
/INCLUDE SND2ME/QRPGLECPY,SYSTEM_H
DCL-PR sendSpoolFile EXTPGM('SND2MECL');
  QualJobName CONST LIKEDS(QualJobName_Template);
  FileName CHAR(10) CONST;
  FileNumber CHAR(6) CONST;
  Mail CHAR(128) CONST;
END-PR;

// Global constants
/INCLUDE SND2ME/QRPGLECPY,BOOL

// Global variables and templates
DCL-DS QualEntryParm_Template TEMPLATE QUALIFIED;
  OutQueue CHAR(10);
  Library CHAR(10);
END-DS;

DCL-DS QualJobName_Template TEMPLATE QUALIFIED;
  JobName CHAR(10);
  JobUser CHAR(10);
  JobNumber CHAR(6);
END-DS;

DCL-DS QualQueueName_Template TEMPLATE QUALIFIED;
  QueueName CHAR(10);
  QueueLibrary CHAR(10);
END-DS;


//#########################################################################
// MAIN-Procedure
//#########################################################################
DCL-PROC Main;
 DCL-PI *N;
   pQualName LIKEDS(QualEntryParm_Template) CONST;
   pType CHAR(5) OPTIONS(*NOPASS) CONST;
 END-PI;
//-------------------------------------------------------------------------

 /INCLUDE SND2ME/QRPGLECPY,OPTSQL

 Select;

   When ( %Parms() = 1 );
     manageSpoolsWithDataQueue(pQualName);

   When ( pType = '*DTAQ' );
     manageSpoolsWithDataQueue(pQualName);

   When ( pType = '*API' );
     manageSpoolsWithAPI(pQualName);

 EndSl;

 Return;

END-PROC;

//* manageSpoolsWithDataQueue *********************************************
// Work with dataqueue-entries
//*************************************************************************
DCL-PROC manageSpoolsWithDataQueue;
 DCL-PI *N;
  pQualName LIKEDS(QualEntryParm_Template) CONST;
 END-PI;

 /INCLUDE SND2ME/QRPGLECPY,QRCVDTAQ_H

 DCL-S Success IND INZ(TRUE);
 DCL-S Command VARCHAR(128) INZ;
 DCL-S Mail CHAR(128) INZ;

 DCL-DS DataDS QUALIFIED INZ;
   Function CHAR(10);
   RecordType CHAR(2);
   QualJobName LIKEDS(QualJobName_Template);
   FileName CHAR(10);
   FileNbr INT(10);
   QualQueueName LIKEDS(QualQueueName_Template);
   Filler CHAR(56);
 END-DS;
//-------------------------------------------------------------------------

 Command = 'CRTDTAQ DTAQ(' + %Trim(pQualName.Library) + '/' +
            %TrimR(pQualName.OutQueue) + ') MAXLEN(128) AUT(*EXCLUDE)';
 system(Command);

 Command = 'CHGOUTQ OUTQ(' + %Trim(pQualName.Library) + '/' +
            %TrimR(pQualName.OutQueue) + ') DTAQ(' +
            %TrimR(pQualName.Library) + '/' + %TrimR(pQualName.OutQueue) + ')';
 system(Command);

 DoW loopJob();

   Clear DataDS;
   Reset Success;

   Monitor;
     recieveDataQueue(pQualName.OutQueue :pQualName.Library :%Len(DataDS)  :DataDS :30);
     On-Error;
       Success = FALSE;
   EndMon;

   Success = ( Success And DataDS.Function <> '' );

   If Success And getMailAddress(DataDS.QualJobName.JobUser :Mail);
     Monitor;
       sendSpoolFile(DataDS.QualJobName :DataDS.FileName :%Char(DataDS.FileNbr) :Mail);
       On-Error;
         Success = FALSE;
     EndMon;
   EndIf;

 EndDo;

 Command = 'CHGOUTQ OUTQ('+%TrimR(pQualName.Library)+'/'+
            %TrimR(pQualName.OutQueue) + ') DTAQ(*NONE)';
 system(Command);

 Command = 'DLTDTAQ DTAQ(' + %TrimR(pQualName.Library) + '/' +
            %TrimR(pQualName.OutQueue) + ')';
 system(Command);

END-PROC;
//* manageSpoolsWithAPI ***************************************************
// Work with SQL-API function OUTPUT_QUEUE_ENTRIES
//*************************************************************************
DCL-PROC manageSpoolsWithAPI;
 DCL-PI *N;
   pQualName LIKEDS(QualEntryParm_Template) CONST;
 END-PI;

 /INCLUDE SND2ME/QRPGLECPY,SLEEP_H

 DCL-S i UNS(3) INZ;
 DCL-S Mail CHAR(128) INZ;
 DCL-S RecordsFound LIKE(SQLEr3) INZ;

 DCL-DS QualJobNameDS LIKEDS(QualJobName_Template) INZ;
 DCL-DS QueryDS QUALIFIED DIM(10) INZ;
   FileName CHAR(10);
   UserName CHAR(10);
   QJobName CHAR(28);
   FileNumber INT(10);
 END-DS;
//-------------------------------------------------------------------------

 DoW loopJob();

   Exec SQL DECLARE C#SQLAPI CURSOR FOR
             SELECT A.SPOOLNAME, A.USER_NAME, A.JOB_NAME, A.FILENUM
               FROM QSYS2.OUTPUT_QUEUE_ENTRIES A
              WHERE A.OUTQLIB = :pQualName.Library AND A.OUTQ = :pQualName.OutQueue
                AND A.STATUS = 'READY'
              ORDER BY CREATED FETCH FIRST 10 ROWS ONLY;

   Exec SQL OPEN C#SQLAPI;

   If ( SQLCode = 0 );

     Exec SQL FETCH FROM C#SQLAPI FOR 10 ROWS INTO :QueryDS;

     RecordsFound = SQLEr3;

     Exec SQL CLOSE C#SQLAPI;

     For i = 1 To RecordsFound;

       If getMailAddress(QueryDS(i).UserName :Mail);

         QualJobNameDS = normalizeJobName(QueryDS(i).QJobName);
         sendSpoolFile(QualJobNameDS :QueryDS(i).FileName :%Char(QueryDS(i).FileNumber) :Mail);

       EndIf;

     EndFor;

   EndIf;

   sleep(10);

 EndDo;

END-PROC;
//* loopJob ***************************************************************
// Here you can place your own control instructions
//*************************************************************************
DCL-PROC loopJob;
 DCL-PI *N IND END-PI;
//-------------------------------------------------------------------------

 Return Not %ShtDn;

END-PROC;
//* getMailAddress ********************************************************
// Read mailaddress from systemdirectory
//*************************************************************************
DCL-PROC getMailAddress;
 DCL-PI *N IND;
   pUser CHAR(10) CONST;
   pMail CHAR(128);
 END-PI;
//-------------------------------------------------------------------------

 Exec SQL SELECT TRIM(A.SMTPUID) CONCAT '@' CONCAT TRIM(A.DOMROUTE) INTO :pMail
            FROM QUSRSYS.QATMSMTPA A JOIN QUSRSYS.QAOKL02A B
              ON (B.WOS1USRP = :pUser AND B.WOS1DDEN = A.USERID AND
                  B.WOS1DDGN = A.ADDRESS);

 Return ( SQLCode = 0 );

END-PROC;
//* normalizeJobName ******************************************************
// Extract jobinfo
//*************************************************************************
DCL-PROC normalizeJobName;
 DCL-PI *N LIKEDS(QualJobName_Template);
   pQJobName CHAR(28) CONST;
 END-PI;

 DCL-S a INT(10) INZ;
 DCL-S b INT(10) INZ;

 DCL-C LEN %LEN(pQJobName);

 DCL-DS QJobNameDS LIKEDS(QualJobName_Template) INZ;
//-------------------------------------------------------------------------

 a = %Scan('/' :pQJobName);
 b = %Scan('/' :pQJobName :a + 1);

 QJobNameDS.JobNumber = %SubSt(pQJobName :1 :a - 1);
 QJobNameDS.JobUser = %SubSt(pQJobName :a + 1 :b - a - 1);
 QJobNameDS.JobName = %SubSt(pQJobName :b + 1 :LEN - b);

 Return QJobNameDS;

END-PROC;

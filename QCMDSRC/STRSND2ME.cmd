             CMD        PROMPT('START SND2ME MAIL-PDF') TEXT('START +
                          SND2ME MAIL-PDF') ALLOW(*ALL) MODE(*ALL) +
                          ALWLMTUSR(*NO) HLPID(*CMD) +
                          HLPPNLGRP(SND2ME/STRSND2ME) PRDLIB(SND2ME) +
                          AUT(*EXCLUDE)

             PARM       KWD(OUTQ) TYPE(QUAL) MIN(1) CHOICE('Valid +
                          Outqueue') PROMPT('Outqueue')
             PARM       KWD(TYPE) TYPE(*CHAR) LEN(5) RSTD(*YES) +
                          DFT(*DTAQ) VALUES(*DTAQ *API) PROMPT('Type')

 QUAL:       QUAL       TYPE(*NAME) DFT(SND2ME) MIN(0)
             QUAL       TYPE(*NAME) DFT(*LIBL) SPCVAL((*LIBL *LIBL)) +
                          MIN(0) PROMPT('Library')

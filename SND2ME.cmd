             CMD        PROMPT('SND2ME MAIL-PDF') TEXT('SND2ME +
                          MAIL-PDF') ALWLMTUSR(*NO) AUT(*EXCLUDE)

             PARM       KWD(OUTQ) TYPE(QUAL) MIN(1) CHOICE('Valid +
                          Outqueue') PROMPT('Outqueue')
             PARM       KWD(TYPE) TYPE(*CHAR) LEN(5) RSTD(*YES) +
                          DFT(*DTAQ) VALUES(*DTAQ *API) PROMPT('Type')

 QUAL:       QUAL       TYPE(*NAME) DFT(SND2ME) MIN(0)
             QUAL       TYPE(*NAME) DFT(*LIBL) SPCVAL((*LIBL *LIBL)) +
                          MIN(0) PROMPT('Library')
             CMD        PROMPT('SND2ME MAIL-DELIVERY') TEXT('SND2ME +
                          MAIL-DELIVERY') ALWLMTUSR(*NO) AUT(*EXCLUDE)
             PARM       KWD(OUTQ) TYPE(QUAL1) MIN(1) +
                          PROMPT('Outqueue')
 QUAL1:      QUAL       TYPE(*NAME) DFT(SND2ME) MIN(0)
             QUAL       TYPE(*NAME) DFT(*LIBL) SPCVAL((*LIBL *LIBL)) +
                          MIN(0) PROMPT('Library')

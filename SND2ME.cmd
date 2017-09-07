             CMD        PROMPT('SND2ME MAIL-VERSAND') TEXT('SND2ME +
                          MAIL-VERSAND') ALWLMTUSR(*NO) AUT(*EXCLUDE)
             PARM       KWD(OUTQ) TYPE(QUAL1) MIN(1) +
                          PROMPT('Ausgabewarteschlange')
 QUAL1:      QUAL       TYPE(*NAME) DFT(SND2ME) MIN(0)
             QUAL       TYPE(*NAME) DFT(*LIBL) MIN(0) +
                          PROMPT('Bibliothek')

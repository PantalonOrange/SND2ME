**FREE
/if not defined (#API_SYSTEM)
/define #API_SYSTEM
DCL-S SystemErrorReturned CHAR(7) IMPORT( '_EXCP_MSGID' );
DCL-PR System INT(10) EXTPROC( 'system' );
 String POINTER VALUE OPTIONS( *STRING );
END-PR;
/endif

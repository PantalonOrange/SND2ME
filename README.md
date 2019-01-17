# SND2ME
IBMi - Convert SPLF to PDF and send them via mail to yourself

This program was written for IBMi 7.2  
Be sure your SMTP-Service is configured correctly on your IBMi and every user is configured in the SMTP-Systemdirectory (WRKNAMSMTP *SYSTEM)  

This program is using DTAQs or the SQL-View OUTPUT_QUEUE_ENTRIES  

## Compile objects
Copy sources to your local sourcefiles (qrpglesrc etc) on your IBMi und compile them with seu option "14"

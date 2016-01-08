---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT TO ANOTHER DEDICATED ACCOUNT --
---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT TO ANOTHER DEDICATED ACCOUNT --
---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT TO ANOTHER DEDICATED ACCOUNT --
---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT TO ANOTHER DEDICATED ACCOUNT --
---------------------------------------------------------------

DECLARE
  BDumpDir VARCHAR2(200);
  SID VARCHAR2(16);
  ObjectExists EXCEPTION;
  PRAGMA EXCEPTION_INIT(ObjectExists,-955);
BEGIN
  -- get the bdump dir
  SELECT value
  INTO BDumpDir
  FROM v$parameter
  WHERE name='background_dump_dest';
  -- create the directory for the bdump dir
  EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY bdump_dir AS '''||BDumpDir||'''';
  -- grant the necessary privileges
---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT HERE --
---------------------------------------------------------------
  EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY bdump_dir TO system';
  -- get the SID
  SELECT instance_name INTO SID FROM v$instance;
  -- create the external table
  EXECUTE IMMEDIATE 'CREATE TABLE system.alert_log_external
(TEXT VARCHAR2(255)
) ORGANIZATION EXTERNAL
(TYPE ORACLE_LOADER
DEFAULT DIRECTORY BDUMP_DIR
ACCESS PARAMETERS
(RECORDS DELIMITED BY NEWLINE
NOBADFILE
NOLOGFILE
FIELDS MISSING FIELD VALUES ARE NULL
)
LOCATION (''alert_'||SID||'.log'')
)
REJECT LIMIT UNLIMITED';
---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT HERE --
---------------------------------------------------------------
    EXECUTE IMMEDIATE 'GRANT SELECT ON system.alert_log_external TO system';
-- ignore ORA-955 errors (object already exists)
EXCEPTION WHEN ObjectExists THEN NULL;
END;
/

CREATE OR REPLACE FUNCTION system.alert_log_date( text IN VARCHAR2 )
  RETURN DATE
IS
  InvalidDate EXCEPTION;
  PRAGMA EXCEPTION_INIT(InvalidDate, -1846);
BEGIN
  RETURN TO_DATE(text,'Dy Mon DD HH24:MI:SS YYYY');
EXCEPTION
  WHEN InvalidDate THEN RETURN NULL;
END;
/

CREATE OR REPLACE FUNCTION system.oracle_to_unix(in_date IN DATE)
RETURN NUMBER
IS
BEGIN
  RETURN (in_date -TO_DATE('19700101','yyyymmdd'))*86400 -
  TO_NUMBER(SUBSTR(TZ_OFFSET(sessiontimezone),1,3))*3600;
END;
/
CREATE OR REPLACE FORCE VIEW system.alert_log as
SELECT row_num
      ,LAST_VALUE(low_row_num IGNORE NULLS)
         OVER(ORDER BY row_num ROWS BETWEEN UNBOUNDED PRECEDING
         AND CURRENT ROW) start_row
      ,LAST_VALUE(alert_date IGNORE NULLS)
         OVER(ORDER BY row_num ROWS BETWEEN UNBOUNDED PRECEDING
         AND CURRENT ROW) alert_date
      ,LAST_VALUE(alert_timestamp IGNORE NULLS)
         OVER(ORDER BY row_num ROWS BETWEEN UNBOUNDED PRECEDING
         AND CURRENT ROW) alert_timestamp
      ,alert_text
FROM (SELECT ROWNUM row_num
            ,NVL2(system.alert_log_date(text),ROWNUM,NULL) low_row_num
            ,system.alert_log_date(text) alert_date
            ,system.oracle_to_unix(system.alert_log_date(text))
                alert_timestamp
            ,text alert_text
      FROM system.alert_log_external
     )
;

DECLARE
  ObjectExists EXCEPTION;
  PRAGMA EXCEPTION_INIT(ObjectExists,-955);
BEGIN
  EXECUTE IMMEDIATE
      'CREATE PUBLIC SYNONYM alert_log FOR system.alert_log';
-- If the synonym exists, drop and recreate it
EXCEPTION WHEN ObjectExists THEN
  EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM alert_log';
  EXECUTE IMMEDIATE
      'CREATE PUBLIC SYNONYM alert_log FOR system.alert_log';
---------------------------------------------------------------
-- PLEASE CHANGE SYSTEM ACCOUNT HERE --
---------------------------------------------------------------
  EXECUTE IMMEDIATE 'GRANT SELECT ON alert_log TO system';
END;
/



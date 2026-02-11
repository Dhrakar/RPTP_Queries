-- Show license usage
SELECT DISTINCT
  '[' || lpad(used.producttype,4,'0') || '] ' || DECODE (
    used.producttype,
      2, 'Workstation Client',
      3, 'COLD/ERM',
     11, 'Document Import Processor',
     16, 'Concurrent Client',
     48, 'WorkFlow Concurrent Client',
    102, 'Named User Client',
    126, 'WorkFlow Named User',
    137, 'Disconnected Scanning',
    339, 'Production TWAIN Scanning',
    389, 'Batch Automatic Indexing',
    478, 'Advanced Capture',
    used.producttype
  )                      AS license,
  LISTAGG( DISTINCT trim(usr.registername),',' )  AS systems
FROM
  HSI.LICUSAGE used
  JOIN HSI.REGUSERSPRODUCTS reg ON (
    reg.producttype = used.producttype
  )
  JOIN HSI.REGISTEREDUSERS usr ON (
    usr.registernum = reg.registernum 
  )
WHERE
  used.logdate >= to_date('01-JAN-2025', 'DD-MON-YYYY')
  AND used.producttype IN (3, 6, 11, 102, 137, 339, 478)
GROUP BY
  '[' || lpad(used.producttype,4,'0') || '] ' || DECODE (
    used.producttype,
      2, 'Workstation Client',
      3, 'COLD/ERM',
     11, 'Document Import Processor',
     16, 'Concurrent Client',
     48, 'WorkFlow Concurrent Client',
    102, 'Named User Client',
    126, 'WorkFlow Named User',
    137, 'Disconnected Scanning',
    339, 'Production TWAIN Scanning',
    389, 'Batch Automatic Indexing',
    478, 'Advanced Capture',
    used.producttype
  )
;

-- =============================
--   Consolidated report of 
--  current license assignments
-- =============================
-- workstation specifc licenses
SELECT DISTINCT
  '[' || lpad(used.producttype,4,'0') || '] ' || DECODE (
    used.producttype,
      2, 'Workstation Client',
      3, 'COLD/ERM',
     11, 'Document Import Processor',
     16, 'Concurrent Client',
     48, 'WorkFlow Concurrent Client',
    137, 'Disconnected Scanning',
    339, 'Production TWAIN Scanning',
    389, 'Batch Automatic Indexing',
    478, 'Advanced Capture',
    used.producttype
  )                      AS product_license,
  count(distinct trim(usr.registername)) AS total_assigned
FROM
  HSI.LICUSAGE used
  JOIN HSI.REGUSERSPRODUCTS reg ON (
    reg.producttype = used.producttype
  )
  JOIN HSI.REGISTEREDUSERS usr ON (
    usr.registernum = reg.registernum 
  )
GROUP BY
  '[' || lpad(used.producttype,4,'0') || '] ' || DECODE (
    used.producttype,
      2, 'Workstation Client',
      3, 'COLD/ERM',
     11, 'Document Import Processor',
     16, 'Concurrent Client',
     48, 'WorkFlow Concurrent Client',
    137, 'Disconnected Scanning',
    339, 'Production TWAIN Scanning',
    389, 'Batch Automatic Indexing',
    478, 'Advanced Capture',
    used.producttype
  )
  
UNION

-- user specific licenses
-- bin_to_num(1,0,0,0,0,0,0,0,0,0) - Group Administrator (not a license)
-- bin_to_num(0,0,0,1,0,0,0,0,0,0) - WF Named User
-- bin_to_num(0,0,0,0,0,0,0,0,0,1) - Named User
SELECT
  '[0102] Named User'  AS product_license,
  sum(
    CASE
      WHEN BITAND(emp.licenseflag, 1) = 1 THEN 1
      ELSE 0
    END
  )                    AS total_assigned
FROM
  HSI.USERACCOUNT emp
WHERE
   -- don't get the system accounts
  emp.usernum > 100
   -- only current users (
  AND emp.username NOT LIKE '%(de%'
  
UNION

SELECT
  '[0136] Named WF User'  AS license,
  sum(
    CASE
      WHEN BITAND(emp.licenseflag, 64) = 64 THEN 1
      ELSE 0
    END
  )                    AS total
FROM
  HSI.USERACCOUNT emp
WHERE
   -- don't get the system accounts
  emp.usernum > 100
   -- only current users (
  AND emp.username NOT LIKE '%(de%'
;  


select BITAND(usr.licenseflag, 64), usr.licenseflag from USERACCOUNT usr where usr.usernum = 4522;

select bin_to_num(1,0,0,0,0,0,0), bitand(bin_to_num(1,0,0,0,0,0,0), 64) from dual;

select distinct username,licenseflag from useraccount where username NOT LIKE '%(de%' and licenseflag > 0;

-- USERXLICENSE
-- LICENSEDPRODUCT
-- LOGGERUSER
-- REGUSERSPRODUCTS
-- REGISTEREDUSERS
-- trim(usr.registername)
-- ===========================================================
--     Employee Core Data Lookup
-- Searches for an employee by either UA ID, UA Username or 
-- legacy BannerID.
-- ============================================================
SELECT 
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                         AS "Campus",
  org.title3                AS "Unit",
  org.title                 AS "Department",
  org.orgn_code             AS "dLevel",
  stat.pebempl_orgn_code_dist AS "TKL",
  emp.spriden_pidm          AS "Banner PIDM",
  usr.gobtpac_external_user AS "Username",
  emp.spriden_id            AS "UA ID", 
  ban.gobeacc_username      AS "Banner ID",
  emp.spriden_first_name    
    || NVL2 ( 
              bio.spbpers_pref_first_name,
              ' (' || bio.spbpers_pref_first_name || ')',
              ''
      )                     AS "First Name",
  emp.spriden_mi            AS "Middle Name",
  emp.spriden_last_name     AS "Last Name",
  stat.pebempl_empl_status  AS "Job Status",
  stat.pebempl_term_date    AS "Term Date",
  SYSDATE                   AS "Date Pulled",
  stat.pebempl_adj_service_date AS "Adj Service Date",
  stat.pebempl_first_hire_date  AS "Hired Date"
FROM 
  GOBTPAC usr
  JOIN SPRIDEN emp ON (
    usr.gobtpac_pidm = emp.spriden_pidm
    AND emp.spriden_change_ind IS NULL
  )
  JOIN SPBPERS bio ON emp.spriden_pidm = bio.spbpers_pidm 
  LEFT JOIN GOBEACC ban ON emp.spriden_pidm = ban.gobeacc_pidm
  JOIN PEBEMPL stat ON usr.gobtpac_pidm = stat.pebempl_pidm
  LEFT JOIN FTVORGN_LEVELS org ON stat.pebempl_orgn_code_home = org.orgn_code
WHERE 
    UPPER(ban.gobeacc_username)       = TRIM(UPPER(:bannerid))
  OR UPPER(emp.spriden_id)            = TRIM(UPPER(:uaid))
  OR UPPER(usr.gobtpac_external_user) = TRIM(UPPER(:username))
ORDER BY
  stat.pebempl_empl_status DESC, org.level1, usr.gobtpac_external_user
;
-- =============================================================================
-- = SRDD Employee Longevity Recipients                                        
-- =  - uses a seed year to calculate the 5,10,15,20,25,30,35,40 awards based  
-- =    on the PEBEMPL_ADJ_SERVICE_DATE field 
-- =  - This code should be run as close to Dec 31 of the Award year as possible
-- =   If run in the next year, then thre start to be folks who are eligible for
-- =   awards, but that have retired and/or terminated.  HR needs to validate 
-- =   the list for folks that have been terminated for less-than-good reasons.
-- =                                          
-- =  @param :srdd_year Calendar year (YYYY) used to calculate the awards.
-- =         NOTE: this is the year they earned the award, not the year of the 
-- =              longevity ceremony.
-- = 
-- =  - 2017 dlb - initial version                                             
-- =  - 201805   - reformatted to match current style and migrate filters into
-- =              the JOINs.  
-- =               Made NBRBJOB a regular JOIN. 
-- =               Added bucket col for easier year sorting
-- =               Added preferred first name (if set)
-- =  - 202110   - updated method for getting email address
-- =               Added mailing address
-- =============================================================================
SELECT DISTINCT
  :srdd_year - 
    EXTRACT( year FROM 
      empl.pebempl_adj_service_date
    )                           AS "Service Years",
  se.spriden_id                 AS "UA ID",
  se.spriden_last_name
   || ', ' 
   || NVL2( pref.spbpers_pref_first_name,
            pref.spbpers_pref_first_name,
            se.spriden_first_name
          ) 
   || ' ' 
   || SUBSTR(se.spriden_mi,0,1) AS "Full Name",
  usr.gobtpac_external_user 
    || '@alaska.edu'            AS "UA Email",
  a.spraddr_street_line1 
    || ', ' || a.spraddr_city 
    || ', ' || a.spraddr_stat_code 
    || ', ' || a.spraddr_zip    AS "Mailing Address",
  dsduaf.f_decode$orgn_campus(
    org.level1
  )                             AS "Campus",
  org.title2                    AS "Cabinet",
  org.title3                    AS "Unit",
  org.title                     AS "Department",
  empl.pebempl_orgn_code_dist   AS "TKL",
  empl.pebempl_ecls_code        AS "Position eClass",
  empl.pebempl_adj_service_date AS "Service Date",
  empl.pebempl_seniority_date   AS "Senority Date",
  job.nbrbjob_begin_date        AS "Contract Start Date",
  job.nbrbjob_end_date          AS "Contract End Date",
  boss.spriden_id               AS "Supervisor UA ID",
  boss.spriden_first_name 
    || ' ' 
    || boss.spriden_last_name   AS "Supervisor Name",
  busr.gobtpac_external_user
    || '@alaska.edu'            AS "Supervisor Email"
FROM
  PAYROLL.PEBEMPL empl
  JOIN SATURN.SPRIDEN se         ON (
    -- only current SPRIDEN record
      empl.pebempl_pidm = se.spriden_pidm
	  AND se.spriden_change_ind IS NULL
  )	
  JOIN SATURN.SPBPERS pref       ON ( 
      se.spriden_pidm = pref.spbpers_pidm
    AND (pref.spbpers_ssn NOT LIKE 'BAD%' OR pref.spbpers_ssn IS NULL)
    AND pref.spbpers_dead_ind IS NULL
  )
  JOIN GENERAL.GOBTPAC usr  ON (
    usr.gobtpac_pidm = empl.pebempl_pidm
  )
  LEFT JOIN SATURN.SPRADDR a ON (
    -- get just the mailing address
      empl.pebempl_pidm = a.spraddr_pidm
    AND a.spraddr_atyp_code = 'MA'
  )
  JOIN REPORTS.FTVORGN_LEVELS org ON (
        empl.pebempl_orgn_code_home = org.orgn_code
    -- limit to only UAF orgs
	  AND org.level1 = 'UAFTOT'
  )
  JOIN POSNCTL.NBRBJOB job   ON (
        empl.pebempl_pidm = nbrbjob_pidm 
    -- only primary job		
    AND job.nbrbjob_contract_type = 'P'  
    -- just current contracts
    AND job.nbrbjob_begin_date <= CURRENT_DATE
    AND (job.nbrbjob_end_date >= CURRENT_DATE OR job.nbrbjob_end_date IS NULL)
  )
  LEFT JOIN NBRJOBS pos ON ( 
    job.nbrbjob_pidm = pos.nbrjobs_pidm
    AND job.nbrbjob_posn = pos.nbrjobs_posn
    AND job.nbrbjob_suff = pos.nbrjobs_suff
  )
  LEFT JOIN NER2SUP sup ON (
        job.nbrbjob_pidm = sup.ner2sup_pidm
    AND job.nbrbjob_posn = sup.ner2sup_posn
    AND job.nbrbjob_suff = sup.ner2sup_suff
    AND sup.ner2sup_sup_ind = 'Y'
  )
  LEFT JOIN SPRIDEN boss ON (
    boss.spriden_pidm = sup.ner2sup_sup_pidm
    AND boss.spriden_change_ind IS NULL
  )
  LEFT JOIN GOBTPAC busr ON 
    boss.spriden_pidm = busr.gobtpac_pidm
WHERE
  -- only active employees (comment out if running past Dec 31)
  empl.pebempl_empl_status <> 'T' 
  -- only the full time, regular ECLS codes
  AND empl.pebempl_ecls_code IN ( 
      'EX', -- Executives
      'CR', -- craft/trade
      'NR', -- non exempt
      'XR'  -- Exempt from overtime
  )
  -- limit to the most current position (if exists)
  AND (
       pos.nbrjobs_pidm IS NULL 
    OR pos.nbrjobs_effective_date = (     
      SELECT MAX (pos2.nbrjobs_effective_date)
      FROM NBRJOBS pos2
      WHERE (
            pos.nbrjobs_pidm = pos2.nbrjobs_pidm
        AND pos.nbrjobs_posn = pos2.nbrjobs_posn
        AND pos.nbrjobs_suff = pos2.nbrjobs_suff
      )
    )
  )
  -- limit to the most current supervisor record (if exists)
  AND (
       sup.ner2sup_pidm IS NULL 
    OR sup.ner2sup_effective_date = (
      SELECT MAX (sup2.ner2sup_effective_date)
      FROM NER2SUP sup2
      WHERE (
            sup2.ner2sup_sup_ind = 'Y'
        AND sup.ner2sup_pidm = sup2.ner2sup_pidm
        AND sup.ner2sup_posn = sup2.ner2sup_posn
        AND sup.ner2sup_suff = sup2.ner2sup_suff
      )
    )
  )
  -- only the most current mailing address (if there is one)
  AND (
    a.spraddr_seqno IS NULL
    OR a.spraddr_seqno = (
      SELECT MAX(a2.spraddr_seqno) 
      FROM SPRADDR a2
      WHERE 
        a.spraddr_pidm = a2.spraddr_pidm
        AND a2.spraddr_atyp_code = 'MA'
    )
  )
  -- now filter out just the folks in the year brackets
  AND (
       empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 1), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 1), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 5), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 5), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 10), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 10), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 15), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 15), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 20), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 20), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 25), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 25), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 30), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 30), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 35), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 35), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 40), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 40), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 45), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 45), 'mm/dd/yyyy')
    OR empl.pebempl_adj_service_date BETWEEN to_date('01/01/' || (:srdd_year - 50), 'mm/dd/yyyy') 
                                 AND to_date('12/31/' || (:srdd_year - 50), 'mm/dd/yyyy')
  )
ORDER BY
  "Service Years", 
  "Full Name"



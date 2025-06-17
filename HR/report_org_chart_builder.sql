-- =============================================================================
--  SQL For pulling data for an org chart
--  - only counts primary jobs
--  - includes supervisor PIDM
--  - name, posn, title, posn classification, fte, grade, step, salary
--  - includes temps, students and term funded
-- =============================================================================
SELECT
  -- emp.spriden_id               AS "UA ID",
  emp.spriden_first_name || ' ' || emp.spriden_last_name AS name,
  boss.spriden_first_name  || ' ' || boss.spriden_last_name AS reports_to,
--  emp.spriden_last_name 
--    || ', ' 
--    || emp.spriden_first_name
--    || ' '
--    || substr(emp.spriden_mi,1,1) AS "Full Name",
--  addr.gobtpac_external_user 
--    || '@alaska.edu'           AS "UA Email",
--  dsduaf.f_decode$orgn_campus(org.level1)                AS "Campus",
--  org.title2                   AS "Cabinet",
--  org.title3                   AS "Unit",
--  org.title                    AS "Department",
--  orgn_code                    AS "dLevel",
--  emp.nbrbjob_posn
--   || '/' 
--   || emp.nbrbjob_suff         AS "Position",
  emp.nbrjobs_desc             AS title,
  '' AS department, '' AS telephone
--  emp.nbrbjob_begin_date       AS "Position Start Date",
--  emp.nbrbjob_end_date         AS "Position End Date",
--  emp.nbrjobs_ecls_code        AS "Position eClass",
--  DSDUAF.F_DECODE$BENEFITS_CATEGORY( 
--    emp.nbrjobs_ecls_code
--  )                            AS "Position Category",
  -- emp.nbrjobs_fte              AS "Position FTE",
  -- emp.pebempl_ecls_code        AS "Employee Class",
  -- emp.nbrbjob_contract_type    AS "Contract Type",
  -- emp.nbrjobs_sal_grade        AS "Grade",
  -- emp.nbrjobs_sal_step         AS "Step",
  -- emp.nbrjobs_ann_salary       AS "Salary",
--  boss.spriden_id              AS "Supervisor UA ID",
--  boss.spriden_last_name
--   || ', ' 
--   || boss.spriden_first_name 
--   || ' ' 
--   || substr(boss.spriden_mi,1,1) AS "Supervisor Name"
FROM
  n_active_jobs emp
  JOIN gobtpac addr  ON (
    -- grab the UA username
	    emp.pebempl_pidm = addr.gobtpac_pidm
  )
  JOIN ftvorgn_levels org ON (
    emp.pebempl_orgn_code_home = org.orgn_code
    -- AND org.level1 = 'UAFTOT'
  )
  LEFT JOIN ner2sup sup   ON (
     -- join to the supervisor table
        emp.nbrbjob_pidm = sup.ner2sup_pidm
    AND emp.nbrbjob_posn = sup.ner2sup_posn
    AND emp.nbrbjob_suff = sup.ner2sup_suff
     -- just get the management supervisor
    AND sup.ner2sup_sup_ind = 'Y'
  )
  LEFT JOIN spriden boss ON (
    sup.ner2sup_sup_pidm = boss.spriden_pidm
    AND boss.spriden_change_ind IS NULL
  )
WHERE
  -- only primary jobs
  emp.nbrbjob_contract_type ='P'
  --  Filters ( like org level of job title, etc)
  AND org.level6 = 'D5OIR'
  -- AND emp.nbrjobs_desc LIKE 'IS %'
  -- only the most current record
  AND ( 
    sup.ner2sup_pidm IS NULL 
    OR sup.ner2sup_effective_date = (
      SELECT MAX (sup2.ner2sup_effective_date)
      FROM ner2sup sup2
      WHERE (
            sup.ner2sup_pidm = sup2.ner2sup_pidm
        AND sup.ner2sup_posn = sup2.ner2sup_posn
        AND sup.ner2sup_suff = sup2.ner2sup_suff
        AND sup2.ner2sup_sup_ind = 'Y'
      )
    )
  )
ORDER BY
  org.level1, org.level2, org.level3, org.orgn_code, emp.spriden_id
;

-- ===============================
--  Using Positions for org chart
-- ===============================
SELECT
  org.title6                   AS "Department",
  posn.nbrptot_orgn_code       AS "Org Code",
  par.ftvorgn_orgn_code_pred   AS "Parent Org Code",
  emp.spriden_id               AS "UA ID",
  CASE
    WHEN emp.spriden_id IS NULL
    THEN 'Vacant'
    ELSE
      emp.spriden_last_name 
        || ', ' 
        || emp.spriden_first_name
        || ' '
        || emp.spriden_mi          
  END                          AS "Full Name",
  posn.nbrptot_posn            AS "Position",
  emp.nbrjobs_desc             AS "Position Title",
  emp.nbrbjob_begin_date       AS "Position Start Date",
  emp.nbrbjob_end_date         AS "Position End Date",
  emp.nbrjobs_ecls_code        AS "Position eClass",
  emp.nbrjobs_fte              AS "Position FTE",
  posn.nbrptot_budget          AS "Position Budget",
  emp.pebempl_ecls_code        AS "Employee Class",
  emp.nbrjobs_sal_grade        AS "Grade",
  emp.nbrjobs_sal_step         AS "Step",
  emp.nbrjobs_ann_salary       AS "Salary"
FROM
  NBRPTOT posn
  -- add the position information and filter to just regular PCNs
  JOIN NBBPOSN job ON (
    posn.nbrptot_posn = job.nbbposn_posn
    AND (
      job.nbbposn_bpro_code = 'REG'
      OR job.nbbposn_bpro_code = 'TERM'
    )
    AND job.nbbposn_status = 'A'
  )
  -- get details on teh people assigned to the PCNs
  LEFT JOIN N_ACTIVE_JOBS emp ON ( 
    posn.nbrptot_posn = emp.nbrbjob_posn
    AND emp.nbrbjob_contract_type ='P'
  )
  -- get job details for positions
  JOIN NBRJOBS vpcn ON  posn.nbrptot_posn = vpcn.nbrjobs_posn
  -- get details on the org hierarchy for each PCN
  JOIN ftvorgn_levels org ON (
    posn.nbrptot_orgn_code = org.orgn_code
    AND org.level1 = 'UAFTOT'
  )
  JOIN ftvorgn_current par ON (
    org.level6 = par.ftvorgn_orgn_code
    AND par.ftvorgn_status_ind = 'A'
  )
WHERE
  posn.nbrptot_fisc_code = 2018
  AND vpcn.nbrjobs_effective_date = (
    SELECT 
      MAX( vpcn_inner.nbrjobs_effective_date )
    FROM 
      NBRJOBS vpcn_inner
    WHERE
      vpcn_inner.nbrjobs_posn = posn.nbrptot_posn
      AND vpcn_inner.nbrjobs_status = 'A'
  )
  AND posn.nbrptot_status = 'A'
  AND org.level3 = '5AVCFS'
ORDER BY
  org.title6,
  posn.nbrptot_orgn_code,
  posn.nbrptot_posn
;
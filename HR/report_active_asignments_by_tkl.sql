WITH
  employee_base AS (
    SELECT
      a.*,
      ( select spriden_pidm 
        from spriden 
        where spriden_id = a.employee_id 
          and spriden_change_ind is null 
      ) as pidm
    FROM 
      REPORTS.ACTIVE_ASSIGNMENTS a
    WHERE
      a.job_tkl = :job_tkl
  ),
  supervisor_info AS (
    SELECT
      a.spriden_pidm AS pidm,
      a.spriden_id   AS uaid,
      a.spriden_last_name || ', ' || COALESCE(b.spbpers_pref_first_name, a.spriden_first_name) AS name,
      c.gobtpac_external_user || '@alaska.edu' AS email
    FROM SATURN.SPRIDEN a
      INNER JOIN SATURN.SPBPERS b ON a.spriden_pidm = b.spbpers_pidm
      INNER JOIN GENERAL.GOBTPAC c ON a.spriden_pidm = c.gobtpac_pidm
    WHERE a.spriden_change_ind IS NULL
  ),
  ranked_positions AS (
    --// Temp table ranked by effective date of active positions
    SELECT 
      a.*, 
      DENSE_RANK() OVER (
        PARTITION BY a.nbrjobs_pidm, a.nbrjobs_posn, a.nbrjobs_suff 
        ORDER BY a.nbrjobs_effective_date DESC
      ) as row_no
    FROM POSNCTL.NBRJOBS a
    WHERE 
      -- only include currently active positions
      a.nbrjobs_status = 'A'
      -- limit the rows of positions to just the employees in the temp table
      AND a.nbrjobs_pidm IN ( SELECT pidm FROM employee_base )
  )
SELECT
  emp.employee_id AS "Employee ID",
  emp.name_first AS "Employee First",
  emp.emp_name_last AS "Employee Last",
  emp.pcn_number AS "PCN Number",
  emp.suff AS SUFFIX,
  emp.job_ecls AS ECLS,
  emp.job_title AS CLASSIFICATION,
  emp.job_begin AS "Job Begin",
  emp.job_end AS "Job End",
  emp.grade,
  emp.step,
  emp.rate,
  emp.hrs_per_pay AS "Biweekly Hours",
  emp.biweekly AS "Biweekly Salary",
  emp.factor,
  emp.annual AS "Annual Salary",
  boss.uaid                   AS "Supervisor UA ID",
  boss.name                   AS "Supervisor Name",
  boss.email                  AS "Supervisor Email"
FROM
  -- start from the temp table of employees for this TKL
  employee_base emp
  -- join in the windowed positions (use ranking to get current one)
  LEFT JOIN ranked_positions pos ON (
        pos.nbrjobs_pidm = emp.pidm
    AND pos.nbrjobs_posn = emp.pcn_number
    AND pos.nbrjobs_suff = emp.suff
    AND pos.row_no = 1
  ) 
  -- grab identity info for the supervisor (if assigned)
  LEFT JOIN supervisor_info boss  ON (
    boss.pidm = pos.nbrjobs_supervisor_pidm
  )
;

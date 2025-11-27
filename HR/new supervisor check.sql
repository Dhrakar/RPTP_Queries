
           
SELECT
  job.nbrjobs_supervisor_pidm AS supervisor_pidm,
  nvl( -- if no supervisor change date, use most recent change date
    to_char(chg.nbrjobs_effective_date, 'MM/DD/YYYY'),
    to_char(job.nbrjobs_effective_date, 'MM/DD/YYYY')
  )                           AS supervisor_change_date,
  emp.spriden_id              AS uaid,
  emp.spriden_last_name 
    || ', ' || emp.spriden_first_name 
    || ' '  || emp.spriden_mi AS full_name
FROM
  -- start with the table of jobs for a position
  POSNCTL.NBRJOBS job
  -- get the matching, active person record
  INNER JOIN SATURN.SPRIDEN emp ON (
        emp.spriden_change_ind IS NULL
    AND emp.spriden_pidm = job.nbrjobs_pidm
  )
  -- get the effective date of the supervisor change (if any)
  LEFT JOIN POSNCTL.NBRJOBS chg ON (
        chg.nbrjobs_pidm = job.nbrjobs_pidm
    AND chg.nbrjobs_posn = job.nbrjobs_posn
    AND chg.nbrjobs_suff = job.nbrjobs_suff
    AND chg.nbrjobs_jcre_code = 'SPCHG'
  )
WHERE
  -- filter to just a specific employee
  emp.spriden_id = '30057994'
  -- filter to a specific posn/suff
  AND job.nbrjobs_posn = '100000' AND job.nbrjobs_suff = '00'
  -- filter to the most recent record
  AND job.nbrjobs_effective_date = (
    SELECT MAX(i.nbrjobs_effective_date)
    FROM POSNCTL.NBRJOBS i
    WHERE i.nbrjobs_pidm = job.nbrjobs_pidm
      AND i.nbrjobs_posn = job.nbrjobs_posn
      AND i.nbrjobs_suff = job.nbrjobs_suff
      AND i.nbrjobs_effective_date <= SYSDATE
  )
  -- find the most recent supervisor change (if any)
  AND (
    chg.nbrjobs_effective_date IS NULL 
    OR chg.nbrjobs_effective_date = (
    SELECT MAX(i.nbrjobs_effective_date)
    FROM POSNCTL.NBRJOBS i
    WHERE i.nbrjobs_pidm = job.nbrjobs_pidm
      AND i.nbrjobs_posn = job.nbrjobs_posn
      AND i.nbrjobs_suff = job.nbrjobs_suff
      AND i.nbrjobs_effective_date <= SYSDATE
    )
  )
;

describe posnctl.nbrjobs;
select * from dsd_degrees where fiscal_year >= 2015;

select * from saradap;

WITH 
  apps AS (
    -- builds a temporary table with student applications for level GF
    -- that have an accepted application decision. Grabs the most recent
    -- decision for each application.
    SELECT
      a.saradap_pidm            AS pidm,
      a.saradap_term_code_entry AS term_code
    FROM
      SATURN.SARADAP a
      INNER JOIN SATURN.SARAPPD b ON (
            b.sarappd_pidm = a.saradap_pidm
        AND b.sarappd_term_code_entry = a.saradap_term_code_entry
        AND b.sarappd_appl_no = a.saradap_appl_no
        AND b.sarappd_apdc_code IN ( 
          SELECT stvapdc_code
          FROM SATURN.STVAPDC
          WHERE stvapdc_inst_acc_ind = 'Y'
        )
        AND b.sarappd_seq_no = (
          SELECT MAX (b2.sarappd_seq_no)
          FROM SATURN.SARAPPD b2
          WHERE b2.sarappd_pidm = b.sarappd_pidm
            AND b2.sarappd_term_code_entry = b.sarappd_term_code_entry
            AND b2.sarappd_appl_no = b.sarappd_appl_no
        )
      )
    WHERE
      a.saradap_levl_code = 'GF'
  )
SELECT
  -- stu.spriden_pidm,
  gdeg.student_id                          AS "UA ID",
  bio.spbpers_pref_first_name              AS "Pref. First Name",
  stu.spriden_first_name                   AS "First Name",
  substr (
    stu.spriden_mi, 0, 1
  )                                        AS "Middle Initial",
  stu.spriden_last_name                    AS "Last Name",
  usr.gobtpac_external_user 
   || '@alaska.edu'                        AS "UA Email",
  LISTAGG( DISTINCT lpad(gdeg.degree,3,' ') || ' [' || gdeg.term_code_grad || ']', ' ' ) WITHIN GROUP (ORDER BY gdeg.term_code_grad, gdeg.degree)  AS "Grad Degrees Earned",
  min(apps.term_code) AS "Started Grad Program"
FROM
  --  start with the IR closing degree records
  DSDMGR.DSD_DEGREES gdeg 
  -- get basic student data
  INNER JOIN SATURN.SPRIDEN stu ON (
    stu.spriden_change_ind IS NULL
    AND stu.spriden_id = gdeg.student_id
  )
  -- get the demographic data
  INNER JOIN SATURN.SPBPERS bio ON (
        bio.spbpers_pidm = stu.spriden_pidm
    AND bio.spbpers_ssn != 'BAD'
  )
  -- get the UA username
  INNER JOIN GENERAL.GOBTPAC usr ON (
    usr.gobtpac_pidm = stu.spriden_pidm
  )
  -- get all the grad apps for each student
  LEFT JOIN apps ON (
    apps.pidm = stu.spriden_pidm
  )
WHERE
  gdeg.fiscal_year >= extract(year from SYSDATE) - 10
  AND gdeg.mau = 'UAF'
  AND gdeg.degree_level = 'GF'
GROUP BY
  stu.spriden_pidm,
  gdeg.student_id,
  bio.spbpers_pref_first_name,
  stu.spriden_first_name,
  substr (stu.spriden_mi, 0, 1),
  stu.spriden_last_name,
  usr.gobtpac_external_user || '@alaska.edu'
ORDER BY
  gdeg.student_id
;
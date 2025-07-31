
WITH 
  terms AS ( SELECT '202503' AS curr_term FROM dual 
--    SELECT
--      a.stvterm_code AS curr_term 
--    FROM
--      SATURN.STVTERM a
--    WHERE
--      SUBSTR(a.stvterm_code,6,1) IN ('1','2','3')
--      AND a.stvterm_start_date <= SYSDATE
--      AND a.stvterm_code = (
--        SELECT max(a2.stvterm_code)
--        FROM SATURN.STVTERM a2
--        WHERE SUBSTR(a2.stvterm_code,6,1) IN ('1','2','3')
--          AND a2.stvterm_start_date <= SYSDATE
--      )
  ),
  ra AS (
    SELECT 
      a.saradap_pidm            AS pidm,
      b.stvapst_desc            AS status,
      a.saradap_term_code_entry AS last_term,
      a.saradap_apst_code
        || ' - ' 
        || a.saradap_apst_date  AS proc_date
    FROM
      SATURN.SARADAP a
      INNER JOIN SATURN.STVAPST b ON (
        b.stvapst_code = a.saradap_apst_code
      )
    WHERE
      a.saradap_levl_code like '%F'
      AND a.saradap_appl_no = (
        SELECT max(a2.saradap_appl_no)
        FROM SATURN.SARADAP a2
        WHERE a2.saradap_pidm = a.saradap_pidm
          AND a2.saradap_levl_code = a.saradap_levl_code
      )
  ),
  reg AS (
    SELECT
      a.sfrstca_pidm           AS pidm,
      a.sfrstca_term_code      AS term_code,
      sum(a.sfrstca_credit_hr) AS sch
    FROM
      SATURN.SFRSTCA a
      INNER JOIN SATURN.STVRSTS b ON (
        b.stvrsts_code = a.sfrstca_rsts_code
        AND b.stvrsts_incl_sect_enrl = 'Y'
        AND b.stvrsts_withdraw_ind = 'N'
      )
    WHERE
      a.sfrstca_term_code = (
        SELECT curr_term
        FROM terms
      )
      AND a.sfrstca_seq_number = (
        SELECT max(a2.sfrstca_seq_number)
        FROM SATURN.SFRSTCA a2
        WHERE a2.sfrstca_term_code = a.sfrstca_term_code
          AND a2.sfrstca_pidm = a.sfrstca_pidm
          AND a2.sfrstca_crn = a.sfrstca_crn
      )
    GROUP BY
      a.sfrstca_pidm,
      a.sfrstca_term_code
  )
SELECT DISTINCT
  stu.spriden_id              AS student_id, cohort.sgrsatt_pidm, 
  reg.term_code               AS "TERM",
  (
    SELECT stvterm_start_date
    FROM SATURN.STVTERM
    WHERE stvterm_code = reg.term_code
  )                           AS term_start_date,
  reg.sch                     AS enrolled_units,
  CASE
    -- WHEN enroll.sfbetrm_term_code != ( SELECT curr_term FROM terms ) THEN NULL
    WHEN enroll.sfbetrm_ests_code = 'WT' THEN 'Total Withdraw'
    WHEN enroll.sfbetrm_ests_code = 'EL' THEN 'Registered'
    ELSE enroll.sfbetrm_ests_code
  END                         AS enrollment_status,
  (
    SELECT stvmajr_desc  
    FROM SATURN.STVMAJR
    WHERE stvmajr_code = record.sgbstdn_majr_code_1
  )                           AS program_of_study,
  (
    SELECT stvmajr_cipc_code
    FROM SATURN.STVMAJR
    WHERE stvmajr_code = record.sgbstdn_majr_code_1
  )                           AS cip_code,
  gpa.shrlgpa_hours_attempted AS credits_attempted,
  gpa.shrlgpa_hours_earned    AS credits_earned,
  round (
    gpa.shrlgpa_gpa, 2 
  )                           AS gpa,
  (
    SELECT max(sfrstca_term_code) 
    FROM SATURN.SFRSTCA
      INNER JOIN STVRSTS ON stvrsts_code = sfrstca_rsts_code
    WHERE sfrstca_pidm = cohort.sgrsatt_pidm
      AND stvrsts_incl_sect_enrl = 'Y'
  )                           AS last_attendance,
  ra.proc_date                AS ra_processed_date,
  ra.proc_date                AS ra_received_date,
  ra.status                   AS ra_status
FROM
  SATURN.SGRSATT cohort
  -- get the ID information for these students
  INNER JOIN SATURN.SPRIDEN stu ON (
    stu.spriden_change_ind IS NULL
    AND stu.spriden_pidm = cohort.sgrsatt_pidm
  )
  -- get the most recent student record
  INNER JOIN SATURN.SGBSTDN record ON (
    record.sgbstdn_pidm = cohort.sgrsatt_pidm
      -- limit to just UAF undergraduate students
    AND record.sgbstdn_levl_code IN ('OF', 'UF')
  )
  -- grab any GPA records
  LEFT JOIN SATURN.SHRLGPA gpa ON (
    gpa.shrlgpa_gpa_type_ind = 'I'
    AND gpa.shrlgpa_levl_code = record.sgbstdn_levl_code
    AND gpa.shrlgpa_pidm = cohort.sgrsatt_pidm
  )
  --  Is the student enrolled for this term?
  LEFT JOIN SATURN.SFBETRM enroll ON (
    enroll.sfbetrm_pidm = cohort.sgrsatt_pidm
  )
  -- grab the most recent admission decision
  LEFT JOIN ra ON (
    ra.pidm = cohort.sgrsatt_pidm
  )
  -- get any prior registrations
  LEFT JOIN reg ON (
    reg.pidm = cohort.sgrsatt_pidm
  )
  WHERE  
    -- temp filter to get aspecific students
    stu.spriden_id IN ('30042295', '30078375', '30093904', '30134305', '30110341', '30114858')
--    -- only students in the ReUp cohort
--    cohort.sgrsatt_atts_code = 'FRUP'
    -- only the current student record
    AND (
      record.sgbstdn_term_code_eff = (
        SELECT MAX(i.sgbstdn_term_code_eff)
        FROM SATURN.SGBSTDN i
          JOIN terms ON i.sgbstdn_term_code_eff <= terms.curr_term
        WHERE i.sgbstdn_pidm = record.sgbstdn_pidm
          AND i.sgbstdn_levl_code IN ('OF', 'UF')
      )
    )
    -- get the current enrollment record
    AND (
      enroll.sfbetrm_term_code IS NULL
      OR enroll.sfbetrm_term_code = (
        SELECT max(e2.sfbetrm_term_code)
        FROM SATURN.SFBETRM e2
        WHERE e2.sfbetrm_pidm = enroll.sfbetrm_pidm
      )
    )
  ORDER BY 
    stu.spriden_id
;
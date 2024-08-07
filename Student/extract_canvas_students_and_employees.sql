-- =============================================================================================================================
--   Combined Canvas Query
-- =============================================================================================================================
WITH 
  terms AS (  -- get the current regular spring/summer/fall term code
    SELECT 
    max(a.stvterm_code) AS curr_term
    FROM SATURN.STVTERM a
    WHERE substr(a.stvterm_code,6,1) IN ('1','2','3') 
      AND a.stvterm_start_date <= SYSDATE
  ),
  sch AS (  -- this gets the total credits earned thru the current term
    SELECT DISTINCT
      a.shrtgpa_pidm AS pidm,
      sum(a.shrtgpa_hours_earned) AS hrs
    FROM 
      SATURN.SHRTGPA a
      INNER JOIN terms ON 
        a.shrtgpa_term_code <= terms.curr_term
    WHERE
      a.shrtgpa_levl_code = 'UF'
      AND a.shrtgpa_gpa_type_ind = 'I'
    GROUP BY
      a.shrtgpa_pidm
  ),
  race AS ( -- returns the total number of race codes per student 
    SELECT
      a.gorprac_pidm AS pidm,
      count(a.gorprac_race_cde) as count
    FROM 
      GENERAL.GORPRAC a
    GROUP BY
      a.gorprac_pidm
  ),
  empl AS ( -- returns a list of pidms that are current employees
            -- used to filter them out of the student list
    SELECT
      a.pebempl_pidm AS pidm
    FROM
      PAYROLL.PEBEMPL a
      INNER JOIN POSNCTL.NBRBJOB b ON (
            a.pebempl_pidm = b.nbrbjob_pidm 
        AND b.nbrbjob_begin_date <= CURRENT_DATE
        AND (
          b.nbrbjob_end_date >= CURRENT_DATE 
          OR b.nbrbjob_end_date IS NULL
        )
      )
    WHERE
          a.pebempl_empl_status <> 'T'
      AND b.nbrbjob_contract_type = 'P'
  )
SELECT DISTINCT
  reg.sfrstcr_term_code                     AS "Current Term",
  reg.sfrstcr_pidm                          AS "UA PIDM",
  person.spriden_id                         AS "UA ID",
  usr.gobtpac_external_user                 AS "UA Username",
  'Student'                                 AS "Person Type",
  nvl( -- get the preferred name if it is set
    bio.spbpers_pref_first_name,
    person.spriden_first_name
  )                                         AS "First Name",
  person.spriden_last_name                  AS "Last Name",
  NVL2( -- only show the formatting if there is a number 
    cell.sprtele_pidm,
    '(' || cell.sprtele_phone_area || ') '
      || substr(cell.sprtele_phone_number,1,3)
      || '-'
      || substr(cell.sprtele_phone_number,4),
    ' '
  )                                         AS "Mobile Number",
  student.sgbstdn_majr_code_1               AS "Major",
  sch.hrs                                   AS "Credit Hours",
  bio.spbpers_ethn_code                     AS "Ethnicity",
  CASE
    WHEN student.sgbstdn_resd_code = 'I' THEN 'Y'
    ELSE 'N'
  END                                       AS "International Status",
  DECODE ( -- if grad student, show grad GPA
           -- if it exists, else undergrad 
           -- or null
    student.sgbstdn_levl_code,
    'UF', ROUND(ugpa.shrlgpa_gpa,1),
    'GF', NVL2(
            ggpa.shrlgpa_pidm,
            ROUND(ggpa.shrlgpa_gpa,1),
            ROUND(ugpa.shrlgpa_gpa,1)
          ),
    null
  )                                         AS "GPA",
  nvl( -- if there is a Gender code, use that.  else sbppers_sex
    bio.spbpers_gndr_code,
    bio.spbpers_sex
  )                                         AS "Gender",
  student.sgbstdn_resd_code                 AS "Residency",
  nvl2( -- if there is a birth date calc the age, else null
    bio.spbpers_birth_date, 
    trunc((SYSDATE - bio.spbpers_birth_date)/365.25),
    null
  )                                         AS "Age",
  CASE
    WHEN race.count < 1 OR race.count IS NULL THEN 'UN'
    WHEN race.count = 1 THEN ( -- if this person has one race code listed
                               -- then look up that specific code
                               SELECT gorprac_race_cde 
                               FROM GENERAL.GORPRAC 
                               WHERE gorprac_pidm = reg.sfrstcr_pidm
                             )
    ELSE '>1'
  END                                       AS "Race",
  CASE 
    WHEN student.sgbstdn_admt_code LIKE 'T%' THEN 'Y'
    ELSE 'N'
  END                                       AS "Transfer Student", -- Y/N
  nvl2(ath.sgrsprt_actc_code,'Y','N')       AS "Athlete", -- Y/N
  student.sgbstdn_camp_code                 AS "Main Campus", 
  nvl2(vet.sgrsatt_pidm, 'Y','N')           AS "Veteran Status",
  nvl2(fgs.sgrsatt_pidm, 'Y','N')           AS "First Generation Status"
FROM
  -- start from the current registration table
  SATURN.SFRSTCR reg    
  INNER JOIN terms ON terms.curr_term = reg.sfrstcr_term_code
  -- only enrolled students
  INNER JOIN SATURN.STVRSTS enr ON (
        reg.sfrstcr_rsts_code = enr.stvrsts_code
    --  limit to just enrolled
    AND enr.stvrsts_incl_sect_enrl = 'Y'
    AND enr.stvrsts_withdraw_ind = 'N'
    AND enr.stvrsts_code NOT IN ('AU')
  ) 
  INNER JOIN SATURN.SPRIDEN person ON (
        person.spriden_pidm = reg.sfrstcr_pidm
    AND person.spriden_change_ind IS NULL
  )
  INNER JOIN SATURN.SPBPERS bio ON (
        bio.spbpers_pidm = reg.sfrstcr_pidm
    AND bio.spbpers_ssn != 'BAD'    
  )
  -- grab other student information
  INNER JOIN SATURN.SGBSTDN student ON (
        student.sgbstdn_pidm = reg.sfrstcr_pidm
    AND student.sgbstdn_stst_code = 'AS'
    AND student.sgbstdn_levl_code in ('GF', 'UF')
  )
  INNER JOIN GENERAL.GOBTPAC usr ON usr.gobtpac_pidm = reg.sfrstcr_pidm
  LEFT JOIN SATURN.SPRTELE cell ON (
        cell.sprtele_pidm = reg.sfrstcr_pidm
    AND cell.sprtele_tele_code = 'CELL'
  )
  -- get the cumulative GPA for Undergrad
  LEFT JOIN SATURN.SHRLGPA ugpa ON (
    ugpa.shrlgpa_pidm = student.sgbstdn_pidm
    AND ugpa.shrlgpa_levl_code = 'UF'
    AND ugpa.shrlgpa_gpa_type_ind = 'I'
  )
  -- get the cumulative GPA for Graduate
  LEFT JOIN SATURN.SHRLGPA ggpa ON (
    ggpa.shrlgpa_pidm = student.sgbstdn_pidm
    AND ggpa.shrlgpa_levl_code = 'GF'
    AND ggpa.shrlgpa_gpa_type_ind = 'I'
  )
  LEFT JOIN SATURN.SGRSPRT ath ON (
        ath.sgrsprt_pidm = student.sgbstdn_pidm
    AND ath.sgrsprt_term_code = terms.curr_term
    AND ath.sgrsprt_spst_code = 'A'
  )
  LEFT JOIN SATURN.SGRSATT vet ON (
        vet.sgrsatt_pidm = student.sgbstdn_pidm
    AND vet.sgrsatt_atts_code = 'FVET'
  )
  LEFT JOIN SATURN.SGRSATT fgs ON (
        fgs.sgrsatt_pidm = student.sgbstdn_pidm
    AND fgs.sgrsatt_atts_code = 'FFGN'
  )
  LEFT JOIN sch ON 
    sch.pidm = student.sgbstdn_pidm
  LEFT JOIN race ON 
    race.pidm = student.sgbstdn_pidm
WHERE
  -- only undergrad UAF students
  reg.sfrstcr_levl_code IN ('UF', 'GF')
  AND ( -- get the most recent Cell record (if it exists)
    cell.sprtele_seqno IS NULL
    OR cell.sprtele_seqno = (
        SELECT max(i.sprtele_seqno)
        FROM saturn.sprtele i
        WHERE i.sprtele_pidm = cell.sprtele_pidm
          AND i.sprtele_tele_code = 'CELL'
      )
  )
  AND -- get the most recent student record
      -- not checking for null here, since all students have at least 1 record
    student.sgbstdn_term_code_eff = (
      SELECT MAX(s1.sgbstdn_term_code_eff) 
      FROM SATURN.SGBSTDN s1
      INNER JOIN SATURN.STVTERM s2 ON s2.stvterm_code = s1.sgbstdn_term_code_eff
      WHERE s1.sgbstdn_pidm = student.sgbstdn_pidm AND s2.stvterm_start_date <= SYSDATE
    )
    
ORDER BY
  person.spriden_id
;

-- =============================================================================
--  Snippet Library:  Temporary tables for WITH stanzas
--
--  This file contains severl SELECT statements tht are intenced to go into WITH
-- stanzas in queries.  They can also be pulled out to run stand alone for 
-- testing. Note that some of these temp tables require a variable to be set.
-- =============================================================================

-- Create a temp table with the current term code
--  - only includes terms ....01, ....02 and ....03
terms AS ( 
  SELECT 
    max(a.stvterm_code) AS curr_term
  FROM 
    SATURN.STVTERM a
  WHERE 
        substr(a.stvterm_code,6,1) IN ('1','2','3') 
    AND a.stvterm_start_date <= SYSDATE
)

-- Create a temporary table  of students that are 
-- registered for the term selected.
--  - only includes UAF students
--  - only includes undergrads
--  - also includes the STVCAMP campus code
--  - also includes a sum of the enrolled credit hours
students AS (  
  SELECT 
    reg.sfrstcr_pidm    AS pidm,
    a.ssbsect_camp_code AS campus,
    sum(reg.sfrstcr_credit_hr) AS sch
  FROM
    SATURN.SFRSTCR reg
    INNER JOIN SATURN.STVRSTS enr ON (
          reg.sfrstcr_rsts_code = enr.stvrsts_code
      --  limit to just enrolled
      AND enr.stvrsts_incl_sect_enrl = 'Y'
      AND enr.stvrsts_withdraw_ind = 'N'
      AND enr.stvrsts_code NOT IN ('AU')
    ) 
    LEFT JOIN SATURN.SSBSECT a ON (
          a.ssbsect_term_code = reg.sfrstcr_term_code
      AND a.ssbsect_crn = reg.sfrstcr_crn
    )
  WHERE
        reg.sfrstcr_term_code = :the_term
    -- to get all enrolled UAF students, change to '%F'
    AND reg.sfrstcr_levl_code LIKE 'UF'
  GROUP BY
    reg.sfrstcr_pidm, 
    a.ssbsect_camp_code
)

-- Create a temporary table of student records that is just
-- the most current one for each student.
--  - Includes the primary majo and college
--  - only includes UAF students
--  - only includes undergrads
--  - only includes records with an effectie term < selected term
records AS ( 
  SELECT 
    a.sgbstdn_term_code_eff AS term_eff,
    a.sgbstdn_camp_code     AS campus,
    a.sgbstdn_pidm          AS pidm,
    a.sgbstdn_degc_code_1   AS degree_code,
    b.stvdegc_desc          AS degree_desc,
    a.sgbstdn_majr_code_1   AS major_code,
    c.stvmajr_desc          AS major_desc,
    a.sgbstdn_coll_code_1   AS college_code,
    d.stvcoll_desc          AS college_desc
  FROM 
    SATURN.SGBSTDN a
    INNER JOIN SATURN.STVDEGC b ON (
      b.stvdegc_code = a.sgbstdn_degc_code_1
    )
    INNER JOIN SATURN.STVMAJR c ON (
      c.stvmajr_code = a.sgbstdn_majr_code_1
    )
    INNER JOIN SATURN.STVCOLL d ON (
      d.stvcoll_code = a.sgbstdn_coll_code_1
    )
  WHERE
    -- to get all UAF students, change to LIKE '%F'
        a.sgbstdn_levl_code LIKE 'UF'
    -- comment out to include exchange students
    AND a.sgbstdn_majr_code_1 <> 'EXCH'
    -- uncomment to limit to just specific home campuses
    -- AND a.sgbstdn_camp_code IN ('X', 'F')
    AND (
      a.sgbstdn_term_code_eff = (
        SELECT MAX(i.sgbstdn_term_code_eff)
        FROM SATURN.SGBSTDN i
        WHERE i.sgbstdn_pidm = a.sgbstdn_pidm
        AND i.sgbstdn_term_code_eff <= :the_term
      )
    )
)

-- Create a temporary table of students who show as enrolled based on the SFBETRM table.
--  - Only includes recored with status (ESTS) codes:
--      EL ( Eligible for Registration)
--      SR ( Stop Registration)
--  - Only includes records with the AR indicator flag set to 'Y'
-- Only includes students enrolled in the term selected
enrolled AS (
  SELECT
    a.sfbetrm_pidm            AS pidm,
    a.sfbetrm_term_code       AS term_code
  FROM
    SATURN.SFBETRM a
  WHERE
    -- limit to valid ests codes for 'enrolled' status
        a.sfbetrm_ests_code IN ('EL', 'SR')
    AND a.sfbetrm_ar_ind = 'Y'
    AND a.sfbetrm_term_code = :the_term
)
  
-- Create a temp table of the most current email addresses for each person
--  - only includes 'Active' addresses
--  - includes the type of email address (from GTVEMAL)
--  - includes Preferred flag (uncomment filter for preferred if you just want those)
emails AS (
  SELECT 
    a.goremal_pidm          AS pidm,
    a.goremal_email_address AS email_address,
    a.goremal_emal_code     AS address_type,
    a.goremal_preferred_ind AS is_preferred
  FROM
    GENERAL.GOREMAL a
  WHERE
        a.goremal_status_ind = 'A'
 -- AND a.goremal_preferred_ind = 'Y' -- uncomment for preferred email 
    AND a.goremal_activity_date = (
      SELECT MAX (b.goremal_activity_date)
      FROM GENERAL.GOREMAL b
      WHERE (
            b.goremal_pidm = a.goremal_pidm
        AND b.goremal_status_ind = 'A'
     -- AND a.goremal_preferred_ind = 'Y' -- uncomment for preferred email 
        AND b.goremal_emal_code = a.goremal_emal_code
      )
    )
)

-- Create a temp table of all current student holds
--  - includes a list of all holds found (for further filtering)
holds AS ( 
  SELECT
    a.sprhold_pidm             AS pidm,
    count(a.sprhold_hldd_code) AS total,
    listagg ( 
      '[' || a.sprhold_hldd_code || '] "' 
      || a.sprhold_reason || '" - ' 
      || b.stvhldd_desc || ' ', ','
    ) WITHIN GROUP (
      ORDER BY a.sprhold_hldd_code
    )                          AS codes
  FROM
    SATURN.SPRHOLD a
    INNER JOIN SATURN.STVHLDD b ON 
      a.sprhold_hldd_code = b.stvhldd_code
  WHERE
        a.sprhold_to_date >= SYSDATE
    AND a.sprhold_hldd_code NOT IN ('AT', 'IX', 'AA')
    AND b.stvhldd_reg_hold_ind = 'Y'
  GROUP BY
    a.sprhold_pidm
)

-- Creates a temp table of all of the current student advisors
--  - only includes the primary advisor for each student
advisors AS ( 
  SELECT
    sgradvr_pidm                  AS pidm,
    b.spriden_last_name  
     || ', ' 
     || b.spriden_first_name 
     || ' ' 
     || substr(b.spriden_mi,0,1)  AS advisor
  FROM 
    SATURN.SGRADVR a
    INNER JOIN SATURN.SPRIDEN b ON (
          b.spriden_pidm = a.sgradvr_advr_pidm
      AND b.spriden_change_ind IS NULL
    )
  WHERE
    a.sgradvr_prim_ind = 'Y'
    AND a.sgradvr_term_code_eff = (
      SELECT max( i.sgradvr_term_code_eff )
      FROM saturn.sgradvr i
      WHERE i.sgradvr_pidm = a.sgradvr_pidm
        AND i.sgradvr_prim_ind = 'Y'
   )
)

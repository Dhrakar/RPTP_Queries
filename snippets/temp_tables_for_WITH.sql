-- =============================================================================
--  Snippet Library:  Temporary tables for WITH stanzas
--
--  This file contains severl SELECT statements tht are intenced to go into WITH
-- stanzas in queries.  They can also be pulled out to run stand alone for 
-- testing. Note that some of these temp tables require a variable to be set.
-- =============================================================================

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

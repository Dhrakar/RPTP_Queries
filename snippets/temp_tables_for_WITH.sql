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

-- Create a temp table with terms based on the current aidyear
terms AS (
    -- this snippet grabs the next aidyr from stvterm as well as the
    -- corresponding terms for the current aidyr
    SELECT  
       
      101 + b.stvterm_fa_proc_yr                       AS aidyr, -- 'future' aidyear for checking FAFSA info
      '20' || substr(b.stvterm_fa_proc_yr,1,2) || '03' AS fall_term,
      '20' || substr(b.stvterm_fa_proc_yr,3,2) || '01' AS spring_term,
      '20' || substr(b.stvterm_fa_proc_yr,3,2) || '02' AS summer_term
    FROM
        SATURN.SOBPTRM a
        INNER JOIN SATURN.STVTERM b ON (
            b.stvterm_code = a.sobptrm_term_code
        )
    WHERE
            a.sobptrm_ptrm_code = 'F'
        AND SYSDATE >= a.sobptrm_start_date
        AND SYSDATE <= a.sobptrm_end_date
  )

-- create a temp table for terms using specific start/end dates
terms AS (
  SELECT -- this picks the current term base on (roughly) registration dates
         -- the conversion to YYYYMMDD in the compariosn is because the 'time'
         -- in SYSTDATE throws off the calc for the endpoints
    CASE
      WHEN 
        -- For Jan 1 -> Jan 31 return Spring for current year
        to_char( SYSDATE, 'YYYYMMDD') 
          BETWEEN 
            to_char( to_date('01/01/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD')
          AND 
            to_char( to_date('01/31/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD') 
        THEN extract(year from SYSDATE) || '01'
      WHEN  
        -- For Feb 1 -> Apr 15 return Summer for current year
        to_char( SYSDATE, 'YYYYMMDD') 
          BETWEEN 
            to_char( to_date('02/01/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD')
          AND 
            to_char( to_date('04/15/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD') 
        THEN extract(year from SYSDATE) || '02'
      WHEN  
        -- For Apr 16 -> Oct 31 return Fall for current year
        to_char( SYSDATE, 'YYYYMMDD') 
          BETWEEN 
            to_char( to_date('04/16/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD')
          AND 
            to_char( to_date('11/01/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD')
        THEN extract(year from SYSDATE) || '03'
      WHEN  
        -- For Nov 1 -> Dec 31 return Spring for next year
        to_char( SYSDATE, 'YYYYMMDD') 
          BETWEEN 
            to_char( to_date('11/01/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD')
          AND 
            to_char( to_date('12/31/' || extract(year from SYSDATE), 'mm/dd/yyyy') , 'YYYYMMDD') 
        THEN (1 + extract(year from SYSDATE)) || '01'
    END                        AS curr_term
  FROM 
    DUAL
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
--  - Includes the primary major and college
--  - only includes UAF students
--  - only includes undergrads
--  - only includes records with an effective term < selected term
records AS ( 
  SELECT 
    a.sgbstdn_term_code_eff AS term_eff,
    a.sgbstdn_camp_code     AS campus,
    a.sgbstdn_pidm          AS pidm,
    a.sgbstdn_levl_code     AS student_levl_code,
    h.stvlevl_desc          AS student_levl_desc,
    a.sgbstdn_degc_code_1   AS prim_degree_code,
    b.stvdegc_desc          AS prim_degree_desc,
    a.sgbstdn_majr_code_1   AS prim_major_code,
    c.stvmajr_desc          AS prim_major_desc,
    a.sgbstdn_degc_code_2   AS sec_degree_code,
    d.stvdegc_desc          AS sec_degree_desc,
    a.sgbstdn_majr_code_2   AS sec_major_code,
    e.stvmajr_desc          AS sec_major_desc,
    a.sgbstdn_coll_code_1   AS prim_college_code,
    f.stvcoll_desc          AS prim_college_desc,
    a.sgbstdn_coll_code_2   AS sec_college_code,
    g.stvcoll_desc          AS sec_college_desc
  FROM 
    SATURN.SGBSTDN a
    LEFT JOIN SATURN.STVDEGC b ON (
      b.stvdegc_code = a.sgbstdn_degc_code_1
    )
    LEFT JOIN SATURN.STVMAJR c ON (
      c.stvmajr_code = a.sgbstdn_majr_code_1
    )
    LEFT JOIN SATURN.STVDEGC d ON (
      d.stvdegc_code = a.sgbstdn_degc_code_2
    )
    LEFT JOIN SATURN.STVMAJR e ON (
      e.stvmajr_code = a.sgbstdn_majr_code_2
    )
    LEFT JOIN SATURN.STVCOLL f ON (
      f.stvcoll_code = a.sgbstdn_coll_code_1
    )
    LEFT JOIN SATURN.STVCOLL g ON (
      g.stvcoll_code = a.sgbstdn_coll_code_2
    )
    LEFT JOIN SATURN.STVLEVL h ON (
      h.stvlevl_code = a.sgbstdn_levl_code
    )
  WHERE
    -- to get all UAF students, change to LIKE '%F'
        a.sgbstdn_levl_code LIKE '%F'
    -- uncomment to exclude exchange students
    -- AND a.sgbstdn_majr_code_1 <> 'EXCH'
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

-- Create a temporary table of the Applications and applicataion decisions for a term
-- - Only includes records with the following
--    Undergraduate UAF
--    Bachelor level degree apps
--    Only the term selected
--  does include all of the descision codes ( STVAPDC )
apps AS (
  SELECT
    a.saradap_pidm            AS pidm,
    a.saradap_term_code_entry AS term_code,
    a.saradap_styp_code       AS styp_code,
    a.saradap_appl_date       AS app_date,
    a.saradap_appl_no         AS app_no,
    a.saradap_majr_code_1     AS major_code,
    a.saradap_coll_code_1     AS coll_code,
    b.sarappd_seq_no          AS seq_no,
    b.sarappd_apdc_code       AS apdc_code
  FROM
    SATURN.SARADAP a
    JOIN SATURN.SARAPPD b ON (
          b.sarappd_pidm = a.saradap_pidm
      AND b.sarappd_term_code_entry = a.saradap_term_code_entry
      AND b.sarappd_appl_no = a.saradap_appl_no
      AND b.sarappd_seq_no = (
        SELECT MAX (b2.sarappd_seq_no)
        FROM SATURN.SARAPPD b2
        WHERE b2.sarappd_pidm = b.sarappd_pidm
          AND b2.sarappd_term_code_entry = b.sarappd_term_code_entry
          AND b2.sarappd_appl_no = b.sarappd_appl_no
          AND b2.sarappd_appl_no = (
           SELECT MAX(b3.sarappd_appl_no)
           FROM SATURN.SARAPPD b3
           WHERE b3.sarappd_pidm = b2.sarappd_pidm
             AND b3.sarappd_term_code_entry = b2.sarappd_term_code_entry
          )
      )
    )
  WHERE
    a.saradap_term_code_entry = :the_term
    -- only include undergrad UAF
    AND a.saradap_levl_code = 'UF'
    -- only first time or transfer
    AND a.saradap_styp_code in ('F', 'T')
    -- only bachelor-type degrees
    AND a.saradap_degc_code_1 in ( 
      SELECT a1.stvdegc_code
      FROM SATURN.STVDEGC a1
        JOIN SATURN.STVDLEV a2 ON (
          a2.stvdlev_code = a1.stvdegc_dlev_code
      AND a2.stvdlev_code in ('02', 'B')
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

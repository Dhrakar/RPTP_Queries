-- ==================================================================
--              URSA Extract for National Clearinghouse Query
--
--   This pulls out all of the URSA cohorted students and sets the 
-- format as needed by NSCH.  The Search Date for the extract is set
-- to the year this record was cohorted + July 31.
--   Be sure to save the file as a tab-delim text file with CR/LF for
-- the line endings.  Note that the header and the footer lines will 
-- both wind up sorted to the end of the file.
-- ==================================================================

-- wrapper to sort the header properly
SELECT 
 type_ind,
 ssn_col,
 fname,
 mi,
 lname,
 suffix,
 bday2,
 searchdate,
 blank_col,
 school_code,
 branch_code,
 pidm
FROM (
  -- start of inner query 
  
  -- Header
  SELECT
    'H1'                               AS type_ind,
    '001063'                           AS ssn_col,
    '00'                               AS fname,
    'University of Alaska Fairbanks'   AS mi,
    to_char(SYSDATE, 'YYYYMMDD')       AS lname,
    'SE'                               AS suffix,
    'I'                                AS bday2,
    ''                                 AS searchdate,
    ''                                 AS blank_col,
    ''                                 AS school_code,
    ''                                 AS branch_code,
    ''                                 AS pidm
  FROM
    DUAL
  
  UNION

  -- Body
  SELECT DISTINCT
    'D1'                               AS type_ind,
    ''                                 AS ssn_col,
    stu.spriden_first_name             AS fname,
    SUBSTR(stu.spriden_mi,1,1)         AS mi,
    substr(stu.spriden_last_name,1,20) AS lname,
    bio.spbpers_name_suffix            AS suffix,
    EXTRACT(
        YEAR FROM bio.spbpers_birth_date
      ) || LPAD ( 
        EXTRACT(
          MONTH FROM bio.spbpers_birth_date
        ), 2, '0'
      ) || LPAD(
        EXTRACT(
          DAY FROM bio.spbpers_birth_date
        ),2 , '0'
      )                                AS bday2, 
    CASE
      WHEN 
        substr(
          cohort.sgrchrt_chrt_code,6,2
        ) < 50 
      THEN 
        '20' || substr(cohort.sgrchrt_chrt_code,6,2)
      ELSE 
        '19' || substr(cohort.sgrchrt_chrt_code,6,2)
    END || '0731'                    AS searchdate,
    ''                               AS blank_col,
    '001063'                         AS school_code,
    '00'                             AS branch_code,
    to_char(
      cohort.sgrchrt_pidm,
      '99999999'
    )                                AS pidm
  FROM
    SATURN.SGRCHRT cohort
    JOIN SATURN.SPRIDEN stu ON (
      stu.spriden_change_ind IS NULL
      AND cohort.sgrchrt_pidm = stu.spriden_pidm
    )
    JOIN SATURN.SPBPERS bio ON cohort.sgrchrt_pidm = bio.spbpers_pidm
  WHERE
    cohort.sgrchrt_chrt_code LIKE 'FURSA%' 
    AND ( -- ensure that the search data is not in the future
      CASE
        WHEN 
          substr(
            cohort.sgrchrt_chrt_code,6,2
          ) < 50 
        THEN 
          '20' || substr(cohort.sgrchrt_chrt_code,6,2)
        ELSE 
          '19' || substr(cohort.sgrchrt_chrt_code,6,2)
      END || '0731'
    ) < ( 
      EXTRACT ( YEAR FROM SYSDATE ) || '0731'
    )
-- end of inner query
)
ORDER BY
  type_ind DESC,
  searchdate ASC
;

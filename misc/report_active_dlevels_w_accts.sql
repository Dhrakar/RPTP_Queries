SELECT DISTINCT
  title2 AS "Cabinet",
  title3 AS "Unit",
  title4 AS "Division",
  level6 AS "dLevel",
  title6 AS "Department"
FROM
  REPORTS.FTVORGN_LEVELS org
WHERE
  org.level1 = 'UAFTOT'
  AND level2 != '3CENTL'
  AND level6 LIKE 'D%'
  AND level8 IS NOT NULL
ORDER BY
  title2, title3, title4, level6
;

SELECT spriden_id,
       spriden_last_name,
       spriden_first_name,
       spriden_mi,
       old_names.last_name_alt1,
       old_names.first_name_alt1,
       old_names.mi_alt1,
       old_names.last_name_alt2,
       old_names.first_name_alt2,
       old_names.mi_alt2,
       to_char(spbpers_birth_date, 'mm/dd/yyyy'),
       to_char(pebempl_i9_date, 'mm/dd/yyyy')
  FROM -- Each record of old_names contains a pidm and the 2nd and 3rd most recent names.
       -- inner query  (step 1): Select distinct names for each pidm from spriden,
       --                        along with the information we need to sort them.
       -- middle query (step 2): Rank the records for each pidm by how recent the name is.
       --                        Order by null change ind first, then by most recent
       --                        activity date, then alphabetically.
       -- outer query  (step 3): Restrict consideration to records with rank 2 or 3.
       --                        Group these into one record per pidm and pivot the names into columns.
         -- outer query
         (SELECT spriden_pidm pidm,
                 MAX(CASE WHEN rank = 2 THEN spriden_last_name ELSE NULL END)  last_name_alt1,
                 MAX(CASE WHEN rank = 2 THEN spriden_first_name ELSE NULL END) first_name_alt1,
                 MAX(CASE WHEN rank = 2 THEN spriden_mi ELSE NULL END)         mi_alt1,
                 MAX(CASE WHEN rank = 3 THEN spriden_last_name ELSE NULL END)  last_name_alt2,
                 MAX(CASE WHEN rank = 3 THEN spriden_first_name ELSE NULL END) first_name_alt2,
                 MAX(CASE WHEN rank = 3 THEN spriden_mi ELSE NULL END)         mi_alt2
            FROM -- middle query
                 (SELECT spriden_pidm,
                         spriden_last_name,
                         spriden_first_name,
                         spriden_mi,
                         ROW_NUMBER() OVER (PARTITION BY spriden_pidm
                                                ORDER BY change_ind,
                                                         activity_date DESC,
                                                         spriden_last_name,
                                                         spriden_first_name,
                                                         spriden_mi) rank
                    FROM -- inner query
                         (SELECT spriden_pidm,
                                 spriden_last_name,
                                 spriden_first_name,
                                 spriden_mi,
                                 -- if the null change_ind record has this name then change_ind = 0
                                 -- otherwise change_ind = 1
                                 MIN(nvl2(spriden_change_ind,1,0)) change_ind,
                                 -- activity_date is the most recent activity date associated with this name
                                 MAX(spriden_activity_date) activity_date
                            FROM spriden
                        GROUP BY spriden_pidm, spriden_last_name, spriden_first_name, spriden_mi))
           WHERE rank IN (2,3)
        GROUP BY spriden_pidm) old_names,
       -- other source tables
       spriden, spbpers, pebempl
 WHERE spriden_pidm = pebempl_pidm
   AND spriden_change_ind IS NULL
   AND spbpers_pidm = pebempl_pidm
   -- outer join since employee may not have old names
   AND old_names.pidm (+) = pebempl_pidm

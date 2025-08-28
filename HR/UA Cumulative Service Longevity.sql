-- Cumulative Years of Service --

-- Currently does not take LWOP or Off Contract into consideration --

-- Takes YYYY and calculates all service through the end of that calendar year.
-- Active eligible staff as of the day the query is run

with assignments as (
    select nbrbjob_pidm pidm,
           nbrbjob_posn posn,
           nbrbjob_suff suff,
           nbrbjob_contract_type contract_type,
           nbrbjob_begin_date begin_date,
           nbrbjob_end_date end_date,
           lag(nbrbjob_begin_date) over (partition by nbrbjob_pidm -- Try moving these to a new CTE to improve performance.
                                             order by nbrbjob_pidm,
                                                      nbrbjob_begin_date,
                                                      nbrbjob_end_date) lag_begin_date,
           lag(nbrbjob_end_date) over (partition by nbrbjob_pidm
                                           order by nbrbjob_pidm,
                                                    nbrbjob_begin_date,
                                                    nbrbjob_end_date) lag_end_date

      from nbrbjob job
      join nbrjobs pos on job.nbrbjob_pidm = pos.nbrjobs_pidm
                      and job.nbrbjob_posn = pos.nbrjobs_posn
                      and job.nbrbjob_suff = pos.nbrjobs_suff
                      and pos.nbrjobs_effective_date = (select max(pos2.nbrjobs_effective_date)
                                                          from nbrjobs pos2
                                                         where job.nbrbjob_pidm = pos2.nbrjobs_pidm
                                                           and job.nbrbjob_posn = pos2.nbrjobs_posn
                                                           and job.nbrbjob_suff = pos2.nbrjobs_suff
                                                           and pos2.nbrjobs_effective_date <= to_date('31-DEC-' || :Calendar_Year_YYYY, 'DD-MON-YYYY'))
     where pos.nbrjobs_ecls_code in ('NR', 'XR', 'CR', 'EX', 'FR', 'F9', 'FN', 'AR', 'A9') -- Historical Employee Classifications for Cumulative Service
       -- and nbrbjob_pidm =
       and nbrbjob_contract_type in ('P', 'S') -- Types of contracts considered.

), group_begin as (

  select assignments.*,
         case 
           when lag_begin_date is null then begin_date
           when begin_date <= nvl(lag_end_date, to_date('31-DEC-' || :Calendar_Year_YYYY, 'DD-MON-YYYY')) then lag_begin_date
           else begin_date
         end grp_begin_date
    from assignments
) 

--select * from group_begin;

,

group_end as (
  
  select group_begin.*,
         (select max(nvl(gb.end_date, to_date('31-DEC-' || :Calendar_Year_YYYY, 'DD-MON-YYYY')))
            from group_begin gb
           where group_begin.pidm = gb.pidm
             and group_begin.grp_begin_date = gb.grp_begin_date) grp_end_date
    from group_begin

)

--  select * from group_end;

, group_service as (

  select pidm,
         grp_begin_date,
         grp_end_date,
         round(grp_end_date - grp_begin_date) days
    from group_end
group by pidm,
         grp_begin_date,
         grp_end_date

)

--select * from group_service;

, service as (

  select pidm,
         round(sum(days) / 365.25, 1) yos
    from group_service
group by pidm)


    select :Calendar_Year_YYYY "Longevity Year",
           to_date('31-DEC-' || :Calendar_Year_YYYY, 'DD-MON-YYYY') "Longevity Date",
           sysdate "As Of Date",
           dsduaf.f_decode$orgn_campus(org.level1) "Campus",
           org.title2 "Cabinet",
           org.title3 "Unit",
           org.title "Department",
           emp.pebempl_orgn_code_dist "TKL",
           emp.spriden_id "UAID",
           emp.spriden_last_name || ', '  || 
           nvl2(bio.spbpers_pref_first_name, bio.spbpers_pref_first_name, emp.spriden_first_name) || ' '  || 
           substr(emp.spriden_mi,0,1) "Full Name",
           usr.gobtpac_external_user || '@alaska.edu' "UA Email",
           a.spraddr_street_line1 
              || ', ' || a.spraddr_city 
              || ', ' || a.spraddr_stat_code 
              || ', ' || a.spraddr_zip "Mailing Address",
           emp.nbrjobs_ecls_code "ECLS",
           boss.spriden_id "Supervisor UA ID",
           boss.spriden_last_name || ', ' || 
           boss.spriden_first_name || ' ' || 
           substr(boss.spriden_mi,0,1) "Supervisor Name",
           busr.gobtpac_external_user || '@alaska.edu' "Supervisor Email",
           emp.pebempl_first_hire_date "Original Hire Date",
           emp.pebempl_adj_service_date "Adjusted Service Date",
           emp.nbrbjob_begin_date "Curr. Position Start Date",
           emp.nbrbjob_end_date "Curr. Position End Date",
           -- get the total years of service using the adj service date
           floor((to_date('31-DEC-' || :Calendar_Year_YYYY, 'DD-MON-YYYY') - emp.pebempl_adj_service_date) / 365.25) "Adj. Service Years",
           CASE -- set the flag for folks hired prior to 1996
             WHEN to_date('01/01/1996', 'mm/dd/yyyy') > emp.pebempl_first_hire_date THEN 'Y'
             ELSE 'N'
           END "Pre-Banner",
           CASE -- if the person has pre-banner time, add it to the cumulative years.  Take the floor to show the highest year.
             WHEN to_date('01/01/1996', 'mm/dd/yyyy') > emp.pebempl_first_hire_date THEN floor((( to_date('01/01/1996', 'mm/dd/yyyy') - emp.pebempl_first_hire_date ) / 365.25 ) + service.yos)
             ELSE floor(service.yos) 
           END "Cumulative Years",
           CASE -- see if the cumulaticve total falls ona 5 year boundary
             WHEN
               CASE
                 WHEN to_date('01/01/1996', 'mm/dd/yyyy') > emp.pebempl_first_hire_date THEN floor((( to_date('01/01/1996', 'mm/dd/yyyy') - emp.pebempl_first_hire_date ) / 365.25 ) + service.yos)
                 ELSE floor(service.yos) 
               END > 0
               AND remainder (
                 CASE
                   WHEN to_date('01/01/1996', 'mm/dd/yyyy') > emp.pebempl_first_hire_date THEN floor((( to_date('01/01/1996', 'mm/dd/yyyy') - emp.pebempl_first_hire_date ) / 365.25 ) + service.yos)
                   ELSE floor(service.yos) 
                 END, 5) = 0 THEN 'Y'
              ELSE 'N'
            END "Milestone"
      from n_active_jobs emp
      join spbpers bio on bio.spbpers_pidm = emp.pebempl_pidm
      join gobtpac usr on usr.gobtpac_pidm = emp.pebempl_pidm
      join service on service.pidm = emp.pebempl_pidm
      left join ftvorgn_levels_titles org on org.orgn_code = emp.pebempl_orgn_code_home
      left join spraddr a on a.spraddr_pidm = emp.pebempl_pidm
                         and a.spraddr_atyp_code = 'MA'
      left join ner2sup sup on emp.nbrbjob_pidm = sup.ner2sup_pidm
                           and emp.nbrbjob_posn = sup.ner2sup_posn
                           and emp.nbrbjob_suff = sup.ner2sup_suff
                           and sup.ner2sup_sup_ind = 'Y'
      left join spriden boss on boss.spriden_pidm = sup.ner2sup_sup_pidm
                            and boss.spriden_change_ind is null
      left join gobtpac busr on sup.ner2sup_sup_pidm = busr.gobtpac_pidm
     where emp.nbrbjob_contract_type = 'P'
       and emp.nbrjobs_ecls_code in ('EX', 'NR', 'XR', 'CR')
       and (a.spraddr_seqno is null
         or a.spraddr_seqno = (select max(a2.spraddr_seqno)
                                 from spraddr a2
                                where a.spraddr_pidm = a2.spraddr_pidm
                                  and a.spraddr_atyp_code = a2.spraddr_atyp_code))
      and (sup.ner2sup_effective_date is null
        or sup.ner2sup_effective_date = (select max(sup2.ner2sup_effective_date)
                                          from ner2sup sup2
                                         where sup.ner2sup_pidm = sup2.ner2sup_pidm
                                           and sup.ner2sup_posn = sup2.ner2sup_posn
                                           and sup.ner2sup_suff = sup2.ner2sup_suff
                                           and sup2.ner2sup_effective_date <= sysdate))
  order by "Campus",
           service.yos desc;

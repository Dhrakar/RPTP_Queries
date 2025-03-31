-- snajs 2023.08.16 -- This query is used to locate the population of employees on contract extension as of a given date.
-- snajs 2024.02.14 -- Updated cont_ext jcre codes

with conf as (

  select pos.nbrjobs_pidm,
         pos.nbrjobs_posn,
         pos.nbrjobs_suff,
         max(pos.nbrjobs_effective_date) conf_date
    from nbrjobs pos    
   where pos.nbrjobs_jcre_code = 'CONF'
group by pos.nbrjobs_pidm,
         pos.nbrjobs_posn,
         pos.nbrjobs_suff),
        
cont_ext as (
         
  select conf.nbrjobs_pidm,
         conf.nbrjobs_posn,
         conf.nbrjobs_suff,
         conf.conf_date,
         min(pos.nbrjobs_effective_date) cont_ext_end_date
    from conf
left join nbrjobs pos on (pos.nbrjobs_pidm = conf.nbrjobs_pidm
                      and pos.nbrjobs_posn = conf.nbrjobs_posn
                      and pos.nbrjobs_suff = conf.nbrjobs_suff)
   where pos.nbrjobs_jcre_code in ('CONE', 'OCE', 'TERM', 'AONC', 'TRP')
     and pos.nbrjobs_effective_date > conf.conf_date
group by conf.nbrjobs_pidm,
         conf.nbrjobs_posn,
         conf.nbrjobs_suff,
         conf.conf_date)   
         
  select :query_date query_date,
         spriden_pidm pidm,
         spriden_id uaid,
         spriden_last_name last_name,
         spriden_first_name first_name,
         pebempl_empl_status employee_status,
         pebempl_ecls_code employee_ecls,
         pebempl_orgn_code_dist employee_tkl,
         pebempl_orgn_code_home employee_dlevel,
         cont_ext.nbrjobs_posn position,
         cont_ext.nbrjobs_suff suffix,
         cont_ext.conf_date,
         cont_ext.cont_ext_end_date,
         (select jcre.nbrjobs_jcre_code
            from nbrjobs jcre
           where jcre.nbrjobs_pidm = cont_ext.nbrjobs_pidm
             and jcre.nbrjobs_posn = cont_ext.nbrjobs_posn
             and jcre.nbrjobs_suff = cont_ext.nbrjobs_suff
             and jcre.nbrjobs_effective_date = cont_ext.cont_ext_end_date) cont_ext_jcre,
         pos.nbrjobs_status current_job_status,
         pos.nbrjobs_orgn_code_ts current_job_tkl,
         pos.nbrjobs_ecls_code current_job_ecls,
         pos.nbrjobs_desc current_job_title
         
    from cont_ext
    join spriden iden on (cont_ext.nbrjobs_pidm = iden.spriden_pidm
                      and iden.spriden_change_ind is null)
    join nbrjobs pos on (cont_ext.nbrjobs_pidm = pos.nbrjobs_pidm
                     and cont_ext.nbrjobs_posn = pos.nbrjobs_posn
                     and cont_ext.nbrjobs_suff = pos.nbrjobs_suff
                     and pos.nbrjobs_effective_date = (select max(pos2.nbrjobs_effective_date)
                                                         from nbrjobs pos2
                                                        where pos2.nbrjobs_pidm = pos.nbrjobs_pidm
                                                          and pos2.nbrjobs_posn = pos.nbrjobs_posn
                                                          and pos2.nbrjobs_suff = pos.nbrjobs_suff
                                                          and pos2.nbrjobs_effective_date <= sysdate))
    join pebempl empl on (cont_ext.nbrjobs_pidm = empl.pebempl_pidm)
   where :query_date between conf_date and nvl(cont_ext_end_date, :query_date)
order by conf_date
;

select pos.nbrjobs_pidm,
         pos.nbrjobs_posn,
         pos.nbrjobs_suff,
         max(pos.nbrjobs_effective_date) conf_date
    from nbrjobs pos    
   where pos.nbrjobs_jcre_code = 'CONF'
group by pos.nbrjobs_pidm,
         pos.nbrjobs_posn,
         pos.nbrjobs_suff
         ;
         
select * from nbrjobs;




select * from DSDMGR.AR_FINAID_202303_OPEN;
select * from DSDMGR.DSD_STUDENT_STATS_OPEN;

select * from all_ind_columns where index_owner = 'DSDMGR' AND table_name = 'PHRDEDN';
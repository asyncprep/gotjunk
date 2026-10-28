-- Removes every row created by supabase/demo-data.sql (development project only).
-- Demo ids start with d0000000- … d7000000-.
-- Audit log entries about demo rows are kept (the audit log is append-only).
begin;

delete from public.photo where photo_id::text like 'd5000000-%';
delete from public.cash_submission where cash_submission_id::text like 'd4000000-%';
delete from public.disposal_material_txn where disposal_visit_id::text like 'd3000000-%';
delete from public.disposal_visit where disposal_visit_id::text like 'd3000000-%';
delete from public.job where job_id::text like 'd2000000-%';
delete from public.shift_checklist_check where shift_id::text like 'd1000000-%';
delete from public.shift_crew_member where shift_id::text like 'd1000000-%';
delete from public.shift where shift_id::text like 'd1000000-%';
delete from public.employee_rank_history h where h.employee_id::text like 'd0000000-%'
  and not exists (select 1 from public.app_user u where u.employee_id = h.employee_id);
-- A demo employee that someone linked to a real login is kept (the login needs it).
delete from public.employee e where e.employee_id::text like 'd0000000-%'
  and not exists (select 1 from public.app_user u where u.employee_id = e.employee_id);
delete from public.truck where truck_id::text like 'd6000000-%'
  and not exists (select 1 from public.shift s where s.truck_id = truck.truck_id);
delete from public.phone where phone_id::text like 'd7000000-%'
  and not exists (select 1 from public.shift s where s.phone_id = phone.phone_id);

commit;

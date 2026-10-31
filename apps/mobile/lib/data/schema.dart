import 'package:powersync/powersync.dart';

// Local (on-phone) copy of the server tables the crew needs. PowerSync adds an `id`
// column to every table; sync rules alias each server primary key to `id`.
// Server-calculated columns (total_hours, signed amounts…) are read-only here.
const schema = Schema([
  Table('shift', [
    Column.text('shift_date'),
    Column.text('status'),
    Column.text('truck_id'),
    Column.text('phone_id'),
    Column.text('hours_type'),
    Column.text('hours_type_confirmed_at'),
    Column.text('start_time'),
    Column.text('finish_time'),
    Column.real('total_hours'),
    Column.text('return_reason'),
    Column.text('reopen_reason'),
    Column.text('submitted_at'),
    // Only the lead's login can change the shift (one shared phone per truck).
    Column.text('lead_employee_id'),
    // Not synced down: sent only when a crew member takes over the phone.
    Column.text('truck_phone_confirmed_at'),
  ]),
  Table('shift_crew_member', [
    Column.text('shift_id'),
    Column.text('employee_id'),
    Column.text('joined_at'),
    Column.text('left_at'),
  ], indexes: [
    Index('by_shift', [IndexedColumn('shift_id')]),
    Index('by_employee', [IndexedColumn('employee_id')]),
  ]),
  Table('job', [
    Column.text('shift_id'),
    Column.text('opportunity_id'),
    Column.text('outcome'),
    Column.text('payment_method_code'),
    Column.real('discount_amount'),
    Column.real('revenue_pre_tax'),
    Column.real('revenue_total_incl_tax'),
    Column.real('tip_amount'),
    Column.text('cancellation_reason_id'),
    Column.text('completed_at'),
    Column.text('created_at'),
  ], indexes: [
    Index('by_shift', [IndexedColumn('shift_id')]),
  ]),
  Table('disposal_visit', [
    Column.text('shift_id'),
    Column.text('site_id'),
    Column.text('visit_at'),
    Column.text('ticket_number'),
    Column.text('notes'),
    Column.text('created_at'),
  ], indexes: [
    Index('by_shift', [IndexedColumn('shift_id')]),
  ]),
  // Price columns are filled by the server; the phone shows a local estimate until then.
  Table('disposal_material_txn', [
    Column.text('disposal_visit_id'),
    Column.text('material_type_id'),
    Column.real('weight_kg'),
    Column.real('rate_per_ton_applied'),
    Column.text('direction'),
    Column.real('billable_kg'),
    Column.real('signed_amount'),
    Column.text('created_at'),
  ], indexes: [
    Index('by_visit', [IndexedColumn('disposal_visit_id')]),
  ]),
  Table('cash_submission', [
    Column.text('shift_id'),
    Column.real('counted_cash'),
    Column.text('created_at'),
  ]),
  Table('photo', [
    Column.text('shift_id'),
    Column.text('photo_kind'),
    Column.text('entity_type'),
    Column.text('entity_id'),
    Column.text('storage_path'),
    Column.text('captured_at'),
    Column.text('uploaded_at'),
  ], indexes: [
    Index('by_entity', [IndexedColumn('entity_id')]),
  ]),
  Table('site', [
    Column.text('code'),
    Column.text('name'),
    Column.integer('issues_tickets'),
    Column.integer('requires_ticket_photo'),
    Column.integer('active'),
  ]),
  Table('material_type', [
    Column.text('code'),
    Column.text('name_fr'),
    Column.text('name_en'),
    Column.integer('active'),
  ]),
  Table('site_rate_config', [
    Column.text('site_id'),
    Column.text('material_type_id'),
    Column.real('rate_per_ton'),
    Column.text('direction'),
    Column.real('min_billable_kg'),
    Column.text('min_applies_to'),
    Column.text('effective_from'),
    Column.text('effective_to'),
    Column.integer('active'),
  ]),
  Table('employee', [Column.text('full_name')]),
  Table('app_user', [Column.text('employee_id'), Column.text('role')]),
  Table('truck', [Column.text('unit_number')]),
  Table('phone', [Column.text('label')]),
  Table('payment_method', [
    Column.text('name_fr'),
    Column.text('name_en'),
    Column.integer('is_cash'),
    Column.integer('active'),
  ]),
  Table('cancellation_reason', [Column.text('name_fr'), Column.text('name_en')]),
  Table('app_setting', [Column.text('value')]),
  // Photo files waiting to reach storage (the photo row itself syncs normally). Never uploaded.
  Table.localOnly('photo_upload_queue', [
    Column.text('photo_id'),
    Column.text('local_path'),
    Column.text('storage_path'),
    Column.integer('attempts'),
    Column.text('last_error'),
  ]),
  // Shifts this login took over (no lead, or the lead left) and the server hasn't confirmed yet.
  // Never uploaded.
  Table.localOnly('lead_claim', [
    Column.text('shift_id'),
    Column.text('employee_id'),
  ]),
  // Writes the server refused (e.g. a submit that wasn't ready). Never uploaded.
  Table.localOnly('sync_rejection', [
    Column.text('table_name'),
    Column.text('record_id'),
    Column.text('code'),
    Column.text('message'),
    Column.text('created_at'),
  ]),
]);

// Server primary key for each table the crew can write to. Other tables are read-only.
const writablePrimaryKeys = {
  'shift': 'shift_id',
  'job': 'job_id',
  'disposal_visit': 'disposal_visit_id',
  'disposal_material_txn': 'material_txn_id',
  'cash_submission': 'cash_submission_id',
  'photo': 'photo_id',
};

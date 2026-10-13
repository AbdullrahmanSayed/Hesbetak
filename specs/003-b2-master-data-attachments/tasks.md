# B2 Tasks

## Schema & Enums

- [ ] T001 Create migration file `20261013000000_b2_master_data_attachments.sql`
- [ ] T002 Add enums: tracking_type, cash_account_type, attachment_owner_type, attachment_kind, attachment_status
- [ ] T003 Create categories table with RLS
- [ ] T004 Create brands table with RLS
- [ ] T005 Create products table with RLS and barcode uniqueness
- [ ] T006 Create customers table with phone/ID validation and RLS
- [ ] T007 Create suppliers table with RLS
- [ ] T008 Create cash_accounts table with RLS
- [ ] T009 Create expense_categories table with RLS
- [ ] T010 Create partners table with RLS (owner only)
- [ ] T011 Create plan_templates table with RLS
- [ ] T012 Create attachments table with indexes and RLS

## Master Data RPCs

- [ ] T013 Implement manage_category RPC with audit
- [ ] T014 Implement manage_brand RPC with audit
- [ ] T015 Implement manage_product RPC with audit
- [ ] T016 Implement manage_customer RPC with audit and validation
- [ ] T017 Implement manage_supplier RPC with audit
- [ ] T018 Implement manage_cash_account RPC with auto GL account creation
- [ ] T019 Implement manage_expense_category RPC with auto GL account creation
- [ ] T020 Implement manage_partner RPC with auto GL accounts (3) and share validation
- [ ] T021 Implement manage_plan_template RPC with audit

## Attachment RPCs

- [ ] T022 Implement register_attachment RPC
- [ ] T023 Implement attach_to_document RPC
- [ ] T024 Implement supersede_attachment RPC
- [ ] T025 Implement get_attachment_url RPC with audit logging
- [ ] T026 Implement app.can_view_attachment helper
- [ ] T027 Implement app.can_upload_attachment helper

## Seed Data

- [ ] T028 Add seed for default categories
- [ ] T029 Add seed for default brands
- [ ] T030 Add seed for default expense categories

## Tests

- [ ] T031 [P] Add failing schema tests for B2 tables
- [ ] T032 [P] Add failing RLS tests for B2 tables
- [ ] T033 [P] Add failing master data CRUD tests
- [ ] T034 [P] Add failing T26 test (cashier upload, no view)
- [ ] T035 [P] Add failing T27 test (cross-tenant attachment)
- [ ] T036 [P] Add failing T28 test (owner view with audit)
- [ ] T037 [P] Add failing T29 test (attachment status flow)
- [ ] T038 [P] Add failing T30 test (pending cleanup)
- [ ] T039 Run schema tests and fix
- [ ] T040 Run RLS tests and fix
- [ ] T041 Run attachment tests and fix

## Finalization

- [ ] T042 Apply migration and verify reset
- [ ] T043 Regenerate src/types/database.ts
- [ ] T044 Run all local gates (typecheck, lint, unit, pgTAP)
- [ ] T045 Update CHANGELOG.md
- [ ] T046 Commit and push branch
- [ ] T047 Open PR and request review
- [ ] T048 CI green, obtain approval

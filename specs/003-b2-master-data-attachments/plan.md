# B2 Implementation Plan

## Phase 1: Database Schema

### Migration: Master Data Tables

1. **categories**
   - id, tenant_id, name_ar, name_en, sort_order, is_active, created_at, created_by
   - RLS: member can read; owner/manager can manage
   - Seed defaults

2. **brands**
   - id, tenant_id, name, logo_path, is_active, created_at, created_by
   - RLS: member can read; owner/manager can manage
   - Seed defaults

3. **products**
   - id, tenant_id, category_id, brand_id, name_ar, name_en, model, barcode, tracking (serial|quantity), default_price, min_stock, warranty_months, is_active, created_at, created_by
   - Unique: (tenant_id, barcode) where barcode is not null
   - RLS: member can read; owner/manager can manage

4. **customers**
   - id, tenant_id, name, phone1, phone2, national_id, address, area, workplace, guarantor_name, guarantor_phone, guarantor_national_id, notes, assigned_collector_id, risk_flag, is_active, created_at, created_by
   - Check: phone1 format, national_id length
   - RLS: member can read; owner/manager/cashier can manage

5. **suppliers**
   - id, tenant_id, name, phone, address, notes, is_active, created_at, created_by
   - RLS: member can read; owner/manager can manage

6. **cash_accounts**
   - id, tenant_id, name, type (cash|bank|wallet), gl_account_id, is_active, created_at, created_by
   - FK to accounts
   - RLS: member can read; owner can manage

7. **expense_categories**
   - id, tenant_id, name_ar, name_en, gl_account_id, is_active, created_at, created_by
   - FK to accounts
   - Seed defaults
   - RLS: member can read; owner can manage

8. **partners**
   - id, tenant_id, name, share_bp, capital_account_id, current_account_id, drawings_account_id, is_active, created_at, created_by
   - FK to accounts (3 columns)
   - RLS: owner only

9. **plan_templates**
   - id, tenant_id, name, months, factor_bp, min_down_payment_bp, is_active, created_at, created_by
   - RLS: member can read; owner can manage

### Migration: Attachments System

10. **attachment_owner_type** enum
    - customer, guarantor, installment_contract, purchase_invoice, purchase_return, supplier_payment, expense, trade_in

11. **attachment_kind** enum
    - national_id_front, national_id_back, signed_contract, supplier_invoice, supplier_credit_note, payment_proof, receipt, unit_photo, seller_national_id_front, seller_national_id_back, other

12. **attachment_status** enum
    - pending, active, superseded

13. **attachments**
    - id, tenant_id, owner_type, owner_id (nullable), kind, upload_session_id (nullable), bucket, object_path, mime_type, size_bytes, original_filename, status, superseded_reason, superseded_by, created_at, created_by
    - Indexes: (tenant_id, owner_type, owner_id), (tenant_id, upload_session_id) where pending

## Phase 2: RPCs

### Master Data RPCs

- `manage_category(tenant_id, id?, name_ar, name_en, sort_order, is_active)` → uuid
- `manage_brand(tenant_id, id?, name, logo_path, is_active)` → uuid
- `manage_product(tenant_id, id?, ...)` → uuid
- `manage_customer(tenant_id, id?, ...)` → uuid
- `manage_supplier(tenant_id, id?, ...)` → uuid
- `manage_cash_account(tenant_id, id?, name, type)` → uuid (auto-creates GL account)
- `manage_expense_category(tenant_id, id?, name_ar, name_en)` → uuid (auto-creates GL account)
- `manage_partner(tenant_id, id?, name, share_bp)` → uuid (auto-creates 3 GL accounts)
- `manage_plan_template(tenant_id, id?, ...)` → uuid

### Attachment RPCs

- `register_attachment(tenant_id, owner_type, kind, upload_session_id, bucket, object_path, mime_type, size_bytes, original_filename)` → uuid
- `attach_to_document(tenant_id, attachment_id, owner_id)` → uuid
- `supersede_attachment(tenant_id, attachment_id, reason)` → uuid
- `get_attachment_url(tenant_id, attachment_id)` → signed_url (300s), writes audit_log
- `app.can_view_attachment(tenant_id, owner_type)` → boolean (helper for Storage RLS)
- `app.can_upload_attachment(tenant_id, owner_type)` → boolean (helper for Storage RLS)

## Phase 3: Storage Setup

- Create buckets via config (tenant-branding, customer-documents, business-documents)
- Storage RLS policies using app.can_view/upload_attachment helpers

## Phase 4: Tests

### pgTAP Tests

- Schema assertions for all 9 new tables
- RLS tests for each table (member read, role-based write)
- Audit log entries on master data changes
- Archive behavior tests
- Cross-tenant isolation (T19)
- T26: Cashier uploads customer ID, cannot get URL
- T27: Tenant A cannot access Tenant B attachments
- T28: Owner views attachment, signed URL works, audit logged
- T29: Attachment status flow (pending → active → superseded)
- T30: Cleanup of pending > 24h (mock via direct query)

## Phase 5: Seed Data

- Default categories from spec
- Default brands from spec
- Default expense categories

## Phase 6: Types & Documentation

- Regenerate src/types/database.ts
- Update CHANGELOG.md
- Update docs/ACCOUNTING.md if needed

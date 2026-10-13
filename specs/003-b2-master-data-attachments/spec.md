# B2 — Master Data & Attachments

## Overview

B2 delivers the master data tables (categories, brands, products, customers, suppliers, cash accounts, expense categories, partners, installment plan templates) with full CRUD operations, audit logging, and archive-instead-of-delete behavior. It also implements the unified attachment system (Section 6.15) with storage buckets, RLS, RPCs, and cleanup.

## User Stories

### US1: Categories & Brands Management
As an owner, I can manage product categories and brands so products are organized.

**Acceptance:**
- Categories with name_ar, name_en, is_active, audit on changes
- Brands with name, logo_path (optional), is_active, audit on changes
- Seeded defaults from spec (Section 6.1)
- Archive instead of delete

### US2: Products Management  
As an owner/manager, I can manage products with tracking type (serial/quantity), default prices, and alerts.

**Acceptance:**
- Products: name_ar, name_en, category_id, brand_id, model, barcode (unique/tenant), tracking (serial|quantity), default_price, min_stock, warranty_months, is_active
- Barcode uniqueness per tenant
- Cost comes from purchases (B3), not entered directly
- Archive instead of delete

### US3: Customers Management
As an owner/manager/cashier, I can manage customers with phone validation, national ID, and guarantor info.

**Acceptance:**
- Customers: name, phone1 (required, Egyptian format), phone2, national_id (14 digits), address, area, workplace, guarantor fields, notes, assigned_collector_id, risk_flag
- Phone format validation: `01[0125][0-9]{8}`
- National ID validation: 14 digits
- ID images via attachment system (US8)
- Archive instead of delete

### US4: Suppliers Management
As an owner/manager, I can manage suppliers for purchase tracking.

**Acceptance:**
- Suppliers: name, phone, address, notes, is_active
- Linked to accounts_payable subledger in B3
- Archive instead of delete

### US5: Cash Accounts Management
As an owner, I can manage cash accounts (خزن) with auto-created GL sub-accounts.

**Acceptance:**
- Cash accounts: name, type (cash|bank|wallet), gl_account_id (auto-created under 1100), is_active
- Auto-create sub-account under 1100 on creation
- Cannot delete if balance exists (B3+)

### US6: Expense Categories Management
As an owner, I can manage expense categories linked to 6xxx accounts.

**Acceptance:**
- Expense categories: name_ar, name_en, gl_account_id (auto-created under 6xxx), is_active
- Seeded defaults
- Archive instead of delete

### US7: Partners & Plan Templates Management
As an owner, I can manage partners with shares and installment plan templates.

**Acceptance:**
- Partners: name, share_bp (basis points), capital_account_id, current_account_id, drawings_account_id (auto-created)
- Share sum validation (must equal 10000 bp = 100%)
- Plan templates: name, months, factor_bp, min_down_payment_bp, is_active

### US8: Unified Attachment System
As any authorized user, I can upload/view attachments with proper permissions and audit.

**Acceptance:**
- Attachments table with owner_type, owner_id, kind, status, bucket, object_path
- Three buckets: tenant-branding, customer-documents, business-documents
- RPCs: register_attachment, attach_to_document, supersede_attachment, get_attachment_url
- Storage RLS based on tenant membership and role
- Signed URLs (300s) with audit logging
- Cleanup job for pending > 24h
- T26, T27, T28, T29, T30 pass

## Non-Functional Requirements

- All tables have tenant_id + RLS
- Audit log entries for all master data changes
- Archive (is_active = false) instead of hard delete
- Cross-tenant isolation tests
- Generated types updated

## Out of Scope (B3+)

- Inventory movements and stock balances
- Purchase invoices
- Sales transactions
- Actual file upload UI component (Edge Function for resize)

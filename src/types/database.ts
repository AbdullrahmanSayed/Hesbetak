
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "graphql_public": {
          Tables: {
            [_ in never]: never
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "graphql":
{ Args: { "extensions"?: Json,"operationName"?: string,"query"?: string,"variables"?: Json }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        },"public": {
          Tables: {
            "accounts": {
                  Row: {
                    "cash_account_id": string | null,"code": string,"created_at": string,"created_by": string,"id": string,"is_active": boolean,"is_header": boolean,"name_ar": string,"name_en": string,"normal_side": Database["public"]['Enums']["normal_side"],"parent_id": string | null,"partner_id": string | null,"system_key": string | null,"tenant_id": string,"type": Database["public"]['Enums']["account_type"]
                  }
                  Insert: {
                    "cash_account_id"?: string | null,"code": string,"created_at"?: string,"created_by": string,"id"?: string,"is_active"?: boolean,"is_header"?: boolean,"name_ar": string,"name_en": string,"normal_side": Database["public"]['Enums']["normal_side"],"parent_id"?: string | null,"partner_id"?: string | null,"system_key"?: string | null,"tenant_id": string,"type": Database["public"]['Enums']["account_type"]
                  }
                  Update: {
                    "cash_account_id"?: string | null,"code"?: string,"created_at"?: string,"created_by"?: string,"id"?: string,"is_active"?: boolean,"is_header"?: boolean,"name_ar"?: string,"name_en"?: string,"normal_side"?: Database["public"]['Enums']["normal_side"],"parent_id"?: string | null,"partner_id"?: string | null,"system_key"?: string | null,"tenant_id"?: string,"type"?: Database["public"]['Enums']["account_type"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "accounts_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "accounts_tenant_id_parent_id_fkey"
      columns: ["tenant_id","parent_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    }
                  ]
                },"attachments": {
                  Row: {
                    "bucket": string,"created_at": string,"created_by": string,"id": string,"kind": Database["public"]['Enums']["attachment_kind"],"mime_type": string,"object_path": string,"original_filename": string | null,"owner_id": string | null,"owner_type": Database["public"]['Enums']["attachment_owner_type"],"size_bytes": number,"status": Database["public"]['Enums']["attachment_status"],"superseded_by": string | null,"superseded_reason": string | null,"tenant_id": string,"upload_session_id": string | null
                  }
                  Insert: {
                    "bucket": string,"created_at"?: string,"created_by": string,"id"?: string,"kind": Database["public"]['Enums']["attachment_kind"],"mime_type": string,"object_path": string,"original_filename"?: string | null,"owner_id"?: string | null,"owner_type": Database["public"]['Enums']["attachment_owner_type"],"size_bytes": number,"status"?: Database["public"]['Enums']["attachment_status"],"superseded_by"?: string | null,"superseded_reason"?: string | null,"tenant_id": string,"upload_session_id"?: string | null
                  }
                  Update: {
                    "bucket"?: string,"created_at"?: string,"created_by"?: string,"id"?: string,"kind"?: Database["public"]['Enums']["attachment_kind"],"mime_type"?: string,"object_path"?: string,"original_filename"?: string | null,"owner_id"?: string | null,"owner_type"?: Database["public"]['Enums']["attachment_owner_type"],"size_bytes"?: number,"status"?: Database["public"]['Enums']["attachment_status"],"superseded_by"?: string | null,"superseded_reason"?: string | null,"tenant_id"?: string,"upload_session_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "attachments_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"audit_log": {
                  Row: {
                    "action": string,"actor_id": string,"after_data": Json | null,"before_data": Json | null,"created_at": string,"id": string,"request_id": string | null,"target_id": string,"target_type": string,"tenant_id": string
                  }
                  Insert: {
                    "action": string,"actor_id": string,"after_data"?: Json | null,"before_data"?: Json | null,"created_at"?: string,"id"?: string,"request_id"?: string | null,"target_id": string,"target_type": string,"tenant_id": string
                  }
                  Update: {
                    "action"?: string,"actor_id"?: string,"after_data"?: Json | null,"before_data"?: Json | null,"created_at"?: string,"id"?: string,"request_id"?: string | null,"target_id"?: string,"target_type"?: string,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "audit_log_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"brands": {
                  Row: {
                    "created_at": string,"created_by": string,"id": string,"is_active": boolean,"logo_path": string | null,"name": string,"tenant_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"id"?: string,"is_active"?: boolean,"logo_path"?: string | null,"name": string,"tenant_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"id"?: string,"is_active"?: boolean,"logo_path"?: string | null,"name"?: string,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "brands_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"cash_accounts": {
                  Row: {
                    "created_at": string,"created_by": string,"gl_account_id": string,"id": string,"is_active": boolean,"name": string,"tenant_id": string,"type": Database["public"]['Enums']["cash_account_type"]
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"gl_account_id": string,"id"?: string,"is_active"?: boolean,"name": string,"tenant_id": string,"type": Database["public"]['Enums']["cash_account_type"]
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"gl_account_id"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"tenant_id"?: string,"type"?: Database["public"]['Enums']["cash_account_type"]
                  }
                  Relationships: [
                    {
      foreignKeyName: "cash_accounts_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cash_accounts_tenant_id_gl_account_id_fkey"
      columns: ["tenant_id","gl_account_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    }
                  ]
                },"categories": {
                  Row: {
                    "created_at": string,"created_by": string,"id": string,"is_active": boolean,"name_ar": string,"name_en": string,"sort_order": number,"tenant_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"id"?: string,"is_active"?: boolean,"name_ar": string,"name_en": string,"sort_order"?: number,"tenant_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"id"?: string,"is_active"?: boolean,"name_ar"?: string,"name_en"?: string,"sort_order"?: number,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "categories_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"customers": {
                  Row: {
                    "address": string | null,"area": string | null,"assigned_collector_id": string | null,"created_at": string,"created_by": string,"guarantor_name": string | null,"guarantor_national_id": string | null,"guarantor_phone": string | null,"id": string,"is_active": boolean,"name": string,"national_id": string | null,"notes": string | null,"phone1": string,"phone2": string | null,"risk_flag": boolean,"tenant_id": string,"workplace": string | null
                  }
                  Insert: {
                    "address"?: string | null,"area"?: string | null,"assigned_collector_id"?: string | null,"created_at"?: string,"created_by": string,"guarantor_name"?: string | null,"guarantor_national_id"?: string | null,"guarantor_phone"?: string | null,"id"?: string,"is_active"?: boolean,"name": string,"national_id"?: string | null,"notes"?: string | null,"phone1": string,"phone2"?: string | null,"risk_flag"?: boolean,"tenant_id": string,"workplace"?: string | null
                  }
                  Update: {
                    "address"?: string | null,"area"?: string | null,"assigned_collector_id"?: string | null,"created_at"?: string,"created_by"?: string,"guarantor_name"?: string | null,"guarantor_national_id"?: string | null,"guarantor_phone"?: string | null,"id"?: string,"is_active"?: boolean,"name"?: string,"national_id"?: string | null,"notes"?: string | null,"phone1"?: string,"phone2"?: string | null,"risk_flag"?: boolean,"tenant_id"?: string,"workplace"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "customers_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"document_counters": {
                  Row: {
                    "created_at": string,"created_by": string,"doc_type": string,"id": string,"last_no": number,"tenant_id": string,"year": number
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"doc_type": string,"id"?: string,"last_no"?: number,"tenant_id": string,"year": number
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"doc_type"?: string,"id"?: string,"last_no"?: number,"tenant_id"?: string,"year"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "document_counters_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"expense_categories": {
                  Row: {
                    "created_at": string,"created_by": string,"gl_account_id": string,"id": string,"is_active": boolean,"name_ar": string,"name_en": string,"tenant_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"gl_account_id": string,"id"?: string,"is_active"?: boolean,"name_ar": string,"name_en": string,"tenant_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"gl_account_id"?: string,"id"?: string,"is_active"?: boolean,"name_ar"?: string,"name_en"?: string,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "expense_categories_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "expense_categories_tenant_id_gl_account_id_fkey"
      columns: ["tenant_id","gl_account_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    }
                  ]
                },"journal_entries": {
                  Row: {
                    "created_at": string,"created_by": string,"description": string,"entry_date": string,"entry_no": number,"id": string,"request_id": string,"reversed_by_entry_id": string | null,"reverses_entry_id": string | null,"source_id": string,"source_type": string,"tenant_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"description": string,"entry_date": string,"entry_no": number,"id"?: string,"request_id": string,"reversed_by_entry_id"?: string | null,"reverses_entry_id"?: string | null,"source_id": string,"source_type": string,"tenant_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"description"?: string,"entry_date"?: string,"entry_no"?: number,"id"?: string,"request_id"?: string,"reversed_by_entry_id"?: string | null,"reverses_entry_id"?: string | null,"source_id"?: string,"source_type"?: string,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "journal_entries_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "journal_entries_tenant_id_reversed_by_entry_id_fkey"
      columns: ["tenant_id","reversed_by_entry_id"]
isOneToOne: false
      referencedRelation: "journal_entries"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "journal_entries_tenant_id_reverses_entry_id_fkey"
      columns: ["tenant_id","reverses_entry_id"]
isOneToOne: false
      referencedRelation: "journal_entries"
      referencedColumns: ["tenant_id","id"]
    }
                  ]
                },"journal_lines": {
                  Row: {
                    "account_id": string,"cash_account_id": string | null,"category_id": string | null,"contract_id": string | null,"created_at": string,"created_by": string,"credit": number,"customer_id": string | null,"debit": number,"entry_id": string,"id": string,"memo": string | null,"partner_id": string | null,"product_id": string | null,"supplier_id": string | null,"tenant_id": string,"user_id": string | null
                  }
                  Insert: {
                    "account_id": string,"cash_account_id"?: string | null,"category_id"?: string | null,"contract_id"?: string | null,"created_at"?: string,"created_by": string,"credit"?: number,"customer_id"?: string | null,"debit"?: number,"entry_id": string,"id"?: string,"memo"?: string | null,"partner_id"?: string | null,"product_id"?: string | null,"supplier_id"?: string | null,"tenant_id": string,"user_id"?: string | null
                  }
                  Update: {
                    "account_id"?: string,"cash_account_id"?: string | null,"category_id"?: string | null,"contract_id"?: string | null,"created_at"?: string,"created_by"?: string,"credit"?: number,"customer_id"?: string | null,"debit"?: number,"entry_id"?: string,"id"?: string,"memo"?: string | null,"partner_id"?: string | null,"product_id"?: string | null,"supplier_id"?: string | null,"tenant_id"?: string,"user_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "journal_lines_tenant_id_account_id_fkey"
      columns: ["tenant_id","account_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "journal_lines_tenant_id_entry_id_fkey"
      columns: ["tenant_id","entry_id"]
isOneToOne: false
      referencedRelation: "journal_entries"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "journal_lines_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"memberships": {
                  Row: {
                    "created_at": string,"created_by": string,"id": string,"is_active": boolean,"role": Database["public"]['Enums']["membership_role"],"tenant_id": string,"user_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"id"?: string,"is_active"?: boolean,"role": Database["public"]['Enums']["membership_role"],"tenant_id": string,"user_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"id"?: string,"is_active"?: boolean,"role"?: Database["public"]['Enums']["membership_role"],"tenant_id"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "memberships_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"partners": {
                  Row: {
                    "capital_account_id": string,"created_at": string,"created_by": string,"current_account_id": string,"drawings_account_id": string,"id": string,"is_active": boolean,"name": string,"share_bp": number,"tenant_id": string
                  }
                  Insert: {
                    "capital_account_id": string,"created_at"?: string,"created_by": string,"current_account_id": string,"drawings_account_id": string,"id"?: string,"is_active"?: boolean,"name": string,"share_bp": number,"tenant_id": string
                  }
                  Update: {
                    "capital_account_id"?: string,"created_at"?: string,"created_by"?: string,"current_account_id"?: string,"drawings_account_id"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"share_bp"?: number,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "partners_tenant_id_capital_account_id_fkey"
      columns: ["tenant_id","capital_account_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "partners_tenant_id_current_account_id_fkey"
      columns: ["tenant_id","current_account_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "partners_tenant_id_drawings_account_id_fkey"
      columns: ["tenant_id","drawings_account_id"]
isOneToOne: false
      referencedRelation: "accounts"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "partners_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"plan_templates": {
                  Row: {
                    "created_at": string,"created_by": string,"factor_bp": number,"id": string,"is_active": boolean,"min_down_payment_bp": number,"months": number,"name": string,"tenant_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"factor_bp": number,"id"?: string,"is_active"?: boolean,"min_down_payment_bp": number,"months": number,"name": string,"tenant_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"factor_bp"?: number,"id"?: string,"is_active"?: boolean,"min_down_payment_bp"?: number,"months"?: number,"name"?: string,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "plan_templates_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"posting_requests": {
                  Row: {
                    "completed_at": string | null,"created_at": string,"created_by": string,"id": string,"payload_hash": string,"request_id": string,"result": Json | null,"rpc_name": string,"status": Database["public"]['Enums']["posting_request_status"],"tenant_id": string
                  }
                  Insert: {
                    "completed_at"?: string | null,"created_at"?: string,"created_by": string,"id"?: string,"payload_hash": string,"request_id": string,"result"?: Json | null,"rpc_name": string,"status"?: Database["public"]['Enums']["posting_request_status"],"tenant_id": string
                  }
                  Update: {
                    "completed_at"?: string | null,"created_at"?: string,"created_by"?: string,"id"?: string,"payload_hash"?: string,"request_id"?: string,"result"?: Json | null,"rpc_name"?: string,"status"?: Database["public"]['Enums']["posting_request_status"],"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "posting_requests_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"products": {
                  Row: {
                    "barcode": string | null,"brand_id": string | null,"category_id": string | null,"created_at": string,"created_by": string,"default_price": number,"id": string,"is_active": boolean,"min_stock": number,"model": string | null,"name_ar": string,"name_en": string | null,"tenant_id": string,"tracking": Database["public"]['Enums']["tracking_type"],"warranty_months": number
                  }
                  Insert: {
                    "barcode"?: string | null,"brand_id"?: string | null,"category_id"?: string | null,"created_at"?: string,"created_by": string,"default_price"?: number,"id"?: string,"is_active"?: boolean,"min_stock"?: number,"model"?: string | null,"name_ar": string,"name_en"?: string | null,"tenant_id": string,"tracking"?: Database["public"]['Enums']["tracking_type"],"warranty_months"?: number
                  }
                  Update: {
                    "barcode"?: string | null,"brand_id"?: string | null,"category_id"?: string | null,"created_at"?: string,"created_by"?: string,"default_price"?: number,"id"?: string,"is_active"?: boolean,"min_stock"?: number,"model"?: string | null,"name_ar"?: string,"name_en"?: string | null,"tenant_id"?: string,"tracking"?: Database["public"]['Enums']["tracking_type"],"warranty_months"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "products_tenant_id_brand_id_fkey"
      columns: ["tenant_id","brand_id"]
isOneToOne: false
      referencedRelation: "brands"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "products_tenant_id_category_id_fkey"
      columns: ["tenant_id","category_id"]
isOneToOne: false
      referencedRelation: "categories"
      referencedColumns: ["tenant_id","id"]
    },{
      foreignKeyName: "products_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"suppliers": {
                  Row: {
                    "address": string | null,"created_at": string,"created_by": string,"id": string,"is_active": boolean,"name": string,"notes": string | null,"phone": string | null,"tenant_id": string
                  }
                  Insert: {
                    "address"?: string | null,"created_at"?: string,"created_by": string,"id"?: string,"is_active"?: boolean,"name": string,"notes"?: string | null,"phone"?: string | null,"tenant_id": string
                  }
                  Update: {
                    "address"?: string | null,"created_at"?: string,"created_by"?: string,"id"?: string,"is_active"?: boolean,"name"?: string,"notes"?: string | null,"phone"?: string | null,"tenant_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "suppliers_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"tenant_secret_refs": {
                  Row: {
                    "created_at": string,"created_by": string,"id": string,"kind": Database["public"]['Enums']["secret_kind"],"tenant_id": string,"vault_secret_id": string
                  }
                  Insert: {
                    "created_at"?: string,"created_by": string,"id"?: string,"kind": Database["public"]['Enums']["secret_kind"],"tenant_id": string,"vault_secret_id": string
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string,"id"?: string,"kind"?: Database["public"]['Enums']["secret_kind"],"tenant_id"?: string,"vault_secret_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "tenant_secret_refs_tenant_id_fkey"
      columns: ["tenant_id"]
isOneToOne: false
      referencedRelation: "tenants"
      referencedColumns: ["id"]
    }
                  ]
                },"tenants": {
                  Row: {
                    "address": string | null,"created_at": string,"created_by": string,"id": string,"legal_name": string | null,"lock_date": string | null,"logo_path": string | null,"name": string,"phones": (string)[],"plan": string,"settings": NonNullable<Json>,"slug": string,"status": Database["public"]['Enums']["tenant_status"],"tax_number": string | null
                  }
                  Insert: {
                    "address"?: string | null,"created_at"?: string,"created_by": string,"id"?: string,"legal_name"?: string | null,"lock_date"?: string | null,"logo_path"?: string | null,"name": string,"phones"?: (string)[],"plan"?: string,"settings"?: NonNullable<Json>,"slug": string,"status"?: Database["public"]['Enums']["tenant_status"],"tax_number"?: string | null
                  }
                  Update: {
                    "address"?: string | null,"created_at"?: string,"created_by"?: string,"id"?: string,"legal_name"?: string | null,"lock_date"?: string | null,"logo_path"?: string | null,"name"?: string,"phones"?: (string)[],"plan"?: string,"settings"?: NonNullable<Json>,"slug"?: string,"status"?: Database["public"]['Enums']["tenant_status"],"tax_number"?: string | null
                  }
                  Relationships: [
                    
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "attach_to_document":
{ Args: { "p_attachment_id": string,"p_owner_id": string,"p_tenant_id": string }; Returns: string
                           },
"bootstrap_tenant":
{ Args: { "p_name": string,"p_slug": string }; Returns: string
                           },
"get_attachment_url":
{ Args: { "p_attachment_id": string,"p_tenant_id": string }; Returns: string
                           },
"manage_brand":
{ Args: { "p_id": string,"p_is_active"?: boolean,"p_logo_path"?: string,"p_name": string,"p_tenant_id": string }; Returns: string
                           },
"manage_cash_account":
{ Args: { "p_id": string,"p_is_active"?: boolean,"p_name": string,"p_tenant_id": string,"p_type": Database["public"]['Enums']["cash_account_type"] }; Returns: string
                           },
"manage_category":
{ Args: { "p_id": string,"p_is_active"?: boolean,"p_name_ar": string,"p_name_en": string,"p_sort_order"?: number,"p_tenant_id": string }; Returns: string
                           },
"manage_customer":
{ Args: { "p_address"?: string,"p_area"?: string,"p_assigned_collector_id"?: string,"p_guarantor_name"?: string,"p_guarantor_national_id"?: string,"p_guarantor_phone"?: string,"p_id": string,"p_is_active"?: boolean,"p_name": string,"p_national_id"?: string,"p_notes"?: string,"p_phone1": string,"p_phone2"?: string,"p_risk_flag"?: boolean,"p_tenant_id": string,"p_workplace"?: string }; Returns: string
                           },
"manage_expense_category":
{ Args: { "p_id": string,"p_is_active"?: boolean,"p_name_ar": string,"p_name_en": string,"p_tenant_id": string }; Returns: string
                           },
"manage_membership":
{ Args: { "p_is_active": boolean,"p_role": Database["public"]['Enums']["membership_role"],"p_tenant_id": string,"p_user_id": string }; Returns: string
                           },
"manage_partner":
{ Args: { "p_id": string,"p_is_active"?: boolean,"p_name": string,"p_share_bp": number,"p_tenant_id": string }; Returns: string
                           },
"manage_plan_template":
{ Args: { "p_factor_bp": number,"p_id": string,"p_is_active"?: boolean,"p_min_down_payment_bp": number,"p_months": number,"p_name": string,"p_tenant_id": string }; Returns: string
                           },
"manage_product":
{ Args: { "p_barcode"?: string,"p_brand_id"?: string,"p_category_id"?: string,"p_default_price"?: number,"p_id": string,"p_is_active"?: boolean,"p_min_stock"?: number,"p_model"?: string,"p_name_ar": string,"p_name_en"?: string,"p_tenant_id": string,"p_tracking"?: Database["public"]['Enums']["tracking_type"],"p_warranty_months"?: number }; Returns: string
                           },
"manage_supplier":
{ Args: { "p_address"?: string,"p_id": string,"p_is_active"?: boolean,"p_name": string,"p_notes"?: string,"p_phone"?: string,"p_tenant_id": string }; Returns: string
                           },
"manage_tenant_secret_ref":
{ Args: { "p_kind": Database["public"]['Enums']["secret_kind"],"p_tenant_id": string,"p_vault_secret_id": string }; Returns: string
                           },
"register_attachment":
{ Args: { "p_bucket": string,"p_kind": Database["public"]['Enums']["attachment_kind"],"p_mime_type": string,"p_object_path": string,"p_original_filename"?: string,"p_owner_type": Database["public"]['Enums']["attachment_owner_type"],"p_size_bytes": number,"p_tenant_id": string,"p_upload_session_id": string }; Returns: string
                           },
"set_lock_date":
{ Args: { "p_lock_date": string,"p_tenant_id": string }; Returns: string
                           },
"supersede_attachment":
{ Args: { "p_attachment_id": string,"p_reason": string,"p_tenant_id": string }; Returns: string
                           }
          }
          Enums: {
            "account_type": "asset"|"liability"|"equity"|"revenue"|"expense","attachment_kind": "national_id_front"|"national_id_back"|"signed_contract"|"supplier_invoice"|"supplier_credit_note"|"payment_proof"|"receipt"|"unit_photo"|"seller_national_id_front"|"seller_national_id_back"|"other","attachment_owner_type": "customer"|"guarantor"|"installment_contract"|"purchase_invoice"|"purchase_return"|"supplier_payment"|"expense"|"trade_in","attachment_status": "pending"|"active"|"superseded","cash_account_type": "cash"|"bank"|"wallet","membership_role": "owner"|"manager"|"cashier"|"collector"|"accountant","normal_side": "debit"|"credit","posting_request_status": "processing"|"completed","secret_kind": "whatsapp"|"n8n"|"llm","tenant_status": "trial"|"active"|"suspended","tracking_type": "serial"|"quantity"
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "graphql_public": {
          Enums: {
            
          }
        },"public": {
          Enums: {
            "account_type": ["asset", "liability", "equity", "revenue", "expense"],"attachment_kind": ["national_id_front", "national_id_back", "signed_contract", "supplier_invoice", "supplier_credit_note", "payment_proof", "receipt", "unit_photo", "seller_national_id_front", "seller_national_id_back", "other"],"attachment_owner_type": ["customer", "guarantor", "installment_contract", "purchase_invoice", "purchase_return", "supplier_payment", "expense", "trade_in"],"attachment_status": ["pending", "active", "superseded"],"cash_account_type": ["cash", "bank", "wallet"],"membership_role": ["owner", "manager", "cashier", "collector", "accountant"],"normal_side": ["debit", "credit"],"posting_request_status": ["processing", "completed"],"secret_kind": ["whatsapp", "n8n", "llm"],"tenant_status": ["trial", "active", "suspended"],"tracking_type": ["serial", "quantity"]
          }
        }
} as const

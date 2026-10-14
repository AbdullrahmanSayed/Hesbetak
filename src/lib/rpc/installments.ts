/**
 * Typed RPC wrappers for installment sales.
 * All money values are passed as decimal strings per spec Section 8.2.
 */

import type { SupabaseClient } from "@supabase/supabase-js";

import {
  type InstallmentSaleInput,
  type InstallmentSaleResult,
  installmentSaleResultSchema,
  type PreviewScheduleInput,
  type PreviewScheduleResult,
  previewScheduleResultSchema,
} from "@/schemas/installments";
import type { Database } from "@/types/database";

export { generateRequestId } from "./sales";

/**
 * Preview installment schedule without posting.
 * Pure function - no database writes.
 */
export async function previewInstallmentSchedule(
  supabase: SupabaseClient<Database>,
  input: PreviewScheduleInput
): Promise<PreviewScheduleResult> {
  const { data, error } = await supabase.rpc("preview_installment_schedule", {
    p_cash_total: input.cashTotal,
    p_down_payment: input.downPayment,
    p_months: input.months,
    p_factor_bp: input.factorBp ?? undefined,
    p_manual_deferred_price: input.manualDeferredPrice ?? undefined,
    p_rounding_step: Number(input.roundingStep),
    p_first_due_date: input.firstDueDate ?? undefined,
  });

  if (error) {
    throw new Error(error.message);
  }

  return previewScheduleResultSchema.parse(data);
}

/**
 * Post an installment sale with contract creation.
 * Creates: sales_invoice, sales_invoice_lines, sales_payments (down payment),
 * installment_contract, installments, journal_entry, stock_movements.
 */
export async function postInstallmentSale(
  supabase: SupabaseClient<Database>,
  input: InstallmentSaleInput
): Promise<InstallmentSaleResult> {
  const lines = input.lines.map((line) => ({
    product_id: line.productId,
    unit_id: line.unitId ?? null,
    qty: line.qty,
    cash_price: line.cashPrice,
    discount: line.discount,
  }));

  const { data, error } = await supabase.rpc("post_installment_sale", {
    p_tenant_id: input.tenantId,
    p_request_id: input.requestId,
    p_doc_date: input.docDate,
    p_customer_id: input.customerId,
    p_lines: lines,
    p_down_payment: input.downPayment,
    p_down_payment_cash_account_id: input.downPaymentCashAccountId ?? undefined,
    p_months: input.months,
    p_factor_bp: input.factorBp ?? undefined,
    p_manual_deferred_price: input.manualDeferredPrice ?? undefined,
    p_rounding_step: input.roundingStep,
    p_first_due_date: input.firstDueDate ?? undefined,
    p_upload_session_id: input.uploadSessionId ?? undefined,
  });

  if (error) {
    throw new Error(error.message);
  }

  return installmentSaleResultSchema.parse(data);
}

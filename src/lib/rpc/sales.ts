import type { SupabaseClient } from "@supabase/supabase-js";

import { piastersToWire, type Piasters } from "@/lib/money";
import { saleResultSchema, type SaleResult } from "@/schemas/sales";
import type { Database, Json } from "@/types/database";

export interface CashSaleLine {
  productId: string;
  unitId: string | null;
  qty: number;
  cashPrice: Piasters;
  discount: Piasters;
}

export interface CashSalePayment {
  cashAccountId: string;
  amount: Piasters;
}

export interface PostCashSaleParams {
  tenantId: string;
  requestId: string;
  docDate: string;
  customerId: string | null;
  lines: readonly CashSaleLine[];
  payments: readonly CashSalePayment[];
  invoiceDiscount: Piasters;
}

export async function postCashSale(
  supabase: SupabaseClient<Database>,
  params: PostCashSaleParams,
): Promise<SaleResult> {
  const lines: Json[] = params.lines.map((line) => ({
    product_id: line.productId,
    unit_id: line.unitId,
    qty: line.qty,
    cash_price: piastersToWire(line.cashPrice),
    discount: piastersToWire(line.discount),
  }));
  const payments: Json[] = params.payments.map((payment) => ({
    cash_account_id: payment.cashAccountId,
    amount: piastersToWire(payment.amount),
  }));

  const { data, error } = await supabase.rpc("post_cash_sale", {
    p_tenant_id: params.tenantId,
    p_request_id: params.requestId,
    p_doc_date: params.docDate,
    ...(params.customerId ? { p_customer_id: params.customerId } : {}),
    p_lines: lines,
    p_payments: payments,
    p_invoice_discount: piastersToWire(params.invoiceDiscount),
  });

  if (error) {
    throw new Error(error.message);
  }
  return saleResultSchema.parse(data);
}

export interface SalesReturnLine {
  originalLineId: string;
  unitId: string | null;
  qty: number;
  returnCondition: "new" | "used" | "open_box";
}

export interface PostSalesReturnParams {
  tenantId: string;
  requestId: string;
  originalInvoiceId: string;
  docDate: string;
  lines: readonly SalesReturnLine[];
  refundCashAccountId: string;
  reason: string;
}

export async function postSalesReturn(
  supabase: SupabaseClient<Database>,
  params: PostSalesReturnParams,
): Promise<SaleResult> {
  const lines: Json[] = params.lines.map((line) => ({
    original_line_id: line.originalLineId,
    unit_id: line.unitId,
    qty: line.qty,
    return_condition: line.returnCondition,
  }));
  const { data, error } = await supabase.rpc("post_sales_return", {
    p_tenant_id: params.tenantId,
    p_request_id: params.requestId,
    p_original_invoice_id: params.originalInvoiceId,
    p_doc_date: params.docDate,
    p_lines: lines,
    p_refund_cash_account_id: params.refundCashAccountId,
    p_reason: params.reason,
  });
  if (error) {
    throw new Error(error.message);
  }
  return saleResultSchema.parse(data);
}

export function generateRequestId(): string {
  return crypto.randomUUID();
}

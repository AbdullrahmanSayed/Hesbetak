import { z } from "zod";

/** Decimal string for money values (integer piasters as string) */
export const decimalString = z.string().regex(/^(0|[1-9][0-9]*)$/, "قيمة المبلغ غير صحيحة");
const moneyWireSchema = decimalString;
const positiveMoneyWireSchema = z.string().regex(/^[1-9][0-9]*$/, "قيمة المبلغ يجب أن تكون موجبة");
const businessDateSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "تنسيق التاريخ غير صحيح");

export const cashSaleLineSchema = z.object({
  product_id: z.string().uuid("معرف المنتج غير صحيح"),
  unit_id: z.string().uuid("معرف الوحدة غير صحيح").nullable(),
  qty: z.number().int().positive("الكمية يجب أن تكون موجبة"),
  cash_price: positiveMoneyWireSchema,
  discount: moneyWireSchema,
});

export const cashSalePaymentSchema = z.object({
  cash_account_id: z.string().uuid("معرف حساب الدفع غير صحيح"),
  amount: positiveMoneyWireSchema,
});

export const postCashSaleSchema = z.object({
  tenant_id: z.string().uuid("معرف المتجر غير صحيح"),
  request_id: z.string().uuid("معرف الطلب غير صحيح"),
  doc_date: businessDateSchema,
  customer_id: z.string().uuid("معرف العميل غير صحيح").nullable(),
  lines: z.array(cashSaleLineSchema).min(1, "أضف صنفاً واحداً على الأقل"),
  payments: z.array(cashSalePaymentSchema).min(1, "أضف طريقة دفع واحدة على الأقل"),
  invoice_discount: moneyWireSchema,
});

export const salesReturnLineSchema = z.object({
  original_line_id: z.string().uuid("معرف السطر الأصلي غير صحيح"),
  unit_id: z.string().uuid("معرف الوحدة غير صحيح").nullable(),
  qty: z.number().int().positive("الكمية يجب أن تكون موجبة"),
  return_condition: z.enum(["new", "used", "open_box"]),
});

export const postSalesReturnSchema = z.object({
  tenant_id: z.string().uuid("معرف المتجر غير صحيح"),
  request_id: z.string().uuid("معرف الطلب غير صحيح"),
  original_invoice_id: z.string().uuid("معرف الفاتورة الأصلية غير صحيح"),
  doc_date: businessDateSchema,
  lines: z.array(salesReturnLineSchema).min(1, "حدد صنفاً مرتجعاً واحداً على الأقل"),
  refund_cash_account_id: z.string().uuid("معرف حساب رد المبلغ غير صحيح"),
  reason: z.string().trim().min(1, "سبب المرتجع مطلوب"),
});

export const saleResultSchema = z.object({
  id: z.string().uuid(),
  doc_no: z.string().regex(/^[1-9][0-9]*$/),
});

export type SaleResult = z.infer<typeof saleResultSchema>;
export type CashSaleWireInput = z.infer<typeof postCashSaleSchema>;
export type SalesReturnWireInput = z.infer<typeof postSalesReturnSchema>;

/**
 * Zod schemas for installment sales input validation.
 * These schemas validate user input before sending to Supabase RPCs.
 * Money values are validated as decimal strings per Section 8.2 of the spec.
 */

import { z } from "zod";

import { decimalString } from "./sales";

/** Preview schedule input (client-side preview before posting) */
export const previewScheduleInputSchema = z.object({
  cashTotal: decimalString,
  downPayment: decimalString,
  months: z.number().int().min(1).max(60),
  factorBp: z.number().int().min(0).max(10000).nullish(),
  manualDeferredPrice: decimalString.nullish(),
  roundingStep: z.enum(["100", "500", "1000"]).default("100"),
  firstDueDate: z.string().date().nullish(),
});
export type PreviewScheduleInput = z.infer<typeof previewScheduleInputSchema>;

/** Single installment in the schedule */
export const scheduleRowSchema = z.object({
  installment_no: z.number(),
  due_date: z.string(),
  amount: z.string(),
  principal: z.string(),
  margin: z.string(),
});
export type ScheduleRow = z.infer<typeof scheduleRowSchema>;

/** Preview result from preview_installment_schedule RPC */
export const previewScheduleResultSchema = z.object({
  cash_total: z.string(),
  down_payment: z.string(),
  financed_base: z.string(),
  margin_total: z.string(),
  receivable: z.string(),
  months: z.number(),
  first_due_date: z.string(),
  rounding_step: z.string(),
  schedule: z.array(scheduleRowSchema),
});
export type PreviewScheduleResult = z.infer<typeof previewScheduleResultSchema>;

/** Line item for installment sale */
export const installmentSaleLineSchema = z.object({
  productId: z.string().uuid(),
  unitId: z.string().uuid().nullish(),
  qty: z.number().int().min(1),
  cashPrice: decimalString,
  discount: decimalString.default("0"),
});
export type InstallmentSaleLine = z.infer<typeof installmentSaleLineSchema>;

/** Full installment sale input */
export const installmentSaleInputSchema = z.object({
  tenantId: z.string().uuid(),
  requestId: z.string().uuid(),
  docDate: z.string().date(),
  customerId: z.string().uuid(),
  lines: z.array(installmentSaleLineSchema).min(1),
  downPayment: decimalString,
  downPaymentCashAccountId: z.string().uuid().nullish(),
  months: z.number().int().min(1).max(60),
  factorBp: z.number().int().min(0).max(10000).nullish(),
  manualDeferredPrice: decimalString.nullish(),
  roundingStep: z.number().int().refine((v) => [100, 500, 1000].includes(v)).default(100),
  firstDueDate: z.string().date().nullish(),
  uploadSessionId: z.string().uuid().nullish(),
});
export type InstallmentSaleInput = z.infer<typeof installmentSaleInputSchema>;

/** Result from post_installment_sale RPC */
export const installmentSaleResultSchema = z.object({
  invoice_id: z.string(),
  invoice_doc_no: z.string(),
  contract_id: z.string(),
  contract_doc_no: z.string(),
});
export type InstallmentSaleResult = z.infer<typeof installmentSaleResultSchema>;

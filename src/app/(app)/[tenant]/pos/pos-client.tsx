"use client";

import { Search, ShoppingCart, Trash2, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useReducer, useRef, useState } from "react";

import { ThermalReceipt } from "@/components/print/thermal-receipt";
import { cairoToday } from "@/lib/dates";
import { formatMoney, MONEY_PARSE_MESSAGES_AR, parseMoney } from "@/lib/money";
import {
  calculateCartTotals,
  canPostCart,
  cartReducer,
  EMPTY_CART,
  lineNet,
  moneyInputValue,
  type CartState,
  type CartTotals,
  type POSCashAccount,
  type POSCustomer,
  type POSProduct,
  type POSUnit,
} from "@/lib/pos";
import { generateRequestId, postCashSale } from "@/lib/rpc/sales";
import { createBrowserSupabaseClient } from "@/lib/supabase/client";

interface POSClientProps {
  tenantId: string;
  tenantName: string;
  receiptFooter: string | null;
  products: readonly POSProduct[];
  units: readonly POSUnit[];
  cashAccounts: readonly POSCashAccount[];
  customers: readonly POSCustomer[];
}

interface PostedReceipt {
  documentNumber: string;
  documentDate: string;
  cart: CartState;
  totals: CartTotals;
  customerName: string | null;
}

function includesQuery(product: POSProduct, normalizedQuery: string, serialMatches: boolean): boolean {
  return serialMatches
    || product.nameAr.toLocaleLowerCase("ar").includes(normalizedQuery)
    || product.model?.toLocaleLowerCase("ar").includes(normalizedQuery) === true
    || product.barcode?.includes(normalizedQuery) === true;
}

export function POSClient({
  tenantId,
  tenantName,
  receiptFooter,
  products,
  units,
  cashAccounts,
}: POSClientProps) {
  const [cart, dispatch] = useReducer(cartReducer, EMPTY_CART);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedSerialProduct, setSelectedSerialProduct] = useState<POSProduct | null>(null);
  const [paymentAccountId, setPaymentAccountId] = useState(cashAccounts[0]?.id ?? "");
  const [paymentInput, setPaymentInput] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const [isPosting, setIsPosting] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [receipt, setReceipt] = useState<PostedReceipt | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const totals = useMemo(() => calculateCartTotals(cart), [cart]);
  const readyToPost = canPostCart(cart) && !isPosting;

  const normalizedQuery = searchQuery.trim().toLocaleLowerCase("ar");
  const filteredProducts = useMemo(
    () => normalizedQuery
      ? products.filter((product) => includesQuery(
          product,
          normalizedQuery,
          units.some((u) => u.productId === product.id && u.serialNo.toLocaleLowerCase("ar").includes(normalizedQuery)),
        ))
      : products,
    [normalizedQuery, products, units],
  );
  const selectableUnits = useMemo(
    () => selectedSerialProduct
      ? units.filter(
          (unit) => unit.productId === selectedSerialProduct.id
            && !cart.lines.some((line) => line.unitId === unit.id),
        )
      : [],
    [cart.lines, selectedSerialProduct, units],
  );

  const chooseProduct = useCallback((product: POSProduct) => {
    setMessage(null);
    if (product.tracking === "serial") {
      setSelectedSerialProduct(product);
      return;
    }
    const existing = cart.lines.find((line) => line.productId === product.id);
    if (existing && existing.qty >= product.availableQty) {
      setMessage("لا توجد كمية إضافية متاحة من هذا الصنف");
      return;
    }
    dispatch({ type: "add", product });
    setSearchQuery("");
  }, [cart.lines]);

  const requestPost = useCallback(() => {
    if (!readyToPost) {
      setMessage("أكمل المدفوعات قبل ترحيل الفاتورة");
      return;
    }
    setConfirmOpen(true);
  }, [readyToPost]);

  useEffect(() => {
    const handleKeyboard = (event: KeyboardEvent) => {
      if (event.key === "/" && document.activeElement !== searchRef.current) {
        event.preventDefault();
        searchRef.current?.focus();
      } else if (event.key === "F9") {
        event.preventDefault();
        requestPost();
      } else if (event.key === "Escape") {
        event.preventDefault();
        if (selectedSerialProduct) {
          setSelectedSerialProduct(null);
        } else if (confirmOpen) {
          setConfirmOpen(false);
        } else {
          dispatch({ type: "clear" });
          setMessage(null);
        }
      }
    };
    window.addEventListener("keydown", handleKeyboard);
    return () => window.removeEventListener("keydown", handleKeyboard);
  }, [confirmOpen, requestPost, selectedSerialProduct]);

  const addPayment = () => {
    setMessage(null);
    const account = cashAccounts.find((item) => item.id === paymentAccountId);
    if (!account) {
      setMessage("اختر حساب الدفع");
      return;
    }
    const parsed = parseMoney(paymentInput);
    if (!parsed.ok) {
      setMessage(MONEY_PARSE_MESSAGES_AR[parsed.error]);
      return;
    }
    if (parsed.value > totals.balance) {
      setMessage("مبلغ الدفع أكبر من المتبقي");
      return;
    }
    dispatch({
      type: "addPayment",
      payment: { cashAccountId: account.id, cashAccountName: account.name, amount: parsed.value },
    });
    setPaymentInput("");
  };

  const setInvoiceDiscount = (input: string) => {
    const parsed = parseMoney(input || "0");
    if (!parsed.ok) {
      setMessage(MONEY_PARSE_MESSAGES_AR[parsed.error]);
      return;
    }
    dispatch({ type: "setInvoiceDiscount", discount: parsed.value });
    setMessage(null);
  };

  const setLineDiscount = (key: string, input: string) => {
    const parsed = parseMoney(input || "0");
    if (!parsed.ok) {
      setMessage(MONEY_PARSE_MESSAGES_AR[parsed.error]);
      return;
    }
    dispatch({ type: "setLineDiscount", key, discount: parsed.value });
    setMessage(null);
  };

  const confirmPost = async () => {
    if (!readyToPost) return;
    setIsPosting(true);
    setMessage(null);
    const documentDate = cairoToday();
    try {
      const result = await postCashSale(createBrowserSupabaseClient(), {
        tenantId,
        requestId: generateRequestId(),
        docDate: documentDate,
        customerId: null,
        lines: cart.lines.map((line) => ({
          productId: line.productId,
          unitId: line.unitId,
          qty: line.qty,
          cashPrice: line.cashPrice,
          discount: line.discount,
        })),
        payments: cart.payments.map((payment) => ({
          cashAccountId: payment.cashAccountId,
          amount: payment.amount,
        })),
        invoiceDiscount: cart.invoiceDiscount,
      });
      setReceipt({ documentNumber: result.doc_no, documentDate, cart, totals, customerName: null });
      dispatch({ type: "clear" });
      setConfirmOpen(false);
      setMessage(`تم ترحيل الفاتورة رقم ${result.doc_no} بنجاح`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "تعذر ترحيل الفاتورة");
    } finally {
      setIsPosting(false);
    }
  };

  return (
    <>
      <div className="mx-auto flex max-w-[1600px] flex-col gap-4 xl:h-[calc(100vh-2.5rem)] xl:flex-row">
        <section className="flex min-h-[520px] flex-1 flex-col overflow-hidden rounded-2xl border bg-white shadow-sm">
          <header className="border-b p-4">
            <div className="mb-3 flex items-center justify-between gap-3">
              <div>
                <p className="text-sm text-slate-500">{tenantName}</p>
                <h1 className="text-2xl font-bold text-slate-900">نقطة البيع</h1>
              </div>
              <div className="rounded-full bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-700">
                بيع كاش
              </div>
            </div>
            <label className="relative block">
              <Search className="absolute right-3 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-400" />
              <input
                ref={searchRef}
                value={searchQuery}
                onChange={(event) => setSearchQuery(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" && filteredProducts[0]) chooseProduct(filteredProducts[0]);
                }}
                className="h-12 w-full rounded-xl border border-slate-300 bg-slate-50 pr-11 pl-4 outline-none transition focus:border-emerald-500 focus:ring-2 focus:ring-emerald-100"
                placeholder="ابحث بالاسم أو الموديل أو الباركود — اضغط /"
              />
            </label>
          </header>

          <div className="grid flex-1 auto-rows-max grid-cols-1 gap-3 overflow-y-auto p-4 sm:grid-cols-2 lg:grid-cols-3">
            {filteredProducts.map((product) => (
              <button
                type="button"
                key={product.id}
                onClick={() => chooseProduct(product)}
                className="min-h-32 rounded-xl border border-slate-200 p-4 text-right transition hover:-translate-y-0.5 hover:border-emerald-400 hover:shadow-md"
              >
                <div className="font-semibold text-slate-900">{product.nameAr}</div>
                <div className="mt-1 min-h-5 text-sm text-slate-500">{product.model ?? "بدون موديل"}</div>
                <div className="mt-4 flex items-end justify-between gap-2">
                  <span className="font-bold text-emerald-700">{formatMoney(product.defaultPrice)}</span>
                  <span className="text-xs text-slate-500">متاح {product.availableQty}</span>
                </div>
              </button>
            ))}
            {filteredProducts.length === 0 ? (
              <div className="col-span-full py-16 text-center text-slate-500">لا توجد منتجات مطابقة</div>
            ) : null}
          </div>
          <footer className="flex gap-4 border-t bg-slate-50 px-4 py-2 text-xs text-slate-500">
            <span>/ للبحث</span><span>Enter للإضافة</span><span>F9 للترحيل</span><span>Esc للمسح</span>
          </footer>
        </section>

        <aside className="flex w-full flex-col overflow-hidden rounded-2xl border bg-white shadow-sm xl:w-[460px]">
          <header className="flex items-center gap-2 border-b p-4">
            <ShoppingCart className="h-5 w-5 text-emerald-700" />
            <h2 className="font-bold">الفاتورة الحالية</h2>
            <span className="mr-auto rounded-full bg-slate-100 px-2 py-0.5 text-xs">{cart.lines.length} صنف</span>
          </header>

          <div className="max-h-[42vh] flex-1 divide-y overflow-y-auto xl:max-h-none">
            {cart.lines.length === 0 ? (
              <div className="flex h-44 items-center justify-center text-sm text-slate-500">أضف صنفاً لبدء الفاتورة</div>
            ) : cart.lines.map((line) => (
              <article key={line.key} className="space-y-3 p-4">
                <div className="flex items-start gap-2">
                  <div className="flex-1">
                    <h3 className="font-semibold">{line.productName}</h3>
                    {line.serialNo ? <p className="text-xs text-slate-500">سيريال: {line.serialNo}</p> : null}
                  </div>
                  <button type="button" aria-label="حذف الصنف" onClick={() => dispatch({ type: "remove", key: line.key })} className="rounded-lg p-2 text-rose-600 hover:bg-rose-50">
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
                <div className="grid grid-cols-3 gap-2 text-sm">
                  <label>الكمية
                    <input
                      type="number" min={1} max={line.availableQty} disabled={line.tracking === "serial"}
                      value={line.qty}
                      onChange={(event) => dispatch({ type: "setQty", key: line.key, qty: Number(event.target.value) })}
                      className="mt-1 h-9 w-full rounded-lg border px-2 disabled:bg-slate-100"
                    />
                  </label>
                  <label>السعر
                    <div className="mt-1 flex h-9 items-center rounded-lg bg-slate-50 px-2">{formatMoney(line.cashPrice)}</div>
                  </label>
                  <label>الخصم
                    <input
                      inputMode="decimal" defaultValue="0"
                      onBlur={(event) => setLineDiscount(line.key, event.target.value)}
                      className="mt-1 h-9 w-full rounded-lg border px-2"
                    />
                  </label>
                </div>
                <div className="flex justify-between text-sm"><span className="text-slate-500">صافي السطر</span><strong>{formatMoney(lineNet(line))}</strong></div>
              </article>
            ))}
          </div>

          <div className="space-y-3 border-t bg-slate-50 p-4">
            <label className="flex items-center justify-between gap-3 text-sm">
              <span>خصم الفاتورة</span>
              <input inputMode="decimal" defaultValue="0" onBlur={(event) => setInvoiceDiscount(event.target.value)} className="h-9 w-32 rounded-lg border bg-white px-2" />
            </label>
            <div className="flex justify-between text-sm"><span>الإجمالي</span><span>{formatMoney(totals.gross)}</span></div>
            <div className="flex justify-between text-sm text-rose-700"><span>إجمالي الخصم</span><span>{formatMoney(totals.totalDiscount)}</span></div>
            <div className="flex justify-between border-t pt-3 text-xl font-bold"><span>المطلوب</span><span>{formatMoney(totals.net)}</span></div>
          </div>

          <div className="space-y-3 border-t p-4">
            <h3 className="font-semibold">المدفوعات</h3>
            <div className="grid grid-cols-[1fr_1fr_auto] gap-2">
              <select value={paymentAccountId} onChange={(event) => setPaymentAccountId(event.target.value)} className="h-10 rounded-lg border px-2">
                {cashAccounts.map((account) => <option value={account.id} key={account.id}>{account.name}</option>)}
              </select>
              <input value={paymentInput} onChange={(event) => setPaymentInput(event.target.value)} inputMode="decimal" placeholder="المبلغ" className="h-10 rounded-lg border px-2" />
              <button type="button" onClick={addPayment} className="rounded-lg bg-slate-900 px-4 text-white">إضافة</button>
            </div>
            <button type="button" onClick={() => setPaymentInput(moneyInputValue(totals.balance))} disabled={totals.balance <= 0n} className="text-sm font-medium text-emerald-700 disabled:text-slate-400">
              إدخال كامل المتبقي: {formatMoney(totals.balance)}
            </button>
            {cart.payments.map((payment, index) => (
              <div key={`${payment.cashAccountId}-${index}`} className="flex items-center justify-between rounded-lg bg-emerald-50 px-3 py-2 text-sm">
                <span>{payment.cashAccountName}</span><strong>{formatMoney(payment.amount)}</strong>
                <button type="button" aria-label="حذف الدفع" onClick={() => dispatch({ type: "removePayment", index })}><X className="h-4 w-4" /></button>
              </div>
            ))}
            <div className="flex justify-between font-semibold"><span>المتبقي</span><span>{formatMoney(totals.balance)}</span></div>
          </div>

          {message ? <div role="status" className="mx-4 mb-3 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">{message}</div> : null}
          <div className="grid grid-cols-2 gap-2 border-t p-4">
            <button type="button" onClick={() => dispatch({ type: "clear" })} className="h-12 rounded-xl border font-semibold">مسح</button>
            <button type="button" onClick={requestPost} disabled={!readyToPost} className="h-12 rounded-xl bg-emerald-600 font-bold text-white disabled:cursor-not-allowed disabled:bg-slate-300">ترحيل F9</button>
          </div>
          {receipt ? <button type="button" onClick={() => window.print()} className="mx-4 mb-4 h-10 rounded-lg border border-emerald-600 font-semibold text-emerald-700">طباعة آخر إيصال</button> : null}
        </aside>
      </div>

      {selectedSerialProduct ? (
        <div className="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/50 p-4" role="dialog" aria-modal="true" aria-label="اختيار الرقم المسلسل">
          <div className="w-full max-w-md rounded-2xl bg-white p-5 shadow-xl">
            <div className="mb-4 flex items-center justify-between"><div><p className="text-sm text-slate-500">اختر الرقم المسلسل</p><h2 className="font-bold">{selectedSerialProduct.nameAr}</h2></div><button type="button" onClick={() => setSelectedSerialProduct(null)}><X /></button></div>
            <div className="max-h-72 space-y-2 overflow-y-auto">
              {selectableUnits.map((unit) => (
                <button type="button" key={unit.id} onClick={() => { dispatch({ type: "add", product: selectedSerialProduct, unit }); setSelectedSerialProduct(null); setSearchQuery(""); }} className="flex w-full justify-between rounded-xl border p-3 text-right hover:border-emerald-500">
                  <span>{unit.serialNo}</span><span className="text-sm text-slate-500">{unit.condition === "new" ? "جديد" : unit.condition === "used" ? "مستعمل" : "فتح كرتونة"}</span>
                </button>
              ))}
              {selectableUnits.length === 0 ? <p className="py-8 text-center text-slate-500">لا توجد وحدات متاحة</p> : null}
            </div>
          </div>
        </div>
      ) : null}

      {confirmOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 p-4" role="dialog" aria-modal="true" aria-label="تأكيد ترحيل الفاتورة">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl">
            <h2 className="text-xl font-bold">تأكيد ترحيل الفاتورة</h2>
            <p className="mt-2 text-sm text-slate-600">سيتم خصم الأصناف من المخزون وإضافة القيود المحاسبية التالية نهائياً.</p>
            <dl className="mt-5 space-y-3 rounded-xl bg-slate-50 p-4">
              <div className="flex justify-between"><dt>عدد الأصناف</dt><dd>{cart.lines.length}</dd></div>
              <div className="flex justify-between"><dt>الإجمالي</dt><dd>{formatMoney(totals.gross)}</dd></div>
              <div className="flex justify-between"><dt>الخصم</dt><dd>{formatMoney(totals.totalDiscount)}</dd></div>
              <div className="flex justify-between border-t pt-3 text-lg font-bold"><dt>صافي التحصيل</dt><dd>{formatMoney(totals.net)}</dd></div>
            </dl>
            <div className="mt-5 grid grid-cols-2 gap-3">
              <button type="button" onClick={() => setConfirmOpen(false)} disabled={isPosting} className="h-11 rounded-xl border font-semibold">رجوع</button>
              <button type="button" onClick={confirmPost} disabled={isPosting} className="h-11 rounded-xl bg-emerald-600 font-bold text-white disabled:bg-slate-300">{isPosting ? "جاري الترحيل..." : "تأكيد الترحيل"}</button>
            </div>
          </div>
        </div>
      ) : null}

      {receipt ? (
        <ThermalReceipt tenantName={tenantName} documentNumber={receipt.documentNumber} documentDate={receipt.documentDate} lines={receipt.cart.lines} totals={receipt.totals} footer={receiptFooter} />
      ) : null}
    </>
  );
}

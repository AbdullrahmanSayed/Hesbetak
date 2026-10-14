import { describe, expect, it } from "vitest";

import { toPiasters } from "@/lib/money";
import {
  calculateCartTotals,
  canPostCart,
  cartReducer,
  EMPTY_CART,
  lineNet,
  moneyInputValue,
  type POSProduct,
} from "@/lib/pos";

const quantityProduct: POSProduct = {
  id: "10000000-0000-0000-0000-000000000001",
  nameAr: "منتج اختبار",
  model: null,
  barcode: null,
  tracking: "quantity",
  defaultPrice: toPiasters(2_000_000n),
  availableQty: 10,
};

describe("POS cart money calculations", () => {
  it("calculates exact bigint totals without floating point", () => {
    let cart = cartReducer(EMPTY_CART, { type: "add", product: quantityProduct });
    cart = cartReducer(cart, { type: "setLineDiscount", key: quantityProduct.id, discount: toPiasters(25_000n) });
    cart = cartReducer(cart, { type: "setInvoiceDiscount", discount: toPiasters(25_000n) });
    const totals = calculateCartTotals(cart);

    expect(totals.gross).toBe(2_000_000n);
    expect(totals.totalDiscount).toBe(50_000n);
    expect(totals.net).toBe(1_950_000n);
    expect(lineNet(cart.lines[0]!)).toBe(1_975_000n);
  });

  it("supports split payments and becomes postable only at zero balance", () => {
    let cart = cartReducer(EMPTY_CART, { type: "add", product: quantityProduct });
    cart = cartReducer(cart, {
      type: "addPayment",
      payment: { cashAccountId: "cash", cashAccountName: "الخزنة", amount: toPiasters(1_000_000n) },
    });
    expect(canPostCart(cart)).toBe(false);
    cart = cartReducer(cart, {
      type: "addPayment",
      payment: { cashAccountId: "wallet", cashAccountName: "محفظة", amount: toPiasters(1_000_000n) },
    });
    expect(canPostCart(cart)).toBe(true);
  });

  it("does not allow quantity to exceed available stock", () => {
    let cart = cartReducer(EMPTY_CART, { type: "add", product: { ...quantityProduct, availableQty: 1 } });
    cart = cartReducer(cart, { type: "add", product: { ...quantityProduct, availableQty: 1 } });
    expect(cart.lines[0]!.qty).toBe(1);
  });

  it("formats a piaster balance for an EGP money input", () => {
    expect(moneyInputValue(toPiasters(1_950_025n))).toBe("19500.25");
  });
});

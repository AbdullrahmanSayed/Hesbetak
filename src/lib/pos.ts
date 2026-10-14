import { toPiasters, type Piasters } from "@/lib/money";

export type TrackingType = "serial" | "quantity";
export type UnitCondition = "new" | "used" | "open_box";

export interface POSProduct {
  id: string;
  nameAr: string;
  model: string | null;
  barcode: string | null;
  tracking: TrackingType;
  defaultPrice: Piasters;
  availableQty: number;
}

export interface POSUnit {
  id: string;
  productId: string;
  serialNo: string;
  condition: UnitCondition;
}

export interface POSCashAccount {
  id: string;
  name: string;
  type: "cash" | "bank" | "wallet";
}

export interface POSCustomer {
  id: string;
  name: string;
  phone: string;
}

export interface CartLine {
  key: string;
  productId: string;
  productName: string;
  tracking: TrackingType;
  unitId: string | null;
  serialNo: string | null;
  availableQty: number;
  qty: number;
  cashPrice: Piasters;
  discount: Piasters;
}

export interface CartPayment {
  cashAccountId: string;
  cashAccountName: string;
  amount: Piasters;
}

export interface CartState {
  lines: CartLine[];
  payments: CartPayment[];
  invoiceDiscount: Piasters;
}

export interface CartTotals {
  gross: Piasters;
  lineDiscount: Piasters;
  invoiceDiscount: Piasters;
  totalDiscount: Piasters;
  net: Piasters;
  paid: Piasters;
  balance: Piasters;
}

export type CartAction =
  | { type: "add"; product: POSProduct; unit?: POSUnit }
  | { type: "remove"; key: string }
  | { type: "setQty"; key: string; qty: number }
  | { type: "setLineDiscount"; key: string; discount: Piasters }
  | { type: "setInvoiceDiscount"; discount: Piasters }
  | { type: "addPayment"; payment: CartPayment }
  | { type: "removePayment"; index: number }
  | { type: "clear" };

export const EMPTY_CART: CartState = {
  lines: [],
  payments: [],
  invoiceDiscount: 0n as Piasters,
};

export function lineGross(line: CartLine): Piasters {
  return toPiasters(line.cashPrice * BigInt(line.qty));
}

export function lineNet(line: CartLine): Piasters {
  return toPiasters(lineGross(line) - line.discount);
}

export function calculateCartTotals(state: CartState): CartTotals {
  const gross = state.lines.reduce((total, line) => total + lineGross(line), 0n);
  const lineDiscount = state.lines.reduce((total, line) => total + line.discount, 0n);
  const net = gross - lineDiscount - state.invoiceDiscount;
  const paid = state.payments.reduce((total, payment) => total + payment.amount, 0n);
  return {
    gross: toPiasters(gross),
    lineDiscount: toPiasters(lineDiscount),
    invoiceDiscount: state.invoiceDiscount,
    totalDiscount: toPiasters(lineDiscount + state.invoiceDiscount),
    net: toPiasters(net),
    paid: toPiasters(paid),
    balance: toPiasters(net - paid),
  };
}

function isValidLine(line: CartLine): boolean {
  return Number.isInteger(line.qty)
    && line.qty > 0
    && line.qty <= line.availableQty
    && (line.tracking !== "serial" || line.qty === 1)
    && line.discount >= 0n
    && line.discount < lineGross(line);
}

export function cartReducer(state: CartState, action: CartAction): CartState {
  switch (action.type) {
    case "add": {
      const unit = action.unit;
      if (action.product.tracking === "serial" && !unit) {
        return state;
      }
      const key = unit?.id ?? action.product.id;
      const existing = state.lines.find((line) => line.key === key);
      if (existing) {
        if (existing.tracking === "serial" || existing.qty >= existing.availableQty) {
          return state;
        }
        return {
          ...state,
          lines: state.lines.map((line) =>
            line.key === key ? { ...line, qty: line.qty + 1 } : line,
          ),
        };
      }
      return {
        ...state,
        lines: [
          ...state.lines,
          {
            key,
            productId: action.product.id,
            productName: action.product.nameAr,
            tracking: action.product.tracking,
            unitId: unit?.id ?? null,
            serialNo: unit?.serialNo ?? null,
            availableQty: action.product.availableQty,
            qty: 1,
            cashPrice: action.product.defaultPrice,
            discount: 0n as Piasters,
          },
        ],
      };
    }
    case "remove":
      return { ...state, lines: state.lines.filter((line) => line.key !== action.key) };
    case "setQty":
      return {
        ...state,
        lines: state.lines.map((line) => {
          if (line.key !== action.key) return line;
          const updated = { ...line, qty: action.qty };
          return isValidLine(updated) ? updated : line;
        }),
      };
    case "setLineDiscount":
      return {
        ...state,
        lines: state.lines.map((line) => {
          if (line.key !== action.key) return line;
          const updated = { ...line, discount: action.discount };
          return isValidLine(updated) ? updated : line;
        }),
      };
    case "setInvoiceDiscount": {
      const grossAfterLineDiscount = state.lines.reduce(
        (total, line) => total + lineNet(line),
        0n,
      );
      if (action.discount < 0n || action.discount >= grossAfterLineDiscount) {
        return state;
      }
      return { ...state, invoiceDiscount: action.discount };
    }
    case "addPayment": {
      const totals = calculateCartTotals(state);
      if (action.payment.amount <= 0n || action.payment.amount > totals.balance) {
        return state;
      }
      return { ...state, payments: [...state.payments, action.payment] };
    }
    case "removePayment":
      return { ...state, payments: state.payments.filter((_, index) => index !== action.index) };
    case "clear":
      return EMPTY_CART;
  }
}

export function canPostCart(state: CartState): boolean {
  const totals = calculateCartTotals(state);
  return state.lines.length > 0 && totals.net > 0n && totals.balance === 0n;
}

export function moneyInputValue(value: Piasters): string {
  const whole = value / 100n;
  const fraction = (value % 100n).toString().padStart(2, "0");
  return `${whole}.${fraction}`;
}

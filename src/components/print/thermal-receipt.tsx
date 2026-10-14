import { APP_NAME } from "@/config/app";
import { formatMoney } from "@/lib/money";
import { lineNet, type CartLine, type CartTotals } from "@/lib/pos";

interface ThermalReceiptProps {
  tenantName: string;
  documentNumber: string;
  documentDate: string;
  lines: readonly CartLine[];
  totals: CartTotals;
  footer: string | null;
}

export function ThermalReceipt({
  tenantName,
  documentNumber,
  documentDate,
  lines,
  totals,
  footer,
}: ThermalReceiptProps) {
  return (
    <section className="thermal-receipt hidden" aria-label="إيصال البيع">
      <header className="receipt-center">
        <strong>{tenantName}</strong>
        <div>{APP_NAME.ar}</div>
        <div>إيصال بيع كاش رقم {documentNumber}</div>
        <div>{documentDate}</div>
      </header>
      <div className="receipt-rule" />
      {lines.map((line) => (
        <div className="receipt-line" key={line.key}>
          <div>
            {line.productName}
            {line.serialNo ? ` — ${line.serialNo}` : ""}
          </div>
          <div className="receipt-row">
            <span>{line.qty} × {formatMoney(line.cashPrice)}</span>
            <strong>{formatMoney(lineNet(line))}</strong>
          </div>
        </div>
      ))}
      <div className="receipt-rule" />
      <div className="receipt-row"><span>الإجمالي</span><span>{formatMoney(totals.gross)}</span></div>
      <div className="receipt-row"><span>الخصم</span><span>{formatMoney(totals.totalDiscount)}</span></div>
      <div className="receipt-row receipt-total"><span>المدفوع</span><strong>{formatMoney(totals.net)}</strong></div>
      {footer ? <footer className="receipt-center receipt-footer">{footer}</footer> : null}
    </section>
  );
}

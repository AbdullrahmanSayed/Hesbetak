import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { APP_NAME } from "@/config/app";
import { piastersFromWire } from "@/lib/money";
import type { POSCashAccount, POSCustomer, POSProduct, POSUnit } from "@/lib/pos";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { POSClient } from "./pos-client";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: `نقطة البيع | ${APP_NAME.ar}`,
};

interface POSPageProps {
  params: Promise<{ tenant: string }>;
}

function requireViewValue<T>(value: T | null, field: string): T {
  if (value === null) throw new Error(`POS view returned null for ${field}`);
  return value;
}

function receiptFooter(settings: unknown): string | null {
  if (!settings || typeof settings !== "object" || Array.isArray(settings)) return null;
  const value = (settings as Record<string, unknown>).receipt_footer;
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export default async function POSPage({ params }: POSPageProps) {
  const { tenant: tenantSlug } = await params;
  const supabase = await createServerSupabaseClient();
  const { data: tenant, error: tenantError } = await supabase
    .from("tenants")
    .select("id,name,settings")
    .eq("slug", tenantSlug)
    .maybeSingle();

  if (tenantError) throw new Error(tenantError.message);
  if (!tenant) notFound();

  const [productsResult, unitsResult, accountsResult, customersResult] = await Promise.all([
    supabase
      .from("pos_products")
      .select("id,name_ar,model,barcode,tracking,default_price,available_qty")
      .eq("tenant_id", tenant.id)
      .gt("available_qty", 0)
      .order("name_ar"),
    supabase
      .from("pos_inventory_units")
      .select("id,product_id,serial_no,condition")
      .eq("tenant_id", tenant.id)
      .order("serial_no"),
    supabase
      .from("pos_cash_accounts")
      .select("id,name,type")
      .eq("tenant_id", tenant.id)
      .order("name"),
    supabase
      .from("customers")
      .select("id,name,phone1")
      .eq("tenant_id", tenant.id)
      .eq("is_active", true)
      .order("name"),
  ]);

  const loadError = productsResult.error ?? unitsResult.error ?? accountsResult.error ?? customersResult.error;
  if (loadError) throw new Error(loadError.message);

  const products: POSProduct[] = (productsResult.data ?? []).map((product) => ({
    id: requireViewValue(product.id, "pos_products.id"),
    nameAr: requireViewValue(product.name_ar, "pos_products.name_ar"),
    model: product.model,
    barcode: product.barcode,
    tracking: requireViewValue(product.tracking, "pos_products.tracking"),
    defaultPrice: piastersFromWire(requireViewValue(product.default_price, "pos_products.default_price")),
    availableQty: requireViewValue(product.available_qty, "pos_products.available_qty"),
  }));
  const units: POSUnit[] = (unitsResult.data ?? []).map((unit) => ({
    id: requireViewValue(unit.id, "pos_inventory_units.id"),
    productId: requireViewValue(unit.product_id, "pos_inventory_units.product_id"),
    serialNo: requireViewValue(unit.serial_no, "pos_inventory_units.serial_no"),
    condition: requireViewValue(unit.condition, "pos_inventory_units.condition"),
  }));
  const cashAccounts: POSCashAccount[] = (accountsResult.data ?? []).map((account) => ({
    id: requireViewValue(account.id, "pos_cash_accounts.id"),
    name: requireViewValue(account.name, "pos_cash_accounts.name"),
    type: requireViewValue(account.type, "pos_cash_accounts.type"),
  }));
  const customers: POSCustomer[] = (customersResult.data ?? []).map((customer) => ({
    id: customer.id,
    name: customer.name,
    phone: customer.phone1,
  }));

  return (
    <main className="min-h-screen bg-slate-100 p-3 md:p-5">
      <POSClient
        tenantId={tenant.id}
        tenantName={tenant.name}
        receiptFooter={receiptFooter(tenant.settings)}
        products={products}
        units={units}
        cashAccounts={cashAccounts}
        customers={customers}
      />
    </main>
  );
}

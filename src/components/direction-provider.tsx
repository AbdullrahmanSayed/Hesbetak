"use client";

import { DirectionProvider as RadixDirectionProvider } from "@radix-ui/react-direction";
import type { ReactNode } from "react";

/** Makes every Radix-based shadcn/ui component render right-to-left. */
export function DirectionProvider({ children }: { children: ReactNode }) {
  return <RadixDirectionProvider dir="rtl">{children}</RadixDirectionProvider>;
}

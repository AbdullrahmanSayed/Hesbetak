import type { Metadata } from "next";
import { IBM_Plex_Sans_Arabic } from "next/font/google";
import type { ReactNode } from "react";

import { DirectionProvider } from "@/components/direction-provider";
import { APP_NAME } from "@/config/app";

import "./globals.css";

const plexArabic = IBM_Plex_Sans_Arabic({
  subsets: ["arabic", "latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
  variable: "--font-plex-arabic",
});

export const metadata: Metadata = {
  title: APP_NAME.ar,
  applicationName: APP_NAME.ar,
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ar" dir="rtl" className={plexArabic.variable}>
      <body>
        <DirectionProvider>{children}</DirectionProvider>
      </body>
    </html>
  );
}

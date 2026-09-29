import { expect, test } from "@playwright/test";

import { APP_NAME } from "../../src/config/app";

// B0 shell smoke test (FR-013, FR-014, FR-015, FR-021): Arabic RTL, IBM Plex Sans Arabic,
// product name from src/config/app.ts, no horizontal overflow, no console errors.

test("home page renders the Arabic RTL shell with the configured product name", async ({ page }) => {
  const consoleErrors: string[] = [];
  page.on("console", (message) => {
    if (message.type() === "error") {
      consoleErrors.push(message.text());
    }
  });
  page.on("pageerror", (error) => {
    consoleErrors.push(error.message);
  });

  await page.goto("/");

  const html = page.locator("html");
  await expect(html).toHaveAttribute("lang", "ar");
  await expect(html).toHaveAttribute("dir", "rtl");

  await expect(page).toHaveTitle(APP_NAME.ar);
  expect(await page.title()).toBe(APP_NAME.ar);

  const headings = page.locator("h1");
  await expect(headings).toHaveCount(1);
  await expect(headings).toHaveText(APP_NAME.ar);

  // No feature links or placeholder navigation in B0 (D-B0-06, Rule 15).
  await expect(page.locator("a")).toHaveCount(0);

  const bodyFontFamily = await page.evaluate(() => getComputedStyle(document.body).fontFamily);
  expect(bodyFontFamily).toMatch(/IBM[ _]Plex[ _]Sans[ _]Arabic/);

  const plexLoaded = await page.evaluate(async () => {
    await document.fonts.ready;
    return Array.from(document.fonts).some(
      (face) => /IBM[ _]Plex[ _]Sans[ _]Arabic/.test(face.family) && face.status === "loaded",
    );
  });
  expect(plexLoaded).toBe(true);

  const overflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  expect(overflow.scrollWidth).toBeLessThanOrEqual(overflow.innerWidth);

  expect(consoleErrors).toEqual([]);
});

import { readFileSync } from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

// Section 0.5 / FR-024: CLAUDE.md and AGENTS.md are identical and carry Section 18 verbatim.

const root = process.cwd();
const read = (file: string): Buffer => readFileSync(path.join(root, file));
// Line endings may be converted on Windows checkouts; compare text with LF endings.
const text = (buffer: Buffer): string => buffer.toString("utf8").replace(/\r\n/g, "\n");

function extractSection18(spec: string): string {
  const start = spec.indexOf("\n## 18. Agent Rules");
  if (start < 0) {
    throw new Error("Section 18 heading not found in docs/HESBETAK_SPEC.md");
  }
  const next = spec.indexOf("\n## ", start + 1);
  return spec.slice(start + 1, next < 0 ? undefined : next).trimEnd();
}

describe("agent-rules guard", () => {
  const claude = read("CLAUDE.md");
  const agents = read("AGENTS.md");
  const section18 = extractSection18(text(read("docs/HESBETAK_SPEC.md")));

  it("keeps CLAUDE.md and AGENTS.md byte-identical", () => {
    expect(claude.equals(agents)).toBe(true);
  });

  it("extracts all 19 Section 18 rules from the canonical spec", () => {
    expect(section18.startsWith("## 18. Agent Rules")).toBe(true);
    expect(section18).toContain("\n19. ");
  });

  it.each([
    ["CLAUDE.md", claude],
    ["AGENTS.md", agents],
  ])("%s contains Section 18 verbatim", (_file, content) => {
    expect(text(content)).toContain(section18);
  });
});

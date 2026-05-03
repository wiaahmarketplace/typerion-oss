#!/usr/bin/env node
import("../dist/bin.js").catch((err) => {
  process.stderr.write(`typerion: bootstrap failed: ${err?.message ?? err}\n`);
  process.exit(70);
});

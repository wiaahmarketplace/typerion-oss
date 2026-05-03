import { run } from "./index.js";

run(process.argv.slice(2)).then(
  (code) => process.exit(code),
  (err: unknown) => {
    process.stderr.write(`typerion: fatal: ${(err as Error).message ?? String(err)}\n`);
    process.exit(70); // sysexits EX_SOFTWARE
  },
);

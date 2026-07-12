// Compile the omp standalone binary via upstream's compileCodingAgent helper.
//
// Since v16.4.6 the compiled binary needs the in-memory `omp-legacy-pi-modules`
// virtual module, which is only provided by a Bun.build() plugin
// (scripts/legacy-pi-virtual-module.ts). The `bun build --compile` CLI cannot
// load plugins, so we call the upstream compile function directly.
//
// Usage (from packages/coding-agent, like upstream's build-binary.ts, so that
// bare package imports emitted by the virtual-module plugin resolve the same
// way): bun compile-standalone.ts <bun-compile-target>

import { createRequire } from "node:module";
import * as path from "node:path";

const target = process.argv[2];
if (!target) throw new Error("usage: compile-standalone.ts <bun-compile-target>");

const codingAgentDir = process.cwd();
const repoRoot = path.resolve(codingAgentDir, "..", "..");

const { compileCodingAgent } = await import(
	path.join(codingAgentDir, "scripts", "compile-binary.ts")
);

// Mirror scripts/build-binary.ts: embed the concrete Transformers.js version so
// the tiny-model worker can pin its runtime install.
const require = createRequire(path.join(codingAgentDir, "package.json"));
const transformersManifest = require("@huggingface/transformers/package.json") as {
	version: string;
};

await compileCodingAgent({
	repoRoot,
	entrypoint: path.join(codingAgentDir, "src", "cli.ts"),
	outfile: path.join(repoRoot, "dist", "omp"),
	transformersVersion: transformersManifest.version,
	target: target as Bun.Build.CompileTarget,
});

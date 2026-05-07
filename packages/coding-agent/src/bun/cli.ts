#!/usr/bin/env node
// Copyright (c) 2025 Mario Zechner. MIT License.
import { APP_NAME } from "../config.js";

process.title = APP_NAME;
process.emitWarning = (() => {}) as typeof process.emitWarning;

import { restoreSandboxEnv } from "./restore-sandbox-env.js";

restoreSandboxEnv();

await import("./register-bedrock.js");
await import("../cli.js");

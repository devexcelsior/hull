// Copyright (c) 2025 Mario Zechner. MIT License.
import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		include: ["test/wrap-ansi.test.ts"],
	},
});

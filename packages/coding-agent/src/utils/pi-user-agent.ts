// Copyright (c) 2025 Mario Zechner. MIT License.
export function getPiUserAgent(version: string): string {
	const runtime = process.versions.bun ? `bun/${process.versions.bun}` : `node/${process.version}`;
	return `pi/${version} (${process.platform}; ${runtime}; ${process.arch})`;
}

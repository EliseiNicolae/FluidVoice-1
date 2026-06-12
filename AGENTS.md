# AGENTS.md

- Be brief and clear. Keep first issue summaries to 5 lines max.
- For macOS app code, optimize for low resource usage and multiple OS versions.
- Ask Barath when a decision is genuinely unclear.
- Build FluidVoice with `sh build_incremental.sh`.
- Before commit-ready code, run `swiftformat --config .swiftformat Sources` and `swiftlint --strict --config .swiftlint.yml Sources/`.
- After committing, update the relevant `RELEASE_NOTES_*.md` version section.
- Ask which release-notes version to use before editing release notes.
- Keep `RELEASE_NOTES_*.md` files local and uncommitted.

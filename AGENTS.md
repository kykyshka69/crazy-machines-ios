# Crazy Machines iOS — working instructions

Read [PROJECT_STATUS.md](PROJECT_STATUS.md) **START HERE** at the beginning of each task before making changes. Verify current GitHub branch/HEAD and the latest relevant Actions run; prior historical notes are not the latest result.

- **Only active gameplay branch:** `work/original-3d-scene-batch`. Never rebuild a second port on `main`, create a third CML decoder, or overwrite the original 3D scene engine. `main` is divergent.
- Continue the actual **Crazy Machines PC→iOS original game port**, not a synthetic substitute. Original scenes/resources remain user-private and outside Git.
- Stage 1 only until the real electrical network, mechanical energy transfer, WIN32 GOAL/CONNECTED_TO events, lifecycle and all **102 real original puzzles** are actually verified. A synthetic UI fixture passing does not mean original gameplay parity.
- Preserve specific confirmed Win32 mechanics and original object identities. Do not invent source voltage/current, contact rules, physical timing, or level completion events.
- **Do not rebuild the iOS application after every commit.** First implement a coherent batch of real Stage-1 mechanics, validate pure Swift locally with `bash scripts/check-stage1-mechanics-fast.sh` (plus specific focused checks), and use `[skip ci]` on intermediate code commits. Run Source, Portable, ARM64 and Simulator **once at a deliberate integration checkpoint**, not after each small change. Record the precise verified outcomes and gameplay SHA at the TOP of `PROJECT_STATUS.md`. Never confuse local fast tests with actual iPhone/Simulator verification.
- No percentage progress updates. No claims of actual original iPhone screenshots without the private owner-only test and screenshot artifact. Do not expose licensed PC assets in GitHub.

Follow the first actionable missing block in `PROJECT_STATUS.md`, not the old root README history.

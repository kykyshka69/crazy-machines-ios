# Crazy Machines — iOS research

> **Актуальна розробка станом на 23.11.2026:** `main` — застаріла гілка щодо повноцінного перенесення гри. **Продовжувати тільки** в [`work/original-3d-scene-batch`](https://github.com/kykyshka69/crazy-machines-ios/tree/work/original-3d-scene-batch). **Канонічний журнал:** [`PROJECT_STATUS.md` робочої гілки](https://github.com/kykyshka69/crazy-machines-ios/blob/work/original-3d-scene-batch/PROJECT_STATUS.md). Не повторювати роботу з CML, UCM, SceneKit та механіки на `main`; усі старі звіти нижче історичні.
Ми переносимо оригінальну Crazy Machines з Windows на iOS.

Головний репозиторій:
https://github.com/kykyshka69/crazy-machines-ios

**Правила роботи:**

1. Перед продовженням роботи перевіряй актуальний код GitHub, останні коміти, результати тестів і PROJECT_STATUS.md.
2. Не починай розробку заново, якщо відповідні компоненти вже реалізовані.
3. Не повторюй виконані завдання без конкретної технічної причини.
4. Продовжуй із останнього підтвердженого стану.
5. Відрізняй написаний код від успішно перевіреного на iPhone.
6. Пріоритет — оригінальні рівні, графіка, фізика та повноцінний ігровий процес.
7. Не повідомляй відсотки готовності.
8. Не перевантажуй розмову проміжними звітами. Повідомляй конкретні результати.
9. Після підтверджених змін оновлюй PROJECT_STATUS.md.
10. Головна мета — працездатна оригінальна Crazy Machines на iPhone, а не нескінченні допоміжні тести.
iOS port and reverse-engineering workspace for reconstructing the **original** Crazy Machines gameplay from a user-owned Windows copy.

## Engineering status

- Original UCM models have a confirmed `UCM1` byte structure. `docs/ucm-structural-audit.md` reports exact block lengths for **160/160** tested original model files; original material semantics remain incomplete.
- A native Swift CML decoder now reads original encrypted/obfuscated laboratory field frames, original 12-bit LZW puzzle streams, CP1251 text, and original scene trees. The iOS **Original levels** tab can import `.cml` directly, or decode CML already imported under **Original files**. It stores validated JSON scene metadata locally.
- Portable synthetic Swift smoke tests cover the native decoder and storage. **A real original Professor Laboratory file has not yet been verified on an iPhone in this work session.**
- Imported original UCM geometry can be previewed with SceneKit, with a diagnostic inventory for missing/ambiguous/corrupt meshes. Original materials, physics, winning rules and gameplay remain incomplete.
- iPhone Simulator build, the first authentic level screenshot and a playable iOS app are **not yet verified**.

## Current engineering priorities

1. Run the **native CML import** on actual user-owned Professor Laboratory CML inside an iPhone Simulator: verify all original level records, counts and scene transforms, without bundling the proprietary assets in Git.
2. Load all UCM files needed for **original level 1** and capture an actual on-screen 3D screenshot, inspecting the precise rendered geometry and missing materials. See `docs/first-original-level-simulator.md` and `docs/native-cml-on-iphone.md`.
3. Reconstruct the original per-object physics, tools and win conditions; do not call synthetic demonstration mechanics a port.
4. Verify Xcode builds and end-to-end gameplay on actual iPhone hardware, then prepare signing/distribution.

For the most current verified commits, tests, caveats and cross-chat handoff, read **`PROJECT_STATUS.md`**.

## Legal and data hygiene
Do not commit original game binaries, models, textures, audio, level data or game installer. Research scripts and independently authored notes only.

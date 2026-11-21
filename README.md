# Crazy Machines — iOS research
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
Private reverse-engineering workspace for investigating the original Crazy Machines game's proprietary UCM model format and preparing a future iOS implementation.

## Verified status
- The original Windows game and extracted resources are available **outside this repository**.
- UCM model files use a `UCM1` signature; the complete multi-section geometry, UV and materials layout is **not yet decoded**.
- A reference to `FAKT3D_GFX_MODEL` was traced in the Windows executable. The related function at `0x4756F0` is a **candidate** model handler, not a confirmed UCM decoder.
- There is **no playable iOS port** at this time.

## Next engineering work
1. Disassemble the candidate model-handler function and establish its callers and callees.
2. Verify a concrete code path that reads UCM bytes.
3. Build reproducible tests using local game assets; do not commit copyrighted game files.
4. Decode the full model layout and validate against original assets before attempting gameplay reconstruction.

## Legal and data hygiene
Do not commit original game binaries, models, textures, audio, level data or game installer. Research scripts and independently authored notes only.

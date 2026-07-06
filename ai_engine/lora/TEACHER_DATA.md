# Teacher data format

The LoRA data is now Codex-authored first. External teacher rows are optional and should only be used after passing the same project rules.

Each JSONL row can use either `context`/`event` or `prompt`/`response`:

```json
{"kind":"codex_expansion","context":"玩家上下文...","event":"【机缘】短标题\n事件描述。\n选项一\n选项二\n选项三"}
```

All samples are filtered before training:

- exactly 5 non-empty lines
- title starts with `【机缘】` / `【危机】` / `【奇遇】` / `【因果】` / `【传承】`
- description is complete Chinese prose
- options are short action phrases
- no prompt, provider, interface, or development wording
- no early leak of hidden reincarnation jade or ancient authority truth
- no low-realm ownership, equipment, or control of top-tier ancient authorities

Codex-authored samples live in:

- built-in edge cases inside `build_wendao_lora_dataset.py`
- readable long-line samples in `codex_gold_events.json`, `codex_gold_events_final.jsonl`, and any later `codex_gold_events*.jsonl`

The readable gold files are where new major story patterns should go first: multi-life character arcs, temporary NPCs that later become karma, family changes, sect remnants, artifact spirit growth, era-specific pressure, and high-realm authority boundaries. The builder auto-loads all `codex_gold_events*.json` and `codex_gold_events*.jsonl` files.

Training path:

- Primary: `run_remote_gemma4_unsloth.sh`, which builds the filtered dataset and trains the Gemma 4 E4B adapter through Unsloth.
- Default mix: repeat Codex gold heavily, then fill the rest with rule-generated project samples.
- C++ game rules remain final authority for rewards, artifacts, realm gates, relationship progression, and consequences.
- Legacy hand-written HF Trainer scripts were removed to keep the training surface small; add a backup path only if Unsloth fails hard.

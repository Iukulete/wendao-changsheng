# -*- coding: utf-8 -*-
"""Add a short recent-title cooldown to EventManager.

Long Agent runs showed that one title could occupy roughly a quarter of all
adventures. This build-time patch keeps the event pool intact, but prefers
candidates not seen in the last eight selections. It falls back to the original
pool when every eligible candidate is on cooldown, so realm/era gating remains
functional.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_4_EVENT_COOLDOWN"


def replace_once(content: str, old: str, new: str, label: str) -> str:
    if old not in content:
        raise RuntimeError(f"Unable to patch {label}.")
    return content.replace(old, new, 1)


def main() -> int:
    if not SRC.exists():
        raise FileNotFoundError(f"Source file not found: {SRC}")

    content = SRC.read_text(encoding="utf-8")
    if MARKER in content:
        print("v0.4 event cooldown already applied.")
        return 0

    old_private = """class EventManager {
private:
    vector<TaggedEvent> events;

public:
"""
    new_private = """class EventManager {
private:
    vector<TaggedEvent> events;
    vector<wstring> recentEventTitles; // V0_4_EVENT_COOLDOWN

    bool WasEventRecent(const wstring& title) const {
        return find(recentEventTitles.begin(), recentEventTitles.end(), title) != recentEventTitles.end();
    }

    void RememberEvent(const wstring& title) {
        recentEventTitles.push_back(title);
        const size_t cooldownWindow = 8;
        if (recentEventTitles.size() > cooldownWindow) {
            recentEventTitles.erase(recentEventTitles.begin());
        }
    }

    Event* PickCandidateWithCooldown(const vector<int>& candidates) {
        if (candidates.empty()) return nullptr;
        vector<int> fresh;
        for (int index : candidates) {
            if (index < 0 || index >= (int)events.size()) continue;
            if (!WasEventRecent(events[index].event.title)) fresh.push_back(index);
        }
        const vector<int>& pool = fresh.empty() ? candidates : fresh;
        int index = pool[Random(0, (int)pool.size() - 1)];
        RememberEvent(events[index].event.title);
        return &events[index].event;
    }

public:
"""
    content = replace_once(content, old_private, new_private, "EventManager private helpers")

    old_root = """        if (!rootCandidates.empty()) {
            int rootEventIndex = rootCandidates[Random(0, (int)rootCandidates.size() - 1)];
            return &events[rootEventIndex].event;
        }
"""
    new_root = """        if (!rootCandidates.empty()) {
            return PickCandidateWithCooldown(rootCandidates);
        }
"""
    content = replace_once(content, old_root, new_root, "root-balance event selection")

    old_preferred = """        if (!preferred.empty() && Random(1, 100) <= 65) {
            int index = preferred[Random(0, (int)preferred.size() - 1)];
            return &events[index].event;
        }
        if (!fallback.empty()) {
            int index = fallback[Random(0, (int)fallback.size() - 1)];
            return &events[index].event;
        }

        int index = Random(0, (int)events.size() - 1);
        return &events[index].event;
"""
    new_preferred = """        if (!preferred.empty() && Random(1, 100) <= 65) {
            return PickCandidateWithCooldown(preferred);
        }
        if (!fallback.empty()) {
            return PickCandidateWithCooldown(fallback);
        }

        vector<int> allCandidates;
        allCandidates.reserve(events.size());
        for (int i = 0; i < (int)events.size(); ++i) allCandidates.push_back(i);
        return PickCandidateWithCooldown(allCandidates);
"""
    content = replace_once(content, old_preferred, new_preferred, "general event selection")

    SRC.write_text(content, encoding="utf-8")
    print("Applied v0.4 event cooldown: prefer titles outside the last 8 events.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Focused preservation checks; no archived tool or game runtime is imported."""
from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

import verify_source_archive as archive


class EntryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = "godot/data/sample.json"
        self.path = self.root / archive.archive_path(self.original)
        self.path.parent.mkdir(parents=True)
        self.path.write_text('{"id":"stable_one","text":"原文不能丢。"}\n', encoding="utf-8")
        self.entry = self.make_entry()

    def make_entry(self) -> dict:
        return {"original_path": self.original, "archive_path": archive.archive_path(self.original),
                "sha256": archive.sha256(self.path), "bytes": self.path.stat().st_size,
                "role": "narrative_source", "json": archive.identity_summary(archive.read_documents(self.path))}

    def errors(self) -> list[str]:
        return archive.verify_entries(self.root, [self.entry])[0]

    def test_valid_bytes_and_original_text(self) -> None:
        errors, parsed = archive.verify_entries(self.root, [self.entry])
        self.assertEqual(errors, [])
        self.assertEqual(parsed[self.original]["text"], "原文不能丢。")

    def test_changed_authored_text_fails_hash(self) -> None:
        self.path.write_text('{"id":"stable_one","text":"改写"}', encoding="utf-8")
        self.assertTrue(any("byte/hash mismatch" in error for error in self.errors()))

    def test_id_change_fails_even_if_byte_hash_updated(self) -> None:
        self.path.write_text('{"id":"different","text":"原文不能丢。"}', encoding="utf-8")
        self.entry.update(sha256=archive.sha256(self.path), bytes=self.path.stat().st_size)
        self.assertTrue(any("identity fingerprint" in error for error in self.errors()))

    def test_duplicate_json_keys_are_rejected(self) -> None:
        self.path.write_text('{"id":"one","id":"two"}', encoding="utf-8")
        self.assertTrue(any("duplicate JSON key" in error for error in self.errors()))

    def test_missing_archive_is_rejected(self) -> None:
        self.path.unlink()
        self.assertTrue(any("missing or symlinked" in error for error in self.errors()))

    def test_restored_runtime_copy_is_rejected(self) -> None:
        old = self.root / self.original
        old.parent.mkdir(parents=True)
        old.write_bytes(self.path.read_bytes())
        self.assertTrue(any("still on active/old path" in error for error in self.errors()))

    def test_misleading_archive_mapping_is_rejected(self) -> None:
        self.entry["archive_path"] = "archive/source_assets/godot/data/other.json"
        self.assertTrue(any("mapping mismatch" in error for error in self.errors()))

    def test_traversal_is_rejected_before_reading(self) -> None:
        self.entry["archive_path"] = "../outside.json"
        self.assertTrue(any("unsafe relative path" in error for error in self.errors()))

    def test_registry_map_keys_are_part_of_identity_fingerprint(self) -> None:
        first = archive.identity_summary([{"characters": {"old_name": {"text": "same"}}}])
        second = archive.identity_summary([{"characters": {"new_name": {"text": "same"}}}])
        self.assertNotEqual(first, second)

    def test_jsonl_is_parsed_without_executing_any_code(self) -> None:
        path = self.root / "examples.jsonl"
        path.write_text('{"id":"one"}\n\n{"id":"two"}\n', encoding="utf-8")
        self.assertEqual(archive.read_documents(path), [{"id": "one"}, {"id": "two"}])
        path.write_text('{"id":"one"}\nnot json\n', encoding="utf-8")
        with self.assertRaises(ValueError):
            archive.read_documents(path)


class ContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.documents = {
            "godot/data/characters/character_registry_v2.json": {"characters": {"hero": {}}},
            "godot/data/characters/character_groups_v1.json": {"groups": {"crew": {"members": ["hero"]}}},
            "godot/data/characters/character_aliases_v1.json": {"aliases": {"主角": "hero"}, "scoped_aliases": []},
            "godot/data/dialogue/dialogue_index_v1.json": {"scenes": [{"scene_id": "greeting", "path": "res://data/dialogue/greeting.json"}]},
            "godot/data/dialogue/greeting.json": {"scene_id": "greeting", "entry_node": "hello", "participants": ["hero"], "nodes": [
                {"id": "hello", "speaker_id": "hero", "next": "end"}, {"id": "end"}]},
        }

    def test_valid_archived_graph(self) -> None:
        self.assertEqual(archive.verify_content(self.documents), [])

    def test_broken_graph_target_fails(self) -> None:
        self.documents["godot/data/dialogue/greeting.json"]["nodes"][0]["next"] = "missing"
        self.assertTrue(any("broken dialogue target" in error for error in archive.verify_content(self.documents)))

    def test_duplicate_node_id_fails(self) -> None:
        self.documents["godot/data/dialogue/greeting.json"]["nodes"].append({"id": "end"})
        self.assertTrue(any("duplicate/empty dialogue node" in error for error in archive.verify_content(self.documents)))

    def test_unknown_speaker_fails(self) -> None:
        self.documents["godot/data/dialogue/greeting.json"]["nodes"][0]["speaker_id"] = "not_registered"
        self.assertTrue(any("unknown dialogue speaker" in error for error in archive.verify_content(self.documents)))

    def test_unindexed_story_is_not_silently_ignored(self) -> None:
        self.documents["godot/data/dialogue/forgotten.json"] = copy.deepcopy(self.documents["godot/data/dialogue/greeting.json"])
        self.assertIn("dialogue index does not cover all archived scene files", archive.verify_content(self.documents))

    def test_unknown_alias_fails(self) -> None:
        self.documents["godot/data/characters/character_aliases_v1.json"]["aliases"]["主角"] = "missing"
        self.assertTrue(any("alias targets unknown" in error for error in archive.verify_content(self.documents)))



class ExtractedNarrativeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = archive.read_documents(archive.ROOT / archive.MANIFEST)[0]
        self.entry = self.manifest["extracted_documents"][0]
        self.path = self.root / self.entry["path"]
        self.path.parent.mkdir(parents=True)
        self.path.write_bytes((archive.ROOT / self.entry["path"]).read_bytes())

    def rewrite(self, document: dict) -> None:
        self.path.write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")
        self.entry.update(sha256=archive.sha256(self.path), bytes=self.path.stat().st_size,
                          json=archive.identity_summary([document]))

    def test_provenance_is_linked_to_retired_source_hash(self) -> None:
        self.assertEqual(archive.verify_extractions(self.root, self.manifest), [])
        document = archive.read_documents(self.path)[0]
        document["sources"][0]["source_sha256"] = "0" * 64
        self.rewrite(document)
        self.assertTrue(any("provenance mismatch" in error for error in archive.verify_extractions(self.root, self.manifest)))

    def test_extracted_prose_tampering_fails(self) -> None:
        self.path.write_text(self.path.read_text(encoding="utf-8").replace("碑前初光", "已被改写"), encoding="utf-8")
        self.assertTrue(any("byte/hash mismatch" in error for error in archive.verify_extractions(self.root, self.manifest)))

    def test_duplicate_embedded_sample_identity_fails(self) -> None:
        document = archive.read_documents(self.path)[0]
        source = next(source for source in document["sources"] if "gold_samples" in source)
        source["gold_samples"].append(copy.deepcopy(source["gold_samples"][0]))
        self.rewrite(document)
        self.assertTrue(any("sample ID" in error for error in archive.verify_extractions(self.root, self.manifest)))


class CurrentArchiveTests(unittest.TestCase):
    def test_current_archive_is_complete_and_byte_exact(self) -> None:
        self.assertEqual(archive.verify(), [])


if __name__ == "__main__":
    unittest.main()

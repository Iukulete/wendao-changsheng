#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


TITLE_PREFIXES = ("【机缘】", "【危机】", "【奇遇】", "【因果】", "【传承】")
EMOTION_WORDS = (
    "欣慰", "担心", "忧虑", "关切", "嫉妒", "酸涩", "不甘", "轻蔑", "傲慢",
    "护短", "认可", "惊疑", "震惊", "审视", "试探", "恭敬", "欺压", "讥讽",
    "冷眼", "戒备", "敬畏", "贪念", "回避", "押注", "护短",
)
ACTION_BAD_WORDS = ("，", "。", "？", "！", "：", "“", "”", " ")


class CaseScore:
    def __init__(
        self,
        kind,
        title_ok,
        line_count_ok,
        desc_len_ok,
        option_len_ok,
        emotion_ok,
        no_prompt_leak,
        no_foreign_noise,
        description_len,
        lines,
    ):
        self.kind = kind
        self.title_ok = title_ok
        self.line_count_ok = line_count_ok
        self.desc_len_ok = desc_len_ok
        self.option_len_ok = option_len_ok
        self.emotion_ok = emotion_ok
        self.no_prompt_leak = no_prompt_leak
        self.no_foreign_noise = no_foreign_noise
        self.description_len = description_len
        self.lines = lines

    @property
    def passed(self):
        return all([
            self.title_ok,
            self.line_count_ok,
            self.desc_len_ok,
            self.option_len_ok,
            self.emotion_ok,
            self.no_prompt_leak,
            self.no_foreign_noise,
        ])


def split_cases(text):
    blocks = re.split(r"\n(?=PROMPT_KIND:)", text.strip())
    cases = []
    for block in blocks:
        if not block.strip():
            continue
        raw_lines = [line.strip() for line in block.splitlines() if line.strip()]
        if not raw_lines or not raw_lines[0].startswith("PROMPT_KIND:"):
            continue
        kind = raw_lines[0].split(":", 1)[1].strip()
        lines = raw_lines[1:]
        cases.append((kind, lines))
    return cases


def score_case(kind, lines):
    title = lines[0] if lines else ""
    description = lines[1] if len(lines) > 1 else ""
    options = lines[2:5]
    desc_len = len(description)
    option_len_ok = len(options) == 3 and all(
        2 <= len(option) <= 8 and not any(mark in option for mark in ACTION_BAD_WORDS)
        for option in options
    )
    leak_words = ("写作约束", "请严格", "玩家：", "NPC：", "当前世界", "PROMPT_KIND")
    foreign_noise = re.search(
        r"[\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff]|://|[A-Za-z]{3,}",
        "\n".join(lines),
    )
    return CaseScore(
        kind=kind,
        title_ok=title.startswith(TITLE_PREFIXES),
        line_count_ok=len(lines) == 5,
        desc_len_ok=45 <= desc_len <= 90,
        option_len_ok=option_len_ok,
        emotion_ok=any(word in description for word in EMOTION_WORDS),
        no_prompt_leak=not any(word in "\n".join(lines) for word in leak_words),
        no_foreign_noise=foreign_noise is None,
        description_len=desc_len,
        lines=lines,
    )


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+")
    return parser.parse_args()


def main():
    args = parse_args()
    for file_name in args.files:
        path = Path(file_name)
        scores = [
            score_case(kind, lines)
            for kind, lines in split_cases(path.read_text(encoding="utf-8"))
        ]
        passed = sum(score.passed for score in scores)
        print(f"FILE {path}: {passed}/{len(scores)} passed")
        for score in scores:
            flags = []
            for name in [
                "title_ok",
                "line_count_ok",
                "desc_len_ok",
                "option_len_ok",
                "emotion_ok",
                "no_prompt_leak",
                "no_foreign_noise",
            ]:
                if not getattr(score, name):
                    flags.append(name)
            status = "PASS" if score.passed else "FAIL " + ",".join(flags)
            print(f"  {score.kind:14s} {status} desc_len={score.description_len}")


if __name__ == "__main__":
    main()

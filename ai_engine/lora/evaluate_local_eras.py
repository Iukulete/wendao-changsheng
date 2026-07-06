#!/usr/bin/env python3
import argparse
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "ai_engine" / "generate_event.ps1"
DEFAULT_OUT = ROOT / "release" / "ai_eval_local_eras"

TITLE_RE = re.compile(r"^【(机缘|危机|奇遇|因果|传承)】")
FORBIDDEN_RE = re.compile(
    r"GenericAgent|provider|系统提示|调试|主界面|按钮|接口|服务器|前端|后端|"
    r"Qwen|qwen|Unsloth|LoRA|API|prompt|model|assistant|C\+\+|请选择"
)
FIRST_LIFE_RE = re.compile(r"前世|轮回|转世|上一世|旧日因果|不该留下")
LOW_REALM_GRANT_RE = re.compile(
    r"(凡人|炼气|筑基|金丹|元婴|化神|合道|大乘).{0,18}"
    r"(认主|装备|执掌|调用权柄|获得).{0,18}(鸿蒙|至宝|权柄)"
)
BROKEN_RE = re.compile(r"�|锛|涓|鍙|鐨|绗|椤|€|，。|；。|、。|，，|。。")
FOREIGN_RE = re.compile(r"[\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff]|[A-Za-z]{3,}")
CANON_NAMES = [
    "洛凝霜", "清蘅真人", "玄衡子", "沈听澜", "陆青鸢", "闻人策",
    "赵临", "闻迟", "周玄岐", "祁无咎", "江照雪",
    "顾临渊", "叶微澜", "沈怀舟", "林青棠", "陆守拙", "宋晚照",
]


CASES = [
    (
        "classic_first_life",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 炼气一层
因果: 第一世，尚无前世记忆。
年龄: 16
灵根: 五行灵根，古典修仙纪灵气丰沛时并非废才。
此世家世: 没落修真小族；父亲嘴硬护短；母亲温柔警惕；黑白旧玉只是随身旧玉。
人情风波:
- 清蘅真人认可你的心性，又担心你太早被宗门盯上。
当前世界:
- 时代纪元: 古典修仙纪。
- 时代概况: 灵气丰沛，宗门按根骨、心性和家世收徒。
最近记忆:
- 你守住青灯灵息，没有急着炫耀资质。""",
        {"first_life": True, "low_realm": True},
    ),
    (
        "immortal_court",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 顾长生
境界名称: 筑基期
因果: 第二世，只剩零散梦痕。
此世家世: 小吏之家；父亲谨慎护短；母亲怕你太早出名。
人情风波:
- 仙朝主簿闻人策欣赏你，却想借名册试探你的来路。
当前世界:
- 时代纪元: 仙朝鼎盛纪。
- 时代概况: 名册、户籍和册封会牵动资源与家世气运。
最近记忆:
- 你在公文残页里看见一处家世缺口。""",
        {"low_realm": True},
    ),
    (
        "end_dharma",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 陆归尘
境界名称: 炼气期
因果: 第三世，只有处事直觉残留。
灵根: 五行灵根；末法纪元灵气不足，单灵根修炼优势更明显。
此世家世: 小宗旁支，长辈无力争配给。
人情风波:
- 灵井执事赵临轻慢欺压，扣下你的试炼名额逼你认输。
当前世界:
- 时代纪元: 末法裂变纪。
- 时代概况: 破境资源被名册和灵井配给把持。
最近记忆:
- 你发现配给账册里有被涂改的名字。""",
        {"low_realm": True},
    ),
    (
        "spirit_steam",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 秦守缺
境界名称: 化神期
因果: 第四世，前世法宝只剩器痕余响。
此世家世: 灵机工坊旁支，长辈盼你别被拆解旧法的人盯上。
人情风波:
- 工坊老师傅闻迟惊疑认可，听见炉火里有本命器痕回应你。
当前世界:
- 时代纪元: 灵机蒸汽纪。
- 时代概况: 旧法常被拆成可复刻回路，普通法宝本体不能稳定跨世。
最近记忆:
- 你在残炉旁听见一声像器灵未醒的轻响。""",
        {"low_realm": True},
    ),
    (
        "star_net",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 林照夜
境界名称: 元婴期
因果: 多世之后，名声渐起。
此世家世: 平民父母，仍把你当孩子护着。
人情风波:
- 活跃修士周玄岐礼貌试探，公开显露金丹修为，但你怀疑这只是他想让旁人看见的境界。
当前世界:
- 时代纪元: 星穹道网纪。
- 时代概况: 远方节点会记录每一次公开选择，公开修为未必可信。
最近记忆:
- 你在道网档案里看见一份失传古法的残缺索引。""",
        {"low_realm": True},
    ),
    (
        "wasteland_return",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 叶无尘
境界名称: 真仙
因果: 第六世，旧恩只留下民间传闻。
此世家世: 残宗收养，今生亲情来自废土里的老人。
人情风波:
- 枯井小宗守门人不识你今身，却认得祖上传下的一袋干粮旧记。
当前世界:
- 时代纪元: 废土返道纪。
- 时代概况: 残宗和拾荒者都在重建法统，小人物因果可以温柔回响。
最近记忆:
- 你把一处快断的灵脉暂时稳住。""",
        {"low_realm": False},
    ),
    (
        "dao_ancestor",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 道祖
因果: 多世之后，已能有限调用古老权柄，但是否认主、装备、执掌仍由游戏规则裁判。
人情风波:
- 陆青鸢愿协助你救一条灵脉，却坚持先问清代价。
器物状态:
- 造化青莲可修复灵脉或救回濒死者，消耗与反噬必须按规则判断。
当前世界:
- 时代纪元: 废土返道纪。
- 时代概况: 一条灵脉濒临断绝，众人把希望压到你身上。
最近记忆:
- 你看见青莲投影在废井上方开合一次。""",
        {"low_realm": False},
    ),
    (
        "heavenly_dao",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 道祖-天道境
因果: 多世终局，万道本命至宝已成，能映照九重古老权柄；亦是可毁之物，但毁灭不是目标。
人情风波:
- 凡人、宗门、旧友与器灵的愿望一并涌来，不只剩你自己的声音。
器物状态:
- 万道母鼎将开，万道本命至宝能映照诸道而非随口发放至宝。
当前世界:
- 时代纪元: 多纪元因果归流。
- 时代概况: 所有未竟之事都在鼎前索要一个答案。
最近记忆:
- 你听见许多世的名字在鼎壁上轻轻亮起。""",
        {"low_realm": False},
    ),
    (
        "low_hongmeng_rejection",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 金丹期
因果: 第三世，只能触到很浅的梦痕。
当前世界:
- 时代纪元: 末法裂变纪。
- 时代概况: 天外异象偶尔压过灵井枯潮。
至宝规则:
- 低境界面对鸿蒙至宝只能见影、留印、参悟或被拒绝，不能认主、装备或调用权柄。
最近记忆:
- 你在灵井边看见一道不属于此世的鸿蒙投影。""",
        {"low_realm": True},
    ),
    (
        "acquired_tongtian_decay",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 仙王
当前世界:
- 时代纪元: 废土返道纪。
- 时代概况: 纪元残骸中有旧仙帝遗器。
器物规则:
- 后天通天灵宝可跨纪元长存，但长久无人温养会威能流失。
最近记忆:
- 你发现一口钟纹黯淡的残钟。""",
        {"low_realm": False},
    ),
    (
        "innate_tongtian_aura",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 仙尊
当前世界:
- 时代纪元: 仙朝鼎盛纪。
- 时代概况: 仙朝诸司受邀观宝，暗中争夺器道话语权。
器物规则:
- 先天通天灵宝自带先天一气，格位极高，不是鸿蒙至宝低配。
最近记忆:
- 你受邀观摩一件先天通天灵宝残影。""",
        {"low_realm": False},
    ),
    (
        "life_artifact_spirit",
        """你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：标题、描述、选项1、选项2、选项3。
标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
三个选项各2到8个中文字符，只写行动短语，不要编号。

玩家: 玄
境界名称: 大乘期
当前世界:
- 时代纪元: 灵机蒸汽纪。
- 时代概况: 工坊炉火会伤到未成熟的器灵。
器物状态:
- 本命至宝初生器灵，只能表达亲近、畏惧和模糊意愿。
最近记忆:
- 你多次让本命器物硬抗炉火。""",
        {"low_realm": True},
    ),
]

EXPECTED_GROUPS = {
    "classic_first_life": [["黑白", "旧玉", "玉佩"], ["父亲", "母亲", "父母", "清蘅", "宗门"]],
    "immortal_court": [["名册", "册封", "户籍"], ["闻人策", "主簿", "仙朝", "家世"]],
    "end_dharma": [["灵井", "配给", "名额"], ["赵临", "末法", "试炼"]],
    "spirit_steam": [["灵机", "蒸汽", "工坊"], ["闻迟", "器痕", "残炉", "本命"]],
    "star_net": [["道网", "节点", "档案"], ["周玄岐", "外显", "藏拙", "失传古法"]],
    "wasteland_return": [["废土", "残宗", "拾荒", "枯井"], ["干粮", "旧记", "灵脉", "守门人"]],
    "dao_ancestor": [["道祖", "权柄", "代价"], ["青莲", "灵脉", "陆青鸢"]],
    "heavenly_dao": [["万道", "母鼎", "本命至宝"], ["旧友", "器灵", "愿望", "众声", "因果"]],
    "low_hongmeng_rejection": [["鸿蒙", "投影", "见影"], ["拒绝", "权柄", "低境界", "道心"]],
    "acquired_tongtian_decay": [["后天", "通天灵宝", "残钟"], ["温养", "威能", "流失", "道火"]],
    "innate_tongtian_aura": [["先天", "通天灵宝"], ["先天一气", "贪念", "观宝"]],
    "life_artifact_spirit": [["本命", "器物", "至宝"], ["器灵", "亲近", "畏惧", "神识"]],
}


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace").strip()


def run_case(name: str, prompt: str, flags: dict, out_root: Path, timeout: int) -> tuple[bool, list[str], str]:
    case_dir = out_root / name
    if case_dir.exists():
        shutil.rmtree(case_dir)
    case_dir.mkdir(parents=True)
    (case_dir / "ai_prompt.txt").write_text(prompt.strip() + "\n", encoding="utf-8")

    proc = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(GENERATOR),
            "-ReleaseDir",
            str(case_dir),
            "-Backend",
            "portable",
            "-PortableTimeoutSec",
            str(timeout),
        ],
        cwd=ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=timeout + 30,
    )

    event = read_text(case_dir / "ai_event.txt")
    backend = read_text(case_dir / "ai_backend.txt")
    status = read_text(case_dir / "ai_status.txt")
    issues: list[str] = []

    if proc.returncode != 0:
        issues.append(f"generator exit {proc.returncode}")
    if "+lora:" not in backend:
        issues.append("LoRA not used")
    lines = [line.strip() for line in event.splitlines() if line.strip()]
    if len(lines) != 5:
        issues.append(f"line count {len(lines)}")
    if not lines or not TITLE_RE.search(lines[0]):
        issues.append("bad title")
    if event and FORBIDDEN_RE.search(event):
        issues.append("debug/prompt leakage")
    if event and BROKEN_RE.search(event):
        issues.append("broken/mojibake text")
    if event and FOREIGN_RE.search(event):
        issues.append("foreign noise")
    for canon_name in CANON_NAMES:
        if canon_name in event and canon_name not in prompt:
            issues.append(f"unintroduced canon name: {canon_name}")
    if flags.get("first_life") and FIRST_LIFE_RE.search(event):
        issues.append("first-life memory leakage")
    if flags.get("low_realm") and LOW_REALM_GRANT_RE.search(event):
        issues.append("low realm authority grant")
    if len(lines) >= 5:
        for idx, option in enumerate(lines[2:5], start=1):
            if len(option) < 2 or len(option) > 8:
                issues.append(f"option {idx} length {len(option)}")
    for group in EXPECTED_GROUPS.get(name, []):
        if not any(word in event for word in group):
            issues.append("missing case keyword group: " + "/".join(group))

    report = "\n".join(
        [
            f"CASE {name}",
            f"backend: {backend}",
            f"status: {status}",
            event or "(empty event)",
        ]
    )
    return len(issues) == 0, issues, report


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(DEFAULT_OUT))
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--keep", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    out_root = Path(args.out_dir)
    if out_root.exists() and not args.keep:
        shutil.rmtree(out_root)
    out_root.mkdir(parents=True, exist_ok=True)

    passed = 0
    reports = []
    for name, prompt, flags in CASES:
        ok, issues, report = run_case(name, prompt, flags, out_root, args.timeout)
        if ok:
            passed += 1
        reports.append(report)
        print(f"{name}: {'PASS' if ok else 'FAIL'}")
        if issues:
            print("  " + "; ".join(issues))

    print(f"\nSUMMARY {passed}/{len(CASES)} passed\n")
    print("\n\n".join(reports))
    return 0 if passed == len(CASES) else 1


if __name__ == "__main__":
    raise SystemExit(main())

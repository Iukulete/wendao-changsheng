#!/usr/bin/env python3
import argparse
import json
import random
from pathlib import Path


REALMS = ["炼气期", "筑基期", "金丹期", "元婴期", "化神期", "仙帝"]
ERAS = [
    ("仙朝鼎盛纪", "仙朝名册在旁，家世与气运都被写成筹码。"),
    ("星穹道网纪", "远方节点会记录每一次公开选择。"),
    ("灵机蒸汽纪", "灵机工坊想把旧法拆成可复刻回路。"),
    ("末法裂变纪", "灵井枯潮逼近，破境资源被配给名册把持。"),
    ("废土返道纪", "残宗和拾荒者都在废墟里重建法统。"),
]
FAMILIES = [
    "没落修真世家；父亲沈怀舟；母亲林青棠；伴生玉佩: 黑白旧玉未显真名",
    "隐秘血脉；父母身份被隐去；养育者: 外门执事；伴生玉佩: 黑白相间旧玉",
    "孤儿；养育者: 残宗向导；伴生玉佩: 梦中玉意偶尔发温",
    "古族旁支；父亲沉默担忧；母亲护短期许；伴生玉佩: 黑白旧玉",
]
NPC_LINES = [
    (
        "父亲",
        "护短期许",
        "父亲低声道「你这份根骨可以骄傲，但不能被旁人一句夸就牵着走。」",
        32,
    ),
    (
        "竞争者",
        "酸意较劲",
        "同代修士冷笑道「资质好又怎样，谁知道你家世里藏着什么债？」",
        -34,
    ),
    (
        "欺压者",
        "轻慢挑衅",
        "外门恶少嗤笑道「测灵碑都替你把话说完了，还想跟我们争名额？」",
        -42,
    ),
    (
        "资源把关者",
        "冷脸卡资源",
        "配给执事合上名册道「灵井不是给热血少年的，拿得出筹码再谈破境。」",
        -18,
    ),
    (
        "旧名追债人",
        "旧怨追问",
        "查账人盯着旧册道「别急着装无辜，有些旧债换了皮囊也会认人。」",
        -32,
    ),
    (
        "功法见证者",
        "惊疑认可",
        "藏经长老压低声音道「这一式别在外头乱用，懂行的人会认出失传古法的骨头。」",
        22,
    ),
    (
        "器痕识别者",
        "压声提醒",
        "器阁执事道「你没有前世法宝本体，可器痕的响声瞒不过我。」",
        12,
    ),
    (
        "旧名仰慕者",
        "仰慕押注",
        "递帖人拱手道「我敬的是你今生这一眼，也盼你配得上旧名留下的光。」",
        28,
    ),
]


def prompt_for(case):
    npc_role, emotion, utterance, relation = case["npc"]
    era, era_rule = case["era"]
    return f"""你是修仙 Roguelike 的事件叙事模型。
请基于玩家上下文生成一个原创事件，严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束:
- 标题必须以【机缘】、【危机】、【奇遇】、【因果】、【传承】之一开头。
- 描述45到90个中文字符，要贴合境界、家世、人情风波、最近记忆和当前世界。
- NPC 要有情绪和立场，但不要无意义骂街。
- 三个选项各2到8个中文字符，只写行动短语。

玩家: 问道者
境界名称: {case["realm"]}
因果: {case["karma"]}
此世家世: {case["family"]}
人情风波:
- {case["npc_name"]}（{npc_role}） · 情绪{emotion} · 关系{relation:+d}: {case["hook"]} NPC情绪代理口吻{utterance}
轮回传承:
{case["legacy"]}
当前世界:
- 时代纪元: {era}
- 时代法则: {era_rule}
- 本世主线: {case["story"]}
最近记忆:
- {case["memory"]}"""


def response_for(case):
    kind = case["kind"]
    npc_role, emotion, utterance, relation = case["npc"]
    npc_name = case["npc_name"]
    era, _ = case["era"]

    if kind == "talent_praise":
        return "\n".join([
            "【因果】长辈护短",
            f"{npc_name}听见族中酸话后没有发怒，只把你叫到廊下，当面夸你根骨好，却提醒你别被人捧着走。",
            "低头受教",
            "追问旧因",
            "暂避锋芒",
        ])
    if kind == "envy":
        return "\n".join([
            "【危机】同门酸语",
            f"{npc_name}表面祝贺你入门，话里却句句带刺，旁人也等着看你这份资质会不会先惹来祸事。",
            "当众回应",
            "暗查底细",
            "不与计较",
        ])
    if kind == "bully":
        return "\n".join([
            "【危机】试炼名额",
            f"{npc_name}故意扣下你的试炼名额，笑你根基太薄；可黑白旧玉微微发温，像在替你压住怒意。",
            "据理争名",
            "暂忍记账",
            "请长辈证",
        ])
    if kind == "lost_tech":
        return "\n".join([
            "【传承】失传古法",
            f"{npc_name}认出你起手式里的旧法骨相，立刻压低声音；在{era}，这门古法会牵动许多双眼。",
            "压下旧法",
            "请教长老",
            "借势入局",
        ])
    if kind == "jade_family":
        return "\n".join([
            "【因果】玉痕旧名",
            f"{npc_name}核验名册时，你胸前黑白玉佩忽然发温，养育者避开目光，像仍在替父母守着旧名。",
            "追问旧名",
            "握玉静听",
            "暂避册封",
        ])
    if kind == "artifact":
        return "\n".join([
            "【传承】器痕余响",
            f"{npc_name}听见你神魂边缘的器痕，提醒你前世法宝本体不能跨世，只剩认主余响可入今生。",
            "询问器痕",
            "封存余响",
            "转身离阁",
        ])
    if kind == "lifespan":
        return "\n".join([
            "【危机】灵井寿限",
            f"{npc_name}扣住破境配给，冷声要你拿筹码；你虽已近仙帝之路，仍听见寿元在石门外逼近。",
            "争取配给",
            "闭关压寿",
            "问道祖路",
        ])
    if kind == "old_debt":
        return "\n".join([
            "【因果】旧债认人",
            f"{npc_name}把旧册摊在灯下，话里全是试探；他不敢确认你前世是谁，却已经把你当成债主影子。",
            "稳住今生",
            "反查旧册",
            "断开牵连",
        ])
    return "\n".join([
        "【奇遇】道途回声",
        f"{npc_name}没有立刻表态，只用{emotion}的眼神看你，像要确认你到底是今生少年还是旧梦归来。",
        "顺势结交",
        "试探虚实",
        "保持距离",
    ])


def build_case(rng, kind):
    npc = rng.choice(NPC_LINES)
    era = rng.choice(ERAS)
    realm = rng.choice(REALMS)
    family = rng.choice(FAMILIES)
    npc_name = rng.choice(["沈听澜", "陆怀璧", "顾灰路", "叶执圭", "林星回", "秦守缺"])
    legacy_by_kind = {
        "lost_tech": "当前继承的传承: 前世遗响·青灯登仙经。失传古法当世解读: 旧法会被当代制度重新解释。",
        "artifact": "当前继承的传承: 前世遗响·本命法宝器痕。普通法宝本体不能跨世。",
        "old_debt": "前世未竟因果: 上一世欠下一段宗门旧债，今生有人循名而来。",
        "jade_family": "轮回余烬: 前世残响尚浅。隐藏设定: 主角不知道伴生玉佩真相。",
        "lifespan": "寿元压力: 仙帝仍会寿尽，若不能证成道祖，时间正在逼近。",
    }
    return {
        "kind": kind,
        "npc": npc,
        "era": era,
        "realm": realm,
        "karma": rng.choice([-45, -20, 5, 35, 80]),
        "family": family,
        "npc_name": npc_name,
        "hook": rng.choice([
            "对方刚听见你的测灵结果，态度立刻变得复杂。",
            "对方怀疑你记得不该记得的前世细节。",
            "对方掌着一次试炼或配给名额。",
            "对方想借你的旧名、家世或资质下注。",
        ]),
        "legacy": legacy_by_kind.get(kind, "轮回余烬: 黑白旧玉在梦醒时微温，留下几段不完整记忆。"),
        "story": rng.choice([
            "本世人脉开始围绕你的资质与旧梦发酵。",
            "远方势力正在观察你每一次公开选择。",
            "家世隐情和前世残响同时压到眼前。",
            "旧时代遗留的制度正在改写今生去路。",
        ]),
        "memory": rng.choice([
            "前世忆起: 上一世死于雷劫，仍记得半段行功脉络。",
            "人情余波: 有人夸你，也有人开始酸你。",
            "伴生玉佩: 黑白旧玉在梦里微温。",
            "天下大事: 灵井枯潮让破境资源变得昂贵。",
        ]),
    }


def write_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="data")
    parser.add_argument("--train-count", type=int, default=1200)
    parser.add_argument("--eval-count", type=int, default=120)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    kinds = [
        "talent_praise", "envy", "bully", "lost_tech", "jade_family",
        "artifact", "lifespan", "old_debt", "neutral",
    ]

    rows = []
    for i in range(args.train_count + args.eval_count):
        kind = kinds[i % len(kinds)]
        case = build_case(rng, kind)
        rows.append({"prompt": prompt_for(case), "response": response_for(case), "kind": kind})
    rng.shuffle(rows)

    out_dir = Path(args.out_dir)
    write_jsonl(out_dir / "train.jsonl", rows[: args.train_count])
    write_jsonl(out_dir / "eval.jsonl", rows[args.train_count :])
    print(f"wrote {args.train_count} train and {args.eval_count} eval samples to {out_dir}")


if __name__ == "__main__":
    main()

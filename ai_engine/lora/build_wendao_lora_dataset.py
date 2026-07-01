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
    (
        "活跃修士",
        "礼貌试探",
        "活跃修士含笑递帖道「我只显这点修为，是怕旁人误会；至于真底细，要看你值不值得问。」",
        8,
    ),
]


def pick_npc_for_kind(rng, kind):
    roles_by_kind = {
        "talent_praise": {"父亲", "旧名仰慕者"},
        "envy": {"竞争者"},
        "bully": {"欺压者", "资源把关者"},
        "lost_tech": {"功法见证者"},
        "jade_family": {"父亲", "旧名仰慕者"},
        "artifact": {"器痕识别者"},
        "lifespan": {"资源把关者"},
        "old_debt": {"旧名追债人"},
        "hidden_realm": {"活跃修士"},
    }
    roles = roles_by_kind.get(kind)
    pool = [npc for npc in NPC_LINES if not roles or npc[0] in roles]
    return rng.choice(pool or NPC_LINES)


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


def stable_pick(items, key):
    return items[sum(ord(ch) for ch in key) % len(items)]


def polish_description(case, description):
    kind = case["kind"]
    key = f"{kind}|{case['npc_name']}|{case['karma']}|{case['memory']}"
    tails = {
        "talent_praise": [
            "；那份担心也把旁人的嫉妒挡在门外。",
            "；这句夸赞不重，却让暗处酸意更难开口。",
        ],
        "envy": [
            "；酸涩与不甘在旁人笑声里越发明显。",
            "；那点嫉妒没有明说，却已经开始找你的破绽。",
        ],
        "bully": [
            "；轻慢欺压逼得旁人也开始衡量你的底气。",
            "；他的冷眼像一把尺，专量你敢不敢反抗。",
        ],
        "lost_tech": [
            "；惊疑认可压在他眼底，像怕旧法再惹风波。",
            "；懂行者的担心很轻，却足以让整座经阁安静下来。",
        ],
        "jade_family": [
            "；那点担心让父母旧名更像被人刻意藏起。",
            "；回避和护短同时浮现，像有人仍替你守着门。",
        ],
        "artifact": [
            "；惊疑和贪念同时浮起，懂器者已经开始留心。",
            "；这份认可带着戒备，像怕器痕引来外人争夺。",
        ],
        "lifespan": [
            "；冷眼背后也藏着试探，像要逼你先低头。",
            "；寿限的忧虑压在话尾，连沉默都像催命声。",
        ],
        "old_debt": [
            "；试探与戒备一并压来，旧怨还没有真正开口。",
            "；敬畏和旧恨搅在一起，让这场寒暄像审问。",
        ],
        "hidden_realm": [
            "；礼貌试探浮在笑里，真正灵压仍被他压住。",
            "；这份从容带着戒备，像故意只给你看半层门槛。",
        ],
    }
    if len(description) >= 50:
        return description
    tail = stable_pick(tails.get(kind, ["；试探和押注都未明说，却已在人群里散开。"]), key)
    base = description.rstrip("。")
    polished = base + tail
    return polished if len(polished) <= 90 else description


def response_for(case):
    kind = case["kind"]
    npc_role, emotion, utterance, relation = case["npc"]
    npc_name = case["npc_name"]
    era, _ = case["era"]
    key = f"{kind}|{npc_name}|{emotion}|{case['realm']}|{case['karma']}"

    templates = {
        "talent_praise": (
            ["【因果】长辈护短", "【机缘】廊下赞骨", "【奇遇】护短一语"],
            [
                f"{npc_name}先压下族中酸话，又当面夸你根骨清亮；{emotion}藏在话尾，提醒你莫被热眼捧坏道心。",
                f"{npc_name}听完测灵结果后故作平静，却把旁人挡在廊外；他夸你天资难得，也担心你太早被人押注。",
                f"{npc_name}没有急着报喜，只低声替你挡住试探；那句认可像一盏灯，也照出暗处几道嫉妒目光。",
            ],
            ["低头受教", "追问旧因", "暂避锋芒"],
        ),
        "envy": (
            ["【危机】同门酸语", "【因果】暗刺入耳", "【危机】贺声带刺"],
            [
                f"{npc_name}表面向你道贺，袖中名册却被攥出折痕；{emotion}让他句句带刺，想看你先惹来谁的忌惮。",
                f"{npc_name}笑着称你前途无量，眼底却压着不甘；他不敢明抢机缘，只把怀疑与酸意塞进每一句话。",
                f"{npc_name}在人前夸你资质出众，人后却散出轻慢传言；那点嫉妒像细针，专挑你家世隐处下手。",
            ],
            ["当众回应", "暗查底细", "不与计较"],
        ),
        "bully": (
            ["【危机】试炼名额", "【危机】外门欺压", "【因果】名额被扣"],
            [
                f"{npc_name}故意扣下你的试炼名额，笑你根基太薄；轻慢声里，黑白旧玉微微发温，替你压住怒意。",
                f"{npc_name}把名册往袖里一收，逼你当众认低；旁人等着看笑话，只有旧玉在胸口一阵发烫。",
                f"{npc_name}借规矩卡住资源，话里全是欺压；你若退一步，今后的试炼名额都会被人拿来试胆。",
            ],
            ["据理争名", "暂忍记账", "请长辈证"],
        ),
        "lost_tech": (
            ["【传承】失传古法", "【机缘】古法露骨", "【因果】旧式惊人"],
            [
                f"{npc_name}认出你起手式里的旧法骨相，立刻压低声音；在{era}，这点传承足够牵动许多双眼。",
                f"{npc_name}盯着你的行功脉络，惊疑里又带认可；他提醒你别乱显旧式，否则懂行者会循味而来。",
                f"{npc_name}只看一眼便合上经卷，像怕旁人听见；失传古法不是招牌，是能把你推上风口的火种。",
            ],
            ["压下旧法", "请教长老", "借势入局"],
        ),
        "jade_family": (
            ["【因果】玉痕旧名", "【奇遇】旧玉微温", "【传承】黑白玉痕"],
            [
                f"{npc_name}核验名册时，你胸前黑白旧玉忽然发温；养育者避开目光，像仍在替父母守着旧名。",
                f"{npc_name}提到你家世时忽然收声，黑白玉佩随之发热；那点回避不像无情，更像有人替你藏命。",
                f"{npc_name}看见玉痕后神色一变，连称呼都放轻了些；你仍不知此物真名，只觉父母旧影近在眼前。",
            ],
            ["追问旧名", "握玉静听", "暂避册封"],
        ),
        "artifact": (
            ["【传承】器痕余响", "【机缘】本命余音", "【因果】旧宝不渡"],
            [
                f"{npc_name}听见你神魂边缘的器痕，语气忽然郑重；前世法宝本体不能跨世，只剩认主余响可入今生。",
                f"{npc_name}按住炉火，提醒你别把器痕当成法宝本体；那只是前世余响，却足以唤来懂器人的贪念。",
                f"{npc_name}从残响里听出旧宝气息，惊疑又克制；普通灵宝会朽，只有被你记住的器意还肯回头。",
            ],
            ["询问器痕", "封存余响", "转身离阁"],
        ),
        "lifespan": (
            ["【危机】灵井寿限", "【因果】寿元逼近", "【危机】配给冷眼"],
            [
                f"{npc_name}扣住破境配给，冷声要你拿筹码；你虽望见仙帝旧路，仍听见寿元在石门外一步步逼近。",
                f"{npc_name}把灵井名额划给旁人，眼神冷得像账册；若不争这一口资源，今生又会被寿限逼到墙角。",
                f"{npc_name}提醒你仙帝也有尽头，话不重却刺骨；若不能问到道祖之路，再多前世记忆也会被岁月磨平。",
            ],
            ["争取配给", "闭关压寿", "问道祖路"],
        ),
        "old_debt": (
            ["【因果】旧债认人", "【危机】灯下旧册", "【因果】债影回身"],
            [
                f"{npc_name}把旧册摊在灯下，话里全是试探；他不敢确认你前世是谁，却已把你当成债主影子。",
                f"{npc_name}盯着你写下的道号，旧怨在眼底翻涌；他敬的是前世余威，也怕今生的你追账上门。",
                f"{npc_name}借寒暄翻出一段旧债，笑意里藏着戒备；你若认下因果，今生第一步便会踏进旧局。",
            ],
            ["稳住今生", "反查旧册", "断开牵连"],
        ),
        "hidden_realm": (
            ["【奇遇】显境有假", "【因果】藏锋试探", "【危机】金丹虚影"],
            [
                f"{npc_name}在人前只显出一层金丹光影，语气却过分从容；{emotion}像薄雾，遮住他真正的修为深浅。",
                f"{npc_name}笑着递来拜帖，外露境界恰到好处；你从他收放灵压的缝隙里，嗅到一丝刻意藏锋。",
                f"{npc_name}故意让众人看见金丹虚影，却在看你时收住半分气机；这不是示弱，是试探你能看透几层。",
            ],
            ["顺势寒暄", "暗观灵压", "暂不交底"],
        ),
    }

    titles, descriptions, options = templates.get(kind, (
        ["【奇遇】道途回声", "【因果】人情暗涌", "【机缘】旧梦照面"],
        [
            f"{npc_name}没有立刻表态，只用{emotion}的眼神看你；他想确认你是今生少年，还是旧梦归来的故人。",
            f"{npc_name}把话说得很轻，立场却并不含糊；人情风波绕到你身前，连沉默都像一次押注。",
            f"{npc_name}看见你时神色微变，像把旧名与今生重叠；这份试探不重，却足够让旁人重新衡量你。",
        ],
        ["顺势结交", "试探虚实", "保持距离"],
    ))

    title = stable_pick(titles, key)
    description = polish_description(case, stable_pick(descriptions, key + "|desc"))
    return "\n".join([title, description, *options])


def build_case(rng, kind):
    npc = pick_npc_for_kind(rng, kind)
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
        "artifact", "lifespan", "old_debt", "hidden_realm", "neutral",
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

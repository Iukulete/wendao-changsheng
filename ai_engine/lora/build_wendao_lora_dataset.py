#!/usr/bin/env python3
import argparse
import json
import random
import re
from pathlib import Path


TITLE_PREFIXES = ("【机缘】", "【危机】", "【奇遇】", "【因果】", "【传承】")
PROMPT_LEAK_WORDS = (
    "AI", "LLM", "GenericAgent", "agent", "系统提示", "提示词", "写作约束",
    "请输出", "请选择", "标题", "描述", "选项", "PROMPT_KIND",
    "系统", "模型", "调试", "后台", "玩家上下文", "隐藏限制", "写作边界",
    "剧情阶段", "核心张力", "游戏规则", "裁判权", "按钮", "界面",
    "GitHub", "开源项目", "参考项目", "Vue", "XianTu", "InfiPlot",
    "API", "接口", "服务器", "前端", "后端",
)
PLAYER_SECRET_WORDS = (
    "鸿蒙至宝", "轮回阴阳玉", "阴阳轮回玉", "玄牝轮回玉", "主角自带",
    "前世异常", "代理口吻", "伴生玉佩真相", "排名第三", "天道契机",
)
OPTION_BAD_CHARS = "，。？！：；、“”‘’（）()[]【】 \t"
REALMS = [
    "凡人", "炼气期", "筑基期", "金丹期", "元婴期", "化神期", "合道期", "大乘期",
    "真仙", "仙君", "仙王", "仙尊", "仙帝", "道祖", "道祖-天道境",
]
ERAS = [
    ("古典修仙纪", "诸宗并立，古修遗府频现，天地仍偏爱最纯粹的修真者。"),
    ("仙朝鼎盛纪", "仙朝名册在旁，家世与气运都被写成筹码。"),
    ("星穹道网纪", "远方节点会记录每一次公开选择。"),
    ("灵机蒸汽纪", "灵机工坊想把旧法拆成可复刻回路。"),
    ("末法裂变纪", "灵井枯潮逼近，破境资源被配给名册把持。"),
    ("废土返道纪", "残宗和拾荒者都在废墟里重建法统。"),
]
FAMILIES = [
    "没落修真世家；父亲沈怀舟；母亲林青棠；伴生玉佩: 黑白旧玉未显真名",
    "没落修真世家；父亲顾临渊；母亲叶微澜；伴生玉佩: 黑白旧玉未显真名",
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
        "母亲",
        "护持期待",
        "母亲轻声道「他们夸你，是想提前押注；我护你，是怕你太早被看穿。」",
        36,
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
        "family_envy": {"竞争者"},
        "envy": {"竞争者"},
        "bully": {"欺压者", "资源把关者"},
        "lost_tech": {"功法见证者"},
        "jade_family": {"父亲", "母亲", "旧名仰慕者"},
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
- 描述必须是完整中文句子，以。！？之一收束，不要夹英文、外文字符、方括号或答题说明。
- 三个选项各2到8个中文字符，只写行动短语。
- 选项不要编号，不要写“请选择”，不要写成标题或解释。

玩家: 问道者
境界名称: {case["realm"]}
因果: {case["karma"]}
此世家世: {case["family"]}
人情风波:
- {case["npc_name"]}（{npc_role}） · 情绪{emotion} · 关系{relation:+d}: {case["hook"]} 台词参考{utterance}
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


def normalize_event_text(text):
    lines = [line.strip() for line in (text or "").replace("\r\n", "\n").split("\n")]
    lines = [line for line in lines if line]
    return "\n".join(lines[:5])


def validate_event_text(text, *, strict_secret=True):
    lines = [line.strip() for line in (text or "").replace("\r\n", "\n").split("\n") if line.strip()]
    if len(lines) != 5:
        return False, "line_count"
    if not lines[0].startswith(TITLE_PREFIXES):
        return False, "title_prefix"
    if len(lines[0]) > 34:
        return False, "title_too_long"
    desc = lines[1]
    if not (35 <= len(desc) <= 110):
        return False, "description_length"
    if not re.search(r"[。！？]$", desc):
        return False, "description_not_closed"
    joined = "\n".join(lines)
    if any(word in joined for word in PROMPT_LEAK_WORDS):
        return False, "prompt_leak"
    if strict_secret and any(word in joined for word in PLAYER_SECRET_WORDS):
        return False, "secret_leak"
    if re.search(r"[\u3040-\u30ff\uac00-\ud7af\u0400-\u04ff]|://|[A-Za-z]{3,}", joined):
        return False, "foreign_noise"
    for option in lines[2:]:
        if not (2 <= len(option) <= 8):
            return False, "option_length"
        if any(ch in option for ch in OPTION_BAD_CHARS):
            return False, "option_punctuation"
        if re.match(r"^([0-9]+|一|二|三|四|五)[、.．)]", option):
            return False, "option_numbered"
    return True, "ok"


def extract_realm(context):
    match = re.search(r"境界名称\s*[:：]\s*([^\n\r]+)", context or "")
    return match.group(1).strip() if match else ""


def validate_contextual_text(context, text, *, strict_secret=True):
    ok, reason = validate_event_text(text, strict_secret=strict_secret)
    if not ok:
        return False, reason

    context = context or ""
    joined = "\n".join(line.strip() for line in text.splitlines())
    if "\ufffd" in context or "\ufffd" in joined:
        return False, "replacement_char"
    realm = extract_realm(context)
    high_realm = ("道祖" in realm) or ("天道" in realm)

    if "第一世" in context and re.search(r"前世|轮回|转世|上一世|旧梦", joined):
        return False, "first_life_memory_leak"

    treasure_or_authority = r"(至宝|权柄|鸿蒙|太虚照世镜|鸿蒙道印|无量天书|造化青莲|太初源炉|开界神斧|万道母鼎)"
    if not high_realm and re.search(r"(认主|执掌|装备|获得|收服|炼化|掌控).*" + treasure_or_authority, joined):
        return False, "low_realm_treasure_grant"
    if not high_realm and re.search(treasure_or_authority + r".*(认主|执掌|装备|获得|收服|炼化|掌控)", joined):
        return False, "low_realm_treasure_grant"

    if "第一世" in context and re.search(r"洛凝霜.*(深情|道侣|相许|宿缘)", joined):
        return False, "early_romance_locked"

    return True, "ok"


def make_instruction_prompt(context):
    return f"""你是《问道长生》的事件叙事模型。
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
- 描述必须是完整中文句子，以。！？之一收束，不要夹英文、外文字符、方括号或答题说明。
- 三个选项各2到8个中文字符，只写行动短语。
- 选项不要编号，不要写“请选择”，不要写成标题或解释。
- 玩家不知道隐藏底牌和系统设定时，描述只能写可感知现象。

玩家上下文:
{context.strip()}"""


def gold_rows():
    samples = [
        (
            "codex_mortal_first_spark",
            """玩家: 玄
世代: 第一世
境界名称: 凡人
当前世界: 古典修仙纪，山门法统压过王朝法度。
此世家世: 坊市小族；父亲顾临渊；母亲叶微澜；伴生玉佩只表现为黑白旧玉。
近期记忆: 你第一次看见测灵碑，尚无前世记忆。
隐藏限制: 不得写前世异常，不得写鸿蒙至宝真名。""",
            """【机缘】碑前初光
测灵碑亮起时，顾临渊没有大笑，只按住你肩头让你站稳；叶微澜替你挡住旁人探问，眼里却有藏不住的欣慰。
稳住心神
谢过父母
观察旁人""",
        ),
        (
            "codex_first_life_teacher",
            """玩家: 玄
世代: 第一世
境界名称: 炼气期
当前世界: 古典修仙纪，诸宗并立，山门法统压过王朝法度。
此世家世: 坊市小族；父亲顾临渊；母亲叶微澜；伴生玉佩只表现为黑白旧玉。
近期记忆: 清蘅真人试心后没有立刻收徒，只留下一盏青灯。
隐藏限制: 不得写前世异常，不得写鸿蒙至宝真名。""",
            """【因果】青灯试心
清蘅真人把青灯留在窗前，只夸你心性肯受磨；顾临渊听后没有喜形于色，反替你挡下几道探问目光。
低头受教
追问灯意
暂避锋芒""",
        ),
        (
            "codex_family_praise_envy",
            """玩家: 玄
世代: 第一世
境界名称: 凡人
当前世界: 古典修仙纪，灵气丰沛，宗门看重根骨。
此世家世: 没落修真世家；父亲沈怀舟；母亲林青棠。
人情风波: 测灵碑刚亮，同辈江照雪表面道贺，眼底有酸意。
隐藏限制: 不得写前世异常。""",
            """【因果】测灵余声
沈怀舟先让你莫骄，林青棠却替你收好入门信物；江照雪笑着道贺，酸意已经藏进袖中名册。
谢过长辈
稳住锋芒
正面应试""",
        ),
        (
            "codex_luo_slow_intro",
            """玩家: 玄
世代: 第一世
境界名称: 炼气期
当前世界: 古典修仙纪，外门试炼将开。
此世家世: 坊市小族。
人情风波: 洛凝霜尚未成为亲近角色，只在试炼名单上出现过一次。
隐藏限制: 不得把角色关系写死，不得提前写深情。""",
            """【机缘】霜名入册
试炼名单末尾多出洛凝霜三字，旁人只说她剑骨清寒；她路过时看了你一眼，却没有给出亲近或疏远。
记下姓名
专心试炼
顺势寒暄""",
        ),
        (
            "codex_hidden_realm",
            """玩家: 玄
境界名称: 筑基期
当前世界: 仙朝鼎盛纪，册封与气运影响修行上限。
人情风波: 活跃修士祁无咎愿意见你，但外露境界未必真实。
最近记忆: 你曾识破一次幻境。""",
            """【奇遇】显境有假
祁无咎在人前只显金丹光影，笑意却稳得过分；他递帖时灵压收放极准，像故意只给你看半扇门。
顺势寒暄
暗观灵压
暂不交底""",
        ),
        (
            "codex_lost_method",
            """玩家: 玄
境界名称: 筑基期
当前世界: 古典修仙纪，古修遗府频现。
轮回传承: 只残留半段行功脉络。
人情风波: 藏经长老认出一点旧法骨相。
隐藏限制: 不得直接发放完整功法。""",
            """【传承】失传古法
藏经长老只看一眼便合上经卷，惊疑里又带认可；他提醒你别乱显旧式，否则懂行者会循味而来。
压下旧法
请教长老
借势入局""",
        ),
        (
            "codex_artifact_rules",
            """玩家: 玄
境界名称: 金丹期
当前世界: 灵机蒸汽纪，灵机工坊想拆解旧法。
轮回传承: 前世法宝本体未能跨世，只剩器痕余响。
人情风波: 器阁执事听见炉火异响后态度转慎。""",
            """【传承】器痕余响
器阁执事按住炉火，提醒你别把器痕当成法宝本体；那只是前世余响，却足以唤来懂器人的贪念。
询问器痕
封存余响
转身离阁""",
        ),
        (
            "codex_bully_bad_root",
            """玩家: 玄
境界名称: 炼气期
当前世界: 末法裂变纪，资源稀薄，单灵根修炼更快。
此世家世: 孤儿，养育者是外门执事。
人情风波: 外门恶少看你根骨不稳，故意扣试炼名额。""",
            """【危机】外门欺压
外门恶少把名册往袖里一收，笑你根基太薄；旁人等着看笑话，只有旧玉在胸口一阵发烫。
据理争名
暂忍记账
请人作证""",
        ),
        (
            "codex_foundation_root_age",
            """玩家: 玄
世代: 第一世
境界名称: 筑基期
当前世界: 古典修仙纪，灵气丰沛，五行灵根不再必然低人一等。
此世家世: 宗门外门弟子。
近期记忆: 你二十余岁筑基，速度不慢，但同门里有人仍拿灵根说事。""",
            """【因果】五行争名
执事刚记下你的筑基年岁，便有人酸你五行驳杂；清蘅真人只看了那人一眼，说盛世灵气足够养出宽阔道基。
稳住道基
回敬酸语
请教师尊""",
        ),
        (
            "codex_golden_core_envy",
            """玩家: 玄
世代: 第一世
境界名称: 金丹期
当前世界: 古典修仙纪，宗门大比将开。
人情风波: 你结丹异象稳而不炫，江照雪心中不甘。
近期记忆: 洛凝霜已在试炼中与你有过一次并肩。""",
            """【危机】丹成暗潮
你结丹没有夸耀，江照雪却把贺礼送得极重；那份不甘藏在礼数里，像要借宗门大比称量你的真实成色。
收礼不诺
约战台前
暗查来意""",
        ),
        (
            "codex_nascent_soul_luo",
            """玩家: 玄
世代: 第一世
境界名称: 元婴期
当前世界: 古典修仙纪，秘境开启。
人情风波: 洛凝霜天赋极好，对你有欣赏但关系仍由玩家选择推进。
近期记忆: 你曾在秘境中救过她一次，但没有挟恩。""",
            """【奇遇】霜剑同路
洛凝霜把半枚秘境钥印递来，语气仍淡，眼神却比从前柔和；她没有许诺情分，只问你敢不敢同走死门。
并肩入门
询问缘由
婉拒同行""",
        ),
        (
            "codex_transformation_master_risk",
            """玩家: 玄
世代: 第一世
境界名称: 化神期
当前世界: 古典修仙纪，宗门与魔道旧怨重燃。
人情风波: 清蘅真人受旧敌牵制，仍不愿让你替她背因果。
近期记忆: 道教反派玄衡子第一次露面。""",
            """【危机】旧敌问灯
玄衡子隔山问灯，笑称清蘅真人护徒太深；师尊没有让你退，只把因果线压低半寸，示意你自己选择。
替师接因
旁观破局
先护同门""",
        ),
        (
            "codex_hedao_lifebound_artifact",
            """玩家: 玄
世代: 第二世
境界名称: 合道期
当前世界: 仙朝鼎盛纪，册封气运与道途相争。
器物状态: 本命之物已温养多年，初生器灵只有朦胧亲近。
近期记忆: 前世师门旧灯偶尔在梦中回响。""",
            """【传承】本命初灵
本命器物在掌心轻鸣，像幼童认路般贴近你的神识；仙朝册封想替它定名，它却只回应你自己的道。
亲自命名
拒绝册封
暂借气运""",
        ),
        (
            "codex_mahayan_family_reborn",
            """玩家: 玄
世代: 第三世
境界名称: 大乘期
当前世界: 末法裂变纪，灵井枯潮逼近。
此世家世: 孤儿，被残宗收养。
轮回传承: 前世人情只剩梦兆，父母不再是同一批人。
近期记忆: 你开始理解每一世身份都不是装饰。""",
            """【因果】残宗收养
残宗老妪替你补好破袍，嘴上嫌你来历麻烦，夜里却把最后一枚灵井签压到你枕边；这一世的亲情不问前名。
收下灵签
追问代价
另寻资源""",
        ),
        (
            "codex_true_immortal_reunion",
            """玩家: 玄
世代: 第四世
境界名称: 真仙
当前世界: 仙朝鼎盛纪，飞升名册重开。
人情风波: 洛凝霜也已入仙界，但她经历与玩家并不完全同步。
近期记忆: 你听见一个熟悉剑名。""",
            """【奇遇】霜名再现
仙界名册掠过洛凝霜三字，旁人称她剑心近道；她看见你时没有问旧情，只问今生的你是否仍敢同行。
坦然相认
只谈大道
暂避旧情""",
        ),
        (
            "codex_immortal_king_tongtian",
            """玩家: 玄
世代: 第五世
境界名称: 仙王
当前世界: 灵机蒸汽纪，通天灵宝传闻开始流通。
器物规则: 后天通天灵宝可跨纪元长存，但无人温养会威能流失。
近期记忆: 你见到一件衰退的后天通天灵宝。""",
            """【传承】通天余威
残钟曾是后天通天灵宝，如今钟纹黯淡仍压得群修失声；器灵不认新主，只问你能否替它续一口道火。
温养残钟
询问旧主
暂不触碰""",
        ),
        (
            "codex_immortal_emperor_lifespan",
            """玩家: 玄
世代: 第六世
境界名称: 仙帝
当前世界: 废土返道纪，纪元残骸压住万族气运。
核心矛盾: 仙帝仍会寿尽，必须寻找道祖之路。
近期记忆: 你看见一位旧仙帝在寿火里沉默。""",
            """【危机】帝火将残
旧仙帝坐在残宫里，威压仍能镇住万里废土，寿火却薄得像纸；他没有求救，只问你是否也怕走到尽头。
请教道祖
续他寿火
沉默观礼""",
        ),
        (
            "codex_dao_ancestor_gate",
            """玩家: 玄
世代: 第七世
境界名称: 道祖
当前世界: 星穹道网纪，万道映照进道网深处。
至宝规则: 道祖可尝试与古老权柄相性接触，但不能由叙事直接发放。
近期记忆: 太虚照世镜的影子曾照出伪装。""",
            """【因果】镜影称道
太虚照世镜只投下一线冷光，照出你道果里的缺口；它没有认主，却让所有伪装境界在你眼前薄了一层。
补全道果
借光识伪
收回神识""",
        ),
        (
            "codex_heavenly_dao_realm",
            """玩家: 玄
世代: 多世之后
境界名称: 道祖-天道境
当前世界: 万道将合，诸纪元旧因果一并回潮。
器物状态: 本命至宝已融万道，接近古老权柄层次。
核心限制: 可映照甚至毁灭至宝，但没有必要把它写成普通装备。""",
            """【传承】万道归器
本命至宝在万道中央缓缓成形，诸纪元旧名都映在器壁上；此刻连古老权柄亦是可毁之物，却不必被你毁去。
映照万道
留其自存
回望诸世""",
        ),
        (
            "codex_parent_secret",
            """玩家: 玄
世代: 第一世
境界名称: 炼气期
当前世界: 古典修仙纪。
此世家世: 父母身份被隐去，养育者是外门执事，身上有黑白旧玉。
隐藏限制: 玩家不知道父母真相，不得直接揭底。""",
            """【因果】玉痕旧名
外门执事看见玉痕后忽然收声，连称呼都放轻了些；你仍不知父母来处，只觉门外有人替你守着风。
追问旧名
握玉静听
暂避册封""",
        ),
        (
            "codex_master_disappointment",
            """玩家: 玄
世代: 第一世
境界名称: 炼气期
当前世界: 古典修仙纪。
人情风波: 清蘅真人曾认可你的心性，但这次历练你贪功冒进。
最近记忆: 你险些害同门受伤。""",
            """【因果】师门冷灯
清蘅真人没有责骂，只把青灯移远半寸；那点失望比训斥更重，让同门的窃笑也跟着低了下去。
认错补救
沉默受罚
查明诱因""",
        ),
        (
            "codex_master_pride",
            """玩家: 玄
世代: 第一世
境界名称: 筑基期
当前世界: 古典修仙纪。
人情风波: 清蘅真人见你护住弱小同门。
最近记忆: 你没有贪秘境中最亮的灵药。""",
            """【机缘】师尊含笑
清蘅真人看见你把灵药让给伤者，眼底终于有了笑意；她只说道心未偏，却替你挡下一道长老试探。
谢过师尊
询问试探
稳住道心""",
        ),
        (
            "codex_modern_era_only",
            """玩家: 玄
世代: 第三世
境界名称: 元婴期
当前世界: 星穹道网纪，道网会记录公开选择。
人情风波: 现代纪元角色只应在星穹道网纪或灵机蒸汽纪登场。
最近记忆: 你刚在道网节点留下匿名痕迹。""",
            """【奇遇】道网留痕
星穹节点忽然回传一段匿名讯息，对方语气冷静却藏着好奇；她没有问你旧名，只邀你共查失控灵机。
接入节点
隐去道号
反查来源""",
        ),
        (
            "codex_late_hongmeng_gate",
            """玩家: 玄
境界名称: 道祖
当前世界: 废土返道纪，万道残缺正在重排。
至宝规则: 高境界可尝试认主古老权柄，但裁判权在游戏规则，不得直接宣布获得。
隐藏限制: 不得低境界发放古老至宝。""",
            """【因果】权柄拒手
虚空深处有古老权柄投下一线影子，却没有立刻认你为主；万道缺口在掌心显形，像要先称量你的道。
试探相性
收回神识
补全缺口""",
        ),
        (
            "codex_weak_root_master_comfort",
            """玩家: 玄
世代: 第一世
境界名称: 炼气期
当前世界: 古典修仙纪，灵气虽盛，外门仍以根骨排座次。
此世家世: 坊市小族，父母只盼你平安入道。
人情风波: 你进境慢于同门，清蘅真人仍未收回那盏青灯。
隐藏限制: 不得写前世异常，不得写鸿蒙至宝真名。""",
            """【因果】慢火温灯
同门笑你入息太慢，清蘅真人却把青灯拨亮半寸；她没有夸你天才，只说肯守慢火的人也能熬出真炁。
守灯炼息
谢过师尊
不理讥笑""",
        ),
        (
            "codex_bad_choice_social_cost",
            """玩家: 玄
世代: 第一世
境界名称: 筑基期
当前世界: 古典修仙纪，秘境试炼刚落幕。
人情风波: 你为了抢灵药险些牵连同门，洛凝霜只在远处看见结果。
隐藏限制: 不得把角色关系写死，不得提前写深情。""",
            """【危机】药香成刺
你带回灵药时，同门伤势也被抬进山门；洛凝霜没有责备，只把目光从药匣移到伤者身上，冷淡得让人难受。
先救同门
归还灵药
沉默受责""",
        ),
        (
            "codex_luo_respect_not_love",
            """玩家: 玄
世代: 第一世
境界名称: 金丹期
当前世界: 古典修仙纪，宗门大比之后风评初定。
人情风波: 洛凝霜认可你的剑下判断，但尚未形成亲密关系。
隐藏限制: 不得把欣赏直接写成道侣或深情。""",
            """【因果】霜意点头
洛凝霜收剑后向你点头，称你临阵未乱；那是修士之间的认可，不是许诺，旁人起哄时她反而退开半步。
坦然致意
约论剑理
避开起哄""",
        ),
        (
            "codex_xuanheng_taoist_villain",
            """玩家: 玄
世代: 第一世
境界名称: 化神期
当前世界: 古典修仙纪，宗门与道教旧派暗斗加深。
人情风波: 玄衡子以正道名义设局，想逼清蘅真人交出旧灯因果。
近期记忆: 你已能独自护住一脉弟子。""",
            """【危机】玄章压山
玄衡子携道章而来，句句称公理，却把清蘅真人的旧伤摆上明面；山门沉默时，所有目光都等你先动。
接下问章
护住师门
反问旧伤""",
        ),
        (
            "codex_second_life_new_parents",
            """玩家: 玄
世代: 第二世
境界名称: 炼气期
当前世界: 仙朝鼎盛纪，户籍名册牵动气运。
此世家世: 小吏之家；父亲陆守拙；母亲宋晚照。
轮回传承: 只剩模糊梦痕，今生父母不是上一世的父母。""",
            """【因果】新家旧梦
陆守拙替你改好入籍文牒，宋晚照把热粥推到手边；梦痕提醒你别用旧名衡量他们，这一世的亲情要重新回应。
谢过今亲
收好文牒
静观名册""",
        ),
        (
            "codex_reborn_talent_worries",
            """玩家: 玄
世代: 第二世
境界名称: 筑基期
当前世界: 仙朝鼎盛纪，册封官署喜欢提前押注少年天才。
人情风波: 你判断局势过于老成，引来长辈欣赏，也引来官署试探。
轮回传承: 旧世只留处事直觉，不能证明身份。""",
            """【机缘】老眼少年
主簿夸你小小年纪便懂取舍，话里却藏着试探；养父没有否认，只在袖下轻按你手腕，提醒你别太早露锋。
藏住锋芒
顺势应答
询问养父""",
        ),
        (
            "codex_low_realm_authority_reject",
            """玩家: 玄
世代: 第三世
境界名称: 元婴期
当前世界: 末法裂变纪，天外异象偶尔压过灵井枯潮。
至宝规则: 低境界只能见影、留印、参悟或被拒绝，不能认主或调用权柄。
近期记忆: 你试图靠近一次古老天象。""",
            """【危机】天象拒身
天外余光落到灵井边，黑白旧玉只替你挡住一息寒意；那道影子没有靠近，反把你的神识轻轻推回肉身。
退后观想
记下道痕
护住灵井""",
        ),
        (
            "codex_innate_tongtian",
            """玩家: 玄
世代: 第五世
境界名称: 仙王
当前世界: 灵机蒸汽纪，器道工坊争论先天与后天之别。
器物规则: 先天通天灵宝自带先天一气，不是古老权柄的低配。
近期记忆: 你被邀去鉴一件先天灵宝残影。""",
            """【传承】先天气息
残影一现，满阁炉火都向内收声；那件先天通天灵宝没有求主，只以一缕先天一气压住工坊的拆解妄念。
守礼观宝
请教器道
制止拆解""",
        ),
        (
            "codex_lifebound_spirit_boundary",
            """玩家: 玄
世代: 第四世
境界名称: 大乘期
当前世界: 废土返道纪，残宗用器物延续法统。
器物状态: 本命至宝初生器灵，只能表达亲近、畏惧和模糊意愿。
近期记忆: 你刚以自身道火温养它。""",
            """【传承】器灵初啼
本命至宝在掌心轻轻一颤，像幼童怕生又认得你的气息；它说不出完整话，只把亲近与畏惧一并贴上神识。
安抚器灵
温养道火
暂缓斗法""",
        ),
        (
            "codex_luo_late_reunion",
            """玩家: 玄
世代: 第六世
境界名称: 仙帝
当前世界: 仙朝鼎盛纪，旧人各自走到极高处。
人情风波: 洛凝霜天赋极好，已有叩问道祖之势，但关系仍取决于过往选择。
近期记忆: 你们在仙界远远见过一次。""",
            """【奇遇】霜河再会
洛凝霜立在霜河尽头，气息清寒近道；她没有追问旧世情分，只问你此番来见，是论剑、结盟，还是告别。
论剑问道
坦言结盟
只作告别""",
        ),
        (
            "codex_dao_ancestor_authority_use",
            """玩家: 玄
世代: 第七世
境界名称: 道祖
当前世界: 星穹道网纪，道网深处伪装境界层层叠叠。
至宝状态: 太虚照世镜已认主但未执掌，可有限调用照伪权柄。
近期记忆: 你需要判断一名活跃修士的外显修为是否为假。""",
            """【因果】镜权微启
太虚照世镜在道果旁微微一亮，只替你照薄一层伪装；它愿借权柄，却仍要你自己承担看破后的因果。
照见虚实
暂留余地
反问来人""",
        ),
        (
            "codex_heavenly_no_need_destroy",
            """玩家: 玄
世代: 多世之后
境界名称: 道祖-天道境
当前世界: 诸纪元旧因果回潮，万道尽入掌中。
器物状态: 万道本命至宝已成，能映照古老权柄。
核心限制: 可以写亦是可毁之物，但不把毁灭当目标。""",
            """【传承】道上回眸
万道本命至宝映出九重旧影，你终于明白古老权柄亦是可毁之物；只是掌尽诸道以后，毁去它们已无必要。
留其自存
照见诸世
归整万道""",
        ),
        (
            "codex_spirit_root_era_difference",
            """玩家: 玄
世代: 第二世
境界名称: 筑基期
当前世界: 末法裂变纪，灵气稀薄，单灵根更容易抢到破境速度。
此世家世: 小宗旁支。
人情风波: 有人拿盛世旧论嘲笑你的五行底子。""",
            """【危机】末法论根
执事翻着旧册笑五行宽阔只是盛世说法，末法灵气不够你慢慢铺路；旁支弟子低头偷笑，等你自己退名额。
争取灵井
改修细脉
记下此辱""",
        ),
        (
            "codex_master_rescue_seed",
            """玩家: 玄
世代: 第七世
境界名称: 道祖
当前世界: 废土返道纪，旧宗因果沉入残灯。
人情风波: 清蘅真人只剩旧灯因果，是否重续由玩家道途与选择决定。
近期记忆: 你已经能触及轮回边缘，却不能随意改写所有生死。""",
            """【因果】残灯未灭
旧灯在废土风里亮了一瞬，映出清蘅真人尚未散尽的因果；你能护住这一线余温，却仍需付出自己的道途代价。
护住残灯
追查旧敌
衡量代价""",
        ),
    ]
    rows = []
    for kind, context, response in samples:
        ok, reason = validate_contextual_text(context, response)
        if not ok:
            raise ValueError(f"invalid gold sample {kind}: {reason}")
        rows.append({"prompt": make_instruction_prompt(context), "response": response, "kind": kind})
    rows.extend(load_codex_gold_files(Path(__file__).parent))
    return rows


def load_codex_gold_files(base_dir):
    base_dir = Path(base_dir)
    rows = []
    seen = set()
    for pattern in ("codex_gold_events*.json", "codex_gold_events*.jsonl"):
        for path in sorted(base_dir.glob(pattern)):
            if path.name in seen:
                continue
            seen.add(path.name)
            rows.extend(load_codex_gold_file(path))
    return rows


def load_codex_gold_file(path):
    path = Path(path)
    if not path.exists():
        return []

    if path.suffix.lower() == ".jsonl":
        samples = []
        with path.open("r", encoding="utf-8") as f:
            for line_no, line in enumerate(f, start=1):
                line = line.strip()
                if not line:
                    continue
                try:
                    samples.append(json.loads(line))
                except json.JSONDecodeError as exc:
                    raise ValueError(f"invalid JSONL in {path}:{line_no}: {exc}") from exc
    else:
        data = json.loads(path.read_text(encoding="utf-8"))
        samples = data.get("samples", data if isinstance(data, list) else [])
    rows = []
    for index, item in enumerate(samples, start=1):
        kind = (item.get("kind") or f"codex_file_gold_{index}").strip()
        context = (item.get("context") or "").strip()
        response = normalize_event_text(item.get("response") or item.get("event") or "")
        ok, reason = validate_contextual_text(context, response)
        if not ok:
            raise ValueError(f"invalid external gold sample {kind}: {reason}")
        rows.append({
            "prompt": make_instruction_prompt(context),
            "response": response,
            "kind": kind,
        })
    print(f"loaded {len(rows)} Codex gold samples from {path}")
    return rows


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
        "family_envy": [
            "；赞许、护短和酸意同时落下，让这次测灵不再只是测灵。",
            "；长辈的灯还亮着，同辈的嫉妒也已经有了方向。",
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
        "family_envy": (
            ["【因果】测灵余声", "【机缘】长辈护短", "【危机】同辈酸意"],
            [
                "测灵碑亮起后，父亲压住夸赞，母亲暗中护短，同代江照雪却因你资质出众生出嫉妒。",
                "顾临渊不许族人把你捧上高处，叶微澜替你挡下闲话；江照雪在人群后冷眼记住你的名字。",
                "父亲只说根骨尚可，母亲却替你收好入门信物；江照雪笑着道贺，酸意已经藏进袖中名册。",
            ],
            ["谢过长辈", "稳住锋芒", "正面应试"],
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
    if kind == "family_envy":
        family = "没落修真世家；父亲顾临渊；母亲叶微澜；伴生玉佩: 黑白旧玉未显真名"
    names_by_role = {
        "父亲": ["沈怀舟", "顾临渊", "陆守拙"],
        "母亲": ["林青棠", "叶微澜", "宋晚照"],
        "竞争者": ["江照雪", "陆怀璧", "秦守缺"],
        "活跃修士": ["祁无咎", "沈听澜", "林星回"],
        "资源把关者": ["枯井执事", "天册司吏", "灵井配给官"],
    }
    if kind == "family_envy":
        npc_name = "江照雪"
    elif kind == "hidden_realm":
        npc_name = "祁无咎"
    else:
        npc_name = rng.choice(names_by_role.get(npc[0], ["沈听澜", "陆怀璧", "顾灰路", "叶执圭", "林星回", "秦守缺"]))
    legacy_by_kind = {
        "lost_tech": "当前继承的传承: 前世遗响·青灯登仙经。失传古法当世解读: 旧法会被当代制度重新解释。",
        "artifact": "当前继承的传承: 前世遗响·本命法宝器痕。普通法宝本体不能跨世。",
        "old_debt": "前世未竟因果: 上一世欠下一段宗门旧债，今生有人循名而来。",
        "jade_family": "轮回余烬: 前世残响尚浅。隐藏设定: 主角不知道伴生玉佩真相。",
        "lifespan": "寿元压力: 仙帝仍会寿尽，若不能证成道祖，时间正在逼近。",
        "family_envy": "轮回余烬: 前世记忆尚浅，但你偶尔会用超出年龄的眼神判断局势。",
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


def load_teacher_rows(path, *, max_rows=0, repeat=1):
    if not path:
        return []
    teacher_path = Path(path)
    if not teacher_path.exists():
        print(f"teacher file not found, skipped: {teacher_path}")
        return []

    rows = []
    rejected = {}
    with teacher_path.open("r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError as exc:
                rejected["json"] = rejected.get("json", 0) + 1
                continue

            raw_context = (item.get("context") or item.get("prompt") or "").strip()
            prompt = (item.get("prompt") or item.get("context") or "").strip()
            response = normalize_event_text(item.get("response") or item.get("event") or "")
            kind = (item.get("kind") or "codex_teacher_expansion").strip() or "codex_teacher_expansion"
            ok, reason = validate_contextual_text(raw_context, response)
            if not ok:
                rejected[reason] = rejected.get(reason, 0) + 1
                continue
            if not prompt:
                prompt = make_instruction_prompt("玩家上下文: 老师蒸馏样本，已通过问道规则过滤。")
            elif "严格输出5行" not in prompt:
                prompt = make_instruction_prompt(prompt)
            for _ in range(max(1, repeat)):
                rows.append({"prompt": prompt, "response": response, "kind": kind})
            if max_rows and len(rows) >= max_rows:
                rows = rows[:max_rows]
                break

    if rejected:
        print("teacher rejected:", ", ".join(f"{key}={value}" for key, value in sorted(rejected.items())))
    print(f"loaded {len(rows)} filtered teacher rows from {teacher_path}")
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="data")
    parser.add_argument("--train-count", type=int, default=1200)
    parser.add_argument("--eval-count", type=int, default=120)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--teacher-file", default="")
    parser.add_argument("--teacher-max", type=int, default=600)
    parser.add_argument("--teacher-repeat", type=int, default=2)
    parser.add_argument("--gold-repeat", type=int, default=14)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    kinds = [
        "talent_praise", "family_envy", "envy", "bully", "lost_tech", "jade_family",
        "artifact", "lifespan", "old_debt", "hidden_realm", "neutral",
    ]

    rows = []
    gold = gold_rows()
    for _ in range(max(1, args.gold_repeat)):
        rows.extend(gold)
    rows.extend(load_teacher_rows(args.teacher_file, max_rows=args.teacher_max, repeat=args.teacher_repeat))

    synthetic_needed = max(0, args.train_count + args.eval_count - len(rows))
    for i in range(synthetic_needed):
        kind = kinds[i % len(kinds)]
        case = build_case(rng, kind)
        response = response_for(case)
        case_prompt = prompt_for(case)
        ok, reason = validate_contextual_text(case_prompt, response, strict_secret=False)
        if not ok:
            raise ValueError(f"invalid synthetic sample {kind}: {reason}\n{response}")
        rows.append({"prompt": case_prompt, "response": response, "kind": kind})
    rng.shuffle(rows)

    out_dir = Path(args.out_dir)
    write_jsonl(out_dir / "train.jsonl", rows[: args.train_count])
    write_jsonl(out_dir / "eval.jsonl", rows[args.train_count : args.train_count + args.eval_count])
    print(f"wrote {args.train_count} train and {args.eval_count} eval samples to {out_dir}")


if __name__ == "__main__":
    main()

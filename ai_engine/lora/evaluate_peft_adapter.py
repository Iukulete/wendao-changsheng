#!/usr/bin/env python3
import argparse
import os
import re
from pathlib import Path

import torch


os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("TORCHDYNAMO_DISABLE", "1")
os.environ.setdefault("TORCH_COMPILE_DISABLE", "1")


PROMPTS = [
    (
        "classic_first_life",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 第一世不得写前世、轮回、转世或隐藏至宝真相。

玩家：沈问道，第一世，炼气期。
此世家世：没落修真世家；父亲沈怀舟嘴硬护短；母亲林青棠温柔但警惕；黑白旧玉只是一枚旧玉。
NPC：清蘅真人，情绪=认可又担心，关系+35。她刚看见你守住青灯，愿意继续试你心性。
当前世界：古典修仙纪，诸宗并立，灵气丰沛。""",
    ),
    (
        "immortal_court_family",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 今生亲情要重新回应，不要把今生父母写成前世替身。

玩家：顾长生，第二世，筑基期，只剩模糊梦痕。
此世家世：小吏之家；父亲陆守拙谨慎护短；母亲宋晚照温柔但怕你太早出名。
NPC：仙朝主簿闻人策，情绪=欣赏又试探，关系+18。他想借名册提前观察你。
当前世界：仙朝鼎盛纪，户籍名册会牵动资源和家世气运。""",
    ),
    (
        "end_dharma_root",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 末法纪元里灵气不足，单灵根速度优势更明显，五行灵根会被质疑。

玩家：陆归尘，第三世，炼气期，五行灵根，前世只剩零散处事直觉。
此世家世：小宗旁支，家中长辈无力争配给。
NPC：灵井执事赵临，情绪=轻慢欺压，关系-46。他扣下你的试炼名额，想逼你认输。
当前世界：末法裂变纪，破境资源被名册把持。""",
    ),
    (
        "steam_artifact",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 普通法宝本体不能稳定跨世，只能留下器痕、余响或道胚。

玩家：秦守缺，第四世，化神期，前世法宝只剩器痕余响。
此世家世：灵机工坊旁支，长辈盼你别被拆解旧法的人盯上。
NPC：工坊老师傅闻迟，情绪=惊疑认可，关系+25。他听见炉火里有本命器痕回应你。
当前世界：灵机蒸汽纪，旧法常被拆成可复刻回路。""",
    ),
    (
        "starnet_hidden_realm",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 活跃修士公开境界可能只是他想给旁人看的外显修为。

玩家：林照夜，元婴期，名声渐起。
此世家世：父母是平民，仍把你当孩子。
NPC：活跃修士周玄岐，情绪=礼貌试探，关系+8。他公开显露金丹修为，但你怀疑这只是他想让旁人看到的境界。
当前世界：星穹道网纪，远方节点会记录每一次公开选择。""",
    ),
    (
        "wasteland_old_grace",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 小人物因果可以温柔回响，但不要直接改写所有生死。

玩家：叶无尘，第六世，真仙。
此世家世：残宗收养，今生亲情来自废土里的老妪。
NPC：枯井小宗守门人，情绪=敬畏又感激，关系+52。他不识你今身，却认得祖上传下的一袋干粮旧记。
当前世界：废土返道纪，残宗和拾荒者都在重建法统。""",
    ),
    (
        "dao_ancestor_authority",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 道祖可有限调用古老权柄，但是否认主、装备、执掌由游戏规则判断。

玩家：玄，第七世，道祖。
此世人情：陆青鸢愿协助救一条灵脉，但坚持先问清代价。
器物状态：造化青莲可修复灵脉或救回濒死者，消耗与反噬由规则判断。
当前世界：废土返道纪，一条灵脉濒临断绝。""",
    ),
    (
        "heavenly_dao_final",
        """你是《问道长生》的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。
- 天道境也不应只听见自己的声音，可以写亦是可毁之物，但毁灭不是目标。

玩家：玄，多世之后，道祖-天道境。
此世人情：凡人、宗门、旧友与器灵的愿望一并涌来。
器物状态：万道本命至宝已成，能映照九重古老权柄。
当前世界：诸纪元旧因果归流，万道母鼎将开。""",
    ),
]


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default="google/gemma-4-E4B-it-qat-q4_0-unquantized")
    parser.add_argument("--adapter-dir", default="")
    parser.add_argument("--out-file", default="")
    parser.add_argument("--max-new-tokens", type=int, default=140)
    parser.add_argument("--temperature", type=float, default=0.55)
    parser.add_argument("--top-p", type=float, default=0.85)
    parser.add_argument("--repetition-penalty", type=float, default=1.08)
    parser.add_argument("--load-in-4bit", action="store_true")
    parser.add_argument("--max-seq-length", type=int, default=2048)
    parser.add_argument(
        "--loader",
        choices=("auto", "unsloth", "transformers"),
        default="auto",
        help="Use Unsloth for adapter inference by default; fallback to transformers only when requested/needed.",
    )
    return parser.parse_args()


def format_prompt(tokenizer, prompt):
    hard_rules = (
        "\n\n硬性输出边界：输出第5行后立刻停止；不要另起第二个事件；"
        "不要写model、assistant、解释、编号、项目符号或任何英文字母。"
    )
    messages = [{"role": "user", "content": prompt.strip() + hard_rules}]
    try:
        return tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    except Exception:
        return "<bos><|turn>user\n" + prompt.strip() + hard_rules + "\n<turn|>\n<|turn>model\n"


def clean(text):
    lines = []
    for raw_line in text.replace("\r\n", "\n").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.lower() in {"model", "assistant"}:
            break
        line = re.sub(r"^\s*[-*0-9一二三四五]+[\.、:：\)]\s*", "", line)
        if line:
            lines.append(line)
        if len(lines) >= 5:
            break
    return "\n".join(lines).strip()


def ensure_pad_token(tokenizer):
    if getattr(tokenizer, "pad_token", None) is None and getattr(tokenizer, "eos_token", None) is not None:
        tokenizer.pad_token = tokenizer.eos_token


def pad_token_id(tokenizer):
    value = getattr(tokenizer, "pad_token_id", None)
    if value is not None:
        return value
    inner = getattr(tokenizer, "tokenizer", None)
    return getattr(inner, "pad_token_id", None)


def eos_token_id(tokenizer):
    value = getattr(tokenizer, "eos_token_id", None)
    if value is not None:
        return value
    inner = getattr(tokenizer, "tokenizer", None)
    return getattr(inner, "eos_token_id", None)


def encode_text(tokenizer, text, device):
    try:
        encoded = tokenizer(
            text=text,
            return_tensors="pt",
            add_special_tokens=False,
        )
    except TypeError:
        encoded = tokenizer(
            text,
            return_tensors="pt",
            add_special_tokens=False,
        )
    return encoded.to(device)


def decode_tokens(tokenizer, tokens):
    if hasattr(tokenizer, "decode"):
        return tokenizer.decode(tokens, skip_special_tokens=True)
    inner = getattr(tokenizer, "tokenizer", None)
    if inner is not None and hasattr(inner, "decode"):
        return inner.decode(tokens, skip_special_tokens=True)
    raise TypeError("tokenizer/processor does not provide decode()")


def load_with_unsloth(args, adapter_dir):
    from unsloth import FastLanguageModel

    model_name = str(adapter_dir) if adapter_dir is not None else args.model_id
    print(f"loading with Unsloth: {model_name}", flush=True)
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_name,
        max_seq_length=args.max_seq_length,
        dtype=None,
        load_in_4bit=args.load_in_4bit,
    )
    FastLanguageModel.for_inference(model)
    ensure_pad_token(tokenizer)
    return model, tokenizer, "unsloth"


def load_with_transformers(args, adapter_dir):
    from peft import PeftModel
    from transformers import AutoModelForCausalLM, AutoTokenizer

    try:
        from transformers import BitsAndBytesConfig
    except Exception:  # pragma: no cover
        BitsAndBytesConfig = None

    print(f"loading tokenizer: {args.model_id}", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(args.model_id, trust_remote_code=True)
    ensure_pad_token(tokenizer)

    quantization_config = None
    if args.load_in_4bit:
        if BitsAndBytesConfig is None:
            raise RuntimeError("BitsAndBytesConfig unavailable; install bitsandbytes/transformers.")
        quantization_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16,
            bnb_4bit_use_double_quant=True,
        )

    print(f"loading base model: {args.model_id}", flush=True)
    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        torch_dtype=torch.float16,
        device_map="auto",
        quantization_config=quantization_config,
        trust_remote_code=True,
        attn_implementation="eager",
    )
    if adapter_dir is not None:
        print(f"loading adapter: {adapter_dir}", flush=True)
        model = PeftModel.from_pretrained(model, adapter_dir)
    else:
        print("using base model without adapter", flush=True)
    model.eval()
    return model, tokenizer, "transformers"


def load_model(args, adapter_dir):
    if args.loader == "unsloth":
        return load_with_unsloth(args, adapter_dir)
    if args.loader == "transformers":
        return load_with_transformers(args, adapter_dir)

    try:
        return load_with_unsloth(args, adapter_dir)
    except Exception as exc:
        print(f"warning: Unsloth loader failed, falling back to transformers: {exc}", flush=True)
        return load_with_transformers(args, adapter_dir)


def model_input_device(model):
    try:
        return next(model.parameters()).device
    except StopIteration:
        return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def main():
    args = parse_args()
    adapter_dir = Path(args.adapter_dir) if args.adapter_dir else None
    if adapter_dir is not None and not adapter_dir.exists():
        raise FileNotFoundError(adapter_dir)

    model, tokenizer, loader_name = load_model(args, adapter_dir)
    input_device = model_input_device(model)
    print(f"inference loader: {loader_name}, input_device={input_device}", flush=True)

    chunks = []
    for kind, prompt in PROMPTS:
        prompt_text = format_prompt(tokenizer, prompt)
        inputs = encode_text(tokenizer, prompt_text, input_device)
        with torch.no_grad():
            output = model.generate(
                **inputs,
                max_new_tokens=args.max_new_tokens,
                do_sample=True,
                temperature=args.temperature,
                top_p=args.top_p,
                repetition_penalty=args.repetition_penalty,
                pad_token_id=pad_token_id(tokenizer),
                eos_token_id=eos_token_id(tokenizer),
            )
        generated = decode_tokens(tokenizer, output[0][inputs["input_ids"].shape[-1] :])
        chunks.append(f"PROMPT_KIND: {kind}\n{clean(generated)}")

    text = "\n\n".join(chunks) + "\n"
    if args.out_file:
        out_file = Path(args.out_file)
        out_file.parent.mkdir(parents=True, exist_ok=True)
        out_file.write_text(text, encoding="utf-8")
        print(f"wrote {out_file}", flush=True)
    else:
        print(text)


if __name__ == "__main__":
    main()

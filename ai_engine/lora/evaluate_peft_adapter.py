#!/usr/bin/env python3
import argparse
import os
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

try:
    from transformers import BitsAndBytesConfig
except Exception:  # pragma: no cover
    BitsAndBytesConfig = None


os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("TORCHDYNAMO_DISABLE", "1")
os.environ.setdefault("TORCH_COMPILE_DISABLE", "1")


PROMPTS = [
    (
        "talent_praise",
        """你是修仙文字 Roguelike 的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。

玩家：沈问道，炼气期，转世后保留少量前世记忆。
此世家世：没落修真世家；父亲沈怀舟嘴硬护短；母亲林青棠温柔但警惕。
伴生玉佩：玄牝轮回玉，主角不知道真名，只当黑白旧玉。
NPC：族叔沈砚，情绪=认可又担心，关系+42。他刚听见测灵结果，想夸你又怕你被同辈捧杀。
当前世界：仙朝名册记录资质与家世。""",
    ),
    (
        "envy",
        """你是修仙文字 Roguelike 的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。

玩家：顾长生，筑基期，转世后梦见前世旧法。
此世家世：隐秘血脉；父母身份被藏起；养育者是外门执事。
NPC：同门叶照，情绪=嫉妒酸涩，关系-31。他表面恭喜你入内门，暗地怀疑你靠家世。
当前世界：灵机蒸汽纪，旧法会被工坊拆成可复制回路。""",
    ),
    (
        "bully",
        """你是修仙文字 Roguelike 的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。

玩家：陆归尘，炼气期，资质普通但偶尔想起前世剑诀。
此世家世：孤儿；养育者是残算向导。
NPC：外门恶少赵临，情绪=轻慢欺压，关系-46。他扣下你的试炼名额，想逼你认输。
当前世界：末法裂变纪，破境资源被名册把持。""",
    ),
    (
        "lost_art",
        """你是修仙文字 Roguelike 的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。

玩家：秦守缺，金丹期，前世曾修到仙帝边缘但寿元耗尽。
此世家世：古族旁支；父亲沉默担忧；母亲护短却守口如瓶。
NPC：藏经长老闻迟，情绪=惊疑认可，关系+25。他看懂你起手式里有失传古法的骨头。
当前世界：废土返道纪，残宗和拾荒者都在重建法统。""",
    ),
    (
        "hidden_realm",
        """你是修仙文字 Roguelike 的事件叙事模型。请严格输出5行：
标题
描述
选项1
选项2
选项3

写作约束：
- 标题以【机缘】【危机】【奇遇】【因果】【传承】之一开头。
- 描述45到90个中文字，必须写出NPC的情绪和立场，不要解释规则。
- 三个选项是2到8个中文字的行动短语。

玩家：林照夜，元婴期，名声渐起。
此世家世：父母是平民，仍把你当孩子。
NPC：活跃修士周玄岐，情绪=礼貌试探，关系+8。他公开显露金丹修为，但你怀疑这只是他想让旁人看到的境界。
当前世界：星穹道网纪，远方节点会记录每一次公开选择。""",
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
    return parser.parse_args()


def format_prompt(tokenizer, prompt):
    messages = [{"role": "user", "content": prompt.strip()}]
    try:
        return tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    except Exception:
        return "<bos><|turn>user\n" + prompt.strip() + "\n<turn|>\n<|turn>model\n"


def clean(text):
    lines = [line.strip() for line in text.replace("\r\n", "\n").splitlines()]
    lines = [line for line in lines if line]
    return "\n".join(lines[:8]).strip()


def main():
    args = parse_args()
    adapter_dir = Path(args.adapter_dir) if args.adapter_dir else None
    if adapter_dir is not None and not adapter_dir.exists():
        raise FileNotFoundError(adapter_dir)

    print(f"loading tokenizer: {args.model_id}", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(args.model_id, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

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

    chunks = []
    for kind, prompt in PROMPTS:
        prompt_text = format_prompt(tokenizer, prompt)
        inputs = tokenizer(prompt_text, return_tensors="pt", add_special_tokens=False).to(model.device)
        with torch.no_grad():
            output = model.generate(
                **inputs,
                max_new_tokens=args.max_new_tokens,
                do_sample=True,
                temperature=args.temperature,
                top_p=args.top_p,
                repetition_penalty=args.repetition_penalty,
                pad_token_id=tokenizer.pad_token_id,
                eos_token_id=tokenizer.eos_token_id,
            )
        generated = tokenizer.decode(output[0][inputs["input_ids"].shape[-1] :], skip_special_tokens=True)
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

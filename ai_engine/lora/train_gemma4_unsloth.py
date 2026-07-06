#!/usr/bin/env python3
import argparse
import inspect
import json
from pathlib import Path

from unsloth import FastLanguageModel
from datasets import Dataset
from trl import SFTTrainer, SFTConfig


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default="google/gemma-4-E4B-it")
    parser.add_argument("--train-file", required=True)
    parser.add_argument("--eval-file", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--max-seq-length", type=int, default=768)
    parser.add_argument("--epochs", type=float, default=2.0)
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--grad-accum", type=int, default=16)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument("--lora-r", type=int, default=8)
    parser.add_argument("--lora-alpha", type=int, default=16)
    parser.add_argument("--lora-dropout", type=float, default=0.0)
    parser.add_argument("--load-in-4bit", action="store_true")
    parser.add_argument("--seed", type=int, default=20260703)
    return parser.parse_args()


def load_rows(path):
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def format_row(tokenizer, row):
    messages = [
        {"role": "user", "content": row["prompt"].strip()},
        {"role": "assistant", "content": row["response"].strip()},
    ]
    try:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=False,
        )
    except Exception:
        return (
            "<bos><|turn>user\n"
            + row["prompt"].strip()
            + "\n<turn|>\n<|turn>model\n"
            + row["response"].strip()
            + (tokenizer.eos_token or "")
        )


def make_dataset(tokenizer, path):
    rows = load_rows(path)
    return Dataset.from_list([
        {"text": format_row(tokenizer, row), "kind": row.get("kind", "")}
        for row in rows
    ])


def accepts_parameter(callable_obj, name):
    return name in inspect.signature(callable_obj).parameters


def compatible_sft_config(args, out_dir):
    kwargs = {
        "output_dir": str(out_dir),
        "dataset_text_field": "text",
        "num_train_epochs": args.epochs,
        "per_device_train_batch_size": args.batch_size,
        "per_device_eval_batch_size": 1,
        "gradient_accumulation_steps": args.grad_accum,
        "learning_rate": args.lr,
        "warmup_ratio": 0.03,
        "logging_steps": 10,
        "save_strategy": "no",
        "optim": "adamw_8bit",
        "fp16": True,
        "bf16": False,
        "seed": args.seed,
        "report_to": "none",
    }
    init = SFTConfig.__init__
    if accepts_parameter(init, "max_seq_length"):
        kwargs["max_seq_length"] = args.max_seq_length
    elif accepts_parameter(init, "max_length"):
        kwargs["max_length"] = args.max_seq_length
    if accepts_parameter(init, "eval_strategy"):
        kwargs["eval_strategy"] = "no"
    elif accepts_parameter(init, "evaluation_strategy"):
        kwargs["evaluation_strategy"] = "no"

    filtered = {key: value for key, value in kwargs.items() if accepts_parameter(init, key)}
    return SFTConfig(**filtered)


def make_trainer(model, tokenizer, config, train_ds, eval_ds):
    kwargs = {
        "model": model,
        "args": config,
        "train_dataset": train_ds,
        "eval_dataset": eval_ds,
    }
    init = SFTTrainer.__init__
    if accepts_parameter(init, "tokenizer"):
        kwargs["tokenizer"] = tokenizer
    elif accepts_parameter(init, "processing_class"):
        kwargs["processing_class"] = tokenizer
    return SFTTrainer(**kwargs)


def main():
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=args.model_id,
        max_seq_length=args.max_seq_length,
        load_in_4bit=args.load_in_4bit,
        dtype=None,
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=args.lora_r,
        target_modules=[
            "q_proj", "k_proj", "v_proj", "o_proj",
            "gate_proj", "up_proj", "down_proj",
        ],
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=args.seed,
    )

    train_ds = make_dataset(tokenizer, args.train_file)
    eval_ds = make_dataset(tokenizer, args.eval_file)
    print(f"train samples={len(train_ds)} eval samples={len(eval_ds)}", flush=True)

    config = compatible_sft_config(args, out_dir)
    trainer = make_trainer(model, tokenizer, config, train_ds, eval_ds)
    trainer.train()

    model.save_pretrained(out_dir)
    tokenizer.save_pretrained(out_dir)
    print(f"saved Unsloth LoRA adapter to {out_dir}", flush=True)


if __name__ == "__main__":
    main()

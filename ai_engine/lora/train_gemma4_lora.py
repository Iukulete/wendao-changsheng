#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path

import torch
from torch.utils.data import DataLoader, Dataset
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training

try:
    from transformers import BitsAndBytesConfig
except Exception:  # pragma: no cover
    BitsAndBytesConfig = None


os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")


class WendaoDataset(Dataset):
    def __init__(self, path, tokenizer, max_length):
        self.rows = []
        self.tokenizer = tokenizer
        self.max_length = max_length
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    self.rows.append(json.loads(line))

    def __len__(self):
        return len(self.rows)

    def _format_prompt(self, prompt):
        messages = [{"role": "user", "content": prompt.strip()}]
        try:
            return self.tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
        except Exception:
            return "<bos><|turn>user\n" + prompt.strip() + "\n<turn|>\n<|turn>model\n"

    def __getitem__(self, index):
        row = self.rows[index]
        prompt_text = self._format_prompt(row["prompt"])
        response_text = row["response"].strip() + (self.tokenizer.eos_token or "")
        full_text = prompt_text + response_text

        full = self.tokenizer(
            full_text,
            add_special_tokens=False,
            truncation=True,
            max_length=self.max_length,
        )
        prompt = self.tokenizer(
            prompt_text,
            add_special_tokens=False,
            truncation=True,
            max_length=self.max_length,
        )

        input_ids = full["input_ids"]
        labels = list(input_ids)
        prompt_len = min(len(prompt["input_ids"]), len(labels))
        labels[:prompt_len] = [-100] * prompt_len
        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.ones(len(input_ids), dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }


def collate(batch, pad_token_id):
    max_len = max(item["input_ids"].size(0) for item in batch)
    out = {}
    for key in ["input_ids", "attention_mask", "labels"]:
        fill = -100 if key == "labels" else (0 if key == "attention_mask" else pad_token_id)
        tensors = []
        for item in batch:
            tensor = item[key]
            if tensor.size(0) < max_len:
                tensor = torch.cat(
                    [tensor, torch.full((max_len - tensor.size(0),), fill, dtype=tensor.dtype)]
                )
            tensors.append(tensor)
        out[key] = torch.stack(tensors)
    return out


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default="google/gemma-4-E4B-it-qat-q4_0-unquantized")
    parser.add_argument("--train-file", required=True)
    parser.add_argument("--eval-file", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--max-length", type=int, default=1152)
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--grad-accum", type=int, default=8)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument("--lora-r", type=int, default=16)
    parser.add_argument("--lora-alpha", type=int, default=32)
    parser.add_argument("--lora-dropout", type=float, default=0.05)
    parser.add_argument("--target-modules", default="q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj")
    parser.add_argument("--load-in-4bit", action="store_true")
    parser.add_argument("--log-every", type=int, default=10)
    parser.add_argument("--save-every", type=int, default=0)
    parser.add_argument("--eval-generations", type=int, default=4)
    return parser.parse_args()


def main():
    args = parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

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

    model = AutoModelForCausalLM.from_pretrained(
        args.model_id,
        torch_dtype=torch.float16,
        device_map="auto",
        quantization_config=quantization_config,
        trust_remote_code=True,
        attn_implementation="eager",
    )
    model.config.use_cache = False
    if args.load_in_4bit:
        model = prepare_model_for_kbit_training(model)
    if hasattr(model, "enable_input_require_grads"):
        model.enable_input_require_grads()
    if hasattr(model, "gradient_checkpointing_enable"):
        model.gradient_checkpointing_enable()

    lora_config = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        lora_dropout=args.lora_dropout,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=[item.strip() for item in args.target_modules.split(",") if item.strip()],
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    train_ds = WendaoDataset(args.train_file, tokenizer, args.max_length)
    eval_ds = WendaoDataset(args.eval_file, tokenizer, args.max_length)
    train_loader = DataLoader(
        train_ds,
        batch_size=args.batch_size,
        shuffle=True,
        collate_fn=lambda b: collate(b, tokenizer.pad_token_id),
    )

    optimizer = torch.optim.AdamW((p for p in model.parameters() if p.requires_grad), lr=args.lr)
    model.train()
    global_step = 0
    running = 0.0
    optimizer.zero_grad(set_to_none=True)

    for epoch in range(args.epochs):
        for step, batch in enumerate(train_loader, start=1):
            batch = {k: v.to(model.device) for k, v in batch.items()}
            outputs = model(**batch)
            loss = outputs.loss / args.grad_accum
            loss.backward()
            running += loss.item() * args.grad_accum

            if step % args.grad_accum == 0:
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                optimizer.step()
                optimizer.zero_grad(set_to_none=True)
                global_step += 1
                if global_step % args.log_every == 0:
                    avg = running / (args.log_every * args.grad_accum)
                    print(f"epoch={epoch + 1} step={global_step} loss={avg:.4f}", flush=True)
                    running = 0.0
                if args.save_every and global_step % args.save_every == 0:
                    ckpt = out_dir / f"checkpoint-{global_step}"
                    model.save_pretrained(ckpt)
                    tokenizer.save_pretrained(ckpt)

    model.save_pretrained(out_dir)
    tokenizer.save_pretrained(out_dir)
    print(f"saved LoRA adapter to {out_dir}", flush=True)

    if args.eval_generations > 0:
        model.eval()
        samples = eval_ds.rows[: args.eval_generations]
        gen_path = out_dir / "eval_generations.txt"
        with gen_path.open("w", encoding="utf-8") as f:
            for row in samples:
                prompt_text = eval_ds._format_prompt(row["prompt"])
                inputs = tokenizer(prompt_text, return_tensors="pt", add_special_tokens=False).to(model.device)
                with torch.no_grad():
                    output = model.generate(
                        **inputs,
                        max_new_tokens=150,
                        do_sample=True,
                        temperature=0.75,
                        top_p=0.9,
                        repetition_penalty=1.08,
                        pad_token_id=tokenizer.pad_token_id,
                        eos_token_id=tokenizer.eos_token_id,
                    )
                generated = tokenizer.decode(output[0][inputs["input_ids"].shape[-1] :], skip_special_tokens=True)
                f.write("PROMPT_KIND: " + row.get("kind", "") + "\n")
                f.write(generated.strip() + "\n\n")
        print(f"wrote eval generations to {gen_path}", flush=True)


if __name__ == "__main__":
    main()

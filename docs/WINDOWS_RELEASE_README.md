# 《问道长生》Windows 版

## 运行

双击 `wendao-changsheng.exe`。游戏会把存档写入同目录的 `save/`，不会写入
Windows 用户目录。请把整个游戏文件夹放在可写位置，不要直接在压缩包内运行。

窗口可自由缩放；关键界面支持 `1280x720` 及以上分辨率。退出前会自动封存当前
命途，主档损坏时会尝试从上一份完整备份恢复。

## 可选本地 AI

双击 `setup-local-ai.bat` 可下载哈希固定的 Gemma 模型、问道 LoRA 和 llama.cpp
Vulkan 运行时。首次下载约需 5.2 GB，安装后文件位于 `ai_engine/`。生成过程只调用
本机进程，不会把存档或提示词发送给在线生成接口；没有安装、运行超时或输出未
通过校验时，游戏会自动使用内置事件。

模型与运行时受各自上游条款约束，来源、固定版本和 SHA-256 见
`licenses/THIRD_PARTY_AI.md`。删除 `ai_engine/models/`、`ai_engine/runtime/` 和
`ai_engine/lora/*.gguf` 即可移除本地 AI 文件，不影响存档和内置玩法。

## 文件与许可

- `wendao-changsheng.exe`、`wendao-changsheng.pck`：游戏程序与资源。
- `save/`：本机存档、备份与损坏档隔离文件。
- `checksums.sha256`：发布包文件完整性清单。
- `licenses/`：项目、字体、音频与可选 AI 的许可和来源说明。

项目程序采用 GNU Affero General Public License v3.0，完整文本见
`licenses/AGPL-3.0.txt`。

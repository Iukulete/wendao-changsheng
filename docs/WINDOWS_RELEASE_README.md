# 《问道长生》Windows 版

## 运行

双击 `wendao-changsheng.exe`。游戏会把存档写入同目录的 `save/`，不会写入
Windows 用户目录。请把整个游戏文件夹放在可写位置，不要直接在压缩包内运行。

窗口可自由缩放；关键界面支持 `1280x720` 及以上分辨率。退出前会自动封存当前
命途，主档损坏时会尝试从上一份完整备份恢复。

## 内容来源

主线、战斗和章节结果均来自随包分发的作者编排数据，不需要联网、模型下载或
额外运行时。发布包不包含本地 AI 模型、下载器或训练数据；仓库中的离线 AI
脚本只用于开发阶段的结构回归和文本检查。

## 文件与许可

- `wendao-changsheng.exe`、`wendao-changsheng.pck`：游戏程序与资源。
- `save/`：本机存档、备份与损坏档隔离文件。
- `checksums.sha256`：发布包文件完整性清单。
- `licenses/`：项目、字体、音频的许可和来源说明。

项目程序采用 GNU Affero General Public License v3.0，完整文本见
`licenses/AGPL-3.0.txt`。

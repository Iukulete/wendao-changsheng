# Emma 模型本地接入

来源：用户提供的 `D:\小游戏开发\素材\OC-Emma.vrm`，原文件未修改。
SHA-256：`e83b023357943d224961595c7b9f25a619205f6cb63738f762ac1cb5bb90a29d`。

`tools/convert_emma_vrm.py` 将 VRM 0 的 glTF 几何、331 根骨骼、六个网格、
蒙皮和贴图保留为 `godot/art/player_emma/emma.glb`，移除 Godot 不支持的
VRM 扩展声明。作者与权限字段保存在 GLB 的 `asset.extras.source_vrm_meta`。
贴图通过导入设置嵌入场景，不依赖素材目录或额外插件。

角色默认使用 Emma，F8 切换原白衣像素表现。两者共用原 CharacterBody3D、
碰撞体、行走/游泳控制器与存档。旧灰盒人物构建函数仍用于居民。
模型缩放为 1.08、原点对齐脚底，朝向适配现有 +Z 控制器。

## 成品动画接入

模型原本未附动画。现使用 Quaternius 官方 Universal Animation Library
Standard 免费包中的 `Idle_Loop`、`Walk_Loop`、`Jog_Fwd_Loop`、`Swim_Idle_Loop` 和
`Swim_Fwd_Loop`，许可为 CC0-1.0。来源：
https://quaternius.com/packs/universalanimationlibrary.html
官方包在 https://quaternius.itch.io/universal-animation-library 下载。
`Jog_Fwd_Loop` 用于按住 Shift 时的快跑。动画许可随资源保留在 `godot/art/player_emma/Quaternius-CC0.txt`。

原始 Standard ZIP SHA-256：
`cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724`。

`tools/retarget_emma_locomotion.py` 以动作库 `A_TPose` 为参考，在统一的
全局坐标中计算旋转差，适配 VRM0 朝向，再转换成 Emma 的局部骨骼轨道。
迁移 49 个人体关节，按角色高度比例保留骨盆的局部运动；骨架、骨长和
蒙皮权重不变。使用普通 `Walk_Loop` 作为标准走路基线，不再生成脚部
正弦曲线或平面双骨反解步态。

使用现有 Godot 和 Python 3 可重新生成：

```powershell
python tools/retarget_emma_locomotion.py .tmp/UAL1_Standard.glb 'D:/小游戏开发/素材/OC-Emma.vrm' .tmp/emma_locomotion.json
./Godot_v4.7.1-stable_win64.exe --headless --path godot --script ../tools/bake_emma_locomotion.gd
```

重新生成还需要同一官方包中的 `.tmp/UAL1_Standard_RM.glb`，用于测量原始动作的移动速度。

生成的 `emma_locomotion.tres` 是原生 Godot AnimationLibrary，可添加到
AnimationPlayer 中编辑。默认地面步行速度为 1.2，按住 Shift 以原先的 5.0 速度快跑，游泳保持 2.9。
游戏表现脚本按速度在待机/行走/快跑间混合，游泳
使用同库动作；所有动画根位移仅作用于骨骼，不驱动玩家碰撞体或存档。
动画播放速度根据原始 root motion 路程与角色比例校准；每个动作使用固定
地面高度偏移，保留原始骨盆起伏和跑步腾空。尚无世界空间锁脚、地形脚部
IK、裙摆与头发物理，不能据此宣称完全消除滑步。

实际渲染在 `.tmp/emma-preview` 生成 48 帧连续侧面步行与快跑和带地面的
正面/背面/侧面预览。数值测试检查动画轨道、有效旋转、手脚相位、原始
绑定姿态保留、F8 切换及游戏位置/碰撞/存档不变；视觉质量单独判断。

模型自带元数据记录作者 `Animeit`，许可字段为 `Redistribution_Prohibited`。
2026-10-22 按用户要求将当前集成版本提交到指定仓库分支；此操作不改变模型原有许可。

验证：`ark_emma_protagonist_test.gd` 检查实际场景默认外观、骨骼、动作变化、
F8 双向切换，以及表现更新不改变玩家碰撞/位置/存档。使用真实渲染运行同一
测试会在 `.tmp/emma-preview` 输出游戏视角与正面、背面、侧面截图。

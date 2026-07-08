# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

修改 Scratch Android APK（3.0.61）的 UI 缩放，让华为等平板可以使用比默认更大的画面；同时新增积木吸附时的音效反馈。所有改动通过 `apk_gen/apk_gen.sh` 一个脚本完成。

`/shared` 目录是 exFAT，**`pip install -e`、符号链接类操作会失败**。详见全局 `~/.claude/CLAUDE.md`。

仓库实际只追踪 `apk_gen/apk_gen.sh`、`.gitignore` 与 `commands.list`，`.apk`、`.keystore`、`.claude/` 都被本地排除——以下操作假设这些文件已就位在工作目录：

- 源 APK：`apk_gen/Scratch 3.0.61-minSdk23.apk`
- 签名密钥：`apk_gen/my-release-key.keystore`（不存在时脚本自动生成）

输出文件：`apk_gen/out/Scratch_3.0.61_modified_${SCALE}x_v3.apk`

完整命令清单见 `commands.list`。

## 目录结构

- `apk_gen/` — APK 改造脚本与工作目录（源 APK、签名密钥、输出 APK 都在这里）
- `anti-sb3/` — `.sb3` 文件解析工具（`sb3_parse.py`），把 Scratch 项目 zip 里的 `project.json` 拆成 raw/pretty 两份 JSON，方便查看/调试
- `class/` — 课堂用 Scratch 作品（`L1-…sb3` ~ `L5-…sb3`），仅作素材，与脚本无关

## 常用命令

```bash
# 修改 APK（默认 2.0x 缩放）
./apk_gen/apk_gen.sh
./apk_gen/apk_gen.sh 1.0    # 原始尺寸
./apk_gen/apk_gen.sh 2.5    # 其他倍数（范围 (0, 100)，>1 放大、<1 缩小）
./apk_gen/apk_gen.sh 3.0
./apk_gen/apk_gen.sh 4.0
./apk_gen/apk_gen.sh 5.0

# 解 .sb3 看 JSON 结构
python3 anti-sb3/sb3_parse.py class/L1-疯狂的小黄猫.sb3
```

## 依赖

- 必需：`apktool`、`keytool`/`jarsigner`（JDK）、`perl`（修补 main.js 用）
- 可选：`zipalign`（未安装时脚本跳过对齐步骤并警告）

缺失时脚本会打印对应 apt 安装命令。

## apk_gen.sh 修改原理（必须读懂才能改对）

脚本对解包后的 APK 做**三处配合**的修改，缺一不可：

### 1. `assets/www/index.html` viewport 元标签

把 `maximum-scale=2.0` 改成 `maximum-scale=10.0, user-scalable=yes`，解除 HTML 层钳制。
真正的缩放由下面 Java 层 `setInitialScale()` 控制，HTML 里 `initial-scale=1.0` 只是兜底。

### 2. `smali*/Editor.smali` 的 4 个常量

Java 层 `WebView.setInitialScale(I)` 按 `densityDpi` 走 4 个分支，常量分别为 `0x64` (1.0x)、`0xc8` (2.0x)、`0x96` (1.5x)、`0x4b` (0.75x)。
脚本把它们一并替换为 `SCALE_VALUE * 100` 的十六进制：

- `<=255` 用 `const/16`；`>255` 用 32 位 `const`
- 替换后必须满足：5 次 `setInitialScale` 调用、4 次目标值加载、零残留原常量——脚本尾部有三项断言校验

`WebView.setInitialScale()` 优先级高于 HTML `initial-scale`。

### 3. `assets/www/main.js` 积木吸附音效（v3 新增）

Scratch 的 `Blockly.BlockAnimations.connectionUiEffect` 在积木吸附时被调用，原实现通过 `audio manager.play("click")` 播放 `click.wav`。
3.0.61 在 Android WebView 上 `audio manager.preload()` 内部用 `.play().then(pause)` 试探，常因 autoplay 限制失败，导致 SOUNDS_ 中的 Audio 元素状态异常，后续 play() 也无声——这是平板上"积木吸附没声音"的根因。

改写为每次吸附时 `new Audio("static/blocks-media/click.wav")` + `.play()`，直接走用户手势（touchend/mouseup）链的 autoplay 通路；失败时回落原 audio manager，桌面浏览器行为不变。

**为什么用 perl 而不是 sed**：`main.js` 是单行 350k+ 字符的 webpack bundle，sed 在超长行 + 含特殊字符（`&&`、`||`、`/`）的替换上有边界问题，perl 更可预测。

## 改 apk_gen.sh 时注意

- viewport 正则只匹配 `maximum-scale=...`，上游改默认值需同步
- smali 常量正则 `(0x64|0xc8|0x96|0x4b)`，若上游版本常量值变化需同步更新
- 校验部分的 `CALL_COUNT=5` 与 `LOAD_COUNT=4` 来自当前分支结构，调整 smali 时需重数
- main.js 替换用 OLD/NEW 字面量匹配 + 出现次数校验（OLD=1→0, NEW=0→1），上游改 `connectionUiEffect` 函数体时需同步更新
- keystore 密码 `123456`、别名 `my-key-alias` 是硬编码的，改名要同步更新脚本中三处常量
- 输出文件名带版本后缀（`_v3`），版本演进时记得同步更新

## 版本演进历史

- v1/v2：仅做 UI 缩放；早期 m5.sh 曾尝试"仅放大字体、布局保持 1.0x"（`html { font-size: ${ROOT_PX}px !important; }` + setInitialScale 强制 100），但 Scratch UI 里大量 frame 用固定 `px` 尺寸，导致部分文字溢出 rem 容器被截断——已弃用
- v3：缩放 + 积木吸附音效（见上文修改原理 §3）

> 历史遗留 APK：`apk_gen/out/Scratch_3.0.61_modified_*x_v2.apk` 与旧 m4.sh/m5.sh 字面命名的脚本均已废弃，可删除。
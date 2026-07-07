# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

修改 Scratch Android APK (3.0.61) 的 UI 缩放，让华为等平板可使用比默认更大的画面。两个并列脚本：
- `m4.sh`：整体缩放（WebView 一并放大，会溢出屏幕）
- `m5.sh`：与 m4.sh 行为一致（均匀缩放所有 frame 与字体），保留 m5.sh 命名便于区分

`/shared` 目录是 exFAT，**`pip install -e`、符号链接类操作会失败**。

> 早期 m5.sh 曾尝试"仅放大字体、布局保持 1.0x"的方案（`html { font-size: ${ROOT_PX}px !important; }` + setInitialScale 强制 100），但用户反馈 frame（块、菜单、舞台）缩放不均匀，部分文字溢出容器被截断。该方案已弃用。

仓库实际只追踪 `m4.sh` 与 `.gitignore`，`.apk`、`.keystore`、`.claude/` 都被本地排除——以下操作假设这些文件已就位在工作目录：

- 源 APK：`Scratch 3.0.61-minSdk23.apk`
- 签名密钥：`my-release-key.keystore`（不存在时脚本会自动生成）

## 常用命令

```bash
# 整体缩放（m4.sh / m5.sh 行为一致，二选一）
./m4.sh 1.0    # 原始尺寸
./m4.sh 2.0    # 默认 2x
./m4.sh 2.5 3.0 4.0 5.0    # 其他倍数（参数范围 (0, 100)，>1 放大、<1 缩小）

./m5.sh 1.0 1.5 2.0 2.5 3.0    # 与 m4.sh 同样的均匀缩放
```

完整命令清单见 `commands.list`。

## 依赖

- 必需：`apktool`、`keytool`/`jarsigner`（来自 JDK）
- 可选：`zipalign`（未安装时脚本跳过对齐步骤并警告）

缺失时脚本会打印对应 apt/dnf 安装命令。

## 修改原理（需要读 m4.sh 多处才能看出来的关键点）

### m4.sh（整体缩放）

脚本对解包后的 APK 做**两处配合**的修改，单做一处不生效：

1. **`assets/www/index.html` viewport 元标签**
   把 `maximum-scale=2.0` 改成 `maximum-scale=10.0, user-scalable=yes`，解除 HTML 层钳制。

2. **`smali*/Editor.smali` 的 4 个常量**
   Java 层 `WebView.setInitialScale(I)` 按 `densityDpi` 走 4 个分支，常量分别为 `0x64` (1.0x)、`0xc8` (2.0x)、`0x96` (1.5x)、`0x4b` (0.75x)。
   脚本把它们一并替换为 `SCALE_VALUE * 100` 的十六进制：
   - `<=255` 用 `const/16`；`>255` 用 32 位 `const`
   - 替换后必须满足：5 次 `setInitialScale` 调用、4 次目标值加载、零残留原常量——脚本尾部有三项断言校验

`WebView.setInitialScale()` 优先级高于 HTML `initial-scale`，所以 HTML 里 `initial-scale=1.0` 只是兜底，真正控制缩放的是 smali 修改。

### m5.sh（均匀缩放，与 m4.sh 行为一致）

实现逻辑与 m4.sh 完全相同：viewport 钳制解除 + smali 4 个常量替换。保留独立脚本是为了让用户可选用 `m5.sh` 这个路径/命名调用。

**为什么不能用"字体专缩"方案**：CSS 注入 `html { font-size: N*16px }` 只能影响 `rem` 单位字体，但 Scratch UI 里大量 frame（块、舞台、菜单）使用固定 `px` 尺寸或基于固定父容器计算，导致放大后部分文字溢出 rem 容器、部分 px 容器不变，缩放不均匀。setInitialScale 把整个 WebView 渲染统一放大 N 倍，所有 frame 与字体按相同比例变化。

## 输出

- `m4.sh` → `Scratch_3.0.61_modified_${SCALE}x.apk`
- `m5.sh` → `Scratch_3.0.61_modified_${SCALE}x.apk`（与 m4.sh 同名格式）

两者均已 jarsigner SHA256 签名（m4.sh 多一步 zipalign），可直接 `adb install` 或拷到平板本地安装。

> 工作目录里若有 `Scratch_3.0.61_font_*.apk` 残留，是旧 m5.sh 字体专缩方案的产物，与新 m5.sh/m4.sh 行为不同，可删除。

## 改 m4.sh / m5.sh 时注意

- 替换常量正则是 `(0x64|0xc8|0x96|0x4b)`，若上游版本常量值变化需同步更新
- 校验部分的 `CALL_COUNT=5` 与 `LOAD_COUNT=4` 来自当前分支结构，调整 smali 时需重数
- keystore 密码 `123456`、别名 `my-key-alias` 是硬编码的，改名要同步更新脚本中三处常量
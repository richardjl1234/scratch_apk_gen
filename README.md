# scratch_apk_gen

为华为等平板定制 **Scratch Android 3.0.61** 的 APK（UI 整体放大、背景中文化、修复积木吸附音效、主题切换），同时托管国内线下课的 Scratch 教学 sb3 课件。

远程仓库：`git@github.com:richardjl1234/scratch_apk_gen.git`

---

## 目录结构

```
.
├── apk_gen/                # APK 定制脚本（核心）
│   ├── apk_gen.sh          #   v3 主脚本：解包 → 补丁 → 重打包 → zipalign → 签名
│   ├── Scratch 3.0.61-minSdk23.apk   #   源 APK（72MB，已入库）
│   ├── my-release-key.keystore       #   签名密钥（不入库；缺失时脚本自动生成）
│   └── out/                          #   产物 APK（不入库）
├── class/                  # 课堂课件 sb3（仅 6 个入库，其余本地保留）
├── anti-sb3/               # sb3 解包工具：抽出并格式化 project.json
├── offline_programs/       # 成体系课件（仅 main 分支）
├── commands.list           # 常用命令速查
└── CLAUDE.md               # Claude Code 项目说明（部分内容已过期，见「技术债」）
```

## 快速开始

依赖：`apktool`、`keytool` / `jarsigner`（JDK）、`zipalign`（可选，缺失时脚本跳过并告警）、`perl`

```bash
cd apk_gen
./apk_gen.sh 2.2          # 默认 2.0；参数范围 (0, 100)，>1 放大、<1 缩小
```

产物：`apk_gen/out/Scratch_3.0.61_modified_2.2x_v3.apk`（已 SHA256 签名，可直接安装）

```bash
adb install -r apk_gen/out/Scratch_3.0.61_modified_2.2x_v3.apk
```

---

## apk_gen.sh 做了什么

脚本对解包后的 APK 做 4 处相互独立的修改，每处都有断言校验，校验不过即退出。

| # | 补丁 | 目标文件 | 机制 |
|---|------|---------|------|
| 1 | 解除 viewport 钳制 | `assets/www/index.html` | `maximum-scale=2.0` → `maximum-scale=10.0, user-scalable=yes` |
| 2 | UI 整体缩放 | `smali*/Editor.smali` | 把 `WebView.setInitialScale(I)` 按 `densityDpi` 走的 4 个分支常量（`0x64`=1.0x、`0xc8`=2.0x、`0x96`=1.5x、`0x4b`=0.75x）一律替换为 `SCALE_VALUE * 100` |
| 3 | 积木吸附音效 | `assets/www/main.js` | 改写 `Blockly.BlockAnimations.connectionUiEffect`：每次吸附新建 `Audio("static/blocks-media/click.wav")` 直接 `play()`，绕开 Android WebView 的 autoplay 限制；失败时回落原 audio manager |
| 4 | 背景名中文化 | `assets/backdrops.json` | 85 个 `name` 字段英文 → 中文 |

### 缩放为什么必须改 smali

`WebView.setInitialScale()` 的优先级高于 HTML 的 `initial-scale`，所以 HTML 里 `initial-scale=1.0` 只是兜底，真正控制缩放的是 smali 修改——**两处配合单做一处都不生效**。

`setInitialScale` 对整个 WebView 渲染统一放大 N 倍，所有 frame 与字体按相同比例变化。早期"只放大字体"的方案（`html { font-size: N*16px }` + 强制 100% 缩放）已废弃：Scratch UI 大量 frame 用固定 `px` 或基于固定父容器计算，放大后部分文字溢出 rem 容器被截断，缩放不均匀。

### 改 smali 时的注意事项

- 替换常量用正则 `(0x64|0xc8|0x96|0x4b)`，上游版本常量变化需同步更新
- smali 指令宽度：目标值 ≤255 用 `const/16`，>255 用 32 位 `const`
- 校验项 `CALL_COUNT=5`（`setInitialScale` 调用数）与 `LOAD_COUNT=4`（目标常量加载数）来自当前分支的代码结构，调整 smali 时要重新计数

---

## 分支

| 分支 | 内容 |
|------|------|
| `version3`（当前） | v3 脚本（上述 4 项补丁）+ 6 个 `class/` 课件 |
| `version4` | v3 + **5 主题切换**：`apk_gen/theme_palettes.js` + 在「编辑」菜单插入 5 个平级菜单项，主题偏好用 `localStorage` 持久化，启动时自动恢复 |
| `main` | `version4` + `offline_programs/` 成套课件 |

---

## 课件说明

sb3 本质是 zip，`project.json` 在压缩包根目录，同级还有 `<md5>.svg` / `<md5>.wav` 素材。

`anti-sb3/sb3_parse.py` 把 `project.json` 解出来，同时输出压缩版和格式化版，便于阅读积木逻辑：

```bash
cd anti-sb3 && python3 sb3_parse.py      # 处理 test.sb3，输出到 sb3_out/
```

---

## 技术债

### 1. sb3 文件「放进去就能用」——未实现

**需求**：把 `.sb3` 拷到平板上某个目录，Scratch App 直接能看见、直接能打开，不需要每次点「导入」。

**结论：技术上可行，但原版 App 做不到「只拷文件」**。已通过反编译 3.0.61 查明的存储结构：

| 内容 | 位置 |
|------|------|
| 项目列表 UI | 原生 `org.scratch.Lobby` Activity + RecyclerView（不是 WebView） |
| 项目索引 | Room 数据库 `/data/data/org.scratch/databases/app-db`，表 `Project(id, title, last_modified)` |
| 项目正文 | `/data/data/org.scratch/app_projects/<id>.json`（**解压后的 project.json**，不是 sb3） |
| 素材 | `/data/data/org.scratch/app_assets/<md5>.svg|.wav`（全局共享） |
| 缩略图 | `/data/data/org.scratch/app_thumbnails/` |

「导入」按钮的完整链路：SAF 选择器 → `ImportTask` 解压 sb3 → `project.json` 写入 `app_projects/<id>.json`、其余条目按 md5 文件名写入 `app_assets/` → 往 `Project` 表插一行。App **既不扫描目录，也不读原始 sb3**，所以把 `.sb3` 拷到 `/sdcard` 任何位置都不可见。

**三条可行路线**：

- **A. 改 APK 自动扫描目录**（推荐，与现有 `apk_gen.sh` 流程一致）
  在 `Lobby.onCreate` 里扫描固定目录（如 `/sdcard/Scratch/Projects/*.sb3`），对未导入过的文件直接调用现成的 `ImportTask`。需要三处改动：
  1. manifest 增加 `READ_EXTERNAL_STORAGE`（当前 manifest 无任何存储权限；无 `uses-sdk` → targetSdk 默认等于 minSdk 23，Android 10 上走 legacy 存储，加权限即可直读 `/sdcard`）
  2. `ImportTask` 增加 file:// 回退：它靠 ContentResolver 查 `_display_name` 列取标题，file:// 下 `query()` 返回 null 会直接报 `IMPORT_GENERIC` 失败
  3. 增加「是否已导入」判定，避免每次启动重复导入

  效果：拷 `.sb3` 进目录 → 重启 App → 项目列表直接出现。

- **B. 不改 App，root 方案**
  `adb shell su` 下解压 sb3、写 `app_projects`/`app_assets`、用 sqlite3 插库。不用改 App 但每台设备都要 root，且要复刻 `ImportTask` 的逻辑。

- **C. 折中：批量导入**
  保留 SAF 选择器，但改为支持多选（`EXTRA_ALLOW_MULTIPLE`），或加「导入本文件夹」按钮（`DocumentsContract` 遍历目录）。改动最小、零权限、无兼容风险，但做不到「放进去就自动出现」。

**建议**：先做 C（风险低、马上能用），确认确实需要「放文件即见」再做 A。

### 2. CLAUDE.md / commands.list 已过期

两者仍在描述早期的 `m4.sh` / `m5.sh` 脚本（已不存在），实际入口是 `apk_gen/apk_gen.sh`。需要同步更新。

### 3. 72MB 的源 APK 直接入库

`apk_gen/Scratch 3.0.61-minSdk23.apk` 超过 GitHub 建议的 50MB（未超 100MB 硬限制），克隆偏慢。可改为 Git LFS，或从版本控制移除、只保留下载脚本。

### 4. 签名密码硬编码

`apk_gen.sh` 里 keystore 密码 `123456`、别名 `my-key-alias` 三处硬编码。属于个人自用工具，暂可接受，但改动时三处必须同步。

### 5. 校验依赖固定计数

`CALL_COUNT=5` / `LOAD_COUNT=4` / 背景名总数等断言都是写死的计数，上游 APK 升级后极易误判失败。需要更稳健的校验或版本化断言。

### 6. 缺少回归验证

所有补丁效果都靠人工在平板上目视确认，没有自动化检查（解包产物比对、smali 断言脚本、UI 截图回归）。

### 7. `class/` 的 ignore 规则状态不一致

`.gitignore` 里写了 `class/**`，但 6 个 sb3 在加规则之前就已入库，因此仍被追踪；其余 20 个课件文件只存在于本地。新增课件默认不会被提交，容易误以为「文件丢了」。

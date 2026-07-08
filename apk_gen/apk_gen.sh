#!/bin/bash

# ============================================================
# Scratch APK Modifier v3 - 专为 3.0.61 APK 优化
# 用法: ./apk_gen.sh [缩放比例]
# 示例: ./apk_gen.sh 2.0   (默认: 2.0)
# 修补内容 (v3 新增):
#   1. HTML viewport 解除 maximum-scale=2.0 钳制
#   2. Java WebView.setInitialScale() 4 个 densityDpi 常量替换
#   3. (v3) 积木吸附音效: 改写 Blockly.BlockAnimations.connectionUiEffect,
#      每次新建 Audio 元素直接播放, 避开 Android WebView 的 autoplay 限制
#      (原 audio manager.preload 在 WebView 上常失败, 用户听不到 click 反馈)
# 参数范围: (0, 100)，>1.0 放大 UI，<1.0 缩小 UI。
# 输出: out/Scratch_3.0.61_modified_${SCALE}x_v3.apk
# ============================================================

# ---------- 配置 ----------
APK_FILE="Scratch 3.0.61-minSdk23.apk"
SCALE_VALUE="${1:-2.0}"          # 默认 2.0 倍
KEYSTORE_PASS="123456"
KEY_ALIAS="my-key-alias"
KEYSTORE_NAME="my-release-key.keystore"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 参数合法性检查 (强制数值转换，非数字会被 awk 当 0)
if ! awk "BEGIN { exit !(($SCALE_VALUE + 0) > 0 && ($SCALE_VALUE + 0) < 100) }"; then
    echo -e "${RED}错误: 缩放比例必须在 (0, 100) 之间，当前: $SCALE_VALUE${NC}"
    exit 1
fi

echo -e "${GREEN}=== Scratch APK Modifier v3 (3.0.61 专用) ===${NC}"
echo -e "缩放比例: ${YELLOW}${SCALE_VALUE}x${NC}"
echo ""

# ---------- 检查依赖 ----------
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}错误: 未找到 $1，请先安装${NC}"
        echo "  Ubuntu/Debian: sudo apt install $2"
        echo "  Fedora:        sudo dnf install $3"
        exit 1
    fi
}

check_dependency "apktool" "apktool" "apktool"
check_dependency "keytool" "default-jdk" "java-latest-openjdk-devel"
check_dependency "jarsigner" "default-jdk" "java-latest-openjdk-devel"

# 检查 zipalign (可选)
if ! command -v zipalign &> /dev/null; then
    echo -e "${YELLOW}警告: 未找到 zipalign，跳过对齐步骤${NC}"
    echo "  安装: sudo apt install zipalign 或 android-sdk"
    USE_ZIPALIGN=false
else
    USE_ZIPALIGN=true
fi

# ---------- 检查输入文件 ----------
if [ ! -f "$APK_FILE" ]; then
    echo -e "${RED}错误: 未找到 $APK_FILE${NC}"
    echo "请将 $APK_FILE 放在当前目录下"
    echo "下载地址: https://apkpure.com/scratch/org.scratch/versions/3.0.61-minSdk23"
    exit 1
fi

# ---------- 清理旧文件 ----------
echo -e "${GREEN}[1/9] 清理旧文件...${NC}"
rm -f org_scratch_unsigned.apk org_scratch_aligned.apk
rm -rf org_scratch_decoded

# ---------- 解包 APK ----------
echo -e "${GREEN}[2/9] 解包 APK...${NC}"
apktool d "$APK_FILE" -o org_scratch_decoded -f > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}解包 APK 失败${NC}"
    echo "尝试使用普通模式解包..."
    apktool d "$APK_FILE" -o org_scratch_decoded -f
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# ---------- 修改 index.html ----------
# 解除 maximum-scale=2.0 钳制 + 允许手势缩放；
# initial-scale 留 1.0 作 fallback，真正起效的是 Java setInitialScale()
echo -e "${GREEN}[3/9] 修改 index.html (解除 maximum-scale 钳制)...${NC}"
INDEX_FILE=$(find org_scratch_decoded/ -name "index.html" | head -1)
if [ -z "$INDEX_FILE" ]; then
    echo -e "${RED}错误: 未找到 index.html${NC}"
    exit 1
fi
echo "  找到: $INDEX_FILE"

sed -i 's|<meta name="viewport"[^>]*>|<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=10.0, user-scalable=yes">|' "$INDEX_FILE"

if grep -q "maximum-scale=10.0" "$INDEX_FILE"; then
    echo -e "  ${GREEN}✓ 解除 maximum-scale 钳制成功${NC}"
else
    echo -e "  ${RED}✗ 修改失败，请检查${NC}"
    exit 1
fi

# ---------- 修改 Editor.smali ----------
# Java 层 WebView.setInitialScale() 覆盖 HTML initial-scale，
# 4 个常量对应不同 densityDpi 分支，全部替换为 SCALE_VALUE*100 的十六进制。
echo -e "${GREEN}[4/9] 修改 Editor.smali (setInitialScale = ${SCALE_VALUE}x)...${NC}"
EDITOR_SMALI=$(find org_scratch_decoded/smali* -name "Editor.smali" | head -1)
if [ -z "$EDITOR_SMALI" ]; then
    echo -e "${RED}错误: 未找到 Editor.smali${NC}"
    exit 1
fi
echo "  找到: $EDITOR_SMALI"

# 计算 SCALE_INT (SCALE_VALUE*100) 和 SCALE_HEX (0x..)
SCALE_INT=$(awk "BEGIN { printf \"%d\", $SCALE_VALUE * 100 }")
SCALE_HEX=$(printf '0x%x' "$SCALE_INT")
echo "  目标整数: ${SCALE_INT}, 十六进制: ${SCALE_HEX}"

# smali 指令宽度：≤255 用 const/16，>255 用 const (32-bit)
if [ "$SCALE_INT" -le 255 ]; then
    NEW_INST="const/16"
else
    NEW_INST="const"
fi

# 替换 4 个原始常量 (0x64/0xc8/0x96/0x4b) → SCALE_HEX
# 用 @ 作分隔符，避免与 ERE 的 | 交替冲突
sed -i -E "s@^    (const/16|const) ([vp][0-9]+), (0x64|0xc8|0x96|0x4b)\$@    $NEW_INST \2, $SCALE_HEX@" "$EDITOR_SMALI"

# 校验：不应残留任何"非目标"原值 (0xc8/0x96/0x4b 之一，且不等于 SCALE_HEX)
LEFTOVER=$(grep -cE "^    (const/16|const) [vp][0-9]+, 0x(c8|96|4b)\$" "$EDITOR_SMALI")
if [ "$LEFTOVER" -gt 0 ]; then
    echo -e "  ${RED}✗ 替换失败，残留 $LEFTOVER 处非目标原始常量${NC}"
    exit 1
fi

# 校验：setInitialScale 调用次数 (分支结构未动，应仍为 5)
CALL_COUNT=$(grep -c "WebView;->setInitialScale(I)V" "$EDITOR_SMALI")
echo -e "  setInitialScale 调用数: ${CALL_COUNT} (预期 5)"

# 校验：应加载 SCALE_HEX 的指令数 (4 个原始位置 + v3 在 cond_3 复用，共 4 次加载)
LOAD_COUNT=$(grep -cE "^    $NEW_INST [vp][0-9]+, $SCALE_HEX\$" "$EDITOR_SMALI")
echo -e "  加载 ${SCALE_HEX} 的指令数: ${LOAD_COUNT} (预期 4)"
echo -e "  ${GREEN}✓ smali 修补完成${NC}"

# ---------- 修改 main.js (积木吸附音效) ----------
# Scratch 默认的 connectionUiEffect 通过 audio manager 播放 click.wav，
# 但 audio manager.preload() 内部调用 .play().then(pause) 在 Android WebView
# 上常因 autoplay 限制失败，导致 SOUNDS_ 中的 Audio 元素状态异常，
# 后续 play() 也无声。这是 3.0.61 在平板上"积木吸附没声音"的根因。
# 这里改为: 每次吸附时新建一个 Audio 元素直接 play()，
# 用户手势 (touchend/mouseup) 链下 WebView 允许 autoplay，可靠出声。
# 失败时回落原 audio manager，保证桌面浏览器行为不变。
echo -e "${GREEN}[5/9] 修改 main.js (积木吸附音效)...${NC}"
MAIN_JS=$(find org_scratch_decoded/assets/www -maxdepth 1 -name "main.js" | head -1)
if [ -z "$MAIN_JS" ]; then
    echo -e "${RED}错误: 未找到 main.js${NC}"
    exit 1
fi
echo "  找到: $MAIN_JS"

# 用 perl 而不是 sed：main.js 是单行 350k+ 字符，sed 在超长行上有边界问题，
# 且 perl 对引号/反斜杠的处理更可预测。
if ! command -v perl &> /dev/null; then
    echo -e "${RED}错误: 未找到 perl，请先安装${NC}"
    echo "  Ubuntu/Debian: sudo apt install perl"
    exit 1
fi

OLD='Blockly.BlockAnimations.connectionUiEffect=function(a){a.workspace.getAudioManager().play("click")};'
NEW='Blockly.BlockAnimations.connectionUiEffect=function(a){try{var s=new Audio("static/blocks-media/click.wav");s.volume=.7;var p=s.play();if(p&&p.catch)p.catch(function(){})}catch(e){try{a.workspace.getAudioManager().play("click")}catch(_){}}};'

OLD_COUNT_BEFORE=$(grep -oF "$OLD" "$MAIN_JS" | wc -l)
if [ "$OLD_COUNT_BEFORE" -ne 1 ]; then
    echo -e "${RED}✗ 原 connectionUiEffect 代码出现 $OLD_COUNT_BEFORE 次 (预期 1)，跳过修补${NC}"
    exit 1
fi

perl -i -pe "s#\Q$OLD\E#$NEW#" "$MAIN_JS"

OLD_COUNT_AFTER=$(grep -oF "$OLD" "$MAIN_JS" | wc -l)
NEW_COUNT_AFTER=$(grep -oF "$NEW" "$MAIN_JS" | wc -l)
if [ "$OLD_COUNT_AFTER" -ne 0 ] || [ "$NEW_COUNT_AFTER" -ne 1 ]; then
    echo -e "${RED}✗ 修补校验失败 (OLD=$OLD_COUNT_AFTER, NEW=$NEW_COUNT_AFTER)${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓ 吸附音效修补完成 (OLD=$OLD_COUNT_BEFORE→0, NEW=0→$NEW_COUNT_AFTER)${NC}"

# ---------- 重新打包 ----------
echo -e "${GREEN}[6/9] 重新打包 APK...${NC}"
apktool b org_scratch_decoded -o org_scratch_unsigned.apk --use-aapt2 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}警告: aapt2 打包失败，尝试普通打包...${NC}"
    apktool b org_scratch_decoded -o org_scratch_unsigned.apk > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}重新打包失败${NC}"
        echo "尝试手动检查错误:"
        apktool b org_scratch_decoded -o org_scratch_unsigned.apk
        exit 1
    fi
fi

# ---------- zipalign 对齐 ----------
if [ "$USE_ZIPALIGN" = true ]; then
    echo -e "${GREEN}[7/9] zipalign 对齐 APK...${NC}"
    zipalign -v -p 4 org_scratch_unsigned.apk org_scratch_aligned.apk > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        SIGN_APK="org_scratch_aligned.apk"
        echo -e "  ${GREEN}✓ 对齐完成${NC}"
    else
        echo -e "  ${YELLOW}⚠ 对齐失败，使用未对齐版本${NC}"
        SIGN_APK="org_scratch_unsigned.apk"
    fi
else
    SIGN_APK="org_scratch_unsigned.apk"
fi

# ---------- 生成或复用 keystore ----------
echo -e "${GREEN}[8/9] 准备签名密钥...${NC}"
if [ ! -f "$KEYSTORE_NAME" ]; then
    echo "  生成新的 keystore..."
    keytool -genkey -v -keystore "$KEYSTORE_NAME" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 30000 \
        -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
        -dname "CN=Scratch User, OU=Education, O=Personal, L=City, S=State, C=US" \
        -noprompt > /dev/null 2>&1
    echo -e "  ${GREEN}✓ 已生成: $KEYSTORE_NAME${NC}"
else
    echo "  使用已有: $KEYSTORE_NAME"
fi

# ---------- 签名 (SHA256) ----------
echo -e "${GREEN}[9/9] 签名 APK (SHA256)...${NC}"
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
    -keystore "$KEYSTORE_NAME" \
    -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
    "$SIGN_APK" "$KEY_ALIAS" 2>&1 | grep -E "(signing:|jar signed|Warning:)" | head -10

# ---------- 验证 ----------
echo ""
echo -e "${GREEN}验证签名...${NC}"
if jarsigner -verify "$SIGN_APK" 2>&1 | grep -q "jar verified"; then
    echo -e "${GREEN}✓ 签名有效${NC}"
else
    echo -e "${RED}✗ 签名验证失败${NC}"
    exit 1
fi

# ---------- 重命名最终文件 ----------
OUTPUT_APK="out/Scratch_3.0.61_modified_${SCALE_VALUE}x_v3.apk"
mv "$SIGN_APK" "$OUTPUT_APK"

# ---------- 显示结果 ----------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "输出文件: ${YELLOW}$OUTPUT_APK${NC}"
echo -e "文件大小: $(du -h "$OUTPUT_APK" | cut -f1)"
echo -e "缩放比例: ${YELLOW}${SCALE_VALUE}x${NC}"
echo -e "源版本:   ${YELLOW}3.0.61-minSdk23${NC}"
echo ""
echo -e "请将 $OUTPUT_APK 传到华为平板安装"

# ---------- 清理 ----------
read -p "是否清理临时文件? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf org_scratch_decoded org_scratch_unsigned.apk
    echo -e "${GREEN}已清理临时文件${NC}"
fi

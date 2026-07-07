#!/bin/bash

# ============================================================
# Scratch APK Modifier v7 - 均匀缩放模式 (m5.sh)
# 用法: ./m5.sh [缩放比例]
# 示例: ./m5.sh 2.0   (默认: 2.0)
# 通过 WebView.setInitialScale() 把整个 WebView 均匀放大，
# 所有 frame (块、菜单、舞台) 与字体一起按 N 倍缩放，
# 与 m4.sh 行为一致——但保留 m5.sh 的命名便于区分。
# 适用: 用户想要 m4.sh 的视觉效果，但希望用 m5.sh 这个文件名/路径调用。
# 参数范围: (0, 100)
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

echo -e "${GREEN}=== Scratch APK Modifier v7 (均匀缩放模式 / m5.sh) ===${NC}"
echo -e "缩放比例: ${YELLOW}${SCALE_VALUE}x${NC}"
echo -e "效果: 所有 frame 与字体按 ${SCALE_VALUE} 倍均匀放大 (与 m4.sh 一致)"
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

if ! command -v zipalign &> /dev/null; then
    echo -e "${YELLOW}警告: 未找到 zipalign，跳过对齐步骤${NC}"
    USE_ZIPALIGN=false
else
    USE_ZIPALIGN=true
fi

# ---------- 检查输入文件 ----------
if [ ! -f "$APK_FILE" ]; then
    echo -e "${RED}错误: 未找到 $APK_FILE${NC}"
    echo "请将 $APK_FILE 放在当前目录下"
    exit 1
fi

# ---------- 清理旧文件 ----------
echo -e "${GREEN}[1/7] 清理旧文件...${NC}"
rm -f org_scratch_unsigned.apk org_scratch_aligned.apk
rm -rf org_scratch_decoded

# ---------- 解包 APK ----------
echo -e "${GREEN}[2/7] 解包 APK...${NC}"
apktool d "$APK_FILE" -o org_scratch_decoded -f > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}解包 APK 失败${NC}"
    apktool d "$APK_FILE" -o org_scratch_decoded -f
    exit 1
fi

# ---------- 修改 index.html ----------
# 解除 maximum-scale=2.0 钳制 + 允许手势缩放；
# initial-scale 留 1.0 作 fallback，真正起效的是 Java setInitialScale()
echo -e "${GREEN}[3/7] 修改 index.html (解除 maximum-scale 钳制)...${NC}"
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
# 这样所有 frame (块、菜单、舞台) 与字体一起按 N 倍均匀放大。
echo -e "${GREEN}[4/7] 修改 Editor.smali (setInitialScale = ${SCALE_VALUE}x, 均匀缩放)...${NC}"
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

# ---------- 重新打包 ----------
echo -e "${GREEN}[5/7] 重新打包 APK...${NC}"
apktool b org_scratch_decoded -o org_scratch_unsigned.apk --use-aapt2 > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}警告: aapt2 打包失败，尝试普通打包...${NC}"
    apktool b org_scratch_decoded -o org_scratch_unsigned.apk > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}重新打包失败${NC}"
        apktool b org_scratch_decoded -o org_scratch_unsigned.apk
        exit 1
    fi
fi

# ---------- zipalign 对齐 ----------
if [ "$USE_ZIPALIGN" = true ]; then
    echo -e "${GREEN}[6/7] zipalign 对齐 APK...${NC}"
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

# ---------- 签名 ----------
echo -e "${GREEN}[7/7] 签名 APK (SHA256)...${NC}"
if [ ! -f "$KEYSTORE_NAME" ]; then
    echo "  生成新的 keystore..."
    keytool -genkey -v -keystore "$KEYSTORE_NAME" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 30000 \
        -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
        -dname "CN=Scratch User, OU=Education, O=Personal, L=City, S=State, C=US" \
        -noprompt > /dev/null 2>&1
    echo -e "  ${GREEN}✓ 已生成: $KEYSTORE_NAME${NC}"
fi

jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
    -keystore "$KEYSTORE_NAME" \
    -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
    "$SIGN_APK" "$KEY_ALIAS" 2>&1 | grep -E "(signing:|jar signed|Warning:)" | head -10

# ---------- 验证 ----------
echo ""
if jarsigner -verify "$SIGN_APK" 2>&1 | grep -q "jar verified"; then
    echo -e "${GREEN}✓ 签名有效${NC}"
else
    echo -e "${RED}✗ 签名验证失败${NC}"
    exit 1
fi

# ---------- 重命名 ----------
OUTPUT_APK="Scratch_3.0.61_modified_${SCALE_VALUE}x.apk"
mv "$SIGN_APK" "$OUTPUT_APK"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 完成 (均匀缩放模式 / m5.sh)!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "输出文件: ${YELLOW}$OUTPUT_APK${NC}"
echo -e "文件大小: $(du -h "$OUTPUT_APK" | cut -f1)"
echo -e "缩放比例: ${YELLOW}${SCALE_VALUE}x${NC} (frame 与字体均匀放大)"
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
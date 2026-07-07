import zipfile
import json
import os

def extract_and_format_sb3(sb3_file_path, output_dir="sb3_out"):
    # 创建输出文件夹
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # 1. 从sb3压缩包读取 project.json
    with zipfile.ZipFile(sb3_file_path, "r") as zf:
        raw_json_bytes = zf.read("project.json")
    
    # 2. 原始未格式化json（一行压缩版）
    raw_json_path = os.path.join(output_dir, "project_raw.json")
    with open(raw_json_path, "wb") as f:
        f.write(raw_json_bytes)

    # 3. 格式化、带缩进的可读json
    data = json.loads(raw_json_bytes)
    pretty_json_path = os.path.join(output_dir, "project_pretty.json")
    with open(pretty_json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"提取完成！")
    print(f"原始压缩JSON：{raw_json_path}")
    print(f"格式化可读JSON：{pretty_json_path}")

# ========== 使用示例 ==========
# 替换成你的 sb3 文件路径
extract_and_format_sb3("test.sb3")


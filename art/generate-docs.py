import re
import sys


def parse_haxe_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    functions = []
    lines = content.splitlines()

    current_comments = []
    in_block_comment = False

    func_pattern = re.compile(
        r"^\s*(?:public|private)?\s*(?:override)?\s*function\s+([a-zA-Z0-9_]+)\s*\((.*?)\)(?:\s*:\s*([a-zA-Z0-9_<>\.\?\[\]\s]+))?"
    )

    i = 0
    while i < len(lines):
        line = lines[i].strip()

        # Handle block comments (/** ... */)
        if line.startswith("/*"):
            comment_block = []
            if line.endswith("*/"):
                clean_line = (
                    line.replace("/*", "")
                    .replace("*/", "")
                    .lstrip("* ")
                    .strip()
                )
                if clean_line:
                    comment_block.append(clean_line)
            else:
                in_block_comment = True
                clean_line = line.replace("/*", "").lstrip("* ").strip()
                if clean_line:
                    comment_block.append(clean_line)
                i += 1
                while i < len(lines) and in_block_comment:
                    bl_line = lines[i].strip()
                    if "*/" in bl_line:
                        in_block_comment = False
                        bl_line = bl_line.replace("*/", "")
                    # Clean leading asterisks and spaces consistently
                    bl_line = bl_line.lstrip("* ").strip()
                    if bl_line:
                        comment_block.append(bl_line)
                    i += 1
            current_comments.extend(comment_block)
            continue

        elif line.startswith("//"):
            comment_text = line[2:].strip()
            current_comments.append(comment_text)
            i += 1
            continue

        elif line == "":
            i += 1
            continue

        match = func_pattern.match(lines[i])
        if match:
            func_name = match.group(1)
            func_args_raw = match.group(2).strip()
            func_return = match.group(3).strip() if match.group(3) else "Void"

            general_desc = []
            params_doc = {}

            for c in current_comments:
                if c.startswith("@param"):
                    parts = c.split(maxsplit=2)
                    if len(parts) >= 2:
                        p_name = parts[1]
                        p_desc = parts[2] if len(parts) > 2 else ""
                        params_doc[p_name] = p_desc
                else:
                    general_desc.append(c)

            functions.append(
                {
                    "name": func_name,
                    "args": func_args_raw,
                    "return_type": func_return,
                    "description": general_desc,
                    "params_doc": params_doc,
                }
            )
            current_comments = []
        else:
            current_comments = []

        i += 1

    return functions


def generate_markdown(functions, output_path="StageAPI_Docs.md"):
    md_content = "# API Documentation\n\n"
    md_content += "\n## Functions\n\n"

    if not functions:
        md_content += "*No functions found.*\n"

    for func in functions:
        md_content += f"### `{func['name']}`\n\n"

        # 1. Function Signature first (or description first—let's put description then signature)
        if func["description"]:
            for line in func["description"]:
                md_content += f"{line} "
            md_content += "\n\n"
        else:
            md_content += "*No description provided.*\n\n"

        # 2. Function Signature Code Block
        md_content += "```haxe\n"
        md_content += f"function {func['name']}({func['args']}):{func['return_type']}\n"
        md_content += "```\n\n"

        # 3. Parameters Table
        if func["params_doc"]:
            md_content += "**Parameters:**\n\n"
            md_content += "| Parameter | Description |\n"
            md_content += "| :--- | :--- |\n"
            for p_name, p_desc in func["params_doc"].items():
                md_content += f"| `{p_name}` | {p_desc} |\n"
            md_content += "\n"

        md_content += "---\n\n"

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(md_content)

    print(f"Successfully fixed and generated documentation at: {output_path}")


if __name__ == "__main__":
    target_file = (
        sys.argv[1] if len(sys.argv) > 1 else "StageAPI.hx"
    )
    funcs = parse_haxe_file(target_file)
    generate_markdown(funcs)
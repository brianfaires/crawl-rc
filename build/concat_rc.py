from pathlib import Path

base_dir = Path(__file__).parent.parent
processed_files = set()

# Paths
init_file = base_dir / "rc" / "init.txt"
core_dir = base_dir / "lua" / "core"
output_dir = base_dir / "bin"
output_dir.mkdir(parents=True, exist_ok=True)

# Patterns
rc_prefix = "include = crawl-rc/"
lua_prefix = "lua_file = crawl-rc/"

def get_comment_char(file_path):
    return "#" if file_path and file_path.suffix == ".lua" else "#"

def write_header(file_path, outfile):
    comment = get_comment_char(file_path)
    name = str(file_path).replace(str(base_dir) + "/", "")
    outfile.write(f"\n{comment * 35} Begin {name} {comment * 35}\n")
    outfile.write(f"{comment * 15} https://github.com/brianfaires/crawl-rc/ {comment * 15}\n")

def write_footer(file_path, outfile):
    comment = get_comment_char(file_path)
    name = str(file_path).replace(str(base_dir) + "/", "")
    outfile.write(f"\n{comment * 31} End {name} {comment * 31}\n{comment * 90}\n")

def write_resume(file_path, outfile):
    comment = get_comment_char(file_path)
    name = str(file_path).replace(str(base_dir) + "/", "")
    outfile.write(f"\n{comment * 2} (Resuming {name}) {comment * 2}\n")

def parse_include(line):
    if line.startswith(rc_prefix):
        return base_dir / line[len(rc_prefix):]
    elif line.startswith(lua_prefix):
        return base_dir / line[len(lua_prefix):]
    return None

def process_file(file_path, outfile):
    if file_path in processed_files:
        return
    processed_files.add(file_path)
    print(f"Processing: {file_path.name}")
    is_lua = file_path.suffix == ".lua"
    
    with open(file_path, 'r', encoding='utf-8') as infile:
        write_header(file_path, outfile)
        if is_lua:
            outfile.write("{\n")
        
        for line in infile:
            if line.startswith(rc_prefix) or line.startswith(lua_prefix):
                include_path = parse_include(line.strip())
                if include_path and include_path.exists() and include_path not in processed_files:
                    process_file(include_path, outfile)
                else:
                    outfile.write(line)
            else:
                outfile.write(line)
        
        if is_lua:
            outfile.write("\n}")
        write_footer(file_path, outfile)

def process_init_file(infile, outfile):
    resume = False
    for line in infile:
        if line.startswith(lua_prefix):
            include_path = parse_include(line.strip())
            if include_path and include_path.exists():
                process_file(include_path, outfile)
                resume = True
            else:
                outfile.write(line)
        elif line.startswith(rc_prefix):
            include_path = parse_include(line.strip())
            if include_path and include_path.exists():
                process_file(include_path, outfile)
                resume = True
            else:
                outfile.write(line)
        else:
            if resume:
                write_resume(init_file, outfile)
                resume = False
            outfile.write(line)

print("Building buehler.rc...")
with open(init_file, 'r') as infile:
    with open(output_dir / "buehler.rc", 'w') as outfile:
        process_init_file(infile, outfile)

print("Building core.rc...")
processed_files.clear()
with open(output_dir / "core.rc", 'w') as outfile:
    for filename in ["config.lua", "constants.lua", "util.lua", "data.lua", "brc.lua"]:
        file_path = core_dir / filename
        if file_path.exists():
            process_file(file_path, outfile)

print(f"Done! processed_files {len(processed_files)} files.")

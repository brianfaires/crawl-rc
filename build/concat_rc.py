from pathlib import Path

base_dir = Path(__file__).parent.parent

MAX_LINE_LENGTH = 99

# Paths
init_file = base_dir / "rc" / "init.txt"
core_dir = base_dir / "lua" / "core"
pickup_alert_dir = base_dir / "lua" / "features" / "pickup-alert"
output_dir = base_dir / "bin"
GITHUB_PREFIX = "https://github.com/brianfaires/crawl-rc/blob/main/"

# Patterns
rc_prefix = "include = crawl-rc/"
lua_prefix = "lua_file = crawl-rc/"

def get_comment_char(file_path):
    return "#" if file_path and file_path.suffix == ".lua" else "#"

def write_header(file_path, outfile):
    print(file=outfile)

    comment = get_comment_char(file_path)
    file_name = str(file_path).replace(str(base_dir) + "/", "")
    lines = [f" Begin {file_name} ", f" {GITHUB_PREFIX}{file_name} "]
    for line in lines:
        num_chars = MAX_LINE_LENGTH - len(line)
        post_chars = num_chars // 2
        pre_chars = num_chars - post_chars
        print(f"{comment * pre_chars}{line}{comment * post_chars}", file=outfile)

def write_footer(file_path, outfile):
    if file_path.suffix != ".lua":
        print(file=outfile)
    comment = get_comment_char(file_path)
    name = str(file_path).replace(str(base_dir) + "/", "")
    end_msg = f" End {name} "
    num_chars = MAX_LINE_LENGTH - len(end_msg)
    post_chars = num_chars // 2
    pre_chars = num_chars - post_chars
    print(f"{comment * pre_chars}{end_msg}{comment * post_chars}", file=outfile)
    print(f"{comment * MAX_LINE_LENGTH}", file=outfile)

def parse_include(line):
    if line.startswith(rc_prefix):
        return base_dir / line[len(rc_prefix):]
    elif line.startswith(lua_prefix):
        return base_dir / line[len(lua_prefix):]
    return None

def process_file(file_path, outfile, processed_files):
    if file_path in processed_files:
        return
    processed_files.add(file_path)
    print(f"Processing: {file_path.name}")
    is_lua = file_path.suffix == ".lua"
    
    with open(file_path, 'r', encoding='utf-8') as infile:
        write_header(file_path, outfile)
        if is_lua:
            print("{", file=outfile)
        
        for line in infile:
            if line.startswith(rc_prefix) or line.startswith(lua_prefix):
                include_path = parse_include(line.strip())
                if include_path and include_path.exists() and include_path not in processed_files:
                    process_file(include_path, outfile, processed_files)
                else:
                    print(line, end="", file=outfile)
            else:
                print(line, end="", file=outfile)
        
        if is_lua:
            print("\n}", file=outfile)
        write_footer(file_path, outfile)

def process_line(line, outfile, processed_files):
    """Process a single line, handling includes and returns True if a file was processed."""
    if line.startswith(lua_prefix):
        include_path = parse_include(line.strip())
        if include_path and include_path.exists():
            process_file(include_path, outfile, processed_files)
            return True
        else:
            print(line, end="", file=outfile)
    elif line.startswith(rc_prefix):
        include_path = parse_include(line.strip())
        if include_path and include_path.exists():
            process_file(include_path, outfile, processed_files)
            return True
        else:
            print(line, end="", file=outfile)
    else:
        print(line, end="", file=outfile)
    return False

def process_init_file(infile, outfile, processed_files):
    # skip first 5 lines of init.txt, assuming they still start with ":crawl"
    for _ in range(5):
        line = infile.readline()
        if not (line.find("crawl.mpr(") or line.find("crawl.more()")):
            process_line(line, outfile, processed_files)
        
    for line in infile:
        process_line(line, outfile, processed_files)

def main():
    """Main entry point."""
    output_dir.mkdir(parents=True, exist_ok=True)
    processed_files = set()
    
    print("Building buehler.rc...")
    with open(init_file, 'r') as infile:
        with open(output_dir / "buehler.rc", 'w') as outfile:
            process_init_file(infile, outfile, processed_files)
    
    print(f"Done! processed_files {len(processed_files)} files.")

if __name__ == "__main__":
    main()

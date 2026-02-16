"""Build script to concatenate RC files into a single output file.

This script processes init.txt and recursively includes referenced files,
wrapping Lua files in braces and adding header/footer comments.
"""

import logging
from pathlib import Path
from typing import Set, TextIO, Optional

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

# Constants
MAX_LINE_LENGTH = 99
BASE_DIR = Path(__file__).parent.parent
INIT_FILE = BASE_DIR / "rc" / "init.txt"
OUTPUT_DIR = BASE_DIR / "bin"
OUTPUT_FILE = OUTPUT_DIR / "buehler.rc"
GITHUB_PREFIX = "https://github.com/brianfaires/crawl-rc/blob/main/"

# Include patterns
RC_PREFIX = "include = crawl-rc/"
LUA_PREFIX = "lua_file = crawl-rc/"

# Init file processing
INIT_SKIP_LINES = 5
INIT_SKIP_PATTERNS = ("crawl.mpr(", "crawl.more()")

COMMENT_CHAR = "#"


def get_relative_path(file_path: Path) -> str:
    return str(file_path.relative_to(BASE_DIR))


def write_header(file_path: Path, outfile: TextIO) -> None:
    print(file=outfile)
    
    file_name = get_relative_path(file_path)
    lines = [
        f" Begin {file_name} ",
        f" {GITHUB_PREFIX}{file_name} "
    ]
    
    for line in lines:
        num_chars = MAX_LINE_LENGTH - len(line)
        post_chars = num_chars // 2
        pre_chars = num_chars - post_chars
        print(
            f"{COMMENT_CHAR * pre_chars}{line}{COMMENT_CHAR * post_chars}",
            file=outfile
        )


def write_footer(file_path: Path, outfile: TextIO) -> None:
    if file_path.suffix != ".lua":
        print(file=outfile)
    
    file_name = get_relative_path(file_path)
    end_msg = f" End {file_name} "
    num_chars = MAX_LINE_LENGTH - len(end_msg)
    post_chars = num_chars // 2
    pre_chars = num_chars - post_chars
    
    print(
        f"{COMMENT_CHAR * pre_chars}{end_msg}{COMMENT_CHAR * post_chars}",
        file=outfile
    )
    print(f"{COMMENT_CHAR * MAX_LINE_LENGTH}", file=outfile)


def parse_include(line: str) -> Optional[Path]:
    line = line.strip()
    if line.startswith(RC_PREFIX):
        return BASE_DIR / line[len(RC_PREFIX):]
    elif line.startswith(LUA_PREFIX):
        return BASE_DIR / line[len(LUA_PREFIX):]
    return None


def process_file(
    file_path: Path,
    outfile: TextIO,
    processed_files: Set[Path]
) -> None:
    """Process a file, handling includes and writing content.
    
    Args:
        file_path: Path to the file to process
        outfile: Output file handle
        processed_files: Set of already processed files to avoid cycles
    """
    if file_path in processed_files:
        logger.warning(f"Skipping already processed file: {file_path}")
        return
    
    processed_files.add(file_path)
    logger.info(f"Processing: {file_path.name}")
    
    is_lua = file_path.suffix == ".lua"
    
    with open(file_path, 'r', encoding='utf-8') as infile:
        write_header(file_path, outfile)
        
        if is_lua:
            print("{", file=outfile)
        
        for line in infile:
            if line.startswith(RC_PREFIX) or line.startswith(LUA_PREFIX):
                include_path = parse_include(line)
                if (include_path and include_path.exists() and
                        include_path not in processed_files):
                    process_file(include_path, outfile, processed_files)
                else:
                    print(line, end="", file=outfile)
            else:
                print(line, end="", file=outfile)
        
        if is_lua:
            print("\n}", file=outfile)
        
        write_footer(file_path, outfile)


def process_line(
    line: str,
    outfile: TextIO,
    processed_files: Set[Path]
) -> bool:
    include_path = parse_include(line)
    
    if include_path and include_path.exists():
        process_file(include_path, outfile, processed_files)
        return True
    else:
        print(line, end="", file=outfile)
        return False


def process_init_file(
    infile: TextIO,
    outfile: TextIO,
    processed_files: Set[Path]
) -> None:
    """Process the init.txt file with special handling.
    
    Skips the first few lines that may contain crawl commands (ie warnings for running in multi-file mode).
    
    Args:
        infile: Input file handle for init.txt
        outfile: Output file handle
        processed_files: Set of already processed files
    """
    # Read first N lines
    skip_lines = []
    for _ in range(INIT_SKIP_LINES):
        line = infile.readline()
        skip_lines.append(line)
    
    # Check if each line should be skipped (contains pattern, is empty, or only has {/})
    def should_skip_line(line: str) -> bool:
        stripped = line.strip()
        return (
            any(pattern in line for pattern in INIT_SKIP_PATTERNS) or
            not stripped or
            stripped in ("{", "}")
        )
    
    # Skip the entire block only if EVERY line should be skipped
    should_skip = all(should_skip_line(line) for line in skip_lines)
    
    # Process the lines only if we're not skipping
    if not should_skip:
        for line in skip_lines:
            process_line(line, outfile, processed_files)
    
    # Process remaining lines
    for line in infile:
        process_line(line, outfile, processed_files)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    processed_files: Set[Path] = set()
    
    logger.info("Building buehler.rc...")
    
    with open(INIT_FILE, 'r', encoding='utf-8') as infile:
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
            process_init_file(infile, outfile, processed_files)
    
    logger.info(f"Done! Processed {len(processed_files)} files.")


if __name__ == "__main__":
    main()

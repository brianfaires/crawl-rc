import re


INIT_FILE_NAME = "init.txt"
OUT_FILE_NAME = "buehler.rc"
REPO_ROOT = "crawl-rc/"
RC_PREFIX =  f"include = {REPO_ROOT}"
LUA_PREFX = f"lua_file = {REPO_ROOT}"
LOAD_LUA_PREFIX = "loadfile("

def write_header(cur_file, file_name, outfile):
  is_lua = cur_file.name.endswith(".lua")
  comment_char = "-" if is_lua else "#"
  outfile.write(f"\n{comment_char * 35} Begin {file_name} {comment_char * 35}\n")
  outfile.write(f"{comment_char * 15} https://github.com/brianfaires/crawl-rc/ {comment_char * 15}\n")

def write_footer(cur_file, file_name, outfile):
  is_lua = cur_file.name.endswith(".lua")
  comment_char = "-" if is_lua else "#"
  outfile.write(f"\n{comment_char * 31} End {file_name} {comment_char * 31}\n")
  outfile.write(f"{comment_char * 90}\n")
 
def write_resume(cur_file, outfile):
  is_lua = cur_file.name.endswith(".lua")
  comment_char = "-" if is_lua else "#"
  outfile.write(f"\n{comment_char * 2} (Resuming {cur_file.name}) {comment_char*2}\n")

def is_new_file(line, prev_files):
  if line.startswith(LOAD_LUA_PREFIX):
    line = line.split('"')[1]
  file_name = line.replace(RC_PREFIX, "").strip()
  file_name = file_name.replace(LUA_PREFX, "").strip()
  file_name = file_name.replace(REPO_ROOT, "").strip()

  if file_name not in prev_files:
    prev_files.append(file_name)
    return file_name
  return None

def recurse_write_lines(infile, outfile, prev_files):
  print(f"Processing {infile.name}")
  resume = False
  for line in infile.readlines():
    if (line.startswith(RC_PREFIX)):
      # RC to RC
      file_name = is_new_file(line, prev_files)
      if file_name:
        with open(file_name, 'r') as inc_file:
          write_header(infile, file_name, outfile)
          recurse_write_lines(inc_file, outfile, prev_files)
          write_footer(infile, file_name, outfile)
          resume = True
    elif (line.startswith(LUA_PREFX)):
      # RC to Lua
      file_name = is_new_file(line, prev_files)
      if file_name:
        with open(file_name, 'r') as inc_file:
          write_header(infile, file_name, outfile)
          outfile.write("{\n")
          recurse_write_lines(inc_file, outfile, prev_files)
          outfile.write("\n}")
          write_footer(infile, file_name, outfile)
          resume = True
    elif line.startswith(LOAD_LUA_PREFIX):
      # Lua to Lua
      file_name = is_new_file(line, prev_files)
      if file_name:
        with open(file_name, 'r') as inc_file:
          write_header(infile, file_name, outfile)
          recurse_write_lines(inc_file, outfile, prev_files)
          write_footer(infile, file_name, outfile)
          resume = True
    else:
      if resume:
        write_resume(infile, outfile)
        resume = False
      outfile.writelines(line)


files_opened = [INIT_FILE_NAME]
with open(INIT_FILE_NAME, 'r') as readfile:
    with open(OUT_FILE_NAME, 'w') as outfile:
        recurse_write_lines(readfile, outfile, files_opened)

input(f"\nDone writing to {OUT_FILE_NAME}\nPress enter to close.")

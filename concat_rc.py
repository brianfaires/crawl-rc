INIT_FILE_NAME = "init.txt"
OUT_FILE_NAME = "buehler.rc"
REPO_ROOT = "crawl-rc/"
RC_PREFIX =  f"include = {REPO_ROOT}"
LUA_PREFX = f"lua_file = {REPO_ROOT}"

def recurse_write_lines(infile, outfile, prevfiles):
  print("Writing " + infile.name)
  is_lua = infile.name.endswith(".lua")
  comment_char = "-" if is_lua else "#"

  # Write header
  outfile.write(f"{comment_char * 35} Begin {infile.name} {comment_char * 35}\n")
  outfile.write(f"{comment_char * 15} https://github.com/brianfaires/crawl-rc/ {comment_char * 15}\n")
   
  resume = False
  for line in infile.readlines():
    if (line.startswith(RC_PREFIX)):
      inc_filename = line.replace(RC_PREFIX, "").strip()
      if inc_filename not in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          recurse_write_lines(inc_file, outfile, prevfiles)
          resume = True
    elif (line.startswith(LUA_PREFX)):
      inc_filename = line.replace(LUA_PREFX, "").strip()
      if inc_filename not in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          outfile.write("{\n")
          recurse_write_lines(inc_file, outfile, prevfiles)
          outfile.write("}\n\n")
          resume = True
    elif line.startswith("loadfile("):
      inc_filename = line.split('"')[1]
      inc_filename = inc_filename.replace(REPO_ROOT, "")
      if inc_filename not in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          recurse_write_lines(inc_file, outfile, prevfiles)
          resume = True
    else:
      if resume:
        outfile.write(f"{comment_char * 2} (Resuming {infile.name}) {comment_char*2}\n")
        resume = False
      outfile.writelines(line)

  # Write footer
  outfile.write(f"\n{comment_char * 31} End {infile.name} {comment_char * 31}\n")
  outfile.write(f"{comment_char * 90}\n\n")
  

files_opened = [INIT_FILE_NAME]
with open(INIT_FILE_NAME, 'r') as readfile:
    with open(OUT_FILE_NAME, 'w') as outfile:
        recurse_write_lines(readfile, outfile, files_opened)

input("\nDone writing to buehler.rc\nPress enter to close.")

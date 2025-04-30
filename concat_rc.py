INIT_FILE_NAME = "init.txt"
OUT_FILE_NAME = "allRC.txt"
REPO_ROOT = "crawl-rc/"
RC_PREFIX =  f"include = {REPO_ROOT}"
LUA_PREFX = f"lua_file = {REPO_ROOT}"

def recurse_write_lines(infile, outfile, prevfiles):
  print("Writing " + infile.name)
  if infile.name.endswith(".lua"):
    outfile.writelines("-------------------------------------------------------------------------------\n")
    outfile.writelines("-------- Begin " + infile.name + " --------\n")
  else:
    outfile.writelines("###############################################################################\n")
    outfile.writelines("######## Begin " + infile.name + " ########\n")
  for line in infile.readlines():
    if (line.startswith(RC_PREFIX)):
      inc_filename = line.replace(RC_PREFIX, "").strip()
      if inc_filename not in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          recurse_write_lines(inc_file, outfile, prevfiles)
    elif (line.startswith(LUA_PREFX)):
      inc_filename = line.replace(LUA_PREFX, "").strip()
      if inc_filename not in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          outfile.writelines("\n### BEGIN LUA ###\n{\n")
          recurse_write_lines(inc_file, outfile, prevfiles)
          outfile.writelines("\n}\n### END LUA ###\n")
    elif line.startswith("dofile("):
      inc_filename = line.split('"')[1]
      inc_filename = inc_filename.replace(REPO_ROOT, "")
      if inc_filename not in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          recurse_write_lines(inc_file, outfile, prevfiles)
    else:
      outfile.writelines(line)

  if infile.name.endswith(".lua"):
    outfile.writelines("\n-------- End " + infile.name + " --------\n")
    outfile.writelines("-------------------------------------------------------------------------------\n")
  else:
    outfile.writelines("\n######## End " + infile.name + " ########\n")
    outfile.writelines("###############################################################################\n")


files_opened = [INIT_FILE_NAME]
with open(INIT_FILE_NAME, 'r') as readfile:
    with open(OUT_FILE_NAME, 'w') as outfile:
        recurse_write_lines(readfile, outfile, files_opened)

input("\nDone writing to allRC.txt\nPress enter to close.")

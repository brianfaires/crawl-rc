import os
path =r'.'
list_of_files = []
files_opened = [ "slots.rc" ]
outfilename = "allRC.txt"

def recurse_write_lines(infile, outfile, prevfiles):
  wroteheader = False
  infilelines = infile.readlines()
  for line in infilelines:
    if (line.startswith("include = ")):
      inc_filename = line.replace("include = ", "").strip()
      if not inc_filename in prevfiles:
        prevfiles.append(inc_filename)
        with open(inc_filename, 'r') as inc_file:
          recurse_write_lines(inc_file, outfile, prevfiles)
    else:
      if (not wroteheader):
        wroteheader = True
        outfile.writelines("\n\n######## Begin " + infile.name + " ########\n\n")
        print("Writing " + infile.name)
      outfile.writelines(line)

  outfile.writelines("\n\n######## End" + infile.name + " ########\n\n")



for root, dirs, files in os.walk(path):
	for file in files:
		if(file.endswith(".rcXXX")):
			list_of_files.append(os.path.join(root,file))
list_of_files.append("./init.txt")

with open(outfilename, 'w') as outfile:
  for fname in list_of_files:
    files_opened.append(fname)
    with open(fname, 'r') as readfile:
        recurse_write_lines(readfile, outfile, files_opened)


input("\nDone writing to allRC.txt\nPress enter to close.")

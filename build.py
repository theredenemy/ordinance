import os
import sys
import requests
import shutil
import time
import subprocess
import pathlib

platform = sys.platform
maindir = os.getcwd()
dir = None
compiler = None
archive = None
archive_files = False
plugins_dir = os.path.join(maindir, "plugins")
scripting_dir = os.path.join(maindir, "scripting")
maps_dir = os.path.join(maindir, "maps")
cfgs_dir = os.path.join(maindir, "cfg")
dependencies_dir = os.path.join(maindir, "dependencies")

plugin_name = "ordinance"

if "--archive" in sys.argv:
    archive_files = True



def download_file(url, filename):
    file_data = requests.get(url, allow_redirects=True)
    open(filename, 'wb').write(file_data.content)
    return filename

# includes
# dependencies\sm-json\addons\sourcemod\scripting\include\json
sm_json = os.path.join(maindir, "dependencies", "sm-json", "addons", "sourcemod", "scripting", "include")
SteamWorks = os.path.join(maindir, "dependencies", "SteamWorks", "Pawn", "includes")
if not os.path.isdir(os.path.join(scripting_dir, "include")):
    os.mkdir(os.path.join(scripting_dir, "include"))
download_file("https://raw.githubusercontent.com/DoctorMcKay/sourcemod-plugins/refs/heads/master/scripting/include/morecolors.inc", os.path.join(scripting_dir, "include", "morecolors.inc"))

# SourcePawn Script

script = os.path.join(scripting_dir, "ordinance.sp")

if not os.path.isdir(sm_json) or not os.path.isdir(SteamWorks):
    print("Try Running git submodule update --init --recursive First")
    sys.exit(1)
print("sm-json :", sm_json)
print("SteamWorks :", SteamWorks)
print(platform)

if platform == "win32":
    dir = os.path.join(maindir, "sourcemod-win")
    compiler = os.path.join(dir, "addons", "sourcemod", "scripting", "spcomp.exe")
    if not os.path.isfile(compiler) and os.path.isdir(dir):
        print("Delete :", dir)
        time.sleep(20)
        shutil.rmtree(dir)
    if not os.path.isdir(dir):
        print("Downloading SourceMod Windows")
        archive = os.path.join(maindir, "sourcemod-win.zip")
        os.mkdir(dir)
        download_file("https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7221-windows.zip", archive)
        if not os.path.isfile(archive):
            sys.exit(1)
        print(f"Unpacking Archive {archive}")
        shutil.unpack_archive(archive, dir)
elif platform == "linux":
    dir = os.path.join(maindir, "sourcemod-linux")
    compiler = os.path.join(dir, "addons", "sourcemod", "scripting", "spcomp")
    if not os.path.isfile(compiler) and os.path.isdir(dir):
        print("Delete :", dir)
        time.sleep(20)
        shutil.rmtree(dir)
    if not os.path.isdir(dir):
        print("Downloading SourceMod Linux")
        archive = os.path.join(maindir, "sourcemod-linux.zip")
        os.mkdir(dir)
        download_file("https://sm.alliedmods.net/smdrop/1.12/sourcemod-1.12.0-git7221-linux.tar.gz", archive)
        if not os.path.isfile(archive):
            sys.exit(1)
        print(f"Unpacking Archive {archive}")
        shutil.unpack_archive(archive, dir)
else:
    print("Failed")
    sys.exit(1)

# Does Compiler exist?

if not os.path.isfile(compiler):
    print("Failed No Compiler")
    sys.exit(1)

# Compile Plugin
if not os.path.isdir(plugins_dir):
    os.mkdir(plugins_dir)
plugin = os.path.join(plugins_dir, f"{pathlib.Path(script).stem}.smx")
cmd = subprocess.Popen([compiler, script, f"-o{plugin}", f"-i{sm_json}", f"-i{SteamWorks}", f"-i{os.path.join(scripting_dir, "include")}", f"-i{scripting_dir}", f"-i{os.path.join(dir, "include")}"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
while cmd.poll() is None:
    
    line = cmd.stdout.readline()

    if line:
        print(line)

print(cmd.returncode)
if not cmd.returncode == 0:
    print("Failed Complie")
    sys.exit(1)

if archive_files is True:
    archive_dir_name = f"{plugin_name}_archive"
    archive_dir = os.path.join(maindir, archive_dir_name)
    print(f"Packing Archive : {archive_dir}")
    if os.path.isdir(archive_dir):
        shutil.rmtree(archive_dir)
    os.mkdir(archive_dir)
    shutil.copytree(scripting_dir, os.path.join(archive_dir, "scripting"), dirs_exist_ok=True)
    shutil.copytree(plugins_dir, os.path.join(archive_dir, "plugins"), dirs_exist_ok=True)
    shutil.copytree(maps_dir, os.path.join(archive_dir, "maps"), dirs_exist_ok=True)
    shutil.copytree(cfgs_dir, os.path.join(archive_dir, "cfgs"), dirs_exist_ok=True)
    shutil.copytree(dependencies_dir, os.path.join(archive_dir, "dependencies"), dirs_exist_ok=True)
    download_file("https://users.alliedmods.net/~kyles/builds/SteamWorks/SteamWorks-git132-windows.zip", os.path.join(archive_dir, "SteamWorks-git132-windows.zip"))
    download_file("https://users.alliedmods.net/~kyles/builds/SteamWorks/SteamWorks-git132-linux.tar.gz", os.path.join(archive_dir, "SteamWorks-git132-linux.tar.gz"))
    shutil.make_archive(base_name=plugin_name, format="zip", root_dir=maindir, base_dir=archive_dir_name)
    shutil.make_archive(base_name=plugin_name, format="gztar", root_dir=maindir, base_dir=archive_dir_name)
    print("Done")

sys.exit(0)





    

    






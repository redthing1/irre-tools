import sh
import os
import sys
import shutil

# CC = sh.sh.bake('./script/irre_cc.sh')

VBCC = "tools/vbcc"
IRRE = "src/irretool"

DEBUG = os.environ.get('DEBUG') != None

cmd_vbcc = sh.Command(f'{VBCC}/bin/vbccirre')
cmd_irretool = sh.Command(f'{IRRE}/irretool')


def run_cc(c_file, output_base):
    cc_file = cmd_vbcc.bake('-c99', '-default-main', f'-o={output_base}.ire', c_file,)
    if DEBUG:
        print(f' running {cc_file} (c -> ire)')
    cc_file(_fg=DEBUG)

    asm_file = cmd_irretool.bake("asm", f'{output_base}.ire', f'{output_base}.bin')
    if DEBUG:
        print(f' running {asm_file} (ire -> bin)')
    asm_file(_fg=DEBUG)

TEST_DIR = 'test/'

def listdir_recurse(path):
    return [os.path.join(dp, f) for dp, dn, fn in os.walk(os.path.expanduser(path)) for f in fn]

# find all test C programs
c_sources = [f for f in listdir_recurse(TEST_DIR) if f.endswith('.c')]

if DEBUG:
    print(f'found test c sources: {c_sources}')

for c_src in c_sources:
    # 1. get path to file without extension
    c_src_path = c_src
    c_src_path_no_ext = os.path.splitext(c_src_path)[0]

    # 2. compile
    # print(f'compiling {c_src_path} -> {c_src_path_no_ext}.ire -> {c_src_path_no_ext}.bin')
    print(f'compiling {c_src_path}')
    # print(CC)
    # output = CC(c_src_path, c_src_path_no_ext, _fg=True)
    run_cc(c_src_path, c_src_path_no_ext)


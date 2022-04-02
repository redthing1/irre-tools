set -e # error exit

VBCC=tools/vbcc
IRRE=src/irretool

# 1. get args: ./irre_cc.sh <input.c> <output.asm/bin>
INPUT_FILE=$1
OUTPUT_BASE=$2


# if DEBUG is set, add some args
if [ -n "$DEBUG" ]; then
    CC_ARGS="-debug=$DEBUG"
else
    CC_ARGS=""
fi

# ensure neither arg is empty
if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_BASE" ]; then
    echo "Usage: $0 <input.c> <output.asm/bin>"
    exit 1
fi

set -x # log

# 2. use vbccirre to get c -> asm
$VBCC/bin/vbccirre -c99 -default-main $CC_ARGS "$INPUT_FILE" -o="$OUTPUT_BASE.ire"

# 3. use irretool asm to get asm -> bin

$IRRE/irretool asm "$OUTPUT_BASE.ire" "$OUTPUT_BASE.bin"


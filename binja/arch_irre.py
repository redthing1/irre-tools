# IRRE/arch_irre.py
# defines the irre architecture plugin for binary ninja.

import struct
from typing import Optional, Dict, Tuple, List

from binaryninja.architecture import (
    Architecture,
    RegisterInfo,
    InstructionInfo,
    InstructionTextToken,
)

# removed ILRegOrTemp from import as it's not directly available
from binaryninja.lowlevelil import (
    LowLevelILFunction,
    LowLevelILLabel,
    LLIL_TEMP,
    ExpressionIndex,
)
from binaryninja.function import InstructionTextTokenType
from binaryninja.enums import (
    Endianness,
    BranchType,
    LowLevelILOperation,
    FlagRole,
    LowLevelILFlagCondition,
)

# --- constants ---
INSTRUCTION_SIZE = 4

# --- register definitions ---
# map register index to name and info
# registers r0-r31 (0x00-0x1f), pc (0x20), lr (0x21), ad (0x22), at (0x23), sp (0x24)
REGISTERS: Dict[int, Tuple[str, RegisterInfo]] = {}
for i in range(32):
    reg_name = f"r{i}"
    REGISTERS[i] = (reg_name, RegisterInfo(reg_name, 4))

REGISTERS[0x20] = ("pc", RegisterInfo("pc", 4))  # program counter
REGISTERS[0x21] = ("lr", RegisterInfo("lr", 4))  # link register
REGISTERS[0x22] = ("ad", RegisterInfo("ad", 4))  # special temporary (arithmetic/data?)
REGISTERS[0x23] = ("at", RegisterInfo("at", 4))  # special temporary (assembler temp?)
REGISTERS[0x24] = ("sp", RegisterInfo("sp", 4))  # stack pointer

# reverse mapping for convenience
REG_NAME_TO_INDEX: Dict[str, int] = {info[0]: idx for idx, info in REGISTERS.items()}

# --- instruction definitions ---
# map opcode to (mnemonic, operand_format, branch_type)
# operand formats: '', 'rA', 'v0_24', 'rA_v0_16', 'rA_rB', 'rA_rB_v0_8', 'rA_v0_8_v1_8', 'rA_rB_rC'
# branch types: none, branchtype.unconditionalbranch, branchtype.truebranch, branchtype.falsebranch, branchtype.calldestination, branchtype.functionreturn, branchtype.indirectbranch
OPCODES: Dict[int, Tuple[str, str, Optional[BranchType]]] = {
    0x00: ("nop", "", None),
    0x01: ("add", "rA_rB_rC", None),
    0x02: ("sub", "rA_rB_rC", None),
    0x03: ("and", "rA_rB_rC", None),
    0x04: ("orr", "rA_rB_rC", None),
    0x05: ("xor", "rA_rB_rC", None),
    0x06: ("not", "rA_rB", None),
    0x07: ("lsh", "rA_rB_rC", None),  # logical shift (signed count)
    0x08: ("ash", "rA_rB_rC", None),  # arithmetic shift (signed count)
    0x09: ("tcu", "rA_rB_rC", None),  # test condition unsigned (stores sign in ra)
    0x0A: ("tcs", "rA_rB_rC", None),  # test condition signed (stores sign in ra)
    0x0B: ("set", "rA_v0_16", None),  # set register with 16-bit immediate
    0x0C: ("mov", "rA_rB", None),  # move register
    0x0D: ("ldw", "rA_rB_v0_8", None),  # load word (32-bit) with signed 8-bit offset
    0x0E: ("stw", "rA_rB_v0_8", None),  # store word (32-bit) with signed 8-bit offset
    0x0F: ("ldb", "rA_rB_v0_8", None),  # load byte with signed 8-bit offset
    0x10: ("stb", "rA_rB_v0_8", None),  # store byte with signed 8-bit offset
    0x20: (
        "jmi",
        "v0_24",
        BranchType.UnconditionalBranch,
    ),  # jump immediate (24-bit address)
    0x21: ("jmp", "rA", BranchType.IndirectBranch),  # jump register
    # 0x22, 0x23 missing?
    0x24: (
        "bve",
        "rA_rB_v0_8",
        BranchType.TrueBranch,
    ),  # branch if value equal (rb == v0, jump to ra)
    0x25: (
        "bvn",
        "rA_rB_v0_8",
        BranchType.TrueBranch,
    ),  # branch if value not equal (rb != v0, jump to ra)
    # 0x26 - 0x29 missing?
    0x2A: (
        "cal",
        "rA",
        BranchType.CallDestination,
    ),  # call register (stores pc+4 in lr)
    0x2B: ("ret", "", BranchType.FunctionReturn),  # return (jumps to lr)
    # 0x2c - 0x2f missing?
    0x30: ("mul", "rA_rB_rC", None),  # multiply
    0x31: ("div", "rA_rB_rC", None),  # divide (unsigned)
    0x32: ("mod", "rA_rB_rC", None),  # modulus (unsigned) - corrected opcode
    # 0x33 - 0x3f missing?
    0x40: ("sia", "rA_v0_8_v1_8", None),  # shift immediate and add (ra += v0 << v1)
    0x41: ("sup", "rA_v0_16", None),  # set upper (sets upper 16 bits of ra)
    0x42: ("sxt", "rA_rB", None),  # sign extend (emulator suggests this is just mov)
    0x43: ("seq", "rA_rB_v0_8", None),  # set if equal (ra = (rb == v0))
    # ... many missing ...
    # 0xF0: ("int", "v0_24", BranchType.Exception),  # interrupt (24-bit code)
    0xF0: ("int", "v0_24", BranchType.UnresolvedBranch),  # interrupt (24-bit code)
    # 0xf1 - 0xfc missing?
    0xFD: ("snd", "rA_rB_rC", None),  # send command to device
    # 0xfe missing?
    0xFF: (
        "hlt",
        "",
        BranchType.UnconditionalBranch,
    ),  # halt execution (effectively a branch to self or invalid location)
}


# helper to get register name from index
def get_reg_name(reg_index: int) -> Optional[str]:
    return REGISTERS.get(reg_index, (None, None))[0]


# helper to parse operands based on format string
def parse_operands(data: bytes, operand_format: str) -> Dict[str, int]:
    operands = {}
    op = data[0]
    a1 = data[1]
    a2 = data[2]
    a3 = data[3]

    if operand_format == "rA":
        operands["rA"] = a1
    elif operand_format == "v0_24":
        operands["v0"] = (a3 << 16) | (a2 << 8) | a1
    elif operand_format == "rA_v0_16":
        operands["rA"] = a1
        operands["v0"] = (a3 << 8) | a2
    elif operand_format == "rA_rB":
        operands["rA"] = a1
        operands["rB"] = a2
    elif operand_format == "rA_rB_v0_8":
        operands["rA"] = a1
        operands["rB"] = a2
        # sign extend the 8-bit offset v0 for ldw/stw/ldb/stb/bve/bvn/seq
        # struct unpack '<b' handles signed conversion correctly
        operands["v0"] = (
            struct.unpack("<b", bytes([a3]))[0]
            if op in [0x0D, 0x0E, 0x0F, 0x10]
            else a3
        )
    elif operand_format == "rA_v0_8_v1_8":  # sia
        operands["rA"] = a1
        operands["v0"] = a2  # immediate value to shift
        operands["v1"] = a3  # shift amount
    elif operand_format == "rA_rB_rC":
        operands["rA"] = a1
        operands["rB"] = a2
        operands["rC"] = a3

    return operands


class IRRE(Architecture):
    name = "IRRE"
    address_size = 4  # 32-bit architecture
    default_int_size = 4
    instr_alignment = 4  # instructions are 4 bytes wide
    max_instr_length = 4
    endianness = Endianness.LittleEndian

    # define registers
    regs = {info[0]: info[1] for info in REGISTERS.values()}

    # define stack pointer
    stack_pointer = "sp"
    # define link register (used by 'cal' and 'ret')
    link_reg = "lr"  # changed from link_register to match docs property name

    # --- instruction info ---
    def get_instruction_info(self, data: bytes, addr: int) -> Optional[InstructionInfo]:
        if len(data) < INSTRUCTION_SIZE:
            return None  # not enough data

        instr_bytes = data[:INSTRUCTION_SIZE]
        opcode = instr_bytes[0]
        instr_def = OPCODES.get(opcode)

        if not instr_def:
            # handle unknown opcode - treat as nop of length 4? or return none?
            # returning none might be safer if we encounter truly invalid data.
            # let's create a basic info for now.
            info = InstructionInfo()
            info.length = INSTRUCTION_SIZE
            # maybe add a specific "illegal" branch type if needed later
            return info

        mnemonic, operand_format, branch_behavior = instr_def
        info = InstructionInfo()
        info.length = INSTRUCTION_SIZE

        # special case: ret can be a non-returning halt if lr is 0
        # however, get_instruction_info doesn't know the value of lr.
        # we mark it as FunctionReturn, and the lifter handles the halt case.
        if branch_behavior:
            operands = parse_operands(instr_bytes, operand_format)
            if branch_behavior == BranchType.UnconditionalBranch:
                if mnemonic == "jmi":
                    target_addr = operands.get("v0")
                    if target_addr is not None:
                        info.add_branch(BranchType.UnconditionalBranch, target_addr)
                elif mnemonic == "hlt":
                    # hlt always stops execution here. represent as branch to self.
                    info.add_branch(BranchType.UnconditionalBranch, addr)
                # jmp is handled as indirectbranch below
            elif branch_behavior == BranchType.IndirectBranch:
                # jmp ra
                info.add_branch(BranchType.IndirectBranch)  # target is in register ra
            elif branch_behavior == BranchType.TrueBranch:
                # bve ra, rb, v0 -> branch to ra if rb == v0
                # bvn ra, rb, v0 -> branch to ra if rb != v0
                # target address is in ra (dynamic). add true (indirect) and false (fallthrough) branches.
                info.add_branch(
                    BranchType.TrueBranch, None
                )  # target depends on ra, mark as unknown for now
                info.add_branch(BranchType.FalseBranch, addr + info.length)
            elif branch_behavior == BranchType.CallDestination:
                # cal ra -> target is in ra
                info.add_branch(
                    BranchType.CallDestination, None
                )  # target depends on ra
            elif branch_behavior == BranchType.FunctionReturn:
                # ret -> target is in lr (or halt)
                info.add_branch(BranchType.FunctionReturn)
            elif branch_behavior == BranchType.Exception:
                # int v0
                info.add_branch(
                    BranchType.Exception
                )  # represents a system call or interrupt

            # add fallthrough for conditional branches if not already handled implicitly
            # bve/bvn already added falsebranch above
            # if branch_behavior == branchtype.truebranch and mnemonic not in ["bve", "bvn"]:
            #      info.add_branch(branchtype.falsebranch, addr + info.length)

        return info

    # --- instruction text ---
    def get_instruction_text(
        self, data: bytes, addr: int
    ) -> Optional[Tuple[List[InstructionTextToken], int]]:
        if len(data) < INSTRUCTION_SIZE:
            return None

        instr_bytes = data[:INSTRUCTION_SIZE]
        opcode = instr_bytes[0]
        instr_def = OPCODES.get(opcode)

        if not instr_def:
            # unknown instruction
            tokens = [InstructionTextToken(InstructionTextTokenType.TextToken, "db ")]
            tokens.append(
                InstructionTextToken(
                    InstructionTextTokenType.IntegerToken, f"0x{opcode:02x}", opcode
                )
            )
            return tokens, INSTRUCTION_SIZE

        mnemonic, operand_format, _ = instr_def
        operands = parse_operands(instr_bytes, operand_format)
        tokens: List[InstructionTextToken] = []

        # mnemonic
        tokens.append(
            InstructionTextToken(InstructionTextTokenType.InstructionToken, mnemonic)
        )

        # operands
        first_operand = True

        def add_separator():
            nonlocal first_operand
            if not first_operand:
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.OperandSeparatorToken, ","
                    )
                )
            tokens.append(InstructionTextToken(InstructionTextTokenType.TextToken, " "))
            first_operand = False

        # helper to format register operand
        def format_register(reg_idx):
            reg_name = get_reg_name(reg_idx)
            if reg_name:
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.RegisterToken, reg_name
                    )
                )
            else:
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.TextToken, f"UNK_REG_{reg_idx:02x}"
                    )
                )

        # helper to format immediate operand
        def format_immediate(value, size_bytes, is_addr=False, is_signed=False):
            if is_signed:
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.IntegerToken, f"{value}", value
                    )
                )
            elif is_addr or (
                size_bytes >= 2 and abs(value) > 0x100
            ):  # heuristic for addresses
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.PossibleAddressToken,
                        f"0x{value:x}",
                        value,
                    )
                )
            else:
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.IntegerToken, f"0x{value:x}", value
                    )
                )

        # format based on operand string
        if operand_format == "rA":
            add_separator()
            format_register(operands["rA"])
        elif operand_format == "v0_24":
            add_separator()
            format_immediate(operands["v0"], 3, is_addr=(mnemonic in ["jmi", "int"]))
        elif operand_format == "rA_v0_16":
            add_separator()
            format_register(operands["rA"])
            add_separator()
            format_immediate(
                operands["v0"], 2, is_addr=(mnemonic == "set")
            )  # `set` often loads addresses
        elif operand_format == "rA_rB":
            add_separator()
            format_register(operands["rA"])
            add_separator()
            format_register(operands["rB"])
        elif operand_format == "rA_rB_v0_8":
            add_separator()
            format_register(operands["rA"])
            add_separator()
            # memory operands for ldw/stw/ldb/stb: [rb, offset] or [rb] if offset is 0
            if mnemonic in ["ldw", "stw", "ldb", "stb"]:
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.BeginMemoryOperandToken, "["
                    )
                )
                format_register(operands["rB"])
                offset = operands["v0"]
                if offset != 0:
                    tokens.append(
                        InstructionTextToken(
                            InstructionTextTokenType.OperandSeparatorToken, ","
                        )
                    )
                    tokens.append(
                        InstructionTextToken(InstructionTextTokenType.TextToken, " ")
                    )
                    format_immediate(offset, 1, is_signed=True)
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.EndMemoryOperandToken, "]"
                    )
                )
            # branch operands for bve/bvn: ra, rb, v0
            elif mnemonic in ["bve", "bvn"]:
                format_register(operands["rB"])  # condition register
                add_separator()
                format_immediate(operands["v0"], 1)  # condition immediate
                add_separator()
                tokens.append(
                    InstructionTextToken(
                        InstructionTextTokenType.PossibleAddressToken,
                        f"reg({get_reg_name(operands['rA'])})",
                    )
                )  # target is in ra
            # set if equal: ra, rb, v0
            elif mnemonic == "seq":
                format_register(operands["rB"])
                add_separator()
                format_immediate(operands["v0"], 1)
            else:  # should not happen with current defs
                format_register(operands["rB"])
                add_separator()
                format_immediate(operands["v0"], 1)

        elif operand_format == "rA_v0_8_v1_8":  # sia ra, v0, v1
            add_separator()
            format_register(operands["rA"])
            add_separator()
            format_immediate(operands["v0"], 1)
            add_separator()
            format_immediate(operands["v1"], 1)
        elif operand_format == "rA_rB_rC":
            add_separator()
            format_register(operands["rA"])
            add_separator()
            format_register(operands["rB"])
            add_separator()
            format_register(operands["rC"])

        return tokens, INSTRUCTION_SIZE

    # --- low level il ---
    def get_instruction_low_level_il(
        self, data: bytes, addr: int, il: LowLevelILFunction
    ) -> Optional[int]:
        if len(data) < INSTRUCTION_SIZE:
            return None

        instr_bytes = data[:INSTRUCTION_SIZE]
        opcode = instr_bytes[0]
        instr_def = OPCODES.get(opcode)

        if not instr_def:
            il.append(il.unimplemented())
            return INSTRUCTION_SIZE

        mnemonic, operand_format, _ = instr_def
        operands = parse_operands(instr_bytes, operand_format)

        # helper to get register il expression
        # returns none if register index is invalid, caller must handle this
        # updated type hint to reflect return type
        def reg(reg_idx) -> Optional[ExpressionIndex]:
            name = get_reg_name(reg_idx)
            if name:
                return il.reg(4, name)
            print(f"error: invalid register index {reg_idx} used at 0x{addr:x}")
            return None  # indicate failure

        # helper to get immediate il expression
        def imm(value, size=4):
            return il.const(size, value)

        # helper to get memory address il expression (base + offset)
        # returns none if base register is invalid
        def mem_addr(base_reg_idx, offset_val) -> Optional[ExpressionIndex]:
            base_reg_expr = reg(base_reg_idx)
            if base_reg_expr is None:
                return None  # propagate error
            if offset_val == 0:
                return base_reg_expr
            else:
                # ensure offset is treated as signed for addition
                offset_expr = il.const(
                    4, offset_val
                )  # use 4-byte const for address arithmetic
                return il.add(4, base_reg_expr, offset_expr)

        # --- lifting logic (revised implementation) ---
        try:
            # check operands requiring registers first
            # this structure helps avoid redundant checks inside each mnemonic block
            required_regs = []
            if "rA" in operands:
                required_regs.append(operands["rA"])
            if "rB" in operands:
                required_regs.append(operands["rB"])
            if "rC" in operands:
                required_regs.append(operands["rC"])

            reg_exprs = {}
            for r_idx in set(required_regs):  # use set to avoid duplicates
                r_expr = reg(r_idx)
                if r_expr is None:
                    il.append(il.unimplemented())  # append error indicator
                    return None  # stop lifting this instruction
                reg_exprs[r_idx] = r_expr

            # --- actual lifting ---
            if mnemonic == "nop":
                il.append(il.nop())
            elif mnemonic == "add":
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4, get_reg_name(rA), il.add(4, reg_exprs[rB], reg_exprs[rC])
                    )
                )
            elif mnemonic == "sub":
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4, get_reg_name(rA), il.sub(4, reg_exprs[rB], reg_exprs[rC])
                    )
                )
            elif mnemonic == "and":
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4,
                        get_reg_name(rA),
                        il.and_expr(4, reg_exprs[rB], reg_exprs[rC]),
                    )
                )
            elif mnemonic == "orr":
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4, get_reg_name(rA), il.or_expr(4, reg_exprs[rB], reg_exprs[rC])
                    )
                )
            elif mnemonic == "xor":
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4,
                        get_reg_name(rA),
                        il.xor_expr(4, reg_exprs[rB], reg_exprs[rC]),
                    )
                )
            elif mnemonic == "not":
                rA, rB = operands["rA"], operands["rB"]
                il.append(
                    il.set_reg(4, get_reg_name(rA), il.not_expr(4, reg_exprs[rB]))
                )

            elif mnemonic in ["lsh", "ash"]:  # ra = rb shifted by rc (signed count)
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                shift_val_reg = reg_exprs[rC]
                value_reg = reg_exprs[rB]
                dest_reg_name = get_reg_name(rA)

                temp_shift_abs = il.reg_temp(4)
                label_left = il.get_label()
                label_right = il.get_label()
                label_done = il.get_label()

                is_negative = il.compare_signed_less_than(
                    4, shift_val_reg, il.const(4, 0)
                )
                il.append(il.if_expr(is_negative, label_right, label_left))

                il.mark_label(label_left)  # shift count >= 0 (left shift)
                il.append(
                    il.set_reg(
                        4, dest_reg_name, il.shift_left(4, value_reg, shift_val_reg)
                    )
                )
                il.append(il.goto(label_done))

                il.mark_label(label_right)  # shift count < 0 (right shift)
                il.append(
                    il.set_reg(4, temp_shift_abs, il.neg_expr(4, shift_val_reg))
                )  # absolute value
                if mnemonic == "lsh":  # logical right shift
                    il.append(
                        il.set_reg(
                            4,
                            dest_reg_name,
                            il.logical_shift_right(
                                4, value_reg, il.reg(4, temp_shift_abs)
                            ),
                        )
                    )
                else:  # ash: arithmetic right shift
                    il.append(
                        il.set_reg(
                            4,
                            dest_reg_name,
                            il.arith_shift_right(
                                4, value_reg, il.reg(4, temp_shift_abs)
                            ),
                        )
                    )
                il.append(il.goto(label_done))

                il.mark_label(label_done)

            elif mnemonic == "tcu":  # ra = sign(rb - rc) unsigned
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                reg_b = reg_exprs[rB]
                reg_c = reg_exprs[rC]
                dest_reg_name = get_reg_name(rA)

                label_lt = il.get_label()
                label_ge = il.get_label()  # greater or equal
                label_eq = il.get_label()
                label_gt = il.get_label()
                label_done = il.get_label()

                il.append(
                    il.if_expr(
                        il.compare_unsigned_less_than(4, reg_b, reg_c),
                        label_lt,
                        label_ge,
                    )
                )

                il.mark_label(label_lt)
                il.append(il.set_reg(4, dest_reg_name, il.const(4, -1)))  # set ra = -1
                il.append(il.goto(label_done))

                il.mark_label(label_ge)
                il.append(
                    il.if_expr(il.compare_equal(4, reg_b, reg_c), label_eq, label_gt)
                )

                il.mark_label(label_eq)
                il.append(il.set_reg(4, dest_reg_name, il.const(4, 0)))  # set ra = 0
                il.append(il.goto(label_done))

                il.mark_label(label_gt)  # must be rb > rc
                il.append(il.set_reg(4, dest_reg_name, il.const(4, 1)))  # set ra = 1
                il.append(il.goto(label_done))

                il.mark_label(label_done)
            elif mnemonic == "tcs":  # ra = sign(rb - rc) signed
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                reg_b = reg_exprs[rB]
                reg_c = reg_exprs[rC]
                dest_reg_name = get_reg_name(rA)

                label_lt = il.get_label()
                label_ge = il.get_label()  # greater or equal
                label_eq = il.get_label()
                label_gt = il.get_label()
                label_done = il.get_label()

                il.append(
                    il.if_expr(
                        il.compare_signed_less_than(4, reg_b, reg_c), label_lt, label_ge
                    )
                )

                il.mark_label(label_lt)
                il.append(il.set_reg(4, dest_reg_name, il.const(4, -1)))  # set ra = -1
                il.append(il.goto(label_done))

                il.mark_label(label_ge)
                il.append(
                    il.if_expr(il.compare_equal(4, reg_b, reg_c), label_eq, label_gt)
                )

                il.mark_label(label_eq)
                il.append(il.set_reg(4, dest_reg_name, il.const(4, 0)))  # set ra = 0
                il.append(il.goto(label_done))

                il.mark_label(label_gt)  # must be rb > rc
                il.append(il.set_reg(4, dest_reg_name, il.const(4, 1)))  # set ra = 1
                il.append(il.goto(label_done))

                il.mark_label(label_done)
            elif mnemonic == "set":  # ra = v0 (16-bit immediate, zero extended)
                rA = operands["rA"]
                v0 = operands["v0"]
                il.append(
                    il.set_reg(4, get_reg_name(rA), il.const(2, v0))
                )  # use 2-byte const, bnil handles extension
            elif mnemonic == "mov":  # ra = rb
                rA, rB = operands["rA"], operands["rB"]
                il.append(il.set_reg(4, get_reg_name(rA), reg_exprs[rB]))
            elif mnemonic == "ldw":  # ra = memword[rb + v0]
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                addr_expr = mem_addr(rB, v0)
                if addr_expr is None:
                    return None  # handle invalid base register
                il.append(il.set_reg(4, get_reg_name(rA), il.load(4, addr_expr)))
            elif mnemonic == "stw":  # memword[rb + v0] = ra
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                addr_expr = mem_addr(rB, v0)
                if addr_expr is None:
                    return None
                il.append(il.store(4, addr_expr, reg_exprs[rA]))
            elif mnemonic == "ldb":  # ra = membyte[rb + v0] (zero extended)
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                addr_expr = mem_addr(rB, v0)
                if addr_expr is None:
                    return None
                il.append(
                    il.set_reg(
                        4, get_reg_name(rA), il.zero_extend(4, il.load(1, addr_expr))
                    )
                )
            elif mnemonic == "stb":  # membyte[rb + v0] = ra (lower 8 bits)
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                addr_expr = mem_addr(rB, v0)
                if addr_expr is None:
                    return None
                il.append(il.store(1, addr_expr, il.low_part(1, reg_exprs[rA])))
            elif mnemonic == "jmi":  # jump to v0 (24-bit immediate)
                target = operands["v0"]
                label = il.get_label_for_address(Architecture["IRRE"], target)
                if label:
                    il.append(il.goto(label))
                else:
                    il.append(il.jump(il.const_pointer(4, target)))
            elif mnemonic == "jmp":  # jump to ra
                rA = operands["rA"]
                il.append(il.jump(reg_exprs[rA]))
            elif mnemonic == "bve":  # if rb == v0 then jump to ra
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                condition = il.compare_equal(4, reg_exprs[rB], imm(v0, 4))
                t = il.get_label()
                f = il.get_label()
                il.append(il.if_expr(condition, t, f))
                il.mark_label(t)
                il.append(il.jump(reg_exprs[rA]))  # target address is in ra
                il.mark_label(f)
            elif mnemonic == "bvn":  # if rb != v0 then jump to ra
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                condition = il.compare_not_equal(4, reg_exprs[rB], imm(v0, 4))
                t = il.get_label()
                f = il.get_label()
                il.append(il.if_expr(condition, t, f))
                il.mark_label(t)
                il.append(il.jump(reg_exprs[rA]))  # target address is in ra
                il.mark_label(f)
            elif mnemonic == "cal":  # lr = pc + 4; pc = ra
                rA = operands["rA"]
                ret_addr = addr + INSTRUCTION_SIZE
                il.append(il.set_reg(4, "lr", il.const_pointer(4, ret_addr)))
                il.append(il.call(reg_exprs[rA]))
            elif mnemonic == "ret":  # pc = lr; lr = 0 (or halt if lr == 0)
                lr_val = il.reg(
                    4, "lr"
                )  # get lr value *before* potentially clearing it
                label_halt = il.get_label()
                label_return = il.get_label()

                il.append(
                    il.if_expr(
                        il.compare_equal(4, lr_val, il.const(4, 0)),
                        label_halt,
                        label_return,
                    )
                )

                il.mark_label(label_halt)
                il.append(il.no_ret())  # use no_ret() for halt condition

                il.mark_label(label_return)
                il.append(il.set_reg(4, "lr", il.const(4, 0)))  # clear lr
                il.append(il.ret(lr_val))  # return using original lr value

            elif mnemonic == "mul":
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4, get_reg_name(rA), il.mult(4, reg_exprs[rB], reg_exprs[rC])
                    )
                )
            elif mnemonic == "div":  # unsigned division
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4,
                        get_reg_name(rA),
                        il.div_unsigned(4, reg_exprs[rB], reg_exprs[rC]),
                    )
                )
            elif mnemonic == "mod":  # unsigned modulus (opcode 0x32)
                rA, rB, rC = operands["rA"], operands["rB"], operands["rC"]
                il.append(
                    il.set_reg(
                        4,
                        get_reg_name(rA),
                        il.mod_unsigned(4, reg_exprs[rB], reg_exprs[rC]),
                    )
                )
            elif mnemonic == "sia":  # ra += v0 << v1
                rA, v0, v1 = operands["rA"], operands["v0"], operands["v1"]
                shifted_val = il.shift_left(4, imm(v0, 4), imm(v1, 4))
                current_rA = reg_exprs[rA]
                il.append(
                    il.set_reg(4, get_reg_name(rA), il.add(4, current_rA, shifted_val))
                )
            elif mnemonic == "sup":  # ra = (ra & 0x0000ffff) | (v0 << 16)
                rA, v0 = operands["rA"], operands["v0"]
                lower_mask = il.const(4, 0x0000FFFF)
                upper_val = il.shift_left(4, il.const(4, v0), il.const(4, 16))
                current_lower = il.and_expr(4, reg_exprs[rA], lower_mask)
                il.append(
                    il.set_reg(
                        4, get_reg_name(rA), il.or_expr(4, current_lower, upper_val)
                    )
                )
            elif mnemonic == "sxt":  # ra = rb (emulator suggests simple move)
                rA, rB = operands["rA"], operands["rB"]
                il.append(il.set_reg(4, get_reg_name(rA), reg_exprs[rB]))
            elif mnemonic == "seq":  # ra = (rb == v0) ? 1 : 0
                rA, rB, v0 = operands["rA"], operands["rB"], operands["v0"]
                condition = il.compare_equal(4, reg_exprs[rB], imm(v0, 4))
                label_true = il.get_label()
                label_false = il.get_label()
                label_done = il.get_label()
                il.append(il.if_expr(condition, label_true, label_false))
                il.mark_label(label_true)
                il.append(il.set_reg(4, get_reg_name(rA), il.const(4, 1)))
                il.append(il.goto(label_done))
                il.mark_label(label_false)
                il.append(il.set_reg(4, get_reg_name(rA), il.const(4, 0)))
                il.append(il.goto(label_done))
                il.mark_label(label_done)
            elif mnemonic == "int":  # interrupt v0
                code = operands["v0"]  # 24-bit immediate
                il.append(
                    il.system_call(code)
                )  # use system_call for interrupts/exceptions
            elif (
                mnemonic == "snd"
            ):  # send command rb to device ra with arg rc, result in rc
                il.append(
                    il.unimplemented()
                )  # todo: define behavior for device interaction
            elif mnemonic == "hlt":
                il.append(il.no_ret())  # use no_ret() for halt

            else:  # catch-all for defined but not yet lifted instructions
                il.append(il.unimplemented())

        except Exception as e:
            # log error during lifting specific instruction
            print(f"error lifting {mnemonic} at 0x{addr:x}: {e}")
            # append something to indicate failure within the il function
            il.append(il.unimplemented())
            return None  # indicate failure to lift

        return INSTRUCTION_SIZE

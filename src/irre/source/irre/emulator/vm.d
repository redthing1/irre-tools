module irre.emulator.vm;

public import irre.encoding.instructions;
import irre.encoding.rega;
import std.algorithm.mutation;
import irre.emulator.device;
import irre.disassembler.reader;
import irre.disassembler.dumper;
import irre.analysis.irre_arch;

import infoflow.models;

enum MEMORY_SIZE = 64 * 1024; // 65K

mixin(IrreInfoLog.GenAliases!("IrreInfoLog"));

class VirtualMachine {
    public UWORD[REGISTER_COUNT] reg;
    public UWORD[REGISTER_COUNT] prev_reg;
    public BYTE[] mem;
    public bool executing = true;
    public BranchStatus last_branch_status = BranchStatus.NO_BRANCH; // whether the last instruction took a branch
    public ulong ticks;
    public Device[int] devices;
    private int device_id_counter = 0;
    public void delegate(UWORD) custom_interrupt_handler;
    public bool log_commits;
    public CommitTrace commit_trace;
    public Reader reader;
    public Dumper dumper;
    public Instruction last_executed_instruction;
    public UWORD last_program_counter;

    // aliases
    enum reg_pc = cast(int) Register.PC;

    enum BranchStatus {
        NO_BRANCH,
        NOT_TAKEN,
        TAKEN,
    }

    public void initialize() {
        // allocate memory buffer
        mem = new BYTE[MEMORY_SIZE];

        // set SP to last word
        reg[Register.SP] = MEMORY_SIZE;

        // reset stats
        ticks = 0;

        // initialize all devices
        device_id_counter = 0;
        foreach (device; devices.byValue()) {
            device.initialize(this, device_id_counter++);
        }

        // for commit logging
        reader = new Reader();
        dumper = new Dumper(Dumper.DumpStyle.Detailed);
    }

    public void attach_device(Device device) {
        auto dev_id = device_id_counter++;
        // initialize the device
        device.initialize(this, dev_id);

        devices[dev_id] = device;
    }

    public void detach_device(Device device) {
        devices.remove(device.id);
    }

    public RegaHeader load(const ubyte[] compiled_data) {
        auto decoder = new RegaDecoder();
        auto head = decoder.read_header(compiled_data[0 .. RegaHeader.OFFSET]);

        // copy the program into memory
        auto copy_size = head.program_size;
        auto program_slice = compiled_data[RegaHeader.OFFSET .. RegaHeader.OFFSET + copy_size];
        program_slice.copy(mem); // copy everything after the header

        return head;
    }

    /** decode the next instruction */
    public Instruction decode_instruction() {
        OpCode op = cast(OpCode) mem[reg[cast(int) Register.PC] + 0];
        ARG a1 = cast(ARG) mem[reg[cast(int) Register.PC] + 1];
        ARG a2 = cast(ARG) mem[reg[cast(int) Register.PC] + 2];
        ARG a3 = cast(ARG) mem[reg[cast(int) Register.PC] + 3];

        return Instruction(op, a1, a2, a3);
    }

    public void interrupt(UWORD code) {
        // call custom handler hook
        custom_interrupt_handler(code);
    }

    public void execute_instruction(Instruction ins) {
        void commit_binary_op_regs() {
            // normally, if a1 is not a2 or a3, we can just commit:
            // dest: a1, source: a2, a3
            // but if a1 is a2 or a3, then
            // dest: a1, source: a2, a3, prev_a1
            auto is_simple = (ins.a1 != ins.a2) && (ins.a1 != ins.a3);

            Commit.Source[] sources;
            if (is_simple) {
                sources = commit_source_regs(
                    [ins.a2, ins.a3],
                    [reg[ins.a2], reg[ins.a3]]);
            } else {
                if (ins.a1 == ins.a2) {
                    // arg2 is the same as arg1
                    // the value of arg2 was thus the previous value of arg1
                    sources ~= Commit.Source(InfoType.Register, ins.a1, prev_reg[ins.a1]);
                }
                if (ins.a1 == ins.a3) {
                    // arg3 is the same as arg1
                    // the value of arg3 was thus the previous value of arg1
                    sources ~= Commit.Source(InfoType.Register, ins.a1, prev_reg[ins.a1]);
                }
            }
            commit_reg(ins.a1, reg[ins.a1], sources);
        }

        last_branch_status = BranchStatus.NO_BRANCH; // default, no branch
        last_executed_instruction = ins; // save last executed instruction for logging
        last_program_counter = reg[reg_pc]; // save program counter for logging
        prev_reg = reg; // save previous register state
        switch (ins.op) {
        case OpCode.NOP:
            // literally do nothing
            break;
        case OpCode.ADD: {
                reg[ins.a1] = (cast(WORD) reg[ins.a2]) + (cast(WORD) reg[ins.a3]);
                commit_binary_op_regs();
                break;
            }
        case OpCode.SUB: {
                reg[ins.a1] = (cast(WORD) reg[ins.a2]) - (cast(WORD) reg[ins.a3]);
                commit_binary_op_regs();
                break;
            }
        case OpCode.AND: {
                reg[ins.a1] = reg[ins.a2] & reg[ins.a3];
                commit_binary_op_regs();
                break;
            }
        case OpCode.ORR: {
                reg[ins.a1] = reg[ins.a2] | reg[ins.a3];
                commit_binary_op_regs();
                break;
            }
        case OpCode.XOR: {
                reg[ins.a1] = reg[ins.a2] ^ reg[ins.a3];
                commit_binary_op_regs();
                break;
            }
        case OpCode.NOT: {
                reg[ins.a1] = ~reg[ins.a2];
                commit_binary_op_regs();
                break;
            }
        case OpCode.LSH: {
                immutable WORD shift = reg[ins.a3];
                if (shift >= 0) {
                    reg[ins.a1] = reg[ins.a2] << shift;
                } else {
                    reg[ins.a1] = reg[ins.a2] >> -shift;
                }
                commit_binary_op_regs();
                break;
            }
        case OpCode.ASH: {
                immutable WORD shift = reg[ins.a3];
                if (shift >= 0) {
                    reg[ins.a1] = (cast(WORD) reg[ins.a2]) << shift;
                } else {
                    reg[ins.a1] = (cast(WORD) reg[ins.a2]) >> -shift;
                }
                commit_binary_op_regs();
                break;
            }
        case OpCode.TCU: {
                WORD sign = 0;
                if (reg[ins.a2] > reg[ins.a3]) {
                    sign = 1;
                } else if (reg[ins.a2] < reg[ins.a3]) {
                    sign = -1;
                }
                reg[ins.a1] = sign;
                commit_binary_op_regs();
                break;
            }
        case OpCode.TCS: {
                WORD sign = 0;
                if ((cast(WORD) reg[ins.a2]) > (cast(WORD) reg[ins.a3])) {
                    sign = 1;
                } else if ((cast(WORD) reg[ins.a2]) < (cast(WORD) reg[ins.a3])) {
                    sign = -1;
                }
                reg[ins.a1] = sign;
                commit_binary_op_regs();
                break;
            }
        case OpCode.SET: {
                immutable UWORD val = (ins.a2 | (ins.a3 << 8));
                reg[ins.a1] = val;
                commit_reg(ins.a1, reg[ins.a1], [
                        Commit.Source(InfoType.Immediate, ImmediatePos.BC, val)
                    ]);
                break;
            }
        case OpCode.SUP: {
                immutable UWORD val = (ins.a2 | (ins.a3 << 8));
                immutable UWORD shifted_val = val << 16; // upper 16 bits of a word
                immutable UWORD existing_data = reg[ins.a1];
                reg[ins.a1] = (existing_data & 0x0000FFFF) | shifted_val; // set only upper 16 bits of a1
                auto source_imm = [
                    Commit.Source(InfoType.Immediate, ImmediatePos.BC, val)
                ];
                auto source_reg = commit_source_regs([ins.a1], [existing_data]);
                auto sources = source_imm ~ source_reg;
                commit_reg(ins.a1, reg[ins.a1], sources);
                break;
            }
        case OpCode.MOV: {
                reg[ins.a1] = reg[ins.a2];
                commit_reg(ins.a1, reg[ins.a1], commit_source_regs([ins.a2], [
                            reg[ins.a2]
                        ]));
                break;
            }
        case OpCode.LDW: {
                immutable UWORD addr = reg[ins.a2];
                immutable byte offset = ins.a3;
                reg[ins.a1] = mem[addr + offset + 0] << 0 | mem[addr + offset + 1]
                    << 8 | mem[addr + offset + 2] << 16 | mem[addr + offset + 3] << 24;

                // complex commit
                auto source_regs = commit_source_regs([ins.a2], [reg[ins.a2]]);
                auto source_imm = Commit.Source(InfoType.Immediate, ImmediatePos.C, offset);
                auto source_mem = commit_source_mem(
                    [
                    addr + offset + 0, addr + offset + 1, addr + offset + 2,
                    addr + offset + 3
                ],
                [
                    mem[addr + offset + 0], mem[addr + offset + 1],
                    mem[addr + offset + 2], mem[addr + offset + 3]
                ]);
                auto sources = source_regs ~ source_imm ~ source_mem;
                // registers a1 is modified, source is memory and address and offset
                commit_reg(ins.a1, reg[ins.a1], sources);
                break;
            }
        case OpCode.STW: {
                immutable UWORD addr = reg[ins.a2];
                immutable byte offset = ins.a3;
                auto pos0 = addr + offset + 0;
                auto pos1 = addr + offset + 1;
                auto pos2 = addr + offset + 2;
                auto pos3 = addr + offset + 3;
                mem[pos0] = (reg[ins.a1] >> 0) & 0xff;
                mem[pos1] = (reg[ins.a1] >> 8) & 0xff;
                mem[pos2] = (reg[ins.a1] >> 16) & 0xff;
                mem[pos3] = (reg[ins.a1] >> 24) & 0xff;

                // complex commit
                auto source_regs = commit_source_regs([ins.a1, ins.a2], [
                        reg[ins.a1], reg[ins.a2]
                    ]);
                auto source_imm = Commit.Source(InfoType.Immediate, ImmediatePos.C, offset);
                auto sources = source_regs ~ source_imm;
                // memory is modified, source is registers source data, address, and offset
                commit_mem([pos0, pos1, pos2, pos3], [
                        mem[pos0], mem[pos1], mem[pos2], mem[pos3]
                    ], sources);
                break;
            }
        case OpCode.ASI: {
                immutable UWORD existing = reg[ins.a1];
                immutable ubyte val = ins.a2;
                immutable byte shift = ins.a3;

                if (shift >= 0 && shift < 32) {
                    UWORD shifted = val << shift;
                    reg[ins.a1] = existing + shifted;
                }

                auto source_regs = commit_source_regs([ins.a1], [reg[ins.a1]]);
                auto source_imm = [
                    Commit.Source(InfoType.Immediate, ImmediatePos.B, val),
                    Commit.Source(InfoType.Immediate, ImmediatePos.C, shift)
                ];
                auto sources = source_regs ~ source_imm;
                commit_reg(ins.a1, reg[ins.a1], sources);
                break;
            }
        case OpCode.MUL: {
                reg[ins.a1] = reg[ins.a2] * reg[ins.a3];
                commit_binary_op_regs();
                break;
            }
        case OpCode.DIV: {
                reg[ins.a1] = reg[ins.a2] / reg[ins.a3];
                commit_binary_op_regs();
                break;
            }
        case OpCode.MOD: {
                reg[ins.a1] = reg[ins.a2] % reg[ins.a3];
                commit_binary_op_regs();
                break;
            }
        case OpCode.JMI: {
                immutable UWORD addr = cast(UWORD)((ins.a1) | (ins.a2 << 8) | (ins.a3) << 16);
                reg[Register.PC] = addr;
                last_branch_status = BranchStatus.TAKEN;
                commit_reg(Register.PC, reg[Register.PC], [
                        Commit.Source(InfoType.Immediate, ImmediatePos.ABC, addr)
                    ]);
                break;
            }
        case OpCode.JMP: {
                immutable UWORD addr = reg[ins.a1];
                reg[Register.PC] = addr;
                last_branch_status = BranchStatus.TAKEN;
                commit_reg(Register.PC, reg[Register.PC], commit_source_regs([
                        ins.a1
                    ], [reg[ins.a1]]));
                break;
            }
        case OpCode.BVE: {
                immutable UWORD addr = reg[ins.a1];
                // branch to @rA if rB == vC
                immutable WORD a = reg[ins.a2];
                immutable byte b = ins.a3;
                if (a == b) {
                    reg[Register.PC] = addr;
                    last_branch_status = BranchStatus.TAKEN;
                } else {
                    last_branch_status = BranchStatus.NOT_TAKEN;
                }
                auto source_regs = commit_source_regs([ins.a1, ins.a2], [
                        reg[ins.a1], reg[ins.a2]
                    ]);
                auto source_imm = Commit.Source(InfoType.Immediate, ImmediatePos.C, b);
                commit_reg(Register.PC, reg[Register.PC], source_regs ~ source_imm);
                break;
            }
        case OpCode.BVN: {
                immutable UWORD addr = reg[ins.a1];
                // branch to @rA if rB != vC
                immutable WORD a = reg[ins.a2];
                immutable byte b = ins.a3;
                if (a != b) {
                    reg[Register.PC] = addr;
                    last_branch_status = BranchStatus.TAKEN;
                } else {
                    last_branch_status = BranchStatus.NOT_TAKEN;
                }
                auto source_regs = commit_source_regs([ins.a1, ins.a2], [
                        reg[ins.a1], reg[ins.a2]
                    ]);
                auto source_imm = Commit.Source(InfoType.Immediate, ImmediatePos.C, b);
                commit_reg(Register.PC, reg[Register.PC], source_regs ~ source_imm);
                break;
            }
        case OpCode.CAL: {
                immutable UWORD addr = reg[ins.a1];
                // store next instruction in LR
                reg[Register.LR] = reg[Register.PC] + cast(uint) INSTRUCTION_SIZE;
                reg[Register.PC] = addr;
                last_branch_status = BranchStatus.TAKEN;
                commit_regs([Register.PC, Register.LR], [
                        reg[Register.PC], reg[Register.LR]
                    ],
                    commit_source_regs([ins.a1, Register.PC], [
                            reg[ins.a1], reg[Register.PC]
                        ]));
                break;
            }
        case OpCode.RET: {
                immutable UWORD addr = reg[Register.LR];
                if (addr == 0) {
                    // attempted to RET to 0
                    // this is a HALT FAULT
                    executing = false;
                }
                reg[Register.PC] = addr;
                last_branch_status = BranchStatus.TAKEN;
                reg[Register.LR] = 0; // clear LR
                commit_regs([Register.PC, Register.LR], [
                        reg[Register.PC], reg[Register.LR]
                    ],
                    commit_source_regs([Register.LR], [reg[Register.LR]]));
                break;
            }
        case OpCode.SND: {
                immutable UWORD device_data = reg[ins.a1];
                immutable UWORD device_id = reg[ins.a2];
                immutable UWORD device_command = reg[ins.a3];

                // get matching device
                if (device_id in devices) {
                    auto device = devices[device_id];
                    immutable WORD result = device.recieve(device_command, device_data);
                    reg[ins.a1] = result;
                } else {
                    // requested a device that was not found
                    // TODO: UNK_DEVICE interrupt
                }

                // commit
                auto source_regs = commit_source_regs([ins.a1, ins.a2, ins.a3], [
                        reg[ins.a1], reg[ins.a2], reg[ins.a3]
                    ]);
                auto source_device = Commit.Source(InfoType.Device, device_id, device_command);
                auto sources = source_regs ~ source_device;
                commit_regs([ins.a1], [reg[ins.a1]], sources);

                break;
            }
        case OpCode.INT: {
                immutable UWORD code = cast(UWORD)((ins.a1) | (ins.a2 << 8) | (ins.a3) << 16);
                interrupt(code);
                break;
            }
        case OpCode.HLT:
            executing = false;
            break;
        default:
            // unhandled op
            break;
        }
        if (last_branch_status != BranchStatus.TAKEN) {
            // as long as we didn't take a branch, we can increment as normal
            reg[reg_pc] += cast(uint) INSTRUCTION_SIZE; // increment PC
            // commit_reg(reg_pc, reg[reg_pc]);
        }
    }

    public bool step() {
        // fetch instruction
        auto instruction = decode_instruction();
        // execute the instruction
        execute_instruction(instruction);
        ticks++;
        return executing; // execution state
    }

    public void read_words(UWORD addr, WORD[] buffer, size_t count) {
        for (int i = 0; i < count; i += 1) {
            auto mem_i = addr + i * WORD.sizeof;
            buffer[i] = mem[mem_i + 0] << 0 | mem[mem_i + 1] << 8 | mem[mem_i + 2]
                << 16 | mem[mem_i + 3] << 24;
        }
    }

    public void read_bytes(UWORD addr, ubyte[] buffer, size_t count) {
        for (int i = 0; i < count; i += 1) {
            auto mem_i = addr + i;
            buffer[i] = mem[mem_i];
        }
    }

    public void write_bytes(UWORD addr, ubyte[] buffer, size_t count) {
        for (int i = 0; i < count; i += 1) {
            auto mem_i = addr + i;
            mem[mem_i] = buffer[i];
        }
    }

    public Snapshot snapshot() {
        import std.algorithm.comparison: min;

        Snapshot snapshot;
        snapshot.reg = reg.dup[0 .. irre.encoding.instructions.REGISTER_COUNT];
        auto mem_base = 0x0;
        snapshot.memory_map ~= MemoryMap(MemoryMap.Type.Memory, mem_base, "mem0");
        // copy our memory into pages
        for (auto i = 0; i < mem.length; i += MemoryPageTable.PAGE_SIZE) {
            auto mem_addr = i;
            snapshot.tracked_mem.make_page(mem_addr);
            // copy memory block
            auto copy_start = mem_addr;
            auto copy_end = min(mem.length, mem_addr + MemoryPageTable.PAGE_SIZE);
            auto copy_size = copy_end - copy_start;
            snapshot.tracked_mem.pages[mem_addr].mem[0..copy_size] = mem[copy_start..copy_end];
        }
        return snapshot;
    }

    public void commit_snapshot() {
        if (!log_commits)
            return;

        commit_trace.snapshots ~= snapshot();
    }

    private string dump_decoded_instruction() {
        auto statement = reader.decompile(last_executed_instruction);
        auto statement_dump = dumper.format_statement(statement);
        return statement_dump;
    }

    public void commit_reg(UWORD reg_id, UWORD reg_value, Commit.Source[] sources) {
        commit_regs([reg_id], [reg_value], sources);
    }

    public void commit_regs(UWORD[] reg_ids, UWORD[] reg_values, Commit.Source[] sources) {
        if (!log_commits)
            return;

        auto commit = Commit()
            .with_type(InfoType.Register)
            .with_pc(last_program_counter)
            .with_dest_regs(reg_ids, reg_values)
            .with_sources(sources)
            .with_description(dump_decoded_instruction());
        commit_trace.commits ~= commit;
    }

    public void commit_mem(UWORD[] mem_addrs, BYTE[] mem_values, Commit.Source[] sources) {
        if (!log_commits)
            return;

        auto commit = Commit()
            .with_type(InfoType.Memory)
            .with_pc(last_program_counter)
            .with_dest_mem(mem_addrs, mem_values)
            .with_sources(sources)
            .with_description(dump_decoded_instruction());
        commit_trace.commits ~= commit;
    }

    private Commit.Source[] commit_source_regs(UWORD[] reg_ids, UWORD[] reg_values) {
        Commit.Source[] sources;
        for (auto i = 0; i < reg_ids.length; i += 1) {
            auto reg_id = reg_ids[i];
            auto reg_value = reg_values[i];
            sources ~= Commit.Source(InfoType.Register, reg_id, reg_value);
        }
        return sources;
    }

    private Commit.Source[] commit_source_mem(UWORD[] mem_addrs, BYTE[] mem_values) {
        Commit.Source[] sources;
        for (auto i = 0; i < mem_addrs.length; i += 1) {
            auto mem_addr = mem_addrs[i];
            auto mem_value = mem_values[i];
            sources ~= Commit.Source(InfoType.Memory, mem_addr, mem_value);
        }
        return sources;
    }
}

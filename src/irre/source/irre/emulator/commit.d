module irre.emulator.commit;

import irre.encoding.instructions;
import irre.encoding.rega;
import std.algorithm.mutation;
import irre.emulator.device;

struct Snapshot {
    public UWORD[REGISTER_COUNT] reg;
    public BYTE[] mem;
}

struct Commit {
    // what changed?
    enum Type {
        Register,
        Memory
    }

    Type type;
    UWORD reg_id;
    UWORD reg_value;
    UWORD mem_addr;
    UWORD mem_value;
    UWORD pc;
    string description;

    static Commit from_reg(UWORD reg_id, UWORD reg_value) {
        Commit c;
        c.type = Type.Register;
        c.reg_id = reg_id;
        c.reg_value = reg_value;
        return c;
    }

    static Commit from_mem(UWORD mem_addr, UWORD mem_value) {
        Commit c;
        c.type = Type.Memory;
        c.mem_addr = mem_addr;
        c.mem_value = mem_value;
        return c;
    }

    string toString() const {
        import std.string : format;
        import std.conv : to;
        import std.array: appender, array;

        auto type_str = type == Type.Register ? "reg" : "mem";
        auto sb = appender!string;
        
        // commit type
        sb ~= format("%s", type_str);
        // pc position
        sb ~= format(" @0x%04x", pc);

        // commit data
        if (type == Type.Register) {
            auto reg_id_show = reg_id.to!Register;
            sb ~= format(" %04s <- %04x", reg_id_show, reg_value);
        } else {
            sb ~= format(" mem[%04x] <- %04x", mem_addr, mem_value);
        }

        // commit description
        sb ~= format(" (%s)", description);

        return sb.array;
    }
}

struct CommitTrace {
    public Snapshot[] snapshots;
    public Commit[] commits;
}

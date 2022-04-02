module irre.emulator.commit;

import irre.encoding.instructions;
import irre.encoding.rega;
import std.algorithm.mutation;
import irre.emulator.device;

struct Snapshot {
    public UWORD[REGISTER_COUNT] reg;
    public BYTE[] mem;

    static Snapshot from(UWORD[REGISTER_COUNT] reg, BYTE[] mem) {
        Snapshot snapshot;
        snapshot.reg = reg.dup[0..REGISTER_COUNT];
        snapshot.mem = mem.dup;
        return snapshot;
    }
}

struct Commit {
    // what changed?
    enum Type {
        Combined,
        Register,
        Memory
    }

    Type type;
    UWORD[] reg_ids;
    UWORD[] reg_values;
    UWORD[] mem_addrs;
    BYTE[] mem_values;
    UWORD pc;
    string description;

    static Commit from_regs(UWORD[] reg_ids, UWORD[] reg_values) {
        Commit c;
        c.type = Type.Register;
        c.reg_ids = reg_ids;
        c.reg_values = reg_values;
        return c;
    }

    static Commit from_reg(UWORD reg_id, UWORD reg_value) {
        return from_regs([reg_id], [reg_value]);
    }

    static Commit from_mem(UWORD[] mem_addrs, BYTE[] mem_values) {
        Commit c;
        c.type = Type.Memory;
        c.mem_addrs = mem_addrs;
        c.mem_values = mem_values;
        return c;
    }

    string toString() const {
        import std.string : format;
        import std.conv : to;
        import std.array : appender, array;

        // auto type_str = type == Type.Register ? "reg" : "mem";
        string type_str;
        switch (type) {
        case Type.Register:
            type_str = "reg";
            break;
        case Type.Memory:
            type_str = "mem";
            break;
        case Type.Combined:
            type_str = "comb";
            break;
        default:
            assert(0);
        }

        auto sb = appender!string;

        // commit type
        sb ~= format("%s", type_str);
        // pc position
        sb ~= format(" @0x%04x", pc);

        // commit data
        if (type == Type.Register) {
            // auto reg_id_show = reg_id.to!Register;
            // sb ~= format(" %04s <- %04x", reg_id_show, reg_value);
            for (auto i = 0; i < reg_ids.length; i++) {
                auto reg_id = reg_ids[i];
                auto reg_value = reg_values[i];
                auto reg_id_show = reg_id.to!Register;
                sb ~= format(" %04s <- %04x", reg_id_show, reg_value);
            }
        } else {
            for (auto i = 0; i < mem_addrs.length; i++) {
                auto addr = mem_addrs[i];
                auto value = mem_values[i];
                sb ~= format(" mem[%04x] <- %04x", addr, value);
            }
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

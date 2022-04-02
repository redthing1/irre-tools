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
        snapshot.reg = reg.dup[0 .. REGISTER_COUNT];
        snapshot.mem = mem.dup;
        return snapshot;
    }
}

struct Commit {
    // what changed?
    enum Type {
        Combined,
        Register,
        Memory,
        Immediate,
    }

    private enum string[Type] _type_abbreviations = [
        Type.Combined: "cmb",
        Type.Register: "reg",
        Type.Memory: "mem",
        Type.Immediate: "imm",
    ];

    struct Source {
        public Type type; // register or memory source?
        public UWORD data; // can be register id or memory address
        public UWORD value; // can be register value or memory value
    }

    Type type;
    UWORD[] reg_ids;
    UWORD[] reg_values;
    UWORD[] mem_addrs;
    BYTE[] mem_values;
    UWORD pc;
    Source[] sources;
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

        string type_str = _type_abbreviations[type];

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

        // commit sources
        sb ~= format(" <source: ");
        for (auto i = 0; i < sources.length; i++) {
            auto source = sources[i];
            string source_type_str = _type_abbreviations[source.type];
            switch (source.type) {
            case Type.Register:
                sb ~= format(" %s=%04x", source.data.to!Register, source.value);
                break;
            case Type.Memory:
                sb ~= format(" mem[%04x]=%04x", source.data, source.value);
                break;
            case Type.Immediate:
                sb ~= format(" i=%04x", source.value);
                break;
            default:
                assert(0);
            }
        }
        sb ~= format(">");

        // commit description
        sb ~= format(" (%s)", description);

        return sb.array;
    }
}

struct CommitTrace {
    public Snapshot[] snapshots;
    public Commit[] commits;
}

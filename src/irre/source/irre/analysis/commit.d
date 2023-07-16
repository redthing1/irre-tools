module irre.analysis.commit;

static import irre.encoding.instructions;
// import irre.encoding.rega;
import std.algorithm.mutation;
// import irre.emulator.device;

alias IrreInfoLog = InfoLog!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    irre.encoding.instructions.Register,
    cast(int) irre.encoding.instructions.REGISTER_COUNT);

template InfoLog(TRegWord, TMemWord, TRegSet, int register_count) {
    template GenAliases(string prefix) {
        import std.format;

        enum GenAliases = format(`
            alias Snapshot = %s.Snapshot;
            alias Commit = %s.Commit;
            alias CommitTrace = %s.CommitTrace;
            alias InfoType = %s.InfoType;
            alias InfoNode = %s.InfoNode;
            alias InfoSource = %s.InfoSource;
            alias InfoSources = %s.InfoSources;
            alias ImmediatePos = %s.ImmediatePos;
        `, prefix, prefix, prefix, prefix, prefix, prefix, prefix, prefix);
    }

    struct Snapshot {
        public TRegWord[register_count] reg;
        public TMemWord[] mem;

        static Snapshot from(TRegWord[register_count] reg, TMemWord[] mem) {
            Snapshot snapshot;
            snapshot.reg = reg.dup[0 .. register_count];
            snapshot.mem = mem.dup;
            return snapshot;
        }
    }

    enum InfoType {
        Combined,
        Register,
        Memory,
        Immediate,
        Device,
        Reserved1,
        Reserved2,
        Reserved3,
        Reserved4,
    }

    enum ImmediatePos : TRegWord {
        NONE = (0 << 0),
        A = (1 << 0),
        B = (1 << 1),
        C = (1 << 2),
        D = (1 << 3),
        E = (1 << 4),
        F = (1 << 5),
        G = (1 << 6),
        H = (1 << 7),

        BC = B | C,

        ABC = A | B | C,
    }

    struct InfoNode {
        InfoType type; // information type: register or memory?
        TRegWord data; // can be register id or memory address
        TRegWord value; // can be register value or memory value

        string toString() const {
            import std.string : format;
            import std.conv : to;
            import std.array : appender, array;
            
            auto sb = appender!string;

            switch (type) {
                case InfoType.Register:
                    sb ~= format("%s=$%04x", data.to!TRegSet, value);
                    break;
                case InfoType.Memory:
                    sb ~= format("mem[$%04x]=%02x", data, value);
                    break;
                case InfoType.Immediate:
                    sb ~= format("i=$%04x", value);
                    break;
                case InfoType.Device:
                    sb ~= format("dev#%02x(%02x)", data, value);
                    break;
                default: assert(0);
            }

            return sb.array;
        }
    }

    struct Commit {
        private enum string[InfoType] _type_abbreviations = [
                InfoType.Combined: "cmb",
                InfoType.Register: "reg",
                InfoType.Memory: "mem",
                InfoType.Immediate: "imm",
                InfoType.Device: "dev",
            ];
        
        alias Source = InfoNode;

        InfoType type;
        TRegWord[] reg_ids;
        TRegWord[] reg_values;
        TRegWord[] mem_addrs;
        TMemWord[] mem_values;
        TRegWord pc;
        Source[] sources;
        string description;

        static Commit from_regs(TRegWord[] reg_ids, TRegWord[] reg_values) {
            Commit c;
            c.type = InfoType.Register;
            c.reg_ids = reg_ids;
            c.reg_values = reg_values;
            return c;
        }

        static Commit from_reg(TRegWord reg_id, TRegWord reg_value) {
            return from_regs([reg_id], [reg_value]);
        }

        static Commit from_mem(TRegWord[] mem_addrs, TMemWord[] mem_values) {
            Commit c;
            c.type = InfoType.Memory;
            c.mem_addrs = mem_addrs;
            c.mem_values = mem_values;
            return c;
        }

        InfoNode[] as_nodes() {
            InfoNode[] nodes;
            
            // check info type
            switch (type) {
                case InfoType.Combined:
                    assert(0, "combined commit is not supported to create info nodes");
                case InfoType.Register:
                    // add a node for each register
                    for (auto i = 0; i < reg_ids.length; i++) {
                        auto node = InfoNode(InfoType.Register, reg_ids[i], reg_values[i]);
                        nodes ~= node;
                    }
                    break;
                case InfoType.Memory:
                    // add a node for each memory address
                    for (auto i = 0; i < mem_addrs.length; i++) {
                        auto node = InfoNode(InfoType.Memory, mem_addrs[i], mem_values[i]);
                        nodes ~= node;
                    }
                    break;
                default:
                    assert(0, "invalid commit info type for creating info nodes");
            }

            return nodes;
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
            sb ~= format(" @0x$%04x", pc);

            // commit data
            if (type == InfoType.Register) {
                // auto reg_id_show = reg_id.to!TRegSet;
                // sb ~= format(" %04s <- $%04x", reg_id_show, reg_value);
                for (auto i = 0; i < reg_ids.length; i++) {
                    auto reg_id = reg_ids[i];
                    auto reg_value = reg_values[i];
                    auto reg_id_show = reg_id.to!TRegSet;
                    sb ~= format(" %04s <- $%04x", reg_id_show, reg_value);
                }
            } else {
                for (auto i = 0; i < mem_addrs.length; i++) {
                    auto addr = mem_addrs[i];
                    auto value = mem_values[i];
                    sb ~= format(" mem[$%04x] <- %02x", addr, value);
                }
            }

            // commit sources
            sb ~= format(" <source: ");
            for (auto i = 0; i < sources.length; i++) {
                auto source = sources[i];
                // string source_type_str = _type_abbreviations[source.type];
                // switch (source.type) {
                // case InfoType.Register : sb ~= format(" %s=$%04x", source.data.to!TRegSet, source.value);
                //     break;
                // case InfoType.Memory : sb ~= format(" mem[$%04x]=%02x", source.data, source.value);
                //     break;
                // case InfoType.Immediate : sb ~= format(" i=$%04x", source.value);
                //     break;
                // case InfoType.Device : sb ~= format(" dev#%02x(%02x)", source.data, source.value);
                // default : assert(0);
                // }
                sb ~= format(" %s", source.toString());
            }
            sb ~= format(">");

            // commit description
            sb ~= format(" (%s)", description);

            return sb.array;
        }
    }

    struct InfoSource {
        InfoNode node;
        long commit_id;

        string toString() const {
            import std.string : format;
            import std.conv : to;
            import std.array : appender, array;

            auto sb = appender!string;

            sb ~= format("InfoSource(node: %s, commit_id: %s)", node, commit_id);

            return sb.array;
        }

        /** returns whether this is a final/deterministic source */
        bool is_final() const {
            return node.type == InfoType.Immediate;
        }
    }
    alias InfoSources = InfoSource[];

    struct CommitTrace {
        public Snapshot[] snapshots;
        public Commit[] commits;
    }
}
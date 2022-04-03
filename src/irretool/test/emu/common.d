module irretool.test.emu.common;

public {
    import std.conv;
    import std.array;
    import std.format;

    import irre.util;
    import irre.meta;
    import irre.encoding.rega;
    import irre.encoding.instructions;
    import irre.emulator.vm;
    import irre.emulator.hypervisor;

    import irretool.test.asmr.common;
    import irretool.test.code;
}

Hypervisor create_hypervisor() {
    auto vm = new VirtualMachine();
    vm.initialize();

    // create a hypervisor
    auto hyp = new Hypervisor(vm);

    // add basic IO support
    hyp.add_default_devices();
    hyp.add_debug_interrupt_handlers();

    return hyp;
}

Hypervisor create_hypervisor_for(ubyte[] program) {
    // load the program
    auto hyp = create_hypervisor();
    auto header = hyp.vm.load(program);

    return hyp;
}

void verify_program(TestProgram prg, long exec_steps, UWORD[Register] expect) {
    auto bin = compile_program(prg);
    auto hyp = create_hypervisor_for(bin);

    hyp.run(exec_steps); // bound how many steps

    // check result
    struct Mistake {
        Register reg;
        UWORD expect;
        UWORD actual;
    }

    auto regs = hyp.vm.reg;

    auto sb = appender!string;
    Mistake[] mistakes;

    for (auto i = 0; i < REGISTER_COUNT; i++) {
        auto reg_id = i.to!Register;
        auto reg_value = regs[reg_id];

        if (reg_id !in expect) {
            continue;
        }

        auto expect_value = expect[reg_id];

        if (reg_value != expect_value) {
            mistakes ~= Mistake(reg_id, expect_value, reg_value);
            sb ~= format(" (reg %s=$%04x (expect $%04x))", reg_id, reg_value, expect_value);
        }
    }

    assert(mistakes.length == 0, format("prog %s incorrect:%s", prg.name, sb.array));
}

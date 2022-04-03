module irretool.test.emu.vm;

import irretool.test.asmr.common;
import irretool.test.emu.common;

@("vm.basic.init")
unittest {
    try {
        auto hyp = create_hypervisor();
    } catch (Exception e) {
        assert(0, format("failed to create hypervisor: %s", e));
    }
}

@("vm.basic.basicprog")
unittest {
    auto bin = compile_program(PROG_BASIC);
    auto hyp = create_hypervisor_for(bin);

    hyp.run(1024); // run up to 1024 steps
}

@("vm.exec.fib2")
unittest {
    auto prg = PROG_FIB2;
    auto bin = compile_program(prg);
    auto hyp = create_hypervisor_for(bin);

    hyp.run(1024); // run up to 1024 steps

    // check result
    struct Mistake {
        Register reg;
        UWORD expect;
        UWORD actual;
    }

    auto regs = hyp.vm.reg;
    UWORD[Register] expect = [
        Register.R0: 0x08
    ];

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

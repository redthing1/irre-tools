module irretool.test.emu.test_vm;

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
    verify_program(PROG_FIB2, 1024, [
        Register.R0: 0x08,
    ]);
}

@("vm.exec.fib3")
unittest {
    verify_program(PROG_FIB3, 2400, [
        Register.R0: 121393,
    ]);
}

@("vm.exec.shuffle1")
unittest {
    verify_program(PROG_SHUFFLE1, 32000, [
        Register.R0: 0xad44f200,
    ]);
}

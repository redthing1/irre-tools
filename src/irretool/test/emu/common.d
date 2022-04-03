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

// void ensure_programs_assemble(immutable TestProgram[] progs) {
//     foreach (prg; progs) {
//         try {
//             auto lex = lex_program(prg.source);
//             auto ast = parse_lex(lex);

//             assert(ast.statements.length > 0,
//                 format("program: %s did not assemble correctly", prg.name));
//         } catch (Exception e) {
//             assert(false,
//                 format("program: %s failed to assemble with exception: %s", prg.name, e));
//         }
//     }
// }

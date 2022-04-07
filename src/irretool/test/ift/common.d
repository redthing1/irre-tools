module irretool.test.ift.common;


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

    import irre.analysis.commit;
    import irre.analysis.ift;

    import irretool.test.asmr.common;
    import irretool.test.emu.common;

    import irretool.test.code;
}

mixin(IrreInfoLog.GenAliases!("IrreInfoLog"));

Hypervisor create_hypervisor_with_commit_log_for(ubyte[] program) {
    auto hyp = create_hypervisor_for(program);
    hyp.enable_commit_log();

    return hyp;
}

alias IFTAnalyzer = IrreIFTAnalysis.IFTAnalyzer;

IFTAnalyzer test_ift(TestProgram prg, long exec_steps) {
    auto bin = compile_program(prg);
    auto hyp = create_hypervisor_with_commit_log_for(bin);

    hyp.run(exec_steps); // bound how many steps
    auto trace = hyp.vm.commit_trace;

    assert(trace.commits.length > 0, "expected at least one commit");
    assert(trace.snapshots.length == 2, "expected two snapshots");

    auto ift_analyzer = new IFTAnalyzer(trace);

    // run ift
    // ift_analyzer.analysis_parallelized = true;
    ift_analyzer.analyze();

    // check result?

    return ift_analyzer;
}


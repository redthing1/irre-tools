module irretool.test.ift.test_ift;

import irretool.test.ift.common;

@("ift.simple.ift4")
unittest {
    // just make sure it can even run
    test_ift(PROG_IFT4, 256);
}

@("ift.verify.ift4")
unittest {
    // run, then verify results
    auto ift = test_ift(PROG_IFT4, 256);

    auto reg_src = ift.clobbered_regs_sources;
    import std.stdio;
    
    // check R0 sources
    // assert(reg_src[Register.R0].length = 4);
    // assert(reg_src[Register.R0][0].node.type == InfoType.Immediate);
    // assert(reg_src[Register.R0][0].commit_id == 2,
    auto r0 = reg_src[Register.R0];
    assert(r0[0].node.type == InfoType.Immediate,
        format("expected node type for R0[0] to be Immediate, but was %s", r0[0].node.type));
    assert(r0[0].commit_id == 2,
        format("expected commit id for R0[0] to be 2, but was %d", r0[0].commit_id));
    
    auto r0_1 = r0[1];
    assert(r0_1.node.type == InfoType.Immediate,
        format("expected node type for R0[1] to be Immediate, but was %s", r0_1.node.type));
    assert(r0_1.commit_id == 3,
        format("expected commit id for R0[1] to be 3, but was %d", r0_1.commit_id));
    
    auto r0_2 = r0[2];
    assert(r0_2.node.type == InfoType.Immediate,
        format("expected node type for R0[2] to be Immediate, but was %s", r0_2.node.type));
    assert(r0_2.commit_id == 5,
        format("expected commit id for R0[2] to be 5, but was %d", r0_2.commit_id));
    
    auto r0_3 = r0[3];
    assert(r0_3.node.type == InfoType.Immediate,
        format("expected node type for R0[3] to be Immediate, but was %s", r0_3.node.type));
    assert(r0_3.commit_id == 6,
        format("expected commit id for R0[3] to be 6, but was %d", r0_3.commit_id));
    

    // check memory cell sources counts
    auto mem_src = ift.clobbered_mem_sources;

    auto mem_src_fff8 = mem_src[0xfff8];
    assert(mem_src_fff8.length = 6,
        format("expected memory cell sources for 0xfff8 to be 6, but was %d", mem_src_fff8.length));
    auto mem_src_fffc = mem_src[0xfffc];
    assert(mem_src_fffc.length = 4,
        format("expected memory cell sources for 0xfffc to be 4, but was %d", mem_src_fffc.length));
}

module irretool.test.code;

// enum PROG_BASIC_ADD = `
// %entry :main

// main:
//     set r1 #10
//     set r2 #-5
//     add r0 r1 r2
//     hlt
// `;

struct TestProgram {
    string name;
    string source;
}

template make_test_prog(string name, string path) {
    import std.format;
    const char[] make_test_prog =
        format(`
            enum PROG_%s = TestProgram(
                "%s",
                import("%s")
            );
        `, name, name, path);
}

mixin(make_test_prog!("BASIC", "asm/basic.asm"));
mixin(make_test_prog!("BIGPROG", "asm/big_prog.asm"));
mixin(make_test_prog!("FUNC", "asm/func.asm"));
mixin(make_test_prog!("MEM", "asm/mem.asm"));

mixin(make_test_prog!("ASMV5", "asm/asmv5.asm"));

mixin(make_test_prog!("MACRO", "asm/macro.asm"));
mixin(make_test_prog!("COND_BRANCH", "asm/cond_branch.asm"));
mixin(make_test_prog!("COND_NOBRANCH", "asm/cond_nobranch.asm"));

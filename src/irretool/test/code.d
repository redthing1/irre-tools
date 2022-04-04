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

mixin(make_test_prog!("FIB2", "c_basic/fib_2.ire"));
mixin(make_test_prog!("FIB3", "c_basic/fib_3.ire"));
mixin(make_test_prog!("SHUFFLE1", "c_basic/shuffle1.ire"));

mixin(make_test_prog!("IFT1", "ift/ift1.asm"));
mixin(make_test_prog!("IFT2", "ift/ift2.asm"));
mixin(make_test_prog!("IFT3", "ift/ift3.asm"));
mixin(make_test_prog!("IFT4", "ift/ift4.asm"));
mixin(make_test_prog!("IFT5", "ift/ift5.asm"));

static immutable PROGS_SET_SIMPLE = [PROG_BIGPROG, PROG_FUNC, PROG_MEM, PROG_COND_BRANCH, PROG_COND_NOBRANCH];
static immutable PROGS_SET_ASMSYNTAX = [PROG_ASMV5, PROG_MACRO];
static immutable PROGS_SET_C_BASIC = [PROG_FIB2, PROG_FIB3, PROG_SHUFFLE1];
static immutable PROGS_SET_IFT = [PROG_IFT1, PROG_IFT2, PROG_IFT3, PROG_IFT4, PROG_IFT5];

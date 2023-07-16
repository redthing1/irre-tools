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

// enum PROG_BASIC = import("asm/basic.asm");
mixin(make_test_prog!("BASIC", "asm/basic.asm"));
mixin(make_test_prog!("BIGPROG", "asm/big_prog.asm"));
mixin(make_test_prog!("FUNC", "asm/func.asm"));
mixin(make_test_prog!("MEM", "asm/mem.asm"));

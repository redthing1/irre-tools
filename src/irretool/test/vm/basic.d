module irretool.test.vm.basic;

import irre.emulator.vm;
import irre.emulator.hypervisor;

@("vm.basic.init")
unittest {
    auto vm = new VirtualMachine();
    vm.initialize();
}
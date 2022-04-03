module irretool.test.vm_basic;

import irre.emulator.vm;
import irre.emulator.hypervisor;

@("vm_basic.init")
unittest {
    auto vm = new VirtualMachine();
    vm.initialize();
}
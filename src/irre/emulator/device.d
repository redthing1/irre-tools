module irre.emulator.device;

public import irre.emulator.vm;

/** represents a device for the IRRE VM machine */
abstract class Device {
    private VirtualMachine vm;
    public int id;

    public void initialize(VirtualMachine vm, int id) {
        this.vm = vm;
        this.id = id;
    }

    public abstract void recieve(WORD command, WORD data);
}
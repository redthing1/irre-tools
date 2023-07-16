module irre.analysis.irre_arch;

static import irre.encoding.instructions;
import infoflow.models;
import infoflow.analysis.ift;

alias IrreInfoLog = InfoLog!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    irre.encoding.instructions.Register);

alias IrreIFTAnalysis = IFTAnalysis!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    irre.encoding.instructions.Register);
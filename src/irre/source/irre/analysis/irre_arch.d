module irre.analysis.irre_arch;

static import irre.encoding.instructions;
import infoflow.models;
import infoflow.analysis.ift;
import infoflow.analysis.regtouch;

alias IrreRegister = irre.encoding.instructions.Register;

alias IrreInfoLog = InfoLog!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    IrreRegister);

alias IrreIFTAnalysis = IFTAnalysis!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    IrreRegister);

alias IrreIFTDump = IFTAnalysisDump!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    IrreRegister);

alias IrreRegTouchAnalysis = RegTouchAnalysis!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    IrreRegister);

alias IrreIFTOptimizer = IFTAnalysisOptimizer!(
    irre.encoding.instructions.UWORD,
    irre.encoding.instructions.BYTE,
    IrreRegister);
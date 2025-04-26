# IRRE/view_rega.py
# defines the binaryview for the rega file format.

import struct
from typing import Optional

from binaryninja.binaryview import BinaryView
from binaryninja.enums import SegmentFlag, SectionSemantics, SymbolType
from binaryninja.architecture import Architecture
from binaryninja.types import Symbol  # for symbol table parsing

# rega header constants
REGA_MAGIC = b"rg"
REGA_HEADER_SIZE = 4  # 2 bytes magic, 2 bytes program_size


class REGAView(BinaryView):
    name = "REGA"
    long_name = "IRRE REGA Binary"

    def __init__(self, data):
        BinaryView.__init__(self, parent_view=data, file_metadata=data.file)
        self.platform = Architecture[
            "IRRE"
        ].standalone_platform  # use the registered irre architecture
        self.raw = data  # keep a reference to the raw data

    @classmethod
    def is_valid_for_data(self, data) -> bool:
        # check for the "rg" magic bytes at the beginning of the file
        magic = data.read(0, len(REGA_MAGIC))
        return magic == REGA_MAGIC

    def init(self) -> bool:
        try:
            # read program size from the header (ushort, little-endian at offset 2)
            program_size_bytes = self.raw.read(2, 2)
            if len(program_size_bytes) < 2:
                print("rega error: could not read program size from header.")
                return False
            program_size = struct.unpack("<H", program_size_bytes)[0]

            # define segments/sections
            # the rega format seems to be flat: header followed by code/data.
            # map the program content (after the header) into memory.
            # let's map it starting at address 0 for simplicity, unless the architecture implies otherwise.
            # the entry point will be the start of this mapped region.
            # the 'program_size' is the size *after* the header.
            load_addr = 0x0000  # load address for the program code/data
            file_offset = REGA_HEADER_SIZE
            length = program_size

            # add a single segment for the entire program code/data
            # mark as read+execute. data might be mixed with code.
            self.add_auto_segment(
                load_addr,
                length,
                file_offset,
                length,
                SegmentFlag.SegmentReadable | SegmentFlag.SegmentExecutable,
            )

            # add a section covering this segment for better analysis context
            self.add_auto_section(
                ".text",
                load_addr,
                length,
                SectionSemantics.ReadOnlyCodeSectionSemantics,
            )  # assume code/data mix

            # define the entry point - start of the code/data block
            self.add_entry_point(load_addr)

            # --- optional: symbol table parsing ---
            # the rega.d file describes a symbol table, but it's unclear if it's
            # part of the standard executable format or just for object files.
            # if symbols are present *after* the main code/data block in the file,
            # we could parse them here. this requires knowing the exact format
            # described in rega.d: length_of_symbols_array (u32), then for each symbol:
            # name (char[] -> requires length prefix?), offset (int32)
            # assuming name is null-terminated for simplicity here, adjust if needed
            symbol_table_offset = file_offset + length
            try:
                # read symbol count (assuming u32 little-endian)
                count_bytes = self.raw.read(symbol_table_offset, 4)
                if len(count_bytes) < 4:
                    raise ValueError("not enough data for symbol count")
                symbol_count = struct.unpack("<I", count_bytes)[0]
                current_offset = symbol_table_offset + 4

                print(
                    f"rega: found {symbol_count} symbols at offset 0x{symbol_table_offset:x}"
                )

                for i in range(symbol_count):
                    # read name (assuming null-terminated string)
                    name_bytes = b""
                    while True:
                        char_byte = self.raw.read(current_offset, 1)
                        if not char_byte or char_byte == b"\x00":
                            current_offset += 1  # consume null terminator
                            break
                        name_bytes += char_byte
                        current_offset += 1
                        if len(name_bytes) > 256:  # sanity check length
                            raise ValueError(
                                f"symbol name too long at offset {current_offset}"
                            )

                    name = name_bytes.decode("utf-8", errors="replace")  # decode name

                    # read symbol offset (int32 little-endian)
                    sym_offset_bytes = self.raw.read(current_offset, 4)
                    if len(sym_offset_bytes) < 4:
                        raise ValueError(
                            f"not enough data for symbol offset for '{name}'"
                        )
                    sym_offset = struct.unpack("<i", sym_offset_bytes)[
                        0
                    ]  # signed offset
                    current_offset += 4

                    # define symbol in binja (adjust address based on load_addr)
                    # assume function symbol for now, could be data too
                    sym_addr = load_addr + sym_offset
                    print(f"  symbol '{name}' -> 0x{sym_addr:x} (offset {sym_offset})")
                    self.define_auto_symbol(
                        Symbol(SymbolType.FunctionSymbol, sym_addr, name)
                    )

            except Exception as sym_e:
                # check if it's just end of file or a real parsing error
                if len(self.raw.read(symbol_table_offset, 1)) == 0:
                    pass  # no symbol table present, that's okay
                else:
                    # only print warning if we expected symbols but failed
                    if "symbol_count" in locals() and symbol_count > 0:
                        print(
                            f"rega warning: failed during symbol table parsing: {sym_e}"
                        )
                    # else: it's likely just no symbol table present after code/data
            # --- end optional symbol parsing ---

            return True

        except Exception as e:
            print(f"error loading rega file: {e}")
            return False

    def perform_is_executable(self) -> bool:
        # this file format contains executable code
        return True

    def perform_get_entry_point(self) -> int:
        # entry point is defined in init() as the start of the mapped code segment
        # typically the first entry point added is returned by default,
        # but we can explicitly return the intended start address.
        return 0x0000  # matches the load_addr used in init()

    # optional: add perform_get_address_size if different from arch default
    def perform_get_address_size(self) -> int:
        return 4 # irre is 32-bit

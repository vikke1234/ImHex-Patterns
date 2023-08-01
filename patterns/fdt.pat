#pragma endian big

#include <std/sys.pat>
#include <std/io.pat>
#include <std/core.pat>

#include <type/magic.pat>
#include <type/size.pat>

u64 fdt_addr;
u64 str_offset;

using FDT;


struct FDTHeader {
    type::Magic<"\xD0\x0D\xFE\xED"> magic;
    u32 totalsize;
    u32 off_dt_struct;
    u32 off_dt_strings;
    u32 off_mem_rsvmap;
    u32 version;
    u32 last_comp_version;
    u32 boot_cpuid_phys;
    u32 size_dt_strings;
    u32 size_dt_struct;
};

struct AlignTo<auto Alignment> {
    padding[Alignment- ((($ - 1) % Alignment) + 1)];
} [[hidden]];

struct FDTReserveEntry {
    u64 address;
    type::Size<u64> size;

    if (address == 0x00 && size == 0x00)
        break;
};

enum FDTToken : u32 {
    FDT_BEGIN_NODE = 0x00000001,
    FDT_END_NODE   = 0x00000002,
    FDT_PROP       = 0x00000003,
    FDT_NOP        = 0x00000004,
    FDT_END        = 0x00000009
};

struct FDTProp {
    FDTToken tok[[hidden]];
    u32 len [[hidden]];
    u32 nameoff [[hidden]];
    u8 value[len];
    AlignTo<4>;
    std::print(std::format("{:x} token {} len {} value {} {}", $, tok, len, value, nameoff));
    char name[] @ fdt_addr + str_offset + nameoff;
    std::core::set_display_name(this, name);
    FDTToken token = std::mem::read_unsigned($, 4, std::mem::Endian::Big);
    if (token != FDTToken::FDT_PROP) {
        break;
    }
};

struct FDTNode {
    FDTToken token = std::mem::read_unsigned($, 4, std::mem::Endian::Big);


    if (token == FDTToken::FDT_BEGIN_NODE) {
        FDTToken tok[[hidden]];
        char name[];
        AlignTo<4>;
        std::core::set_display_name(this, name[0] ? name : "/");
        token = std::mem::read_unsigned($, 4, std::mem::Endian::Big);
        if(token == FDTToken::FDT_PROP) {
            FDTProp props[while(true)];
        }
        token = std::mem::read_unsigned($, 4, std::mem::Endian::Big);
        if(token == FDTToken::FDT_END_NODE) {
            FDTToken[[hidden]];
            break;
        }
        FDTNode children[while(true)][[inline]];
    } else if(token == FDTToken::FDT_NOP) {
        // do nothing
    }
    // ew duplication
    token = std::mem::read_unsigned($, 4, std::mem::Endian::Big);
    if(token == FDTToken::FDT_END_NODE) {
        FDTToken tok[[hidden]];
        break;
    }
};

struct FDTStructureBlock {
    FDTNode;
};


struct FDT {
    FDTHeader header;
    std::assert(header.version == 17, "Unsupported format version");
    fdt_addr = addressof(this);
    str_offset = header.off_dt_strings;

    FDTStructureBlock structureBlocks @ fdt_addr + header.off_dt_struct;
    FDTReserveEntry reserveEntries[while(true)] @ fdt_addr + header.off_mem_rsvmap;
};

std::mem::MagicSearch<"\xD0\x0D\xFE\xED", FDT> fdt @ std::mem::base_address();

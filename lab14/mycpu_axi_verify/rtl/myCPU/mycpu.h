`ifndef MYCPU_H
    `define MYCPU_H
//make all the bus 300 bits (convenient)
    `define BR_BUS_WD       34 //32 + 1 + 1
    `define FS_TO_DS_BUS_WD 300//64 + 1(exec_ADEF)
    `define DS_TO_ES_BUS_WD 300//151+ 3(mul_div) + 3(ld) + 2(st) + 4(exec_INE,exec_SYS,exec_BRK) + 14(csr_num) + 1(csr_we)
                               //                 8                          19
    `define ES_TO_MS_BUS_WD 320 //71 + 1 + 3(ld) + 2(st) + 2(ld_off) + 5(exec_ALE) + 32(vaddr) + 14(csr_num) + 1(csr_we)
                                //                8                                  51
    `define MS_TO_WS_BUS_WD 300 //70 + 5(execeptions) + 32(vaddr) + 14(csr_num) + 1(csr_we)
                                //                    51
    `define WS_TO_RF_BUS_WD 38
    `define DATA_RISK_BUS   117//15 + 1 + 5 + 32 * 3
    
    `define CSR_CRMD_PLV        1:0
    `define CSR_CRMD_PIE        2
    `define CSR_CRMD_DA         3
    `define CSR_CRMD_PG         4
    `define CSR_PRMD_PPLV       1:0
    `define CSR_PRMD_PIE        2
    `define CSR_ECFG_LIE        12:0
    `define CSR_ESTAT_IS10      1:0
    `define CSR_TICLR_CLR       0
    `define CSR_ERA_PC          31:0
    `define CSR_EENTRY_VA       31:6
    `define CSR_SAVE_DATA       31:0
    `define CSR_TID_TID         31:0
    `define CSR_TCFG_EN         0
    `define CSR_TCFG_PERIOD     1
    `define CSR_TCFG_INITV      31:2
    `define CSR_TCFG_INITVAL    31:2
    `define CSR_TLBIDX_INDEX  3 :0
    `define CSR_TLBIDX_PS     29:24
    `define CSR_TLBIDX_NE     31
    `define CSR_TLBEHI_VPPN   31:13
    `define CSR_TLBELO_V      0
    `define CSR_TLBELO_D      1
    `define CSR_TLBELO_PLV    3 :2
    `define CSR_TLBELO_MAT    5 :4
    `define CSR_TLBELO_G      6
    `define CSR_TLBELO_PPN    31:8
    `define CSR_TLBRENTRY_PA  31:6
    `define CSR_ASID_ASID     9 :0
    `define CSR_ASID_ASIDBITS 23:16
    `define CSR_DMW_PLV0      0
    `define CSR_DMW_PLV3      3
    `define CSR_DMW_MAT       5 :4
    `define CSR_DMW_PSEG      27:25
    `define CSR_DMW_VSEG      31:29
//CSR NUM
`define CSR_CRMD            0
    `define CSR_PRMD        1
    `define CSR_ECFG        4
    `define CSR_ESTAT       5
    `define CSR_ERA         6
    `define CSR_BADV        7
    `define CSR_EENTRY      12
    `define CSR_TLBIDX      16//0x10
    `define CSR_TLBEHI      17//0x11
    `define CSR_TLBELO0     18//0x12
    `define CSR_TLBELO1     19//0x13
    `define CSR_ASID        24
    `define CSR_SAVE0       48
    `define CSR_SAVE1       49
    `define CSR_SAVE2       50
    `define CSR_SAVE3       51
    `define CSR_TID         64
    `define CSR_TCFG        65
    `define CSR_TVAL        66
    `define CSR_TICLR       68
    `define CSR_TLBRENTRY   136
    `define CSR_DMW0        384
    `define CSR_DMW1        385
    //ECODE
    `define ECODE_INT       0
    `define ECODE_PIL       1
    `define ECODE_PIS       2
    `define ECODE_PIF       3
    `define ECODE_PME       4
    `define ECODE_PPI       7
    `define ECODE_ADE       8
    `define ESUBCODE_ADEF   0
    `define ESUBCODE_ADEM   1
    `define ECODE_ALE       9
    `define ECODE_SYS       11
    `define ECODE_BRK       12
    `define ECODE_INE       13
    `define ECODE_TLBR      63
`endif

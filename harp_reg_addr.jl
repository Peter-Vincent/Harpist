#=
This file contains definitions (input output stream, registers and addresses) required to understand the data in the harp binaries.

Message protocol
https://github.com/harp-tech/protocol/blob/master/Binary%20Protocol%201.0%201.1%2020180223.pdf

Register and Addresses
https://bitbucket.org/fchampalimaud/device.behavior/src/master/Firmware/Behavior/app_ios_and_regs.h
=#

payloadtypes = Dict([
    (1 , UInt8),
    (2 , UInt16),
    (4 , UInt32),
    (8 , UInt64),
    (129 , Int8),
    (130 , Int16),
    (132 , Int32),
    (136 , Int64),
    (68  , Float32)
])

registerbits_A = Dict([
    (0, "PORT0_DO"),
    (1, "PORT1_DO"),
    (2, "PORT2_DO"),
    (3, "PORT0_12V"),
    (4, "PORT1_12V"),
    (5, "PORT2_12V"),
    (6, "LED0"),
    (7, "LED1"),
    (8, "RGB0"),
    (9, "RGB1"),
    (10,"DO0"),
    (11,"DO1"),
    (12,"DO2"),
    (13,"DO3")
])

registeradds_A = Dict([
    (46, "PORT0_DO"),
    (47, "PORT1_DO"),
    (48, "PORT2_DO"),
    (49, "PORT0_12V"),
    (50, "PORT1_12V"),
    (51, "PORT2_12V"),
    (52, "LED0"),
    (53, "LED1"),
    (54, "RGB0"),
    (55, "RGB1"),
    (56,"DO0"),
    (57,"DO1"),
    (58,"DO2"),
    (59,"DO3")
])

registeradds_PWM = Dict([
    (60, "FREQ_PWM_DO0"),
    (61, "FREQ_PWM_DO1"),
    (62, "FREQ_PWM_DO2"),
    (63, "FREQ_PWM_DO3"),
    (64, "DCYC_PWM_DO0"),
    (65, "DCYC_PWM_DO0"),
    (66, "DCYC_PWM_DO0"),
    (67, "DCYC_PWM_DO0"),
    (68, "PWM_START"),
    (69, "PWM_STOP")
])






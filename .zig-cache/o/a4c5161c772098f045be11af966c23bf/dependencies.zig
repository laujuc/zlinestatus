pub const packages = struct {
    pub const @"N-V-__8AAJC3GAC2LeGXShVNoV0oWVW9T293JVzmx0kY5KVa" = struct {
        pub const build_root = "/home/ljuc/.cache/zig/p/N-V-__8AAJC3GAC2LeGXShVNoV0oWVW9T293JVzmx0kY5KVa";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"N-V-__8AAKVpDQArujwc7m_Z--ypCGFKQ4yb10QdjR99hoEf" = struct {
        pub const build_root = "/home/ljuc/.cache/zig/p/N-V-__8AAKVpDQArujwc7m_Z--ypCGFKQ4yb10QdjR99hoEf";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
    pub const @"shimizu-0.1.1-irfMUUAwBAD8QD5BxR2ojneUIYRA5-LbOgGRcuXQzZXj" = struct {
        pub const build_root = "/home/ljuc/.cache/zig/p/shimizu-0.1.1-irfMUUAwBAD8QD5BxR2ojneUIYRA5-LbOgGRcuXQzZXj";
        pub const build_zig = @import("shimizu-0.1.1-irfMUUAwBAD8QD5BxR2ojneUIYRA5-LbOgGRcuXQzZXj");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "wayland", "N-V-__8AAJC3GAC2LeGXShVNoV0oWVW9T293JVzmx0kY5KVa" },
            .{ "wayland-protocols", "N-V-__8AAKVpDQArujwc7m_Z--ypCGFKQ4yb10QdjR99hoEf" },
            .{ "xml", "xml-0.1.0-ZTbP36goAgCTL5kYRoBLW9zxW_7b1aF1GyqgIj80qj1D" },
        };
    };
    pub const @"xml-0.1.0-ZTbP36goAgCTL5kYRoBLW9zxW_7b1aF1GyqgIj80qj1D" = struct {
        pub const build_root = "/home/ljuc/.cache/zig/p/xml-0.1.0-ZTbP36goAgCTL5kYRoBLW9zxW_7b1aF1GyqgIj80qj1D";
        pub const build_zig = @import("xml-0.1.0-ZTbP36goAgCTL5kYRoBLW9zxW_7b1aF1GyqgIj80qj1D");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const @"z2d-0.9.0-j5P_Hu-WFgA_JEfRpiFss6gdvcvS47cgOc0Via2eKD_T" = struct {
        pub const build_root = "/home/ljuc/.cache/zig/p/z2d-0.9.0-j5P_Hu-WFgA_JEfRpiFss6gdvcvS47cgOc0Via2eKD_T";
        pub const build_zig = @import("z2d-0.9.0-j5P_Hu-WFgA_JEfRpiFss6gdvcvS47cgOc0Via2eKD_T");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "shimizu", "shimizu-0.1.1-irfMUUAwBAD8QD5BxR2ojneUIYRA5-LbOgGRcuXQzZXj" },
    .{ "z2d", "z2d-0.9.0-j5P_Hu-WFgA_JEfRpiFss6gdvcvS47cgOc0Via2eKD_T" },
};

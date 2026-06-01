//! Dummy file to export docs for both shimizu and wayland-protocols

pub const shimizu = @import("shimizu");
pub const @"wayland-protocols" = @import("wayland-protocols");

comptime {
    _ = shimizu;
    _ = @"wayland-protocols";
}

const echo = @import("echo.zig");
const uniqueIds = @import("unique-ids.zig");

pub fn main() !void {
    try uniqueIds.uniqueIds();
}

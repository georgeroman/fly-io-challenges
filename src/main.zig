const echo = @import("./challenges/echo.zig");
const uniqueIds = @import("./challenges/unique-ids.zig");
const broadcast1 = @import("./challenges/broadcast-1.zig");

pub fn main() !void {
    try broadcast1.broadcast1();
}

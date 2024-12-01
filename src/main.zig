const echo = @import("./challenges/echo.zig");
const uniqueIds = @import("./challenges/unique-ids.zig");
const broadcast1 = @import("./challenges/broadcast-1.zig");
const broadcast2 = @import("./challenges/broadcast-2.zig");
const broadcast3 = @import("./challenges/broadcast-3.zig");

pub fn main() !void {
    try broadcast3.broadcast3();
}

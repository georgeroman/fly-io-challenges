const std = @import("std");

pub fn stringify(obj: anytype, allocator: std.mem.Allocator) ![]const u8 {
    var string = std.ArrayList(u8).init(allocator);
    try std.json.stringify(obj, .{}, string.writer());
    return string.items;
}

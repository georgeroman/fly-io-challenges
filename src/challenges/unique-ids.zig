const std = @import("std");

const node = @import("../node.zig");
const utils = @import("../utils.zig");

const InMsg = struct { src: []const u8, dest: []const u8, body: struct { type: []const u8, msg_id: u32 } };

var numericId: u32 = 0;
fn f(msgId: u32, msg: []const u8, nodeId: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    // Parse the raw message into an `InMsg` struct
    const parsed = try std.json.parseFromSlice(InMsg, allocator, msg, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    const inMsg = parsed.value;

    // Build the unique id based on the node id and a local increment numeric id
    var id = std.ArrayList(u8).init(allocator);
    try id.writer().print("{s}:{d}", .{ nodeId, numericId });
    defer id.deinit();

    // Increment the local numeric id
    numericId += 1;

    const response = .{ .src = nodeId, .dest = inMsg.src, .body = .{ .type = "generate_ok", .msg_id = msgId, .in_reply_to = inMsg.body.msg_id, .id = id.items } };

    return utils.stringify(response, allocator);
}

pub fn uniqueIds() !void {
    try node.run(f);
}

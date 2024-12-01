const std = @import("std");

const node = @import("../node.zig");

var numericId: u32 = 0;
fn f(n: *node.Node, msg: []const u8) !void {
    const GenerateMsg = struct { src: []const u8, dest: []const u8, body: struct { type: []const u8, msg_id: u32 } };

    // Parse the raw message into an `InMsg` struct
    const parsed = try std.json.parseFromSlice(GenerateMsg, n.allocator, msg, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    const parsedMsg = parsed.value;

    // Build the unique id based on the node id and a local increment numeric id
    var id = std.ArrayList(u8).init(n.allocator);
    try id.writer().print("{s}:{d}", .{ n.nodeId, numericId });
    defer id.deinit();

    // Increment the local numeric id
    numericId += 1;

    const response = .{ .src = n.nodeId, .dest = parsedMsg.src, .body = .{ .type = "generate_ok", .msg_id = n.getMsgId(), .in_reply_to = parsedMsg.body.msg_id, .id = id.items } };
    try n.send(response);
}

pub fn uniqueIds() !void {
    try node.run(f);
}

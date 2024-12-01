const std = @import("std");

const node = @import("../node.zig");
const utils = @import("../utils.zig");

const InMsg = struct { src: []const u8, dest: []const u8, body: struct { type: []const u8, msg_id: u32, echo: []const u8 } };

fn f(msgId: u32, msg: []const u8, nodeId: []const u8, _: [][]const u8, allocator: std.mem.Allocator) ![][]const u8 {
    // Parse the raw message into an `InMsg` struct
    const parsed = try std.json.parseFromSlice(InMsg, allocator, msg, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    const inMsg = parsed.value;

    const response = .{ .src = nodeId, .dest = inMsg.src, .body = .{
        .type = "echo_ok",
        .msg_id = msgId,
        .echo = inMsg.body.echo,
        .in_reply_to = inMsg.body.msg_id,
    } };

    var responses = std.ArrayList([]const u8).init(allocator);
    try responses.append(try utils.stringify(response, allocator));
    return responses.items;
}

pub fn echo() !void {
    try node.run(f);
}

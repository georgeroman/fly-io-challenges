const std = @import("std");

const node = @import("../node.zig");

fn f(n: *node.Node, msg: []const u8) !void {
    const EchoMsg = struct { src: []const u8, dest: []const u8, body: struct { type: []const u8, msg_id: u32, echo: []const u8 } };

    // Parse the raw message into an `EchoMsg` struct
    const parsed = try std.json.parseFromSlice(EchoMsg, node.allocator, msg, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    const parsedMsg = parsed.value;

    const response = .{ .src = n.nodeId, .dest = parsedMsg.src, .body = .{
        .type = "echo_ok",
        .msg_id = n.getMsgId(),
        .in_reply_to = parsedMsg.body.msg_id,
        .echo = parsedMsg.body.echo,
    } };
    try n.send(response);
}

pub fn echo() !void {
    try node.run(f);
}

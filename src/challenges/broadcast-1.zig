const std = @import("std");

const node = @import("../node.zig");

var messages = std.ArrayList(i64).init(std.heap.page_allocator);
fn f(n: *node.Node, msg: []const u8) !void {
    // Parse the raw message
    const parsed = try std.json.parseFromSlice(std.json.Value, n.allocator, msg, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    const msgSrc = parsed.value.object.get("src").?.string;
    const msgBody = parsed.value.object.get("body").?.object;
    const msgType = msgBody.get("type").?.string;
    const msgMsgId = msgBody.get("msg_id").?.integer;

    if (std.mem.eql(u8, msgType, "broadcast")) {
        const message = msgBody.get("message").?.integer;
        try messages.append(message);

        const response = .{ .src = n.nodeId, .dest = msgSrc, .body = .{ .type = "broadcast_ok", .msg_id = n.getMsgId(), .in_reply_to = msgMsgId } };
        try n.send(response);
    } else if (std.mem.eql(u8, msgType, "read")) {
        const response = .{ .src = n.nodeId, .dest = msgSrc, .body = .{ .type = "read_ok", .msg_id = n.getMsgId(), .in_reply_to = msgMsgId, .messages = messages.items } };
        try n.send(response);
    } else if (std.mem.eql(u8, msgType, "topology")) {
        const response = .{ .src = n.nodeId, .dest = msgSrc, .body = .{ .type = "topology_ok", .msg_id = n.getMsgId(), .in_reply_to = msgMsgId } };
        try n.send(response);
    } else {
        unreachable;
    }
}

pub fn broadcast1() !void {
    try node.run(f);
}

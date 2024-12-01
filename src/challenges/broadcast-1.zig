const std = @import("std");

const node = @import("../node.zig");
const utils = @import("../utils.zig");

var messages = std.ArrayList(i64).init(std.heap.page_allocator);
fn f(msgId: u32, msg: []const u8, nodeId: []const u8, _: [][]const u8, allocator: std.mem.Allocator) ![][]const u8 {
    // Parse the raw message
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, msg, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    const msgSrc = parsed.value.object.get("src").?.string;
    const msgBody = parsed.value.object.get("body").?.object;
    const msgType = msgBody.get("type").?.string;
    const msgMsgId = msgBody.get("msg_id").?.integer;

    var responses = std.ArrayList([]const u8).init(allocator);
    if (std.mem.eql(u8, msgType, "broadcast")) {
        const message = msgBody.get("message").?.integer;
        try messages.append(message);

        const response = .{ .src = nodeId, .dest = msgSrc, .body = .{ .type = "broadcast_ok", .msg_id = msgId, .in_reply_to = msgMsgId } };
        try responses.append(try utils.stringify(response, allocator));
    } else if (std.mem.eql(u8, msgType, "read")) {
        const response = .{ .src = nodeId, .dest = msgSrc, .body = .{ .type = "read_ok", .msg_id = msgId, .in_reply_to = msgMsgId, .messages = messages.items } };
        try responses.append(try utils.stringify(response, allocator));
    } else if (std.mem.eql(u8, msgType, "topology")) {
        const response = .{ .src = nodeId, .dest = msgSrc, .body = .{ .type = "topology_ok", .msg_id = msgId, .in_reply_to = msgMsgId } };
        try responses.append(try utils.stringify(response, allocator));
    } else {
        unreachable;
    }

    return responses.items;
}

pub fn broadcast1() !void {
    try node.run(f);
}

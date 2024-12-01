const std = @import("std");

const node = @import("../node.zig");

var messages = std.AutoHashMap(i64, bool).init(std.heap.page_allocator);
var messagesList = std.ArrayList(i64).init(std.heap.page_allocator);

const BroadcastMsg = struct {
    src: []const u8,
    dest: []const u8,
    body: struct {
        type: []const u8,
        msg_id: u32,
        message: i64
    }
};

// Keep track of broadcast messages which were sent to other nodes, but not yet confirmed
var pendingBroadcastMessages = std.AutoHashMap(i64, BroadcastMsg).init(std.heap.page_allocator);

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

        // Send "broadcast_ok" message
        {
            const response = .{ .src = n.nodeId, .dest = msgSrc, .body = .{ .type = "broadcast_ok", .msg_id = n.getMsgId(), .in_reply_to = msgMsgId } };
            try n.send(response);
        }

        // Only if we didn't already process the message
        if (messages.get(message) == null) {
            try messages.put(message, true);
            try messagesList.append(message);

            // Broadcast to every other node
            for (n.neighborNodeIds) |neighborNodeId| {
                const response: BroadcastMsg = .{ .src = n.nodeId, .dest = neighborNodeId, .body = .{ .type = "broadcast", .msg_id = n.getMsgId(), .message = message } };
                try n.send(response);

                // Mark the message as pending
                try pendingBroadcastMessages.put(response.body.msg_id, response);
            }
        }
    } else if (std.mem.eql(u8, msgType, "read")) {
        const response = .{ .src = n.nodeId, .dest = msgSrc, .body = .{ .type = "read_ok", .msg_id = n.getMsgId(), .in_reply_to = msgMsgId, .messages = messagesList.items } };
        try n.send(response);
    } else if (std.mem.eql(u8, msgType, "topology")) {
        const response = .{ .src = n.nodeId, .dest = msgSrc, .body = .{ .type = "topology_ok", .msg_id = n.getMsgId(), .in_reply_to = msgMsgId } };
        try n.send(response);
    } else if (std.mem.eql(u8, msgType, "broadcast_ok")) {
        // If we received a "broadcast_ok", remove the corresponding message from the pending list
        const msgInReplyTo = msgBody.get("in_reply_to").?.integer;
        _ = pendingBroadcastMessages.remove(msgInReplyTo);

        // Resend all pending broadcast messages for the sending node id
        // Ideally this is happening in a separate thread which tries every once in a while to resend unacknowledged messages
        var it = pendingBroadcastMessages.iterator();
        
        while (true) {
            const entry = it.next();
            if (entry != null) {
                if (std.mem.eql(u8, entry.?.value_ptr.dest, msgSrc)) {
                    try n.send(entry.?.value_ptr);
                }
            } else {
                break;
            }
        }
    }
}

pub fn broadcast3() !void {
    try node.run(f);
}

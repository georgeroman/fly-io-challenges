const std = @import("std");

pub fn run(f: *const fn (node: *Node, msg: []const u8) anyerror!void) !void {
    const in = std.io.getStdIn();

    // Initialize an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Initialize a stdin buffered reader
    var bufferedReader = std.io.bufferedReader(in.reader());
    const reader = bufferedReader.reader();

    var node: ?Node = null;
    while (true) {
        // Read a line for stdin
        var msgBuffer: [4096]u8 = undefined;
        const msg = try reader.readUntilDelimiterOrEof(&msgBuffer, '\n');

        if (msg) |m| {
            if (node == null) {
                // This is the first message we're processing, so we expect it to be an "init" message

                const InitMsg = struct { src: []const u8, dest: []const u8, body: struct { type: []const u8, msg_id: u32, node_id: []const u8, node_ids: [][]const u8 } };

                // Parse the raw message into an `InitMsg` struct
                const parsed = try std.json.parseFromSlice(InitMsg, allocator, m, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
                defer parsed.deinit();

                const initMsg = parsed.value;

                // Allocate memory for the node id and copy it from the message data
                // We cannot use `initMsg.body.node_id` since it will be deallocated at the end of the current scope
                const nodeId = try std.mem.Allocator.dupe(allocator, u8, initMsg.body.node_id);

                // Same as above but for `initMsg.body.node_ids`
                var neighborNodeIds = std.ArrayList([]u8).init(allocator);
                for (initMsg.body.node_ids) |neighborNodeId| {
                    if (!std.mem.eql(u8, nodeId, neighborNodeId)) {
                        try neighborNodeIds.append(try std.mem.Allocator.dupe(allocator, u8, neighborNodeId));
                    }
                }

                // Intialize the node struct
                node = Node {
                    .allocator = allocator,

                    .nodeId = nodeId,

                    .neighborNodeIds = neighborNodeIds.items
                };

                // Send the "init_ok" response
                try node.?.send(.{ .src = nodeId, .dest = initMsg.src, .body = .{
                    .type = "init_ok",
                    .msg_id = node.?.getMsgId(),
                    .in_reply_to = initMsg.body.msg_id,
                } });
            } else {
                try f(&node.?, m);
            }
        }
    }
}

pub const Node = struct {
    allocator: std.mem.Allocator,

    nextMsgId: u32 = 1,

    nodeId: []const u8,

    neighborNodeIds: [][]const u8,

    pub fn getMsgId(self: *Node) u32 {
        self.nextMsgId += 1;
        return self.nextMsgId - 1;
    }

    pub fn send(self: Node, msg: anytype) !void {
        const stdout = std.io.getStdOut();

        // Stringify the message
        var stringifiedMsg = std.ArrayList(u8).init(self.allocator);
        defer stringifiedMsg.deinit();
        try std.json.stringify(msg, .{}, stringifiedMsg.writer());

        // Append a newline at the end of the message
        const stringifiedMsgWithDelimiter = try std.mem.concat(self.allocator, u8, &.{ stringifiedMsg.items, "\n" });
        defer self.allocator.free(stringifiedMsgWithDelimiter);

        // Write to stdout
        _ = try stdout.write(stringifiedMsgWithDelimiter);
    }
};
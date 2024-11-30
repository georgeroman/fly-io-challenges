const std = @import("std");

const InitMsg = struct { src: []const u8, dest: []const u8, body: struct { type: []const u8, msg_id: u32, node_id: []const u8, node_ids: [][]const u8 } };

// Utility method for sending a response via stdout
var msgId: u32 = 0;
fn write(f: std.fs.File, allocator: std.mem.Allocator, msg: []const u8) !void {
    // Make sure to append a newline delimiter at the end
    const msgWithDelimiter = try std.mem.concat(allocator, u8, &.{ msg, "\n" });
    _ = try f.write(msgWithDelimiter);

    // Increment the message id
    msgId += 1;
}

pub fn run(f: *const fn (msgId: u32, msg: []const u8, nodeId: []const u8, allocator: std.mem.Allocator) anyerror![]const u8) !void {
    const in = std.io.getStdIn();
    const out = std.io.getStdOut();

    // Initialize an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Initialize a stdin buffered reader
    var bufferedReader = std.io.bufferedReader(in.reader());
    const reader = bufferedReader.reader();

    var nodeId: []u8 = undefined;
    while (true) {
        // Read a line for stdin
        var msgBuffer: [4096]u8 = undefined;
        const msg = try reader.readUntilDelimiterOrEof(&msgBuffer, '\n');

        if (msg) |m| {
            if (msgId == 0) {
                // This is the first message we're processing, so we expect it to be an init message

                // Parse the raw message into an `InitMsg` struct
                const parsed = try std.json.parseFromSlice(InitMsg, allocator, m, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
                defer parsed.deinit();

                const initMsg = parsed.value;

                // Allocate memory for the node id and copy it from the message data
                // We cannot use `initMsg.body.node_id` since it will be deallocated at the end of the current scope
                nodeId = try allocator.alloc(u8, initMsg.body.node_id.len);
                @memcpy(nodeId[0..initMsg.body.node_id.len], initMsg.body.node_id);

                const response = .{ .src = nodeId, .dest = initMsg.src, .body = .{
                    .type = "init_ok",
                    .msg_id = msgId,
                    .in_reply_to = initMsg.body.msg_id,
                } };

                // Stringify the above response and write to stdout
                var string = std.ArrayList(u8).init(allocator);
                try std.json.stringify(response, .{}, string.writer());
                try write(out, allocator, string.items);
            } else {
                const response = try f(msgId, m, nodeId, allocator);
                try write(out, allocator, response);

                allocator.free(response);
            }
        }
    }
}
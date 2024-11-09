const std = @import("std");
const Ollama = @import("ollama-zig");

pub fn main() !void {
    var msgs = std.ArrayList(Ollama.Type.Message).init(std.heap.c_allocator);
    defer msgs.deinit();
    try msgs.append(.{ .role = "user", .content = "Why is the sky blue?" });

    var ollama = Ollama.init(std.heap.c_allocator, .{});
    defer ollama.deinit();
    const itr = try ollama.chatStream(.{
        .model = "llama3.2",
        .messages = msgs.items,
    });
    while (try itr.next()) |part| {
        std.debug.print("{s}", .{part.message.content});
    }
}

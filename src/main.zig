const std = @import("std");
const Ollama = @import("ollama");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("Memory leak detected!\n", .{});
    }

    var msgs = try std.ArrayList(Ollama.Type.Message).initCapacity(allocator, 0);
    defer msgs.deinit(allocator);
    try msgs.append(allocator, .{ .role = "user", .content = "Why is the sky blue?" });

    var ollama = Ollama.init(allocator, .{});
    defer ollama.deinit();
    var itr = try ollama.chatStream(.{
        .model = "llama3.2",
        .messages = msgs.items,
    });
    while (try itr.next()) |part| {
        std.debug.print("{s}", .{part.message.content});
    }
}

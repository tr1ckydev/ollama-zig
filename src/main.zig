const std = @import("std");
const Ollama = @import("ollama");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var msgs = std.ArrayList(Ollama.Type.Message).init(allocator);
    defer msgs.deinit();
    try msgs.append(.{ .role = "user", .content = "Why is the sky blue?" });

    var ollama = Ollama.init(allocator, .{});
    defer ollama.deinit();
    const itr = try ollama.chatStream(.{
        .model = "llama3.2",
        .messages = msgs.items,
    });
    while (try itr.next()) |part| {
        std.debug.print("{s}", .{part.message.content});
    }
}

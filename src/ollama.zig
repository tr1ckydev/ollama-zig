//! The Ollama interface for interacting with the Ollama API.

const std = @import("std");
/// The types for various API interfaces.
pub const Type = @import("types.zig");
const Ollama = @This();

fn Streamable(comptime T: type) type {
    return struct {
        request: *std.http.Client.Request,
        var done: bool = false;
        pub fn next(self: @This()) !?T {
            if (done) return null;
            const result = self.request.reader().readUntilDelimiterAlloc(self.request.client.allocator, '\n', 2048);
            if (result) |response| {
                const options = std.json.ParseOptions{
                    .ignore_unknown_fields = true,
                };
                const parsed = try std.json.parseFromSlice(T, self.request.client.allocator, response, options);
                defer parsed.deinit();
                done = parsed.value.done;
                return parsed.value;
            } else |err| switch (err) {
                error.EndOfStream => return null,
                else => return err,
            }
        }
    };
}

config: Type.Config,
client: std.http.Client,
fetch_response: ?std.http.Client.FetchResult = null,
post_request: ?std.http.Client.Request = null,

/// Initialize a new Ollama client.
pub fn init(allocator: std.mem.Allocator, config: Type.Config) Ollama {
    return .{
        .config = config,
        .client = std.http.Client{ .allocator = allocator },
    };
}

/// Release all resources used by the client.
pub fn deinit(self: *Ollama) void {
    // if (self.fetch_response) |_| self.fetch_response.?.deinit();
    if (self.post_request) |_| self.post_request.?.deinit();
    self.client.deinit();
}

fn sendPOST(self: *Ollama, path: []const u8, request: anytype) !void {
    var json_string = std.ArrayList(u8).init(self.client.allocator);
    defer json_string.deinit();
    try std.json.stringify(request, .{}, json_string.writer());
    const header = try self.client.allocator.alloc(u8, 1024 * 8);
    defer self.client.allocator.free(header);
    const options = std.http.Client.RequestOptions{
        .server_header_buffer = header,
    };
    const uri = try std.Uri.parse(try std.mem.concat(self.client.allocator, u8, &.{ self.config.host, path }));
    self.post_request = try self.client.open(.POST, uri, options);
    self.post_request.?.transfer_encoding = .chunked;
    try self.post_request.?.send();
    try self.post_request.?.writeAll(json_string.items);
    try self.post_request.?.finish();
    try self.post_request.?.wait();
}

fn sendGET(self: *Ollama, path: []const u8) !void {
    self.fetch_response = try self.client.fetch(self.client.allocator, .{
        .location = .{
            .url = try std.mem.concat(self.client.allocator, u8, &.{ self.config.host, path }),
        },
    });
}

/// Generate the next message in a chat with a provided model.
///
/// This is not a streaming endpoint and returns a single response object.
///
/// (Requires `stream: false`)
pub fn chat(self: *Ollama, request: Type.ChatRequest) !Type.ChatResponse {
    if (request.stream) return error.StreamNotDisabled;
    try self.sendPOST("/api/chat", request);
    const response = try self.post_request.?.reader().readAllAlloc(self.client.allocator, self.config.response_max_size);
    const parsed = try std.json.parseFromSlice(Type.ChatResponse, self.client.allocator, response, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Generate the next message in a chat with a provided model.
///
/// This is a streaming endpoint and returns a series of response objects through a `Streamable` interface.
pub fn chatStream(self: *Ollama, request: Type.ChatRequest) !Streamable(Type.ChatResponse) {
    if (!request.stream) return error.StreamDisabled;
    try self.sendPOST("/api/chat", request);
    return .{ .request = &self.post_request.? };
}

/// Generate a response for a given prompt with a provided model.
///
/// This is not a streaming endpoint and returns a single response object.
///
/// (Requires `stream: false`)
pub fn generate(self: *Ollama, request: Type.GenerateRequest) !Type.GenerateResponse {
    if (request.stream) return error.StreamNotDisabled;
    try self.sendPOST("/api/generate", request);
    const response = try self.post_request.?.reader().readAllAlloc(self.client.allocator, self.config.response_max_size);
    const parsed = try std.json.parseFromSlice(Type.GenerateResponse, self.client.allocator, response, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Generate a response for a given prompt with a provided model.
///
/// This is a streaming endpoint and returns a series of response objects through a `Streamable` interface.
pub fn generateStream(self: *Ollama, request: Type.GenerateRequest) !Streamable(Type.GenerateResponse) {
    if (!request.stream) return error.StreamDisabled;
    try self.sendPOST("/api/generate", request);
    return .{ .request = &self.post_request.? };
}

/// List models that are available locally.
pub fn list(self: *Ollama) !Type.ListResponse {
    try self.sendGET("/api/tags");
    const parsed = try std.json.parseFromSlice(Type.ListResponse, self.client.allocator, self.fetch_response.?.body.?, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Show information about a model including details, modelfile, template, parameters, license, and system prompt.
pub fn show(self: *Ollama, request: Type.ShowRequest) !Type.ShowResponse {
    try self.sendPOST("/api/show", request);
    const response = try self.post_request.?.reader().readAllAlloc(self.client.allocator, self.config.response_max_size);
    const parsed = try std.json.parseFromSlice(Type.ShowResponse, self.client.allocator, response, .{});
    defer parsed.deinit();
    return parsed.value;
}

/// Generate embeddings from a model for a given prompt.
pub fn embeddings(self: *Ollama, request: Type.EmbeddingsRequest) !Type.EmbeddingsResponse {
    try self.sendPOST("/api/embeddings", request);
    const response = try self.post_request.?.reader().readAllAlloc(self.client.allocator, self.config.response_max_size);
    const parsed = try std.json.parseFromSlice(Type.EmbeddingsResponse, self.client.allocator, response, .{});
    defer parsed.deinit();
    return parsed.value;
}

//! The Ollama interface for interacting with the Ollama API.

const std = @import("std");
/// The types for various API interfaces.
pub const Type = @import("types.zig");
const Ollama = @This();

fn Streamable(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        request: std.http.Client.Request,
        max: usize,
        var buffer: []u8 = undefined;
        var response: std.http.Client.Response = undefined;
        var response_reader: *std.Io.Reader = undefined;
        var first: bool = true;
        var current: ?std.json.Parsed(T) = null;
        var done: bool = false;
        var deinit_done = false;
        /// next() frees the previously returned result from memory. The returned value is only valid until the
        /// next iteration or call. Use or copy before that.
        pub fn next(self: *@This()) !?T {
            if (done) {
                if (!deinit_done) {
                    if (current) |cur| {
                        cur.deinit();
                    }
                    self.request.deinit();
                    self.allocator.free(buffer);
                    deinit_done = true;
                }
                return null;
            }
            if (first) {
                response = try self.request.receiveHead(&.{});
                buffer = try self.allocator.alloc(u8, self.max);
                response_reader = response.reader(buffer);
                first = false;
            }
            if (current) |cur| {
                cur.deinit();
            }
            const resp = try response_reader.takeDelimiterExclusive('\n');
            current = try std.json.parseFromSlice(T, self.allocator, resp, .{ .ignore_unknown_fields = true });

            done = current.?.value.done;

            return current.?.value;
        }
        // If iterator finished this function is a no-op
        pub fn deinit(self: *@This()) void {
            if (!deinit_done & !first) {
                if (current) |cur| {
                    cur.deinit();
                }
                self.request.deinit();
                self.allocator.free(buffer);
                done = true;
                deinit_done = true;
            }
        }
    };
}

config: Type.Config,
client: std.http.Client,

/// Initialize a new Ollama client.
pub fn init(allocator: std.mem.Allocator, config: Type.Config) Ollama {
    return .{
        .config = config,
        .client = std.http.Client{ .allocator = allocator },
    };
}

/// Release all resources used by the client. If any streamable iterators are still active you
/// must call deinit() on them before calling this method.
pub fn deinit(self: *Ollama) void {
    self.client.deinit();
}

fn sendPOST(self: *Ollama, path: []const u8, request: anytype) !std.http.Client.Request {
    const stringified = try std.json.Stringify.valueAlloc(self.client.allocator, request, .{});
    defer self.client.allocator.free(stringified);
    const concated = try std.mem.concat(self.client.allocator, u8, &.{ self.config.host, path });
    defer self.client.allocator.free(concated);
    const uri = try std.Uri.parse(concated);
    var post_request = try self.client.request(.POST, uri, .{});
    post_request.transfer_encoding = .chunked;
    try post_request.sendBodyComplete(stringified);
    return post_request;
}

fn sendGET(self: *Ollama, path: []const u8) !std.http.Client.Request {
    const concated = try std.mem.concat(self.client.allocator, u8, &.{ self.config.host, path });
    defer self.client.allocator.free(concated);
    const uri = try std.Uri.parse(concated);
    var get_request = try self.client.request(.GET, uri, .{});
    try get_request.sendBodiless();
    return get_request;
}

/// Generate the next message in a chat with a provided model.
///
/// This is not a streaming endpoint and returns a single response object.
///
/// (Requires `stream: false`)
pub fn chat(self: *Ollama, request: Type.ChatRequest) !std.json.Parsed(Type.ChatResponse) {
    if (request.stream) return error.StreamNotDisabled;
    const post_request = try self.sendPOST("/api/chat", request);
    defer post_request.deinit();
    var resp = try post_request.receiveHead(&.{});
    if (resp.head.status != .ok) {
        return error.HTTPRequestFailed;
    }
    const buffer = try self.client.allocator.alloc(u8, self.config.response_max_size);
    defer self.client.allocator.free(buffer);
    const reader = resp.reader(buffer);
    const response = try reader.takeDelimiterExclusive('\n');
    const parsed = try std.json.parseFromSlice(Type.ChatResponse, self.client.allocator, response, .{ .allocate = .alloc_always });
    return parsed;
}

/// Generate the next message in a chat with a provided model.
///
/// This is a streaming endpoint and returns a series of response objects through a `Streamable` interface.
pub fn chatStream(self: *Ollama, request: Type.ChatRequest) !Streamable(Type.ChatResponse) {
    if (!request.stream) return error.StreamDisabled;
    const post_request = try self.sendPOST("/api/chat", request);
    return .{
        .allocator = self.client.allocator,
        .request = post_request,
        .max = self.config.response_max_size,
    };
}

/// Generate a response for a given prompt with a provided model.
///
/// This is not a streaming endpoint and returns a single response object.
///
/// (Requires `stream: false`)
pub fn generate(self: *Ollama, request: Type.GenerateRequest) !std.json.Parsed(Type.GenerateResponse) {
    if (request.stream) return error.StreamNotDisabled;
    const post_request = try self.sendPOST("/api/generate", request);
    defer post_request.deinit();
    var resp = try post_request.receiveHead(&.{});
    if (resp.head.status != .ok) {
        return error.HTTPRequestFailed;
    }

    const buffer = try self.client.allocator.alloc(u8, self.config.response_max_size);
    defer self.client.allocator.free(buffer);
    const reader = resp.reader(buffer);
    const response = try reader.takeDelimiterExclusive('\n');
    const parsed = try std.json.parseFromSlice(Type.GenerateResponse, self.client.allocator, response, .{ .allocate = .alloc_always });
    return parsed;
}

/// Generate a response for a given prompt with a provided model.
///
/// This is a streaming endpoint and returns a series of response objects through a `Streamable` interface.
pub fn generateStream(self: *Ollama, request: Type.GenerateRequest) !Streamable(Type.GenerateResponse) {
    if (!request.stream) return error.StreamDisabled;
    const post_request = try self.sendPOST("/api/generate", request);
    return .{
        .request = post_request,
        .allocator = self.client.allocator,
        .max = self.config.response_max_size,
    };
}

/// List models that are available locally.
pub fn list(self: *Ollama) !std.json.Parsed(Type.ListResponse) {
    var get_request = try self.sendGET("/api/tags");
    defer get_request.deinit();
    var resp = try get_request.receiveHead(&.{});
    if (resp.head.status != .ok) {
        return error.HTTPRequestFailed;
    }
    const buffer = try self.client.allocator.alloc(u8, self.config.response_max_size);
    defer self.client.allocator.free(buffer);
    const reader = resp.reader(buffer);
    const response = try reader.takeDelimiterExclusive('\n');
    const parsed = try std.json.parseFromSlice(Type.ListResponse, self.client.allocator, response, .{ .allocate = .alloc_always });
    return parsed;
}

/// Show information about a model including details, modelfile, template, parameters, license, and system prompt.
pub fn show(self: *Ollama, request: Type.ShowRequest) !std.json.Parsed(Type.ShowResponse) {
    var post_request = try self.sendPOST("/api/show", request);
    defer post_request.deinit();
    var resp = try post_request.receiveHead(&.{});
    if (resp.head.status != .ok) {
        return error.HTTPRequestFailed;
    }
    const buffer = try self.client.allocator.alloc(u8, self.config.response_max_size);
    defer self.client.allocator.free(buffer);
    const reader = resp.reader(buffer);
    const response = try reader.takeDelimiterExclusive('\n');
    const parsed = try std.json.parseFromSlice(Type.ShowResponse, self.client.allocator, response, .{ .allocate = .alloc_always });
    return parsed;
}

/// Generate embeddings from a model for a given prompt.
pub fn embeddings(self: *Ollama, request: Type.EmbeddingsRequest) !std.json.Parsed(Type.EmbeddingsResponse) {
    var post_request = try self.sendPOST("/api/embeddings", request);
    defer post_request.deinit();
    var resp = try post_request.receiveHead(&.{});
    if (resp.head.status != .ok) {
        return error.HTTPRequestFailed;
    }
    const buffer = try self.client.allocator.alloc(u8, self.config.response_max_size);
    defer self.client.allocator.free(buffer);
    const reader = resp.reader(buffer);
    const response = try reader.takeDelimiterExclusive('\n');
    const parsed = try std.json.parseFromSlice(Type.EmbeddingsResponse, self.client.allocator, response, .{ .allocate = .alloc_always });
    return parsed;
}

# 🦙⚡ ollama-zig
The Ollama zig library is the easiest way to interact and integrate your zig project with the [Ollama REST API](https://github.com/ollama/ollama/blob/main/docs/api.md).



## Installation

> Zig master version is required to use ollama-zig.

1. Copy the full hash of the latest commit and replace `<COMMIT_HASH>` with it, then run this.

   ```bash
   zig fetch --save https://github.com/tr1ckydev/ollama-zig/archive/<COMMIT_HASH>.tar.gz
   ```

2. Add the dependency and module to your `build.zig`.

   ```zig
   const ollama_dep = b.dependency("ollama", .{});
   const ollama_mod = ollama_dep.module("ollama");
   exe.root_module.addImport("ollama", ollama_mod);
   ```

3. Import it inside your project.

   ```zig
   const Ollama = @import("ollama");
   ```



## Usage

```zig
var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const res = try ollama.generate(.{
    .model = "llama3.2",
    .prompt = "Why is the sky blue?",
    .stream = false,
});
std.debug.print("{s}", .{res.response});
```



## Streaming responses

Streaming responses are made easy through the `Streamable` iterator interface.

Functions with suffix `Stream` always return an iterator interface where each part is an object in the stream.

```zig
var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const stream = try ollama.generateStream(.{
    .model = "llama3.2",
    .prompt = "Why is the sky blue?",
});
while (try stream.next()) |part| {
    std.debug.print("{s}", .{part.response});
}
```



## Documentation

### Type

Access the underlying Ollama API structs.

```zig
const req = Ollama.Type.GenerateRequest{
    .model = "llama3.2",
    .prompt = "Why is the sky blue?",
    .stream = false,
};
var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const res = try ollama.generate(req);
std.debug.print("{s}", .{res.response});
```

### init

Initialize a new Ollama client.

```zig
var ollama = Ollama.init(allocator, .{});
```

- `allocator`: The allocator to use in the client.
- `config`: The configuration for the client. (Pass an empty object to use default configuration.)
  - `host`: The host URL to use for the Ollama API server.
  - `response_max_size`: The maximum size for a response in bytes. Set this to a higher value if you encounter '***error: StreamTooLong***'. Default is 4096.

### deinit

Release all resources used by the client.

```zig
ollama.deinit();
```

### chat

Generate the next message in a chat with a provided model.

This is not a streaming endpoint and returns a single response object. (Requires `stream: false`)

```zig
var msgs = std.ArrayList(Ollama.Type.Message).init(allocator);
defer msgs.deinit();
try msgs.append(.{ .role = "user", .content = "Why is the sky blue?" });

var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const res = try ollama.chat(.{
    .model = "llama3.2",
    .messages = msgs.items,
    .stream = false,
});
std.debug.print("{s}", .{res.message.content});
```

- `model`: The name of the model to use for the chat.
- `messages`: Array slice of `Message` objects representing the conversation history. (Ideally, you'd want to use an ArrayList to store message history.)
  - `role`: The role of the message sender. (`"system"`|`"user"`|`"assistant"`)
  - `content`: The content of the message.
- `stream`: (Optional) Should be explicitly set to `false` for functions without a `Stream` suffix. Default is true.
- `format`: (Optional) The format to return a response in. Currently the only accepted value is `"json"`.
- `options`: (Optional) Additional model parameters listed in the documentation for the [Modelfile](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values).
- `template`: (Optional) The prompt template to use. (Overrides what is defined in the `Modelfile`)
- `keep_alive`: (Optional) Controls how long the model will stay loaded into memory following the request. Accepts both number or string through a union. (e.g. `.keep_alive = .{ .number = 5000000 }` or `.keep_alive = .{ .string = "5m" }`)

### chatStream

Streamable version of the above `chat` function.

```zig
var msgs = std.ArrayList(Ollama.Type.Message).init(allocator);
defer msgs.deinit();
try msgs.append(.{ .role = "user", .content = "Why is the sky blue?" });

var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const stream = try ollama.chatStream(.{
    .model = "llama3.2",
    .messages = msgs.items,
});
while (try stream.next()) |part| {
    std.debug.print("{s}", .{part.message.content});
}
```

### generate

Generate a response for a given prompt with a provided model.

This is not a streaming endpoint and returns a single response object. (Requires `stream: false`)

```zig
var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const res = try ollama.generate(.{
    .model = "llama3.2",
    .prompt = "Why is the sky blue?",
    .stream = false,
});
std.debug.print("{s}", .{res.response});
```

- `model`: The name of the model to use for generating the response.
- `prompt`: The prompt to generate a response for.
- `stream`: (Optional) Should be explicitly set to `false` for functions without a `Stream` suffix. Default is true.
- `format`: (Optional) The format to return a response in. Currently the only accepted value is `"json"`.
- `options`: (Optional) Additional model parameters listed in the documentation for the [Modelfile](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values).
- `template`: (Optional) The prompt template to use. (Overrides what is defined in the `Modelfile`)
- `keep_alive`: (Optional) Controls how long the model will stay loaded into memory following the request. Accepts both number or string through a union. (e.g. `.keep_alive = .{ .number = 5000000 }` or `.keep_alive = .{ .string = "5m" }`)
- `system`: (Optional) System message to override what is defined in the `Modelfile`.
- `context`: (Optional) The context parameter returned from a previous `generate()`, this can be used to keep a short conversational memory.
- `raw`: (Optional) If `true`, no formatting will be applied to the prompt if you are specifying a full templated prompt.

### generateStream

Streamable version of the above `generate` function.

```zig
var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const stream = try ollama.generateStream(.{
    .model = "llama3.2",
    .prompt = "Why is the sky blue?",
});
while (try stream.next()) |part| {
    std.debug.print("{s}", .{part.response});
}
```

### list

List models that are available locally.

```zig
var ollama = Ollama.init(allocator, .{});
defer ollama.deinit();
const res = try ollama.list();
for (res.models) |model| {
    std.debug.print("{s}\n", .{model.model});
}
```

### show

Show information about a model including details, modelfile, template, parameters, license, and system prompt.

```zig
var ollama = Ollama.init(allocator, .{ .response_max_size = 1024 * 100 });
defer ollama.deinit();
const res = try ollama.show(.{ .model = "llama3.2" });
std.debug.print("{s}", .{res.modelfile});
```

- `model`: The name of the model to show the information of.
- `system`: (Optional) System message to override what is defined in the `Modelfile`.
- `template`: (Optional) The prompt template to use. (Overrides what is defined in the `Modelfile`)
- `options`: (Optional) Additional model parameters listed in the documentation for the [Modelfile](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values).

### embeddings

Generate embeddings from a model for a given prompt.

```zig
var ollama = Ollama.init(allocator, .{ .response_max_size = 1024 * 100 });
defer ollama.deinit();
const res = try ollama.embeddings(.{
    .model = "llama3.2",
    .prompt = "Why is the sky blue?",
});
std.debug.print("{any}", .{res.embedding});
```

- `model`: The name of the model to use for generating the embeddings.
- `prompt`: The prompt to generate embeddings for.
- `options`: (Optional) Additional model parameters listed in the documentation for the [Modelfile](https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values).
- `keep_alive`: (Optional) Controls how long the model will stay loaded into memory following the request. Accepts both number or string through a union. (e.g. `.keep_alive = .{ .number = 5000000 }` or `.keep_alive = .{ .string = "5m" }`)



## Experimental library!

This is a very early version and may contain bugs and unusual behaviors.

APIs not implemented: `pull`, `push`, `create`, `delete`, `copy`

Known issues:

- Images aren't supported yet.
- Results in unknown errors if the provided `model` isn't found on host system.
- Sometimes `name` field from `list()` is empty.
- ...create issue if you find more!



## License

This repository uses MIT License. See [LICENSE](https://github.com/tr1ckydev/ollama-zig/blob/main/LICENSE) for full license text.

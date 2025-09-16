pub const Config = struct {
    host: []const u8 = "http://127.0.0.1:11434",
    response_max_size: usize = 1024 * 4,
};

pub const Message = struct {
    role: []const u8,
    content: []const u8,
    images: ?[]const []const u8 = null,
};

pub const Options = struct {
    numa: ?bool = null,
    num_ctx: ?u32 = null,
    num_batch: ?u32 = null,
    main_gpu: ?u32 = null,
    low_vram: ?bool = null,
    f16_kv: ?bool = null,
    logits_all: ?bool = null,
    vocab_only: ?bool = null,
    use_mmap: ?bool = null,
    use_mlock: ?bool = null,
    embedding_only: ?bool = null,
    num_thread: ?u32 = null,

    // Runtime options
    num_keep: ?u32 = null,
    seed: ?u32 = null,
    num_predict: ?u32 = null,
    top_k: ?u32 = null,
    top_p: ?f32 = null,
    tfs_z: ?f32 = null,
    typical_p: ?f32 = null,
    repeat_last_n: ?u32 = null,
    temperature: ?f32 = null,
    repeat_penalty: ?f32 = null,
    presence_penalty: ?f32 = null,
    frequency_penalty: ?f32 = null,
    mirostat: ?f32 = null,
    mirostat_tau: ?f32 = null,
    mirostat_eta: ?f32 = null,
    penalize_newline: ?bool = null,
    stop: ?[]const []const u8 = null,
};

const KeepAlive = union(enum) {
    string: []const u8,
    number: i64,
    pub fn jsonStringify(value: KeepAlive, out_stream: anytype) !void {
        switch (value) {
            .string => |s| try out_stream.write(s),
            .number => |n| try out_stream.write(n),
        }
    }
};

pub const ChatRequest = struct {
    model: []const u8,
    messages: []Message,
    stream: bool = true,
    format: ?[]const u8 = null,
    options: ?Options = null,
    template: ?[]const u8 = null,
    keep_alive: ?KeepAlive = null,
};

pub const ChatResponse = struct {
    model: []const u8,
    created_at: []const u8,
    message: Message,
    done: bool,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u64 = null,
    prompt_eval_duration: ?u64 = null,
    eval_count: ?u64 = null,
    eval_duration: ?u64 = null,
};

pub const GenerateRequest = struct {
    model: []const u8,
    prompt: []const u8,
    stream: bool = true,
    images: ?[]const []const u8 = null,
    format: ?[]const u8 = null,
    options: ?Options = null,
    template: ?[]const u8 = null,
    keep_alive: ?KeepAlive = null,
    system: ?[]const u8 = null,
    context: ?[]const u32 = null,
    raw: ?bool = null,
};

pub const GenerateResponse = struct {
    model: []const u8,
    created_at: []const u8,
    response: []const u8,
    done: bool,
    context: ?[]const u32 = null,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u64 = null,
    prompt_eval_duration: ?u64 = null,
    eval_count: ?u64 = null,
    eval_duration: ?u64 = null,
};

const ModelResponse = struct {
    name: []const u8,
    model: []const u8,
    modified_at: []const u8,
    size: usize,
    digest: []const u8,
    details: struct {
        parent_model: []const u8,
        format: []const u8,
        family: []const u8,
        families: ?[]const []const u8,
        parameter_size: []const u8,
        quantization_level: []const u8,
    },
};

pub const ListResponse = struct {
    models: []ModelResponse,
};

pub const ShowRequest = struct {
    model: []const u8,
    system: ?[]const u8 = null,
    template: ?[]const u8 = null,
    options: ?Options = null,
};

pub const ShowResponse = struct {
    license: []const u8,
    modelfile: []const u8,
    parameters: []const u8,
    template: []const u8,
    details: struct {
        parent_model: []const u8,
        format: []const u8,
        family: []const u8,
        families: ?[]const []const u8,
        parameter_size: []const u8,
        quantization_level: []const u8,
    },
};

pub const EmbeddingsRequest = struct {
    model: []const u8,
    prompt: []const u8,
    options: ?Options = null,
    keep_alive: ?KeepAlive = null,
};

pub const EmbeddingsResponse = struct {
    embedding: []f64,
};

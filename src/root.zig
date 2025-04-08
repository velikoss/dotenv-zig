const std = @import("std");
const unicode = @import("std").unicode;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Allocator = mem.Allocator;
const fs = std.fs;

comptime {
    std.testing.refAllDecls(@This());
}

fn parse_line(line_content: []u8) !?struct {
    key: []const u8,
    val: []const u8,
} {
    var tokenizer = std.mem.tokenizeAny(u8, line_content, "=");
    var key = tokenizer.next() orelse return null;
    var val = tokenizer.next() orelse return null;
    key = std.mem.trim(u8, key, " \t\r\n");
    val = std.mem.trim(u8, val, " \t\r\n");
    if (val.len > 1) if (val[0] == '"' or val[0] == '\'') {
        if (val[0] != val[val.len - 1]) return error.ValueMalformed;
        val = val[1 .. val.len - 1];
    };
    return .{
        .key = key,
        .val = val,
    };
}

fn parse_env_file_content(alloc: Allocator, path_content: []const u8) !StringMap {
    var stream = std.io.fixedBufferStream(path_content);
    var reader_stream = stream.reader();
    var env_map = StringMap.init(alloc);
    const max_bytes = 1024 * 1024;
    while (true) {
        const readline = try reader_stream.readUntilDelimiterOrEofAlloc(alloc, '\n', max_bytes);
        if (readline) |line| {
            if (try parse_line(line)) |res| {
                const key = try alloc.dupe(u8, res.key);
                const val = try alloc.dupe(u8, res.val);
                try env_map.put(key, val);
            }
        } else break;
    }
    return env_map;
}

const StringMap = std.StringHashMap([]const u8);
pub const Env = @This();

vars: StringMap,
arena: std.heap.ArenaAllocator,

pub fn init(alloc: Allocator, file_content: []const u8) !Env {
    var arena = std.heap.ArenaAllocator.init(alloc);
    const vars = try parse_env_file_content(arena.allocator(), file_content);
    const env = Env{
        .vars = vars,
        .arena = arena,
    };
    return env;
}

pub fn deinit(env: *Env) void {
    env.arena.deinit();
}

pub fn get(self: *Env, key: []const u8) ?[]const u8 {
    return self.vars.get(key);
}

test "test\n" {
    const alloc = std.testing.allocator;
    var file = try std.fs.cwd().openFile(".env", .{});
    defer file.close();
    const content = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(content);
    var env: Env = try Env.init(alloc, content);
    defer env.deinit();
    try expect(env.get("no key") == null);
    try expect(std.mem.eql(u8, env.get("password").?, "mysecretpassword"));
    try expect(std.mem.eql(u8, env.get("number").?, "123"));
    try expect(std.mem.eql(u8, env.get("somekey").?, "somekey"));
    try expect(std.mem.eql(u8, env.get("keywith2spaces").?, "keywith2spaces  "));
    std.debug.print("{s}\n", .{env.get("password").?});
}

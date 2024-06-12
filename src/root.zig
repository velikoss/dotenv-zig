const std = @import("std");
const unicode = @import("std").unicode;
const mem = std.mem;
const debug = std.debug;
const assert = debug.assert;
const Allocator = mem.Allocator;

comptime {
	std.testing.refAllDecls(@This());
}

pub const string = struct {
    buffer: []u8,
    allocator: *Allocator,

    pub fn init(_allocator: *Allocator, str: []const u8) !string {
        var buf = try _allocator.alloc(u8, str.len);
        var i: usize = 0;
        for (str) |c| {
            buf[i] = c;
            i += 1;
        }
        return string {
            .buffer = buf,
            .allocator = _allocator
        };
    }

    pub fn cinit(str: []const u8) !string {
        var unconst = std.heap.c_allocator;
        var buf = try std.heap.c_allocator.alloc(u8, str.len);
        var i: usize = 0;
        for (str) |c| {
            buf[i] = c;
            i += 1;
        }
        return string {
            .buffer = buf,
            .allocator = &unconst
        };
    }

    pub fn deinit(self: *const string) void {
        self.allocator.free(self.buffer);
    }

    pub fn length(self: *const string) usize {
        return self.buffer.len;
    }

    pub fn kmp(self: *const string, needle: []const u8) ![]usize {
        const m = needle.len;

        var border = try self.allocator.alloc(i64, m+1);
        defer self.allocator.free(border);
        border[0] = -1;

        var i: usize = 0;
        while (i < m): (i += 1) {
            border[i+1] = border[i];
            while (border[i+1] > -1 and needle[@intCast(border[i+1])] != needle[i]) {
                border[i+1] = border[@intCast(border[i+1])];
            }
            border[i+1]+=1;
        }

        const max_found = self.buffer.len / needle.len;

        var results = try self.allocator.alloc(usize, max_found);
        var n = self.buffer.len;
        _ = &n;
        var seen: i64 = 0;
        var j: usize = 0;
        var found: usize = 0;

        while (j < n): (j += 1) {
            while (seen > -1 and needle[@intCast(seen)] != self.buffer[j])  {
                seen = border[@intCast(seen)];
            }
            seen+=1;
            if (seen == m) {
                found += 1;
                results[found-1] = j-m+1;
                seen = border[m];
            }
        }
        results = try self.allocator.realloc(results, found);
        return results;
    }

    pub fn single_space_indices(self: *const string) ![]usize {
        var results = try self.allocator.alloc(usize, self.buffer.len);
        var i: usize = 0;
        var j: usize = 0;
        for (self.buffer) |c| {
            if (c == ' ') {
                results[i] = j;
                i += 1;
            }
            j += 1;
        }
        results = try self.allocator.realloc(results, i);
        return results[0..];
    }

    pub fn find_all(self: *const string, needle: []const u8) ![]usize {
        var indices: []usize = undefined;
        if (needle.len == 1 and needle[0] == ' ') {
            indices = try self.single_space_indices();
        } else {
            indices = try self.kmp(needle);
        }
        return indices;
    }

    pub fn reverse(self: *const string) void {
        mem.reverse(u8, self.buffer);
    }

    pub fn split_to_u8(self: *const string, sep: []const u8) ![][]const u8 {
        var indices = try self.find_all(sep);
        _ = &indices;

        var results = try self.allocator.alloc([]u8, indices.len+1);
        var i: usize = 0;
        var j: usize = 0;
        for (indices) |n|  {
            results[j] = self.buffer[i..n];
            i = n+sep.len;
            j += 1;
        }
        if (i < self.buffer.len) {
            results[indices.len] = self.buffer[i..];
        }
        return results;
    }

    pub fn split(self: *const string, sep: []const u8) ![]string {
        var indices = try self.find_all(sep);
        _ = &indices;

        var results = try self.allocator.alloc(string, indices.len+1);
        var i: usize = 0;
        var j: usize = 0;
        for (indices) |n| {
            results[j] = try string.cinit(self.buffer[i..n]);
            i = n+sep.len;
            j += 1;
        }

        if (i < self.buffer.len) {
            results[indices.len] = try string.cinit(self.buffer[i..]);
        }
        return results;
    }

    pub fn all_space_indices(self: *const string) ![]usize {
        var results = try self.allocator.alloc(usize, self.buffer.len);
        var i: usize = 0;
        var j: usize = 0;
        for (self.buffer) |c| {
            switch (c) {
                ' ', '\t', '\n', 11, '\r'  =>
                {
                    results[i] = j;
                    i += 1;
                },
                else => continue,
            }
            j += 1;
        }
        results = try self.allocator.realloc(usize, results, i);
        return results;
    }

    pub fn count(self: *const string, substr: []const u8) !usize {
        var subs = try self.find_all(substr);
        _ = &subs;
        return subs.len;
    }
};

fn cwd(allocator: *Allocator, relative: []const u8) ![]const u8 {
    const cwdPath = try std.fs.cwd().realpathAlloc(allocator.*, ".");
    defer allocator.free(cwdPath);
    return try std.fs.path.resolve(allocator.*, &[_][]const u8{cwdPath, relative});
}

fn parseEnvFile(allocator: *Allocator, file_path: []const u8) !StringMap {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    var line_allocator = arena.allocator();
    defer arena.deinit();
    const env = cwd(allocator, file_path) catch null;
    assert(env != null);
    const absolutePath = try allocator.alloc(u8, env.?.len);
    errdefer allocator.free(absolutePath);
    _ = try std.fmt.bufPrint(absolutePath, "{s}", .{ env.? });
    var file = try std.fs.cwd().openFile(absolutePath, .{});
    defer file.close();
    var buffered_reader = std.io.bufferedReader(file.reader());
    var reader_stream = buffered_reader.reader();
    var env_map = StringMap.init(allocator.*);
    const max_bytes = 1024 * 1024;
    while (true) {
        const line = try reader_stream.readUntilDelimiterOrEofAlloc(line_allocator, '\n', max_bytes);
        if (line == null or line.?.len == 0) break;
        var line_str = try string.init(&line_allocator, line.?);
        defer line_str.deinit();
        if (try line_str.count("=") != 1) continue;
        const parts = try line_str.split("=");
        if (parts.len == 2) {
            const key = parts[0];
            const value = parts[1];
            try env_map.put(key.buffer, value.buffer);
        }
        line_allocator.free(line_str.buffer);
    }
    return env_map;
}

const StringMap = std.StringHashMap([]const u8);

pub const Env = struct {
    file_path: []const u8,
    allocator: *Allocator,
    vars: StringMap,

    pub fn init() !Env {
        var allocator = std.heap.page_allocator;
	_ = &allocator;
	var file_path = try cwd(&allocator, ".env");
	_ = &file_path;

        const env = try Env {
            .file_path = file_path,
            .allocator = &allocator,
            .vars = try parseEnvFile(&allocator, file_path),
        };

        return env;
    }

    pub fn deinit(env: *Env) void {
        env.allocator.free(env.file_path);
        env.vars.deinit();
    }

    pub fn get(self: *Env, key: []const u8) ![]const u8 {
        return try self.vars.get(key);
    }
};

test "test\n" {
    var allocator = std.heap.c_allocator;
    var env: Env = try Env.init(&allocator, ".env");
    std.debug.print("{s}\n", .{ env.get("password").? });
}

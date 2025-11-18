# dotenv zig 0.15.0

- dotenv is a super simple single file zig library for parsing a `.env` file.
- implementation is < 100 lines
- Support for key-value pairs separated by `=` in the `.env` file.
- trims trailing spaces in key and values
- values in double or single quotes get stripped: "myvalue" -> myvalue
- does not check keys for syntax correctness
- dupes the key-values into a hashmap, so the input buffer may get deallocated without problems
- **Process environment variable support** - automatically falls back to process environment when key is not found in .env file
- No dependencies

## Usage

0. with zon: zig fetch --save "thisrepo/hash"
   in build.zig, add the module (the name of the module is "dotenv")

1. Create a `.env` file in your project or executable directory:

   ```sh
   # .env
   MY_ENV_VAR=hello
   ANOTHER_VAR=world
   ```

2. Use dotenv to read the environment variable:

   ```zig
   const Env = @import("dotenv");
   pub fn main() !void {
      const alloc = std.heap.page_allocator;
      // read the env file
      var file = try std.fs.cwd().openFile(".env", .{});
      defer file.close();
      const content = try file.readToEndAlloc(alloc, 1024 * 1024);
      defer alloc.free(content);
      // parse the env file
      var env: Env = try Env.init(alloc, content);
      defer env.deinit();
      // This will first check the .env file, then fall back to process environment if not found
      std.debug.print("{s}\n", .{env.get("password").?});
      // Use the environment variables
      // ...
   }
   ```

   Alternatively, use `init_with_path` for a more convenient approach:

   ```zig
   const Env = @import("dotenv");
   pub fn main() !void {
      const alloc = std.heap.page_allocator;
      // init_with_path handles file opening, reading, and cleanup automatically
      // Set use_process_env=true to fall back to process environment if .env file is not found
      var env: Env = try Env.init_with_path(alloc, ".env", 1024 * 1024, true);
      defer env.deinit();
      // This will first check the .env file, then fall back to process environment if not found
      std.debug.print("{s}\n", .{env.get("password").?});
      // Use the environment variables
      // ...
   }
   ```

3. Use dotenv to get a key from a dotenv file at comptime:

   ```zig
   const Env = @import("dotenv");
   pub fn main() !void {
      const content = @embedFile(".env");
      try expect(try Env.parse_key("no key", content) == null);
      const password = try Env.parse_key("password", content);
      try expect(std.mem.eql(u8, password.?, "mysecretpassword"));
   }
   ```

4. Process environment variable support (for cloud deployments):

   When a key is not found in the `.env` file, `Env.get()` automatically falls back to reading from the process environment. This makes it perfect for cloud deployments where environment variables are provided by the platform.

   **Option A: Initialize without a .env file** (process environment only):

   ```zig
   const Env = @import("dotenv");
   pub fn main() !void {
      const alloc = std.heap.page_allocator;
      // Initialize without a .env file - will use process environment only
      var env: Env = try Env.init(alloc, null);
      defer env.deinit();

      // This will read from process environment (e.g., set by Docker, Heroku, AWS Lambda, etc.)
      if (env.get("DATABASE_URL")) |url| {
         std.debug.print("Database URL: {s}\n", .{url});
      }
   }
   ```

   **Option B: Use `init_with_path` with fallback** (recommended for cloud deployments):

   ```zig
   const Env = @import("dotenv");
   pub fn main() !void {
      const alloc = std.heap.page_allocator;
      // If .env file exists, use it; otherwise fall back to process environment
      // This works seamlessly in both local development and cloud deployments
      var env: Env = try Env.init_with_path(alloc, ".env", 1024 * 1024, true);
      defer env.deinit();

      // This will check .env file first, then process environment
      if (env.get("DATABASE_URL")) |url| {
         std.debug.print("Database URL: {s}\n", .{url});
      }
   }
   ```

   This is particularly useful for:

   - Cloud platforms (Heroku, AWS Lambda, Google Cloud Run, etc.)
   - Docker containers with environment variables
   - CI/CD pipelines
   - Production environments where .env files should not be included
   - Local development where you want .env file support with cloud deployment compatibility

## Docker Testing

The repository includes Docker support for testing process environment functionality:

```bash
docker-compose up --build
```

This will run all tests with environment variables set via Docker Compose, verifying that process environment variable support works correctly.

## Contributing

Contributions are welcome! Fork the repository and submit a pull request.

## License

dotenv-zig is licensed under the MIT License. See [LICENSE](LICENSE) for details.

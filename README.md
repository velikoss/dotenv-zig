# dotenv-zig

dotenv-zig is a Zig library for parsing and managing environment variables from a `.env` file. It provides a simple and efficient way to load environment variables into your Zig applications.

## Features

- Parse `.env` files and load environment variables into your application.
- Support for key-value pairs separated by `=` in the `.env` file.
- Easily integrate with existing Zig projects.
- **No dependencies needed.**

## Installation

Install dotenv-zig using [zigmod](https://github.com/nektro/zigmod/):

   ```sh
   zigmod aq add dotenv-zig
   ```

Also you can install it using Zon

## Usage

1. Create a `.env` file in your project or executable directory:

   ```sh
   # .env
   MY_ENV_VAR=hello
   ANOTHER_VAR=world
   ```

2. Use dotenv-zig to load the environment variables in your Zig code:

   ```zig
   const dotenv = @import("dotenv-zig");

   pub fn main() void {
      var allocator = std.heap.c_allocator;
      var env: Env = try Env.init();
         
      const myEnvVar = try env.get("MY_ENV_VAR");
      const anotherVar = try env.get("ANOTHER_VAR");
   
      // Use the environment variables
      // ...
   }
   ```

## More information
Seeking for more info? Look at [Wiki](https://github.com/velikoss/dotenv-zig/wiki)

## Contributing

Contributions are welcome! Fork the repository and submit a pull request.

## License

dotenv-zig is licensed under the MIT License. See [LICENSE](LICENSE) for details.

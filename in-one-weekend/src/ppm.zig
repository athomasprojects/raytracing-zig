const std = @import("std");
const Allocator = std.mem.Allocator;
const Colour = @import("vec3.zig").Colour;
const Vec3 = @import("vec3.zig").Vec3;
const colour = @import("colour.zig");

const MAGIC_NUMBER = "P3";
pub const IMG_DIR = "images/ppm/";

// Constants
const MAX_COLOUR = 255;
const DEFAULT_IMAGE_WIDTH = MAX_COLOUR;
const DEFAULT_IMAGE_HEIGHT = DEFAULT_IMAGE_WIDTH;

pub const PpmError = error{
    FileError,
};

/// Write a ppm image file to disk.
pub fn createFile(image_width: usize, image_height: usize, path: []const u8, allocator: Allocator) !void {
    // Create buffered writer to stdout.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Create ppm file.
    const file = try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
    defer file.close();

    const file_writer = file.writer();
    var buffer = std.ArrayList(u8).init(allocator);
    const buf_writer = buffer.writer();

    try buf_writer.print("{s}\n{d} {d}\n{d}\n", .{ MAGIC_NUMBER, image_width, image_height, MAX_COLOUR });

    var pixel_colour: Colour = Vec3.createEmpty();
    for (0..image_height) |j| {
        // Progress indicator.
        try stdout.print("Scanlines remaining: {d}\r", .{image_height - j});
        try bw.flush();

        for (0..image_width) |i| {
            // Render
            pixel_colour = Vec3.create(
                @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(image_width - 1)),
                @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(image_height - 1)),
                @as(f64, 0.0),
            );
            try colour.writeColour(buf_writer, pixel_colour);
        }
    }
    try file_writer.writeAll(buffer.items);
    try stdout.print("\rDone.                     \n", .{});
    try bw.flush();
}

const std = @import("std");
const Allocator = std.mem.Allocator;

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
pub fn create_file(image_width: usize, image_height: usize, path: []const u8, allocator: Allocator) !void {
    const file = try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
    defer file.close();

    var data: []const u8 = try std.fmt.allocPrint(allocator, "{s}\n{d} {d}\n{d}\n", .{ MAGIC_NUMBER, image_width, image_height, MAX_COLOUR });

    const c: f64 = 255.999;
    for (0..image_height) |j| {
        for (0..image_width) |i| {
            // Normalize RBG triplets to 0-255 values
            const r: u8 = @intFromFloat(c * (@as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(image_width - 1))));
            const g: u8 = @intFromFloat(c * (@as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(image_height - 1))));
            const b: u8 = @intFromFloat(c * @as(f64, 0.0));

            data = try std.fmt.allocPrint(allocator, "{s}{d} {d} {d}\n", .{ data, r, g, b });
        }
    }

    try file.writeAll(data);
}

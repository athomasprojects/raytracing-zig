const std = @import("std");
const vec = @import("vec.zig");
const colour = @import("colour.zig");
const Ray = @import("ray.zig").Ray;
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const ppm_fname = "image03.ppm";
    const ppm_dir = "images/ppm/";
    const path = ppm_dir ++ ppm_fname;

    const aspect_ratio = 16.0 / 9.0;
    const image_width = 1200;
    const image_height: comptime_int = @intFromFloat(@as(comptime_float, image_width) / aspect_ratio);

    const magic_number = "P3";
    const max_colour = 255;

    // Create buffered writer to stdout.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Create or open ppm file.
    const file = try std.fs.cwd().createFile(path, std.fs.File.CreateFlags{ .read = true });
    defer file.close();

    const file_writer = file.writer();
    var buffer = std.ArrayList(u8).init(allocator);
    const buf_writer = buffer.writer();

    // Render
    try buf_writer.print("{s}\n{d} {d}\n{d}\n", .{ magic_number, image_width, image_height, max_colour });

    var pixel_colour: Colour = Vec3.createEmpty();
    for (0..image_height) |j| {
        // Progress indicator.
        try stdout.print("Scanlines remaining: {d}\r", .{image_height - j});
        try bw.flush();

        for (0..image_width) |i| {
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

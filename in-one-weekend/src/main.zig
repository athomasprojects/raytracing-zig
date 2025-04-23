const std = @import("std");
const vec = @import("vec.zig");
const colour = @import("colour.zig");
const Ray = @import("ray.zig").Ray;
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// Returns the ray colour as a linear interpolation (lerp) of the 'y' pixel value between white and blue.
fn rayColour(r: *Ray) Colour {
    const unit_direction: Vec3 = vec.normalize(r.dir);
    const a: f64 = 0.5 * (vec.y(unit_direction) + 1.0);
    return vec.scale(Colour{ 1, 1, 1 }, 1.0 - a) + vec.scale(Colour{ 0.5, 0.7, 1 }, a);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const ppm_dir = "images/ppm/";
    const ppm_fname = "image02.ppm";
    const path = ppm_dir ++ ppm_fname;

    // Calculate the image height, and ensure that it is at least 1.
    // const aspect_ratio = 3.0 / 2.0;
    const aspect_ratio = 16.0 / 9.0;
    const image_width = 1200;
    const image_height: comptime_int = @intFromFloat(@as(comptime_float, image_width) / aspect_ratio);

    // Camera
    const focal_length = 1.0; // distance from the camera center to the viewport.
    const viewport_height = 2.0;
    const viewport_width: comptime_float = viewport_height * (@as(comptime_float, image_width) / @as(comptime_float, image_height));
    const camera_center: Point3 = .{ 0, 0, 0 };

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u = vec.create(viewport_width, 0, 0);
    const viewport_v = vec.create(0, -viewport_height, 0);

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u = vec.divScalar(viewport_u, image_width);
    const pixel_delta_v = vec.divScalar(viewport_v, image_height);

    // Calculate location of upper left pixel.
    const viewport_upper_left: Vec3 = camera_center - vec.create(0, 0, focal_length) - vec.divScalar(viewport_u, 2) - vec.divScalar(viewport_v, 2);
    const pixel00_loc: Vec3 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

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
    const magic_number = "P3";
    const max_colour = 255;
    try buf_writer.print("{s}\n{d} {d}\n{d}\n", .{ magic_number, image_width, image_height, max_colour });

    var pixel_center: Vec3 = vec.createEmpty();
    var pixel_colour: Colour = vec.createEmpty();
    var ray: Ray = Ray.init(camera_center, vec.createEmpty());
    for (0..image_height) |j| {
        // Progress indicator.
        try stdout.print("Scanlines remaining: {d}\r", .{image_height - j});
        try bw.flush();

        for (0..image_width) |i| {
            pixel_center = pixel00_loc + vec.scale(pixel_delta_u, @floatFromInt(i)) + vec.scale(pixel_delta_v, @floatFromInt(j));
            ray.dir = pixel_center - camera_center;
            pixel_colour = rayColour(&ray);
            // pixel_colour = vec.create(
            //     @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(image_width - 1)),
            //     @as(f64, @floatFromInt(j)) / @as(f64, @floatFromInt(image_height - 1)),
            //     @as(f64, 0.0),
            // );
            try colour.writeColour(buf_writer, pixel_colour);
        }
    }
    try file_writer.writeAll(buffer.items);
    try stdout.print("\rDone.                     \n", .{});
    try bw.flush();
}

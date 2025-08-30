const std = @import("std");
const vec = @import("vec.zig");
const hittable = @import("hittable.zig");
const Ray = @import("Ray.zig");
const Sphere = @import("Sphere.zig");
const Interval = @import("Interval.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const Hittable = hittable.Hittable;
const HittableList = hittable.HittableList;
const HitRecord = hittable.HitRecord;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ppm_dir = "images/ppm/";
    const ppm_fname = "image05.ppm";
    const path = ppm_dir ++ ppm_fname;

    // Calculate the image height, and ensure that it is at least 1.
    const aspect_ratio = 16.0 / 9.0;
    const image_width = 1200;
    const image_height: comptime_int = @intFromFloat(@as(comptime_float, image_width) / aspect_ratio);

    // World
    const world_capacity: usize = 128;
    var world: HittableList = try .init(allocator, world_capacity);
    try world.add(
        .{ .sphere = Sphere.init(.{ 0, 0, -1 }, 0.5) },
    );
    try world.add(
        .{ .sphere = Sphere.init(.{ 0, -100.5, -1 }, 100) },
    );

    // Initialize camera.
    const focal_length = 1.0; // distance from the camera center to the viewport.
    const viewport_height = 2.0;
    const viewport_width: comptime_float = viewport_height * (@as(comptime_float, image_width) / @as(comptime_float, image_height));
    const camera_center: Point3 = .{ 0, 0, 0 };

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u: Vec3 = vec.init(viewport_width, 0, 0);
    const viewport_v: Vec3 = vec.init(0, -viewport_height, 0);

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u: Vec3 = vec.divScalar(viewport_u, image_width);
    const pixel_delta_v: Vec3 = vec.divScalar(viewport_v, image_height);

    // Calculate location of upper left pixel.
    const viewport_upper_left: Vec3 = camera_center - vec.init(0, 0, focal_length) - vec.divScalar(viewport_u, 2) - vec.divScalar(viewport_v, 2);
    const pixel00_loc: Vec3 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

    // Create writer to stdout.
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Create or opent ppm file
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Get file writer interface.
    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const file_out = &file_writer.interface;

    // Render image.
    const magic_number = "P3";
    const max_colour = 255;
    try file_out.print(
        "{s}\n{d} {d}\n{d}\n",
        .{
            magic_number,
            image_width,
            image_height,
            max_colour,
        },
    );

    var pixel_center: Vec3 = vec.empty;
    var pixel_colour: Colour = vec.empty;
    var ray: Ray = .init(camera_center, vec.empty);
    for (0..image_height) |j| {
        // Progress indicator.
        try stdout.print("Scanlines remaining: {d}\r", .{image_height - j});
        try stdout.flush();

        for (0..image_width) |i| {
            pixel_center = pixel00_loc + vec.scale(pixel_delta_u, @floatFromInt(i)) + vec.scale(pixel_delta_v, @floatFromInt(j));
            ray.dir = pixel_center - camera_center;
            pixel_colour = rayColour(&ray, &world);

            // Translate the [0,1] pixel rgb colour component values to the byte range [0,255].
            const c: f64 = 255.999;
            const r_byte: u8 = @intFromFloat(c * pixel_colour[0]);
            const g_byte: u8 = @intFromFloat(c * pixel_colour[1]);
            const b_byte: u8 = @intFromFloat(c * pixel_colour[2]);

            // Write pixel colour components.
            try file_out.print("{d} {d} {d}\n", .{ r_byte, g_byte, b_byte });
        }
    }
    try file_out.flush();
    try stdout.print("\rDone.                     \n", .{});
    try stdout.flush();
}

/// Returns the ray colour as a linear interpolation (lerp) of the 'y' pixel value between white and blue.
fn rayColour(r: *Ray, world: *HittableList) Colour {
    var rec: HitRecord = undefined;
    if (world.hit(r, .init(0, vec.infinity), &rec)) {
        return vec.scale(rec.normal + Colour{ 1, 1, 1 }, 0.5);
    }

    const unit_direction: Vec3 = vec.normalize(r.dir);
    const a: f64 = 0.5 * (vec.y(unit_direction) + 1.0);
    return vec.scale(Colour{ 1, 1, 1 }, 1.0 - a) + vec.scale(Colour{ 0.5, 0.7, 1 }, a);
}

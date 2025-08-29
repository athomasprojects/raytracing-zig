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
    const ppm_dir = "images/ppm/";
    const ppm_fname = "image05.ppm";
    const path = ppm_dir ++ ppm_fname;

    // Calculate the image height, and ensure that it is at least 1.
    const aspect_ratio = 16.0 / 9.0;
    const image_width = 1200;
    const image_height: comptime_int = @intFromFloat(@as(comptime_float, image_width) / aspect_ratio);

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
            pixel_colour = rayColour(&ray);

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
fn rayColour(r: *Ray) Colour {
    const t: f64 = hitSphere(.{ 0, 0, -1 }, 0.5, r);

    // The ray has 2 unique intersection points.
    if (t > 0) {
        const N: Vec3 = vec.normalize(r.at(t) - Vec3{ 0, 0, -1 });
        return vec.scale(Colour{ vec.x(N) + 1, vec.y(N) + 1, vec.z(N) + 1 }, 0.5);
    }

    const unit_direction: Vec3 = vec.normalize(r.dir);
    const a: f64 = 0.5 * (vec.y(unit_direction) + 1.0);
    return vec.scale(Colour{ 1, 1, 1 }, 1.0 - a) + vec.scale(Colour{ 0.5, 0.7, 1 }, a);
}

fn hitSphere(center: Point3, radius: f64, ray: *Ray) f64 {
    const oc: Vec3 = center - ray.origin; // vector from the ray origin to the center of the sphere.
    const a: f64 = vec.lengthSquared(ray.dir);
    const h: f64 = vec.dot(ray.dir, oc);
    const c: f64 = vec.lengthSquared(oc) - radius * radius;

    // discriminant < 0 : no solutions (ray does not hit).
    // discriminant == 0 : 1 solution (ray intersects sphere at one point tangent to the sphere).
    // discriminant > 0 : 2 solutions (ray intersects the sphere at 2 unique points).
    const discriminant: f64 = h * h - a * c;
    return if (discriminant < 0) -1 else (h - std.math.sqrt(discriminant)) / a;
}

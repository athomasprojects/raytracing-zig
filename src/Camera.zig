const std = @import("std");
const colour = @import("colour.zig");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const hittable = @import("hittable.zig");
const HitRecord = hittable.HitRecord;
const Hittable = hittable.Hittable;
const HittableList = hittable.HittableList;
const Ray = @import("Ray.zig");
const Interval = @import("Interval.zig");
const Writer = std.Io.Writer;

// Fields prefixed with `_` are for internal use only and should not be modified!
aspect_ratio: comptime_float, // Ratio of the image width to image height.
image_width: comptime_int, // Rendered image width in pixel count.
samples_per_pixel: comptime_int, // Count of random samples for each pixel.
max_ray_bounces: comptime_int, // Maximum number of ray bounces into scene.
_image_height: comptime_int, // Rendered image height.
_center: Point3, // Camera center.
_pixel00_loc: Point3, // Locatio of pixel (0,0).
_pixel_delta_u: Vec3, // Offset to pixel to the right.
_pixel_delta_v: Vec3, // Offset to pixel below.
_pixel_samples_scale: f64, // Colour scale factor for a sum of pixel samples.
const Camera = @This();

pub const default: Camera = .init(16.0 / 9.0, 400, 100, 50);

pub fn init(aspect_ratio: comptime_float, image_width: comptime_float, samples_per_pixel: comptime_int, max_ray_bounces: comptime_int) Camera {
    if (aspect_ratio <= 0) @compileError("aspect ratio must be positive");
    if (image_width <= 0) @compileError("image_width must be positive");

    const image_height: comptime_int = @intFromFloat(@as(comptime_float, image_width) / aspect_ratio);
    const center: Point3 = .{ 0, 0, 0 };

    // Determine viewport dimensions.
    const focal_length = 1.0; // Distance from the camera center to the viewport.
    const viewport_height = 2.0;
    const viewport_width: comptime_float = viewport_height * (@as(comptime_float, image_width) / @as(comptime_float, image_height));

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u: Vec3 = vec.init(viewport_width, 0, 0);
    const viewport_v: Vec3 = vec.init(0, -viewport_height, 0);

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u: Vec3 = vec.divScalar(viewport_u, image_width);
    const pixel_delta_v: Vec3 = vec.divScalar(viewport_v, image_height);

    // Calculate location of upper left pixel.
    const viewport_upper_left: Vec3 = center - vec.init(0, 0, focal_length) - vec.divScalar(viewport_u, 2) - vec.divScalar(viewport_v, 2);
    const pixel00_loc: Vec3 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

    return .{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .samples_per_pixel = samples_per_pixel,
        .max_ray_bounces = max_ray_bounces,
        ._image_height = image_height,
        ._center = center,
        ._pixel00_loc = pixel00_loc,
        ._pixel_delta_u = pixel_delta_u,
        ._pixel_delta_v = pixel_delta_v,
        ._pixel_samples_scale = 1.0 / @as(f64, samples_per_pixel),
    };
}

pub fn render(self: Camera, stdout: *Writer, file_out: *Writer, world: *HittableList) !void {
    const magic_number = "P3";
    const max_colour = 255;

    try file_out.print(
        "{s}\n{d} {d}\n{d}\n",
        .{
            magic_number,
            self.image_width,
            self._image_height,
            max_colour,
        },
    );

    var ray: Ray = undefined;
    var pixel_colour: Colour = undefined;
    const intensity: Interval = .init(0, 0.999);
    for (0..self._image_height) |j| {
        // Progress indicator.
        try stdout.print("Scanlines remaining: {d}\r", .{self._image_height - j});
        try stdout.flush();

        for (0..self.image_width) |i| {
            pixel_colour = vec.empty;
            for (0..self.samples_per_pixel) |_| {
                ray = self.getRay(i, j);
                pixel_colour += rayColour(&ray, self.max_ray_bounces, world);
            }
            pixel_colour = vec.scale(pixel_colour, self._pixel_samples_scale);

            // Translate the [0,1] pixel rgb colour component values to the byte range [0,255].
            const r_byte: u8 = @intFromFloat(256 * intensity.clamp(colour.gammaFromLinear(pixel_colour[0])));
            const g_byte: u8 = @intFromFloat(256 * intensity.clamp(colour.gammaFromLinear(pixel_colour[1])));
            const b_byte: u8 = @intFromFloat(256 * intensity.clamp(colour.gammaFromLinear(pixel_colour[2])));

            // Write pixel colour components.
            try file_out.print("{d} {d} {d}\n", .{ r_byte, g_byte, b_byte });
        }
    }
    try file_out.flush();
    try stdout.print("\rDone.                     \n", .{});
    try stdout.flush();
}

/// Construct a camera ray originating from the origin and directed at randomly sampled point around the pixel location (i, j).
fn getRay(self: Camera, i: usize, j: usize) Ray {
    const offset: Vec3 = sampleSquare();
    const pixel_sample = self._pixel00_loc +
        vec.scale(
            self._pixel_delta_u,
            @as(f64, @floatFromInt(i)) + vec.x(offset),
        ) +
        vec.scale(
            self._pixel_delta_v,
            @as(f64, @floatFromInt(j)) + vec.y(offset),
        );

    return .init(self._center, pixel_sample - self._center);
}

/// Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
fn sampleSquare() Vec3 {
    return vec.init(vec.randomFloat() - 0.5, vec.randomFloat() - 0.5, 0);
}

/// Returns the ray colour as a linear interpolation (lerp) of the 'y' pixel value between white and blue.
fn rayColour(r: *Ray, depth: comptime_int, world: *HittableList) Colour {
    // If we've exceeded the ray bounce limit, no more light is gathered.
    if (depth < 0) {
        return vec.empty;
    }

    var rec: HitRecord = undefined;
    var ray: Ray = undefined;
    const interval: Interval = .init(0.001, vec.infinity);
    if (world.hit(r, interval, &rec)) {
        ray = .init(rec.p, rec.normal + vec.randomUnitVec());
        return vec.scale(rayColour(&ray, depth - 1, world), 0.5);
    }

    const unit_direction: Vec3 = vec.normalize(r.dir);
    const a: f64 = 0.5 * (vec.y(unit_direction) + 1.0);
    return vec.scale(Colour{ 1, 1, 1 }, 1.0 - a) + vec.scale(Colour{ 0.5, 0.7, 1 }, a);
}

const std = @import("std");
const hittable = @import("hittable.zig");
const vec = @import("vec.zig");

const Colour = vec.Colour;
const HitRecord = hittable.HitRecord;
const Bvh = @import("bvh.zig").Bvh;
const Interval = @import("Interval.zig");
const Material = @import("material.zig").Material;
const Point3 = vec.Point3;
const Ray = @import("Ray.zig");
const Vec3 = vec.Vec3;
const Writer = std.Io.Writer;

// Fields prefixed with `_` are for internal use only and should not be modified!
aspect_ratio: comptime_float, // Ratio of the image width to image height.
image_width: comptime_int, // Rendered image width in pixel count.
samples_per_pixel: comptime_int, // Count of random samples for each pixel.
vertical_fov_deg: comptime_float, // Vertical field of view (viewing angle), specified in degrees.
look_from: Point3, // Point camera is looking from.
look_at: Point3, // Point camera is looking from.
v_up: Vec3, // Camera-relative "up" direction.
defocus_angle_deg: comptime_float, // Variation angle (in degrees) of rays through each pixel.
focus_dist: comptime_float, // Distance from camera `look_from` point to plane of perfect focus.
_image_height: comptime_int, // Rendered image height.
_center: Point3, // Camera center.
_pixel00_loc: Point3, // Location of pixel (0,0).
_pixel_delta_u: Vec3, // Offset to pixel to the right.
_pixel_delta_v: Vec3, // Offset to pixel below.
_pixel_samples_scale: Vec3, // Colour scale factor for a sum of pixel samples.
_u: Vec3, // Camera frame basis vector.
_v: Vec3, // Camera frame basis vector.
_w: Vec3, // Camera frame basis vector pointing along the viewing direction.
_defocus_disk_u: Vec3, // Defocus disk horizontal radius.
_defocus_disk_v: Vec3, // Defocus disk vertical radius.
const Self = @This();

const max_recursion_depth = 50;

pub const default: Self = .init(
    16.0 / 9.0,
    400,
    100,
    20,
    Point3{ 13, 2, 3 },
    vec.zero,
    Vec3{ 0, 1, 0 },
    0.6,
    10,
);

pub fn init(aspect_ratio: comptime_float, image_width: comptime_float, samples_per_pixel: comptime_float, vertical_fov_deg: comptime_float, look_from: Vec3, look_at: Vec3, v_up: Vec3, defocus_angle_deg: comptime_float, focus_dist: comptime_float) Self {
    if (aspect_ratio <= 0) @compileError("aspect ratio must be positive");
    if (image_width <= 0) @compileError("image_width must be positive");

    const image_height: comptime_int = @intFromFloat(@as(comptime_float, image_width) / aspect_ratio);
    const camera_center = look_from;

    // Determine viewport dimensions.
    const h = @tan(std.math.degreesToRadians(vertical_fov_deg) * 0.5);
    const viewport_height = 2 * h * focus_dist;
    const viewport_width: comptime_float = viewport_height * (@as(comptime_float, image_width) / @as(comptime_float, image_height));

    // Calculate the {u,v,w} orthonormal basis vectors for the camera coordinate frame.
    const w = vec.unit(look_from - look_at);
    const u = vec.unit(vec.cross(v_up, w));
    const v = vec.cross(w, u);

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u: Vec3 = vec.scale(u, viewport_width); // Vector across the horizontal viewport edge.
    const viewport_v: Vec3 = vec.scale(v, -viewport_height); // Vector down the vertical viewport edge.

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u: Vec3 = vec.divScalar(viewport_u, image_width);
    const pixel_delta_v: Vec3 = vec.divScalar(viewport_v, image_height);

    // Calculate location of upper left pixel.
    // const viewport_upper_left: Vec3 = camera_center - vec.scale(w, focus_dist) - vec.scale(viewport_u, 0.5) - vec.scale(viewport_v, 0.5);
    const viewport_upper_left: Vec3 = camera_center - vec.scale(w, focus_dist) - vec.scale(viewport_u + viewport_v, 0.5);
    const pixel00_loc: Vec3 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

    // Calculate the camera defocus disk basis vectors.
    const defocus_radius = focus_dist * @tan(std.math.degreesToRadians(0.5 * defocus_angle_deg));
    const defocus_disk_u: Vec3 = vec.scale(u, defocus_radius);
    const defocus_disk_v: Vec3 = vec.scale(v, defocus_radius);

    return .{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        .samples_per_pixel = samples_per_pixel,
        .vertical_fov_deg = vertical_fov_deg,
        .look_from = look_from,
        .look_at = look_at,
        .defocus_angle_deg = defocus_angle_deg,
        .focus_dist = focus_dist,
        ._image_height = image_height,
        ._center = camera_center,
        ._pixel00_loc = pixel00_loc,
        ._pixel_delta_u = pixel_delta_u,
        ._pixel_delta_v = pixel_delta_v,
        ._pixel_samples_scale = vec.splat(1.0 / samples_per_pixel),
        ._w = w,
        ._u = u,
        ._v = v,
        .v_up = v_up,
        ._defocus_disk_u = defocus_disk_u,
        ._defocus_disk_v = defocus_disk_v,
    };
}

pub fn render(self: Self, file_out: *Writer, world: *Bvh) !void {
    var progress_buf: [1024]u8 = undefined;
    const progress_node = std.Progress.start(.{
        .draw_buffer = &progress_buf,
        .estimated_total_items = self._image_height,
        .root_name = "scanlines",
    });
    defer progress_node.end();

    const gpa = std.heap.smp_allocator;
    var image_buffer: [][3]u8 = try gpa.alloc([3]u8, self._image_height * self.image_width);

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = gpa });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    const max_colour = 255;
    try file_out.print(
        "P6\n{d} {d}\n{d}\n",
        .{
            self.image_width,
            self._image_height,
            max_colour,
        },
    );

    for (0..self._image_height) |row| {
        pool.spawnWg(&wg, Self.renderRow, .{
            self,
            @as(f64, @floatFromInt(row)),
            world,
            image_buffer[row * self.image_width ..][0..self.image_width], // Extract the current scanline of pixels from the buffer.
            progress_node,
        });
    }

    pool.waitAndWork(&wg);

    try file_out.writeSliceEndian(u8, std.mem.sliceAsBytes(image_buffer), .big);
    try file_out.flush();
}

fn renderRow(self: Self, row: f64, world: *Bvh, scanline: [][3]u8, progress_node: std.Progress.Node) void {
    defer progress_node.completeOne();

    for (0..self.image_width) |column| {
        var pixel_colour = vec.zero;
        for (0..self.samples_per_pixel) |_| {
            const ray = self.getRay(@floatFromInt(column), row);
            pixel_colour += rayColour(ray, 0, world);
        }
        pixel_colour *= self._pixel_samples_scale;

        // Translate the [0,1] pixel rgb colour component values to the byte range [0,255].
        const max = 255.999;
        const r_byte: u8 = @intFromFloat(max * gamma2FromLinear(pixel_colour[0]));
        const g_byte: u8 = @intFromFloat(max * gamma2FromLinear(pixel_colour[1]));
        const b_byte: u8 = @intFromFloat(max * gamma2FromLinear(pixel_colour[2]));

        // Write pixel colour components to scanline buffer.
        scanline[column] = .{ r_byte, g_byte, b_byte };
    }
}

/// Constructs a camera ray originating from the defocus disk and directed at a
/// randomly sampled point around the pixel location (i, j), where i is the
/// pixel `column` position and j is the pixel `row` position.
fn getRay(self: Self, column: f64, row: f64) Ray {
    @setFloatMode(.optimized);
    const offset: Vec3 = sampleSquare();
    const pixel_sample = self._pixel00_loc +
        self._pixel_delta_u * vec.splat(vec.x(offset) + column) +
        self._pixel_delta_v * vec.splat(vec.y(offset) + row);
    const ray_origin = if (self.defocus_angle_deg <= 0) self._center else self.defocusDiskSample();
    const ray_time = vec.randomFloat();
    return .initMoving(ray_origin, pixel_sample - ray_origin, ray_time);
}

/// Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
fn sampleSquare() Vec3 {
    return .{
        vec.randomFloat() - 0.5,
        vec.randomFloat() - 0.5,
        0,
    };
}

/// Returns a random point in the camera defocus disk.
fn defocusDiskSample(self: Self) Point3 {
    const v = vec.randomVecInUnitDisk();
    return self._center +
        vec.scale(self._defocus_disk_u, vec.x(v)) +
        vec.scale(self._defocus_disk_v, vec.y(v));
}

fn rayColour(r: Ray, depth: comptime_int, world: *Bvh) Colour {
    // If we've exceeded the ray bounce limit, no more light is gathered.
    if (depth == max_recursion_depth) return vec.zero;

    const interval: Interval = .{ .min = 0.001, .max = vec.infinity };
    if (world.hit(r, interval)) |hit| {
        const scattered = hit.mat.scatter(r, hit) orelse return vec.zero;
        const attenuation: Colour = switch (hit.mat) {
            inline else => |m| m.albedo,
        };
        return attenuation * rayColour(scattered, depth + 1, world);
    }

    // If the ray does not hit any of the world objects, we compute the ray colour
    // as a linear interpolation (lerp) of the 'y' pixel value between white and blue.
    // This renders the sky.
    const unit_direction: Vec3 = vec.unit(r.direction);
    const a: f64 = 0.5 * (vec.y(unit_direction) + 1.0);
    return vec.scale(Colour{ 1, 1, 1 }, 1 - a) + vec.scale(Colour{ 0.5, 0.7, 1 }, a);
}

/// Transforms `colour` from a linear colour space to a gamma space using the gamma 2 transform.
pub fn gamma2FromLinear(colour: f64) f64 {
    return if (colour > 0) @sqrt(colour) else 0;
}

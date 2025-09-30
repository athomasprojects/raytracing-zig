const Camera = @This();

const default_defocus_angle_deg = 0;
const default_focus_dist = 10;
const default_bg_colour: Colour = .{ 0.7, 0.8, 1 };

// Fields prefixed with `_` are for internal use,
// they should not be modified externally!

aspect_ratio: comptime_float, // Ratio of the image width to image height.
image_width: comptime_int, // Rendered image width in pixel count.
// samples_per_pixel: comptime_int, // Count of random samples for each pixel.
vertical_fov_deg: comptime_float, // Vertical field of view (viewing angle), specified in degrees.
look_from: Point3, // Point camera is looking from.
look_at: Point3, // Point camera is looking from.
v_up: Vec3, // Camera-relative "up" direction.
defocus_angle_deg: comptime_float, // Variation angle (in degrees) of rays through each pixel.
focus_dist: comptime_float, // Distance from camera `look_from` point to plane of perfect focus.
background_colour: Colour,
max_recursion_depth: comptime_int = 50,
min_samples_per_pixel: comptime_int,
max_samples_per_pixel: comptime_int,
noise_threshold: Vec3, // Noise threshold for when to stop sampling. Relative error tolerance.
_image_height: comptime_int, // Rendered image height.
_center: Point3, // Camera center.
_pixel00_loc: Point3, // Location of pixel (0,0).
_pixel_delta_u: Vec3, // Offset to pixel to the right.
_pixel_delta_v: Vec3, // Offset to pixel below.
// _pixel_samples_scale: Vec3, // Colour scale factor for a sum of pixel samples.
_u: Vec3, // Camera frame basis vector.
_v: Vec3, // Camera frame basis vector.
_w: Vec3, // Camera frame basis vector pointing along the viewing direction.
_defocus_disk_u: Vec3, // Defocus disk horizontal radius.
_defocus_disk_v: Vec3, // Defocus disk vertical radius.

const Tile = struct {
    x0: usize,
    y0: usize,
    x1: usize,
    y1: usize,
    seed: usize,
};

/// Tracks per-pixel statistics using Welford's variance estimation algorithm.
///
/// See: [https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm]
const PixelStats = struct {
    num_samples: u32 = 0,
    mean: Vec3 = vec.zero, // Running colour estimate.
    sum_of_squared_differences: Vec3 = vec.zero, // Sum of squared differences (M₂).

    fn update(self: *PixelStats, sample: Vec3) void {
        self.num_samples += 1;
        const delta = sample - self.mean;

        // Normalizes the pixel colour value to [0,1].
        self.mean += vec.divScalar(delta, @floatFromInt(self.num_samples));

        const delta2 = sample - self.mean;
        self.sum_of_squared_differences += delta * delta2;
    }

    /// Returns the per-channel variance estimate.
    fn variance(self: PixelStats) Vec3 {
        if (self.num_samples < 2) return vec.zero;
        return vec.divScalar(self.sum_of_squared_differences, @floatFromInt(self.num_samples - 1));
    }
};

// const DebugRenderStats = struct {
//     count: u64 = 0,
//     sum: f64 = 0,
//
//     fn print(self: DebugRenderStats) void {
//         std.debug.print("Average render recursion statistics:\n------------------------------------\n", .{});
//         std.debug.print("Avg recursion depth: {d}\n", .{@max(
//             0,
//             self.sum / @as(f64, @floatFromInt(self.count)),
//         )});
//         std.debug.print("Total recursion depth: {d}\n", .{self.count});
//         // std.debug.print("Total samples: {d}\n", .{self.total_samples});
//     }
// };

pub fn init(
    aspect_ratio: comptime_float,
    image_width: comptime_float,
    // samples_per_pixel: comptime_float,
    vertical_fov_deg: comptime_float,
    look_from: Vec3,
    look_at: Vec3,
    v_up: Vec3,
    defocus_angle_deg: comptime_float,
    focus_dist: comptime_float,
    background_colour: Colour,
    min_samples_per_pixel: ?comptime_int,
    max_samples_per_pixel: ?comptime_int,
    noise_threshold: ?comptime_float,
) Camera {
    if (aspect_ratio <= 0) @compileError("aspect ratio must be positive");
    if (image_width <= 0) @compileError("image_width must be positive");

    const image_height: comptime_int = @intFromFloat(image_width / aspect_ratio);

    // Determine viewport dimensions.
    const h = @tan(std.math.degreesToRadians(vertical_fov_deg) * 0.5);
    const viewport_height = 2 * h * focus_dist;
    const viewport_width: comptime_float = viewport_height * image_width / @as(comptime_float, image_height);

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
    const viewport_upper_left: Vec3 = look_from - vec.scale(w, focus_dist) - vec.scale(viewport_u + viewport_v, 0.5);
    const pixel00_loc: Vec3 = viewport_upper_left + vec.scale(pixel_delta_u + pixel_delta_v, 0.5);

    // Calculate the camera defocus disk basis vectors.
    const defocus_radius = focus_dist * @tan(std.math.degreesToRadians(0.5 * defocus_angle_deg));
    const defocus_disk_u: Vec3 = vec.scale(u, defocus_radius);
    const defocus_disk_v: Vec3 = vec.scale(v, defocus_radius);

    return .{
        .aspect_ratio = aspect_ratio,
        .image_width = image_width,
        // .samples_per_pixel = samples_per_pixel,
        .vertical_fov_deg = vertical_fov_deg,
        .look_from = look_from,
        .look_at = look_at,
        .defocus_angle_deg = defocus_angle_deg,
        .focus_dist = focus_dist,
        ._image_height = image_height,
        ._center = look_from,
        ._pixel00_loc = pixel00_loc,
        ._pixel_delta_u = pixel_delta_u,
        ._pixel_delta_v = pixel_delta_v,
        // ._pixel_samples_scale = vec.splat(1.0 / samples_per_pixel),
        ._w = w,
        ._u = u,
        ._v = v,
        .v_up = v_up,
        ._defocus_disk_u = defocus_disk_u,
        ._defocus_disk_v = defocus_disk_v,
        .background_colour = background_colour,
        .min_samples_per_pixel = min_samples_per_pixel orelse 100,
        .max_samples_per_pixel = max_samples_per_pixel orelse 250,
        .noise_threshold = vec.splat(noise_threshold orelse 0.01),
    };
}

pub fn render(
    self: Camera,
    file_out: *Writer,
    bvh: *Bvh,
    primitives: []const Primitive,
    tex_buf: []const Texture,
) !void {
    const gpa = std.heap.smp_allocator;

    var global_seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&global_seed));

    const TILE_W: usize = 4;
    const TILE_H: usize = 4;
    const num_tiles_x = (self.image_width + TILE_W - 1) / TILE_W;
    const num_tiles_y = (self._image_height + TILE_H - 1) / TILE_H;
    const total_tile_count = num_tiles_x * num_tiles_y;

    // Progress bar.
    var progress_buf: [1024]u8 = undefined;
    const progress_node = std.Progress.start(.{
        .draw_buffer = &progress_buf,
        .estimated_total_items = total_tile_count,
        .root_name = "tiles",
    });
    defer progress_node.end();

    var image_buffer: [][3]u8 = try gpa.alloc([3]u8, self._image_height * self.image_width);
    _ = &image_buffer; // Suppress `var` is never mutated error.

    var tiles: []Tile = try gpa.alloc(Tile, total_tile_count);

    // Compute the current tile start and end location pixel coordinates:
    // => (rows) y: [ty, ty + TILE_H)
    // => (cols) x: [tx, tx + TILE_W)
    var tile_idx: usize = 0;
    for (0..num_tiles_y) |ty| {
        for (0..num_tiles_x) |tx| {
            const x0 = tx * TILE_W;
            const y0 = ty * TILE_H;
            tiles[tile_idx] = .{
                .x0 = x0,
                .y0 = y0,
                .x1 = @min(x0 + TILE_W, self.image_width),
                .y1 = @min(y0 + TILE_H, self._image_height),
                .seed = global_seed ^ (tx << 32) ^ ty,
            };
            tile_idx += 1;

            // Previous tile-based mutex protected queue rendering:
            // const tile_seed: u64 = global_seed ^ (tx << 32) ^ ty;
            //
            // pool.spawnWg(&wg, Camera.renderTile, .{
            //     self,
            //     tile_seed,
            //     x0,
            //     y0,
            //     x1,
            //     y1,
            //     bvh,
            //     primitives,
            //     tex_buf,
            //     image_buffer,
            //     progress_node,
            // });
        }
    }

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = gpa });
    defer pool.deinit();

    var wg: std.Thread.WaitGroup = .{};

    // The queue state is an index into `tiles` that workers will increment
    // atomically under a mutex.
    // var queue_index: usize = 0;
    // var queue_mutex = std.Thread.Mutex{};

    var tile_counter: std.atomic.Value(usize) = .init(0);

    // var global_recursion_stats: DebugRenderStats = .{}; // null,
    // var rec_depth_mutex: std.Thread.Mutex = .{};

    for (0..pool.threads.len) |_| {
        pool.spawnWg(&wg, Camera.worker, .{
            self,
            tiles,
            &tile_counter,
            // &queue_index,
            // &queue_mutex,
            bvh,
            primitives,
            tex_buf,
            image_buffer,
            progress_node,
            // &global_recursion_stats,
            // &rec_depth_mutex,
        });
    }

    pool.waitAndWork(&wg);

    try file_out.print(
        "P6\n{d} {d}\n255\n",
        .{
            self.image_width,
            self._image_height,
        },
    );
    try file_out.writeSliceEndian(u8, std.mem.sliceAsBytes(image_buffer), .little);
    try file_out.flush();

    // Debug:
    // global_recursion_stats.print();
}

/// Repeatedly pops the index of the next tile to be rendered from the queue of
/// tile indices, and renders the corresponding tile until all tiles have been
/// rendered.
fn worker(
    self: Camera,
    tiles: []Tile,
    tile_counter_ptr: *std.atomic.Value(usize),
    // queue_index_ptr: *usize,
    // queue_mutex: *std.Thread.Mutex,
    bvh: *Bvh,
    primitives: []const Primitive,
    tex_buf: []const Texture,
    image_buffer: [][3]u8,
    progress_node: std.Progress.Node,
    // global_recursion_stats: ?*DebugRenderStats,
    // rec_depth_mutex: *std.Thread.Mutex,
) void {
    while (true) {
        // Fetch the next tile index.
        const idx: usize = tile_counter_ptr.fetchAdd(1, .acq_rel);
        if (idx >= tiles.len) break;

        const t = tiles[idx];
        self.renderTile(
            t.seed,
            t.x0,
            t.y0,
            t.x1,
            t.y1,
            bvh,
            primitives,
            tex_buf,
            image_buffer,
            progress_node,
            // global_recursion_stats,
            // rec_depth_mutex,
        );

        // var current_tile: ?Tile = null;
        //
        // // Pop the next tile index (protected by mutex)
        // queue_mutex.lock();
        // if (queue_index_ptr.* < tiles.len) {
        //     const idx = queue_index_ptr.*;
        //     queue_index_ptr.* += 1;
        //     current_tile = tiles[idx];
        // }
        //
        // queue_mutex.unlock();
        // if (current_tile == null) break;
        //
        // const t = current_tile.?;
        // self.renderTile(
        //     t.seed,
        //     t.x0,
        //     t.y0,
        //     t.x1,
        //     t.y1,
        //     bvh,
        //     primitives,
        //     tex_buf,
        //     image_buffer,
        //     progress_node,
        // );
    }
}

fn renderTile(
    self: Camera,
    tile_seed: u64,
    x0: usize,
    y0: usize,
    x1: usize,
    y1: usize,
    bvh: *Bvh,
    primitives: []const Primitive,
    tex_buf: []const Texture,
    image_buffer: [][3]u8,
    progress_node: std.Progress.Node,
    // global_recursion_stats: ?*DebugRenderStats,
    // rec_depth_mutex: *std.Thread.Mutex,
) void {
    defer progress_node.completeOne();

    // Debug:
    // Seed PRNG for this tile. Each thread gets its own PRNG.
    var prng = std.Random.DefaultPrng.init(tile_seed);
    var tile_rng = prng.random();

    // var avg_tile_rec_depth_count: u64 = 0;
    // var avg_tile_rec_depth_accum: f64 = 0;

    // TODO: Not sure about this variance early termination algorithm. It might
    // be resulting in artefacts in the final rendered image. The light source
    // quad never fully renders as white for some reason. Moreover, There are
    // these weird magenta pixels beneath the glass sphere and there are also
    // completely black pixels in both the perlin noise sphere and the white
    // spheres that make up the cube.
    //
    // Try rendering the scene with just the light source and background (no
    // floor, or other spheres) and see if the light source renders correctly.

    for (y0..y1) |row| {
        for (x0..x1) |col| {
            // Adaptive sampling.
            var pixel_noise_stats: PixelStats = .{};
            // var pixel_rec_depth_accum: u64 = 0; // Per-pixel recursion depth accumulator. Stores the total number of recursions for all samples of the current pixel.

            while (pixel_noise_stats.num_samples < self.max_samples_per_pixel) {
                // var sample_rec_depth_counter: u64 = 0;

                const ray = self.getRay(&tile_rng, @floatFromInt(col), @floatFromInt(row));
                const sample = self.rayColour(&tile_rng, ray, 0, bvh, primitives, tex_buf);

                pixel_noise_stats.update(sample);

                // pixel_rec_depth_accum += sample_rec_depth_counter; // Accumulate current sample recursion depth.

                if (pixel_noise_stats.num_samples >= self.min_samples_per_pixel) {
                    const std_dev = @sqrt(vec.divScalar(pixel_noise_stats.variance(), @floatFromInt(pixel_noise_stats.num_samples)));
                    const pixel_noise = @max(pixel_noise_stats.mean / std_dev, vec.zero);

                    // Pixel colour has converged.
                    if (@reduce(.And, pixel_noise < self.noise_threshold)) break;
                }
            }

            // avg_tile_rec_depth_count += 1;
            //
            // avg_tile_rec_depth_accum += @as(f64, @floatFromInt(pixel_rec_depth_accum)) /
            //     @as(f64, @floatFromInt(pixel_noise_stats.num_samples));

            const img_idx = row * self.image_width + col; // Convert 2D pixel tile coordinate to 1D image buffer index.

            // Transform the normalized pixel colour from a linear to gamma
            // colour space using the gamma 2 transform.
            const r_byte, const g_byte, const b_byte = vec.splat(255.999) * @sqrt(@max(pixel_noise_stats.mean, vec.zero));

            image_buffer[img_idx] = .{
                @intFromFloat(r_byte), // r-byte
                @intFromFloat(g_byte), // g-byte
                @intFromFloat(b_byte), // b-byte
            };

            // Previous tile-based rendering:
            // var pixel_colour = vec.zero;
            //
            // for (0..self.samples_per_pixel) |_| {
            //     const ray = self.getRay(&tile_rng, @floatFromInt(col), @floatFromInt(row));
            //     pixel_colour += self.rayColour(&tile_rng, ray, 0, bvh, primitives, tex_buf);
            // }
            //
            // // Normalize the pixel colour value to [0,1].
            // pixel_colour *= self._pixel_samples_scale;
            //
            // Transform the pixel colour from a linear to gamma colour space using
            // the gamma 2 transform.
            // const r_byte, const g_byte, const b_byte = vec.splat(255.999) * @sqrt(@max(pixel_colour, vec.zero));
            //
            // Translate the [0, 1.0] pixel rgb colour component to the byte range
            // [0, 255], and wrote the components to the scanline buffer.
            // image_buffer[img_idx] = .{
            //     @intFromFloat(r_byte), // r-byte
            //     @intFromFloat(g_byte), // g-byte
            //     @intFromFloat(b_byte), // b-byte
            // };
        }
    }

    // if (global_recursion_stats) |rec_stats| {
    //     rec_depth_mutex.lock();
    //     rec_stats.count += avg_tile_rec_depth_count;
    //     rec_stats.sum += avg_tile_rec_depth_accum;
    //     rec_depth_mutex.unlock();
    // }
}

/// Constructs a camera ray originating from the defocus disk and directed at a
/// randomly sampled point around the pixel location (i, j), where i is the
/// pixel `column` position and j is the pixel `row` position.
fn getRay(self: Camera, rng: *std.Random, column: f64, row: f64) Ray {
    @setFloatMode(.optimized);

    const offset: Vec3 = sampleSquare(rng);
    const pixel_sample = self._pixel00_loc +
        self._pixel_delta_u * vec.splat(vec.x(offset) + column) +
        self._pixel_delta_v * vec.splat(vec.y(offset) + row);
    const ray_origin = if (self.defocus_angle_deg <= 0) self._center else self.defocusDiskSample(rng);
    const ray_time = vec.randomFloat(rng);
    return .initMoving(ray_origin, pixel_sample - ray_origin, ray_time);
}

/// Returns the vector to a random point in the [-0.5,-0.5]-[+0.5,+0.5] unit square.
fn sampleSquare(rng: *std.Random) Vec3 {
    return .{
        vec.randomFloat(rng) - 0.5,
        vec.randomFloat(rng) - 0.5,
        0,
    };
}

/// Returns a random point in the camera defocus disk.
fn defocusDiskSample(self: Camera, rng: *std.Random) Point3 {
    const v = vec.randomVecInUnitDisk(rng);
    return self._center +
        vec.scale(self._defocus_disk_u, vec.x(v)) +
        vec.scale(self._defocus_disk_v, vec.y(v));
}

fn rayColour(
    self: Camera,
    rng: *std.Random,
    ray: Ray,
    depth: comptime_int,
    bvh: *Bvh,
    primitives: []const Primitive,
    tex_buf: []const Texture,
) Colour {
    @setFloatMode(.optimized);

    // TODO(amanda): Use iterative loop instead of recursion.

    // If we've exceeded the ray bounce limit, no more light is gathered.
    if (depth == self.max_recursion_depth) return vec.zero;

    const interval: Interval = .{
        .min = 0.001,
        .max = vec.infinity,
    };
    if (bvh.stackHit(rng, primitives, ray, interval)) |optional_hit| {
        if (optional_hit) |hit| {
            const colour_from_emission = hit.material.emittedColour(hit.u, hit.v, hit.p, tex_buf);
            const scattered_ray = hit.material.scatter(rng, ray, hit) orelse return colour_from_emission;

            const colour_from_scatter = hit.material.attenuation(hit, tex_buf) *
                self.rayColour(rng, scattered_ray, depth + 1, bvh, primitives, tex_buf);

            return colour_from_emission + colour_from_scatter;
        }
    } else |_| return .{ 0, 1, 1 };

    return self.background_colour;
}

pub const bouncing_spheres: Camera = .init(
    16.0 / 9.0,
    400,
    20,
    Point3{ 13, 2, 3 },
    vec.zero,
    Vec3{ 0, 1, 0 },
    0.6,
    default_focus_dist,
    default_bg_colour,
    null,
    null,
    null,
);

pub const checker: Camera = .init(
    16.0 / 9.0,
    400,
    20,
    Point3{ 13, 2, 3 },
    vec.zero,
    Vec3{ 0, 1, 0 },
    default_defocus_angle_deg,
    default_focus_dist,
    default_bg_colour,
    null,
    null,
    null,
);

pub const earth: Camera = .init(
    16.0 / 9.0,
    800,
    20,
    Point3{ 0, 0, 12 },
    vec.zero,
    Vec3{ 0, 1, 0 },
    default_defocus_angle_deg,
    default_focus_dist,
    default_bg_colour,
    1000, // null,
    15000, // null,
    null,
);

pub const quads: Camera = .init(
    1.0,
    400,
    80,
    Point3{ 0, 0, 9 },
    vec.zero,
    Vec3{ 0, 1, 0 },
    default_defocus_angle_deg,
    default_focus_dist,
    default_bg_colour,
    null,
    null,
    null,
);

pub const simple_light: Camera = .init(
    16.0 / 9.0,
    400,
    20,
    Point3{ 23, 3, 6 },
    Vec3{ 0, 2, 0 },
    Vec3{ 0, 1, 0 },
    default_defocus_angle_deg,
    default_focus_dist,
    vec.zero,
    null,
    null,
    null,
);

pub const cornell: Camera = .init(
    1.0,
    600,
    40,
    Point3{ 278, 278, -800 },
    Vec3{ 278, 278, 0 },
    Vec3{ 0, 1, 0 },
    default_defocus_angle_deg,
    default_focus_dist,
    vec.zero,
    null,
    null,
    null,
);

pub const final: Camera = blk: {
    var c: Camera = .init(
        1.0,
        600,
        40,
        Point3{ 478, 278, -600 },
        Vec3{ 278, 278, 0 },
        Vec3{ 0, 1, 0 },
        default_defocus_angle_deg,
        default_focus_dist,
        vec.zero,
        null,
        null,
        null,
    );
    c.max_recursion_depth = 40;
    break :blk c;
};

const std = @import("std");
const Writer = std.Io.Writer;

const Bvh = @import("bvh.zig").Bvh;
const hittable = @import("hittable.zig");
const Primitive = hittable.Primitive;
const Interval = @import("Interval.zig");
const Material = @import("material.zig").Material;
const Ray = @import("Ray.zig");
const Texture = @import("texture.zig").Texture;
const vec = @import("vec.zig");
const Colour = vec.Colour;
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;

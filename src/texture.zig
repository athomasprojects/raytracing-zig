const TextureTag = enum {
    solid_colour,
    checker,
    image,
    noise,
};

pub const Texture = union(TextureTag) {
    solid_colour: struct {
        albedo: Colour,

        pub inline fn fromRgb(rgb: Colour) @This() {
            return .{ .albedo = rgb };
        }
    },

    checker: struct {
        inv_scale: f64,
        even_idx: u32, // Index of the 'even' texture in a buffer of textures.
        odd_idx: u32, // Index of the 'odd' texture in a buffer of textures.

        pub fn init(scale: f64, even: u32, odd: u32) @This() {
            return .{
                .inv_scale = 1.0 / scale,
                .even_idx = even,
                .odd_idx = odd,
            };
        }

        // pub fn fromColours(scale: f64, c1: Colour, c2: Colour, tex_buf: []Texture) !@This() {
        //     const even_idx = tex_buf.items.len;
        //     const odd_idx = even_idx + 1;
        //     tex_buf[even_idx] = .{ .solid_colour = .{ .albedo = c1 } };
        //     tex_buf[odd_idx] = .{ .solid_colour = .{ .albedo = c2 } };
        //
        //     return .{
        //         .inv_scale = 1.0 / scale,
        //         .even = even_idx,
        //         .odd = even_idx + 1,
        //     };
        // }

        fn value(self: @This(), u: f64, v: f64, p: Point3, tex_buf: []const Texture) Colour {
            var sum: i64 = 0;
            for (0..3) |i| {
                sum += @intFromFloat(@floor(self.inv_scale * p[i]));
            }

            return if (@mod(sum, 2) == 0)
                tex_buf[self.even_idx].value(u, v, p, tex_buf)
            else
                tex_buf[self.odd_idx].value(u, v, p, tex_buf);
        }
    },

    image: struct {
        img: zstbi.Image,

        const Self = @This();
        const bytes_per_pixel = 3;

        pub fn init(pathname: [:0]const u8, forced_num_components: ?u32) !Self {
            const num_components = forced_num_components orelse Self.bytes_per_pixel;
            return .{ .img = try .loadFromFile(pathname, num_components) };
        }

        pub fn value(self: Self, u: f64, v: f64) Colour {
            // Clamp input texture coordinates to [0,1] x [1,0]
            const u_clamp = std.math.clamp(u, 0, 1);
            const v_clamp = 1.0 - std.math.clamp(v, 0, 1); // Flip image coordinates.

            // Converting texture coordinates (u,v) into texture (image) indices:
            //     Our image pixel data is represented by a 2D array, where each pixel's position
            //     is given by a coordinate pair (x, y). The pixel data is stored in memory as a
            //     1D array of bytes, wherein each scan line (row) of pixels is stored sequentially.
            //
            //     1. We can therefore access a particular scan line of pixels by indexing into
            //     the array by an offset of `row * bytes_per_scanline`.
            //
            //     2. To select a pixel from a scan line we subsequently index into the scan line
            //     by an offset of `col * bytes_per_pixel`.
            //
            //     In general, to convert a 2D coordinate (x, y) to a 1D coordinate we can use: `y * width + x`.

            // Denormalize the normalized texture space coordinates to 2D texture coordinates (x,y).
            var col: u32 = @intFromFloat(u_clamp * @as(f64, @floatFromInt(self.img.width)));
            var row: u32 = @intFromFloat(v_clamp * @as(f64, @floatFromInt(self.img.height)));

            if (col >= self.img.width) col = self.img.width - 1;
            if (row >= self.img.height) row = self.img.height - 1;

            const index = row * self.img.bytes_per_row + (col * Self.bytes_per_pixel); // Convert 2D coordinate to 1D index.
            const pixel = self.img.data[index .. index + Self.bytes_per_pixel];

            return vec.divScalar(
                Colour{
                    @floatFromInt(pixel[0]),
                    @floatFromInt(pixel[1]),
                    @floatFromInt(pixel[2]),
                },
                255,
            );
        }
    },

    noise: struct {
        scale: f64,
        rand_unit_vecs: [point_count]Vec3 = .{vec.zero} ** point_count,
        perm_x: [point_count]u32 = .{0} ** point_count,
        perm_y: [point_count]u32 = .{0} ** point_count,
        perm_z: [point_count]u32 = .{0} ** point_count,

        const point_count: u32 = 256;
        const max_turbulence_depth = 10;

        pub fn init(rng: *std.Random, scale: f64) @This() {
            var perlin: @This() = .{ .scale = scale };

            // Generate array of unit vectors with random translations.
            for (0..perlin.rand_unit_vecs.len) |i| {
                perlin.rand_unit_vecs[i] = vec.unit(vec.randomVecInRange(rng, -1, 1));
            }

            // Generate permutation arrays used to randomize indices in noise generation.
            const fields = @typeInfo(@This()).@"struct".fields;
            inline for (fields[2..]) |field| perlinGeneratePermutation(rng, &@field(perlin, field.name));

            return perlin;
        }

        fn perlinGeneratePermutation(rand: *std.Random, p: []u32) void {
            for (0..p.len) |i| p[i] = @as(u32, @intCast(i));
            permute(rand, p);
        }

        fn permute(rng: *std.Random, p: []u32) void {
            var i = point_count - 1;
            while (i > 0) : (i -= 1) {
                const target = rng.uintAtMost(u32, i);
                const tmp = p[i];
                p[i] = p[target];
                p[target] = tmp;
            }
        }

        fn value(self: @This(), p: Point3) Colour {
            return vec.splat(0.5 * (1 + @sin(self.scale * vec.z(p) + 10 * self.turbulence(p, 7))));
        }

        fn turbulence(self: @This(), p: Point3, depth: u32) f64 {
            if (depth > max_turbulence_depth) return 0;

            var accum: f64 = 0;
            var temp_p = p;
            var weight: f64 = 1;
            for (0..depth) |_| {
                accum += weight * self.noise(temp_p);
                weight *= 0.5;
                temp_p = vec.scale(temp_p, 2);
            }
            return @abs(accum);
        }

        /// Returns a repeatable pseudo-random number tied to the cell of space containing the sampled point.
        fn noise(self: @This(), p: Point3) f64 {
            // We are effectively hashing (scramble + combine) the coordinates of our
            // sample point and returning the corresponding pseudo-random float from our LUT.

            // Compute the "in-cell" coordinates (i.e. how far along the voxel we are).
            const u = vec.x(p) - @floor(vec.x(p));
            const v = vec.y(p) - @floor(vec.y(p));
            const w = vec.z(p) - @floor(vec.z(p));

            // Use a Hermite cubic spline to round off the interpolation.
            const uu = u * u * @mulAdd(f64, -2, u, 3); // (3 - 2 * u);
            const vv = v * v * @mulAdd(f64, -2, v, 3); // (3 - 2 * v);
            const ww = w * w * @mulAdd(f64, -2, w, 3); // (3 - 2 * w);

            const i: i32 = @intFromFloat(@floor(vec.x(p)));
            const j: i32 = @intFromFloat(@floor(vec.y(p)));
            const k: i32 = @intFromFloat(@floor(vec.z(p)));

            const u_factors: [2]f64 = .{ 1.0 - uu, uu };
            const v_factors: [2]f64 = .{ 1.0 - vv, vv };
            const w_factors: [2]f64 = .{ 1.0 - ww, ww };

            const per_corner_interpolation_weights: [8]f64 = .{
                u_factors[0] * v_factors[0] * w_factors[0],
                u_factors[1] * v_factors[0] * w_factors[0],
                u_factors[0] * v_factors[1] * w_factors[0],
                u_factors[1] * v_factors[1] * w_factors[0],
                u_factors[0] * v_factors[0] * w_factors[1],
                u_factors[1] * v_factors[0] * w_factors[1],
                u_factors[0] * v_factors[1] * w_factors[1],
                u_factors[1] * v_factors[1] * w_factors[1],
            };

            const offsets: [8][3]i32 = .{
                .{ 0, 0, 0 },
                .{ 1, 0, 0 },
                .{ 0, 1, 0 },
                .{ 1, 1, 0 },
                .{ 0, 0, 1 },
                .{ 1, 0, 1 },
                .{ 0, 1, 1 },
                .{ 1, 1, 1 },
            };

            var accum: f64 = 0;
            for (offsets, 0..offsets.len) |offset, index| {
                const ii: u32 = @intCast((i + offset[0]) & 255);
                const jj: u32 = @intCast((j + offset[1]) & 255);
                const kk: u32 = @intCast((k + offset[2]) & 255);
                const hash_idx = self.perm_x[ii] ^ self.perm_y[jj] ^ self.perm_z[kk];

                accum += per_corner_interpolation_weights[index] * vec.dot(
                    self.rand_unit_vecs[hash_idx],
                    Vec3{
                        u - @as(f64, @floatFromInt(offset[0])),
                        v - @as(f64, @floatFromInt(offset[1])),
                        w - @as(f64, @floatFromInt(offset[2])),
                    },
                );
            }
            return accum;
        }
    },

    pub fn value(self: Texture, u: f64, v: f64, p: Point3, tex_buf: []const Texture) Colour {
        return switch (self) {
            .solid_colour => |t| t.albedo,
            .image => |img| img.value(u, v),
            .noise => |noise| noise.value(p),
            inline else => |t| t.value(u, v, p, tex_buf),
        };
    }

    pub fn deinitImage(self: *Texture) void {
        switch (self.*) {
            .image => |*image| image.img.deinit(),
            inline else => @panic("Invalid Texture, expected tag '" ++ @tagName(TextureTag.image) ++ "'"),
        }
    }
};

const std = @import("std");

const vec = @import("vec.zig");
const Colour = vec.Colour;
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;
const zstbi = @import("zstbi");

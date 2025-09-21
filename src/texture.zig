const std = @import("std");
const vec = @import("vec.zig");

const Colour = vec.Colour;
const Point3 = vec.Point3;

const stb = @cImport({
    @cDefine("STBI_ONLY_JPEG", "");
    @cInclude("stb_image.h");
});

const StbError = error{
    ImageLoadFailed,
};

pub const Texture = union(enum) {
    solid_colour: struct {
        albedo: Colour,

        pub inline fn init(albedo: Colour) @This() {
            return .{ .albedo = albedo };
        }

        pub inline fn initRgb(red: f64, green: f64, blue: f64) @This() {
            return .{ .albedo = .{ red, green, blue } };
        }

        inline fn value(self: @This(), _: f64, _: f64, _: Point3, _: []const Texture) Colour {
            return self.albedo;
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

        // pub fn fromColours(gpa: std.mem.Allocator, scale: f64, c1: Colour, c2: Colour, tex_buf: std.ArrayListUnmanaged(Texture)) !@This() {
        //     var textures = [_]Texture{
        //         .{ .solid_colour = .{ .albedo = c1 } },
        //         .{ .solid_colour = .{ .albedo = c2 } },
        //     };
        //
        //     const offset = tex_buf.items.len;
        //     try tex_buf.appendSlice(gpa, &textures);
        //     return .{
        //         .inv_scale = 1.0 / scale,
        //         .even = offset,
        //         .odd = offset + 1,
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
        data: ?[]u8 = null,
        width: u32 = 0,
        height: u32 = 0,
        bytes_per_scanline: u32 = 0,

        const bytes_per_pixel = 3;
        const Self = @This();

        pub fn init(pathname: [:0]const u8) !Self {
            var w: c_int = 0;
            var h: c_int = 0;
            var width: u32 = 0;
            var height: u32 = 0;
            var components_per_pixel: c_int = Self.bytes_per_pixel;

            const float_data_ptr = stb.stbi_load(pathname.ptr, &w, &h, &components_per_pixel, components_per_pixel);

            if (float_data_ptr == null) return StbError.ImageLoadFailed;

            width = @intCast(w);
            height = @intCast(h);
            const bytes_per_scanline = width * bytes_per_pixel;

            return .{
                .width = width,
                .height = height,
                .bytes_per_scanline = bytes_per_scanline,
                .data = @as([*]u8, @ptrCast(float_data_ptr))[0 .. height * bytes_per_scanline],
            };
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            // stb.stbi_image_free(self.data.ptr);
            gpa.free(self.data.?);
            self.* = undefined;
        }

        pub fn value(self: Self, u: f64, v: f64, _: Point3, _: []const Texture) Colour {
            if (self.data) |data| {
                // Clamp input texture coordinates to [0,1] x [1,0]
                const u_clamp = std.math.clamp(u, 0, 1);
                const v_clamp = 1.0 - std.math.clamp(v, 0, 1); // Flip image coordinates.

                var col: u32 = @intFromFloat(u_clamp * @as(f64, @floatFromInt(self.width)));
                var row: u32 = @intFromFloat(v_clamp * @as(f64, @floatFromInt(self.height)));

                if (col >= self.width) col = self.width - 1;
                if (row >= self.height) row = self.height - 1;

                const index = row * self.bytes_per_scanline + col * Self.bytes_per_pixel;
                const pixel = data[index .. index + Self.bytes_per_pixel];

                const colour_scale: f64 = 1.0 / 255.0;
                return vec.scale(
                    Colour{
                        @floatFromInt(pixel[0]),
                        @floatFromInt(pixel[1]),
                        @floatFromInt(pixel[2]),
                    },
                    colour_scale,
                );
            }

            // If we have no texture data, then return solid cyan as a debugging aid.
            return .{ 0, 1, 1 };
        }
    },

    pub fn value(self: Texture, u: f64, v: f64, p: Point3, tex_buf: []const Texture) Colour {
        return switch (self) {
            inline else => |tex| tex.value(u, v, p, tex_buf),
        };
    }
};

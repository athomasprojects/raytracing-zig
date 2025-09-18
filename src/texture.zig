const std = @import("std");
const vec = @import("vec.zig");

const Colour = vec.Colour;
const Point3 = vec.Point3;

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

    pub fn value(self: Texture, u: f64, v: f64, p: Point3, tex_buf: []const Texture) Colour {
        return switch (self) {
            inline else => |tex| tex.value(u, v, p, tex_buf),
        };
    }
};

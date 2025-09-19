const std = @import("std");
const bvh = @import("bvh.zig");
const hittable = @import("hittable.zig");
const vec = @import("vec.zig");

const BoundedList = @import("util.zig").BoundedList;
const Bvh = bvh.Bvh;
const Camera = @import("Camera.zig");
const Material = @import("material.zig").Material;
const Point3 = vec.Point3;
const Sphere = hittable.Sphere;
const Texture = @import("texture.zig").Texture;
const Vec3 = vec.Vec3;

pub fn main() !void {
    const gpa = std.heap.smp_allocator;

    const ppm_dir = "images/the-next-week/";
    const ppm_fname = "img6.ppm";
    const path = ppm_dir ++ ppm_fname;

    // Create or open ppm file.
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Get file writer interface.
    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const file_out = &file_writer.interface;

    const checker_textures = comptime [_]Texture{
        .{
            .solid_colour = .initRgb(0.2, 0.3, 0.1),
        },
        .{
            .solid_colour = .initRgb(0.9, 0.9, 0.9),
        },
        .{ .checker = .init(0.32, 0, 1) },
    };

    var primitives: BoundedList(Sphere) = try bouncingSpheres(gpa, 490, &checker_textures);
    defer primitives.deinit(gpa);

    var bounding_volumes: Bvh = try .buildAllocating(gpa, primitives.list.items);
    defer bounding_volumes.deinit(gpa);

    const cam: Camera = .default;
    try cam.render(file_out, &bounding_volumes, primitives.list.items, &checker_textures);
}

fn initObjects2(buf: []Sphere) !BoundedList(Sphere) {
    var objects = comptime blk: {
        const ground: Material = .{
            .lambertian = .{ .tex = .{ .solid_colour = .initRgb(0.8, 0.8, 0) } },
        };
        const center: Material = .{
            .lambertian = .{ .tex = .{ .solid_colour = .initRgb(0.1, 0.2, 0.5) } },
        };
        const left: Material = .{
            .metal = .{ .albedo = .{ 0.8, 0.8, 0.8 }, .fuzz = 0.3 },
        };
        _ = left;
        const right: Material = .{
            .metal = .{ .albedo = .{ 0.8, 0.6, 0.2 }, .fuzz = 1 },
        };
        const left_glass: Material = .{
            .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 },
        };
        const bubble: Material = .{
            .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.0 / 1.5 },
        };

        break :blk [_]Sphere{
            .init(.{ 0, -100.5, -1 }, 100, ground),
            .init(.{ 0, 0, -1.2 }, 0.5, center),
            .init(.{ -1, 0, -1 }, 0.5, left_glass),
            .init(.{ -1, 0, -1 }, 0.4, bubble),
            .init(.{ 1, 0, -1 }, 0.5, right),
        };
    };

    var primitives: BoundedList(Sphere) = .init(buf);
    try primitives.list.appendSliceBounded(&objects);
    return primitives;
}

fn initObjects1(buf: []Sphere) !BoundedList(Sphere) {
    var objects = comptime blk: {
        const R = @cos(std.math.pi * 0.25);

        const left: Material = .{
            .lambertian = .{ .tex = .{ .solid_colour = .initRgb(0, 0, 1) } },
        };
        const right: Material = .{
            .lambertian = .{ .tex = .{ .solid_colour = .initRgb(1, 0, 0) } },
        };

        break :blk [_]Sphere{
            .init(.{ -R, 0, -1 }, R, left),
            .init(.{ R, 0, -1 }, R, right),
        };
    };

    var primitives: BoundedList(Sphere) = .init(buf);
    try primitives.list.appendSliceBounded(&objects);
    return primitives;
}

fn bouncingSpheres(gpa: std.mem.Allocator, max_capacity: usize, tex_buf: []const Texture) !BoundedList(Sphere) {
    // const ground: Material = .{
    //     .lambertian = .{ .tex = .{ .solid_colour = .initRgb(0.5, 0.5, 0.5) } },
    // };

    var primitives: BoundedList(Sphere) = try .initCapacity(gpa, max_capacity);

    const ground: Material = .{
        .lambertian = .{ .tex = tex_buf[tex_buf.len - 1] },
    };

    try primitives.list.appendBounded(.init(Point3{ 0, -1000, 0 }, 1000, ground));

    for (0..22) |i| {
        const a: f64 = @as(f64, @floatFromInt(i)) - 11.0;
        for (0..22) |j| {
            const b: f64 = @as(f64, @floatFromInt(j)) - 11.0;

            const choose_mat = vec.randomFloat();
            const center: Vec3 = .{
                a + 0.9 * vec.randomFloat(),
                0.2,
                b + 0.9 * vec.randomFloat(),
            };

            const p: Vec3 = center - Point3{ 4, 0.2, 0 };
            var material: Material = undefined;
            if (vec.magnitude(p) > 0.9) {
                if (choose_mat < 0.8) {
                    // Diffuse
                    material = .{
                        .lambertian = .{ .tex = .{ .solid_colour = .{ .albedo = vec.randomVec() * vec.randomVec() } } },
                    };
                    try primitives.list.appendBounded(
                        .initMoving(
                            center,
                            center + Vec3{ 0, vec.randomFloatInRange(0, 0.5), 0 },
                            0.2,
                            material,
                        ),
                    );
                } else if (choose_mat < 0.95) {
                    // Metal
                    material = .{
                        .metal = .{
                            .albedo = vec.randomVecInRange(0.5, 1),
                            .fuzz = vec.randomFloatInRange(0, 0.5),
                        },
                    };
                    try primitives.list.appendBounded(.init(center, 0.2, material));
                } else {
                    // Glass
                    material = .{
                        .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 },
                    };
                    try primitives.list.appendBounded(.init(center, 0.2, material));
                }
            }
        }
    }

    var objects = [3]Sphere{
        .init(
            Point3{ 0, 1, 0 },
            1,
            .{ .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 } },
        ),
        .init(
            Point3{ -4, 1, 0 },
            1,
            .{ .lambertian = .{ .tex = .{ .solid_colour = .initRgb(0.4, 0.2, 0.1) } } },
        ),
        .init(
            Point3{ 4, 1, 0 },
            1,
            .{ .metal = .{ .albedo = .{ 0.7, 0.6, 0.5 }, .fuzz = 0 } },
        ),
    };
    try primitives.list.appendSliceBounded(&objects);

    return primitives;
}

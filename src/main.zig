const std = @import("std");
const Camera = @import("Camera.zig");
const hittable = @import("hittable.zig");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const HittableList = hittable.HittableList;
const Sphere = hittable.Sphere;
const Ray = @import("Ray.zig");
const Material = @import("material.zig").Material;

const world_capacity = 490;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ppm_dir = "images/ppm/";
    const ppm_fname = "image24.ppm";
    const path = ppm_dir ++ ppm_fname;

    // World
    var world: HittableList = try .init(allocator, world_capacity);
    try initWorld2(&world);

    // Create writer to stdout.
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Create or open ppm file.
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Get file writer interface.
    var file_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const file_out = &file_writer.interface;

    const cam: Camera = .default;
    try cam.render(stdout, file_out, &world);
}

fn initWorld(world: *HittableList) !void {
    const ground: Material = .{
        .lambertian = .{ .albedo = .{ 0.8, 0.8, 0 } },
    };
    const center: Material = .{
        .lambertian = .{ .albedo = .{ 0.1, 0.2, 0.5 } },
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

    try world.addSlice(&.{
        .init(.{ 0, -100.5, -1 }, 100, ground),
        .init(.{ 0, 0, -1.2 }, 0.5, center),
        .init(.{ -1, 0, -1 }, 0.5, left_glass),
        .init(.{ -1, 0, -1 }, 0.4, bubble),
        .init(.{ 1, 0, -1 }, 0.5, right),
    });
}

fn initWorld1(world: *HittableList) !void {
    const R = @cos(std.math.pi * 0.25);

    const left: Material = .{
        .lambertian = .{ .albedo = .{ 0, 0, 1 } },
    };
    const right: Material = .{
        .lambertian = .{ .albedo = .{ 1, 0, 0 } },
    };
    try world.addSlice(&.{
        .init(.{ -R, 0, -1 }, R, left),
        .init(.{ R, 0, -1 }, R, right),
    });
}

fn initWorld2(world: *HittableList) !void {
    const ground: Material = .{
        .lambertian = .{ .albedo = .{ 0.5, 0.5, 0.5 } },
    };
    try world.add(.init(Point3{ 0, -1000, 0 }, 1000, ground));

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
            if (vec.magnitude(p) > 0.9) {
                const material: Material = if (choose_mat < 0.8)
                    // Diffuse
                    .{
                        .lambertian = .{ .albedo = vec.randomVec() * vec.randomVec() },
                    }
                else if (choose_mat < 0.95)
                    // Metal
                    .{
                        .metal = .{
                            .albedo = vec.randomVecRange(0.5, 1),
                            .fuzz = vec.randomFloatRange(0, 0.5),
                        },
                    }
                else
                    // Glass
                    .{
                        .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 },
                    };
                try world.add(.init(center, 0.2, material));
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
            .{ .lambertian = .{ .albedo = .{ 0.4, 0.2, 0.1 } } },
        ),
        .init(
            Point3{ 4, 1, 0 },
            1,
            .{ .metal = .{ .albedo = .{ 0.7, 0.6, 0.5 }, .fuzz = 0 } },
        ),
    };
    try world.addSlice(&objects);
}

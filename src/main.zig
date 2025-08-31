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

const world_capacity = 100;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ppm_dir = "images/ppm/";
    const ppm_fname = "image18.ppm";
    const path = ppm_dir ++ ppm_fname;

    // World
    var world: HittableList = try .init(allocator, world_capacity);
    try world.objects.appendSlice(allocator, &initWorld());

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

fn initWorld() [5]Sphere {
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

    return .{
        .init(.{ 0, -100.5, -1 }, 100, ground),
        .init(.{ 0, 0, -1.2 }, 0.5, center),
        .init(.{ -1, 0, -1 }, 0.5, left_glass),
        .init(.{ -1, 0, -1 }, 0.4, bubble),
        .init(.{ 1, 0, -1 }, 0.5, right),
    };
}

fn initWorld1() [2]Sphere {
    const R = @cos(std.math.pi * 0.25);

    const left: Material = .{
        .lambertian = .{ .albedo = .{ 0, 0, 1 } },
    };
    const right: Material = .{
        .lambertian = .{ .albedo = .{ 1, 0, 0 } },
    };
    return .{
        .init(.{ -R, 0, -1 }, R, left),
        .init(.{ R, 0, -1 }, R, right),
    };
}

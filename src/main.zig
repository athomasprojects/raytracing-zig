const std = @import("std");
const Camera = @import("Camera.zig");
const hittable = @import("hittable.zig");
const HitRecord = hittable.HitRecord;
const Hittable = hittable.Hittable;
const HittableList = hittable.HittableList;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
const Ray = @import("Ray.zig");
const Sphere = @import("Sphere.zig");
const Material = @import("material.zig").Material;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ppm_dir = "images/ppm/";
    const ppm_fname = "image11.ppm";
    const path = ppm_dir ++ ppm_fname;

    // World

    const material_ground: Material = .{ .lambertian = .{ 0.8, 0.8, 0 } };
    const material_center: Material = .{ .lambertian = .{ 0.1, 0.2, 0.5 } };
    const material_left: Material = .{ .metal = .{ 0.8, 0.8, 0.8 } };
    const material_right: Material = .{ .metal = .{ 0.8, 0.6, 0.2 } };

    const world_capacity: usize = 128;
    var world: HittableList = try .init(allocator, world_capacity);
    try world.add(
        .{ .sphere = Sphere.init(.{ 0, -100.5, -1 }, 100, &material_ground) },
    );
    try world.add(
        .{ .sphere = Sphere.init(.{ 0, 0, -1.2 }, 0.5, &material_center) },
    );
    try world.add(
        .{ .sphere = Sphere.init(.{ -1, 0, -1 }, 0.5, &material_left) },
    );
    try world.add(
        .{ .sphere = Sphere.init(.{ 1, 0, -1 }, 0.5, &material_right) },
    );

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

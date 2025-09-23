const std = @import("std");
const bvh = @import("bvh.zig");
const hittable = @import("hittable.zig");
const vec = @import("vec.zig");

const BoundedList = @import("util.zig").BoundedList;
const Bvh = bvh.Bvh;
const BvhNode = bvh.Node;
const Camera = @import("Camera.zig");
const Material = @import("material.zig").Material;
const Point3 = vec.Point3;
const Sphere = hittable.Sphere;
const Texture = @import("texture.zig").Texture;
const Vec3 = vec.Vec3;
const Writer = std.Io.Writer;

pub fn main() !void {
    const ppm_dir = "images/the-next-week/";
    const ppm_fname = "img10.ppm";
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

    try perlinSpheres(file_out, &checker_textures);
    // try earth(file_out, &checker_textures);
    // try bouncingSpheres(file_out, 490, &checker_textures);
    // try checkeredSpheres(file_out, &checker_textures);
}

pub fn perlinSpheres(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const perlin: Texture = .{ .noise = .init(4) };
    const prim_count = 2;
    var prim_buf: [prim_count]Sphere = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Sphere) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&.{
        .init(
            Point3{ 0, -1000, 0 },
            1000,
            .{ .lambertian = .{ .tex = perlin } },
        ),
        .init(
            Point3{ 0, 2, 0 },
            2,
            .{ .lambertian = .{ .tex = perlin } },
        ),
    });

    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .checker;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

pub fn earth(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const gpa = std.heap.smp_allocator;

    var earth_texture: Texture = .{ .image = try .init("./images/earthmap.jpg") };
    defer switch (earth_texture) {
        .image => |*img| img.deinit(gpa),
        else => unreachable,
    };

    const prim_count = 1;
    var prim_buf: [prim_count]Sphere = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Sphere) = .init(&prim_buf);
    try primitives.list.appendBounded(.init(
        vec.zero,
        2,
        .{ .lambertian = .{ .tex = earth_texture } }, // Earth surface.
    ));

    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .earth;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn checkeredSpheres(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const objects = [_]Sphere{
        .init(
            Point3{ 0, -10, 0 },
            10,
            .{ .lambertian = .{ .tex = tex_buf[tex_buf.len - 1] } },
        ),
        .init(
            Point3{ 0, 10, 0 },
            10,
            .{ .lambertian = .{ .tex = tex_buf[tex_buf.len - 1] } },
        ),
    };

    var prim_buf: [objects.len]Sphere = undefined;
    var indices: [objects.len]u32 = undefined;
    var node_buf: [2 * objects.len - 1]BvhNode = undefined;

    var primitives: BoundedList(Sphere) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&objects);

    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .checker;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn bouncingSpheres(file_writer: *Writer, comptime max_capacity: usize, comptime tex_buf: []const Texture) !void {
    const gpa = std.heap.smp_allocator;

    var primitives: BoundedList(Sphere) = try .initCapacity(gpa, max_capacity);
    defer primitives.deinit(gpa);

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

    try primitives.list.appendSliceBounded(&.{
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
    });

    var bounding_volumes: Bvh = try .buildAllocating(gpa, primitives.list.items);
    defer bounding_volumes.deinit(gpa);

    const cam: Camera = .default;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

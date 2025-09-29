const gpa = std.heap.smp_allocator;

pub fn main() !void {
    zstbi.init(gpa);
    defer zstbi.deinit();

    const ppm_dir = "images/the-next-week/";
    const ppm_fname = "final_high_res.ppm";
    const path = ppm_dir ++ ppm_fname;

    // Create or open ppm file.
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Get file writer interface.
    var file_buffer: [32768]u8 = undefined;
    var file_writer = file.writer(&file_buffer);
    const file_out = &file_writer.interface;

    const empty_tex_buf = comptime &[0]Texture{};
    const checker_textures = comptime [_]Texture{
        .{
            .solid_colour = .fromRgb(Colour{ 0.2, 0.3, 0.1 }),
        },
        .{
            .solid_colour = .fromRgb(Colour{ 0.9, 0.9, 0.9 }),
        },
        .{ .checker = .init(0.32, 0, 1) },
    };

    const SceneType = enum {
        final,
        cornell_box,
        cornell_smoke,
        simple_light,
        quads,
        perlin_spheres,
        earth,
        bouncing_spheres,
        checkered_spheres,
    };

    switch (SceneType.final) {
        .final => try finalScene(file_out, empty_tex_buf),
        .cornell_box => try cornellBox(file_out, empty_tex_buf),
        .cornell_smoke => try cornellSmoke(file_out, empty_tex_buf),
        .simple_light => try simpleLight(file_out, empty_tex_buf),
        .quads => try quads(file_out, empty_tex_buf),
        .perlin_spheres => try perlinSpheres(file_out, empty_tex_buf),
        .earth => try earth(file_out, empty_tex_buf),
        .checkered_spheres => try bouncingSpheres(file_out, 490, &checker_textures),
        .bouncing_spheres => try checkeredSpheres(file_out, &checker_textures),
    }

    errdefer file.close();
}

fn finalScene(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const rand = Camera.rand_state.random();

    // Allocate all required memory for creating scene primitives up front.
    const total_scene_prim_count = 1410;
    const tiny_sphere_count = 1000;
    var scene: BoundedList(Primitive) = try .initCapacity(gpa, total_scene_prim_count);
    var cube_of_spheres_buf = try gpa.alloc(Primitive, 3 * tiny_sphere_count);
    defer scene.deinit(gpa);
    defer gpa.free(cube_of_spheres_buf);

    // Materials
    const ground: Material = .{ .lambertian = .fromAlbedo(.{ 0.48, 0.83, 0.53 }) };
    const light: Material = .{ .diffuse_light = .fromEmittedColour(.{ 7, 7, 7 }) };
    const dielectric: Material = .{ .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 } };

    var earth_texture: Texture = .{ .image = try .init("./images/earthmap.jpg", null) };
    defer earth_texture.deinitImage();

    // Create scene floor blocks.
    const boxes_per_side = 20;
    for (0..boxes_per_side) |i| {
        for (0..boxes_per_side) |j| {
            const w = 100.0;
            const x0 = @as(f64, @floatFromInt(i)) * w - 1000.0;
            const z0 = @as(f64, @floatFromInt(j)) * w - 1000.0;

            try scene.list.appendBounded(.{ .box = .init(
                Point3{ x0, 0, z0 },
                Point3{ x0 + w, vec.randomFloatInRange(rand, 1, 101), z0 + w },
                ground,
            ) });
        }
    }

    // Large spheres.
    const center: Point3 = .{ 400, 400, 200 };
    const boundary: Primitive = .{ .sphere = .init(Point3{ 360, 150, 145 }, 70, dielectric) };
    try scene.list.appendSliceBounded(&.{
        .{ .quad = .init(
            Point3{ 123, 554, 147 },
            Vec3{ 300, 0, 0 },
            Vec3{ 0, 0, 265 },
            light,
        ) },
        .{ .sphere = .initMoving(
            center,
            center + Vec3{ 30, 0, 0 },
            50,
            .{ .lambertian = .fromAlbedo(.{ 0.7, 0.3, 0.1 }) },
        ) },
        .{ .sphere = .init(Point3{ 260, 150, 45 }, 50, dielectric) },
        .{ .sphere = .init(
            Point3{ 0, 150, 145 },
            50,
            .{ .metal = .{ .albedo = .{ 0.8, 0.8, 0.9 }, .fuzz = 1 } },
        ) },
        boundary,
        .{ .constant_medium = .fromAlbedo(&boundary, 0.2, Colour{ 0.2, 0.4, 0.9 }) },
        .{ .constant_medium = .fromAlbedo(
            &.{ .sphere = .init(vec.zero, 5000, dielectric) },
            0.0001,
            Colour{ 1, 1, 1 },
        ) },
        .{ .sphere = .init(
            Point3{ 400, 200, 400 },
            100,
            .{ .lambertian = .{ .tex = earth_texture } },
        ) },
        .{ .sphere = .init(
            Point3{ 220, 280, 300 },
            80,
            .{ .lambertian = .{ .tex = .{ .noise = .init(rand, 0.2) } } },
        ) },
    });

    // Cube of small spheres.
    const white: Material = .{ .lambertian = .fromAlbedo(Colour{ 0.73, 0.73, 0.73 }) };
    const translation_offset = 2 * tiny_sphere_count;
    for (0..tiny_sphere_count) |i| {
        const rot_idx = tiny_sphere_count + i;
        const trans_idx = translation_offset + i;
        cube_of_spheres_buf[i] = .{ .sphere = .init(vec.randomVecInRange(rand, 0, 165), 10, white) };
        cube_of_spheres_buf[rot_idx] = .{ .rotate = .init(&cube_of_spheres_buf[i], 15) };
        cube_of_spheres_buf[trans_idx] = .{ .translate = .init(&cube_of_spheres_buf[rot_idx], Vec3{ -100, 270, 395 }) };
    }
    try scene.list.appendSliceBounded(cube_of_spheres_buf[translation_offset..]);

    {
        var scene_bvh: Bvh = try .buildAllocating(gpa, scene.list.items);
        defer scene_bvh.deinit(gpa);

        const cam: Camera = .final;
        try cam.render(file_writer, &scene_bvh, scene.list.items, tex_buf);
        errdefer {
            scene_bvh.deinit(gpa);
            scene.deinit(gpa);
            earth_texture.deinitImageTexture();
            gpa.free(cube_of_spheres_buf);
        }
    }
}

fn cornellSmoke(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const red: Material = .{ .lambertian = .fromAlbedo(.{ 0.65, 0.05, 0.05 }) };
    const white: Material = .{ .lambertian = .fromAlbedo(.{ 0.73, 0.73, 0.73 }) };
    const green: Material = .{ .lambertian = .fromAlbedo(.{ 0.12, 0.45, 0.15 }) };
    const light: Material = .{ .diffuse_light = .fromEmittedColour(.{ 15, 15, 15 }) };

    const prim_count = 8;
    var prim_buf: [prim_count]Primitive = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    const smoke_block: Primitive = .{
        .translate = .init(
            &.{ .rotate = .init(&.{ .box = .init(vec.zero, Vec3{ 165, 330, 165 }, white) }, 15) },
            Vec3{ 265, 0, 295 },
        ),
    };
    const fog_block: Primitive = .{
        .translate = .init(
            &.{ .rotate = .init(&.{ .box = .init(vec.zero, Vec3{ 165, 165, 165 }, white) }, -18) },
            Vec3{ 130, 0, 65 },
        ),
    };

    var scene_primitives: BoundedList(Primitive) = .init(&prim_buf);
    try scene_primitives.list.appendSliceBounded(&.{
        .{ .quad = .init(Vec3{ 555, 0, 0 }, Vec3{ 0, 555, 0 }, Vec3{ 0, 0, 555 }, green) },
        .{ .quad = .init(vec.zero, Vec3{ 0, 555, 0 }, Vec3{ 0, 0, 555 }, red) },
        .{ .quad = .init(Point3{ 343, 554, 332 }, Vec3{ -130, 0, 0 }, Vec3{ 0, 0, -105 }, light) },
        .{ .quad = .init(vec.zero, Vec3{ 555, 0, 0 }, Vec3{ 0, 0, 555 }, white) },
        .{ .quad = .init(Point3{ 555, 555, 555 }, Vec3{ -555, 0, 0 }, Vec3{ 0, 0, -555 }, white) },
        .{ .quad = .init(Point3{ 0, 0, 555 }, Vec3{ 555, 0, 0 }, Vec3{ 0, 555, 0 }, white) },
        .{ .constant_medium = .fromAlbedo(&smoke_block, 0.01, vec.zero) },
        .{ .constant_medium = .fromAlbedo(&fog_block, 0.01, Colour{ 1, 1, 1 }) },
    });
    var bounding_volumes: Bvh = try .build(&node_buf, scene_primitives.list.items, &indices);

    const cam: Camera = .cornell;
    try cam.render(file_writer, &bounding_volumes, scene_primitives.list.items, tex_buf);
}

fn cornellBox(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const red: Material = .{ .lambertian = .fromAlbedo(.{ 0.65, 0.05, 0.05 }) };
    const white: Material = .{ .lambertian = .fromAlbedo(.{ 0.73, 0.73, 0.73 }) };
    const green: Material = .{ .lambertian = .fromAlbedo(.{ 0.12, 0.45, 0.15 }) };
    const light: Material = .{ .diffuse_light = .fromEmittedColour(.{ 15, 15, 15 }) };

    const prim_count = 8;
    var prim_buf: [prim_count]Primitive = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Primitive) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&.{
        .{ .quad = .init(Vec3{ 555, 0, 0 }, Vec3{ 0, 555, 0 }, Vec3{ 0, 0, 555 }, green) },
        .{ .quad = .init(vec.zero, Vec3{ 0, 555, 0 }, Vec3{ 0, 0, 555 }, red) },
        .{ .quad = .init(Point3{ 343, 554, 332 }, Vec3{ -130, 0, 0 }, Vec3{ 0, 0, -105 }, light) },
        .{ .quad = .init(vec.zero, Vec3{ 555, 0, 0 }, Vec3{ 0, 0, 555 }, white) },
        .{ .quad = .init(Point3{ 555, 555, 555 }, Vec3{ -555, 0, 0 }, Vec3{ 0, 0, -555 }, white) },
        .{ .quad = .init(Point3{ 0, 0, 555 }, Vec3{ 555, 0, 0 }, Vec3{ 0, 555, 0 }, white) },
        .{ .translate = .init(
            &.{ .rotate = .init(&.{ .box = .init(vec.zero, Vec3{ 165, 330, 165 }, white) }, 15) },
            .{ 265, 0, 295 },
        ) },
        .{ .translate = .init(
            &.{ .rotate = .init(&.{ .box = .init(vec.zero, Vec3{ 165, 165, 165 }, white) }, -18) },
            .{ 130, 0, 65 },
        ) },
    });
    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .cornell;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn simpleLight(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const rand = Camera.rand_state.random();

    const perlin: Texture = .{ .noise = .init(rand, 4) };
    const diffuse_light: Material = .{ .diffuse_light = .fromEmittedColour(.{ 4, 4, 4 }) };

    const prim_count = 4;
    var prim_buf: [prim_count]Primitive = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Primitive) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&.{
        .{ .sphere = .init(
            Point3{ 0, -1000, 0 },
            1000,
            .{ .lambertian = .{ .tex = perlin } },
        ) },
        .{ .sphere = .init(
            Point3{ 0, 2, 0 },
            2,
            .{ .lambertian = .{ .tex = perlin } },
        ) },
        .{ .sphere = .init(Point3{ 0, 7, 0 }, 2, diffuse_light) },
        .{ .quad = .init(Point3{ 3, 1, -2 }, Vec3{ 2, 0, 0 }, Vec3{ 0, 2, 0 }, diffuse_light) },
    });
    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .simple_light;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn quads(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const left_red: Material = .{ .lambertian = .fromAlbedo(.{ 1, 0.2, 0.2 }) };
    const back_green: Material = .{ .lambertian = .fromAlbedo(.{ 0.2, 1, 0.2 }) };
    const right_blue: Material = .{ .lambertian = .fromAlbedo(.{ 0.2, 0.2, 1 }) };
    const upper_orange: Material = .{ .lambertian = .fromAlbedo(.{ 1, 0.5, 0 }) };
    const lower_teal: Material = .{ .lambertian = .fromAlbedo(.{ 0.2, 0.8, 0.8 }) };

    const prim_count = 5;
    var prim_buf: [prim_count]Primitive = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Primitive) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&.{
        .{ .quad = .init(Point3{ -3, -2, 5 }, Vec3{ 0, 0, -4 }, Vec3{ 0, 4, 0 }, left_red) },
        .{ .quad = .init(Point3{ -2, -2, 0 }, Vec3{ 4, 0, 0 }, Vec3{ 0, 4, 0 }, back_green) },
        .{ .quad = .init(Point3{ 3, -2, 1 }, Vec3{ 0, 0, 4 }, Vec3{ 0, 4, 0 }, right_blue) },
        .{ .quad = .init(Point3{ -2, 3, 1 }, Vec3{ 4, 0, 0 }, Vec3{ 0, 0, 4 }, upper_orange) },
        .{ .quad = .init(Point3{ -2, -3, 5 }, Vec3{ 4, 0, 0 }, Vec3{ 0, 0, -4 }, lower_teal) },
    });
    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .quads;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn perlinSpheres(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const rand = Camera.rand_state.random();

    const perlin: Texture = .{ .noise = .init(rand, 4) };
    const prim_count = 2;
    var prim_buf: [prim_count]Primitive = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Primitive) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&.{
        .{ .sphere = .init(
            Point3{ 0, -1000, 0 },
            1000,
            .{ .lambertian = .{ .tex = perlin } },
        ) },
        .{ .sphere = .init(
            Point3{ 0, 2, 0 },
            2,
            .{ .lambertian = .{ .tex = perlin } },
        ) },
    });

    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .checker;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn earth(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    var earth_texture: Texture = .{ .image = try .init("./images/earthmap.jpg", null) };
    defer earth_texture.deinitImage();

    const prim_count = 1;
    var prim_buf: [prim_count]Primitive = undefined;
    var indices: [prim_count]u32 = undefined;
    var node_buf: [2 * prim_count - 1]BvhNode = undefined;

    var primitives: BoundedList(Primitive) = .init(&prim_buf);
    try primitives.list.appendBounded(.{
        .sphere = .init(
            vec.zero,
            2,
            .{ .lambertian = .{ .tex = earth_texture } }, // Earth surface.
        ),
    });

    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .earth;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn checkeredSpheres(file_writer: *Writer, comptime tex_buf: []const Texture) !void {
    const spheres = [_]Primitive{
        .{ .sphere = .init(
            Point3{ 0, -10, 0 },
            10,
            .{ .lambertian = .{ .tex = tex_buf[tex_buf.len - 1] } },
        ) },
        .{ .sphere = .init(
            Point3{ 0, 10, 0 },
            10,
            .{ .lambertian = .{ .tex = tex_buf[tex_buf.len - 1] } },
        ) },
    };

    var prim_buf: [spheres.len]Primitive = undefined;
    var indices: [spheres.len]u32 = undefined;
    var node_buf: [2 * spheres.len - 1]BvhNode = undefined;

    var primitives: BoundedList(Primitive) = .init(&prim_buf);
    try primitives.list.appendSliceBounded(&spheres);

    var bounding_volumes: Bvh = try .build(&node_buf, primitives.list.items, &indices);

    const cam: Camera = .checker;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
}

fn bouncingSpheres(file_writer: *Writer, comptime max_capacity: usize, comptime tex_buf: []const Texture) !void {
    const rand = Camera.rand_state.random();

    var primitives: BoundedList(Primitive) = try .initCapacity(gpa, max_capacity);
    defer primitives.deinit(gpa);

    const ground: Material = .{
        .lambertian = .{ .tex = tex_buf[tex_buf.len - 1] },
    };

    try primitives.list.appendBounded(.{ .sphere = .init(Point3{ 0, -1000, 0 }, 1000, ground) });

    for (0..22) |i| {
        const a: f64 = @as(f64, @floatFromInt(i)) - 11.0;
        for (0..22) |j| {
            const b: f64 = @as(f64, @floatFromInt(j)) - 11.0;

            const choose_mat = vec.randomFloat(rand);
            const center: Vec3 = .{
                a + 0.9 * vec.randomFloat(rand),
                0.2,
                b + 0.9 * vec.randomFloat(rand),
            };

            const p: Vec3 = center - Point3{ 4, 0.2, 0 };
            var material: Material = undefined;
            if (vec.magnitude(p) > 0.9) {
                if (choose_mat < 0.8) {
                    // Diffuse
                    material = .{
                        .lambertian = .{ .tex = .{ .solid_colour = .{ .albedo = vec.randomVec(rand) * vec.randomVec(rand) } } },
                    };
                    try primitives.list.appendBounded(
                        .{ .sphere = .initMoving(
                            center,
                            center + Vec3{ 0, vec.randomFloatInRange(rand, 0, 0.5), 0 },
                            0.2,
                            material,
                        ) },
                    );
                } else if (choose_mat < 0.95) {
                    // Metal
                    material = .{
                        .metal = .{
                            .albedo = vec.randomVecInRange(rand, 0.5, 1),
                            .fuzz = vec.randomFloatInRange(rand, 0, 0.5),
                        },
                    };
                    try primitives.list.appendBounded(.{ .sphere = .init(center, 0.2, material) });
                } else {
                    // Glass
                    material = .{
                        .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 },
                    };
                    try primitives.list.appendBounded(.{ .sphere = .init(center, 0.2, material) });
                }
            }
        }
    }

    try primitives.list.appendSliceBounded(&.{
        .{ .sphere = .init(
            Point3{ 0, 1, 0 },
            1,
            .{ .dielectric = .{ .albedo = .{ 1, 1, 1 }, .refraction_index = 1.5 } },
        ) },
        .{ .sphere = .init(
            Point3{ -4, 1, 0 },
            1,
            .{ .lambertian = .{ .tex = .{ .solid_colour = .fromRgb(Colour{ 0.4, 0.2, 0.1 }) } } },
        ) },
        .{ .sphere = .init(
            Point3{ 4, 1, 0 },
            1,
            .{ .metal = .{ .albedo = .{ 0.7, 0.6, 0.5 }, .fuzz = 0 } },
        ) },
    });

    var bounding_volumes: Bvh = try .buildAllocating(gpa, primitives.list.items);
    defer bounding_volumes.deinit(gpa);

    const cam: Camera = .bouncing_spheres;
    try cam.render(file_writer, &bounding_volumes, primitives.list.items, tex_buf);
    errdefer {
        primitives.deinit(gpa);
        bounding_volumes.deinit(gpa);
    }
}

const std = @import("std");
const Writer = std.Io.Writer;

const zstbi = @import("zstbi");

const BoundedList = @import("util.zig").BoundedList;
const bvh = @import("bvh.zig");
const Bvh = bvh.Bvh;
const BvhNode = bvh.Node;
const Camera = @import("Camera.zig");
const Material = @import("material.zig").Material;
const Primitive = @import("hittable.zig").Primitive;
const Texture = @import("texture.zig").Texture;
const vec = @import("vec.zig");
const Colour = vec.Colour;
const Point3 = vec.Point3;
const Vec3 = vec.Vec3;

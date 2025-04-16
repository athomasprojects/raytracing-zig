const std = @import("std");
const ppm = @import("ppm.zig");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const ppm_fname = "image02.ppm";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const image_width: usize = 5 * 256;
    const image_height: usize = 5 * 256;
    const path = ppm.IMG_DIR ++ ppm_fname;
    try ppm.createFile(image_width, image_height, path, allocator);
}

test "vec3.create" {
    const v = Vec3.create(1, 2, 3);
    try expect(std.meta.eql(v, @Vector(3, f64){ 1, 2, 3 }));
}

test "vec3.createEmpty" {
    const v = Vec3.createEmpty();
    const expected: @Vector(3, f64) = [_]f64{0} ** 3;
    try expect(std.meta.eql(v, expected));
}

test "vec3.fromScalar" {
    const c: f64 = 5.018972;
    const v = Vec3.fromScalar(c);
    const expected: @Vector(3, f64) = [_]f64{c} ** 3;
    try expect(std.meta.eql(v, expected));
}

test "vec3.loadArr" {
    const arr: [3]f64 = .{ 2, 5, -6.9 };
    const v = Vec3.loadArr(arr);
    try expect(std.meta.eql(v, arr));
}

test "vec3.xyz" {
    const v = Vec3.create(1, 2, 3);
    const x = Vec3.x(v);
    const y = Vec3.y(v);
    const z = Vec3.z(v);
    try expect(x == 1);
    try expect(y == 2);
    try expect(z == 3);
}

test "vec3.divByScalar" {
    var v = Vec3.create(1, 2, 3);
    v = Vec3.divByScalar(v, 2);
    try expect(std.meta.eql(v, [_]f64{ 0.5, 1, 1.5 }));
}

test "vec3.dot" {
    const u = Vec3.create(1, 0, 0);
    const v = Vec3.create(0, 1, 0);

    const a = Vec3.create(1, -1, 1);
    const b = Vec3.create(0.5, 1, 1);
    try expect(Vec3.dot(u, v) == 0);
    try expect(Vec3.dot(a, b) == 0.5);
}

test "vec3.cross" {
    const x = Vec3.create(1, 0, 0);
    const y = Vec3.create(0, 1, 0);
    const z = Vec3.create(0, 0, 1);
    const zero = [_]f64{0} ** 3;
    try expectEqual(Vec3.cross(x, y), z);
    try expectEqual(Vec3.cross(y, z), x);
    try expectEqual(Vec3.cross(z, x), y);
    try expectEqual(Vec3.cross(x, z), -y);
    try expectEqual(Vec3.cross(x, x), zero);
    try expectEqual(Vec3.cross(-x, x), zero);
}

test "vec3.lengthSquared" {
    const v = Vec3.create(1, 1, 1);
    const u = Vec3.create(1, 1, 0);
    const v_lsq = Vec3.lengthSquared(v);
    const u_lsq = Vec3.lengthSquared(u);
    try expect(v_lsq == 3);
    try expect(u_lsq == 2);
}

test "vec3.length" {
    const u = Vec3.create(-1, 0, 0);
    const v = Vec3.create(1, 0, 1);
    const w = Vec3.create(1, 1, 1);
    try expect(Vec3.length(u) == 1);
    try expect(Vec3.length(v) == vec3.sqrt2);
    try expect(Vec3.length(w) == vec3.sqrt3);
}

test "vec3.unitVector" {
    const v = Vec3.create(1, -1, -1);
    const v_norm = Vec3.unitVector(v);
    const norm_vlen = Vec3.length(v_norm);
    try expect(norm_vlen == 1);
}

test "vec3.containsTwo" {
    const u = Vec3.create(1, -1, 0);
    const v = Vec3.create(1, 1, 0);
    const w = Vec3.create(-1, -1, 1);

    try expect(Vec3.containsTwo(@abs(u), 1));
    try expect(Vec3.containsTwo(v, 1));
    try expect(!Vec3.containsTwo(@abs(w), 1));
}

test "vec3.containsThree" {
    const u = Vec3.create(1, -1, 1);
    const v = Vec3.create(1, 1, -1);
    const w = Vec3.create(-1, -1, -1);

    try expect(Vec3.containsThree(@abs(u), 1));
    try expect(Vec3.containsThree(@abs(v), 1));
    try expect(Vec3.containsThree(@abs(w), 1));
}

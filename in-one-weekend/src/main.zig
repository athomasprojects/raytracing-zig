const std = @import("std");
const ppm = @import("ppm.zig");
const vec = @import("vec.zig");
const Ray = @import("ray.zig").Ray;
const Vec3 = vec.Vec3;
const Point3 = vec.Point3;
const Colour = vec.Colour;
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

test "vec.create" {
    const v = Vec3.create(1, 2, 3);
    try expect(std.meta.eql(v, @Vector(3, f64){ 1, 2, 3 }));
}

test "vec.createEmpty" {
    const v = Vec3.createEmpty();
    const expected: @Vector(3, f64) = [_]f64{0} ** 3;
    try expect(std.meta.eql(v, expected));
}

test "vec.fromScalar" {
    const c: f64 = 5.018972;
    const v = Vec3.fromScalar(c);
    const expected: @Vector(3, f64) = [_]f64{c} ** 3;
    try expect(std.meta.eql(v, expected));
}

test "vec.loadArr" {
    const arr: [3]f64 = .{ 2, 5, -6.9 };
    const v = Vec3.loadArr(arr);
    try expect(std.meta.eql(v, arr));
}

test "vec.xyz" {
    const v = Vec3.create(1, 2, 3);
    const x = Vec3.x(v);
    const y = Vec3.y(v);
    const z = Vec3.z(v);
    try expect(x == 1);
    try expect(y == 2);
    try expect(z == 3);
}

test "vec.scale" {
    var v = Vec3.create(1, 2, -3.5);
    v = Vec3.scale(v, 2);
    try expect(std.meta.eql(v, Vec3.create(2, 4, -7)));
}

test "vec.divScalar" {
    var v = Vec3.create(1, 2, 3);
    v = Vec3.divScalar(v, 2);
    try expect(std.meta.eql(v, [_]f64{ 0.5, 1, 1.5 }));
}

test "vec.dot" {
    const u = Vec3.create(1, 0, 0);
    const v = Vec3.create(0, 1, 0);

    const a = Vec3.create(1, -1, 1);
    const b = Vec3.create(0.5, 1, 1);
    try expect(Vec3.dot(u, v) == 0);
    try expect(Vec3.dot(a, b) == 0.5);
}

test "vec.cross" {
    const x = Vec3.create(1, 0, 0);
    const y = Vec3.create(0, 1, 0);
    const z = Vec3.create(0, 0, 1);
    const zero = Vec3.createEmpty();
    try expectEqual(Vec3.cross(x, y), z);
    try expectEqual(Vec3.cross(y, z), x);
    try expectEqual(Vec3.cross(z, x), y);
    try expectEqual(Vec3.cross(x, z), -y);
    try expectEqual(Vec3.cross(x, x), zero);
    try expectEqual(Vec3.cross(-x, x), zero);
}

test "vec.lengthSquared" {
    const u = Vec3.create(1, 1, 0);
    const v = Vec3.create(1, 1, 1);
    const w = Vec3.create(-1, 1, 0);
    const u_l2 = Vec3.lengthSquared(u);
    const v_l2 = Vec3.lengthSquared(v);
    const w_l2 = Vec3.lengthSquared(w);
    try expect(u_l2 == 2);
    try expect(v_l2 == 3);
    try expect(w_l2 == 2);
}

test "vec.length" {
    const u = Vec3.create(-1, 0, 0);
    const v = Vec3.create(1, 0, 1);
    const w = Vec3.create(1, 1, 1);
    try expect(Vec3.length(u) == 1);
    try expect(Vec3.length(v) == vec.sqrt2);
    try expect(Vec3.length(w) == vec.sqrt3);
}

test "vec.normalize" {
    const v = Vec3.create(1, -1, -1);
    const v_norm = Vec3.normalize(v);
    const norm_vlen = Vec3.length(v_norm);
    try expect(norm_vlen == 1);
}

test "vec.hasTwoOnes" {
    const u = Vec3.create(1, -1, 0);
    const v = Vec3.create(1, 1, 0);
    const w = Vec3.create(-1, -1, 1);

    try expect(Vec3.hasTwoOnes(u));
    try expect(Vec3.hasTwoOnes(v));
    try expect(!Vec3.hasTwoOnes(w));
}

test "vec.isAllOnes" {
    const u = Vec3.create(1, -1, 1);
    const v = Vec3.create(1, 1, -1);
    const w = Vec3.create(-1, -1, -1);

    try expect(Vec3.isAllOnes(u));
    try expect(Vec3.isAllOnes(v));
    try expect(Vec3.isAllOnes(w));
}

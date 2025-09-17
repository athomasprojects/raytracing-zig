const std = @import("std");
const hittable = @import("hittable.zig");

const Aabb = @import("AxisAlignedBoundingBox.zig");
const Allocator = std.mem.Allocator;
const HitRecord = hittable.HitRecord;
const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");
const Sphere = hittable.Sphere;

const Link = struct {
    left: ?*Link,
    right: ?*Link,
    bbox: Aabb,

    const empty: Link = .{
        .left = null,
        .right = null,
        .bbox = .empty,
    };
};

const Node = struct {
    data: ?*Sphere = null,
    link: Link,
};

pub const Bvh = struct {
    gpa: Allocator,
    nodes: std.ArrayListUnmanaged(Node),
    root: ?*Link = null,

    pub fn init(gpa: Allocator) Bvh {
        return .{ .gpa = gpa, .nodes = .empty };
    }

    pub fn initCapacity(gpa: Allocator, size: usize) !Bvh {
        return .{
            .gpa = gpa,
            .nodes = try .initCapacity(gpa, size),
        };
    }

    pub fn deinit(self: *Bvh) void {
        self.nodes.deinit(self.gpa);
    }

    pub fn build(self: *Bvh, objects: []*Sphere) !void {
        if (objects.len == 0) {
            self.root = null;
            return;
        }

        self.root = try self.buildRange(objects, 0, objects.len);
    }

    pub fn buildRange(self: *Bvh, objects: []*Sphere, start: usize, end: usize) !*Link {
        const span = end - start;

        if (span == 1) {
            try self.nodes.append(
                self.gpa,
                .{ .data = objects[start], .link = .empty },
            );
            var node = &self.nodes.items[self.nodes.items.len - 1];
            node.link.bbox = objects[start].bbox;
            return &node.link;
        }

        // Build the bounding box for the span of all the source objects in this range.
        var node_bbox: Aabb = .empty;
        for (objects) |obj| node_bbox = .fromEnclosedBoxes(node_bbox, obj.*.bbox);

        // Split over the longest bounding box axis.
        const axis = node_bbox.longestAxis();

        // Sort slice of object pointers along the chosen axis.
        std.mem.sort(
            *Sphere,
            objects[start..end],
            axis,
            struct {
                fn lessThan(ax: usize, a: *Sphere, b: *Sphere) bool {
                    return a.bbox.axisInterval(ax).min < b.bbox.axisInterval(ax).min;
                }
            }.lessThan,
        );

        // Allocate interal node.
        try self.nodes.append(self.gpa, .{ .link = .empty });
        var node = &self.nodes.items[self.nodes.items.len - 1];
        node.link.bbox = node_bbox;

        const mid = start + span / 2;
        node.link.left = try self.buildRange(objects, start, mid);
        node.link.right = try self.buildRange(objects, mid, end);

        return &node.link;
    }

    pub fn hit(self: *Bvh, ray: Ray, ray_interval: Interval) ?HitRecord {
        if (self.root == null) return null;
        return hitNode(self.root.?, ray, ray_interval);
    }
};

pub fn hitNode(link: *Link, ray: Ray, ray_interval: Interval) ?HitRecord {
    if (!link.bbox.hit(ray, ray_interval)) return null;

    const node: *Node = @fieldParentPtr("link", link);

    // Check if the ray hits the sphere.
    if (node.*.data) |sphere| {
        return sphere.*.hit(ray, ray_interval);
    }

    var closest_hit: ?HitRecord = null;
    var closest_so_far = ray_interval.max;

    if (link.left) |left_link| {
        if (hitNode(left_link, ray, .{ .min = ray_interval.min, .max = closest_so_far })) |hit| {
            closest_hit = hit;
            closest_so_far = hit.t;
        }
    }

    if (link.right) |right_link| {
        if (hitNode(right_link, ray, .{ .min = ray_interval.min, .max = closest_so_far })) |hit| {
            closest_hit = hit;
            closest_so_far = hit.t;
        }
    }

    return closest_hit;
}

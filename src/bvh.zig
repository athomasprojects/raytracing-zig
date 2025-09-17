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

    const empty: Link = .{
        .left = null,
        .right = null,
    };
};

const Node = struct {
    data: ?u32 = null,
    bbox: Aabb = .empty,
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

    pub fn build(self: *Bvh, objects: []const Sphere) !void {
        if (objects.len == 0) {
            self.root = null;
            return;
        }

        try self.nodes.ensureTotalCapacity(self.gpa, 2 * objects.len);
        var indices = try self.gpa.alloc(u32, objects.len);
        defer self.gpa.free(indices);

        for (0..indices.len) |idx| indices[idx] = @intCast(idx);

        self.root = try self.buildRange(objects, indices, 0, objects.len);
    }

    pub fn buildRange(self: *Bvh, objects: []const Sphere, indices: []u32, start: usize, end: usize) !*Link {
        const span = end - start;

        if (span == 1) {
            // Append leaf.
            try self.nodes.append(
                self.gpa,
                .{
                    .data = indices[start],
                    .bbox = objects[indices[start]].bbox,
                    .link = .empty,
                },
            );
            return &self.nodes.items[self.nodes.items.len - 1].link;
        }

        // Build the bounding box for the span of all the source objects in this range.
        var node_bbox: Aabb = .empty;
        for (indices[start..end]) |idx| node_bbox = .fromEnclosedBoxes(node_bbox, objects[idx].bbox);

        // Split over the longest bounding box axis.
        const axis = node_bbox.longestAxis();

        // Sort slice of object array indices along the chosen axis.
        const Context = struct { axis: usize, objects: []const Sphere };
        std.mem.sort(
            u32,
            indices[start..end],
            Context{
                .axis = axis,
                .objects = objects,
            },
            struct {
                fn lessThan(ctx: Context, a: u32, b: u32) bool {
                    return ctx.objects[a].bbox.axisInterval(ctx.axis).min < ctx.objects[b].bbox.axisInterval(ctx.axis).min;
                }
            }.lessThan,
        );

        const mid = start + span / 2;
        const left_link = try self.buildRange(objects, indices, start, mid);
        const right_link = try self.buildRange(objects, indices, mid, end);

        // Append interal node.
        try self.nodes.append(self.gpa, .{
            .bbox = node_bbox,
            .link = .{ .left = left_link, .right = right_link },
        });
        return &self.nodes.items[self.nodes.items.len - 1].link;
    }

    pub fn hit(self: *Bvh, objects: []const Sphere, ray: Ray, ray_interval: Interval) ?HitRecord {
        if (self.root == null) return null;
        return hitNode(self.root.?, objects, ray, ray_interval);
    }
};

pub fn hitNode(link: *Link, objects: []const Sphere, ray: Ray, ray_interval: Interval) ?HitRecord {
    const node_ptr: *Node = @fieldParentPtr("link", link);

    if (!node_ptr.bbox.hit(ray, ray_interval)) return null;

    // Check if the ray hits the sphere.
    if (node_ptr.data) |idx| {
        return objects[idx].hit(ray, ray_interval);
    }

    var closest_hit: ?HitRecord = null;
    var closest_so_far = ray_interval.max;

    const link_fields = @typeInfo(Link).@"struct".fields;
    inline for (link_fields) |link_field| {
        const child_link: ?*Link = @field(link.*, link_field.name);
        if (child_link) |child| {
            if (hitNode(child, objects, ray, .{ .min = ray_interval.min, .max = closest_so_far })) |hit| {
                closest_hit = hit;
                closest_so_far = hit.t;
            }
        }
    }
    return closest_hit;
}

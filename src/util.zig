/// A thin wrapper around `std.ArrayListUnmanaged` for creating generic bounded array lists.
pub fn BoundedList(comptime T: type) type {
    return struct {
        buf: []T,
        list: ArrayList(T),

        const Self = @This();

        /// Initialize with externally-managed memory. The buffer determines
        /// the capacity, and the length is set to zero.
        pub fn init(buf: []T) Self {
            return .{ .buf = buf, .list = .initBuffer(buf) };
        }

        /// Initialize with externally-managed memory.
        ///
        /// `capacity` determines the allocated buffer size.
        pub fn initCapacity(gpa: Allocator, capacity: usize) !Self {
            const buf = try gpa.alloc(T, capacity);
            return .{ .buf = buf, .list = .initBuffer(buf) };
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            gpa.free(self.buf);
            self.buf = &.{};
            self.list = undefined;
        }
    };
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const std = @import("std");
const log = std.log;
const mem = std.mem;
const Allocator = mem.Allocator;

const String = @This();
const Self = @This();

allocator: Allocator,
len: usize,
data: ?[]u8,

pub fn init(allocator: Allocator) String {
    return .{
        .allocator = allocator,
        .len = 0,
        .data = null,
    };
}

pub fn from(allocator: Allocator, str: []const u8) !String {
    var string = init(allocator);
    string.data = try string.allocator.dupe(u8, str);
    string.len = str.len;

    return string;
}

pub fn iterator(self: Self) Iterator {
    return .{
        .data = self.data.?,
        .len = self.len,
    };
}

pub fn concat(self: *Self, other: []const u8) !void {
    // Could pre-allocate some memory to make it more eficient
    if (self.data) |data| {
        self.data = try self.allocator.realloc(data, self.len + other.len);
    } else {
        self.data = try self.allocator.alloc(u8, other.len);
    }

    @memcpy(self.data.?[self.len..], other);

    self.len += other.len;
}

pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    if (self.data) |data| {
        try writer.print("{s}", .{data});
    }
}

pub fn deinit(self: Self) void {
    if (self.data) |data| {
        self.allocator.free(data);
    }
}

pub const Iterator = struct {
    data: []u8,
    len: usize,
    index: usize = 0,

    pub fn next(it: *Iterator) ?u8 {
        if (it.index >= it.len) {
            return null;
        }

        const char: u8 = it.data[it.index];
        it.index += 1;
        return char;
    }
};

const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "init" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var string = String.init(allocator);
    defer string.deinit();

    try expectEqual(0, string.len);
}

test "from" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const str = "Hello world!";

    const string = try String.from(allocator, str);
    defer string.deinit();

    try expectEqual(str.len, string.len);

    const output_buf = try std.fmt.allocPrint(allocator, "{s}", .{string});

    try expect(mem.eql(u8, output_buf, str));
}

test "concat on an empty string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const str = "second half";

    var string = String.init(allocator);
    try string.concat(str);
    defer string.deinit();

    try expectEqual(str.len, string.len);

    const output_buf = try std.fmt.allocPrint(allocator, "{s}", .{string});

    try expect(mem.eql(u8, output_buf, str));
}

test "concat" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const str1 = "the";
    const str2 = "re wa";
    const str3 = "s data be";
    const str4 = "fore";

    var string = try String.from(allocator, str1);
    try string.concat(str2);
    try string.concat(str3);
    try string.concat(str4);
    defer string.deinit();

    try expectEqual(str1.len + str2.len + str3.len + str4.len, string.len);

    const output_buf = try std.fmt.allocPrint(allocator, "{s}", .{string});

    try expect(mem.eql(u8, output_buf, "there was data before"));
}

test "iterator" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const str = "World";

    const string = try String.from(allocator, str);
    defer string.deinit();

    var iter = string.iterator();
    try expectEqual('W', iter.next().?);
    try expectEqual('o', iter.next().?);
    try expectEqual('r', iter.next().?);
    try expectEqual('l', iter.next().?);
    try expectEqual('d', iter.next().?);
    try expectEqual(null, iter.next());
}

test "deinit" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const string = try String.from(allocator, "Should entirely free this one");
    string.deinit();

    const deinit_status = gpa.deinit();
    try expect(deinit_status == .ok);
}

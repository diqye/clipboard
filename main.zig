const std = @import("std");
const argsParser = @import("args");

extern fn getClipboardText() ?[*:0]const u8;
extern fn setClipboardText(text: [*:0]const u8) void;

test "mytest" {
    const allocator = std.heap.page_allocator;
    const A = struct {
        allocator : @TypeOf(allocator),

        const Self = @This();
        fn call(self: *Self, parameter: [] const u8) ![] const u8 {
            const len_str = try std.fmt.allocPrint(self.allocator, "{s}{d}", .{parameter,parameter.len});
            // defer self.allocator.free(len_str);
            // const result = try self.allocator.alloc(u8, parameter.len + len_str.len);
            // @memcpy(result[0..parameter.len], parameter);
            // @memcpy(result[parameter.len..], len_str);
            // return result;
            return len_str;
        }
    };
    var a = A{.allocator = allocator};
    const new_str = try a.call("hello");
    defer allocator.free(new_str);
    std.debug.print("new_str={s}\n", .{new_str});
}

fn errHanding(err: argsParser.Error) anyerror!void {
    std.debug.print("My error: {}",.{err});
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const options = argsParser.parseForCurrentProcess(struct {
        // This declares long options for double hyphen
        output: ?[]const u8 = null,
        @"with-offset": bool = false,
        @"with-hexdump": bool = false,
        @"intermix-source": bool = false,
        numberOfBytes: ?i32 = null,
        signed_number: ?i64 = null,
        unsigned_number: ?u64 = null,
        mode: enum { default, special, slow, fast } = .default,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .S = "intermix-source",
            .b = "with-hexdump",
            .O = "with-offset",
            .o = "output",
        };
    }, allocator, .{
        .forward = errHanding,
    }) catch |e| return e;
    defer options.deinit();

    std.debug.print("executable name: {?s}\n", .{options.executable_name});

    std.debug.print("parsed options:\n", .{});
    inline for (std.meta.fields(@TypeOf(options.options))) |fld| {
        std.debug.print("\t{s} = {any}\n", .{
            fld.name,
            @field(options.options, fld.name),
        });
    }

    std.debug.print("parsed positionals:\n", .{});
    for (options.positionals) |arg| {
        std.debug.print("\t'{s}'\n", .{arg});
    }
}

fn printClipboardText() void {
    const text = getClipboardText();
    if (text) |str| {
        const len = std.mem.len(str);
        std.debug.print("{s}\n", .{str[0..len]});
    } else {
        std.debug.print("No text\n", .{});
    }
}

fn writeClipboardText(text: []const u8) !void {
    const allocator = std.heap.page_allocator;
    var buf = try allocator.alloc(u8, text.len + 1);
    defer allocator.free(buf);
    @memcpy(buf[0..text.len], text);
    buf[text.len] = 0;
    setClipboardText(@ptrCast(buf.ptr));
}

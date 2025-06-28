const std = @import("std");
const argsParser = @import("args");

extern fn getClipboardText() ?[*:0]const u8;
extern fn setClipboardText(text: [*:0]const u8) void;

const Entry = struct {
    data: std.StringArrayHashMap([] const u8),
    file: std.fs.File,
    arena: std.heap.ArenaAllocator,


    const Self = @This();
    pub fn init(a:std.mem.Allocator)!Self {
        const home = try std.process.getEnvVarOwned(a, "HOME");
        defer a.free(home);
        // const app_path = try std.fs.getAppDataDir(a, "d-clipboard/.bin");
        // defer a.free(app_path);
        const app_path = try std.fs.path.join(a, &.{home,".config","clipboard",".b"});
        std.fs.makeDirAbsolute(std.fs.path.dirname(app_path).?) catch {};
        return .{
            .arena = std.heap.ArenaAllocator.init(a),
            .file = std.fs.openFileAbsolute(app_path, .{ 
                .mode = .read_write
            }) catch |err| switch (err) {
                error.FileNotFound => try std.fs.createFileAbsolute(app_path, .{ .truncate = true}) ,
                else => return err,
            },
            .data = .init(a),
        };
    }

    pub fn deinit(self:*Self) void {
        self.file.close();
        self.data.deinit();
        self.arena.deinit();
    }

    fn readAll(self: *Self) !void {
        while (try self.readData()) |data| {
            try self.data.put(data.@"0", data.@"1");
        }
    }
    /// 读取数据赋值给self.data,回收原有data的内存
    fn readData(self: *Self) !?struct {[]u8,[]u8} {
        const end = try self.file.getEndPos();
        const current = try self.file.getPos();
        const allocator = self.arena.allocator();
        if(current == end) {
            return null;
        }
        var name:[]  u8 = undefined;
        var value:[] u8 = undefined;
        {
            var buffer : [2]u8  = undefined;
            _ = try self.file.readAll(&buffer);
            for (&buffer) |*byte| {
                byte.* ^= 0x88;
            }
            const len : u16 = std.mem.readPackedInt(u16, &buffer, 0, .big);
            name = try allocator.alloc(u8, len);
            _ = try self.file.readAll(name);
            for (name) |*byte| {
                byte.* ^= 0x88;
            }
        }
        {
            var buffer : [2]u8  = undefined;
            _ = try self.file.readAll(&buffer);
            for (&buffer) |*byte| {
                byte.* ^= 0x88;
            }
            const len : u16 = std.mem.readPackedInt(u16, &buffer, 0, .big);
            value = try allocator.alloc(u8, len);
            _ = try self.file.readAll(value);
            for (value) |*byte| {
                byte.* ^= 0x88;
            }
        }
        return .{name,value};
    }
    /// 写入文件
    pub fn writeAll(self:*Self)!void {
        const allocator = self.arena.allocator();
        try self.file.setEndPos(0);
        try self.file.seekFromEnd(0);
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            const key = entry.key_ptr.*;
            const value = entry.value_ptr.*;
            const name_len = key.len;
            const value_len = value.len;
            const total = name_len + value_len + 4;
            var buffer = try allocator.alloc(u8, total);
            defer allocator.free(buffer);
            var name_len_buffer: [2] u8 = undefined;
            std.mem.writePackedInt(u16, &name_len_buffer, 0, @intCast(name_len), .big);
            var value_len_buffer: [2] u8 = undefined;
            std.mem.writePackedInt(u16, &value_len_buffer, 0, @intCast(value_len), .big);
            @memcpy(buffer[0..2], &name_len_buffer);
            @memcpy(buffer[2..2+name_len], key);
            @memcpy(buffer[2+name_len..2+2+name_len], &value_len_buffer);
            @memcpy(buffer[2+2+name_len..], value);
            for(buffer)|*byte| {
                byte.* ^= 0x88;
            }
            try self.file.writeAll(buffer);
        }
     }

};

test "only one" {
    const act = std.testing.allocator;
    _ = act;
    std.debug.print("{}", .{0xff ^ 0x88});
}
fn errHanding(err: argsParser.Error) anyerror!void {
    std.debug.print("{}",.{err});
}
fn print(executable_name: ?[:0]const u8) void {
    const help = \\{?s}:
    \\ --print  [-p]        打印当前剪切板文本
    \\ --write  [-w] text   写入内容到剪切板
    \\ --key    [-k] key    读取已经存储到本地的内容到剪切板
    \\ --value  [-v] text   存储到本地和--key同时使用
    \\ --delete [-d]        删除key和--key同时使用
    \\ --list   [-l]        列出所有的key
    \\ --help   [-h]        打印帮助信息
    \\
    ;
    std.debug.print(help, .{executable_name});
    std.process.exit(0);
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const options = argsParser.parseForCurrentProcess(struct {
        print: bool = false,
        write: [] const u8 = "",
        key: [] const u8 = "",
        value: [] const u8 = "",
        delete: bool = false,
        /// 列出所有的 key
        list: bool = false,
        help: bool = false,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .p = "print",
            .w = "write",
            .k = "key",
            .v = "value",
            .d = "delete",
            .l = "list",
            .h = "help",
        };
    }, allocator, .{
        .forward = errHanding,
    }) catch {};
    defer options.deinit();


    if(options.options.list) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try entry.readAll();
        const iterator = entry.data.iterator();
        for (iterator.keys[0..iterator.len]) |item| {
            std.debug.print("{s}\n", .{item});
        }
    } else if(options.options.print){
        const text = getClipboardText() orelse "";
        std.debug.print("{s}\n", .{text});
    } else if(options.options.write.len != 0) {
        const c_str = try allocator.dupeZ(u8, options.options.write);
        defer allocator.free(c_str);
        setClipboardText(c_str.ptr);
    } else if(options.options.key.len != 0) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try entry.readAll();

        if(options.options.value.len != 0) {
            try entry.data.put(options.options.key, options.options.value);
        } else if(options.options.delete) {
            _ = entry.data.orderedRemove(options.options.key);
        } else {
            const text = entry.data.get(options.options.key) orelse @panic("没有这个key");
            const c_text = try allocator.dupeZ(u8, text);
            defer allocator.free(c_text);
            setClipboardText(c_text);
        }
        
        try entry.writeAll();
    } else if(options.options.help) {
        print(options.executable_name);
    } else {
        print(options.executable_name);
    }
}



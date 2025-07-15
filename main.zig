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


fn errHanding(err: argsParser.Error) anyerror!void {
    std.debug.print("{}\n",.{err});
}
fn printHelp(executable_name: ?[:0]const u8) void {
    const help = \\{?s}:
    \\ --print  [-p]        打印当前剪切板文本
    \\ --write  [-w] text   写入内容到剪切板
    \\ --write_pipe         通过管道进来的内容写入剪切板
    \\ --key    [-k] key    读取已经存储到本地的内容到剪切板
    \\ --key_s  [-s] seq    通过序号读取已经存储到本地的内容到剪切板
    \\ --value  [-v] text   存储到本地和--key同时使用
    \\ --paste              将剪切板的内容存储到本地,和 --key 一起使用
    \\ --delete [-d]        删除key和--key同时使用
    \\ --list   [-l]        列出所有的key
    \\ --help   [-h]        打印帮助信息
    \\ --push               将数据文件推送到gitee上,需要环境变量:
    \\                      $gitee_clipboard_token=私有令牌
    \\                      $gitee_store_path=https://gitee.com/api/v5/repos/diqye/store/contents/{{path}}
    \\                      其中 {{path}} 为占位符，程序会自动生成名字替换它。
    \\
    ;
    print(help, .{executable_name});
    std.process.exit(0);
}
fn getDays() ![9]u8 {
    // now secends 
    const now : u32 = @intCast(std.time.timestamp() - 1751263280);
    const days : u32 = @divTrunc(now, std.time.s_per_day);
    var result : [9]u8 = undefined;
    _ = try std.fmt.bufPrint(&result, "{d:0>5}days", .{days});
    return result;

}
test getDays{
    const json_str = \\ {"content":{"name":"00000daysago.b","path":"00000daysago.b","size":123,"sha":"3f1b2fb499b1ed5b3f94b0ba1abea6f2c50966fd","type":"file","url":"https://gitee.com/api/v5/repos/diqye/store/contents/00000daysago.b","html_url":"https://gitee.com/diqye/store/blob/master/00000daysago.b","download_url":"https://gitee.com/diqye/store/raw/master/00000daysago.b","_links":{"self":"https://gitee.com/api/v5/repos/diqye/store/contents/00000daysago.b","html":"https://gitee.com/diqye/store/blob/master/00000daysago.b"}},"commit":{"sha":"fcf4f5927ec2d30905f855a934402d5b8364b698","author":{"name":"Rezero","email":"262666212@qq.com","date":"2025-06-30T06:39:43+00:00"},"committer":{"name":"Gitee","email":"noreply@gitee.com","date":"2025-06-30T06:39:43+00:00"},"message":"commit aotocally by clipboard","tree":{"sha":"0e5b430ac05387b6611ba56d438bcceb21733812","url":"https://gitee.com/api/v5/repos/diqye/store/git/trees/0e5b430ac05387b6611ba56d438bcceb21733812"},"parents":[{"sha":"843b776f5832d735d294e8b221a5d636935b9623","url":"https://gitee.com/api/v5/repos/diqye/store/commits/843b776f5832d735d294e8b221a5d636935b9623"}]}}
    \\
    ;
    const start = std.mem.indexOf(u8, json_str,"html_url\":\"").? + 11;
    const start_str = json_str[start..];
    const end = std.mem.indexOfScalar(u8, start_str, '"').?;
    std.debug.print("{s}\n", .{start_str[0..end]});
}
/// 将文件推送到gitee
fn push(file: std.fs.File) !void {
    const allocator = std.heap.page_allocator;
    // base64 编码
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    try std.base64.standard.Encoder.encodeFromReaderToWriter(list.writer(), file.reader());
    // http
    var client = std.http.Client{
        .allocator = allocator,
    };
    defer client.deinit();
    // token
    const token = try std.process.getEnvVarOwned(allocator, "gitee_clipboard_token");
    defer allocator.free(token);

    // gitee path
    const gitee_store_path= try std.process.getEnvVarOwned(allocator, "gitee_store_path");
    defer allocator.free(gitee_store_path);

    // path
    const name = try getDays();
    const path = try std.fmt.allocPrint(allocator, "{s}.b", .{&name});
    defer allocator.free(path);

    const gitee_path = try std.mem.replaceOwned(u8, allocator, gitee_store_path, "{path}", path);
    defer allocator.free(gitee_path);

    
    // payload
    var obj = std.json.ObjectMap.init(allocator);
    defer obj.deinit();
    try obj.put("access_token", .{.string = token});
    try obj.put("content", .{.string = list.items});
    try obj.put("message", .{.string = "commit aotocally by clipboard"});
    const payload = try std.json.stringifyAlloc(allocator, std.json.Value{
        .object = obj,
    }, .{});
    defer allocator.free(payload);
    // resposne
    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = gitee_path},
        .method = .POST,
        .payload = payload,
        .headers = .{
            .content_type = .{ .override =  "application/json" }
        },
        .response_storage = .{ .dynamic = &response },
    });
    const start = std.mem.indexOf(u8, response.items,"html_url\":\"");
    if(start)|start_index| {
        const start_str = response.items[start_index + 11 ..];
        const end = std.mem.indexOfScalar(u8, start_str, '"').?;
        print("Success {} {s}\n", .{result.status,start_str[0..end]});
    } else {
        std.debug.print("Failed {} {s}\n", .{result.status,response.items});
    }

}
fn print(comptime fmt: [] const u8,args:anytype) void {
    std.io.getStdOut().writer().print(fmt, args) catch {
        std.debug.print("stdout print error", .{});
    };
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const options = argsParser.parseForCurrentProcess(struct {
        print: bool = false,
        write: ?[] const u8 = "",
        write_pipe: bool = false,
        key: [] const u8 = "",
        key_s: u16 = 0,
        value: [] const u8 = "",
        delete: bool = false,
        /// 列出所有的 key
        list: bool = false,
        help: bool = false,
        push: bool = false,
        paste: bool = false,

        // This declares short-hand options for single hyphen
        pub const shorthands = .{
            .p = "print",
            .w = "write",
            .k = "key",
            .s = "key_s",
            .v = "value",
            .d = "delete",
            .l = "list",
            .h = "help",
        };
    }, allocator, .{
        .forward = errHanding,
    }) catch {
        std.process.exit(0);
    };
    defer options.deinit();


    if(options.options.list) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try entry.readAll();
        const iterator = entry.data.iterator();
        print("-----+----------------------------+\n", .{});
        for (iterator.keys[0..iterator.len],1..) |item,i| {
            print("|{: >3} | {s: <27}|\n", .{i,item});
            print("-----+----------------------------+\n", .{});
        }
    } else if(options.options.print){
        const text = getClipboardText() orelse "";
        print("{s}\n", .{text});
    } else if(options.options.write_pipe){
        const reader = std.io.getStdIn().reader();
        // max_size = 1G
        const text = try reader.readAllAlloc(allocator, 1024 * 1024 * 1024);
        defer allocator.free(text);
        const text_c = try allocator.dupeZ(u8, text);
        defer allocator.free(text_c);
        setClipboardText(text_c);
    } else if(options.options.write) |write_val| {
        const c_str = try allocator.dupeZ(u8, write_val);
        defer allocator.free(c_str);
        setClipboardText(c_str);
    } else if(options.options.key.len != 0) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try entry.readAll();

        if(options.options.value.len != 0) {
            try entry.data.put(options.options.key, options.options.value);
        } else if(options.options.delete) {
            _ = entry.data.orderedRemove(options.options.key);
        } else if(options.options.paste) {
            const text_c = getClipboardText() orelse "";
            const text: [] const u8 = std.mem.span(text_c);
            try entry.data.put(options.options.key, text);
        } else {
            const text = entry.data.get(options.options.key) orelse @panic("没有这个key");
            const c_text = try allocator.dupeZ(u8, text);
            defer allocator.free(c_text);
            setClipboardText(c_text);
        }
        
        try entry.writeAll();
    } else if(options.options.key_s != 0) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try entry.readAll();
        const values = entry.data.values();
        if(options.options.key_s > values.len or options.options.key_s < 1) {
            std.debug.print("Invalid value '{}' for option --key_s", .{options.options.key_s});
            std.process.exit(0);
        }
        const text = values[options.options.key_s - 1];
        const c_text = try allocator.dupeZ(u8, text);
        defer allocator.free(c_text);
        setClipboardText(c_text);
    } else if(options.options.help) {
        printHelp(options.executable_name);
    } else if(options.options.push) {
        var entry = try Entry.init(allocator);
        defer entry.deinit();
        try push(entry.file);        
    } else {
        printHelp(options.executable_name);
    }
}



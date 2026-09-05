extends RefCounted

static func run(source_path: String, output_path: String) -> void:
    var source = FileAccess.get_file_as_string(source_path)
    var parsed = JSON.parse_string(source)
    if parsed == null or parsed.provinces.size() != 710:
        push_error("源数据不是 710 个省份")
        return
    DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
    var file = FileAccess.open(output_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(parsed))
    print("已导入 710 个省份")


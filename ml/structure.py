# from pathlib import Path

# # Root folder
# ROOT = Path(r"D:\Projects\oras")

# # File type categories
# FILE_TYPES = {
#     "Images": {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tif", ".tiff", ".webp"},
#     "Videos": {".mp4", ".avi", ".mov", ".mkv", ".wmv", ".flv", ".mpeg"},
#     "Audio": {".mp3", ".wav", ".aac", ".flac", ".ogg"},
#     "CSV": {".csv"},
#     "Excel": {".xls", ".xlsx"},
#     "Python": {".py", ".ipynb"},
#     "Text": {".txt", ".md"},
#     "JSON": {".json"},
#     "XML": {".xml"},
#     "Archives": {".zip", ".rar", ".7z", ".tar", ".gz"},
#     "Models": {".pth", ".pt", ".onnx", ".h5"},
# }


# def get_file_type(path):
#     ext = path.suffix.lower()
#     for category, exts in FILE_TYPES.items():
#         if ext in exts:
#             return category
#     return "Other"


# def print_tree(folder, prefix=""):
#     items = sorted(folder.iterdir(), key=lambda x: (x.is_file(), x.name.lower()))

#     for i, item in enumerate(items):
#         connector = "└── " if i == len(items) - 1 else "├── "

#         if item.is_dir():
#             print(f"{prefix}{connector}📁 {item.name}/")
#             extension = "    " if i == len(items) - 1 else "│   "
#             print_tree(item, prefix + extension)
#         else:
#             size_kb = item.stat().st_size / 1024
#             file_type = get_file_type(item)
#             print(f"{prefix}{connector}📄 {item.name} [{file_type}, {size_kb:.1f} KB]")


# print(f"\nFolder Architecture: {ROOT}\n")
# print(f"📁 {ROOT.name}/")
# print_tree(ROOT)

from pathlib import Path

ROOT = Path(r"D:\Projects\oras\app\lib")
OUTPUT = ROOT / "lib_folder_structure.txt"

with open(OUTPUT, "w", encoding="utf-8") as f:

    def write_tree(folder, prefix=""):
        items = sorted(folder.iterdir(), key=lambda x: (x.is_file(), x.name.lower()))

        for i, item in enumerate(items):
            connector = "└── " if i == len(items)-1 else "├── "

            if item.is_dir():
                f.write(f"{prefix}{connector}{item.name}/\n")
                extension = "    " if i == len(items)-1 else "│   "
                write_tree(item, prefix + extension)
            else:
                f.write(f"{prefix}{connector}{item.name}\n")

    f.write(f"{ROOT.name}/\n")
    write_tree(ROOT)

print(f"Saved to {OUTPUT}")
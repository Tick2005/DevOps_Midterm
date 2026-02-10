# DevOps_Midterm

## Branch Management

### Xóa nhánh (Delete Branches)

Để xóa các nhánh không cần thiết trong repository:

1. **Xem hướng dẫn chi tiết**: Đọc file [delete-branch-guide.md](./delete-branch-guide.md)
2. **Sử dụng script tự động**: Chạy script `./delete-branch.sh <tên-nhánh>`

#### Ví dụ xóa nhánh

```bash
# Xóa nhánh copilot/vscode-mlgl0w5b-8mwx
./delete-branch.sh copilot/vscode-mlgl0w5b-8mwx
```

hoặc dùng lệnh git trực tiếp:

```bash
# Xóa nhánh remote
git push origin --delete copilot/vscode-mlgl0w5b-8mwx

# Xóa nhánh local (nếu có)
git branch -D copilot/vscode-mlgl0w5b-8mwx
```

---
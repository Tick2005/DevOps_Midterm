# Hướng dẫn xóa nhánh (Branch Deletion Guide)

## Cách xóa nhánh trên GitHub

### 1. Xóa nhánh local (Local Branch)

Để xóa một nhánh local trên máy tính của bạn:

```bash
# Xóa nhánh đã merge
git branch -d <tên-nhánh>

# Xóa nhánh chưa merge (force delete)
git branch -D <tên-nhánh>
```

### 2. Xóa nhánh remote (Remote Branch)

Để xóa một nhánh đã được push lên GitHub:

```bash
# Cách 1: Sử dụng git push
git push origin --delete <tên-nhánh>

# Cách 2: Sử dụng cú pháp rút gọn
git push origin :<tên-nhánh>
```

### 3. Xóa nhánh qua GitHub Web Interface

1. Truy cập repository trên GitHub
2. Nhấp vào tab "Branches"
3. Tìm nhánh cần xóa
4. Nhấp vào biểu tượng thùng rác (🗑️) bên cạnh tên nhánh

### 4. Xóa nhánh bằng GitHub CLI

Nếu bạn đã cài đặt GitHub CLI (`gh`):

```bash
gh api repos/{owner}/{repo}/git/refs/heads/{branch} -X DELETE
```

## Ví dụ cụ thể

Để xóa nhánh `copilot/vscode-mlgl0w5b-8mwx`:

```bash
# Xóa từ remote (GitHub)
git push origin --delete copilot/vscode-mlgl0w5b-8mwx

# Xóa từ local (nếu có)
git branch -D copilot/vscode-mlgl0w5b-8mwx
```

## Lưu ý quan trọng

- ⚠️ **Không thể xóa nhánh đang được bảo vệ (protected branch)**
- ⚠️ **Không thể xóa nhánh đang checkout hiện tại**
- ✅ Nên xóa nhánh sau khi đã merge PR thành công
- ✅ Kiểm tra kỹ trước khi xóa để không mất code quan trọng

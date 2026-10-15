# BÀI 4: TỰ ĐỘNG TRIỂN KHAI ỨNG DỤNG SPRING BOOT (CONTAINER) LÊN VPS TỪ XA QUA SSH

- **Môn học:** DevOps / CI-CD
- **Bài thực hành:** Bài 4 - Session 12
- **Mục tiêu:**
  - Tự động hóa quá trình đóng gói và đẩy Docker Image lên GitHub Container Registry (GHCR).
  - Tự động kết nối tới máy chủ VPS từ xa qua giao thức SSH an toàn bằng `appleboy/ssh-action@v1.0.3`.
  - Thực thi các câu lệnh kéo Docker Image mới nhất và khởi chạy lại container Spring Boot trên VPS.
  - Kiểm tra trạng thái ứng dụng qua endpoint Spring Boot Actuator (`/actuator/health`).
- **Đường dẫn gợi ý:** `homework/session_12/ex4/`

---

## 1. Cấu trúc thư mục dự án

```text
PTIT_CNTT1_IT209_Session12_Bai04/
├── .github/
│   └── workflows/
│       └── deploy-vps.yml         # Kịch bản Build Docker Image và Deploy lên VPS qua SSH
├── Dockerfile                     # Multi-stage Dockerfile tối ưu kích thước
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── src/
│   ├── main/
│   │   ├── java/com/example/demo/
│   │   │   ├── DemoApplication.java
│   │   │   └── HelloController.java
│   │   └── resources/
│   │       └── application.properties # Cấu hình Spring Boot Actuator
│   └── test/java/com/example/demo/
│       └── DemoApplicationTests.java
├── image/                         # Thư mục lưu ảnh minh chứng log SSH Deploy
├── .gitignore
├── build.gradle                   # Thêm dependency spring-boot-starter-actuator
├── gradlew
├── gradlew.bat
├── settings.gradle
└── README.md                      # Báo cáo chi tiết và hướng dẫn triển khai
```

---

## 2. Chi tiết kịch bản GitHub Actions Workflow (`.github/workflows/deploy-vps.yml`)

Kịch bản gồm 2 Job liên kết tuần tự: Job `deploy-vps` nối sau Job `build-image`:

```yaml
name: Deploy to VPS via SSH

on:
  push:
    branches: [ "main" ]

jobs:
  build-image:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Log in to GitHub Container Registry (GHCR)
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=latest
            type=sha

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy-vps:
    name: Deploy to Remote VPS via SSH
    runs-on: ubuntu-latest
    needs: build-image

    steps:
      - name: Execute deployment commands on VPS via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_KEY }}
          port: ${{ secrets.SSH_PORT || 22 }}
          script: |
            REPO_LOWER=$(echo "${{ github.repository }}" | tr '[:upper:]' '[:lower:]')
            IMAGE_NAME="ghcr.io/${REPO_LOWER}:latest"

            echo "=== 1. Đăng nhập GHCR trên VPS ==="
            echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u "${{ github.actor }}" --password-stdin

            echo "=== 2. Kéo Image mới nhất từ GHCR ==="
            docker pull "$IMAGE_NAME"

            echo "=== 3. Dừng và xóa Container cũ (nếu có) ==="
            docker stop app || true
            docker rm app || true

            echo "=== 4. Khởi chạy Container mới trên cổng 8080 ==="
            docker run -d \
              --name app \
              --restart unless-stopped \
              -p 8080:8080 \
              "$IMAGE_NAME"

            echo "=== 5. Kiểm tra danh sách container đang chạy ==="
            docker ps --filter "name=app"
```

### Phân tích và giải thích các thành phần:

1. **Job `build-image`**:
   - Sử dụng `docker/build-push-action@v5` để biên dịch mã nguồn và đóng gói thành Docker Image.
   - Gắn nhãn tag `:latest` và đẩy thẳng lên GHCR (`ghcr.io`).

2. **Job `deploy-vps` nối sau Job `build-image` (`needs: build-image`)**:
   - Chỉ bắt đầu chạy khi Image mới nhất đã được build và đẩy thành công lên GHCR.
   - Sử dụng action `appleboy/ssh-action@v1.0.3` kết nối bảo mật đến VPS thông qua SSH Key.

3. **Các câu lệnh triển khai trên VPS**:
   - `docker login ghcr.io`: Đăng nhập GHCR ngay trên VPS sử dụng biến `${{ secrets.GITHUB_TOKEN }}` để có quyền kéo image (ngay cả khi package ở chế độ private).
   - `docker pull ghcr.io/...:latest`: Tải bản image mới nhất vừa được build.
   - `docker stop app || true && docker rm app || true`: Dừng và xóa container cũ đang chạy để tránh xung đột cổng hoặc tên container.
   - `docker run -d --name app -p 8080:8080 ...`: Chạy container mới ở chế độ nền (detached mode), map cổng 8080 của VPS vào container và tự động khởi động lại nếu có lỗi (`--restart unless-stopped`).

---

## 3. Hướng dẫn cấu hình GitHub Secrets (Bạn thực hiện trên GitHub)

Truy cập repository GitHub -> **Settings** -> **Secrets and variables** -> **Actions** -> Nhấp **New repository secret** để thêm các biến sau:

| Tên Secret | Ý nghĩa | Ví dụ giá trị |
| :--- | :--- | :--- |
| `SSH_HOST` | Địa chỉ IP công khai hoặc tên miền của máy chủ VPS | `103.123.45.67` |
| `SSH_USER` | Tên người dùng SSH trên VPS | `ubuntu` hoặc `root` |
| `SSH_KEY` | Toàn bộ nội dung Private Key (OpenSSH format) để đăng nhập vào VPS | `-----BEGIN OPENSSH PRIVATE KEY----- ... -----END OPENSSH PRIVATE KEY-----` |
| `SSH_PORT` *(tùy chọn)* | Cổng SSH của VPS (mặc định là 22 nếu không khai báo) | `22` |

> **Lưu ý trên VPS:**
> 1. Đảm bảo user SSH đã thuộc nhóm `docker`: `sudo usermod -aG docker $USER` và đăng xuất đăng nhập lại.
> 2. Mở cổng 8080 trên firewall của VPS: `sudo ufw allow 8080/tcp`.

---

## 4. Hướng dẫn kiểm tra và nộp bài (Bạn tự thực hiện)

### Bước 1: Khởi tạo và đẩy code lên GitHub
```bash
cd d:\Documents\DEVOPS\Session12\PTIT_CNTT1_IT209_Session12_Bai04
git init
git add .
git commit -m "feat: setup automated SSH deployment to VPS with Docker and GHCR"
git branch -M main
git remote add origin <URL_REPOSITORY_CỦA_BẠN>
git push -u origin main
```

### Bước 2: Theo dõi log thực thi trên GitHub Actions
1. Vào tab **Actions** trên GitHub repository.
2. Nhấp vào lần chạy workflow **Deploy to VPS via SSH**.
3. Quan sát:
   - Job **build-image** biên dịch và push image thành công.
   - Job **deploy-vps** kết nối SSH tới VPS, kéo image và khởi chạy container.
4. Mở chi tiết bước **Execute deployment commands on VPS via SSH** để xem log output của Docker.
5. **Chụp ảnh màn hình log kết quả SSH Deploy** hiển thị trạng thái `docker ps` thành công.

### Bước 3: Kiểm tra ứng dụng trên trình duyệt
1. Mở trình duyệt và truy cập:
   ```text
   http://<VPS_IP>:8080/actuator/health
   ```
   Xác nhận trả về JSON trạng thái HTTP 200 OK:
   ```json
   {"status":"UP"}
   ```
2. Hoặc truy cập đường dẫn gốc:
   ```text
   http://<VPS_IP>:8080/
   ```
   Xác nhận hiển thị thông điệp xác nhận ứng dụng đang hoạt động tốt.
3. Lưu ảnh chụp màn hình vào thư mục `image/` để nộp bài.

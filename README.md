# BubbleSheet – Hướng dẫn sử dụng và chạy project

Ứng dụng chấm bài trắc nghiệm qua ảnh chụp phiếu trả lời (bubble sheet), gồm **backend Django + MongoDB** và **frontend Flutter** (Web + Mobile).

---

## 1. Yêu cầu

- **Python** 3.10+ (backend)
- **Flutter** 3.x (frontend) — cài [Flutter SDK](https://docs.flutter.dev/get-started/install)
- **MongoDB** — dùng MongoDB Atlas (cloud) hoặc MongoDB local. Backend hiện cấu hình kết nối trong `bubblesheet_backend/bubblesheet_backend/settings.py` (có thể chuyển sang biến môi trường sau).

---

## 2. Backend (Django)

### 2.1 Cài đặt

```bash
cd bubblesheet_backend
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # macOS/Linux
pip install -r requirements.txt
```

### 2.2 Cấu hình MongoDB

- Mặc định backend dùng **MongoDB Atlas**. Chuỗi kết nối nằm trong `bubblesheet_backend/settings.py` (`MONGODB_HOST`, `MONGODB_NAME`).
- Nếu dùng MongoDB khác: sửa `MONGODB_HOST` trong `bubblesheet_backend/bubblesheet_backend/settings.py` cho đúng (vd: `mongodb://localhost:27017` cho MongoDB local).

### 2.3 Tạo tài khoản admin (tùy chọn)

```bash
cd bubblesheet_backend
python set_admin.py
```

### 2.4 Chạy server

```bash
cd bubblesheet_backend
python manage.py runserver 0.0.0.0:8000
```

- **Chỉ chạy web (trên cùng máy):** có thể dùng `runserver 8000` hoặc `runserver 127.0.0.1:8000`.
- **Chạy mobile (emulator/thiết bị thật) kết nối tới máy này:** bắt buộc `0.0.0.0:8000` để lắng nghe mọi interface.

Kiểm tra: mở trình duyệt vào `http://127.0.0.1:8000/api/ping/` — nếu trả về `{"ok": true, ...}` là backend đã chạy.

---

## 3. Frontend (Flutter)

### 3.1 Cài đặt

```bash
cd bubblesheet_frontend
flutter pub get
```

### 3.2 Chạy Web

Đảm bảo backend đang chạy tại `http://127.0.0.1:8000` (mặc định trong code web dùng `127.0.0.1:8000`).

```bash
cd bubblesheet_frontend
flutter run -d chrome
```

Hoặc chọn device khi chạy `flutter run`.

### 3.3 Chạy Mobile (Android / iOS)

**Bước 1:** Backend phải chạy với `runserver 0.0.0.0:8000`.

**Bước 2:** Cấu hình địa chỉ API cho mobile trong `bubblesheet_frontend/lib/services/api_service.dart`:

- Trong `_mobileBaseUrls` thêm hoặc đổi thành IP máy đang chạy Django (cùng WiFi với điện thoại).
- Ví dụ: `'http://192.168.1.100:8000/api'` — thay `192.168.1.100` bằng IP máy bạn (Windows: `ipconfig`, Mac/Linux: `ifconfig`).
- **Android Emulator:** có thể dùng `http://10.0.2.2:8000/api` (10.0.2.2 = máy host từ emulator).

**Bước 3:** Chạy app:

```bash
cd bubblesheet_frontend
flutter run -d <device_id>
```

Ví dụ: `flutter run -d android` hoặc `flutter run -d chrome`.

**Entry point:**

- **Web:** mặc định dùng `lib/main.dart` (GoRouter, màn hình trong `lib/screens/`).
- **Mobile:** chạy với entry `lib/main_mobile.dart` (có Hive, scanning):  
  `flutter run -t lib/main_mobile.dart -d android`

(Nếu trong project đã cấu hình sẵn entry cho mobile thì chỉ cần `flutter run -d android`.)

### 3.4 Lỗi "Cannot connect server" trên mobile

1. **Cùng WiFi:** Điện thoại và máy chạy Django phải cùng mạng WiFi.
2. **Đúng IP:** Trong `api_service.dart`, `_mobileBaseUrls` phải có `http://<IP_MÁY>:8000/api` đúng với IP máy chạy backend.
3. **Firewall (Windows):** Cổng 8000 có thể bị chặn. Chạy **Run as administrator** file `bubblesheet_backend/allow_mobile_firewall.bat` để thêm rule cho phép kết nối vào port 8000. Hoặc vào Windows Defender Firewall → Allow an app → bật Python (hoặc rule port 8000) cho mạng Private.
4. **Kiểm tra nhanh:** Trên điện thoại mở trình duyệt, vào `http://<IP_MÁY>:8000/api/ping/`. Nếu không mở được thì lỗi do mạng/firewall.

---

## 4. Luồng sử dụng cơ bản

1. **Đăng ký / Đăng nhập** — Tạo tài khoản giáo viên hoặc đăng nhập.
2. **Lớp học** — Tạo lớp, thêm/sửa học sinh trong lớp.
3. **Mẫu phiếu trả lời (Answer sheet)** — Tạo mẫu phiếu (số câu, số lựa chọn, số chữ số mã SV/đề/lớp…), xuất PDF.
4. **Đề thi (Quiz/Exam)** — Tạo đề thi, gắn mẫu phiếu, gắn lớp, thiết lập đáp án (answer key) và mã đề.
5. **Chấm bài** — Chụp/upload ảnh phiếu đã tô; backend nhận diện ArUco, warp ảnh, đọc bọt, so đáp án và trả về điểm.
6. **Xem điểm / thống kê** — Xem bảng điểm theo lớp/đề, phân tích câu hỏi (nếu có).

---

## 5. Cấu trúc thư mục (tóm tắt)

```
datn_grade_sheet/
├── bubblesheet_backend/          # Django + DRF + MongoEngine
│   ├── bubblesheet_backend/      # settings, urls
│   ├── users/                    # User (MongoDB), auth, JWT
│   ├── classes/                  # Lớp học
│   ├── students/                 # Học sinh
│   ├── exams/                    # Đề thi (Quiz)
│   ├── answer_sheets/            # Mẫu phiếu trả lời, generate PDF
│   ├── answer_keys/              # Đáp án, mã đề
│   ├── grading/                  # Pipeline chấm bài (scan, ArUco, chấm)
│   ├── manage.py
│   ├── requirements.txt
│   └── allow_mobile_firewall.bat # Mở firewall port 8000 (Windows)
│
├── bubblesheet_frontend/         # Flutter
│   ├── lib/
│   │   ├── main.dart             # Entry web (dùng router.dart)
│   │   ├── main_mobile.dart     # Entry mobile (Hive, scanning)
│   │   ├── router.dart          # GoRouter cho web
│   │   ├── screens/             # Màn hình web
│   │   ├── mobile/              # Màn hình mobile
│   │   ├── services/             # API, cache, grading...
│   │   └── providers/           # Provider (auth, class, exam...)
│   ├── pubspec.yaml
│   └── README.md                 # README riêng frontend (mobile connection)
│
└── README.md                     # File này
```

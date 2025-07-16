# QR Code Login Demo

This is a simple demo project demonstrating a QR code-based login system. It consists of:
-  **Web Frontend**: Built with Next.js (React), renders QR codes and polls for confirmation.
-  **Backend**: Built with Hono.js (Node.js), PostgreSQL for data storage, and JWT for authentication. Handles token generation, confirmation, and protected routes.
-  **iOS App**: Built with SwiftUI, allows users to log in, scan QR codes, and confirm logins.

The system simulates a cross-device login flow (e.g., scan QR on mobile to log in on web). It's designed for learning and testing purposes only.

**Important Warning**: This is a demo and **NOT suitable for production**. It uses hardcoded credentials, no password hashing, insecure practices (e.g., plain HTTP, no input validation), and minimal error handling. In production, use secure hashing (e.g., bcrypt), HTTPS, proper validation, and a real database with user registration. Do not deploy this as-is, as it could expose security risks.


```mermaid
sequenceDiagram
    participant Web
    participant iOS
    participant Backend

    Web->>Backend: GET /generate-qrcode
    Backend-->>Web: { token: 'uuid' }
    Web->>Web: 渲染 QR 码，开始轮询 /check-session/[token]

    iOS->>Backend: POST /login {email, password}
    Backend-->>iOS: { jwt: 'token' }
    iOS->>iOS: 存储 JWT，显示 email + Scan 按钮

    iOS->>iOS: 点击 Scan，打开摄像头
    iOS->>iOS: 扫描到 QR (token)，弹出确认弹窗
    iOS->>Backend: (确认) POST /confirm-login { scannedToken }, Bearer [JWT]
    Backend->>Backend: 从 JWT 提取 userId，更新 qr_sessions status='confirmed', user_id

    loop 每 3 秒轮询
        Web->>Backend: GET /check-session/[token]
        Backend-->>Web: { status: 'confirmed', authToken }
    end
    Web->>Web: 存储 authToken，停止轮询，refetch /protected (Bearer [authToken])
    Backend-->>Web: { message: 'Protected content' }
    Web->>Web: 显示保护内容
```


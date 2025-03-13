# 📱 중원대학교 기숙사 QR 코드 앱

### 🚀 개요
이 앱은 **Flutter 프레임워크**를 사용하여 제작된 **중원대학교 기숙사 출입 QR 코드 앱**입니다.
기숙사 게이트를 통과하려면 QR 코드를 리딩해야 하지만, 기본 제공 앱은 디자인이 만족스럽지 않고 QR 코드를 바로 띄우지 않는 불편함이 있었습니다.
이를 개선하여 **더 빠르고 직관적인 QR 코드 출입 시스템**을 제공합니다.

---

### 🔍 주요 기능
- **DMS(기숙사 관리 시스템) 자동 로그인**
    - 사용자 계정 정보를 입력하면 DMS 웹사이트에 자동 로그인합니다.
    - 로그인 후 인증 토큰을 포함한 쿠키 데이터를 저장합니다.
- **QR 코드 즉시 표시**
    - 로그인 상태에서는 앱 실행 즉시 **QR 화면(qr_screen)**으로 이동합니다.
    - DMS 웹사이트에서 출입 QR 코드(출입 토큰)를 자동으로 파싱하여 표시합니다.
- **QR 코드 생성**
    - 출입 토큰을 QR 코드로 변환하여 화면에 띄웁니다.

---

### 🛠️ 기술 스택
- **Flutter**
- **Dart**
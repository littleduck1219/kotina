# Kotina

Kotina는 macOS 화면 상단에 떠 있는 글래스 플로팅 바에서 한국어 문장을
보수적으로 교정하고 한국어·영어 사이를 번역하는 무료 베타 앱입니다.

## 시스템 요구 사항

- Apple silicon Mac
- macOS 15.0 이상
- 초기 베타는 개발자 서명이 없는 unsigned 앱입니다.

## 비용과 개인정보

맞춤법 검사와 번역은 모두 Mac 안에서 처리됩니다. 번역은 앱에 포함된 llama.cpp
실행기와 사용자가 처음 준비할 때 내려받는 Qwen3-4B 모델을 사용하며, 유료 API 키,
사용량 과금, 서버 전송이 없습니다. Kotina는 분석·추적·원격 텔레메트리를 포함하지
않습니다.

번역을 처음 사용할 때 약 2.5GB의 모델을 한 번 내려받습니다. 모델은
`Application Support/Kotina/Models`에 저장되며 이후 한국어↔영어 번역은 오프라인으로
실행됩니다.

## 설치

1. `Kotina-<version>-macOS-arm64.zip`의 압축을 풉니다.
2. `Kotina.app`을 응용 프로그램 폴더로 옮깁니다.
3. unsigned 베타이므로 처음 실행이 차단되면 Finder에서 앱을 Control-클릭한 뒤
   `열기`를 선택합니다. 또는 시스템 설정 → 개인정보 보호 및 보안에서 차단된
   Kotina의 `확인 없이 열기`를 선택합니다.

Gatekeeper를 비활성화하거나 quarantine 속성을 제거하는 명령은 필요하지 않습니다.

## 사용

1. 상단 플로팅 바에 한국어 또는 영어 문장을 입력하거나 붙여넣습니다.
2. 맞춤법 탭에서 확신할 수 있는 교정과 이유를 확인합니다.
3. 번역 탭에서 `한국어 → 영어` 또는 `영어 → 한국어`를 선택하고, `로컬 번역 모델 준비`가
   표시되면 버튼을 눌러 약 2.5GB 모델을 한 번 준비합니다.
4. `교정문 복사` 또는 `번역문 복사`로 결과를 클립보드에 복사합니다.

플로팅 바의 `…` 메뉴에서 `Kotina 종료`를 선택하거나 `Command-Q`를 눌러 앱을
완전히 종료할 수 있습니다.

## 맞춤법 검사 범위

이 베타는 생성형 재작성을 하지 않습니다. 현재 자동 교정은 다음과 같이
검증된 좁은 규칙에 한정됩니다.

- `몇일 → 며칠`
- `되요 → 돼요`
- 부정 표현 `안 되-` 띄어쓰기
- `왠/웬` 구분과 `왠지` 예외
- 형태소 근거가 있는 의존 명사 `수` 띄어쓰기
- 연속된 가로 공백 정리

규칙 범위 밖의 문장은 그대로 보존됩니다. “오류 없음”이 모든 문법의 정확성을
보장한다는 뜻은 아닙니다.

## SHA-256 확인

ZIP과 `.sha256` 파일을 같은 폴더에 둔 뒤 Terminal에서 확인합니다.

```bash
shasum -a 256 -c Kotina-<version>-macOS-arm64.zip.sha256
```

결과가 `OK`여야 합니다.

## 제거

Kotina를 종료한 뒤 응용 프로그램 폴더의 `Kotina.app`을 휴지통으로 옮기면 됩니다.
계정이나 서버 데이터는 없습니다. 내려받은 모델까지 지우려면
`Application Support/Kotina/Models` 폴더도 삭제합니다.

## 소스에서 빌드

```bash
scripts/fetch-kiwi.sh
scripts/fetch-llama.sh
xcodegen generate
xcodebuild -project Kotina.xcodeproj -scheme Kotina -destination 'platform=macOS' build
```

Kiwi 0.23.2, llama.cpp, Qwen3 모델의 출처·checksum·라이선스 정보는
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)에 있습니다.

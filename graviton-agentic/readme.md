Graviton in Days vs Months — 핵심 개념
"몇 달 걸리던 Graviton 마이그레이션을 며칠 만에"라는 메시지입니다. 원래 x86 → ARM64(Graviton) 전환은 호환성 분석, 의존성 수정, 재컴파일, 검증 등으로 수개월이 걸리는 프로젝트였는데, AI 에이전트 도구(AWS Transform custom, Agent Skills, Kiro Power)를 쓰면 이 과정을 대폭 자동화해 며칠 수준으로 단축할 수 있다는 이야기입니다.

각 구성 요소를 정리하면 다음과 같습니다.

1. AWS Graviton (전환의 목표)
AWS가 자체 설계한 ARM64 기반 프로세서입니다. 동급 x86 인스턴스 대비 최대 40% 더 나은 가격 대비 성능을 제공하는 것이 핵심 가치입니다 (AWS EC2 Graviton). 순수 Java 애플리케이션은 Amazon Corretto/OpenJDK가 ARM64에 잘 최적화되어 있어 변경 없이 그대로 도는 경우도 많습니다.

2. AWS Transform custom (ATX) — 전환 엔진
에이전트 기반 AI로 대규모 코드 현대화(기술 부채 감소)를 수행하는 서비스입니다. 언어 버전 업그레이드, API/SDK 마이그레이션, 프레임워크 전환, 리팩터링 등을 다루며 x86 → Graviton 도 기본 제공 카탈로그에 포함됩니다 (DevOps 블로그).

CLI와 웹 인터페이스 제공, 자연어로 변환을 정의하고 로컬 코드베이스에서 대화형/자율 실행 가능
많은 사례에서 실행 시간을 최대 80%까지 단축했다고 보고 (AWS 블로그)
Java x86 → Graviton 관리형 변환은 4단계 프로세스로 진행됩니다 (Getting Started):

호환성 차단 요소(blocker) 분석
자동 재컴파일 및 의존성 업데이트로 문제 수정 (ARM64를 막는 의존성만 선별 업데이트)
Graviton 인스턴스에서 변경 사항 검증
전환 내용 문서화
3. Graviton 유니버설 스킬 (Claude Skills / Agent Skills)
"Agent Skills"는 전문가 지침을 AI 코딩 어시스턴트가 따를 수 있는 형태로 패키징하는 오픈 표준입니다. 각 스킬은 지침, 참고자료, 스크립트를 담은 폴더로, 에이전트에게 특정 작업(여기서는 Graviton 마이그레이션) 수행법을 가르칩니다 (Graviton 기술 가이드).

AWS가 오픈소스 Graviton 유니버설 스킬을 공개
Claude Code, Kiro, Cursor, Codex, Windsurf, Gemini CLI, GitHub Copilot 등 20개 이상 플랫폼에서 동일하게 동작 (tools 페이지)
즉 특정 도구에 종속되지 않고 원하는 플랫폼에서 같은 마이그레이션 전문성을 사용 가능
4. Kiro Power for AWS Transform — 에디터 안에서 실행
Kiro Power, AWS Transform 에이전트 스킬, AWS Transform IDE 플러그인(VS Code 및 Open VSX)을 조합하면 에디터를 벗어나지 않고 커스텀 변환을 설계하고 실행할 수 있습니다 (DevOps 블로그). 참고로 Kiro에서 Power는 문서·워크플로 가이드(스티어링)와 (선택적으로) MCP 서버를 묶어 제공하는 패키지 개념입니다.

세 가지를 함께 쓰는 흐름
정리하면 세 요소는 목적이 다르지만 상호 보완적입니다.

구성 요소	역할	특징
AWS Transform custom	대규모 자동 변환 엔진	관리형 4단계 Graviton 변환, CLI/웹
Graviton 유니버설 스킬 (Claude Skills)	이식 가능한 마이그레이션 전문성	오픈 표준, 20+ 플랫폼 호환
Kiro Power	에디터 내 통합 실행	Kiro/IDE에서 설계·실행
핵심 요약: Graviton의 가격·성능 이점(최대 40% 절감)을 얻기 위한 x86→ARM64 마이그레이션을, ATX의 자동화 + 여러 AI 도구에서 재사용 가능한 오픈 스킬 + Kiro/IDE 통합 실행으로 결합해 "몇 달 → 며칠"로 단축한다는 것이 이 주제의 골자입니다.

참고: 라이선스 준수를 위해 출처 내용은 재구성했습니다(Content was rephrased for compliance). 더 깊은 실습 예제(특정 Java 프로젝트 전환 데모 등)가 필요하면 원하는 방향을 알려주시면 해당 블로그 내용을 더 자세히 찾아드리겠습니다.
